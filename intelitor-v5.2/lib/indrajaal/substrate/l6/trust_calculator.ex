defmodule Indrajaal.Substrate.L6.TrustCalculator do
  @moduledoc """
  ## Design Intent
  L6 substrate Trust Calculator — pure functional multi-factor trust computation
  for the Indrajaal inter-holon federation layer.

  Models mutualistic symbiosis assessment: before a holon deepens cooperation
  with a peer, it evaluates trust across four orthogonal factors, weighted by
  their relative importance in the federation context.

  Trust factors and default weights:
    1. :reputation   (w = 0.35) — historical performance score [0.0, 1.0]
    2. :attestation  (w = 0.30) — recency and validity of identity proof [0.0, 1.0]
    3. :capability   (w = 0.20) — overlap between offered and required capabilities
    4. :connectivity (w = 0.15) — link quality / latency score [0.0, 1.0]

  Composite trust = Σ(weight_i × factor_i), clamped to [0.0, 1.0].

  Trust tiers:
    :full       (≥ 0.80) — unrestricted federation
    :guarded    (≥ 0.55) — limited data sharing
    :restricted (≥ 0.30) — read-only, no write delegation
    :blocked    (< 0.30) — no interaction permitted

  ## STAMP Constraints
  - SC-FED-006: Attestation Ed25519-verified — attestation factor sourced from FFI
  - SC-DIST-001: FQUN tracked for all peers — identity is a prerequisite
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type trust_tier :: :full | :guarded | :restricted | :blocked

  @type factor_weights :: %{
          reputation: float(),
          attestation: float(),
          capability: float(),
          connectivity: float()
        }

  @type factor_scores :: %{
          reputation: float(),
          attestation: float(),
          capability: float(),
          connectivity: float()
        }

  @type trust_result :: %{
          peer_id: String.t(),
          composite_score: float(),
          trust_tier: trust_tier(),
          factor_scores: factor_scores(),
          factor_weights: factor_weights()
        }

  @type t :: %__MODULE__{
          weights: factor_weights(),
          computation_count: non_neg_integer(),
          created_at: integer()
        }

  @default_weights %{
    reputation: 0.35,
    attestation: 0.30,
    capability: 0.20,
    connectivity: 0.15
  }

  defstruct weights: @default_weights,
            computation_count: 0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    weights = Keyword.get(opts, :weights, @default_weights)

    cond do
      not is_map(weights) ->
        {:error, "weights must be a map"}

      abs((Map.values(weights) |> Enum.sum()) - 1.0) > 0.001 ->
        {:error, "weights must sum to 1.0 (got #{Map.values(weights) |> Enum.sum()})"}

      true ->
        state = %__MODULE__{
          weights: Map.merge(@default_weights, weights),
          computation_count: 0,
          created_at: System.monotonic_time(:second)
        }

        {:ok, state}
    end
  end

  @doc """
  Compute the composite trust score for a peer given raw factor scores.
  All factor scores must be in [0.0, 1.0].
  Returns `{:ok, updated_calculator, trust_result}`.
  """
  @spec compute(t(), String.t(), factor_scores()) ::
          {:ok, t(), trust_result()} | {:error, String.t()}
  def compute(%__MODULE__{} = calc, peer_id, factors)
      when is_binary(peer_id) and is_map(factors) do
    required = [:reputation, :attestation, :capability, :connectivity]
    missing = Enum.reject(required, &Map.has_key?(factors, &1))

    cond do
      missing != [] ->
        {:error, "missing factor keys: #{inspect(missing)}"}

      true ->
        clamped = Map.new(factors, fn {k, v} -> {k, clamp(v)} end)

        composite =
          Enum.reduce(required, 0.0, fn factor, acc ->
            acc + Map.get(calc.weights, factor, 0.0) * Map.get(clamped, factor, 0.0)
          end)

        composite = Float.round(clamp(composite), 4)

        result = %{
          peer_id: peer_id,
          composite_score: composite,
          trust_tier: tier(composite),
          factor_scores: clamped,
          factor_weights: calc.weights
        }

        updated = %{calc | computation_count: calc.computation_count + 1}
        {:ok, updated, result}
    end
  end

  @doc """
  Determine the trust tier for a raw composite score.
  """
  @spec classify(float()) :: trust_tier()
  def classify(score) when is_float(score), do: tier(clamp(score))

  @doc """
  Return a summary of calculator configuration and usage.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = calc) do
    %{
      weights: calc.weights,
      computation_count: calc.computation_count,
      weight_sum: calc.weights |> Map.values() |> Enum.sum() |> Float.round(4)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec tier(float()) :: trust_tier()
  defp tier(score) when score >= 0.80, do: :full
  defp tier(score) when score >= 0.55, do: :guarded
  defp tier(score) when score >= 0.30, do: :restricted
  defp tier(_score), do: :blocked

  @spec clamp(float()) :: float()
  defp clamp(v), do: max(0.0, min(1.0, v))
end
