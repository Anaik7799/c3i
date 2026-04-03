defmodule Indrajaal.Substrate.L0.EntropyWell do
  @moduledoc """
  ## Design Intent
  L0 substrate entropy well — pure functional accumulator that tracks the
  disorder (Shannon entropy) building up in the holon's substrate layers.

  In thermodynamics an entropy well is a local region of low entropy surrounded
  by a high-entropy environment. In the substrate layer the well captures
  entropy contributions from multiple sources (signal noise, configuration
  divergence, state drift) and maintains a running Shannon entropy score.

  Model:
    - Entropy is accumulated as weighted samples in [0.0, 1.0]
    - `accumulate/3` accepts a source label and a normalised value; the running
      Shannon entropy H is recomputed from the empirical distribution
    - When `entropy_level` crosses `critical_threshold` (default 0.85),
      `critical?/1` returns true
    - `drain/2` reduces entropy by a fixed `drain_rate` (models dissipation)
    - `entropy_level` is the current normalised H, clamped to [0.0, 1.0]

  Shannon entropy over source histogram:
    H = -Σ p_i · log2(p_i)   (normalised by log2(n_sources))

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-IKE-002: Entropy gating (blocked if > 0.2) — REFERENCE

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type source :: String.t()
  @type sample :: float()

  @type t :: %__MODULE__{
          entropy_level: float(),
          critical_threshold: float(),
          drain_rate: float(),
          source_totals: %{source() => float()},
          sample_count: non_neg_integer(),
          peak_entropy: float()
        }

  defstruct entropy_level: 0.0,
            critical_threshold: 0.85,
            drain_rate: 0.05,
            source_totals: %{},
            sample_count: 0,
            peak_entropy: 0.0

  @default_critical 0.85
  @default_drain 0.05

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new entropy well.

  Options:
    - `:critical_threshold` (float in (0.0, 1.0], default 0.85)
    - `:drain_rate`          (float in (0.0, 1.0], default 0.05)

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    critical = Keyword.get(opts, :critical_threshold, @default_critical)
    drain = Keyword.get(opts, :drain_rate, @default_drain)

    cond do
      not is_float(critical) or critical <= 0.0 or critical > 1.0 ->
        {:error, "critical_threshold must be a float in (0.0, 1.0]"}

      not is_float(drain) or drain <= 0.0 or drain > 1.0 ->
        {:error, "drain_rate must be a float in (0.0, 1.0]"}

      true ->
        {:ok, %__MODULE__{critical_threshold: critical, drain_rate: drain}}
    end
  end

  @doc """
  Accumulate an entropy sample from `source` with normalised value in [0.0, 1.0].

  Updates the source histogram and recomputes the Shannon entropy level.

  Returns `{:ok, updated_well}`.
  """
  @spec accumulate(t(), source(), sample()) ::
          {:ok, t()} | {:error, String.t()}
  def accumulate(%__MODULE__{} = well, source, value)
      when is_binary(source) and is_float(value) and
             value >= 0.0 and value <= 1.0 do
    new_totals = Map.update(well.source_totals, source, value, &(&1 + value))
    new_count = well.sample_count + 1
    new_h = compute_entropy(new_totals)
    new_peak = max(well.peak_entropy, new_h)

    updated = %{
      well
      | source_totals: new_totals,
        sample_count: new_count,
        entropy_level: new_h,
        peak_entropy: new_peak
    }

    {:ok, updated}
  end

  def accumulate(%__MODULE__{}, _source, _value),
    do: {:error, "source must be binary and value must be float in [0.0, 1.0]"}

  @doc """
  Drain entropy by one `drain_rate` step (models dissipation / active cooling).

  Returns `{:ok, updated_well}`.
  """
  @spec drain(t()) :: {:ok, t()}
  def drain(%__MODULE__{} = well) do
    new_h = clamp(well.entropy_level - well.drain_rate)
    {:ok, %{well | entropy_level: new_h}}
  end

  @doc """
  Returns true when entropy level has crossed the critical threshold.
  """
  @spec critical?(t()) :: boolean()
  def critical?(%__MODULE__{entropy_level: h, critical_threshold: t}), do: h >= t

  @doc """
  Returns a status map summarising the well state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = well) do
    %{
      entropy_level: Float.round(well.entropy_level, 4),
      critical_threshold: well.critical_threshold,
      drain_rate: well.drain_rate,
      sample_count: well.sample_count,
      source_count: map_size(well.source_totals),
      peak_entropy: Float.round(well.peak_entropy, 4),
      is_critical: critical?(well),
      sources: Map.keys(well.source_totals)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec compute_entropy(%{source() => float()}) :: float()
  defp compute_entropy(totals) when map_size(totals) == 0, do: 0.0

  defp compute_entropy(totals) do
    grand_total = Enum.reduce(totals, 0.0, fn {_k, v}, acc -> acc + v end)

    if grand_total <= 0.0 do
      0.0
    else
      n = map_size(totals)
      # Shannon entropy: H = -Σ p_i log2(p_i)
      raw_h =
        totals
        |> Enum.reduce(0.0, fn {_k, v}, acc ->
          p = v / grand_total
          if p > 0.0, do: acc - p * :math.log2(p), else: acc
        end)

      # Normalise by log2(n) so result is in [0.0, 1.0]
      max_h = if n > 1, do: :math.log2(n), else: 1.0
      clamp(raw_h / max_h)
    end
  end

  @spec clamp(float()) :: float()
  defp clamp(v), do: max(0.0, min(1.0, v))
end
