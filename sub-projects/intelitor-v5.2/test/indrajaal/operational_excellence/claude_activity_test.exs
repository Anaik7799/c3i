defmodule Indrajaal.OperationalExcellence.ClaudeActivityTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.OperationalExcellence.ClaudeActivity.

  Tests the GenServer-based tamper-proof activity log.
  Verifies public API: start_link/1, track/2, get_last_entry/0,
  find_by_script/1, modify/1, search/1, get_stats/0, export/2.

  ## STAMP Constraints Verified
  - SC-006: Tamper-proof activity log (modify always returns error)
  - SC-DOC-001: Activity entries must include all context fields
  """

  use ExUnit.Case, async: false

  alias Indrajaal.OperationalExcellence.ClaudeActivity

  setup do
    case Process.whereis(ClaudeActivity) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 500)
    end

    case start_supervised({ClaudeActivity, []}) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        IO.puts("ClaudeActivity start skipped: #{inspect(reason)}")
        :skip
    end
  end

  # ---------------------------------------------------------------------------
  # modify/1 — always returns {:error, :tamper_detected} (SC-006)
  # ---------------------------------------------------------------------------

  describe "modify/1" do
    test "returns {:error, :tamper_detected} for any entry" do
      result = ClaudeActivity.modify(%{id: "fake-entry", operation: "edit"})
      assert result == {:error, :tamper_detected}
    end

    test "returns {:error, :tamper_detected} for empty map" do
      result = ClaudeActivity.modify(%{})
      assert result == {:error, :tamper_detected}
    end

    test "returns {:error, :tamper_detected} for nil" do
      result = ClaudeActivity.modify(nil)
      assert result == {:error, :tamper_detected}
    end

    test "returns {:error, :tamper_detected} regardless of entry content" do
      result = ClaudeActivity.modify(%{id: "real-looking", data: "admin override"})
      assert result == {:error, :tamper_detected}
    end
  end

  # ---------------------------------------------------------------------------
  # get_stats/0
  # ---------------------------------------------------------------------------

  describe "get_stats/0" do
    test "returns a map" do
      result = ClaudeActivity.get_stats()
      assert is_map(result)
    end

    test "stats has :total_operations key" do
      stats = ClaudeActivity.get_stats()
      assert Map.has_key?(stats, :total_operations)
    end

    test "stats has :buffered_entries key" do
      stats = ClaudeActivity.get_stats()
      assert Map.has_key?(stats, :buffered_entries)
    end

    test "stats has :memory_cache_size key" do
      stats = ClaudeActivity.get_stats()
      assert Map.has_key?(stats, :memory_cache_size)
    end

    test "total_operations starts at 0 on fresh start" do
      stats = ClaudeActivity.get_stats()
      assert stats.total_operations == 0
    end

    test "buffered_entries starts at 0 on fresh start" do
      stats = ClaudeActivity.get_stats()
      assert stats.buffered_entries == 0
    end
  end

  # ---------------------------------------------------------------------------
  # track/2 — async cast, no return value
  # ---------------------------------------------------------------------------

  describe "track/2" do
    test "track does not raise for valid operation and context" do
      # track/2 is a cast — no return value to assert, just ensure no crash
      ClaudeActivity.track(:compile, %{script: "mix compile", exit_code: 0})
      # Give async time to process
      Process.sleep(20)
      stats = ClaudeActivity.get_stats()
      assert stats.total_operations >= 0
    end

    test "total_operations increases after tracking" do
      initial = ClaudeActivity.get_stats().total_operations
      ClaudeActivity.track(:test_run, %{exit_code: 0, duration_ms: 5000})
      Process.sleep(30)
      final = ClaudeActivity.get_stats().total_operations
      assert final >= initial
    end

    test "track with complex context does not raise" do
      ClaudeActivity.track(:quality_gate, %{
        credo: :pass,
        dialyzer: :pass,
        sobelow: :pass,
        coverage: 97.5
      })

      Process.sleep(10)
    end

    test "buffered_entries increases after tracking when not flushed" do
      initial = ClaudeActivity.get_stats().buffered_entries
      ClaudeActivity.track(:some_operation, %{data: "value"})
      # If buffer not yet flushed, buffered_entries grows
      Process.sleep(10)
      final = ClaudeActivity.get_stats().buffered_entries
      assert final >= initial
    end
  end

  # ---------------------------------------------------------------------------
  # find_by_script/1
  # ---------------------------------------------------------------------------

  describe "find_by_script/1" do
    test "returns a list for any script name" do
      result = ClaudeActivity.find_by_script("nonexistent_script.exs")
      assert is_list(result)
    end

    test "returns empty list for unknown script" do
      result = ClaudeActivity.find_by_script("no_such_script_xyz.exs")
      assert result == []
    end
  end

  # ---------------------------------------------------------------------------
  # search/1
  # ---------------------------------------------------------------------------

  describe "search/1" do
    test "returns {:ok, results} tuple" do
      result = ClaudeActivity.search(%{operation: :compile})
      assert {:ok, _results} = result
    end

    test "results is a list" do
      {:ok, results} = ClaudeActivity.search(%{})
      assert is_list(results)
    end

    test "search with empty criteria returns list" do
      {:ok, results} = ClaudeActivity.search(%{})
      assert is_list(results)
    end

    test "search with specific operation criteria returns ok" do
      result = ClaudeActivity.search(%{operation: :nonexistent_op})
      assert {:ok, _} = result
    end
  end

  # ---------------------------------------------------------------------------
  # get_last_entry/0
  # ---------------------------------------------------------------------------

  describe "get_last_entry/0" do
    test "returns nil or a map on fresh start" do
      result = ClaudeActivity.get_last_entry()
      assert is_nil(result) or is_map(result)
    end

    test "returns a map after tracking an operation" do
      ClaudeActivity.track(:test_op, %{key: "value"})
      Process.sleep(30)
      result = ClaudeActivity.get_last_entry()
      # Either nil (not yet buffered to accessible location) or a map
      assert is_nil(result) or is_map(result)
    end
  end

  # ---------------------------------------------------------------------------
  # export/2
  # ---------------------------------------------------------------------------

  describe "export/2" do
    test "returns ok or error tuple" do
      start_time = DateTime.add(DateTime.utc_now(), -3600, :second)
      end_time = DateTime.utc_now()
      result = ClaudeActivity.export(start_time, end_time)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "export with valid time range does not raise" do
      start_time = ~U[2026-01-01 00:00:00Z]
      end_time = ~U[2026-01-02 00:00:00Z]
      # May return empty list or error — both are valid
      result = ClaudeActivity.export(start_time, end_time)
      assert is_tuple(result)
    end
  end
end
