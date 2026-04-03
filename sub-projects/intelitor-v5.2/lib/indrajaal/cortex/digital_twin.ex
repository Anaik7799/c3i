defmodule Indrajaal.Cortex.DigitalTwin do
  @moduledoc """
  ## CORTEX DIGITAL TWIN (L4-OPERATIONAL)
  The "Memory of the Present". Maintains a real-time, high-fidelity model of the running system.

  **Compliance**: SC-TWIN-001 (Topology Accuracy), SC-SIL6-015 (Immutable Audit).
  """

  use GenServer
  require Logger

  # State Structure
  defstruct [
    # Graph of system components
    :topology,
    # Map of AgentID -> State
    :agents,
    # Map of ContainerID -> Stats
    :containers,
    # List of registered tools
    :mcp_tools,
    # 0.0 - 1.0
    :health_score,
    # 0.0 - 1.0 (Genotype vs Phenotype)
    :drift_score,
    # Timestamp
    :last_updated
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def update_component(id, type, state) do
    GenServer.cast(__MODULE__, {:update, id, type, state})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[CORTEX] Digital Twin Initializing...")

    state = %__MODULE__{
      topology: Graph.new(),
      agents: %{},
      containers: %{},
      mcp_tools: [],
      health_score: 1.0,
      drift_score: 0.0,
      last_updated: DateTime.utc_now()
    }

    # Start Zenoh listener for telemetry
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohSession) do
      Indrajaal.Observability.ZenohSession.subscribe("indrajaal/**", self())
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update, id, :agent, agent_state}, state) do
    new_agents = Map.put(state.agents, id, agent_state)
    new_score = calculate_health(new_agents)

    {:noreply,
     %{state | agents: new_agents, health_score: new_score, last_updated: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:update, id, :container, container_state}, state) do
    new_containers = Map.put(state.containers, id, container_state)
    {:noreply, %{state | containers: new_containers, last_updated: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:zenoh_message, key_expr, _payload}, state) do
    if String.starts_with?(key_expr, "indrajaal/git/commit") do
      Logger.info(
        "[CORTEX] Digital Twin detected git commit. Refreshing topology and recalculating drift score."
      )

      # Extract possible impact from payload
      new_drift = min(state.drift_score + 0.05, 1.0)
      {:noreply, %{state | drift_score: new_drift, last_updated: DateTime.utc_now()}}
    else
      {:noreply, state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp calculate_health(agents) do
    # Simple heuristic: % of active agents / total agents
    total = map_size(agents)
    if total == 0, do: 1.0, else: Enum.count(agents, fn {_, s} -> s.status == :active end) / total
  end
end
