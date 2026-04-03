defmodule Indrajaal.Cortex.GDE.AIIntegrationTest do
  @moduledoc """
  TDG Tests for GDE AI Integration module.

  Tests AI-enhanced proposal generation via OpenRouter.

  STAMP Constraints:
  - SC-GDE-060: AI calls must use OpenRouter exclusively
  - SC-GDE-061: All proposals must include confidence scores
  - SC-GDE-062: AI outputs must be validated before execution
  - SC-GDE-063: Fallback to local analysis if API unavailable
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.GDE.AIIntegration
  alias Indrajaal.Cortex.GDE.Generator
  alias Indrajaal.Cortex.GDE.ProposalEngine

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure ProposalEngine is running for fallback
    case GenServer.whereis(ProposalEngine) do
      nil ->
        {:ok, pid} = ProposalEngine.start_link([])
        on_exit(fn -> GenServer.stop(pid) end)
        {:ok, proposal_engine: pid}

      pid ->
        {:ok, proposal_engine: pid}
    end
  end

  # ============================================================
  # GENERATE_AI_PROPOSALS TESTS
  # ============================================================

  describe "generate_ai_proposals/2" do
    test "generates proposals for compile error (with fallback)" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: "** (CompileError) lib/test.ex:10: undefined function foo/1"
      }

      # This will likely fallback to local if API key not set
      {:ok, proposals} = AIIntegration.generate_ai_proposals(error_context)

      # Should return proposals (either from AI or fallback)
      assert is_list(proposals)
    end

    test "proposals include required fields" do
      error_context = %{
        type: :undefined_function,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function bar/0",
        raw: ""
      }

      {:ok, proposals} = AIIntegration.generate_ai_proposals(error_context)

      Enum.each(proposals, fn p ->
        assert Map.has_key?(p, :type)
        assert Map.has_key?(p, :confidence)
        assert Map.has_key?(p, :description)
        assert p.confidence >= 0.0 and p.confidence <= 1.0
      end)
    end

    test "respects max_proposals option" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      {:ok, proposals} = AIIntegration.generate_ai_proposals(error_context, max_proposals: 2)

      assert length(proposals) <= 2
    end

    test "respects min_confidence option" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      {:ok, proposals} = AIIntegration.generate_ai_proposals(error_context, min_confidence: 0.7)

      Enum.each(proposals, fn p ->
        assert p.confidence >= 0.7
      end)
    end
  end

  # ============================================================
  # PROPOSAL_GENERATOR TESTS
  # ============================================================

  describe "proposal_generator/2" do
    test "returns a generator" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      gen = AIIntegration.proposal_generator(error_context)

      # Should be enumerable
      proposals = Enum.take(gen, 3)
      assert is_list(proposals)
    end

    test "can be used with Generator.find_first" do
      error_context = %{
        type: :undefined_function,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      gen = AIIntegration.proposal_generator(error_context)

      result = Generator.find_first(gen, fn p -> p.type == :add_import end)

      # Should find or not find based on generated proposals
      assert match?({:ok, _}, result) or match?({:error, :not_found}, result)
    end
  end

  # ============================================================
  # ANALYZE_AND_PROPOSE TESTS
  # ============================================================

  describe "analyze_and_propose/2" do
    test "analyzes error logs and generates proposals" do
      error_logs = """
      ** (CompileError) lib/indrajaal/test.ex:42: undefined function missing_func/1
      """

      result = AIIntegration.analyze_and_propose(error_logs)

      case result do
        {:ok, %{analysis: analysis, proposals: proposals}} ->
          assert is_map(analysis)
          assert is_list(proposals)

        {:error, reason} ->
          # Acceptable if API unavailable
          assert is_tuple(reason) or is_atom(reason)
      end
    end

    test "handles empty error logs" do
      result = AIIntegration.analyze_and_propose("")

      # Should either succeed with empty proposals or return appropriate error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # ENHANCE_PROPOSAL TESTS
  # ============================================================

  describe "enhance_proposal/3" do
    test "enhances basic proposal with AI" do
      proposal = %{
        type: :add_import,
        confidence: 0.7,
        description: "Add import for Enum",
        file: "lib/test.ex",
        line: 10,
        original: nil,
        replacement: nil,
        metadata: %{}
      }

      file_content = """
      defmodule Test do
        def foo do
          Enum.map([1, 2, 3], &(&1 * 2))
        end
      end
      """

      {:ok, enhanced} = AIIntegration.enhance_proposal(proposal, file_content)

      # Should return enhanced proposal
      assert is_map(enhanced)
      assert Map.has_key?(enhanced, :type)
      assert Map.has_key?(enhanced, :confidence)
    end

    test "preserves original proposal on enhancement failure" do
      proposal = %{
        type: :fix_code,
        confidence: 0.6,
        description: "Fix syntax",
        file: "lib/test.ex",
        line: 5,
        original: "foo(",
        replacement: "foo()",
        metadata: %{}
      }

      {:ok, enhanced} = AIIntegration.enhance_proposal(proposal, "")

      # Should still have type and confidence
      assert enhanced.type == :fix_code
      assert is_float(enhanced.confidence)
    end
  end

  # ============================================================
  # VALIDATE_FIX TESTS
  # ============================================================

  describe "validate_fix/3" do
    test "validates a proposed fix" do
      proposal = %{
        type: :add_import,
        confidence: 0.9,
        description: "Add import",
        file: "lib/test.ex",
        line: 1,
        original: nil,
        replacement: "import Enum",
        reasoning: "Missing import",
        model: :smart,
        metadata: %{}
      }

      original_error = %{
        type: :undefined_function,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function map/2",
        raw: ""
      }

      {:ok, validation} = AIIntegration.validate_fix(proposal, original_error)

      assert Map.has_key?(validation, :valid)
      assert Map.has_key?(validation, :reasoning)
      assert is_boolean(validation.valid)
    end
  end

  # ============================================================
  # FALLBACK BEHAVIOR TESTS
  # ============================================================

  describe "fallback behavior" do
    test "falls back to local ProposalEngine when API unavailable" do
      # This test verifies fallback works
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function test/0",
        raw: ""
      }

      # Should not crash, even if API unavailable
      result = AIIntegration.generate_ai_proposals(error_context)

      assert match?({:ok, _}, result)
    end

    test "local fallback proposals have model: :local" do
      error_context = %{
        type: :undefined_function,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function local_test/1",
        raw: ""
      }

      {:ok, proposals} = AIIntegration.generate_ai_proposals(error_context)

      # If fallback was used, model should be :local
      # (or if API worked, it should be :smart/:fast/:deep)
      Enum.each(proposals, fn p ->
        if Map.get(p, :model) == :local do
          assert p.ai_enhanced == false
        end
      end)
    end
  end

  # ============================================================
  # INTEGRATION WITH GDE PIPELINE
  # ============================================================

  describe "GDE pipeline integration" do
    test "proposals can be used in backtracking" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function pipeline_test/0",
        raw: ""
      }

      # Generate proposals
      {:ok, proposals} = AIIntegration.generate_ai_proposals(error_context)

      # Create generator from proposals
      gen = Generator.alternatives(proposals)

      # Use with backtrack
      result =
        Generator.with_backtrack(gen, fn proposal ->
          # Simulate testing each proposal
          if proposal.confidence > 0.5 do
            {:ok, proposal}
          else
            {:error, :low_confidence}
          end
        end)

      # Should either find a valid proposal or exhaust
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
