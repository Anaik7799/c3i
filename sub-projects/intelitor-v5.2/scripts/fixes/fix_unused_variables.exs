#!/usr/bin/env elixir

defmodule UnusedVariableFixer do
  @moduledoc """
  Fixes unused variable warnings by adding underscore prefix.

  Changes variable names to _variable in function definitions where the
  compiler reports the variable as unused.
  """

  def fix_file(file_path, unused_vars) do
    IO.puts("\n📝 Processing: #{Path.basename(file_path)}")

    content = File.read!(file_path)

    # Apply fixes for each unused variable in this file
    fixed_content = Enum.reduce(unused_vars, content, fn var_name, acc ->
      acc
      # Pattern 1: Function parameter with type annotation
      # Example: defp function_name(opts :: map())
      |> then(fn text ->
        Regex.replace(
          ~r/\b(defp?\s+\w+\([^)]*)\b#{var_name}\b(\s*::\s*\w+\(\))?([^)]*)\)/,
          text,
          fn _match, before, type_annotation, after_part ->
            "#{before}_#{var_name}#{type_annotation || ""}#{after_part})"
          end
        )
      end)
      # Pattern 2: Simple function parameter
      # Example: defp function_name(opts, other)
      |> then(fn text ->
        Regex.replace(
          ~r/\b(defp?\s+\w+\([^)]*)\b#{var_name}\b([,\)])/,
          text,
          "\\g{1}_#{var_name}\\g{2}"
        )
      end)
      # Pattern 3: Pattern matching in function head
      # Example: def function_name(%{opts: opts} = params)
      |> then(fn text ->
        Regex.replace(
          ~r/\b#{var_name}:\s*#{var_name}\b/,
          text,
          "#{var_name}: _#{var_name}"
        )
      end)
      # Pattern 4: Case/with clause binding
      # Example: {:ok, opts} -> ...
      |> then(fn text ->
        Regex.replace(
          ~r/(\{[^}]*)\b#{var_name}\b(\})/,
          text,
          "\\g{1}_#{var_name}\\g{2}"
        )
      end)
    end)

    if content != fixed_content do
      # Create backup
      backup_path = file_path <> ".backup"
      File.write!(backup_path, content)

      # Write fixed content
      File.write!(file_path, fixed_content)

      IO.puts("✅ Fixed #{Path.basename(file_path)}")
      IO.puts("   Variables fixed: #{Enum.join(unused_vars, ", ")}")
      IO.puts("   Backup created: #{backup_path}")
      {:ok, :fixed, length(unused_vars)}
    else
      IO.puts("ℹ️  No changes needed for #{Path.basename(file_path)}")
      {:ok, :no_changes, 0}
    end
  end

  def parse_warnings(compile_log) do
    content = File.read!(compile_log)

    # Parse warnings: extract file path and variable name
    # Format:
    #   └─ lib/some/file.ex:123:45: Module.function/1
    #   warning: variable "varname" is unused

    lines = String.split(content, "\n")

    warnings = lines
    |> Enum.chunk_every(10, 1, :discard)  # Look at 10-line windows
    |> Enum.flat_map(fn chunk ->
      # Find lines with file paths (└─ prefix)
      file_lines = Enum.with_index(chunk)
      |> Enum.filter(fn {line, _idx} -> String.contains?(line, "└─") end)

      # Find lines with unused variable warnings
      warning_lines = Enum.with_index(chunk)
      |> Enum.filter(fn {line, _idx} ->
        String.contains?(line, ~s(variable ")) and String.contains?(line, "is unused")
      end)

      # Match file paths with their warnings (warning typically comes after file path)
      for {file_line, file_idx} <- file_lines,
          {warning_line, warning_idx} <- warning_lines,
          warning_idx > file_idx do

        file_match = Regex.run(~r/└─ ([^:]+\.ex):\d+/, file_line)
        var_match = Regex.run(~r/variable "([^"]+)"/, warning_line)

        if file_match && var_match do
          file_path = Enum.at(file_match, 1)
          var_name = Enum.at(var_match, 1)
          {file_path, var_name}
        end
      end
      |> Enum.reject(&is_nil/1)
    end)

    # Group by file
    warnings
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.into(%{})
  end

  def fix_all_warnings(compile_log) do
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("Unused Variable Fixer")
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("\nParsing warnings from: #{compile_log}\n")

    warnings_by_file = parse_warnings(compile_log)

    IO.puts("Found unused variables in #{map_size(warnings_by_file)} files\n")

    results = Enum.map(warnings_by_file, fn {file, vars} ->
      unique_vars = Enum.uniq(vars)
      fix_file(file, unique_vars)
    end)

    fixed_count = Enum.count(results, fn {_, status, _} -> status == :fixed end)
    unchanged_count = Enum.count(results, fn {_, status, _} -> status == :no_changes end)
    total_vars_fixed = Enum.sum(Enum.map(results, fn {_, _, count} -> count end))

    IO.puts("\n" <> String.duplicate("=", 72))
    IO.puts("Summary:")
    IO.puts("  Total files analyzed: #{map_size(warnings_by_file)}")
    IO.puts("  Files fixed: #{fixed_count}")
    IO.puts("  Files unchanged: #{unchanged_count}")
    IO.puts("  Total variables fixed: #{total_vars_fixed}")
    IO.puts(String.duplicate("=", 72))
  end
end

# Run the fixer
compile_log = System.argv() |> List.first() || "./data/tmp/2-compile.log"
UnusedVariableFixer.fix_all_warnings(compile_log)
