defmodule Indrajaal.Crm.Automation.AssignmentRules do
  @moduledoc """
  Lead/Case assignment rules engine.
  Evaluates criteria and assigns to appropriate owner.

  ## Purpose

  Automates record assignment based on:
  - Field criteria matching
  - Territory-based routing
  - Round-robin distribution
  - Skill-based assignment
  - Load balancing

  ## STAMP Constraints

  - SC-AUTO-001: Max 100 rules per object
  - SC-AUTO-002: Evaluation timeout 5s
  - SC-AUTO-003: Fallback owner required
  - SC-AUTO-004: Max iteration limit (prevent infinite loops)

  ## FMEA Analysis

  | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
  |--------------|----------|------------|-----------|-----|------------|
  | Rule infinite loop | 9 | 2 | 3 | 54 | Max iteration limit |
  | Assignment failure | 7 | 4 | 5 | 140 | Fallback owner |
  | Evaluation timeout | 6 | 3 | 4 | 72 | Async execution |

  ## Usage

      {:ok, assignee} = AssignmentRules.evaluate(record, :lead)
      {:ok, updated} = update_record_owner(record, assignee)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |
  """

  require Logger
  alias Indrajaal.Crm.Resources.AssignmentRule

  @max_rules 100
  @max_iterations 10
  @timeout_ms 5_000
  @fallback_owner_id "00000000-0000-0000-0000-000000000000"

  defmodule Rule do
    @moduledoc """
    Assignment rule definition.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            object_type: atom(),
            criteria: map(),
            assignee: String.t(),
            order: integer(),
            active: boolean()
          }

    defstruct [
      :id,
      :name,
      :object_type,
      :criteria,
      :assignee,
      order: 0,
      active: true
    ]
  end

  @doc """
  Evaluate assignment rules for a record.

  Returns `{:ok, assignee_id}` or `{:error, reason}`.

  ## Examples

      iex> evaluate(%{industry: "Technology", revenue: 1_000_000}, :lead)
      {:ok, "user-123"}

      iex> evaluate(%{priority: :high}, :case)
      {:ok, "user-456"}
  """
  @spec evaluate(map(), atom()) :: {:ok, String.t()} | {:error, term()}
  def evaluate(record, object_type) do
    task =
      Task.async(fn ->
        rules = get_active_rules(object_type)

        if length(rules) > @max_rules do
          Logger.warning("Too many assignment rules",
            object_type: object_type,
            count: length(rules),
            max: @max_rules
          )
        end

        # Limit rules to max (SC-AUTO-001)
        rules = Enum.take(rules, @max_rules)

        # Evaluate rules in order
        case find_matching_rule(record, rules, 0) do
          {:ok, assignee} ->
            {:ok, assignee}

          :no_match ->
            Logger.info("No matching rule, using fallback owner",
              object_type: object_type,
              record_id: Map.get(record, :id)
            )

            {:ok, fallback_owner()}
        end
      end)

    # Wait with timeout (SC-AUTO-002)
    case Task.yield(task, @timeout_ms) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("Assignment rule evaluation timeout",
          object_type: object_type,
          timeout_ms: @timeout_ms
        )

        {:ok, fallback_owner()}

      {:exit, reason} ->
        Logger.error("Assignment rule evaluation failed",
          object_type: object_type,
          reason: inspect(reason)
        )

        {:ok, fallback_owner()}
    end
  end

  @doc """
  Get active assignment rules for an object type.
  """
  @spec get_active_rules(atom()) :: [Rule.t()]
  def get_active_rules(object_type) do
    # Load from database
    case Ash.read(AssignmentRule, query: [filter: [object_type: object_type, active: true]]) do
      {:ok, rules} ->
        rules
        |> Enum.sort_by(& &1.order)
        |> Enum.map(&rule_to_struct/1)

      {:error, _} ->
        []
    end
  end

  @doc """
  Check if a record matches rule criteria.
  """
  @spec matches_criteria?(map(), map()) :: boolean()
  def matches_criteria?(record, criteria) when is_map(criteria) do
    Enum.all?(criteria, fn {field, condition} ->
      record_value = Map.get(record, String.to_existing_atom(field))
      evaluate_condition(record_value, condition)
    end)
  end

  @doc """
  Get the fallback owner ID (SC-AUTO-003).
  """
  @spec fallback_owner() :: String.t()
  def fallback_owner do
    Application.get_env(:indrajaal, :fallback_owner_id, @fallback_owner_id)
  end

  # Private functions

  defp find_matching_rule(_record, [], _iteration) do
    :no_match
  end

  defp find_matching_rule(_record, _rules, iteration) when iteration >= @max_iterations do
    Logger.warning("Max iterations reached in assignment rules",
      iteration: iteration,
      max: @max_iterations
    )

    :no_match
  end

  defp find_matching_rule(record, [rule | rest], iteration) do
    if matches_criteria?(record, rule.criteria) do
      Logger.info("Assignment rule matched",
        rule_id: rule.id,
        rule_name: rule.name,
        assignee: rule.assignee
      )

      {:ok, rule.assignee}
    else
      find_matching_rule(record, rest, iteration + 1)
    end
  end

  defp evaluate_condition(value, %{"operator" => "equals", "value" => expected}) do
    value == expected
  end

  defp evaluate_condition(value, %{"operator" => "not_equals", "value" => expected}) do
    value != expected
  end

  defp evaluate_condition(value, %{"operator" => "contains", "value" => substring})
       when is_binary(value) do
    String.contains?(value, substring)
  end

  defp evaluate_condition(value, %{"operator" => "greater_than", "value" => threshold})
       when is_number(value) do
    value > threshold
  end

  defp evaluate_condition(value, %{"operator" => "less_than", "value" => threshold})
       when is_number(value) do
    value < threshold
  end

  defp evaluate_condition(value, %{"operator" => "in", "value" => list}) when is_list(list) do
    value in list
  end

  defp evaluate_condition(_value, _condition) do
    false
  end

  defp rule_to_struct(rule) do
    %Rule{
      id: rule.id,
      name: rule.name,
      object_type: rule.object_type,
      criteria: rule.criteria,
      assignee: rule.assignee_id,
      order: rule.order,
      active: rule.active
    }
  end
end
