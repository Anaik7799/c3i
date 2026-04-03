defmodule Indrajaal.Substrate.L5.WisdomDistiller do
  @moduledoc """
  L5 Wisdom Distiller — Experience distillation engine for organisational learning.

  Accumulates experience observations and distils them into condensed lessons
  by clustering similar experiences and computing their collective insight weight.
  The L5 identity layer uses distilled wisdom to inform policy evolution.

  Algorithm:
  - Insight weight: frequency × confidence × recency_decay
  - Clustering: experiences with Jaccard similarity >= 0.5 are merged
  - Distillation: top-N insights by weight form the wisdom corpus

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy identity — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @default_capacity 128
  @similarity_threshold 0.5
  @decay_factor 0.95

  @type experience :: %{
          text: String.t(),
          confidence: float(),
          weight: float(),
          count: pos_integer()
        }

  @type t :: %__MODULE__{
          capacity: pos_integer(),
          experiences: [experience()],
          distilled: [String.t()]
        }

  defstruct capacity: @default_capacity,
            experiences: [],
            distilled: []

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    capacity = Keyword.get(opts, :capacity, @default_capacity)

    cond do
      not is_integer(capacity) or capacity < 1 ->
        {:error, "capacity must be a positive integer"}

      true ->
        {:ok, %__MODULE__{capacity: capacity}}
    end
  end

  @spec absorb(t(), String.t(), float()) :: {:ok, t()} | {:error, String.t()}
  def absorb(%__MODULE__{} = state, text, confidence)
      when is_binary(text) and is_number(confidence) do
    cond do
      String.trim(text) == "" ->
        {:error, "text must not be empty"}

      confidence < 0.0 or confidence > 1.0 ->
        {:error, "confidence must be in [0.0, 1.0]"}

      true ->
        tokens = tokenise(text)
        state = apply_decay(state)

        updated_experiences =
          case find_similar(state.experiences, tokens) do
            nil ->
              entry = %{
                text: text,
                confidence: confidence / 1.0,
                weight: confidence / 1.0,
                count: 1
              }

              Enum.take([entry | state.experiences], state.capacity)

            existing ->
              Enum.map(state.experiences, fn e ->
                if e.text == existing.text do
                  new_count = e.count + 1
                  new_weight = Float.round(e.weight + confidence / 1.0 * @decay_factor, 4)
                  %{e | count: new_count, weight: new_weight}
                else
                  e
                end
              end)
          end

        distilled = distil(updated_experiences)
        {:ok, %{state | experiences: updated_experiences, distilled: distilled}}
    end
  end

  @spec top_insights(t(), non_neg_integer()) :: [experience()]
  def top_insights(%__MODULE__{experiences: exps}, n) when is_integer(n) and n >= 0 do
    exps
    |> Enum.sort_by(& &1.weight, :desc)
    |> Enum.take(n)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      experience_count: length(state.experiences),
      capacity: state.capacity,
      distilled_count: length(state.distilled),
      top_insight: state.distilled |> List.first()
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp tokenise(text) do
    text |> String.downcase() |> String.split(~r/\W+/, trim: true) |> MapSet.new()
  end

  defp jaccard(a, b) do
    i = MapSet.intersection(a, b) |> MapSet.size()
    u = MapSet.union(a, b) |> MapSet.size()
    if u == 0, do: 0.0, else: i / u
  end

  defp find_similar(experiences, tokens) do
    Enum.find(experiences, fn e ->
      jaccard(tokenise(e.text), tokens) >= @similarity_threshold
    end)
  end

  defp apply_decay(%__MODULE__{experiences: exps} = state) do
    decayed = Enum.map(exps, fn e -> %{e | weight: Float.round(e.weight * @decay_factor, 4)} end)
    %{state | experiences: decayed}
  end

  defp distil(experiences) do
    experiences
    |> Enum.sort_by(& &1.weight, :desc)
    |> Enum.take(10)
    |> Enum.map(& &1.text)
  end
end
