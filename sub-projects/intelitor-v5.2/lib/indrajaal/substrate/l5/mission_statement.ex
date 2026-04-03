defmodule Indrajaal.Substrate.L5.MissionStatement do
  @moduledoc """
  L5 Mission Statement — Purpose and mission tracker for the identity layer.

  Maintains a structured representation of the system's stated purpose,
  tracks mission drift over time, and scores proposed objectives for
  mission alignment. Acts as the normative anchor for all L5 policy decisions.

  A mission is decomposed into:
  - purpose: the fundamental reason for existence
  - objectives: concrete, time-bound targets
  - principles: behavioural commitments that cannot be compromised
  - boundaries: explicit out-of-scope exclusions

  Drift detection compares active objectives to the core purpose using
  keyword overlap and semantic distance heuristics.

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type objective :: %{
          id: String.t(),
          text: String.t(),
          horizon: :short | :medium | :long,
          active: boolean(),
          alignment_score: float()
        }

  @type t :: %__MODULE__{
          purpose: String.t(),
          principles: [String.t()],
          boundaries: [String.t()],
          objectives: [objective()],
          label: String.t()
        }

  defstruct purpose: "",
            principles: [],
            boundaries: [],
            objectives: [],
            label: "default"

  @valid_horizons [:short, :medium, :long]

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    purpose = Keyword.get(opts, :purpose, "")
    principles = Keyword.get(opts, :principles, [])
    boundaries = Keyword.get(opts, :boundaries, [])
    label = Keyword.get(opts, :label, "default")

    cond do
      not is_binary(purpose) ->
        {:error, "purpose must be a string"}

      not is_list(principles) ->
        {:error, "principles must be a list"}

      not is_list(boundaries) ->
        {:error, "boundaries must be a list"}

      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        {:ok,
         %__MODULE__{
           purpose: purpose,
           principles: principles,
           boundaries: boundaries,
           label: label
         }}
    end
  end

  @spec add_objective(t(), String.t(), :short | :medium | :long) ::
          {:ok, t()} | {:error, String.t()}
  def add_objective(%__MODULE__{} = state, text, horizon)
      when is_binary(text) do
    cond do
      horizon not in @valid_horizons ->
        {:error, "horizon must be one of #{inspect(@valid_horizons)}"}

      String.trim(text) == "" ->
        {:error, "objective text must not be blank"}

      true ->
        alignment = compute_alignment(text, state.purpose)

        obj = %{
          id: generate_id(),
          text: text,
          horizon: horizon,
          active: true,
          alignment_score: alignment
        }

        {:ok, %{state | objectives: state.objectives ++ [obj]}}
    end
  end

  @spec active_objectives(t()) :: [objective()]
  def active_objectives(%__MODULE__{objectives: objectives}) do
    Enum.filter(objectives, & &1.active)
  end

  @spec mission_coherence(t()) :: float()
  def mission_coherence(%__MODULE__{objectives: []}), do: 1.0

  def mission_coherence(%__MODULE__{} = state) do
    active = active_objectives(state)

    if Enum.empty?(active) do
      1.0
    else
      avg = Enum.sum(Enum.map(active, & &1.alignment_score)) / length(active)
      Float.round(avg, 4)
    end
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    active = active_objectives(state)
    by_horizon = Enum.group_by(active, & &1.horizon) |> Map.new(fn {k, v} -> {k, length(v)} end)

    %{
      label: state.label,
      purpose: state.purpose,
      principle_count: length(state.principles),
      boundary_count: length(state.boundaries),
      active_objectives: length(active),
      horizons: by_horizon,
      mission_coherence: mission_coherence(state)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp compute_alignment(text, purpose) when purpose == "" do
    _ = text
    1.0
  end

  defp compute_alignment(text, purpose) do
    text_words = tokenize(text)
    purpose_words = tokenize(purpose)

    if Enum.empty?(purpose_words) do
      1.0
    else
      overlap = MapSet.intersection(MapSet.new(text_words), MapSet.new(purpose_words))
      Float.round(MapSet.size(overlap) / length(purpose_words), 4)
    end
  end

  defp tokenize(str) do
    str
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.reject(&(String.length(&1) < 3))
  end

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end
end
