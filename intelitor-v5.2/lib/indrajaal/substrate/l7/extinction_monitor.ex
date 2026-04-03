defmodule Indrajaal.Substrate.L7.ExtinctionMonitor do
  @moduledoc """
  L7 Extinction Monitor — Species/capability extinction tracker for ecosystem resilience.

  Tracks population health of capabilities, services, and knowledge domains across
  the ecosystem. Applies a minimum viable population (MVP) model: entities whose
  population falls below MVP are flagged as endangered; zero means extinct.

  Algorithm:
  - Health ratio: current_population / initial_population
  - Endangered threshold: health_ratio < 0.20
  - Diversity index: Shannon entropy H = -Σ p_i * log(p_i) over populations
  - Ecosystem resilience: normalised diversity score

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem external boundaries — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @endangered_ratio 0.20
  @extinct_ratio 0.0
  @ln2 0.693_147_180_559_945_3

  @type entity_status :: :healthy | :endangered | :extinct
  @type entity :: %{
          name: String.t(),
          population: non_neg_integer(),
          initial: pos_integer(),
          status: entity_status()
        }

  @type t :: %__MODULE__{
          ecosystem: String.t(),
          entities: [entity()],
          diversity_index: float(),
          resilience: float(),
          extinct_count: non_neg_integer()
        }

  defstruct ecosystem: "default",
            entities: [],
            diversity_index: 0.0,
            resilience: 1.0,
            extinct_count: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    ecosystem = Keyword.get(opts, :ecosystem, "default")

    cond do
      not is_binary(ecosystem) ->
        {:error, "ecosystem must be a string"}

      true ->
        {:ok, %__MODULE__{ecosystem: ecosystem}}
    end
  end

  @spec register(t(), String.t(), pos_integer()) :: {:ok, t()} | {:error, String.t()}
  def register(%__MODULE__{} = state, name, initial_population)
      when is_binary(name) and is_integer(initial_population) do
    cond do
      initial_population < 1 ->
        {:error, "initial_population must be at least 1"}

      true ->
        entry = %{
          name: name,
          population: initial_population,
          initial: initial_population,
          status: :healthy
        }

        existing = Enum.reject(state.entities, &(&1.name == name))
        updated = %{state | entities: existing ++ [entry]}
        {:ok, recompute(updated)}
    end
  end

  @spec update_population(t(), String.t(), non_neg_integer()) ::
          {:ok, t()} | {:error, String.t()}
  def update_population(%__MODULE__{} = state, name, population)
      when is_binary(name) and is_integer(population) do
    cond do
      population < 0 ->
        {:error, "population must be non-negative"}

      not Enum.any?(state.entities, &(&1.name == name)) ->
        {:error, "entity '#{name}' not registered"}

      true ->
        updated_entities =
          Enum.map(state.entities, fn e ->
            if e.name == name do
              ratio = population / e.initial

              status =
                cond do
                  ratio <= @extinct_ratio -> :extinct
                  ratio < @endangered_ratio -> :endangered
                  true -> :healthy
                end

              %{e | population: population, status: status}
            else
              e
            end
          end)

        updated = %{state | entities: updated_entities}
        {:ok, recompute(updated)}
    end
  end

  @spec endangered(t()) :: [String.t()]
  def endangered(%__MODULE__{entities: entities}) do
    entities |> Enum.filter(&(&1.status == :endangered)) |> Enum.map(& &1.name)
  end

  @spec extinct(t()) :: [String.t()]
  def extinct(%__MODULE__{entities: entities}) do
    entities |> Enum.filter(&(&1.status == :extinct)) |> Enum.map(& &1.name)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      ecosystem: state.ecosystem,
      entity_count: length(state.entities),
      diversity_index: state.diversity_index,
      resilience: state.resilience,
      extinct_count: state.extinct_count,
      endangered: endangered(state),
      extinct: extinct(state)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp recompute(%__MODULE__{entities: []} = state) do
    %{state | diversity_index: 0.0, resilience: 1.0, extinct_count: 0}
  end

  defp recompute(%__MODULE__{entities: entities} = state) do
    extinct_count = Enum.count(entities, &(&1.status == :extinct))
    alive = Enum.filter(entities, &(&1.population > 0))
    total_pop = Enum.reduce(alive, 0, fn e, acc -> acc + e.population end)

    diversity_index =
      if total_pop == 0 or length(alive) == 0 do
        0.0
      else
        alive
        |> Enum.reduce(0.0, fn e, acc ->
          p = e.population / total_pop
          acc - p * (:math.log(p) / @ln2)
        end)
        |> Float.round(4)
      end

    max_diversity = if length(entities) > 0, do: :math.log(length(entities)) / @ln2, else: 1.0

    resilience =
      if max_diversity == 0.0 do
        1.0
      else
        Float.round(min(1.0, diversity_index / max_diversity), 4)
      end

    %{
      state
      | diversity_index: diversity_index,
        resilience: resilience,
        extinct_count: extinct_count
    }
  end
end
