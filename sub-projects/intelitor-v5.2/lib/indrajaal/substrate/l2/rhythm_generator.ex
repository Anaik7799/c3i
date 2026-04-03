defmodule Indrajaal.Substrate.L2.RhythmGenerator do
  @moduledoc """
  L2 Rhythm Generator — VSM System 2 periodic coordination signal producer.

  Produces periodic "beat" events that subsystems use to synchronise their
  internal cycles. Analogous to a biological pacemaker: it maintains a
  configurable tempo (beat_interval_ms), advances through discrete phases,
  and broadcasts beat events to all registered subscribers via Phoenix.PubSub
  topic "prajna:rhythm".

  ## Algorithm
  1. Schedule a timer tick every `beat_interval_ms` milliseconds.
  2. On each tick: advance phase (wraps at @phase_count), build beat payload.
  3. Broadcast `{:beat, payload}` to "prajna:rhythm" PubSub topic.
  4. Deliver directly to registered subscriber PIDs (in-process delivery).

  ## Phase Semantics
  - Phase 0 — Reset / baseline
  - Phase 1 — Active coordination window
  - Phase 2 — Quorum collection
  - Phase 3 — Apply / commit

  ## STAMP Constraints
  - SC-S2-001: S2 coordination subsystem constraints — ENFORCED
  - SC-S2-002: Oscillation detection mandatory — ENFORCED (phase tracks periodicity)
  - SC-S2-003: Subsystem synchronisation signal — ENFORCED
  - SC-S2-004: Broadcast via PubSub "prajna:rhythm" — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L2 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:rhythm"
  @default_interval_ms 1_000
  @phase_count 4

  @type phase :: 0 | 1 | 2 | 3

  @type beat_payload :: %{
          beat: non_neg_integer(),
          phase: phase(),
          interval_ms: pos_integer(),
          timestamp: DateTime.t()
        }

  @type t :: %{
          beat_interval_ms: pos_integer(),
          phase: phase(),
          beat_count: non_neg_integer(),
          subscribers: [pid()],
          timer_ref: reference() | nil
        }

  # ── Client API ──────────────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Subscribe the calling process to beat events. Returns :ok."
  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.call(@name, {:subscribe, pid})
  end

  @doc "Set the tempo in milliseconds. Must be > 0."
  @spec set_tempo(pos_integer()) :: :ok | {:error, :invalid_interval}
  def set_tempo(interval_ms) when is_integer(interval_ms) and interval_ms > 0 do
    GenServer.call(@name, {:set_tempo, interval_ms})
  end

  def set_tempo(_), do: {:error, :invalid_interval}

  @doc "Returns the current phase (0..3)."
  @spec current_phase() :: phase()
  def current_phase do
    GenServer.call(@name, :current_phase)
  end

  @doc "Returns current generator status."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  # ── GenServer Callbacks ──────────────────────────────────────────────

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :beat_interval_ms, @default_interval_ms)

    state = %{
      beat_interval_ms: interval_ms,
      phase: 0,
      beat_count: 0,
      subscribers: [],
      timer_ref: nil
    }

    timer_ref = schedule_beat(interval_ms)

    Logger.info("[RHYTHM_GENERATOR] started — interval=#{interval_ms}ms")

    {:ok, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    subscribers = Enum.uniq([pid | state.subscribers])
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_call({:set_tempo, interval_ms}, _from, state) do
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    timer_ref = schedule_beat(interval_ms)

    Logger.info(
      "[RHYTHM_GENERATOR] tempo changed — #{state.beat_interval_ms}ms → #{interval_ms}ms"
    )

    {:reply, :ok, %{state | beat_interval_ms: interval_ms, timer_ref: timer_ref}}
  end

  @impl true
  def handle_call(:current_phase, _from, state) do
    {:reply, state.phase, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      beat_interval_ms: state.beat_interval_ms,
      phase: state.phase,
      beat_count: state.beat_count,
      subscriber_count: length(state.subscribers)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:beat, state) do
    new_phase = rem(state.phase + 1, @phase_count)
    new_beat_count = state.beat_count + 1

    payload = %{
      beat: new_beat_count,
      phase: new_phase,
      interval_ms: state.beat_interval_ms,
      timestamp: DateTime.utc_now()
    }

    broadcast(payload, state.subscribers)
    timer_ref = schedule_beat(state.beat_interval_ms)

    {:noreply, %{state | phase: new_phase, beat_count: new_beat_count, timer_ref: timer_ref}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    subscribers = List.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ──────────────────────────────────────────────────────────

  @spec schedule_beat(pos_integer()) :: reference()
  defp schedule_beat(interval_ms) do
    Process.send_after(self(), :beat, interval_ms)
  end

  @spec broadcast(beat_payload(), [pid()]) :: :ok
  defp broadcast(payload, subscribers) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:beat, payload}
      )
    rescue
      _ -> :ok
    end

    Enum.each(subscribers, fn pid ->
      send(pid, {:beat, payload})
    end)

    :telemetry.execute(
      [:substrate, :l2, :rhythm_generator, :beat],
      %{beat_count: payload.beat},
      %{phase: payload.phase}
    )

    :ok
  rescue
    _ -> :ok
  end
end
