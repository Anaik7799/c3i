defmodule Indrajaal.Cockpit.Prajna.SentinelBridge do
  @moduledoc """
  Sentinel Bridge for Prajna SmartMetrics.

  WHAT: A bidirectional bridge that synchronizes Prajna's SmartMetrics with
  the Sentinel Immune System.

  WHY: SC-IMMUNE-001 requires active monitoring. This bridge ensures that
  SmartMetrics collected in the Cockpit are fed into the Sentinel for threat
  analysis, and Sentinel's health scores are reflected back in the Cockpit.

  ## Architecture

  ```
  [SmartMetrics] --(metrics)--> [SentinelBridge] --(report_threat)--> [Sentinel]
        ^
        |
        +---------(health_score)--------+
  ```

  CONSTRAINTS:
  - SC-IMMUNE-007: Bridge MUST sync every 30s.
  - SC-PRAJNA-004: Critical domains must have visibility.

  ## STAMP Compliance
  - SC-OBS-069: Uses Telemetry for all sync operations.
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.Backoff
  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Safety.Sentinel

  # Sync interval: 30 seconds (SC-IMMUNE-007)
  @sync_interval_ms 30_000

  # Backoff configuration (SC-API-003, SC-BIO-007)
  @backoff_base_ms 1_000
  @backoff_max_ms 60_000
  @backoff_max_attempts 5

  # ============================================================ 
  # CLIENT API
  # ============================================================ 

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Force immediate synchronization."
  @spec sync_now() :: :ok
  def sync_now do
    GenServer.cast(__MODULE__, :sync_now)
  end

  @doc """
  Emergency fast-path sync for critical threats.
  SIL-4 FIX: Bypasses normal 30s interval for immediate response.
  SC-IMMUNE-007: Response time requirements per severity.
  """
  @spec emergency_sync(atom()) :: :ok | {:error, :not_running}
  def emergency_sync(severity \\ :critical) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :not_running}

      pid ->
        # Use call (not cast) to ensure sync completes before returning
        GenServer.call(pid, {:emergency_sync, severity}, 5000)
    end
  end

  @doc "Get current health data from Sentinel."
  @spec get_health() :: map()
  def get_health do
    GenServer.call(__MODULE__, :get_health)
  end

  @doc "Get current advisories from Sentinel."
  @spec get_advisories() :: list(map())
  def get_advisories do
    GenServer.call(__MODULE__, :get_advisories)
  end

  @doc "Get current quarantine status from Sentinel."
  @spec get_quarantine_status() :: list(map())
  def get_quarantine_status do
    GenServer.call(__MODULE__, :get_quarantine_status)
  end

  @doc "Get bridge statistics."
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================ 

  @impl true
  def init(_opts) do
    Logger.info("[Prajna.SentinelBridge] Initializing bridge to Immune System...")
    schedule_sync()

    {:ok,
     %{
       last_sync: nil,
       status: :connected,
       health: %{score: 1.0, score_percent: 100, threats: [], status: :healthy},
       advisories: [],
       quarantine: [],
       sync_count: 0,
       sync_interval: @sync_interval_ms,
       # Backoff state (SC-API-003, SC-BIO-007)
       consecutive_failures: 0,
       last_failure_time: nil,
       backoff_active: false
     }}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    # Include last_sync in health response for test compatibility
    health_with_sync = Map.put(state.health, :last_sync, state.last_sync)
    {:reply, health_with_sync, state}
  end

  @impl true
  def handle_call(:get_advisories, _from, state) do
    {:reply, state.advisories, state}
  end

  @impl true
  def handle_call(:get_quarantine_status, _from, state) do
    {:reply, state.quarantine, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      sync_count: state.sync_count,
      last_sync: state.last_sync,
      status: state.status,
      sync_interval: state.sync_interval,
      error_count: Map.get(state, :error_count, 0),
      # Backoff metrics (SC-API-003)
      consecutive_failures: state.consecutive_failures,
      backoff_active: state.backoff_active,
      last_failure_time: state.last_failure_time
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:emergency_sync, severity}, _from, state) do
    # SIL-4 FIX: Emergency fast-path sync
    Logger.warning("[Prajna.SentinelBridge] EMERGENCY SYNC triggered (severity: #{severity})")

    :telemetry.execute(
      [:indrajaal, :prajna, :sentinel_bridge, :emergency_sync],
      %{timestamp: System.system_time(:millisecond)},
      %{severity: severity}
    )

    # Perform sync immediately and return new state
    new_state = perform_sync(state)

    # Record response time for SC-IMMUNE-007 compliance
    response_time_ms =
      if new_state.last_sync do
        DateTime.diff(DateTime.utc_now(), state.last_sync || DateTime.utc_now(), :millisecond)
      else
        0
      end

    :telemetry.execute(
      [:indrajaal, :prajna, :sentinel_bridge, :emergency_sync_complete],
      %{response_time_ms: response_time_ms, timestamp: System.system_time(:millisecond)},
      %{severity: severity}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast(:sync_now, state) do
    new_state = perform_sync(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:sync_tick, state) do
    new_state = perform_sync(state)
    schedule_sync()
    {:noreply, new_state}
  end

  # ============================================================ 
  # SYNC LOGIC
  # ============================================================ 

  defp perform_sync(state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :sentinel_bridge, :sync_start],
      %{timestamp: System.system_time(:millisecond)}
    )

    # Check if backoff is active and we should skip this sync
    case check_backoff_state(state) do
      {:skip, new_state} ->
        Logger.debug("[Prajna.SentinelBridge] Sync skipped due to active backoff")
        new_state

      {:proceed, state} ->
        do_perform_sync(state)
    end
  end

  # SC-API-003: Check if we should skip sync due to active backoff
  defp check_backoff_state(state) do
    if state.backoff_active and state.consecutive_failures > 0 do
      case Backoff.exponential_backoff(state.consecutive_failures,
             base_ms: @backoff_base_ms,
             max_ms: @backoff_max_ms,
             max_attempts: @backoff_max_attempts
           ) do
        {:ok, delay_ms} ->
          # Check if enough time has passed since last failure
          elapsed_ms = elapsed_since_failure(state.last_failure_time)

          if elapsed_ms < delay_ms do
            Logger.debug(
              "[Prajna.SentinelBridge] Backoff active: #{elapsed_ms}ms/#{delay_ms}ms elapsed"
            )

            {:skip, state}
          else
            {:proceed, state}
          end

        {:error, :max_attempts_exceeded} ->
          # Max attempts exceeded, log critical and reset
          Logger.error(
            "[Prajna.SentinelBridge] Max retry attempts exceeded (#{@backoff_max_attempts})"
          )

          emit_max_retries_exceeded()
          {:proceed, %{state | consecutive_failures: 0, backoff_active: false}}

        {:error, :circuit_open} ->
          Logger.warning("[Prajna.SentinelBridge] Circuit open, skipping sync")
          {:skip, state}
      end
    else
      {:proceed, state}
    end
  end

  defp elapsed_since_failure(nil), do: :infinity

  defp elapsed_since_failure(last_failure_time) do
    System.monotonic_time(:millisecond) - last_failure_time
  end

  defp do_perform_sync(state) do
    # 1. PULL from Sentinel: Get Health Score & Active Threats
    case Sentinel.get_health() do
      %{status: :not_running} ->
        Logger.warning("[Prajna.SentinelBridge] Sentinel not running. Skipping sync.")
        %{state | sync_count: state.sync_count + 1, last_sync: DateTime.utc_now()}

      health ->
        update_smart_metrics(health)

        # 2. PUSH to Sentinel: Send anomalies from SmartMetrics
        report_anomalies_to_sentinel()

        # 3. Get advisories and quarantine status
        advisories = get_advisories_from_sentinel(health)
        quarantine = Map.get(health, :quarantined, [])

        # Build health map for state
        health_data = %{
          score: Map.get(health, :score, 1.0),
          score_percent: round(Map.get(health, :score, 1.0) * 100),
          threats: Map.get(health, :threats, []),
          status: Map.get(health, :status, :healthy)
        }

        :telemetry.execute(
          [:indrajaal, :prajna, :sentinel_bridge, :sync_complete],
          %{timestamp: System.system_time(:millisecond)},
          %{health_score: health_data.score}
        )

        # ZUIP: Publish sentinel health sync to Zenoh mesh
        safe_publish(:publish_sentinel_threat, [
          :health_sync,
          :sentinel_bridge,
          health_data.status,
          %{score: health_data.score, threats: length(health_data.threats)}
        ])

        # Success - reset backoff state
        %{
          state
          | last_sync: DateTime.utc_now(),
            sync_count: state.sync_count + 1,
            health: health_data,
            advisories: advisories,
            quarantine: quarantine,
            consecutive_failures: 0,
            backoff_active: false
        }
    end
  rescue
    e ->
      Logger.error("[Prajna.SentinelBridge] Sync failed: #{inspect(e)}")

      # SC-API-003: Record failure and activate backoff
      new_failures = state.consecutive_failures + 1

      emit_sync_failure(new_failures, e)

      # Update health status to :unknown when sync fails
      unknown_health = %{
        score: 0.0,
        score_percent: 0,
        threats: [],
        status: :unknown
      }

      %{
        state
        | sync_count: state.sync_count + 1,
          health: unknown_health,
          last_sync: DateTime.utc_now(),
          consecutive_failures: new_failures,
          backoff_active: true,
          last_failure_time: System.monotonic_time(:millisecond)
      }
  end

  defp emit_sync_failure(attempt, error) do
    :telemetry.execute(
      [:indrajaal, :prajna, :sentinel_bridge, :sync_failure],
      %{
        attempt: attempt,
        timestamp: System.system_time(:millisecond)
      },
      %{error: inspect(error)}
    )
  end

  defp emit_max_retries_exceeded do
    :telemetry.execute(
      [:indrajaal, :prajna, :sentinel_bridge, :max_retries_exceeded],
      %{
        max_attempts: @backoff_max_attempts,
        timestamp: System.system_time(:millisecond)
      },
      %{}
    )
  end

  defp get_advisories_from_sentinel(health) do
    # Convert threats to advisories format
    threats = Map.get(health, :threats, [])

    Enum.map(threats, fn threat ->
      source = Map.get(threat, :source, :sentinel)

      %{
        id: Map.get(threat, :id, Ecto.UUID.generate()),
        severity: Map.get(threat, :severity, :low),
        message: Map.get(threat, :message, "Unknown threat"),
        # P1 FIX: Include both :source and :type for compatibility
        source: source,
        type: source,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  defp update_smart_metrics(health) do
    # Record Health Score
    SmartMetrics.record(
      "system.health_score",
      "System Health",
      # Convert 0.0-1.0 to percentage
      health.score * 100,
      thresholds: %{caution_low: 70.0, warning_low: 50.0, critical_low: 30.0}
    )

    # Record Threat Count
    threat_count = length(health.threats)

    SmartMetrics.record(
      "system.active_threats",
      "Active Threats",
      threat_count,
      thresholds: %{caution_high: 1, warning_high: 3, critical_high: 5}
    )

    # Record Quarantine Count
    quarantine_count = length(health.quarantined)

    SmartMetrics.record(
      "system.quarantine_count",
      "Quarantined Processes",
      quarantine_count,
      thresholds: %{caution_high: 1, warning_high: 5}
    )
  end

  defp report_anomalies_to_sentinel do
    # Get all alarmed metrics from SmartMetrics
    alarmed = SmartMetrics.alarmed_metrics()

    Enum.each(alarmed, fn {id, metric} ->
      # If level is warning or critical, report to Sentinel
      if metric.level in [:warning, :critical] do
        Logger.info("[Prajna.SentinelBridge] Escalating alarm to Sentinel: #{id}")

        Sentinel.report_threat(
          :metric_alarm,
          id,
          %{
            metric_label: metric.label,
            value: metric.value,
            level: metric.level,
            source: "Prajna.SmartMetrics"
          }
        )
      end
    end)
  end

  defp schedule_sync do
    Process.send_after(self(), :sync_tick, @sync_interval_ms)
  end

  defp safe_publish(function, args) do
    try do
      case Code.ensure_loaded(Indrajaal.Observability.ZenohSafetyPublisher) do
        {:module, mod} -> apply(mod, function, args)
        _ -> :ok
      end
    rescue
      _ -> :ok
    end
  end
end
