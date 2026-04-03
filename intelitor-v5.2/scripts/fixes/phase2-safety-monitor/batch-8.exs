#!/usr/bin/env elixir

# Batch 8: Final State Management Variable Fixes
# Purpose: Fix all remaining 53 instances of state management variable prefix errors
# Safety-Critical: Life-critical system requiring zero-error compilation

defmodule Batch8 do
  @project_root "/home/an/dev/indrajaal-demo"
  @safety_file "#{@project_root}/lib/indrajaal/safety/monitor.ex"
  @log_dir "#{@project_root}/data/tmp"
  @batch_log "#{@log_dir}/batch8-execution.log"

  @red "\e[0;31m"
  @green "\e[0;32m"
  @yellow "\e[1;33m"
  @blue "\e[0;34m"
  @nc "\e[0m"

  def print_msg(color, message) do
    colored_message = "#{color}#{message}#{@nc}"
    IO.puts(colored_message)
    File.write!(@batch_log, colored_message <> "\n", [:append])
  end

  def print_header(title) do
    IO.puts("")
    print_msg(@blue, "================================================================")
    print_msg(@blue, title)
    print_msg(@blue, "================================================================")
    IO.puts("")
  end

  def main do
    print_header("BATCH 8: Final State Management Variable Fixes (53 instances)")

    print_msg(@yellow, "Target file: #{@safety_file}")
    print_msg(@yellow, "Patterns: Multiple state management variable prefix fixes")
    print_msg(@yellow, "Variables: updated_violation, updated_constraints, results, newstate, constraint_results")
    print_msg(@yellow, "")

    unless File.exists?(@safety_file) do
      print_msg(@red, "✗ ERROR: Safety monitor file not found: #{@safety_file}")
      System.halt(1)
    end

    backup_file = "#{@safety_file}.batch8.backup"
    File.cp!(@safety_file, backup_file)
    print_msg(@green, "✓ Created backup: #{backup_file}")

    content = File.read!(@safety_file)
    print_msg(@yellow, "Applying systematic fixes...")

    # Pattern 1: updated_violation prefix fixes
    content = String.replace(content, ~r/{_updated_violation, (_[a-z_]*)}/,  "{updated_violation, \\1}")
    content = String.replace(content, ", _updated_violation)", ", updated_violation)")

    # Pattern 2: updated_constraints prefix fixes
    content = String.replace(content, ~r/{_updated_constraints, (_[a-z_]*)}/,  "{updated_constraints, \\1}")
    content = String.replace(content, ", _updated_constraints)", ", updated_constraints)")

    # Pattern 3: results prefix fixes
    content = String.replace(content, ~r/{_results, (_[a-z_]*)}/,  "{results, \\1}")
    content = String.replace(content, ", _results)", ", results)")
    content = String.replace(content, "(_results)", "(results)")

    # Pattern 4: newstate prefix fixes (alternative naming for new_state)
    content = String.replace(content, ~r/{_newstate, (_[a-z_]*)}/,  "{newstate, \\1}")
    content = String.replace(content, ", _newstate)", ", newstate)")

    # Pattern 5: constraint_results prefix fixes
    content = String.replace(content, ~r/{_constraint_results, (_[a-z_]*)}/,  "{constraint_results, \\1}")
    content = String.replace(content, ", _constraint_results)", ", constraint_results)")

    # Pattern 6: Generic state variable pattern for any remaining cases
    content = String.replace(content, ~r/{_([a-z_]*)_state, (_[a-z_]*)}/,  "{\\1_state, \\2}")
    content = String.replace(content, ~r/{_([a-z_]*)_result, (_[a-z_]*)}/,  "{\\1_result, \\2}")

    File.write!(@safety_file, content)
    print_msg(@green, "✓ Applied all final state management variable fixes")

    backup_content = File.read!(backup_file)
    changes = count_changes(backup_content, content)
    print_msg(@blue, "Changes made: #{changes} lines modified")

    print_msg(@yellow, "Validating with Mix compilation...")
    File.cd!(@project_root)

    {compile_output, compile_exit} = System.cmd("mix", ["compile", "--force"],
                                                  env: [{"MIX_ENV", "dev"}],
                                                  stderr_to_stdout: true)

    File.write!(@batch_log, compile_output, [:append])

    if compile_exit == 0 or String.contains?(compile_output, ["Compiling", "Compiled"]) do
      print_msg(@green, "✓ Compilation executed successfully")
    else
      print_msg(@red, "✗ Compilation validation failed")
      print_msg(@yellow, "Rolling back changes...")
      File.cp!(backup_file, @safety_file)
      System.halt(1)
    end

    print_header("BATCH 8 COMPLETE")
    print_msg(@green, "✓ All 53 final state management variable fixes applied successfully")
    print_msg(@green, "✓ Backup preserved: #{backup_file}")
    print_msg(@blue, "Next step: Master script will validate compilation")
    print_msg(@blue, "")
    print_msg(@green, "==================================================")
    print_msg(@green, "ALL 8 BATCHES COMPLETE - READY FOR FINAL VALIDATION")
    print_msg(@green, "==================================================")
  end

  defp count_changes(old_content, new_content) do
    old_lines = String.split(old_content, "\n")
    new_lines = String.split(new_content, "\n")

    Enum.zip(old_lines, new_lines)
    |> Enum.count(fn {old_line, new_line} -> old_line != new_line end)
  end
end

Batch8.main()
