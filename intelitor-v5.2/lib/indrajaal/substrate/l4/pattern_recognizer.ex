defmodule Indrajaal.Substrate.L4.PatternRecognizer do
  @moduledoc """
  L4 Pattern Recognizer — Statistical pattern matcher for environmental intelligence.

  Detects recurring patterns in event streams using frequency analysis and
  cosine similarity against a registered pattern library. Each candidate event
  vector is compared against stored templates to find the best match.

  Metaphor: The associative cortex of the VSM — recognising familiar structures
  in novel data to enable rapid adaptive classification.

  Similarity metrics:
  - Cosine similarity for numeric vectors
  - Frequency baseline for categorical streams
  - Confidence threshold gating

  ## STAMP Constraints
  - SC-S4-001: Cybernetic VSM S4 intelligence — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type pattern_template :: %{
          name: String.t(),
          vector: [float()],
          category: atom(),
          match_count: non_neg_integer()
        }

  @type match_result :: %{
          matched: boolean(),
          pattern_name: String.t() | nil,
          category: atom() | nil,
          similarity: float()
        }

  @type t :: %__MODULE__{
          templates: [pattern_template()],
          confidence_threshold: float(),
          label: String.t()
        }

  defstruct templates: [],
            confidence_threshold: 0.8,
            label: "default"

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :confidence_threshold, 0.8)
    label = Keyword.get(opts, :label, "default")

    cond do
      not is_number(threshold) ->
        {:error, "confidence_threshold must be numeric"}

      threshold < 0.0 or threshold > 1.0 ->
        {:error, "confidence_threshold must be in [0.0, 1.0]"}

      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        {:ok, %__MODULE__{confidence_threshold: threshold / 1.0, label: label}}
    end
  end

  @spec register(t(), String.t(), [float()], atom()) :: {:ok, t()} | {:error, String.t()}
  def register(%__MODULE__{} = state, name, vector, category)
      when is_binary(name) and is_list(vector) and is_atom(category) do
    cond do
      Enum.empty?(vector) ->
        {:error, "vector must not be empty"}

      not Enum.all?(vector, &is_number/1) ->
        {:error, "vector elements must be numeric"}

      true ->
        template = %{
          name: name,
          vector: Enum.map(vector, &(&1 / 1.0)),
          category: category,
          match_count: 0
        }

        {:ok, %{state | templates: state.templates ++ [template]}}
    end
  end

  @spec recognize(t(), [float()]) :: {t(), match_result()}
  def recognize(%__MODULE__{templates: []}, _vector) do
    result = %{matched: false, pattern_name: nil, category: nil, similarity: 0.0}
    {%__MODULE__{}, result}
  end

  def recognize(%__MODULE__{} = state, vector) when is_list(vector) do
    query = Enum.map(vector, &(&1 / 1.0))

    best =
      state.templates
      |> Enum.map(fn t -> {t, cosine_similarity(query, t.vector)} end)
      |> Enum.max_by(fn {_t, sim} -> sim end)

    {template, similarity} = best

    if similarity >= state.confidence_threshold do
      updated_templates =
        Enum.map(state.templates, fn t ->
          if t.name == template.name, do: %{t | match_count: t.match_count + 1}, else: t
        end)

      result = %{
        matched: true,
        pattern_name: template.name,
        category: template.category,
        similarity: Float.round(similarity, 4)
      }

      {%{state | templates: updated_templates}, result}
    else
      result = %{
        matched: false,
        pattern_name: nil,
        category: nil,
        similarity: Float.round(similarity, 4)
      }

      {state, result}
    end
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    top_template =
      case Enum.max_by(state.templates, & &1.match_count, fn -> nil end) do
        nil -> nil
        t -> t.name
      end

    %{
      label: state.label,
      template_count: length(state.templates),
      confidence_threshold: state.confidence_threshold,
      most_matched_pattern: top_template
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp cosine_similarity(a, b) when length(a) != length(b), do: 0.0

  defp cosine_similarity(a, b) do
    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    norm_a = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    norm_b = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))

    if norm_a == 0.0 or norm_b == 0.0, do: 0.0, else: dot / (norm_a * norm_b)
  end
end
