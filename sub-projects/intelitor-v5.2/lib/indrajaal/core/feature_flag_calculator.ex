defmodule Indrajaal.Core.FeatureFlagCalculator do
  @moduledoc """
  Calculation functions for feature flags.
  Separated to avoid macro expansion issues.
  """

  @spec is_enabled_for(any(), any()) :: any()
  def is_enabled_for(records, args) do
    Enum.map(records, fn flag ->
      cond do
        # Flag is globally disabled
        !flag.enabled ->
          false

        # 100% rollout
        flag.rollout_percentage == 100 ->
          true

        # 0% rollout but might have targeting rules
        flag.rollout_percentage == 0 && map_size(flag.targeting_rules) > 0 ->
          evaluate_targeting_rules(flag.targeting_rules, args.attributes)

        # Percentage - based rollout
        flag.rollout_percentage > 0 ->
          # Consistent hash - based rollout
          hash = :erlang.phash2({flag.id, args.user_id}, 100)

          # Check targeting rules first
          if map_size(flag.targeting_rules) > 0 &&
               evaluate_targeting_rules(
                 flag.targeting_rules,
                 args.attributes
               ) do
            true
          else
            hash < flag.rollout_percentage
          end

        true ->
          false
      end
    end)
  end

  @doc false
  @spec evaluate_targeting_rules(any(), any()) :: any()
  def evaluate_targeting_rules(rules, attributes) do
    Enum.any?(rules, fn {_name, rule} ->
      case rule do
        %{"type" => "attribute", "attribute" => attr, "operator" => op, "value" => val} ->
          evaluate_attribute_rule(Map.get(attributes, attr), op, val)

        %{"type" => "group", "groups" => groups} ->
          Enum.member?(groups, Map.get(attributes, "group"))

        _ ->
          false
      end
    end)
  end

  defp evaluate_attribute_rule(attr_value, "equals", value),
    do: attr_value == value

  defp evaluate_attribute_rule(attr_value, "not_equals", value),
    do: attr_value != value

  defp evaluate_attribute_rule(attr_value, "contains", value) when is_list(attr_value),
    do: Enum.member?(attr_value, value)

  defp evaluate_attribute_rule(attr_value, "contains", value) when is_binary(attr_value),
    do: String.contains?(attr_value, value)

  defp evaluate_attribute_rule(_, _, _), do: false
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Core
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
