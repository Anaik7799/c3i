defmodule Indrajaal.Substrate.L4.InnovationFunnel do
  @moduledoc """
  ## Design Intent
  L4 substrate innovation funnel — pure functional idea pipeline management
  module tracking ideas through staged evaluation and selection.

  Biological metaphor: Adaptive immune response clonal selection. B-cells
  that recognise an antigen are selected and expanded; those with poor
  binding affinity are discarded. This module models ideas as candidates
  that enter at the top of a funnel and are progressively filtered through
  stages, with only the highest-potential ideas advancing toward activation.

  Algorithm:
    - Ideas are identified by a string key and have a `score` in [0.0, 1.0].
    - Five ordered stages: :ideation → :assessment → :incubation → :development → :launch.
    - `submit/3` adds an idea at the :ideation stage.
    - `advance/2` moves an idea to the next stage if `score >= stage_threshold`.
    - `prune/2` removes ideas with score below `prune_threshold` from a stage.
    - `pipeline/1` returns a map of stage → list of ideas at that stage.

  ## STAMP Constraints
  - SC-S4-001: Environmental scanning at L4 boundary — ENFORCED
  - SC-S4-003: Forecast horizon aligned with OODA cycle — ENFORCED
  - SC-S4-004: Confidence bounds verified before actuation — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @stages [:ideation, :assessment, :incubation, :development, :launch]

  @type idea_id :: String.t()
  @type stage :: :ideation | :assessment | :incubation | :development | :launch

  @type idea :: %{
          id: idea_id(),
          score: float(),
          stage: stage(),
          submitted_at: integer(),
          advance_count: non_neg_integer()
        }

  @type t :: %__MODULE__{
          ideas: %{idea_id() => idea()},
          stage_threshold: float(),
          prune_threshold: float(),
          submit_count: non_neg_integer(),
          launch_count: non_neg_integer()
        }

  defstruct ideas: %{},
            stage_threshold: 0.60,
            prune_threshold: 0.20,
            submit_count: 0,
            launch_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new InnovationFunnel.

  Options:
    - `:stage_threshold`  (float in (0,1], default 0.60) — min score to advance
    - `:prune_threshold`  (float in [0,1), default 0.20) — ideas below this are pruned

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    stage_threshold = Keyword.get(opts, :stage_threshold, 0.60)
    prune_threshold = Keyword.get(opts, :prune_threshold, 0.20)

    cond do
      not is_float(stage_threshold) or stage_threshold <= 0.0 or stage_threshold > 1.0 ->
        {:error, "stage_threshold must be in (0.0, 1.0]"}

      not is_float(prune_threshold) or prune_threshold < 0.0 or prune_threshold >= stage_threshold ->
        {:error, "prune_threshold must be in [0.0, stage_threshold)"}

      true ->
        {:ok, %__MODULE__{stage_threshold: stage_threshold, prune_threshold: prune_threshold}}
    end
  end

  @doc """
  Submit a new idea at the :ideation stage.

  Score is clamped to [0.0, 1.0]. Duplicate ids overwrite the prior entry.

  Returns `{:ok, updated}`.
  """
  @spec submit(t(), idea_id(), float()) :: {:ok, t()}
  def submit(%__MODULE__{} = funnel, id, score)
      when is_binary(id) and is_number(score) do
    clamped = clamp(score * 1.0, 0.0, 1.0)

    idea = %{
      id: id,
      score: clamped,
      stage: :ideation,
      submitted_at: System.monotonic_time(:millisecond),
      advance_count: 0
    }

    updated = %{
      funnel
      | ideas: Map.put(funnel.ideas, id, idea),
        submit_count: funnel.submit_count + 1
    }

    {:ok, updated}
  end

  def submit(%__MODULE__{} = funnel, _id, _score), do: {:ok, funnel}

  @doc """
  Attempt to advance an idea to the next stage.

  Returns:
    - `{:ok, :advanced, updated}` — idea moved to next stage
    - `{:ok, :launched, updated}` — idea was already at :development; now :launch
    - `{:error, :below_threshold}` — score too low to advance
    - `{:error, :already_launched}` — idea is at :launch (terminal stage)
    - `{:error, :not_found}` — idea id not in funnel
  """
  @spec advance(t(), idea_id()) ::
          {:ok, :advanced | :launched, t()}
          | {:error, :below_threshold | :already_launched | :not_found}
  def advance(%__MODULE__{} = funnel, id) when is_binary(id) do
    case Map.get(funnel.ideas, id) do
      nil ->
        {:error, :not_found}

      %{stage: :launch} ->
        {:error, :already_launched}

      %{score: score} when score < funnel.stage_threshold ->
        {:error, :below_threshold}

      idea ->
        next_stage = next_stage(idea.stage)
        updated_idea = %{idea | stage: next_stage, advance_count: idea.advance_count + 1}

        new_launch_count =
          if next_stage == :launch, do: funnel.launch_count + 1, else: funnel.launch_count

        outcome = if next_stage == :launch, do: :launched, else: :advanced

        updated = %{
          funnel
          | ideas: Map.put(funnel.ideas, id, updated_idea),
            launch_count: new_launch_count
        }

        {:ok, outcome, updated}
    end
  end

  def advance(%__MODULE__{} = _funnel, _id), do: {:error, :not_found}

  @doc """
  Remove all ideas at `stage` whose score is below `prune_threshold`.

  Returns `{:ok, pruned_count, updated}`.
  """
  @spec prune(t(), stage()) :: {:ok, non_neg_integer(), t()}
  def prune(%__MODULE__{} = funnel, stage) when stage in @stages do
    {surviving, pruned_count} =
      Enum.reduce(funnel.ideas, {%{}, 0}, fn {id, idea}, {acc, count} ->
        if idea.stage == stage and idea.score < funnel.prune_threshold do
          {acc, count + 1}
        else
          {Map.put(acc, id, idea), count}
        end
      end)

    {:ok, pruned_count, %{funnel | ideas: surviving}}
  end

  def prune(%__MODULE__{} = funnel, _stage), do: {:ok, 0, funnel}

  @doc """
  Returns a map of stage → list of ideas at that stage, sorted by score descending.
  """
  @spec pipeline(t()) :: %{stage() => [idea()]}
  def pipeline(%__MODULE__{} = funnel) do
    base = Map.new(@stages, fn stage -> {stage, []} end)

    Enum.reduce(funnel.ideas, base, fn {_id, idea}, acc ->
      Map.update!(acc, idea.stage, fn list -> [idea | list] end)
    end)
    |> Map.new(fn {stage, list} -> {stage, Enum.sort_by(list, & &1.score, :desc)} end)
  end

  @doc """
  Returns a summary status map.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = funnel) do
    pipe = pipeline(funnel)

    stage_counts =
      Map.new(@stages, fn stage ->
        {stage, length(Map.get(pipe, stage, []))}
      end)

    %{
      total_ideas: map_size(funnel.ideas),
      submit_count: funnel.submit_count,
      launch_count: funnel.launch_count,
      stage_threshold: funnel.stage_threshold,
      prune_threshold: funnel.prune_threshold,
      stage_counts: stage_counts
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec next_stage(stage()) :: stage()
  defp next_stage(:ideation), do: :assessment
  defp next_stage(:assessment), do: :incubation
  defp next_stage(:incubation), do: :development
  defp next_stage(:development), do: :launch
  defp next_stage(:launch), do: :launch

  @spec clamp(float(), float(), float()) :: float()
  defp clamp(v, lo, hi), do: max(lo, min(hi, v))
end
