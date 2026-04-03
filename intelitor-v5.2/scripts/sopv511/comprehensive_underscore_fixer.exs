#!/usr/bin/env elixir
# Comprehensive underscore variable fixer - Batch 2
# Targets remaining 114 errors with precision

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveUnderscoreFixer do
  @moduledoc """
  Fixes the specific pattern where variables are defined with underscore
  but then used without underscore in the function body
  """

  def run(_args \\ []) do
    IO.puts """
    🔧 Comprehensive Underscore Fixer - Batch 2
    ============================================
    Target: Remaining 114 undefined variable errors
    Strategy: Remove underscores from used variables
    """

    # Focus on files with most errors
    priority_files = [
      "lib/indrajaal/access_control/timescale_integration.ex",
      "lib/indrajaal/access_control/compliance_reporter.ex",
      "lib/indrajaal/access_control/domain_hooks.ex",
      "lib/indrajaal/access_control/analytics_engine.ex",
      "lib/indrajaal/access_control/unified_patterns.ex"
    ]

    # Create checkpoint
    System.cmd("git", ["add", "-A"])
    System.cmd("git", ["commit", "-m", "Checkpoint: Before batch 2 underscore fixes"])

    # Fix each file systematically
    Enum.each(priority_files, &fix_underscores_in_file/1)

    # Also scan for other files with the pattern
    find_and_fix_additional_files()

    IO.puts("\n✅ Batch 2 underscore fixes complete!")
  end

  defp fix_underscores_in_file(file) do
    if !File.exists?(file) do
      IO.puts("  ⚠️ File not found: #{file}")
    else
      IO.puts("\n📝 Processing: #{Path.basename(file)}")
      content = File.read!(file)

      # Apply various fix strategies
      fixed_content = content
        |> fix_context_pattern()
        |> fix_opts_pattern()
        |> fix_schedule_config_pattern()
        |> fix_violation_data_pattern()
        |> fix_framework_config_pattern()
        |> fix_other_underscore_patterns()

      if fixed_content != content do
        File.write!(file, fixed_content)
        IO.puts("  ✅ Fixed underscore patterns")
      else
        IO.puts("  ℹ️ No changes needed")
      end
    end
  end

  defp fix_context_pattern(content) do
    # Fix the pattern where _context is defined but context is used
    content
    |> String.replace(~r/\b_context\[:/, "context[:")
    |> fix_function_params("_context", "context")
  end

  defp fix_opts_pattern(content) do
    # Fix the pattern where _opts is defined but opts is used
    content
    |> String.replace(~r/\b_opts\[:/, "opts[:")
    |> fix_function_params("_opts", "opts")
  end

  defp fix_schedule_config_pattern(content) do
    # Fix _schedule_config usage
    content
    |> String.replace("_schedule_config[:", "schedule_config[:")
    |> fix_function_params("_schedule_config", "schedule_config")
  end

  defp fix_violation_data_pattern(content) do
    # Fix _violation_data usage and handle duplicate parameter issue
    content
    |> String.replace("_violation_data.", "violation_data.")
    |> String.replace("_violation_data[:", "violation_data[:")
    # Fix duplicate parameter pattern
    |> String.replace(
      "perform_violation_analysis(_violation_data, _violation_data)",
      "perform_violation_analysis(violation_data, _duplicate_data)"
    )
    |> fix_function_params("_violation_data", "violation_data")
  end

  defp fix_framework_config_pattern(content) do
    # Fix _framework_config usage
    content
    |> String.replace("_framework_config[:", "framework_config[:")
    |> String.replace("_framework_config.", "framework_config.")
    |> fix_function_params("_framework_config", "framework_config")
  end

  defp fix_other_underscore_patterns(content) do
    # Fix other common patterns
    patterns = [
      {"_user_id", "user_id"},
      {"_analysis_type", "analysis_type"},
      {"_eventdata", "eventdata"},
      {"__framework_config", "framework_config"},
      {"__req", "_req"}  # This one should remain with single underscore
    ]

    Enum.reduce(patterns, content, fn {old, new}, acc ->
      fix_function_params(acc, old, new)
    end)
  end

  defp fix_function_params(content, old_param, new_param) do
    lines = String.split(content, "\n")

    Enum.map_reduce(lines, false, fn line, in_function ->
      cond do
        # Start of function definition
        line =~ ~r/^\s*(def|defp)\s+/ ->
          if line =~ ~r/\b#{Regex.escape(old_param)}\b/ do
            # Check if the parameter is actually used in the function
            # For now, we'll fix it if we see it's being referenced
            fixed_line = if should_fix_param?(lines, old_param) do
              String.replace(line, old_param, new_param)
            else
              line
            end
            {fixed_line, true}
          else
            {line, true}
          end

        # End of function (simplistic check)
        in_function && line =~ ~r/^\s*end\s*$/ ->
          {line, false}

        # Inside function body
        in_function ->
          # Don't change references inside the function body here
          # They should match the parameter name
          {line, in_function}

        true ->
          {line, in_function}
      end
    end)
    |> elem(0)
    |> Enum.join("\n")
  end

  defp should_fix_param?(lines, param_name) do
    # Check if the parameter (without underscore) is used in the function body
    bare_name = String.trim_leading(param_name, "_")

    lines
    |> Enum.any?(fn line ->
      # Look for usage of the variable without underscore
      line =~ ~r/\b#{Regex.escape(bare_name)}\[/ ||
      line =~ ~r/\b#{Regex.escape(bare_name)}\./ ||
      line =~ ~r/\|\|\s*#{Regex.escape(bare_name)}\b/
    end)
  end

  defp find_and_fix_additional_files do
    IO.puts("\n🔍 Scanning for additional files with underscore issues...")

    # Find files with potential underscore issues
    {output, 0} = System.cmd("grep", [
      "-r",
      "-l",
      "_context\\|_opts\\|_schedule_config\\|_violation_data",
      "lib/indrajaal/",
      "--include=*.ex"
    ], stderr_to_stdout: true)

    files = output
      |> String.split("\n")
      |> Enum.filter(&(&1 != ""))
      |> Enum.reject(&already_processed?/1)

    if length(files) > 0 do
      IO.puts("  Found #{length(files)} additional files")
      Enum.each(files, &fix_underscores_in_file/1)
    else
      IO.puts("  No additional files found")
    end
  end

  defp already_processed?(file) do
    priority = [
      "timescale_integration.ex",
      "compliance_reporter.ex",
      "domain_hooks.ex",
      "analytics_engine.ex",
      "unified_patterns.ex"
    ]

    Enum.any?(priority, &String.ends_with?(file, &1))
  end
end

# Run the fixer
ComprehensiveUnderscoreFixer.run()