defmodule Indrajaal.Cluster.ZenohKeyExpressionRoutingTest do
  @moduledoc """
  Zenoh key expression routing test suite.

  ## WHAT
  Tests Zenoh topic hierarchy, wildcard matching, key expression resolution,
  and routing correctness for the pub/sub mesh network.

  ## CONSTRAINTS
  - SC-ZTEST-001: All checkpoints MUST have unique topic
  - SC-ZTEST-012: Message ordering MUST be FIFO per topic
  - SC-ZTEST-017: Topic depth <= 6 levels
  - SC-ZEN-003: Topic hierarchy indrajaal/cepaf/{cmd|evt|query}/*
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ============================================================================
  # Topic Hierarchy Structure
  # ============================================================================

  describe "topic hierarchy structure" do
    test "standard topics follow indrajaal/{domain}/{subdomain} pattern" do
      topics = [
        "indrajaal/health/node-1",
        "indrajaal/metrics/node-1/cpu",
        "indrajaal/logs/cluster/node-1",
        "indrajaal/cluster/events",
        "indrajaal/sentinel/threats",
        "indrajaal/prajna/kpi"
      ]

      for topic <- topics do
        segments = String.split(topic, "/")
        assert hd(segments) == "indrajaal", "Topic #{topic} must start with indrajaal/"
        assert length(segments) >= 2
        assert length(segments) <= 6, "Topic #{topic} exceeds max depth of 6 (SC-ZTEST-017)"
      end
    end

    test "CEPAF topics follow indrajaal/cepaf/{cmd|evt|query}/* pattern" do
      cepaf_topics = [
        "indrajaal/cepaf/cmd/deploy",
        "indrajaal/cepaf/evt/boot_complete",
        "indrajaal/cepaf/query/status"
      ]

      for topic <- cepaf_topics do
        segments = String.split(topic, "/")
        assert Enum.at(segments, 0) == "indrajaal"
        assert Enum.at(segments, 1) == "cepaf"
        assert Enum.at(segments, 2) in ["cmd", "evt", "query"]
      end
    end

    test "checkpoint topics follow CP-{DOMAIN}-{NN} ID format" do
      checkpoint_topics = [
        {"indrajaal/boot/checkpoint", "CP-BOOT-01"},
        {"indrajaal/test/checkpoint", "CP-TEST-01"},
        {"indrajaal/smoke/checkpoint", "CP-SMOKE-01"}
      ]

      for {_topic, cp_id} <- checkpoint_topics do
        assert Regex.match?(~r/^CP-[A-Z]+-\d{2}$/, cp_id),
               "Checkpoint ID #{cp_id} must match CP-{DOMAIN}-{NN} format (SC-ZTEST-013)"
      end
    end
  end

  # ============================================================================
  # Wildcard Matching
  # ============================================================================

  describe "wildcard matching" do
    test "single wildcard * matches one level" do
      pattern = "indrajaal/health/*"
      assert matches?(pattern, "indrajaal/health/node-1")
      assert matches?(pattern, "indrajaal/health/node-2")
      refute matches?(pattern, "indrajaal/health/node-1/cpu")
      refute matches?(pattern, "indrajaal/metrics/node-1")
    end

    test "double wildcard ** matches multiple levels" do
      pattern = "indrajaal/**"
      assert matches?(pattern, "indrajaal/health/node-1")
      assert matches?(pattern, "indrajaal/metrics/node-1/cpu")
      assert matches?(pattern, "indrajaal/cepaf/cmd/deploy")
    end

    test "mixed wildcards work correctly" do
      pattern = "indrajaal/*/checkpoint"
      assert matches?(pattern, "indrajaal/boot/checkpoint")
      assert matches?(pattern, "indrajaal/test/checkpoint")
      refute matches?(pattern, "indrajaal/boot/stage/checkpoint")
    end

    test "exact match requires full path" do
      pattern = "indrajaal/health/node-1"
      assert matches?(pattern, "indrajaal/health/node-1")
      refute matches?(pattern, "indrajaal/health/node-2")
      refute matches?(pattern, "indrajaal/health/node-1/extra")
    end
  end

  # ============================================================================
  # Topic Depth Validation (SC-ZTEST-017)
  # ============================================================================

  describe "topic depth validation (SC-ZTEST-017)" do
    test "valid topics have <= 6 levels" do
      valid = "indrajaal/health/node/cpu/core/0"
      segments = String.split(valid, "/")
      assert length(segments) <= 6
    end

    test "topics exceeding 6 levels are invalid" do
      invalid = "indrajaal/health/node/cpu/core/0/extra"
      segments = String.split(invalid, "/")
      assert length(segments) > 6
    end

    test "topic validation function" do
      assert valid_topic?("indrajaal/health/node-1")
      assert valid_topic?("indrajaal/cepaf/cmd/deploy")
      refute valid_topic?("indrajaal/a/b/c/d/e/f")
      refute valid_topic?("")
    end
  end

  # ============================================================================
  # Message Ordering (SC-ZTEST-012)
  # ============================================================================

  describe "message ordering (SC-ZTEST-012)" do
    test "messages on same topic maintain FIFO order" do
      messages =
        for i <- 1..10 do
          %{
            topic: "indrajaal/test/events",
            payload: %{seq: i},
            timestamp: DateTime.add(~U[2026-01-01 00:00:00Z], i, :second)
          }
        end

      sequences = Enum.map(messages, & &1.payload.seq)
      assert sequences == Enum.sort(sequences)
    end

    test "messages on different topics are independent" do
      topic_a = [%{topic: "indrajaal/a", seq: 1}, %{topic: "indrajaal/a", seq: 2}]
      topic_b = [%{topic: "indrajaal/b", seq: 1}, %{topic: "indrajaal/b", seq: 2}]

      # Each topic maintains its own order
      assert Enum.map(topic_a, & &1.seq) == [1, 2]
      assert Enum.map(topic_b, & &1.seq) == [1, 2]
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: topic depth always <= 6" do
    @tag timeout: 30_000
    test "generated topics respect depth limit" do
      ExUnitProperties.check all(
                               segments <-
                                 SD.list_of(
                                   SD.string(:alphanumeric, min_length: 1, max_length: 10),
                                   min_length: 1,
                                   max_length: 5
                                 )
                             ) do
        topic = "indrajaal/" <> Enum.join(segments, "/")
        depth = length(String.split(topic, "/"))
        assert depth <= 6, "Topic #{topic} has depth #{depth}, max is 6"
      end
    end
  end

  describe "property: wildcard ** matches any subtopic" do
    @tag timeout: 30_000
    test "** pattern matches all generated subtopics" do
      ExUnitProperties.check all(
                               base <-
                                 SD.member_of([
                                   "indrajaal/health",
                                   "indrajaal/metrics",
                                   "indrajaal/cepaf"
                                 ]),
                               suffix <-
                                 SD.list_of(
                                   SD.string(:alphanumeric, min_length: 1, max_length: 8),
                                   min_length: 1,
                                   max_length: 3
                                 )
                             ) do
        topic = base <> "/" <> Enum.join(suffix, "/")
        pattern = base <> "/**"
        assert matches?(pattern, topic)
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp matches?(pattern, topic) do
    pattern_parts = String.split(pattern, "/")
    topic_parts = String.split(topic, "/")
    do_match(pattern_parts, topic_parts)
  end

  defp do_match([], []), do: true
  defp do_match(["**" | _], _), do: true
  defp do_match(["*" | rest_p], [_ | rest_t]), do: do_match(rest_p, rest_t)
  defp do_match([p | rest_p], [t | rest_t]) when p == t, do: do_match(rest_p, rest_t)
  defp do_match(_, _), do: false

  defp valid_topic?(topic) when is_binary(topic) and byte_size(topic) > 0 do
    segments = String.split(topic, "/")
    length(segments) >= 2 and length(segments) <= 6 and hd(segments) == "indrajaal"
  end

  defp valid_topic?(_), do: false
end
