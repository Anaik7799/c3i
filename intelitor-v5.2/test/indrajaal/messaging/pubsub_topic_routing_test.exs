defmodule Indrajaal.Messaging.PubSubTopicRoutingTest do
  @moduledoc """
  TDG-compliant test suite for PubSub topic routing with wildcard subscription.

  WHAT: Tests exact match, single-level wildcard (*), multi-level wildcard (**),
        topic hierarchy routing, multi-subscriber fan-out, and message ordering.
  WHY: SC-PUBSUB-001..004 mandate reliable topic-based publish/subscribe semantics.
       Zenoh-style topic routing is used throughout the Indrajaal mesh.
  CONSTRAINTS: SC-PUBSUB-001, SC-PUBSUB-002, SC-PUBSUB-003, SC-PUBSUB-004, EP-GEN-014

  ## Coverage Matrix
  | Concern                         | PropCheck | StreamData | Unit |
  |---------------------------------|-----------|------------|------|
  | Exact topic match               | 0         | 1          | 2    |
  | Single-level wildcard (*)       | 1         | 1          | 2    |
  | Multi-level wildcard (**)       | 1         | 1          | 2    |
  | No-match rejection              | 0         | 1          | 1    |
  | Multiple subscriber fan-out     | 0         | 0          | 2    |
  | Message ordering (FIFO)         | 1         | 1          | 2    |
  | Topic hierarchy segment count   | 1         | 0          | 0    |
  | TOTAL                           | 4         | 5          | 11   |

  ## EP-GEN-014 compliance
  - `use PropCheck` + `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
  - PC. prefix for PropCheck generators (forall blocks)
  - SD. prefix for StreamData generators (check all blocks)
  - All helpers are self-contained in this module (no external production deps)
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :property
  @moduletag :pubsub
  @moduletag :topic_routing

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ==========================================================================
  # Self-contained PubSub router simulation
  # Implements Zenoh-style topic routing: exact, *, ** wildcards
  # SC-PUBSUB-001: exact match; SC-PUBSUB-002: wildcard patterns
  # ==========================================================================

  defmodule Router do
    @moduledoc """
    Self-contained in-memory PubSub router for test validation.

    Topics are slash-separated paths, e.g. "indrajaal/health/node-1".
    Subscription patterns support:
      - Exact: "indrajaal/health/node-1"
      - Single-level wildcard: "indrajaal/health/*" (matches one segment)
      - Multi-level wildcard: "indrajaal/**" (matches zero or more trailing segments)
    """

    defstruct subscriptions: %{}

    @type t :: %__MODULE__{}

    @spec new() :: t()
    def new(), do: %__MODULE__{}

    @spec subscribe(t(), binary(), pid()) :: t()
    def subscribe(%__MODULE__{} = router, pattern, subscriber_pid) do
      subs = Map.update(router.subscriptions, pattern, [subscriber_pid], &[subscriber_pid | &1])
      %{router | subscriptions: subs}
    end

    @spec publish(t(), binary(), any()) :: {t(), list({binary(), any()})}
    def publish(%__MODULE__{} = router, topic, message) do
      deliveries =
        router.subscriptions
        |> Enum.filter(fn {pattern, _} -> matches?(topic, pattern) end)
        |> Enum.flat_map(fn {pattern, pids} -> Enum.map(pids, &{pattern, &1, message}) end)

      {router, deliveries}
    end

    @spec matches?(binary(), binary()) :: boolean()
    def matches?(topic, pattern) do
      topic_parts = String.split(topic, "/")
      pattern_parts = String.split(pattern, "/")
      match_parts(topic_parts, pattern_parts)
    end

    defp match_parts([], []), do: true
    defp match_parts(_remaining, ["**"]), do: true
    defp match_parts([], ["**"]), do: true
    defp match_parts([], _), do: false
    defp match_parts(_, []), do: false

    defp match_parts([_t | t_rest], ["*" | p_rest]) do
      match_parts(t_rest, p_rest)
    end

    defp match_parts([t | t_rest], [p | p_rest]) when t == p do
      match_parts(t_rest, p_rest)
    end

    defp match_parts(_, _), do: false

    @spec matching_patterns(t(), binary()) :: list(binary())
    def matching_patterns(%__MODULE__{} = router, topic) do
      router.subscriptions
      |> Map.keys()
      |> Enum.filter(&matches?(topic, &1))
    end
  end

  # ==========================================================================
  # SECTION 1: Exact Topic Matching — SC-PUBSUB-001
  # ==========================================================================

  describe "exact topic matching — SC-PUBSUB-001" do
    test "PS_UNIT_01: exact topic matches itself" do
      topic = "indrajaal/health/node-1"
      assert Router.matches?(topic, topic)
    end

    test "PS_UNIT_02: exact topic does not match different topic" do
      refute Router.matches?("indrajaal/health/node-1", "indrajaal/health/node-2")
      refute Router.matches?("indrajaal/metrics", "indrajaal/health")
    end

    test "PS_STREAM_01: any topic matches itself exactly" do
      ExUnitProperties.check all(
                               segments <-
                                 SD.list_of(SD.string(:alphanumeric, min_length: 1),
                                   min_length: 1,
                                   max_length: 5
                                 )
                             ) do
        topic = Enum.join(segments, "/")
        assert Router.matches?(topic, topic)
      end
    end
  end

  # ==========================================================================
  # SECTION 2: Single-Level Wildcard (*) — SC-PUBSUB-002
  # ==========================================================================

  describe "single-level wildcard (*) — SC-PUBSUB-002" do
    test "PS_UNIT_03: * matches exactly one segment at its position" do
      assert Router.matches?("indrajaal/health/node-1", "indrajaal/health/*")
      assert Router.matches?("indrajaal/health/node-abc", "indrajaal/health/*")
    end

    test "PS_UNIT_04: * does not match across segment boundaries" do
      refute Router.matches?("indrajaal/health/node-1/sub", "indrajaal/health/*")
      refute Router.matches?("indrajaal/health", "indrajaal/health/*")
    end

    property "PS_PROP_01: * matches any single segment at correct depth" do
      forall segments <- PC.list(PC.utf8()) do
        # Strip "/" from segments to keep them as single path components
        cleaned =
          segments
          |> Enum.map(fn s -> String.replace(s, "/", "x") end)
          |> Enum.reject(&(&1 == ""))

        non_empty =
          case cleaned do
            [] -> ["root", "leaf"]
            [_single] -> ["root", "leaf"]
            many -> Enum.take(many, 4)
          end

        topic = Enum.join(non_empty, "/")
        wildcard_at_last = Enum.join(Enum.drop(non_empty, -1) ++ ["*"], "/")

        Router.matches?(topic, wildcard_at_last)
      end
    end

    test "PS_STREAM_02: wildcard at position n matches any value at position n only" do
      ExUnitProperties.check all(
                               prefix_segs <-
                                 SD.list_of(SD.string(:alphanumeric, min_length: 1),
                                   min_length: 1,
                                   max_length: 2
                                 ),
                               target_seg <- SD.string(:alphanumeric, min_length: 1)
                             ) do
        pattern = Enum.join(prefix_segs ++ ["*"], "/")
        matching_topic = Enum.join(prefix_segs ++ [target_seg], "/")
        too_deep_topic = Enum.join(prefix_segs ++ [target_seg, "extra"], "/")

        assert Router.matches?(matching_topic, pattern)
        refute Router.matches?(too_deep_topic, pattern)
      end
    end
  end

  # ==========================================================================
  # SECTION 3: Multi-Level Wildcard (**) — SC-PUBSUB-002
  # ==========================================================================

  describe "multi-level wildcard (**) — SC-PUBSUB-002" do
    test "PS_UNIT_05: ** matches zero or more trailing segments" do
      assert Router.matches?("indrajaal/metrics", "indrajaal/**")
      assert Router.matches?("indrajaal/metrics/node-1", "indrajaal/**")
      assert Router.matches?("indrajaal/metrics/node-1/cpu", "indrajaal/**")
    end

    test "PS_UNIT_06: ** at root matches any topic" do
      assert Router.matches?("indrajaal/health/node-1", "**")
      assert Router.matches?("a/b/c/d/e", "**")
    end

    property "PS_PROP_02: ** suffix matches any sub-path of the prefix" do
      forall prefix_parts <- PC.list(PC.utf8()) do
        non_empty =
          case Enum.map(prefix_parts, fn s ->
                 if s == "", do: "seg", else: String.replace(s, "/", "x")
               end) do
            [] -> ["indrajaal"]
            many -> Enum.take(many, 3)
          end

        suffix = ["extra", "segment"]
        pattern = Enum.join(non_empty ++ ["**"], "/")
        topic = Enum.join(non_empty ++ suffix, "/")

        Router.matches?(topic, pattern)
      end
    end

    test "PS_STREAM_03: ** does not match topics with wrong prefix" do
      ExUnitProperties.check all(
                               prefix_a <- SD.string(:alphanumeric, min_length: 1),
                               prefix_b <- SD.string(:alphanumeric, min_length: 1),
                               suffix <- SD.string(:alphanumeric, min_length: 1),
                               _guard <-
                                 SD.filter(SD.constant(:ok), fn _ -> prefix_a != prefix_b end)
                             ) do
        pattern = "#{prefix_a}/**"
        non_matching_topic = "#{prefix_b}/#{suffix}"
        assert refute_or_skip(non_matching_topic, pattern, prefix_a, prefix_b)
      end
    end

    defp refute_or_skip(topic, pattern, prefix_a, prefix_b) do
      # Only assert mismatch when prefixes genuinely differ at segment level
      if prefix_a != prefix_b do
        not Router.matches?(topic, pattern)
      else
        true
      end
    end
  end

  # ==========================================================================
  # SECTION 4: No-Match Rejection — SC-PUBSUB-003
  # ==========================================================================

  describe "no-match rejection — SC-PUBSUB-003" do
    test "PS_UNIT_07: published message delivers nothing when no subscribers match" do
      router = Router.new()
      router = Router.subscribe(router, "indrajaal/metrics/**", self())

      {_router, deliveries} = Router.publish(router, "indrajaal/health/node-1", :ping)

      assert deliveries == []
    end

    test "PS_STREAM_04: non-matching patterns never receive published messages" do
      ExUnitProperties.check all(
                               pub_topic <- SD.string(:alphanumeric, min_length: 1),
                               sub_topic <- SD.string(:alphanumeric, min_length: 1),
                               _guard <-
                                 SD.filter(SD.constant(:ok), fn _ -> pub_topic != sub_topic end)
                             ) do
        router = Router.new()
        router = Router.subscribe(router, sub_topic, self())
        {_router, deliveries} = Router.publish(router, pub_topic, :msg)
        assert deliveries == []
      end
    end
  end

  # ==========================================================================
  # SECTION 5: Multiple Subscriber Fan-Out — SC-PUBSUB-004
  # ==========================================================================

  describe "multiple subscriber fan-out — SC-PUBSUB-004" do
    test "PS_UNIT_08: all matching subscribers receive the message" do
      router = Router.new()
      router = Router.subscribe(router, "indrajaal/health/*", self())
      router = Router.subscribe(router, "indrajaal/**", self())
      router = Router.subscribe(router, "indrajaal/health/node-1", self())

      {_router, deliveries} =
        Router.publish(router, "indrajaal/health/node-1", :heartbeat)

      assert length(deliveries) == 3
    end

    test "PS_UNIT_09: non-matching subscriber does not receive message" do
      router = Router.new()
      router = Router.subscribe(router, "indrajaal/metrics/**", self())
      router = Router.subscribe(router, "indrajaal/health/**", self())

      {_router, deliveries} = Router.publish(router, "indrajaal/health/node-1", :msg)

      assert length(deliveries) == 1
      [{pattern, _pid, msg}] = deliveries
      assert pattern == "indrajaal/health/**"
      assert msg == :msg
    end
  end

  # ==========================================================================
  # SECTION 6: Message Ordering — SC-PUBSUB-004 (FIFO per topic)
  # ==========================================================================

  describe "message ordering FIFO — SC-PUBSUB-004" do
    test "PS_UNIT_10: sequential publishes to same topic preserve order" do
      router = Router.new()
      router = Router.subscribe(router, "indrajaal/events/**", self())

      messages = [:first, :second, :third, :fourth]

      {_router, all_deliveries} =
        Enum.reduce(messages, {router, []}, fn msg, {r, acc} ->
          {r2, deliveries} = Router.publish(r, "indrajaal/events/stream", msg)
          {r2, acc ++ deliveries}
        end)

      received_payloads = Enum.map(all_deliveries, fn {_, _, payload} -> payload end)
      assert received_payloads == messages
    end

    test "PS_UNIT_11: FIFO ordering holds for rapid sequential publishes" do
      router = Router.new()
      router = Router.subscribe(router, "indrajaal/**", self())

      n = 20
      messages = Enum.to_list(1..n)

      {_router, all_deliveries} =
        Enum.reduce(messages, {router, []}, fn i, {r, acc} ->
          {r2, deliveries} = Router.publish(r, "indrajaal/count", i)
          {r2, acc ++ deliveries}
        end)

      received = Enum.map(all_deliveries, fn {_, _, payload} -> payload end)
      assert received == messages
    end

    property "PS_PROP_03: published messages always appear in publication order" do
      forall msgs <- PC.list(PC.integer()) do
        msgs_bounded = Enum.take(msgs, 10)
        router = Router.new()
        router = Router.subscribe(router, "test/**", self())

        {_r, deliveries} =
          Enum.reduce(msgs_bounded, {router, []}, fn msg, {r, acc} ->
            {r2, d} = Router.publish(r, "test/topic", msg)
            {r2, acc ++ d}
          end)

        received = Enum.map(deliveries, fn {_, _, payload} -> payload end)
        received == msgs_bounded
      end
    end

    test "PS_STREAM_05: messages from multiple topics are individually ordered" do
      ExUnitProperties.check all(count <- SD.integer(2..8)) do
        router = Router.new()
        router = Router.subscribe(router, "a/**", self())
        router = Router.subscribe(router, "b/**", self())

        a_msgs = Enum.to_list(1..count)
        b_msgs = Enum.map(1..count, &(&1 * 100))

        {_r, a_deliveries} =
          Enum.reduce(a_msgs, {router, []}, fn m, {r, acc} ->
            {r2, d} = Router.publish(r, "a/topic", m)
            {r2, acc ++ d}
          end)

        {_r, b_deliveries} =
          Enum.reduce(b_msgs, {router, []}, fn m, {r, acc} ->
            {r2, d} = Router.publish(r, "b/topic", m)
            {r2, acc ++ d}
          end)

        a_received = Enum.map(a_deliveries, fn {_, _, p} -> p end)
        b_received = Enum.map(b_deliveries, fn {_, _, p} -> p end)

        assert a_received == a_msgs
        assert b_received == b_msgs
      end
    end
  end

  # ==========================================================================
  # SECTION 7: Topic Hierarchy Segment Counting — SC-PUBSUB-001
  # ==========================================================================

  describe "topic hierarchy segment validation — SC-PUBSUB-001" do
    property "PS_PROP_04: topic segment count matches slash-split length" do
      forall parts <- PC.list(PC.utf8()) do
        # Strip "/" so each element stays as a single path segment
        bounded =
          parts
          |> Enum.take(6)
          |> Enum.map(fn s -> String.replace(s, "/", "x") end)
          |> Enum.reject(&(&1 == ""))

        case bounded do
          [] ->
            true

          segs ->
            topic = Enum.join(segs, "/")
            String.split(topic, "/") |> length() == length(segs)
        end
      end
    end
  end
end
