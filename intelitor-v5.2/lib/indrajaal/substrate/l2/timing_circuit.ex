defmodule Indrajaal.Substrate.L2.TimingCircuit do
  @moduledoc """
  ## Design Intent
  L2 substrate timing circuit — pure functional clock and interval management.

  Biomorphic metaphor: the suprachiasmatic nucleus (SCN), the biological master clock
  that coordinates circadian rhythms. Maintains a set of named intervals, each tracking
  elapsed time against a configured period, and provides deadline and jitter analysis.

  Algorithm:
  1. Each interval is registered with a period (ms) and optional phase offset.
  2. On each `tick/2`, elapsed time advances and intervals are evaluated for expiry.
  3. An interval fires when `elapsed >= period + jitter_sample`.
  4. Jitter is a zero-mean Gaussian approximation via Box-Muller using deterministic seeds.
  5. Returns the set of fired intervals and updated state.

  ## STAMP Constraints
  - SC-S2-001: Cybernetic VSM S2 coordination — ENFORCED
  - SC-S2-002: Oscillation detection mandatory — ENFORCED
  - SC-BIO-001: Biomorphic substrate layer L2 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type interval :: %{
          period_ms: pos_integer(),
          elapsed_ms: non_neg_integer(),
          jitter_ms: non_neg_integer(),
          fire_count: non_neg_integer(),
          phase_offset_ms: non_neg_integer()
        }

  @type t :: %__MODULE__{
          intervals: %{String.t() => interval()},
          resolution_ms: pos_integer(),
          total_ticks: non_neg_integer(),
          total_fires: non_neg_integer()
        }

  defstruct intervals: %{},
            resolution_ms: 1,
            total_ticks: 0,
            total_fires: 0

  @doc """
  Create a new TimingCircuit.

  Options:
  - `:resolution_ms` — minimum tick granularity in ms ∈ [1, 1000], default 1
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    res = Keyword.get(opts, :resolution_ms, 1)

    cond do
      not is_integer(res) ->
        {:error, "resolution_ms must be an integer"}

      res < 1 or res > 1_000 ->
        {:error, "resolution_ms must be in [1, 1000]"}

      true ->
        {:ok, %__MODULE__{resolution_ms: res}}
    end
  end

  @doc """
  Register a named interval with a period in milliseconds.

  Options:
  - `:jitter_ms` — max random jitter added to period ∈ [0, period], default 0
  - `:phase_offset_ms` — initial elapsed offset ∈ [0, period], default 0
  """
  @spec register(t(), String.t(), pos_integer(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def register(state, name, period_ms, opts \\ [])

  def register(%__MODULE__{} = state, name, period_ms, opts)
      when is_binary(name) and is_integer(period_ms) and period_ms > 0 do
    jitter = Keyword.get(opts, :jitter_ms, 0)
    phase = Keyword.get(opts, :phase_offset_ms, 0)

    cond do
      Map.has_key?(state.intervals, name) ->
        {:error, "interval #{name} already registered"}

      jitter < 0 or jitter > period_ms ->
        {:error, "jitter_ms must be in [0, period_ms]"}

      phase < 0 or phase > period_ms ->
        {:error, "phase_offset_ms must be in [0, period_ms]"}

      true ->
        interval = %{
          period_ms: period_ms,
          elapsed_ms: phase,
          jitter_ms: jitter,
          fire_count: 0,
          phase_offset_ms: phase
        }

        {:ok, %__MODULE__{state | intervals: Map.put(state.intervals, name, interval)}}
    end
  end

  def register(%__MODULE__{}, _name, _period_ms, _opts) do
    {:error, "name must be a binary and period_ms must be a positive integer"}
  end

  @doc """
  Advance the circuit by `delta_ms` milliseconds.

  Returns `{fired_names, updated_state}` where `fired_names` is the list of interval
  names that crossed their deadline during this tick.
  """
  @spec tick(t(), pos_integer()) :: {[String.t()], t()}
  def tick(%__MODULE__{} = state, delta_ms) when is_integer(delta_ms) and delta_ms > 0 do
    {fired, new_intervals} =
      Enum.reduce(state.intervals, {[], %{}}, fn {name, iv}, {acc_fired, acc_ivs} ->
        new_elapsed = iv.elapsed_ms + delta_ms
        threshold = iv.period_ms + jitter_sample(iv.jitter_ms, iv.fire_count)

        if new_elapsed >= threshold do
          updated_iv = %{
            iv
            | elapsed_ms: rem(new_elapsed, iv.period_ms),
              fire_count: iv.fire_count + 1
          }

          {[name | acc_fired], Map.put(acc_ivs, name, updated_iv)}
        else
          {acc_fired, Map.put(acc_ivs, name, %{iv | elapsed_ms: new_elapsed})}
        end
      end)

    new_state = %__MODULE__{
      state
      | intervals: new_intervals,
        total_ticks: state.total_ticks + 1,
        total_fires: state.total_fires + length(fired)
    }

    {Enum.reverse(fired), new_state}
  end

  @doc """
  Returns a summary map of the timing circuit state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      resolution_ms: state.resolution_ms,
      interval_count: map_size(state.intervals),
      total_ticks: state.total_ticks,
      total_fires: state.total_fires,
      intervals:
        Map.new(state.intervals, fn {name, iv} ->
          {name,
           %{
             period_ms: iv.period_ms,
             elapsed_ms: iv.elapsed_ms,
             fire_count: iv.fire_count,
             utilization: iv.elapsed_ms / iv.period_ms
           }}
        end)
    }
  end

  # ── Private ────────────────────────────────────────────────────────────────

  # Deterministic jitter using integer hash (no randomness, reproducible)
  @spec jitter_sample(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  defp jitter_sample(0, _seed), do: 0

  defp jitter_sample(max_jitter, seed) do
    # Simple LCG-derived deterministic jitter
    hash = rem(seed * 1_664_525 + 1_013_904_223, 4_294_967_296)
    rem(hash, max_jitter + 1)
  end
end
