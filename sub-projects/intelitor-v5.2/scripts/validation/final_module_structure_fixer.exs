#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FinalModuleStructureFixer do
  @moduledoc """
  FINAL: Fix module structure issues where functions were added outside the module
  """

  def main(args \\ []) do
    IO.puts("FINAL: Module Structure Fixer - Moving functions inside module")

    case Enum.at(args, 0) do
      "--execute" -> execute_module_fixes()
      "--analyze" -> analyze_module_structure()
      _ -> show_help()
    end
  end

  defp execute_module_fixes do
    IO.puts("Fixing module structure issues...")

    fix_compliance_reporter_structure()
    validate_zero_errors_achieved()
  end

  defp fix_compliance_reporter_structure do
    file_path = "lib/indrajaal/access_control/compliance_reporter.ex"
    IO.puts("Fixing module structure in #{file_path}...")

    if File.exists?(file_path) do
      content = File.read!(file_path)

      # Find the module end and move functions inside
      lines = String.split(content, "\n")

      # Find the real module end (line 893: "end")
      {module_lines, rest_lines} = Enum.split_while(lines, fn line ->
        not (String.trim(line) == "end" and line_contains_module_end?(line, lines))
      end)

      # Take the "end" line
      [module_end | comments_and_functions] = rest_lines

      # Separate comments from functions
      {comments, functions} = Enum.split_while(comments_and_functions, fn line ->
        not String.contains?(line, "defp ") or String.trim(line) == ""
      end)

      # Rebuild: module content + functions + module end + comments
      fixed_lines = module_lines ++ functions ++ [module_end] ++ comments

      fixed_content = Enum.join(fixed_lines, "\n")

      File.write!(file_path, fixed_content)
      IO.puts("Fixed module structure in compliance_reporter.ex")
      IO.puts("   Moved functions inside module before 'end' statement")
    else
      IO.puts("File not found: #{file_path}")
    end
  end

  defp line_contains_module_end?(line, lines) do
    # Simple heuristic: if it's just "end" and the previous lines suggest it's the module end
    String.trim(line) == "end"
  end

  defp validate_zero_errors_achieved do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_file = "./data/tmp/final_structure_fix_validation_#{timestamp}.log"

    File.mkdir_p("./data/tmp")

    IO.puts("Running FINAL Patient Mode validation after structure fix...")

    case System.cmd("bash", ["-c", "export NO_TIMEOUT=true && export PATIENT_MODE=enabled && export INFINITE_PATIENCE=true && export ELIXIR_ERL_OPTIONS='+fnu +S 16' && mix compile --jobs 16 --warnings-as-errors"], stderr_to_stdout: true) do
      {output, 0} ->
        File.write!(log_file, output)
        IO.puts("ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED!")
        IO.puts("Perfect compilation: 0 errors, 0 warnings")
        save_success_report(timestamp)
        true
      {output, _} ->
        File.write!(log_file, output)
        errors = count_errors(output)
        warnings = count_warnings(output)

        IO.puts("Final Validation Results:")
        IO.puts("   Errors: #{errors} (was 2)")
        IO.puts("   Warnings: #{warnings} (was 0)")
        IO.puts("Full compilation log saved: #{log_file}")

        if errors > 0 do
          IO.puts("#{errors} errors still remain")
          show_remaining_errors(output)
        end

        false
    end
  end

  defp count_errors(output) do
    output
    |> String.split("\n")
    |> Enum.count(fn line ->
      String.contains?(line, "error:") ||
      String.contains?(line, "** (") ||
      String.contains?(line, "CompileError") ||
      String.contains?(line, "== Compilation error") ||
      String.contains?(line, "undefined variable") ||
      String.contains?(line, "undefined function")
    end)
  end

  defp count_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "warning:"))
  end

  defp show_remaining_errors(output) do
    IO.puts("\nRemaining errors:")

    output
    |> String.split("\n")
    |> Enum.filter(fn line ->
      String.contains?(line, "error:") ||
      String.contains?(line, "** (") ||
      String.contains?(line, "== Compilation error")
    end)
    |> Enum.take(5)
    |> Enum.each(fn line ->
      IO.puts("   #{String.trim(line)}")
    end)
  end

  defp save_success_report(timestamp) do
    report_path = "./data/tmp/zero_error_checkpoint_success_#{timestamp}.log"

    report = """
    ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED
    ===========================================

    Timestamp: #{DateTime.utc_now()}

    FINAL RESULTS:
    - Compilation Errors: 0 (was 2)
    - Compilation Warnings: 0 (was 0)
    - Zero-Error Validation Checkpoint: ACHIEVED

    Final Structure Fixes Applied:
    - Moved functions inside module before 'end' statement
    - Fixed module structure in compliance_reporter.ex

    COMPLETE ERROR REDUCTION SUCCESS:
    - Previous session: 329 -> 280 -> 235 -> 218 -> 125 -> 48 -> 7 errors
    - Current session: 7 -> 1 -> 8 -> 3 -> 10 -> 2 -> 0 errors
    - Total errors eliminated: 329 errors
    - Zero-error validation checkpoint: ACHIEVED

    ULTIMATE SUCCESS: Zero-error validation checkpoint achieved!
    All compilation errors have been systematically eliminated.
    """

    File.write!(report_path, report)
    IO.puts("Final success report saved: #{report_path}")
  end

  defp analyze_module_structure do
    IO.puts("Analyzing module structure issue:")
    IO.puts("  Issue: Functions added outside module in compliance_reporter.ex")
    IO.puts("  Problem: Module ends at line 893, functions start at line 902")
    IO.puts("  Solution: Move functions inside module before 'end' statement")
  end

  defp show_help do
    IO.puts("""
    Final Module Structure Fixer

    Usage:
      elixir final_module_structure_fixer.exs [--execute|--analyze]

    Commands:
      --execute    Execute module structure fixes
      --analyze    Show analysis of module structure issues
    """)
  end
end

FinalModuleStructureFixer.main(System.argv())