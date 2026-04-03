#!/usr/bin/env elixir

# SYSTEMATIC PARAMETER FIXER - AEE SOPv5.11 Implementation
# Date: 2025-08-31 19:47:00 CEST
# Addresses 1,031 compilation errors systematically

Mix.install([{:jason, "~> 1.4"}])

defmodule SystematicParameterFixerAEE do
  @moduledoc """
  AEE SOPv5.11 Systematic Parameter Fixer

  Fixes the identified root cause: Parameters with underscore prefix (_state, _opts)
  that are actually used in function bodies (causing undefined variable errors).
  """

  def main(args \\ []) do
    case args do
      ["--analyze"] -> analyze_parameter_issues()
      ["--fix"] -> execute_systematic_fixes()
      ["--validate"] -> validate_fixes()
      ["--comprehensive"] -> run_comprehensive_fix_workflow()
      _ -> show_help()
    end
  end

  def show_help do
    IO.puts("""
    AEE SOPv5.11 Systematic Parameter Fixer

    Usage:
      --analyze       Analyze parameter mismatches across codebase
      --fix           Execute systematic parameter fixes
      --validate      Validate fixes with Patient Mode compilation
      --comprehensive Run complete fix workflow

    Example:
      elixir scripts/validation/systematic_parameter_fixer_aee.exs --comprehensive
    """)
  end

  def run_comprehensive_fix_workflow do
    IO.puts("🚀 AEE SOPv5.11: Comprehensive Parameter Fix Workflow")

    # Phase 1: Analysis
    analysis = analyze_parameter_issues()

    # Phase 2: Systematic Fixes
    fix_results = execute_systematic_fixes()

    # Phase 3: Validation
    validation = validate_fixes()

    # Generate comprehensive report
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report = %{
      timestamp: timestamp,
      analysis: analysis,
      fixes: fix_results,
      validation: validation,
      status: if(validation.compilation_success, do: "SUCCESS", else: "REQUIRES_ADDITIONAL_FIXES")
    }

    report_file = "./__data/tmp/#{timestamp}-comprehensive-parameter-fix-report.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))

    IO.puts("📋 Comprehensive Fix Workflow Complete:")
    IO.puts("   Report: #{report_file}")
    IO.puts("   Status: #{report.status}")

    report
  end

  def analyze_parameter_issues do
    IO.puts("🔍 Analyzing Parameter Issues Across Codebase")

    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")

    _analysis_results = Enum.map(files, fn file ->
      content = File.read!(file)

      %{
        file: file,
        underscore_parameters: find_underscore_parameters(content),
        undefined_variables: find_undefined_variables(content),
        genserver_issues: find_genserver_parameter_issues(content),
        fix_opportunities: identify_fix_opportunities(content)
      }
    end)

    # Summary statistics
    total_files = length(analysis_results)
    files_with_issues = Enum.count(analysis_results, fn result ->
      length(result.underscore_parameters) > 0 or
      length(result.undefined_variables) > 0 or
      length(result.genserver_issues) > 0
    end)

    total_fixes_needed = Enum.sum(Enum.map(analysis_results, &length(&1.fix_opportunities)))

    IO.puts("📊 Parameter Issue Analysis:")
    IO.puts("   Files Analyzed: #{total_files}")
    IO.puts("   Files with Issues: #{files_with_issues}")
    IO.puts("   Total Fixes Needed: #{total_fixes_needed}")

    %{
      total_files: total_files,
      files_with_issues: files_with_issues,
      total_fixes_needed: total_fixes_needed,
      detailed_analysis: analysis_results
    }
  end

  def execute_systematic_fixes do
    IO.puts("🔧 Executing Systematic Parameter Fixes")

    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("test/**/*.exs")
    fix_results = []

    files_fixed = Enum.reduce(files, 0, fn file, acc ->
      original_content = File.read!(file)
      fixed_content = apply_all_parameter_fixes(original_content)

      if original_content != fixed_content do
        File.write!(file, fixed_content)
        fixes_applied = count_fixes_applied(original_content, fixed_content)
        IO.puts("   ✅ Fixed #{file}: #{fixes_applied} parameter fixes applied")
        acc + 1
      else
        acc
      end
    end)

    IO.puts("📊 Systematic Fix Results:")
    IO.puts("   Files Fixed: #{files_fixed}")

    %{files_fixed: files_fixed, timestamp: DateTime.utc_now()}
  end

  def validate_fixes do
    IO.puts("🎯 Validating Fixes with Patient Mode Compilation")

    # Run Patient Mode compilation
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_file = "./__data/tmp/#{timestamp}-validation-compilation.log"

    compilation_cmd = "NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS=\"+S 16:16 +SDio 16\" MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 mix compile --jobs 16 --verbose 2>&1 | tee -a #{log_file}"

    {_output, _exit_code} = System.cmd("bash", ["-c", compilation_cmd])

    # Analyze results with multiple methods
    content = if File.exists?(log_file), do: File.read!(log_file), else: output

    error_counts = [
      count_errors_method1(content),
      count_errors_method2(content),
      count_errors_method3(content),
      count_errors_method4(content),
      count_errors_method5(content)
    ]

    consensus = Enum.uniq(error_counts) |> length() == 1
    total_errors = if consensus, do: hd(error_counts), else: :consensus_failed

    validation_result = %{
      compilation_success: total_errors == 0,
      error_counts: error_counts,
      consensus_achieved: consensus,
      total_errors: total_errors,
      exit_code: exit_code,
      log_file: log_file
    }

    if validation_result.compilation_success do
      IO.puts("✅ VALIDATION SUCCESS: Zero compilation errors achieved")
    else
      IO.puts("❌ VALIDATION: #{total_errors} errors remaining (consensus: #{consensus})")
    end

    validation_result
  end

  # Parameter fixing functions
  def apply_all_parameter_fixes(content) do
    content
    |> fix_underscore_parameters()
    |> fix_genserver_callbacks()
    |> fix_function_signatures()
    |> fix_callback_parameters()
  end

  def fix_underscore_parameters(content) do
    # Pattern: def function(_param) do ... param ... end
    # Fix: def function(param) do ... param ... end

    # Handle standard function definitions
    content = Regex.replace(~r/def\s+(\w+)\(([^)]*?)_(\w+)([^)]*?)\)\s+do/m, content, fn match, func_name, before, param, after_param ->
      # Check if the parameter is actually used in the function body
      function_body = extract_function_body(content, match)
      if String.contains?(function_body, param) do
        "def #{func_name}(#{before}#{param}#{after_param}) do"
      else
        match  # Keep underscore if truly unused
      end
    end)

    # Handle private function definitions
    Regex.replace(~r/defp\s+(\w+)\(([^)]*?)_(\w+)([^)]*?)\)\s+do/m, content, fn match, func_name, before, param, after_param ->
      function_body = extract_function_body(content, match)
      if String.contains?(function_body, param) do
        "defp #{func_name}(#{before}#{param}#{after_param}) do"
      else
        match
      end
    end)
  end

  def fix_genserver_callbacks(content) do
    # Fix GenServer callback signatures specifically
    content_1 = Regex.replace(~r/def\s+handle_call\(([^,]+),\s*_from,\s*_(\w+)\)\s+do/m, content, fn match, pattern, __state_param ->
      function_body = extract_function_body(content, match)
      if String.contains?(function_body, __state_param) do
        "def handle_call(#{pattern}, _from, #{state_param}) do"
      else
        match
      end
    end)

    content_2 = Regex.replace(~r/def\s+handle_cast\(([^,]+),\s*_(\w+)\)\s+do/m, content_1, fn match, pattern, __state_param ->
      function_body = extract_function_body(content, match)
      if String.contains?(function_body, __state_param) do
        "def handle_cast(#{pattern}, #{state_param}) do"
      else
        match
      end
    end)

    Regex.replace(~r/def\s+handle_info\(([^,]+),\s*_(\w+)\)\s+do/m, content_2, fn match, pattern, __state_param ->
      function_body = extract_function_body(content, match)
      if String.contains?(function_body, __state_param) do
        "def handle_info(#{pattern}, #{state_param}) do"
      else
        match
      end
    end)
  end

  def fix_function_signatures(content) do
    # Fix other common parameter patterns
    Regex.replace(~r/def\s+(\w+)\(([^)]*?)_opts([^)]*?)\)\s+do/m, content, fn match, func_name, before, after_param ->
      function_body = extract_function_body(content, match)
      if String.contains?(function_body, "__opts") do
        "def #{func_name}(#{before}__opts#{after_param}) do"
      else
        match
      end
    end)
  end

  def fix_callback_parameters(content) do
    # Fix callback parameter patterns
    Regex.replace(~r/def\s+(\w+)\(([^)]*?)_params([^)]*?)\)\s+do/m, content, fn match, func_name, before, after_param ->
      function_body = extract_function_body(content, match)
      if String.contains?(function_body, "__params") do
        "def #{func_name}(#{before}__params#{after_param}) do"
      else
        match
      end
    end)
  end

  # Analysis helper functions
  def find_underscore_parameters(content) do
    Regex.scan(~r/def.*?_(\w+).*?do/m, content)
    |> Enum.map(&List.last/1)
    |> Enum.uniq()
  end

  def find_undefined_variables(content) do
    # This is a simplified analysis - in a real implementation,
    # we would need to parse the AST to accurately find undefined variables
    lines = String.split(content, "\n")

    Enum.with_index(lines)
    |> Enum.filter(fn {line, _index} ->
      String.contains?(line, "undefined variable")
    end)
    |> Enum.map(fn {line, index} ->
      %{line_number: index + 1, content: String.trim(line)}
    end)
  end

  def find_genserver_parameter_issues(content) do
    patterns = [
      ~r/handle_call\([^,]*,\s*_from,\s*_(\w+)\)/,
      ~r/handle_cast\([^,]*,\s*_(\w+)\)/,
      ~r/handle_info\([^,]*,\s*_(\w+)\)/
    ]

    Enum.flat_map(patterns, fn pattern ->
      Regex.scan(pattern, content, capture: :all_but_first)
    end)
  end

  def identify_fix_opportunities(content) do
    # Identify specific patterns that need fixing
    opportunities = []

    # Check for underscore parameters that are used
    underscore_params = find_underscore_parameters(content)
    opportunities = opportunities ++ Enum.map(underscore_params, &({:underscore_parameter, &1}))

    # Check for GenServer callback issues
    genserver_issues = find_genserver_parameter_issues(content)
    opportunities = opportunities ++ Enum.map(genserver_issues, &({:genserver_callback, &1}))

    opportunities
  end

  def extract_function_body(content, function_definition) do
    # This is a simplified implementation
    # In a real implementation, we would need to properly parse the AST
    lines = String.split(content, "\n")

    # Find the line with the function definition
    def_line_index = Enum.find_index(lines, &String.contains?(&1, function_definition))

    if def_line_index do
      # Take next 10 lines as a simple approximation of function body
      lines
      |> Enum.drop(def_line_index + 1)
      |> Enum.take(10)
      |> Enum.join("\n")
    else
      ""
    end
  end

  def count_fixes_applied(original, fixed) do
    # Count the number of differences between original and fixed content
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    Enum.zip(original_lines, fixed_lines)
    |> Enum.count(fn {orig, fix} -> orig != fix end)
  end

  # Error detection methods (same as in enhanced pr__evention system)
  def count_errors_method1(output) do
    output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error:"))
  end

  def count_errors_method2(output) do
    patterns = [~r/error:/, ~r/\*\* \(/, ~r/undefined variable/, ~r/undefined function/]
    lines = String.split(output, "\n")
    Enum.count(lines, fn line ->
      Enum.any?(patterns, &Regex.match?(&1, line))
    end)
  end

  def count_errors_method3(output) do
    lines = String.split(output, "\n")
    Enum.count(lines, fn line ->
      String.contains?(line, "error:") and not String.contains?(line, "warning:")
    end)
  end

  def count_errors_method4(output) do
    error_patterns = ["error:", "** (", "undefined variable", "undefined function", "CompileError"]

    error_patterns
    |> Enum.reduce(0, fn pattern, acc ->
      case String.split(output, pattern) do
        [_] -> acc
        parts -> acc + (length(parts) - 1)
      end
    end)
  end

  def count_errors_method5(output) do
    lines = String.split(output, "\n")
    error_keywords = ["error", "undefined", "CompileError", "cannot compile"]

    Enum.count(lines, fn line ->
      line_lower = String.downcase(line)
      Enum.any?(error_keywords, &String.contains?(line_lower, &1)) and
      not String.contains?(line_lower, "warning")
    end)
  end
end

# Execute if run directly
SystematicParameterFixerAEE.main(System.argv())