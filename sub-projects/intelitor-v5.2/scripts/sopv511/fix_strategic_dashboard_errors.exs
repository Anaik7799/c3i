#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule FixStrategicDashboardErrors do
  @moduledoc """
  Emergency fix for strategic_impact_dashboard.ex compilation errors
  Fixes incorrectly modified __state variables
  """

  def main(args \\ []) do
    IO.puts("🚀 Emergency Fix: Strategic Impact Dashboard Compilation Errors")
    IO.puts("📊 Fixing incorrectly modified state variables")
    IO.puts("⏰ Timestamp: #{current_timestamp()}")

    case args do
      ["--fix"] -> fix_dashboard_errors()
      ["--analyze"] -> analyze_dashboard_errors()
      _ -> show_usage()
    end
  end

  defp show_usage do
    IO.puts("""
    Usage:
      elixir #{__ENV__.file} --fix      # Fix the strategic dashboard errors
      elixir #{__ENV__.file} --analyze  # Analyze the errors
    """)
  end

  def fix_dashboard_errors do
    file_path = "lib/indrajaal/analytics/strategic_impact_dashboard.ex"
    IO.puts("🔧 Fixing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = apply_emergency_fixes(content)

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("  ✅ Fixed compilation errors in #{file_path}")

          # Log the changes
          log_file = "./data/tmp/#{current_timestamp()}-strategic-dashboard-emergency-fix.log"
          log_entry = """
          Emergency Fix Applied: #{file_path}

          Fixed Issues:
          - _state → state (removed extra underscores)
          - __state variable references corrected
          - Function parameter mismatches resolved

          Timestamp: #{current_timestamp()}
          """
          File.write!(log_file, log_entry)
        else
          IO.puts("  ℹ️ No emergency fixes needed in #{file_path}")
        end

        # Test compilation
        test_compilation()

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  defp apply_emergency_fixes(content) do
    content
    # Fix triple underscore state variables (_state -> state)
    |> String.replace(~r/\b_state\b/, "state")
    # Fix function parameter __opts -> _opts (unused parameter)
    |> String.replace(~r/def start_link\(__opts/, "def start_link(_opts")
    |> String.replace(~r/def init\(__opts/, "def init(_opts")
    # Fix incorrect __user_experience_rating -> user_experience_rating
    |> String.replace(~r/__user_experience_rating:/, "user_experience_rating:")
    # Fix state parameter in functions that use it
    |> fix_function_state_parameters()
  end

  defp fix_function_state_parameters(content) do
    content
    # Fix handle_call functions where state is used
    |> String.replace(
      ~r/def handle_call\(([^,]+), ([^,]+), (_state|__state)\) do/,
      "def handle_call(\\1, \\2, state) do"
    )
    # Fix handle_info functions where state is used
    |> String.replace(
      ~r/def handle_info\(([^,]+), (_state|__state)\) do/,
      "def handle_info(\\1, state) do"
    )
    # Fix private function parameters where state is used
    |> String.replace(
      ~r/defp ([a-zA-Z_][a-zA-Z0-9_]*)\(([^,)]*), (_state|__state)\)/,
      "defp \\1(\\2, state)"
    )
    # Fix standalone __state references in function bodies
    |> String.replace(~r/(?<![a-zA-Z0-9_])__state(?![a-zA-Z0-9_])/, "state")
  end

  def analyze_dashboard_errors do
    file_path = "lib/indrajaal/analytics/strategic_impact_dashboard.ex"
    IO.puts("🔍 Analyzing errors in: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        error_lines = lines
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} ->
          String.contains?(line, "_state") or
          String.contains?(line, "__user_experience_rating") or
          (String.contains?(line, "__state") and String.contains?(line, "def "))
        end)

        IO.puts("  📋 Found #{length(error_lines)} problematic lines:")
        Enum.each(error_lines, fn {line, line_num} ->
          IO.puts("    Line #{line_num}: #{String.trim(line)}")
        end)

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
    end
  end

  defp test_compilation do
    IO.puts("🧪 Testing compilation after fixes...")

    case System.cmd("mix", ["compile", "lib/indrajaal/analytics/strategic_impact_dashboard.ex", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Compilation successful - strategic dashboard fixed!")
        true
      {output, _} ->
        IO.puts("❌ Compilation still has issues:")

        # Show first few errors
        errors = output
        |> String.split("\n")
        |> Enum.filter(&(String.contains?(&1, "error:") or String.contains?(&1, "** (")))
        |> Enum.take(5)

        Enum.each(errors, fn error ->
          IO.puts("  #{error}")
        end)

        false
    end
  end

  defp current_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

# Execute
FixStrategicDashboardErrors.main(System.argv())