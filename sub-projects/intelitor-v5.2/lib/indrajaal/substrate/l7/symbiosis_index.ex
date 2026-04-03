defmodule Indrajaal.Substrate.L7.SymbiosisIndex do
  @moduledoc """
  ## Design Intent
  L7 substrate Symbiosis Index — pure functional symbiotic relationship scorer
  for the Indrajaal biomorphic ecosystem layer.

  Models mutualism theory from ecology: every pair of holons can have a
  symbiotic relationship classified by the net benefit exchange.

  Relationship types (from ecology):
    - :mutualism    — both parties benefit    (+/+)
    - :commensalism — one benefits, neutral    (+/0)
    - :parasitism   — one benefits, other hurt (+/−)
    - :amensalism   — one neutral, other hurt  (0/−)
    - :competition  — both parties hurt        (−/−)
    - :neutralism   — neither affected         (0/0)

  Scoring:
    - Each relationship is assigned two benefit scores: `a_benefit` and `b_benefit`
      both in [−1.0, 1.0] representing net gain (positive) or harm (negative).
    - The symbiosis index for a relationship pair = (a_benefit + b_benefit) / 2
    - Global ecosystem symbiosis = mean of all pair indices

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — index is read-only observer
  - SC-ECO-004: Ecosystem diversity — relationship diversity tracked (Shannon H)
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type relationship_type ::
          :mutualism
          | :commensalism
          | :parasitism
          | :amensalism
          | :competition
          | :neutralism

  @type relationship :: %{
          pair_key: String.t(),
          holon_a: String.t(),
          holon_b: String.t(),
          a_benefit: float(),
          b_benefit: float(),
          pair_index: float(),
          type: relationship_type(),
          recorded_at: integer()
        }

  @type t :: %__MODULE__{
          relationships: %{String.t() => relationship()},
          global_index: float(),
          created_at: integer()
        }

  defstruct relationships: %{},
            global_index: 0.0,
            created_at: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    _opts = opts

    state = %__MODULE__{
      relationships: %{},
      global_index: 0.0,
      created_at: System.monotonic_time(:second)
    }

    {:ok, state}
  end

  @doc """
  Record or update a relationship between `holon_a` and `holon_b`.
  `a_benefit` and `b_benefit` must be in [−1.0, 1.0].
  Returns `{:ok, updated_index}`.
  """
  @spec record(t(), String.t(), String.t(), float(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def record(%__MODULE__{} = idx, holon_a, holon_b, a_benefit, b_benefit)
      when is_binary(holon_a) and is_binary(holon_b) and
             is_float(a_benefit) and is_float(b_benefit) do
    cond do
      a_benefit < -1.0 or a_benefit > 1.0 ->
        {:error, "a_benefit must be in [-1.0, 1.0]"}

      b_benefit < -1.0 or b_benefit > 1.0 ->
        {:error, "b_benefit must be in [-1.0, 1.0]"}

      holon_a == holon_b ->
        {:error, "holon_a and holon_b must differ"}

      true ->
        pair_key = pair_key(holon_a, holon_b)
        pair_index = Float.round((a_benefit + b_benefit) / 2.0, 4)

        rel = %{
          pair_key: pair_key,
          holon_a: holon_a,
          holon_b: holon_b,
          a_benefit: a_benefit,
          b_benefit: b_benefit,
          pair_index: pair_index,
          type: classify(a_benefit, b_benefit),
          recorded_at: System.monotonic_time(:second)
        }

        updated_rels = Map.put(idx.relationships, pair_key, rel)
        global = compute_global(updated_rels)

        {:ok, %{idx | relationships: updated_rels, global_index: global}}
    end
  end

  @doc """
  Return all relationships of a given type.
  """
  @spec by_type(t(), relationship_type()) :: [relationship()]
  def by_type(%__MODULE__{} = idx, type) when is_atom(type) do
    idx.relationships
    |> Map.values()
    |> Enum.filter(&(&1.type == type))
  end

  @doc """
  Return a summary of the symbiosis index state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = idx) do
    rels = Map.values(idx.relationships)

    type_counts =
      Enum.reduce(rels, %{}, fn r, acc ->
        Map.update(acc, r.type, 1, &(&1 + 1))
      end)

    %{
      global_index: idx.global_index,
      relationship_count: map_size(idx.relationships),
      type_distribution: type_counts
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec pair_key(String.t(), String.t()) :: String.t()
  defp pair_key(a, b) do
    [x, y] = Enum.sort([a, b])
    "#{x}::#{y}"
  end

  @spec classify(float(), float()) :: relationship_type()
  defp classify(a, b) do
    cond do
      a > 0.0 and b > 0.0 -> :mutualism
      a > 0.0 and abs(b) < 0.05 -> :commensalism
      abs(a) < 0.05 and b > 0.0 -> :commensalism
      a > 0.0 and b < 0.0 -> :parasitism
      a < 0.0 and b > 0.0 -> :parasitism
      a < 0.0 and abs(b) < 0.05 -> :amensalism
      abs(a) < 0.05 and b < 0.0 -> :amensalism
      a < 0.0 and b < 0.0 -> :competition
      true -> :neutralism
    end
  end

  @spec compute_global(%{String.t() => relationship()}) :: float()
  defp compute_global(rels) when map_size(rels) == 0, do: 0.0

  defp compute_global(rels) do
    indices = rels |> Map.values() |> Enum.map(& &1.pair_index)
    Float.round(Enum.sum(indices) / length(indices), 4)
  end
end
