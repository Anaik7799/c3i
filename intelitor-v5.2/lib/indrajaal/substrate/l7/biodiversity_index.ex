defmodule Indrajaal.Substrate.L7.BiodiversityIndex do
  @moduledoc """
  ## Design Intent
  L7 substrate biodiversity index — pure functional module that measures
  ecological diversity using standard diversity indices.

  Biological metaphor: species richness and evenness in an ecosystem.
  A high-diversity system is more resilient — loss of one species/component
  does not destabilise the whole. Homogeneous systems are fragile.

  Algorithms implemented:
    - Shannon-Wiener entropy: H' = -Σ (pᵢ × ln pᵢ)  where pᵢ = nᵢ/N.
    - Simpson's index: D = 1 - Σ pᵢ²  (probability that two random
      individuals belong to different species).
    - Pielou's evenness: J' = H' / ln(S)  where S = species richness.
    - Margalef richness: d = (S - 1) / ln(N).
    - Berger-Parker dominance: d_BP = n_max / N.

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED
  - SC-ECO-003: Ecosystem health monitoring — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type abundance_map :: %{String.t() => non_neg_integer()}

  @type diversity_metrics :: %{
          species_richness: non_neg_integer(),
          total_count: non_neg_integer(),
          shannon_entropy: float(),
          simpson_index: float(),
          pielou_evenness: float() | nil,
          margalef_richness: float() | nil,
          berger_parker_dominance: float()
        }

  @type t :: %__MODULE__{
          species: abundance_map(),
          computation_count: non_neg_integer()
        }

  defstruct species: %{},
            computation_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new BiodiversityIndex.

  Options:
    - `:species` — initial abundance map `%{name => count}` (default `%{}`).
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    species = Keyword.get(opts, :species, %{})

    cond do
      not is_map(species) ->
        {:error, "species must be a map"}

      not all_counts_valid?(species) ->
        {:error, "all species counts must be non-negative integers"}

      true ->
        {:ok, %__MODULE__{species: species}}
    end
  end

  @doc "Record an observation of a species (increment its count by 1)."
  @spec observe(t(), String.t()) :: t()
  def observe(%__MODULE__{} = state, species_name) when is_binary(species_name) do
    updated = Map.update(state.species, species_name, 1, &(&1 + 1))
    %{state | species: updated}
  end

  @doc "Set the abundance count for a named species."
  @spec set_abundance(t(), String.t(), non_neg_integer()) ::
          {:ok, t()} | {:error, String.t()}
  def set_abundance(%__MODULE__{} = state, name, count)
      when is_binary(name) and is_integer(count) and count >= 0 do
    {:ok, %{state | species: Map.put(state.species, name, count)}}
  end

  def set_abundance(%__MODULE__{}, _name, _count),
    do: {:error, "name must be a string and count a non-negative integer"}

  @doc """
  Compute all diversity metrics from the current species abundances.

  Returns `{:ok, diversity_metrics}` or `{:error, :no_data}` when empty.
  """
  @spec compute(t()) :: {:ok, diversity_metrics()} | {:error, :no_data}
  def compute(%__MODULE__{species: sp}) when map_size(sp) == 0, do: {:error, :no_data}

  def compute(%__MODULE__{} = state) do
    counts = state.species |> Map.values() |> Enum.filter(&(&1 > 0))
    total = Enum.sum(counts)
    s = length(counts)

    if total == 0 do
      {:error, :no_data}
    else
      proportions = Enum.map(counts, fn n -> n / total end)

      shannon =
        Enum.reduce(proportions, 0.0, fn p, acc ->
          if p > 0.0, do: acc - p * :math.log(p), else: acc
        end)

      simpson =
        1.0 - Enum.reduce(proportions, 0.0, fn p, acc -> acc + p * p end)

      evenness =
        if s > 1 do
          max_h = :math.log(s)
          if max_h > 0.0, do: shannon / max_h, else: nil
        else
          nil
        end

      margalef =
        if total > 1 do
          (s - 1) / :math.log(total)
        else
          nil
        end

      n_max = Enum.max(counts)
      bp_dominance = n_max / total

      {:ok,
       %{
         species_richness: s,
         total_count: total,
         shannon_entropy: Float.round(shannon, 4),
         simpson_index: Float.round(simpson, 4),
         pielou_evenness: if(evenness, do: Float.round(evenness, 4)),
         margalef_richness: if(margalef, do: Float.round(margalef, 4)),
         berger_parker_dominance: Float.round(bp_dominance, 4)
       }}
    end
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    base = %{
      species_count: map_size(state.species),
      total_observations: state.species |> Map.values() |> Enum.sum(),
      computation_count: state.computation_count
    }

    case compute(state) do
      {:ok, metrics} ->
        Map.merge(base, %{
          shannon_entropy: metrics.shannon_entropy,
          simpson_index: metrics.simpson_index
        })

      {:error, _} ->
        Map.put(base, :shannon_entropy, nil)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec all_counts_valid?(map()) :: boolean()
  defp all_counts_valid?(sp) do
    Enum.all?(sp, fn
      {k, v} when is_binary(k) and is_integer(v) -> v >= 0
      _ -> false
    end)
  end
end
