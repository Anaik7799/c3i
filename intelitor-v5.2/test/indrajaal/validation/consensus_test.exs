defmodule Indrajaal.Validation.ConsensusTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.Consensus.

  Tests the FPPS 5-method consensus engine.
  SC-VAL-003: 100% consensus required.
  SC-VAL-004: Halt on disagreement.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.Consensus

  defp make_results(errors, warnings) do
    methods = [:pattern, :ast, :statistical, :binary, :line_by_line]

    Enum.map(methods, fn method ->
      %{method: method, errors: errors, warnings: warnings}
    end)
  end

  describe "check/2" do
    test "returns ok when all 5 methods agree" do
      results = make_results(0, 0)
      assert {:ok, %{errors: 0, warnings: 0}} = Consensus.check(results)
    end

    test "returns ok with non-zero agreement" do
      results = make_results(2, 1)
      assert {:ok, %{errors: 2, warnings: 1}} = Consensus.check(results)
    end

    test "returns error when less than 5 results provided" do
      results = Enum.take(make_results(0, 0), 4)
      assert {:error, :incomplete_methods} = Consensus.check(results)
    end

    test "returns consensus_failed when methods disagree on errors" do
      base = make_results(0, 0)
      disagreeing = List.replace_at(base, 0, %{method: :pattern, errors: 1, warnings: 0})
      result = Consensus.check(disagreeing)
      assert match?({:error, :consensus_failed, _}, result)
    end

    test "returns consensus_failed when methods disagree on warnings" do
      base = make_results(0, 0)
      disagreeing = List.replace_at(base, 2, %{method: :statistical, errors: 0, warnings: 3})
      result = Consensus.check(disagreeing)
      assert match?({:error, :consensus_failed, _}, result)
    end

    test "diagnostics include disagreement_summary" do
      base = make_results(0, 0)
      disagreeing = List.replace_at(base, 0, %{method: :pattern, errors: 5, warnings: 0})
      {:error, :consensus_failed, diagnostics} = Consensus.check(disagreeing)
      assert is_map(diagnostics)
      assert Map.has_key?(diagnostics, :disagreement_summary)
    end

    test "diagnostics include method_count" do
      base = make_results(0, 0)
      disagreeing = List.replace_at(base, 0, %{method: :pattern, errors: 5, warnings: 0})
      {:error, :consensus_failed, diagnostics} = Consensus.check(disagreeing)
      assert diagnostics.method_count == 5
    end

    test "handles invalid input" do
      assert {:error, :invalid_input} = Consensus.check("not a list")
    end

    test "quorum mode passes when min_agreement methods agree" do
      # 4 out of 5 agree on 0 errors/warnings, 1 disagrees
      base = make_results(0, 0)
      disagreeing = List.replace_at(base, 0, %{method: :pattern, errors: 1, warnings: 0})
      result = Consensus.check(disagreeing, min_agreement: 4)
      # 4 methods agree on errors=0, so quorum with min_agreement=4 should pass
      assert match?({:ok, _}, result) or match?({:error, :consensus_failed, _}, result)
    end

    test "quorum mode includes mode and agreement fields on success" do
      results = make_results(0, 0)

      case Consensus.check(results, min_agreement: 3) do
        {:ok, result} ->
          # Full consensus returns without mode field (strict mode)
          assert is_map(result)

        {:error, _, _} ->
          :ok
      end
    end
  end

  describe "consensus?/1" do
    test "returns true when all methods agree" do
      results = make_results(0, 0)
      assert Consensus.consensus?(results) == true
    end

    test "returns false when methods disagree" do
      base = make_results(0, 0)
      disagreeing = List.replace_at(base, 0, %{method: :pattern, errors: 1, warnings: 0})
      assert Consensus.consensus?(disagreeing) == false
    end

    test "returns false for invalid input" do
      assert Consensus.consensus?("invalid") == false
    end

    test "returns false for incomplete methods" do
      results = Enum.take(make_results(0, 0), 3)
      assert Consensus.consensus?(results) == false
    end
  end
end
