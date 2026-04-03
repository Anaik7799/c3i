defmodule Indrajaal.Substrate.L3.ResourceAllocator do
  @moduledoc """
  ## Design Intent
  L3 substrate resource allocator — manages a pool of resource units and
  distributes them across registered subsystems using a weighted fair-share
  algorithm with priority weighting.

  Allocation model:
    - Total pool size configurable (default 1000 units)
    - Subsystems register with a weight ∈ (0.0, 1.0] and a priority 1–10
    - Effective weight = base_weight × priority_multiplier(priority)
    - Each allocation cycle computes shares proportional to effective weights
    - Subsystems may request more or less than their share; unallocated units
      are distributed as surplus to subsystems below their requested cap
    - Allocation state published to PubSub "substrate:resource_allocation"

  Priority multipliers:
    1 (lowest) → 0.5×, 5 (medium) → 1.0×, 10 (highest) → 2.0×
    Linear interpolation between those anchor points.

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L3 — ENFORCED
  - SC-RCPSP-001: Resource-constrained scheduling — ENFORCED
  - SC-HOM-001: Homeostatic controller — resource pool balancing — REFERENCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "substrate:resource_allocation"
  @allocation_cycle_ms 2_000

  @default_pool_size 1_000.0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Register a subsystem.
  `weight` ∈ (0.0, 1.0], `priority` ∈ 1..10.
  """
  @spec register(String.t(), float(), 1..10) :: :ok | {:error, :already_registered}
  def register(subsystem_id, weight, priority)
      when is_binary(subsystem_id) and is_float(weight) and weight > 0.0 and weight <= 1.0 and
             is_integer(priority) and priority >= 1 and priority <= 10 do
    GenServer.call(@name, {:register, subsystem_id, weight, priority})
  end

  @doc "Deregister a subsystem."
  @spec deregister(String.t()) :: :ok
  def deregister(subsystem_id) when is_binary(subsystem_id) do
    GenServer.call(@name, {:deregister, subsystem_id})
  end

  @doc "Set the requested allocation (units) for a subsystem."
  @spec request(String.t(), float()) :: :ok | {:error, :not_registered}
  def request(subsystem_id, units)
      when is_binary(subsystem_id) and is_float(units) and units >= 0.0 do
    GenServer.call(@name, {:request, subsystem_id, units})
  end

  @doc "Returns current allocation for a subsystem."
  @spec allocation(String.t()) :: {:ok, float()} | {:error, :not_registered}
  def allocation(subsystem_id) when is_binary(subsystem_id) do
    GenServer.call(@name, {:allocation, subsystem_id})
  end

  @doc "Returns full allocation state."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  @doc "Resize the total resource pool."
  @spec set_pool_size(float()) :: :ok
  def set_pool_size(size) when is_float(size) and size > 0.0 do
    GenServer.call(@name, {:set_pool_size, size})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    state = %{
      pool_size: Keyword.get(opts, :pool_size, @default_pool_size),
      subsystems: %{},
      allocations: %{},
      cycle_count: 0,
      started_at: DateTime.utc_now()
    }

    schedule_cycle()
    Logger.info("[RESOURCE_ALLOCATOR] started — pool_size=#{state.pool_size}")
    {:ok, state}
  end

  @impl true
  def handle_call({:register, id, weight, priority}, _from, state) do
    if Map.has_key?(state.subsystems, id) do
      {:reply, {:error, :already_registered}, state}
    else
      subsystem = %{weight: weight, priority: priority, requested: nil}
      new_state = %{state | subsystems: Map.put(state.subsystems, id, subsystem)}
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:deregister, id}, _from, state) do
    new_state = %{
      state
      | subsystems: Map.delete(state.subsystems, id),
        allocations: Map.delete(state.allocations, id)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:request, id, units}, _from, state) do
    if Map.has_key?(state.subsystems, id) do
      updated = put_in(state.subsystems[id][:requested], units)
      {:reply, :ok, %{state | subsystems: updated}}
    else
      {:reply, {:error, :not_registered}, state}
    end
  end

  @impl true
  def handle_call({:allocation, id}, _from, state) do
    case Map.fetch(state.allocations, id) do
      {:ok, v} -> {:reply, {:ok, v}, state}
      :error -> {:reply, {:error, :not_registered}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply,
     %{
       pool_size: state.pool_size,
       subsystem_count: map_size(state.subsystems),
       allocations: state.allocations,
       cycle_count: state.cycle_count
     }, state}
  end

  @impl true
  def handle_call({:set_pool_size, size}, _from, state) do
    {:reply, :ok, %{state | pool_size: size}}
  end

  @impl true
  def handle_info(:allocate, state) do
    new_allocations = compute_allocations(state.subsystems, state.pool_size)

    new_state = %{
      state
      | allocations: new_allocations,
        cycle_count: state.cycle_count + 1
    }

    broadcast(new_state)
    schedule_cycle()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Fair-share allocation algorithm
  # ---------------------------------------------------------------------------

  @spec compute_allocations(map(), float()) :: map()
  defp compute_allocations(subsystems, pool_size) when map_size(subsystems) == 0 do
    _ = pool_size
    %{}
  end

  defp compute_allocations(subsystems, pool_size) do
    # Compute effective weights
    effective_weights =
      Map.new(subsystems, fn {id, sub} ->
        {id, sub.weight * priority_multiplier(sub.priority)}
      end)

    total_weight = Enum.sum(Map.values(effective_weights))

    # Fair-share base allocation
    base_allocs =
      Map.new(effective_weights, fn {id, ew} ->
        share = pool_size * ew / total_weight
        requested = get_in(subsystems, [id, :requested])
        # Respect requested cap if set
        allocated = if requested != nil, do: min(share, requested), else: share
        {id, allocated}
      end)

    # Surplus redistribution (units returned from capped subsystems)
    total_base = Enum.sum(Map.values(base_allocs))
    surplus = pool_size - total_base

    if surplus > 0.01 do
      # Find subsystems that didn't reach their requested cap or have no cap
      uncapped =
        Enum.filter(base_allocs, fn {id, alloc} ->
          req = get_in(subsystems, [id, :requested])
          req == nil or alloc < req
        end)

      if length(uncapped) > 0 do
        uncapped_weight_total =
          Enum.reduce(uncapped, 0.0, fn {id, _}, acc ->
            acc + Map.get(effective_weights, id, 0.0)
          end)

        Enum.reduce(uncapped, base_allocs, fn {id, alloc}, acc ->
          ew = Map.get(effective_weights, id, 0.0)
          bonus = surplus * ew / uncapped_weight_total
          req = get_in(subsystems, [id, :requested])
          new_alloc = if req != nil, do: min(alloc + bonus, req), else: alloc + bonus
          Map.put(acc, id, new_alloc)
        end)
      else
        base_allocs
      end
    else
      base_allocs
    end
  end

  @spec priority_multiplier(1..10) :: float()
  defp priority_multiplier(priority) do
    # Linear interpolation: 1 → 0.5, 5 → 1.0, 10 → 2.0
    cond do
      priority <= 1 -> 0.5
      priority <= 5 -> 0.5 + (priority - 1) / 4.0 * 0.5
      true -> 1.0 + (priority - 5) / 5.0 * 1.0
    end
  end

  defp schedule_cycle do
    Process.send_after(self(), :allocate, @allocation_cycle_ms)
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:resource_allocation,
       %{
         allocations: state.allocations,
         pool_size: state.pool_size,
         cycle_count: state.cycle_count,
         timestamp: DateTime.utc_now()
       }}
    )
  end
end
