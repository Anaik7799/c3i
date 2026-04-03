#!/usr/bin/env elixir
# Targeted undefined variable fixer for specific patterns

Mix.install([{:jason, "~> 1.4"}])

defmodule UndefinedVariableFixer do
  @moduledoc """
  Fixes undefined variable errors by analyzing usage patterns
  and removing unnecessary underscores or fixing variable names
  """

  def run(args \\ []) do
    mode = if "--dry-run" in args, do: :dry_run, else: :fix

    IO.puts """
    🔧 Undefined Variable Fixer
    ============================
    Mode: #{mode}
    Target patterns:
      • _context → context (213 errors)
      • _opts → opts (114 errors)
      • eventcontext → event_context (51 errors)
      • Other undefined variables
    """

    # Create checkpoint
    if mode == :fix do
      System.cmd("git", ["add", "-A"])
      System.cmd("git", ["commit", "-m", "Checkpoint before undefined variable fixes"])
    end

    # Fix each pattern systematically
    fix_context_errors(mode)
    fix_opts_errors(mode)
    fix_camel_case_errors(mode)
    fix_other_undefined_variables(mode)

    IO.puts("\n✅ All undefined variable patterns processed!")
  end

  defp fix_context_errors(mode) do
    IO.puts("\n📍 Fixing _context errors...")

    # Find all files with _context usage
    files = find_files_with_pattern("_context")

    Enum.each(files, fn file ->
      fix_underscore_variable_in_file(file, "_context", "context", mode)
    end)
  end

  defp fix_opts_errors(mode) do
    IO.puts("\n📍 Fixing _opts errors...")

    files = find_files_with_pattern("_opts")

    Enum.each(files, fn file ->
      fix_underscore_variable_in_file(file, "_opts", "opts", mode)
    end)
  end

  defp fix_camel_case_errors(mode) do
    IO.puts("\n📍 Fixing camelCase variable errors...")

    camel_case_vars = [
      {"eventcontext", "event_context"},
      {"violationdata", "violation_data"},
      {"frameworkconfig", "framework_config"},
      {"processeddata", "processed_data"},
      {"rawdata", "raw_data"},
      {"currentdata", "current_data"},
      {"compliancedata", "compliance_data"},
      {"baselinedata", "baseline_data"}
    ]

    Enum.each(camel_case_vars, fn {old_name, new_name} ->
      files = find_files_with_pattern(old_name)
      Enum.each(files, fn file ->
        fix_variable_name_in_file(file, old_name, new_name, mode)
      end)
    end)
  end

  defp fix_other_undefined_variables(mode) do
    IO.puts("\n📍 Fixing other undefined variables...")

    # Handle schedule_config and other specific cases
    specific_fixes = [
      {"schedule_config", "_schedule_config", :add_underscore},
      {"violation_data", "_violation_data", :add_underscore},
      {"framework_config", "_framework_config", :add_underscore}
    ]

    Enum.each(specific_fixes, fn {var, fix, _type} ->
      files = find_files_with_pattern(var)
      Enum.each(files, fn file ->
        fix_variable_name_in_file(file, var, fix, mode)
      end)
    end)
  end

  defp find_files_with_pattern(pattern) do
    {output, 0} = System.cmd("grep", [
      "-r",
      "-l",
      pattern,
      "lib/",
      "--include=*.ex"
    ], stderr_to_stdout: true)

    output
    |> String.split("\n")
    |> Enum.filter(&(&1 != ""))
    |> Enum.uniq()
  end

  defp fix_underscore_variable_in_file(file, old_var, new_var, mode) do
    if !File.exists?(file) do
      :ok
    else
      content = File.read!(file)

    # Check if the variable is used in the function body
    # If it's only in the parameter list, keep the underscore
    # If it's used in the body, remove the underscore

    new_content = fix_underscore_usage(content, old_var, new_var)

    if new_content != content do
      IO.puts("  • Fixing #{Path.basename(file)}: #{old_var} → #{new_var}")
      if mode == :fix do
        File.write!(file, new_content)
      end
    end
    end
  end

  defp fix_variable_name_in_file(file, old_name, new_name, mode) do
    if !File.exists?(file) do
      :ok
    else
      content = File.read!(file)

    # Simple replacement for camelCase to snake_case
    new_content = String.replace(content, old_name, new_name)

    if new_content != content do
      IO.puts("  • Fixing #{Path.basename(file)}: #{old_name} → #{new_name}")
      if mode == :fix do
        File.write!(file, new_content)
      end
    end
    end
  end

  defp fix_underscore_usage(content, old_var, new_var) do
    lines = String.split(content, "\n")

    # Process function by function
    lines
    |> Enum.chunk_by(&function_boundary?/1)
    |> Enum.flat_map(fn chunk ->
      fix_function_chunk(chunk, old_var, new_var)
    end)
    |> Enum.join("\n")
  end

  defp function_boundary?(line) do
    line =~ ~r/^\s*(def|defp|defmacro|defmacrop)\s+/
  end

  defp fix_function_chunk(chunk, old_var, new_var) do
    # Check if this is a function definition
    first_line = List.first(chunk) || ""

    if function_boundary?(first_line) do
      # Check if the variable is used in the function body
      body_uses_var = chunk
        |> Enum.drop(1)  # Skip the definition line
        |> Enum.any?(fn line ->
          # Check if the line references the variable without underscore
          line =~ ~r/\b#{Regex.escape(String.slice(old_var, 1..-1//1))}\b/
        end)

      if body_uses_var do
        # Remove underscore from parameter and fix body references
        Enum.map(chunk, fn line ->
          if line =~ ~r/def/ && line =~ ~r/#{Regex.escape(old_var)}/ do
            # Fix parameter definition
            String.replace(line, old_var, new_var)
          else
            line
          end
        end)
      else
        chunk
      end
    else
      chunk
    end
  end

end

# Run the fixer
if System.argv() != [] or true do
  UndefinedVariableFixer.run(System.argv())
end