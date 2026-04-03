defmodule Indrajaal.Distributed.Agents.FractalAgent do
  @moduledoc """
  Agent 4: Fractal - 5-Level Controllable Logging Agent.

  WHAT: Manages distributed fractal logging with dynamic level control.
  WHY: SC-LOG-001 requires async, controllable logging across mesh.
  CONSTRAINTS: Log routing < 1ms, level changes propagate mesh-wide.

  ## Fractal Levels

  1. **L0**: Critical system events (always logged)
  2. **L1**: Error conditions and failures
  3. **L2**: Warnings and degraded states
  4. **L3**: Informational messages
  5. **L4**: Debug and trace data

  ## STAMP Constraints
  - SC-LOG-001: Async logging implementation
  - SC-LOG-002: 5-level controllable hierarchy
  - SC-LOG-003: Log level changes via Zenoh
  - SC-LOG-006: HLC timestamps for causality

  ## Mathematical Specification

  ```
  Fractal := (Levels, Router, Encoder, Filter)

  Levels = {L0, L1, L2, L3, L4}
  Priority: L0 > L1 > L2 > L3 > L4

  Router: LogEvent → Destination
  Encoder: LogEvent → WireFormat
  Filter: LogEvent × CurrentLevel → Bool

  Filtering Invariant:
    ∀ event: Level(event) ≤ CurrentLevel ⟹ Emit(event)
  ```
  """

  use Indrajaal.Distributed.Agents.BaseAgent,
    type: :observability,
    namespace: "fractal",
    name: "logger"

  # ============================================================
  # AGENT CALLBACKS
  # ============================================================

  @impl true
  def agent_init(_opts) do
    state = %{
      # Current log level (0-4)
      current_level: 3,

      # Per-module overrides
      module_levels: %{},

      # Routing configuration
      routes: %{
        console: %{enabled: true, min_level: 0, max_level: 4},
        signoz: %{enabled: true, min_level: 0, max_level: 2},
        file: %{enabled: true, min_level: 0, max_level: 4, path: "data/logs/fractal.log"},
        zenoh: %{enabled: true, min_level: 0, max_level: 1}
      },

      # Batch configuration
      batch: %{
        size: 100,
        timeout_ms: 1000,
        current: [],
        pending_count: 0
      },

      # Metrics
      events_received: 0,
      events_filtered: 0,
      events_routed: 0,
      batches_flushed: 0,

      # Boost state
      boost: %{
        active: false,
        original_level: 3,
        expires_at: nil
      }
    }

    {:ok, state}
  end

  @impl true
  def agent_state(state) do
    %{
      current_level: state.current_level,
      level_name: level_name(state.current_level),
      module_overrides: map_size(state.module_levels),
      routes: route_summary(state.routes),
      batch_pending: state.batch.pending_count,
      boost_active: state.boost.active
    }
  end

  @impl true
  def agent_metrics(state) do
    %{
      current_level: state.current_level,
      events_received: state.events_received,
      events_filtered: state.events_filtered,
      events_routed: state.events_routed,
      filter_ratio: safe_ratio(state.events_filtered, state.events_received),
      batches_flushed: state.batches_flushed,
      batch_pending: state.batch.pending_count
    }
  end

  @impl true
  def handle_command(:set_level, params, state) do
    level = Map.get(params, :level, state.current_level)

    if level in 0..4 do
      new_state = %{state | current_level: level}

      # Publish level change to Zenoh
      publish_level_change(level)

      {:ok, %{level: level, name: level_name(level)}, new_state}
    else
      {:error, :invalid_level, state}
    end
  end

  @impl true
  def handle_command(:set_module_level, params, state) do
    module = Map.get(params, :module)
    level = Map.get(params, :level)

    if level in 0..4 do
      new_levels = Map.put(state.module_levels, module, level)
      new_state = %{state | module_levels: new_levels}
      {:ok, :updated, new_state}
    else
      {:error, :invalid_level, state}
    end
  end

  @impl true
  def handle_command(:clear_module_level, params, state) do
    module = Map.get(params, :module)
    new_levels = Map.delete(state.module_levels, module)
    new_state = %{state | module_levels: new_levels}
    {:ok, :cleared, new_state}
  end

  @impl true
  def handle_command(:boost, params, state) do
    level = Map.get(params, :level, 4)
    duration_ms = Map.get(params, :duration_ms, 60_000)

    expires_at = DateTime.add(DateTime.utc_now(), duration_ms, :millisecond)

    new_boost = %{
      active: true,
      original_level: state.current_level,
      expires_at: expires_at
    }

    new_state = %{state | current_level: level, boost: new_boost}

    # Schedule boost expiry
    Process.send_after(self(), :boost_expired, duration_ms)

    {:ok, %{boosted_to: level, expires_at: expires_at}, new_state}
  end

  @impl true
  def handle_command(:log, params, state) do
    event = Map.get(params, :event)
    level = Map.get(params, :level, 3)
    module = Map.get(params, :module)

    effective_level = get_effective_level(module, state)

    if level <= effective_level do
      # Route the event
      routed = route_event(event, level, state.routes)

      new_state = %{
        state
        | events_received: state.events_received + 1,
          events_routed: state.events_routed + 1
      }

      {:ok, %{routed_to: routed}, new_state}
    else
      new_state = %{
        state
        | events_received: state.events_received + 1,
          events_filtered: state.events_filtered + 1
      }

      {:ok, :filtered, new_state}
    end
  end

  @impl true
  def handle_command(:flush, _params, state) do
    # Flush pending batch
    flushed_count = flush_batch(state.batch.current)

    new_batch = %{state.batch | current: [], pending_count: 0}
    new_state = %{state | batch: new_batch, batches_flushed: state.batches_flushed + 1}

    {:ok, %{flushed: flushed_count}, new_state}
  end

  @impl true
  def handle_command(:configure_route, params, state) do
    route = Map.get(params, :route)
    config = Map.get(params, :config, %{})

    if Map.has_key?(state.routes, route) do
      new_route_config = Map.merge(state.routes[route], config)
      new_routes = Map.put(state.routes, route, new_route_config)
      new_state = %{state | routes: new_routes}
      {:ok, :updated, new_state}
    else
      {:error, :invalid_route, state}
    end
  end

  @impl true
  def handle_command(unknown, _params, state) do
    {:error, {:unknown_command, unknown}, state}
  end

  # Handle boost expiry
  @impl Indrajaal.Distributed.Agents.BaseAgent
  def handle_agent_info(:boost_expired, state) do
    if state.boost.active do
      new_state = %{
        state
        | current_level: state.boost.original_level,
          boost: %{active: false, original_level: 3, expires_at: nil}
      }

      Logger.info("[FractalAgent] Boost expired, level restored to #{state.boost.original_level}")
      {:ok, new_state}
    else
      :ignore
    end
  end

  def handle_agent_info(_msg, _state), do: :ignore

  # ============================================================
  # FRACTAL IMPLEMENTATION
  # ============================================================

  defp level_name(0), do: :critical
  defp level_name(1), do: :error
  defp level_name(2), do: :warning
  defp level_name(3), do: :info
  defp level_name(4), do: :debug
  defp level_name(_), do: :unknown

  defp get_effective_level(nil, state), do: state.current_level

  defp get_effective_level(module, state) do
    Map.get(state.module_levels, module, state.current_level)
  end

  defp route_event(_event, level, routes) do
    routes
    |> Enum.filter(fn {_name, config} ->
      config.enabled && level >= config.min_level && level <= config.max_level
    end)
    |> Enum.map(fn {name, _config} ->
      # Simulate routing
      name
    end)
  end

  defp flush_batch([]), do: 0
  defp flush_batch(events), do: length(events)

  defp publish_level_change(level) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "fractal/level",
      %{level: level, name: level_name(level), timestamp: DateTime.utc_now()}
    )
  rescue
    _ -> :ok
  end

  defp route_summary(routes) do
    mapped =
      Enum.map(routes, fn {name, config} ->
        {name, %{enabled: config.enabled, levels: "#{config.min_level}-#{config.max_level}"}}
      end)

    mapped |> Map.new()
  end

  defp safe_ratio(_, 0), do: 0.0
  defp safe_ratio(num, denom), do: Float.round(num / denom, 3)
end
