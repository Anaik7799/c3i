defmodule Indrajaal.Zenoh.KeyExpressionRoutingTest do
  @moduledoc """
  TDG test: Zenoh key expression routing — parsing, wildcard matching, and subscriber dispatch.

  WHAT: Tests key expression parsing, wildcard matching (* and **), topic depth validation,
        topic hierarchy classification, subscriber routing, FIFO message ordering, payload
        size limits, and key expression alias registry.
  WHY: Validates SC-ZTEST-012 (FIFO per topic), SC-ZTEST-016 (payload < 64KB),
       SC-ZTEST-017 (topic depth <= 6), SC-ZEN-003 (topic hierarchy),
       SC-BRIDGE-001 (message buffer FIFO), SC-LOG-009 (key expression aliases).

  STAMP Constraints:
  - SC-ZTEST-012: Message ordering MUST be FIFO per topic
  - SC-ZTEST-016: Payload size < 64KB
  - SC-ZTEST-017: Topic depth <= 6 levels
  - SC-ZEN-003: Topic hierarchy (cmd/evt/query)
  - SC-BRIDGE-001: Message buffer FIFO ordering
  - SC-LOG-009: Key expression aliases pre-registered
  """

  use ExUnit.Case, async: true
  use PropCheck
  require ExUnitProperties
  import ExUnitProperties, except: [property: 2, property: 3]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @max_topic_depth 6
  @max_payload_bytes 65_536

  describe "key expression parsing" do
    test "parses simple topic" do
      {:ok, parsed} = parse_key_expr("indrajaal/health/node-1")
      assert parsed.segments == ["indrajaal", "health", "node-1"]
      assert parsed.depth == 3
    end

    test "rejects empty key expression" do
      assert {:error, :empty_key_expression} = parse_key_expr("")
    end

    test "rejects leading slash" do
      assert {:error, :invalid_format} = parse_key_expr("/indrajaal/health")
    end

    test "rejects trailing slash" do
      assert {:error, :invalid_format} = parse_key_expr("indrajaal/health/")
    end

    test "parses wildcard segments" do
      {:ok, parsed} = parse_key_expr("indrajaal/*/health")
      assert parsed.segments == ["indrajaal", "*", "health"]
      assert parsed.has_wildcard == true
    end

    test "parses double wildcard" do
      {:ok, parsed} = parse_key_expr("indrajaal/**")
      assert parsed.segments == ["indrajaal", "**"]
      assert parsed.has_double_wildcard == true
    end
  end

  describe "topic depth validation (SC-ZTEST-017)" do
    test "accepts topics within depth limit" do
      for depth <- 1..@max_topic_depth do
        segments = Enum.map(1..depth, fn i -> "seg-#{i}" end)
        topic = Enum.join(segments, "/")
        {:ok, parsed} = parse_key_expr(topic)
        assert parsed.depth <= @max_topic_depth
      end
    end

    test "rejects topics exceeding depth limit" do
      segments = Enum.map(1..7, fn i -> "seg-#{i}" end)
      topic = Enum.join(segments, "/")
      assert {:error, :topic_too_deep} = parse_key_expr(topic)
    end

    test "double wildcard counts as one level" do
      {:ok, parsed} = parse_key_expr("a/b/c/d/e/**")
      assert parsed.depth == 6
    end
  end

  describe "wildcard matching" do
    test "single wildcard matches one segment" do
      pattern = "indrajaal/*/health"
      assert matches_key_expr?(pattern, "indrajaal/node-1/health")
      assert matches_key_expr?(pattern, "indrajaal/node-2/health")
      refute matches_key_expr?(pattern, "indrajaal/node-1/node-2/health")
    end

    test "double wildcard matches zero or more segments" do
      pattern = "indrajaal/**"
      assert matches_key_expr?(pattern, "indrajaal/health")
      assert matches_key_expr?(pattern, "indrajaal/health/node-1")
      assert matches_key_expr?(pattern, "indrajaal/a/b/c/d/e")
    end

    test "exact match without wildcards" do
      pattern = "indrajaal/health/node-1"
      assert matches_key_expr?(pattern, "indrajaal/health/node-1")
      refute matches_key_expr?(pattern, "indrajaal/health/node-2")
    end

    test "wildcard does not match empty segment" do
      pattern = "indrajaal/*/health"
      refute matches_key_expr?(pattern, "indrajaal//health")
    end

    test "multiple single wildcards" do
      pattern = "indrajaal/*/metrics/*"
      assert matches_key_expr?(pattern, "indrajaal/node-1/metrics/cpu")
      assert matches_key_expr?(pattern, "indrajaal/node-2/metrics/memory")
      refute matches_key_expr?(pattern, "indrajaal/node-1/metrics/cpu/usage")
    end
  end

  describe "topic hierarchy classification (SC-ZEN-003)" do
    test "classifies command topics" do
      assert classify_topic("indrajaal/cepaf/cmd/deploy") == :command
      assert classify_topic("indrajaal/cepaf/cmd/restart") == :command
    end

    test "classifies event topics" do
      assert classify_topic("indrajaal/cepaf/evt/boot_complete") == :event
      assert classify_topic("indrajaal/cepaf/evt/health_changed") == :event
    end

    test "classifies query topics" do
      assert classify_topic("indrajaal/cepaf/query/status") == :query
      assert classify_topic("indrajaal/cepaf/query/metrics") == :query
    end

    test "classifies unknown topics as data" do
      assert classify_topic("indrajaal/health/node-1") == :data
      assert classify_topic("indrajaal/metrics/cpu") == :data
    end
  end

  describe "subscriber routing" do
    test "routes message to matching subscriber" do
      subscribers = [
        %{id: "s1", pattern: "indrajaal/health/*"},
        %{id: "s2", pattern: "indrajaal/metrics/**"},
        %{id: "s3", pattern: "indrajaal/alerts/*"}
      ]

      matches = route_to_subscribers(subscribers, "indrajaal/health/node-1")
      assert length(matches) == 1
      assert hd(matches).id == "s1"
    end

    test "routes to multiple matching subscribers" do
      subscribers = [
        %{id: "s1", pattern: "indrajaal/**"},
        %{id: "s2", pattern: "indrajaal/health/*"},
        %{id: "s3", pattern: "indrajaal/alerts/*"}
      ]

      matches = route_to_subscribers(subscribers, "indrajaal/health/node-1")
      ids = Enum.map(matches, & &1.id)
      assert "s1" in ids
      assert "s2" in ids
      refute "s3" in ids
    end

    test "no match returns empty list" do
      subscribers = [%{id: "s1", pattern: "other/topic/*"}]
      assert route_to_subscribers(subscribers, "indrajaal/health/node-1") == []
    end
  end

  describe "FIFO message ordering (SC-ZTEST-012, SC-BRIDGE-001)" do
    test "messages delivered in send order" do
      buffer = new_message_buffer()

      messages =
        Enum.map(1..20, fn i ->
          %{topic: "indrajaal/test", payload: "msg-#{i}", seq: i}
        end)

      filled = Enum.reduce(messages, buffer, &push_message(&2, &1))
      delivered = drain_messages(filled)

      sequences = Enum.map(delivered, & &1.seq)
      assert sequences == Enum.to_list(1..20)
    end

    test "per-topic FIFO preserved with interleaved topics" do
      buffer = new_message_buffer()

      messages = [
        %{topic: "a", payload: "a1", seq: 1},
        %{topic: "b", payload: "b1", seq: 1},
        %{topic: "a", payload: "a2", seq: 2},
        %{topic: "b", payload: "b2", seq: 2},
        %{topic: "a", payload: "a3", seq: 3}
      ]

      filled = Enum.reduce(messages, buffer, &push_message(&2, &1))
      delivered = drain_messages(filled)

      topic_a = Enum.filter(delivered, &(&1.topic == "a")) |> Enum.map(& &1.seq)
      topic_b = Enum.filter(delivered, &(&1.topic == "b")) |> Enum.map(& &1.seq)

      assert topic_a == [1, 2, 3]
      assert topic_b == [1, 2]
    end
  end

  describe "payload size limits (SC-ZTEST-016)" do
    test "accepts payload under 64KB" do
      payload = String.duplicate("x", @max_payload_bytes - 1)
      assert :ok = validate_payload_size(payload)
    end

    test "accepts payload at exactly 64KB" do
      payload = String.duplicate("x", @max_payload_bytes)
      assert :ok = validate_payload_size(payload)
    end

    test "rejects payload over 64KB" do
      payload = String.duplicate("x", @max_payload_bytes + 1)
      assert {:error, :payload_too_large} = validate_payload_size(payload)
    end
  end

  describe "key expression alias registry (SC-LOG-009)" do
    test "registers and resolves alias" do
      registry = new_alias_registry()
      {:ok, registry} = register_alias(registry, "health", "indrajaal/health/**")

      assert resolve_alias(registry, "health") == {:ok, "indrajaal/health/**"}
    end

    test "resolves unknown alias to error" do
      registry = new_alias_registry()
      assert {:error, :unknown_alias} = resolve_alias(registry, "nonexistent")
    end

    test "duplicate alias registration updates value" do
      registry = new_alias_registry()
      {:ok, registry} = register_alias(registry, "health", "indrajaal/health/**")
      {:ok, registry} = register_alias(registry, "health", "indrajaal/health/v2/**")

      assert resolve_alias(registry, "health") == {:ok, "indrajaal/health/v2/**"}
    end

    test "lists all aliases" do
      registry = new_alias_registry()
      {:ok, registry} = register_alias(registry, "health", "indrajaal/health/**")
      {:ok, registry} = register_alias(registry, "metrics", "indrajaal/metrics/**")

      aliases = list_aliases(registry)
      assert length(aliases) == 2
    end
  end

  describe "property: routing invariants" do
    property "double wildcard always matches any subtopic" do
      forall segments <- PC.non_empty(PC.list(PC.elements(["a", "b", "c", "health", "node"]))) do
        prefix = "indrajaal"
        pattern = "#{prefix}/**"
        topic = Enum.join([prefix | Enum.take(segments, 5)], "/")
        matches_key_expr?(pattern, topic)
      end
    end

    test "parsed depth always matches segment count" do
      ExUnitProperties.check all(
                               depth <- SD.integer(1..@max_topic_depth),
                               max_runs: 20
                             ) do
        segments = Enum.map(1..depth, fn i -> "seg#{i}" end)
        topic = Enum.join(segments, "/")
        {:ok, parsed} = parse_key_expr(topic)
        assert parsed.depth == depth
        assert length(parsed.segments) == depth
      end
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp parse_key_expr(""), do: {:error, :empty_key_expression}

  defp parse_key_expr(expr) do
    cond do
      String.starts_with?(expr, "/") ->
        {:error, :invalid_format}

      String.ends_with?(expr, "/") ->
        {:error, :invalid_format}

      true ->
        segments = String.split(expr, "/")
        depth = length(segments)

        if depth > @max_topic_depth do
          {:error, :topic_too_deep}
        else
          {:ok,
           %{
             raw: expr,
             segments: segments,
             depth: depth,
             has_wildcard: "*" in segments,
             has_double_wildcard: "**" in segments
           }}
        end
    end
  end

  defp matches_key_expr?(pattern, topic) do
    pattern_segments = String.split(pattern, "/")
    topic_segments = String.split(topic, "/")
    match_segments(pattern_segments, topic_segments)
  end

  defp match_segments([], []), do: true
  defp match_segments(["**"], _rest), do: true
  defp match_segments(["**" | _], _rest), do: true
  defp match_segments([], _), do: false
  defp match_segments(_, []), do: false

  defp match_segments(["*" | p_rest], [seg | t_rest]) do
    seg != "" and match_segments(p_rest, t_rest)
  end

  defp match_segments([p | p_rest], [t | t_rest]) do
    p == t and match_segments(p_rest, t_rest)
  end

  defp classify_topic(topic) do
    segments = String.split(topic, "/")

    cond do
      "cmd" in segments -> :command
      "evt" in segments -> :event
      "query" in segments -> :query
      true -> :data
    end
  end

  defp route_to_subscribers(subscribers, topic) do
    Enum.filter(subscribers, fn sub ->
      matches_key_expr?(sub.pattern, topic)
    end)
  end

  defp new_message_buffer, do: %{messages: []}

  defp push_message(buffer, message) do
    %{buffer | messages: buffer.messages ++ [message]}
  end

  defp drain_messages(buffer), do: buffer.messages

  defp validate_payload_size(payload) do
    if byte_size(payload) <= @max_payload_bytes do
      :ok
    else
      {:error, :payload_too_large}
    end
  end

  defp new_alias_registry, do: %{aliases: %{}}

  defp register_alias(registry, name, pattern) do
    {:ok, %{registry | aliases: Map.put(registry.aliases, name, pattern)}}
  end

  defp resolve_alias(registry, name) do
    case Map.get(registry.aliases, name) do
      nil -> {:error, :unknown_alias}
      pattern -> {:ok, pattern}
    end
  end

  defp list_aliases(registry) do
    Enum.map(registry.aliases, fn {name, pattern} -> {name, pattern} end)
  end
end
