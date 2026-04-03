#!/usr/bin/env elixir

# Warning Parser - Extracts and categorizes all compilation warnings
# Usage: elixir scripts/analysis/warning_parser.exs ./data/tmp/20251011-1943-warning-analysis.log

defmodule WarningParser do
  def parse_log(file_path) do
    File.stream!(file_path)
    |> Enum.reduce({[], nil, []}, fn line, {warnings, current_file, current_warning} ->
      cond do
        # Track current file being compiled
        String.contains?(line, "Compiling ") ->
          file =
            line
            |> String.replace("Compiling ", "")
            |> String.replace(~r/\s+\(.*\)/, "")
            |> String.trim()

          {warnings, file, current_warning}

        # Start of a warning
        String.contains?(line, "warning:") ->
          warning_text =
            line
            |> String.split("warning: ")
            |> List.last()
            |> String.trim()

          {warnings, current_file, [warning_text]}

        # Line number and code location
        String.match?(line, ~r/^\s*\d+\s+│/) ->
          line_num =
            line
            |> String.split("│")
            |> List.first()
            |> String.trim()

          updated_warning = current_warning ++ [line_num]
          {warnings, current_file, updated_warning}

        # End of warning (empty line or next warning)
        current_warning != [] and (String.trim(line) == "" or String.contains?(line, "warning:")) ->
          if current_file && length(current_warning) >= 1 do
            warning_record = %{
              file: current_file,
              warning: Enum.at(current_warning, 0),
              line: Enum.at(current_warning, 1, "unknown")
            }

            if String.contains?(line, "warning:") do
              # Start new warning
              warning_text =
                line
                |> String.split("warning: ")
                |> List.last()
                |> String.trim()

              {[warning_record | warnings], current_file, [warning_text]}
            else
              {[warning_record | warnings], current_file, []}
            end
          else
            {warnings, current_file, []}
          end

        true ->
          {warnings, current_file, current_warning}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  def categorize_warnings(warnings) do
    warnings
    |> Enum.group_by(fn w ->
      cond do
        String.contains?(w.warning, "variable") && String.contains?(w.warning, "is unused") ->
          {:unused_variable, w.warning |> String.split("\"") |> Enum.at(1)}

        String.contains?(w.warning, "function") && String.contains?(w.warning, "is unused") ->
          {:unused_function, w.warning |> String.split(" ") |> Enum.at(1)}

        String.contains?(w.warning, "clauses with the same name") ->
          :clause_grouping

        String.contains?(w.warning, "module attribute") ->
          :module_attribute

        String.contains?(w.warning, "underscored variable") &&
            String.contains?(w.warning, "is used") ->
          :underscored_used

        String.contains?(w.warning, "unknown compiler variable") ->
          :unknown_compiler_var

        true ->
          :other
      end
    end)
  end

  def print_summary(categorized) do
    IO.puts("\n=== WARNING ANALYSIS SUMMARY ===\n")

    # Count by category
    Enum.each(categorized, fn {category, warnings} ->
      case category do
        {:unused_variable, var_name} ->
          IO.puts("Unused variable '#{var_name}': #{length(warnings)} occurrences")

          warnings
          |> Enum.take(3)
          |> Enum.each(fn w ->
            IO.puts("  - #{w.file}:#{w.line}")
          end)

          if length(warnings) > 3, do: IO.puts("  ... and #{length(warnings) - 3} more")
          IO.puts("")

        {:unused_function, func} ->
          IO.puts("Unused function #{func}: #{length(warnings)} occurrences")

          Enum.each(warnings, fn w ->
            IO.puts("  - #{w.file}:#{w.line}")
          end)

          IO.puts("")

        :clause_grouping ->
          IO.puts("Clause grouping issues: #{length(warnings)} occurrences")

          Enum.each(warnings, fn w ->
            IO.puts("  - #{w.file}:#{w.line}: #{w.warning}")
          end)

          IO.puts("")

        other ->
          IO.puts("#{inspect(other)}: #{length(warnings)} occurrences")

          warnings
          |> Enum.take(3)
          |> Enum.each(fn w ->
            IO.puts("  - #{w.file}:#{w.line}: #{String.slice(w.warning, 0..80)}")
          end)

          if length(warnings) > 3, do: IO.puts("  ... and #{length(warnings) - 3} more")
          IO.puts("")
      end
    end)

    IO.puts(
      "\nTotal warnings: #{Enum.map(categorized, fn {_, ws} -> length(ws) end) |> Enum.sum()}"
    )
  end
end

# Main execution
case System.argv() do
  [log_file] ->
    warnings = WarningParser.parse_log(log_file)
    categorized = WarningParser.categorize_warnings(warnings)
    WarningParser.print_summary(categorized)

    # Also generate a detailed report
    report_file = Path.dirname(log_file) <> "/warning_analysis_report.txt"

    File.write!(report_file, """
    # Detailed Warning Report
    # Generated: #{DateTime.utc_now()}
    # Total warnings: #{length(warnings)}

    #{Enum.map_join(warnings, "\n", fn w -> "#{w.file}:#{w.line} - #{w.warning}" end)}
    """)

    IO.puts("\nDetailed report saved to: #{report_file}")

  _ ->
    IO.puts("Usage: elixir scripts/analysis/warning_parser.exs <log_file>")
    System.halt(1)
end
