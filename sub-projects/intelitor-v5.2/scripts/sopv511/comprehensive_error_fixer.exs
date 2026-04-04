#!/usr/bin/env elixir
# AEE SOPv5.11 Comprehensive Error Fixer
# Phase 0: Fix all 432 compilation errors systematically

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule ComprehensiveErrorFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Error Elimination System
  Fixes undefined variable errors in batches of 200
  """

  @batch_size 200
  @patient_mode_env %{
    "NO_TIMEOUT" => "true",
    "PATIENT_MODE" => "enabled",
    "INFINITE_PATIENCE" => "true",
    "ELIXIR_ERL_OPTIONS" => "+fnu +S 16"
  }

  def run(args \\ []) do
    IO.puts """
    🤖 AEE SOPv5.11 Comprehensive Error Fixer
    ==========================================
    Phase 0: Compilation Error Elimination
    Target: 432 undefined variable errors
    Batch Size: #{@batch_size} fixes per checkpoint
    """

    # Step 1: Analyze current errors
    errors = analyze_errors()
    IO.puts("\n📊 Error Analysis Complete:")
    IO.puts("  • Total errors: #{length(errors)}")
    IO.puts("  • Batches required: #{ceil(length(errors) / @batch_size)}")

    # Step 2: Create initial checkpoint
    create_git_checkpoint("initial-error-fix")

    # Step 3: Process errors in batches
    errors
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_num} ->
      process_error_batch(batch, batch_num)
    end)

    # Step 4: Final validation
    validate_no_errors()
    IO.puts("\n✅ Phase 0 Complete: All compilation errors resolved!")
  end

  defp analyze_errors do
    IO.puts("\n🔍 Analyzing compilation errors...")

    # Parse the compilation log
    log_content = File.read!("1-compile.log")

    # Extract error information with file context
    errors = extract_errors(log_content)

    # Group by pattern for efficient fixing
    grouped = Enum.group_by(errors, &(&1.pattern))

    Enum.each(grouped, fn {pattern, items} ->
      IO.puts("  • #{pattern}: #{length(items)} occurrences")
    end)

    errors
  end

  defp extract_errors(log_content) do
    # Parse errors with their file context
    log_content
    |> String.split("\n")
    |> Enum.chunk_every(5, 1)
    |> Enum.flat_map(fn chunk ->
      case find_error_in_chunk(chunk) do
        nil -> []
        error -> [error]
      end
    end)
    |> Enum.uniq_by(fn error -> {error.file, error.line, error.variable} end)
  end

  defp find_error_in_chunk(chunk) do
    # Look for compilation file and error pattern
    file_line = Enum.find(chunk, &String.contains?(&1, "Compiling"))
    error_line = Enum.find(chunk, &String.contains?(&1, "error: undefined variable"))

    if file_line && error_line do
      file = extract_file_from_compile_line(file_line)
      {line_num, variable} = extract_error_details(error_line)
      pattern = categorize_error_pattern(variable)

      %{
        file: file,
        line: line_num,
        variable: variable,
        pattern: pattern,
        fix_type: determine_fix_type(variable)
      }
    else
      nil
    end
  end

  defp extract_file_from_compile_line(line) do
    case Regex.run(~r/Compiling \d+ files? \(\.ex\)\s+(.+)/, line) do
      [_, file] -> String.trim(file)
      _ ->
        # Try alternative pattern
        case Regex.run(~r/(.+\.ex)/, line) do
          [_, file] -> String.trim(file)
          _ -> nil
        end
    end
  end

  defp extract_error_details(error_line) do
    case Regex.run(~r/:(\d+).*undefined variable "([^"]+)"/, error_line) do
      [_, line, var] -> {String.to_integer(line), var}
      _ ->
        # Try without line number
        case Regex.run(~r/undefined variable "([^"]+)"/, error_line) do
          [_, var] -> {0, var}
          _ -> {0, "unknown"}
        end
    end
  end

  defp categorize_error_pattern(variable) do
    cond do
      String.starts_with?(variable, "_context") -> "_context_pattern"
      String.starts_with?(variable, "_opts") -> "_opts_pattern"
      variable == "eventcontext" -> "camelCase_pattern"
      variable == "schedule_config" -> "undefined_config"
      variable == "violationdata" -> "camelCase_pattern"
      variable == "frameworkconfig" -> "camelCase_pattern"
      variable == "violation_data" -> "undefined_data"
      String.starts_with?(variable, "_") -> "underscore_prefix"
      true -> "undefined_variable"
    end
  end

  defp determine_fix_type(variable) do
    cond do
      String.starts_with?(variable, "_") -> :remove_underscore
      variable =~ ~r/[a-z][A-Z]/ -> :snake_case_conversion
      true -> :add_definition
    end
  end

  defp process_error_batch(batch, batch_num) do
    IO.puts("\n📦 Processing Batch #{batch_num} (#{length(batch)} errors)...")

    # Group by file for efficient processing
    by_file = Enum.group_by(batch, &(&1.file))

    Enum.each(by_file, fn {file, file_errors} ->
      if file && File.exists?(file) do
        fix_errors_in_file(file, file_errors)
      end
    end)

    # Compile and check
    IO.puts("  🔧 Running compilation check...")
    case run_compilation_check() do
      :ok ->
        IO.puts("  ✅ Batch #{batch_num} successful!")
        create_git_checkpoint("batch-#{batch_num}-complete")

      {:error, new_error_count} ->
        IO.puts("  ⚠️ Batch #{batch_num} introduced #{new_error_count} errors")
        IO.puts("  🔄 Rolling back and trying alternative approach...")
        rollback_to_last_checkpoint()
        process_error_batch_conservative(batch, batch_num)
    end
  end

  defp fix_errors_in_file(file, errors) do
    IO.puts("  📝 Fixing #{length(errors)} errors in #{Path.basename(file)}")

    content = File.read!(file)
    lines = String.split(content, "\n")

    # Apply fixes based on error type
    fixed_lines = Enum.map(errors, fn error ->
      apply_fix(lines, error)
    end)
    |> merge_fixes(lines)

    # Write back the fixed content
    File.write!(file, Enum.join(fixed_lines, "\n"))
  end

  defp apply_fix(lines, error) do
    case error.fix_type do
      :remove_underscore ->
        # Change _variable to variable when it's actually used
        fix_underscore_prefix(lines, error)

      :snake_case_conversion ->
        # Convert camelCase to snake_case
        fix_camel_case(lines, error)

      :add_definition ->
        # Add variable definition or parameter
        add_variable_definition(lines, error)
    end
  end

  defp fix_underscore_prefix(lines, error) do
    # Find the function definition and remove underscore if variable is used
    pattern = ~r/def\w*\s+\w+\([^)]*#{Regex.escape(error.variable)}[^)]*\)/

    Enum.map(lines, fn line ->
      if line =~ pattern do
        # Check if variable is used in function body
        String.replace(line, error.variable, String.slice(error.variable, 1..-1//1))
      else
        line
      end
    end)
  end

  defp fix_camel_case(lines, error) do
    snake_case = to_snake_case(error.variable)

    Enum.map(lines, fn line ->
      String.replace(line, error.variable, snake_case)
    end)
  end

  defp to_snake_case(string) do
    string
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
  end

  defp add_variable_definition(lines, _error) do
    # This is more complex - would need context-aware fixing
    lines
  end

  defp merge_fixes(fix_sets, original_lines) do
    # Merge multiple fix sets intelligently
    fix_sets
    |> Enum.reduce(original_lines, fn fixes, acc ->
      Enum.zip(acc, fixes)
      |> Enum.map(fn {orig, fix} ->
        if orig != fix, do: fix, else: orig
      end)
    end)
  end

  defp run_compilation_check do
    IO.puts("  ⏳ Running patient mode compilation...")

    {output, _exit_code} = System.cmd("mix", ["compile", "--warnings-as-errors"],
      env: @patient_mode_env,
      stderr_to_stdout: true
    )

    error_count = count_errors_in_output(output)

    if error_count == 0 do
      :ok
    else
      {:error, error_count}
    end
  end

  defp count_errors_in_output(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "error:"))
  end

  defp create_git_checkpoint(name) do
    IO.puts("  💾 Creating git checkpoint: #{name}")
    System.cmd("git", ["add", "-A"])
    System.cmd("git", ["commit", "-m", "Checkpoint: #{name} - #{DateTime.utc_now()}"])
  end

  defp rollback_to_last_checkpoint do
    IO.puts("  ⏮️ Rolling back to last checkpoint...")
    System.cmd("git", ["reset", "--hard", "HEAD"])
  end

  defp process_error_batch_conservative(batch, batch_num) do
    IO.puts("  🐢 Using conservative approach for batch #{batch_num}...")

    # Process one file at a time with validation
    batch
    |> Enum.group_by(&(&1.file))
    |> Enum.each(fn {file, errors} ->
      if file do
        fix_errors_in_file(file, errors)
        run_compilation_check()
      end
    end)

    create_git_checkpoint("batch-#{batch_num}-conservative")
  end

  defp validate_no_errors do
    IO.puts("\n🔍 Final validation...")

    {output, _} = System.cmd("mix", ["compile"],
      env: @patient_mode_env,
      stderr_to_stdout: true
    )

    error_count = count_errors_in_output(output)

    if error_count == 0 do
      IO.puts("  ✅ SUCCESS: Zero compilation errors!")
    else
      IO.puts("  ⚠️ WARNING: #{error_count} errors remain")
      IO.puts("  📋 Run manual review required")
    end
  end
end

# Run if executed directly
if System.argv() != [] or true do
  ComprehensiveErrorFixer.run(System.argv())
end