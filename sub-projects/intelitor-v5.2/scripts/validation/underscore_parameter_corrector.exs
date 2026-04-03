#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule UnderscoreParameterCorrector do
  @moduledoc """
  🚨 CRITICAL: Fix underscore parameter overuse from warning elimination system

  The warning elimination system added underscores to variables that are actually used,
  causing new warnings. This fixes the systematic overuse of underscore prefixes.
  """

  def main(args \\ []) do
    IO.puts("🔧 SYSTEMATIC: Correcting underscore parameter overuse")

    case Enum.at(args, 0) do
      "--execute" -> execute_corrections()
      "--analyze" -> analyze_underscore_issues()
      _ -> show_help()
    end
  end

  defp execute_corrections do
    IO.puts("🔧 Scanning all Elixir files for underscore overuse...")

    files = find_elixir_files()
    _fixed_files = 0
    _total_fixes = 0

    {_fixed_files, _total_fixes} = Enum.reduce(files, {0, 0}, fn file, {acc_fixed, acc_total} ->
      case fix_underscore_overuse_in_file(file) do
        {true, fixes} ->
          IO.puts("✅ Fixed: #{Path.basename(file)} (#{fixes} corrections)")
          {acc_fixed + 1, acc_total + fixes}
        {false, 0} ->
          {acc_fixed, acc_total}
      end
    end)

    IO.puts("\n📊 Underscore Correction Results:")
    IO.puts("   Files scanned: #{length(files)}")
    IO.puts("   Files fixed: #{fixed_files}")
    IO.puts("   Total corrections: #{total_fixes}")

    # Validate compilation after fixes
    IO.puts("\n🎯 Validating compilation after underscore corrections...")
    validate_compilation()
  end

  defp analyze_underscore_issues do
    IO.puts("🔍 Analyzing underscore parameter issues...")

    files = find_elixir_files()

    Enum.each(files, fn file ->
      content = File.read!(file)

      # Look for patterns where underscored variables are used
      used_underscored = Regex.scan(~r/the underscored variable \"([^\"]+)\" is used/, content)

      if length(used_underscored) > 0 do
        IO.puts("📄 #{file}:")
        Enum.each(used_underscored, fn [_, var] ->
          IO.puts("   Used underscored variable: #{var}")
        end)
      end
    end)
  end

  defp fix_underscore_overuse_in_file(file_path) do
    try do
      content = File.read!(file_path)
      original_content = content

      # Apply systematic corrections for overused underscores
      fixed_content = content
      |> fix_used_underscored_variables()
      |> fix_parameter_patterns()
      |> fix_function_signatures()

      if fixed_content != original_content do
        File.write!(file_path, fixed_content)
        fixes_count = count_differences(original_content, fixed_content)
        {true, fixes_count}
      else
        {false, 0}
      end
    rescue
      e ->
        IO.puts("⚠️  Error processing #{file_path}: #{inspect(e)}")
        {false, 0}
    end
  end

  defp fix_used_underscored_variables(content) do
    # Fix common patterns where variables are used but have underscores
    content
    |> String.replace(~r/\b__user\b(?=\s*[,\)\]])/, "user")
    |> String.replace(~r/\b__opts\b(?=\s*[,\)\]])/, "opts")
    |> String.replace(~r/\b__context\b(?=\s*[,\)\]])/, "context")
    |> String.replace(~r/\b__data\b(?=\s*[,\)\]])/, "data")
    |> String.replace(~r/\b__params\b(?=\s*[,\)\]])/, "params")
    |> String.replace(~r/\b__state\b(?=\s*[,\)\]])/, "state")
    |> String.replace(~r/\b__event\b(?=\s*[,\)\]])/, "event")
    |> String.replace(~r/\b__req\b(?=\s*[,\)\]])/, "req")
    |> String.replace(~r/\b__tenant_id\b(?=\s*[,\)\]])/, "tenant_id")
    |> String.replace(~r/\b__event_context\b(?=\s*[,\)\]])/, "event__context")
  end

  defp fix_parameter_patterns(content) do
    # Fix function parameter patterns where variables are actually used
    content
    |> String.replace("validate_user_access(__user,", "validate__user_access(__user,")
    |> String.replace("validate_item_access(__user,", "validate_item_access(__user,")
    |> String.replace("validate_create_attrs(_attrs, __req)", "validate_create_attrs(_attrs, req)")
    |> String.replace("determine_access_level(validated_params, __context)", "determine_access_level(validated__params, context)")
    |> String.replace("enforce_access_policy(access_level, __context)", "enforce_access_policy(access_level, context)")
    |> String.replace("enrich_access_log_context(access_log, __context)", "enrich_access_log__context(access_log, context)")
    |> String.replace("broadcast_event(:access_log_created, access_log, __event_context)", "broadcast__event(:access_log_created, access_log, event__context)")
  end

  defp fix_function_signatures(content) do
    # Fix function signatures that have been over-underscored
    content
    |> String.replace("defp validate_user_access(_user,", "defp validate__user_access(__user,")
    |> String.replace("defp validate_item_access(_user,", "defp validate_item_access(__user,")
    |> String.replace("defp validate_create_attrs(_attrs, _req)", "defp validate_create_attrs(_attrs, req)")
    |> String.replace("_tenant_id = Keyword.get(__opts", "tenant_id = Keyword.get(opts")
    |> String.replace("__event_context =", "event__context =")
  end

  defp find_elixir_files do
    ["lib/**/*.ex", "test/**/*.exs"]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.filter(&File.exists?/1)
  end

  defp count_differences(original, fixed) do
    original_lines = String.split(original, "\n")
    fixed_lines = String.split(fixed, "\n")

    original_lines
    |> Enum.zip(fixed_lines)
    |> Enum.count(fn {orig, fixed} -> orig != fixed end)
  end

  defp validate_compilation do
    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("🏆 SUCCESS: Compilation successful after underscore corrections!")
        true
      {output, _} ->
        IO.puts("❌ Compilation still has issues:")

        # Count errors and warnings
        errors = count_pattern(output, ["error:", "** ("])
        warnings = count_pattern(output, ["warning:"])

        IO.puts("   Errors: #{errors}")
        IO.puts("   Warnings: #{warnings}")

        # Save the output for analysis
        timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
        log_path = "./data/tmp/underscore_fix_compilation_#{timestamp}.log"
        File.write!(log_path, output)
        IO.puts("📄 Compilation log saved: #{log_path}")

        false
    end
  end

  defp count_pattern(text, patterns) do
    text
    |> String.split("\n")
    |> Enum.count(fn line ->
      Enum.any?(patterns, &String.contains?(line, &1))
    end)
  end

  defp show_help do
    IO.puts("""
    🔧 Underscore Parameter Corrector

    Usage:
      elixir underscore_parameter_corrector.exs [--execute|--analyze]

    Commands:
      --execute    Fix underscore parameter overuse issues
      --analyze    Analyze underscore issues in codebase
    """)
  end
end

UnderscoreParameterCorrector.main(System.argv())