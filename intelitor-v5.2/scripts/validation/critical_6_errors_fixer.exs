#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Critical6ErrorsFixer do
  @moduledoc """
  🎯 CRITICAL: Fix 6 compilation errors blocking zero-error validation checkpoint

  Target errors:
  1. lib/indrajaal/access_control/analytics_engine.ex:495 - undefined variable "data"
  2. lib/indrajaal/access_control/analytics_engine.ex:496 - undefined variable "data"
  3. lib/indrajaal/access_control/timescale_integration.ex:171 - undefined variable "__context"
  4. lib/indrajaal/access_control/timescale_integration.ex:172 - undefined variable "__context"
  5. lib/indrajaal/access_control/timescale_integration.ex:174 - undefined variable "__context"
  6. lib/indrajaal/access_control/timescale_integration.ex:175 - undefined variable "__context"
  """

  def main(args \\ []) do
    IO.puts("🎯 CRITICAL: Fixing 6 compilation errors for zero-error validation checkpoint")

    case Enum.at(args, 0) do
      "--execute" -> execute_critical_fixes()
      "--analyze" -> analyze_critical_errors()
      _ -> show_help()
    end
  end

  defp execute_critical_fixes do
    IO.puts("🔧 Fixing 6 critical compilation errors...")

    # Fix analytics_engine.ex errors
    fix_analytics_engine_errors()

    # Fix timescale_integration.ex errors
    fix_timescale_integration_errors()

    # Validate fixes
    IO.puts("🎯 Running final Patient Mode validation...")
    validate_compilation_success()
  end

  defp fix_analytics_engine_errors do
    file_path = "lib/indrajaal/access_control/analytics_engine.ex"
    IO.puts("🔧 Fixing undefined 'data' variables in #{file_path}...")

    content = File.read!(file_path)

    # Fix undefined 'data' variable - replace with proper parameter
    fixed_content = content
    |> String.replace(
      "temporal: analyze_temporal_patterns(data),",
      "temporal: analyze_temporal_patterns(analytics_data),"
    )
    |> String.replace(
      "behavioral: analyze_behavioral_patterns(data),",
      "behavioral: analyze_behavioral_patterns(analytics_data),"
    )

    # Also need to ensure the function has analytics_data parameter
    fixed_content = if String.contains?(fixed_content, "defp perform_enhanced_analysis(") do
      String.replace(
        fixed_content,
        "defp perform_enhanced_analysis(",
        "defp perform_enhanced_analysis(analytics_data,"
      )
    else
      fixed_content
    end

    File.write!(file_path, fixed_content)
    IO.puts("✅ Fixed analytics_engine.ex undefined 'data' variables")
  end

  defp fix_timescale_integration_errors do
    file_path = "lib/indrajaal/access_control/timescale_integration.ex"
    IO.puts("🔧 Fixing undefined '__context' variables in #{file_path}...")

    content = File.read!(file_path)

    # Fix undefined '__context' variable - replace with proper parameter
    fixed_content = content
    |> String.replace("__context[:tenant_id]", "context[:tenant_id]")
    |> String.replace("__context[:user_id]", "context[:user_id]")
    |> String.replace("__context[:request_id]", "context[:request_id]")
    |> String.replace("__context[:correlation_id]", "context[:correlation_id]")

    # Also fix the function parameter if it uses __context
    fixed_content = String.replace(
      fixed_content,
      "defp build_query_context(__context, filters) do",
      "defp build_query_context(context, filters) do"
    )

    File.write!(file_path, fixed_content)
    IO.puts("✅ Fixed timescale_integration.ex undefined '__context' variables")
  end

  defp analyze_critical_errors do
    IO.puts("🔍 Analyzing 6 critical compilation errors...")

    errors = [
      %{
        file: "lib/indrajaal/access_control/analytics_engine.ex",
        line: 495,
        error: "undefined variable \"data\"",
        solution: "Replace 'data' with proper parameter 'analytics_data'"
      },
      %{
        file: "lib/indrajaal/access_control/analytics_engine.ex",
        line: 496,
        error: "undefined variable \"data\"",
        solution: "Replace 'data' with proper parameter 'analytics_data'"
      },
      %{
        file: "lib/indrajaal/access_control/timescale_integration.ex",
        line: 171,
        error: "undefined variable \"__context\"",
        solution: "Replace '__context' with 'context'"
      },
      %{
        file: "lib/indrajaal/access_control/timescale_integration.ex",
        line: 172,
        error: "undefined variable \"__context\"",
        solution: "Replace '__context' with 'context'"
      },
      %{
        file: "lib/indrajaal/access_control/timescale_integration.ex",
        line: 174,
        error: "undefined variable \"__context\"",
        solution: "Replace '__context' with 'context'"
      },
      %{
        file: "lib/indrajaal/access_control/timescale_integration.ex",
        line: 175,
        error: "undefined variable \"__context\"",
        solution: "Replace '__context' with 'context'"
      }
    ]

    IO.puts("📊 Critical Error Analysis:")
    Enum.each(errors, fn error ->
      IO.puts("   #{error.file}:#{error.line} - #{error.error}")
      IO.puts("     Solution: #{error.solution}")
    end)
  end

  defp validate_compilation_success do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_file = "./data/tmp/critical_6_errors_validation_#{timestamp}.log"

    # Ensure directory exists
    File.mkdir_p("./data/tmp")

    case System.cmd("mix", ["compile", "--warnings-as-errors"],
                   stderr_to_stdout: true,
                   env: [{"NO_TIMEOUT", "true"}, {"PATIENT_MODE", "enabled"}, {"INFINITE_PATIENCE", "true"}]) do
      {output, 0} ->
        File.write!(log_file, output)
        IO.puts("🏆 ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED!")
        IO.puts("✅ All 6 critical compilation errors fixed successfully")
        save_success_report(timestamp)
        true
      {output, _} ->
        File.write!(log_file, output)
        errors = count_errors(output)
        warnings = count_warnings(output)

        IO.puts("📊 Critical Error Fix Results:")
        IO.puts("   Errors: #{errors}")
        IO.puts("   Warnings: #{warnings}")
        IO.puts("📄 Full compilation log saved: #{log_file}")

        if errors > 0 do
          IO.puts("🔄 Additional fixes needed - #{errors} errors remain")
          show_remaining_errors(output)
        else
          IO.puts("✅ All critical errors fixed! #{warnings} warnings remain to be addressed.")
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
    IO.puts("\n🔍 Remaining errors:")

    output
    |> String.split("\n")
    |> Enum.filter(fn line ->
      String.contains?(line, "error:") ||
      String.contains?(line, "** (") ||
      String.contains?(line, "undefined")
    end)
    |> Enum.take(10)
    |> Enum.each(fn line ->
      IO.puts("   #{String.trim(line)}")
    end)
  end

  defp save_success_report(timestamp) do
    report_path = "./data/tmp/critical_6_errors_success_#{timestamp}.log"

    report = """
    🏆 CRITICAL 6 ERRORS FIXED SUCCESSFULLY
    =====================================

    Timestamp: #{DateTime.utc_now()}

    📊 RESULTS:
    - Critical Compilation Errors: 0 ✅ (was 6)
    - Files Fixed: 2 ✅
      - lib/indrajaal/access_control/analytics_engine.ex
      - lib/indrajaal/access_control/timescale_integration.ex

    🔧 Applied Fixes:
    - Fixed undefined 'data' variables in analytics_engine.ex
    - Fixed undefined '__context' variables in timescale_integration.ex
    - Updated function parameters to match variable usage

    🎯 Next Phase: Address remaining warnings to achieve zero-error validation checkpoint
    """

    File.write!(report_path, report)
    IO.puts("📄 Success report saved: #{report_path}")
  end

  defp show_help do
    IO.puts("""
    🎯 Critical 6 Errors Fixer

    Usage:
      elixir critical_6_errors_fixer.exs [--execute|--analyze]

    Commands:
      --execute    Execute fixes for 6 critical compilation errors
      --analyze    Analyze the 6 critical errors and solutions
    """)
  end
end

Critical6ErrorsFixer.main(System.argv())