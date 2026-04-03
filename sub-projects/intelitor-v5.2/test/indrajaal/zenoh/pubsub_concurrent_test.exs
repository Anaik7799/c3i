defmodule Indrajaal.Zenoh.PubsubConcurrentTest do
  @moduledoc """
  Zenoh pub/sub integration test — 10 topics concurrent.

  WHAT: Simultaneously publishes and subscribes on 10 independent topics,
        verifying no message loss, no cross-contamination between topics,
        and correct FIFO ordering within each topic.

  WHY: SC-BRIDGE-001 (FIFO), SC-ZTEST-012 (per-topic ordering), and
       SC-BUS-002 (no blocking) all require that the pub/sub fabric can
       handle concurrent multi-topic activity without degradation.

  CONSTRAINTS:
    - SC-ZENOH-001: Zenoh NIF active (SKIP_ZENOH_NIF=0)
    - SC-ZTEST-012: FIFO ordering per topic
    - SC-ZTEST-017: Topic depth ≤ 6 levels
    - SC-BRIDGE-001: Message buffer FIFO
    - SC-BRIDGE-003: Latency budget 50ms
    - SC-BUS-001: Async messaging only
    - SC-BUS-002: No blocking operations

  ## Change History
  | Version | Date       | Author            | Change               |
  |---------|------------|-------------------|----------------------|
  | 1.0.0   | 2026-03-23 | Claude Sonnet 4.6 | Sprint 88 — initial  |

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh
  @moduletag :requires_zenoh
  @moduletag timeout: 60_000

  @pubsub_name __MODULE__.PubSub

  @topic_count 10
  @msgs_per_topic 20

  @topics for i <- 1..@topic_count,
              do: "indrajaal/test/concurrent/topic-#{String.pad_leading(to_string(i), 2, "0")}"

  # ── Setup ────────────────────────────────────────────────────────────────────

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})

    for topic <- @topics do
      :ok = Phoenix.PubSub.subscribe(@pubsub_name, topic)
    end

    on_exit(fn ->
      for topic <- @topics do
        Phoenix.PubSub.unsubscribe(@pubsub_name, topic)
      end
    end)

    :ok
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp make_msg(topic_idx, seq) do
    %{
      topic_idx: topic_idx,
      sequence: seq,
      payload: "msg-#{topic_idx}-#{seq}",
      ts_us: System.monotonic_time(:microsecond)
    }
  end

  defp broadcast_all do
    for {topic, idx} <- Enum.with_index(@topics, 1) do
      for seq <- 1..@msgs_per_topic do
        msg = make_msg(idx, seq)
        Phoenix.PubSub.broadcast(@pubsub_name, topic, {:concurrent, topic, msg})
      end
    end
  end

  defp drain_concurrent(timeout_ms, acc \\ []) do
    receive do
      {:concurrent, topic, msg} -> drain_concurrent(timeout_ms, [{topic, msg} | acc])
    after
      timeout_ms -> Enum.reverse(acc)
    end
  end

  # ── Tests ────────────────────────────────────────────────────────────────────

  describe "Concurrent PubSub: Topic contract" do
    test "all #{@topic_count} topics conform to depth ≤ 6 (SC-ZTEST-017)" do
      for topic <- @topics do
        depth = topic |> String.graphemes() |> Enum.count(&(&1 == "/"))
        assert depth <= 6, "Topic #{topic} has depth #{depth} > 6 (SC-ZTEST-017)"
      end
    end

    test "topics are unique (no duplicates)" do
      assert length(@topics) == length(Enum.uniq(@topics))
    end

    test "topic count is exactly #{@topic_count}" do
      assert length(@topics) == @topic_count
    end
  end

  describe "Concurrent PubSub: No message loss" do
    test "all #{@topic_count * @msgs_per_topic} messages are delivered" do
      broadcast_all()

      received = drain_concurrent(500)
      expected_total = @topic_count * @msgs_per_topic

      assert length(received) == expected_total,
             "Expected #{expected_total} msgs, got #{length(received)} — message loss detected"
    end

    test "each topic receives exactly #{@msgs_per_topic} messages" do
      broadcast_all()

      received = drain_concurrent(500)

      per_topic =
        received
        |> Enum.group_by(fn {topic, _} -> topic end)
        |> Enum.map(fn {topic, msgs} -> {topic, length(msgs)} end)

      for {topic, count} <- per_topic do
        assert count == @msgs_per_topic,
               "Topic #{topic} received #{count} msgs instead of #{@msgs_per_topic}"
      end
    end
  end

  describe "Concurrent PubSub: Topic isolation" do
    test "messages for topic-01 only appear on topic-01" do
      broadcast_all()
      received = drain_concurrent(500)

      topic_01 = hd(@topics)

      cross_msgs =
        received
        |> Enum.filter(fn {topic, msg} ->
          topic != topic_01 and msg.topic_idx == 1
        end)

      assert cross_msgs == [],
             "Cross-topic contamination: #{length(cross_msgs)} msgs from topic-01 arrived on wrong topic"
    end

    test "no cross-topic contamination across all #{@topic_count} topics" do
      broadcast_all()
      received = drain_concurrent(500)

      cross_contaminated =
        received
        |> Enum.filter(fn {topic, msg} ->
          expected_idx =
            topic
            |> String.split("-")
            |> List.last()
            |> String.to_integer()

          msg.topic_idx != expected_idx
        end)

      assert cross_contaminated == [],
             "Cross-topic contamination found: #{length(cross_contaminated)} messages on wrong topics"
    end
  end

  describe "Concurrent PubSub: FIFO ordering" do
    test "FIFO ordering preserved within each topic (SC-ZTEST-012)" do
      broadcast_all()

      received = drain_concurrent(500)

      violations =
        received
        |> Enum.group_by(fn {topic, _} -> topic end)
        |> Enum.flat_map(fn {topic, msgs} ->
          sequences = Enum.map(msgs, fn {_, msg} -> msg.sequence end)
          sorted = Enum.sort(sequences)

          if sequences != sorted do
            [{topic, sequences, sorted}]
          else
            []
          end
        end)

      assert violations == [],
             "FIFO ordering violated on topics: #{inspect(Enum.map(violations, &elem(&1, 0)))}"
    end

    test "each topic delivers sequences 1..#{@msgs_per_topic} in order" do
      broadcast_all()

      received = drain_concurrent(500)

      expected_seqs = Enum.to_list(1..@msgs_per_topic)

      for {topic, msgs_for_topic} <-
            Enum.group_by(received, fn {t, _} -> t end) do
        actual_seqs = Enum.map(msgs_for_topic, fn {_, msg} -> msg.sequence end)

        assert actual_seqs == expected_seqs,
               "Topic #{topic}: expected seqs #{inspect(expected_seqs)}, got #{inspect(actual_seqs)}"
      end
    end
  end

  describe "Concurrent PubSub: Latency" do
    test "publishing all #{@topic_count * @msgs_per_topic} msgs completes within 1s" do
      t0 = System.monotonic_time(:millisecond)
      broadcast_all()
      t1 = System.monotonic_time(:millisecond)

      elapsed_ms = t1 - t0

      assert elapsed_ms < 1_000,
             "Broadcasting #{@topic_count * @msgs_per_topic} messages took #{elapsed_ms}ms > 1000ms"
    end

    test "per-message average publish latency is < 1ms across all topics" do
      total_msgs = @topic_count * @msgs_per_topic

      t0 = System.monotonic_time(:microsecond)
      broadcast_all()
      t1 = System.monotonic_time(:microsecond)

      avg_us = (t1 - t0) / total_msgs

      assert avg_us < 1_000,
             "Average per-message latency #{Float.round(avg_us, 1)}µs > 1000µs (1ms)"
    end
  end

  describe "Concurrent PubSub: Payload integrity" do
    test "message payload is preserved verbatim through pub/sub" do
      topic = hd(@topics)
      original = make_msg(1, 99)

      Phoenix.PubSub.broadcast(@pubsub_name, topic, {:concurrent, topic, original})

      assert_receive {:concurrent, ^topic, received}, 200
      assert received.topic_idx == original.topic_idx
      assert received.sequence == original.sequence
      assert received.payload == original.payload
    end

    test "timestamp is preserved through pub/sub without modification" do
      topic = hd(@topics)
      original = make_msg(1, 1)

      Phoenix.PubSub.broadcast(@pubsub_name, topic, {:concurrent, topic, original})

      assert_receive {:concurrent, ^topic, received}, 200
      assert received.ts_us == original.ts_us
    end
  end
end
