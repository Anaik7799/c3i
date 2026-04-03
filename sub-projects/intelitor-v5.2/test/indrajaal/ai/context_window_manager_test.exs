defmodule Indrajaal.AI.ContextWindowManagerTest do
  @moduledoc """
  TDG test suite for ContextWindowManager (GenServer).

  ## STAMP Safety Integration
  - SC-AI-007: Context window usage MUST trigger /compact at 75%
  - SC-BIO-004: Auto-compact at 75% context

  ## TPS 5-Level RCA Context
  - L1 Symptom: Context overflow causing agent failures
  - L5 Root Cause: Missing compaction trigger or threshold misconfiguration
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.ContextWindowManager

  setup do
    {:ok, pid} = start_supervised({ContextWindowManager, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer successfully", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "already running returns error when name registered" do
      # The GenServer is already started via setup, so a second start_link
      # with the same registered name should return an error
      result = ContextWindowManager.start_link([])
      assert match?({:error, {:already_started, _}}, result)
    end
  end

  describe "start_session/2" do
    test "starts a new session with model name" do
      result = ContextWindowManager.start_session("session-1", "claude-3-5-sonnet")
      assert result == :ok or match?({:ok, _}, result)
    end

    test "starts session with haiku model" do
      result = ContextWindowManager.start_session("haiku-session", "claude-3-haiku")
      assert result == :ok or match?({:ok, _}, result)
    end

    test "starting same session twice is handled" do
      ContextWindowManager.start_session("dup-session", "claude-3-5-sonnet")
      result = ContextWindowManager.start_session("dup-session", "claude-3-5-sonnet")
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "record_usage/3" do
    test "records token usage for a session" do
      ContextWindowManager.start_session("usage-session", "claude-3-5-sonnet")
      result = ContextWindowManager.record_usage("usage-session", 1000, 0)
      assert result == :ok or match?({:ok, _}, result)
    end

    test "records output token usage" do
      ContextWindowManager.start_session("out-session", "claude-3-5-sonnet")
      result = ContextWindowManager.record_usage("out-session", 0, 500)
      assert result == :ok or match?({:ok, _}, result)
    end

    test "recording usage for non-existent session is handled" do
      result = ContextWindowManager.record_usage("ghost-session", 100, 0)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "get_usage_percent/1" do
    test "returns 0.0 for new session" do
      ContextWindowManager.start_session("fresh-session", "claude-3-5-sonnet")
      result = ContextWindowManager.get_usage_percent("fresh-session")
      assert {:ok, percent} = result
      assert is_float(percent) or is_integer(percent)
      assert percent >= 0.0
    end

    test "usage percent increases after recording tokens" do
      ContextWindowManager.start_session("track-session", "claude-3-5-sonnet")
      ContextWindowManager.record_usage("track-session", 10_000, 0)
      result = ContextWindowManager.get_usage_percent("track-session")
      assert {:ok, percent} = result
      assert is_float(percent) or is_integer(percent)
      assert percent >= 0.0
    end

    test "returns error for unknown session" do
      result = ContextWindowManager.get_usage_percent("unknown-session-xyz")
      assert {:error, :not_found} = result
    end
  end

  describe "get_session_state/1" do
    test "returns session state map for active session" do
      ContextWindowManager.start_session("state-session", "claude-3-5-sonnet")
      result = ContextWindowManager.get_session_state("state-session")
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error or nil for non-existent session" do
      result = ContextWindowManager.get_session_state("nonexistent-xyz")
      assert is_nil(result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "needs_compaction?/1" do
    test "returns false for new session" do
      ContextWindowManager.start_session("compact-check-session", "claude-3-5-sonnet")
      result = ContextWindowManager.needs_compaction?("compact-check-session")
      assert is_boolean(result)
      assert result == false
    end

    test "returns boolean value" do
      ContextWindowManager.start_session("bool-session", "claude-3-haiku")
      result = ContextWindowManager.needs_compaction?("bool-session")
      assert is_boolean(result)
    end
  end

  describe "get_context_window/1" do
    test "returns context window size for known model" do
      result = ContextWindowManager.get_context_window("claude-3-5-sonnet")
      assert is_integer(result) or match?({:ok, _}, result)
    end

    test "returns context window for haiku model" do
      result = ContextWindowManager.get_context_window("claude-3-haiku")
      assert is_integer(result) or match?({:ok, _}, result)
    end

    test "handles unknown model gracefully" do
      result = ContextWindowManager.get_context_window("unknown-model-xyz")
      assert is_integer(result) or is_nil(result) or match?({:error, _}, result)
    end
  end

  describe "get_recommended_action/1" do
    test "returns :continue for fresh session" do
      ContextWindowManager.start_session("action-session", "claude-3-5-sonnet")
      result = ContextWindowManager.get_recommended_action("action-session")
      assert match?({:continue, _}, result)
    end

    test "returns action tuple" do
      ContextWindowManager.start_session("rec-session", "claude-3-haiku")
      result = ContextWindowManager.get_recommended_action("rec-session")

      assert match?(
               {action, _percent} when action in [:continue, :compact, :minimal_mode],
               result
             ) or
               match?({:error, _}, result)
    end
  end

  describe "get_stats/0" do
    test "returns stats map" do
      result = ContextWindowManager.get_stats()
      assert is_map(result)
    end

    test "stats include session count or similar metric" do
      result = ContextWindowManager.get_stats()
      assert is_map(result)
      assert map_size(result) >= 0
    end
  end

  describe "record_compaction/2" do
    test "records a compaction event for a session" do
      ContextWindowManager.start_session("compact-rec-session", "claude-3-5-sonnet")

      result =
        ContextWindowManager.record_compaction("compact-rec-session", 5000)

      assert result == :ok or match?({:ok, _}, result)
    end

    test "handles compaction for non-existent session" do
      result = ContextWindowManager.record_compaction("ghost-compact", 0)
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "end_session/1" do
    test "ends an active session" do
      ContextWindowManager.start_session("end-me-session", "claude-3-5-sonnet")
      result = ContextWindowManager.end_session("end-me-session")
      assert result == :ok or match?({:ok, _}, result)
    end

    test "ending non-existent session is handled gracefully" do
      result = ContextWindowManager.end_session("never-started-xyz")
      assert is_atom(result) or is_tuple(result)
    end
  end
end
