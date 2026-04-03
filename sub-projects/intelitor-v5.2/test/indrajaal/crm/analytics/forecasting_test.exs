defmodule Indrajaal.Crm.Analytics.ForecastingTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Crm.Analytics.Forecasting.

  Sprint 54 — 100% module coverage.

  ## STAMP Compliance
  - SC-COV-001: Module coverage
  - SC-PRF-050: Response time < 50ms
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Crm.Analytics.Forecasting
  alias Indrajaal.Crm.Analytics.Forecasting.Forecast

  @moduletag :zenoh_nif

  describe "module existence" do
    test "Forecasting module is loaded" do
      assert Code.ensure_loaded?(Forecasting)
    end

    test "Forecast struct module is loaded" do
      assert Code.ensure_loaded?(Forecast)
    end
  end

  describe "get_forecast/2" do
    test "returns {:ok, %Forecast{}} for valid inputs" do
      result = Forecasting.get_forecast("user-1", {:quarter, 2026, 1})
      assert {:ok, %Forecast{}} = result
    end

    test "forecast has correct user_id" do
      {:ok, forecast} = Forecasting.get_forecast("user-42", {:quarter, 2026, 2})
      assert forecast.user_id == "user-42"
    end

    test "forecast has correct period" do
      {:ok, forecast} = Forecasting.get_forecast("user-1", {:quarter, 2026, 3})
      assert forecast.period == {:quarter, 2026, 3}
    end

    test "pipeline, best_case, commit, closed are Decimals" do
      {:ok, forecast} = Forecasting.get_forecast("user-1", {:quarter, 2026, 1})
      assert %Decimal{} = forecast.pipeline
      assert %Decimal{} = forecast.best_case
      assert %Decimal{} = forecast.commit
      assert %Decimal{} = forecast.closed
    end
  end

  describe "rollup_forecast/2" do
    test "returns {:ok, map()} for valid manager" do
      result = Forecasting.rollup_forecast("mgr-1", {:quarter, 2026, 1})
      assert {:ok, %{manager_id: "mgr-1"}} = result
    end

    test "rollup includes period" do
      {:ok, rollup} = Forecasting.rollup_forecast("mgr-1", {:quarter, 2026, 2})
      assert rollup.period == {:quarter, 2026, 2}
    end

    test "rollup aggregates are Decimals" do
      {:ok, rollup} = Forecasting.rollup_forecast("mgr-1", {:quarter, 2026, 1})
      assert %Decimal{} = rollup.total_quota
      assert %Decimal{} = rollup.total_pipeline
    end
  end

  describe "adjust_forecast/3" do
    test "returns error for nil forecast_id" do
      assert {:error, :invalid_forecast_id} =
               Forecasting.adjust_forecast(nil, "mgr-1", %{adjusted_amount: Decimal.new("100")})
    end

    test "returns error for missing adjusted_amount" do
      assert {:error, :missing_adjusted_amount} =
               Forecasting.adjust_forecast("fc-1", "mgr-1", %{})
    end

    test "returns error for non-Decimal adjusted_amount" do
      assert {:error, :invalid_adjusted_amount} =
               Forecasting.adjust_forecast("fc-1", "mgr-1", %{adjusted_amount: 100})
    end

    test "succeeds with valid Decimal amount" do
      amount = Decimal.new("300000.00")

      assert {:ok, %Forecast{adjusted_by_manager: ^amount}} =
               Forecasting.adjust_forecast("fc-1", "mgr-1", %{
                 adjusted_amount: amount,
                 notes: "Test"
               })
    end
  end

  describe "forecast_accuracy/2" do
    test "returns {:ok, []} with no history" do
      assert {:ok, []} = Forecasting.forecast_accuracy("user-1")
    end

    test "calculates accuracy from supplied history" do
      history = [
        %{
          period: {:quarter, 2025, 4},
          forecasted: Decimal.new("500"),
          actual: Decimal.new("400")
        }
      ]

      {:ok, [entry]} = Forecasting.forecast_accuracy("user-1", history: history)
      assert entry.accuracy == 80.0
    end

    test "respects last_n_quarters option" do
      history =
        Enum.map(1..10, fn i ->
          %{
            period: {:quarter, 2025, rem(i, 4) + 1},
            forecasted: Decimal.new("100"),
            actual: Decimal.new("90")
          }
        end)

      {:ok, results} =
        Forecasting.forecast_accuracy("user-1", history: history, last_n_quarters: 3)

      assert length(results) == 3
    end
  end

  describe "Forecast struct" do
    test "has all expected fields" do
      forecast = %Forecast{}
      assert Map.has_key?(forecast, :user_id)
      assert Map.has_key?(forecast, :period)
      assert Map.has_key?(forecast, :quota)
      assert Map.has_key?(forecast, :pipeline)
      assert Map.has_key?(forecast, :best_case)
      assert Map.has_key?(forecast, :commit)
      assert Map.has_key?(forecast, :closed)
      assert Map.has_key?(forecast, :adjusted_by_manager)
      assert Map.has_key?(forecast, :attainment_percent)
      assert Map.has_key?(forecast, :gap_to_quota)
    end
  end
end
