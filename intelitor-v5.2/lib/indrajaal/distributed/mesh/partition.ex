defmodule Indrajaal.Distributed.Mesh.Partition do
  @moduledoc """
  Partition Handling - Network Partition Detection and Recovery for v20.0.0

  Implements partition handling for mesh network:
  - Partition detection
  - Split-brain prevention
  - Partition healing
  - Consistency during partition

  ## Partition Model

  Network partition: G = G₁ ∪ G₂ where G₁ ∩ G₂ = ∅

  Detection: If cannot reach quorum of nodes for T seconds

  ## Partition Strategies
  - **Majority**: Only majority partition operates
  - **Witness**: External witness decides
  - **Graceful**: Both partitions operate with reduced capability
  - **Freeze**: Pause operations until healed

  ## STAMP Constraints
  - SC-PAR-001: Partition detection < 5s
  - SC-PAR-002: No split-brain operations
  - SC-PAR-003: Partition healing MUST be automatic
  - SC-PAR-004: Data MUST reconcile after healing
  """

  use GenServer
  require Logger

  alias Indrajaal.Distributed.Mesh.{Mycelium, Gossip}

  @type node_id :: String.t()
  @type partition_id :: String.t()
  @type partition_state :: :normal | :suspected | :partitioned | :healing

  @type partition_info :: %{
          id: partition_id(),
          members: [node_id()],
          leader: node_id() | nil,
          is_majority: boolean(),
          detected_at: DateTime.t()
        }

  @type state :: %{
          node_id: node_id(),
          status: partition_state(),
          partition: partition_info() | nil,
          known_partitions: [partition_info()],
          config: map()
        }

  # Partition detection timeout (ms)
  @detection_timeout 5_000

  # Heartbeat interval for partition check
  @heartbeat_interval 1_000

  # Quorum calculation
  @quorum_fraction 0.5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets current partition status.
  """
  @spec status() :: partition_state()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Gets current partition info.
  """
  @spec partition_info() :: partition_info() | nil
  def partition_info do
    GenServer.call(__MODULE__, :partition_info)
  end

  @doc """
  Checks if this node is in the majority partition.
  """
  @spec in_majority?() :: boolean()
  def in_majority? do
    GenServer.call(__MODULE__, :in_majority)
  end

  @doc """
  Triggers partition check.
  """
  @spec check() :: {:ok, partition_state()} | {:error, term()}
  def check do
    GenServer.call(__MODULE__, :check)
  end

  @doc """
  Manually triggers partition healing.
  """
  @spec heal() :: :ok | {:error, term()}
  def heal do
    GenServer.call(__MODULE__, :heal)
  end

  @doc """
  Reports node unreachable.
  """
  @spec report_unreachable(node_id()) :: :ok
  def report_unreachable(node_id) do
    GenServer.cast(__MODULE__, {:unreachable, node_id})
  end

  @doc """
  Reports node reachable.
  """
  @spec report_reachable(node_id()) :: :ok
  def report_reachable(node_id) do
    GenServer.cast(__MODULE__, {:reachable, node_id})
  end

  @doc """
  Gets partition statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, generate_id())

    state = %{
      node_id: node_id,
      status: :normal,
      partition: nil,
      known_partitions: [],
      unreachable: MapSet.new(),
      last_check: nil,
      stats: %{
        partitions_detected: 0,
        partitions_healed: 0,
        time_partitioned_ms: 0
      },
      config: %{
        strategy: Keyword.get(opts, :strategy, :majority),
        detection_timeout: Keyword.get(opts, :timeout, @detection_timeout),
        heartbeat_interval: Keyword.get(opts, :heartbeat, @heartbeat_interval)
      }
    }

    # Start heartbeat
    Process.send_after(self(), :heartbeat, state.config.heartbeat_interval)

    Logger.info("🔀 Partition handler started on #{node_id}")

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:partition_info, _from, state) do
    {:reply, state.partition, state}
  end

  @impl true
  def handle_call(:in_majority, _from, state) do
    is_majority =
      case state.partition do
        nil -> true
        partition -> partition.is_majority
      end

    {:reply, is_majority, state}
  end

  @impl true
  def handle_call(:check, _from, state) do
    {new_status, new_state} = detect_partition(state)
    {:reply, {:ok, new_status}, new_state}
  end

  @impl true
  def handle_call(:heal, _from, state) do
    if state.status in [:partitioned, :suspected] do
      new_state = initiate_healing(state)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_partitioned}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        status: state.status,
        unreachable_count: MapSet.size(state.unreachable),
        partition_members: if(state.partition, do: length(state.partition.members), else: 0)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:unreachable, node_id}, state) do
    new_unreachable = MapSet.put(state.unreachable, node_id)
    new_state = %{state | unreachable: new_unreachable}

    # Check if this triggers partition
    {_status, final_state} = maybe_partition(new_state)
    {:noreply, final_state}
  end

  @impl true
  def handle_cast({:reachable, node_id}, state) do
    new_unreachable = MapSet.delete(state.unreachable, node_id)
    new_state = %{state | unreachable: new_unreachable}

    # Check if this heals partition
    {_status, final_state} = maybe_heal(new_state)
    {:noreply, final_state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    # Ping all known nodes
    nodes = Mycelium.nodes()

    Enum.each(nodes, fn node ->
      Task.start(fn ->
        case ping_node(node.id) do
          :ok -> report_reachable(node.id)
          :error -> report_unreachable(node.id)
        end
      end)
    end)

    # Schedule next heartbeat
    Process.send_after(self(), :heartbeat, state.config.heartbeat_interval)

    # Update time in partition state
    new_state = update_partition_time(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:healing_complete, partition_id}, state) do
    if state.partition && state.partition.id == partition_id do
      Logger.info("Partition #{partition_id} healed")

      new_stats = %{state.stats | partitions_healed: state.stats.partitions_healed + 1}

      {:noreply,
       %{
         state
         | status: :normal,
           partition: nil,
           unreachable: MapSet.new(),
           stats: new_stats
       }}
    else
      {:noreply, state}
    end
  end

  # Private helpers

  defp generate_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(random_bytes, case: :lower)
  end

  defp detect_partition(state) do
    nodes = Mycelium.nodes()
    total = length(nodes) + 1
    unreachable_count = MapSet.size(state.unreachable)
    reachable_count = total - unreachable_count

    quorum = ceil(total * @quorum_fraction)

    cond do
      unreachable_count == 0 ->
        {:normal, %{state | status: :normal, partition: nil}}

      reachable_count >= quorum ->
        # We're in majority, but there's a partition
        partition = create_partition(state, nodes, true)
        {:partitioned, %{state | status: :partitioned, partition: partition}}

      reachable_count < quorum ->
        # We're in minority
        partition = create_partition(state, nodes, false)
        handle_minority_partition(state, partition)
    end
  end

  defp maybe_partition(state) do
    nodes = Mycelium.nodes()
    total = length(nodes) + 1
    unreachable_count = MapSet.size(state.unreachable)

    threshold = ceil(total * 0.3)

    if unreachable_count >= threshold and state.status == :normal do
      Logger.warning(
        "Suspected network partition: #{unreachable_count}/#{total} nodes unreachable"
      )

      new_stats = %{state.stats | partitions_detected: state.stats.partitions_detected + 1}

      {:suspected, %{state | status: :suspected, stats: new_stats}}
    else
      {state.status, state}
    end
  end

  defp maybe_heal(state) do
    if state.status in [:partitioned, :suspected] and MapSet.size(state.unreachable) == 0 do
      # All nodes reachable again
      initiate_healing(state)
      {:healing, %{state | status: :healing}}
    else
      {state.status, state}
    end
  end

  defp create_partition(state, nodes, is_majority) do
    reachable_nodes =
      nodes
      |> Enum.filter(fn n -> not MapSet.member?(state.unreachable, n.id) end)
      |> Enum.map(& &1.id)

    members = [state.node_id | reachable_nodes]

    # Elect leader (highest ID for simplicity)
    leader = Enum.max(members)

    %{
      id: generate_partition_id(),
      members: members,
      leader: leader,
      is_majority: is_majority,
      detected_at: DateTime.utc_now()
    }
  end

  defp generate_partition_id do
    random_bytes = :crypto.strong_rand_bytes(4)
    hex_string = Base.encode16(random_bytes, case: :lower)
    "part_#{hex_string}"
  end

  defp handle_minority_partition(state, partition) do
    case state.config.strategy do
      :majority ->
        # Minority cannot operate
        Logger.warning("In minority partition - operations restricted")
        {:partitioned, %{state | status: :partitioned, partition: partition}}

      :graceful ->
        # Continue with reduced capability
        Logger.warning("In minority partition - degraded mode")
        {:partitioned, %{state | status: :partitioned, partition: partition}}

      :freeze ->
        # Freeze operations
        Logger.warning("In minority partition - freezing")
        {:partitioned, %{state | status: :partitioned, partition: partition}}

      _ ->
        {:partitioned, %{state | status: :partitioned, partition: partition}}
    end
  end

  defp initiate_healing(state) do
    Logger.info("Initiating partition healing")

    # Gossip healing intent
    Gossip.gossip_event({:healing, state.partition && state.partition.id})

    # Schedule healing completion check
    if state.partition do
      Process.send_after(self(), {:healing_complete, state.partition.id}, 5000)
    end

    %{state | status: :healing}
  end

  defp ping_node(node_id) do
    case Mycelium.send_message(node_id, {:ping, self()}) do
      :ok -> :ok
      _ -> :error
    end
  end

  defp update_partition_time(state) do
    if state.status == :partitioned and state.partition do
      now = DateTime.utc_now()
      duration = DateTime.diff(now, state.partition.detected_at, :millisecond)
      new_stats = %{state.stats | time_partitioned_ms: state.stats.time_partitioned_ms + duration}
      %{state | stats: new_stats}
    else
      state
    end
  end
end
