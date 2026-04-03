#!/usr/bin/env elixir

# ═══════════════════════════════════════════════════════════════════════════════
# DEPRECATED - SPRINT 45 MIGRATION
# ═══════════════════════════════════════════════════════════════════════════════
#
# This script has been superseded by the F# Planning CLI (Cepaf.Planning.CLI).
#
# NEW VALIDATION:
#   - The F# Planning CLI validates tasks on add/update operations
#   - SQLite persistence ensures data integrity
#   - Use: sa-plan list to verify task state
#
# See CLAUDE.md Section 6.0 "Planning & Task Management" for details.
#
# MIGRATION DATE: 2026-01-14
#
# ═══════════════════════════════════════════════════════════════════════════════
# INTELITOR TODO RULES VALIDATOR (LEGACY)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Validates PROJECT_TODOLIST.md against STAMP and AOR constraints.
#
# STAMP Constraints (SC-TODO-STATIC):
# - SC-TODO-003: All tasks SHALL have a unique ID and valid Status.
# - SC-TODO-004: Parent-Child relationships SHALL NOT form cycles.
# - SC-TODO-006: All tasks SHALL have a Priority (P0-P3).
# - SC-TODO-007: Completed parents SHALL have all children completed.
#
# Usage: elixir scripts/validation/todo_rules_validator.exs
# ═══════════════════════════════════════════════════════════════════════════════

# NOTE: This requires the archived todolist_manager.exs - script is deprecated
# Code.require_file("scripts/planning/todolist_manager.exs")
IO.puts("⚠️  DEPRECATED: This script has been replaced by the F# Planning CLI.")
IO.puts("   Use 'sa-plan list' or 'chaya-tasks' instead.")
IO.puts("   See CLAUDE.md Section 6.0 for new commands.")
System.halt(0)

defmodule TodoRulesValidator do
  def validate do
    IO.puts("🛡️  STARTING TODO RULES VALIDATION (STAMP/AOR)...")
    
    file_path = "PROJECT_TODOLIST.md"
    if not File.exists?(file_path) do
      IO.puts("❌ ERROR: PROJECT_TODOLIST.md not found.")
      System.halt(1)
    end

    content = File.read!(file_path)
    tasks = TodolistManager.parse_tasks(content)
    
    errors = []
    |> validate_unique_ids(tasks)
    |> validate_mandatory_fields(tasks)
    |> validate_hierarchy(tasks)
    |> validate_completion_consistency(tasks)

    if errors == [] do
      IO.puts("✅ VALIDATION SUCCESS: Todo list complies with all rules.")
      System.halt(0)
    else
      IO.puts("\n❌ VALIDATION FAILED (#{length(errors)} errors):")
      Enum.each(errors, fn err -> IO.puts("  - #{err}") end)
      System.halt(1)
    end
  end

  defp validate_unique_ids(errors, tasks) do
    ids = Enum.map(tasks, & &1.id)
    duplicates = ids -- Enum.uniq(ids)
    
    if duplicates != [] do
      ["SC-TODO-003: Duplicate Task IDs found: #{Enum.join(Enum.uniq(duplicates), ", ")} " | errors]
    else
      errors
    end
  end

  defp validate_mandatory_fields(errors, tasks) do
    tasks
    |> Enum.reduce(errors, fn task, acc ->
      acc
      |> check_field(task, :status, "SC-TODO-003")
      |> check_field(task, :priority, "SC-TODO-006")
    end)
  end

  defp check_field(acc, task, field, rule_id) do
    value = Map.get(task, field)
    if is_nil(value) or String.trim(value) == "" do
      ["#{rule_id}: Task #{task.id} missing mandatory field '#{field}'" | acc]
    else
      acc
    end
  end

  defp validate_hierarchy(errors, tasks) do
    # Check for cycles and valid parents
    id_set = MapSet.new(Enum.map(tasks, & &1.id))
    
    tasks
    |> Enum.reduce(errors, fn task, acc ->
      if not is_nil(task.parent) and task.parent not in ["", "0", "0.0"] do
        if not MapSet.member?(id_set, task.parent) do
          ["SC-TODO-004: Task #{task.id} references non-existent parent '#{task.parent}'" | acc]
        else
          # Simple cycle check: Parent cannot be same as ID (deeper cycles require graph traversal, simplified for now)
          if task.parent == task.id do
             ["SC-TODO-004: Task #{task.id} is its own parent (Cycle detected)" | acc]
          else
             acc
          end
        end
      else
        acc
      end
    end)
  end

  defp validate_completion_consistency(errors, tasks) do
    # SC-TODO-007: If parent is completed, all children must be completed
    
    # 1. Group children by parent
    children_map = Enum.group_by(tasks, & &1.parent)
    
    tasks
    |> Enum.filter(fn t -> t.status == "completed" end)
    |> Enum.reduce(errors, fn parent, acc ->
      children = Map.get(children_map, parent.id, [])
      
      incomplete_children = Enum.filter(children, fn child -> 
        child.status != "completed"
      end)
      
      if incomplete_children != [] do
        ids = Enum.map(incomplete_children, & &1.id) |> Enum.join(", ")
        ["SC-TODO-007: Parent #{parent.id} is completed but has incomplete children: #{ids}" | acc]
      else
        acc
      end
    end)
  end
end

TodoRulesValidator.validate()
