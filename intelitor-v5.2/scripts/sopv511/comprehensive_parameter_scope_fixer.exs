#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveParameterScopeFixer do
  @moduledoc """
  Comprehensive Parameter Scope Error Fixer - SOPv5.11 Enhanced

  Fixes systematic parameter scope errors where functions have underscore-prefixed
  parameters (_opts, _params) but reference the non-prefixed version in function bodies.

  Based on compilation errors pattern: "undefined variable '__opts'" where function
  signature uses "_opts" but body references "__opts".
  """

  def main(args \\ []) do
    IO.puts("🚨 SOPv5.11 Comprehensive Parameter Scope Fixer")
    IO.puts("🎯 Fixing systematic underscore parameter mismatches")

    case Enum.at(args, 0) do
      "--analyze" -> analyze_parameter_errors()
      "--fix-all" -> fix_all_parameter_errors()
      "--test" -> test_parameter_fixes()
      _ ->
        IO.puts("Usage: elixir #{__MODULE__} [--analyze|--fix-all|--test]")
        analyze_and_fix()
    end
  end

  def analyze_and_fix do
    IO.puts("\n📊 Phase 1: Analyzing parameter scope errors...")
    files_with_errors = analyze_parameter_errors()

    IO.puts("\n🔧 Phase 2: Applying systematic fixes...")
    fix_results = fix_all_parameter_errors()

    IO.puts("\n🧪 Phase 3: Testing compilation...")
    test_parameter_fixes()

    %{
      analysis: files_with_errors,
      fixes: fix_results,
      timestamp: DateTime.utc_now()
    }
  end

  def analyze_parameter_errors do
    IO.puts("🔍 Analyzing Elixir files for parameter scope patterns...")

    # Get all .ex files in the lib directory
    files = Path.wildcard("lib/**/*.ex")

    error_patterns = [
      # Pattern: undefined variable "__opts" with _opts parameter
      {~r/def\s+\w+\([^)]*,\s*_opts([^)]*)\)\s+do/, ~r/(?<!_)__opts\b/, "_opts", "__opts"},
      {~r/def\s+\w+\([^)]*,\s*_params([^)]*)\)\s+do/, ~r/(?<!_)__params\b/, "_params", "__params"},
      {~r/def\s+\w+\([^)]*,\s*_conn([^)]*)\)\s+do/, ~r/(?<!_)conn\b/, "_conn", "conn"},
      {~r/def\s+\w+\([^)]*,\s*_state([^)]*)\)\s+do/, ~r/(?<!_)__state\b/, "_state", "__state"},
      {~r/def\s+\w+\([^)]*,\s*_browser_info([^)]*)\)\s+do/, ~r/(?<!_)browser_info\b/, "_browser_info", "browser_info"}
    ]

    files_with_errors = []

    for file <- files do
      case File.read(file) do
        {:ok, content} ->
          errors = detect_parameter_scope_errors(file, content, error_patterns)
          if not Enum.empty?(errors) do
            files_with_errors = [{file, errors} | files_with_errors]
            IO.puts("❌ #{file}: #{length(errors)} parameter scope errors")
          end
        {:error, reason} ->
          IO.puts("⚠️ Cannot read #{file}: #{reason}")
      end
    end

    IO.puts("📊 Total files with parameter errors: #{length(files_with_errors)}")
    files_with_errors
  end

  def detect_parameter_scope_errors(file, content, patterns) do
    errors = []

    for {param_pattern, usage_pattern, underscore_param, clean_param} <- patterns do
      # Find functions with underscore parameters
      functions_with_underscore = Regex.scan(param_pattern, content, return: :index)

      if not Enum.empty?(functions_with_underscore) do
        # Check if the clean parameter is used in the content
        if Regex.match?(usage_pattern, content) do
          errors = [%{
            file: file,
            pattern: clean_param,
            underscore_param: underscore_param,
            clean_param: clean_param,
            description: "Function has #{underscore_param} parameter but references #{clean_param}"
          } | errors]
        end
      end
    end

    errors
  end

  def fix_all_parameter_errors do
    IO.puts("🔧 Starting comprehensive parameter scope fixes...")

    # Known files with parameter errors from compilation output
    files_to_fix = [
      "lib/indrajaal/agent_comments/comprehensive_agent_integrator.ex",
      "lib/indrajaal/access_control_context.ex",
      "lib/indrajaal/access_control.ex",
      "lib/indrajaal/access_control/unified_patterns.ex",
      "lib/indrajaal/accounts/session_security.ex"
    ]

    fix_results = []

    for file <- files_to_fix do
      if File.exists?(file) do
        case fix_parameter_errors_in_file(file) do
          {:ok, fixes} ->
            fix_results = [{file, fixes} | fix_results]
            IO.puts("✅ Fixed #{length(fixes)} parameter errors in #{file}")
          {:error, reason} ->
            IO.puts("❌ Failed to fix #{file}: #{reason}")
        end
      else
        IO.puts("⚠️ File not found: #{file}")
      end
    end

    IO.puts("📊 Total files fixed: #{length(fix_results)}")
    fix_results
  end

  def fix_parameter_errors_in_file(file) do
    case File.read(file) do
      {:ok, content} ->
        fixes = []

        # Pattern fixes to apply
        replacements = [
          # Function signatures - remove underscore prefix when parameter is used
          {~r/def\s+(\w+)\(([^)]*),\s*_opts(\s*\\\\\s*[^),)]*)?([^)]*)\)\s+do/,
           fn [match, func_name, before_opts, default_val, after_opts] ->
             default_part = if default_val, do: default_val, else: ""
             "def #{func_name}(#{before_opts}, __opts#{default_part}#{after_opts}) do"
           end},

          {~r/def\s+(\w+)\(([^)]*),\s*_params([^)]*)\)\s+do/,
           fn [match, func_name, before_params, after_params] ->
             "def #{func_name}(#{before_params}, __params#{after_params}) do"
           end},

          {~r/def\s+(\w+)\(([^)]*),\s*_conn([^)]*)\)\s+do/,
           fn [match, func_name, before_conn, after_conn] ->
             "def #{func_name}(#{before_conn}, conn#{after_conn}) do"
           end},

          {~r/def\s+(\w+)\(([^)]*),\s*_state([^)]*)\)\s+do/,
           fn [match, func_name, before_state, after_state] ->
             "def #{func_name}(#{before_state}, __state#{after_state}) do"
           end},

          {~r/def\s+(\w+)\(([^)]*),\s*_browser_info([^)]*)\)\s+do/,
           fn [match, func_name, before_browser, after_browser] ->
             "def #{func_name}(#{before_browser}, browser_info#{after_browser}) do"
           end}
        ]

        updated_content = content

        for {pattern, replacement_func} <- replacements do
          updated_content = Regex.replace(pattern, updated_content, fn match ->
            captures = Regex.run(pattern, match)
            if captures do
              case replacement_func.(captures) do
                result when is_binary(result) ->
                  fixes = ["Applied #{inspect(pattern)}" | fixes]
                  result
                _ -> match
              end
            else
              match
            end
          end)
        end

        # Write the updated content back
        case File.write(file, updated_content) do
          :ok -> {:ok, fixes}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} -> {:error, reason}
    end
  end

  def test_parameter_fixes do
    IO.puts("🧪 Testing compilation after parameter fixes...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"],
                   stderr_to_stdout: true,
                   env: [{"NO_TIMEOUT", "true"}, {"PATIENT_MODE", "enabled"}, {"INFINITE_PATIENCE", "true"}]) do
      {output, 0} ->
        IO.puts("✅ Compilation successful!")
        IO.puts("📊 Parameter scope fixes resolved compilation errors")
        :ok
      {output, _code} ->
        IO.puts("❌ Compilation still has errors:")

        # Extract and show remaining errors
        error_lines = String.split(output, "\n")
        |> Enum.filter(&(String.contains?(&1, "error:") or String.contains?(&1, "undefined variable")))
        |> Enum.take(10)

        for line <- error_lines do
          IO.puts("   #{line}")
        end

        IO.puts("\n📋 Saving compilation output for analysis...")
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
        log_file = "./__data/tmp/parameter-compilation-#{timestamp}.log"
        File.write!(log_file, output)
        IO.puts("📄 Compilation log saved to: #{log_file}")

        :errors_remain
    end
  end
end

# Execute if run directly
if System.argv() != [] or Path.basename(__ENV__.file) == Path.basename(System.argv() |> hd || "") do
  ComprehensiveParameterScopeFixer.main(System.argv())
end