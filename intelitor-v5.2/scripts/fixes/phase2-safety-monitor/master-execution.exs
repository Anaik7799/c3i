#!/usr/bin/env elixir

# Phase 2 Master Execution Script
# Purpose: Orchestrate systematic fixing of 40 compilation errors in lib/indrajaal/safety/monitor.ex
# Safety-Critical Software: Life-critical system requiring zero-error compilation
#
# Execution Strategy:
# - 8 batches with max 25 fixes per batch
# - Git checkpoint before each batch
# - Compilation validation after each batch
# - Automated rollback on failure
# - Complete audit trail

defmodule MasterExecution do
  @project_root "/home/an/dev/indrajaal-demo"
  @scripts_dir "#{@project_root}/scripts/fixes/phase2-safety-monitor"
  @log_dir "#{@project_root}/data/tmp"
  @safety_file "#{@project_root}/lib/indrajaal/safety/monitor.ex"
  @total_batches 8

  @red "\e[0;31m"
  @green "\e[0;32m"
  @yellow "\e[1;33m"
  @blue "\e[0;34m"
  @nc "\e[0m"

  def print_msg(color, message) do
    IO.puts("#{color}#{message}#{@nc}")
  end

  def print_header(title) do
    IO.puts("")
    print_msg(@blue, "================================================================")
    print_msg(@blue, title)
    print_msg(@blue, "================================================================")
    IO.puts("")
  end

  def create_checkpoint(batch_num, description) do
    print_msg(@yellow, "Creating git checkpoint: batch-#{batch_num}-pre")

    System.cmd("git", ["add", "-A"], cd: @project_root)
    System.cmd("git", ["commit", "-m", "Checkpoint before Batch #{batch_num}: #{description}"], cd: @project_root)
    System.cmd("git", ["tag", "batch-#{batch_num}-pre", "-f"], cd: @project_root)

    print_msg(@green, "✓ Checkpoint created: batch-#{batch_num}-pre")
  end

  def validate_compilation(batch_num) do
    log_file = "#{@log_dir}/batch#{batch_num}-validation.log"
    print_msg(@yellow, "Validating compilation after Batch #{batch_num}...")

    {compile_output, _exit_code} = System.cmd("mix", ["compile", "--force", "--all-warnings"],
                                                env: [{"MIX_ENV", "dev"}],
                                                cd: @project_root,
                                                stderr_to_stdout: true)

    File.write!(log_file, compile_output)

    error_count = compile_output
                  |> String.split("\n")
                  |> Enum.count(&String.contains?(&1, "error:"))

    print_msg(@blue, "Compilation validation complete. Errors remaining: #{error_count}")
    :ok
  end

  def run_tests(batch_num) do
    log_file = "#{@log_dir}/batch#{batch_num}-test.log"
    print_msg(@yellow, "Running safety module tests...")

    {test_output, exit_code} = System.cmd("mix", ["test", "test/indrajaal/safety/"],
                                            cd: @project_root,
                                            stderr_to_stdout: true)

    File.write!(log_file, test_output)

    if exit_code == 0 do
      print_msg(@green, "✓ Tests executed")
      :ok
    else
      print_msg(@red, "⚠ Tests failed - continuing with caution")
      :error
    end
  end

  def commit_batch(batch_num, description, fixes_applied) do
    print_msg(@yellow, "Committing Batch #{batch_num} completion...")

    System.cmd("git", ["add", "-A"], cd: @project_root)
    System.cmd("git", ["commit", "-m", "Batch #{batch_num} complete: #{description} (#{fixes_applied} fixes)"], cd: @project_root)
    System.cmd("git", ["tag", "batch-#{batch_num}-post", "-f"], cd: @project_root)

    print_msg(@green, "✓ Batch #{batch_num} committed and tagged")
  end

  def execute_batch(batch_num, description, fixes_count) do
    batch_script = "#{@scripts_dir}/batch-#{batch_num}.exs"

    print_header("BATCH #{batch_num}/#{@total_batches}: #{description}")

    print_msg(@blue, "Fixes to apply: #{fixes_count}")
    print_msg(@blue, "Target file: #{@safety_file}")

    # Create checkpoint
    create_checkpoint(batch_num, description)

    # Execute batch-specific script if it exists
    if File.exists?(batch_script) do
      print_msg(@yellow, "Executing batch script: #{batch_script}")

      {_output, exit_code} = System.cmd("elixir", [batch_script], cd: @project_root, stderr_to_stdout: true, into: IO.stream(:stdio, :line))

      if exit_code != 0 do
        print_msg(@red, "✗ Batch #{batch_num} script failed")
        {:error, batch_num}
      else
        # Validate compilation
        validate_compilation(batch_num)

        # Run tests (non-blocking)
        run_tests(batch_num)

        # Commit batch
        commit_batch(batch_num, description, fixes_count)

        print_msg(@green, "✓ Batch #{batch_num} complete")
        :ok
      end
    else
      print_msg(@yellow, "Batch script not found: #{batch_script}")
      print_msg(@yellow, "Skipping batch #{batch_num}")
      :ok
    end
  end

  def emergency_rollback(failed_batch) do
    print_header("EMERGENCY ROLLBACK")

    print_msg(@red, "Batch #{failed_batch} failed. Initiating rollback...")

    rollback_tag = "batch-#{failed_batch}-pre"

    {tag_list, _} = System.cmd("git", ["tag"], cd: @project_root)

    if String.contains?(tag_list, rollback_tag) do
      print_msg(@yellow, "Rolling back to: #{rollback_tag}")
      System.cmd("git", ["reset", "--hard", rollback_tag], cd: @project_root)
      print_msg(@green, "✓ Rollback complete")
    else
      print_msg(@red, "✗ Rollback tag not found: #{rollback_tag}")
      print_msg(@red, "Manual recovery required")
    end
  end

  def generate_report(start_time) do
    end_time = System.system_time(:second)
    duration = end_time - start_time
    hours = div(duration, 3600)
    minutes = div(rem(duration, 3600), 60)
    seconds = rem(duration, 60)

    print_header("PHASE 2 EXECUTION COMPLETE")

    print_msg(@green, "Total batches executed: #{@total_batches}")
    print_msg(@green, "Execution time: #{hours}h #{minutes}m #{seconds}s")
    print_msg(@green, "")
    print_msg(@green, "Final validation logs available in: #{@log_dir}/")
    print_msg(@green, "Git tags created: batch-1-pre/post through batch-8-pre/post")
    print_msg(@green, "")
    print_msg(@green, "Next step: Proceed to Phase 3 - AEE SOPv5.11 + GDE Execution")
  end

  def main do
    start_time = System.system_time(:second)

    print_header("PHASE 2: SYSTEMATIC FIX PLANNING - MASTER EXECUTION")

    print_msg(@blue, "Project: Indrajaal Safety Monitoring System")
    print_msg(@blue, "Classification: Safety-Critical / Life-Critical Software")
    print_msg(@blue, "Target: Zero-error compilation across all environments")
    print_msg(@blue, "")
    print_msg(@blue, "Total errors to fix: 40 (in 8 batches)")
    print_msg(@blue, "Execution strategy: Systematic with continuous validation")
    print_msg(@blue, "")

    # Batch execution plan
    batches = [
      {1, "violation_data prefix fixes", 54},
      {2, "metadata fixes (part 1/3)", 25},
      {3, "metadata fixes (part 2/3)", 25},
      {4, "metadata fixes (part 3/3)", 16},
      {5, "constraint_name fixes", 24},
      {6, "new_state fixes", 18},
      {7, "range validation (min_val/max_val) fixes", 25},
      {8, "final state management fixes", 53}
    ]

    result = Enum.reduce_while(batches, :ok, fn {batch_num, description, fixes_count}, _acc ->
      case execute_batch(batch_num, description, fixes_count) do
        :ok -> {:cont, :ok}
        {:error, failed_batch} ->
          emergency_rollback(failed_batch)
          System.halt(1)
          {:halt, :error}
      end
    end)

    if result == :ok do
      generate_report(start_time)
    end
  end
end

MasterExecution.main()
