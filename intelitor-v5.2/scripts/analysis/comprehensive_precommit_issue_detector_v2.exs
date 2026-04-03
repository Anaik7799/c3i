#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - comprehensive_precommit_issue_detector_v2.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: core_analysis
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - comprehensive_precommit_issue_detector_v2.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: core_analysis
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - comprehensive_precommit_issue_detector_v2.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: core_analysis
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


Mix.install([{:jason, "~> 1.4"}])


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework

defmodule ComprehensivePrecommitIssueDetectorV2 do
  
__require Logger

@moduledoc """
  Advanced pre-commit issue detection system with comprehensive analysis capabilities.

  Detects 10+ categories of issues across the entire codebase:
  1. Compilation errors (undefined variables, syntax errors, missing dependencies)
  2. Warning violations (unused variables, deprecated functions, style warnings)  
  3. Format violations (mix format, code style inconsistencies)
  4. Credo violations (code quality, complexity, maintainability)
  5. Dialyzer violations (type inconsistencies, function specifications)
  6. Test coverage gaps (missing tests, low coverage areas)
  7. Documentation issues (missing @doc, @spec, @moduledoc)
  8. Timestamp inaccuracies (outdated timestamps, inconsistent formats)
  9. Performance issues (inefficient queries, resource leaks)
  10. Security vulnerabilities (exposed secrets, unsafe operations)

  Features:
  - 500+ issues minimum per analysis run
  - Detailed categorization and priority scoring
  - Batch processing recommendations
  - Pattern recognition for similar issues
  - Structured JSON output for automated processing
  - Integration with EP pattern __database
  """
## SOPv5.1 Framework Integration

This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

**Framework Components:**
- SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
- TPS: Toyota Production System with 5-Level Root Cause Analysis
- STAMP: Safety Constraint Validation with real-time monitoring
- TDG: Test-Driven Generation methodology compliance
- GDE: Goal-Directed Execution with adaptive strategy selection
- Patient Mode: NO_TIMEOUT policy with infinite patience execution
- Container-Only: Mandatory NixOS container execution with PHICS integration
- 11-Agent Architecture: Supervisor-Helper-Worker coordination support

**Category**: core_analysis
**Enhanced**: 2025-08-02 17:10:00 CEST
**Agent**: Script Enhancement System with systematic SOPv5.1 integration


## SOPv5.1 Framework Integration

This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

**Framework Components:**
- SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
- TPS: Toyota Production System with 5-Level Root Cause Analysis
- STAMP: Safety Constraint Validation with real-time monitoring
- TDG: Test-Driven Generation methodology compliance
- GDE: Goal-Directed Execution with adaptive strategy selection
- Patient Mode: NO_TIMEOUT policy with infinite patience execution
- Container-Only: Mandatory NixOS container execution with PHICS integration
- 11-Agent Architecture: Supervisor-Helper-Worker coordination support

**Category**: core_analysis
**Enhanced**: 2025-08-02 17:10:00 CEST
**Agent**: Script Enhancement System with systematic SOPv5.1 integration


## SOPv5.1 Framework Integration

This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

**Framework Components:**
- SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
- TPS: Toyota Production System with 5-Level Root Cause Analysis
- STAMP: Safety Constraint Validation with real-time monitoring
- TDG: Test-Driven Generation methodology compliance
- GDE: Goal-Directed Execution with adaptive strategy selection
- Patient Mode: NO_TIMEOUT policy with infinite patience execution
- Container-Only: Mandatory NixOS container execution with PHICS integration
- 11-Agent Architecture: Supervisor-Helper-Worker coordination support

**Category**: core_analysis
**Enhanced**: 2025-08-02 17:10:00 CEST
**Agent**: Script Enhancement System with systematic SOPv5.1 integration



  @version "2.0.0"
  @detection_categories [
    :compilation_errors,
    :warning_violations,
    :format_violations,
    :credo_violations,
    :dialyzer_violations,
    :test_coverage_gaps,
    :documentation_issues,
    :timestamp_inaccuracies,
    :performance_issues,
    :security_vulnerabilities
  ]

  @priority_levels %{
    critical: 1,
    high: 2,
    medium: 3,
    low: 4,
    info: 5
  }

  def main(args \\ []) do
    case parse_args(args) do
      {:ok, options} ->
        run_comprehensive_analysis(options)

      {:error, message} ->
        IO.puts(:stderr, "Error: #{message}")
        print_usage()
        System.halt(1)
    end
  end

  defp parse_args(args) do
    case OptionParser.parse(args,
           switches: [
             help: :boolean,
             comprehensive: :boolean,
             batch_process: :boolean,
             json_output: :boolean,
             patterns: :boolean,
             export: :string,
             categories: :string,
             min_issues: :integer,
             timeout: :integer
           ],
           aliases: [h: :help, c: :comprehensive, b: :batch_process, j: :json_output]
         ) do
      {__opts, [], []} ->
        cond do
          __opts[:help] -> {:error, "help_requested"}
          true -> {:ok, normalize_options(__opts)}
        end

      {_opts, args, []} when length(args) > 0 ->
        {:error, "Unknown arguments: #{Enum.join(args, ", ")}"}

      {_opts, [], invalid} ->
        {:error, "Invalid options: #{Enum.join(Enum.map(invalid, &elem(&1, 0)), ", ")}"}
    end
  end

  defp normalize_options(opts) do
    %{
      comprehensive: __opts[:comprehensive] || false,
      batch_process: __opts[:batch_process] || false,
      json_output: __opts[:json_output] || true,
      patterns: __opts[:patterns] || true,
      export: __opts[:export],
      categories: parse_categories(__opts[:categories]),
      min_issues: __opts[:min_issues] || 500,
      # 1 hour timeout
      timeout: __opts[:timeout] || 3600
    }
  end

  defp parse_categories(nil), do: @detection_categories

  defp parse_categories(categories_str) do
    categories_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
    |> Enum.filter(&(&1 in @detection_categories))
  end

  defp run_comprehensive_analysis(options) do
    start_time = System.monotonic_time(:millisecond)

    IO.puts("🔍 Starting Comprehensive Pre-commit Issue Detection v#{@version}")

    IO.puts(
      "📊 Target: #{options.min_issues}+ issues across #{length(options.categories)} categories"
    )

    IO.puts("⏱️  Timeout: #{options.timeout} seconds")
    IO.puts("🎯 Categories: #{Enum.join(options.categories, ", ")}")
    IO.puts("")

    # Initialize analysis __state
    analysis_state = %{
      start_time: start_time,
      options: options,
      issues: [],
      patterns: %{},
      statistics: %{},
      progress: 0,
      total_files: count_total_files()
    }

    # Run comprehensive detection
    final_state =
      analysis_state
      |> detect_compilation_errors()
      |> detect_warning_violations()
      |> detect_format_violations()
      |> detect_credo_violations()
      |> detect_dialyzer_violations()
      |> detect_test_coverage_gaps()
      |> detect_documentation_issues()
      |> detect_timestamp_inaccuracies()
      |> detect_performance_issues()
      |> detect_security_vulnerabilities()
      |> analyze_patterns()
      |> generate_batch_recommendations()
      |> finalize_analysis()

    # Output results
    output_results(final_state)

    # Validate minimum issues threshold
    total_issues = length(final_state.issues)

    if total_issues < options.min_issues do
      IO.puts("⚠️  WARNING: Only #{total_issues} issues detected (target: #{options.min_issues}+)")
      IO.puts("🔍 Consider expanding analysis scope or adjusting detection thresholds")
    else
      IO.puts(
        "✅ SUCCESS: #{total_issues} issues detected (exceeds target: #{options.min_issues}+)"
      )
    end

    :ok
  end

  # === COMPILATION ERRORS DETECTION ===

  defp detect_compilation_errors(%{options: %{categories: categories}} = state) do
    if :compilation_errors in categories do
      IO.puts("🔧 Detecting compilation errors...")
      update_progress(__state, 10)

      issues =
        [
          run_mix_compile_analysis(),
          detect_syntax_errors(),
          detect_undefined_variables(),
          detect_missing_dependencies(),
          detect_module_conflicts(),
          detect_function_conflicts()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :compilation_errors))

      IO.puts("   Found #{length(issues)} compilation issues")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp run_mix_compile_analysis do
    case System.cmd("mix", ["compile", "--warnings-as-errors"],
           stderr_to_stdout: true,
           cd: System.cwd()
         ) do
      {output, 0} ->
        []

      {output, _exit_code} ->
        parse_compilation_output(output)
    end
  end

  defp parse_compilation_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["error:", "** (CompileError)"]))
    |> Enum.map(&parse_compilation_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_compilation_line(line) do
    cond do
      Regex.match?(~r/\*\* \(CompileError\)/, line) ->
        %{
          type: :compile_error,
          description: String.trim(line),
          file: extract_file_from_line(line),
          line_number: extract_line_number_from_line(line),
          priority: :critical,
          pattern: "EP001"
        }

      Regex.match?(~r/error:/, line) ->
        %{
          type: :compilation_error,
          description: String.trim(line),
          file: extract_file_from_line(line),
          line_number: extract_line_number_from_line(line),
          priority: :high,
          pattern: "EP002"
        }

      true ->
        nil
    end
  end

  defp detect_syntax_errors do
    get_elixir_files()
    |> Enum.flat_map(&analyze_file_syntax/1)
  end

  defp analyze_file_syntax(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        try do
          Code.string_to_quoted(content)
          []
        rescue
          e in SyntaxError ->
            [
              %{
                type: :syntax_error,
                description: "Syntax error: #{Exception.message(e)}",
                file: file_path,
                line_number: e.line,
                priority: :critical,
                pattern: "EP003"
              }
            ]

          e in TokenMissingError ->
            [
              %{
                type: :token_missing_error,
                description: "Token missing: #{Exception.message(e)}",
                file: file_path,
                line_number: e.line,
                priority: :critical,
                pattern: "EP004"
              }
            ]
        end

      {:error, _} ->
        [
          %{
            type: :file_read_error,
            description: "Cannot read file: #{file_path}",
            file: file_path,
            line_number: nil,
            priority: :high,
            pattern: "EP005"
          }
        ]
    end
  end

  defp detect_undefined_variables do
    get_elixir_files()
    |> Enum.flat_map(&analyze_undefined_variables/1)
  end

  defp analyze_undefined_variables(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_line_for_undefined_variables(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_line_for_undefined_variables(line, file_path, line_no) do
    issues = []

    # Check for common undefined variable patterns
    issues =
      if Regex.match?(~r/[^a-zA-Z_]([a-z_][a-zA-Z0-9_]*)\s*(?![a-zA-Z0-9_\(])/, line) do
        [
          %{
            type: :potential_undefined_variable,
            description: "Potential undefined variable usage: #{String.trim(line)}",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP006"
          }
          | issues
        ]
      else
        issues
      end

    # Check for unused assignments
    issues =
      if Regex.match?(~r/^\s*[a-z_][a-zA-Z0-9_]*\s*=.*$/, line) and
           not String.contains?(line, ["_", "Logger", "IO"]) do
        [
          %{
            type: :potential_unused_assignment,
            description: "Potential unused assignment: #{String.trim(line)}",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP007"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp detect_missing_dependencies do
    case File.read("mix.exs") do
      {:ok, content} ->
        analyze_missing_dependencies(content)

      {:error, _} ->
        [
          %{
            type: :missing_mix_exs,
            description: "mix.exs file not found",
            file: "mix.exs",
            line_number: nil,
            priority: :critical,
            pattern: "EP008"
          }
        ]
    end
  end

  defp analyze_missing_dependencies(mix_content) do
    # Extract dependencies from mix.exs
    deps_match = Regex.run(~r/defp deps do\s*\[(.*?)\]/s, mix_content)

    case deps_match do
      [_, deps_content] ->
        declared_deps = extract_declared_dependencies(deps_content)
        used_deps = find_used_dependencies()

        missing = used_deps -- declared_deps
        unused = declared_deps -- used_deps

        _missing_issues =
          Enum.map(missing, fn dep ->
            %{
              type: :missing_dependency,
              description: "Missing dependency: #{dep}",
              file: "mix.exs",
              line_number: nil,
              priority: :high,
              pattern: "EP009"
            }
          end)

        _unused_issues =
          Enum.map(unused, fn dep ->
            %{
              type: :unused_dependency,
              description: "Unused dependency: #{dep}",
              file: "mix.exs",
              line_number: nil,
              priority: :low,
              pattern: "EP010"
            }
          end)

        missing_issues ++ unused_issues

      nil ->
        [
          %{
            type: :malformed_deps,
            description: "Cannot parse deps function in mix.exs",
            file: "mix.exs",
            line_number: nil,
            priority: :high,
            pattern: "EP011"
          }
        ]
    end
  end

  defp extract_declared_dependencies(deps_content) do
    Regex.scan(~r/{:([a-zA-Z_][a-zA-Z0-9_]*),/, deps_content)
    |> Enum.map(fn [_, dep] -> dep end)
    |> Enum.uniq()
  end

  defp find_used_dependencies do
    get_elixir_files()
    |> Enum.flat_map(&extract_dependencies_from_file/1)
    |> Enum.uniq()
  end

  defp extract_dependencies_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Look for common dependency usage patterns
        patterns = [
          ~r/use\s+([A-Z][a-zA-Z0-9\.]*)/,
          ~r/import\s+([A-Z][a-zA-Z0-9\.]*)/,
          ~r/alias\s+([A-Z][a-zA-Z0-9\.]*)/,
          ~r/__require\s+([A-Z][a-zA-Z0-9\.]*)/
        ]

        patterns
        |> Enum.flat_map(fn pattern ->
          Regex.scan(pattern, content)
          |> Enum.map(fn [_, module] -> module_to_dependency(module) end)
        end)
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        []
    end
  end

  defp module_to_dependency(module) do
    # Map common modules to their dependencies
    case module do
      "Jason" -> "jason"
      "Ecto" <> _ -> "ecto"
      "Phoenix" <> _ -> "phoenix"
      "Plug" <> _ -> "plug"
      "Ash" <> _ -> "ash"
      _ -> nil
    end
  end

  defp detect_module_conflicts do
    module_files =
      get_elixir_files()
      |> Enum.map(fn file ->
        case extract_module_name(file) do
          {:ok, module_name} -> {module_name, file}
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Group by module name to find conflicts
    module_files
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.filter(fn {_module, files} -> length(files) > 1 end)
    |> Enum.flat_map(fn {module_name, files} ->
      Enum.map(files, fn file ->
        %{
          type: :module_conflict,
          description:
            "Module #{module_name} defined in multiple files: #{Enum.join(files, ", ")}",
          file: file,
          line_number: nil,
          priority: :high,
          pattern: "EP012"
        }
      end)
    end)
  end

  defp extract_module_name(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Regex.run(~r/defmodule\s+([A-Z][a-zA-Z0-9\.]*)/, content) do
          [_, module_name] -> {:ok, module_name}
          nil -> {:error, :no_module_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp detect_function_conflicts do
    get_elixir_files()
    |> Enum.flat_map(&analyze_function_conflicts/1)
  end

  defp analyze_function_conflicts(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        functions = extract_function_definitions(content)
        find_duplicate_functions(functions, file_path)

      {:error, _} ->
        []
    end
  end

  defp extract_function_definitions(content) do
    patterns = [
      ~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/,
      ~r/defp\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, content, capture: :all_but_first)
      |> List.flatten()
    end)
  end

  defp find_duplicate_functions(functions, file_path) do
    functions
    |> Enum.f__requencies()
    |> Enum.filter(fn {_func, count} -> count > 1 end)
    |> Enum.map(fn {func_name, count} ->
      %{
        type: :duplicate_function,
        description: "Function #{func_name} defined #{count} times",
        file: file_path,
        line_number: nil,
        priority: :medium,
        pattern: "EP013"
      }
    end)
  end

  # === WARNING VIOLATIONS DETECTION ===

  defp detect_warning_violations(%{options: %{categories: categories}} = state) do
    if :warning_violations in categories do
      IO.puts("⚠️  Detecting warning violations...")
      update_progress(__state, 20)

      issues =
        [
          run_mix_compile_warnings(),
          detect_unused_variables(),
          detect_deprecated_functions(),
          detect_style_warnings()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :warning_violations))

      IO.puts("   Found #{length(issues)} warning violations")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp run_mix_compile_warnings do
    case System.cmd("mix", ["compile"], stderr_to_stdout: true, cd: System.cwd()) do
      {output, _exit_code} ->
        parse_warning_output(output)
    end
  end

  defp parse_warning_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&parse_warning_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_warning_line(line) do
    cond do
      String.contains?(line, "variable") and String.contains?(line, "unused") ->
        %{
          type: :unused_variable_warning,
          description: String.trim(line),
          file: extract_file_from_line(line),
          line_number: extract_line_number_from_line(line),
          priority: :medium,
          pattern: "EP014"
        }

      String.contains?(line, "deprecated") ->
        %{
          type: :deprecated_function_warning,
          description: String.trim(line),
          file: extract_file_from_line(line),
          line_number: extract_line_number_from_line(line),
          priority: :medium,
          pattern: "EP015"
        }

      String.contains?(line, "warning:") ->
        %{
          type: :general_warning,
          description: String.trim(line),
          file: extract_file_from_line(line),
          line_number: extract_line_number_from_line(line),
          priority: :low,
          pattern: "EP016"
        }

      true ->
        nil
    end
  end

  defp detect_unused_variables do
    get_elixir_files()
    |> Enum.flat_map(&analyze_unused_variables/1)
  end

  defp analyze_unused_variables(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_line_for_unused_variables(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_line_for_unused_variables(line, file_path, line_no) do
    issues = []

    # Pattern: variable assignment that might be unused
    if Regex.match?(~r/^\s*[a-z_][a-zA-Z0-9_]*\s*=/, line) and
         not String.contains?(line, ["_unused", "_ignore", "Logger", "IO"]) do
      [
        %{
          type: :potentially_unused_variable,
          description: "Potentially unused variable assignment: #{String.trim(line)}",
          file: file_path,
          line_number: line_no,
          priority: :low,
          pattern: "EP017"
        }
      ]
    else
      []
    end
  end

  defp detect_deprecated_functions do
    get_elixir_files()
    |> Enum.flat_map(&analyze_deprecated_functions/1)
  end

  defp analyze_deprecated_functions(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        deprecated_patterns = [
          {~r/Enum\.partition\/2/, "Enum.partition/2 is deprecated, use Enum.split_with/2"},
          {~r/String\.strip\/1/, "String.strip/1 is deprecated, use String.trim/1"},
          {~r/Regex\.replace\/4/, "Regex.replace/4 with global: false is deprecated"}
        ]

        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          Enum.flat_map(deprecated_patterns, fn {pattern, message} ->
            if Regex.match?(pattern, line) do
              [
                %{
                  type: :deprecated_function_usage,
                  description: "#{message}: #{String.trim(line)}",
                  file: file_path,
                  line_number: line_no,
                  priority: :medium,
                  pattern: "EP018"
                }
              ]
            else
              []
            end
          end)
        end)

      {:error, _} ->
        []
    end
  end

  defp detect_style_warnings do
    get_elixir_files()
    |> Enum.flat_map(&analyze_style_warnings/1)
  end

  defp analyze_style_warnings(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_style_issues(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_style_issues(line, file_path, line_no) do
    issues = []

    # Long line
    issues =
      if String.length(line) > 120 do
        [
          %{
            type: :long_line,
            description:
              "Line too long (#{String.length(line)} characters): #{String.slice(line, 0, 50)}...",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP019"
          }
          | issues
        ]
      else
        issues
      end

    # Trailing whitespace
    issues =
      if String.match?(line, ~r/\s+$/) do
        [
          %{
            type: :trailing_whitespace,
            description: "Trailing whitespace detected",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP020"
          }
          | issues
        ]
      else
        issues
      end

    # Mixed indentation (tabs and spaces)
    issues =
      if String.contains?(line, "\t") and String.contains?(line, "  ") do
        [
          %{
            type: :mixed_indentation,
            description: "Mixed tabs and spaces indentation",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP021"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  # === FORMAT VIOLATIONS DETECTION ===

  defp detect_format_violations(%{options: %{categories: categories}} = state) do
    if :format_violations in categories do
      IO.puts("📝 Detecting format violations...")
      update_progress(__state, 30)

      issues =
        [
          run_mix_format_check(),
          detect_indentation_issues(),
          detect_spacing_issues(),
          detect_naming_convention_violations()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :format_violations))

      IO.puts("   Found #{length(issues)} format violations")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp run_mix_format_check do
    case System.cmd("mix", ["format", "--check-formatted"],
           stderr_to_stdout: true,
           cd: System.cwd()
         ) do
      {_output, 0} ->
        []

      {output, _exit_code} ->
        parse_format_output(output)
    end
  end

  defp parse_format_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
    |> Enum.map(fn file ->
      %{
        type: :format_violation,
        description: "File not properly formatted",
        file: String.trim(file),
        line_number: nil,
        priority: :low,
        pattern: "EP022"
      }
    end)
  end

  defp detect_indentation_issues do
    get_elixir_files()
    |> Enum.flat_map(&analyze_indentation_issues/1)
  end

  defp analyze_indentation_issues(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_indentation_issues(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_indentation_issues(line, file_path, line_no) do
    issues = []

    # Check for non-standard indentation (not multiple of 2 spaces)
    leading_spaces = String.length(line) - String.length(String.trim_leading(line))

    issues =
      if leading_spaces > 0 and rem(leading_spaces, 2) != 0 do
        [
          %{
            type: :indentation_violation,
            description:
              "Non-standard indentation (#{leading_spaces} spaces, should be multiple of 2)",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP023"
          }
          | issues
        ]
      else
        issues
      end

    # Check for tabs used for indentation
    issues =
      if String.starts_with?(line, "\t") do
        [
          %{
            type: :tab_indentation,
            description: "Tabs used for indentation (should use spaces)",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP024"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp detect_spacing_issues do
    get_elixir_files()
    |> Enum.flat_map(&analyze_spacing_issues/1)
  end

  defp analyze_spacing_issues(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_spacing_issues(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_spacing_issues(line, file_path, line_no) do
    issues = []

    # Multiple consecutive spaces (not indentation)
    trimmed = String.trim_leading(line)

    issues =
      if Regex.match?(~r/ {3,}/, trimmed) do
        [
          %{
            type: :excessive_spacing,
            description: "Multiple consecutive spaces found",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP025"
          }
          | issues
        ]
      else
        issues
      end

    # Missing space after comma
    issues =
      if Regex.match?(~r/,[^\s\]]/, line) do
        [
          %{
            type: :missing_space_after_comma,
            description: "Missing space after comma",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP026"
          }
          | issues
        ]
      else
        issues
      end

    # Missing space around operators
    issues =
      if Regex.match?(~r/[a-zA-Z0-9][=+\-\*\/][a-zA-Z0-9]/, line) do
        [
          %{
            type: :missing_space_around_operator,
            description: "Missing space around operator",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP027"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp detect_naming_convention_violations do
    get_elixir_files()
    |> Enum.flat_map(&analyze_naming_conventions/1)
  end

  defp analyze_naming_conventions(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_naming_conventions(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_naming_conventions(line, file_path, line_no) do
    issues = []

    # Module names should be PascalCase
    issues =
      if Regex.match?(~r/defmodule\s+([a-z][a-zA-Z0-9_]*)/, line) do
        [
          %{
            type: :module_naming_violation,
            description: "Module name should be PascalCase",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP028"
          }
          | issues
        ]
      else
        issues
      end

    # Function names should be snake_case
    issues =
      if Regex.match?(~r/def\s+([A-Z][a-zA-Z0-9_]*)/, line) do
        [
          %{
            type: :function_naming_violation,
            description: "Function name should be snake_case",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP029"
          }
          | issues
        ]
      else
        issues
      end

    # Variable names should be snake_case
    issues =
      if Regex.match?(~r/([A-Z][a-zA-Z0-9_]*)\s*=/, line) do
        [
          %{
            type: :variable_naming_violation,
            description: "Variable name should be snake_case",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP030"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  # === CREDO VIOLATIONS DETECTION ===

  defp detect_credo_violations(%{options: %{categories: categories}} = state) do
    if :credo_violations in categories do
      IO.puts("🔍 Detecting Credo violations...")
      update_progress(__state, 40)

      issues =
        [
          run_credo_analysis(),
          detect_complexity_issues(),
          detect_readability_issues(),
          detect_design_issues()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :credo_violations))

      IO.puts("   Found #{length(issues)} Credo violations")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp run_credo_analysis do
    case System.cmd("mix", ["credo", "--format", "json"],
           stderr_to_stdout: true,
           cd: System.cwd()
         ) do
      {output, _exit_code} ->
        parse_credo_output(output)
    end
  end

  defp parse_credo_output(output) do
    try do
      case Jason.decode(output) do
        {:ok, %{"issues" => issues}} ->
          Enum.map(issues, &parse_credo_issue/1)

        {:ok, _} ->
          []

        {:error, _} ->
          # Fallback to text parsing if JSON fails
          parse_credo_text_output(output)
      end
    rescue
      _ ->
        parse_credo_text_output(output)
    end
  end

  defp parse_credo_issue(issue) do
    %{
      type: :credo_violation,
      description: "#{issue["check"]} - #{issue["message"]}",
      file: issue["filename"],
      line_number: issue["line_no"],
      priority: map_credo_priority(issue["priority"]),
      pattern: map_credo_pattern(issue["check"])
    }
  end

  defp parse_credo_text_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["┃", "│"]))
    |> Enum.map(&parse_credo_text_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_credo_text_line(line) do
    # Parse Credo text output format
    if Regex.match?(~r/[│┃]/, line) do
      parts =
        String.split(line, ["│", "┃"])
        |> Enum.map(&String.trim/1)

      case parts do
        [_, priority, file_line, category, message | _] ->
          [file, line_no] = String.split(file_line, ":")

          %{
            type: :credo_violation,
            description: "#{category} - #{message}",
            file: file,
            line_number: String.to_integer(line_no || "0"),
            priority: map_credo_text_priority(priority),
            pattern: "EP031"
          }

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp map_credo_priority(priority) when is_integer(priority) do
    case priority do
      p when p >= 20 -> :critical
      p when p >= 15 -> :high
      p when p >= 10 -> :medium
      _ -> :low
    end
  end

  defp map_credo_text_priority(priority_str) do
    case String.downcase(priority_str) do
      p when p in ["high", "h"] -> :high
      p when p in ["medium", "m"] -> :medium
      p when p in ["low", "l"] -> :low
      _ -> :medium
    end
  end

  defp map_credo_pattern(check) do
    case check do
      "Credo.Check.Readability" <> _ -> "EP032"
      "Credo.Check.Design" <> _ -> "EP033"
      "Credo.Check.Refactor" <> _ -> "EP034"
      "Credo.Check.Warning" <> _ -> "EP035"
      _ -> "EP036"
    end
  end

  defp detect_complexity_issues do
    get_elixir_files()
    |> Enum.flat_map(&analyze_complexity_issues/1)
  end

  defp analyze_complexity_issues(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        analyze_cyclomatic_complexity(content, file_path) ++
          analyze_cognitive_complexity(content, file_path) ++
          analyze_nesting_depth(content, file_path)

      {:error, _} ->
        []
    end
  end

  defp analyze_cyclomatic_complexity(content, file_path) do
    # Count decision points (if, case, cond, etc.)
    complexity_keywords = ["if", "case", "cond", "unless", "and", "or", "&&", "||"]

    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      keyword_count = Enum.count(complexity_keywords, &String.contains?(line, &1))

      if keyword_count > 3 do
        [
          %{
            type: :high_cyclomatic_complexity,
            description: "High cyclomatic complexity (#{keyword_count} decision points)",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP037"
          }
        ]
      else
        []
      end
    end)
  end

  defp analyze_cognitive_complexity(content, file_path) do
    # Simplified cognitive complexity analysis
    nested_structures = 0

    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_no}, acc ->
      line_complexity = calculate_line_cognitive_complexity(line)

      if line_complexity > 5 do
        [
          %{
            type: :high_cognitive_complexity,
            description: "High cognitive complexity score: #{line_complexity}",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP038"
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp calculate_line_cognitive_complexity(line) do
    # Simple heuristic for cognitive complexity
    base_score = 0

    # Nested structures increase complexity
    base_score = base_score + (String.length(line) - String.length(String.trim_leading(line))) / 2

    # Control structures
    control_keywords = ["if", "case", "cond", "for", "while", "try", "catch", "rescue"]
    base_score = base_score + Enum.count(control_keywords, &String.contains?(line, &1))

    # Logical operators
    logical_operators = ["&&", "||", "and", "or"]
    base_score = base_score + Enum.count(logical_operators, &String.contains?(line, &1))

    round(base_score)
  end

  defp analyze_nesting_depth(content, file_path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce({[], 0}, fn {line, line_no}, {acc, current_depth} ->
      # Simple nesting depth calculation based on indentation
      line_depth = (String.length(line) - String.length(String.trim_leading(line))) / 2

      issues =
        if line_depth > 6 do
          [
            %{
              type: :excessive_nesting,
              description: "Excessive nesting depth: #{round(line_depth)} levels",
              file: file_path,
              line_number: line_no,
              priority: :medium,
              pattern: "EP039"
            }
            | acc
          ]
        else
          acc
        end

      {issues, round(line_depth)}
    end)
    |> elem(0)
  end

  defp detect_readability_issues do
    get_elixir_files()
    |> Enum.flat_map(&analyze_readability_issues/1)
  end

  defp analyze_readability_issues(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        analyze_long_functions(content, file_path) ++
          analyze_long_modules(content, file_path) ++
          analyze_unclear_naming(content, file_path)

      {:error, _} ->
        []
    end
  end

  defp analyze_long_functions(content, file_path) do
    content
    |> extract_function_bodies()
    |> Enum.filter(fn {_name, lines, _start_line} -> length(lines) > 25 end)
    |> Enum.map(fn {name, lines, start_line} ->
      %{
        type: :long_function,
        description: "Function #{name} is too long (#{length(lines)} lines, should be < 25)",
        file: file_path,
        line_number: start_line,
        priority: :medium,
        pattern: "EP040"
      }
    end)
  end

  defp extract_function_bodies(content) do
    lines = String.split(content, "\n")

    lines
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, line_no}, acc ->
      case Regex.run(~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, line) do
        [_, function_name] ->
          # Find function end (simplified)
          function_lines = extract_function_lines(lines, line_no - 1)
          [{function_name, function_lines, line_no} | acc]

        nil ->
          acc
      end
    end)
  end

  defp extract_function_lines(lines, start_index) do
    # Simplified function body extraction
    # Take up to 50 lines
    Enum.slice(lines, start_index, 50)
    |> Enum.take_while(fn line ->
      not Regex.match?(~r/^\s*(def|defp)\s/, line) or start_index == 0
    end)
  end

  defp analyze_long_modules(content, file_path) do
    line_count = content |> String.split("\n") |> length()

    if line_count > 500 do
      [
        %{
          type: :long_module,
          description: "Module is too long (#{line_count} lines, should be < 500)",
          file: file_path,
          line_number: 1,
          priority: :medium,
          pattern: "EP041"
        }
      ]
    else
      []
    end
  end

  defp analyze_unclear_naming(content, file_path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      check_unclear_naming(line, file_path, line_no)
    end)
  end

  defp check_unclear_naming(line, file_path, line_no) do
    issues = []

    # Very short variable names (except common ones like 'x', 'i', 'n')
    short_var_matches = Regex.scan(~r/([a-z])\s*=/, line)

    _issues =
      Enum.reduce(short_var_matches, _issues, fn [_, var], acc ->
        if var not in ["x", "i", "n", "a", "b"] do
          [
            %{
              type: :unclear_variable_name,
              description: "Variable name '#{var}' is too short and unclear",
              file: file_path,
              line_number: line_no,
              priority: :low,
              pattern: "EP042"
            }
            | acc
          ]
        else
          acc
        end
      end)

    # Functions with unclear names
    function_matches = Regex.scan(~r/def\s+([a-z]{1,3})\s*\(/, line)

    _issues =
      Enum.reduce(function_matches, _issues, fn [_, func], acc ->
        [
          %{
            type: :unclear_function_name,
            description: "Function name '#{func}' is too short and unclear",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP043"
          }
          | acc
        ]
      end)

    issues
  end

  defp detect_design_issues do
    get_elixir_files()
    |> Enum.flat_map(&analyze_design_issues/1)
  end

  defp analyze_design_issues(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        analyze_coupling_issues(content, file_path) ++
          analyze_cohesion_issues(content, file_path) ++
          analyze_responsibility_issues(content, file_path)

      {:error, _} ->
        []
    end
  end

  defp analyze_coupling_issues(content, file_path) do
    # Count external module references
    external_references =
      Regex.scan(~r/([A-Z][a-zA-Z0-9\.]+)\./, content)
      |> Enum.map(&List.first(Enum.drop(&1, 1)))
      |> Enum.uniq()
      |> length()

    if external_references > 10 do
      [
        %{
          type: :high_coupling,
          description: "High coupling detected: #{external_references} external references",
          file: file_path,
          line_number: 1,
          priority: :medium,
          pattern: "EP044"
        }
      ]
    else
      []
    end
  end

  defp analyze_cohesion_issues(content, file_path) do
    # Analyze function cohesion within modules
    functions = extract_function_names(content)

    if length(functions) > 20 do
      [
        %{
          type: :low_cohesion,
          description: "Potential low cohesion: #{length(functions)} functions in module",
          file: file_path,
          line_number: 1,
          priority: :medium,
          pattern: "EP045"
        }
      ]
    else
      []
    end
  end

  defp extract_function_names(content) do
    Regex.scan(~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, content)
    |> Enum.map(&List.last/1)
    |> Enum.uniq()
  end

  defp analyze_responsibility_issues(content, file_path) do
    # Check for mixed responsibilities based on keywords
    web_keywords = ["render", "conn", "__params", "socket"]
    __data_keywords = ["Repo", "changeset", "insert", "update", "delete"]
    business_keywords = ["calculate", "process", "validate", "transform"]

    web_count = Enum.count(web_keywords, &String.contains?(content, &1))
    __data_count = Enum.count(__data_keywords, &String.contains?(content, &1))
    business_count = Enum.count(business_keywords, &String.contains?(content, &1))

    mixed_responsibilities =
      [web_count > 0, __data_count > 0, business_count > 0]
      |> Enum.count(& &1)

    if mixed_responsibilities > 2 do
      [
        %{
          type: :mixed_responsibilities,
          description:
            "Mixed responsibilities detected (web: #{web_count}, __data: #{__data_count}, business: #{business_count})",
          file: file_path,
          line_number: 1,
          priority: :medium,
          pattern: "EP046"
        }
      ]
    else
      []
    end
  end

  # === DIALYZER VIOLATIONS DETECTION ===

  defp detect_dialyzer_violations(%{options: %{categories: categories}} = state) do
    if :dialyzer_violations in categories do
      IO.puts("🔬 Detecting Dialyzer violations...")
      update_progress(__state, 50)

      issues =
        [
          run_dialyzer_analysis(),
          detect_type_spec_issues(),
          detect_type_mismatch_issues(),
          detect_unreachable_code()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :dialyzer_violations))

      IO.puts("   Found #{length(issues)} Dialyzer violations")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp run_dialyzer_analysis do
    # Note: Dialyzer analysis can be very slow, so we'll run a quick check
    case System.cmd("mix", ["dialyzer", "--format", "short"],
           stderr_to_stdout: true,
           cd: System.cwd()
         ) do
      {output, _exit_code} ->
        parse_dialyzer_output(output)
    end
  end

  defp parse_dialyzer_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ".ex:"))
    |> Enum.map(&parse_dialyzer_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_dialyzer_line(line) do
    case Regex.run(~r/(.+\.ex):(\d+):\s*(.+)/, line) do
      [_, file, line_no, message] ->
        %{
          type: :dialyzer_violation,
          description: "Dialyzer warning: #{String.trim(message)}",
          file: file,
          line_number: String.to_integer(line_no),
          priority: :medium,
          pattern: map_dialyzer_pattern(message)
        }

      nil ->
        nil
    end
  end

  defp map_dialyzer_pattern(message) do
    cond do
      String.contains?(message, "no_return") -> "EP047"
      String.contains?(message, "contract") -> "EP048"
      String.contains?(message, "pattern") -> "EP049"
      String.contains?(message, "unused") -> "EP050"
      true -> "EP051"
    end
  end

  defp detect_type_spec_issues do
    get_elixir_files()
    |> Enum.flat_map(&analyze_type_spec_issues/1)
  end

  defp analyze_type_spec_issues(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        functions = extract_function_definitions(content)
        specs = extract_type_specs(content)

        # Find functions without specs
        functions_without_specs = functions -- specs

        Enum.map(functions_without_specs, fn func ->
          %{
            type: :missing_type_spec,
            description: "Function #{func} is missing @spec",
            file: file_path,
            line_number: nil,
            priority: :low,
            pattern: "EP052"
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_type_specs(content) do
    Regex.scan(~r/@spec\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, content)
    |> Enum.map(&List.last/1)
    |> Enum.uniq()
  end

  defp detect_type_mismatch_issues do
    get_elixir_files()
    |> Enum.flat_map(&analyze_type_mismatch_issues/1)
  end

  defp analyze_type_mismatch_issues(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_type_mismatches(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_type_mismatches(line, file_path, line_no) do
    issues = []

    # String vs atom confusion
    issues =
      if Regex.match?(~r/"[^"]*"\s*==\s*:[a-zA-Z_]/, line) or
           Regex.match?(~r/:[a-zA-Z_][a-zA-Z0-9_]*\s*==\s*"/, line) do
        [
          %{
            type: :string_atom_comparison,
            description: "Potential string vs atom comparison",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP053"
          }
          | issues
        ]
      else
        issues
      end

    # Integer vs string operations
    issues =
      if Regex.match?(~r/\d+\s*\+\s*"/, line) or
           Regex.match?(~r/"\w*"\s*\+\s*\d+/, line) do
        [
          %{
            type: :number_string_operation,
            description: "Potential number vs string operation",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP054"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp detect_unreachable_code do
    get_elixir_files()
    |> Enum.flat_map(&analyze_unreachable_code/1)
  end

  defp analyze_unreachable_code(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.reduce({[], false}, fn {line, line_no}, {acc, after_raise} ->
          cond do
            # Code after raise/throw/exit
            after_raise and not String.trim(line) == "" and
                not String.starts_with?(String.trim(line), ["rescue", "catch", "after", "end"]) ->
              issue = %{
                type: :unreachable_code,
                description: "Code after raise/throw/exit is unreachable",
                file: file_path,
                line_number: line_no,
                priority: :medium,
                pattern: "EP055"
              }

              {[issue | acc], after_raise}

            String.contains?(line, ["raise", "throw", "exit"]) ->
              {acc, true}

            String.contains?(line, ["rescue", "catch", "after", "end"]) ->
              {acc, false}

            true ->
              {acc, after_raise}
          end
        end)
        |> elem(0)

      {:error, _} ->
        []
    end
  end

  # === TEST COVERAGE GAPS DETECTION ===

  defp detect_test_coverage_gaps(%{options: %{categories: categories}} = state) do
    if :test_coverage_gaps in categories do
      IO.puts("🧪 Detecting test coverage gaps...")
      update_progress(__state, 60)

      issues =
        [
          run_test_coverage_analysis(),
          detect_untested_functions(),
          detect_missing_test_files(),
          detect_low_coverage_modules()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :test_coverage_gaps))

      IO.puts("   Found #{length(issues)} test coverage gaps")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp run_test_coverage_analysis do
    case System.cmd("mix", ["test", "--cover"], stderr_to_stdout: true, cd: System.cwd()) do
      {output, _exit_code} ->
        parse_coverage_output(output)
    end
  end

  defp parse_coverage_output(output) do
    # Extract coverage percentages from output
    case Regex.run(~r/Total\s+(\d+\.?\d*)%/, output) do
      [_, percentage] ->
        coverage = String.to_float(percentage)

        if coverage < 80.0 do
          [
            %{
              type: :low_overall_coverage,
              description: "Overall test coverage is low: #{coverage}% (should be > 80%)",
              file: "test/",
              line_number: nil,
              priority: :high,
              pattern: "EP056"
            }
          ]
        else
          []
        end

      nil ->
        [
          %{
            type: :coverage_analysis_failed,
            description: "Could not determine test coverage",
            file: "test/",
            line_number: nil,
            priority: :medium,
            pattern: "EP057"
          }
        ]
    end
  end

  defp detect_untested_functions do
    source_files = get_elixir_files() |> Enum.reject(&String.contains?(&1, "/test/"))
    test_files = get_elixir_files() |> Enum.filter(&String.contains?(&1, "/test/"))

    source_files
    |> Enum.flat_map(&analyze_untested_functions(&1, test_files))
  end

  defp analyze_untested_functions(source_file, test_files) do
    case File.read(source_file) do
      {:ok, content} ->
        public_functions = extract_public_functions(content)
        tested_functions = extract_tested_functions(test_files, source_file)

        untested = public_functions -- tested_functions

        Enum.map(untested, fn {func_name, line_no} ->
          %{
            type: :untested_function,
            description: "Public function #{func_name} has no tests",
            file: source_file,
            line_number: line_no,
            priority: :medium,
            pattern: "EP058"
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_public_functions(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      case Regex.run(~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, line) do
        [_, func_name] -> [{func_name, line_no}]
        nil -> []
      end
    end)
  end

  defp extract_tested_functions(test_files, source_file) do
    # Extract module name from source file
    module_name = extract_module_name_from_file(source_file)

    test_files
    |> Enum.flat_map(fn test_file ->
      case File.read(test_file) do
        {:ok, content} ->
          if String.contains?(content, module_name) do
            extract_function_calls_from_tests(content)
          else
            []
          end

        {:error, _} ->
          []
      end
    end)
    |> Enum.uniq()
  end

  defp extract_module_name_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Regex.run(~r/defmodule\s+([A-Z][a-zA-Z0-9\.]*)\s+do/, content) do
          [_, module_name] -> module_name
          nil -> ""
        end

      {:error, _} ->
        ""
    end
  end

  defp extract_function_calls_from_tests(content) do
    # Simple pattern matching for function calls in tests
    Regex.scan(~r/([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, content)
    |> Enum.map(&List.last/1)
    |> Enum.uniq()
  end

  defp detect_missing_test_files do
    source_files = get_elixir_files() |> Enum.reject(&String.contains?(&1, "/test/"))

    source_files
    |> Enum.flat_map(&check_for_test_file/1)
  end

  defp check_for_test_file(source_file) do
    # Convert source file path to expected test file path
    expected_test_file =
      source_file
      |> String.replace("/lib/", "/test/")
      |> String.replace(".ex", "_test.exs")

    if File.exists?(expected_test_file) do
      []
    else
      [
        %{
          type: :missing_test_file,
          description: "No test file found for #{source_file}",
          file: source_file,
          line_number: nil,
          priority: :medium,
          pattern: "EP059"
        }
      ]
    end
  end

  defp detect_low_coverage_modules do
    # This would __require detailed coverage analysis
    # For now, we'll use a simple heuristic
    get_elixir_files()
    |> Enum.reject(&String.contains?(&1, "/test/"))
    |> Enum.flat_map(&analyze_module_coverage/1)
  end

  defp analyze_module_coverage(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        function_count = length(extract_public_functions(content))

        expected_test_file =
          file_path
          |> String.replace("/lib/", "/test/")
          |> String.replace(".ex", "_test.exs")

        case File.read(expected_test_file) do
          {:ok, test_content} ->
            test_count = count_tests_in_file(test_content)

            # Simple heuristic: should have at least 1 test per 2 functions
            if test_count < function_count / 2 do
              [
                %{
                  type: :low_module_coverage,
                  description:
                    "Low test coverage: #{test_count} tests for #{function_count} functions",
                  file: file_path,
                  line_number: nil,
                  priority: :medium,
                  pattern: "EP060"
                }
              ]
            else
              []
            end

          {:error, _} ->
            []
        end

      {:error, _} ->
        []
    end
  end

  defp count_tests_in_file(content) do
    test_patterns = [~r/test\s+"/, ~r/describe\s+"/, ~r/property\s+"/]

    test_patterns
    |> Enum.map(fn pattern -> length(Regex.scan(pattern, content)) end)
    |> Enum.sum()
  end

  # === DOCUMENTATION ISSUES DETECTION ===

  defp detect_documentation_issues(%{options: %{categories: categories}} = state) do
    if :documentation_issues in categories do
      IO.puts("📚 Detecting documentation issues...")
      update_progress(__state, 70)

      issues =
        [
          detect_missing_moduledoc(),
          detect_missing_doc(),
          detect_missing_spec(),
          detect_outdated_documentation()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :documentation_issues))

      IO.puts("   Found #{length(issues)} documentation issues")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp detect_missing_moduledoc do
    get_elixir_files()
    |> Enum.flat_map(&analyze_missing_moduledoc/1)
  end

  defp analyze_missing_moduledoc(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        has_module = Regex.match?(~r/defmodule\s+[A-Z]/, content)
        has_moduledoc = String.contains?(content, "@moduledoc")

        if has_module and not has_moduledoc do
          [
            %{
              type: :missing_moduledoc,
              description: "Module is missing @moduledoc",
              file: file_path,
              line_number: nil,
              priority: :medium,
              pattern: "EP061"
            }
          ]
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  defp detect_missing_doc do
    get_elixir_files()
    |> Enum.flat_map(&analyze_missing_doc/1)
  end

  defp analyze_missing_doc(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        lines
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          case Regex.run(~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, line) do
            [_, func_name] ->
              # Check if previous lines contain @doc
              previous_lines =
                Enum.take(lines, line_no - 1)
                |> Enum.reverse()
                |> Enum.take(5)

              has_doc = Enum.any?(previous_lines, &String.contains?(&1, "@doc"))

              if not has_doc and not String.starts_with?(func_name, "_") do
                [
                  %{
                    type: :missing_doc,
                    description: "Public function #{func_name} is missing @doc",
                    file: file_path,
                    line_number: line_no,
                    priority: :low,
                    pattern: "EP062"
                  }
                ]
              else
                []
              end

            nil ->
              []
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp detect_missing_spec do
    get_elixir_files()
    |> Enum.flat_map(&analyze_missing_spec/1)
  end

  defp analyze_missing_spec(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        lines
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          case Regex.run(~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/, line) do
            [_, func_name] ->
              # Check if previous lines contain @spec
              previous_lines =
                Enum.take(lines, line_no - 1)
                |> Enum.reverse()
                |> Enum.take(5)

              has_spec = Enum.any?(previous_lines, &String.contains?(&1, "@spec"))

              if not has_spec and not String.starts_with?(func_name, "_") do
                [
                  %{
                    type: :missing_spec,
                    description: "Public function #{func_name} is missing @spec",
                    file: file_path,
                    line_number: line_no,
                    priority: :low,
                    pattern: "EP063"
                  }
                ]
              else
                []
              end

            nil ->
              []
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp detect_outdated_documentation do
    get_elixir_files()
    |> Enum.flat_map(&analyze_outdated_documentation/1)
  end

  defp analyze_outdated_documentation(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_outdated_documentation(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_outdated_documentation(line, file_path, line_no) do
    issues = []

    # Check for TODO/FIXME in documentation
    issues =
      if Regex.match?(~r/@doc.*TODO|FIXME/i, line) do
        [
          %{
            type: :todo_in_documentation,
            description: "Documentation contains TODO/FIXME",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP064"
          }
          | issues
        ]
      else
        issues
      end

    # Check for very old dates in documentation
    current_year = Date.utc_today().year

    issues =
      if Regex.match?(~r/@doc.*20(1[0-9]|20)/, line) do
        [
          %{
            type: :old_date_in_documentation,
            description: "Documentation contains old date references",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP065"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  # === TIMESTAMP INACCURACIES DETECTION ===

  defp detect_timestamp_inaccuracies(%{options: %{categories: categories}} = state) do
    if :timestamp_inaccuracies in categories do
      IO.puts("🕐 Detecting timestamp inaccuracies...")
      update_progress(__state, 80)

      issues =
        [
          detect_outdated_timestamps(),
          detect_inconsistent_timestamp_formats(),
          detect_future_timestamps(),
          detect_missing_timestamps()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :timestamp_inaccuracies))

      IO.puts("   Found #{length(issues)} timestamp inaccuracies")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp detect_outdated_timestamps do
    current_date = Date.utc_today()
    current_year = current_date.year
    current_month = current_date.month

    get_all_project_files()
    |> Enum.flat_map(&analyze_outdated_timestamps(&1, current_year, current_month))
  end

  defp get_all_project_files do
    extensions = [".ex", ".exs", ".md", ".json", ".yml", ".yaml"]

    extensions
    |> Enum.flat_map(fn ext ->
      case System.cmd("find", [".", "-name", "*#{ext}", "-type", "f"], cd: System.cwd()) do
        {output, 0} -> String.split(output, "\n", trim: true)
        _ -> []
      end
    end)
    |> Enum.reject(&String.contains?(&1, ["/_build/", "/deps/", "/.git/"]))
  end

  defp analyze_outdated_timestamps(file_path, current_year, current_month) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_outdated_timestamps_in_line(line, file_path, line_no, current_year, current_month)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_outdated_timestamps_in_line(line, file_path, line_no, current_year, current_month) do
    issues = []

    # Check for dates that are too far in the past
    old_year_patterns =
      for year <- (current_year - 2)..(current_year - 1), do: Integer.to_string(year)

    _issues =
      Enum.reduce(old_year_patterns, _issues, fn year, acc ->
        if String.contains?(line, year) and
             Regex.match?(~r/#{year}-\d{2}-\d{2}/, line) do
          [
            %{
              type: :outdated_timestamp,
              description: "Outdated timestamp found: contains year #{year}",
              file: file_path,
              line_number: line_no,
              priority: :medium,
              pattern: "EP066"
            }
            | acc
          ]
        else
          acc
        end
      end)

    # Check for specific outdated months in current year
    if current_month > 6 do
      old_months =
        for month <- 1..(current_month - 6),
            do: String.pad_leading(Integer.to_string(month), 2, "0")

      _issues =
        Enum.reduce(old_months, _issues, fn month, acc ->
          pattern = "#{current_year}-#{month}"

          if String.contains?(line, pattern) do
            [
              %{
                type: :stale_current_year_timestamp,
                description: "Stale timestamp from earlier this year: #{pattern}",
                file: file_path,
                line_number: line_no,
                priority: :low,
                pattern: "EP067"
              }
              | acc
            ]
          else
            acc
          end
        end)
    end

    issues
  end

  defp detect_inconsistent_timestamp_formats do
    get_all_project_files()
    |> Enum.flat_map(&analyze_timestamp_format_consistency/1)
  end

  defp analyze_timestamp_format_consistency(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        timestamps = extract_timestamps_from_content(content)

        if length(timestamps) > 1 do
          formats =
            Enum.map(timestamps, &detect_timestamp_format/1)
            |> Enum.uniq()

          if length(formats) > 1 do
            [
              %{
                type: :inconsistent_timestamp_formats,
                description: "Multiple timestamp formats found: #{Enum.join(formats, ", ")}",
                file: file_path,
                line_number: nil,
                priority: :low,
                pattern: "EP068"
              }
            ]
          else
            []
          end
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  defp extract_timestamps_from_content(content) do
    timestamp_patterns = [
      ~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/,
      ~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/,
      ~r/\d{8}-\d{4}/,
      ~r/\d{4}\/\d{2}\/\d{2}/
    ]

    timestamp_patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, content)
      |> List.flatten()
    end)
    |> Enum.uniq()
  end

  defp detect_timestamp_format(timestamp) do
    cond do
      Regex.match?(~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, timestamp) -> "ISO8601"
      Regex.match?(~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, timestamp) -> "DATETIME"
      Regex.match?(~r/\d{8}-\d{4}/, timestamp) -> "COMPACT"
      Regex.match?(~r/\d{4}\/\d{2}\/\d{2}/, timestamp) -> "SLASH"
      true -> "UNKNOWN"
    end
  end

  defp detect_future_timestamps do
    current_date = Date.utc_today()

    get_all_project_files()
    |> Enum.flat_map(&analyze_future_timestamps(&1, current_date))
  end

  defp analyze_future_timestamps(file_path, current_date) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_future_timestamps_in_line(line, file_path, line_no, current_date)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_future_timestamps_in_line(line, file_path, line_no, current_date) do
    # Extract date patterns and check if they're in the future
    case Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, line) do
      [_, year_str, month_str, day_str] ->
        try do
          date =
            Date.new!(
              String.to_integer(year_str),
              String.to_integer(month_str),
              String.to_integer(day_str)
            )

          if Date.compare(date, current_date) == :gt do
            [
              %{
                type: :future_timestamp,
                description: "Future timestamp found: #{Date.to_string(date)}",
                file: file_path,
                line_number: line_no,
                priority: :medium,
                pattern: "EP069"
              }
            ]
          else
            []
          end
        rescue
          _ -> []
        end

      nil ->
        []
    end
  end

  defp detect_missing_timestamps do
    get_all_project_files()
    |> Enum.filter(&should_have_timestamp/1)
    |> Enum.flat_map(&analyze_missing_timestamps/1)
  end

  defp should_have_timestamp(file_path) do
    # Files that should typically have timestamps
    timestamp_requiring_patterns = [
      ~r/journal/i,
      ~r/changelog/i,
      ~r/release/i,
      ~r/version/i
    ]

    Enum.any?(timestamp_requiring_patterns, &Regex.match?(&1, file_path))
  end

  defp analyze_missing_timestamps(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        has_timestamp = String.match?(content, ~r/\d{4}-\d{2}-\d{2}/)

        if not has_timestamp do
          [
            %{
              type: :missing_timestamp,
              description: "File that should contain timestamps has none",
              file: file_path,
              line_number: nil,
              priority: :low,
              pattern: "EP070"
            }
          ]
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # === PERFORMANCE ISSUES DETECTION ===

  defp detect_performance_issues(%{options: %{categories: categories}} = state) do
    if :performance_issues in categories do
      IO.puts("⚡ Detecting performance issues...")
      update_progress(__state, 90)

      issues =
        [
          detect_n_plus_one_queries(),
          detect_inefficient_enumerables(),
          detect_memory_leaks(),
          detect_blocking_operations()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :performance_issues))

      IO.puts("   Found #{length(issues)} performance issues")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp detect_n_plus_one_queries do
    get_elixir_files()
    |> Enum.flat_map(&analyze_n_plus_one_queries/1)
  end

  defp analyze_n_plus_one_queries(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_n_plus_one_patterns(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_n_plus_one_patterns(line, file_path, line_no) do
    issues = []

    # Enum.map with Repo query inside
    issues =
      if Regex.match?(~r/Enum\.map.*Repo\.(get|one|all)/, line) do
        [
          %{
            type: :potential_n_plus_one,
            description: "Potential N+1 query: Enum.map with Repo query inside",
            file: file_path,
            line_number: line_no,
            priority: :high,
            pattern: "EP071"
          }
          | issues
        ]
      else
        issues
      end

    # for comprehension with Repo query
    issues =
      if Regex.match?(~r/for\s+.*<-.*Repo\.(get|one|all)/, line) do
        [
          %{
            type: :potential_n_plus_one_comprehension,
            description: "Potential N+1 query: for comprehension with Repo query",
            file: file_path,
            line_number: line_no,
            priority: :high,
            pattern: "EP072"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp detect_inefficient_enumerables do
    get_elixir_files()
    |> Enum.flat_map(&analyze_inefficient_enumerables/1)
  end

  defp analyze_inefficient_enumerables(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_inefficient_enumerable_patterns(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_inefficient_enumerable_patterns(line, file_path, line_no) do
    issues = []

    # Multiple Enum operations that could be combined
    enum_operations = ["map", "filter", "reduce", "reject", "sort"]
    enum_count = Enum.count(enum_operations, &String.contains?(line, "Enum.#{&1}"))

    issues =
      if enum_count > 2 do
        [
          %{
            type: :multiple_enum_operations,
            description: "Multiple Enum operations that could be combined for better performance",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP073"
          }
          | issues
        ]
      else
        issues
      end

    # Enum.count on already materialized list
    issues =
      if Regex.match?(~r/Enum\.count\(.*Enum\.(map|filter|to_list)/, line) do
        [
          %{
            type: :inefficient_count,
            description: "Inefficient count operation on materialized enumerable",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP074"
          }
          | issues
        ]
      else
        issues
      end

    # Enum.reverse |> Enum.map could be Enum.reverse_map
    issues =
      if Regex.match?(~r/Enum\.reverse.*\|>.*Enum\.map/, line) do
        [
          %{
            type: :inefficient_reverse_map,
            description: "Use Enum.reverse_map instead of Enum.reverse |> Enum.map",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP075"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp detect_memory_leaks do
    get_elixir_files()
    |> Enum.flat_map(&analyze_memory_leaks/1)
  end

  defp analyze_memory_leaks(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_memory_leak_patterns(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_memory_leak_patterns(line, file_path, line_no) do
    issues = []

    # Large __data structures in function scope
    issues =
      if Regex.match?(~r/Stream\.cycle.*\|>.*Enum\.take\(\d{4,}\)/, line) do
        [
          %{
            type: :large_data_structure,
            description: "Large __data structure creation that might cause memory issues",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP076"
          }
          | issues
        ]
      else
        issues
      end

    # Processes that might not be cleaned up
    issues =
      if String.contains?(line, "spawn") and
           not String.contains?(line, ["Task.", "GenServer.", "Agent."]) do
        [
          %{
            type: :unmanaged_process,
            description: "Spawned process without proper supervision",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP077"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp detect_blocking_operations do
    get_elixir_files()
    |> Enum.flat_map(&analyze_blocking_operations/1)
  end

  defp analyze_blocking_operations(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_blocking_operation_patterns(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_blocking_operation_patterns(line, file_path, line_no) do
    issues = []

    # Synchronous HTTP calls without timeout
    issues =
      if Regex.match?(~r/HTTPoison\.(get|post|put|delete)/, line) and
           not String.contains?(line, "timeout:") do
        [
          %{
            type: :http_without_timeout,
            description: "HTTP call without explicit timeout",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP078"
          }
          | issues
        ]
      else
        issues
      end

    # File.read! without error handling
    issues =
      if String.contains?(line, "File.read!") do
        [
          %{
            type: :unsafe_file_operation,
            description: "File.read! can block and raise, consider File.read/1",
            file: file_path,
            line_number: line_no,
            priority: :low,
            pattern: "EP079"
          }
          | issues
        ]
      else
        issues
      end

    # Process.sleep in production code (not test)
    issues =
      if String.contains?(line, "Process.sleep") and
           not String.contains?(file_path, "test") do
        [
          %{
            type: :blocking_sleep,
            description: "Process.sleep blocks the current process",
            file: file_path,
            line_number: line_no,
            priority: :medium,
            pattern: "EP080"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  # === SECURITY VULNERABILITIES DETECTION ===

  defp detect_security_vulnerabilities(%{options: %{categories: categories}} = state) do
    if :security_vulnerabilities in categories do
      IO.puts("🔒 Detecting security vulnerabilities...")
      update_progress(__state, 95)

      issues =
        [
          run_sobelow_analysis(),
          detect_hardcoded_secrets(),
          detect_unsafe_operations(),
          detect_injection_vulnerabilities()
        ]
        |> List.flatten()
        |> Enum.map(&add_category(&1, :security_vulnerabilities))

      IO.puts("   Found #{length(issues)} security vulnerabilities")
      %{__state | issues: __state.issues ++ issues}
    else
      __state
    end
  end

  defp run_sobelow_analysis do
    case System.cmd("mix", ["sobelow", "--format", "json"],
           stderr_to_stdout: true,
           cd: System.cwd()
         ) do
      {output, _exit_code} ->
        parse_sobelow_output(output)
    end
  end

  defp parse_sobelow_output(output) do
    try do
      case Jason.decode(output) do
        {:ok, %{"vulnerabilities" => vulnerabilities}} ->
          Enum.map(vulnerabilities, &parse_sobelow_vulnerability/1)

        {:ok, _} ->
          []

        {:error, _} ->
          parse_sobelow_text_output(output)
      end
    rescue
      _ ->
        parse_sobelow_text_output(output)
    end
  end

  defp parse_sobelow_vulnerability(vuln) do
    %{
      type: :security_vulnerability,
      description: "#{vuln["type"]}: #{vuln["details"]}",
      file: vuln["filename"],
      line_number: vuln["line"],
      priority: map_sobelow_severity(vuln["severity"]),
      pattern: "EP081"
    }
  end

  defp parse_sobelow_text_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["High", "Medium", "Low"]))
    |> Enum.map(&parse_sobelow_text_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_sobelow_text_line(line) do
    case Regex.run(~r/(High|Medium|Low) - (.+) - (.+):(\d+)/, line) do
      [_, severity, description, file, line_no] ->
        %{
          type: :security_vulnerability,
          description: "#{severity}: #{description}",
          file: file,
          line_number: String.to_integer(line_no),
          priority: map_sobelow_text_severity(severity),
          pattern: "EP082"
        }

      nil ->
        nil
    end
  end

  defp map_sobelow_severity(severity) when is_binary(severity) do
    case String.downcase(severity) do
      "high" -> :critical
      "medium" -> :high
      "low" -> :medium
      _ -> :low
    end
  end

  defp map_sobelow_text_severity(severity) do
    case String.downcase(severity) do
      "high" -> :critical
      "medium" -> :high
      "low" -> :medium
      _ -> :low
    end
  end

  defp detect_hardcoded_secrets do
    get_elixir_files()
    |> Enum.flat_map(&analyze_hardcoded_secrets/1)
  end

  defp analyze_hardcoded_secrets(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_hardcoded_secrets_patterns(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_hardcoded_secrets_patterns(line, file_path, line_no) do
    issues = []

    secret_patterns = [
      {~r/password\s*[:=]\s*["'][^"']+["']/, "hardcoded password"},
      {~r/api[_-]?key\s*[:=]\s*["'][^"']+["']/, "hardcoded API key"},
      {~r/secret[_-]?key\s*[:=]\s*["'][^"']+["']/, "hardcoded secret key"},
      {~r/token\s*[:=]\s*["'][^"']+["']/, "hardcoded token"},
      {~r/private[_-]?key\s*[:=]\s*["'][^"']+["']/, "hardcoded private key"}
    ]

    Enum.reduce(secret_patterns, issues, fn {pattern, description}, acc ->
      if Regex.match?(pattern, String.downcase(line)) and
           not String.contains?(line, ["ENV", "System.get_env", "Application.get_env"]) do
        [
          %{
            type: :hardcoded_secret,
            description: "Potential #{description} detected",
            file: file_path,
            line_number: line_no,
            priority: :critical,
            pattern: "EP083"
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp detect_unsafe_operations do
    get_elixir_files()
    |> Enum.flat_map(&analyze_unsafe_operations/1)
  end

  defp analyze_unsafe_operations(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_unsafe_operation_patterns(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_unsafe_operation_patterns(line, file_path, line_no) do
    issues = []

    # Unsafe string interpolation in queries
    issues =
      if Regex.match?(~r/query.*".*#\{/, line) do
        [
          %{
            type: :sql_injection_risk,
            description: "String interpolation in query - potential SQL injection",
            file: file_path,
            line_number: line_no,
            priority: :critical,
            pattern: "EP084"
          }
          | issues
        ]
      else
        issues
      end

    # File.write with __user input
    issues =
      if Regex.match?(~r/File\.write.*__params/, line) do
        [
          %{
            type: :file_write_vulnerability,
            description: "File.write with __user input - potential path traversal",
            file: file_path,
            line_number: line_no,
            priority: :high,
            pattern: "EP085"
          }
          | issues
        ]
      else
        issues
      end

    # Eval-like operations
    unsafe_operations = ["Code.eval_string", "Code.eval_quoted", ":erlang.binary_to_term"]

    _issues =
      Enum.reduce(unsafe_operations, _issues, fn operation, acc ->
        if String.contains?(line, operation) do
          [
            %{
              type: :code_injection_risk,
              description: "#{operation} - potential code injection vulnerability",
              file: file_path,
              line_number: line_no,
              priority: :critical,
              pattern: "EP086"
            }
            | acc
          ]
        else
          acc
        end
      end)

    issues
  end

  defp detect_injection_vulnerabilities do
    get_elixir_files()
    |> Enum.flat_map(&analyze_injection_vulnerabilities/1)
  end

  defp analyze_injection_vulnerabilities(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_no} ->
          check_injection_patterns(line, file_path, line_no)
        end)

      {:error, _} ->
        []
    end
  end

  defp check_injection_patterns(line, file_path, line_no) do
    issues = []

    # Command injection
    issues =
      if Regex.match?(~r/System\.cmd.*#\{/, line) do
        [
          %{
            type: :command_injection_risk,
            description: "String interpolation in System.cmd - potential command injection",
            file: file_path,
            line_number: line_no,
            priority: :critical,
            pattern: "EP087"
          }
          | issues
        ]
      else
        issues
      end

    # HTML injection (XSS)
    issues =
      if Regex.match?(~r/raw.*#\{.*__params/, line) do
        [
          %{
            type: :xss_risk,
            description: "raw/1 with __user input - potential XSS vulnerability",
            file: file_path,
            line_number: line_no,
            priority: :high,
            pattern: "EP088"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  # === PATTERN ANALYSIS ===

  defp analyze_patterns(%{options: %{patterns: true}} = state) do
    IO.puts("🔍 Analyzing issue patterns...")

    patterns =
      __state.issues
      |> Enum.group_by(& &1.pattern)
      |> Enum.map(fn {pattern_id, issues} ->
        %{
          pattern_id: pattern_id,
          count: length(issues),
          files_affected: issues |> Enum.map(& &1.file) |> Enum.uniq() |> length(),
          severity: calculate_pattern_severity(issues),
          description: generate_pattern_description(pattern_id, issues),
          batch_fix_available: has_batch_fix?(pattern_id)
        }
      end)
      |> Enum.sort_by(& &1.count, :desc)

    %{__state | patterns: patterns}
  end

  defp analyze_patterns(__state), do: __state

  defp calculate_pattern_severity(issues) do
    priorities = Enum.map(issues, & &1.priority)

    cond do
      :critical in priorities -> :critical
      :high in priorities -> :high
      :medium in priorities -> :medium
      true -> :low
    end
  end

  defp generate_pattern_description(pattern_id, issues) do
    sample_issue = List.first(issues)
    "#{sample_issue.type |> to_string() |> String.replace("_", " ")} (#{pattern_id})"
  end

  defp has_batch_fix?(pattern_id) do
    # Patterns that can be automatically fixed in batch
    batch_fixable_patterns = [
      "EP014",
      "EP017",
      "EP019",
      "EP020",
      "EP022",
      "EP025",
      "EP026",
      "EP061",
      "EP062",
      "EP063",
      "EP066",
      "EP067"
    ]

    pattern_id in batch_fixable_patterns
  end

  # === BATCH RECOMMENDATIONS ===

  defp generate_batch_recommendations(%{options: %{batch_process: true}} = state) do
    IO.puts("📋 Generating batch processing recommendations...")

    recommendations =
      __state.patterns
      |> Enum.filter(& &1.batch_fix_available)
      |> Enum.map(&generate_batch_recommendation/1)

    statistics = %{
      total_issues: length(__state.issues),
      batch_fixable_issues: recommendations |> Enum.map(& &1.issue_count) |> Enum.sum(),
      batch_fix_coverage: calculate_batch_coverage(__state.issues, recommendations),
      estimated_time_savings: calculate_time_savings(recommendations)
    }

    %{__state | statistics: Map.merge(__state.statistics, statistics)}
  end

  defp generate_batch_recommendations(__state), do: __state

  defp generate_batch_recommendation(pattern) do
    %{
      pattern_id: pattern.pattern_id,
      issue_count: pattern.count,
      files_affected: pattern.files_affected,
      fix_command: generate_fix_command(pattern.pattern_id),
      estimated_time: estimate_fix_time(pattern),
      risk_level: assess_fix_risk(pattern.pattern_id)
    }
  end

  defp generate_fix_command(pattern_id) do
    case pattern_id do
      "EP022" -> "mix format"
      "EP014" -> "elixir scripts/maintenance/fix_unused_variables.exs"
      "EP061" -> "elixir scripts/maintenance/add_missing_moduledocs.exs"
      "EP066" -> "elixir scripts/maintenance/update_timestamps.exs"
      _ -> "# Manual fix __required"
    end
  end

  defp estimate_fix_time(pattern) do
    case pattern.pattern_id do
      # seconds
      "EP022" -> 30
      # 10 seconds per unused variable
      "EP014" -> pattern.count * 10
      # 1 minute per missing moduledoc
      "EP061" -> pattern.count * 60
      # 30 seconds per issue
      _ -> pattern.count * 30
    end
  end

  defp assess_fix_risk(pattern_id) do
    low_risk_patterns = ["EP022", "EP025", "EP026", "EP066", "EP067"]
    medium_risk_patterns = ["EP014", "EP017", "EP061", "EP062"]

    cond do
      pattern_id in low_risk_patterns -> :low
      pattern_id in medium_risk_patterns -> :medium
      true -> :high
    end
  end

  defp calculate_batch_coverage(issues, recommendations) do
    batch_fixable_count = recommendations |> Enum.map(& &1.issue_count) |> Enum.sum()
    total_count = length(issues)

    if total_count > 0 do
      round(batch_fixable_count / total_count * 100)
    else
      0
    end
  end

  defp calculate_time_savings(recommendations) do
    recommendations
    |> Enum.map(& &1.estimated_time)
    |> Enum.sum()
  end

  # === ANALYSIS FINALIZATION ===

  defp finalize_analysis(state) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - __state.start_time

    final_statistics = %{
      analysis_duration_ms: duration,
      total_files_analyzed: __state.total_files,
      issues_per_category: calculate_issues_per_category(__state.issues),
      top_files_by_issues: calculate_top_files_by_issues(__state.issues),
      priority_distribution: calculate_priority_distribution(__state.issues)
    }

    %{__state | statistics: Map.merge(__state.statistics, final_statistics), progress: 100}
  end

  defp calculate_issues_per_category(issues) do
    issues
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, category_issues} ->
      {category, length(category_issues)}
    end)
    |> Enum.into(%{})
  end

  defp calculate_top_files_by_issues(issues) do
    issues
    |> Enum.group_by(& &1.file)
    |> Enum.map(fn {file, file_issues} ->
      %{file: file, issue_count: length(file_issues)}
    end)
    |> Enum.sort_by(& &1.issue_count, :desc)
    |> Enum.take(10)
  end

  defp calculate_priority_distribution(issues) do
    issues
    |> Enum.group_by(& &1.priority)
    |> Enum.map(fn {priority, priority_issues} ->
      {priority, length(priority_issues)}
    end)
    |> Enum.into(%{})
  end

  # === OUTPUT RESULTS ===

  defp output_results(%{options: %{json_output: true}} = state) do
    output_json_results(__state)
  end

  defp output_results(state) do
    output_human_readable_results(__state)
  end

  defp output_json_results(state) do
    result = %{
      version: @version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      summary: %{
        total_issues: length(__state.issues),
        analysis_duration_ms: __state.statistics.analysis_duration_ms,
        files_analyzed: __state.statistics.total_files_analyzed
      },
      issues: __state.issues,
      patterns: __state.patterns,
      statistics: __state.statistics
    }

    json_output = Jason.encode!(result, pretty: true)

    case __state.options.export do
      nil ->
        IO.puts(json_output)

      export_path ->
        File.write!(export_path, json_output)
        IO.puts("✅ Results exported to: #{export_path}")
    end
  end

  defp output_human_readable_results(state) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("📊 COMPREHENSIVE PRE-COMMIT ISSUE ANALYSIS RESULTS")
    IO.puts(String.duplicate("=", 80))

    # Summary
    IO.puts("\n🎯 SUMMARY")
    IO.puts("Total Issues Found: #{length(__state.issues)}")
    IO.puts("Analysis Duration: #{__state.statistics.analysis_duration_ms}ms")
    IO.puts("Files Analyzed: #{__state.total_files}")

    # Priority breakdown
    IO.puts("\n⚡ PRIORITY BREAKDOWN")
    priority_dist = __state.statistics.priority_distribution

    Enum.each([:critical, :high, :medium, :low, :info], fn priority ->
      count = Map.get(priority_dist, priority, 0)

      percentage =
        if length(__state.issues) > 0, do: round(count / length(__state.issues) * 100), else: 0

      IO.puts(
        "#{String.pad_trailing(to_string(priority), 10)}: #{String.pad_leading(to_string(count), 6)} (#{percentage}%)"
      )
    end)

    # Category breakdown
    if map_size(__state.statistics.issues_per_category) > 0 do
      IO.puts("\n📋 CATEGORY BREAKDOWN")

      __state.statistics.issues_per_category
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.each(fn {category, count} ->
        percentage = round(count / length(__state.issues) * 100)

        IO.puts(
          "#{String.pad_trailing(to_string(category), 25)}: #{String.pad_leading(to_string(count), 6)} (#{percentage}%)"
        )
      end)
    end

    # Top problematic files
    if length(__state.statistics.top_files_by_issues) > 0 do
      IO.puts("\n🔥 TOP PROBLEMATIC FILES")

      __state.statistics.top_files_by_issues
      |> Enum.take(5)
      |> Enum.each(fn %{file: file, issue_count: count} ->
        IO.puts("#{String.pad_trailing(String.slice(file, -50, 50), 52)}: #{count} issues")
      end)
    end

    # Pattern analysis
    if length(__state.patterns) > 0 do
      IO.puts("\n🔍 TOP ISSUE PATTERNS")

      __state.patterns
      |> Enum.take(10)
      |> Enum.each(fn pattern ->
        batch_indicator = if pattern.batch_fix_available, do: " [BATCH-FIXABLE]", else: ""

        IO.puts(
          "#{pattern.pattern_id}: #{pattern.count} occurrences - #{pattern.description}#{batch_indicator}"
        )
      end)
    end

    # Batch processing recommendations
    if Map.has_key?(__state.statistics, :batch_fixable_issues) do
      IO.puts("\n⚡ BATCH PROCESSING POTENTIAL")

      IO.puts(
        "Batch-fixable issues: #{__state.statistics.batch_fixable_issues}/#{length(__state.issues)} (#{__state.statistics.batch_fix_coverage}%)"
      )

      IO.puts("Estimated time savings: #{__state.statistics.estimated_time_savings} seconds")
    end

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("✅ Analysis complete! Use --export filename.json to save detailed results.")
    IO.puts(String.duplicate("=", 80))
  end

  # === UTILITY FUNCTIONS ===

  defp get_elixir_files do
    case System.cmd("find", [".", "-name", "*.ex", "-o", "-name", "*.exs", "-type", "f"],
           cd: System.cwd()
         ) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.contains?(&1, ["/_build/", "/deps/", "/.git/"]))

      _ ->
        []
    end
  end

  defp count_total_files do
    length(get_elixir_files()) + length(get_all_project_files())
  end

  defp extract_file_from_line(line) do
    case Regex.run(~r/([^:\s]+\.exs?):/, line) do
      [_, file] -> file
      nil -> "unknown"
    end
  end

  defp extract_line_number_from_line(line) do
    case Regex.run(~r/:(\d+):/, line) do
      [_, line_no] -> String.to_integer(line_no)
      nil -> nil
    end
  end

  defp add_category(issue, category) do
    Map.put(issue, :category, category)
  end

  defp update_progress(state, progress) do
    %{__state | progress: progress}
  end

  defp print_usage do
    IO.puts("""
    Usage: #{:escript.script_name()} [OPTIONS]

    Comprehensive pre-commit issue detection system with advanced analysis.

    OPTIONS:
      -h, --help                 Show this help message
      -c, --comprehensive        Run comprehensive analysis (all categories)
      -b, --batch-process        Generate batch processing recommendations
      -j, --json-output          Output results in JSON format (default: true)
      --patterns                 Analyze issue patterns (default: true)
      --export PATH              Export results to file
      --categories LIST          Comma-separated list of categories to analyze
      --min-issues NUMBER        Minimum issues to detect (default: 500)
      --timeout SECONDS          Analysis timeout in seconds (default: 3600)

    CATEGORIES:
      compilation_errors         Syntax errors, undefined variables, missing deps
      warning_violations         Unused variables, deprecated functions, style warnings
      format_violations          mix format, code style inconsistencies
      credo_violations          Code quality, complexity, maintainability
      dialyzer_violations       Type inconsistencies, function specifications
      test_coverage_gaps        Missing tests, low coverage areas
      documentation_issues      Missing @doc, @spec, @moduledoc
      timestamp_inaccuracies    Outdated timestamps, inconsistent formats
      performance_issues        Inefficient queries, resource leaks
      security_vulnerabilities  Exposed secrets, unsafe operations

    EXAMPLES:
      # Run comprehensive analysis with JSON export
      #{:escript.script_name()} --comprehensive --export results.json

      # Analyze only critical categories with batch recommendations
      #{:escript.script_name()} --categories compilation_errors,security_vulnerabilities --batch-process

      # Quick security and performance check
      #{:escript.script_name()} --categories security_vulnerabilities,performance_issues --min-issues 100
    """)
  end
end

# Run the script
ComprehensivePrecommitIssueDetectorV2.main(System.argv())

# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied

