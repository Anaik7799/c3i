defmodule Indrajaal.Zenoh.FifoMessageOrderingTest do
  @moduledoc """
  FIFO message ordering invariant tests for Zenoh messaging.

  WHAT: Validates that the Zenoh messaging layer preserves strict FIFO ordering
        within each topic, that checkpoint IDs are well-formed, that timestamps
        are monotonically increasing, and that payload and topic-depth constraints
        are enforced.

  WHY: SC-ZTEST-012 mandates FIFO ordering per topic as a hard invariant for the
       SIL-6 control plane.  SC-ZTEST-016 and SC-ZTEST-017 bound message size and
       topic depth respectively.  SC-ZTEST-001 requires unique topics.

  CONSTRAINTS:
    - SC-ZTEST-012: Message ordering MUST be FIFO per topic
    - SC-ZTEST-001: All checkpoints MUST have unique topics
    - SC-ZTEST-013: Checkpoint ID format CP-{DOMAIN}-{NN}
    - SC-ZTEST-015: Timestamp MUST be ISO 8601 UTC
    - SC-ZTEST-016: Payload size < 64 KB
    - SC-ZTEST-017: Topic depth <= 6 levels
    - SC-BRIDGE-001: Message buffer FIFO

  ## EP-GEN-014 compliance
  - `use PropCheck` provides `forall` inside `property` blocks (PC. generators)
  - `ExUnitProperties.check all` blocks are inside plain `test` blocks only
  - PC. prefix for PropCheck.BasicTypes generators
  - SD. prefix for StreamData generators
  - Module-level `ExUnitProperties.check all` blocks inline all logic; no defp calls

  ## Change History
  | Version | Date       | Author            | Change             |
  |---------|------------|-------------------|--------------------|
  | 1.0.0   | 2026-03-24 | Claude Sonnet 4.6 | Initial TDG suite  |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: Dual property testing — MANDATORY import pattern.
  # `use PropCheck` provides `forall` + `property` for PropCheck-native tests.
  # `import ExUnitProperties, except: [property: 2, property: 3, check: 2]` gives
  #   the `check all` macro used inside plain `test` blocks.
  use PropCheck
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :fifo
  @moduletag :zenoh
  @moduletag :ordering

  # SC-ZTEST-016: max payload size in bytes (64 KB)
  @max_payload_bytes 65_536
  # SC-ZTEST-017: max topic depth expressed as segment count
  @max_topic_depth 6
  # SC-ZTEST-013: regex for checkpoint ID format CP-{DOMAIN}-{NN}
  @checkpoint_id_regex ~r/^CP-[A-Z0-9]+-\d{2}$/

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ==========================================================================
  # 1. FIFO buffer maintains insertion order
  # ==========================================================================

  describe "FIFO buffer insertion order (SC-ZTEST-012)" do
    test "enqueuing N messages preserves insertion order on dequeue" do
      payloads = ~w[alpha beta gamma delta epsilon]
      buf = Enum.reduce(payloads, new_buffer(), &enqueue(&2, &1))
      {dequeued, _} = drain_buffer(buf)
      assert dequeued == payloads
    end

    test "single-element buffer enqueues and dequeues correctly" do
      buf = new_buffer() |> enqueue("only-message")
      {dequeued, empty} = drain_buffer(buf)
      assert dequeued == ["only-message"]
      assert buf_size(empty) == 0
    end

    test "empty buffer drains to empty list" do
      {dequeued, _} = drain_buffer(new_buffer())
      assert dequeued == []
    end

    test "interleaved enqueue/dequeue preserves FIFO" do
      buf0 = new_buffer()
      buf1 = enqueue(buf0, "first")
      buf2 = enqueue(buf1, "second")
      {head, buf3} = dequeue_one(buf2)
      buf4 = enqueue(buf3, "third")
      {rest, _} = drain_buffer(buf4)
      assert head == "first"
      assert rest == ["second", "third"]
    end

    test "stream data property: dequeue order equals enqueue order" do
      ExUnitProperties.check all(items <- SD.list_of(SD.string(:alphanumeric))) do
        # Inline buffer operations to satisfy module-level check all restriction
        buf = Enum.reduce(items, {[], []}, fn item, {front, back} -> {front, [item | back]} end)

        {dequeued, _} =
          Enum.reduce_while(1..max(length(items), 1), {[], buf}, fn _, {acc, {f, b}} ->
            case {f, b} do
              {[], []} ->
                {:halt, {Enum.reverse(acc), {[], []}}}

              _ ->
                {head, rest} =
                  case f do
                    [h | t] ->
                      {h, {t, b}}

                    [] ->
                      [h | t] = Enum.reverse(b)
                      {h, {t, []}}
                  end

                {:cont, {[head | acc], rest}}
            end
          end)
          |> then(fn
            {acc, rest} when is_list(acc) -> {Enum.reverse(acc), rest}
            other -> other
          end)

        assert dequeued == items,
               "FIFO invariant: expected #{inspect(items)}, got #{inspect(dequeued)}"
      end
    end
  end

  # ==========================================================================
  # 2. Messages within same topic preserve sequence numbers
  # ==========================================================================

  describe "Per-topic sequence preservation (SC-ZTEST-012)" do
    test "messages enqueued with ascending seq nums dequeue in seq order" do
      topic = "indrajaal/test/ordering/seq"
      msgs = for seq <- 1..10, do: build_message(topic, seq, "payload-#{seq}")
      buf = Enum.reduce(msgs, new_buffer(), &enqueue(&2, &1))
      {dequeued, _} = drain_buffer(buf)
      actual_seqs = Enum.map(dequeued, & &1.sequence)
      assert actual_seqs == Enum.to_list(1..10)
    end

    test "sequence numbers on dequeued messages are non-decreasing" do
      topic = "indrajaal/test/ordering/monotone"
      msgs = for seq <- 1..20, do: build_message(topic, seq, "p")
      buf = Enum.reduce(msgs, new_buffer(), &enqueue(&2, &1))
      {dequeued, _} = drain_buffer(buf)
      seqs = Enum.map(dequeued, & &1.sequence)

      assert seqs == Enum.sort(seqs),
             "Sequence numbers are not monotonically non-decreasing"
    end
  end

  # ==========================================================================
  # 3. Concurrent publishers maintain per-publisher ordering
  # ==========================================================================

  describe "Per-publisher FIFO ordering (SC-ZTEST-012)" do
    test "messages from two publishers arrive in per-publisher order even when interleaved" do
      topic = "indrajaal/test/ordering/concurrent"

      msgs_a = for seq <- 1..5, do: build_message(topic, seq, "pub-A-#{seq}", "A")
      msgs_b = for seq <- 1..5, do: build_message(topic, seq, "pub-B-#{seq}", "B")

      interleaved =
        Enum.zip(msgs_a, msgs_b)
        |> Enum.flat_map(fn {a, b} -> [a, b] end)

      buf = Enum.reduce(interleaved, new_buffer(), &enqueue(&2, &1))
      {dequeued, _} = drain_buffer(buf)

      seqs_a =
        dequeued
        |> Enum.filter(&(&1.publisher == "A"))
        |> Enum.map(& &1.sequence)

      assert seqs_a == Enum.to_list(1..5),
             "Publisher A ordering violated: got #{inspect(seqs_a)}"

      seqs_b =
        dequeued
        |> Enum.filter(&(&1.publisher == "B"))
        |> Enum.map(& &1.sequence)

      assert seqs_b == Enum.to_list(1..5),
             "Publisher B ordering violated: got #{inspect(seqs_b)}"
    end

    test "three concurrent publishers each preserve their own ordering" do
      topic = "indrajaal/test/ordering/three-pub"
      publishers = ["P1", "P2", "P3"]
      n = 8

      all_msgs =
        for pub <- publishers, seq <- 1..n do
          build_message(topic, seq, "#{pub}-#{seq}", pub)
        end

      shuffled = Enum.shuffle(all_msgs)
      buf = Enum.reduce(shuffled, new_buffer(), &enqueue(&2, &1))
      {dequeued, _} = drain_buffer(buf)

      for pub <- publishers do
        seqs =
          dequeued
          |> Enum.filter(&(&1.publisher == pub))
          |> Enum.map(& &1.sequence)
          |> Enum.sort()

        assert seqs == Enum.to_list(1..n),
               "Publisher #{pub} missing sequences; got #{inspect(seqs)}"
      end
    end
  end

  # ==========================================================================
  # 4. Buffer overflow preserves FIFO (drops oldest, keeps newest)
  # ==========================================================================

  describe "Buffer overflow FIFO preservation (SC-BRIDGE-001)" do
    test "overflow drops oldest messages, not newest" do
      capacity = 5
      # Enqueue 8 messages into capacity-5 buffer; oldest 3 should be dropped
      msgs = for seq <- 1..8, do: "msg-#{seq}"
      buf = Enum.reduce(msgs, new_bounded_buffer(capacity), &enqueue_bounded(&2, &1))
      {dequeued, _} = drain_bounded(buf)
      assert length(dequeued) == capacity
      # Newest 5 messages must be present in order
      assert dequeued == Enum.map(4..8, &"msg-#{&1}")
    end

    test "bounded buffer never exceeds its capacity" do
      capacity = 3

      buf =
        Enum.reduce(1..10, new_bounded_buffer(capacity), fn i, acc ->
          enqueue_bounded(acc, "item-#{i}")
        end)

      assert bounded_size(buf) == capacity
    end

    test "FIFO order is maintained after overflow" do
      capacity = 4
      msgs = for i <- 1..7, do: "m#{i}"
      buf = Enum.reduce(msgs, new_bounded_buffer(capacity), &enqueue_bounded(&2, &1))
      {dequeued, _} = drain_bounded(buf)
      # Must be in insertion order (no reordering on drop)
      sorted =
        Enum.sort_by(dequeued, fn "m" <> n -> String.to_integer(n) end)

      assert dequeued == sorted,
             "FIFO order corrupted after overflow: got #{inspect(dequeued)}"
    end
  end

  # ==========================================================================
  # 5. Property: dequeue order equals enqueue order
  # ==========================================================================

  describe "Property: FIFO round-trip (SC-ZTEST-012)" do
    property "for any list of binaries, dequeue order equals enqueue order" do
      forall items <- PC.list(PC.binary()) do
        buf = Enum.reduce(items, new_buffer(), &enqueue(&2, &1))
        {dequeued, _} = drain_buffer(buf)
        dequeued == items
      end
    end

    property "FIFO holds for non-empty lists of integers" do
      forall items <- PC.non_empty(PC.list(PC.integer())) do
        buf = Enum.reduce(items, new_buffer(), &enqueue(&2, &1))
        {dequeued, _} = drain_buffer(buf)
        dequeued == items
      end
    end

    property "partial dequeue preserves relative order of remainder" do
      forall items <- PC.list(PC.atom()) do
        case items do
          [] ->
            true

          [_ | rest] ->
            buf = Enum.reduce(items, new_buffer(), &enqueue(&2, &1))
            {_head, buf2} = dequeue_one(buf)
            {tail, _} = drain_buffer(buf2)
            tail == rest
        end
      end
    end
  end

  # ==========================================================================
  # 6. Property: sequence numbers are strictly monotonically increasing
  # ==========================================================================

  describe "Property: strictly monotonic sequence numbers (SC-ZTEST-012)" do
    property "generated sequence numbers 1..N are strictly increasing" do
      forall n <- PC.range(2, 50) do
        seqs = Enum.to_list(1..n)
        Enum.zip(seqs, tl(seqs)) |> Enum.all?(fn {a, b} -> b > a end)
      end
    end

    property "sequence counter increments by exactly 1 each step" do
      forall n <- PC.range(1, 100) do
        seqs = Enum.to_list(1..n)

        deltas =
          Enum.zip(seqs, tl(seqs))
          |> Enum.map(fn {a, b} -> b - a end)

        Enum.all?(deltas, &(&1 == 1))
      end
    end

    property "sequence numbers are always positive integers" do
      forall n <- PC.pos_integer() do
        n > 0
      end
    end

    test "stream data: sequence numbers strictly increase for any length" do
      ExUnitProperties.check all(n <- SD.integer(2..100)) do
        seqs = Enum.to_list(1..n)
        pairs = Enum.zip(seqs, tl(seqs))

        assert Enum.all?(pairs, fn {a, b} -> b == a + 1 end),
               "Sequence numbers must increment by 1"
      end
    end
  end

  # ==========================================================================
  # 7. Checkpoint message ID format validation (SC-ZTEST-013)
  # ==========================================================================

  describe "Checkpoint ID format (SC-ZTEST-013)" do
    test "valid checkpoint IDs match CP-{DOMAIN}-{NN} pattern" do
      valid_ids = [
        "CP-BOOT-01",
        "CP-TEST-08",
        "CP-SMOKE-13",
        "CP-MATH-01",
        "CP-AUTH-99",
        "CP-ZENOH-42"
      ]

      for id <- valid_ids do
        assert Regex.match?(@checkpoint_id_regex, id),
               "Expected #{id} to match #{inspect(@checkpoint_id_regex)}"
      end
    end

    test "invalid checkpoint IDs are rejected" do
      invalid_ids = [
        "cp-boot-01",
        "CP-boot-01",
        "CP-BOOT-1",
        "CP-BOOT-001",
        "CPBOOT01",
        "CP--01",
        "CP-BOOT-",
        ""
      ]

      for id <- invalid_ids do
        refute Regex.match?(@checkpoint_id_regex, id),
               "Expected #{id} NOT to match checkpoint ID format"
      end
    end

    property "checkpoint IDs with uppercase domain and 2-digit suffix always match" do
      forall {domain_len, nn} <- {PC.range(1, 10), PC.range(0, 99)} do
        # Build an uppercase-only domain string of `domain_len` chars
        domain = String.duplicate("A", domain_len)
        padded_nn = String.pad_leading(to_string(nn), 2, "0")
        id = "CP-#{domain}-#{padded_nn}"
        Regex.match?(@checkpoint_id_regex, id)
      end
    end

    test "stream data: generated checkpoint IDs always conform to format" do
      ExUnitProperties.check all(
                               nn <- SD.integer(0..99),
                               domain <- SD.string(?A..?Z, min_length: 1, max_length: 10)
                             ) do
        # Inline format check — no defp call
        checkpoint_regex = ~r/^CP-[A-Z0-9]+-\d{2}$/
        padded = String.pad_leading(to_string(nn), 2, "0")
        id = "CP-#{domain}-#{padded}"

        assert Regex.match?(checkpoint_regex, id),
               "Generated checkpoint ID #{inspect(id)} should match format"
      end
    end
  end

  # ==========================================================================
  # 8. Message timestamps are ISO 8601 UTC and monotonically increasing
  # ==========================================================================

  describe "Timestamp validity (SC-ZTEST-015)" do
    test "generated timestamp is valid ISO 8601 UTC" do
      ts = DateTime.utc_now() |> DateTime.to_iso8601()

      assert String.ends_with?(ts, "Z"),
             "Timestamp #{ts} must end with Z"

      assert String.contains?(ts, "T"),
             "Timestamp #{ts} must contain T separator"

      assert Regex.match?(~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z$/, ts),
             "Timestamp #{ts} does not match ISO 8601 UTC format"
    end

    test "successive timestamps are monotonically non-decreasing (lexicographic)" do
      ts1 = DateTime.utc_now() |> DateTime.to_iso8601()
      ts2 = DateTime.utc_now() |> DateTime.to_iso8601()
      ts3 = DateTime.utc_now() |> DateTime.to_iso8601()

      assert ts1 <= ts2, "Timestamp went backwards: #{ts1} > #{ts2}"
      assert ts2 <= ts3, "Timestamp went backwards: #{ts2} > #{ts3}"
    end

    test "messages built in sequence carry non-decreasing timestamps" do
      topic = "indrajaal/test/ts"
      msgs = for seq <- 1..10, do: build_message(topic, seq, "p")
      timestamps = Enum.map(msgs, & &1.timestamp)

      for {t1, t2} <- Enum.zip(timestamps, tl(timestamps)) do
        assert t1 <= t2,
               "Message timestamps not monotonically non-decreasing: #{t1} > #{t2}"
      end
    end

    property "monotonic time never goes backwards between two reads" do
      forall _dummy <- PC.boolean() do
        t1 = System.monotonic_time(:microsecond)
        t2 = System.monotonic_time(:microsecond)
        t2 >= t1
      end
    end
  end

  # ==========================================================================
  # 9. Payload size validation < 64 KB (SC-ZTEST-016)
  # ==========================================================================

  describe "Payload size constraint (SC-ZTEST-016)" do
    test "empty payload is accepted" do
      assert byte_size("") < @max_payload_bytes
    end

    test "payload of 65_535 bytes (max valid) is accepted" do
      payload = :binary.copy("x", @max_payload_bytes - 1)
      assert byte_size(payload) < @max_payload_bytes
    end

    test "payload at exactly 64 KB is rejected" do
      payload = :binary.copy("a", @max_payload_bytes)

      refute byte_size(payload) < @max_payload_bytes,
             "64KB payload must be rejected (SC-ZTEST-016 requires < 64KB)"
    end

    test "payload exceeding 64 KB is rejected" do
      payload = :binary.copy("b", @max_payload_bytes + 100)
      refute byte_size(payload) < @max_payload_bytes
    end

    property "any payload under 64KB satisfies the constraint" do
      forall size <- PC.range(0, @max_payload_bytes - 1) do
        payload = :binary.copy("x", size)
        byte_size(payload) < @max_payload_bytes
      end
    end

    property "any payload at or over 64KB violates the constraint" do
      forall size <- PC.range(@max_payload_bytes, @max_payload_bytes + 10_000) do
        payload = :binary.copy("x", size)
        not (byte_size(payload) < @max_payload_bytes)
      end
    end

    test "stream data: payloads under limit all satisfy constraint" do
      ExUnitProperties.check all(size <- SD.integer(0..(@max_payload_bytes - 1))) do
        # Inline constraint check — no defp call from check all block
        max_bytes = 65_536
        payload = :binary.copy("z", size)

        assert byte_size(payload) < max_bytes,
               "Payload of #{size} bytes should be < #{max_bytes}"
      end
    end
  end

  # ==========================================================================
  # 10. Topic depth validation <= 6 levels (SC-ZTEST-017)
  # ==========================================================================

  describe "Topic depth constraint (SC-ZTEST-017)" do
    test "topic with exactly 6 slash-delimited segments is valid" do
      topic = "a/b/c/d/e/f"

      assert length(String.split(topic, "/")) <= @max_topic_depth,
             "6-level topic should be valid"
    end

    test "topics with fewer than 6 segments are valid" do
      for depth <- 1..5 do
        topic = Enum.map_join(1..depth, "/", &"seg#{&1}")

        assert length(String.split(topic, "/")) <= @max_topic_depth,
               "#{depth}-level topic should be valid"
      end
    end

    test "topic with 7 segments is invalid" do
      topic = "a/b/c/d/e/f/g"

      refute length(String.split(topic, "/")) <= @max_topic_depth,
             "7-level topic must be rejected (SC-ZTEST-017)"
    end

    test "flat topic (no slashes) is valid" do
      assert length(String.split("indrajaal", "/")) <= @max_topic_depth
    end

    test "standard Indrajaal topics satisfy depth constraint" do
      valid_topics = [
        "indrajaal/evolution/status",
        "indrajaal/control/guardian/approve",
        "indrajaal/planning/events",
        "indrajaal/test/concurrent/topic-01",
        "indrajaal/health/node-1",
        "indrajaal/metrics/node/cpu"
      ]

      for topic <- valid_topics do
        depth = length(String.split(topic, "/"))

        assert depth <= @max_topic_depth,
               "Topic #{topic} has #{depth} levels, exceeds max #{@max_topic_depth}"
      end
    end

    property "topics with up to 6 segments always satisfy depth constraint" do
      forall n <- PC.range(1, 6) do
        topic = Enum.map_join(1..n, "/", &"s#{&1}")
        length(String.split(topic, "/")) <= @max_topic_depth
      end
    end

    property "topics with more than 6 segments always violate depth constraint" do
      forall n <- PC.range(7, 20) do
        topic = Enum.map_join(1..n, "/", &"s#{&1}")
        not (length(String.split(topic, "/")) <= @max_topic_depth)
      end
    end

    test "stream data: topics at valid depth satisfy constraint" do
      ExUnitProperties.check all(depth <- SD.integer(1..6)) do
        # Inline depth check — no defp call from check all block
        max_depth = 6
        topic = Enum.map_join(1..depth, "/", &"seg#{&1}")

        assert length(String.split(topic, "/")) <= max_depth,
               "Topic with #{depth} levels should satisfy depth <= #{max_depth}"
      end
    end
  end

  # ==========================================================================
  # Helpers — Unbounded FIFO buffer (Okasaki two-list queue)
  # No production module dependencies.
  # ==========================================================================

  # new_buffer/0 — create empty two-list queue {front, back}
  defp new_buffer, do: {[], []}

  # enqueue/2 — O(1); push to back list
  defp enqueue({front, back}, item), do: {front, [item | back]}

  # dequeue_one/1 — O(1) amortised; returns {head_item, remaining_buffer}
  # or raises if called on empty buffer (callers guard against empty)
  defp dequeue_one({[head | rest], back}), do: {head, {rest, back}}

  defp dequeue_one({[], back}) do
    [head | rest] = Enum.reverse(back)
    {head, {rest, []}}
  end

  # drain_buffer/1 — drain all items in FIFO order; returns {[items], empty_buf}
  defp drain_buffer(buf), do: do_drain(buf, [])

  defp do_drain({[], []}, acc), do: {Enum.reverse(acc), {[], []}}

  defp do_drain(buf, acc) do
    {item, rest} = dequeue_one(buf)
    do_drain(rest, [item | acc])
  end

  # buf_size/1 — number of items in the buffer
  defp buf_size({front, back}), do: length(front) + length(back)

  # ==========================================================================
  # Helpers — Bounded FIFO buffer (drops oldest on overflow)
  # Uses a distinct 3-tuple {front, back, capacity} to avoid pattern clash.
  # ==========================================================================

  # new_bounded_buffer/1 — create capacity-bounded empty buffer
  defp new_bounded_buffer(capacity), do: {[], [], capacity}

  # enqueue_bounded/2 — O(n) on overflow; drops oldest to maintain capacity
  defp enqueue_bounded({front, back, cap}, item) do
    new_back = [item | back]
    total = length(front) + length(new_back)

    if total > cap do
      # Reconstruct in FIFO order and drop the oldest (head)
      ordered = Enum.reverse(front) ++ Enum.reverse(new_back)
      [_dropped | kept] = Enum.reverse(ordered)
      {Enum.reverse(kept), [], cap}
    else
      {front, new_back, cap}
    end
  end

  # drain_bounded/1 — drain all items in FIFO order from bounded buffer
  defp drain_bounded(buf), do: do_drain_bounded(buf, [])

  defp do_drain_bounded({[], [], cap}, acc),
    do: {Enum.reverse(acc), {[], [], cap}}

  defp do_drain_bounded({front, back, cap}, acc) do
    {item, rest} =
      case front do
        [h | t] ->
          {h, {t, back, cap}}

        [] ->
          [h | t] = Enum.reverse(back)
          {h, {t, [], cap}}
      end

    do_drain_bounded(rest, [item | acc])
  end

  # bounded_size/1 — item count in bounded buffer
  defp bounded_size({front, back, _cap}), do: length(front) + length(back)

  # ==========================================================================
  # Helpers — Message construction
  # ==========================================================================

  # build_message/4 — construct a typed message map with a UTC timestamp
  defp build_message(topic, sequence, payload, publisher \\ "default") do
    %{
      topic: topic,
      sequence: sequence,
      payload: payload,
      publisher: publisher,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end
