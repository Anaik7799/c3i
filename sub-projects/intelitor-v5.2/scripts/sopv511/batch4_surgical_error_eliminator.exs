#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511Batch4SurgicalErrorEliminator do
  @moduledoc """
  SOPv5.11 Batch 4: Surgical Error Elimination

  Targets the remaining 48 critical errors with surgical file editing.
  Direct fixes to specific files and line numbers based on compilation analysis.

  Focus: Undefined variable errors in specific files with exact line targeting
  """

  @max_changes 200
  @compile_log "4-compile.log"

  def main(args) do
    case args do
      ["--execute"] -> execute_batch_4_fixes()
      ["--analyze"] -> analyze_specific_errors()
      _ -> show_help()
    end
  end

  defp show_help do
    IO.puts """
    SOPv5.11 Batch 4 Surgical Error Eliminator

    Usage:
      --execute    Apply surgical fixes to specific files with exact targeting
      --analyze    Analyze specific error locations and patterns
    """
  end

  defp analyze_specific_errors do
    IO.puts """
    🔍 SOPv5.11 BATCH 4 SURGICAL ERROR ANALYSIS
    ==========================================
    """

    if File.exists?(@compile_log) do
      {output, _} = System.cmd("grep", ["-B3", "-A2", "undefined variable", @compile_log])

      error_files = extract_error_files(output)

      IO.puts "📊 Specific Error Files Analysis:"
      IO.puts "  Total Files with Errors: #{length(error_files)}"

      IO.puts "\n🎯 Priority Files for Surgical Fixes:"
      error_files
      |> Enum.take(10)
      |> Enum.each(fn {file, errors} ->
        IO.puts "  #{file}: #{length(errors)} errors"
        Enum.each(errors, fn error_info ->
          IO.puts "    - Line #{error_info.line}: #{error_info.error}"
        end)
      end)

    else
      IO.puts "❌ Error log not found: #{@compile_log}"
      IO.puts "Please run compilation first to generate error data"
    end
  end

  defp execute_batch_4_fixes do
    IO.puts """
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  SOPv5.11 BATCH 4: SURGICAL ERROR ELIMINATION                      ║
    ║  🎯 TPS Jidoka: Surgical fixes to exact files and lines            ║
    ║  🔧 Target: 48 remaining critical errors (post Batch 3)            ║
    ╚═════════════════════════════════════════════════════════════════════╝
    """

    # Get specific error data
    IO.puts "📸 Analyzing specific error locations..."
    if not File.exists?(@compile_log) do
      IO.puts "❌ ERROR: Compilation log not found: #{@compile_log}"
      System.halt(1)
    end

    # Extract specific file errors
    {error_output, _} = System.cmd("grep", ["-B3", "-A2", "undefined variable", @compile_log])
    error_files = extract_error_files(error_output)

    IO.puts "📊 Found #{length(error_files)} files with specific errors"

    results = %{
      fixed: 0,
      files_modified: [],
      errors: []
    }

    # Apply surgical fixes to specific files
    results = apply_surgical_fixes(error_files, results)

    # Validation compilation
    IO.puts "🧪 Validating surgical error elimination..."
    validation_result = run_validation_compile()

    IO.puts """

    ✅ BATCH 4 SURGICAL ERROR ELIMINATION COMPLETE
    ==============================================
    📊 Results:
      • Changes applied: #{results.fixed}/#{@max_changes}
      • Files modified: #{length(results.files_modified)}
      • Errors encountered: #{length(results.errors)}
      • Validation: #{if validation_result == :success, do: "PASSED", else: "NEEDS REVIEW"}

    🔄 Next: Git checkpoint and final validation
    """
  end

  defp extract_error_files(error_output) do
    error_output
    |> String.split("└─")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.contains?(&1, ".ex:"))
    |> Enum.map(&parse_error_line/1)
    |> Enum.filter(& &1)
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {file, errors} -> {file, Enum.map(errors, &elem(&1, 1))} end)
  end

  defp parse_error_line(line) do
    case Regex.run(~r/(lib\/[^:]+\.ex):(\d+):(\d+): (.+)/, line) do
      [_, file, line_num, _col, error] -> {file, %{line: String.to_integer(line_num), error: error}}
      _ -> nil
    end
  end

  defp apply_surgical_fixes(error_files, results) do
    IO.puts "🔧 Applying surgical fixes to specific files..."

    # Priority files based on most errors
    priority_files = error_files
    |> Enum.sort_by(fn {_file, errors} -> -length(errors) end)
    |> Enum.take(10)

    Enum.reduce(priority_files, results, fn {file_path, errors}, acc ->
      if acc.fixed < @max_changes and File.exists?(file_path) do
        IO.puts "  🎯 Surgical fixes for: #{file_path} (#{length(errors)} errors)"
        case apply_file_specific_fixes(file_path, errors) do
          {:ok, changes_made} when changes_made > 0 ->
            %{acc |
              fixed: acc.fixed + changes_made,
              files_modified: [file_path | acc.files_modified]
            }
          {:ok, 0} ->
            IO.puts "    ⚠️ No changes applied to #{file_path}"
            acc
          {:error, reason} ->
            %{acc | errors: [reason | acc.errors]}
        end
      else
        acc
      end
    end)
  end

  defp apply_file_specific_fixes(file_path, errors) do
    try do
      content = File.read!(file_path)
      original_content = content
      changes_made = 0

      # Apply specific fixes based on file and error patterns
      {updated_content, changes} = case Path.basename(file_path) do
        "metrics.ex" -> fix_metrics_file(content, errors, changes_made)
        "error_helpers.ex" -> fix_error_helpers_file(content, errors, changes_made)
        "test_support.ex" -> fix_test_support_file(content, errors, changes_made)
        "environment_lifecycle.ex" -> fix_environment_lifecycle_file(content, errors, changes_made)
        _ -> fix_generic_undefined_variables(content, errors, changes_made)
      end

      if updated_content != original_content do
        File.write!(file_path, updated_content)
        IO.puts "    ✅ Applied #{changes} surgical fixes to #{Path.basename(file_path)}"
        {:ok, changes}
      else
        {:ok, 0}
      end
    rescue
      e -> {:error, "Error processing #{file_path}: #{inspect(e)}"}
    end
  end

  defp fix_metrics_file(content, _errors, changes_made) do
    # Fix undefined 'state' variable in metrics.ex
    updated_content = content
    |> String.replace(
      ~r/(def generate_prometheus_format)\(\) do/,
      "\\1(state) do"
    )
    |> String.replace(
      ~r/(defp format_metric_entry)\(([^)]*)\) do/,
      "\\1(\\2, state) do"
    )

    changes = if updated_content != content, do: changes_made + 1, else: changes_made
    {updated_content, changes}
  end

  defp fix_error_helpers_file(content, _errors, changes_made) do
    # Fix undefined 'operation', 'error', 'opts' variables in error_helpers.ex
    updated_content = content
    |> String.replace(
      ~r/(def function_name)\(\) do/,
      "\\1(operation, error) do"
    )
    |> String.replace(
      ~r/(def generate_business_recommended_actions)\(([^)]*)\) do/,
      "\\1(\\2, opts) do"
    )
    |> String.replace(
      ~r/(defp extract_operation_info)\(\) do/,
      "\\1(operation) do"
    )
    |> String.replace(
      ~r/(defp format_error_details)\(\) do/,
      "\\1(error) do"
    )

    changes = count_replacements(content, updated_content) + changes_made
    {updated_content, changes}
  end

  defp fix_test_support_file(content, _errors, changes_made) do
    # Fix undefined 'factory_name', 'attrs', 'count' variables in test_support.ex
    updated_content = content
    |> String.replace(
      ~r/(def start_link)\(\) do/,
      "\\1(factory_name, attrs, count) do"
    )
    |> String.replace(
      ~r/(defp create_test_data)\(\) do/,
      "\\1(factory_name, attrs) do"
    )
    |> String.replace(
      ~r/(defp process_count)\(\) do/,
      "\\1(count) do"
    )

    changes = count_replacements(content, updated_content) + changes_made
    {updated_content, changes}
  end

  defp fix_environment_lifecycle_file(content, _errors, changes_made) do
    # Fix undefined 'state' variable in environment_lifecycle.ex
    updated_content = content
    |> String.replace(
      ~r/(def start_link)\(\) do/,
      "\\1(state) do"
    )
    |> String.replace(
      ~r/(defp initialize_environment)\(\) do/,
      "\\1(state) do"
    )

    changes = count_replacements(content, updated_content) + changes_made
    {updated_content, changes}
  end

  defp fix_generic_undefined_variables(content, _errors, changes_made) do
    # Generic fixes for common undefined variable patterns
    updated_content = content
    |> fix_underscore_variables()
    |> fix_missing_parameters()

    changes = count_replacements(content, updated_content) + changes_made
    {updated_content, changes}
  end

  defp fix_underscore_variables(content) do
    # Fix _opts to opts, _state to state, etc.
    content
    |> String.replace(~r/\b_opts\b/, "opts")
    |> String.replace(~r/\b_state\b/, "state")
    |> String.replace(~r/\b_context\b/, "context")
  end

  defp fix_missing_parameters(content) do
    # Add missing parameters to function definitions
    content
    |> String.replace(
      ~r/(def[p]?\s+\w+)\(\) do(\s*\n\s*[^#\n]*\b(?:state|opts|context|error|operation)\b)/,
      "\\1(\\g{2}|> extract_var_name()) do\\2"
    )
  end

  defp count_replacements(original, updated) do
    original_lines = String.split(original, "\n")
    updated_lines = String.split(updated, "\n")

    Enum.zip(original_lines, updated_lines)
    |> Enum.count(fn {orig, upd} -> orig != upd end)
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

SOPv511Batch4SurgicalErrorEliminator.main(System.argv())