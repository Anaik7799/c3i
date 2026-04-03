defmodule Indrajaal.Substrate.L2.CoordinationDampener do
  @moduledoc """
  L2 Coordination Dampener — VSM System 2 oscillation damping.

  Detects and suppresses inter-subsystem oscillations using exponential moving
  average (EMA) smoothing and deadband filtering. When two subsystems enter
  a feedback loop (e.g., CPU governor vs scheduler), the dampener reduces gain
  to prevent hunting.

  ## Algorithm
  1. Track signal history per channel (EMA with configurable alpha)
  2. Compute oscillation index: ratio of sign changes to total samples
  3. If oscillation_index > threshold, apply gain reduction (damping_factor)
  4. Publish damping events to PubSub for cockpit display

  ## STAMP Constraints
  - SC-S2-001: S2 coordination subsystem constraints
  - SC-S2-002: Oscillation detection mandatory
  - SC-HOM-001: Homeostatic controller integration
  """

  use GenServer
  require Logger

  @default_alpha 0.3
  @default_threshold 0.6
  @default_damping_factor 0.5
  @history_size 20
  @check_interval_ms 2_000

  defstruct channels: %{},
            alpha: @default_alpha,
            threshold: @default_threshold,
            damping_factor: @default_damping_factor,
            damping_active: %{}

  @type channel_state :: %{
          values: [float()],
          ema: float(),
          oscillation_index: float(),
          damped: boolean()
        }

  @type t :: %__MODULE__{
          channels: %{atom() => channel_state()},
          alpha: float(),
          threshold: float(),
          damping_factor: float(),
          damping_active: %{atom() => boolean()}
        }

  # ── Client API ──────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec record(atom(), float()) :: :ok
  def record(channel, value) when is_atom(channel) and is_number(value) do
    GenServer.cast(__MODULE__, {:record, channel, value / 1})
  end

  @spec damped_value(atom(), float()) :: float()
  def damped_value(channel, raw_value) do
    GenServer.call(__MODULE__, {:damped_value, channel, raw_value / 1})
  end

  @spec oscillation_index(atom()) :: {:ok, float()} | {:error, :unknown_channel}
  def oscillation_index(channel) do
    GenServer.call(__MODULE__, {:oscillation_index, channel})
  end

  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────

  @impl true
  def init(opts) do
    alpha = Keyword.get(opts, :alpha, @default_alpha)
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    damping_factor = Keyword.get(opts, :damping_factor, @default_damping_factor)

    Process.send_after(self(), :check_oscillations, @check_interval_ms)

    {:ok,
     %__MODULE__{
       alpha: alpha,
       threshold: threshold,
       damping_factor: damping_factor
     }}
  end

  @impl true
  def handle_cast({:record, channel, value}, state) do
    channel_state = Map.get(state.channels, channel, new_channel_state())
    updated = update_channel(channel_state, value, state.alpha)
    channels = Map.put(state.channels, channel, updated)
    {:noreply, %{state | channels: channels}}
  end

  @impl true
  def handle_call({:damped_value, channel, raw_value}, _from, state) do
    is_damped = Map.get(state.damping_active, channel, false)

    result =
      if is_damped do
        raw_value * state.damping_factor
      else
        raw_value
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:oscillation_index, channel}, _from, state) do
    case Map.get(state.channels, channel) do
      nil -> {:reply, {:error, :unknown_channel}, state}
      ch -> {:reply, {:ok, ch.oscillation_index}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    summary =
      Enum.map(state.channels, fn {name, ch} ->
        {name,
         %{
           ema: ch.ema,
           oscillation_index: ch.oscillation_index,
           damped: Map.get(state.damping_active, name, false),
           sample_count: length(ch.values)
         }}
      end)
      |> Map.new()

    {:reply, %{channels: summary, config: %{alpha: state.alpha, threshold: state.threshold}},
     state}
  end

  @impl true
  def handle_info(:check_oscillations, state) do
    damping_active =
      Enum.reduce(state.channels, %{}, fn {name, ch}, acc ->
        was_damped = Map.get(state.damping_active, name, false)
        now_damped = ch.oscillation_index > state.threshold

        if now_damped and not was_damped do
          Logger.warning(
            "[L2-Dampener] Oscillation detected on #{name}: #{Float.round(ch.oscillation_index, 3)}"
          )

          publish_damping_event(name, :activated, ch.oscillation_index)
        end

        if was_damped and not now_damped do
          Logger.info("[L2-Dampener] Oscillation resolved on #{name}")
          publish_damping_event(name, :deactivated, ch.oscillation_index)
        end

        Map.put(acc, name, now_damped)
      end)

    Process.send_after(self(), :check_oscillations, @check_interval_ms)
    {:noreply, %{state | damping_active: damping_active}}
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp new_channel_state do
    %{values: [], ema: 0.0, oscillation_index: 0.0, damped: false}
  end

  defp update_channel(ch, value, alpha) do
    values = Enum.take([value | ch.values], @history_size)
    ema = alpha * value + (1 - alpha) * ch.ema
    osc = compute_oscillation_index(values)
    %{ch | values: values, ema: ema, oscillation_index: osc}
  end

  defp compute_oscillation_index(values) when length(values) < 3, do: 0.0

  defp compute_oscillation_index(values) do
    deltas = values |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> a - b end)
    signs = Enum.map(deltas, fn d -> if d >= 0, do: 1, else: -1 end)

    sign_changes =
      signs
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [a, b] -> a != b end)

    total = max(length(signs) - 1, 1)
    sign_changes / total
  end

  defp publish_damping_event(channel, event, index) do
    payload = %{
      channel: channel,
      event: event,
      oscillation_index: index,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:coordination",
      {:damping_event, payload}
    )

    :telemetry.execute(
      [:substrate, :l2, :dampener],
      %{oscillation_index: index},
      %{channel: channel, event: event}
    )
  rescue
    _ -> :ok
  end
end
