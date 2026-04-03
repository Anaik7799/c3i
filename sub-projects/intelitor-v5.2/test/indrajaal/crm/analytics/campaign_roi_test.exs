defmodule Indrajaal.Crm.Analytics.CampaignRoiTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Crm.Analytics.CampaignRoi.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation gaps addressed
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-PRF-050: Response time < 50ms for metrics queries
  - SC-HOLON-007: DuckDB for campaign history and trend analysis
  - SC-OBS-069: Dual logging (Terminal + Zenoh)

  ## Constitutional Verification
  - Ψ₀ Existence: Campaign metrics functions never crash callers
  - Ψ₅ Truthfulness: Attribution credits always sum to 1.0 (or 0.0 for empty)

  ## Founder's Directive Alignment
  - Ω₀.1: Campaign ROI analytics enables optimal resource allocation
  - Ω₀.7: Power accumulation through marketing effectiveness

  ## TPS 5-Level RCA Context
  - L1 Symptom: Campaign ROI shows incorrect or missing values
  - L5 Root Cause: Division-by-zero in percentage/cost calculations (FMEA RPN 192)
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Analytics.CampaignRoi

  @moduletag :zenoh_nif

  # Attribution model atoms
  @all_models [:first_touch, :last_touch, :linear, :time_decay, :u_shaped]

  # ============================================================
  # 1. campaign_metrics/1 — CONTRACT TESTS
  # ============================================================

  describe "campaign_metrics/1 return contract" do
    test "returns :ok tuple for a valid campaign_id" do
      assert {:ok, _} = CampaignRoi.campaign_metrics("campaign-001")
    end

    test "returned metrics has all required keys" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("campaign-002")

      required_keys = [
        :campaign_id,
        :campaign_name,
        :total_members,
        :responses,
        :response_rate,
        :leads_generated,
        :opportunities_created,
        :deals_won,
        :revenue_generated,
        :actual_cost,
        :cost_per_lead,
        :cost_per_opportunity,
        :cost_per_won,
        :roi_percent,
        :conversion_rate
      ]

      for key <- required_keys do
        assert Map.has_key?(metrics, key), "Missing key :#{key} in campaign_metrics result"
      end
    end

    test "campaign_id in result matches input" do
      id = "campaign-abc"
      {:ok, metrics} = CampaignRoi.campaign_metrics(id)
      assert metrics.campaign_id == id
    end

    test "campaign_name is a non-empty string" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("campaign-003")
      assert is_binary(metrics.campaign_name) and metrics.campaign_name != ""
    end

    test "total_members is a non-negative integer" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c1")
      assert is_integer(metrics.total_members)
      assert metrics.total_members >= 0
    end

    test "responses is a non-negative integer" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c2")
      assert is_integer(metrics.responses)
      assert metrics.responses >= 0
    end

    test "response_rate is a float in [0.0, 100.0]" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c3")
      assert is_float(metrics.response_rate)
      assert metrics.response_rate >= 0.0
      assert metrics.response_rate <= 100.0
    end

    test "leads_generated is a non-negative integer" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c4")
      assert is_integer(metrics.leads_generated)
      assert metrics.leads_generated >= 0
    end

    test "opportunities_created is a non-negative integer" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c5")
      assert is_integer(metrics.opportunities_created)
      assert metrics.opportunities_created >= 0
    end

    test "deals_won is a non-negative integer" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c6")
      assert is_integer(metrics.deals_won)
      assert metrics.deals_won >= 0
    end

    test "revenue_generated is a Decimal" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c7")
      assert %Decimal{} = metrics.revenue_generated
    end

    test "actual_cost is a Decimal" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c8")
      assert %Decimal{} = metrics.actual_cost
    end

    test "cost_per_lead is a Decimal" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c9")
      assert %Decimal{} = metrics.cost_per_lead
    end

    test "cost_per_opportunity is a Decimal" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c10")
      assert %Decimal{} = metrics.cost_per_opportunity
    end

    test "cost_per_won is a Decimal" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c11")
      assert %Decimal{} = metrics.cost_per_won
    end

    test "roi_percent is a float" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c12")
      assert is_float(metrics.roi_percent)
    end

    test "conversion_rate is a float in [0.0, 100.0]" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("c13")
      assert is_float(metrics.conversion_rate)
      assert metrics.conversion_rate >= 0.0
      assert metrics.conversion_rate <= 100.0
    end
  end

  # ============================================================
  # 2. ZERO-DIVISION SAFETY (FMEA: RPN 192)
  # ============================================================

  describe "zero-division safety (FMEA RPN 192)" do
    test "response_rate is 0.0 when total_members is 0" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("zero-members")
      # Placeholder stub returns member_count: 0, so response_rate must be 0.0
      if metrics.total_members == 0 do
        assert metrics.response_rate == 0.0
      end
    end

    test "cost_per_lead is Decimal 0 when leads_generated is 0" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("zero-leads")

      if metrics.leads_generated == 0 do
        assert Decimal.compare(metrics.cost_per_lead, Decimal.new(0)) == :eq
      end
    end

    test "cost_per_opportunity is Decimal 0 when opportunities_created is 0" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("zero-opps")

      if metrics.opportunities_created == 0 do
        assert Decimal.compare(metrics.cost_per_opportunity, Decimal.new(0)) == :eq
      end
    end

    test "cost_per_won is Decimal 0 when deals_won is 0" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("zero-won")

      if metrics.deals_won == 0 do
        assert Decimal.compare(metrics.cost_per_won, Decimal.new(0)) == :eq
      end
    end

    test "roi_percent is 0.0 when actual_cost is 0" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("zero-cost")

      if Decimal.compare(metrics.actual_cost, Decimal.new(0)) == :eq do
        assert metrics.roi_percent == 0.0
      end
    end

    test "conversion_rate is 0.0 when responses is 0" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("zero-responses")

      if metrics.responses == 0 do
        assert metrics.conversion_rate == 0.0
      end
    end
  end

  # ============================================================
  # 3. multi_touch_attribution/2 — ALL MODELS
  # ============================================================

  describe "multi_touch_attribution/2 — all attribution models" do
    for model <- [:first_touch, :last_touch, :linear, :time_decay, :u_shaped] do
      @model model
      test "#{model} model returns :ok tuple" do
        assert {:ok, _} = CampaignRoi.multi_touch_attribution("opp-001", @model)
      end

      test "#{model} model returns a list" do
        {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-001", @model)
        assert is_list(attribution)
      end

      test "#{model} model: each attributed touch has :credit key" do
        {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-001", @model)

        for touch <- attribution do
          assert Map.has_key?(touch, :credit),
                 "Touch missing :credit key under #{@model}: #{inspect(touch)}"
        end
      end

      test "#{model} model: credit values are floats between 0 and 1" do
        {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-001", @model)

        for touch <- attribution do
          assert is_float(touch.credit),
                 "credit must be a float, got #{inspect(touch.credit)}"

          assert touch.credit >= 0.0 and touch.credit <= 1.0,
                 "credit #{touch.credit} out of [0,1] range"
        end
      end
    end

    test "default model (no model arg) returns :ok" do
      assert {:ok, _} = CampaignRoi.multi_touch_attribution("opp-default")
    end

    test "unknown model falls back gracefully" do
      assert {:ok, _} = CampaignRoi.multi_touch_attribution("opp-001", :unknown_model)
    end
  end

  describe "multi_touch_attribution/2 — credit sum invariant (Ψ₅)" do
    test "first_touch: single touch gets credit 1.0" do
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-ft", :first_touch)

      # first_touch returns only the first touch with credit 1.0
      if length(attribution) > 0 do
        first = List.first(attribution)
        assert_in_delta first.credit, 1.0, 0.001
      end
    end

    test "last_touch: last touch gets credit 1.0" do
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-lt", :last_touch)

      if length(attribution) > 0 do
        last = List.last(attribution)
        assert_in_delta last.credit, 1.0, 0.001
      end
    end

    test "linear: all credits are equal" do
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-lin", :linear)
      count = length(attribution)

      if count > 0 do
        expected = 1.0 / count

        for touch <- attribution do
          assert_in_delta touch.credit,
                          expected,
                          0.001,
                          "Expected linear credit #{expected}, got #{touch.credit}"
        end
      end
    end

    test "linear: credits sum to 1.0 (or 0.0 for empty)" do
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-lin-sum", :linear)
      total = Enum.reduce(attribution, 0.0, fn t, acc -> acc + t.credit end)

      if length(attribution) > 0 do
        assert_in_delta total, 1.0, 0.001, "Linear credits should sum to 1.0, got #{total}"
      else
        assert total == 0.0
      end
    end

    test "time_decay: credits sum to 1.0 for non-empty result" do
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-td", :time_decay)
      total = Enum.reduce(attribution, 0.0, fn t, acc -> acc + t.credit end)

      if length(attribution) > 0 do
        assert_in_delta total, 1.0, 0.01, "Time decay credits should sum to 1.0, got #{total}"
      end
    end

    test "u_shaped: credits sum to 1.0 for non-empty result" do
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-us", :u_shaped)
      total = Enum.reduce(attribution, 0.0, fn t, acc -> acc + t.credit end)

      if length(attribution) > 0 do
        assert_in_delta total, 1.0, 0.01, "U-shaped credits should sum to 1.0, got #{total}"
      end
    end

    test "u_shaped with 2 touches: first and last get 0.40 each" do
      # The placeholder returns exactly 2 touches, so this is deterministic
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("opp-us-2t", :u_shaped)

      if length(attribution) == 2 do
        [first, last] = attribution
        assert_in_delta first.credit, 0.40, 0.001
        assert_in_delta last.credit, 0.40, 0.001
      end
    end
  end

  # ============================================================
  # 4. compare_campaigns/1
  # ============================================================

  describe "compare_campaigns/1" do
    test "returns :ok tuple for list of campaign IDs" do
      assert {:ok, _} = CampaignRoi.compare_campaigns(["c1", "c2", "c3"])
    end

    test "returns :ok for empty list" do
      assert {:ok, _} = CampaignRoi.compare_campaigns([])
    end

    test "result has required comparison keys" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["c1", "c2"])

      assert Map.has_key?(comparison, :campaigns)
      assert Map.has_key?(comparison, :best_roi)
      assert Map.has_key?(comparison, :best_response_rate)
      assert Map.has_key?(comparison, :best_conversion)
      assert Map.has_key?(comparison, :generated_at)
    end

    test "campaigns key is a list" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["c1", "c2"])
      assert is_list(comparison.campaigns)
    end

    test "generated_at is a DateTime" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["c1"])
      assert %DateTime{} = comparison.generated_at
    end

    test "best_roi is nil or a campaign_id string" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["c1", "c2"])

      case comparison.best_roi do
        nil -> :ok
        id -> assert is_binary(id)
      end
    end

    test "best_response_rate is nil or a campaign_id string" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["c1", "c2"])

      case comparison.best_response_rate do
        nil -> :ok
        id -> assert is_binary(id)
      end
    end

    test "best_conversion is nil or a campaign_id string" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["c1", "c2"])

      case comparison.best_conversion do
        nil -> :ok
        id -> assert is_binary(id)
      end
    end

    test "single campaign comparison identifies it as best in all categories (when metrics exist)" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["only-camp"])

      if length(comparison.campaigns) == 1 do
        assert comparison.best_roi == "only-camp" or is_nil(comparison.best_roi)
      end
    end
  end

  # ============================================================
  # 5. CONSTITUTIONAL INVARIANTS (Ψ₀-Ψ₅)
  # ============================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence: campaign_metrics never raises for any string id" do
      for id <- ["", "a", "campaign-with-spaces and special!@#", String.duplicate("x", 500)] do
        result =
          try do
            CampaignRoi.campaign_metrics(id)
          rescue
            e -> {:rescued, e}
          end

        refute match?({:rescued, _}, result),
               "campaign_metrics raised for id=#{inspect(id)}: #{inspect(result)}"
      end
    end

    test "Ψ₀ existence: multi_touch_attribution never raises for any model" do
      for model <- @all_models do
        result =
          try do
            CampaignRoi.multi_touch_attribution("opp-psi0", model)
          rescue
            e -> {:rescued, e}
          end

        refute match?({:rescued, _}, result),
               "multi_touch_attribution raised for model=#{model}: #{inspect(result)}"
      end
    end

    test "Ψ₅ truthfulness: roi_percent cannot be negative when revenue >= cost > 0" do
      # With placeholder (cost=0, revenue=0), roi = 0.0 which is correct
      {:ok, metrics} = CampaignRoi.campaign_metrics("roi-truth")

      cost_zero = Decimal.compare(metrics.actual_cost, Decimal.new(0)) == :eq

      rev_gte_cost =
        Decimal.compare(metrics.revenue_generated, metrics.actual_cost) in [:gt, :eq]

      if not cost_zero and rev_gte_cost do
        assert metrics.roi_percent >= 0.0,
               "ROI should not be negative when revenue >= cost"
      end
    end

    test "Ψ₅ truthfulness: response_rate cannot exceed 100%" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("rate-truth")
      assert metrics.response_rate <= 100.0
    end

    test "Ψ₅ truthfulness: conversion_rate cannot exceed 100%" do
      {:ok, metrics} = CampaignRoi.campaign_metrics("conv-truth")
      assert metrics.conversion_rate <= 100.0
    end
  end

  # ============================================================
  # 6. PROPERTY TESTS
  # ============================================================

  property "campaign_metrics always returns :ok or :error (PropCheck)" do
    forall id_suffix <- PC.binary() do
      campaign_id = "prop-" <> Base.encode16(id_suffix, case: :lower)

      case CampaignRoi.campaign_metrics(campaign_id) do
        {:ok, _} -> true
        {:error, _} -> true
        other -> flunk("Unexpected: #{inspect(other)}")
      end
    end
  end

  test "response_rate in [0.0, 100.0] for any campaign (StreamData)" do
    ExUnitProperties.check all(id <- SD.string(:alphanumeric, min_length: 1, max_length: 20)) do
      case CampaignRoi.campaign_metrics(id) do
        {:ok, metrics} ->
          assert metrics.response_rate >= 0.0
          assert metrics.response_rate <= 100.0

        {:error, _} ->
          :ok
      end
    end
  end

  property "multi_touch_attribution credits are floats in [0,1] for all models (PropCheck)" do
    forall model <- PC.oneof([:first_touch, :last_touch, :linear, :time_decay, :u_shaped]) do
      case CampaignRoi.multi_touch_attribution("prop-opp", model) do
        {:ok, attribution} ->
          Enum.all?(attribution, fn t ->
            is_float(t.credit) and t.credit >= 0.0 and t.credit <= 1.0
          end)

        {:error, _} ->
          true
      end
    end
  end

  test "compare_campaigns returns ok or error for any list of ids (StreamData)" do
    ExUnitProperties.check all(
                             ids <-
                               SD.list_of(SD.string(:alphanumeric, min_length: 1, max_length: 15),
                                 max_length: 5
                               )
                           ) do
      result = CampaignRoi.compare_campaigns(ids)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  property "linear attribution: credit * n = 1.0 for n touches (PropCheck)" do
    # The placeholder always returns 2 touches, so linear gives 0.5 each
    forall _n <- PC.pos_integer() do
      case CampaignRoi.multi_touch_attribution("prop-lin-#{:rand.uniform(1000)}", :linear) do
        {:ok, attribution} when length(attribution) > 0 ->
          n = length(attribution)
          expected_credit = 1.0 / n

          Enum.all?(attribution, fn t ->
            abs(t.credit - expected_credit) < 0.001
          end)

        {:ok, []} ->
          true

        {:error, _} ->
          true
      end
    end
  end

  # ============================================================
  # 7. FMEA TESTS
  # ============================================================

  describe "FMEA: edge cases and failure recovery" do
    @tag :fmea
    test "campaign_metrics for duplicate IDs returns consistent result" do
      {:ok, m1} = CampaignRoi.campaign_metrics("duplicate")
      {:ok, m2} = CampaignRoi.campaign_metrics("duplicate")
      # Both should have the same shape (not necessarily same data if DB)
      assert Map.keys(m1) == Map.keys(m2)
    end

    @tag :fmea
    test "compare_campaigns with duplicate IDs is handled gracefully" do
      result = CampaignRoi.compare_campaigns(["dup", "dup", "dup"])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "compare_campaigns with single ID returns best_roi pointing to that ID or nil" do
      {:ok, comparison} = CampaignRoi.compare_campaigns(["solo"])
      # If metrics retrieved, best_roi must be the solo campaign or nil (on zero-cost)
      assert is_nil(comparison.best_roi) or comparison.best_roi == "solo"
    end

    @tag :fmea
    test "multi_touch_attribution for empty opportunity still returns :ok" do
      assert {:ok, _list} = CampaignRoi.multi_touch_attribution("empty-opp-99999")
    end

    @tag :fmea
    test "campaign_metrics is safe to call concurrently" do
      tasks =
        for i <- 1..10 do
          Task.async(fn -> CampaignRoi.campaign_metrics("concurrent-#{i}") end)
        end

      results = Task.await_many(tasks, 5_000)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               {:error, _} -> true
             end)
    end

    @tag :fmea
    test "time_decay: credit for older touch is <= credit for newer touch" do
      {:ok, attribution} = CampaignRoi.multi_touch_attribution("td-order", :time_decay)

      if length(attribution) >= 2 do
        # placeholder returns camp-1 (~D[2026-01-01]) then camp-2 (~D[2026-01-15])
        # camp-2 is more recent so should have higher credit
        [older | rest] = attribution
        newer = List.last(rest)

        assert newer.credit >= older.credit,
               "More recent touch should have >= credit: #{newer.credit} vs #{older.credit}"
      end
    end
  end
end
