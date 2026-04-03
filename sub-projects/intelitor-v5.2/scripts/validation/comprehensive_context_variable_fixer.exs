#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveContextVariableFixer do
  @moduledoc """
  🎯 COMPREHENSIVE: Fix all __context variable errors and underscore issues

  This script systematically fixes:
  1. All __context → context variable issues
  2. All __user → user variable issues
  3. All _variable → variable issues (when used)
  4. All variable → _variable issues (when unused)
  """

  def main(args \\ []) do
    IO.puts("🎯 COMPREHENSIVE: Fixing all context and underscore variable issues")

    case Enum.at(args, 0) do
      "--execute" -> execute_comprehensive_fixes()
      "--analyze" -> analyze_all_variable_issues()
      _ -> show_help()
    end
  end

  defp execute_comprehensive_fixes do
    IO.puts("🔧 Applying comprehensive variable fixes...")

    files_to_fix = [
      "lib/indrajaal/access_control/timescale_integration.ex",
      "lib/indrajaal/access_control/analytics_engine.ex",
      "lib/indrajaal/access_control_context.ex",
      "lib/indrajaal/access_control/unified_patterns.ex"
    ]

    Enum.each(files_to_fix, &fix_file/1)

    IO.puts("🎯 Running final Patient Mode validation...")
    validate_compilation_success()
  end

  defp fix_file(file_path) do
    IO.puts("🔧 Fixing #{file_path}...")

    if File.exists?(file_path) do
      content = File.read!(file_path)
      original_content = content

      # Apply all systematic fixes
      fixed_content = content
      |> fix_context_variables()
      |> fix_user_variables()
      |> fix_used_underscored_variables()
      |> fix_unused_variables()

      if fixed_content != original_content do
        File.write!(file_path, fixed_content)
        changes = count_changes(original_content, fixed_content)
        IO.puts("✅ Fixed #{Path.basename(file_path)} (#{changes} changes)")
      else
        IO.puts("📋 No changes needed in #{Path.basename(file_path)}")
      end
    else
      IO.puts("⚠️  File not found: #{file_path}")
    end
  end

  defp fix_context_variables(content) do
    content
    # Fix __context references to context
    |> String.replace("__context[:tenant_id]", "context[:tenant_id]")
    |> String.replace("__context[:user_id]", "context[:user_id]")
    |> String.replace("__context[:request_id]", "context[:request_id]")
    |> String.replace("__context[:correlation_id]", "context[:correlation_id]")
    |> String.replace("__context[:device_type]", "context[:device_type]")
    |> String.replace("__context[:firmware_version]", "context[:firmware_version]")
    |> String.replace("__context[:manufacturer]", "context[:manufacturer]")
    |> String.replace("__context[:model]", "context[:model]")
    |> String.replace("__context[:serial_number]", "context[:serial_number]")
    |> String.replace("__context[:credential_type]", "context[:credential_type]")
    |> String.replace("__context[:access_level]", "context[:access_level]")
    |> String.replace("__context[:authorization_level]", "context[:authorization_level]")
    |> String.replace("__context[:security_level]", "context[:security_level]")
    |> String.replace("__context[:", "context[:")
  end

  defp fix_user_variables(content) do
    content
    # Fix __user references (when used, remove underscore)
    |> String.replace("validate__user_access(__user,", "validate__user_access(user,")
    |> String.replace("apply_permission_rules(__user,", "apply_permission_rules(user,")
    |> String.replace("validate_item_access(__user,", "validate_item_access(user,")
    |> String.replace("do_create_access_control(_attrs, tenant_id, __user)", "do_create_access_control(_attrs, tenant_id, user)")
    |> String.replace("do_update_access_control(item, attrs, __user)", "do_update_access_control(item, attrs, user)")
    |> String.replace("do_delete_access_control(item, __user)", "do_delete_access_control(item, user)")
    |> String.replace("__user:", "user:")
    |> String.replace("__userid:", "userid:")
    |> String.replace("__userid,", "userid,")
  end

  defp fix_used_underscored_variables(content) do
    content
    # Fix _attrs when it's actually used
    |> String.replace("do_create_access_control(_attrs,", "do_create_access_control(attrs,")
    # Fix other underscored variables that are used
    |> String.replace("defp validate_user(user), do: {:ok, __user}", "defp validate_user(user), do: {:ok, user}")
  end

  defp fix_unused_variables(content) do
    content
    # Fix unused variables by adding underscore
    |> String.replace("def filter_resources(resources, user, options", "def filter_resources(resources, _user, options")
    |> String.replace("tenantid = extract__tenant_id(context, opts)", "_tenantid = extract__tenant_id(context, opts)")
    |> String.replace("anomaly = ", "_anomaly = ")
  end

  defp count_changes(original, fixed) do
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    original_lines
    |> Enum.zip(fixed_lines)
    |> Enum.count(fn {orig, fix} -> orig != fix end)
  end

  defp analyze_all_variable_issues do
    IO.puts("🔍 Analyzing all variable issues...")

    # Get recent compilation output to analyze patterns
    log_files = Path.wildcard("./data/tmp/*validation*.log")
                |> Enum.sort()
                |> Enum.reverse()
                |> Enum.take(1)

    if length(log_files) > 0 do
      log_file = hd(log_files)
      IO.puts("📋 Analyzing: #{log_file}")

      content = File.read!(log_file)

      context_errors = String.split(content, "\n")
                      |> Enum.filter(&String.contains?(&1, "undefined variable \"__context\""))
                      |> length()

      user_warnings = String.split(content, "\n")
                      |> Enum.filter(&String.contains?(&1, "underscored variable \"__user\" is used"))
                      |> length()

      unused_warnings = String.split(content, "\n")
                        |> Enum.filter(&String.contains?(&1, "is unused"))
                        |> length()

      IO.puts("📊 Variable Issue Analysis:")
      IO.puts("   __context errors: #{context_errors}")
      IO.puts("   __user warnings: #{user_warnings}")
      IO.puts("   Unused variable warnings: #{unused_warnings}")
    else
      IO.puts("📋 No recent compilation logs found")
    end
  end

  defp validate_compilation_success do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    log_file = "./data/tmp/comprehensive_context_validation_#{timestamp}.log"

    # Ensure directory exists
    File.mkdir_p("./data/tmp")

    case System.cmd("mix", ["compile", "--warnings-as-errors"],
                   stderr_to_stdout: true,
                   env: [{"NO_TIMEOUT", "true"}, {"PATIENT_MODE", "enabled"}, {"INFINITE_PATIENCE", "true"}]) do
      {output, 0} ->
        File.write!(log_file, output)
        IO.puts("🏆 ZERO-ERROR VALIDATION CHECKPOINT ACHIEVED!")
        IO.puts("✅ All compilation errors and warnings resolved")
        save_success_report(timestamp)
        true
      {output, _} ->
        File.write!(log_file, output)
        errors = count_errors(output)
        warnings = count_warnings(output)

        IO.puts("📊 Comprehensive Fix Results:")
        IO.puts("   Errors: #{errors}")
        IO.puts("   Warnings: #{warnings}")
        IO.puts("📄 Full compilation log saved: #{log_file}")

        if errors > 0 do
          IO.puts("🔄 Additional fixes needed - #{errors} errors remain")
          show_sample_issues(output, "error")
        end

        if warnings > 0 do
          IO.puts("🔄 #{warnings} warnings remain to be addressed")
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

  defp save_success_report(timestamp) do
    report_path = "./data/tmp/comprehensive_context_success_#{timestamp}.log"

    report = """
    🏆 COMPREHENSIVE CONTEXT VARIABLE FIXES SUCCESSFUL
    ================================================

    Timestamp: #{DateTime.utc_now()}

    📊 RESULTS:
    - Compilation Errors: 0 ✅
    - Compilation Warnings: 0 ✅
    - Zero-Error Validation Checkpoint: ACHIEVED ✅

    🔧 Applied Fixes:
    - Fixed all __context → context variable references
    - Fixed all __user → user variable references when used
    - Fixed all _variable → variable when actually used
    - Fixed all unused variables by adding underscore prefix

    🎯 ULTIMATE SUCCESS: Zero-error validation checkpoint achieved!
    """

    File.write!(report_path, report)
    IO.puts("📄 Success report saved: #{report_path}")
  end

  defp show_help do
    IO.puts("""
    🎯 Comprehensive Context Variable Fixer

    Usage:
      elixir comprehensive_context_variable_fixer.exs [--execute|--analyze]

    Commands:
      --execute    Execute comprehensive variable fixes
      --analyze    Analyze all variable issues in recent logs
    """)
  end
end

ComprehensiveContextVariableFixer.main(System.argv())