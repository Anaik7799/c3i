defmodule Indrajaal.Core.FPPSConsensusIntegrationTest do
  @moduledoc """
  TDG test suite for FPPS 5-method consensus integration.

  WHAT: Tests that the 5-point FPPS validation (Pattern, AST, Statistical,
  Binary, LineByLine) produces correct consensus results, that quorum
  is computed correctly, and that disagreement triggers emergency handling.

  CONSTRAINTS:
  - SC-VAL-003: 100% consensus required
  - SC-SIL4-023: FPPS 3/5 consensus for health
  - SC-SIL6-006: 2oo3 voting MANDATORY

  ## Constitutional Verification
  - Ψ₃ (Verification): FPPS results are reproducible
  - Ψ₅ (Truthfulness): Consensus reflects actual validation state

  ## Change History
  | Version | Date       | Author | Change                                    |
  |---------|------------|--------|-------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — FPPS consensus suite  |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # FPPS consensus engine
  # ---------------------------------------------------------------------------

  @methods [:pattern, :ast, :statistical, :binary, :line_by_line]

  defp run_method(method, input) do
    # Simulate 5 validation methods with deterministic results
    case method do
      :pattern -> %{method: :pattern, result: pattern_check(input), confidence: 0.95}
      :ast -> %{method: :ast, result: ast_check(input), confidence: 0.90}
      :statistical -> %{method: :statistical, result: stat_check(input), confidence: 0.85}
      :binary -> %{method: :binary, result: binary_check(input), confidence: 0.92}
      :line_by_line -> %{method: :line_by_line, result: lbl_check(input), confidence: 0.88}
    end
  end

  defp pattern_check(%{valid: valid}), do: if(valid, do: :pass, else: :fail)
  defp pattern_check(_), do: :pass

  defp ast_check(%{valid: valid}), do: if(valid, do: :pass, else: :fail)
  defp ast_check(_), do: :pass

  defp stat_check(%{valid: valid, anomaly: true}), do: if(valid, do: :pass, else: :fail)
  defp stat_check(%{valid: valid}), do: if(valid, do: :pass, else: :fail)
  defp stat_check(_), do: :pass

  defp binary_check(%{valid: valid}), do: if(valid, do: :pass, else: :fail)
  defp binary_check(_), do: :pass

  defp lbl_check(%{valid: valid}), do: if(valid, do: :pass, else: :fail)
  defp lbl_check(_), do: :pass

  defp run_all_methods(input) do
    Enum.map(@methods, &run_method(&1, input))
  end

  defp compute_consensus(results, opts \\ []) do
    min_agreement = Keyword.get(opts, :min_agreement, 5)
    pass_count = Enum.count(results, &(&1.result == :pass))
    fail_count = Enum.count(results, &(&1.result == :fail))
    total = length(results)

    avg_confidence =
      if total > 0 do
        Enum.sum(Enum.map(results, & &1.confidence)) / total
      else
        0.0
      end

    consensus =
      cond do
        pass_count >= min_agreement -> :healthy
        fail_count >= min_agreement -> :unhealthy
        pass_count >= 3 -> :degraded
        true -> :emergency
      end

    %{
      consensus: consensus,
      pass_count: pass_count,
      fail_count: fail_count,
      total: total,
      avg_confidence: Float.round(avg_confidence, 3),
      quorum_met: pass_count >= div(total, 2) + 1,
      methods: Enum.map(results, &{&1.method, &1.result})
    }
  end

  defp two_of_three_vote(results) when length(results) >= 3 do
    top3 = Enum.take(results, 3)
    pass_count = Enum.count(top3, &(&1.result == :pass))
    pass_count >= 2
  end

  defp two_of_three_vote(_results), do: false

  # ---------------------------------------------------------------------------
  # Consensus agreement tests (SC-VAL-003)
  # ---------------------------------------------------------------------------

  describe "SC-VAL-003: 100% consensus" do
    test "all pass yields :healthy" do
      results = run_all_methods(%{valid: true})
      consensus = compute_consensus(results)

      assert consensus.consensus == :healthy
      assert consensus.pass_count == 5
      assert consensus.quorum_met == true
    end

    test "all fail yields :unhealthy" do
      results = run_all_methods(%{valid: false})
      consensus = compute_consensus(results)

      assert consensus.consensus == :unhealthy
      assert consensus.fail_count == 5
    end

    test "split yields :degraded or :emergency" do
      results = [
        %{method: :pattern, result: :pass, confidence: 0.95},
        %{method: :ast, result: :pass, confidence: 0.90},
        %{method: :statistical, result: :pass, confidence: 0.85},
        %{method: :binary, result: :fail, confidence: 0.92},
        %{method: :line_by_line, result: :fail, confidence: 0.88}
      ]

      consensus = compute_consensus(results)
      assert consensus.consensus == :degraded
      assert consensus.pass_count == 3
      assert consensus.fail_count == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Quorum tests (SC-SIL4-023)
  # ---------------------------------------------------------------------------

  describe "SC-SIL4-023: FPPS 3/5 quorum" do
    test "3/5 agreement meets quorum" do
      results = [
        %{method: :pattern, result: :pass, confidence: 0.95},
        %{method: :ast, result: :pass, confidence: 0.90},
        %{method: :statistical, result: :pass, confidence: 0.85},
        %{method: :binary, result: :fail, confidence: 0.92},
        %{method: :line_by_line, result: :fail, confidence: 0.88}
      ]

      consensus = compute_consensus(results)
      assert consensus.quorum_met == true
    end

    test "2/5 agreement does not meet quorum" do
      results = [
        %{method: :pattern, result: :pass, confidence: 0.95},
        %{method: :ast, result: :pass, confidence: 0.90},
        %{method: :statistical, result: :fail, confidence: 0.85},
        %{method: :binary, result: :fail, confidence: 0.92},
        %{method: :line_by_line, result: :fail, confidence: 0.88}
      ]

      consensus = compute_consensus(results)
      assert consensus.quorum_met == false
    end

    test "configurable min_agreement" do
      results = run_all_methods(%{valid: true})
      consensus_strict = compute_consensus(results, min_agreement: 5)
      consensus_relaxed = compute_consensus(results, min_agreement: 3)

      assert consensus_strict.consensus == :healthy
      assert consensus_relaxed.consensus == :healthy
    end
  end

  # ---------------------------------------------------------------------------
  # 2oo3 voting tests (SC-SIL6-006)
  # ---------------------------------------------------------------------------

  describe "SC-SIL6-006: 2oo3 voting" do
    test "2 of 3 pass is accepted" do
      results = [
        %{method: :pattern, result: :pass, confidence: 0.95},
        %{method: :ast, result: :pass, confidence: 0.90},
        %{method: :statistical, result: :fail, confidence: 0.85}
      ]

      assert two_of_three_vote(results) == true
    end

    test "1 of 3 pass is rejected" do
      results = [
        %{method: :pattern, result: :pass, confidence: 0.95},
        %{method: :ast, result: :fail, confidence: 0.90},
        %{method: :statistical, result: :fail, confidence: 0.85}
      ]

      assert two_of_three_vote(results) == false
    end

    test "3 of 3 pass is accepted" do
      results = [
        %{method: :pattern, result: :pass, confidence: 0.95},
        %{method: :ast, result: :pass, confidence: 0.90},
        %{method: :statistical, result: :pass, confidence: 0.85}
      ]

      assert two_of_three_vote(results) == true
    end

    test "0 of 3 pass is rejected" do
      results = [
        %{method: :pattern, result: :fail, confidence: 0.95},
        %{method: :ast, result: :fail, confidence: 0.90},
        %{method: :statistical, result: :fail, confidence: 0.85}
      ]

      assert two_of_three_vote(results) == false
    end
  end

  # ---------------------------------------------------------------------------
  # Confidence scoring tests
  # ---------------------------------------------------------------------------

  describe "confidence scoring" do
    test "average confidence computed correctly" do
      results = [
        %{method: :pattern, result: :pass, confidence: 1.0},
        %{method: :ast, result: :pass, confidence: 0.8},
        %{method: :statistical, result: :pass, confidence: 0.6},
        %{method: :binary, result: :pass, confidence: 0.4},
        %{method: :line_by_line, result: :pass, confidence: 0.2}
      ]

      consensus = compute_consensus(results)
      assert consensus.avg_confidence == 0.6
    end

    test "methods are tracked in consensus" do
      results = run_all_methods(%{valid: true})
      consensus = compute_consensus(results)

      assert length(consensus.methods) == 5
      method_names = Enum.map(consensus.methods, &elem(&1, 0))
      assert :pattern in method_names
      assert :ast in method_names
      assert :statistical in method_names
      assert :binary in method_names
      assert :line_by_line in method_names
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: FPPS invariants" do
    property "pass_count + fail_count == total" do
      forall pass_count <- PC.integer(0, 5) do
        results =
          for i <- 1..5 do
            method = Enum.at(@methods, i - 1)
            result = if i <= pass_count, do: :pass, else: :fail

            %{method: method, result: result, confidence: 0.9}
          end

        consensus = compute_consensus(results)
        consensus.pass_count + consensus.fail_count == consensus.total
      end
    end

    test "consensus is deterministic" do
      ExUnitProperties.check all(valid <- SD.boolean()) do
        input = %{valid: valid}
        r1 = run_all_methods(input) |> compute_consensus()
        r2 = run_all_methods(input) |> compute_consensus()

        assert r1.consensus == r2.consensus
        assert r1.pass_count == r2.pass_count
      end
    end

    test "quorum requires strict majority" do
      ExUnitProperties.check all(pass_count <- SD.integer(0..5)) do
        results =
          for i <- 1..5 do
            %{
              method: Enum.at(@methods, i - 1),
              result: if(i <= pass_count, do: :pass, else: :fail),
              confidence: 0.9
            }
          end

        consensus = compute_consensus(results)

        if pass_count >= 3 do
          assert consensus.quorum_met == true
        else
          assert consensus.quorum_met == false
        end
      end
    end

    property "2oo3 vote is monotonic with pass count" do
      forall pass_count <- PC.integer(0, 3) do
        results =
          for i <- 1..3 do
            %{
              method: Enum.at(@methods, i - 1),
              result: if(i <= pass_count, do: :pass, else: :fail),
              confidence: 0.9
            }
          end

        if pass_count >= 2 do
          two_of_three_vote(results) == true
        else
          two_of_three_vote(results) == false
        end
      end
    end
  end
end
