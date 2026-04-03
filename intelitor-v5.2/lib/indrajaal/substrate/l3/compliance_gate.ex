defmodule Indrajaal.Substrate.L3.ComplianceGate do
  @moduledoc """
  ## Design Intent
  L3 substrate compliance gate — pure functional rule verification gate.

  Biomorphic metaphor: the blood-brain barrier, a selective gate that allows only
  compliant molecules through. Each rule is a predicate over an operation context;
  all rules must pass for the gate to open.

  Algorithm:
  1. Rules are registered with an ID, description, severity, and predicate function.
  2. `evaluate/2` runs all rules against a context map and collects results.
  3. Gate opens (`:pass`) only if all CRITICAL and HIGH rules pass.
  4. Results include per-rule verdicts and an aggregate summary.
  5. Rule violations are tagged with severity to support risk-weighted decisions.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-STAMP-001: STAMP constraint checking — ENFORCED
  - SC-SAFETY-018: Pre-execution validation completes all checks — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type severity :: :critical | :high | :medium | :low

  @type rule :: %{
          id: String.t(),
          description: String.t(),
          severity: severity(),
          predicate: (map() -> boolean())
        }

  @type verdict :: %{
          rule_id: String.t(),
          passed: boolean(),
          severity: severity(),
          description: String.t()
        }

  @type evaluation :: %{
          result: :pass | :block,
          verdicts: [verdict()],
          passed_count: non_neg_integer(),
          failed_count: non_neg_integer(),
          blocking_failures: [verdict()]
        }

  @type t :: %__MODULE__{
          rules: %{String.t() => rule()},
          blocking_severities: [severity()],
          evaluation_count: non_neg_integer(),
          pass_count: non_neg_integer(),
          block_count: non_neg_integer()
        }

  defstruct rules: %{},
            blocking_severities: [:critical, :high],
            evaluation_count: 0,
            pass_count: 0,
            block_count: 0

  @doc """
  Create a new ComplianceGate.

  Options:
  - `:blocking_severities` — list of severities that block on failure, default [:critical, :high]
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    blocking = Keyword.get(opts, :blocking_severities, [:critical, :high])
    valid_severities = [:critical, :high, :medium, :low]

    cond do
      not is_list(blocking) ->
        {:error, "blocking_severities must be a list"}

      Enum.any?(blocking, &(&1 not in valid_severities)) ->
        {:error, "blocking_severities must only contain :critical, :high, :medium, or :low"}

      true ->
        {:ok, %__MODULE__{blocking_severities: blocking}}
    end
  end

  @doc """
  Register a compliance rule.

  `id` — unique rule identifier
  `description` — human-readable description
  `severity` — one of :critical, :high, :medium, :low
  `predicate` — function `context -> boolean()`
  """
  @spec register_rule(t(), String.t(), String.t(), severity(), (map() -> boolean())) ::
          {:ok, t()} | {:error, String.t()}
  def register_rule(%__MODULE__{} = state, id, description, severity, predicate)
      when is_binary(id) and is_binary(description) and
             severity in [:critical, :high, :medium, :low] and
             is_function(predicate, 1) do
    if Map.has_key?(state.rules, id) do
      {:error, "rule #{id} already registered"}
    else
      rule = %{id: id, description: description, severity: severity, predicate: predicate}
      {:ok, %__MODULE__{state | rules: Map.put(state.rules, id, rule)}}
    end
  end

  def register_rule(%__MODULE__{}, _id, _desc, _sev, _pred) do
    {:error,
     "invalid rule parameters — check id/description are binaries, severity is an atom, predicate is arity-1"}
  end

  @doc """
  Evaluate all rules against a context map.
  Returns `{evaluation, updated_state}`.
  """
  @spec evaluate(t(), map()) :: {evaluation(), t()}
  def evaluate(%__MODULE__{} = state, context) when is_map(context) do
    verdicts =
      state.rules
      |> Map.values()
      |> Enum.map(fn rule ->
        passed =
          try do
            rule.predicate.(context)
          rescue
            _ -> false
          end

        %{
          rule_id: rule.id,
          passed: passed,
          severity: rule.severity,
          description: rule.description
        }
      end)

    blocking_failures =
      Enum.filter(verdicts, fn v ->
        not v.passed and v.severity in state.blocking_severities
      end)

    result = if Enum.empty?(blocking_failures), do: :pass, else: :block

    evaluation = %{
      result: result,
      verdicts: verdicts,
      passed_count: Enum.count(verdicts, & &1.passed),
      failed_count: Enum.count(verdicts, &(not &1.passed)),
      blocking_failures: blocking_failures
    }

    new_state = %__MODULE__{
      state
      | evaluation_count: state.evaluation_count + 1,
        pass_count: state.pass_count + if(result == :pass, do: 1, else: 0),
        block_count: state.block_count + if(result == :block, do: 1, else: 0)
    }

    {evaluation, new_state}
  end

  @doc """
  Returns a summary map of the gate state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    pass_rate =
      if state.evaluation_count > 0,
        do: state.pass_count / state.evaluation_count,
        else: 1.0

    %{
      rule_count: map_size(state.rules),
      blocking_severities: state.blocking_severities,
      evaluation_count: state.evaluation_count,
      pass_count: state.pass_count,
      block_count: state.block_count,
      pass_rate: pass_rate
    }
  end
end
