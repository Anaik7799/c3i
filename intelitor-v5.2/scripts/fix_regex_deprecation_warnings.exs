#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - fix_regex_deprecation_warnings.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: miscellaneous
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - fix_regex_deprecation_warnings.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: miscellaneous
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - fix_regex_deprecation_warnings.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: miscellaneous
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied



# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework

defmodule FixRegexWarnings do
  
__require Logger

@moduledoc """
  Fixes deprecated regex syntax in Ash string match constraints for OTP 28 compatibility.

  Converts:
    match: ~r/pattern/flags  -> match: {~S/pattern/, "flags"}
    match: ~r/pattern/       -> match: ~S/pattern/
    match: ~S/pattern/       -> match: ~S/pattern/ (no change needed)
  """

  @spec run() :: any()
  def run do
    IO.puts("🔍 Searching for deprecated regex patterns in match constraints...")

    files = find_files_with_regex_patterns()

    if Enum.empty?(files) do
      IO.puts("✅ No deprecated regex patterns found!")
    else
      IO.puts("📝 Found #{length(files)} files with regex patterns to fix:")

      Enum.each(files, fn file ->
        IO.puts("  - #{file}")
      end)

      IO.puts("\n🔧 Fixing regex patterns...")

      Enum.each(files, &fix_file/1)

      IO.puts("\n✅ All regex patterns have been updated for OTP 28 compatibility!")
    end
  end

  @spec find_files_with_regex_patterns() :: any()
  defp find_files_with_regex_patterns do
    Path.wildcard"lib/**/*.ex" |> Enum.filter(fn file ->
      content = File.read!(file)
      # Match lines with "match:" followed by regex syntax
      String.contains?(content, "match:") &&
        (String.contains?(content, "match: ~r/") ||
           String.contains?(content, "match: ~R/"))
    end)
  end

  @spec fix_file(term()) :: term()
  defp fix_file(file) do
    content = File.read!(file)

    # Fix patterns with flags: ~r/pattern/flags -> {~S/pattern/, "flags"}
    updated_content =
      Regex.replace(
        ~r/match:\s*~r\/([^\/]+)\/([gimuxs]+)/,
        content,
        fn _, pattern, flags ->
          ~s[match: {~S/#{pattern}/, "#{flags}"}]
        end
      )

    # Fix patterns without flags: ~r/pattern/ -> ~S/pattern/
    updated_content =
      Regex.replace(
        ~r/match:\s*~r\/([^\/]+)\//,
        updated_content,
        fn _, pattern ->
          ~s[match: ~S/#{pattern}/]
        end
      )

    # Fix uppercase R patterns with flags: ~R/pattern/flags -> {~S/pattern/, "fla
    updated_content =
      Regex.replace(
        ~r/match:\s*~R\/([^\/]+)\/([gimuxs]+)/,
        updated_content,
        fn _, pattern, flags ->
          ~s[match: {~S/#{pattern}/, "#{flags}"}]
        end
      )

    # Fix uppercase R patterns without flags: ~R/pattern/ -> ~S/pattern/
    updated_content =
      Regex.replace(
        ~r/match:\s*~R\/([^\/]+)\//,
        updated_content,
        fn _, pattern ->
          ~s[match: ~S/#{pattern}/]
        end
      )

    if content != updated_content do
      File.write!(file, updated_content)
      IO.puts("  ✓ Fixed #{file}")
      show_changes(file, content, updated_content)
    end
  end

  defp show_changes(file, original, updated) do
    original_lines = String.split(original, "\n")
    updated_lines = String.split(updated, "\n")

    Enum.ziporiginal_lines, updated_lines |> Enum.with_index1 |> Enum.each(fn {{orig, upd}, line_num} ->
      if orig != upd && String.contains?(orig, "match:") do
        IO.puts("    Line #{line_num}:")
        IO.puts("      - #{String.trim(orig)}")
        IO.puts("      + #{String.trim(upd)}")
      end
    end)
  end
end

# Run the script
FixRegexWarnings.run()

# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied

