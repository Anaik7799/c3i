defmodule Indrajaal.Crm.ForecastingTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Crm.Analytics.Forecasting.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written for pure analytic functions (no DB required)
  - FPPS Validation: Dual property testing (PropCheck + ExUnitProperties)

  ## STAMP Safety Integration
  - SC-PRF-050: Response time < 50ms for all forecast calculations
  - SC-COV-006: TDG compliance mandatory
  - SC-TDG-001: TDG validation before code gen

  ## Constitutional Verification
  - Ψ₀ Existence: Forecasting module returns valid structs under all inputs
  - Ψ₁ Regeneration: Forecast state is fully derivable from opportunity lists

  ## Founder's Directive Alignment
  - Ω₀.1: Revenue forecasting enables resource acquisition tracking
  - Ω₀.6: Accurate pipeline data fuels intelligence amplification

  ## TPS 5-Level RCA Context
  - L1 Symptom: Incorrect forecast amounts shown to sales reps
  - L5 Root Cause: Missing probability-threshold filtering in category sums

  ## Test Categories
  - Happy path for `adjust_forecast/3`
  - Happy path for `forecast_accuracy/2`
  - Happy path for `get_forecast/2` and `rollup_forecast/2` (struct shape)
  - Error/edge cases for adjust_forecast and forecast_accuracy
  - PropCheck property: accuracy is bounded [0.0, 100.0] for any positive inputs
  - StreamData property: adjust_forecast always returns :ok for valid Decimal amounts
  """

  use ExUnit.Case, async: true
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Analytics.Forecasting
  alias Indrajaal.Crm.Analytics.Forecasting.Forecast

  @moduletag :crm
  @moduletag :sprint_54

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp make_history_entry(period, forecasted_str, actual_str) do
    %{
      period: period,
      forecasted: Decimal.new(forecasted_str),
      actual: Decimal.new(actual_str)
    }
  end

  # ---------------------------------------------------------------------------
  # describe adjust_forecast/3
  # ---------------------------------------------------------------------------

  describe "adjust_forecast/3" do
    test "returns adjusted Forecast struct with valid Decimal amount" do
      forecast_id = "fc-001"
      manager_id = "mgr-001"
      amount = Decimal.new("300000.00")

      assert {:ok, %Forecast{} = result} =
               Forecasting.adjust_forecast(forecast_id, manager_id, %{
                 adjusted_amount: amount,
                 notes: "Adjusted down due to competitive pressure"
               })

      assert Decimal.equal?(result.adjusted_by_manager, amount)
      assert Decimal.equal?(result.forecast_override, amount)
      assert result.manager_notes == "Adjusted down due to competitive pressure"
    end

    test "reflects forecast_id as user_id in returned struct" do
      forecast_id = "fc-xyz-123"

      assert {:ok, result} =
               Forecasting.adjust_forecast(forecast_id, "mgr-002", %{
                 adjusted_amount: Decimal.new("50000.00")
               })

      assert result.user_id == forecast_id
    end

    test "returns :ok with nil notes when notes key is absent from adjustments" do
      assert {:ok, result} =
               Forecasting.adjust_forecast("fc-003", "mgr-003", %{
                 adjusted_amount: Decimal.new("100000.00")
               })

      assert is_nil(result.manager_notes)
    end

    test "returns error when forecast_id is nil" do
      assert {:error, :invalid_forecast_id} =
               Forecasting.adjust_forecast(nil, "mgr-001", %{
                 adjusted_amount: Decimal.new("100000.00")
               })
    end

    test "returns error when adjusted_amount key is missing from adjustments" do
      assert {:error, :missing_adjusted_amount} =
               Forecasting.adjust_forecast("fc-004", "mgr-001", %{notes: "some note"})
    end

    test "returns error when adjusted_amount is an integer, not a Decimal struct" do
      assert {:error, :invalid_adjusted_amount} =
               Forecasting.adjust_forecast("fc-005", "mgr-001", %{
                 adjusted_amount: 100_000
               })
    end

    test "returns error when adjusted_amount is a float instead of a Decimal struct" do
      assert {:error, :invalid_adjusted_amount} =
               Forecasting.adjust_forecast("fc-006", "mgr-001", %{
                 adjusted_amount: 100_000.0
               })
    end
  end

  # ---------------------------------------------------------------------------
  # describe forecast_accuracy/2
  # ---------------------------------------------------------------------------

  describe "forecast_accuracy/2" do
    test "returns empty list when no history keyword is provided" do
      assert {:ok, []} = Forecasting.forecast_accuracy("user-001")
    end

    test "returns empty list when history keyword is explicitly empty list" do
      assert {:ok, []} = Forecasting.forecast_accuracy("user-001", history: [])
    end

    test "computes 100.0 accuracy for a perfectly-forecasted single entry" do
      history = [make_history_entry({:quarter, 2025, 4}, "500000", "500000")]

      assert {:ok, [entry]} = Forecasting.forecast_accuracy("user-001", history: history)
      assert entry.accuracy == 100.0
      assert Decimal.equal?(entry.variance, Decimal.new("0"))
    end

    test "accuracy is capped at 100.0 when actual exceeds forecasted" do
      history = [make_history_entry({:quarter, 2025, 3}, "400000", "600000")]

      assert {:ok, [entry]} = Forecasting.forecast_accuracy("user-002", history: history)
      assert entry.accuracy <= 100.0
    end

    test "accuracy is 0.0 when forecasted amount is zero" do
      history = [make_history_entry({:quarter, 2025, 2}, "0", "50000")]

      assert {:ok, [entry]} = Forecasting.forecast_accuracy("user-003", history: history)
      assert entry.accuracy == 0.0
    end

    test "respects last_n_quarters limit and truncates history to that count" do
      history =
        Enum.map(1..6, fn q ->
          make_history_entry({:quarter, 2025, rem(q - 1, 4) + 1}, "100000", "90000")
        end)

      assert {:ok, results} =
               Forecasting.forecast_accuracy("user-004", history: history, last_n_quarters: 2)

      assert length(results) == 2
    end

    test "returns all entries when history count is below default last_n_quarters" do
      history = [
        make_history_entry({:quarter, 2025, 1}, "300000", "270000"),
        make_history_entry({:quarter, 2025, 2}, "350000", "340000")
      ]

      assert {:ok, results} = Forecasting.forecast_accuracy("user-005", history: history)
      assert length(results) == 2
    end

    test "variance is negative when actual falls short of forecast" do
      history = [make_history_entry({:quarter, 2025, 4}, "500000", "400000")]

      assert {:ok, [entry]} = Forecasting.forecast_accuracy("user-006", history: history)
      assert Decimal.lt?(entry.variance, Decimal.new("0"))
    end

    test "each result map contains the five required keys" do
      history = [make_history_entry({:quarter, 2026, 1}, "250000", "240000")]

      assert {:ok, [entry]} = Forecasting.forecast_accuracy("user-007", history: history)
      assert Map.has_key?(entry, :period)
      assert Map.has_key?(entry, :forecasted)
      assert Map.has_key?(entry, :actual)
      assert Map.has_key?(entry, :accuracy)
      assert Map.has_key?(entry, :variance)
    end
  end

  # ---------------------------------------------------------------------------
  # describe get_forecast/2 — struct shape (no quota available in test env)
  # ---------------------------------------------------------------------------

  describe "get_forecast/2 struct shape" do
    test "returns Forecast struct with correct user_id and period" do
      user_id = "u-#{System.unique_integer([:positive])}"
      period = {:quarter, 2026, 1}

      assert {:ok, %Forecast{} = forecast} = Forecasting.get_forecast(user_id, period)
      assert forecast.user_id == user_id
      assert forecast.period == period
    end

    test "pipeline, best_case, commit, closed are all Decimal structs" do
      {:ok, forecast} = Forecasting.get_forecast("u-100", {:quarter, 2026, 2})

      assert is_struct(forecast.pipeline, Decimal)
      assert is_struct(forecast.best_case, Decimal)
      assert is_struct(forecast.commit, Decimal)
      assert is_struct(forecast.closed, Decimal)
    end

    test "attainment_percent is 0.0 when no quota is found" do
      # Quota resource is not reachable without the DB sandbox
      {:ok, forecast} = Forecasting.get_forecast("u-200", {:year, 2026})
      assert forecast.attainment_percent == 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # describe rollup_forecast/2 — struct shape (no direct reports in test env)
  # ---------------------------------------------------------------------------

  describe "rollup_forecast/2 struct shape" do
    test "returns rollup map with correct manager_id and zero-value Decimal totals" do
      manager_id = "mgr-#{System.unique_integer([:positive])}"
      period = {:quarter, 2026, 1}

      assert {:ok, rollup} = Forecasting.rollup_forecast(manager_id, period)
      assert rollup.manager_id == manager_id
      assert is_struct(rollup.total_quota, Decimal)
      assert is_struct(rollup.total_pipeline, Decimal)
      assert rollup.rep_count == 0
    end

    test "team_attainment is 0.0 when manager has no direct reports" do
      {:ok, rollup} = Forecasting.rollup_forecast("mgr-zero", {:quarter, 2026, 3})
      assert rollup.team_attainment == 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property: accuracy is always in [0.0, 100.0]
  # ---------------------------------------------------------------------------

  property "forecast_accuracy result accuracy is always between 0.0 and 100.0 (PropCheck)" do
    forall {forecasted_int, actual_int} <-
             {PC.pos_integer(), PC.non_neg_integer()} do
      forecasted = Decimal.new(forecasted_int)
      actual = Decimal.new(actual_int)
      history = [%{period: {:quarter, 2025, 1}, forecasted: forecasted, actual: actual}]

      {:ok, [entry]} = Forecasting.forecast_accuracy("prop-user", history: history)
      entry.accuracy >= 0.0 and entry.accuracy <= 100.0
    end
  end

  # ---------------------------------------------------------------------------
  # StreamData property: adjust_forecast always :ok for any positive Decimal amount
  # ---------------------------------------------------------------------------

  test "adjust_forecast returns :ok for any positive Decimal amount (StreamData)" do
    ExUnitProperties.check all(
                             cents <- SD.integer(1..100_000_000),
                             notes <-
                               SD.one_of([
                                 SD.constant(nil),
                                 SD.string(:alphanumeric, min_length: 1, max_length: 120)
                               ])
                           ) do
      amount = Decimal.new(cents)

      adjustments =
        if is_nil(notes),
          do: %{adjusted_amount: amount},
          else: %{adjusted_amount: amount, notes: notes}

      assert {:ok, result} = Forecasting.adjust_forecast("fc-prop", "mgr-prop", adjustments)
      assert Decimal.equal?(result.adjusted_by_manager, amount)
    end
  end
end
