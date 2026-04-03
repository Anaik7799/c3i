defmodule Indrajaal.Substrate.L5.GovernanceFramework do
  @moduledoc """
  L5 Governance Framework — Policy rule engine for identity and values layer.

  Maintains a named rule registry that maps governance dimensions (safety,
  compliance, autonomy, resource) to enforcement policies. Each rule has a
  severity weight and an enforcement mode (hard/soft/advisory).

  At VSM L5 the governance framework acts as the organisational constitution —
  the meta-rules that constrain all lower-layer adaptation without specifying
  mechanism.

  Enforcement modes:
  - :hard — rule violations are rejected immediately
  - :soft — rule violations raise a warning and are logged
  - :advisory — rule violations generate suggestions only

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type enforcement_mode :: :hard | :soft | :advisory
  @type dimension :: :safety | :compliance | :autonomy | :resource | :ethics | :strategic

  @type rule :: %{
          id: String.t(),
          name: String.t(),
          dimension: dimension(),
          mode: enforcement_mode(),
          weight: float(),
          description: String.t()
        }

  @type evaluation :: %{
          rule_id: String.t(),
          passed: boolean(),
          mode: enforcement_mode(),
          message: String.t()
        }

  @type t :: %__MODULE__{
          rules: [rule()],
          label: String.t()
        }

  defstruct rules: [],
            label: "default"

  @valid_modes [:hard, :soft, :advisory]
  @valid_dimensions [:safety, :compliance, :autonomy, :resource, :ethics, :strategic]

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    label = Keyword.get(opts, :label, "default")

    cond do
      not is_binary(label) ->
        {:error, "label must be a string"}

      true ->
        {:ok, %__MODULE__{label: label}}
    end
  end

  @spec add_rule(t(), String.t(), dimension(), enforcement_mode(), float(), String.t()) ::
          {:ok, t()} | {:error, String.t()}
  def add_rule(%__MODULE__{} = state, name, dimension, mode, weight, description)
      when is_binary(name) and is_binary(description) do
    cond do
      dimension not in @valid_dimensions ->
        {:error, "invalid dimension #{inspect(dimension)}"}

      mode not in @valid_modes ->
        {:error, "invalid mode #{inspect(mode)}"}

      not is_number(weight) ->
        {:error, "weight must be numeric"}

      true ->
        rule = %{
          id: generate_id(),
          name: name,
          dimension: dimension,
          mode: mode,
          weight: clamp(weight),
          description: description
        }

        {:ok, %{state | rules: state.rules ++ [rule]}}
    end
  end

  @spec evaluate_all(t(), map()) :: [evaluation()]
  def evaluate_all(%__MODULE__{rules: rules}, context) when is_map(context) do
    Enum.map(rules, fn rule -> evaluate_rule(rule, context) end)
  end

  @spec hard_violations(t(), map()) :: [evaluation()]
  def hard_violations(%__MODULE__{} = state, context) do
    state
    |> evaluate_all(context)
    |> Enum.filter(fn e -> e.mode == :hard and not e.passed end)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    by_mode = Enum.group_by(state.rules, & &1.mode) |> Map.new(fn {k, v} -> {k, length(v)} end)

    by_dim =
      Enum.group_by(state.rules, & &1.dimension) |> Map.new(fn {k, v} -> {k, length(v)} end)

    %{
      label: state.label,
      total_rules: length(state.rules),
      hard_rules: Map.get(by_mode, :hard, 0),
      soft_rules: Map.get(by_mode, :soft, 0),
      advisory_rules: Map.get(by_mode, :advisory, 0),
      dimensions: by_dim
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp evaluate_rule(rule, context) do
    # Context-driven pass/fail: rules pass unless the context explicitly signals violation
    violated =
      Map.get(context, rule.id, false) == :violated or
        Map.get(context, rule.name, false) == :violated

    %{
      rule_id: rule.id,
      passed: not violated,
      mode: rule.mode,
      message:
        if violated do
          "Rule '#{rule.name}' (#{rule.dimension}/#{rule.mode}) violated"
        else
          "Rule '#{rule.name}' passed"
        end
    }
  end

  defp clamp(v) when is_number(v), do: Float.round(min(1.0, max(0.0, v / 1.0)), 4)
  defp clamp(_), do: 0.5

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end
end
