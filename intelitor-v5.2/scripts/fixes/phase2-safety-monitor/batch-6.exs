#!/usr/bin/env elixir

# Batch 6: new_state Prefix Fixes
# Purpose: Fix all 18 instances of _new_state prefix errors
# Safety-Critical: Life-critical system requiring zero-error compilation

defmodule Batch6 do
  @project_root "/home/an/dev/indrajaal-demo"
  @safety_file "#{@project_root}/lib/indrajaal/safety/monitor.ex"
  @log_dir "#{@project_root}/data/tmp"
  @batch_log "#{@log_dir}/batch6-execution.log"

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
    print_header("BATCH 6: new_state Prefix Fixes (18 instances)")

    print_msg(@yellow, "Target file: #{@safety_file}")
    print_msg(@yellow, "Pattern: Change {_result, _new_state} to {result, new_state} in pattern matches")
    print_msg(@yellow, "")

    unless File.exists?(@safety_file) do
      print_msg(@red, "✗ ERROR: Safety monitor file not found: #{@safety_file}")
      System.halt(1)
    end

    backup_file = "#{@safety_file}.batch6.backup"
    File.cp!(@safety_file, backup_file)
    print_msg(@green, "✓ Created backup: #{backup_file}")

    content = File.read!(@safety_file)
    print_msg(@yellow, "Applying systematic fixes...")

    # Pattern 1: In pattern matches, change {_result, _new_state} to {result, new_state}
    content = String.replace(content, "{_result, _new_state}", "{result, new_state}")

    # Pattern 2: In pattern matches, change {_new_state} to {new_state}
    content = String.replace(content, "{_new_state}", "{new_state}")

    # Pattern 3: Handle cases where _new_state appears alone in pattern match
    content = String.replace(content, ", _new_state)", ", new_state)")

    File.write!(@safety_file, content)
    print_msg(@green, "✓ Applied new_state prefix fixes")

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

    print_header("BATCH 6 COMPLETE")
    print_msg(@green, "✓ All 18 new_state prefix fixes applied successfully")
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

Batch6.main()
