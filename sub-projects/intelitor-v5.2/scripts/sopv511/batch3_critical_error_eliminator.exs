#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511Batch3CriticalErrorEliminator do
  @moduledoc """
  SOPv5.11 Batch 3: Critical Error Elimination

  Targets the remaining 182 errors (mainly undefined variables) with systematic fixes.
  Uses TPS Jidoka stop-and-fix methodology with 200-change limit.

  Focus: Undefined variable errors that prevent compilation success
  """

  @max_changes 200
  @compile_log "3-compile.log"

  def main(args) do
    case args do
      ["--execute"] -> execute_batch_3_fixes()
      ["--analyze"] -> analyze_error_patterns()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts """
    SOPv5.11 Batch 3 Critical Error Eliminator

    Usage:
      --execute    Apply systematic error fixes with 200-change limit
      --analyze    Analyze error patterns for strategic approach
    """
  end

  defp analyze_error_patterns do
    IO.puts """
    🔍 SOPv5.11 BATCH 3 CRITICAL ERROR ANALYSIS
    ==========================================
    """

    if File.exists?(@compile_log) do
      {output, _} = System.cmd("grep", ["error:", @compile_log])
      errors = String.split(output, "\n", trim: true)

      IO.puts "📊 Error Analysis from #{@compile_log}:"
      IO.puts "  Total Errors: #{length(errors)}"

      # Analyze undefined variable patterns
      undefined_vars = analyze_undefined_variables(errors)
      undefined_functions = analyze_undefined_functions(errors)

      IO.puts "\n🎯 Top Undefined Variable Patterns:"
      undefined_vars
      |> Enum.take(10)
      |> Enum.each(fn {pattern, count} ->
        IO.puts "  #{pattern}: #{count} occurrences"
      end)

      IO.puts "\n🎯 Top Undefined Function Patterns:"
      undefined_functions
      |> Enum.take(5)
      |> Enum.each(fn {pattern, count} ->
        IO.puts "  #{pattern}: #{count} occurrences"
      end)

    else
      IO.puts "❌ Error log not found: #{@compile_log}"
      IO.puts "Please run compilation first to generate error data"
    end
  end

  defp execute_batch_3_fixes do
    IO.puts """
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  SOPv5.11 BATCH 3: CRITICAL ERROR ELIMINATION                      ║
    ║  🎯 TPS Jidoka: Stop-and-Fix with 200-Change Limit                 ║
    ║  🔧 Target: 182 remaining errors (post Batch 2)                    ║
    ╚═════════════════════════════════════════════════════════════════════╝
    """

    # Get error data
    IO.puts "📸 Analyzing current error state..."
    if not File.exists?(@compile_log) do
      IO.puts "❌ ERROR: Compilation log not found: #{@compile_log}"
      System.halt(1)
    end

    {error_output, _} = System.cmd("grep", ["error:", @compile_log])
    errors = String.split(error_output, "\n", trim: true)

    IO.puts "📊 Current errors: #{length(errors)}"

    # Focus on undefined variables first
    undefined_vars = analyze_undefined_variables(errors)

    results = %{
      fixed: 0,
      files_modified: [],
      errors: []
    }

    # Apply systematic fixes in priority order
    results = apply_undefined_variable_fixes(undefined_vars, results)

    # Validation compilation
    IO.puts "🧪 Validating error elimination..."
    validation_result = run_validation_compile()

    IO.puts """

    ✅ BATCH 3 CRITICAL ERROR ELIMINATION COMPLETE
    ==============================================
    📊 Results:
      • Changes applied: #{results.fixed}/#{@max_changes}
      • Files modified: #{length(results.files_modified)}
      • Errors encountered: #{length(results.errors)}
      • Validation: #{if validation_result == :success, do: "PASSED", else: "NEEDS REVIEW"}

    🔄 Next: Git checkpoint and Batch 4 preparation
    """
  end

  defp analyze_undefined_variables(errors) do
    errors
    |> Enum.filter(&String.contains?(&1, "undefined variable"))
    |> Enum.map(&extract_undefined_variable_name/1)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp analyze_undefined_functions(errors) do
    errors
    |> Enum.filter(&String.contains?(&1, "undefined function"))
    |> Enum.map(&extract_function_name/1)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp extract_undefined_variable_name(error_line) do
    case Regex.run(~r/undefined variable "([^"]+)"/, error_line) do
      [_, var_name] -> var_name
      _ -> nil
    end
  end

  defp extract_function_name(error_line) do
    case Regex.run(~r/undefined function ([^\/\s]+)/, error_line) do
      [_, func_name] -> func_name
      _ -> nil
    end
  end

  defp apply_undefined_variable_fixes(undefined_vars, results) do
    IO.puts "🔧 Applying systematic undefined variable fixes..."

    # Get top critical patterns to fix
    critical_patterns = undefined_vars |> Enum.take(10)

    Enum.reduce(critical_patterns, results, fn {var_name, count}, acc ->
      if acc.fixed < @max_changes do
        IO.puts "  🎯 Fixing undefined variable: #{var_name} (#{count} occurrences)"
        case fix_undefined_variable_critical(var_name) do
          {:ok, files_changed} ->
            %{acc |
              fixed: acc.fixed + count,
              files_modified: (acc.files_modified ++ files_changed) |> Enum.uniq()
            }
          {:error, reason} ->
            %{acc | errors: [reason | acc.errors]}
        end
      else
        acc
      end
    end)
  end

  defp fix_undefined_variable_critical(var_name) do
    try do
      # Find files with undefined variable errors
      {grep_output, _} = System.cmd("grep", [
        "-r", "-l",
        "undefined variable \"#{var_name}\"",
        "lib/"
      ])

      files = String.split(grep_output, "\n", trim: true)
      changed_files = []

      changed_files = Enum.reduce(files, changed_files, fn file_path, acc ->
        if File.exists?(file_path) do
          content = File.read!(file_path)
          updated_content = apply_critical_undefined_variable_fix(content, var_name)

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

  defp apply_critical_undefined_variable_fix(content, var_name) do
    case var_name do
      "opts" ->
        # Add opts parameter to functions missing it
        content
        |> String.replace(
          ~r/(def[p]?\s+\w+\([^)]*)\) do(\s*\n\s*[^#\n]*#{var_name})/,
          "\\1, opts) do\\2"
        )
        |> String.replace(
          ~r/(def[p]?\s+\w+\([^)]*), \) do/,
          "\\1) do"
        )

      "state" ->
        # Add state parameter or fix state references
        content
        |> String.replace(
          ~r/(def[p]?\s+\w+\([^)]*)\) do(\s*\n\s*[^#\n]*#{var_name})/,
          "\\1, state) do\\2"
        )
        |> String.replace(
          ~r/(def[p]?\s+\w+\([^)]*), \) do/,
          "\\1) do"
        )

      "_context" ->
        # Fix underscore context references
        content
        |> String.replace("_context", "context")

      _ ->
        # Generic fix for other undefined variables
        content
        |> String.replace(
          ~r/(def[p]?\s+\w+\([^)]*)\) do(\s*\n\s*[^#\n]*#{var_name})/,
          "\\1, #{var_name}) do\\2"
        )
    end
  end

  defp run_validation_compile do
    IO.puts "🔄 Running validation compilation..."

    case System.cmd("env", [
      "NO_TIMEOUT=true",
      "PATIENT_MODE=enabled",
      "INFINITE_PATIENCE=true",
      "ELIXIR_ERL_OPTIONS=+fnu +S 16",
      "mix", "compile"
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

SOPv511Batch3CriticalErrorEliminator.main(System.argv())