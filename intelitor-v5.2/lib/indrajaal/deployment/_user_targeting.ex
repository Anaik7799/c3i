defmodule Indrajaal.Deployment.UserTargeting do
  @moduledoc """
  Feature flag user targeting rules engine.

  WHAT: Evaluates whether a user_context matches a set of attribute-based rules.
  WHY: Enables targeted feature rollout to specific user segments.
  CONSTRAINTS: SC-GDE-001 (Guardian validation), SC-PRF-050
  """

  @table :deployment_user_targeting

  @spec evaluate(map(), [map()]) :: boolean()
  def evaluate(user_context, rules) when is_map(user_context) and is_list(rules) do
    Enum.all?(rules, &match_rule?(user_context, &1))
  end

  @spec add_rule(term(), map()) :: :ok
  def add_rule(rule_id, %{attribute: _, operator: _, value: _} = rule) do
    ensure_table()
    :ets.insert(@table, {rule_id, rule})
    :ok
  end

  @spec list_rules() :: [map()]
  def list_rules do
    ensure_table()
    :ets.tab2list(@table) |> Enum.map(fn {id, rule} -> Map.put(rule, :id, id) end)
  end

  defp match_rule?(ctx, %{attribute: attr, operator: op, value: expected}) do
    actual = Map.get(ctx, attr) || Map.get(ctx, to_string(attr))
    apply_operator(op, actual, expected)
  end

  defp match_rule?(_ctx, _rule), do: false

  defp apply_operator(:eq, actual, expected), do: actual == expected
  defp apply_operator(:neq, actual, expected), do: actual != expected
  defp apply_operator(:in, actual, list) when is_list(list), do: actual in list
  defp apply_operator(:not_in, actual, list) when is_list(list), do: actual not in list
  defp apply_operator(:gt, actual, expected) when is_number(actual), do: actual > expected
  defp apply_operator(:lt, actual, expected) when is_number(actual), do: actual < expected
  defp apply_operator(_, _actual, _expected), do: false

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end
