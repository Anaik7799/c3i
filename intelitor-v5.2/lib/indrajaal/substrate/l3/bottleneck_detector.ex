defmodule Indrajaal.Substrate.L3.BottleneckDetector do
  @moduledoc """
  ## Design Intent
  L3 substrate bottleneck detector — pure functional throughput constraint finder.

  Biomorphic metaphor: the Theory of Constraints applied to metabolic pathways —
  Goldratt's observation that system throughput is governed by its weakest link.
  This module tracks utilization rates across pipeline stages and identifies which
  stage is the binding constraint using Little's Law and utilization analysis.

  Algorithm:
  1. Each stage has a capacity (max items/unit time) and an observed throughput.
  2. Utilization = throughput / capacity; the stage with utilization nearest 1.0 is
     the bottleneck candidate.
  3. A stage is confirmed as a bottleneck when utilization >= threshold for N
     consecutive observations.
  4. Returns the bottleneck stage ID and a ranked utilization map.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-HOM-001: Homeostatic controller — REFERENCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type stage :: %{
          capacity: float(),
          throughput: float(),
          utilization: float(),
          consecutive_hot: non_neg_integer()
        }

  @type t :: %__MODULE__{
          stages: %{String.t() => stage()},
          bottleneck_threshold: float(),
          confirmation_runs: pos_integer(),
          bottleneck: String.t() | nil,
          observation_count: non_neg_integer()
        }

  defstruct stages: %{},
            bottleneck_threshold: 0.85,
            confirmation_runs: 3,
            bottleneck: nil,
            observation_count: 0

  @doc """
  Create a new BottleneckDetector.

  Options:
  - `:bottleneck_threshold` — utilization ratio to flag ∈ (0.5, 1.0], default 0.85
  - `:confirmation_runs` — consecutive hot observations needed ∈ [1, 20], default 3
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :bottleneck_threshold, 0.85)
    runs = Keyword.get(opts, :confirmation_runs, 3)

    cond do
      not is_number(threshold) ->
        {:error, "bottleneck_threshold must be a number"}

      threshold <= 0.5 or threshold > 1.0 ->
        {:error, "bottleneck_threshold must be in (0.5, 1.0]"}

      not is_integer(runs) ->
        {:error, "confirmation_runs must be an integer"}

      runs < 1 or runs > 20 ->
        {:error, "confirmation_runs must be in [1, 20]"}

      true ->
        {:ok, %__MODULE__{bottleneck_threshold: threshold * 1.0, confirmation_runs: runs}}
    end
  end

  @doc """
  Register a pipeline stage with its maximum capacity (items per unit time).
  """
  @spec register_stage(t(), String.t(), float()) :: {:ok, t()} | {:error, String.t()}
  def register_stage(%__MODULE__{} = state, id, capacity)
      when is_binary(id) and is_number(capacity) and capacity > 0.0 do
    if Map.has_key?(state.stages, id) do
      {:error, "stage #{id} already registered"}
    else
      stage = %{capacity: capacity * 1.0, throughput: 0.0, utilization: 0.0, consecutive_hot: 0}
      {:ok, %__MODULE__{state | stages: Map.put(state.stages, id, stage)}}
    end
  end

  def register_stage(%__MODULE__{}, _id, _capacity) do
    {:error, "id must be a binary and capacity must be a positive number"}
  end

  @doc """
  Record an observation of current throughput for all stages.

  `readings` — map of stage_id => current_throughput (items/unit time).
  Returns `{bottleneck_id_or_nil, updated_state}`.
  """
  @spec observe(t(), %{String.t() => float()}) :: {String.t() | nil, t()}
  def observe(%__MODULE__{} = state, readings) when is_map(readings) do
    new_stages =
      Map.new(state.stages, fn {id, stage} ->
        throughput = Map.get(readings, id, stage.throughput)
        throughput = max(0.0, throughput * 1.0)
        utilization = min(1.0, throughput / stage.capacity)

        is_hot = utilization >= state.bottleneck_threshold
        consecutive = if is_hot, do: stage.consecutive_hot + 1, else: 0

        {id,
         %{stage | throughput: throughput, utilization: utilization, consecutive_hot: consecutive}}
      end)

    # Find confirmed bottleneck: highest utilization among stages with enough consecutive hot runs
    bottleneck =
      new_stages
      |> Enum.filter(fn {_id, s} -> s.consecutive_hot >= state.confirmation_runs end)
      |> Enum.max_by(fn {_id, s} -> s.utilization end, fn -> nil end)
      |> case do
        nil -> nil
        {id, _stage} -> id
      end

    new_state = %__MODULE__{
      state
      | stages: new_stages,
        bottleneck: bottleneck,
        observation_count: state.observation_count + 1
    }

    {bottleneck, new_state}
  end

  @doc """
  Returns a summary map of the detector state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    utilizations =
      Map.new(state.stages, fn {id, s} ->
        {id, %{utilization: s.utilization, throughput: s.throughput, capacity: s.capacity}}
      end)

    ranked =
      utilizations
      |> Enum.sort_by(fn {_id, v} -> -v.utilization end)
      |> Enum.map(fn {id, v} -> Map.put(v, :stage_id, id) end)

    %{
      stage_count: map_size(state.stages),
      bottleneck: state.bottleneck,
      bottleneck_threshold: state.bottleneck_threshold,
      observation_count: state.observation_count,
      ranked_stages: ranked
    }
  end
end
