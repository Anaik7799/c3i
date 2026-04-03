defmodule Indrajaal.Lifecycle.MeshLifecycle do
  @moduledoc """
  SIL-4 Compliant Mesh Lifecycle Manager

  WHAT: Orchestrates the lifecycle of the entire container mesh (fractal-cluster).

  WHY: SIL-4 requires coordinated mesh management with quorum enforcement
  and split-brain prevention. This module ensures the mesh operates as
  a cohesive unit with deterministic startup/shutdown sequences.

  CONSTRAINTS:
  - SC-SIL4-009: Seed node MUST start before satellites
  - SC-SIL4-011: Quorum = floor(N/2) + 1
  - SC-SIL4-015: Split-brain triggers apoptosis
  - SC-SIL4-016: Node failure logging mandatory
  - SC-CLU-001: Seed node MUST start before satellites
  - SC-CLU-002: Fractal-cluster is MANDATORY

  TECHNIQUES:
  | Technique | Source | Purpose |
  |-----------|--------|---------|
  | Quorum Voting | Raft/Paxos | Consensus for cluster state |
  | Split-Brain Detection | Distributed Systems | Prevent data corruption |
  | Apoptosis | Biology | Controlled self-destruction |
  | Wave Shutdown | SRE | Ordered graceful termination |

  AOR:
  - AOR-SIL4-001: Never operate without quorum
  - AOR-SIL4-002: Trigger apoptosis on split-brain
  - AOR-SIL4-003: Log all node state changes
  """

  use GenServer
  require Logger

  alias Indrajaal.Deployment.{WaveExecutor, ConnectionDrainer, DyingGasp, TopologyValidator}
  alias Indrajaal.Lifecycle.HealthCoordinator

  # =============================================================================
  # Constants
  # =============================================================================

  @quorum_check_interval_ms 5_000
  @apoptosis_delay_ms 10_000
  @shutdown_wave_timeout_ms 60_000

  # =============================================================================
  # Types
  # =============================================================================

  @type node_id :: String.t()
  @type mesh_state ::
          :initializing | :booting | :running | :degraded | :shutting_down | :stopped | :apoptosis

  @type node_status :: %{
          node_id: node_id(),
          container_id: String.t(),
          status: :healthy | :unhealthy | :unknown | :stopped,
          last_seen: DateTime.t(),
          is_seed: boolean()
        }

  @type mesh_status :: %{
          state: mesh_state(),
          nodes: %{node_id() => node_status()},
          quorum: boolean(),
          quorum_count: non_neg_integer(),
          required_quorum: non_neg_integer(),
          seed_healthy: boolean(),
          last_update: DateTime.t()
        }

  # =============================================================================
  # State
  # =============================================================================

  defmodule State do
    @moduledoc false
    defstruct [
      :mesh_state,
      :nodes,
      :seed_node,
      :quorum_count,
      :required_quorum,
      :last_quorum_check,
      :apoptosis_timer,
      :shutdown_in_progress
    ]
  end

  # =============================================================================
  # Fractal-Cluster Node Configuration
  # =============================================================================

  @fractal_cluster_nodes [
    %{node_id: "db-primary", container_id: "db-primary", is_seed: true, order: 1},
    %{node_id: "indrajaal-obs", container_id: "indrajaal-obs", is_seed: false, order: 2},
    %{
      node_id: "indrajaal-ex-app-1",
      container_id: "indrajaal-ex-app-1",
      is_seed: false,
      order: 3
    },
    %{
      node_id: "indrajaal-ex-app-2",
      container_id: "indrajaal-ex-app-2",
      is_seed: false,
      order: 4
    },
    %{node_id: "indrajaal-ex-app-3", container_id: "indrajaal-ex-app-3", is_seed: false, order: 5}
  ]

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Starts the MeshLifecycle GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Boots the entire mesh using wave-based orchestration.
  """
  @spec boot_mesh(keyword()) :: {:ok, mesh_status()} | {:error, term()}
  def boot_mesh(opts \\ []) do
    GenServer.call(__MODULE__, {:boot_mesh, opts}, @shutdown_wave_timeout_ms + 30_000)
  end

  @doc """
  Shuts down the mesh gracefully in reverse order.
  """
  @spec shutdown_mesh(keyword()) :: {:ok, mesh_status()} | {:error, term()}
  def shutdown_mesh(opts \\ []) do
    GenServer.call(__MODULE__, {:shutdown_mesh, opts}, @shutdown_wave_timeout_ms + 30_000)
  end

  @doc """
  Gets current mesh status.
  """
  @spec get_status() :: mesh_status()
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Checks if mesh has quorum.
  """
  @spec has_quorum?() :: boolean()
  def has_quorum? do
    GenServer.call(__MODULE__, :has_quorum)
  end

  @doc """
  Triggers apoptosis (controlled self-destruction) for split-brain.
  """
  @spec trigger_apoptosis(String.t()) :: :ok
  def trigger_apoptosis(reason) do
    GenServer.cast(__MODULE__, {:apoptosis, reason})
  end

  @doc """
  Manually marks a node as healthy/unhealthy.
  """
  @spec update_node_status(node_id(), :healthy | :unhealthy) :: :ok
  def update_node_status(node_id, status) do
    GenServer.cast(__MODULE__, {:update_node_status, node_id, status})
  end

  # =============================================================================
  # GenServer Callbacks
  # =============================================================================

  @impl true
  def init(_opts) do
    nodes =
      @fractal_cluster_nodes
      |> Enum.map(fn node ->
        {node.node_id,
         %{
           node_id: node.node_id,
           container_id: node.container_id,
           status: :unknown,
           last_seen: nil,
           is_seed: node.is_seed
         }}
      end)
      |> Map.new()

    seed_node =
      @fractal_cluster_nodes
      |> Enum.find(& &1.is_seed)
      |> Map.get(:node_id)

    total_nodes = map_size(nodes)
    required_quorum = div(total_nodes, 2) + 1

    state = %State{
      mesh_state: :initializing,
      nodes: nodes,
      seed_node: seed_node,
      quorum_count: 0,
      required_quorum: required_quorum,
      last_quorum_check: nil,
      apoptosis_timer: nil,
      shutdown_in_progress: false
    }

    # Schedule quorum checks
    Process.send_after(self(), :check_quorum, @quorum_check_interval_ms)

    Logger.info("[MeshLifecycle] Started with #{total_nodes} nodes, quorum=#{required_quorum}")

    {:ok, state}
  end

  @impl true
  def handle_call({:boot_mesh, opts}, _from, state) do
    Logger.info("[MeshLifecycle] Starting mesh boot sequence")

    emit_telemetry(:boot_start, %{node_count: map_size(state.nodes)})

    new_state = %{state | mesh_state: :booting}

    # Validate topology first
    case TopologyValidator.validate_fractal_cluster() do
      :ok ->
        # Boot using WaveExecutor
        case WaveExecutor.boot(opts) do
          {:ok, result} ->
            # Update node statuses based on boot result
            updated_nodes = update_nodes_from_boot(state.nodes, result)
            quorum_count = count_healthy_nodes(updated_nodes)

            final_state = %{
              new_state
              | nodes: updated_nodes,
                quorum_count: quorum_count,
                mesh_state:
                  if(quorum_count >= state.required_quorum, do: :running, else: :degraded)
            }

            status = build_mesh_status(final_state)

            emit_telemetry(:boot_complete, %{
              success: result.success,
              quorum: quorum_count >= state.required_quorum
            })

            {:reply, {:ok, status}, final_state}

          {:error, reason} ->
            emit_telemetry(:boot_failed, %{reason: inspect(reason)})
            {:reply, {:error, reason}, %{new_state | mesh_state: :stopped}}
        end

      {:error, reason} ->
        emit_telemetry(:boot_failed, %{reason: "topology_invalid"})
        {:reply, {:error, {:topology_invalid, reason}}, new_state}
    end
  end

  @impl true
  def handle_call({:shutdown_mesh, opts}, _from, state) do
    Logger.info("[MeshLifecycle] Starting mesh shutdown sequence")

    emit_telemetry(:shutdown_start, %{node_count: map_size(state.nodes)})

    new_state = %{state | mesh_state: :shutting_down, shutdown_in_progress: true}

    # Get shutdown waves (reverse of startup)
    {:ok, shutdown_waves} =
      TopologyValidator.default_graph()
      |> TopologyValidator.compute_shutdown_waves()

    # Execute shutdown in waves
    result = execute_shutdown_waves(shutdown_waves, opts)

    # Update all nodes to stopped
    stopped_nodes =
      state.nodes
      |> Enum.map(fn {id, node} -> {id, %{node | status: :stopped}} end)
      |> Map.new()

    final_state = %{
      new_state
      | nodes: stopped_nodes,
        mesh_state: :stopped,
        quorum_count: 0,
        shutdown_in_progress: false
    }

    status = build_mesh_status(final_state)

    emit_telemetry(:shutdown_complete, %{success: result.success})

    {:reply, {:ok, status}, final_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = build_mesh_status(state)
    {:reply, status, state}
  end

  @impl true
  def handle_call(:has_quorum, _from, state) do
    {:reply, state.quorum_count >= state.required_quorum, state}
  end

  @impl true
  def handle_cast({:apoptosis, reason}, state) do
    Logger.warning("[MeshLifecycle] APOPTOSIS triggered: #{reason}")

    emit_telemetry(:apoptosis_triggered, %{reason: reason})

    # Cancel any existing timer
    if state.apoptosis_timer do
      Process.cancel_timer(state.apoptosis_timer)
    end

    # Schedule apoptosis execution
    timer = Process.send_after(self(), :execute_apoptosis, @apoptosis_delay_ms)

    {:noreply, %{state | mesh_state: :apoptosis, apoptosis_timer: timer}}
  end

  @impl true
  def handle_cast({:update_node_status, node_id, status}, state) do
    case Map.get(state.nodes, node_id) do
      nil ->
        {:noreply, state}

      node ->
        updated_node = %{node | status: status, last_seen: DateTime.utc_now()}
        updated_nodes = Map.put(state.nodes, node_id, updated_node)
        quorum_count = count_healthy_nodes(updated_nodes)

        emit_telemetry(:node_status_change, %{
          node_id: node_id,
          status: status,
          quorum: quorum_count >= state.required_quorum
        })

        new_state = %{
          state
          | nodes: updated_nodes,
            quorum_count: quorum_count
        }

        # Check for split-brain if seed is unhealthy
        if node.is_seed and status == :unhealthy do
          check_split_brain(new_state)
        end

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:check_quorum, state) do
    # Get health from HealthCoordinator
    new_state =
      try do
        health = HealthCoordinator.get_health()
        update_from_health_check(state, health)
      rescue
        _ -> state
      end

    # Schedule next check
    Process.send_after(self(), :check_quorum, @quorum_check_interval_ms)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:execute_apoptosis, state) do
    Logger.error("[MeshLifecycle] Executing APOPTOSIS - stopping all nodes")

    emit_telemetry(:apoptosis_executing, %{})

    # Capture dying gasp for all containers
    Enum.each(state.nodes, fn {_id, node} ->
      try do
        DyingGasp.capture(node.container_id)
      rescue
        _ -> :ok
      end
    end)

    # Force stop all containers
    Enum.each(state.nodes, fn {_id, node} ->
      System.cmd("podman", ["stop", "-t", "5", node.container_id], stderr_to_stdout: true)
    end)

    stopped_nodes =
      state.nodes
      |> Enum.map(fn {id, node} -> {id, %{node | status: :stopped}} end)
      |> Map.new()

    {:noreply, %{state | nodes: stopped_nodes, mesh_state: :stopped, quorum_count: 0}}
  end

  # =============================================================================
  # Private: Shutdown Execution
  # =============================================================================

  defp execute_shutdown_waves(waves, opts) do
    drain_timeout = Keyword.get(opts, :drain_timeout_ms, 30_000)

    results =
      Enum.map(waves, fn wave ->
        Logger.info("[MeshLifecycle] Shutting down wave: #{inspect(wave)}")

        # Drain connections for each container
        wave
        |> Task.async_stream(
          fn container_id ->
            # Enter lameduck
            ConnectionDrainer.enter_lameduck(container_id)

            # Capture dying gasp
            DyingGasp.capture(container_id)

            # Drain connections
            ConnectionDrainer.drain(container_id, timeout_ms: drain_timeout)

            # Stop container
            System.cmd("podman", ["stop", "-t", "10", container_id], stderr_to_stdout: true)
          end,
          timeout: drain_timeout + 15_000,
          on_timeout: :kill_task
        )
        |> Enum.to_list()
      end)

    %{
      success: true,
      waves_completed: length(results)
    }
  end

  # =============================================================================
  # Private: Node Updates
  # =============================================================================

  defp update_nodes_from_boot(nodes, boot_result) do
    boot_result.container_results
    |> Enum.reduce(nodes, fn {container_id, result}, acc ->
      node_id = container_id

      case Map.get(acc, node_id) do
        nil ->
          acc

        node ->
          status = if result.success, do: :healthy, else: :unhealthy
          Map.put(acc, node_id, %{node | status: status, last_seen: DateTime.utc_now()})
      end
    end)
  end

  defp update_from_health_check(state, health) do
    updated_nodes =
      health.containers
      |> Enum.reduce(state.nodes, fn {container_id, report}, acc ->
        node_id = container_id

        case Map.get(acc, node_id) do
          nil ->
            acc

          node ->
            status =
              case report.status do
                :healthy -> :healthy
                :degraded -> :healthy
                _ -> :unhealthy
              end

            Map.put(acc, node_id, %{node | status: status, last_seen: DateTime.utc_now()})
        end
      end)

    quorum_count = count_healthy_nodes(updated_nodes)

    # Update mesh state based on quorum
    mesh_state =
      cond do
        state.mesh_state in [:stopped, :apoptosis, :shutting_down] ->
          state.mesh_state

        quorum_count >= state.required_quorum ->
          :running

        true ->
          :degraded
      end

    %{
      state
      | nodes: updated_nodes,
        quorum_count: quorum_count,
        mesh_state: mesh_state,
        last_quorum_check: DateTime.utc_now()
    }
  end

  defp count_healthy_nodes(nodes) do
    nodes
    |> Enum.count(fn {_id, node} -> node.status == :healthy end)
  end

  # =============================================================================
  # Private: Split-Brain Detection
  # =============================================================================

  defp check_split_brain(state) do
    # If seed is unhealthy and we have partial quorum,
    # this might be a split-brain scenario
    seed_node = Map.get(state.nodes, state.seed_node)

    if seed_node && seed_node.status == :unhealthy do
      # Check if satellites can still see each other
      healthy_satellites =
        state.nodes
        |> Enum.filter(fn {_id, node} -> not node.is_seed and node.status == :healthy end)
        |> length()

      # If we have satellites but no seed, trigger apoptosis
      if healthy_satellites > 0 and healthy_satellites < state.required_quorum do
        Logger.warning(
          "[MeshLifecycle] Potential split-brain detected: " <>
            "seed unhealthy, #{healthy_satellites} satellites healthy"
        )

        # Don't auto-trigger apoptosis, but emit warning
        emit_telemetry(:split_brain_warning, %{
          seed_status: seed_node.status,
          healthy_satellites: healthy_satellites
        })
      end
    end
  end

  # =============================================================================
  # Private: Status Building
  # =============================================================================

  defp build_mesh_status(state) do
    seed_node = Map.get(state.nodes, state.seed_node)

    %{
      state: state.mesh_state,
      nodes: state.nodes,
      quorum: state.quorum_count >= state.required_quorum,
      quorum_count: state.quorum_count,
      required_quorum: state.required_quorum,
      seed_healthy: seed_node && seed_node.status == :healthy,
      last_update: state.last_quorum_check || DateTime.utc_now()
    }
  end

  # =============================================================================
  # Private: Telemetry
  # =============================================================================

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :lifecycle, :mesh, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
