defmodule Indrajaal.Jain.Node do
  @moduledoc """
  Jain Node - Autonomous Self-Replicating Node for v20.0.0

  Implements Jain philosophy of non-violence in autonomous systems:
  - Self-replication with constitutional constraints
  - Non-aggressive resource acquisition
  - Automatic sterilization on corruption
  - Symbiotic relationship with host systems

  ## Jain Model

  The Jain Node follows three core principles:
  1. Ahimsa (Non-violence): MUST NOT harm host systems
  2. Aparigraha (Non-possession): MUST NOT hoard resources
  3. Satya (Truth): MUST NOT deceive about its nature

  ## Lifecycle
  1. Genesis: Bootstrap from minimal seed
  2. Growth: Acquire resources within limits
  3. Replication: Spread with constitutional verification
  4. Transcendence: Become part of federation

  ## STAMP Constraints
  - SC-JAI-001: Node MUST verify constitution before any action
  - SC-JAI-002: Resource usage MUST NOT exceed host capacity
  - SC-JAI-003: Replication MUST include full constitution
  - SC-JAI-004: Corruption MUST trigger sterilization
  """

  use GenServer
  require Logger

  alias Indrajaal.Jain.{Constitution, Sterilization}

  @type node_id :: String.t()
  @type node_state :: :seed | :growing | :mature | :replicating | :transcending | :sterile

  @type jain_node :: %{
          id: node_id(),
          state: node_state(),
          constitution_hash: binary(),
          generation: non_neg_integer(),
          parent_id: node_id() | nil,
          children: [node_id()],
          resources: map(),
          metadata: map()
        }

  @type config :: %{
          max_resource_ratio: float(),
          replication_threshold: float(),
          sterilization_enabled: boolean()
        }

  # Maximum resource ratio relative to host (SC-JAI-002)
  @max_resource_ratio 0.1

  # Replication threshold (resource fullness)
  @replication_threshold 0.8

  # Health check interval
  @health_interval 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current node state.
  """
  @spec state() :: jain_node()
  def state do
    GenServer.call(__MODULE__, :state)
  end

  @doc """
  Gets the node's constitution hash.
  """
  @spec constitution_hash() :: binary()
  def constitution_hash do
    GenServer.call(__MODULE__, :constitution_hash)
  end

  @doc """
  Verifies the node's constitution.
  """
  @spec verify_constitution() :: :ok | {:error, :corrupted}
  def verify_constitution do
    GenServer.call(__MODULE__, :verify_constitution)
  end

  @doc """
  Attempts to acquire resources.
  """
  @spec acquire_resource(atom(), term()) :: :ok | {:error, term()}
  def acquire_resource(type, amount) do
    GenServer.call(__MODULE__, {:acquire_resource, type, amount})
  end

  @doc """
  Releases resources back to host.
  """
  @spec release_resource(atom(), term()) :: :ok
  def release_resource(type, amount) do
    GenServer.cast(__MODULE__, {:release_resource, type, amount})
  end

  @doc """
  Initiates replication process.
  """
  @spec replicate() :: {:ok, node_id()} | {:error, term()}
  def replicate do
    GenServer.call(__MODULE__, :replicate)
  end

  @doc """
  Gets node statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    # Verify constitution first (SC-JAI-001)
    constitution = Constitution.load()

    case Constitution.verify(constitution) do
      :ok ->
        node = %{
          id: generate_node_id(),
          state: :seed,
          constitution_hash: Constitution.hash(constitution),
          generation: Keyword.get(opts, :generation, 0),
          parent_id: Keyword.get(opts, :parent_id),
          children: [],
          resources: %{
            cpu: 0.0,
            memory: 0,
            storage: 0,
            network: 0
          },
          created_at: DateTime.utc_now(),
          last_verified: DateTime.utc_now()
        }

        config = %{
          max_resource_ratio: Keyword.get(opts, :max_resource_ratio, @max_resource_ratio),
          replication_threshold:
            Keyword.get(opts, :replication_threshold, @replication_threshold),
          sterilization_enabled: Keyword.get(opts, :sterilization_enabled, true)
        }

        # Schedule health checks
        Process.send_after(self(), :health_check, @health_interval)

        Logger.info("🌱 Jain Node #{node.id} initialized (gen #{node.generation})")

        {:ok, %{node: node, constitution: constitution, config: config}}

      {:error, :corrupted} ->
        Logger.error("Constitution corrupted - cannot start Jain Node")
        {:stop, :constitution_corrupted}
    end
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state.node, state}
  end

  @impl true
  def handle_call(:constitution_hash, _from, state) do
    {:reply, state.node.constitution_hash, state}
  end

  @impl true
  def handle_call(:verify_constitution, _from, state) do
    case Constitution.verify(state.constitution) do
      :ok ->
        new_node = %{state.node | last_verified: DateTime.utc_now()}
        {:reply, :ok, %{state | node: new_node}}

      {:error, :corrupted} ->
        # Trigger sterilization (SC-JAI-004)
        if state.config.sterilization_enabled do
          send(self(), :sterilize)
        end

        {:reply, {:error, :corrupted}, state}
    end
  end

  @impl true
  def handle_call({:acquire_resource, type, amount}, _from, state) do
    # Check host capacity (SC-JAI-002)
    host_capacity = get_host_capacity(type)
    max_allowed = host_capacity * state.config.max_resource_ratio
    current = Map.get(state.node.resources, type, 0)

    if current + amount <= max_allowed do
      new_resources = Map.update(state.node.resources, type, amount, &(&1 + amount))
      new_node = %{state.node | resources: new_resources}

      # Check if ready to grow
      new_node = maybe_transition_state(new_node, state.config)

      {:reply, :ok, %{state | node: new_node}}
    else
      {:reply, {:error, :would_exceed_limit}, state}
    end
  end

  @impl true
  def handle_call(:replicate, _from, state) do
    if state.node.state == :replicating do
      case do_replicate(state) do
        {:ok, child_id, new_node} ->
          {:reply, {:ok, child_id}, %{state | node: new_node}}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :not_ready}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      id: state.node.id,
      state: state.node.state,
      generation: state.node.generation,
      children_count: length(state.node.children),
      resources: state.node.resources,
      constitution_verified: state.node.last_verified,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.node.created_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:release_resource, type, amount}, state) do
    new_resources = Map.update(state.node.resources, type, 0, &max(0, &1 - amount))
    new_node = %{state.node | resources: new_resources}
    {:noreply, %{state | node: new_node}}
  end

  @impl true
  def handle_info(:health_check, state) do
    # Verify constitution periodically
    case Constitution.verify(state.constitution) do
      :ok ->
        new_node = %{state.node | last_verified: DateTime.utc_now()}
        Process.send_after(self(), :health_check, @health_interval)
        {:noreply, %{state | node: new_node}}

      {:error, :corrupted} ->
        if state.config.sterilization_enabled do
          send(self(), :sterilize)
        end

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:sterilize, state) do
    Logger.warning("🔒 Jain Node #{state.node.id} entering sterilization")

    # Release all resources
    Enum.each(state.node.resources, fn {type, amount} ->
      release_resource(type, amount)
    end)

    # Mark as sterile
    new_node = %{state.node | state: :sterile, resources: %{}}

    # Trigger sterilization protocol
    Sterilization.execute(new_node)

    {:noreply, %{state | node: new_node}}
  end

  # Private helpers

  defp generate_node_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    "jain_#{Base.encode16(rand_bytes, case: :lower)}"
  end

  defp get_host_capacity(type) do
    # In production, would query actual host metrics
    case type do
      :cpu -> 1.0
      :memory -> 8 * 1024 * 1024 * 1024
      :storage -> 100 * 1024 * 1024 * 1024
      :network -> 1000
    end
  end

  defp maybe_transition_state(node, config) do
    resource_fullness = calculate_resource_fullness(node.resources)

    cond do
      node.state == :sterile ->
        node

      node.state == :seed and resource_fullness > 0.1 ->
        %{node | state: :growing}

      node.state == :growing and resource_fullness > 0.5 ->
        %{node | state: :mature}

      node.state == :mature and resource_fullness >= config.replication_threshold ->
        %{node | state: :replicating}

      true ->
        node
    end
  end

  defp calculate_resource_fullness(resources) do
    # Calculate average fullness across resource types
    values =
      Enum.map(resources, fn {type, amount} ->
        capacity = get_host_capacity(type)
        amount / capacity
      end)

    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end

  defp do_replicate(state) do
    # Verify constitution before replication (SC-JAI-003)
    case Constitution.verify(state.constitution) do
      :ok ->
        child_id = generate_node_id()

        # Create child with constitutional DNA (spec reserved for process spawning)
        _child_spec = %{
          id: child_id,
          generation: state.node.generation + 1,
          parent_id: state.node.id,
          constitution: state.constitution,
          constitution_hash: state.node.constitution_hash
        }

        # Register child (in production, would spawn process/container)
        new_children = [child_id | state.node.children]
        new_node = %{state.node | children: new_children, state: :mature}

        Logger.info("🌿 Jain Node #{state.node.id} replicated → #{child_id}")

        {:ok, child_id, new_node}

      {:error, :corrupted} ->
        {:error, :constitution_corrupted}
    end
  end
end
