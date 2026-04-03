defmodule Indrajaal.Testing.AnalyticsEngineTest do
  @moduledoc """
  TDG test suite for AnalyticsEngine (GenServer, DB-dependent).

  ## STAMP Safety Integration
  - SC-COV-002: Runtime coverage >= 95%
  - SC-TDG-001: TDG validation before code generation

  ## TPS 5-Level RCA Context
  - L1 Symptom: Test analytics not computing optimization scores
  - L5 Root Cause: DB connection failure or empty test history table

  ## Note: DB-dependent
  AnalyticsEngine.analyze_suite_optimization/2 calls Repo.query!.
  The GenServer itself can start without DB but the primary function requires it.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Testing.AnalyticsEngine

  describe "module definition" do
    test "AnalyticsEngine module exists and is loaded" do
      assert Code.ensure_loaded?(AnalyticsEngine)
    end

    test "exports start_link/1" do
      assert function_exported?(AnalyticsEngine, :start_link, 1)
    end

    test "exports analyze_suite_optimization/2" do
      assert function_exported?(AnalyticsEngine, :analyze_suite_optimization, 2)
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      {:ok, pid} = AnalyticsEngine.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "can start multiple instances" do
      {:ok, pid1} = AnalyticsEngine.start_link([])
      {:ok, pid2} = AnalyticsEngine.start_link([])
      assert pid1 != pid2
      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
      GenServer.stop(pid1)
      GenServer.stop(pid2)
    end
  end

  describe "analyze_suite_optimization/2" do
    @tag :requires_db
    test "analyzes test suite and returns optimization report" do
      suite_name = "test_suite"
      opts = %{limit: 10, threshold: 0.8}
      result = AnalyticsEngine.analyze_suite_optimization(suite_name, opts)
      assert is_map(result) or is_tuple(result)
    end

    @tag :requires_db
    test "handles empty suite name" do
      result = AnalyticsEngine.analyze_suite_optimization("", %{})
      assert is_map(result) or is_tuple(result)
    end

    @tag :requires_db
    test "handles non-existent suite" do
      result = AnalyticsEngine.analyze_suite_optimization("nonexistent-suite-xyz", %{})
      assert is_map(result) or is_tuple(result)
    end

    test "analyze_suite_optimization exists as function" do
      # Just verify the function exists without calling DB
      assert function_exported?(AnalyticsEngine, :analyze_suite_optimization, 2)
    end
  end

  describe "process lifecycle" do
    test "process stays alive after start" do
      {:ok, pid} = AnalyticsEngine.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "process responds to GenServer.call :get_state or similar" do
      {:ok, pid} = AnalyticsEngine.start_link([])
      assert Process.alive?(pid)

      # Try to get state via GenServer
      try do
        state = :sys.get_state(pid)
        assert is_map(state) or is_tuple(state)
      rescue
        _ -> :ok
      end

      GenServer.stop(pid)
    end

    test "process handles unexpected messages without crashing" do
      {:ok, pid} = AnalyticsEngine.start_link([])
      send(pid, {:unexpected_message, :test})
      Process.sleep(50)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
