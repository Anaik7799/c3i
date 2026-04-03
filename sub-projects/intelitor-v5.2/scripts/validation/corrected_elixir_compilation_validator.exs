#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Indrajaal.Validation.CorrectedElixirCompilationValidator do
  @moduledoc """
  CORRECTED Elixir Compilation Validator - Post TPS Jidoka Analysis

  This corrected validator properly understands Elixir compilation log structure
  where warnings and errors span multiple lines in a specific format.

  Created: 2025-01-22 16:25:00 CET
  Agent: CS-001 (Syntax Error Specialist)
  Purpose: Fix FPPS validation accuracy issue identified in 5-Level RCA
  """

  require Logger

  def main(args \\ []) do
    options = parse_args(args)

    if options[:help] do
      print_help()
    else
      execute_corrected_validation(options)
    end
  end

  def execute_corrected_validation(options) do
    log_file = options[:log] || "1-compile.log"

    Logger.info("🔧 Corrected Elixir Compilation Validator (Post-Jidoka)")
    Logger.info("📅 Timestamp: #{DateTime.utc_now() |> DateTime.to_string()}")
    Logger.info("📄 Analyzing log file: #{log_file}")

    case File.read(log_file) do
      {:ok, content} ->
        # Use the corrected method that understands Elixir compilation structure
        result = validate_elixir_compilation_structure(content)

        Logger.info("📊 CORRECTED Results:")
        Logger.info("   Errors: #{result.error_count}")
        Logger.info("   Warnings: #{result.warning_count}")
        Logger.info("   Multi-line warnings properly parsed: #{result.multiline_warnings}")
        Logger.info("   Compilation status: #{result.compilation_status}")

        if options[:save_report] do
          save_corrected_report(result, options)
        end

        result

      {:error, reason} ->
        Logger.error("❌ Failed to read log file #{log_file}: #{reason}")
        System.halt(1)
    end
  end

  def validate_elixir_compilation_structure(content) do
    lines = String.split(content, "\n")

    # Parse Elixir compilation output properly understanding multi-line structure
    {errors, warnings, compilation_status} = parse_elixir_compilation_output(lines)

    %{
      errors: errors,
      warnings: warnings,
      error_count: length(errors),
      warning_count: length(warnings),
      multiline_warnings: count_multiline_warnings(warnings),
      compilation_status: compilation_status,
      method: :corrected_elixir_structure_parser,
      accuracy: :high,
      jidoka_validated: true
    }
  end

  defp parse_elixir_compilation_output(lines) do
    # State machine to parse Elixir compilation output properly
    {errors, warnings, _status} = parse_compilation_state_machine(lines)

    # Determine overall compilation status
    compilation_status = cond do
      length(errors) > 0 -> :failed_with_errors
      length(warnings) > 0 -> :succeeded_with_warnings
      true -> :succeeded_clean
    end

    {errors, warnings, compilation_status}
  end

  defp parse_compilation_state_machine(lines) do
    # Initialize parsing state
    initial_state = %{
      errors: [],
      warnings: [],
      current_item: nil,
      current_type: nil,
      current_lines: [],
      in_multiline: false
    }

    # Process lines with state machine
    final_state = Enum.reduce(lines, initial_state, &process_compilation_line/2)

    # Finalize any pending item
    final_state = finalize_current_item(final_state)

    {final_state.errors, final_state.warnings, :determined_by_content}
  end

  defp process_compilation_line(line, state) do
    cond do
      # Start of a new warning (FIXED: always finalize current first)
      String.contains?(line, "warning:") ->
        finalized_state = finalize_current_item(state)
        %{finalized_state |
          current_type: :warning,
          current_lines: [line],
          in_multiline: true,
          current_item: %{type: :warning, message: line, line_number: nil, file: nil}
        }

      # Start of a new error (FIXED: always finalize current first)
      String.contains?(line, "error:") ->
        finalized_state = finalize_current_item(state)
        %{finalized_state |
          current_type: :error,
          current_lines: [line],
          in_multiline: true,
          current_item: %{type: :error, message: line, line_number: nil, file: nil}
        }

      # File path line (contains "└─")
      String.contains?(line, "└─") && state.in_multiline ->
        # Extract file information
        file_info = parse_file_info(line)
        updated_item = Map.merge(state.current_item, file_info)
        %{state |
          current_item: updated_item,
          current_lines: state.current_lines ++ [line]
        }

      # Continuation line for current warning/error
      state.in_multiline && (String.starts_with?(line, "    ") || String.starts_with?(line, "  ") || line == "") ->
        %{state | current_lines: state.current_lines ++ [line]}

      # Empty line or end of current item
      line == "" && state.in_multiline ->
        finalize_current_item(state)

      # Regular compilation line - not part of warning/error
      true ->
        if state.in_multiline do
          # Check if this line indicates end of current warning/error
          if should_end_current_item?(line, state) do
            finalize_current_item(state)
          else
            %{state | current_lines: state.current_lines ++ [line]}
          end
        else
          state
        end
    end
  end

  defp should_end_current_item?(line, _state) do
    # Heuristics to determine if current warning/error block has ended
    cond do
      # New warning starts
      String.contains?(line, "warning:") -> true
      # New error starts
      String.contains?(line, "error:") -> true
      # Compilation progress line
      String.match?(line, ~r/^Compiling \d+ files/) -> true
      # Generated something line
      String.contains?(line, "Generated") -> true
      # Default: continue current item
      true -> false
    end
  end

  defp finalize_current_item(state) do
    if state.current_item && state.in_multiline do
      # Complete the current item with all collected lines
      completed_item = Map.merge(state.current_item, %{
        raw_content: Enum.join(state.current_lines, "\n"),
        line_count: length(state.current_lines)
      })

      case state.current_type do
        :warning ->
          %{state |
            warnings: state.warnings ++ [completed_item],
            current_item: nil,
            current_type: nil,
            current_lines: [],
            in_multiline: false
          }
        :error ->
          %{state |
            errors: state.errors ++ [completed_item],
            current_item: nil,
            current_type: nil,
            current_lines: [],
            in_multiline: false
          }
        _ ->
          %{state |
            current_item: nil,
            current_type: nil,
            current_lines: [],
            in_multiline: false
          }
      end
    else
      state
    end
  end

  defp parse_file_info(line) do
    # Extract file, line number from "└─ file.ex:line:col: Module.function/arity"
    case Regex.run(~r/└─ (.+):(\d+):(\d+): (.+)/, line) do
      [_, file, line_num, col, location] ->
        %{
          file: file,
          line_number: String.to_integer(line_num),
          column: String.to_integer(col),
          location: location
        }
      _ ->
        # Fallback parsing
        case Regex.run(~r/└─ (.+):(\d+)/, line) do
          [_, file, line_num] ->
            %{file: file, line_number: String.to_integer(line_num)}
          _ ->
            %{file: "unknown", line_number: 0}
        end
    end
  end

  defp count_multiline_warnings(warnings) do
    Enum.count(warnings, fn warning ->
      warning[:line_count] && warning.line_count > 1
    end)
  end

  defp save_corrected_report(result, _options) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    report_file = "./data/tmp/corrected_validation_report_#{timestamp}.json"

    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      validator: "corrected_elixir_compilation_validator",
      jidoka_analysis: "5_level_rca_completed",
      method: result.method,
      results: result,
      accuracy_improvement: "multi_line_warning_parsing_fixed",
      agent: "CS-001_syntax_error_specialist"
    }

    File.write!(report_file, Jason.encode!(report, pretty: true))
    Logger.info("📊 Corrected report saved to: #{report_file}")
  end

  defp parse_args(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        log: :string,
        save_report: :boolean,
        help: :boolean
      ],
      aliases: [
        l: :log,
        s: :save_report,
        h: :help
      ]
    )

    options
  end

  defp print_help do
    IO.puts """
    Corrected Elixir Compilation Validator (Post-TPS Jidoka Analysis)

    Usage: elixir corrected_elixir_compilation_validator.exs [OPTIONS]

    Options:
      -l, --log FILE       Specify log file (default: 1-compile.log)
      -s, --save-report    Save detailed report to ./data/tmp/
      -h, --help           Show this help

    This validator correctly parses Elixir compilation output understanding
    that warnings and errors span multiple lines in a structured format.

    Agent: CS-001 (Syntax Error Specialist)
    TPS Jidoka Analysis: Applied to fix FPPS validation accuracy issue
    """
  end
end

# Execute if run directly
if System.argv() |> length() > 0 || !IEx.started?() do
  Indrajaal.Validation.CorrectedElixirCompilationValidator.main(System.argv())
end