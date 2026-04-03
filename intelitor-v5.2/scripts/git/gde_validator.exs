#!/usr/bin/env elixir

defmodule GDEValidator do
  @moduledoc "Goal-Driven Engineering validation for git operations"

  @spec validate_goal_alignment(any(), any()) :: any()
  def validate_goal_alignment(commit_message, branch_name) do
    IO.puts("🎯 Validating GDE goal alignment...")

    # Extract goal references from commit or branch
    goal_references = extract_goal_references(commit_message, branch_name)

    if length(goal_references) > 0 do
      IO.puts("  🎯 Goal references found: #{Enum.join(goal_references, ", ")}")

      # Validate each goal reference
      invalid_goals = Enum.filter(goal_references, fn goal ->
        not validate_goal_exists(goal)
      end)

      if length(invalid_goals) == 0 do
        IO.puts("  ✅ All goal references are valid")
        true
      else
        IO.puts("  ❌ Invalid goal references:")
        Enum.each(invalid_goals, fn goal ->
          IO.puts("    - #{goal}")
        end)
        false
      end
    else
      IO.puts("  ℹ️  No explicit goal references found")

      # Check if this is a goal-critical branch
      if is_goal_critical_branch(branch_name) do
        IO.puts("  ⚠️  Goal-critical branch should reference specific goals")
        false
      else
        true
      end
    end
  end

  @spec extract_goal_references(term(), term()) :: term()
  defp extract_goal_references(commit_message, branch_name) do
    # Extract goal IDs (G1.1, G2.3, etc.)
    goal_pattern = ~r/G\d+\.\d+/

    commit_goals = Regex.scangoal_pattern, commit_message |> Enum.map(fn [goal] -> goal end)

    branch_goals = Regex.scangoal_pattern, branch_name |> Enum.map(fn [goal] -> goal end)

    commit_goals ++ branch_goals |> Enum.uniq()
  end

  @spec validate_goal_exists(term()) :: term()
  defp validate_goal_exists(goal_id) do
    # Check if goal exists in goal registry
    goal_file = "docs/gde/goals/#{goal_id}.md"
    File.exists?(goal_file)
  end

  @spec is_goal_critical_branch(term()) :: term()
  defp is_goal_critical_branch(branch_name) do
    critical_patterns = [
      "feature/goal-",
      "feature/g\d",
      "develop/goal-",
      "critical/goal-"
    ]

    Enum.any?(critical_patterns, fn pattern ->
      String.contains?(String.downcase(branch_name), String.downcase(pattern))
    end)
  end

  @spec validate_success_metrics(any()) :: any()
  def validate_success_metrics(goal_id) do
    IO.puts("📊 Validating success metrics for #{goal_id}...")

    goal_file = "docs/gde/goals/#{goal_id}.md"

    if File.exists?(goal_file) do
      content = File.read!(goal_file)

      # Check for __required success metrics
      __required_sections = [
        "## Success Criteria",
        "## Measurement Methods",
        "## Progress Tracking"
      ]

      missing_sections = Enum.filter(__required_sections, fn section ->
        not String.contains?(content, section)
      end)

      if length(missing_sections) == 0 do
        IO.puts("  ✅ All __required sections present")
        true
      else
        IO.puts("  ❌ Missing sections:")
        Enum.each(missing_sections, fn section ->
          IO.puts("    - #{section}")
        end)
        false
      end
    else
      IO.puts("  ❌ Goal file not found: #{goal_file}")
      false
    end
  end
end
