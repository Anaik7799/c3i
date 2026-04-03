#!/usr/bin/env elixir

defmodule STAMPValidator do
  @moduledoc "STAMP methodology validation for git operations"

  @spec validate_safety_constraints(any()) :: any()
  def validate_safety_constraints(changed_files) do
    IO.puts("🛡️ Validating STAMP safety constraints...")

    # Check for unsafe control actions in changed files
    safety_violations = check_unsafe_control_actions(changed_files)

    if length(safety_violations) == 0 do
      IO.puts("  ✅ No safety constraint violations detected")
      true
    else
      IO.puts("  ❌ Safety constraint violations detected:")
      Enum.each(safety_violations, fn violation ->
        IO.puts("-#{violation}")
      end)
      false
    end
  end

  @spec check_unsafe_control_actions(term()) :: term()
  defp check_unsafe_control_actions(files) do
    # Implementation would check for:
    # - Direct __database modifications without safety checks
    # - Authentication bypasses
    # - Authorization vulnerabilities
    # - Data validation bypasses
    # - Resource limit bypasses

    Enum.reduce(files, [], fn file, violations ->
      if String.ends_with?(file, [".ex", ".exs"]) and File.exists?(file) do
        content = File.read!(file)

        # Check for dangerous patterns
        if String.contains?(content, ["Repo.delete_all", "raw query", "unsafe"]) do
          violations ++ ["Potentially unsafe __database operation in #{file}"]
        else
          violations
        end
      else
        violations
      end
    end)
  end

  @spec perform_stpa_check(any()) :: any()
  def perform_stpa_check(feature_description) do
    IO.puts("🔍 Performing STPA analysis check...")

    # Check if STPA analysis exists for critical features
    critical_keywords = ["auth", "security", "__database", "payment", "admin"]

    is_critical = Enum.any?(critical_keywords, fn keyword ->
      String.contains?(String.downcase(feature_description), keyword)
    end)

    if is_critical do
      stpa_file = "docs/stamp/stpa_#{String.replace(feature_description, " ", "_"

      if File.exists?(stpa_file) do
        IO.puts("  ✅ STPA analysis found: #{stpa_file}")
        true
      else
        IO.puts("  ⚠️  Critical feature __requires STPA analysis: #{stpa_file}")
        false
      end
    else
      IO.puts("  ✅ Non-critical feature, STPA analysis not __required")
      true
    end
  end
end
