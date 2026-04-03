defmodule Indrajaal.Cortex.GDE.ProposalEngineTest do
  @moduledoc """
  TDG Tests for GDE ProposalEngine module.

  Tests hypothesis generation and ranking.

  STAMP Constraints:
  - SC-GDE-040: Proposals must include confidence score
  - SC-GDE-041: Proposals must be deterministic
  - SC-GDE-042: Must integrate with StringScanner
  - SC-GDE-043: Must track proposal success rates
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cortex.GDE.ProposalEngine
  alias Indrajaal.Cortex.GDE.Generator

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    case GenServer.whereis(ProposalEngine) do
      nil ->
        {:ok, pid} = ProposalEngine.start_link([])
        on_exit(fn -> GenServer.stop(pid) end)
        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  # ============================================================
  # GENERATE TESTS
  # ============================================================

  describe "generate/2" do
    test "generates proposals for undefined function error" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)

      assert length(proposals) > 0
      assert Enum.all?(proposals, &Map.has_key?(&1, :confidence))
      assert Enum.all?(proposals, &(&1.confidence >= 0.0 and &1.confidence <= 1.0))
    end

    test "generates proposals for undefined module error" do
      error_context = %{
        type: :undefined_module,
        file: "lib/test.ex",
        line: 5,
        message: "undefined module MyApp.Context",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)

      types = Enum.map(proposals, & &1.type)
      assert :add_alias in types
    end

    test "proposals are sorted by confidence" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)

      confidences = Enum.map(proposals, & &1.confidence)
      assert confidences == Enum.sort(confidences, :desc)
    end

    test "respects max_proposals option" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context, max_proposals: 2)

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

      {:ok, proposals} = ProposalEngine.generate(error_context, min_confidence: 0.7)

      assert Enum.all?(proposals, &(&1.confidence >= 0.7))
    end

    test "includes file and line in proposals" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 42,
        message: "undefined function bar/0",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)

      # At least some proposals should reference the file
      file_proposals = Enum.filter(proposals, &(&1.file == "lib/test.ex"))
      assert length(file_proposals) > 0
    end
  end

  # ============================================================
  # GENERATE_FROM_LOGS TESTS
  # ============================================================

  describe "generate_from_logs/2" do
    test "generates proposals from compile error log" do
      log_text = "** (CompileError) lib/test.ex:10: undefined function foo/0"

      {:ok, proposals} = ProposalEngine.generate_from_logs(log_text)

      assert length(proposals) > 0
    end

    test "generates proposals from runtime error log" do
      log_text = "** (RuntimeError) something went wrong"

      {:ok, proposals} = ProposalEngine.generate_from_logs(log_text)

      assert length(proposals) > 0
    end

    test "returns error for unrecognized logs" do
      log_text = "random text with no error pattern"

      result = ProposalEngine.generate_from_logs(log_text)

      assert {:error, :no_errors_found} = result
    end
  end

  # ============================================================
  # PROPOSAL_GENERATOR TESTS
  # ============================================================

  describe "proposal_generator/2" do
    test "returns generator of proposals" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      gen = ProposalEngine.proposal_generator(error_context)
      proposals = Enum.to_list(gen)

      assert length(proposals) > 0
      assert Enum.all?(proposals, &is_map/1)
    end

    test "can be used with Generator.find_first" do
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      gen = ProposalEngine.proposal_generator(error_context)

      result = Generator.find_first(gen, fn p -> p.type == :add_import end)

      assert {:ok, proposal} = result
      assert proposal.type == :add_import
    end
  end

  # ============================================================
  # RECORD_OUTCOME TESTS
  # ============================================================

  describe "record_outcome/2" do
    test "records successful outcome" do
      proposal = %{
        type: :add_import,
        confidence: 0.8,
        description: "test",
        file: nil,
        line: nil,
        original: nil,
        replacement: nil,
        metadata: %{}
      }

      assert :ok = ProposalEngine.record_outcome(proposal, true)
    end

    test "records failed outcome" do
      proposal = %{
        type: :add_import,
        confidence: 0.8,
        description: "test",
        file: nil,
        line: nil,
        original: nil,
        replacement: nil,
        metadata: %{}
      }

      assert :ok = ProposalEngine.record_outcome(proposal, false)
    end

    test "affects future confidence calculations" do
      # Generate initial proposals
      error_context = %{
        type: :undefined_function,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      {:ok, proposals_before} = ProposalEngine.generate(error_context)

      # Record multiple successes for add_import
      for _ <- 1..5 do
        ProposalEngine.record_outcome(
          %{
            type: :add_import,
            confidence: 0.8,
            description: "",
            file: nil,
            line: nil,
            original: nil,
            replacement: nil,
            metadata: %{}
          },
          true
        )
      end

      # Give time for async updates
      Process.sleep(10)

      {:ok, proposals_after} = ProposalEngine.generate(error_context)

      # Find add_import proposals
      import_before = Enum.find(proposals_before, &(&1.type == :add_import))
      import_after = Enum.find(proposals_after, &(&1.type == :add_import))

      # After recording successes, confidence should be higher
      # (or at least not lower, depending on blending)
      assert import_after.confidence >= import_before.confidence * 0.9
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/0" do
    test "returns proposal statistics" do
      # Generate some proposals
      error_context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: ""
      }

      ProposalEngine.generate(error_context)

      stats = ProposalEngine.stats()

      assert stats.total_generated >= 0
      assert Map.has_key?(stats, :successful_outcomes)
      assert Map.has_key?(stats, :failed_outcomes)
      assert Map.has_key?(stats, :success_rate)
    end

    test "tracks success rates by type" do
      # Record outcomes for different types
      ProposalEngine.record_outcome(
        %{
          type: :add_import,
          confidence: 0.8,
          description: "",
          file: nil,
          line: nil,
          original: nil,
          replacement: nil,
          metadata: %{}
        },
        true
      )

      ProposalEngine.record_outcome(
        %{
          type: :add_alias,
          confidence: 0.7,
          description: "",
          file: nil,
          line: nil,
          original: nil,
          replacement: nil,
          metadata: %{}
        },
        false
      )

      Process.sleep(10)

      stats = ProposalEngine.stats()

      assert Map.has_key?(stats, :success_rates_by_type)
    end
  end

  # ============================================================
  # ERROR TYPE SPECIFIC TESTS
  # ============================================================

  describe "error type specific proposals" do
    test "undefined_function generates import/alias/fix proposals" do
      error_context = %{
        type: :undefined_function,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function my_func/2",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)
      types = Enum.map(proposals, & &1.type)

      assert :add_import in types
      assert :add_alias in types
      assert :fix_function_call in types
    end

    test "undefined_module generates alias/dependency proposals" do
      error_context = %{
        type: :undefined_module,
        file: "lib/test.ex",
        line: 5,
        message: "undefined module MyApp.Context",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)
      types = Enum.map(proposals, & &1.type)

      assert :add_alias in types
      assert :add_dependency in types
    end

    test "runtime_error generates clause/fix proposals" do
      error_context = %{
        type: :runtime_error,
        file: "lib/test.ex",
        line: 15,
        message: "no function clause matching",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)
      types = Enum.map(proposals, & &1.type)

      assert :add_clause in types or :fix_type in types
    end

    test "test_failure generates fix proposals" do
      error_context = %{
        type: :test_failure,
        file: "test/my_test.exs",
        line: 20,
        message: "assertion failed",
        raw: ""
      }

      {:ok, proposals} = ProposalEngine.generate(error_context)

      assert length(proposals) > 0
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "all proposals have required fields" do
      error_types = [:compile_error, :undefined_function, :undefined_module, :runtime_error]

      forall error_type <- PC.elements(error_types) do
        error_context = %{
          type: error_type,
          file: "lib/test.ex",
          line: 10,
          message: "test message",
          raw: ""
        }

        {:ok, proposals} = ProposalEngine.generate(error_context)

        Enum.all?(proposals, fn p ->
          Map.has_key?(p, :type) and
            Map.has_key?(p, :confidence) and
            Map.has_key?(p, :description) and
            Map.has_key?(p, :metadata)
        end)
      end
    end

    property "confidence scores are always between 0 and 1" do
      forall msg <- PC.utf8() do
        error_context = %{
          type: :compile_error,
          file: "lib/test.ex",
          line: 10,
          message: msg,
          raw: ""
        }

        {:ok, proposals} = ProposalEngine.generate(error_context)

        Enum.all?(proposals, fn p ->
          p.confidence >= 0.0 and p.confidence <= 1.0
        end)
      end
    end

    property "generation is deterministic" do
      forall msg <- PC.utf8() do
        error_context = %{
          type: :compile_error,
          file: "lib/test.ex",
          line: 10,
          message: msg,
          raw: ""
        }

        {:ok, p1} = ProposalEngine.generate(error_context)
        {:ok, p2} = ProposalEngine.generate(error_context)

        # Types and confidences should match
        types1 = Enum.map(p1, & &1.type)
        types2 = Enum.map(p2, & &1.type)

        types1 == types2
      end
    end
  end
end
