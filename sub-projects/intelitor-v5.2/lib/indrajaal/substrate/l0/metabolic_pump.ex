defmodule Indrajaal.Substrate.L0.MetabolicPump do
  @moduledoc """
  ## Design Intent
  L0 substrate metabolic pump — manages resource-level pumping for the biomorphic
  mesh. Tracks a continuous resource_level (0.0–1.0), an adjustable pump_rate, and
  a target_level setpoint. On each :pump tick the level is driven toward the target
  via a first-order exponential approach (rate-limited).

  Pump cycle (default 2 s):
    1. Compute delta = target_level - resource_level
    2. Step = pump_rate × dt (clamped to delta sign)
    3. resource_level updated, clamped to [0.0, 1.0]
    4. Metrics broadcast via PubSub "substrate:metabolic_pump"

  ## STAMP Constraints
  - SC-HOM-001: Homeostatic controller — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "substrate:metabolic_pump"
  @pump_interval_ms 2_000

  # Clamp helpers
  @resource_min 0.0
  @resource_max 1.0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Returns current {resource_level, pump_rate, target_level}."
  @spec status() :: %{resource_level: float(), pump_rate: float(), target_level: float()}
  def status do
    GenServer.call(@name, :status)
  end

  @doc "Set new target level (0.0–1.0)."
  @spec set_target(float()) :: :ok | {:error, :out_of_range}
  def set_target(level) when is_float(level) and level >= 0.0 and level <= 1.0 do
    GenServer.call(@name, {:set_target, level})
  end

  def set_target(_), do: {:error, :out_of_range}

  @doc "Set pump rate (units/s, must be positive)."
  @spec set_pump_rate(float()) :: :ok | {:error, :invalid_rate}
  def set_pump_rate(rate) when is_float(rate) and rate > 0.0 do
    GenServer.call(@name, {:set_pump_rate, rate})
  end

  def set_pump_rate(_), do: {:error, :invalid_rate}

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    resource_level = Keyword.get(opts, :resource_level, 0.5)
    pump_rate = Keyword.get(opts, :pump_rate, 0.1)
    target_level = Keyword.get(opts, :target_level, 0.8)

    schedule_pump()

    state = %{
      resource_level: clamp(resource_level),
      pump_rate: pump_rate,
      target_level: clamp(target_level),
      cycle_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[METABOLIC_PUMP] started — resource=#{resource_level} target=#{target_level} rate=#{pump_rate}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply,
     %{
       resource_level: state.resource_level,
       pump_rate: state.pump_rate,
       target_level: state.target_level
     }, state}
  end

  @impl true
  def handle_call({:set_target, level}, _from, state) do
    {:reply, :ok, %{state | target_level: level}}
  end

  @impl true
  def handle_call({:set_pump_rate, rate}, _from, state) do
    {:reply, :ok, %{state | pump_rate: rate}}
  end

  @impl true
  def handle_info(:pump, state) do
    dt = @pump_interval_ms / 1_000.0
    delta = state.target_level - state.resource_level
    # Step toward target, never overshoot
    step = min(abs(delta), state.pump_rate * dt) * sign(delta)
    new_level = clamp(state.resource_level + step)

    new_state = %{state | resource_level: new_level, cycle_count: state.cycle_count + 1}

    broadcast(new_state)
    schedule_pump()

    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float()) :: float()
  defp clamp(v), do: max(@resource_min, min(@resource_max, v))

  @spec sign(float()) :: float()
  defp sign(v) when v >= 0.0, do: 1.0
  defp sign(_), do: -1.0

  defp schedule_pump do
    Process.send_after(self(), :pump, @pump_interval_ms)
  end

  defp broadcast(state) do
    payload = %{
      resource_level: state.resource_level,
      pump_rate: state.pump_rate,
      target_level: state.target_level,
      cycle_count: state.cycle_count,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:metabolic_pump_update, payload})
  end
end
