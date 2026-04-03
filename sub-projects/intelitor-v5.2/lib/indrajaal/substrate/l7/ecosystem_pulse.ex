defmodule Indrajaal.Substrate.L7.EcosystemPulse do
  @moduledoc """
  ## Design Intent
  L7 substrate Ecosystem Pulse — pure functional ecosystem health aggregator
  for the Indrajaal biomorphic mesh.

  Models the ecophysiology concept of ecosystem vitality indices: a set of
  independently measured health signals is aggregated into a single composite
  pulse score that reflects the overall wellbeing of the wider holon ecosystem.

  Each signal is:
    - A named float in [0.0, 1.0] representing a health dimension
    - Assigned a weight that reflects its importance in the aggregate
    - Combined via weighted arithmetic mean

  Pulse tiers:
    :thriving  (≥ 0.80) — healthy, expanding
    :stable    (≥ 0.55) — normal homeostasis
    :stressed  (≥ 0.30) — degraded, needs intervention
    :critical  (< 0.30) — emergency response required

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — pulse aggregates only external signals
  - SC-ECO-002: Ecosystem integrity — signals cannot be fabricated
  - SC-VER-044: 5-Order effects logged — pulse change triggers cascade analysis
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type pulse_tier :: :thriving | :stable | :stressed | :critical

  @type signal :: %{
          name: String.t(),
          value: float(),
          weight: float(),
          recorded_at: integer()
        }

  @type t :: %__MODULE__{
          signals: %{String.t() => signal()},
          pulse_score: float(),
          pulse_tier: pulse_tier(),
          snapshot_count: non_neg_integer(),
          created_at: integer()
        }

  defstruct signals: %{},
            pulse_score: 0.5,
            pulse_tier: :stable,
            snapshot_count: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    initial_signals = Keyword.get(opts, :initial_signals, [])

    cond do
      not is_list(initial_signals) ->
        {:error, "initial_signals must be a list of {name, value, weight} tuples"}

      true ->
        state = %__MODULE__{
          signals: %{},
          pulse_score: 0.5,
          pulse_tier: :stable,
          snapshot_count: 0,
          created_at: System.monotonic_time(:second)
        }

        {:ok, state}
    end
  end

  @doc """
  Record a health signal. `value` and `weight` must be in [0.0, 1.0].
  Recomputes the composite pulse after insertion.
  Returns `{:ok, updated_pulse}`.
  """
  @spec record_signal(t(), String.t(), float(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def record_signal(%__MODULE__{} = pulse, name, value, weight \\ 1.0)
      when is_binary(name) and is_float(value) and is_float(weight) do
    cond do
      value < 0.0 or value > 1.0 ->
        {:error, "value must be in [0.0, 1.0]"}

      weight < 0.0 or weight > 1.0 ->
        {:error, "weight must be in [0.0, 1.0]"}

      true ->
        sig = %{
          name: name,
          value: value,
          weight: weight,
          recorded_at: System.monotonic_time(:second)
        }

        updated_signals = Map.put(pulse.signals, name, sig)
        score = compute_score(updated_signals)

        updated = %{
          pulse
          | signals: updated_signals,
            pulse_score: score,
            pulse_tier: tier(score),
            snapshot_count: pulse.snapshot_count + 1
        }

        {:ok, updated}
    end
  end

  @doc """
  Remove a signal from the aggregator. Recomputes the pulse.
  """
  @spec remove_signal(t(), String.t()) :: t()
  def remove_signal(%__MODULE__{} = pulse, name) when is_binary(name) do
    updated_signals = Map.delete(pulse.signals, name)
    score = compute_score(updated_signals)
    %{pulse | signals: updated_signals, pulse_score: score, pulse_tier: tier(score)}
  end

  @doc """
  Return a summary of the ecosystem pulse state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = pulse) do
    %{
      pulse_score: pulse.pulse_score,
      pulse_tier: pulse.pulse_tier,
      signal_count: map_size(pulse.signals),
      snapshot_count: pulse.snapshot_count,
      signals: Enum.map(pulse.signals, fn {k, v} -> {k, v.value} end) |> Map.new()
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec compute_score(%{String.t() => signal()}) :: float()
  defp compute_score(signals) when map_size(signals) == 0, do: 0.5

  defp compute_score(signals) do
    {weighted_sum, total_weight} =
      Enum.reduce(signals, {0.0, 0.0}, fn {_k, sig}, {ws, tw} ->
        {ws + sig.value * sig.weight, tw + sig.weight}
      end)

    if total_weight > 0.0 do
      Float.round(weighted_sum / total_weight, 4)
    else
      0.5
    end
  end

  @spec tier(float()) :: pulse_tier()
  defp tier(s) when s >= 0.80, do: :thriving
  defp tier(s) when s >= 0.55, do: :stable
  defp tier(s) when s >= 0.30, do: :stressed
  defp tier(_s), do: :critical
end
