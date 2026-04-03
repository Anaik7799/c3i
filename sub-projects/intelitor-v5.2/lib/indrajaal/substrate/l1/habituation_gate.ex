defmodule Indrajaal.Substrate.L1.HabituationGate do
  @moduledoc """
  ## Design Intent
  L1 substrate habituation gate — implements biological habituation: the
  reduction in response strength when the same stimulus is presented repeatedly.
  After a period without stimulation, the response recovers via decay.

  Habituation model (per stimulus channel):
    - Each stimulus increments a fatigue accumulator F by `fatigue_increment`
    - Response gain = max(0.0, 1.0 - F)  (1.0 = full, 0.0 = fully habituated)
    - F decays continuously: F(t) = F₀ × e^(-λ × Δt)
      where λ = decay_rate (default 0.1 per second)
    - If response gain falls below `inhibit_threshold` (default 0.1), the gate
      suppresses the response entirely

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-DFA-001: Deterministic finite automaton — gate states are deterministic — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "substrate:habituation"

  @default_fatigue_increment 0.2
  @default_decay_rate 0.1
  @default_inhibit_threshold 0.1
  @decay_tick_ms 500

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Present a stimulus on `channel_id` and compute gated response gain.

  Returns `{:respond, gain}` when gain > inhibit_threshold,
  or `{:inhibited, gain}` when fully habituated.
  """
  @spec stimulate(String.t(), float()) ::
          {:respond, float()} | {:inhibited, float()}
  def stimulate(channel_id, intensity \\ 1.0)
      when is_binary(channel_id) and is_float(intensity) do
    GenServer.call(@name, {:stimulate, channel_id, intensity})
  end

  @doc "Returns habituation state for a channel."
  @spec channel_state(String.t()) :: map() | nil
  def channel_state(channel_id) when is_binary(channel_id) do
    GenServer.call(@name, {:channel_state, channel_id})
  end

  @doc "Force-reset habituation for a channel."
  @spec reset_channel(String.t()) :: :ok
  def reset_channel(channel_id) when is_binary(channel_id) do
    GenServer.call(@name, {:reset_channel, channel_id})
  end

  @doc "Returns all channel states with current gain."
  @spec all_channels() :: map()
  def all_channels do
    GenServer.call(@name, :all_channels)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    state = %{
      channels: %{},
      fatigue_increment: Keyword.get(opts, :fatigue_increment, @default_fatigue_increment),
      decay_rate: Keyword.get(opts, :decay_rate, @default_decay_rate),
      inhibit_threshold: Keyword.get(opts, :inhibit_threshold, @default_inhibit_threshold)
    }

    schedule_decay()

    Logger.info(
      "[HABITUATION_GATE] started — fatigue_increment=#{state.fatigue_increment} decay_rate=#{state.decay_rate}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:stimulate, channel_id, intensity}, _from, state) do
    now_ms = System.monotonic_time(:millisecond)
    channel = get_or_create_channel(state.channels, channel_id, now_ms)

    # Apply temporal decay first for accurate current fatigue
    channel = apply_decay(channel, now_ms, state.decay_rate)

    # Add fatigue proportional to stimulus intensity
    new_fatigue = min(1.0, channel.fatigue + state.fatigue_increment * intensity)
    gain = max(0.0, 1.0 - new_fatigue)

    updated_channel = %{
      channel
      | fatigue: new_fatigue,
        last_stimulus_at: now_ms,
        stimulus_count: channel.stimulus_count + 1,
        last_gain: gain
    }

    new_state = %{state | channels: Map.put(state.channels, channel_id, updated_channel)}

    result =
      if gain > state.inhibit_threshold do
        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          @pubsub_topic,
          {:habituation_gate, %{channel: channel_id, gain: gain, fatigue: new_fatigue}}
        )

        {:respond, gain}
      else
        {:inhibited, gain}
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:channel_state, channel_id}, _from, state) do
    {:reply, Map.get(state.channels, channel_id), state}
  end

  @impl true
  def handle_call({:reset_channel, channel_id}, _from, state) do
    now_ms = System.monotonic_time(:millisecond)
    fresh = new_channel(now_ms)
    {:reply, :ok, %{state | channels: Map.put(state.channels, channel_id, fresh)}}
  end

  @impl true
  def handle_call(:all_channels, _from, state) do
    {:reply, state.channels, state}
  end

  @impl true
  def handle_info(:decay_tick, state) do
    now_ms = System.monotonic_time(:millisecond)

    updated_channels =
      Map.new(state.channels, fn {id, ch} ->
        {id, apply_decay(ch, now_ms, state.decay_rate)}
      end)

    schedule_decay()
    {:noreply, %{state | channels: updated_channels}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp new_channel(now_ms) do
    %{
      fatigue: 0.0,
      last_stimulus_at: now_ms,
      last_decay_at: now_ms,
      stimulus_count: 0,
      last_gain: 1.0
    }
  end

  defp get_or_create_channel(channels, channel_id, now_ms) do
    Map.get(channels, channel_id, new_channel(now_ms))
  end

  @spec apply_decay(map(), integer(), float()) :: map()
  defp apply_decay(channel, now_ms, decay_rate) do
    dt_s = (now_ms - channel.last_decay_at) / 1_000.0
    new_fatigue = channel.fatigue * :math.exp(-decay_rate * dt_s)

    %{
      channel
      | fatigue: new_fatigue,
        last_decay_at: now_ms,
        last_gain: max(0.0, 1.0 - new_fatigue)
    }
  end

  defp schedule_decay do
    Process.send_after(self(), :decay_tick, @decay_tick_ms)
  end
end
