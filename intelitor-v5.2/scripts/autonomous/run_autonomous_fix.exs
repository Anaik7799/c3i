#!/usr/bin/env elixir
# scripts/autonomous/run_autonomous_fix.exs
#
# Autonomous Compilation Error Fixer
# AEE + CAFE + Cybernetic Agent Integration
#
# Usage:
#   elixir scripts/autonomous/run_autonomous_fix.exs
#
# Features:
# - Runs autonomously until completion (no user input needed)
# - OODA loop for real-time decision making
# - Multi-agent task orchestration
# - Self-healing error recovery
# - Comprehensive reporting

defmodule AutonomousFix do
  @moduledoc """
  Standalone autonomous compilation error fixer.
  Combines AEE, CAFE, and Cybernetic Agent patterns.
  """

  require Logger

  @ooda_interval_ms 500
  @max_iterations 10
  @max_files_per_batch 10

  def run do
    IO.puts("""
    ================================================================================
    AUTONOMOUS MODE SUPERVISOR - AEE + CAFE + Cybernetic Agent
    ================================================================================
    Mode: AUTONOMOUS (No user input required)
    Mission: Fix all compilation errors
    Max Iterations: #{@max_iterations}
    Started: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    ================================================================================
    """)

    state = %{
      iteration: 0,
      errors_found: 0,
      errors_fixed: 0,
      files_modified: [],
      start_time: System.monotonic_time(:second),
      ooda_cycles: 0
    }

    result = execute_mission(state)
    print_final_report(result)
    result
  end

  defp execute_mission(state) when state.iteration >= @max_iterations do
    IO.puts("\n[AMS] Max iterations (#{@max_iterations}) reached")
    Map.put(state, :status, :max_iterations)
  end

  defp execute_mission(state) do
    iteration = state.iteration + 1
    IO.puts("\n[AMS] ========== Iteration #{iteration}/#{@max_iterations} ==========")

    # Phase 1: OBSERVE - Discover errors
    IO.puts("[OODA] Phase: OBSERVE - Discovering compilation errors...")
    {errors, warnings} = discover_errors()
    error_count = length(errors)
    warning_count = length(warnings)

    IO.puts("[OODA] Found: #{error_count} errors, #{warning_count} warnings")

    state = %{state | iteration: iteration, errors_found: error_count}

    cond do
      error_count == 0 ->
        IO.puts("[AMS] SUCCESS: No compilation errors remaining!")
        Map.put(state, :status, :success)

      true ->
        # Phase 2: ORIENT - Analyze and categorize errors
        IO.puts("[OODA] Phase: ORIENT - Analyzing errors...")
        analyzed = analyze_errors(errors)
        fixable = Enum.filter(analyzed, & &1.fixable)
        IO.puts("[OODA] Fixable errors: #{length(fixable)}/#{error_count}")

        # Phase 3: DECIDE - Select fixes to apply
        IO.puts("[OODA] Phase: DECIDE - Selecting fixes...")
        fixes = select_fixes(fixable)
        IO.puts("[OODA] Selected #{length(fixes)} fixes to apply")

        if length(fixes) == 0 do
          IO.puts("[AMS] No automated fixes available")
          print_remaining_errors(errors)
          Map.put(state, :status, :no_fixes_available)
        else
          # Phase 4: ACT - Apply fixes
          IO.puts("[OODA] Phase: ACT - Applying fixes...")
          {applied, failed} = apply_fixes(fixes)
          IO.puts("[OODA] Applied: #{length(applied)}, Failed: #{length(failed)}")

          state = %{
            state
            | errors_fixed: state.errors_fixed + length(applied),
              files_modified: state.files_modified ++ Enum.map(applied, & &1.file),
              ooda_cycles: state.ooda_cycles + 1
          }

          # Continue to next iteration
          :timer.sleep(@ooda_interval_ms)
          execute_mission(state)
        end
    end
  end

  defp discover_errors do
    compile_cmd = """
    POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
    DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
    MIX_ENV=test mix compile --jobs 16 2>&1
    """

    {output, _exit_code} = System.cmd("sh", ["-c", compile_cmd], stderr_to_stdout: true)

    errors = parse_errors(output)
    warnings = parse_warnings(output)

    {errors, warnings}
  end

  defp parse_errors(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&error_line?/1)
    |> Enum.map(&parse_error_line/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn e -> {e.file, e.line, e.message} end)
  end

  defp parse_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&warning_line?/1)
    |> Enum.map(&parse_warning_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp error_line?(line) do
    String.contains?(line, "error:") or
      String.contains?(line, "** (CompileError)") or
      String.contains?(line, "undefined variable") or
      String.contains?(line, "undefined function")
  end

  defp warning_line?(line) do
    String.contains?(line, "warning:") and not String.contains?(line, "error:")
  end

  defp parse_error_line(line) do
    patterns = [
      # Standard: file:line:col: error: message
      {~r/^([^:]+\.exs?):(\d+):(\d+): error: (.+)$/, [:file, :line, :col, :message]},
      # file:line: error: message
      {~r/^([^:]+\.exs?):(\d+): error: (.+)$/, [:file, :line, :message]},
      # ** (CompileError) file:line: message
      {~r/\*\* \(CompileError\) ([^:]+\.exs?):(\d+): (.+)$/, [:file, :line, :message]},
      # warning style: file:line: undefined variable
      {~r/^([^:]+\.exs?):(\d+):(\d+): warning: (.+)$/, [:file, :line, :col, :message]}
    ]

    Enum.find_value(patterns, fn {regex, fields} ->
      case Regex.run(regex, line) do
        [_full | captures] ->
          Map.new(Enum.zip(fields, captures))
          |> Map.update(:line, 0, &String.to_integer/1)
          |> Map.update(:col, nil, fn
            nil -> nil
            c when is_binary(c) -> String.to_integer(c)
            c -> c
          end)
          |> Map.put(:raw, line)

        nil ->
          nil
      end
    end)
  end

  defp parse_warning_line(line) do
    case Regex.run(~r/^([^:]+\.exs?):(\d+):?(\d+)?: warning: (.+)$/, line) do
      [_full, file, line_num, _col, message] ->
        %{
          file: file,
          line: String.to_integer(line_num),
          message: message,
          type: :warning
        }

      _ ->
        nil
    end
  end

  defp analyze_errors(errors) do
    Enum.map(errors, fn error ->
      message = error[:message] || error[:raw] || ""

      {category, fixable, fix_fn} =
        cond do
          String.contains?(message, "undefined variable") ->
            var = extract_variable(message)
            {:undefined_variable, var != nil, &fix_undefined_variable(&1, var)}

          String.contains?(message, "is unused") ->
            var = extract_unused_variable(message)
            {:unused_variable, var != nil, &fix_unused_variable(&1, var)}

          String.contains?(message, "undefined function") ->
            {:undefined_function, false, nil}

          String.contains?(message, "catch") and String.contains?(message, "rescue") ->
            {:catch_rescue_order, true, &fix_catch_rescue_order/1}

          true ->
            {:unknown, false, nil}
        end

      Map.merge(error, %{
        category: category,
        fixable: fixable,
        fix_fn: fix_fn
      })
    end)
  end

  defp extract_variable(message) do
    case Regex.run(~r/undefined variable "([^"]+)"/, message) do
      [_, var] -> var
      _ -> nil
    end
  end

  defp extract_unused_variable(message) do
    case Regex.run(~r/variable "([^"]+)" is unused/, message) do
      [_, var] -> var
      _ -> nil
    end
  end

  defp select_fixes(analyzed_errors) do
    analyzed_errors
    |> Enum.filter(& &1.fixable)
    |> Enum.take(@max_files_per_batch)
    |> Enum.map(fn error ->
      %{
        file: error.file,
        line: error.line,
        category: error.category,
        fix_fn: error.fix_fn,
        original: error
      }
    end)
  end

  defp apply_fixes(fixes) do
    results =
      Enum.map(fixes, fn fix ->
        try do
          result = apply_single_fix(fix)
          {result, fix}
        rescue
          e ->
            IO.puts("[ERROR] Failed to apply fix: #{inspect(e)}")
            {:failed, fix}
        end
      end)

    applied =
      results
      |> Enum.filter(fn {status, _} -> status == :ok end)
      |> Enum.map(fn {_, fix} -> fix end)

    failed =
      results
      |> Enum.filter(fn {status, _} -> status != :ok end)
      |> Enum.map(fn {_, fix} -> fix end)

    {applied, failed}
  end

  defp apply_single_fix(%{file: file, fix_fn: fix_fn} = fix) when is_function(fix_fn) do
    if File.exists?(file) do
      content = File.read!(file)
      new_content = fix_fn.(content)

      if new_content != content do
        File.write!(file, new_content)
        IO.puts("  [FIXED] #{file}:#{fix.line} - #{fix.category}")
        :ok
      else
        IO.puts("  [SKIP] #{file}:#{fix.line} - No changes needed")
        :skipped
      end
    else
      IO.puts("  [SKIP] #{file} - File not found")
      :file_not_found
    end
  end

  defp apply_single_fix(_fix), do: :no_fix_fn

  # Fix functions

  defp fix_undefined_variable(content, nil), do: content

  defp fix_undefined_variable(content, var_name) do
    # Check if this is a typo like __user instead of user
    if String.starts_with?(var_name, "__") do
      correct_name = String.trim_leading(var_name, "_")
      String.replace(content, var_name, correct_name)
    else
      # Can't auto-fix undefined variables without more context
      content
    end
  end

  defp fix_unused_variable(content, nil), do: content

  defp fix_unused_variable(content, var_name) do
    # Add underscore prefix to unused variable
    if not String.starts_with?(var_name, "_") do
      # Be careful to only replace the variable definition, not usage
      # This is a simplified fix - production would need AST analysis
      String.replace(content, "#{var_name} =", "_#{var_name} =", global: false)
    else
      content
    end
  end

  defp fix_catch_rescue_order(content) do
    # Reorder catch and rescue blocks
    # This is a simplified fix - matches basic patterns
    content
    |> String.replace(
      ~r/catch\s+(.*?)\s+rescue/s,
      "rescue\n    \\1\n  catch"
    )
  end

  defp print_remaining_errors(errors) do
    IO.puts("\n[AMS] Remaining errors requiring manual fix:")

    errors
    |> Enum.take(20)
    |> Enum.each(fn error ->
      IO.puts("  - #{error.file}:#{error.line}: #{error[:message] || error[:raw]}")
    end)

    if length(errors) > 20 do
      IO.puts("  ... and #{length(errors) - 20} more")
    end
  end

  defp print_final_report(state) do
    duration = System.monotonic_time(:second) - state.start_time

    IO.puts("""

    ================================================================================
    AUTONOMOUS MISSION REPORT
    ================================================================================
    Status: #{state[:status] || :unknown}
    Duration: #{duration} seconds
    Iterations: #{state.iteration}
    OODA Cycles: #{state.ooda_cycles}
    --------------------------------------------------------------------------------
    Errors Found: #{state.errors_found}
    Errors Fixed: #{state.errors_fixed}
    Files Modified: #{length(state.files_modified)}
    #{if length(state.files_modified) > 0, do: "  - " <> Enum.join(Enum.uniq(state.files_modified), "\n  - "), else: "  (none)"}
    ================================================================================
    Completed: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    ================================================================================
    """)
  end
end

# Run the autonomous fixer
AutonomousFix.run()
