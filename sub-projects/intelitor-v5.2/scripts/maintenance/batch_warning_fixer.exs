#!/usr/bin/env elixir
# =============================================================================
# SCRIPT: batch_warning_fixer.exs
# CONTEXT: Stream Gamma (Task 30.3.1)
# PURPOSE: Automate warning elimination in compliance with SC-BATCH
# =============================================================================

Mix.install([{:jason, "~> 1.4"}])

defmodule BatchWarningFixer do
  @max_batch_size 5 # SC-BATCH-001 / SC-CYBER-002
  @log_file "data/tmp/1-compile.log"

  def run do
    IO.puts("🌊 Stream Gamma: Analyzing compilation log for warnings...")

    if not File.exists?(@log_file) do
      IO.puts("❌ Error: Log file #{@log_file} not found. Run Patient Mode compilation first.")
      System.halt(1)
    end

    warnings = parse_warnings(@log_file)
    IO.puts("📊 Found #{length(warnings)} fixable warnings.")

    if Enum.empty?(warnings) do
      IO.puts("✅ No warnings to fix.")
      System.halt(0)
    end

    # Take top batch
    batch = Enum.take(warnings, @max_batch_size)
    apply_batch(batch)
  end

  defp parse_warnings(file) do
    File.read!(file)
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&parse_line/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp parse_line(line) do
    # Pattern: file.ex:12: warning: variable "x" is unused
    case Regex.run(~r/^([^:]+):(\d+): warning: variable "([^"]+)" is unused/, line) do
      [_, file, line_no, var_name] ->
        %{type: :unused_var, file: String.trim(file), line: String.to_integer(line_no), var: var_name}
      _ ->
        nil # Ignore other warning types for this automated pass
    end
  end

  defp apply_batch(batch) do
    IO.puts("🔨 Applying batch of #{length(batch)} fixes...")

    # Group by file to minimize IO
    batch_by_file = Enum.group_by(batch, & &1.file)

    Enum.each(batch_by_file, fn {file, file_warnings} ->
      fix_file(file, file_warnings)
    end)

    IO.puts("✅ Batch applied. PLEASE VERIFY with 'mix compile --jobs 16'.")
  end

  defp fix_file(file, warnings) do
    IO.puts("   -> Fixing #{file}")
    content = File.read!(file)
    lines = String.split(content, "\n")

    # Sort warnings by line descending to avoid index shifting if we were deleting
    # But for underscore prefixing, replacement is safe if we are careful
    # Simple line replacement for now
    
    new_lines = Enum.reduce(warnings, lines, fn warning, acc_lines ->
      idx = warning.line - 1
      old_line = Enum.at(acc_lines, idx)
      
      # Regex replace strictly the variable name
      # This is simplistic and might need AST analysis for robustness, 
      # but fits the "Fast OODA" for obvious unused vars
      new_line = String.replace(old_line, warning.var, "_#{warning.var}", global: false)
      
      List.replace_at(acc_lines, idx, new_line)
    end)

    File.write!(file, Enum.join(new_lines, "\n"))
  end
end

BatchWarningFixer.run()
