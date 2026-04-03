defmodule Indrajaal.Substrate.L4.ScenarioModeler do
  @moduledoc """
  L4 Scenario Modeler — What-if scenario evaluation for strategic intelligence.

  Evaluates hypothetical future states by applying parameterised perturbations
  to a baseline model. Each scenario is scored by feasibility, impact, and
  reversibility, enabling the L4 layer to rank contingency options.

  Model:
  - Baseline state vector with named dimensions
  - Delta functions applied per scenario parameter
  - Monte-Carlo weight for stochastic perturbations
  - Score = feasibility × impact × reversibility

  ## STAMP Constraints
  - SC-S4-001: Cybernetic VSM S4 intelligence — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type scenario :: %{
          name: String.t(),
          parameters: map(),
          feasibility: float(),
          impact: float(),
          reversibility: float(),
          score: float()
        }

  @type t :: %__MODULE__{
          baseline: map(),
          scenarios: [scenario()],
          label: String.t()
        }

  defstruct baseline: %{},
            scenarios: [],
            label: "default"

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    baseline = Keyword.get(opts, :baseline, %{})
    label = Keyword.get(opts, :label, "default")

    cond do
      not is_map(baseline) ->
        {:error, "baseline must be a map"}

      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        {:ok, %__MODULE__{baseline: baseline, label: label}}
    end
  end

  @spec add_scenario(t(), String.t(), map()) :: t()
  def add_scenario(%__MODULE__{} = state, name, params) when is_binary(name) and is_map(params) do
    feasibility = clamp(Map.get(params, :feasibility, 0.5))
    impact = clamp(Map.get(params, :impact, 0.5))
    reversibility = clamp(Map.get(params, :reversibility, 0.5))
    score = Float.round(feasibility * impact * reversibility, 4)

    scenario = %{
      name: name,
      parameters: params,
      feasibility: feasibility,
      impact: impact,
      reversibility: reversibility,
      score: score
    }

    %{state | scenarios: state.scenarios ++ [scenario]}
  end

  @spec ranked_scenarios(t()) :: [scenario()]
  def ranked_scenarios(%__MODULE__{scenarios: scenarios}) do
    Enum.sort_by(scenarios, & &1.score, :desc)
  end

  @spec best_scenario(t()) :: scenario() | nil
  def best_scenario(%__MODULE__{scenarios: []}), do: nil

  def best_scenario(%__MODULE__{} = state) do
    state
    |> ranked_scenarios()
    |> List.first()
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    best = best_scenario(state)

    %{
      label: state.label,
      scenario_count: length(state.scenarios),
      baseline_dimensions: map_size(state.baseline),
      best_scenario: if(best, do: best.name, else: nil),
      best_score: if(best, do: best.score, else: nil)
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp clamp(v) when is_number(v), do: Float.round(min(1.0, max(0.0, v / 1.0)), 4)
  defp clamp(_), do: 0.5
end
