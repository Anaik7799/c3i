#!/usr/bin/env elixir

# Final Performance Module Unused Variable Fix with AEE SOPv5.11
# Date: 2025-09-09 15:00:00 CEST
# Framework: Jidoka stop-and-fix with intelligent pattern matching

defmodule FixPerformanceWarningsFinal do
  @moduledoc """
  AGENT FIX: Final comprehensive unused variable correction
  TPS Level: Level 2 (Surface cause fix) with Jidoka
  Strategy: Targeted pattern matching for GenServer callbacks
  """

  def main do
    IO.puts """
    🔧 Final Performance Module Warning Fix
    ==========================================
    Strategy: Intelligent pattern-based fixing
    Method: Jidoka stop-and-fix methodology
    """

    # Get all performance module files
    performance_files = Path.wildcard("lib/indrajaal/performance/*.ex")
    
    IO.puts "Found #{length(performance_files)} performance module files\n"
    
    # Process each file with Jidoka
    results = Enum.map(performance_files, &fix_file/1)
    total_fixed = Enum.sum(results)
    
    IO.puts """
    
    ✅ Fix Complete
    ===============
    Files processed: #{length(performance_files)}
    Total fixes applied: #{total_fixed}
    
    AGENT SUMMARY:
    • Applied targeted fixes for unused parameters
    • Used intelligent pattern matching
    • Followed Jidoka methodology
    • Added agent comments for tracking
    """
  end
  
  defp fix_file(file) do
    IO.puts "📁 Processing #{Path.basename(file)}..."
    
    content = File.read!(file)
    original = content
    fix_count = 0
    
    # Fix handle_call callbacks where 'from' is unused
    fixed = String.replace(content, ~r/def handle_call\(([^,]+),\s*from,\s*__state\)/, fn match ->
      # Check if 'from' is used in the function body
      if String.contains?(content, "from") and not String.contains?(match, "_from") do
        match  # Keep as is if 'from' is used
      else
        # Add underscore if unused
        fix_count = fix_count + 1
        String.replace(match, "from,", "_from,")
      end
    end)
    
    # Fix handle_cast callbacks where '__state' is unused
    fixed = String.replace(fixed, ~r/def handle_cast\([^,]+,\s*__state\)/, fn match ->
      if String.contains?(content, "__state") and not String.contains?(match, "_state") do
        match
      else
        fix_count = fix_count + 1
        String.replace(match, "__state)", "__state)")
      end
    end)
    
    # Fix handle_info callbacks
    fixed = String.replace(fixed, ~r/def handle_info\(([^,]+),\s*__state\)/, fn match ->
      if String.contains?(content, "__state") and not String.contains?(match, "_state") do
        match
      else
        fix_count = fix_count + 1
        String.replace(match, "__state)", "__state)")
      end
    end)
    
    # Fix init callbacks with unused __opts
    fixed = String.replace(fixed, ~r/def init\(__opts\)/, fn match ->
      if String.contains?(content, "__opts") and not String.contains?(match, "_opts") do
        match
      else
        fix_count = fix_count + 1
        "def init(_opts)"
      end
    end)
    
    # Fix unused variables in case __statements
    fixed = String.replace(fixed, ~r/\{:ok,\s*(\w+)\}/, fn match ->
      var = Regex.run(~r/\{:ok,\s*(\w+)\}/, match, capture: :all_but_first)
      if var do
        [var_name] = var
        if String.contains?(content, var_name) and not String.starts_with?(var_name, "_") do
          match
        else
          fix_count = fix_count + 1
          "{:ok, _#{var_name}}"
        end
      else
        match
      end
    end)
    
    if fixed != original do
      # Add agent comment if not present
      fixed = add_agent_comment(fixed, file)
      File.write!(file, fixed)
      IO.puts "  ✅ Applied #{fix_count} fixes"
      fix_count
    else
      IO.puts "  ✔️ No changes needed"
      0
    end
  end
  
  defp add_agent_comment(content, file) do
    if String.contains?(content, "# AGENT FIX:") do
      content
    else
      # Add comment after moduledoc
      String.replace(content, ~r/(@moduledoc\s+"""[\s\S]*?""")/m, fn match ->
        match <> "\n\n  # AGENT FIX: Unused variables fixed (#{DateTime.utc_now() |> DateTime.to_string()})\n  # Framework: AEE SOPv5.11 with Jidoka\n  # TPS Level: Level 2 (Surface cause fix)"
      end)
    end
  end
end

# Execute with Jidoka
FixPerformanceWarningsFinal.main()