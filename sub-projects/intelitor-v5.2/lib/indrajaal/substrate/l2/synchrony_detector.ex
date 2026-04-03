defmodule Indrajaal.Substrate.L2.SynchronyDetector do
  @moduledoc """
  L2 Synchrony Detector — phase alignment measurement between subsystems.

  Pure module (no process) that computes cross-correlation and phase
  difference between two time-series signals.  Used by the VSM System 2
  coordination layer to detect how well subsystems are operating in phase
  with the reference rhythm produced by RhythmGenerator.

  ## Algorithms
  - **Phase difference**: circular mean of instantaneous phase angles derived
    from zero-crossing analysis of each signal.
  - **Cross-correlation**: normalised Pearson cross-correlation at lag 0.
  - **Coherence score**: combined measure — high when both phase-diff is
    small and correlation is high.

  ## Definitions
  - Signals are `[float()]` lists of equal length.
  - Phase difference is returned in radians `[-π, π]`.
  - Coherence score ∈ [0.0, 1.0] — 1.0 means perfect synchrony.

  ## STAMP Constraints
  - SC-S2-001: S2 coordination subsystem constraints — ENFORCED
  - SC-S2-002: Cross-correlation computation mandatory — ENFORCED
  - SC-S2-003: Phase alignment measurement — ENFORCED
  - SC-S2-004: Coherence score output — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  import :math, only: [pi: 0, sqrt: 1, atan2: 2, cos: 1, sin: 1]

  @type signal :: [float()]
  @type sync_result :: %{
          phase_diff_rad: float(),
          correlation: float(),
          coherence: float(),
          in_phase: boolean()
        }

  @phase_threshold_rad 0.5

  # ── Public API ───────────────────────────────────────────────────────

  @doc """
  Measures synchrony between two signals of equal length.
  Returns a map with phase_diff_rad, correlation, coherence, and in_phase flag.
  Returns `{:error, :length_mismatch}` when lists have different lengths.
  Returns `{:error, :insufficient_samples}` when fewer than 3 samples provided.
  """
  @spec measure_sync(signal(), signal()) ::
          {:ok, sync_result()} | {:error, :length_mismatch | :insufficient_samples}
  def measure_sync(signal_a, signal_b)
      when is_list(signal_a) and is_list(signal_b) do
    len_a = length(signal_a)
    len_b = length(signal_b)

    cond do
      len_a != len_b ->
        {:error, :length_mismatch}

      len_a < 3 ->
        {:error, :insufficient_samples}

      true ->
        diff = phase_diff(signal_a, signal_b)
        corr = normalised_correlation(signal_a, signal_b)
        coh = coherence_from(diff, corr)

        result = %{
          phase_diff_rad: diff,
          correlation: corr,
          coherence: coh,
          in_phase: abs(diff) < @phase_threshold_rad
        }

        {:ok, result}
    end
  end

  @doc """
  Returns the phase difference in radians between two signals.
  Uses circular mean of instantaneous phase estimates derived from
  zero-crossing analysis.  Range: [-π, π].
  """
  @spec phase_diff(signal(), signal()) :: float()
  def phase_diff(signal_a, signal_b) do
    phases_a = instantaneous_phases(signal_a)
    phases_b = instantaneous_phases(signal_b)

    diffs =
      Enum.zip(phases_a, phases_b)
      |> Enum.map(fn {pa, pb} -> wrap_angle(pa - pb) end)

    circular_mean(diffs)
  end

  @doc """
  Returns a coherence score ∈ [0.0, 1.0] given a pre-computed list of
  `{phase_diff_rad, correlation}` pairs across a window.  High coherence
  requires both small phase difference and high positive correlation.
  """
  @spec coherence_score([{float(), float()}]) :: float()
  def coherence_score(pairs) when is_list(pairs) and pairs != [] do
    scores =
      Enum.map(pairs, fn {diff, corr} ->
        coherence_from(diff, corr)
      end)

    Enum.sum(scores) / length(scores)
  end

  def coherence_score([]), do: 0.0

  # ── Private ──────────────────────────────────────────────────────────

  @spec instantaneous_phases(signal()) :: [float()]
  defp instantaneous_phases(signal) do
    # Estimate phase via zero-crossing interpolation.
    # Each sample's phase is its normalised position within the current half-cycle.
    {phases, _acc} =
      signal
      |> Enum.with_index()
      |> Enum.map_reduce({0, 0.0}, fn {v, _i}, {prev_sign, accum_phase} ->
        curr_sign = if v >= 0.0, do: 1, else: -1
        delta = if curr_sign != prev_sign, do: pi(), else: pi() / max(length(signal), 1)
        new_phase = accum_phase + delta
        {wrap_angle(new_phase), {curr_sign, new_phase}}
      end)

    phases
  end

  @spec normalised_correlation(signal(), signal()) :: float()
  defp normalised_correlation(a, b) do
    mean_a = mean(a)
    mean_b = mean(b)
    centred_a = Enum.map(a, &(&1 - mean_a))
    centred_b = Enum.map(b, &(&1 - mean_b))

    dot = centred_a |> Enum.zip(centred_b) |> Enum.reduce(0.0, fn {x, y}, s -> s + x * y end)
    norm_a = centred_a |> Enum.reduce(0.0, fn x, s -> s + x * x end) |> sqrt()
    norm_b = centred_b |> Enum.reduce(0.0, fn x, s -> s + x * x end) |> sqrt()

    denom = norm_a * norm_b

    if denom < 1.0e-12, do: 0.0, else: dot / denom
  end

  @spec coherence_from(float(), float()) :: float()
  defp coherence_from(phase_diff, corr) do
    # Phase component: 1 at diff=0, 0 at diff=π
    phase_component = (cos(phase_diff) + 1.0) / 2.0
    # Correlation component: map [-1,1] → [0,1]
    corr_component = (corr + 1.0) / 2.0

    # Geometric mean to require both components to be high
    sqrt(max(phase_component * corr_component, 0.0))
  end

  @spec circular_mean([float()]) :: float()
  defp circular_mean([]), do: 0.0

  defp circular_mean(angles) do
    sin_sum = Enum.reduce(angles, 0.0, fn a, s -> s + sin(a) end)
    cos_sum = Enum.reduce(angles, 0.0, fn a, s -> s + cos(a) end)
    atan2(sin_sum, cos_sum)
  end

  @spec wrap_angle(float()) :: float()
  defp wrap_angle(angle) do
    pi_val = pi()
    two_pi = 2.0 * pi_val

    cond do
      angle > pi_val -> angle - two_pi
      angle < -pi_val -> angle + two_pi
      true -> angle
    end
  end

  @spec mean([float()]) :: float()
  defp mean([]), do: 0.0
  defp mean(xs), do: Enum.sum(xs) / length(xs)
end
