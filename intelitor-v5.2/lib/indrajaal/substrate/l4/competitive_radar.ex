defmodule Indrajaal.Substrate.L4.CompetitiveRadar do
  @moduledoc """
  ## Design Intent
  L4 substrate competitive radar — pure functional competitor tracking module
  for monitoring the relative positioning of competing entities in a shared
  environment.

  Biological metaphor: Territorial vigilance in social animals. A wolf pack
  maintains awareness of neighbouring pack positions, food-cache locations,
  and intrusion events. This module tracks competitor entities across
  configurable dimensions and computes relative threat scores.

  Algorithm:
    - Each competitor has a `profile` — a map of `%{dimension => score}`.
    - `upsert/3` registers or updates a competitor's profile.
    - `threat_score/2` computes a weighted mean of dimension scores for
      a given competitor, using the `weights` map (default: uniform).
    - `rank/1` returns all competitors sorted by threat score descending.
    - `gap_analysis/2` computes dimension-by-dimension delta vs a reference
      competitor.

  ## STAMP Constraints
  - SC-S4-001: Environmental scanning at L4 boundary — ENFORCED
  - SC-S4-003: Forecast horizon aligned with OODA cycle — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type competitor_id :: String.t()
  @type dimension :: String.t()
  @type profile :: %{dimension() => float()}

  @type competitor_entry :: %{
          profile: profile(),
          last_updated: integer(),
          observation_count: non_neg_integer()
        }

  @type t :: %__MODULE__{
          competitors: %{competitor_id() => competitor_entry()},
          weights: %{dimension() => float()},
          update_count: non_neg_integer()
        }

  defstruct competitors: %{},
            weights: %{},
            update_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new CompetitiveRadar.

  Options:
    - `:weights` — map of `%{dimension => weight_float}` for threat scoring
      (defaults to uniform weights if empty or omitted)

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    weights = Keyword.get(opts, :weights, %{})

    cond do
      not is_map(weights) ->
        {:error, "weights must be a map"}

      not all_weights_valid?(weights) ->
        {:error, "all weights must be non-negative floats"}

      true ->
        {:ok, %__MODULE__{weights: weights}}
    end
  end

  @doc """
  Register or update a competitor's profile scores.

  All score values are clamped to [0.0, 1.0].

  Returns `{:ok, updated}`.
  """
  @spec upsert(t(), competitor_id(), profile()) :: {:ok, t()}
  def upsert(%__MODULE__{} = radar, id, profile)
      when is_binary(id) and is_map(profile) do
    clamped_profile =
      Map.new(profile, fn {k, v} ->
        {k, clamp(v * 1.0, 0.0, 1.0)}
      end)

    prior = Map.get(radar.competitors, id, %{profile: %{}, last_updated: 0, observation_count: 0})

    entry = %{
      profile: clamped_profile,
      last_updated: System.monotonic_time(:millisecond),
      observation_count: prior.observation_count + 1
    }

    updated = %{
      radar
      | competitors: Map.put(radar.competitors, id, entry),
        update_count: radar.update_count + 1
    }

    {:ok, updated}
  end

  def upsert(%__MODULE__{} = radar, _id, _profile), do: {:ok, radar}

  @doc """
  Compute a threat score for a competitor.

  Uses the radar's `weights` map. If weights is empty, uses uniform weighting
  over all dimensions in the competitor's profile. Returns 0.0 for unknown ids.
  """
  @spec threat_score(t(), competitor_id()) :: float()
  def threat_score(%__MODULE__{} = radar, id) when is_binary(id) do
    case Map.get(radar.competitors, id) do
      nil ->
        0.0

      %{profile: profile} ->
        effective_weights = effective_weights(radar.weights, profile)
        weighted_score(profile, effective_weights)
    end
  end

  def threat_score(_radar, _id), do: 0.0

  @doc """
  Returns all competitors ranked by threat score, highest first.

  Each entry is `%{id, score, profile}`.
  """
  @spec rank(t()) :: [%{id: competitor_id(), score: float(), profile: profile()}]
  def rank(%__MODULE__{} = radar) do
    radar.competitors
    |> Enum.map(fn {id, entry} ->
      %{id: id, score: threat_score(radar, id), profile: entry.profile}
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Compute dimension-by-dimension gap between `subject_id` and `reference_id`.

  Positive values = subject scores higher; negative = reference scores higher.
  Returns empty map if either id is unknown.
  """
  @spec gap_analysis(t(), competitor_id(), competitor_id()) :: %{dimension() => float()}
  def gap_analysis(%__MODULE__{} = radar, subject_id, reference_id) do
    subject_profile = get_in(radar.competitors, [subject_id, :profile]) || %{}
    reference_profile = get_in(radar.competitors, [reference_id, :profile]) || %{}

    all_dims =
      MapSet.union(MapSet.new(Map.keys(subject_profile)), MapSet.new(Map.keys(reference_profile)))

    Map.new(all_dims, fn dim ->
      s = Map.get(subject_profile, dim, 0.0)
      r = Map.get(reference_profile, dim, 0.0)
      {dim, Float.round(s - r, 4)}
    end)
  end

  @doc """
  Returns a summary status map.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = radar) do
    ranked = rank(radar)

    %{
      competitor_count: map_size(radar.competitors),
      update_count: radar.update_count,
      weight_dimensions: map_size(radar.weights),
      top_threat: List.first(ranked)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec effective_weights(%{dimension() => float()}, profile()) :: %{dimension() => float()}
  defp effective_weights(weights, profile) when map_size(weights) == 0 do
    n = map_size(profile)
    if n == 0, do: %{}, else: Map.new(profile, fn {k, _} -> {k, 1.0 / n} end)
  end

  defp effective_weights(weights, _profile), do: weights

  @spec weighted_score(profile(), %{dimension() => float()}) :: float()
  defp weighted_score(_profile, weights) when map_size(weights) == 0, do: 0.0

  defp weighted_score(profile, weights) do
    total_weight = weights |> Map.values() |> Enum.sum()

    if total_weight == 0.0 do
      0.0
    else
      weighted_sum =
        Enum.reduce(weights, 0.0, fn {dim, w}, acc ->
          acc + w * Map.get(profile, dim, 0.0)
        end)

      Float.round(weighted_sum / total_weight, 4)
    end
  end

  @spec all_weights_valid?(map()) :: boolean()
  defp all_weights_valid?(weights) do
    Enum.all?(weights, fn
      {_k, v} when is_float(v) -> v >= 0.0
      _ -> false
    end)
  end

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
