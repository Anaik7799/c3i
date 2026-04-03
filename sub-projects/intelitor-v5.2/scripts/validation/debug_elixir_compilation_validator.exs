#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Indrajaal.Validation.DebugElixirCompilationValidator do
  @moduledoc """
  DEBUG version of the Elixir Compilation Validator with extensive logging

  This debug validator traces every parsing step to identify where the original
  validator is failing on the fresh compilation log.

  Created: 2025-01-22 17:55:00 CET
  Agent: CS-001 (Syntax Error Specialist)
  Purpose: Debug state machine parser that's only detecting 1 warning from dozens
  """

  require Logger

  def main(args \\ []) do
    options = parse_args(args)

    if options[:help] do
      print_help()
    else
      execute_debug_validation(options)
    end
  end

  def execute_debug_validation(options) do
    log_file = options[:log] || "1-compile-fresh.log"

    Logger.info("🔧 DEBUG Elixir Compilation Validator")
    Logger.info("📅 Timestamp: #{DateTime.utc_now() |> DateTime.to_string()}")
    Logger.info("📄 Analyzing log file: #{log_file}")

    case File.read(log_file) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        Logger.info("📊 Total lines to process: #{length(lines)}")

        # Use debug version with extensive logging
        result = validate_with_debug_logging(lines)

        Logger.info("📊 DEBUG Results:")
        Logger.info("   Errors: #{result.error_count}")
        Logger.info("   Warnings: #{result.warning_count}")
        Logger.info("   Total items processed: #{length(result.errors) + length(result.warnings)}")
        Logger.info("   Compilation status: #{result.compilation_status}")

        if options[:save_report] do
          save_debug_report(result, options)
        end

        result

      {:error, reason} ->
        Logger.error("❌ Failed to read log file #{log_file}: #{reason}")
        System.halt(1)
    end
  end

  def validate_with_debug_logging(lines) do
    Logger.info("🔍 Starting state machine parsing with debug logging...")

    # Initialize parsing state
    initial_state = %{
      errors: [],
      warnings: [],
      current_item: nil,
      current_type: nil,
      current_lines: [],
      in_multiline: false,
      processed_lines: 0,
      skipped_lines: 0,
      warning_starts: 0,
      error_starts: 0,
      finalizations: 0
    }

    # Process lines with extensive debug logging
    final_state = Enum.with_index(lines)
                  |> Enum.reduce(initial_state, fn {line, index}, state ->
                    process_line_with_debug(line, index, state)
                  end)

    # Finalize any pending item
    Logger.info("🔍 Finalizing any pending item...")
    final_state = finalize_current_item_debug(final_state)

    # Log final statistics
    Logger.info("📊 PARSING STATISTICS:")
    Logger.info("   Lines processed: #{final_state.processed_lines}")
    Logger.info("   Lines skipped: #{final_state.skipped_lines}")
    Logger.info("   Warning starts detected: #{final_state.warning_starts}")
    Logger.info("   Error starts detected: #{final_state.error_starts}")
    Logger.info("   Items finalized: #{final_state.finalizations}")
    Logger.info("   Final errors collected: #{length(final_state.errors)}")
    Logger.info("   Final warnings collected: #{length(final_state.warnings)}")

    # Determine compilation status
    compilation_status = cond do
      length(final_state.errors) > 0 -> :failed_with_errors
      length(final_state.warnings) > 0 -> :succeeded_with_warnings
      true -> :succeeded_clean
    end

    %{
      errors: final_state.errors,
      warnings: final_state.warnings,
      error_count: length(final_state.errors),
      warning_count: length(final_state.warnings),
      compilation_status: compilation_status,
      method: :debug_state_machine_parser,
      debug_stats: %{
        processed_lines: final_state.processed_lines,
        skipped_lines: final_state.skipped_lines,
        warning_starts: final_state.warning_starts,
        error_starts: final_state.error_starts,
        finalizations: final_state.finalizations
      }
    }
  end

  defp process_line_with_debug(line, index, state) do
    # Log every 50th line for progress tracking
    if rem(index, 50) == 0 do
      Logger.info("🔍 Processing line #{index + 1}: in_multiline=#{state.in_multiline}, current_type=#{state.current_type}")
    end

    # Detailed logging for warning and error detection
    warning_detected = String.contains?(line, "warning:")
    error_detected = String.contains?(line, "error:")

    if warning_detected or error_detected do
      Logger.info("🚨 Line #{index + 1}: #{if warning_detected, do: "WARNING", else: "ERROR"} detected: '#{String.slice(line, 0, 80)}...'")
      Logger.info("   Current state: in_multiline=#{state.in_multiline}, current_type=#{state.current_type}")
    end

    new_state = cond do
      # Start of a new warning
      warning_detected && !state.in_multiline ->
        Logger.info("✅ Line #{index + 1}: Starting new WARNING")
        finalized_state = finalize_current_item_debug(state)
        new_state = %{finalized_state |
          current_type: :warning,
          current_lines: [line],
          in_multiline: true,
          current_item: %{type: :warning, message: line, line_number: nil, file: nil},
          warning_starts: finalized_state.warning_starts + 1,
          processed_lines: finalized_state.processed_lines + 1
        }
        Logger.info("   New state: in_multiline=#{new_state.in_multiline}, warnings_collected=#{length(new_state.warnings)}")
        new_state

      # Start of a new error
      error_detected && !state.in_multiline ->
        Logger.info("✅ Line #{index + 1}: Starting new ERROR")
        finalized_state = finalize_current_item_debug(state)
        new_state = %{finalized_state |
          current_type: :error,
          current_lines: [line],
          in_multiline: true,
          current_item: %{type: :error, message: line, line_number: nil, file: nil},
          error_starts: finalized_state.error_starts + 1,
          processed_lines: finalized_state.processed_lines + 1
        }
        Logger.info("   New state: in_multiline=#{new_state.in_multiline}, errors_collected=#{length(new_state.errors)}")
        new_state

      # File path line (contains "└─")
      String.contains?(line, "└─") && state.in_multiline ->
        if rem(index, 50) == 0 || warning_detected || error_detected do
          Logger.info("📍 Line #{index + 1}: File path line detected")
        end
        file_info = parse_file_info(line)
        updated_item = Map.merge(state.current_item, file_info)
        %{state |
          current_item: updated_item,
          current_lines: state.current_lines ++ [line],
          processed_lines: state.processed_lines + 1
        }

      # Continuation line for current warning/error
      state.in_multiline && (String.starts_with?(line, "    ") || String.starts_with?(line, "  ") || line == "") ->
        %{state |
          current_lines: state.current_lines ++ [line],
          processed_lines: state.processed_lines + 1
        }

      # Empty line or end of current item
      line == "" && state.in_multiline ->
        Logger.info("🔚 Line #{index + 1}: Empty line - finalizing current item")
        finalize_current_item_debug(state)

      # Regular compilation line - not part of warning/error
      true ->
        if state.in_multiline do
          # Check if this line indicates end of current warning/error
          should_end = should_end_current_item_debug?(line, state, index)
          if should_end do
            Logger.info("🔚 Line #{index + 1}: End condition detected - finalizing current item")
            Logger.info("   Line content: '#{String.slice(line, 0, 80)}...'")
            finalize_current_item_debug(state)
          else
            %{state |
              current_lines: state.current_lines ++ [line],
              processed_lines: state.processed_lines + 1
            }
          end
        else
          %{state | skipped_lines: state.skipped_lines + 1}
        end
    end

    new_state
  end

  defp should_end_current_item_debug?(line, _state, index) do
    # Heuristics to determine if current warning/error block has ended
    result = cond do
      # New warning starts
      String.contains?(line, "warning:") ->
        Logger.info("🔚 Line #{index + 1}: New warning detected - ending current item")
        true
      # New error starts
      String.contains?(line, "error:") ->
        Logger.info("🔚 Line #{index + 1}: New error detected - ending current item")
        true
      # Compilation progress line
      String.match?(line, ~r/^Compiling \d+ files/) ->
        Logger.info("🔚 Line #{index + 1}: Compilation progress line - ending current item")
        true
      # Generated something line
      String.contains?(line, "Generated") ->
        Logger.info("🔚 Line #{index + 1}: Generated line - ending current item")
        true
      # Default: continue current item
      true -> false
    end

    result
  end

  defp finalize_current_item_debug(state) do
    if state.current_item && state.in_multiline do
      Logger.info("🔄 Finalizing item: type=#{state.current_type}, lines_collected=#{length(state.current_lines)}")

      # Complete the current item with all collected lines
      completed_item = Map.merge(state.current_item, %{
        raw_content: Enum.join(state.current_lines, "\n"),
        line_count: length(state.current_lines)
      })

      new_state = case state.current_type do
        :warning ->
          Logger.info("✅ Adding WARNING to collection (total will be #{length(state.warnings) + 1})")
          %{state |
            warnings: state.warnings ++ [completed_item],
            current_item: nil,
            current_type: nil,
            current_lines: [],
            in_multiline: false,
            finalizations: state.finalizations + 1
          }
        :error ->
          Logger.info("✅ Adding ERROR to collection (total will be #{length(state.errors) + 1})")
          %{state |
            errors: state.errors ++ [completed_item],
            current_item: nil,
            current_type: nil,
            current_lines: [],
            in_multiline: false,
            finalizations: state.finalizations + 1
          }
        _ ->
          Logger.info("⚠️ Unknown current_type: #{state.current_type}")
          %{state |
            current_item: nil,
            current_type: nil,
            current_lines: [],
            in_multiline: false,
            finalizations: state.finalizations + 1
          }
      end

      Logger.info("   New state: warnings=#{length(new_state.warnings)}, errors=#{length(new_state.errors)}")
      new_state
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

  defp save_debug_report(result, _options) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./data/tmp/debug_validation_report_#{timestamp}.json"

    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      validator: "debug_elixir_compilation_validator",
      purpose: "debug_state_machine_parsing_failure",
      method: result.method,
      results: result,
      debug_analysis: "extensive_logging_to_identify_parsing_failure"
    }

    File.write!(report_file, Jason.encode!(report, pretty: true))
    Logger.info("📊 Debug report saved to: #{report_file}")
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
    DEBUG Elixir Compilation Validator

    Usage: elixir debug_elixir_compilation_validator.exs [OPTIONS]

    Options:
      -l, --log FILE       Specify log file (default: 1-compile-fresh.log)
      -s, --save-report    Save detailed debug report to ./data/tmp/
      -h, --help           Show this help

    This debug validator traces every step of the state machine parsing
    to identify why the corrected validator is only detecting 1 warning
    when the log clearly contains dozens of warnings and errors.
    """
  end
end

# Execute if run directly
if System.argv() |> length() > 0 || !IEx.started?() do
  Indrajaal.Validation.DebugElixirCompilationValidator.main(System.argv())
end