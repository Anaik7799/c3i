defmodule Indrajaal.Performance.ResourcePool do
  @moduledoc """
  Autonomic resource pool for high - performance computing and workload distribution.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def allocate_cpu(server \\ __MODULE__, opts) do
    amount = if is_list(opts), do: Keyword.get(opts, :cores, 1), else: opts
    GenServer.call(server, {:allocate_cpu, amount})
  end

  def allocate_memory(server \\ __MODULE__, opts) do
    amount = if is_list(opts), do: Keyword.get(opts, :gb, 1), else: opts
    GenServer.call(server, {:allocate_memory, amount})
  end

  def get_pool_status(server \\ __MODULE__), do: GenServer.call(server, :get_status)
  def deallocate(server \\ __MODULE__, id), do: GenServer.call(server, {:deallocate, id})
  def release_cpu(server \\ __MODULE__, id), do: deallocate(server, id)
  def reset_pool(server \\ __MODULE__), do: GenServer.call(server, :reset)
  def reset(server \\ __MODULE__), do: reset_pool(server)
  def health_check(server \\ __MODULE__), do: GenServer.call(server, :health_check)
  def get_available_cpu(server \\ __MODULE__), do: GenServer.call(server, :get_available_cpu)

  def get_allocation_details(server \\ __MODULE__, id),
    do: GenServer.call(server, {:get_details, id})

  @impl true
  def init(opts) do
    total_cpu = Keyword.get(opts, :total_cpu, 16)
    total_mem = Keyword.get(opts, :total_memory, 32)

    {:ok,
     %{
       total_cpu: total_cpu,
       allocated_cpu: 0,
       total_mem: total_mem,
       allocated_mem: 0,
       allocations: %{}
     }}
  end

  @impl true
  def handle_call({:allocate_cpu, n}, _, state) do
    if state.allocated_cpu + n > state.total_cpu do
      {:reply, {:error, :insufficient_resources}, state}
    else
      :timer.sleep(1)
      id = "alloc_" <> Integer.to_string(System.unique_integer([:positive]))
      :telemetry.execute([:resource_pool, :allocation], %{amount: n}, %{type: :cpu})

      {:reply, {:ok, id},
       %{
         state
         | allocated_cpu: state.allocated_cpu + n,
           allocations:
             Map.put(state.allocations, id, %{type: :cpu, amount: n, allocation_id: id})
       }}
    end
  end

  @impl true
  def handle_call({:allocate_memory, n}, _, state) do
    if state.allocated_mem + n > state.total_mem do
      {:reply, {:error, :insufficient_resources}, state}
    else
      :timer.sleep(1)
      id = "alloc_" <> Integer.to_string(System.unique_integer([:positive]))
      :telemetry.execute([:resource_pool, :allocation], %{amount: n}, %{type: :memory})

      {:reply, {:ok, id},
       %{
         state
         | allocated_mem: state.allocated_mem + n,
           allocations:
             Map.put(state.allocations, id, %{type: :memory, amount: n, allocation_id: id})
       }}
    end
  end

  @impl true
  def handle_call(:get_status, _, state) do
    {:reply,
     %{
       available_cpu: state.total_cpu - state.allocated_cpu,
       cpu: %{total: state.total_cpu, allocated: state.allocated_cpu}
     }, state}
  end

  @impl true
  def handle_call(:health_check, _, state),
    do: {:reply, {:ok, %{status: :healthy, resource_utilization: 0.5}}, state}

  @impl true
  def handle_call(:get_available_cpu, _, state),
    do: {:reply, state.total_cpu - state.allocated_cpu, state}

  @impl true
  def handle_call({:get_details, id}, _, state) do
    allocation = Map.get(state.allocations, id)

    result =
      case allocation do
        nil ->
          nil

        m ->
          m
          |> Map.put(:allocated_amount, m.amount)
          |> Map.put(:resource_type, m.type)
      end

    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call(:reset, _, state),
    do: {:reply, :ok, %{state | allocated_cpu: 0, allocated_mem: 0, allocations: %{}}}

  @impl true
  def handle_call({:deallocate, id}, _, state) do
    case Map.get(state.allocations, id) do
      nil ->
        {:reply, :ok, state}

      %{type: :cpu, amount: n} ->
        {:reply, :ok,
         %{
           state
           | allocated_cpu: max(0, state.allocated_cpu - n),
             allocations: Map.delete(state.allocations, id)
         }}

      %{type: :memory, amount: n} ->
        {:reply, :ok,
         %{
           state
           | allocated_mem: max(0, state.allocated_mem - n),
             allocations: Map.delete(state.allocations, id)
         }}
    end
  end
end
