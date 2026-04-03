defmodule Indrajaal.Substrate.L5.CulturalDNA do
  @moduledoc """
  L5 Cultural DNA — Organisational culture model for the identity layer.

  Encodes the holon's cultural genotype as a vector of named traits scored
  on a [0.0, 1.0] scale. Cultural traits persist across operational cycles
  and evolve slowly through deliberate mutation, not environmental noise.

  Culture dimensions (Hofstede-inspired + VSM extensions):
  - :collaboration        — preference for collective over individual action
  - :innovation           — tolerance for novelty and experimentation
  - :transparency         — openness of information and decision-making
  - :resilience           — capacity to absorb and recover from shocks
  - :learning_orientation — prioritisation of knowledge accumulation
  - :safety_culture       — strength of safety-first norms

  Trait mutation is bounded: each update can shift a trait by at most
  `max_drift` per cycle, enforcing cultural stability.

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type trait :: atom()

  @type t :: %__MODULE__{
          traits: map(),
          max_drift: float(),
          mutation_count: non_neg_integer(),
          label: String.t()
        }

  defstruct traits: %{},
            max_drift: 0.1,
            mutation_count: 0,
            label: "default"

  @default_traits %{
    collaboration: 0.7,
    innovation: 0.6,
    transparency: 0.8,
    resilience: 0.75,
    learning_orientation: 0.7,
    safety_culture: 0.9
  }

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    max_drift = Keyword.get(opts, :max_drift, 0.1)
    label = Keyword.get(opts, :label, "default")
    use_defaults = Keyword.get(opts, :use_defaults, true)
    custom_traits = Keyword.get(opts, :traits, %{})

    cond do
      not is_number(max_drift) ->
        {:error, "max_drift must be numeric"}

      max_drift < 0.0 or max_drift > 1.0 ->
        {:error, "max_drift must be in [0.0, 1.0]"}

      not is_binary(label) ->
        {:error, "label must be a string"}

      not is_map(custom_traits) ->
        {:error, "traits must be a map"}

      true ->
        base = if use_defaults, do: @default_traits, else: %{}
        traits = Map.merge(base, custom_traits) |> Map.new(fn {k, v} -> {k, clamp(v)} end)
        {:ok, %__MODULE__{traits: traits, max_drift: max_drift / 1.0, label: label}}
    end
  end

  @spec mutate(t(), trait(), float()) :: {:ok, t()} | {:error, String.t()}
  def mutate(%__MODULE__{} = state, trait, target_value)
      when is_atom(trait) and is_number(target_value) do
    current = Map.get(state.traits, trait)

    if is_nil(current) do
      {:error, "unknown trait #{inspect(trait)}"}
    else
      target = clamp(target_value)
      delta = target - current
      bounded_delta = clamp_delta(delta, state.max_drift)
      new_value = clamp(current + bounded_delta)
      updated_traits = Map.put(state.traits, trait, new_value)

      {:ok, %{state | traits: updated_traits, mutation_count: state.mutation_count + 1}}
    end
  end

  @spec trait_value(t(), trait()) :: float() | nil
  def trait_value(%__MODULE__{traits: traits}, trait) when is_atom(trait) do
    Map.get(traits, trait)
  end

  @spec cultural_alignment(t(), map()) :: float()
  def cultural_alignment(%__MODULE__{traits: traits}, expected) when is_map(expected) do
    if map_size(expected) == 0 or map_size(traits) == 0 do
      1.0
    else
      shared_keys =
        MapSet.intersection(MapSet.new(Map.keys(traits)), MapSet.new(Map.keys(expected)))

      if MapSet.size(shared_keys) == 0 do
        0.0
      else
        total_diff =
          Enum.reduce(shared_keys, 0.0, fn k, acc ->
            acc + abs(Map.fetch!(traits, k) - clamp(Map.fetch!(expected, k)))
          end)

        avg_diff = total_diff / MapSet.size(shared_keys)
        Float.round(1.0 - avg_diff, 4)
      end
    end
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      label: state.label,
      trait_count: map_size(state.traits),
      mutation_count: state.mutation_count,
      max_drift: state.max_drift,
      traits: state.traits
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp clamp(v) when is_number(v), do: Float.round(min(1.0, max(0.0, v / 1.0)), 4)
  defp clamp(_), do: 0.5

  defp clamp_delta(delta, max_drift) when delta > 0, do: min(delta, max_drift)
  defp clamp_delta(delta, max_drift), do: max(delta, -max_drift)
end
