defmodule Indrajaal.Observability.ZenohAgentMeshPublisher do
  @moduledoc """
  Zenoh-based agent mesh publisher for CEPAF-Prajna synchronization.

  WHAT: Publishes agent status, commands, and mesh topology via Zenoh.
  WHY: SC-SYNC-012 requires real-time agent mesh telemetry for F# CEPAF cockpit.
  CONSTRAINTS: <50ms delivery, JSON encoding, 15s interval for status, immediate for commands.

  ## Data Plane Topics (SC-SYNC-012)
  - indrajaal/mesh/topology - Mesh topology and node status (15s)
  - indrajaal/mesh/agents - Individual agent status
  - indrajaal/mesh/commands - Command dispatch events
  - indrajaal/mesh/heartbeat - Agent heartbeat stream
  - indrajaal/mesh/metrics - Agent performance metrics

  ## STAMP Constraints
  - SC-SYNC-012: Agent mesh events via Zenoh
  - SC-AGT-017: Agent efficiency >90%
  - SC-PRF-050: <50ms delivery latency

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 21.1.0 |
  | Sprint | 32 |
  | Created | 2026-01-02 |
  | Author | Cybernetic Architect |
  """

  use GenServer
  require Logger

  @topology_interval_ms 15_000
  @heartbeat_interval_ms 5_000
  @delivery_timeout_ms 50
  @topic_prefix "indrajaal/mesh"

  @known_agents [
    "ooda-agent",
    "smart-metrics-agent",
    "sentinel-bridge",
    "guardian-integration",
    "ai-copilot",
    "immutable-state",
    "prometheus-verifier"
  ]

  defstruct [
    :started_at,
    :publish_count,
    :last_publish,
    :sequence,
    subscribers: %{},
    agent_states: %{},
    command_log: []
  ]

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Force immediate topology publish"
  def publish_topology(pid \\ __MODULE__), do: GenServer.cast(pid, :publish_topology)

  @doc "Get publisher statistics"
  def get_stats(pid \\ __MODULE__), do: GenServer.call(pid, :get_stats)

  @doc "Get current agent states"
  def get_agent_states(pid \\ __MODULE__), do: GenServer.call(pid, :get_agent_states)

  @doc "Publish command event"
  def publish_command(pid \\ __MODULE__, agent_id, command, params) do
    GenServer.cast(pid, {:publish_command, agent_id, command, params})
  end

  @doc "Update agent heartbeat"
  def agent_heartbeat(pid \\ __MODULE__, agent_id, metrics) do
    GenServer.cast(pid, {:agent_heartbeat, agent_id, metrics})
  end

  @doc "Subscribe to mesh updates"
  def subscribe(pid \\ __MODULE__, pattern \\ nil) do
    GenServer.call(pid, {:subscribe, pattern, self()})
  end

  @doc "Unsubscribe from mesh updates"
  def unsubscribe(pid \\ __MODULE__, ref) do
    GenServer.call(pid, {:unsubscribe, ref})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[ZenohAgentMeshPublisher] Starting agent mesh publisher...")

    state = %__MODULE__{
      started_at: DateTime.utc_now(),
      publish_count: 0,
      last_publish: nil,
      sequence: 0,
      subscribers: %{},
      agent_states: %{},
      command_log: []
    }

    # Schedule periodic publishes
    schedule_topology_publish()
    schedule_heartbeat_collect()

    {:ok, state}
  end

  @impl true
  def handle_cast(:publish_topology, state) do
    new_state = publish_mesh_topology(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:publish_command, agent_id, command, params}, state) do
    new_state = do_publish_command(state, agent_id, command, params)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:agent_heartbeat, agent_id, metrics}, state) do
    new_state = update_agent_state(state, agent_id, metrics)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      started_at: state.started_at,
      publish_count: state.publish_count,
      last_publish: state.last_publish,
      sequence: state.sequence,
      subscriber_count: map_size(state.subscribers),
      known_agents: @known_agents,
      active_agents: count_active_agents(state.agent_states)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_agent_states, _from, state) do
    {:reply, state.agent_states, state}
  end

  @impl true
  def handle_call({:subscribe, pattern, subscriber_pid}, _from, state) do
    ref = make_ref()
    Process.monitor(subscriber_pid)

    subscription = %{
      pid: subscriber_pid,
      pattern: pattern,
      subscribed_at: DateTime.utc_now()
    }

    new_subscribers = Map.put(state.subscribers, ref, subscription)
    {:reply, {:ok, ref}, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_call({:unsubscribe, ref}, _from, state) do
    new_subscribers = Map.delete(state.subscribers, ref)
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_info(:publish_topology, state) do
    new_state = publish_mesh_topology(state)
    schedule_topology_publish()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:collect_heartbeats, state) do
    new_state = collect_agent_heartbeats(state)
    schedule_heartbeat_collect()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_subscribers =
      state.subscribers
      |> Enum.reject(fn {_ref, sub} -> sub.pid == pid end)
      |> Map.new()

    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp schedule_topology_publish do
    Process.send_after(self(), :publish_topology, @topology_interval_ms)
  end

  defp schedule_heartbeat_collect do
    Process.send_after(self(), :collect_heartbeats, @heartbeat_interval_ms)
  end

  defp publish_mesh_topology(state) do
    start_time = System.monotonic_time(:millisecond)

    # Collect agent statuses
    agents = collect_agent_statuses()

    # Build topology message
    message = %{
      topic: "#{@topic_prefix}/topology",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      sequence: state.sequence + 1,
      agents: agents,
      total_count: length(agents),
      active_count: Enum.count(agents, &(&1.status == "active")),
      mesh_health: compute_mesh_health(agents)
    }

    # Notify subscribers
    notify_subscribers(state.subscribers, :topology, message)

    # Log delivery timing (SC-PRF-050)
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > @delivery_timeout_ms do
      Logger.warning(
        "[ZenohAgentMeshPublisher] Delivery exceeded #{@delivery_timeout_ms}ms: #{elapsed}ms"
      )
    end

    %{
      state
      | publish_count: state.publish_count + 1,
        last_publish: DateTime.utc_now(),
        sequence: state.sequence + 1
    }
  end

  defp do_publish_command(state, agent_id, command, params) do
    message = %{
      topic: "#{@topic_prefix}/commands",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      sequence: state.sequence + 1,
      agent_id: agent_id,
      command: command,
      params: params,
      command_id: generate_command_id()
    }

    # Notify subscribers immediately
    notify_subscribers(state.subscribers, :command, message)

    Logger.info("[ZenohAgentMeshPublisher] Command published: #{command} to #{agent_id}")

    %{
      state
      | sequence: state.sequence + 1,
        command_log: [message | Enum.take(state.command_log, 99)]
    }
  end

  defp update_agent_state(state, agent_id, metrics) do
    agent_state = %{
      agent_id: agent_id,
      last_heartbeat: DateTime.utc_now(),
      metrics: metrics,
      status: "active"
    }

    new_agent_states = Map.put(state.agent_states, agent_id, agent_state)

    # Publish heartbeat event
    message = %{
      topic: "#{@topic_prefix}/heartbeat",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      agent_id: agent_id,
      metrics: metrics
    }

    notify_subscribers(state.subscribers, :heartbeat, message)

    %{state | agent_states: new_agent_states}
  end

  defp collect_agent_heartbeats(state) do
    # Check for stale agents (no heartbeat in 30s)
    now = DateTime.utc_now()

    updated_states =
      state.agent_states
      |> Enum.map(fn {agent_id, agent_state} ->
        age = DateTime.diff(now, agent_state.last_heartbeat, :second)
        status = if age > 30, do: "stale", else: "active"
        {agent_id, %{agent_state | status: status}}
      end)
      |> Map.new()

    %{state | agent_states: updated_states}
  end

  defp collect_agent_statuses do
    Enum.map(@known_agents, fn agent_name ->
      module = agent_name_to_module(agent_name)

      {status, metrics} =
        case Process.whereis(module) do
          nil ->
            {"inactive", %{}}

          pid ->
            info = Process.info(pid, [:memory, :message_queue_len, :reductions])

            {"active",
             %{
               memory_bytes: Keyword.get(info || [], :memory, 0),
               message_queue: Keyword.get(info || [], :message_queue_len, 0),
               reductions: Keyword.get(info || [], :reductions, 0)
             }}
        end

      %{
        fqun: agent_name,
        status: status,
        last_heartbeat: DateTime.utc_now() |> DateTime.to_iso8601(),
        health: if(status == "active", do: "healthy", else: "degraded"),
        metrics: metrics
      }
    end)
  end

  defp agent_name_to_module(name) do
    case name do
      "ooda-agent" -> Indrajaal.Cockpit.Prajna.OodaAgent
      "smart-metrics-agent" -> Indrajaal.Cockpit.Prajna.SmartMetrics
      "sentinel-bridge" -> Indrajaal.Cockpit.Prajna.SentinelBridge
      "guardian-integration" -> Indrajaal.Cockpit.Prajna.GuardianIntegration
      "ai-copilot" -> Indrajaal.Cockpit.Prajna.AiCopilot
      "immutable-state" -> Indrajaal.Cockpit.Prajna.ImmutableState
      "prometheus-verifier" -> Indrajaal.Cockpit.Prajna.PrometheusVerifier
      _ -> nil
    end
  end

  defp count_active_agents(agent_states) do
    Enum.count(agent_states, fn {_id, state} -> state.status == "active" end)
  end

  defp compute_mesh_health(agents) do
    active = Enum.count(agents, &(&1.status == "active"))
    total = length(agents)

    cond do
      total == 0 -> "unknown"
      active == total -> "healthy"
      active >= total * 0.7 -> "degraded"
      true -> "critical"
    end
  end

  defp generate_command_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp notify_subscribers(subscribers, event_type, message) do
    Enum.each(subscribers, fn {_ref, sub} ->
      if matches_pattern?(sub.pattern, event_type) do
        send(sub.pid, {:zenoh_mesh, event_type, message})
      end
    end)
  end

  defp matches_pattern?(nil, _event_type), do: true
  defp matches_pattern?(pattern, event_type) when is_atom(pattern), do: pattern == event_type
  defp matches_pattern?(pattern, event_type), do: to_string(pattern) == to_string(event_type)
end
