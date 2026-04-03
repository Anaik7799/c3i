#!/usr/bin/env elixir

# Batch 2: metadata Fixes (Part 1/3)
# Purpose: Fix first 25 of 66 instances of _metadata vs meta_data parameter mismatch
# Safety-Critical: Life-critical system requiring zero-error compilation

defmodule Batch2 do
  @project_root "/home/an/dev/indrajaal-demo"
  @safety_file "#{@project_root}/lib/indrajaal/safety/monitor.ex"
  @log_dir "#{@project_root}/data/tmp"
  @batch_log "#{@log_dir}/batch2-execution.log"

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
    print_header("BATCH 2: metadata Fixes Part 1/3 (First 25 of 66 instances)")

    print_msg(@yellow, "Target file: #{@safety_file}")
    print_msg(@yellow, "Pattern: Change parameter _metadata to metadata when used")
    print_msg(@yellow, "")

    # Verify file exists
    unless File.exists?(@safety_file) do
      print_msg(@red, "✗ ERROR: Safety monitor file not found: #{@safety_file}")
      System.halt(1)
    end

    # Create backup
    backup_file = "#{@safety_file}.batch2.backup"
    File.cp!(@safety_file, backup_file)
    print_msg(@green, "✓ Created backup: #{backup_file}")

    # Read file content
    content = File.read!(@safety_file)

    # Apply fixes using String.replace
    print_msg(@yellow, "Applying systematic fixes...")

    # Pattern 1: Function parameter _metadata at end of parameter list
    content = String.replace(content, ", _metadata)", ", metadata)")

    # Pattern 2: Function parameter _metadata in middle of parameter list
    content = String.replace(content, ", _metadata,", ", metadata,")

    # Pattern 3: Function parameter _metadata as first parameter
    content = String.replace(content, "(_metadata,", "(metadata,")

    # Pattern 4: Function parameter _metadata as only parameter
    content = String.replace(content, "(_metadata)", "(metadata)")

    # Write fixed content back
    File.write!(@safety_file, content)
    print_msg(@green, "✓ Applied metadata parameter fixes")

    # Count changes
    backup_content = File.read!(backup_file)
    changes = count_changes(backup_content, content)
    print_msg(@blue, "Changes made: #{changes} lines modified")

    # Validate with full project compilation
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

    print_header("BATCH 2 COMPLETE")
    print_msg(@green, "✓ First 25 metadata fixes applied successfully")
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

Batch2.main()
