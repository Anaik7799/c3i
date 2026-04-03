defmodule Indrajaal.Crm.PipelineTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Crm.Analytics.Pipeline.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written for pure analytic functions (no DB required)
  - FPPS Validation: Dual property testing (PropCheck + ExUnitProperties)

  ## STAMP Safety Integration
  - SC-PRF-050: Response time < 50ms for pipeline analytics
  - SC-COV-006: TDG compliance mandatory
  - SC-TDG-001: TDG validation before code gen

  ## Constitutional Verification
  - Ψ₀ Existence: Pipeline module returns valid results under all inputs
  - Ψ₁ Regeneration: Pipeline metrics are derivable from opportunity list alone

  ## Founder's Directive Alignment
  - Ω₀.1: Win rate and velocity metrics drive resource acquisition strategy
  - Ω₀.7: Power accumulation tracked via accurate pipeline velocity KPIs

  ## TPS 5-Level RCA Context
  - L1 Symptom: Sales velocity shows 0 despite closed-won opportunities
  - L5 Root Cause: Missing `closed_at` field on opportunity maps silently drops
                   cycle-day contributions, producing an empty avg_days list

  ## Test Categories
  - Happy path for `win_rate/1`
  - Happy path for `conversion_rates/1`
  - Happy path for `sales_velocity/1`
  - Error/edge cases: empty inputs, no closed deals, missing date fields
  - Property test: win_rate is always in [0.0, 1.0] for any closed-opportunity list
  - Property test: conversion rates are always in [0.0, 1.0] per stage pair
  """

  use ExUnit.Case, async: true
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Analytics.Pipeline

  @moduletag :crm
  @moduletag :sprint_54

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp make_opp(attrs) do
    Map.merge(
      %{
        amount: Decimal.new("10000.00"),
        is_won: false,
        is_closed: false,
        stage: :qualification,
        inserted_at: ~U[2026-01-01 00:00:00Z],
        closed_at: nil
      },
      attrs
    )
  end

  defp won_opp(amount_str, inserted_at, closed_at) do
    make_opp(%{
      amount: Decimal.new(amount_str),
      is_won: true,
      is_closed: true,
      stage: :closed_won,
      inserted_at: inserted_at,
      closed_at: closed_at
    })
  end

  defp lost_opp do
    make_opp(%{is_won: false, is_closed: true, stage: :closed_lost})
  end

  # ---------------------------------------------------------------------------
  # describe win_rate/1
  # ---------------------------------------------------------------------------

  describe "win_rate/1" do
    test "returns 0.0 when no opportunities provided" do
      assert {:ok, 0.0} = Pipeline.win_rate(opportunities: [])
    end

    test "returns 0.0 when no closed opportunities exist" do
      opps = [make_opp(%{stage: :qualification}), make_opp(%{stage: :proposal})]
      assert {:ok, 0.0} = Pipeline.win_rate(opportunities: opps)
    end

    test "returns 1.0 when all closed opportunities are won" do
      opps = [
        make_opp(%{is_won: true, is_closed: true, stage: :closed_won}),
        make_opp(%{is_won: true, is_closed: true, stage: :closed_won})
      ]

      assert {:ok, rate} = Pipeline.win_rate(opportunities: opps)
      assert rate == 1.0
    end

    test "returns 0.0 when all closed opportunities are lost" do
      opps = [lost_opp(), lost_opp(), lost_opp()]
      assert {:ok, rate} = Pipeline.win_rate(opportunities: opps)
      assert rate == 0.0
    end

    test "returns correct fractional win rate for mixed closed set" do
      # 2 won, 1 lost → 2/3 = 0.6667
      opps = [
        make_opp(%{is_won: true, is_closed: true, stage: :closed_won}),
        make_opp(%{is_won: true, is_closed: true, stage: :closed_won}),
        lost_opp()
      ]

      assert {:ok, rate} = Pipeline.win_rate(opportunities: opps)
      assert_in_delta rate, 2 / 3, 0.001
    end

    test "ignores open opportunities in win rate denominator" do
      opps = [
        make_opp(%{is_won: true, is_closed: true, stage: :closed_won}),
        # open — should not count
        make_opp(%{stage: :proposal}),
        lost_opp()
      ]

      assert {:ok, rate} = Pipeline.win_rate(opportunities: opps)
      # 1 won, 1 lost → 0.5
      assert_in_delta rate, 0.5, 0.001
    end

    test "accepts stage-based closed_won detection without is_closed flag" do
      opps = [make_opp(%{stage: :closed_won, is_won: false, is_closed: false})]
      assert {:ok, rate} = Pipeline.win_rate(opportunities: opps)
      assert rate == 1.0
    end

    test "win_rate is between 0.0 and 1.0 (inclusive)" do
      opps = [
        make_opp(%{is_won: true, is_closed: true}),
        make_opp(%{is_won: false, is_closed: true})
      ]

      assert {:ok, rate} = Pipeline.win_rate(opportunities: opps)
      assert rate >= 0.0 and rate <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # describe conversion_rates/1
  # ---------------------------------------------------------------------------

  describe "conversion_rates/1" do
    test "returns 6 stage pairs for standard funnel when no data" do
      assert {:ok, rates} = Pipeline.conversion_rates(opportunities: [])
      # prospecting→qualification, qualification→needs_analysis, …, negotiation→closed_won
      assert length(rates) == 6
    end

    test "falls back to empirical defaults when no opportunities provided" do
      assert {:ok, rates} = Pipeline.conversion_rates(opportunities: [])
      rate_map = Map.new(rates, fn r -> {{r.from_stage, r.to_stage}, r.rate} end)

      assert rate_map[{:prospecting, :qualification}] == 0.60
      assert rate_map[{:negotiation, :closed_won}] == 0.55
    end

    test "all sample_sizes are 0 when no opportunities provided" do
      assert {:ok, rates} = Pipeline.conversion_rates(opportunities: [])
      assert Enum.all?(rates, fn r -> r.sample_size == 0 end)
    end

    test "conversion rate from prospecting to qualification is 1.0 when all opps are at least qualification" do
      opps =
        Enum.map(1..5, fn _ ->
          make_opp(%{stage: :qualification})
        end)

      assert {:ok, rates} = Pipeline.conversion_rates(opportunities: opps)
      rate_entry = Enum.find(rates, fn r -> r.from_stage == :prospecting end)

      # All 5 reached qualification (>=prospecting), so prospecting→qualification = 5/5 = 1.0
      assert rate_entry.rate == 1.0
    end

    test "each rate entry has required keys" do
      assert {:ok, [first | _]} = Pipeline.conversion_rates(opportunities: [])
      assert Map.has_key?(first, :from_stage)
      assert Map.has_key?(first, :to_stage)
      assert Map.has_key?(first, :rate)
      assert Map.has_key?(first, :sample_size)
    end

    test "conversion rate for a stage is <= 1.0 when data is present" do
      opps = [
        make_opp(%{stage: :prospecting}),
        make_opp(%{stage: :qualification}),
        make_opp(%{stage: :proposal})
      ]

      assert {:ok, rates} = Pipeline.conversion_rates(opportunities: opps)
      assert Enum.all?(rates, fn r -> r.rate <= 1.0 end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe sales_velocity/1
  # ---------------------------------------------------------------------------

  describe "sales_velocity/1" do
    test "returns zero velocity when no opportunities" do
      assert {:ok, result} = Pipeline.sales_velocity(opportunities: [])
      assert Decimal.equal?(result.velocity, Decimal.new("0.00"))
      assert result.opportunities == 0
      assert result.win_rate == 0.0
    end

    test "returns zero velocity when no closed-won opportunities" do
      opps = [make_opp(%{}), make_opp(%{})]
      assert {:ok, result} = Pipeline.sales_velocity(opportunities: opps)
      assert Decimal.equal?(result.velocity, Decimal.new("0.00"))
    end

    test "calculates velocity with one closed-won opportunity with timestamps" do
      inserted = ~U[2026-01-01 00:00:00Z]
      closed = ~U[2026-02-10 00:00:00Z]
      # 40 days cycle

      opps = [
        won_opp("100000.00", inserted, closed),
        # open
        make_opp(%{})
      ]

      assert {:ok, result} = Pipeline.sales_velocity(opportunities: opps)
      assert Decimal.gt?(result.velocity, Decimal.new("0"))
      assert result.win_rate > 0.0
      assert result.avg_sales_cycle_days > 0
    end

    test "falls back to 30-day cycle when closed_at timestamps are missing" do
      opps = [
        make_opp(%{is_won: true, is_closed: true, amount: Decimal.new("50000.00")})
      ]

      assert {:ok, result} = Pipeline.sales_velocity(opportunities: opps)
      # avg_sales_cycle_days falls back to 30 when no timestamps
      assert result.avg_sales_cycle_days == 30
    end

    test "result map has all required keys" do
      assert {:ok, result} = Pipeline.sales_velocity(opportunities: [])
      assert Map.has_key?(result, :velocity)
      assert Map.has_key?(result, :opportunities)
      assert Map.has_key?(result, :win_rate)
      assert Map.has_key?(result, :avg_deal_size)
      assert Map.has_key?(result, :avg_sales_cycle_days)
      assert Map.has_key?(result, :period_days)
    end

    test "period_days defaults to 90" do
      assert {:ok, result} = Pipeline.sales_velocity(opportunities: [])
      assert result.period_days == 90
    end

    test "respects custom period_days option" do
      assert {:ok, result} = Pipeline.sales_velocity(opportunities: [], period_days: 180)
      assert result.period_days == 180
    end

    test "avg_deal_size is Decimal struct" do
      opps = [won_opp("75000.00", ~U[2026-01-01 00:00:00Z], ~U[2026-02-01 00:00:00Z])]
      assert {:ok, result} = Pipeline.sales_velocity(opportunities: opps)
      assert is_struct(result.avg_deal_size, Decimal)
    end
  end

  # ---------------------------------------------------------------------------
  # describe pipeline_summary/1 — smoke test (DB-backed, graceful fallback)
  # ---------------------------------------------------------------------------

  describe "pipeline_summary/1" do
    test "returns {:ok, summary} with required keys even when Repo returns empty" do
      # build_pipeline_query + calculate_stage_metrics falls back to [] on Repo error
      assert {:ok, summary} = Pipeline.pipeline_summary([])
      assert Map.has_key?(summary, :total_pipeline)
      assert Map.has_key?(summary, :weighted_pipeline)
      assert Map.has_key?(summary, :by_stage)
      assert Map.has_key?(summary, :opportunity_count)
      assert Map.has_key?(summary, :average_deal_size)
      assert Map.has_key?(summary, :generated_at)
    end

    test "total_pipeline is non-negative Decimal when Repo returns empty" do
      assert {:ok, summary} = Pipeline.pipeline_summary([])
      assert Decimal.compare(summary.total_pipeline, Decimal.new("0")) in [:eq, :gt]
    end

    test "opportunity_count is 0 when Repo returns empty" do
      assert {:ok, summary} = Pipeline.pipeline_summary([])
      assert summary.opportunity_count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property — win_rate always in [0.0, 1.0]
  # ---------------------------------------------------------------------------

  property "win_rate is always in [0.0, 1.0] for any mixture of closed opportunities" do
    forall {won_count, lost_count} <-
             {PC.non_neg_integer(), PC.non_neg_integer()} do
      won_opps =
        List.duplicate(make_opp(%{is_won: true, is_closed: true, stage: :closed_won}), won_count)

      lost_opps = List.duplicate(lost_opp(), lost_count)
      opps = won_opps ++ lost_opps

      {:ok, rate} = Pipeline.win_rate(opportunities: opps)
      rate >= 0.0 and rate <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property — conversion rates always in [0.0, 1.0]
  # ---------------------------------------------------------------------------

  test "conversion_rates all rates are in [0.0, 1.0] for any stage distribution (StreamData)" do
    stage_order = [
      :prospecting,
      :qualification,
      :needs_analysis,
      :value_proposition,
      :proposal,
      :negotiation,
      :closed_won
    ]

    ExUnitProperties.check all(
                             stages <-
                               SD.list_of(SD.member_of(stage_order),
                                 min_length: 0,
                                 max_length: 30
                               )
                           ) do
      opps = Enum.map(stages, fn s -> make_opp(%{stage: s}) end)
      assert {:ok, rates} = Pipeline.conversion_rates(opportunities: opps)
      assert Enum.all?(rates, fn r -> r.rate >= 0.0 and r.rate <= 1.0 end)
    end
  end
end
