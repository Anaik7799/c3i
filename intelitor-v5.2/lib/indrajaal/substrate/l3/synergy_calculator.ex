defmodule Indrajaal.Substrate.L3.SynergyCalculator do
  @moduledoc """
  L3 Synergy Calculator — emergent value measurement for subsystem interactions.

  Pure module (no GenServer) that measures how combinations of subsystems
  create value exceeding the sum of their individual contributions.

  ## Theory
  For a set of subsystems S with individual values v_i and a combined value
  V(S), the synergy is:

    Synergy(S) = V(S) − Σ v_i

  Positive synergy means the combination produces more than its parts.
  Negative synergy indicates interference or overhead.

  ## Decomposition (Shapley-inspired)
  The `decompose/1` function computes each subsystem's *marginal contribution*
  to the synergy using a simplified Shapley-like approach:

    φ_i = V(S) − V(S ∖ {i})

  ## Emergent Value
  `emergent_value/1` returns the fraction of combined value that cannot be
  attributed to individual components:

    E = max(Synergy, 0) / V(S)   if V(S) > 0, else 0.0

  ## STAMP Constraints
  - SC-S3-001: S3 operational management constraints — ENFORCED
  - SC-S3-002: Synergy index computation — ENFORCED
  - SC-S3-003: Shapley-inspired decomposition — ENFORCED
  - SC-S3-004: Emergent value calculation — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type subsystem_id :: atom() | binary()

  @type subsystem_contribution :: %{
          subsystem: subsystem_id(),
          individual_value: float(),
          marginal_contribution: float()
        }

  @type synergy_input :: %{
          subsystems: [subsystem_id()],
          individual_values: %{subsystem_id() => float()},
          combined_value: float()
        }

  @type synergy_result :: %{
          synergy: float(),
          synergy_ratio: float(),
          positive: boolean()
        }

  @type decomposition :: %{
          combined_value: float(),
          sum_individual: float(),
          synergy: float(),
          contributions: [subsystem_contribution()]
        }

  # ── Public API ───────────────────────────────────────────────────────

  @doc """
  Computes the synergy for a given `synergy_input`.
  Returns `{:ok, synergy_result}` or `{:error, :no_subsystems}`.
  """
  @spec compute(synergy_input(), keyword()) ::
          {:ok, synergy_result()} | {:error, :no_subsystems}
  def compute(%{subsystems: []}, _opts), do: {:error, :no_subsystems}

  def compute(%{individual_values: iv, combined_value: cv, subsystems: ss}, _opts) do
    sum_individual = ss |> Enum.map(fn s -> Map.get(iv, s, 0.0) end) |> Enum.sum()

    synergy = cv - sum_individual

    synergy_ratio =
      if cv > 1.0e-12, do: synergy / cv, else: 0.0

    result = %{
      synergy: synergy,
      synergy_ratio: synergy_ratio,
      positive: synergy > 0.0
    }

    {:ok, result}
  end

  @doc """
  Decomposes the combined value into individual marginal contributions
  using a Shapley-inspired approach.

  Returns `{:ok, decomposition}` or `{:error, :no_subsystems}`.
  """
  @spec decompose(synergy_input()) :: {:ok, decomposition()} | {:error, :no_subsystems}
  def decompose(%{subsystems: []}), do: {:error, :no_subsystems}

  def decompose(%{subsystems: ss, individual_values: iv, combined_value: cv}) do
    sum_individual = ss |> Enum.map(fn s -> Map.get(iv, s, 0.0) end) |> Enum.sum()
    synergy = cv - sum_individual

    contributions =
      Enum.map(ss, fn subsystem ->
        own_value = Map.get(iv, subsystem, 0.0)
        # V(S) − V(S \ {i}) — coalition value without this subsystem
        sum_others =
          ss
          |> Enum.reject(fn s -> s == subsystem end)
          |> Enum.map(fn s -> Map.get(iv, s, 0.0) end)
          |> Enum.sum()

        # Marginal contribution to the combined value
        marginal = cv - sum_others

        %{
          subsystem: subsystem,
          individual_value: own_value,
          marginal_contribution: marginal
        }
      end)

    decomp = %{
      combined_value: cv,
      sum_individual: sum_individual,
      synergy: synergy,
      contributions: contributions
    }

    {:ok, decomp}
  end

  @doc """
  Returns the emergent value fraction ∈ [0.0, 1.0].
  Emergent value is the proportion of combined value that arises only from
  interaction (positive synergy / combined value).  Returns 0.0 if synergy
  is negative or combined value is zero.
  """
  @spec emergent_value(synergy_input()) :: float()
  def emergent_value(%{subsystems: []}), do: 0.0

  def emergent_value(%{individual_values: iv, combined_value: cv, subsystems: ss}) do
    sum_individual = ss |> Enum.map(fn s -> Map.get(iv, s, 0.0) end) |> Enum.sum()
    synergy = cv - sum_individual

    if cv > 1.0e-12 and synergy > 0.0 do
      min(synergy / cv, 1.0)
    else
      0.0
    end
  end
end
