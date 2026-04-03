defmodule Indrajaal.Substrate.L4.WeakSignalAmplifier do
  @moduledoc """
  ## Design Intent
  L4 substrate weak signal amplifier — pure functional faint signal detection
  module for identifying low-magnitude but strategically significant signals.

  Biological metaphor: Hair-cell amplification in the cochlea. Outer hair
  cells actively amplify the basilar membrane's response to faint sounds,
  enabling the inner ear to detect signals well below the noise floor. This
  module amplifies weak environmental signals by accumulating corroborating
  evidence from multiple low-confidence observations.

  Algorithm:
    - Each signal is characterised by `{key, strength, confidence}`.
    - `ingest/2` adds an observation; strength and confidence are clamped to [0.0, 1.0].
    - Signals are accumulated in an evidence map; weak signals (strength < `noise_floor`)
      have their evidence boosted by `amplification_factor`.
    - `amplified_signals/1` returns signals whose accumulated evidence crosses
      `detection_threshold`.
    - `reset_key/2` clears evidence for a specific signal key.

  ## STAMP Constraints
  - SC-S4-001: Environmental scanning at L4 boundary — ENFORCED
  - SC-S4-002: Trend detection from metabolic telemetry — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type signal_key :: atom() | String.t()

  @type observation :: %{
          key: signal_key(),
          strength: float(),
          confidence: float()
        }

  @type evidence_entry :: %{
          accumulated: float(),
          observation_count: non_neg_integer(),
          last_strength: float()
        }

  @type t :: %__MODULE__{
          evidence: %{signal_key() => evidence_entry()},
          noise_floor: float(),
          amplification_factor: float(),
          detection_threshold: float(),
          ingest_count: non_neg_integer()
        }

  defstruct evidence: %{},
            noise_floor: 0.15,
            amplification_factor: 3.0,
            detection_threshold: 1.0,
            ingest_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new WeakSignalAmplifier.

  Options:
    - `:noise_floor`           (float in (0,1), default 0.15) — below this strength, amplify
    - `:amplification_factor`  (float > 1.0, default 3.0) — boost for weak signals
    - `:detection_threshold`   (float > 0.0, default 1.0) — accumulated evidence for detection

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    noise_floor = Keyword.get(opts, :noise_floor, 0.15)
    amplification_factor = Keyword.get(opts, :amplification_factor, 3.0)
    detection_threshold = Keyword.get(opts, :detection_threshold, 1.0)

    cond do
      not is_float(noise_floor) or noise_floor <= 0.0 or noise_floor >= 1.0 ->
        {:error, "noise_floor must be in (0.0, 1.0)"}

      not is_float(amplification_factor) or amplification_factor <= 1.0 ->
        {:error, "amplification_factor must be > 1.0"}

      not is_float(detection_threshold) or detection_threshold <= 0.0 ->
        {:error, "detection_threshold must be > 0.0"}

      true ->
        {:ok,
         %__MODULE__{
           noise_floor: noise_floor,
           amplification_factor: amplification_factor,
           detection_threshold: detection_threshold
         }}
    end
  end

  @doc """
  Ingest one observation into the evidence accumulator.

  Strength and confidence are clamped to [0.0, 1.0]. Effective evidence
  added = `strength × confidence × (amplification_factor if weak else 1.0)`.

  Returns `{:ok, updated}`.
  """
  @spec ingest(t(), observation()) :: {:ok, t()}
  def ingest(%__MODULE__{} = amp, %{key: key, strength: strength, confidence: confidence}) do
    s = clamp(strength * 1.0, 0.0, 1.0)
    c = clamp(confidence * 1.0, 0.0, 1.0)

    multiplier = if s < amp.noise_floor, do: amp.amplification_factor, else: 1.0
    added_evidence = s * c * multiplier

    prior =
      Map.get(amp.evidence, key, %{accumulated: 0.0, observation_count: 0, last_strength: 0.0})

    new_entry = %{
      accumulated: prior.accumulated + added_evidence,
      observation_count: prior.observation_count + 1,
      last_strength: s
    }

    updated = %{
      amp
      | evidence: Map.put(amp.evidence, key, new_entry),
        ingest_count: amp.ingest_count + 1
    }

    {:ok, updated}
  end

  def ingest(%__MODULE__{} = amp, _obs), do: {:ok, amp}

  @doc """
  Returns the list of signal keys whose accumulated evidence has crossed
  `detection_threshold`, sorted by accumulated evidence descending.
  """
  @spec amplified_signals(t()) :: [
          %{key: signal_key(), evidence: float(), observations: non_neg_integer()}
        ]
  def amplified_signals(%__MODULE__{} = amp) do
    amp.evidence
    |> Enum.filter(fn {_k, e} -> e.accumulated >= amp.detection_threshold end)
    |> Enum.map(fn {k, e} ->
      %{key: k, evidence: e.accumulated, observations: e.observation_count}
    end)
    |> Enum.sort_by(& &1.evidence, :desc)
  end

  @doc """
  Clear accumulated evidence for a specific signal key.

  Returns `{:ok, updated}`.
  """
  @spec reset_key(t(), signal_key()) :: {:ok, t()}
  def reset_key(%__MODULE__{} = amp, key) do
    {:ok, %{amp | evidence: Map.delete(amp.evidence, key)}}
  end

  @doc """
  Returns a summary status map.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = amp) do
    detected = amplified_signals(amp)

    %{
      tracked_signals: map_size(amp.evidence),
      detected_signals: length(detected),
      ingest_count: amp.ingest_count,
      noise_floor: amp.noise_floor,
      amplification_factor: amp.amplification_factor,
      detection_threshold: amp.detection_threshold,
      top_signal: List.first(detected)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
