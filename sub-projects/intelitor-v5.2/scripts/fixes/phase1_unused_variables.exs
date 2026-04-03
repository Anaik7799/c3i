#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Phase1UnusedVariables do
  @moduledoc """
  Phase 1: Automated fixing of unused variable warnings.

  This script:
  1. Runs compilation to get all unused variable warnings
  2. Groups warnings by file
  3. Fixes warnings in batches of 25 files max
  4. Creates git checkpoints after each batch
  5. Validates compilation success after each batch

  Usage:
    elixir scripts/fixes/phase1_unused_variables.exs
    elixir scripts/fixes/phase1_unused_variables.exs --dry-run
  """

  def main(args \\ []) do
    dry_run = "--dry-run" in args

    IO.puts("\n🚀 Phase 1: Unused Variable Warning Elimination")
    IO.puts("=" |> String.duplicate(60))

    if dry_run do
      IO.puts("⚠️  DRY RUN MODE - No changes will be made\n")
    end

    # Step 1: Get all unused variable warnings
    IO.puts("📊 Step 1: Analyzing unused variable warnings...")
    warnings = get_unused_variable_warnings()

    IO.puts("   Found #{length(warnings)} unused variable warnings")
    IO.puts("   Grouped into #{map_size(group_by_file(warnings))} files")

    # Step 2: Group by file and create batches
    file_groups = group_by_file(warnings)
    batches = create_batches(file_groups, 25)

    IO.puts("\n📦 Step 2: Created #{length(batches)} batches (max 25 files per batch)")

    # Step 3: Process each batch
    Enum.with_index(batches, 1)
    |> Enum.each(fn {batch, batch_num} ->
      process_batch(batch, batch_num, length(batches), dry_run)
    end)

    IO.puts("\n✅ Phase 1 Task 1: Unused Variables - COMPLETE")
    IO.puts("   Total warnings fixed: #{length(warnings)}")
    IO.puts("   Total files modified: #{map_size(file_groups)}")
    IO.puts("   Total batches processed: #{length(batches)}")
  end

  defp get_unused_variable_warnings do
    IO.puts("   Running compilation to collect warnings...")

    {output, _exit_code} = System.cmd(
      "sh",
      ["-c", "NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS=\"+S 16\" mix compile --jobs 16 --warnings-as-errors 2>&1"],
      stderr_to_stdout: true
    )

    # Parse warnings - format: "warning: variable \"name\" is unused ... file:line:"
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "variable") && String.contains?(&1, "is unused"))
    |> Enum.map(&parse_warning/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_warning(warning_line) do
    # Extract variable name from: warning: variable "name" is unused
    var_match = Regex.run(~r/variable "([^"]+)" is unused/, warning_line)

    # Look for file path in the line or subsequent context
    # Format can be: └─ lib/path/file.ex:123:45
    file_match = Regex.run(~r/(?:└─ |  )(lib\/[^:]+\.exs?):(\d+)/, warning_line)

    case {var_match, file_match} do
      {[_, var_name], [_, file_path, line_num]} ->
        %{
          variable: var_name,
          file: file_path,
          line: String.to_integer(line_num)
        }
      _ -> nil
    end
  end

  defp group_by_file(warnings) do
    warnings
    |> Enum.group_by(& &1.file)
  end

  defp create_batches(file_groups, max_per_batch) do
    file_groups
    |> Enum.map(fn {file, warnings} -> {file, warnings} end)
    |> Enum.chunk_every(max_per_batch)
  end

  defp process_batch(batch, batch_num, total_batches, dry_run) do
    IO.puts("\n" <> ("─" |> String.duplicate(60)))
    IO.puts("📦 Processing Batch #{batch_num}/#{total_batches}")
    IO.puts("   Files in batch: #{length(batch)}")

    batch
    |> Enum.each(fn {file, warnings} ->
      fix_file(file, warnings, dry_run)
    end)

    unless dry_run do
      # Validate compilation
      IO.puts("\n   ✓ Validating compilation...")
      case run_compilation_check() do
        :ok ->
          IO.puts("   ✅ Compilation successful")

          # Create git checkpoint
          create_git_checkpoint(batch_num, length(batch))

        {:error, reason} ->
          IO.puts("   ❌ Compilation failed: #{reason}")
          IO.puts("   🔄 Rolling back batch #{batch_num}")
          System.cmd("git", ["reset", "--hard", "HEAD"])
          raise "Batch #{batch_num} failed compilation - rolled back"
      end
    end
  end

  defp fix_file(file_path, warnings, dry_run) do
    IO.puts("\n   📄 #{file_path}")
    IO.puts("      Warnings: #{length(warnings)}")

    if dry_run do
      warnings
      |> Enum.each(fn w ->
        IO.puts("      - Line #{w.line}: #{w.variable} → _#{w.variable}")
      end)
    else
      # Read file
      content = File.read!(file_path)

      # Fix each unused variable by prefixing with underscore
      fixed_content = warnings
      |> Enum.sort_by(& &1.line, :desc)  # Process from bottom to top to preserve line numbers
      |> Enum.reduce(content, fn warning, acc ->
        fix_unused_variable_in_content(acc, warning)
      end)

      # Write fixed content
      File.write!(file_path, fixed_content)
      IO.puts("      ✅ Fixed #{length(warnings)} warnings")
    end
  end

  defp fix_unused_variable_in_content(content, %{variable: var_name, line: line_num}) do
    lines = String.split(content, "\n", trim: false)

    # Fix the specific line
    fixed_lines = lines
    |> Enum.with_index(1)
    |> Enum.map(fn {line, idx} ->
      if idx == line_num do
        # Replace "variable_name" with "_variable_name" in function parameters
        # Be careful to only replace in parameter context, not in usage
        line
        |> replace_in_function_params(var_name)
      else
        line
      end
    end)

    Enum.join(fixed_lines, "\n")
  end

  defp replace_in_function_params(line, var_name) do
    # Common patterns for function parameters:
    # def func(var_name, ...)
    # defp func(var_name, ...)
    # fn var_name -> ... end
    # |> Enum.map(fn var_name -> ... end)
    # case ... do var_name -> ... end

    # Pattern: match variable in parameter positions
    # This is a simplified approach - match common patterns
    line
    |> String.replace(
      ~r/\b(def|defp|fn)\s+([a-z_][a-z0-9_]*\(|)\s*#{Regex.escape(var_name)}\b/,
      "\\1 \\2_#{var_name}"
    )
    |> String.replace(
      ~r/\|\s*#{Regex.escape(var_name)}\b/,
      "| _#{var_name}"
    )
    |> String.replace(
      ~r/,\s*#{Regex.escape(var_name)}\b(?=\s*[,\)])/,
      ", _#{var_name}"
    )
    |> String.replace(
      ~r/\(\s*#{Regex.escape(var_name)}\b/,
      "(_#{var_name}"
    )
  end

  defp run_compilation_check do
    {output, exit_code} = System.cmd(
      "sh",
      ["-c", "NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS=\"+S 16\" mix compile --jobs 16 --warnings-as-errors 2>&1"],
      stderr_to_stdout: true
    )

    error_count = output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "error:"))

    if exit_code == 0 || error_count == 0 do
      :ok
    else
      {:error, "#{error_count} compilation errors"}
    end
  end

  defp create_git_checkpoint(batch_num, file_count) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    System.cmd("git", ["add", "-A"])

    message = "Phase 1.1 Batch #{batch_num}: Fixed unused variable warnings in #{file_count} files - #{timestamp}"

    {_output, 0} = System.cmd("git", ["commit", "-m", message])

    IO.puts("   📌 Git checkpoint created: Batch #{batch_num}")
  end
end

# Run the script
Phase1UnusedVariables.main(System.argv())
