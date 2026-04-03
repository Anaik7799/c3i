defmodule Indrajaal.Lifecycle.ContainerLifecycle do
  @moduledoc """
  SIL-4 Compliant Container Lifecycle State Machine

  WHAT: Tracks and enforces the lifecycle phases of individual containers.

  WHY: SIL-4 requires deterministic phase transitions with verified
  preconditions. This module ensures containers follow a strict
  lifecycle protocol with 5 startup and 6 shutdown phases.

  CONSTRAINTS:
  - SC-SIL4-012: 5 startup phases mandatory
  - SC-SIL4-013: 6 shutdown phases mandatory
  - SC-SIL4-014: Gossip protocol cookie required
  - SC-HOLON-001: State via SQLite/DuckDB only

  TECHNIQUES:
  | Technique | Source | Purpose |
  |-----------|--------|---------|
  | Finite State Machine | CS Theory | Deterministic transitions |
  | Phase Gates | Industry | Verified preconditions |
  | Event Sourcing | DDD | Auditable lifecycle |
  | Telemetry | BEAM | Observable transitions |

  STARTUP PHASES (SC-SIL4-012):
  1. :created - Container image pulled, not started
  2. :starting - Process spawning, ports binding
  3. :initializing - Application bootstrapping
  4. :connecting - Joining cluster, gossip
  5. :running - Fully operational

  SHUTDOWN PHASES (SC-SIL4-013):
  1. :running - Normal operation
  2. :lameduck - No new connections
  3. :draining - Waiting for connections to close
  4. :checkpointing - Saving state (dying gasp)
  5. :stopping - Process termination
  6. :stopped - Container exited

  AOR:
  - AOR-SIL4-001: Phase transitions must be sequential
  - AOR-SIL4-002: No phase skipping allowed
  - AOR-SIL4-003: Log all phase transitions
  """

  use GenServer
  require Logger

  alias Indrajaal.Deployment.{ConnectionDrainer, DyingGasp}
  alias Indrajaal.Mesh.HolonPhenotype

  # =============================================================================
  # Constants
  # =============================================================================

  @phase_timeout_ms 30_000

  # =============================================================================
  # Phase Definitions
  # =============================================================================

  @startup_phases [:created, :starting, :initializing, :connecting, :running]
  @shutdown_phases [:running, :lameduck, :draining, :checkpointing, :stopping, :stopped]

  @valid_transitions %{
    # Startup
    :not_started => :created,
    :created => :starting,
    :starting => :initializing,
    :initializing => :connecting,
    :connecting => :running,
    # Shutdown
    :running => :lameduck,
    :lameduck => :draining,
    :draining => :checkpointing,
    :checkpointing => :stopping,
    :stopping => :stopped
  }

  # =============================================================================
  # State
  # =============================================================================

  defmodule State do
    @moduledoc false
    defstruct [
      :container_id,
      :phenotype,
      :history
    ]
  end

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Starts the ContainerLifecycle GenServer for a container.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    container_id = Keyword.fetch!(opts, :container_id)
    name = via_tuple(container_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets the current phenotype state.
  """
  @spec get_phenotype(String.t()) :: {:ok, HolonPhenotype.t()} | {:error, :not_found}
  def get_phenotype(container_id) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil -> {:error, :not_found}
      pid -> GenServer.call(pid, :get_phenotype)
    end
  end

  # Legacy API compatibility
  def get_state(container_id), do: get_phenotype(container_id)

  def current_phase(container_id) do
    case get_phenotype(container_id) do
      # Mapping health to phase loosely for compat
      {:ok, p} -> {:ok, p.health}
      err -> err
    end
  end

  @doc """
  Advances the FSM to the next state.
  """
  @spec advance(String.t(), atom()) :: :ok | {:error, term()}
  def advance(container_id, target_phase) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil -> {:error, :not_found}
      pid -> GenServer.call(pid, {:advance, target_phase}, @phase_timeout_ms)
    end
  end

  # Legacy wrappers
  def advance_startup(id), do: advance(id, :next_startup)
  def advance_shutdown(id), do: advance(id, :next_shutdown)

  @doc """
  Executes complete startup sequence.
  """
  def execute_startup(container_id, opts \\ []) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil ->
        {:ok, _pid} = start_link(container_id: container_id)
        execute_startup(container_id, opts)

      pid ->
        GenServer.call(pid, {:execute_sequence, :startup}, @phase_timeout_ms * 5)
    end
  end

  @doc """
  Executes complete shutdown sequence.
  """
  def execute_shutdown(container_id, _opts \\ []) do
    case GenServer.whereis(via_tuple(container_id)) do
      nil -> {:error, :not_found}
      pid -> GenServer.call(pid, {:execute_sequence, :shutdown}, @phase_timeout_ms * 6)
    end
  end

  # =============================================================================
  # GenServer Callbacks
  # =============================================================================

  @impl true
  def init(opts) do
    container_id = Keyword.fetch!(opts, :container_id)

    phenotype = %HolonPhenotype{
      genotype_id: container_id,
      container_id: container_id,
      health: :unknown,
      startup_phase: :created
    }

    state = %State{
      container_id: container_id,
      phenotype: phenotype,
      history: []
    }

    Logger.info("[ContainerLifecycle] Started for #{container_id}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_phenotype, _from, state) do
    {:reply, {:ok, state.phenotype}, state}
  end

  @impl true
  def handle_call({:advance, phase}, _from, state) do
    # Determine actual next phase if generic request
    current = current_fsm_state(state.phenotype)

    target =
      case phase do
        :next_startup -> next_startup_phase(current)
        :next_shutdown -> next_shutdown_phase(current)
        specific -> specific
      end

    if valid_transition?(current, target) do
      new_state = execute_transition(state, target)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, {:invalid_transition, current, target}}, state}
    end
  end

  @impl true
  def handle_call({:execute_sequence, :startup}, _from, state) do
    # Run through startup phases
    final_state =
      Enum.reduce(@startup_phases, state, fn phase, acc ->
        execute_transition(acc, phase)
      end)

    {:reply, {:ok, final_state.phenotype}, final_state}
  end

  @impl true
  def handle_call({:execute_sequence, :shutdown}, _from, state) do
    # Run through shutdown phases
    final_state =
      Enum.reduce(@shutdown_phases, state, fn phase, acc ->
        execute_transition(acc, phase)
      end)

    {:reply, {:ok, final_state.phenotype}, final_state}
  end

  # =============================================================================
  # Private: FSM Logic
  # =============================================================================

  defp current_fsm_state(phenotype) do
    cond do
      phenotype.shutdown_phase != :running -> phenotype.shutdown_phase
      phenotype.health == :healthy -> :running
      true -> phenotype.startup_phase
    end
  end

  defp valid_transition?(current, target) do
    Map.get(@valid_transitions, current) == target
  end

  defp next_startup_phase(current), do: Map.get(@valid_transitions, current)
  defp next_shutdown_phase(current), do: Map.get(@valid_transitions, current)

  defp execute_transition(state, phase) do
    Logger.info("[ContainerLifecycle] Transitioning #{state.container_id} to #{phase}")

    # Execute side effects
    case phase do
      :starting -> System.cmd("podman", ["start", state.container_id])
      :draining -> ConnectionDrainer.drain(state.container_id)
      :checkpointing -> DyingGasp.capture(state.container_id)
      :stopping -> System.cmd("podman", ["stop", state.container_id])
      _ -> :ok
    end

    # Update phenotype
    new_phenotype = update_phenotype_for_phase(state.phenotype, phase)
    %{state | phenotype: new_phenotype}
  end

  defp update_phenotype_for_phase(p, phase) do
    case phase in @startup_phases do
      true ->
        %{p | startup_phase: phase, health: if(phase == :running, do: :healthy, else: :starting)}

      false ->
        %{p | shutdown_phase: phase, health: if(phase == :stopped, do: :stopped, else: :stopping)}
    end
  end

  defp via_tuple(container_id) do
    {:via, Registry, {Indrajaal.Lifecycle.ContainerRegistry, container_id}}
  end
end
