defmodule Indrajaal.Compute.Allocation do
  @moduledoc """
  Resource Allocation - Compute Resource Distribution for v20.0.0

  Implements resource allocation strategies:
  - Priority-based allocation
  - Fair-share allocation
  - Deadline-aware allocation
  - Preemption support

  ## Allocation Model

  Allocation = {resource, quantity, holder, priority, deadline}

  Constraint: Σ allocated ≤ capacity

  ## Allocation Strategies
  - **FIFO**: First-come, first-served
  - **Priority**: Highest priority first
  - **Fair-share**: Equal distribution
  - **Deadline**: Earliest deadline first

  ## STAMP Constraints
  - SC-ALL-001: Total allocation MUST NOT exceed capacity
  - SC-ALL-002: Allocation MUST respect priority
  - SC-ALL-003: Preemption MUST be logged
  - SC-ALL-004: Deadlines MUST be honored
  """

  use GenServer
  require Logger

  @type resource_type :: :cpu | :memory | :network | :storage
  @type agent_id :: String.t()
  @type priority :: 0..100

  @type allocation :: %{
          id: String.t(),
          resource: resource_type(),
          quantity: non_neg_integer(),
          holder: agent_id(),
          priority: priority(),
          deadline: DateTime.t() | nil,
          created_at: DateTime.t(),
          expires_at: DateTime.t() | nil
        }

  @type request :: %{
          requester: agent_id(),
          resource: resource_type(),
          quantity: non_neg_integer(),
          priority: priority(),
          deadline: DateTime.t() | nil
        }

  @type state :: %{
          allocations: map(),
          capacity: map(),
          queue: [request()],
          config: map()
        }

  # Default capacities
  @default_capacity %{
    cpu: 1000,
    memory: 10_000,
    network: 5000,
    storage: 100_000
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Requests resource allocation.
  """
  @spec request(request()) :: {:ok, allocation()} | {:queued, pos_integer()} | {:error, term()}
  def request(req) do
    GenServer.call(__MODULE__, {:request, req})
  end

  @doc """
  Releases an allocation.
  """
  @spec release(String.t()) :: :ok | {:error, :not_found}
  def release(allocation_id) do
    GenServer.call(__MODULE__, {:release, allocation_id})
  end

  @doc """
  Gets current allocations for an agent.
  """
  @spec get_allocations(agent_id()) :: [allocation()]
  def get_allocations(agent_id) do
    GenServer.call(__MODULE__, {:get_allocations, agent_id})
  end

  @doc """
  Gets available capacity for a resource.
  """
  @spec available(resource_type()) :: non_neg_integer()
  def available(resource) do
    GenServer.call(__MODULE__, {:available, resource})
  end

  @doc """
  Gets total capacity for a resource.
  """
  @spec capacity(resource_type()) :: non_neg_integer()
  def capacity(resource) do
    GenServer.call(__MODULE__, {:capacity, resource})
  end

  @doc """
  Sets capacity for a resource.
  """
  @spec set_capacity(resource_type(), non_neg_integer()) :: :ok
  def set_capacity(resource, capacity) do
    GenServer.call(__MODULE__, {:set_capacity, resource, capacity})
  end

  @doc """
  Preempts lower-priority allocations to serve higher priority.
  """
  @spec preempt(request()) :: {:ok, [allocation()]} | {:error, term()}
  def preempt(req) do
    GenServer.call(__MODULE__, {:preempt, req})
  end

  @doc """
  Gets allocation summary.
  """
  @spec summary() :: map()
  def summary do
    GenServer.call(__MODULE__, :summary)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      allocations: %{},
      capacity: Keyword.get(opts, :capacity, @default_capacity),
      queue: [],
      config: %{
        strategy: Keyword.get(opts, :strategy, :priority),
        max_queue_size: Keyword.get(opts, :max_queue_size, 1000)
      }
    }

    # Schedule periodic queue processing
    Process.send_after(self(), :process_queue, 100)

    {:ok, state}
  end

  @impl true
  def handle_call({:request, req}, _from, state) do
    available = calculate_available(state, req.resource)

    if available >= req.quantity do
      # Allocate immediately
      allocation = create_allocation(req)
      new_allocations = Map.put(state.allocations, allocation.id, allocation)

      Logger.debug("Allocated #{req.quantity} #{req.resource} to #{req.requester}")

      {:reply, {:ok, allocation}, %{state | allocations: new_allocations}}
    else
      # Queue the request
      if length(state.queue) >= state.config.max_queue_size do
        {:reply, {:error, :queue_full}, state}
      else
        new_queue = insert_by_priority(state.queue, req, state.config.strategy)
        position = Enum.find_index(new_queue, &(&1 == req)) + 1

        {:reply, {:queued, position}, %{state | queue: new_queue}}
      end
    end
  end

  @impl true
  def handle_call({:release, allocation_id}, _from, state) do
    case Map.pop(state.allocations, allocation_id) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {allocation, new_allocations} ->
        Logger.debug(
          "Released #{allocation.quantity} #{allocation.resource} from #{allocation.holder}"
        )

        # Trigger queue processing
        send(self(), :process_queue)

        {:reply, :ok, %{state | allocations: new_allocations}}
    end
  end

  @impl true
  def handle_call({:get_allocations, agent_id}, _from, state) do
    allocations =
      state.allocations
      |> Map.values()
      |> Enum.filter(&(&1.holder == agent_id))

    {:reply, allocations, state}
  end

  @impl true
  def handle_call({:available, resource}, _from, state) do
    available = calculate_available(state, resource)
    {:reply, available, state}
  end

  @impl true
  def handle_call({:capacity, resource}, _from, state) do
    cap = Map.get(state.capacity, resource, 0)
    {:reply, cap, state}
  end

  @impl true
  def handle_call({:set_capacity, resource, capacity}, _from, state) do
    new_capacity = Map.put(state.capacity, resource, capacity)
    {:reply, :ok, %{state | capacity: new_capacity}}
  end

  @impl true
  def handle_call({:preempt, req}, _from, state) do
    # Find lower-priority allocations to preempt
    preemptable =
      state.allocations
      |> Map.values()
      |> Enum.filter(fn a ->
        a.resource == req.resource and a.priority < req.priority
      end)
      |> Enum.sort_by(& &1.priority)

    # Calculate how much we need
    available = calculate_available(state, req.resource)
    needed = req.quantity - available

    if needed <= 0 do
      {:reply, {:ok, []}, state}
    else
      # Preempt until we have enough
      {preempted, remaining_needed, new_allocations} =
        Enum.reduce_while(preemptable, {[], needed, state.allocations}, fn allocation,
                                                                           {preempted_acc, need,
                                                                            allocs} ->
          if need <= 0 do
            {:halt, {preempted_acc, need, allocs}}
          else
            # Preempt this allocation (SC-ALL-003)
            Logger.warning(
              "Preempting allocation #{allocation.id} from #{allocation.holder} for #{req.requester}"
            )

            new_allocs = Map.delete(allocs, allocation.id)
            new_need = need - allocation.quantity

            emit_preemption(allocation, req)

            {:cont, {[allocation | preempted_acc], new_need, new_allocs}}
          end
        end)

      if remaining_needed > 0 do
        {:reply, {:error, :insufficient_preemptable}, state}
      else
        {:reply, {:ok, preempted}, %{state | allocations: new_allocations}}
      end
    end
  end

  @impl true
  def handle_call(:summary, _from, state) do
    by_resource =
      Enum.into(state.capacity, %{}, fn {resource, capacity} ->
        allocated = calculate_allocated(state, resource)

        {resource,
         %{
           capacity: capacity,
           allocated: allocated,
           available: capacity - allocated,
           utilization: if(capacity > 0, do: Float.round(allocated / capacity, 2), else: 0.0)
         }}
      end)

    summary = %{
      by_resource: by_resource,
      total_allocations: map_size(state.allocations),
      queue_size: length(state.queue)
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_info(:process_queue, state) do
    # Process queued requests
    {new_allocations, new_queue} =
      Enum.reduce(state.queue, {state.allocations, []}, fn req, {allocs, remaining_queue} ->
        available = calculate_available(%{state | allocations: allocs}, req.resource)

        if available >= req.quantity do
          allocation = create_allocation(req)

          Logger.debug("Allocated #{req.quantity} #{req.resource} to #{req.requester} from queue")

          {Map.put(allocs, allocation.id, allocation), remaining_queue}
        else
          {allocs, [req | remaining_queue]}
        end
      end)

    # Schedule next processing
    Process.send_after(self(), :process_queue, 100)

    {:noreply, %{state | allocations: new_allocations, queue: Enum.reverse(new_queue)}}
  end

  # Private helpers

  defp calculate_available(state, resource) do
    capacity = Map.get(state.capacity, resource, 0)
    allocated = calculate_allocated(state, resource)
    max(0, capacity - allocated)
  end

  defp calculate_allocated(state, resource) do
    state.allocations
    |> Map.values()
    |> Enum.filter(&(&1.resource == resource))
    |> Enum.reduce(0, fn a, acc -> acc + a.quantity end)
  end

  defp create_allocation(req) do
    %{
      id: generate_id(),
      resource: req.resource,
      quantity: req.quantity,
      holder: req.requester,
      priority: req.priority,
      deadline: req.deadline,
      created_at: DateTime.utc_now(),
      expires_at: nil
    }
  end

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    encoded = bytes |> Base.encode16(case: :lower)
    "alloc_#{encoded}"
  end

  defp insert_by_priority(queue, req, strategy) do
    case strategy do
      :fifo ->
        queue ++ [req]

      :priority ->
        Enum.sort_by([req | queue], & &1.priority, :desc)

      :deadline ->
        Enum.sort_by([req | queue], fn r ->
          if r.deadline, do: DateTime.to_unix(r.deadline), else: :infinity
        end)

      _ ->
        queue ++ [req]
    end
  end

  defp emit_preemption(allocation, req) do
    :telemetry.execute(
      [:indrajaal, :compute, :allocation, :preemption],
      %{quantity: allocation.quantity},
      %{
        preempted: allocation.holder,
        preemptor: req.requester,
        resource: allocation.resource
      }
    )
  end
end
