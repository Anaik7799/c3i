defmodule Indrajaal.Substrate.L0.QuantumFoam do
  @moduledoc """
  ## Design Intent
  L0 substrate quantum foam — pure functional superposition pool for holding
  multiple candidate states simultaneously until one is selected and collapsed.

  In quantum mechanics, vacuum fluctuations at the Planck scale produce a
  "foam" of virtual particles — configurations that exist in superposition until
  observation forces collapse to a definite state. In the substrate layer this
  provides the holon with a pool of pending candidate configurations (proposals,
  mutations, hypotheses) that can be evaluated before any single one is committed.

  Model:
    - Up to `max_candidates` entries may coexist in superposition
    - Each candidate carries a `weight` in [0.0, 1.0] representing relative
      probability amplitude
    - `collapse/2` selects the candidate with the highest weight (or by id),
      discards the rest, and returns it as the resolved state
    - `decohere/1` clears all candidates (vacuum → ground state)
    - Weights are normalised so they sum to 1.0 after each addition

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-HASH-001: Deterministic computation — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type candidate_id :: String.t()
  @type weight :: float()

  @type candidate :: %{
          id: candidate_id(),
          payload: term(),
          weight: weight()
        }

  @type t :: %__MODULE__{
          candidates: [candidate()],
          max_candidates: pos_integer(),
          collapsed: candidate() | nil,
          decoherence_count: non_neg_integer()
        }

  defstruct candidates: [],
            max_candidates: 8,
            collapsed: nil,
            decoherence_count: 0

  @weight_min 0.0
  @weight_max 1.0
  @default_max_candidates 8

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new quantum foam pool.

  Options:
    - `:max_candidates` (pos_integer, default 8) — superposition limit

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    max_candidates = Keyword.get(opts, :max_candidates, @default_max_candidates)

    cond do
      not is_integer(max_candidates) or max_candidates < 1 ->
        {:error, "max_candidates must be a positive integer"}

      true ->
        {:ok, %__MODULE__{max_candidates: max_candidates}}
    end
  end

  @doc """
  Add a candidate to the superposition pool.

  `weight` must be in (0.0, 1.0]. Weights are re-normalised after insertion.

  Returns `{:ok, updated_foam}` or `{:error, reason}`.
  """
  @spec superpose(t(), candidate_id(), term(), weight()) ::
          {:ok, t()} | {:error, atom()}
  def superpose(foam, id, payload, weight \\ 0.5)

  def superpose(%__MODULE__{} = foam, id, payload, weight)
      when is_binary(id) and is_float(weight) and
             weight > @weight_min and weight <= @weight_max do
    cond do
      length(foam.candidates) >= foam.max_candidates ->
        {:error, :superposition_full}

      Enum.any?(foam.candidates, &(&1.id == id)) ->
        {:error, :duplicate_id}

      true ->
        entry = %{id: id, payload: payload, weight: weight}
        updated = normalize_weights([entry | foam.candidates])
        {:ok, %{foam | candidates: updated, collapsed: nil}}
    end
  end

  def superpose(%__MODULE__{}, _id, _payload, _weight),
    do: {:error, :invalid_args}

  @doc """
  Collapse the superposition by selecting the highest-weight candidate.

  If `preferred_id` is given and exists, that candidate wins regardless of weight.

  Returns `{:ok, candidate, updated_foam}` or `{:error, :empty}`.
  """
  @spec collapse(t(), candidate_id() | nil) ::
          {:ok, candidate(), t()} | {:error, :empty}
  def collapse(foam, preferred_id \\ nil)

  def collapse(%__MODULE__{candidates: []}, _preferred_id),
    do: {:error, :empty}

  def collapse(%__MODULE__{} = foam, preferred_id) do
    chosen =
      if is_binary(preferred_id) do
        Enum.find(foam.candidates, &(&1.id == preferred_id)) ||
          Enum.max_by(foam.candidates, & &1.weight)
      else
        Enum.max_by(foam.candidates, & &1.weight)
      end

    updated = %{foam | candidates: [], collapsed: chosen}
    {:ok, chosen, updated}
  end

  @doc """
  Decohere (clear) all candidates without committing any.

  Returns `{:ok, updated_foam}`.
  """
  @spec decohere(t()) :: {:ok, t()}
  def decohere(%__MODULE__{} = foam) do
    {:ok,
     %{
       foam
       | candidates: [],
         collapsed: nil,
         decoherence_count: foam.decoherence_count + 1
     }}
  end

  @doc """
  Returns a status map summarising the foam state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = foam) do
    %{
      candidate_count: length(foam.candidates),
      max_candidates: foam.max_candidates,
      collapsed_id: if(foam.collapsed, do: foam.collapsed.id, else: nil),
      decoherence_count: foam.decoherence_count,
      capacity_pct: Float.round(length(foam.candidates) / foam.max_candidates * 100.0, 1),
      weight_distribution: Enum.map(foam.candidates, &{&1.id, Float.round(&1.weight, 4)})
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec normalize_weights([candidate()]) :: [candidate()]
  defp normalize_weights(candidates) do
    total = Enum.reduce(candidates, 0.0, fn c, acc -> acc + c.weight end)

    if total > 0.0 do
      Enum.map(candidates, fn c -> %{c | weight: c.weight / total} end)
    else
      candidates
    end
  end
end
