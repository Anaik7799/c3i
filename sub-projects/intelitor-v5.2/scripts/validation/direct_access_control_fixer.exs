#!/usr/bin/env elixir

defmodule DirectAccessControlFixer do
  @moduledoc """
  Direct fix for access_control domain compilation errors
  Based on 1-compile.log analysis - 420 errors, 261 warnings
  """

  def run do
    IO.puts("🔧 Direct Access Control Error Fixing")
    IO.puts("🎯 Target: Fix undefined variable errors in domain_hooks.ex")

    # Create git checkpoint before changes
    create_git_checkpoint("before-direct-access-control-fixes", "Before direct access control fixes")

    # Fix the specific files with errors
    fix_domain_hooks_errors()

    # Create checkpoint after changes
    create_git_checkpoint("after-direct-access-control-fixes", "Applied direct access control fixes")

    # Validate changes
    validate_compilation()
  end

  defp fix_domain_hooks_errors do
    file_path = "lib/indrajaal/access_control/domain_hooks.ex"
    IO.puts("  📝 Fixing: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = content
        |> fix_parameter_name_inconsistency()
        |> fix_undefined_variables()

        File.write!(file_path, fixed_content)
        IO.puts("    ✅ Applied fixes to domain_hooks.ex")

      {:error, reason} ->
        IO.puts("    ❌ Error reading file: #{reason}")
    end
  end

  defp fix_parameter_name_inconsistency(content) do
    content
    # Fix: analyze_policy_change function parameter name mismatch
    |> String.replace(
      "defp analyze_policy_change(accessrule, event_type, context) do",
      "defp analyze_policy_change(access_rule, event_type, context) do"
    )
    # Fix: enrich_access_rule_context function parameter name mismatch
    |> String.replace(
      "defp enrich_access_rule_context(accessrule, context) do",
      "defp enrich_access_rule_context(access_rule, context) do"
    )
  end

  defp fix_undefined_variables(content) do
    content
    # Fix analyze_privilege_escalation function - add missing parameter
    |> String.replace(
      ~r/defp analyze_privilege_escalation\(([^,]+), ([^)]+)\) do\s*\n\s*%\{\s*from_level: [^,]+,\s*to_level: access_grant\.permission_level,\s*granted_by: access_grant\.granted_by_id,/m,
      "defp analyze_privilege_escalation(access_grant, context) do\n    %{\n      from_level: __context[:previous_level] || :none,\n      to_level: access_grant.permission_level,\n      granted_by: access_grant.granted_by_id,"
    )
    # Fix broadcast_event function parameters
    |> String.replace(
      ~r/defp broadcast_event\(([^,]+), ([^,]+), ([^)]+)\) do\s*\n\s*__event_message = \{__event_type, __event_data, __context\}/m,
      "defp broadcast_event(event_type, __event_data, context) do\n    __event_message = {__event_type, __event_data, __context}"
    )
    # Fix undefined __opts variable in time range functions
    |> String.replace(
      "time_range = __opts[:time_range] || @default_time_window",
      "time_range = _opts[:time_range] || @default_time_window"
    )
    # Add missing __opts parameter to functions that need it
    |> String.replace(
      ~r/defp ([a-z_]+)\(([^)]*)\) do\s*\n\s*time_range = _opts/m,
      "defp \\1(\\2, _opts \\\\ []) do\n    time_range = _opts"
    )
  end

  defp create_git_checkpoint(tag, message) do
    IO.puts("📋 Creating git checkpoint: #{tag}")
    {_, 0} = System.cmd("git", ["add", "-A"])
    {_, 0} = System.cmd("git", ["commit", "-m", "#{message}\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"])
    {_, 0} = System.cmd("git", ["tag", tag])
  end

  defp validate_compilation do
    IO.puts("🔍 Validating compilation after fixes...")

    case System.cmd("mix", ["compile"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("✅ Compilation successful!")
      {output, _} ->
        error_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error:"))
        warning_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))
        IO.puts("📊 Remaining: #{error_count} errors, #{warning_count} warnings")

        if error_count < 420 do
          IO.puts("✅ Progress made: Reduced from 420 errors")
        end

        # Save compilation output for analysis
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
        File.write!("./__data/tmp/post_fix_compile_#{timestamp}.log", output)
        IO.puts("📄 Saved compilation log: ./__data/tmp/post_fix_compile_#{timestamp}.log")
    end
  end
end

DirectAccessControlFixer.run()