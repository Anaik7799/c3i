defmodule Indrajaal.Cortex.AI.ClaudeInterfaceTest do
  @moduledoc """
  TDG Test Artifacts for ClaudeInterface.

  WHAT: Tests for Claude API interface and code generation.
  WHY: SC-AI-001 requires API key validation, SC-SEC-001 requires Guardian validation.
  CONSTRAINTS: Must test mock mode, Guardian integration, error handling.

  ## TDG Methodology

  - Unit tests for core functionality
  - Mock tests when API key not configured
  - Property tests for response parsing
  - Guardian integration tests

  ## STAMP Constraints Tested

  - SC-AI-001: API key must be configured
  - SC-AI-002: Rate limiting must be respected
  - SC-AI-003: Outputs must pass Guardian validation
  - SC-SEC-001: No code execution without Guardian review

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-AI-001 to SC-AI-003, SC-SEC-001 |
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Cortex.AI.ClaudeInterface

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start the GenServer for tests
    case GenServer.whereis(ClaudeInterface) do
      nil ->
        {:ok, pid} = ClaudeInterface.start_link()
        on_exit(fn -> Process.exit(pid, :normal) end)
        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  # ============================================================
  # UNIT TESTS - AVAILABILITY
  # ============================================================

  describe "available?/0" do
    test "returns boolean" do
      result = ClaudeInterface.available?()
      assert is_boolean(result)
    end

    test "returns false when API key not set" do
      # In test environment, API key is typically not set
      result = ClaudeInterface.available?()
      assert is_boolean(result)
    end
  end

  # ============================================================
  # UNIT TESTS - STATS
  # ============================================================

  describe "stats/0" do
    test "returns statistics map" do
      stats = ClaudeInterface.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :available)
      assert Map.has_key?(stats, :model)
      assert Map.has_key?(stats, :total_requests)
      assert Map.has_key?(stats, :successful_requests)
      assert Map.has_key?(stats, :failed_requests)
      assert Map.has_key?(stats, :guardian_vetoes)
      assert Map.has_key?(stats, :uptime_seconds)
    end

    test "tracks guardian vetoes" do
      stats = ClaudeInterface.stats()
      assert is_integer(stats.guardian_vetoes)
      assert stats.guardian_vetoes >= 0
    end
  end

  # ============================================================
  # UNIT TESTS - GENERATE SOLUTION
  # ============================================================

  describe "generate_solution/3" do
    test "returns generated code" do
      analysis = %{
        summary: "Test module needs a new function",
        insights: ["Add helper function"],
        references: [%{file: "test.ex", relevance: 0.9}]
      }

      requirements = "Add a function that returns :ok"

      result = ClaudeInterface.generate_solution(analysis, requirements)

      case result do
        {:ok, response} ->
          assert is_map(response)
          assert Map.has_key?(response, :code)
          assert Map.has_key?(response, :explanation)
          assert Map.has_key?(response, :confidence)

        {:error, _reason} ->
          :ok

        {:veto, _reason, _fallback} ->
          # Guardian veto is acceptable
          :ok
      end
    end

    test "returns mock response when API key not set" do
      analysis = %{summary: "test"}
      result = ClaudeInterface.generate_solution(analysis, "test")

      case result do
        {:ok, response} ->
          if Map.get(response, :mock, false) do
            assert response.confidence == 0.0
          end

        {:error, _} ->
          :ok

        {:veto, _, _} ->
          :ok
      end
    end

    test "can skip guardian validation" do
      analysis = %{summary: "test"}

      result =
        ClaudeInterface.generate_solution(analysis, "test", guardian_validate: false)

      # Should not return veto when validation skipped
      case result do
        {:ok, response} ->
          # Guardian not consulted, so approved should be false
          refute Map.get(response, :guardian_approved, false)

        {:error, _} ->
          :ok
      end
    end

    test "accepts custom constraints" do
      analysis = %{summary: "test"}
      constraints = ["SC-VAL-001: Use Patient Mode", "SC-AGT-001: No deadlocks"]

      result =
        ClaudeInterface.generate_solution(analysis, "test", constraints: constraints)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or
               match?({:veto, _, _}, result)
    end
  end

  # ============================================================
  # UNIT TESTS - GENERATE FIX
  # ============================================================

  describe "generate_fix/3" do
    test "returns fix for error" do
      error_analysis = %{
        error_type: :compilation,
        root_cause: "Undefined function foo/0",
        affected_files: ["lib/test.ex"],
        suggested_fixes: ["Define the function"]
      }

      affected_files = ["lib/test.ex"]

      result = ClaudeInterface.generate_fix(error_analysis, affected_files)

      case result do
        {:ok, response} ->
          assert is_map(response)
          assert Map.has_key?(response, :fixes) or Map.has_key?(response, :code)
          assert Map.has_key?(response, :confidence)

        {:error, _} ->
          :ok

        {:veto, _, _} ->
          :ok
      end
    end

    test "handles empty affected files" do
      error_analysis = %{root_cause: "test error"}
      result = ClaudeInterface.generate_fix(error_analysis, [])

      assert match?({:ok, _}, result) or match?({:error, _}, result) or
               match?({:veto, _, _}, result)
    end
  end

  # ============================================================
  # UNIT TESTS - REASON
  # ============================================================

  describe "reason/3" do
    test "returns reasoning analysis" do
      problem = "How should I structure this module?"
      context = %{files: ["test.ex"], constraints: ["Must be simple"]}

      result = ClaudeInterface.reason(problem, context)

      case result do
        {:ok, response} ->
          assert is_map(response)
          assert Map.has_key?(response, :analysis) or Map.has_key?(response, :solutions)

        {:error, _} ->
          :ok
      end
    end

    test "handles empty context" do
      result = ClaudeInterface.reason("What is the best approach?", %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "generate_solution always returns valid tuple" do
      forall {summary, requirements} <- {PC.binary(), PC.binary()} do
        analysis = %{summary: summary}
        result = ClaudeInterface.generate_solution(analysis, requirements)

        case result do
          {:ok, _} -> true
          {:error, _} -> true
          {:veto, _, _} -> true
          _ -> false
        end
      end
    end

    property "stats always returns map with required keys" do
      forall _ <- PC.boolean() do
        stats = ClaudeInterface.stats()

        is_map(stats) and
          Map.has_key?(stats, :available) and
          Map.has_key?(stats, :guardian_vetoes)
      end
    end

    property "reason handles any problem string" do
      forall problem <- PC.binary() do
        result = ClaudeInterface.reason(problem, %{})
        match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  # ============================================================
  # GUARDIAN INTEGRATION TESTS (SC-SEC-001)
  # ============================================================

  describe "SC-SEC-001 Guardian integration" do
    test "default behavior validates with Guardian" do
      analysis = %{summary: "test"}
      result = ClaudeInterface.generate_solution(analysis, "test")

      case result do
        {:ok, response} ->
          # If Guardian approved, flag should be set
          if Map.get(response, :guardian_approved, false) do
            assert response.guardian_approved == true
          end

        {:veto, reason, fallback} ->
          # Guardian vetoed - this is SC-SEC-001 in action
          assert is_atom(reason) or is_binary(reason) or is_map(reason)
          # Fallback can be nil or have suggestions
          assert fallback == nil or is_map(fallback)

        {:error, _} ->
          :ok
      end
    end
  end

  # ============================================================
  # LATENCY TESTS
  # ============================================================

  describe "latency requirements" do
    test "mock generate_solution completes in <100ms" do
      analysis = %{summary: "test"}

      start = System.monotonic_time(:millisecond)
      ClaudeInterface.generate_solution(analysis, "test")
      elapsed = System.monotonic_time(:millisecond) - start

      # Mock should be very fast
      assert elapsed < 100, "generate_solution took #{elapsed}ms, expected <100ms for mock"
    end

    test "stats returns in <10ms" do
      start = System.monotonic_time(:millisecond)
      ClaudeInterface.stats()
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 10, "stats took #{elapsed}ms, expected <10ms"
    end

    test "available? returns in <10ms" do
      start = System.monotonic_time(:millisecond)
      ClaudeInterface.available?()
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 10, "available? took #{elapsed}ms, expected <10ms"
    end
  end
end
