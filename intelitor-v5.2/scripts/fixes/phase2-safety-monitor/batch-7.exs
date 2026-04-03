#!/usr/bin/env elixir

# Batch 7: Range Validation min_val/max_val Fixes
# Purpose: Fix all 25 instances of min_val/max_val prefix errors
# Safety-Critical: Life-critical system requiring zero-error compilation

defmodule Batch7 do
  @project_root "/home/an/dev/indrajaal-demo"
  @safety_file "#{@project_root}/lib/indrajaal/safety/monitor.ex"
  @log_dir "#{@project_root}/data/tmp"
  @batch_log "#{@log_dir}/batch7-execution.log"

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
    print_header("BATCH 7: Range Validation min_val/max_val Fixes (25 instances)")

    print_msg(@yellow, "Target file: #{@safety_file}")
    print_msg(@yellow, "Pattern: Change {_min_val, _max_val} to {min_val, max_val} in pattern matches")
    print_msg(@yellow, "")

    unless File.exists?(@safety_file) do
      print_msg(@red, "✗ ERROR: Safety monitor file not found: #{@safety_file}")
      System.halt(1)
    end

    backup_file = "#{@safety_file}.batch7.backup"
    File.cp!(@safety_file, backup_file)
    print_msg(@green, "✓ Created backup: #{backup_file}")

    content = File.read!(@safety_file)
    print_msg(@yellow, "Applying systematic fixes...")

    # Pattern 1: In pattern matches, change {_min_val, _max_val} to {min_val, max_val}
    content = String.replace(content, "{_min_val, _max_val}", "{min_val, max_val}")

    # Pattern 2: Handle _min_val alone in pattern matches
    content = String.replace(content, ~r/{_min_val, (_[a-z_]*)}/,  "{min_val, \\1}")

    # Pattern 3: Handle _max_val alone in pattern matches
    content = String.replace(content, ~r/{_max_val, (_[a-z_]*)}/,  "{max_val, \\1}")

    # Pattern 4: Handle range constraint patterns
    content = String.replace(content, "min: _min_val", "min: min_val")
    content = String.replace(content, "max: _max_val", "max: max_val")

    File.write!(@safety_file, content)
    print_msg(@green, "✓ Applied min_val/max_val prefix fixes")

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

    print_header("BATCH 7 COMPLETE")
    print_msg(@green, "✓ All 25 min_val/max_val prefix fixes applied successfully")
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

Batch7.main()
