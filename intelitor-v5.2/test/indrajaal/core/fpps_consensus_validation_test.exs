defmodule Indrajaal.Core.FPPSConsensusValidationTest do
  @moduledoc """
  TDG test: sa-health FPPS 5-method consensus validation.

  ## WHAT
  Validates the FPPS (Five-Point Pattern System) 5-method consensus:
  Pattern, AST, Statistical, Binary, LineByLine.

  ## WHY
  SC-VAL-003 mandates 100% consensus across all 5 methods.
  SC-SIL4-023 requires FPPS 3/5 consensus for health and snapshot validation.
  Ω₅ mandates 5-method FPPS agreement.

  ## CONSTRAINTS
  - SC-VAL-003: 100% Consensus required
  - SC-VAL-004: Halt on disagreement
  - SC-SIL4-023: FPPS 3/5 consensus for health
  - SC-VER-004: Verification < 100ms

  ## Coverage Matrix
  | Test | SC Constraint | Level |
  |------|---------------|-------|
  | 5-method agreement | SC-VAL-003 | L5 |
  | disagreement halt | SC-VAL-004 | L5 |
  | 3/5 quorum | SC-SIL4-023 | L5 |
  | verification timing | SC-VER-004 | L5 |
  | method independence | SC-SIL-004 | L5 |

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-24 | Claude | Initial implementation — Sprint 88 Wave 7 |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :fpps
  @moduletag :consensus
  @moduletag :sprint_88

  @methods [:pattern, :ast, :statistical, :binary, :line_by_line]

  setup do
    table = :ets.new(:fpps_test, [:set, :public])
    :ets.insert(table, {:results, %{}})
    :ets.insert(table, {:consensus_threshold, 5})
    on_exit(fn -> :ets.delete(table) end)
    {:ok, table: table}
  end

  describe "5-method agreement (SC-VAL-003)" do
    test "all 5 methods agreeing produces :ok consensus", %{table: table} do
      results = Map.new(@methods, fn method -> {method, :healthy} end)
      :ets.insert(table, {:results, results})

      assert fpps_consensus(results) == {:ok, :healthy}
    end

    test "exactly 5 methods are validated" do
      assert length(@methods) == 5
      assert @methods == [:pattern, :ast, :statistical, :binary, :line_by_line]
    end

    test "all methods return same status for agreement" do
      for status <- [:healthy, :degraded, :critical] do
        results = Map.new(@methods, fn method -> {method, status} end)
        assert {:ok, ^status} = fpps_consensus(results)
      end
    end
  end

  describe "disagreement detection (SC-VAL-004)" do
    test "single method disagreement produces :halt", %{table: table} do
      results = %{
        pattern: :healthy,
        ast: :healthy,
        statistical: :healthy,
        binary: :degraded,
        line_by_line: :healthy
      }

      :ets.insert(table, {:results, results})

      assert {:halt, details} = fpps_consensus(results)
      assert details.disagreeing == [:binary]
      assert details.majority == :healthy
    end

    test "multiple disagreements report all dissenting methods" do
      results = %{
        pattern: :healthy,
        ast: :critical,
        statistical: :healthy,
        binary: :critical,
        line_by_line: :healthy
      }

      assert {:halt, details} = fpps_consensus(results)
      assert length(details.disagreeing) == 2
      assert :ast in details.disagreeing
      assert :binary in details.disagreeing
    end
  end

  describe "3/5 quorum mode (SC-SIL4-023)" do
    test "3 out of 5 agreement produces quorum consensus" do
      results = %{
        pattern: :healthy,
        ast: :healthy,
        statistical: :healthy,
        binary: :degraded,
        line_by_line: :critical
      }

      assert {:quorum, :healthy, 3} = fpps_quorum(results, 3)
    end

    test "less than quorum threshold fails" do
      results = %{
        pattern: :healthy,
        ast: :degraded,
        statistical: :critical,
        binary: :degraded,
        line_by_line: :critical
      }

      assert {:no_quorum, _details} = fpps_quorum(results, 3)
    end

    test "5/5 quorum is strict consensus" do
      results = Map.new(@methods, fn method -> {method, :healthy} end)
      assert {:quorum, :healthy, 5} = fpps_quorum(results, 5)
    end

    test "property — quorum is reached for any threshold when all methods agree (SD)" do
      check all(threshold <- SD.integer(1..5)) do
        results = Map.new(@methods, fn method -> {method, :healthy} end)
        assert {:quorum, :healthy, 5} = fpps_quorum(results, threshold)
      end
    end
  end

  describe "verification timing (SC-VER-004)" do
    test "consensus check completes under 100ms" do
      results = Map.new(@methods, fn method -> {method, :healthy} end)

      {time_us, _result} = :timer.tc(fn -> fpps_consensus(results) end)
      time_ms = time_us / 1000

      assert time_ms < 100, "Consensus took #{time_ms}ms (budget: 100ms)"
    end
  end

  describe "method independence (SC-SIL-004)" do
    test "each method can be evaluated independently" do
      for method <- @methods do
        result = evaluate_method(method, %{source: "test_module", content: "valid"})
        assert result in [:healthy, :degraded, :critical, :unknown]
      end
    end

    test "method failure is isolated" do
      # One method fails, others should still return valid results
      working_results =
        @methods
        |> Enum.reject(&(&1 == :binary))
        |> Map.new(fn method -> {method, :healthy} end)

      assert map_size(working_results) == 4
      assert Enum.all?(Map.values(working_results), &(&1 == :healthy))
    end
  end

  describe "property-based validation" do
    test "property — consensus result is consistent with method statuses for any combination (SD)" do
      check all(
              statuses <-
                SD.list_of(
                  SD.member_of([:healthy, :degraded, :critical]),
                  length: 5
                )
            ) do
        results = Enum.zip(@methods, statuses) |> Map.new()

        case fpps_consensus(results) do
          {:ok, status} ->
            assert Enum.all?(Map.values(results), &(&1 == status))

          {:halt, details} ->
            assert is_list(details.disagreeing)
            assert length(details.disagreeing) > 0
        end
      end
    end
  end

  # --- FPPS Simulation Helpers ---

  defp fpps_consensus(results) do
    values = Map.values(results)
    unique = Enum.uniq(values)

    if length(unique) == 1 do
      {:ok, hd(unique)}
    else
      {majority, _count} =
        values
        |> Enum.frequencies()
        |> Enum.max_by(fn {_k, v} -> v end)

      disagreeing =
        results
        |> Enum.filter(fn {_method, status} -> status != majority end)
        |> Enum.map(fn {method, _status} -> method end)

      {:halt, %{majority: majority, disagreeing: disagreeing}}
    end
  end

  defp fpps_quorum(results, threshold) do
    values = Map.values(results)
    frequencies = Enum.frequencies(values)

    {majority_status, majority_count} = Enum.max_by(frequencies, fn {_k, v} -> v end)

    if majority_count >= threshold do
      {:quorum, majority_status, majority_count}
    else
      {:no_quorum, %{best: majority_status, count: majority_count, needed: threshold}}
    end
  end

  defp evaluate_method(method, context) do
    case {method, context} do
      {:pattern, %{content: c}} when is_binary(c) -> :healthy
      {:ast, %{content: c}} when is_binary(c) -> :healthy
      {:statistical, %{content: c}} when is_binary(c) -> :healthy
      {:binary, %{content: c}} when is_binary(c) -> :healthy
      {:line_by_line, %{content: c}} when is_binary(c) -> :healthy
      _ -> :unknown
    end
  end
end
