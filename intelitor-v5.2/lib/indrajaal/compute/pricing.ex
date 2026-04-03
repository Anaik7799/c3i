defmodule Indrajaal.Compute.Pricing do
  @moduledoc """
  Dynamic Pricing - Market-Based Resource Pricing for v20.0.0

  Implements dynamic pricing for compute resources:
  - Supply and demand based pricing
  - Time-of-day adjustments
  - Priority pricing
  - Congestion pricing

  ## Pricing Model

  Price = BasePrice × DemandMultiplier × TimeMultiplier × PriorityMultiplier

  Where:
  - BasePrice: Cost to provide the resource
  - DemandMultiplier: f(current_demand / capacity)
  - TimeMultiplier: Time-of-day adjustment
  - PriorityMultiplier: Urgency premium

  ## Pricing Strategies
  - **Cost-plus**: Base cost + margin
  - **Market**: Supply/demand equilibrium
  - **Congestion**: Higher prices during peak
  - **Priority**: Premium for urgent requests

  ## STAMP Constraints
  - SC-PRC-001: Prices MUST be non-negative
  - SC-PRC-002: Price changes MUST be gradual (max 10%/minute)
  - SC-PRC-003: Base price MUST cover operational cost
  - SC-PRC-004: Price history MUST be retained
  """

  use GenServer
  require Logger

  @type resource_type :: :cpu | :memory | :network | :storage
  @type price :: float()
  @type priority :: :low | :normal | :high | :critical

  @type price_point :: %{
          resource: resource_type(),
          price: price(),
          timestamp: DateTime.t(),
          factors: map()
        }

  @type pricing_state :: %{
          base_prices: map(),
          current_prices: map(),
          demand: map(),
          capacity: map(),
          history: [price_point()],
          config: map()
        }

  # Base prices per resource unit
  @base_prices %{
    cpu: 1.0,
    memory: 0.5,
    network: 0.2,
    storage: 0.1
  }

  # Priority multipliers
  @priority_multipliers %{
    low: 0.5,
    normal: 1.0,
    high: 2.0,
    critical: 5.0
  }

  # Maximum price change per update (10%)
  @max_price_change 0.10

  # History retention
  @max_history 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current price for a resource.
  """
  @spec get_price(resource_type(), Keyword.t()) :: price()
  def get_price(resource, opts \\ []) do
    GenServer.call(__MODULE__, {:get_price, resource, opts})
  end

  @doc """
  Gets prices for multiple resources.
  """
  @spec get_prices([resource_type()]) :: map()
  def get_prices(resources) do
    GenServer.call(__MODULE__, {:get_prices, resources})
  end

  @doc """
  Calculates total cost for a resource bundle.
  """
  @spec calculate_cost(map(), Keyword.t()) :: price()
  def calculate_cost(bundle, opts \\ []) do
    GenServer.call(__MODULE__, {:calculate_cost, bundle, opts})
  end

  @doc """
  Updates demand for a resource.
  """
  @spec update_demand(resource_type(), non_neg_integer()) :: :ok
  def update_demand(resource, demand) do
    GenServer.cast(__MODULE__, {:update_demand, resource, demand})
  end

  @doc """
  Updates capacity for a resource.
  """
  @spec update_capacity(resource_type(), non_neg_integer()) :: :ok
  def update_capacity(resource, capacity) do
    GenServer.cast(__MODULE__, {:update_capacity, resource, capacity})
  end

  @doc """
  Gets price history for a resource.
  """
  @spec history(resource_type(), Keyword.t()) :: [price_point()]
  def history(resource, opts \\ []) do
    GenServer.call(__MODULE__, {:history, resource, opts})
  end

  @doc """
  Gets current pricing summary.
  """
  @spec summary() :: map()
  def summary do
    GenServer.call(__MODULE__, :summary)
  end

  @doc """
  Sets base price for a resource (admin only).
  """
  @spec set_base_price(resource_type(), price()) :: :ok
  def set_base_price(resource, price) do
    GenServer.call(__MODULE__, {:set_base_price, resource, price})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      base_prices: Keyword.get(opts, :base_prices, @base_prices),
      current_prices: Keyword.get(opts, :base_prices, @base_prices),
      demand: %{cpu: 0, memory: 0, network: 0, storage: 0},
      capacity: %{cpu: 100, memory: 100, network: 100, storage: 100},
      history: [],
      config: %{
        update_interval: Keyword.get(opts, :update_interval, 10_000),
        smoothing: Keyword.get(opts, :smoothing, 0.1)
      }
    }

    # Schedule periodic price updates
    Process.send_after(self(), :update_prices, state.config.update_interval)

    {:ok, state}
  end

  @impl true
  def handle_call({:get_price, resource, opts}, _from, state) do
    base = Map.get(state.current_prices, resource, 1.0)
    priority = Keyword.get(opts, :priority, :normal)
    quantity = Keyword.get(opts, :quantity, 1)

    # Apply priority multiplier
    priority_mult = Map.get(@priority_multipliers, priority, 1.0)

    # Apply time-of-day multiplier
    time_mult = time_multiplier()

    # Final price
    price = base * priority_mult * time_mult * quantity

    {:reply, price, state}
  end

  @impl true
  def handle_call({:get_prices, resources}, _from, state) do
    prices =
      Enum.into(resources, %{}, fn resource ->
        {resource, Map.get(state.current_prices, resource, 1.0)}
      end)

    {:reply, prices, state}
  end

  @impl true
  def handle_call({:calculate_cost, bundle, opts}, _from, state) do
    priority = Keyword.get(opts, :priority, :normal)
    priority_mult = Map.get(@priority_multipliers, priority, 1.0)
    time_mult = time_multiplier()

    total =
      Enum.reduce(bundle, 0.0, fn {resource, quantity}, acc ->
        base = Map.get(state.current_prices, resource, 1.0)
        acc + base * quantity * priority_mult * time_mult
      end)

    {:reply, total, state}
  end

  @impl true
  def handle_call({:history, resource, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)

    history =
      state.history
      |> Enum.filter(&(&1.resource == resource))
      |> Enum.take(limit)

    {:reply, history, state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    summary = %{
      current_prices: state.current_prices,
      base_prices: state.base_prices,
      demand: state.demand,
      capacity: state.capacity,
      utilization: calculate_utilization(state),
      time_multiplier: time_multiplier()
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_call({:set_base_price, resource, price}, _from, state) do
    # Ensure non-negative (SC-PRC-001)
    if price < 0 do
      {:reply, {:error, :negative_price}, state}
    else
      new_base = Map.put(state.base_prices, resource, price)
      {:reply, :ok, %{state | base_prices: new_base}}
    end
  end

  @impl true
  def handle_cast({:update_demand, resource, demand}, state) do
    new_demand = Map.put(state.demand, resource, demand)
    {:noreply, %{state | demand: new_demand}}
  end

  @impl true
  def handle_cast({:update_capacity, resource, capacity}, state) do
    new_capacity = Map.put(state.capacity, resource, capacity)
    {:noreply, %{state | capacity: new_capacity}}
  end

  @impl true
  def handle_info(:update_prices, state) do
    # Update prices based on demand/capacity
    new_prices =
      Enum.into(state.base_prices, %{}, fn {resource, base} ->
        demand = Map.get(state.demand, resource, 0)
        capacity = Map.get(state.capacity, resource, 100)

        # Calculate demand multiplier
        utilization = if capacity > 0, do: demand / capacity, else: 1.0
        demand_mult = demand_multiplier(utilization)

        # Calculate target price
        target = base * demand_mult

        # Apply smoothing and limit change rate (SC-PRC-002)
        current = Map.get(state.current_prices, resource, base)
        new_price = smooth_price(current, target, state.config.smoothing)

        {resource, new_price}
      end)

    # Record price points (SC-PRC-004)
    new_history =
      Enum.reduce(new_prices, state.history, fn {resource, price}, history ->
        point = %{
          resource: resource,
          price: price,
          timestamp: DateTime.utc_now(),
          factors: %{
            demand: Map.get(state.demand, resource, 0),
            capacity: Map.get(state.capacity, resource, 100)
          }
        }

        [point | Enum.take(history, @max_history - 1)]
      end)

    # Schedule next update
    Process.send_after(self(), :update_prices, state.config.update_interval)

    {:noreply, %{state | current_prices: new_prices, history: new_history}}
  end

  # Private helpers

  defp demand_multiplier(utilization) do
    cond do
      utilization < 0.3 -> 0.8
      utilization < 0.5 -> 0.9
      utilization < 0.7 -> 1.0
      utilization < 0.8 -> 1.2
      utilization < 0.9 -> 1.5
      utilization < 0.95 -> 2.0
      true -> 3.0
    end
  end

  defp time_multiplier do
    hour = DateTime.utc_now().hour

    cond do
      hour in 0..6 -> 0.7
      hour in 7..9 -> 1.2
      hour in 10..12 -> 1.0
      hour in 13..14 -> 0.9
      hour in 15..18 -> 1.2
      hour in 19..21 -> 1.0
      true -> 0.8
    end
  end

  defp smooth_price(current, target, smoothing) do
    # Calculate change
    change = target - current
    max_change = current * @max_price_change

    # Limit change rate (SC-PRC-002)
    limited_change =
      cond do
        change > max_change -> max_change
        change < -max_change -> -max_change
        true -> change
      end

    # Apply smoothing
    current + limited_change * smoothing
  end

  defp calculate_utilization(state) do
    Enum.into(state.demand, %{}, fn {resource, demand} ->
      capacity = Map.get(state.capacity, resource, 100)
      util = if capacity > 0, do: demand / capacity, else: 1.0
      {resource, Float.round(util, 2)}
    end)
  end
end
