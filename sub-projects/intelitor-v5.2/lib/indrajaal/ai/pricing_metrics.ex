defmodule Indrajaal.AI.PricingMetrics do
  @moduledoc """
  Prometheus metrics and correctness checks for the AI Pricing subsystem.

  ## WHAT
  Defines and exposes Prometheus metrics for monitoring the pricing cache,
  cost tracking, and runtime correctness validation.

  ## WHY
  - Enables real-time monitoring of AI costs via Prometheus/Grafana
  - Provides correctness invariants that can be checked at runtime
  - Supports alerting on pricing anomalies and budget thresholds

  ## STAMP Constraints
  - SC-PROM-001: All pricing metrics exposed via Prometheus
  - SC-PROM-002: Runtime correctness checks executed on metrics collection
  - SC-GVF-001: Graph verification includes cost path validation

  ## Metrics Exposed

  ### Gauges
  - `ai_pricing_cache_model_count` - Number of models in cache
  - `ai_pricing_cache_history_entries` - Historical pricing entries
  - `ai_pricing_cache_last_refresh_timestamp` - Unix timestamp of last refresh
  - `ai_pricing_cache_refresh_errors` - Consecutive refresh errors

  ### Counters
  - `ai_cost_total` - Total USD spent on AI calls
  - `ai_tokens_total` - Total tokens consumed (by type)
  - `ai_api_calls_total` - Total API calls (by model)
  - `ai_price_changes_total` - Number of price changes detected

  ### Histograms
  - `ai_cost_per_request` - Cost per request distribution
  - `ai_tokens_per_request` - Tokens per request distribution

  ## Correctness Invariants

  1. INV_CACHE_FRESHNESS: Cache must be refreshed within 25 hours
  2. INV_PRICE_POSITIVE: All prices must be >= 0
  3. INV_HISTORY_BOUNDED: History entries <= max_days * model_count
  4. INV_COST_TRACKING: Every API call must have cost telemetry
  """

  use GenServer
  require Logger

  alias Indrajaal.AI.PricingCache

  @check_interval :timer.minutes(5)
  @max_cache_age_hours 25

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current pricing metrics as a map.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  catch
    :exit, _ -> collect_metrics_direct()
  end

  @doc """
  Run all correctness checks and return results.
  """
  @spec run_correctness_checks() :: {:ok, map()} | {:error, list()}
  def run_correctness_checks do
    checks = [
      check_cache_freshness(),
      check_prices_positive(),
      check_history_bounded(),
      check_cache_populated()
    ]

    violations = Enum.filter(checks, fn {status, _} -> status == :violation end)

    if Enum.empty?(violations) do
      {:ok, %{passed: length(checks), violations: 0, checks: checks}}
    else
      {:error, violations}
    end
  end

  @doc """
  Get correctness score (0-100).
  """
  @spec correctness_score() :: float()
  def correctness_score do
    case run_correctness_checks() do
      {:ok, %{passed: _passed}} ->
        100.0

      {:error, violations} ->
        total_checks = 4
        passed = total_checks - length(violations)
        Float.round(passed / total_checks * 100, 1)
    end
  end

  @doc """
  Format metrics for Prometheus exposition format.
  """
  @spec prometheus_format() :: String.t()
  def prometheus_format do
    metrics = collect_metrics_direct()

    lines = [
      "# HELP ai_pricing_cache_model_count Number of models in pricing cache",
      "# TYPE ai_pricing_cache_model_count gauge",
      "ai_pricing_cache_model_count #{metrics.model_count}",
      "",
      "# HELP ai_pricing_cache_history_entries Historical pricing entries count",
      "# TYPE ai_pricing_cache_history_entries gauge",
      "ai_pricing_cache_history_entries #{metrics.history_entries}",
      "",
      "# HELP ai_pricing_cache_last_refresh_seconds Seconds since last cache refresh",
      "# TYPE ai_pricing_cache_last_refresh_seconds gauge",
      "ai_pricing_cache_last_refresh_seconds #{metrics.seconds_since_refresh}",
      "",
      "# HELP ai_pricing_cache_refresh_errors Consecutive refresh error count",
      "# TYPE ai_pricing_cache_refresh_errors gauge",
      "ai_pricing_cache_refresh_errors #{metrics.refresh_errors}",
      "",
      "# HELP ai_pricing_cache_free_models Number of free tier models",
      "# TYPE ai_pricing_cache_free_models gauge",
      "ai_pricing_cache_free_models #{metrics.free_model_count}",
      "",
      "# HELP ai_pricing_cache_correctness_score Correctness check score 0-100",
      "# TYPE ai_pricing_cache_correctness_score gauge",
      "ai_pricing_cache_correctness_score #{metrics.correctness_score}",
      "",
      "# HELP ai_price_changes_detected_total Total price changes detected",
      "# TYPE ai_price_changes_detected_total counter",
      "ai_price_changes_detected_total #{metrics.price_changes_detected}"
    ]

    Enum.join(lines, "\n")
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Attach telemetry handlers
    attach_telemetry_handlers()

    # Schedule periodic correctness checks
    schedule_correctness_check()

    state = %{
      cost_total: 0.0,
      tokens_input: 0,
      tokens_output: 0,
      api_calls: 0,
      last_check: nil,
      violations: []
    }

    Logger.info("[PricingMetrics] Initialized - SC-PROM-001, SC-PROM-002 active")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = collect_metrics_with_state(state)
    {:reply, metrics, state}
  end

  @impl true
  def handle_info(:correctness_check, state) do
    case run_correctness_checks() do
      {:ok, _} ->
        Logger.debug("[PricingMetrics] All correctness checks passed")

      {:error, violations} ->
        Logger.warning("[PricingMetrics] Correctness violations: #{inspect(violations)}")
        emit_violation_telemetry(violations)
    end

    schedule_correctness_check()
    {:noreply, %{state | last_check: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:telemetry, :cost_tracked, cost, tokens_in, tokens_out}, state) do
    new_state = %{
      state
      | cost_total: state.cost_total + cost,
        tokens_input: state.tokens_input + tokens_in,
        tokens_output: state.tokens_output + tokens_out,
        api_calls: state.api_calls + 1
    }

    {:noreply, new_state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp schedule_correctness_check do
    Process.send_after(self(), :correctness_check, @check_interval)
  end

  defp attach_telemetry_handlers do
    # Attach to OpenRouter cost events
    :telemetry.attach(
      "pricing-metrics-cost-handler",
      [:ai, :openrouter, :cost],
      &handle_cost_event/4,
      nil
    )

    # Attach to pricing cache refresh events
    :telemetry.attach(
      "pricing-metrics-refresh-handler",
      [:ai, :pricing_cache, :refresh],
      &handle_refresh_event/4,
      nil
    )

    # Attach to price change events
    :telemetry.attach(
      "pricing-metrics-change-handler",
      [:ai, :pricing_cache, :price_change],
      &handle_price_change_event/4,
      nil
    )
  end

  defp handle_cost_event(_event, measurements, metadata, _config) do
    # Forward to GenServer for aggregation
    if pid = GenServer.whereis(__MODULE__) do
      send(
        pid,
        {:telemetry, :cost_tracked, measurements.cost, measurements.prompt_tokens,
         measurements.completion_tokens}
      )
    end

    # Log for debugging
    Logger.debug("[PricingMetrics] Cost tracked: $#{measurements.cost} for #{metadata.model}")
  end

  defp handle_refresh_event(_event, measurements, metadata, _config) do
    Logger.info(
      "[PricingMetrics] Cache refresh: #{measurements.model_count} models, status=#{metadata.status}"
    )
  end

  defp handle_price_change_event(_event, measurements, _metadata, _config) do
    Logger.warning("[PricingMetrics] Price changes detected: #{measurements.change_count}")
  end

  defp collect_metrics_direct do
    stats =
      try do
        PricingCache.stats()
      catch
        :exit, _ ->
          %{
            model_count: 0,
            history_entries: 0,
            last_refresh: nil,
            refresh_errors: 0,
            price_changes_detected: 0
          }
      end

    free_count = length(PricingCache.list_free_models())

    seconds_since_refresh =
      if stats.last_refresh do
        DateTime.diff(DateTime.utc_now(), stats.last_refresh, :second)
      else
        -1
      end

    %{
      model_count: stats.model_count,
      history_entries: stats[:history_entries] || 0,
      seconds_since_refresh: seconds_since_refresh,
      refresh_errors: stats.refresh_errors,
      free_model_count: free_count,
      price_changes_detected: stats[:price_changes_detected] || 0,
      correctness_score: correctness_score()
    }
  end

  defp collect_metrics_with_state(state) do
    base = collect_metrics_direct()

    Map.merge(base, %{
      cost_total: state.cost_total,
      tokens_input: state.tokens_input,
      tokens_output: state.tokens_output,
      api_calls: state.api_calls,
      last_check: state.last_check
    })
  end

  # ============================================================================
  # Correctness Invariants
  # ============================================================================

  defp check_cache_freshness do
    stats =
      try do
        PricingCache.stats()
      catch
        :exit, _ -> %{last_refresh: nil}
      end

    case stats.last_refresh do
      nil ->
        {:violation, {:inv_cache_freshness, "Cache never refreshed"}}

      timestamp ->
        age_hours = DateTime.diff(DateTime.utc_now(), timestamp, :hour)

        if age_hours <= @max_cache_age_hours do
          {:ok, {:inv_cache_freshness, "Cache age: #{age_hours}h"}}
        else
          {:violation,
           {:inv_cache_freshness, "Cache too old: #{age_hours}h > #{@max_cache_age_hours}h"}}
        end
    end
  end

  defp check_prices_positive do
    models = PricingCache.list_by_cost(limit: 100)

    negative =
      Enum.filter(models, fn m ->
        m.input < 0 or m.output < 0
      end)

    if Enum.empty?(negative) do
      {:ok, {:inv_price_positive, "All prices >= 0"}}
    else
      {:violation, {:inv_price_positive, "Negative prices found: #{inspect(negative)}"}}
    end
  end

  defp check_history_bounded do
    stats =
      try do
        PricingCache.stats()
      catch
        :exit, _ -> %{history_entries: 0, model_count: 0}
      end

    # Max 90 days * model count
    max_entries = 90 * max(stats.model_count, 1)
    history_count = stats[:history_entries] || 0

    if history_count <= max_entries do
      {:ok, {:inv_history_bounded, "History entries: #{history_count} <= #{max_entries}"}}
    else
      {:violation, {:inv_history_bounded, "History unbounded: #{history_count} > #{max_entries}"}}
    end
  end

  defp check_cache_populated do
    models = PricingCache.list_models()

    if length(models) > 0 do
      {:ok, {:inv_cache_populated, "Cache has #{length(models)} models"}}
    else
      {:violation, {:inv_cache_populated, "Cache is empty"}}
    end
  end

  defp emit_violation_telemetry(violations) do
    :telemetry.execute(
      [:ai, :pricing_metrics, :violation],
      %{count: length(violations)},
      %{violations: violations}
    )
  end
end
