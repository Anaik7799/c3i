#!/usr/bin/env elixir

defmodule SurgicalAccessControlFixer do
  @moduledoc """
  Surgical precision fixer for access_control_context.ex
  Targets only the specific parameter/variable inconsistencies
  """

  def run do
    IO.puts("🔧 Surgical Access Control Context Fixing")
    IO.puts("🎯 Target: Fix parameter/variable inconsistencies with surgical precision")

    # Create git checkpoint before changes
    create_git_checkpoint("before-surgical-access-control-fixes", "Before surgical access control fixes")

    # Fix the specific file with surgical precision
    fix_access_control_context_surgical()

    # Create checkpoint after changes
    create_git_checkpoint("after-surgical-access-control-fixes", "Applied surgical access control fixes")

    # Validate changes
    validate_compilation()
  end

  defp fix_access_control_context_surgical do
    file_path = "lib/indrajaal/access_control_context.ex"
    IO.puts("  📝 Surgical fixing: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = content
        |> fix_underscore_variable_usage()
        |> fix_function_parameter_consistency()

        File.write!(file_path, fixed_content)
        IO.puts("    ✅ Applied surgical fixes to access_control_context.ex")

      {:error, reason} ->
        IO.puts("    ❌ Error reading file: #{reason}")
    end
  end

  defp fix_underscore_variable_usage(content) do
    content
    # Fix: the underscored variable "_tenant_id" is used after being set
    # Line 90: __tenant_id: _tenant_id, -> __tenant_id: __tenant_id,
    |> String.replace("__tenant_id: _tenant_id,", "__tenant_id: __tenant_id,")

    # Fix: the underscored variable "_user" is used after being set
    # Line 246: created_by_id: _user.id, -> created_by_id: __user.id,
    |> String.replace("created_by_id: _user.id,", "created_by_id: __user.id,")
    # Line 259: updated_by_id: _user.id, -> updated_by_id: __user.id,
    |> String.replace("updated_by_id: _user.id,", "updated_by_id: __user.id,")
  end

  defp fix_function_parameter_consistency(content) do
    content
    # Fix function parameter consistency - remove underscore from parameters that are used
    # defp do_create_access_control(_attrs, _tenant_id, _user) -> defp do_create_access_control(_attrs, __tenant_id, __user)
    |> String.replace("defp do_create_access_control(_attrs, _tenant_id, _user)", "defp do_create_access_control(_attrs, __tenant_id, __user)")

    # defp do_update_access_control(item, attrs, _user) -> defp do_update_access_control(item, attrs, __user)
    |> String.replace("defp do_update_access_control(item, attrs, _user)", "defp do_update_access_control(item, attrs, __user)")

    # defp do_delete_access_control(item, _user) -> defp do_delete_access_control(item, __user) [if __user is used]
    # Check __context first - seems __user is not used in this function, so keep underscore

    # Fix function calls to match the corrected parameters
    |> String.replace("do_create_access_control(_attrs, _tenant_id, __user)", "do_create_access_control(_attrs, __tenant_id, __user)")

    # Fix unused variable declarations that should have underscore
    # __tenant_id = Keyword.get(__opts, :__tenant_id) where __tenant_id is not used -> _tenant_id = ...
    |> fix_unused_tenant_id_declarations()
  end

  defp fix_unused_tenant_id_declarations(content) do
    # This is tricky - need to identify which __tenant_id declarations are actually unused
    # Based on error analysis, some __tenant_id vars are declared but not used
    content
    # If __tenant_id is extracted but not used in the function, prefix with underscore
    |> String.replace(~r/(\s+)__tenant_id = Keyword\.get\(__opts, :__tenant_id\)\s*\n(\s+)with/m,
      "\\1_tenant_id = Keyword.get(__opts, :__tenant_id)\n\\2with")
  end

  defp create_git_checkpoint(tag, message) do
    IO.puts("📋 Creating git checkpoint: #{tag}")
    {_, 0} = System.cmd("git", ["add", "-A"])
    {_, 0} = System.cmd("git", ["commit", "-m", "#{message}\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"])
    {_, 0} = System.cmd("git", ["tag", tag])
  end

  defp validate_compilation do
    IO.puts("🔍 Validating compilation after surgical fixes...")

    case System.cmd("mix", ["compile"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("✅ Compilation successful!")
      {output, _} ->
        error_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error:"))
        warning_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning:"))
        IO.puts("📊 Remaining: #{error_count} errors, #{warning_count} warnings")

        if error_count < 168 do
          IO.puts("✅ Progress made: Reduced from 168 errors")
        end

        # Save compilation output for analysis
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
        File.write!("./__data/tmp/surgical_fix_compile_#{timestamp}.log", output)
        IO.puts("📄 Saved compilation log: ./__data/tmp/surgical_fix_compile_#{timestamp}.log")
    end
  end
end

SurgicalAccessControlFixer.run()