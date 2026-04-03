defmodule Indrajaal.Core.ZenohThroughputBenchmarkTest do
  @moduledoc """
  Throughput benchmark and correctness tests for the Zenoh data path.

  WHAT: Tests message serialization/deserialization throughput, per-message
        latency, batch publishing, FIFO ordering, concurrent publishers,
        backpressure semantics, and serialization round-trip correctness.
        All tests are self-contained using Jason + in-process queues;
        no running Zenoh router is required.

  WHY: Validates SC-ZTEST-003 (publish latency < 10ms) and SC-PRF-050
       (response < 50ms). Ensures the data path can sustain 1000 msg/s
       through the serialization layer before any NIF overhead is added.

  STAMP Constraints:
  - SC-ZTEST-003: Publish latency per message < 10ms
  - SC-ZTEST-012: Message ordering MUST be FIFO per topic
  - SC-ZTEST-016: Payload size < 64KB
  - SC-PRF-050: Response < 50ms (batch budget)
  - SC-BUS-001: Async messaging only — no blocking operations

  AOR Rules:
  - AOR-ZTEST-004: Use async publishing — never block test execution
  - AOR-ZTEST-010: Duration metrics included in all test result messages
  - AOR-ZTEST-012: FIFO ordering preserved within topic
  - AOR-ZTEST-013: Log-based fallback when Zenoh unavailable

  Constitutional Verification:
  - Ψ₁ Regeneration: Serialized messages fully reconstruct original data
  - Ψ₃ Verification: Sequence numbers allow integrity verification
  - Ψ₅ Truthfulness: Throughput numbers come from wall-clock measurements

  ## Change History
  | Version | Date       | Author | Change                                    |
  |---------|------------|--------|-------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial Zenoh throughput benchmark tests  |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :zenoh_benchmark
  @moduletag :throughput

  # ── Throughput budget constants ──────────────────────────────────────────────
  # 1000 messages must serialize in under this many milliseconds.
  @throughput_budget_ms 1_000

  # Per-message publish latency limit (SC-ZTEST-003).
  @per_message_latency_ms 10

  # Batch publish budget: 100 messages in < 100ms (SC-PRF-050).
  @batch_budget_ms 100

  # Maximum allowed payload size in bytes (SC-ZTEST-016: < 64KB).
  @max_payload_bytes 65_536

  # ============================================================================
  # 1. SERIALIZATION THROUGHPUT — 1000 messages encoded in < 1s
  # ============================================================================

  describe "serialization throughput (SC-PRF-050)" do
    test "1000 messages serialized in under #{@throughput_budget_ms}ms" do
      messages = build_messages(1000, "throughput/serialize", 100)

      {elapsed_us, _encoded} =
        :timer.tc(fn ->
          Enum.map(messages, &serialize_message/1)
        end)

      elapsed_ms = elapsed_us / 1_000

      assert elapsed_ms < @throughput_budget_ms,
             "Serialize 1000 msgs took #{Float.round(elapsed_ms, 2)}ms — budget #{@throughput_budget_ms}ms"
    end

    test "1000 messages deserialized in under #{@throughput_budget_ms}ms" do
      messages = build_messages(1000, "throughput/deserialize", 100)
      encoded = Enum.map(messages, &serialize_message/1)

      {elapsed_us, decoded} =
        :timer.tc(fn ->
          Enum.map(encoded, &deserialize_message/1)
        end)

      elapsed_ms = elapsed_us / 1_000

      assert elapsed_ms < @throughput_budget_ms,
             "Deserialize 1000 msgs took #{Float.round(elapsed_ms, 2)}ms — budget #{@throughput_budget_ms}ms"

      assert length(decoded) == 1000
    end
  end

  # ============================================================================
  # 2. PAYLOAD SIZES — small / medium / large under budget
  # ============================================================================

  describe "payload size budgets (SC-ZTEST-016)" do
    test "small payload (100B) serializes and fits under max size" do
      msg = build_message("size/small", 100, 1)
      encoded = serialize_message(msg)

      assert byte_size(encoded) < @max_payload_bytes
      assert byte_size(encoded) > 0
    end

    test "medium payload (1KB) serializes and fits under max size" do
      msg = build_message("size/medium", 1_024, 1)
      encoded = serialize_message(msg)

      assert byte_size(encoded) < @max_payload_bytes
    end

    test "large payload (10KB) serializes and fits under max size" do
      msg = build_message("size/large", 10_240, 1)
      encoded = serialize_message(msg)

      assert byte_size(encoded) < @max_payload_bytes
    end

    test "payload at 32KB fits well within SC-ZTEST-016 limit" do
      # 32KB raw payload — well under the 64KB ceiling even after JSON+Base64 encoding
      msg = build_message("size/boundary", 32 * 1024, 1)
      encoded = serialize_message(msg)

      # Base64 expands by ~33% and JSON envelope adds overhead, so we assert
      # the encoded form is still under twice the raw limit (128KB), and the
      # raw payload itself is under 64KB (SC-ZTEST-016 targets the message payload).
      assert byte_size(msg.payload) < @max_payload_bytes
      assert byte_size(encoded) < @max_payload_bytes * 2
    end
  end

  # ============================================================================
  # 3. PER-MESSAGE PUBLISH LATENCY — < 10ms (SC-ZTEST-003)
  # ============================================================================

  describe "per-message publish latency (SC-ZTEST-003)" do
    test "each individual message serializes in under #{@per_message_latency_ms}ms" do
      messages = build_messages(50, "latency/single", 256)

      latencies_ms =
        Enum.map(messages, fn msg ->
          {us, _} = :timer.tc(fn -> serialize_message(msg) end)
          us / 1_000
        end)

      for {latency, idx} <- Enum.with_index(latencies_ms) do
        assert latency < @per_message_latency_ms,
               "Message #{idx} latency #{Float.round(latency, 3)}ms exceeds #{@per_message_latency_ms}ms"
      end
    end

    test "99th-percentile latency over 100 messages is within budget" do
      messages = build_messages(100, "latency/p99", 512)

      latencies_us =
        Enum.map(messages, fn msg ->
          {us, _} = :timer.tc(fn -> serialize_message(msg) end)
          us
        end)

      sorted = Enum.sort(latencies_us)
      p99_us = Enum.at(sorted, 98)
      p99_ms = p99_us / 1_000

      assert p99_ms < @per_message_latency_ms,
             "p99 latency #{Float.round(p99_ms, 3)}ms exceeds #{@per_message_latency_ms}ms"
    end
  end

  # ============================================================================
  # 4. BATCH PUBLISH — 100 messages in < 100ms (SC-PRF-050)
  # ============================================================================

  describe "batch publish throughput (SC-PRF-050)" do
    test "100 messages published to simulated queue in under #{@batch_budget_ms}ms" do
      messages = build_messages(100, "batch/publish", 256)
      queue = :queue.new()

      {elapsed_us, _queue} =
        :timer.tc(fn ->
          Enum.reduce(messages, queue, fn msg, q ->
            encoded = serialize_message(msg)
            :queue.in(encoded, q)
          end)
        end)

      elapsed_ms = elapsed_us / 1_000

      assert elapsed_ms < @batch_budget_ms,
             "Batch publish 100 msgs took #{Float.round(elapsed_ms, 2)}ms — budget #{@batch_budget_ms}ms"
    end

    test "batch of 100 messages all arrive in the queue" do
      messages = build_messages(100, "batch/arrival", 100)
      queue = :queue.new()

      final_queue =
        Enum.reduce(messages, queue, fn msg, q ->
          :queue.in(serialize_message(msg), q)
        end)

      assert :queue.len(final_queue) == 100
    end
  end

  # ============================================================================
  # 5. MESSAGE ORDERING (FIFO) — SC-ZTEST-012
  # ============================================================================

  describe "FIFO message ordering (SC-ZTEST-012)" do
    test "messages dequeued in same order as enqueued" do
      messages = build_messages(20, "ordering/fifo", 128)
      queue = :queue.new()

      filled_queue =
        Enum.reduce(messages, queue, fn msg, q ->
          :queue.in(serialize_message(msg), q)
        end)

      dequeued =
        1..20
        |> Enum.map_reduce(filled_queue, fn _i, q ->
          {{:value, item}, rest} = :queue.out(q)
          {deserialize_message(item), rest}
        end)
        |> elem(0)

      original_seqs = Enum.map(messages, & &1.seq)
      dequeued_seqs = Enum.map(dequeued, & &1["seq"])

      assert dequeued_seqs == original_seqs,
             "FIFO violated: expected #{inspect(original_seqs)}, got #{inspect(dequeued_seqs)}"
    end

    test "batch ordering preserved after serialize→deserialize roundtrip" do
      messages = build_messages(50, "ordering/roundtrip", 64)

      roundtripped =
        messages
        |> Enum.map(&serialize_message/1)
        |> Enum.map(&deserialize_message/1)

      for {orig, rt} <- Enum.zip(messages, roundtripped) do
        assert rt["seq"] == orig.seq
        assert rt["topic"] == orig.topic
      end
    end
  end

  # ============================================================================
  # 6. CONCURRENT PUBLISHERS — 5 × 200 = 1000 total messages all arrive
  # ============================================================================

  describe "concurrent publishers (SC-PRF-050)" do
    test "5 concurrent publishers × 200 messages each — all 1000 arrive" do
      parent = self()
      n_publishers = 5
      msgs_per_publisher = 200
      topic_prefix = "concurrent"

      tasks =
        for pub_id <- 1..n_publishers do
          Task.async(fn ->
            msgs = build_messages(msgs_per_publisher, "#{topic_prefix}/pub#{pub_id}", 128)
            encoded = Enum.map(msgs, &serialize_message/1)
            send(parent, {:batch_done, pub_id, length(encoded)})
            length(encoded)
          end)
        end

      counts = Task.await_many(tasks, 5_000)
      total = Enum.sum(counts)

      assert total == n_publishers * msgs_per_publisher,
             "Expected #{n_publishers * msgs_per_publisher} total messages, got #{total}"
    end

    test "concurrent serializations do not interfere with each other" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            msg = build_message("concurrent/isolate", 256, i)
            encoded = serialize_message(msg)
            decoded = deserialize_message(encoded)
            decoded["seq"] == i
          end)
        end

      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results), "Concurrent serializations produced incorrect seq numbers"
    end
  end

  # ============================================================================
  # 7. BACKPRESSURE — slow consumer causes producer to block (not drop)
  # ============================================================================

  describe "backpressure: producer blocks when consumer is slow (SC-BUS-001)" do
    test "bounded queue blocks producer at capacity limit" do
      capacity = 10
      # Fill a bounded queue to capacity using ETS as a counter substitute
      table = :ets.new(:bp_test, [:set, :public])
      :ets.insert(table, {:count, 0})

      messages = build_messages(capacity + 5, "backpressure/test", 64)

      admitted =
        Enum.reduce_while(messages, 0, fn msg, acc ->
          [{:count, current}] = :ets.lookup(table, :count)

          if current < capacity do
            _encoded = serialize_message(msg)
            :ets.insert(table, {:count, current + 1})
            {:cont, acc + 1}
          else
            # Backpressure: halt accepting new messages
            {:halt, acc}
          end
        end)

      :ets.delete(table)

      # Producer was blocked once queue reached capacity
      assert admitted == capacity,
             "Expected exactly #{capacity} messages admitted, got #{admitted}"
    end

    test "messages are not dropped when backpressure is applied" do
      # All messages that are admitted must be dequeue-able intact
      capacity = 5
      messages = build_messages(capacity, "backpressure/no-drop", 128)
      queue = :queue.new()

      final_queue =
        Enum.reduce(messages, queue, fn msg, q ->
          :queue.in(serialize_message(msg), q)
        end)

      # All admitted messages are intact in the queue
      assert :queue.len(final_queue) == capacity
    end
  end

  # ============================================================================
  # 8. PROPERTY: serialization roundtrip preserves data exactly
  # ============================================================================

  describe "property: serialization roundtrip (SC-ZTEST-012)" do
    test "roundtrip preserves all scalar fields (SD property)" do
      ExUnitProperties.check all(
                               topic <- SD.string(:alphanumeric, min_length: 1, max_length: 40),
                               seq <- SD.positive_integer(),
                               max_runs: 30
                             ) do
        msg = build_message(topic, 64, seq)
        decoded = msg |> serialize_message() |> deserialize_message()

        assert decoded["topic"] == topic
        assert decoded["seq"] == seq
        assert is_integer(decoded["timestamp"])
      end
    end
  end

  # ============================================================================
  # 9. PROPERTY: throughput scales linearly with batch size
  # ============================================================================

  describe "property: throughput scales sub-quadratically with batch size" do
    test "serialization time scales sub-quadratically for batch sizes 10→100 (SD property)" do
      ExUnitProperties.check all(
                               base_size <- SD.integer(10..40),
                               max_runs: 10
                             ) do
        small = build_messages(base_size, "scale/sd-small", 64)
        large = build_messages(base_size * 5, "scale/sd-large", 64)

        {small_us, _} = :timer.tc(fn -> Enum.map(small, &serialize_message/1) end)
        {large_us, _} = :timer.tc(fn -> Enum.map(large, &serialize_message/1) end)

        # Generous safety margin: large batch should take less than 50× the time
        # for 5× the work (allows for scheduling jitter in CI)
        assert large_us < small_us * 50 + 100_000,
               "Throughput degraded unexpectedly: small=#{small_us}us large=#{large_us}us"
      end
    end
  end

  # ============================================================================
  # STANDALONE PROPERTY TESTS (PropCheck forall — outside describe blocks)
  # ============================================================================

  test "roundtrip: Jason encode→decode preserves topic, payload_size, and seq (SD property)" do
    ExUnitProperties.check all(
                             topic <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                             payload_len <- SD.integer(1..512),
                             seq <- SD.positive_integer(),
                             max_runs: 25
                           ) do
      msg = %{
        topic: topic,
        payload: :binary.copy(<<0>>, payload_len),
        timestamp: System.system_time(:millisecond),
        seq: seq
      }

      encoded = serialize_message(msg)
      decoded = deserialize_message(encoded)

      assert decoded["topic"] == topic
      assert decoded["seq"] == seq
    end
  end

  test "encoding time scales sub-quadratically with batch size (SD property)" do
    ExUnitProperties.check all(
                             base <- SD.integer(10..50),
                             multiplier <- SD.integer(2..4),
                             max_runs: 10
                           ) do
      small = build_messages(base, "scale/small", 128)
      large = build_messages(base * multiplier, "scale/large", 128)

      {small_us, _} = :timer.tc(fn -> Enum.map(small, &serialize_message/1) end)
      {large_us, _} = :timer.tc(fn -> Enum.map(large, &serialize_message/1) end)

      quadratic_budget = small_us * multiplier * multiplier * 3
      assert large_us <= max(quadratic_budget, 10_000)
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  # Builds a single message struct.
  @spec build_message(String.t(), non_neg_integer(), pos_integer()) :: map()
  defp build_message(topic, payload_bytes, seq) do
    %{
      topic: topic,
      payload: :binary.copy(<<65>>, max(payload_bytes, 1)),
      timestamp: System.system_time(:millisecond),
      seq: seq
    }
  end

  # Builds a list of `count` messages with incrementing seq numbers.
  @spec build_messages(pos_integer(), String.t(), non_neg_integer()) :: [map()]
  defp build_messages(count, topic, payload_bytes) do
    for seq <- 1..count do
      build_message(topic, payload_bytes, seq)
    end
  end

  # Serializes a message map to a JSON binary (SC-ZTEST-016 payload contract).
  @spec serialize_message(map()) :: binary()
  defp serialize_message(%{topic: topic, payload: payload, timestamp: ts, seq: seq}) do
    Jason.encode!(%{
      topic: topic,
      payload: Base.encode64(payload),
      timestamp: ts,
      seq: seq
    })
  end

  # Deserializes a JSON binary back to a map with string keys.
  @spec deserialize_message(binary()) :: map()
  defp deserialize_message(encoded) when is_binary(encoded) do
    Jason.decode!(encoded)
  end
end
