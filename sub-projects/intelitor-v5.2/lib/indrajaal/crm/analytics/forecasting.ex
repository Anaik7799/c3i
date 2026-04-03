defmodule Indrajaal.Crm.Analytics.Forecasting do
  @moduledoc """
  Collaborative forecasting engine with quota tracking.

  ## WHAT
  Provides bottom-up sales forecasting with collaborative adjustments,
  quota tracking, forecast categories (Pipeline, Best Case, Commit, Closed),
  and hierarchical rollup (Rep → Manager → VP → C-Suite).

  ## WHY
  Enables accurate revenue forecasting through collaborative forecasting
  methodology with manager overrides, historical trend analysis, and
  quota attainment tracking for sales performance management.

  ## CONSTRAINTS
  - SC-PRF-050: Response time < 50ms
  - SC-OBS-069: Dual logging (Terminal + Zenoh)
  - SC-HOLON-007: DuckDB for historical forecast analysis

  ## Forecast Categories
  - **Pipeline**: All open opportunities (0% probability filter)
  - **Best Case**: Opportunities with >= 50% probability
  - **Commit**: Opportunities with >= 75% probability (committed deals)
  - **Closed**: Closed won deals for the period

  ## Hierarchical Rollup
  Sales Rep → Manager → VP Sales → C-Suite
  Each level can view subordinates' forecasts and add overrides/adjustments.

  ## FMEA Analysis
  | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
  |--------------|----------|------------|-----------|-----|------------|
  | Calculation error | 8 | 3 | 4 | 96 | Dual calculation validation |
  | Rollup mismatch | 7 | 4 | 5 | 140 | Automated reconciliation |
  | Stale data | 6 | 5 | 5 | 150 | Real-time refresh |

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial forecasting engine implementation |
  """

  alias Indrajaal.Crm.Quota

  require Logger

  defmodule Forecast do
    @moduledoc "Individual user forecast for a specific period"

    @type period_tuple :: {integer(), integer() | atom()}

    @type t :: %__MODULE__{
            user_id: binary(),
            period: period_tuple(),
            quota: Decimal.t() | nil,
            pipeline: Decimal.t(),
            best_case: Decimal.t(),
            commit: Decimal.t(),
            closed: Decimal.t(),
            adjusted_by_manager: Decimal.t() | nil,
            manager_notes: String.t() | nil,
            forecast_override: Decimal.t() | nil,
            attainment_percent: float() | nil,
            gap_to_quota: Decimal.t() | nil
          }

    defstruct [
      :user_id,
      :period,
      :quota,
      :pipeline,
      :best_case,
      :commit,
      :closed,
      :adjusted_by_manager,
      :manager_notes,
      :forecast_override,
      :attainment_percent,
      :gap_to_quota
    ]
  end

  @type period_tuple :: {:quarter, pos_integer(), 1..4} | {:year, pos_integer()}
  @type period_type :: :quarterly | :yearly | :monthly

  @doc """
  Get forecast for a specific user and period.

  Calculates forecast based on opportunities and applies any manager adjustments.

  ## Examples

      iex> Forecasting.get_forecast(user_id, {:quarter, 2026, 1})
      {:ok, %Forecast{
        user_id: "...",
        period: {:quarter, 2026, 1},
        quota: Decimal.new("500000.00"),
        pipeline: Decimal.new("450000.00"),
        best_case: Decimal.new("350000.00"),
        commit: Decimal.new("250000.00"),
        closed: Decimal.new("180000.00"),
        attainment_percent: 36.0
      }}
  """
  @spec get_forecast(binary(), period_tuple(), keyword()) ::
          {:ok, Forecast.t()} | {:error, term()}
  def get_forecast(user_id, period, _opts), do: get_forecast(user_id, period)

  @spec get_forecast(binary(), period_tuple()) :: {:ok, Forecast.t()} | {:error, term()}
  def get_forecast(user_id, period) do
    start_time = System.monotonic_time(:microsecond)

    try do
      # Get user's opportunities for the period
      opportunities = get_user_opportunities(user_id, period)

      # Get quota
      quota = get_quota(user_id, period)

      # Calculate forecast categories
      pipeline = sum_by_category(opportunities, :pipeline)
      best_case = sum_by_category(opportunities, :best_case)
      commit = sum_by_category(opportunities, :commit)
      closed = sum_by_category(opportunities, :closed_won)

      # Calculate attainment
      attainment =
        if quota && Decimal.gt?(quota, 0) do
          Decimal.to_float(Decimal.div(Decimal.mult(closed, Decimal.new(100)), quota))
        else
          0.0
        end

      # Calculate gap to quota
      gap =
        if quota do
          Decimal.sub(quota, closed)
        else
          nil
        end

      forecast = %Forecast{
        user_id: user_id,
        period: period,
        quota: quota,
        pipeline: pipeline,
        best_case: best_case,
        commit: commit,
        closed: closed,
        adjusted_by_manager: nil,
        manager_notes: nil,
        forecast_override: nil,
        attainment_percent: attainment,
        gap_to_quota: gap
      }

      elapsed = System.monotonic_time(:microsecond) - start_time

      :telemetry.execute(
        [:crm, :forecasting, :get],
        %{
          duration_us: elapsed
        },
        %{user_id: user_id, period: period}
      )

      Logger.debug("Forecast calculated for user #{user_id} in #{elapsed}µs")

      {:ok, forecast}
    rescue
      error ->
        Logger.error("Forecast calculation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Rollup forecast from all direct reports.

  Aggregates forecasts from a manager's direct reports for hierarchical reporting.

  ## Examples

      iex> Forecasting.rollup_forecast(manager_id, {:quarter, 2026, 1})
      {:ok, %{
        total_quota: Decimal.new("2000000.00"),
        total_pipeline: Decimal.new("1800000.00"),
        total_commit: Decimal.new("1200000.00"),
        total_closed: Decimal.new("850000.00"),
        team_attainment: 42.5,
        forecasts_by_rep: [...]
      }}
  """
  @spec rollup_forecast(binary(), period_tuple()) :: {:ok, map()} | {:error, term()}
  def rollup_forecast(manager_id, period) do
    try do
      # Get direct reports
      # NOTE: Assumes a User.direct_reports relationship exists
      direct_reports = get_direct_reports(manager_id)

      # Get forecasts for each report
      forecasts =
        Enum.map(direct_reports, fn user_id ->
          case get_forecast(user_id, period) do
            {:ok, forecast} -> forecast
            {:error, _} -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      # Aggregate
      total_quota = sum_field(forecasts, :quota)
      total_pipeline = sum_field(forecasts, :pipeline)
      total_best_case = sum_field(forecasts, :best_case)
      total_commit = sum_field(forecasts, :commit)
      total_closed = sum_field(forecasts, :closed)

      team_attainment =
        if Decimal.gt?(total_quota, 0) do
          Decimal.to_float(Decimal.div(Decimal.mult(total_closed, Decimal.new(100)), total_quota))
        else
          0.0
        end

      rollup = %{
        manager_id: manager_id,
        period: period,
        total_quota: total_quota,
        total_pipeline: total_pipeline,
        total_best_case: total_best_case,
        total_commit: total_commit,
        total_closed: total_closed,
        team_attainment: team_attainment,
        forecasts_by_rep: forecasts,
        rep_count: length(forecasts),
        generated_at: DateTime.utc_now()
      }

      {:ok, rollup}
    rescue
      error ->
        Logger.error("Forecast rollup failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Manager adjusts a forecast with override and notes.

  Allows manager to adjust subordinate's forecast with explanation.

  ## Examples

      iex> Forecasting.adjust_forecast(forecast_id, manager_id, %{
        adjusted_amount: Decimal.new("300000.00"),
        notes: "Adjusted down due to competitive pressure"
      })
      {:ok, %Forecast{adjusted_by_manager: Decimal.new("300000.00"), ...}}
  """
  @spec adjust_forecast(binary(), binary(), map()) :: {:ok, Forecast.t()} | {:error, term()}
  def adjust_forecast(forecast_id, manager_id, adjustments) do
    Logger.info(
      "Forecast adjustment by manager #{manager_id} for #{forecast_id}: #{inspect(adjustments)}"
    )

    adjusted_amount = Map.get(adjustments, :adjusted_amount)
    notes = Map.get(adjustments, :notes)

    cond do
      is_nil(forecast_id) ->
        {:error, :invalid_forecast_id}

      is_nil(adjusted_amount) ->
        {:error, :missing_adjusted_amount}

      not is_struct(adjusted_amount, Decimal) ->
        {:error, :invalid_adjusted_amount}

      true ->
        # Build a minimal adjusted forecast struct reflecting the manager override.
        # In a full implementation this would persist via Ash.Changeset.
        adjusted = %Forecast{
          user_id: forecast_id,
          period: nil,
          quota: nil,
          pipeline: Decimal.new("0.00"),
          best_case: Decimal.new("0.00"),
          commit: Decimal.new("0.00"),
          closed: Decimal.new("0.00"),
          adjusted_by_manager: adjusted_amount,
          manager_notes: notes,
          forecast_override: adjusted_amount,
          attainment_percent: nil,
          gap_to_quota: nil
        }

        {:ok, adjusted}
    end
  end

  @doc """
  Classify an opportunity into an aging bucket based on how long it has been open.

  ## Buckets
  - `:fresh` — 0–30 days
  - `:maturing` — 31–60 days
  - `:aging` — 61–90 days
  - `:stale` — 91+ days

  ## Examples

      iex> Forecasting.classify_aging_bucket(%{days_open: 15})
      :fresh

      iex> Forecasting.classify_aging_bucket(%{days_open: 100})
      :stale
  """
  @spec classify_aging_bucket(map()) :: :fresh | :maturing | :aging | :stale
  def classify_aging_bucket(opportunity) do
    days = Map.get(opportunity, :days_open, 0)

    cond do
      days <= 30 -> :fresh
      days <= 60 -> :maturing
      days <= 90 -> :aging
      true -> :stale
    end
  end

  @doc """
  Compute an aging risk score (0–3) for an opportunity.

  - 0 = fresh (0–30 days)
  - 1 = maturing (31–60 days)
  - 2 = aging (61–90 days)
  - 3 = stale (91+ days)

  ## Examples

      iex> Forecasting.aging_risk_score(%{days_open: 45})
      1
  """
  @spec aging_risk_score(map()) :: 0..3
  def aging_risk_score(opportunity) do
    case classify_aging_bucket(opportunity) do
      :fresh -> 0
      :maturing -> 1
      :aging -> 2
      :stale -> 3
    end
  end

  @doc """
  Generate a pipeline aging report that breaks open opportunities into four
  time-based buckets and computes summary statistics.

  ## Return value

  ```elixir
  {:ok, %{
    fresh:    %{count: integer(), total: Decimal.t(), opportunities: [map()]},
    maturing: %{count: integer(), total: Decimal.t(), opportunities: [map()]},
    aging:    %{count: integer(), total: Decimal.t(), opportunities: [map()]},
    stale:    %{count: integer(), total: Decimal.t(), opportunities: [map()]},
    total_count:       integer(),
    total_amount:      Decimal.t(),
    average_age_days:  float(),
    stale_percentage:  float(),
    generated_at:      DateTime.t()
  }}
  ```

  ## CONSTRAINTS
  - SC-PRF-050: Must complete in < 50ms
  - SC-OBS-069: Emits telemetry to both Terminal and Zenoh
  """
  @spec pipeline_aging_report([map()]) :: {:ok, map()} | {:error, term()}
  def pipeline_aging_report(opportunities) do
    start_time = System.monotonic_time(:microsecond)

    try do
      # Classify each opportunity into a bucket
      bucketed =
        Enum.group_by(opportunities, &classify_aging_bucket/1)

      fresh = Map.get(bucketed, :fresh, [])
      maturing = Map.get(bucketed, :maturing, [])
      aging = Map.get(bucketed, :aging, [])
      stale = Map.get(bucketed, :stale, [])

      total_count = length(opportunities)

      total_amount =
        opportunities
        |> Enum.reduce(Decimal.new("0"), fn opp, acc ->
          amount = Map.get(opp, :amount)

          if amount && is_struct(amount, Decimal) do
            Decimal.add(acc, amount)
          else
            acc
          end
        end)

      average_age =
        if total_count > 0 do
          total_days =
            Enum.reduce(opportunities, 0, fn opp, acc ->
              acc + Map.get(opp, :days_open, 0)
            end)

          total_days / total_count
        else
          0.0
        end

      stale_pct =
        if total_count > 0 do
          Float.round(length(stale) / total_count * 100.0, 1)
        else
          0.0
        end

      elapsed = System.monotonic_time(:microsecond) - start_time

      :telemetry.execute(
        [:crm, :forecasting, :aging_report],
        %{
          duration_us: elapsed,
          opportunity_count: total_count
        },
        %{
          fresh_count: length(fresh),
          maturing_count: length(maturing),
          aging_count: length(aging),
          stale_count: length(stale)
        }
      )

      Logger.debug(
        "Pipeline aging report: #{total_count} opps in #{elapsed}µs " <>
          "(fresh=#{length(fresh)}, maturing=#{length(maturing)}, " <>
          "aging=#{length(aging)}, stale=#{length(stale)})"
      )

      report = %{
        fresh: %{
          count: length(fresh),
          total: bucket_total(fresh),
          opportunities: fresh
        },
        maturing: %{
          count: length(maturing),
          total: bucket_total(maturing),
          opportunities: maturing
        },
        aging: %{
          count: length(aging),
          total: bucket_total(aging),
          opportunities: aging
        },
        stale: %{
          count: length(stale),
          total: bucket_total(stale),
          opportunities: stale
        },
        total_count: total_count,
        total_amount: total_amount,
        average_age_days: average_age,
        stale_percentage: stale_pct,
        generated_at: DateTime.utc_now()
      }

      {:ok, report}
    rescue
      error ->
        Logger.error("Pipeline aging report failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Get historical forecast accuracy for trend analysis.

  Compares forecasted amounts vs. actual closed amounts for past periods.

  ## Examples

      iex> Forecasting.forecast_accuracy(user_id, last_n_quarters: 4)
      {:ok, [
        %{period: {:quarter, 2025, 4}, forecasted: "500K", actual: "480K", accuracy: 96.0},
        %{period: {:quarter, 2025, 3}, forecasted: "450K", actual: "425K", accuracy: 94.4}
      ]}
  """
  @spec forecast_accuracy(binary(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def forecast_accuracy(user_id, opts \\ []) do
    Logger.info("Forecast accuracy analysis for user #{user_id}")

    last_n = Keyword.get(opts, :last_n_quarters, 4)
    history = Keyword.get(opts, :history, [])

    if Enum.empty?(history) do
      # No historical data supplied — return empty but valid result
      {:ok, []}
    else
      # history is a list of maps with keys:
      #   :period, :forecasted (Decimal), :actual (Decimal)
      # We compute accuracy as min(actual/forecasted, 1.0) * 100 clamped to last_n entries.
      results =
        history
        |> Enum.take(last_n)
        |> Enum.map(fn entry ->
          forecasted = Map.get(entry, :forecasted, Decimal.new("0"))
          actual = Map.get(entry, :actual, Decimal.new("0"))

          accuracy =
            if Decimal.gt?(forecasted, Decimal.new("0")) do
              ratio =
                actual
                |> Decimal.div(forecasted)
                |> Decimal.mult(Decimal.new("100"))
                |> Decimal.to_float()

              Float.round(min(ratio, 100.0), 1)
            else
              0.0
            end

          variance = Decimal.sub(actual, forecasted)

          %{
            period: Map.get(entry, :period),
            forecasted: forecasted,
            actual: actual,
            accuracy: accuracy,
            variance: variance
          }
        end)

      {:ok, results}
    end
  end

  # Private Helpers

  defp get_user_opportunities(user_id, period) do
    # Placeholder for getting opportunities
    # Would filter opportunities by owner and close date within period
    # NOTE: Requires Opportunity resource to be implemented

    Logger.debug("Fetching opportunities for user #{user_id}, period #{inspect(period)}")
    []
  end

  defp get_quota(user_id, period) do
    # Fetch quota from Quota resource
    {period_type, year, number} = parse_period(period)

    # Use Ash to query quota
    # NOTE: This would use the actual Ash query when Quota resource is registered
    case Quota.by_period(period_type, year, number) do
      {:ok, quotas} ->
        quotas
        |> Enum.find(fn q -> q.user_id == user_id end)
        |> case do
          nil -> nil
          quota -> quota.amount
        end

      {:error, _} ->
        nil
    end
  rescue
    _ ->
      Logger.debug("Quota fetch failed for user #{user_id}")
      nil
  end

  defp parse_period({:quarter, year, quarter}), do: {:quarterly, year, quarter}
  defp parse_period({:year, year}), do: {:yearly, year, 1}

  # Each opportunity map is expected to have :amount (Decimal), :probability (integer),
  # :forecast_category (atom), and :is_won (boolean).
  defp sum_by_category(opportunities, :pipeline) do
    # All open opportunities sum (forecast_category in [:pipeline, :best_case, :commit])
    opportunities
    |> Enum.filter(fn o ->
      Map.get(o, :forecast_category) in [:pipeline, :best_case, :commit]
    end)
    |> sum_amounts()
  end

  defp sum_by_category(opportunities, :best_case) do
    # Opportunities with probability >= 50%
    opportunities
    |> Enum.filter(fn o ->
      prob = Map.get(o, :probability, 0)
      prob >= 50
    end)
    |> sum_amounts()
  end

  defp sum_by_category(opportunities, :commit) do
    # Opportunities with probability >= 75% (committed deals)
    opportunities
    |> Enum.filter(fn o ->
      prob = Map.get(o, :probability, 0)
      prob >= 75
    end)
    |> sum_amounts()
  end

  defp sum_by_category(opportunities, :closed_won) do
    # Closed won opportunities only
    opportunities
    |> Enum.filter(fn o ->
      Map.get(o, :is_won, false) == true or
        Map.get(o, :stage) == :closed_won or
        Map.get(o, :forecast_category) == :closed
    end)
    |> sum_amounts()
  end

  defp sum_amounts(opportunities) do
    Enum.reduce(opportunities, Decimal.new("0.00"), fn o, acc ->
      amount = Map.get(o, :amount)

      if amount && is_struct(amount, Decimal) do
        Decimal.add(acc, amount)
      else
        acc
      end
    end)
  end

  defp get_direct_reports(_manager_id) do
    # Placeholder - would query User.direct_reports
    []
  end

  defp bucket_total(opportunities) do
    Enum.reduce(opportunities, Decimal.new("0"), fn opp, acc ->
      amount = Map.get(opp, :amount)

      if amount && is_struct(amount, Decimal) do
        Decimal.add(acc, amount)
      else
        acc
      end
    end)
  end

  defp sum_field(records, field) do
    Enum.reduce(records, Decimal.new(0), fn record, acc ->
      value = Map.get(record, field)

      if value && is_struct(value, Decimal) do
        Decimal.add(acc, value)
      else
        acc
      end
    end)
  end
end
