#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511Batch2WarningEliminator do
  @moduledoc """
  SOPv5.11 Batch 2: Systematic Warning Elimination

  Targets the remaining 3,152 warnings identified after Batch 1 success.
  Uses TPS Jidoka stop-and-fix methodology with 200-change limit.

  Focus: Unused variable warnings, function warnings, and structural issues
  """

  @max_changes 200
  @compile_log "2-compile.log"

  def main(args) do
    case args do
      ["--execute"] -> execute_batch_2_fixes()
      ["--analyze"] -> analyze_warning_patterns()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts """
    SOPv5.11 Batch 2 Warning Eliminator

    Usage:
      --execute    Apply systematic warning fixes with 200-change limit
      --analyze    Analyze warning patterns for strategic approach
    """
  end

  defp analyze_warning_patterns do
    IO.puts """
    🔍 SOPv5.11 BATCH 2 WARNING PATTERN ANALYSIS
    ==========================================
    """

    if File.exists?(@compile_log) do
      {output, _} = System.cmd("grep", ["warning:", @compile_log])
      warnings = String.split(output, "\n", trim: true)

      IO.puts "📊 Warning Analysis from #{@compile_log}:"
      IO.puts "  Total Warnings: #{length(warnings)}"

      # Analyze unused variable patterns
      unused_vars = analyze_unused_variables(warnings)
      unused_functions = analyze_unused_functions(warnings)

      IO.puts "\n🎯 Top Unused Variable Patterns:"
      unused_vars
      |> Enum.take(10)
      |> Enum.each(fn {pattern, count} ->
        IO.puts "  #{pattern}: #{count} occurrences"
      end)

      IO.puts "\n🎯 Unused Function Patterns:"
      unused_functions
      |> Enum.take(5)
      |> Enum.each(fn {pattern, count} ->
        IO.puts "  #{pattern}: #{count} occurrences"
      end)

    else
      IO.puts "❌ Warning log not found: #{@compile_log}"
      IO.puts "Please run compilation first to generate warning data"
    end
  end

  defp execute_batch_2_fixes do
    IO.puts """
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  SOPv5.11 BATCH 2: SYSTEMATIC WARNING ELIMINATION                  ║
    ║  🎯 TPS Jidoka: Stop-and-Fix with 200-Change Limit                 ║
    ║  🔧 Target: 3,152 remaining warnings (post Batch 1)                ║
    ╚═════════════════════════════════════════════════════════════════════╝
    """

    # Get warning data
    IO.puts "📸 Analyzing current warning state..."
    if not File.exists?(@compile_log) do
      IO.puts "❌ ERROR: Compilation log not found: #{@compile_log}"
      System.halt(1)
    end

    {warning_output, _} = System.cmd("grep", ["warning:", @compile_log])
    warnings = String.split(warning_output, "\n", trim: true)

    IO.puts "📊 Current warnings: #{length(warnings)}"

    # Analyze and prioritize fixes
    unused_vars = analyze_unused_variables(warnings)

    results = %{
      fixed: 0,
      files_modified: [],
      errors: []
    }

    # Apply systematic fixes in priority order
    results = apply_unused_variable_fixes(unused_vars, results)

    # Validation compilation
    IO.puts "🧪 Validating warning elimination..."
    validation_result = run_validation_compile()

    IO.puts """

    ✅ BATCH 2 WARNING ELIMINATION COMPLETE
    ======================================
    📊 Results:
      • Changes applied: #{results.fixed}/#{@max_changes}
      • Files modified: #{length(results.files_modified)}
      • Errors encountered: #{length(results.errors)}
      • Validation: #{if validation_result == :success, do: "PASSED", else: "NEEDS REVIEW"}

    🔄 Next: Git checkpoint and Batch 3 preparation
    """
  end

  defp analyze_unused_variables(warnings) do
    warnings
    |> Enum.filter(&String.contains?(&1, "is unused"))
    |> Enum.map(&extract_unused_variable/1)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp analyze_unused_functions(warnings) do
    warnings
    |> Enum.filter(&String.contains?(&1, "is unused"))
    |> Enum.filter(&String.contains?(&1, "function"))
    |> Enum.map(&extract_function_name/1)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp extract_unused_variable(warning_line) do
    case Regex.run(~r/variable "([^"]+)" is unused/, warning_line) do
      [_, var_name] -> var_name
      _ -> nil
    end
  end

  defp extract_function_name(warning_line) do
    case Regex.run(~r/function ([^\/]+)\/\d+ is unused/, warning_line) do
      [_, func_name] -> func_name
      _ -> nil
    end
  end

  defp apply_unused_variable_fixes(unused_vars, results) do
    IO.puts "🔧 Applying systematic unused variable fixes..."

    # Get top patterns to fix
    top_patterns = unused_vars |> Enum.take(20)

    Enum.reduce(top_patterns, results, fn {var_name, count}, acc ->
      if acc.fixed < @max_changes do
        IO.puts "  🎯 Fixing unused variable: #{var_name} (#{count} occurrences)"
        case fix_unused_variable_pattern(var_name) do
          {:ok, files_changed} ->
            %{acc |
              fixed: acc.fixed + count,
              files_modified: acc.files_modified ++ files_changed
            }
          {:error, reason} ->
            %{acc | errors: [reason | acc.errors]}
        end
      else
        acc
      end
    end)
  end

  defp fix_unused_variable_pattern(var_name) do
    try do
      # Find files containing this unused variable
      {grep_output, _} = System.cmd("grep", [
        "-r", "-l",
        "variable \"#{var_name}\" is unused",
        "lib/"
      ])

      files = String.split(grep_output, "\n", trim: true)

      changed_files = Enum.reduce(files, [], fn file_path, acc ->
        if File.exists?(file_path) do
          content = File.read!(file_path)

          # Apply underscore prefix fix
          updated_content = apply_underscore_fix(content, var_name)

          if updated_content != content do
            File.write!(file_path, updated_content)
            [file_path | acc]
          else
            acc
          end
        else
          acc
        end
      end)

      {:ok, changed_files}
    rescue
      e -> {:error, "Error processing #{var_name}: #{inspect(e)}"}
    end
  end

  defp apply_underscore_fix(content, var_name) do
    # Add underscore prefix to unused variable parameters
    # Pattern: def function_name(var_name) -> def function_name(_var_name)
    content
    |> String.replace(
      ~r/\b(def[p]?\s+\w+\([^)]*)\b#{var_name}\b([^)]*\))/,
      "\\1_#{var_name}\\2"
    )
    |> String.replace(
      ~r/\b(fn\s+[^-]*)\b#{var_name}\b([^-]*->)/,
      "\\1_#{var_name}\\2"
    )
  end

  defp run_validation_compile do
    IO.puts "🔄 Running validation compilation..."

    case System.cmd("env", [
      "NO_TIMEOUT=true",
      "PATIENT_MODE=enabled",
      "INFINITE_PATIENCE=true",
      "ELIXIR_ERL_OPTIONS=+fnu +S 16",
      "mix", "compile", "--warnings-as-errors"
    ], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts "✅ Validation compilation successful"
        :success
      {output, _} ->
        IO.puts "⚠️ Validation compilation has issues:"
        IO.puts String.slice(output, 0, 500) <> "..."
        :needs_review
    end
  end
end

SOPv511Batch2WarningEliminator.main(System.argv())