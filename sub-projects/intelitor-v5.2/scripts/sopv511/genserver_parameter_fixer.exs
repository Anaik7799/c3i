#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule GenServerParameterFixer do
  @moduledoc """
  GenServer Parameter Scope Error Fixer - SOPv5.11 Enhanced

  Systematically fixes parameter scope errors in GenServer modules where:
  - Functions have underscore-prefixed parameters (_opts, _state, _params)
  - Function bodies reference the non-prefixed version (__opts, __state, __params)

  This is the final phase of compilation error resolution for AEE SOPv5.11 implementation.
  """

  def main(args \\ []) do
    IO.puts("🚨 SOPv5.11 GenServer Parameter Scope Fixer")
    IO.puts("🎯 Final phase: Fixing GenServer parameter scope errors")

    case Enum.at(args, 0) do
      "--fix-all" -> fix_all_genserver_errors()
      "--test" -> test_compilation()
      _ ->
        IO.puts("📊 Analyzing and fixing GenServer parameter scope errors...")
        fix_all_genserver_errors()
        test_compilation()
    end
  end

  def fix_all_genserver_errors do
    IO.puts("🔧 Starting systematic GenServer parameter fixes...")

    # Files identified from compilation errors with specific patterns
    files_to_fix = [
      {"lib/indrajaal/alarms/analytics_dashboard.ex", [
        # start_link function
        {"def start_link(_opts \\\\", "def start_link(__opts \\\\"},
        # All handle_call functions with _state but using __state
        {"handle_call(", "_state)", "__state)"},
        # All handle_info functions with _state but using __state
        {"handle_info(", "_state)", "__state)"}
      ]},
      {"lib/indrajaal/alarms/analytics_engine.ex", [
        {"def start_link(_opts \\\\", "def start_link(__opts \\\\"},
        {"handle_info(", "_state)", "__state)"}
      ]},
      {"lib/indrajaal/accounts/authentication.ex", [
        {"def start_link(_opts \\\\", "def start_link(__opts \\\\"},
        {"def authenticate(", "_opts \\\\", "__opts \\\\"},
        {"handle_info(", "_state)", "__state)"}
      ]},
      {"lib/indrajaal/agent_comments/comprehensive_agent_integrator.ex", [
        # __opts warning
        {"handle_call({:execute_comprehensive_integration, __opts}", "_opts"},
      ]}
    ]

    for {file, patterns} <- files_to_fix do
      if File.exists?(file) do
        case fix_genserver_file(file, patterns) do
          {:ok, fixes_count} ->
            IO.puts("✅ Fixed #{fixes_count} parameter issues in #{file}")
          {:error, reason} ->
            IO.puts("❌ Failed to fix #{file}: #{reason}")
        end
      else
        IO.puts("⚠️ File not found: #{file}")
      end
    end
  end

  def fix_genserver_file(file, patterns) do
    case File.read(file) do
      {:ok, content} ->
        fixes_count = 0
        updated_content = content

        # Apply systematic fixes for GenServer parameter patterns
        updated_content = fix_start_link_functions(updated_content)
        updated_content = fix_handle_call_functions(updated_content)
        updated_content = fix_handle_info_functions(updated_content)
        updated_content = fix_authenticate_functions(updated_content)
        updated_content = fix_specific_patterns(updated_content)

        case File.write(file, updated_content) do
          :ok -> {:ok, count_fixes(content, updated_content)}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} -> {:error, reason}
    end
  end

  defp fix_start_link_functions(content) do
    # Fix start_link(_opts \\ []) -> start_link(__opts \\ []) when __opts is used
    pattern = ~r/def start_link\(_opts(\s*\\\\\s*\[[^\]]*\])?\)\s+do(.*?)end/s

    Regex.replace(pattern, content, fn match ->
      if String.contains?(match, "__opts") and not String.contains?(match, "_opts") do
        String.replace(match, "_opts", "__opts", global: false)
      else
        match
      end
    end)
  end

  defp fix_handle_call_functions(content) do
    # Fix handle_call functions with _state parameter but using __state in body
    pattern = ~r/def handle_call\(([^)]+), _from, _state\)\s+do(.*?)(?=def|@|$)/s

    Regex.replace(pattern, content, fn match ->
      # Check if the function body uses '__state' (not _state)
      if String.contains?(match, "{:reply,") and String.contains?(match, ", __state}") do
        String.replace(match, ", _state) do", ", __state) do")
      else
        match
      end
    end)
  end

  defp fix_handle_info_functions(content) do
    # Fix handle_info functions with _state parameter but using __state in body
    pattern = ~r/def handle_info\(([^)]+), _state\)\s+do(.*?)(?=def|@|$)/s

    Regex.replace(pattern, content, fn match ->
      # Check if the function body uses '__state' (not _state)
      if String.contains?(match, "{:noreply, __state}") do
        String.replace(match, ", _state) do", ", __state) do")
      else
        match
      end
    end)
  end

  defp fix_authenticate_functions(content) do
    # Fix authenticate functions with _opts parameter but using __opts in body
    pattern = ~r/def authenticate\(([^)]+), _opts(\s*\\\\\s*\[[^\]]*\])?\)\s+do(.*?)(?=def|@|$)/s

    Regex.replace(pattern, content, fn match ->
      if String.contains?(match, "__opts") and String.match?(match, ~r/[^_]__opts/) do
        String.replace(match, "_opts", "__opts", global: false)
      else
        match
      end
    end)
  end

  defp fix_specific_patterns(content) do
    # Fix specific patterns found in compilation errors
    content
    |> String.replace(~r/handle_call\(\{:execute_comprehensive_integration, __opts\}, _from, __state\)/,
                     "handle_call({:execute_comprehensive_integration, _opts}, _from, __state)")
    |> String.replace(~r/def generate_report\(_report_type, _params\)/,
                     "def generate_report(report_type, __params)")
    |> String.replace(~r/def get_sla_compliance_report\(_time_period, _opts\)/,
                     "def get_sla_compliance_report(time_period, __opts)")
  end

  defp count_fixes(original, updated) do
    original_lines = String.split(original, "\n")
    updated_lines = String.split(updated, "\n")

    Enum.zip(original_lines, updated_lines)
    |> Enum.count(fn {orig, upd} -> orig != upd end)
  end

  def test_compilation do
    IO.puts("🧪 Testing compilation after GenServer parameter fixes...")

    case System.cmd("mix", ["compile", "--warnings-as-errors"],
                   stderr_to_stdout: true,
                   env: [{"NO_TIMEOUT", "true"}, {"PATIENT_MODE", "enabled"}, {"INFINITE_PATIENCE", "true"}]) do
      {output, 0} ->
        IO.puts("✅ Compilation successful!")
        IO.puts("🎯 GenServer parameter scope fixes resolved compilation errors")
        :ok
      {output, _code} ->
        IO.puts("❌ Compilation still has errors:")

        # Extract remaining errors for analysis
        error_lines = String.split(output, "\n")
        |> Enum.filter(&(String.contains?(&1, "error:") or String.contains?(&1, "undefined variable")))
        |> Enum.take(15)

        for line <- error_lines do
          IO.puts("   #{line}")
        end

        # Count remaining errors
        error_count = length(error_lines)
        IO.puts("\n📊 Remaining errors: #{error_count}")

        # Save compilation output for further analysis
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
        log_file = "./__data/tmp/genserver-compilation-#{timestamp}.log"
        File.write!(log_file, output)
        IO.puts("📄 Compilation log saved to: #{log_file}")

        :errors_remain
    end
  end
end

# Execute if run directly
if System.argv() != [] or Path.basename(__ENV__.file) == Path.basename(System.argv() |> hd || "") do
  GenServerParameterFixer.main(System.argv())
end