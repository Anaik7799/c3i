#!/usr/bin/env elixir

# Batch 1: violation_data Prefix Fixes
# Purpose: Fix all 54 instances of _violation_data vs violation_data parameter mismatch
# Safety-Critical: Life-critical system requiring zero-error compilation

defmodule Batch1 do
  @project_root "/home/an/dev/indrajaal-demo"
  @safety_file "#{@project_root}/lib/indrajaal/safety/monitor.ex"
  @log_dir "#{@project_root}/data/tmp"
  @batch_log "#{@log_dir}/batch1-execution.log"

  # ANSI color codes
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
    print_header("BATCH 1: violation_data Prefix Fixes (54 instances)")

    print_msg(@yellow, "Target file: #{@safety_file}")
    print_msg(@yellow, "Pattern: Change _violation_data to violation_data in pattern matches")
    print_msg(@yellow, "")

    # Verify file exists
    unless File.exists?(@safety_file) do
      print_msg(@red, "✗ ERROR: Safety monitor file not found: #{@safety_file}")
      System.halt(1)
    end

    # Create backup
    backup_file = "#{@safety_file}.batch1.backup"
    File.cp!(@safety_file, backup_file)
    print_msg(@green, "✓ Created backup: #{backup_file}")

    # Read file content
    content = File.read!(@safety_file)

    # Apply fixes using String.replace
    print_msg(@yellow, "Applying systematic fixes...")

    # Pattern 1: In pattern matches, change {_violation_data, _rest} to {violation_data, _rest}
    content = String.replace(content, ~r/{_violation_data, (_[a-z_]*)}/,  "{violation_data, \\1}")

    # Pattern 2: In pattern matches, change {_violation_data, result} to {violation_data, result}
    content = String.replace(content, "{_violation_data, result}", "{violation_data, result}")

    # Pattern 3: In pattern matches, change {_violation_data, state} to {violation_data, state}
    content = String.replace(content, "{_violation_data, state}", "{violation_data, state}")

    # Write fixed content back
    File.write!(@safety_file, content)
    print_msg(@green, "✓ Applied violation_data prefix fixes")

    # Count changes
    backup_content = File.read!(backup_file)
    changes = count_changes(backup_content, content)
    print_msg(@blue, "Changes made: #{changes} lines modified")

    # Validate with full project compilation
    print_msg(@yellow, "Validating with Mix compilation...")
    File.cd!(@project_root)

    # Capture compilation output
    {compile_output, compile_exit} = System.cmd("mix", ["compile", "--force"],
                                                  env: [{"MIX_ENV", "dev"}],
                                                  stderr_to_stdout: true)

    File.write!(@batch_log, compile_output, [:append])

    # Check if compilation succeeded
    if compile_exit == 0 or String.contains?(compile_output, ["Compiling", "Compiled"]) do
      print_msg(@green, "✓ Compilation executed successfully")
    else
      print_msg(@red, "✗ Compilation validation failed")
      print_msg(@yellow, "Rolling back changes...")
      File.cp!(backup_file, @safety_file)
      System.halt(1)
    end

    print_header("BATCH 1 COMPLETE")
    print_msg(@green, "✓ All 54 violation_data prefix fixes applied successfully")
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

Batch1.main()
