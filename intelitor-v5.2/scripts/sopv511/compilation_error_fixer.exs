#!/usr/bin/env elixir

defmodule SOPv511.CompilationErrorFixer do
  @moduledoc """
  SOPv5.11 Cybernetic Framework - Compilation Error Fixer
  🎯 CRITICAL MISSION: Fix compilation errors preventing --warnings-as-errors
  📊 TARGET: predictive_analytics.ex undefined variable errors
  """

  def main(args \\ []) do
    IO.puts("🎯 SOPv5.11 Compilation Error Fixer")
    IO.puts("📊 Mission: Fix undefined variable errors in predictive_analytics.ex")

    case args do
      ["--fix"] -> fix_predictive_analytics()
      ["--validate"] -> validate_fixes()
      _ -> show_help()
    end
  end

  defp fix_predictive_analytics do
    IO.puts("\n🔧 Fixing predictive_analytics.ex compilation errors...")

    file_path = "lib/indrajaal/analytics/predictive_analytics.ex"
    content = File.read!(file_path)

    # Fix parameter names to match variable usage
    fixed_content = content
    |> String.replace("horizonhours,", "horizon_hours,")
    |> String.replace("confidencelevel", "confidence_level")
    |> String.replace("modeltype", "model_type")
    |> String.replace("resourcemetrics,", "resource_metrics,")
    |> String.replace("horizonhours)", "horizon_hours)")

    File.write!(file_path, fixed_content)
    IO.puts("✅ Fixed parameter names in predictive_analytics.ex")

    # Test compilation
    IO.puts("\n🔍 Testing compilation...")
    {output, exit_code} = System.cmd("mix", ["compile", "lib/indrajaal/analytics/predictive_analytics.ex"])

    if exit_code == 0 do
      IO.puts("✅ Compilation successful")
    else
      IO.puts("❌ Compilation still has issues:")
      IO.puts(output)
    end
  end

  defp validate_fixes do
    IO.puts("\n🔍 Validating compilation fixes...")

    {output, exit_code} = System.cmd("env",
      ["ELIXIR_ERL_OPTIONS=+S 16", "mix", "compile", "--warnings-as-errors"],
      stderr_to_stdout: true)

    if exit_code == 0 do
      IO.puts("✅ SOPv5.11 COMPILATION VALIDATION: SUCCESSFUL")
      IO.puts("🎯 Ready for warning elimination")
    else
      IO.puts("❌ Still has compilation issues preventing --warnings-as-errors")

      # Show first 20 lines of output
      output
      |> String.split("\n")
      |> Enum.take(20)
      |> Enum.each(&IO.puts("   #{&1}"))
    end
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Compilation Error Fixer

    Usage:
      elixir #{__MODULE__} [command]

    Commands:
      --fix        Fix undefined variable errors in predictive_analytics.ex
      --validate   Validate compilation with --warnings-as-errors

    📋 SOPv5.11 Protocol Compliance:
    - Fix compilation errors first
    - Then proceed to warning elimination
    """)
  end
end

# Execute if run directly
if System.argv() |> length() > 0 do
  SOPv511.CompilationErrorFixer.main(System.argv())
else
  SOPv511.CompilationErrorFixer.main(["--help"])
end