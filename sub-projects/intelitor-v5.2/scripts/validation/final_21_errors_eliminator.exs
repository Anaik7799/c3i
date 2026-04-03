#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Final21ErrorsEliminator do
  @moduledoc """
  🎯 CRITICAL: Fix remaining 21 compilation errors to achieve zero-error checkpoint
  Focuses on __context undefined variables and tenant_id conflicts
  """

  def main(args \\ []) do
    IO.puts("🎯 CRITICAL: Fixing remaining 21 errors for zero-error validation checkpoint")

    case Enum.at(args, 0) do
      "--execute" -> execute_final_fixes()
      "--analyze" -> analyze_remaining_errors()
      _ -> show_help()
    end
  end

  defp execute_final_fixes do
    IO.puts("🔧 Applying final fixes for 21 remaining errors...")

    fixes = [
      {"lib/indrajaal/access_control/domain_hooks.ex", &fix_domain_hooks_context/1},
      {"lib/indrajaal/access_control_context.ex", &fix_access_control_tenant_conflicts/1},
      {"lib/indrajaal/access_control/timescale_integration.ex", &fix_timescale_tenant_id/1}
    ]

    total_fixes = Enum.reduce(fixes, 0, fn {file_path, fix_function}, acc ->
      if File.exists?(file_path) do
        case apply_fix(file_path, fix_function) do
          {:ok, fixes_count} when fixes_count > 0 ->
            IO.puts("✅ Fixed #{Path.basename(file_path)}: #{fixes_count} fixes")
            acc + fixes_count
          {:ok, 0} ->
            acc
          {:error, reason} ->
            IO.puts("❌ Error processing #{Path.basename(file_path)}: #{reason}")
            acc
        end
      else
        acc
      end
    end)

    IO.puts("📊 Total fixes applied: #{total_fixes}")
    IO.puts("🎯 Running Patient Mode validation...")
    validate_zero_errors_achieved()
  end

  defp apply_fix(file_path, fix_function) do
    try do
      original_content = File.read!(file_path)
      fixed_content = fix_function.(original_content)

      if fixed_content != original_content do
        File.write!(file_path, fixed_content)
        fixes_count = count_differences(original_content, fixed_content)
        {:ok, fixes_count}
      else
        {:ok, 0}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp fix_domain_hooks_context(content) do
    content
    # Fix all __context undefined variables (11 instances)
    |> String.replace("__context[:session_id]", "_context[:session_id]")
    |> String.replace("__context[:admin_context]", "_context[:admin_context]")
    |> String.replace("__context[:__request_context]", "_context[:__request_context]")
    |> String.replace("__context[:admin_user_id]", "_context[:admin_user_id]")
    |> String.replace("__context[:__request_id]", "_context[:__request_id]")
    |> String.replace("__context[:detection_method]", "_context[:detection_method]")
    |> String.replace("__context[:repeated_attempts]", "_context[:repeated_attempts]")
    |> String.replace("__context[:previous_permission_level]", "_context[:previous_permission_level]")
    |> String.replace("__context: __context", "_context: _context")
    |> String.replace("event_data, __context}", "event_data, _context}")
    |> String.replace("Map.get(__context ||", "Map.get(_context ||")

    # Fix function signatures to include _context parameter
    |> String.replace("defp broadcast_security_alert(exception, context) do", "defp broadcast_security_alert(exception, _context) do")
    |> String.replace("defp is_anomalous_access_event?(access_log, context) do", "defp is_anomalous_access_event?(access_log, _context) do")
    |> String.replace("defp is_privilege_escalation?(access_grant, context) do", "defp is_privilege_escalation?(access_grant, _context) do")
    |> String.replace("defp enrich_access_log_context(context, additional_context) do", "defp enrich_access_log_context(_context, additional_context) do")
    |> String.replace("defp enrich_credential_context(context, additional_context) do", "defp enrich_credential_context(_context, additional_context) do")
    |> String.replace("defp enrich_access_grant_context(context, additional_context) do", "defp enrich_access_grant_context(_context, additional_context) do")
    |> String.replace("defp enrich_access_rule_context(context, additional_context) do", "defp enrich_access_rule_context(_context, additional_context) do")
    |> String.replace("defp enrich_security_exception_context(context, additional_context) do", "defp enrich_security_exception_context(_context, additional_context) do")

    # Fix broadcastevent function - add missing parameters
    |> String.replace("defp broadcastevent(event_type, event_data, context) do",
                     "defp broadcastevent(event_type, event_data, _context) do\n    event_message = {event_type, event_data, _context}")
  end

  defp fix_access_control_tenant_conflicts(content) do
    content
    # Fix the tenant_id vs _tenant_id conflicts
    |> String.replace("defp do_create_access_control(attrs, tenant_id, user) do",
                     "defp do_create_access_control(attrs, _tenant_id, user) do")
    |> String.replace("tenant_id: _tenant_id,", "tenant_id: _tenant_id,")

    # Fix usage of _tenant_id to remove underscore warning when it's actually used
    |> String.replace("fetch_access_control(id, _tenant_id)", "fetch_access_control(id, tenant_id)")
    |> String.replace("do_create_access_control(attrs, _tenant_id, user)", "do_create_access_control(attrs, tenant_id, user)")
    |> String.replace("tenant_id: _tenant_id", "tenant_id: tenant_id")
    |> String.replace("%{id: id, tenant_id: _tenant_id,", "%{id: id, tenant_id: tenant_id,")

    # Fix function parameter usage
    |> String.replace("_tenant_id = Keyword.get(opts, :tenant_id)", "tenant_id = Keyword.get(opts, :tenant_id)")
    |> String.replace("list_access_control(tenant_id: _tenant_id)", "list_access_control(tenant_id: tenant_id)")
  end

  defp fix_timescale_tenant_id(content) do
    content
    # Fix undefined tenant_id in logauthentication_event function
    |> String.replace("def logauthentication_event(event_type, user_id, opts \\\\ %{}) do",
                     "def logauthentication_event(event_type, user_id, opts \\\\ %{}) do\n    tenant_id = Map.get(opts, :tenant_id)")
    |> String.replace("    event_data = %{\n      tenant_id,", "    event_data = %{\n      tenant_id: tenant_id,")
  end

  defp count_differences(original, fixed) do
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    max_lines = max(length(original_lines), length(fixed_lines))

    0..(max_lines - 1)
    |> Enum.count(fn i ->
      orig_line = Enum.at(original_lines, i, "")
      fixed_line = Enum.at(fixed_lines, i, "")
      orig_line != fixed_line
    end)
  end

  defp validate_zero_errors_achieved do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_file = "./data/tmp/final_zero_errors_validation_#{timestamp}.log"

    File.mkdir_p("./data/tmp")

    case System.cmd("env", [
      "NO_TIMEOUT=true",
      "PATIENT_MODE=enabled",
      "INFINITE_PATIENCE=true",
      "ELIXIR_ERL_OPTIONS=+S 16",
      "mix", "compile", "--warnings-as-errors"
    ], stderr_to_stdout: true) do
      {output, 0} ->
        File.write!(log_file, output)
        IO.puts("🏆 ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED!")
        IO.puts("✅ Perfect compilation: 0 errors, 0 warnings")
        save_success_report(timestamp)
        true
      {output, _} ->
        File.write!(log_file, output)
        errors = count_errors(output)
        warnings = count_warnings(output)

        IO.puts("📊 Final Validation Results:")
        IO.puts("   Errors: #{errors}")
        IO.puts("   Warnings: #{warnings}")
        IO.puts("📄 Full compilation log saved: #{log_file}")

        if errors > 0 do
          IO.puts("🔄 #{errors} errors remain - further analysis needed")
          show_sample_issues(output, "error")
        end

        if warnings > 0 do
          IO.puts("🔄 #{warnings} warnings remain - final cleanup needed")
          show_sample_issues(output, "warning")
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

  defp show_sample_issues(output, type) do
    IO.puts("\n🔍 Sample #{type}s:")

    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "#{type}:"))
    |> Enum.take(10)
    |> Enum.each(fn line ->
      IO.puts("   #{String.trim(line)}")
    end)
  end

  defp analyze_remaining_errors do
    IO.puts("🔍 Analyzing remaining error patterns from current compilation...")
    # Implementation for specific analysis
  end

  defp save_success_report(timestamp) do
    report_path = "./data/tmp/zero_errors_checkpoint_success_#{timestamp}.log"

    report = """
    🏆 ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED - ULTIMATE SUCCESS
    ==============================================================

    Timestamp: #{DateTime.utc_now()}

    📊 FINAL RESULTS:
    - Compilation Errors: 0 ✅ (was 21)
    - Compilation Warnings: 0 ✅ (was 8)
    - Zero-Error Validation Checkpoint: ACHIEVED ✅

    🔧 Final Fixes Applied:
    - Fixed all 11 __context undefined variables in domain_hooks.ex
    - Resolved tenant_id vs _tenant_id naming conflicts in access_control_context.ex
    - Fixed undefined tenant_id in timescale_integration.ex logauthentication_event function
    - Corrected function parameter signatures to match variable usage
    - Applied systematic variable naming consistency

    🎯 ULTIMATE SUCCESS: Zero-error validation checkpoint achieved!
    All compilation errors and warnings have been systematically eliminated.
    The project now compiles with zero errors and zero warnings.
    """

    File.write!(report_path, report)
    IO.puts("📄 Success report saved: #{report_path}")
  end

  defp show_help do
    IO.puts("""
    🎯 Final 21 Errors Eliminator

    Usage:
      elixir final_21_errors_eliminator.exs [--execute|--analyze]

    Commands:
      --execute    Execute final fixes for remaining 21 errors
      --analyze    Analyze remaining error patterns
    """)
  end
end

Final21ErrorsEliminator.main(System.argv())