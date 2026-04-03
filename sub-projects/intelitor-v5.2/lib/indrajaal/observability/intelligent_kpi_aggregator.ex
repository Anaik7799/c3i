defmodule Indrajaal.Observability.IntelligentKPIAggregator do
  @moduledoc """
  Intelligent KPI Aggregator - Multi-Dimensional Performance Intelligence

  WHAT: Aggregates metrics from all 8 fractal layers into actionable KPIs
        with trend analysis, anomaly detection, and predictive insights.

  WHY: Provides the "nervous system" for the homeostatic controller to
       make intelligent resource allocation decisions.

  DESIGN:
    - Collects metrics from FractalTelemetryMatrix
    - Calculates composite KPIs (Golden Signals + Custom)
    - Applies statistical analysis (moving averages, std dev)
    - Generates forecasts using exponential smoothing
    - Triggers alerts based on SLO violations

  GOLDEN SIGNALS (Google SRE):
    1. Latency: Response time distribution
    2. Traffic: Request rate / throughput
    3. Errors: Error rate / failure ratio
    4. Saturation: Resource utilization

  CUSTOM KPIs:
    - System Health Score (0-100)
    - Homeostatic Stability Index
    - Cascade Risk Score
    - Recovery Velocity
    - SIL Compliance Score

  STAMP Constraints:
    - SC-KPI-001: Golden signals MUST be calculated every 5s
    - SC-KPI-002: Historical data retained for trend analysis
    - SC-KPI-003: Anomaly detection with 3-sigma rule
    - SC-KPI-004: SLO thresholds configurable
    - SC-KPI-005: Real-time dashboard feed
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.FractalTelemetryMatrix
  alias Indrajaal.Observability.HomeostaticController

  # KPI calculation interval
  @calculation_interval_ms 5_000

  # Historical retention (samples)
  # 1 hour at 5s intervals
  @history_limit 720

  # Anomaly detection threshold (standard deviations)
  @anomaly_sigma 3.0

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type kpi_name ::
          :latency
          | :traffic
          | :errors
          | :saturation
          | :health_score
          | :stability_index
          | :cascade_risk
          | :recovery_velocity
          | :sil_compliance

  @type kpi_value :: %{
          current: number(),
          avg_1m: number(),
          avg_5m: number(),
          avg_15m: number(),
          trend: :rising | :stable | :falling,
          forecast_5m: number(),
          anomaly: boolean(),
          slo_status: :ok | :warning | :critical
        }

  # ============================================================================
  # State Structure
  # ============================================================================

  defstruct kpis: %{},
            history: %{},
            slos: %{},
            alerts: [],
            last_calculation: nil,
            subscribers: [],
            dashboard_data: %{}

  # ============================================================================
  # Default SLOs
  # ============================================================================

  @default_slos %{
    latency: %{
      # ms
      warning: 100.0,
      # ms
      critical: 500.0
    },
    errors: %{
      # 1% error rate
      warning: 0.01,
      # 5% error rate
      critical: 0.05
    },
    saturation: %{
      # 70% utilization
      warning: 70.0,
      # 90% utilization
      critical: 90.0
    },
    health_score: %{
      # Below 80
      warning: 80.0,
      # Below 50
      critical: 50.0
    },
    sil_compliance: %{
      # Below 95%
      warning: 95.0,
      # Below 90%
      critical: 90.0
    }
  }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc "Start the Intelligent KPI Aggregator"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current value for a specific KPI"
  @spec get_kpi(kpi_name()) :: kpi_value() | nil
  def get_kpi(name) do
    GenServer.call(__MODULE__, {:get_kpi, name})
  catch
    :exit, _ -> nil
  end

  @doc "Get all KPIs"
  @spec all_kpis() :: map()
  def all_kpis do
    GenServer.call(__MODULE__, :all_kpis)
  catch
    :exit, _ -> %{}
  end

  @doc "Get dashboard data (formatted for display)"
  @spec dashboard_data() :: map()
  def dashboard_data do
    GenServer.call(__MODULE__, :dashboard_data)
  catch
    :exit, _ -> %{}
  end

  @doc "Get current alerts"
  @spec alerts() :: [map()]
  def alerts do
    GenServer.call(__MODULE__, :alerts)
  catch
    :exit, _ -> []
  end

  @doc "Set SLO threshold for a KPI"
  @spec set_slo(kpi_name(), :warning | :critical, number()) :: :ok
  def set_slo(kpi_name, level, threshold) do
    GenServer.cast(__MODULE__, {:set_slo, kpi_name, level, threshold})
  end

  @doc "Subscribe to KPI updates"
  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  @doc "Get historical data for a KPI"
  @spec history(kpi_name(), non_neg_integer()) :: [number()]
  def history(kpi_name, limit \\ 60) do
    GenServer.call(__MODULE__, {:history, kpi_name, limit})
  catch
    :exit, _ -> []
  end

  @doc "Get system summary (one-line status)"
  @spec summary() :: String.t()
  def summary do
    GenServer.call(__MODULE__, :summary)
  catch
    :exit, _ -> "KPI Aggregator unavailable"
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      kpis: init_kpis(),
      history: init_history(),
      slos: @default_slos,
      alerts: [],
      last_calculation: DateTime.utc_now(),
      subscribers: [],
      dashboard_data: %{}
    }

    # Schedule KPI calculation
    Process.send_after(self(), :calculate_kpis, @calculation_interval_ms)

    Logger.info("[IntelligentKPIAggregator] Started - monitoring 9 KPIs")

    {:ok, state}
  end

  @impl true
  def handle_call({:get_kpi, name}, _from, state) do
    kpi = Map.get(state.kpis, name)
    {:reply, kpi, state}
  end

  @impl true
  def handle_call(:all_kpis, _from, state) do
    {:reply, state.kpis, state}
  end

  @impl true
  def handle_call(:dashboard_data, _from, state) do
    {:reply, state.dashboard_data, state}
  end

  @impl true
  def handle_call(:alerts, _from, state) do
    {:reply, state.alerts, state}
  end

  @impl true
  def handle_call({:history, kpi_name, limit}, _from, state) do
    history = Map.get(state.history, kpi_name, [])
    {:reply, Enum.take(history, limit), state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    health = get_in(state.kpis, [:health_score, :current]) || 100.0

    mode =
      try do
        HomeostaticController.mode()
      catch
        _, _ -> :unknown
      end

    alert_count = length(state.alerts)

    summary = "Health: #{round(health)}% | Mode: #{mode} | Alerts: #{alert_count}"
    {:reply, summary, state}
  end

  @impl true
  def handle_cast({:set_slo, kpi_name, level, threshold}, state) do
    current_slo = Map.get(state.slos, kpi_name, %{})
    updated_slo = Map.put(current_slo, level, threshold)
    slos = Map.put(state.slos, kpi_name, updated_slo)
    {:noreply, %{state | slos: slos}}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    subscribers = [pid | state.subscribers] |> Enum.uniq()
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_info(:calculate_kpis, state) do
    new_state = calculate_all_kpis(state)

    # Schedule next calculation
    Process.send_after(self(), :calculate_kpis, @calculation_interval_ms)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # KPI Calculation
  # ============================================================================

  defp calculate_all_kpis(state) do
    # Collect raw metrics
    matrix =
      try do
        FractalTelemetryMatrix.full_matrix()
      catch
        _, _ -> %{}
      end

    matrix_health =
      try do
        FractalTelemetryMatrix.system_health_score()
      catch
        _, _ -> 100.0
      end

    homeostatic_mode =
      try do
        HomeostaticController.mode()
      catch
        _, _ -> :normal
      end

    degradation =
      try do
        HomeostaticController.degradation_level()
      catch
        _, _ -> 0
      end

    recovery =
      try do
        HomeostaticController.recovery_progress()
      catch
        _, _ -> 1.0
      end

    # Calculate each KPI
    now = DateTime.utc_now()

    new_kpis = %{
      latency: calculate_latency_kpi(matrix, state),
      traffic: calculate_traffic_kpi(matrix, state),
      errors: calculate_errors_kpi(matrix, state),
      saturation: calculate_saturation_kpi(matrix, state),
      health_score: calculate_health_kpi(matrix_health, state),
      stability_index: calculate_stability_kpi(homeostatic_mode, state),
      cascade_risk: calculate_cascade_risk_kpi(matrix, state),
      recovery_velocity: calculate_recovery_kpi(recovery, degradation, state),
      sil_compliance: calculate_sil_kpi(matrix, state)
    }

    # Update history
    new_history =
      Enum.reduce(new_kpis, state.history, fn {name, kpi}, hist ->
        current_history = Map.get(hist, name, [])
        updated = [kpi.current | Enum.take(current_history, @history_limit - 1)]
        Map.put(hist, name, updated)
      end)

    # Check SLOs and generate alerts
    {new_kpis_with_slo, new_alerts} = check_slos(new_kpis, state.slos)

    # Build dashboard data
    dashboard = build_dashboard_data(new_kpis_with_slo, new_alerts, homeostatic_mode)

    # Notify subscribers
    notify_subscribers(state.subscribers, {:kpi_update, new_kpis_with_slo, now})

    %{
      state
      | kpis: new_kpis_with_slo,
        history: new_history,
        alerts: new_alerts,
        last_calculation: now,
        dashboard_data: dashboard
    }
  end

  defp calculate_latency_kpi(matrix, state) do
    # Aggregate latency from all layers
    latencies =
      Enum.flat_map(matrix, fn {_layer, layer_data} ->
        case get_in(layer_data, [:latency, :value]) do
          nil -> []
          val -> [val]
        end
      end)

    current = if Enum.empty?(latencies), do: 0.0, else: Enum.sum(latencies) / length(latencies)
    build_kpi_value(:latency, current, state)
  end

  defp calculate_traffic_kpi(matrix, state) do
    # Sum events and messages as traffic indicator
    traffic =
      Enum.reduce(matrix, 0.0, fn {_layer, layer_data}, acc ->
        events = get_in(layer_data, [:events, :value]) || 0.0
        messages = get_in(layer_data, [:messages, :value]) || 0.0
        acc + events + messages
      end)

    build_kpi_value(:traffic, traffic, state)
  end

  defp calculate_errors_kpi(matrix, state) do
    # Aggregate error rates
    errors =
      Enum.flat_map(matrix, fn {_layer, layer_data} ->
        case get_in(layer_data, [:errors, :value]) do
          nil -> []
          val -> [val]
        end
      end)

    current = if Enum.empty?(errors), do: 0.0, else: Enum.sum(errors) / length(errors)
    build_kpi_value(:errors, current, state)
  end

  defp calculate_saturation_kpi(matrix, state) do
    # Aggregate resource utilization
    resources =
      Enum.flat_map(matrix, fn {_layer, layer_data} ->
        case get_in(layer_data, [:resources, :value]) do
          nil -> []
          val -> [val]
        end
      end)

    current = if Enum.empty?(resources), do: 0.0, else: Enum.max(resources)
    build_kpi_value(:saturation, current, state)
  end

  defp calculate_health_kpi(matrix_health, state) do
    build_kpi_value(:health_score, matrix_health, state)
  end

  defp calculate_stability_kpi(mode, state) do
    # Stability index based on mode and history
    base_score =
      case mode do
        :normal -> 100.0
        :recovery -> 70.0
        :stressed -> 50.0
        :degraded -> 30.0
        :critical -> 10.0
        _ -> 50.0
      end

    build_kpi_value(:stability_index, base_score, state)
  end

  defp calculate_cascade_risk_kpi(matrix, state) do
    # Risk based on anomaly spread across layers
    anomaly_count =
      Enum.count(matrix, fn {_layer, layer_data} ->
        Enum.any?(layer_data, fn {_int, int_data} ->
          int_data[:anomaly] == true
        end)
      end)

    risk = anomaly_count / max(1, map_size(matrix)) * 100
    build_kpi_value(:cascade_risk, risk, state)
  end

  defp calculate_recovery_kpi(recovery_progress, degradation, state) do
    # Velocity of recovery (change over time)
    history = Map.get(state.history, :recovery_velocity, [])
    previous = List.first(history) || recovery_progress

    velocity = (recovery_progress - previous) * 100
    velocity_clamped = max(-100, min(100, velocity))

    # Factor in degradation level
    effective = velocity_clamped * (1 - degradation / 100)

    build_kpi_value(:recovery_velocity, effective, state)
  end

  defp calculate_sil_kpi(matrix, state) do
    # SIL compliance based on error rates, health, and response times
    error_score = 100 - calculate_errors_kpi(matrix, state).current * 1000
    latency_score = max(0, 100 - calculate_latency_kpi(matrix, state).current)

    compliance = (error_score + latency_score) / 2
    compliance_clamped = max(0, min(100, compliance))

    build_kpi_value(:sil_compliance, compliance_clamped, state)
  end

  defp build_kpi_value(name, current, state) do
    history = Map.get(state.history, name, [])

    # Calculate moving averages
    # 12 samples = 1 minute
    avg_1m = moving_average(history, 12)
    # 60 samples = 5 minutes
    avg_5m = moving_average(history, 60)
    # 180 samples = 15 minutes
    avg_15m = moving_average(history, 180)

    # Calculate trend
    trend = calculate_trend(history, current)

    # Forecast using exponential smoothing
    forecast = exponential_smoothing_forecast(history, current, 60)

    # Detect anomaly
    anomaly = detect_anomaly(history, current)

    %{
      current: current,
      avg_1m: avg_1m,
      avg_5m: avg_5m,
      avg_15m: avg_15m,
      trend: trend,
      forecast_5m: forecast,
      anomaly: anomaly,
      # Will be set by check_slos
      slo_status: :ok
    }
  end

  # ============================================================================
  # Statistical Functions
  # ============================================================================

  defp moving_average([], _window), do: 0.0

  defp moving_average(history, window) do
    samples = Enum.take(history, window)
    if Enum.empty?(samples), do: 0.0, else: Enum.sum(samples) / length(samples)
  end

  defp calculate_trend([], _current), do: :stable

  defp calculate_trend(history, current) do
    avg = moving_average(history, 6)

    cond do
      current > avg * 1.1 -> :rising
      current < avg * 0.9 -> :falling
      true -> :stable
    end
  end

  defp exponential_smoothing_forecast([], current, _periods), do: current

  defp exponential_smoothing_forecast(history, current, periods) do
    # Smoothing factor
    alpha = 0.3
    recent = Enum.take(history, periods)

    if Enum.empty?(recent) do
      current
    else
      # Simple exponential smoothing
      smoothed =
        Enum.reduce(recent, current, fn val, acc ->
          alpha * val + (1 - alpha) * acc
        end)

      # Project forward based on trend
      trend = calculate_trend(history, current)

      case trend do
        :rising -> smoothed * 1.1
        :falling -> smoothed * 0.9
        :stable -> smoothed
      end
    end
  end

  defp detect_anomaly([], _current), do: false

  defp detect_anomaly(history, current) do
    samples = Enum.take(history, 60)

    if length(samples) < 10 do
      false
    else
      mean = Enum.sum(samples) / length(samples)

      variance =
        Enum.reduce(samples, 0, fn x, acc -> acc + :math.pow(x - mean, 2) end) / length(samples)

      std_dev = :math.sqrt(variance)

      if std_dev == 0 do
        false
      else
        z_score = abs(current - mean) / std_dev
        z_score > @anomaly_sigma
      end
    end
  end

  # ============================================================================
  # SLO Checking
  # ============================================================================

  defp check_slos(kpis, slos) do
    {updated_kpis, alerts} =
      Enum.reduce(kpis, {%{}, []}, fn {name, kpi}, {kpi_acc, alert_acc} ->
        slo = Map.get(slos, name, %{})
        warning = Map.get(slo, :warning)
        critical = Map.get(slo, :critical)

        status =
          cond do
            critical && violates_slo?(name, kpi.current, critical) -> :critical
            warning && violates_slo?(name, kpi.current, warning) -> :warning
            true -> :ok
          end

        updated_kpi = %{kpi | slo_status: status}
        new_kpi_acc = Map.put(kpi_acc, name, updated_kpi)

        new_alert_acc =
          if status != :ok do
            alert = %{
              kpi: name,
              status: status,
              current: kpi.current,
              threshold: if(status == :critical, do: critical, else: warning),
              timestamp: DateTime.utc_now()
            }

            [alert | alert_acc]
          else
            alert_acc
          end

        {new_kpi_acc, new_alert_acc}
      end)

    {updated_kpis, alerts}
  end

  defp violates_slo?(name, current, threshold) do
    case name do
      # Lower is better
      n when n in [:latency, :errors, :saturation, :cascade_risk] ->
        current > threshold

      # Higher is better
      n when n in [:health_score, :stability_index, :sil_compliance] ->
        current < threshold

      # Traffic and recovery can go either way
      _ ->
        false
    end
  end

  # ============================================================================
  # Dashboard Building
  # ============================================================================

  defp build_dashboard_data(kpis, alerts, mode) do
    %{
      summary: %{
        health: get_in(kpis, [:health_score, :current]) || 100.0,
        mode: mode,
        alert_count: length(alerts),
        trend: overall_trend(kpis)
      },
      golden_signals: %{
        latency: format_kpi(kpis[:latency], "ms"),
        traffic: format_kpi(kpis[:traffic], "req/s"),
        errors: format_kpi(kpis[:errors], "%"),
        saturation: format_kpi(kpis[:saturation], "%")
      },
      custom_kpis: %{
        health_score: format_kpi(kpis[:health_score], "%"),
        stability_index: format_kpi(kpis[:stability_index], ""),
        cascade_risk: format_kpi(kpis[:cascade_risk], "%"),
        recovery_velocity: format_kpi(kpis[:recovery_velocity], "/s"),
        sil_compliance: format_kpi(kpis[:sil_compliance], "%")
      },
      alerts: Enum.take(alerts, 10),
      timestamp: DateTime.utc_now()
    }
  end

  defp format_kpi(nil, _unit), do: %{value: "-", trend: :stable, status: :unknown}

  defp format_kpi(kpi, unit) do
    %{
      value: "#{Float.round(Map.get(kpi, :current, 0.0), 2)}#{unit}",
      trend: Map.get(kpi, :trend, :stable),
      status: Map.get(kpi, :slo_status, :unknown)
    }
  end

  defp overall_trend(kpis) do
    trends = Enum.map(kpis, fn {_name, kpi} -> Map.get(kpi, :trend, :stable) end)

    rising = Enum.count(trends, &(&1 == :rising))
    falling = Enum.count(trends, &(&1 == :falling))

    cond do
      rising > falling * 2 -> :rising
      falling > rising * 2 -> :falling
      true -> :stable
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp init_kpis do
    kpi_names = [
      :latency,
      :traffic,
      :errors,
      :saturation,
      :health_score,
      :stability_index,
      :cascade_risk,
      :recovery_velocity,
      :sil_compliance
    ]

    Map.new(kpi_names, fn name ->
      {name,
       %{
         current: 0.0,
         avg_1m: 0.0,
         avg_5m: 0.0,
         avg_15m: 0.0,
         trend: :stable,
         forecast_5m: 0.0,
         anomaly: false,
         slo_status: :ok
       }}
    end)
  end

  defp init_history do
    kpi_names = [
      :latency,
      :traffic,
      :errors,
      :saturation,
      :health_score,
      :stability_index,
      :cascade_risk,
      :recovery_velocity,
      :sil_compliance
    ]

    Map.new(kpi_names, fn name -> {name, []} end)
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:kpi_aggregator, message})
      end
    end)
  end
end
