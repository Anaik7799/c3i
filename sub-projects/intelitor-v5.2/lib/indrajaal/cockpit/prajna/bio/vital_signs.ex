defmodule Indrajaal.Cockpit.Prajna.Bio.VitalSigns do
  @moduledoc """
  ## Vital Signs - Real-Time Health Metrics System

  WHAT: Continuous health monitoring engine that tracks physiological metrics
        for all system components using 0.0-1.0 normalized float values.

  WHY: Boolean health checks (healthy/unhealthy) are insufficient for
       safety-critical systems. Vital Signs provide:
       - Gradual degradation detection (early warning)
       - Trend analysis (predictive maintenance)
       - Component-level aggregation (situational awareness)
       - OODA loop integration (rapid response)

  CONSTRAINTS:
    - SC-BIO-003: All health values MUST be 0.0-1.0 floats
    - SC-PRF-050: Metric collection < 50ms latency
    - SC-OBS-069: Dual logging to Terminal + SigNoz

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                     VITAL SIGNS ENGINE                               │
  ├─────────────────────────────────────────────────────────────────────┤
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
  │  │  CPU Health │  │Memory Health│  │  IO Health  │  │Latency Hlth│ │
  │  │   (0.0-1.0) │  │  (0.0-1.0)  │  │  (0.0-1.0)  │  │  (0.0-1.0) │ │
  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘ │
  │         │                │                │               │        │
  │         └────────────────┼────────────────┼───────────────┘        │
  │                          ▼                                          │
  │              ┌───────────────────────┐                              │
  │              │  COMPOSITE HEALTH     │                              │
  │              │  (Weighted Aggregate) │                              │
  │              └───────────────────────┘                              │
  │                          │                                          │
  │         ┌────────────────┼────────────────┐                        │
  │         ▼                ▼                ▼                        │
  │  ┌────────────┐  ┌─────────────┐  ┌────────────┐                  │
  │  │  Telemetry │  │   PubSub    │  │  ETS Store │                  │
  │  │   Events   │  │  Broadcast  │  │  (Current) │                  │
  │  └────────────┘  └─────────────┘  └────────────┘                  │
  └─────────────────────────────────────────────────────────────────────┘
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-29 |
  | Author | L3-BIO-3 (Biomorphic Architecture Worker) |
  | STAMP | SC-BIO-003, SC-PRF-050, SC-OBS-069 |
  """

  use GenServer
  require Logger

  # ═══════════════════════════════════════════════════════════════════════════
  # TYPES & CONSTANTS
  # ═══════════════════════════════════════════════════════════════════════════

  @type health_value :: float()
  @type component_id :: String.t()
  @type metric_type :: :cpu_health | :memory_health | :io_health | :latency_health

  @type vital_reading :: %{
          cpu_health: health_value(),
          memory_health: health_value(),
          io_health: health_value(),
          latency_health: health_value(),
          composite_health: health_value(),
          timestamp: DateTime.t(),
          trend: :improving | :stable | :degrading,
          generation: non_neg_integer()
        }

  @type component_vitals :: %{
          component_id: component_id(),
          type: :container | :supervisor | :worker | :domain | :cluster,
          vitals: vital_reading(),
          children: list(component_id()),
          parent: component_id() | nil
        }

  @table :vital_signs_store
  @history_table :vital_signs_history
  @collection_interval_ms 1_000
  @history_retention 60

  # Weights for composite health calculation (must sum to 1.0)
  @cpu_weight 0.30
  @memory_weight 0.25
  @io_weight 0.20
  @latency_weight 0.25

  # Health thresholds
  @critical_threshold 0.3
  @warning_threshold 0.5
  @caution_threshold 0.7

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Starts the VitalSigns GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a vital sign reading for a component.

  ## Parameters
    - component_id: Unique identifier for the component
    - type: Component type (:container, :supervisor, :worker, :domain, :cluster)
    - metrics: Map with cpu_health, memory_health, io_health, latency_health (all 0.0-1.0)
    - opts: Additional options (parent, children)

  ## Example
      VitalSigns.record("indrajaal-app", :container, %{
        cpu_health: 0.85,
        memory_health: 0.72,
        io_health: 0.90,
        latency_health: 0.95
      })
  """
  @spec record(component_id(), atom(), map(), keyword()) :: :ok | {:error, term()}
  def record(component_id, type, metrics, opts \\ []) do
    with :ok <- validate_metrics(metrics) do
      GenServer.cast(__MODULE__, {:record, component_id, type, metrics, opts})
    end
  end

  @doc """
  Gets the current vital signs for a component.
  Returns nil if component not found.
  """
  @spec get(component_id()) :: component_vitals() | nil
  def get(component_id) do
    case :ets.lookup(@table, component_id) do
      [{^component_id, vitals}] -> vitals
      [] -> nil
    end
  end

  @doc """
  Gets vital signs for all components.
  """
  @spec all() :: list({component_id(), component_vitals()})
  def all do
    :ets.tab2list(@table)
  end

  @doc """
  Gets vital signs for components of a specific type.
  """
  @spec by_type(atom()) :: list({component_id(), component_vitals()})
  def by_type(type) do
    all_vitals = :ets.tab2list(@table)

    all_vitals
    |> Enum.filter(fn {_, vitals} -> vitals.type == type end)
  end

  @doc """
  Calculates aggregate health for a component and its children.
  Uses weighted average based on child component types.
  """
  @spec aggregate_health(component_id()) :: {:ok, health_value()} | {:error, :not_found}
  def aggregate_health(component_id) do
    case get(component_id) do
      nil ->
        {:error, :not_found}

      vitals ->
        children_health = calculate_children_health(vitals.children)
        own_health = vitals.vitals.composite_health

        # Weight: 60% own health, 40% children average
        aggregate =
          if children_health do
            own_health * 0.6 + children_health * 0.4
          else
            own_health
          end

        {:ok, clamp(aggregate)}
    end
  end

  @doc """
  Gets components with health below threshold.
  """
  @spec unhealthy_components(health_value()) :: list({component_id(), component_vitals()})
  def unhealthy_components(threshold \\ @warning_threshold) do
    all_vitals = :ets.tab2list(@table)

    all_vitals
    |> Enum.filter(fn {_, vitals} -> vitals.vitals.composite_health < threshold end)
    |> Enum.sort_by(fn {_, vitals} -> vitals.vitals.composite_health end)
  end

  @doc """
  Gets components with degrading health trend.
  """
  @spec degrading_components() :: list({component_id(), component_vitals()})
  def degrading_components do
    all_vitals = :ets.tab2list(@table)

    all_vitals
    |> Enum.filter(fn {_, vitals} -> vitals.vitals.trend == :degrading end)
  end

  @doc """
  Gets the health history for a component (last 60 readings).
  """
  @spec history(component_id()) :: list(vital_reading())
  def history(component_id) do
    case :ets.lookup(@history_table, component_id) do
      [{^component_id, history}] -> history
      [] -> []
    end
  end

  @doc """
  Calculates system-wide health metrics.
  """
  @spec system_health() :: map()
  def system_health do
    all_vitals = all()
    total = length(all_vitals)

    if total == 0 do
      %{
        overall_health: 1.0,
        component_count: 0,
        by_status: %{healthy: 0, caution: 0, warning: 0, critical: 0},
        by_type: %{},
        degrading_count: 0,
        status: :healthy
      }
    else
      healths = Enum.map(all_vitals, fn {_, v} -> v.vitals.composite_health end)
      overall = Enum.sum(healths) / total

      by_status =
        Enum.reduce(all_vitals, %{healthy: 0, caution: 0, warning: 0, critical: 0}, fn {_, v},
                                                                                       acc ->
          status = health_to_status(v.vitals.composite_health)
          Map.update!(acc, status, &(&1 + 1))
        end)

      grouped = Enum.group_by(all_vitals, fn {_, v} -> v.type end)

      by_type =
        grouped
        |> Enum.map(fn {type, vitals} ->
          healths = Enum.map(vitals, fn {_, v} -> v.vitals.composite_health end)
          type_health = Enum.sum(healths) / length(vitals)

          {type, %{count: length(vitals), average_health: type_health}}
        end)
        |> Map.new()

      degrading_count = length(degrading_components())

      %{
        overall_health: Float.round(overall, 3),
        component_count: total,
        by_status: by_status,
        by_type: by_type,
        degrading_count: degrading_count,
        status: health_to_status(overall)
      }
    end
  end

  @doc """
  Manually triggers health collection for all registered collectors.
  """
  @spec collect_now() :: :ok
  def collect_now do
    GenServer.cast(__MODULE__, :collect_now)
  end

  @doc """
  Registers a health collector function for a component.
  The collector should return a map with cpu_health, memory_health, io_health, latency_health.
  """
  @spec register_collector(component_id(), atom(), (-> map())) :: :ok
  def register_collector(component_id, type, collector_fn) when is_function(collector_fn, 0) do
    GenServer.cast(__MODULE__, {:register_collector, component_id, type, collector_fn})
  end

  @doc """
  Unregisters a health collector.
  """
  @spec unregister_collector(component_id()) :: :ok
  def unregister_collector(component_id) do
    GenServer.cast(__MODULE__, {:unregister_collector, component_id})
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@history_table, [:named_table, :public, :set, read_concurrency: true])

    # Attach telemetry handlers
    attach_telemetry_handlers()

    # Schedule periodic collection
    schedule_collection()

    Logger.info("[VitalSigns] Initialized - SC-BIO-003 compliant health monitoring active")

    {:ok,
     %{
       started_at: DateTime.utc_now(),
       generation: 0,
       collectors: %{},
       last_collection: nil
     }}
  end

  @impl GenServer
  def handle_cast({:record, component_id, type, metrics, opts}, state) do
    now = DateTime.utc_now()
    generation = state.generation

    # Calculate composite health
    composite = calculate_composite_health(metrics)

    # Determine trend from history
    trend = calculate_trend(component_id, composite)

    vital_reading = %{
      cpu_health: clamp(metrics[:cpu_health] || metrics.cpu_health),
      memory_health: clamp(metrics[:memory_health] || metrics.memory_health),
      io_health: clamp(metrics[:io_health] || metrics.io_health),
      latency_health: clamp(metrics[:latency_health] || metrics.latency_health),
      composite_health: composite,
      timestamp: now,
      trend: trend,
      generation: generation
    }

    component_vitals = %{
      component_id: component_id,
      type: type,
      vitals: vital_reading,
      children: Keyword.get(opts, :children, []),
      parent: Keyword.get(opts, :parent)
    }

    # Store current vitals
    :ets.insert(@table, {component_id, component_vitals})

    # Update history
    update_history(component_id, vital_reading)

    # Emit telemetry
    emit_telemetry(component_id, type, vital_reading)

    # Broadcast via PubSub
    broadcast_update(component_id, component_vitals)

    # Check for alerts
    check_health_alerts(component_id, vital_reading)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:register_collector, component_id, type, collector_fn}, state) do
    collectors = Map.put(state.collectors, component_id, {type, collector_fn})
    {:noreply, %{state | collectors: collectors}}
  end

  @impl GenServer
  def handle_cast({:unregister_collector, component_id}, state) do
    collectors = Map.delete(state.collectors, component_id)
    :ets.delete(@table, component_id)
    :ets.delete(@history_table, component_id)
    {:noreply, %{state | collectors: collectors}}
  end

  @impl GenServer
  def handle_cast(:collect_now, state) do
    run_collectors(state.collectors)
    {:noreply, %{state | last_collection: DateTime.utc_now()}}
  end

  @impl GenServer
  def handle_info(:collect, state) do
    run_collectors(state.collectors)
    schedule_collection()

    {:noreply, %{state | generation: state.generation + 1, last_collection: DateTime.utc_now()}}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE FUNCTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  defp validate_metrics(metrics) do
    required = [:cpu_health, :memory_health, :io_health, :latency_health]

    missing =
      Enum.reject(required, fn key ->
        Map.has_key?(metrics, key) or (is_list(metrics) and Keyword.has_key?(metrics, key))
      end)

    cond do
      length(missing) > 0 ->
        {:error, {:missing_metrics, missing}}

      not all_valid_floats?(metrics) ->
        {:error, :invalid_values}

      true ->
        :ok
    end
  end

  defp all_valid_floats?(metrics) do
    [:cpu_health, :memory_health, :io_health, :latency_health]
    |> Enum.all?(fn key ->
      value = metrics[key]
      is_number(value) and value >= 0.0 and value <= 1.0
    end)
  end

  defp calculate_composite_health(metrics) do
    cpu = metrics[:cpu_health] || metrics.cpu_health
    memory = metrics[:memory_health] || metrics.memory_health
    io = metrics[:io_health] || metrics.io_health
    latency = metrics[:latency_health] || metrics.latency_health

    composite =
      cpu * @cpu_weight +
        memory * @memory_weight +
        io * @io_weight +
        latency * @latency_weight

    clamp(composite)
  end

  defp calculate_trend(component_id, current_health) do
    case history(component_id) do
      [] ->
        :stable

      history when length(history) < 3 ->
        :stable

      history ->
        recent = Enum.take(history, 5)
        avg_recent = Enum.sum(Enum.map(recent, & &1.composite_health)) / length(recent)
        older = Enum.slice(history, 5, 10)

        if length(older) > 0 do
          compare_with_older(avg_recent, older)
        else
          compare_with_current(current_health, avg_recent)
        end
    end
  end

  defp compare_with_older(avg_recent, older) do
    avg_older = Enum.sum(Enum.map(older, & &1.composite_health)) / length(older)
    diff = avg_recent - avg_older

    cond do
      diff > 0.05 -> :improving
      diff < -0.05 -> :degrading
      true -> :stable
    end
  end

  defp compare_with_current(current_health, avg_recent) do
    cond do
      current_health > avg_recent + 0.02 -> :improving
      current_health < avg_recent - 0.02 -> :degrading
      true -> :stable
    end
  end

  defp calculate_children_health([]), do: nil

  defp calculate_children_health(children) do
    healths =
      children
      |> Enum.map(&get/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.vitals.composite_health)

    if length(healths) > 0 do
      Enum.sum(healths) / length(healths)
    else
      nil
    end
  end

  defp update_history(component_id, vital_reading) do
    current_history =
      case :ets.lookup(@history_table, component_id) do
        [{^component_id, history}] -> history
        [] -> []
      end

    # Prepend new reading and keep only last @history_retention readings
    new_history = [vital_reading | current_history] |> Enum.take(@history_retention)
    :ets.insert(@history_table, {component_id, new_history})
  end

  defp emit_telemetry(component_id, type, vital_reading) do
    :telemetry.execute(
      [:indrajaal, :vital_signs, :reading],
      %{
        cpu_health: vital_reading.cpu_health,
        memory_health: vital_reading.memory_health,
        io_health: vital_reading.io_health,
        latency_health: vital_reading.latency_health,
        composite_health: vital_reading.composite_health
      },
      %{
        component_id: component_id,
        component_type: type,
        trend: vital_reading.trend,
        generation: vital_reading.generation
      }
    )
  end

  defp broadcast_update(component_id, component_vitals) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "vital_signs:#{component_id}",
        {:vital_signs_updated, component_vitals}
      )

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "vital_signs:all",
        {:vital_signs_updated, component_id, component_vitals}
      )
    rescue
      ArgumentError -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp check_health_alerts(component_id, vital_reading) do
    composite = vital_reading.composite_health

    cond do
      composite < @critical_threshold ->
        emit_health_alert(component_id, :critical, vital_reading)

      composite < @warning_threshold ->
        emit_health_alert(component_id, :warning, vital_reading)

      composite < @caution_threshold ->
        emit_health_alert(component_id, :caution, vital_reading)

      true ->
        :ok
    end

    # Also alert on degrading trend with low health
    if vital_reading.trend == :degrading and composite < 0.6 do
      emit_health_alert(component_id, :degrading, vital_reading)
    end
  end

  defp emit_health_alert(component_id, severity, vital_reading) do
    :telemetry.execute(
      [:indrajaal, :vital_signs, :alert],
      %{
        composite_health: vital_reading.composite_health,
        severity_level: severity_to_level(severity)
      },
      %{
        component_id: component_id,
        severity: severity,
        trend: vital_reading.trend,
        timestamp: vital_reading.timestamp
      }
    )

    Logger.warning(
      "[VitalSigns] Health alert for #{component_id}: #{severity} " <>
        "(health=#{Float.round(vital_reading.composite_health, 3)}, trend=#{vital_reading.trend})"
    )
  end

  defp severity_to_level(:critical), do: 4
  defp severity_to_level(:warning), do: 3
  defp severity_to_level(:caution), do: 2
  defp severity_to_level(:degrading), do: 2
  defp severity_to_level(_), do: 1

  defp health_to_status(health) do
    cond do
      health < @critical_threshold -> :critical
      health < @warning_threshold -> :warning
      health < @caution_threshold -> :caution
      true -> :healthy
    end
  end

  defp clamp(value) when is_number(value) do
    value
    |> max(0.0)
    |> min(1.0)
    |> Float.round(4)
  end

  defp run_collectors(collectors) do
    Enum.each(collectors, fn {component_id, {type, collector_fn}} ->
      try do
        metrics = collector_fn.()
        record(component_id, type, metrics)
      rescue
        e ->
          Logger.error(
            "[VitalSigns] Collector failed for #{component_id}: #{Exception.message(e)}"
          )
      catch
        kind, reason ->
          Logger.error("[VitalSigns] Collector crashed for #{component_id}: #{kind} - #{reason}")
      end
    end)
  end

  defp schedule_collection do
    Process.send_after(self(), :collect, @collection_interval_ms)
  end

  defp attach_telemetry_handlers do
    events = [
      [:indrajaal, :vital_signs, :reading],
      [:indrajaal, :vital_signs, :alert]
    ]

    :telemetry.attach_many(
      "vital-signs-handlers",
      events,
      &handle_telemetry_event/4,
      nil
    )
  end

  defp handle_telemetry_event([:indrajaal, :vital_signs, :reading], measurements, metadata, _) do
    Logger.debug(
      "[VitalSigns] Reading: #{metadata.component_id} " <>
        "cpu=#{measurements.cpu_health} mem=#{measurements.memory_health} " <>
        "io=#{measurements.io_health} lat=#{measurements.latency_health} " <>
        "composite=#{measurements.composite_health} trend=#{metadata.trend}"
    )
  end

  defp handle_telemetry_event([:indrajaal, :vital_signs, :alert], measurements, metadata, _) do
    Logger.info(
      "[VitalSigns] Alert: #{metadata.component_id} severity=#{metadata.severity} " <>
        "health=#{measurements.composite_health}"
    )
  end
end
