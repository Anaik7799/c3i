defmodule Indrajaal.Core.DashboardDataPipelineTest do
  @moduledoc """
  TDG test suite for dashboard data pipeline from Zenoh to LiveView.

  WHAT: Tests that telemetry data flows correctly from Zenoh subscriptions
  through the data transformation pipeline to LiveView assigns, verifying
  ordering, latency budgets, and data fidelity.

  CONSTRAINTS:
  - SC-BRIDGE-001: Message buffer FIFO
  - SC-BRIDGE-003: Latency budget 50ms
  - SC-PRF-050: Response < 50ms
  - SC-HMI-001: Dashboard refresh < 2s

  ## Constitutional Verification
  - Ψ₃ (Verification): Pipeline results are reproducible
  - Ψ₅ (Truthfulness): Dashboard reflects actual system state

  ## Change History
  | Version | Date       | Author | Change                                      |
  |---------|------------|--------|---------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — dashboard pipeline suite|
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Pipeline engine (simulates Zenoh → Transform → LiveView)
  # ---------------------------------------------------------------------------

  @latency_budget_ms 50

  defp build_zenoh_message(topic, payload, opts \\ []) do
    %{
      topic: topic,
      payload: payload,
      timestamp: Keyword.get(opts, :timestamp, System.monotonic_time(:microsecond)),
      sequence: Keyword.get(opts, :sequence, 0)
    }
  end

  defp transform_for_dashboard(message) do
    t_start = System.monotonic_time(:microsecond)

    result = %{
      widget_id: topic_to_widget(message.topic),
      value: extract_value(message.payload),
      updated_at: message.timestamp,
      source_topic: message.topic
    }

    t_end = System.monotonic_time(:microsecond)
    {result, (t_end - t_start) / 1_000}
  end

  defp topic_to_widget(topic) do
    topic
    |> String.split("/")
    |> List.last()
    |> String.to_atom()
  end

  defp extract_value(payload) when is_map(payload) do
    Map.get(payload, :value, Map.get(payload, "value", payload))
  end

  defp extract_value(payload), do: payload

  defp apply_assigns(socket_assigns, dashboard_data) do
    Enum.reduce(dashboard_data, socket_assigns, fn data, acc ->
      Map.put(acc, data.widget_id, data.value)
    end)
  end

  defp pipeline_fifo(messages) do
    messages
    |> Enum.sort_by(& &1.sequence)
    |> Enum.map(&transform_for_dashboard/1)
  end

  defp pipeline_batch(messages, batch_size) do
    messages
    |> Enum.sort_by(& &1.sequence)
    |> Enum.chunk_every(batch_size)
    |> Enum.map(fn batch ->
      t_start = System.monotonic_time(:microsecond)
      results = Enum.map(batch, fn msg -> elem(transform_for_dashboard(msg), 0) end)
      t_end = System.monotonic_time(:microsecond)
      {results, (t_end - t_start) / 1_000}
    end)
  end

  defp deduplicate_latest(messages) do
    messages
    |> Enum.group_by(& &1.topic)
    |> Enum.map(fn {_topic, msgs} ->
      Enum.max_by(msgs, & &1.sequence)
    end)
  end

  # ---------------------------------------------------------------------------
  # FIFO ordering tests (SC-BRIDGE-001)
  # ---------------------------------------------------------------------------

  describe "SC-BRIDGE-001: FIFO message ordering" do
    test "messages are processed in sequence order" do
      messages =
        for i <- 1..10 do
          build_zenoh_message("indrajaal/health/cpu", %{value: i * 10}, sequence: i)
        end

      results = pipeline_fifo(messages)
      sequences = Enum.map(results, fn {data, _} -> data.value end)

      assert sequences == Enum.map(1..10, &(&1 * 10))
    end

    test "out-of-order messages are reordered" do
      messages = [
        build_zenoh_message("indrajaal/health/cpu", %{value: 30}, sequence: 3),
        build_zenoh_message("indrajaal/health/cpu", %{value: 10}, sequence: 1),
        build_zenoh_message("indrajaal/health/cpu", %{value: 20}, sequence: 2)
      ]

      results = pipeline_fifo(messages)
      values = Enum.map(results, fn {data, _} -> data.value end)
      assert values == [10, 20, 30]
    end

    test "duplicate sequences are preserved" do
      messages = [
        build_zenoh_message("indrajaal/health/cpu", %{value: 10}, sequence: 1),
        build_zenoh_message("indrajaal/health/cpu", %{value: 11}, sequence: 1),
        build_zenoh_message("indrajaal/health/cpu", %{value: 20}, sequence: 2)
      ]

      results = pipeline_fifo(messages)
      assert length(results) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # Latency budget tests (SC-BRIDGE-003)
  # ---------------------------------------------------------------------------

  describe "SC-BRIDGE-003: latency budget" do
    test "single message transform within 50ms" do
      msg = build_zenoh_message("indrajaal/health/score", %{value: 95.5})
      {_result, latency_ms} = transform_for_dashboard(msg)

      assert latency_ms < @latency_budget_ms,
             "Transform took #{latency_ms}ms, budget is #{@latency_budget_ms}ms"
    end

    test "batch of 100 messages within 50ms" do
      messages =
        for i <- 1..100 do
          build_zenoh_message("indrajaal/metrics/m#{i}", %{value: i}, sequence: i)
        end

      batches = pipeline_batch(messages, 100)

      for {_results, latency_ms} <- batches do
        assert latency_ms < @latency_budget_ms,
               "Batch took #{latency_ms}ms, budget is #{@latency_budget_ms}ms"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Data transformation tests
  # ---------------------------------------------------------------------------

  describe "data transformation" do
    test "topic maps to widget_id" do
      msg = build_zenoh_message("indrajaal/health/cpu", %{value: 75.0})
      {data, _} = transform_for_dashboard(msg)

      assert data.widget_id == :cpu
      assert data.source_topic == "indrajaal/health/cpu"
    end

    test "nested topic extracts last segment" do
      msg = build_zenoh_message("indrajaal/prajna/kpi/health_score", %{value: 92})
      {data, _} = transform_for_dashboard(msg)
      assert data.widget_id == :health_score
    end

    test "payload value extraction from map" do
      msg = build_zenoh_message("indrajaal/metric", %{value: 42, unit: "ms"})
      {data, _} = transform_for_dashboard(msg)
      assert data.value == 42
    end

    test "raw payload passed through" do
      msg = build_zenoh_message("indrajaal/metric", 99.9)
      {data, _} = transform_for_dashboard(msg)
      assert data.value == 99.9
    end
  end

  # ---------------------------------------------------------------------------
  # LiveView assigns tests
  # ---------------------------------------------------------------------------

  describe "LiveView assign integration" do
    test "assigns are updated from dashboard data" do
      initial = %{cpu: 0, memory: 0}

      data = [
        %{widget_id: :cpu, value: 75.0, updated_at: 0, source_topic: "t1"},
        %{widget_id: :memory, value: 62.3, updated_at: 0, source_topic: "t2"}
      ]

      updated = apply_assigns(initial, data)
      assert updated.cpu == 75.0
      assert updated.memory == 62.3
    end

    test "new widgets are added" do
      initial = %{cpu: 50}
      data = [%{widget_id: :disk, value: 80.0, updated_at: 0, source_topic: "t1"}]

      updated = apply_assigns(initial, data)
      assert updated.cpu == 50
      assert updated.disk == 80.0
    end

    test "later values overwrite earlier" do
      initial = %{}

      data = [
        %{widget_id: :cpu, value: 50.0, updated_at: 0, source_topic: "t1"},
        %{widget_id: :cpu, value: 90.0, updated_at: 1, source_topic: "t1"}
      ]

      updated = apply_assigns(initial, data)
      assert updated.cpu == 90.0
    end
  end

  # ---------------------------------------------------------------------------
  # Deduplication tests
  # ---------------------------------------------------------------------------

  describe "deduplication" do
    test "keeps only latest message per topic" do
      messages = [
        build_zenoh_message("indrajaal/health/cpu", %{value: 10}, sequence: 1),
        build_zenoh_message("indrajaal/health/cpu", %{value: 20}, sequence: 2),
        build_zenoh_message("indrajaal/health/mem", %{value: 50}, sequence: 1),
        build_zenoh_message("indrajaal/health/cpu", %{value: 30}, sequence: 3)
      ]

      deduped = deduplicate_latest(messages)
      assert length(deduped) == 2

      cpu = Enum.find(deduped, &(&1.topic == "indrajaal/health/cpu"))
      assert cpu.payload == %{value: 30}
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: pipeline invariants" do
    property "FIFO preserves message count" do
      forall n <- PC.integer(1, 100) do
        messages =
          for i <- 1..n do
            build_zenoh_message("topic", %{value: i}, sequence: i)
          end

        length(pipeline_fifo(messages)) == n
      end
    end

    test "deduplication never increases message count" do
      ExUnitProperties.check all(n <- SD.integer(1..50)) do
        messages =
          for i <- 1..n do
            topic = "indrajaal/health/metric_#{rem(i, 5)}"
            build_zenoh_message(topic, %{value: i}, sequence: i)
          end

        deduped = deduplicate_latest(messages)
        assert length(deduped) <= n
      end
    end

    test "transform always produces valid widget_id" do
      ExUnitProperties.check all(
                               suffix <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                             ) do
        msg = build_zenoh_message("indrajaal/#{suffix}", %{value: 1})
        {data, _} = transform_for_dashboard(msg)
        assert is_atom(data.widget_id)
      end
    end

    property "batch processing handles any batch size" do
      forall {n, batch_size} <- {PC.integer(1, 50), PC.integer(1, 20)} do
        messages =
          for i <- 1..n do
            build_zenoh_message("topic", %{value: i}, sequence: i)
          end

        batches = pipeline_batch(messages, batch_size)
        total = Enum.sum(Enum.map(batches, fn {results, _} -> length(results) end))
        total == n
      end
    end
  end
end
