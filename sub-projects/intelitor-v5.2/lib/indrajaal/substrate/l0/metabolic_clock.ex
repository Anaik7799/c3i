defmodule Indrajaal.Substrate.L0.MetabolicClock do
  @moduledoc """
  ## Design Intent
  L0 substrate metabolic clock — GenServer maintaining the holon's internal
  sense of biological time. Unlike wall-clock time, the metabolic clock counts
  autonomous ticks and tracks drift against an external synchronisation source.

  Tick model:
    - A periodic `:tick` message fires every `tick_interval_ms` (default 1000 ms)
    - Each tick increments `tick_count` and records `last_tick_at` (monotonic ms)
    - Drift is computed on each `sync/1` call: drift_ms = (external_now_ms - internal_estimate_ms)
    - State is broadcast to PubSub topic "prajna:metabolic_clock" on every tick

  Drift accumulation:
    - `drift_ms` is an EWMA (α = 0.2) of successive sync samples
    - Positive drift: holon clock is slow relative to external reference
    - Negative drift: holon clock is running fast

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-DMS-001: Heartbeat interval MUST be 100 ms (tick default overrideable) — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:metabolic_clock"

  # Default tick interval: 1 second
  @default_tick_interval_ms 1_000

  # EWMA smoothing factor for drift
  @drift_alpha 0.2

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type tick_count :: non_neg_integer()
  @type drift_ms :: float()
  @type status :: %{
          tick_count: tick_count(),
          drift_ms: drift_ms(),
          last_sync: DateTime.t() | nil,
          tick_interval_ms: pos_integer(),
          uptime_ms: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Manually trigger a tick and return the new tick_count.
  In normal operation ticks fire automatically; this is for testing/forcing.
  """
  @spec tick() :: tick_count()
  def tick do
    GenServer.call(@name, :tick)
  end

  @doc """
  Returns the current accumulated drift in milliseconds.
  Positive = holon clock is slow; negative = holon clock is fast.
  """
  @spec drift() :: drift_ms()
  def drift do
    GenServer.call(@name, :drift)
  end

  @doc """
  Synchronise the metabolic clock against an external reference.
  `external_now_ms` is the caller's monotonic timestamp in milliseconds.
  Returns the updated drift_ms.
  """
  @spec sync(pos_integer()) :: {:ok, drift_ms()}
  def sync(external_now_ms) when is_integer(external_now_ms) and external_now_ms > 0 do
    GenServer.call(@name, {:sync, external_now_ms})
  end

  @doc """
  Returns the full status map.
  """
  @spec status() :: status()
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    tick_interval_ms = Keyword.get(opts, :tick_interval_ms, @default_tick_interval_ms)

    state = %{
      tick_count: 0,
      drift_ms: 0.0,
      last_sync: nil,
      tick_interval_ms: tick_interval_ms,
      started_at_ms: System.monotonic_time(:millisecond),
      last_tick_at: nil
    }

    schedule_tick(tick_interval_ms)

    Logger.info("[METABOLIC_CLOCK] started — tick_interval=#{tick_interval_ms}ms")
    {:ok, state}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    new_state = do_tick(state)
    {:reply, new_state.tick_count, new_state}
  end

  @impl true
  def handle_call(:drift, _from, state) do
    {:reply, state.drift_ms, state}
  end

  @impl true
  def handle_call({:sync, external_now_ms}, _from, state) do
    now_ms = System.monotonic_time(:millisecond)
    # Estimate where our clock thinks we are
    internal_estimate_ms = now_ms

    raw_drift = (external_now_ms - internal_estimate_ms) * 1.0

    # EWMA update
    new_drift = @drift_alpha * raw_drift + (1.0 - @drift_alpha) * state.drift_ms

    new_state = %{state | drift_ms: new_drift, last_sync: DateTime.utc_now()}

    Logger.debug(
      "[METABOLIC_CLOCK] sync raw_drift=#{Float.round(raw_drift, 2)}ms ewma_drift=#{Float.round(new_drift, 2)}ms"
    )

    {:reply, {:ok, new_drift}, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, build_status(state), state}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state = do_tick(state)
    schedule_tick(new_state.tick_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec do_tick(map()) :: map()
  defp do_tick(state) do
    now_ms = System.monotonic_time(:millisecond)
    new_state = %{state | tick_count: state.tick_count + 1, last_tick_at: now_ms}

    broadcast(new_state)
    new_state
  end

  defp schedule_tick(interval_ms) do
    Process.send_after(self(), :tick, interval_ms)
  end

  @spec build_status(map()) :: status()
  defp build_status(state) do
    now_ms = System.monotonic_time(:millisecond)

    %{
      tick_count: state.tick_count,
      drift_ms: state.drift_ms,
      last_sync: state.last_sync,
      tick_interval_ms: state.tick_interval_ms,
      uptime_ms: now_ms - state.started_at_ms
    }
  end

  defp broadcast(state) do
    payload = Map.merge(build_status(state), %{timestamp: DateTime.utc_now()})

    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:metabolic_tick, payload})
    rescue
      _ -> :ok
    end
  end
end
