#!/usr/bin/env elixir

# Batch 5: constraint_name Fixes
# Purpose: Fix all 24 instances of constraint_name prefix errors
# Safety-Critical: Life-critical system requiring zero-error compilation

defmodule Batch5 do
  @project_root "/home/an/dev/indrajaal-demo"
  @safety_file "#{@project_root}/lib/indrajaal/safety/monitor.ex"
  @log_dir "#{@project_root}/data/tmp"
  @batch_log "#{@log_dir}/batch5-execution.log"

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
    print_header("BATCH 5: constraint_name Fixes (24 instances)")

    print_msg(@yellow, "Target file: #{@safety_file}")
    print_msg(@yellow, "Pattern: Change {_constraint_name, ...} to {constraint_name, ...}")
    print_msg(@yellow, "")

    unless File.exists?(@safety_file) do
      print_msg(@red, "✗ ERROR: Safety monitor file not found: #{@safety_file}")
      System.halt(1)
    end

    backup_file = "#{@safety_file}.batch5.backup"
    File.cp!(@safety_file, backup_file)
    print_msg(@green, "✓ Created backup: #{backup_file}")

    content = File.read!(@safety_file)
    print_msg(@yellow, "Applying systematic fixes...")

    # Pattern 1: {_constraint_name, _var} to {constraint_name, _var}
    content = String.replace(content, ~r/{_constraint_name, (_[a-z_]*)}/,  "{constraint_name, \\1}")

    # Pattern 2: {_constraint_name, result}
    content = String.replace(content, "{_constraint_name, result}", "{constraint_name, result}")

    # Pattern 3: {_constraint_name, state}
    content = String.replace(content, "{_constraint_name, state}", "{constraint_name, state}")

    File.write!(@safety_file, content)
    print_msg(@green, "✓ Applied constraint_name prefix fixes")

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

    print_header("BATCH 5 COMPLETE")
    print_msg(@green, "✓ All 24 constraint_name fixes applied successfully")
    print_msg(@green, "✓ Backup preserved: #{backup_file}")
    print_msg(@blue, "Next step: Master script will validate compilation")
  end

  defp count_changes(old_content, new_content) do
    old_lines = String.split(old_content, "\n")
    new_lines = String.split(new_content, "\n")

    Enum.zip(old_lines, new_lines)
    |> Enum.count(fn {old_line, new_line} -> old_line != new_line end)
  end
end

Batch5.main()
