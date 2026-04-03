defmodule Indrajaal.Substrate.L0.EnergyHarvester do
  @moduledoc """
  ## Design Intent
  L0 substrate energy harvester — collects energy units from telemetry events and
  accumulates them in an ETS counter. Subscribes to PubSub topics to receive
  event notifications, computes energy contribution per event type, and publishes
  aggregate energy state to "prajna:energy" every harvest cycle.

  Energy model:
    - Each event type has a configurable energy_value (default 1.0 unit)
    - Total energy_units accumulates without bound (consumers drain it)
    - Harvest cycle (default 5 s) resets the per-cycle accumulator and broadcasts

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-HOM-002: Energy balance monitoring — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_energy :energy_harvester_store
  @pubsub_energy "prajna:energy"
  @harvest_interval_ms 5_000

  # Default energy units per unlisted event type
  @default_energy_per_event 1.0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Returns {total_energy_units, cycle_energy, event_count, cycle_event_count}."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  @doc "Manually inject an energy event (type, value)."
  @spec harvest_event(atom(), float()) :: :ok
  def harvest_event(event_type, value \\ @default_energy_per_event)
      when is_atom(event_type) and is_float(value) do
    GenServer.cast(@name, {:harvest_event, event_type, value})
  end

  @doc "Drain a given number of energy units from the total. Returns actual drained."
  @spec drain(float()) :: float()
  def drain(amount) when is_float(amount) and amount > 0.0 do
    GenServer.call(@name, {:drain, amount})
  end

  @doc "Register an energy value for a specific event type."
  @spec register_event_value(atom(), float()) :: :ok
  def register_event_value(event_type, value) when is_atom(event_type) and is_float(value) do
    GenServer.call(@name, {:register_event_value, event_type, value})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_energy, [:set, :public, :named_table, write_concurrency: true])
    :ets.insert(@ets_energy, {:total_energy, 0.0})
    :ets.insert(@ets_energy, {:cycle_energy, 0.0})
    :ets.insert(@ets_energy, {:event_count, 0})
    :ets.insert(@ets_energy, {:cycle_event_count, 0})

    subscriptions = Keyword.get(opts, :subscriptions, [])
    Enum.each(subscriptions, &Phoenix.PubSub.subscribe(Indrajaal.PubSub, &1))

    event_values = Keyword.get(opts, :event_values, %{})

    schedule_harvest()

    state = %{
      event_values: event_values,
      cycle_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info("[ENERGY_HARVESTER] started — subscriptions=#{inspect(subscriptions)}")
    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    total = ets_get(:total_energy, 0.0)
    cycle = ets_get(:cycle_energy, 0.0)
    count = ets_get(:event_count, 0)
    cycle_count = ets_get(:cycle_event_count, 0)

    reply = %{
      total_energy_units: total,
      cycle_energy: cycle,
      event_count: count,
      cycle_event_count: cycle_count,
      cycle_count: state.cycle_count
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:drain, amount}, _from, state) do
    total = ets_get(:total_energy, 0.0)
    drained = min(total, amount)
    :ets.insert(@ets_energy, {:total_energy, total - drained})
    {:reply, drained, state}
  end

  @impl true
  def handle_call({:register_event_value, event_type, value}, _from, state) do
    {:reply, :ok, %{state | event_values: Map.put(state.event_values, event_type, value)}}
  end

  @impl true
  def handle_cast({:harvest_event, event_type, value}, state) do
    energy = Map.get(state.event_values, event_type, value)
    ets_add(:total_energy, energy)
    ets_add(:cycle_energy, energy)
    ets_inc(:event_count)
    ets_inc(:cycle_event_count)
    {:noreply, state}
  end

  # Catch PubSub messages — extract event type and harvest energy
  @impl true
  def handle_info({event_type, _payload}, state) when is_atom(event_type) do
    GenServer.cast(self(), {:harvest_event, event_type, @default_energy_per_event})
    {:noreply, state}
  end

  @impl true
  def handle_info(:harvest, state) do
    total = ets_get(:total_energy, 0.0)
    cycle_energy = ets_get(:cycle_energy, 0.0)
    cycle_events = ets_get(:cycle_event_count, 0)

    # Reset per-cycle accumulators
    :ets.insert(@ets_energy, {:cycle_energy, 0.0})
    :ets.insert(@ets_energy, {:cycle_event_count, 0})

    payload = %{
      total_energy_units: total,
      cycle_energy: cycle_energy,
      cycle_events: cycle_events,
      cycle_count: state.cycle_count + 1,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_energy, {:energy_harvest, payload})

    Logger.debug(
      "[ENERGY_HARVESTER] harvest cycle=#{state.cycle_count + 1} total=#{Float.round(total, 3)} cycle_energy=#{Float.round(cycle_energy, 3)}"
    )

    schedule_harvest()
    {:noreply, %{state | cycle_count: state.cycle_count + 1}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedule_harvest do
    Process.send_after(self(), :harvest, @harvest_interval_ms)
  end

  defp ets_get(key, default) do
    case :ets.lookup(@ets_energy, key) do
      [{^key, v}] -> v
      [] -> default
    end
  end

  defp ets_add(key, amount) do
    current = ets_get(key, 0.0)
    :ets.insert(@ets_energy, {key, current + amount})
  end

  defp ets_inc(key) do
    current = ets_get(key, 0)
    :ets.insert(@ets_energy, {key, current + 1})
  end
end
