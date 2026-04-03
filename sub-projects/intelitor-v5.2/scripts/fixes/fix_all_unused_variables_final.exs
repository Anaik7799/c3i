#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FinalUnusedVariablesFixer do
  @moduledoc """
  Final comprehensive fix for ALL unused variables to achieve zero warnings
  """

  def fix_all_unused_variables do
    IO.puts("🎯 FINAL Unused Variables Elimination - Zero Tolerance")
    IO.puts("=" |> String.duplicate(60))

    # Get compilation log
    log_file = "/home/an/dev/indrajaal-demo/__data/tmp/zero_error_validation_20250917-0634.log"

    if File.exists?(log_file) do
      content = File.read!(log_file)

      # Extract ALL unused variable warnings
      unused_vars = extract_all_unused_variables(content)

      IO.puts("🔍 Total unused variables found: #{length(unused_vars)}")

      # Group by file and variable name for efficient processing
      grouped_fixes = group_fixes_by_file(unused_vars)

      IO.puts("📁 Files __requiring fixes: #{map_size(grouped_fixes)}")

      # Apply fixes systematically
      total_fixed = 0

      Enum.each(grouped_fixes, fn {file_path, variables} ->
        fixed_count = apply_comprehensive_fixes(file_path, variables)
        total_fixed = total_fixed + fixed_count
      end)

      IO.puts("✅ Total variables fixed: #{total_fixed}")
    else
      IO.puts("❌ Compilation log not found: #{log_file}")
    end
  end

  defp extract_all_unused_variables(content) do
    # More comprehensive pattern to match all unused variable warnings
    pattern = ~r/warning: variable "([^"]+)" is unused.*?└─ ([^:]+):(\d+):(\d+)/s

    Regex.scan(pattern, content)
    |> Enum.map(fn [_full, var_name, file_path, line_num, col_num] ->
      %{
        variable: var_name,
        file: String.trim(file_path),
        line: String.to_integer(line_num),
        column: String.to_integer(col_num)
      }
    end)
  end

  defp group_fixes_by_file(unused_vars) do
    unused_vars
    |> Enum.group_by(& &1.file)
  end

  defp apply_comprehensive_fixes(file_path, variables) do
    # Convert to absolute path
    full_path = if String.starts_with?(file_path, "/") do
      file_path
    else
      "/home/an/dev/indrajaal-demo/#{file_path}"
    end

    if File.exists?(full_path) do
      IO.puts("🔧 Processing: #{Path.basename(full_path)} (#{length(variables)} variables)")

      content = File.read!(full_path)
      lines = String.split(content, "\n")

      # Sort by line number (descending) to avoid line shifts
      sorted_vars = Enum.sort_by(variables, & &1.line, :desc)

      # Apply fixes line by line
      {updated_lines, fixes_applied} =
        Enum.reduce(sorted_vars, {lines, 0}, fn var, {current_lines, count} ->
          if var.line <= length(current_lines) do
            target_line = Enum.at(current_lines, var.line - 1)

            case fix_unused_variable_in_line(target_line, var.variable) do
              {:ok, updated_line} ->
                new_lines = List.replace_at(current_lines, var.line - 1, updated_line)
                {new_lines, count + 1}

              :no_change ->
                {current_lines, count}
            end
          else
            {current_lines, count}
          end
        end)

      if fixes_applied > 0 do
        updated_content = Enum.join(updated_lines, "\n")
        File.write!(full_path, updated_content)
        IO.puts("  ✅ Fixed #{fixes_applied} variables")
      else
        IO.puts("  ℹ️  No fixes applied")
      end

      fixes_applied
    else
      IO.puts("  ❌ File not found: #{full_path}")
      0
    end
  end

  defp fix_unused_variable_in_line(line, var_name) do
    cond do
      # Function parameter (def/defp)
      String.contains?(line, "def ") or String.contains?(line, "defp ") ->
        fix_parameter_variable(line, var_name)

      # Pattern matching in case __statements or with __statements
      String.contains?(line, " <- ") or String.contains?(line, " = ") ->
        fix_assignment_variable(line, var_name)

      # Function arguments in anonymous functions
      String.contains?(line, "fn ") and String.contains?(line, " ->") ->
        fix_anonymous_function_variable(line, var_name)

      # Enum.each and similar where variable is in block parameter
      String.contains?(line, "|>") or String.contains?(line, "Enum.") ->
        fix_enum_variable(line, var_name)

      true ->
        :no_change
    end
  end

  defp fix_parameter_variable(line, var_name) do
    # Fix function parameters by adding underscore prefix if not already there
    if not String.starts_with?(var_name, "_") do
      # Use word boundaries to avoid partial matches
      updated = String.replace(line, ~r/\b#{var_name}\b/, "_#{var_name}", global: false)
      if updated != line do
        {:ok, updated}
      else
        :no_change
      end
    else
      :no_change
    end
  end

  defp fix_assignment_variable(line, var_name) do
    # Fix variables in pattern matching
    if not String.starts_with?(var_name, "_") do
      # Be more careful with assignment patterns
      updated = String.replace(line, ~r/([^a-zA-Z_])#{var_name}(\s*[=<])/, "\\1_#{var_name}\\2")
      if updated != line do
        {:ok, updated}
      else
        :no_change
      end
    else
      :no_change
    end
  end

  defp fix_anonymous_function_variable(line, var_name) do
    # Fix variables in anonymous function parameters
    if not String.starts_with?(var_name, "_") do
      updated = String.replace(line, ~r/(fn\s+[^-]*?)#{var_name}(\s*[,-]|(?=\s*->))/, "\\1_#{var_name}\\2")
      if updated != line do
        {:ok, updated}
      else
        :no_change
      end
    else
      :no_change
    end
  end

  defp fix_enum_variable(line, var_name) do
    # Fix variables in Enum functions
    if not String.starts_with?(var_name, "_") do
      updated = String.replace(line, ~r/(Enum\.[a-z_]+\([^,]*, fn\s+)#{var_name}(\s*[-,}])/, "\\1_#{var_name}\\2")
      if updated != line do
        {:ok, updated}
      else
        :no_change
      end
    else
      :no_change
    end
  end

  def run do
    fix_all_unused_variables()
  end
end

FinalUnusedVariablesFixer.run()