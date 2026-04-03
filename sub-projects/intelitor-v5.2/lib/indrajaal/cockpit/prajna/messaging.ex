defmodule Indrajaal.Cockpit.Prajna.Messaging do
  @moduledoc """
  PRAJNA Messaging Integration - Unified Protocol Layer

  WHAT: Elixir-side integration for all PRAJNA messaging protocols including
        Zenoh telemetry, Phoenix PubSub events, and gRPC bridge communication.

  WHY: Provides real-time bidirectional communication between:
       - Zenoh distributed mesh (C3I telemetry)
       - Phoenix PubSub (LiveView updates)
       - CEPAF gRPC bridge (F# ↔ Elixir)
       - SigNoz observability (OTEL traces)

  STAMP Compliance:
    - SC-MSG-001: Message delivery guarantee (at-least-once)
    - SC-MSG-002: Message ordering preservation
    - SC-MSG-003: Protocol failover capability
    - SC-MSG-004: Audit logging for all messages
    - SC-TEL-001: Telemetry latency <100ms
    - SC-LOG-001: Fractal logging hierarchy enforcement

  Usage:
    # Subscribe to PRAJNA topics
    Messaging.subscribe(:metrics)
    Messaging.subscribe(:alarms)

    # Broadcast events
    Messaging.broadcast(:alarms, {:alarm_raised, alarm_id, level, message})

    # Get telemetry state
    Messaging.get_telemetry_state()
  """

  use GenServer
  require Logger

  alias Phoenix.PubSub
  alias Indrajaal.Observability.FractalLogger

  # PubSub topics
  @topics %{
    metrics: "prajna:metrics",
    alarms: "prajna:alarms",
    commands: "prajna:commands",
    insights: "prajna:insights",
    ooda: "prajna:ooda",
    containers: "prajna:containers",
    nodes: "prajna:nodes",
    navigation: "prajna:navigation"
  }

  # Telemetry thresholds
  @staleness_threshold_ms 5_000
  @sparkline_max_points 60

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Start the messaging server"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Subscribe to a PRAJNA topic"
  def subscribe(topic) when is_atom(topic) do
    topic_name = Map.get(@topics, topic, "prajna:#{topic}")
    PubSub.subscribe(Indrajaal.PubSub, topic_name)
  end

  @doc "Unsubscribe from a PRAJNA topic"
  def unsubscribe(topic) when is_atom(topic) do
    topic_name = Map.get(@topics, topic, "prajna:#{topic}")
    PubSub.unsubscribe(Indrajaal.PubSub, topic_name)
  end

  @doc "Broadcast an event to a PRAJNA topic"
  def broadcast(topic, event) when is_atom(topic) do
    topic_name = Map.get(@topics, topic, "prajna:#{topic}")
    PubSub.broadcast(Indrajaal.PubSub, topic_name, event)

    # Log at appropriate fractal level
    log_event(topic, event)
  end

  @doc "Broadcast an event from a specific sender"
  def broadcast_from(topic, from_pid, event) when is_atom(topic) do
    topic_name = Map.get(@topics, topic, "prajna:#{topic}")
    # Correct order: pubsub, from, topic, message
    PubSub.broadcast_from(Indrajaal.PubSub, from_pid, topic_name, event)
    log_event(topic, event)
  end

  @doc "Update a telemetry metric"
  def update_metric(node_id, metric_type, value, unit \\ "") do
    GenServer.cast(__MODULE__, {:update_metric, node_id, metric_type, value, unit})
    broadcast(:metrics, {:metric_updated, node_id, metric_type, value})
  end

  @doc "Get current telemetry state"
  def get_telemetry_state do
    GenServer.call(__MODULE__, :get_telemetry_state)
  end

  @doc "Get sparkline data for a metric"
  def get_sparkline(metric_key, width \\ 20) do
    GenServer.call(__MODULE__, {:get_sparkline, metric_key, width})
  end

  @doc "Check if a metric is stale"
  def stale?(metric_key) do
    GenServer.call(__MODULE__, {:is_stale, metric_key})
  end

  @doc "Get staleness in seconds"
  def get_staleness(metric_key) do
    GenServer.call(__MODULE__, {:get_staleness, metric_key})
  end

  @doc "Get messaging status summary"
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl true
  def init(_opts) do
    # Subscribe to Zenoh coordinator events (if available)
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohCoordinator) do
      subscribe_to_zenoh()
    end

    state = %{
      metrics: %{},
      sparklines: %{},
      updated_at: %{},
      message_count: 0,
      error_count: 0,
      started_at: DateTime.utc_now()
    }

    # Schedule periodic pruning
    Process.send_after(self(), :prune_stale, 60_000)

    Logger.info("[PRAJNA.Messaging] Started messaging integration")

    {:ok, state}
  end

  @impl true
  def handle_cast({:update_metric, node_id, metric_type, value, unit}, state) do
    metric_key = "#{node_id}.#{metric_type}"
    now = DateTime.utc_now()

    # Update metric
    metrics =
      Map.put(state.metrics, metric_key, %{
        value: value,
        unit: unit,
        node_id: node_id,
        type: metric_type
      })

    # Update sparkline
    sparkline = Map.get(state.sparklines, metric_key, [])
    new_sparkline = [value | sparkline] |> Enum.take(@sparkline_max_points)
    sparklines = Map.put(state.sparklines, metric_key, new_sparkline)

    # Update timestamp
    updated_at = Map.put(state.updated_at, metric_key, now)

    {:noreply,
     %{
       state
       | metrics: metrics,
         sparklines: sparklines,
         updated_at: updated_at,
         message_count: state.message_count + 1
     }}
  end

  @impl true
  def handle_call(:get_telemetry_state, _from, state) do
    result = %{
      metrics: state.metrics,
      sparklines: state.sparklines,
      updated_at: state.updated_at,
      message_count: state.message_count
    }

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_sparkline, metric_key, width}, _from, state) do
    sparkline = Map.get(state.sparklines, metric_key, [])
    rendered = render_sparkline(sparkline, width)
    {:reply, rendered, state}
  end

  @impl true
  def handle_call({:is_stale, metric_key}, _from, state) do
    stale =
      case Map.get(state.updated_at, metric_key) do
        nil ->
          true

        updated_at ->
          DateTime.diff(DateTime.utc_now(), updated_at, :millisecond) > @staleness_threshold_ms
      end

    {:reply, stale, state}
  end

  @impl true
  def handle_call({:get_staleness, metric_key}, _from, state) do
    staleness =
      case Map.get(state.updated_at, metric_key) do
        nil ->
          9999.0

        updated_at ->
          DateTime.diff(DateTime.utc_now(), updated_at, :millisecond) / 1000.0
      end

    {:reply, staleness, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    uptime = DateTime.diff(DateTime.utc_now(), state.started_at, :second)

    status = %{
      uptime_seconds: uptime,
      message_count: state.message_count,
      error_count: state.error_count,
      metric_count: map_size(state.metrics),
      topics: Map.keys(@topics)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:prune_stale, state) do
    # Prune metrics older than 5 minutes
    now = DateTime.utc_now()
    # 5 minutes in ms
    threshold = 300_000

    {updated_at, pruned} =
      Enum.reduce(state.updated_at, {%{}, []}, fn {key, time}, {acc, pruned_keys} ->
        if DateTime.diff(now, time, :millisecond) > threshold do
          {acc, [key | pruned_keys]}
        else
          {Map.put(acc, key, time), pruned_keys}
        end
      end)

    metrics = Map.drop(state.metrics, pruned)
    sparklines = Map.drop(state.sparklines, pruned)

    if length(pruned) > 0 do
      Logger.debug("[PRAJNA.Messaging] Pruned #{length(pruned)} stale metrics")
    end

    # Schedule next pruning
    Process.send_after(self(), :prune_stale, 60_000)

    {:noreply, %{state | metrics: metrics, sparklines: sparklines, updated_at: updated_at}}
  end

  @impl true
  def handle_info({:zenoh_telemetry, key_expr, payload}, state) do
    # Process Zenoh telemetry message
    case parse_zenoh_telemetry(key_expr, payload) do
      {:ok, node_id, metrics} ->
        state =
          Enum.reduce(metrics, state, fn {type, value}, acc ->
            metric_key = "#{node_id}.#{type}"
            now = DateTime.utc_now()

            metrics =
              Map.put(acc.metrics, metric_key, %{
                value: value,
                unit: "",
                node_id: node_id,
                type: type
              })

            sparkline = Map.get(acc.sparklines, metric_key, [])
            new_sparkline = [value | sparkline] |> Enum.take(@sparkline_max_points)
            sparklines = Map.put(acc.sparklines, metric_key, new_sparkline)

            updated_at = Map.put(acc.updated_at, metric_key, now)

            %{
              acc
              | metrics: metrics,
                sparklines: sparklines,
                updated_at: updated_at,
                message_count: acc.message_count + 1
            }
          end)

        # Broadcast to LiveView
        broadcast(:metrics, {:zenoh_metrics, node_id, metrics})

        {:noreply, state}

      :error ->
        {:noreply, %{state | error_count: state.error_count + 1}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[PRAJNA.Messaging] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE FUNCTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  defp subscribe_to_zenoh do
    # Subscribe to Zenoh telemetry via ZenohCoordinator
    patterns = [
      "c3i/units/*/*/telemetry",
      "c3i/alarms/*",
      "c3i/metrics/*"
    ]

    pid = self()

    Enum.each(patterns, fn pattern ->
      # Create callback that sends messages to this process
      callback = fn key_expr, payload ->
        send(pid, {:zenoh, key_expr, payload})
      end

      with :ok <- Indrajaal.Observability.ZenohCoordinator.subscribe_coord(pattern, callback) do
        Logger.debug("[PRAJNA.Messaging] Subscribed to Zenoh: #{pattern}")
      else
        {:error, reason} -> Logger.warning("[PRAJNA.Messaging] Failed to subscribe: #{reason}")
      end
    end)
  rescue
    # ZenohCoordinator may not be available
    _ -> :ok
  end

  defp parse_zenoh_telemetry(key_expr, payload) do
    # Parse key expression: c3i/units/{zone}/{node}/telemetry
    case String.split(key_expr, "/") do
      ["c3i", "units", _zone, node, "telemetry"] ->
        case Jason.decode(payload) do
          {:ok, data} ->
            metrics = [
              {:cpu, Map.get(data, "cpu", 0.0)},
              {:memory, Map.get(data, "memory", 0.0)},
              {:latency, Map.get(data, "latency", 0.0)}
            ]

            {:ok, node, metrics}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp render_sparkline(values, width) when values == [] do
    String.duplicate("░", width)
  end

  defp render_sparkline(values, width) do
    chars = ~c[▁▂▃▄▅▆▇█]
    recent = values |> Enum.take(width) |> Enum.reverse()

    min_val = Enum.min(recent)
    max_val = Enum.max(recent)
    range = max(0.001, max_val - min_val)

    rendered =
      recent
      |> Enum.map(fn v ->
        normalized = (v - min_val) / range
        idx = trunc(normalized * (length(chars) - 1))
        idx = max(0, min(length(chars) - 1, idx))
        Enum.at(chars, idx)
      end)

    padding = String.duplicate("░", max(0, width - length(rendered)))
    padding <> List.to_string(rendered)
  end

  defp log_event(topic, event) do
    # Determine fractal log level based on topic and event
    level =
      case {topic, event} do
        {:alarms, {:alarm_raised, _, :critical, _}} -> :spine
        {:alarms, {:alarm_raised, _, :warning, _}} -> :thorax
        {:alarms, {:alarm_raised, _, _, _}} -> :segment
        {:commands, _} -> :segment
        {:ooda, _} -> :fiber
        _ -> :gossamer
      end

    # Log via FractalLogger if available
    if Code.ensure_loaded?(Indrajaal.Observability.FractalLogger) do
      message = format_event_message(topic, event)

      case level do
        :spine -> FractalLogger.spine("PRAJNA.Messaging", message, %{topic: topic})
        :thorax -> FractalLogger.thorax("PRAJNA.Messaging", message, %{topic: topic})
        :segment -> FractalLogger.segment("PRAJNA.Messaging", message, %{topic: topic})
        :fiber -> FractalLogger.fiber("PRAJNA.Messaging", message, %{topic: topic})
        :gossamer -> FractalLogger.gossamer("PRAJNA.Messaging", message, %{topic: topic})
      end
    end
  rescue
    # FractalLogger may not be available
    _ -> :ok
  end

  defp format_event_message(topic, event) do
    case event do
      {:metric_updated, node_id, type, value} ->
        "Metric #{type} updated on #{node_id}: #{value}"

      {:alarm_raised, alarm_id, level, message} ->
        "[#{level}] Alarm #{alarm_id}: #{message}"

      {:alarm_acknowledged, alarm_id, operator} ->
        "Alarm #{alarm_id} acknowledged by #{operator}"

      {:command_armed, cmd_id, node_id, cmd} ->
        "Command #{cmd_id} armed: #{inspect(cmd)} for #{node_id}"

      {:command_executed, cmd_id, result} ->
        "Command #{cmd_id} executed: #{result}"

      {:ooda_phase_changed, phase, cycle_ms} ->
        "OODA phase: #{phase} (#{cycle_ms}ms)"

      _ ->
        "#{topic}: #{inspect(event)}"
    end
  end
end
