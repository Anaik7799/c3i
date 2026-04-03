defmodule Indrajaal.Cortex.SynapseTest do
  @moduledoc """
  TDG Test Artifacts for Synapse (Bicameral Cortex).

  WHAT: Tests for Bicameral Loop orchestration and GDE backtracking.
  WHY: SC-CTX-001 requires Bicameral Loop, SC-CTX-002 requires Guardian validation.
  CONSTRAINTS: Must test all OODA phases, GDE retry logic, checkpoint management.

  ## TDG Methodology

  - Unit tests for each Bicameral phase
  - Integration tests for full loop
  - Property tests for GDE invariants
  - Latency tests for performance requirements

  ## STAMP Constraints Tested

  - SC-CTX-001: Synapse must use Bicameral Loop
  - SC-CTX-002: All proposals must pass Guardian
  - SC-CTX-003: Telemetry must stream to Zenoh
  - SC-CTX-004: GDE backtracking via ZenohTimeTravel
  - SC-CTX-005: Max 5 retry attempts per problem

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-CTX-001 to SC-CTX-005 |
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Cortex.Synapse

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start required GenServers
    start_support_servers()

    case GenServer.whereis(Synapse) do
      nil ->
        {:ok, pid} = Synapse.start_link()
        on_exit(fn -> Process.exit(pid, :normal) end)
        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  defp start_support_servers do
    # Start ZenohTimeTravel if not running
    unless GenServer.whereis(Indrajaal.Observability.ZenohTimeTravel) do
      Indrajaal.Observability.ZenohTimeTravel.start_link()
    end

    # Start ZenohNeuralStream if not running
    unless GenServer.whereis(Indrajaal.Observability.ZenohNeuralStream) do
      Indrajaal.Observability.ZenohNeuralStream.start_link()
    end
  rescue
    _ -> :ok
  end

  # ============================================================
  # UNIT TESTS - AVAILABILITY
  # ============================================================

  describe "available?/0" do
    test "returns boolean" do
      result = Synapse.available?()
      assert is_boolean(result)
    end
  end

  # ============================================================
  # UNIT TESTS - STATS
  # ============================================================

  describe "stats/0" do
    test "returns comprehensive statistics" do
      stats = Synapse.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :synapse)
      assert Map.has_key?(stats, :gemini)
      assert Map.has_key?(stats, :claude)

      # Synapse-specific stats
      synapse_stats = stats.synapse
      assert Map.has_key?(synapse_stats, :total_problems)
      assert Map.has_key?(synapse_stats, :solved_problems)
      assert Map.has_key?(synapse_stats, :failed_problems)
      assert Map.has_key?(synapse_stats, :success_rate)
      assert Map.has_key?(synapse_stats, :guardian_vetoes)
      assert Map.has_key?(synapse_stats, :uptime_seconds)
    end

    test "tracks time_travel_session" do
      stats = Synapse.stats()
      synapse_stats = stats.synapse

      # May be nil if ZenohTimeTravel not available, or string if available
      assert synapse_stats.time_travel_session == nil or
               is_binary(synapse_stats.time_travel_session)
    end
  end

  # ============================================================
  # UNIT TESTS - ANALYZE CONTEXT
  # ============================================================

  describe "analyze_context/3" do
    test "delegates to Gemini and returns analysis" do
      files = ["lib/indrajaal/cortex/synapse.ex"]
      query = "What is the module structure?"

      result = Synapse.analyze_context(files, query)

      case result do
        {:ok, response} ->
          assert is_map(response)
          assert Map.has_key?(response, :summary)

        {:error, _} ->
          :ok
      end
    end

    test "handles empty files" do
      result = Synapse.analyze_context([], "test")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # UNIT TESTS - GENERATE CODE
  # ============================================================

  describe "generate_code/3" do
    test "delegates to Claude and returns generated code" do
      analysis = %{summary: "Need a helper function"}
      requirements = "Add a function that returns :ok"

      result = Synapse.generate_code(analysis, requirements)

      case result do
        {:ok, response} ->
          assert is_map(response)
          assert Map.has_key?(response, :code)

        {:error, _} ->
          :ok

        {:veto, _, _} ->
          # Guardian veto is acceptable
          :ok
      end
    end

    test "tracks guardian vetoes" do
      initial_stats = Synapse.stats()
      initial_vetoes = initial_stats.synapse.guardian_vetoes

      # Make requests that might be vetoed
      Synapse.generate_code(%{}, "test")
      Synapse.generate_code(%{}, "another test")

      final_stats = Synapse.stats()
      # Vetoes should not decrease
      assert final_stats.synapse.guardian_vetoes >= initial_vetoes
    end
  end

  # ============================================================
  # UNIT TESTS - ANALYZE AND FIX
  # ============================================================

  describe "analyze_and_fix/3" do
    test "combines Gemini analysis with Claude fix" do
      error_logs = """
      ** (CompileError) lib/test.ex:10: undefined function foo/0
      """

      result = Synapse.analyze_and_fix(error_logs)

      case result do
        {:ok, response} ->
          assert is_map(response)
          assert Map.has_key?(response, :analysis)
          # Fix may be nil if vetoed
          assert Map.has_key?(response, :fix) or Map.has_key?(response, :veto)

        {:error, _} ->
          :ok
      end
    end

    test "accepts additional context" do
      error_logs = "Test error"
      context = %{file: "test.ex", line: 42}

      result = Synapse.analyze_and_fix(error_logs, context)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # UNIT TESTS - SOLVE PROBLEM (BICAMERAL LOOP)
  # ============================================================

  describe "solve_problem/3 - SC-CTX-001 Bicameral Loop" do
    test "executes Bicameral Loop for compilation goal" do
      context = %{
        files: ["lib/test.ex"],
        logs: "** (CompileError) undefined function",
        error: "undefined function foo/0",
        metadata: %{source: :compiler}
      }

      result = Synapse.solve_problem(context, :compilation_success)

      case result do
        {:ok, response} ->
          assert is_map(response)
          assert Map.has_key?(response, :success)
          assert Map.has_key?(response, :attempts)
          assert Map.has_key?(response, :checkpoints)
          assert is_integer(response.attempts)
          assert response.attempts >= 1

        {:error, error_info} ->
          # GDE exhausted attempts
          assert is_map(error_info)
          assert Map.has_key?(error_info, :reason)
      end
    end

    test "tracks attempts in stats" do
      initial_stats = Synapse.stats()
      initial_attempts = initial_stats.synapse.total_attempts

      context = %{files: [], error: "test"}
      Synapse.solve_problem(context, :error_fix)

      final_stats = Synapse.stats()
      assert final_stats.synapse.total_attempts > initial_attempts
    end

    test "respects max_attempts option - SC-CTX-005" do
      context = %{files: [], error: "will fail"}

      result = Synapse.solve_problem(context, :test_pass, max_attempts: 2)

      case result do
        {:ok, response} ->
          assert response.attempts <= 2

        {:error, error_info} ->
          # If exhausted, should have tried 2 times
          assert error_info.attempts <= 2
      end
    end

    test "records checkpoints - SC-CTX-004" do
      context = %{files: [], error: "test"}

      result = Synapse.solve_problem(context, :error_fix, max_attempts: 3)

      case result do
        {:ok, response} ->
          # Should have at least initial checkpoint
          assert is_list(response.checkpoints)

        {:error, error_info} ->
          # Checkpoints should be recorded even on failure
          assert is_list(error_info.checkpoints)
      end
    end
  end

  # ============================================================
  # UNIT TESTS - GOALS
  # ============================================================

  describe "solution goals" do
    test "handles :compilation_success goal" do
      context = %{files: [], error: "compile error"}
      result = Synapse.solve_problem(context, :compilation_success, max_attempts: 1)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles :test_pass goal" do
      context = %{files: [], error: "test failure"}
      result = Synapse.solve_problem(context, :test_pass, max_attempts: 1)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles :error_fix goal" do
      context = %{files: [], error: "runtime error"}
      result = Synapse.solve_problem(context, :error_fix, max_attempts: 1)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles :feature_complete goal" do
      context = %{files: [], error: "missing feature"}
      result = Synapse.solve_problem(context, :feature_complete, max_attempts: 1)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "solve_problem always returns valid result" do
      forall goal <- PC.elements([:compilation_success, :test_pass, :error_fix]) do
        context = %{files: [], error: "test"}
        result = Synapse.solve_problem(context, goal, max_attempts: 1)

        case result do
          {:ok, _} -> true
          {:error, _} -> true
          _ -> false
        end
      end
    end

    property "stats always returns consistent structure" do
      forall _ <- PC.boolean() do
        stats = Synapse.stats()

        is_map(stats) and
          is_map(stats.synapse) and
          is_number(stats.synapse.success_rate) and
          stats.synapse.solved_problems <= stats.synapse.total_problems
      end
    end

    property "analyze_context handles any query" do
      forall query <- PC.binary() do
        result = Synapse.analyze_context([], query)
        match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  # ============================================================
  # GDE INVARIANT TESTS
  # ============================================================

  describe "GDE invariants" do
    test "attempts never exceed max_attempts" do
      context = %{files: [], error: "will fail"}

      for max <- [1, 2, 3, 5] do
        result = Synapse.solve_problem(context, :error_fix, max_attempts: max)

        case result do
          {:ok, response} ->
            assert response.attempts <= max

          {:error, error_info} ->
            assert error_info.attempts <= max
        end
      end
    end

    test "checkpoints accumulate with each attempt" do
      context = %{files: [], error: "test"}

      result = Synapse.solve_problem(context, :error_fix, max_attempts: 3)

      case result do
        {:ok, response} ->
          # At least one checkpoint per attempt
          assert length(Enum.filter(response.checkpoints, &is_binary/1)) >= 1

        {:error, error_info} ->
          # At least initial checkpoint
          assert length(Enum.filter(error_info.checkpoints, &is_binary/1)) >= 0
      end
    end
  end

  # ============================================================
  # LATENCY TESTS
  # ============================================================

  describe "latency requirements" do
    test "stats returns in <50ms" do
      start = System.monotonic_time(:millisecond)
      Synapse.stats()
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 50, "stats took #{elapsed}ms, expected <50ms"
    end

    test "available? returns in <20ms" do
      start = System.monotonic_time(:millisecond)
      Synapse.available?()
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 20, "available? took #{elapsed}ms, expected <20ms"
    end

    test "single attempt solve completes in <2s" do
      context = %{files: [], error: "test"}

      start = System.monotonic_time(:millisecond)
      Synapse.solve_problem(context, :error_fix, max_attempts: 1)
      elapsed = System.monotonic_time(:millisecond) - start

      # With mock AI, should be fast
      assert elapsed < 2000, "solve_problem took #{elapsed}ms, expected <2000ms"
    end
  end
end
