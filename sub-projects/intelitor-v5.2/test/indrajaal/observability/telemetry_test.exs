defmodule Indrajaal.Observability.TelemetryTest do
  @moduledoc """
  Test suite for telemetry system enhancements.

  This module tests:
  - Event emission and handling
  - Metric reporters and collectors
  - Event metadata enrichment
  - Performance measurement
  - Event batching and buffering
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Telemetry

  describe "event emission" do
    test "emits events with proper structure" do
      # Given an event handler
      {:ok, handler_ref} =
        Telemetry.attach_handler(
          "test_handler",
          [:indrajaal, :request, :complete],
          fn event, measurements, metadata, config ->
            send(config.test_pid, {:event_received, event, measurements, metadata})
          end,
          %{test_pid: self()}
        )

      # When emitting event
      Telemetry.emit(
        [:indrajaal, :request, :complete],
        %{duration: 100, status_code: 200},
        %{path: "/api/users", method: "GET"}
      )

      # Then handler should receive it
      assert_receive {:event_received, received_event, measurements, received_metadata}
      assert received_event == [:indrajaal, :request, :complete]
      assert measurements.duration == 100
      assert measurements.status_code == 200
      assert received_metadata.path == "/api/users"
      assert received_metadata.method == "GET"

      # Cleanup
      Telemetry.detach_handler(handler_ref)
    end

    test "supports wildcard event handlers" do
      # Given a wildcard handler
      events_received = :ets.new(:events_table, [:public, :bag])

      {:ok, handler_ref} =
        Telemetry.attach_wildcard_handler(
          "wildcard_test",
          [:indrajaal, :*, :*],
          fn event_name, _measurements, _metadata, config ->
            :ets.insert(config.table, {event_name})
          end,
          %{table: events_received}
        )

      # When emitting various events
      Telemetry.emit([:indrajaal, :accounts, :login], %{}, %{})
      Telemetry.emit([:indrajaal, :payments, :process], %{}, %{})
      Telemetry.emit([:indrajaal, :orders, :create], %{}, %{})

      # Then all matching events should be captured
      received_events = events_received |> :ets.tab2list() |> Enum.map(&elem(&1, 0))
      assert [:indrajaal, :accounts, :login] in received_events
      assert [:indrajaal, :payments, :process] in received_events
      assert [:indrajaal, :orders, :create] in received_events

      # Cleanup
      Telemetry.detach_handler(handler_ref)
      :ets.delete(events_received)
    end

    test "handles errors in event handlers gracefully" do
      # Given a failing handler
      {:ok, failing_ref} =
        Telemetry.attach_handler(
          "failing_handler",
          [:indrajaal, :test, :event],
          fn _event, _measurements, _metadata, _config ->
            raise "Handler error"
          end,
          %{}
        )

      # And a working handler
      {:ok, working_ref} =
        Telemetry.attach_handler(
          "working_handler",
          [:indrajaal, :test, :event],
          fn _event, _measurements, _metadata, config ->
            send(config.test_pid, :handler_executed)
          end,
          %{test_pid: self()}
        )

      # When emitting event
      result = Telemetry.emit([:indrajaal, :test, :event], %{}, %{})

      # Then emission should succeed
      assert result == :ok
      assert_receive :handler_executed

      # And failing handler should be detached
      handlers = Telemetry.list_handlers([:indrajaal, :test, :event])
      refute Enum.any?(handlers, &(&1.id == "failing_handler"))
      assert Enum.any?(handlers, &(&1.id == "working_handler"))

      # Cleanup
      Telemetry.detach_handler(working_ref)
    end
  end

  describe "metric reporters" do
    test "configures metric reporters correctly" do
      # Given metric reporter configuration
      reporter_config = %{
        metrics: [
          Telemetry.Metrics.counter("indrajaal.request.count"),
          Telemetry.Metrics.distribution("indrajaal.request.duration", unit: :millisecond),
          Telemetry.Metrics.last_value("indrajaal.system.memory", unit: :megabyte)
        ],
        interval: 5_000
      }

      # When starting reporter
      {:ok, reporter_pid} = Telemetry.start_reporter(:test_reporter, reporter_config)

      # Then reporter should be running
      assert Process.alive?(reporter_pid)
      assert Telemetry.get_reporter_status(:test_reporter) == :running

      # Cleanup
      Telemetry.stop_reporter(:test_reporter)
    end

    test "aggregates metrics over reporting interval" do
      # Given a metric reporter
      {:ok, _reporter} =
        Telemetry.start_reporter(
          :aggregation_test,
          %{
            metrics: [
              Telemetry.Metrics.sum("indrajaal.api.requests", tags: [:endpoint])
            ],
            interval: 100,
            handler: fn metrics ->
              send(self(), {:metrics_reported, metrics})
            end
          }
        )

      # When events occur
      Telemetry.emit([:indrajaal, :api, :requests], %{count: 1}, %{endpoint: "/users"})
      Telemetry.emit([:indrajaal, :api, :requests], %{count: 1}, %{endpoint: "/users"})
      Telemetry.emit([:indrajaal, :api, :requests], %{count: 1}, %{endpoint: "/orders"})

      # Then aggregated metrics should be reported
      assert_receive {:metrics_reported, metrics}, 200
      assert metrics["indrajaal.api.requests"][%{endpoint: "/users"}] == 2
      assert metrics["indrajaal.api.requests"][%{endpoint: "/orders"}] == 1

      # Cleanup
      Telemetry.stop_reporter(:aggregation_test)
    end

    test "handles custom metric types" do
      # Given custom metric type
      defmodule PercentileMetric do
        def init(opts), do: {:ok, %{values: [], percentile: opts[:percentile] || 95}}
        def handle_event(value, state), do: {:ok, %{state | values: [value | state.values]}}

        def extract(state) do
          sorted = Enum.sort(state.values)
          index = round(length(sorted) * state.percentile / 100)
          Enum.at(sorted, index)
        end
      end

      # When using custom metric
      metric =
        Telemetry.Metrics.custom(
          "indrajaal.latency.p95",
          PercentileMetric,
          event: [:indrajaal, :request, :complete],
          measurement: :duration,
          percentile: 95
        )

      # Then it should work correctly
      assert metric.type == :custom
      assert metric.reporter_module == PercentileMetric
    end
  end

  describe "metadata enrichment" do
    test "automatically enriches events with context" do
      # Given context enrichment rules
      Telemetry.configure_enrichment([
        {[:indrajaal, :*, :*],
         fn metadata ->
           Map.merge(metadata, %{
             node: Node.self(),
             timestamp: System.system_time(:millisecond)
           })
         end}
      ])

      # When emitting event
      {:ok, handler_ref} =
        Telemetry.attach_handler(
          "enrichment_test",
          [:indrajaal, :test, :enriched],
          fn _event, _measurements, metadata, config ->
            send(config.test_pid, {:enriched_metadata, metadata})
          end,
          %{test_pid: self()}
        )

      Telemetry.emit([:indrajaal, :test, :enriched], %{}, %{user_id: 123})

      # Then metadata should be enriched
      assert_receive {:enriched_metadata, enriched_metadata}
      assert enriched_metadata.user_id == 123
      assert enriched_metadata.node == Node.self()
      assert is_integer(enriched_metadata.timestamp)

      # Cleanup
      Telemetry.detach_handler(handler_ref)
    end

    test "enriches with process dictionary values" do
      # Given process dictionary values
      Process.put(:tenant_id, "tenant_123")
      Process.put(:request_id, "req_456")

      # When configuring process enrichment
      Telemetry.configure_process_enrichment([:tenant_id, :request_id])

      # And emitting event
      metadata = Telemetry.emit_and_return([:indrajaal, :enriched], %{}, %{})

      # Then process values should be included
      assert metadata.tenant_id == "tenant_123"
      assert metadata.request_id == "req_456"
    end

    test "supports conditional enrichment" do
      # Given conditional enrichment rules
      Telemetry.configure_enrichment([
        {[:indrajaal, :api, :*],
         fn metadata ->
           if metadata[:authenticated] do
             Map.put(metadata, :auth_method, "token")
           else
             Map.put(metadata, :auth_method, "none")
           end
         end}
      ])

      # When emitting authenticated and unauthenticated events
      auth_meta =
        Telemetry.emit_and_return([:indrajaal, :api, :call], %{}, %{authenticated: true})

      unauth_meta =
        Telemetry.emit_and_return([:indrajaal, :api, :call], %{}, %{authenticated: false})

      # Then enrichment should be conditional
      assert auth_meta.auth_method == "token"
      assert unauth_meta.auth_method == "none"
    end
  end

  describe "performance measurement" do
    test "provides convenient timing helpers" do
      # When measuring operation duration
      {result, measurements} =
        Telemetry.measure([:indrajaal, :operation], %{op: "test"}, fn ->
          Process.sleep(50)
          {:ok, "result"}
        end)

      # Then duration should be measured
      assert result == {:ok, "result"}
      # microseconds
      assert measurements.duration >= 50_000
      assert measurements.duration < 100_000
    end

    test "measures with automatic status detection" do
      # When measuring successful operation
      {success_result, success_meta} =
        Telemetry.measure_with_status(
          [:indrajaal, :operation],
          fn -> {:ok, "success"} end
        )

      # When measuring failed operation
      {error_result, error_meta} =
        Telemetry.measure_with_status(
          [:indrajaal, :operation],
          fn -> {:error, :failed} end
        )

      # Then status should be detected
      assert success_result == {:ok, "success"}
      assert success_meta.status == :success

      assert error_result == {:error, :failed}
      assert error_meta.status == :error
    end

    test "supports span-like measurements" do
      # When using span measurements
      span = Telemetry.start_span([:indrajaal, :complex, :operation], %{user_id: 123})

      # Perform some work
      Process.sleep(25)
      Telemetry.add_span_event(span, "checkpoint_1", %{progress: 50})

      Process.sleep(25)
      Telemetry.add_span_event(span, "checkpoint_2", %{progress: 100})

      # When ending span
      measurements = Telemetry.end_span(span, %{items_processed: 10})

      # Then span should have complete data
      assert measurements.duration >= 50_000
      assert length(measurements.events) == 2
      assert measurements.metadata.user_id == 123
      assert measurements.metadata.items_processed == 10
    end
  end

  describe "event batching" do
    test "batches events for efficiency" do
      # Given batch configuration
      Telemetry.configure_batching(
        batch_size: 10,
        batch_timeout: 100,
        handler: fn batch ->
          send(self(), {:batch_received, batch})
        end
      )

      # When emitting multiple events
      Enum.each(1..10, fn i ->
        Telemetry.emit([:indrajaal, :batch, :test], %{value: i}, %{})
      end)

      # Then batch should be sent
      assert_receive {:batch_received, batch}
      assert length(batch) == 10
      assert Enum.map(batch, & &1.measurements.value) == Enum.to_list(1..10)
    end

    test "flushes batch on timeout" do
      # Given batch configuration with timeout
      Telemetry.configure_batching(
        batch_size: 100,
        batch_timeout: 50,
        handler: fn batch ->
          send(self(), {:timeout_batch, length(batch)})
        end
      )

      # When emitting fewer events than batch size
      Enum.each(1..5, fn i ->
        Telemetry.emit([:indrajaal, :timeout, :test], %{value: i}, %{})
      end)

      # Then batch should be sent after timeout
      assert_receive {:timeout_batch, 5}, 100
    end

    test "handles backpressure gracefully" do
      # Given slow batch handler
      Telemetry.configure_batching(
        batch_size: 5,
        max_buffer_size: 20,
        handler: fn _batch ->
          # Slow processing
          Process.sleep(100)
        end
      )

      # When emitting many events quickly
      emit_results =
        Enum.map(1..30, fn i ->
          Telemetry.emit([:indrajaal, :pressure, :test], %{value: i}, %{})
        end)

      # Then some events should be dropped
      dropped_count = Enum.count(emit_results, &(&1 == {:dropped, :buffer_full}))
      assert dropped_count > 0
    end
  end

  describe "multi-tenant telemetry" do
    test "isolates telemetry by tenant" do
      # Given tenant-specific handlers
      tenant1_events = :ets.new(:tenant1, [:public, :bag])
      tenant2_events = :ets.new(:tenant2, [:public, :bag])

      {:ok, _} =
        Telemetry.attach_tenant_handler(
          "tenant1_handler",
          "tenant_1",
          [:indrajaal, :*, :*],
          fn event, measurements, metadata, config ->
            :ets.insert(config.table, {event, measurements, metadata})
          end,
          %{table: tenant1_events}
        )

      {:ok, _} =
        Telemetry.attach_tenant_handler(
          "tenant2_handler",
          "tenant_2",
          [:indrajaal, :*, :*],
          fn event, measurements, metadata, config ->
            :ets.insert(config.table, {event, measurements, metadata})
          end,
          %{table: tenant2_events}
        )

      # When emitting events for different tenants
      Telemetry.emit_for_tenant("tenant_1", [:indrajaal, :test, :event], %{value: 1}, %{})
      Telemetry.emit_for_tenant("tenant_2", [:indrajaal, :test, :event], %{value: 2}, %{})

      # Then events should be isolated
      assert length(:ets.tab2list(tenant1_events)) == 1
      assert length(:ets.tab2list(tenant2_events)) == 1

      [{_, _, meta1}] = :ets.tab2list(tenant1_events)
      [{_, _, meta2}] = :ets.tab2list(tenant2_events)

      assert meta1.tenant_id == "tenant_1"
      assert meta2.tenant_id == "tenant_2"

      # Cleanup
      :ets.delete(tenant1_events)
      :ets.delete(tenant2_events)
    end

    test "prevents cross-tenant event access" do
      # Given strict tenant isolation
      Telemetry.enable_strict_tenant_isolation()

      # When trying to attach handler without tenant
      result =
        Telemetry.attach_handler(
          "no_tenant_handler",
          [:indrajaal, :secure, :event],
          fn _, _, _, _ -> :ok end,
          %{}
        )

      # Then it should be rejected
      assert {:error, :tenant_required} = result
    end
  end

  describe "STAMP safety constraints" do
    test "limits number of handlers per event" do
      # When attaching many handlers
      handler_results =
        Enum.map(1..100, fn i ->
          Telemetry.attach_handler(
            "handler_#{i}",
            [:indrajaal, :crowded, :event],
            fn _, _, _, _ -> :ok end,
            %{}
          )
        end)

      # Then limit should be enforced
      success_count = Enum.count(handler_results, fn r -> match?({:ok, _}, r) end)

      error_count =
        Enum.count(handler_results, fn r -> match?({:error, :too_many_handlers}, r) end)

      assert success_count == Telemetry.max_handlers_per_event()
      assert error_count == 100 - Telemetry.max_handlers_per_event()
    end

    test "prevents recursive event emission" do
      # Given a handler that emits events
      {:ok, _} =
        Telemetry.attach_handler(
          "recursive_handler",
          [:indrajaal, :recursive, :event],
          fn _event, _measurements, metadata, _config ->
            if metadata[:depth] < 10 do
              Telemetry.emit([:indrajaal, :recursive, :event], %{}, %{
                depth: metadata[:depth] + 1
              })
            end
          end,
          %{}
        )

      # When starting recursive emission
      result = Telemetry.emit([:indrajaal, :recursive, :event], %{}, %{depth: 0})

      # Then recursion should be prevented
      assert {:error, :recursion_detected} = result
    end

    test "enforces event name conventions" do
      # When emitting with invalid event names
      assert {:error, :invalid_event_name} =
               Telemetry.emit([:indrajaal, "Invalid-Name"], %{}, %{})

      assert {:error, :invalid_event_name} =
               Telemetry.emit([:indrajaal, :too, :many, :parts, :here], %{}, %{})

      # Valid events should work
      assert :ok = Telemetry.emit([:indrajaal, :valid, :event], %{}, %{})
    end
  end
end
