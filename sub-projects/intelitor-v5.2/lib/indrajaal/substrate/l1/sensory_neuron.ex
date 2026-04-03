defmodule Indrajaal.Substrate.L1.SensoryNeuron do
  @moduledoc """
  ## Design Intent
  L1 substrate sensory neuron — receives raw sensor data, applies EWMA
  (Exponentially Weighted Moving Average) noise filtering, and forwards
  cleaned signals to motor neurons via PubSub.

  Signal pipeline:
    1. Raw sensor reading arrives via `sense/2`
    2. EWMA filter applied: filtered = α × raw + (1-α) × prev_filtered
    3. Noise gate: only forward if |filtered - prev_forwarded| > dead_band
    4. Forward filtered signal on PubSub topic "substrate:motor_input"
    5. Telemetry published each cycle

  EWMA smoothing factor α ∈ (0.0, 1.0]:
    - α → 1.0 = no smoothing (pass-through)
    - α → 0.0 = heavy smoothing (very slow response)
    - Default α = 0.15 (moderate smoothing)

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-DAT-033: Environmental sensor data collection — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_motor "substrate:motor_input"

  @default_alpha 0.15
  @default_dead_band 0.01

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Deliver a raw sensor reading (0.0–1.0) for channel `channel_id`.
  Returns `{:forwarded, filtered_value}` or `{:suppressed, filtered_value}`.
  """
  @spec sense(String.t(), float()) ::
          {:forwarded, float()} | {:suppressed, float()}
  def sense(channel_id, raw_value)
      when is_binary(channel_id) and is_float(raw_value) do
    GenServer.call(@name, {:sense, channel_id, raw_value})
  end

  @doc "Returns per-channel sensor state."
  @spec channel_state(String.t()) :: map() | nil
  def channel_state(channel_id) when is_binary(channel_id) do
    GenServer.call(@name, {:channel_state, channel_id})
  end

  @doc "Returns all channel states."
  @spec all_channels() :: map()
  def all_channels do
    GenServer.call(@name, :all_channels)
  end

  @doc "Configure EWMA alpha for a channel (0 < alpha <= 1.0)."
  @spec set_alpha(String.t(), float()) :: :ok | {:error, :invalid_alpha}
  def set_alpha(channel_id, alpha)
      when is_binary(channel_id) and is_float(alpha) and alpha > 0.0 and alpha <= 1.0 do
    GenServer.call(@name, {:set_alpha, channel_id, alpha})
  end

  def set_alpha(_channel_id, _alpha), do: {:error, :invalid_alpha}

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    default_alpha = Keyword.get(opts, :alpha, @default_alpha)
    dead_band = Keyword.get(opts, :dead_band, @default_dead_band)

    state = %{
      channels: %{},
      default_alpha: default_alpha,
      dead_band: dead_band,
      total_sensed: 0,
      total_forwarded: 0
    }

    Logger.info("[SENSORY_NEURON] started — alpha=#{default_alpha} dead_band=#{dead_band}")
    {:ok, state}
  end

  @impl true
  def handle_call({:sense, channel_id, raw_value}, _from, state) do
    channel = Map.get(state.channels, channel_id, new_channel(state.default_alpha))

    # Apply EWMA
    filtered = channel.alpha * raw_value + (1.0 - channel.alpha) * channel.filtered_value

    # Noise gate
    delta = abs(filtered - channel.last_forwarded)
    should_forward = delta >= state.dead_band

    updated_channel = %{
      channel
      | filtered_value: filtered,
        last_forwarded: if(should_forward, do: filtered, else: channel.last_forwarded),
        sample_count: channel.sample_count + 1,
        forward_count: channel.forward_count + if(should_forward, do: 1, else: 0),
        last_raw: raw_value
    }

    new_state = %{
      state
      | channels: Map.put(state.channels, channel_id, updated_channel),
        total_sensed: state.total_sensed + 1,
        total_forwarded: state.total_forwarded + if(should_forward, do: 1, else: 0)
    }

    if should_forward do
      msg = %{
        channel_id: channel_id,
        raw_value: raw_value,
        filtered_value: filtered,
        timestamp: System.monotonic_time(:millisecond)
      }

      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_motor, {:sensor_signal, msg})

      Logger.debug(
        "[SENSORY_NEURON] forwarded channel=#{channel_id} raw=#{Float.round(raw_value, 4)} filtered=#{Float.round(filtered, 4)}"
      )
    end

    reply = if should_forward, do: {:forwarded, filtered}, else: {:suppressed, filtered}
    {:reply, reply, new_state}
  end

  @impl true
  def handle_call({:channel_state, channel_id}, _from, state) do
    {:reply, Map.get(state.channels, channel_id), state}
  end

  @impl true
  def handle_call(:all_channels, _from, state) do
    {:reply, state.channels, state}
  end

  @impl true
  def handle_call({:set_alpha, channel_id, alpha}, _from, state) do
    channel = Map.get(state.channels, channel_id, new_channel(state.default_alpha))
    updated = %{channel | alpha: alpha}
    {:reply, :ok, %{state | channels: Map.put(state.channels, channel_id, updated)}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp new_channel(alpha) do
    %{
      alpha: alpha,
      filtered_value: 0.5,
      last_forwarded: 0.5,
      last_raw: 0.5,
      sample_count: 0,
      forward_count: 0
    }
  end
end
