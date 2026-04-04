#!/usr/bin/env elixir

defmodule SOPv511.TargetedWarningFixer do
  @moduledoc """
  SOPv5.11 Targeted Warning Fixer
  
  Fixes specific warning patterns found in the codebase:
  1. Unused variables - prefix with underscore
  2. Underscored variables that are used - remove underscore
  3. Systematic approach with git checkpointing
  """
  
  def fix_warnings_with_validation do
    IO.puts """
    ╔════════════════════════════════════════════════════════════════════════╗
    ║   SOPv5.11 TARGETED WARNING FIXER                                     ║
    ╠════════════════════════════════════════════════════════════════════════╣
    ║   🎯 Target: 2,107 remaining warnings                                  ║
    ║   📊 Strategy: Fix unused variables and underscored misuse             ║
    ║   🔧 Method: Pattern-based systematic fixes with validation            ║
    ╚════════════════════════════════════════════════════════════════════════╝
    """
    
    # Create git checkpoint
    IO.puts "\n📸 Creating git checkpoint..."
    System.cmd("git", ["add", "-A"])
    System.cmd("git", ["commit", "-m", "🎯 Checkpoint before targeted warning fixes"])
    
    # Get all Elixir files
    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("lib/**/*.exs")
    total_files = length(files)
    
    IO.puts "📊 Found #{total_files} Elixir files to process"
    
    # Process files in batches
    files
    |> Enum.chunk_every(25)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_num} ->
      IO.puts "\n🔧 Processing batch #{batch_num}/#{ceil(total_files / 25)}..."
      
      fixed_count = Enum.reduce(batch, 0, fn file, acc ->
        changes = fix_warnings_in_file(file)
        acc + changes
      end)
      
      if fixed_count > 0 do
        IO.puts "   ✅ Fixed #{fixed_count} warnings in batch #{batch_num}"
        
        # Test compilation
        IO.puts "   🧪 Testing compilation..."
        {__, _exit_code} = System.cmd("mix", ["compile"], 
          stderr_to_stdout: true,
          env: [{"ELIXIR_ERL_OPTIONS", "+fnu +S 16"}]
        )
        
        if exit_code == 0 do
          # Commit successful batch
          System.cmd("git", ["add", "-A"])
          System.cmd("git", ["commit", "-m", "✅ Fixed batch #{batch_num} - #{fixed_count} warnings"])
          IO.puts "   ✅ Batch #{batch_num} committed"
        else
          # Rollback on failure
          System.cmd("git", ["reset", "--hard", "HEAD"])
          IO.puts "   ❌ Batch #{batch_num} failed - rolled back"
        end
      end
    end)
    
    # Final validation
    IO.puts "\n📊 Running final validation..."
    {_output, __} = System.cmd("mix", ["compile", "--force"], stderr_to_stdout: true)
    final_warnings = length(Regex.scan(~r/warning:/, output))
    
    IO.puts """
    
    ✅ Targeted fixing complete!
    
    📊 Results:
       - Initial warnings: 2,107
       - Final warnings: #{final_warnings}
       - Warnings fixed: #{2107 - final_warnings}
       - Success rate: #{Float.round((2107 - final_warnings) / 2107 * 100, 1)}%
    """
  end
  
  defp fix_warnings_in_file(file_path) do
    content = File.read!(file_path)
    
    # Fix pattern 1: Unused variables in function definitions
    new_content = fix_unused_variables(content)
    
    # Fix pattern 2: Underscored variables that are actually used
    new_content = fix_underscored_misuse(new_content)
    
    # Fix pattern 3: Unused variables in case/with __statements
    new_content = fix_unused_in_case(new_content)
    
    if content != new_content do
      File.write!(file_path, new_content)
      count_changes(content, new_content)
    else
      0
    end
  end
  
  defp fix_unused_variables(content) do
    # Fix unused parameters in function definitions
    content
    |> fix_unused_param("__opts")
    |> fix_unused_param("__params")
    |> fix_unused_param("attrs")
    |> fix_unused_param("__data")
    |> fix_unused_param("config")
    |> fix_unused_param("__state")
    |> fix_unused_param("timeout")
    |> fix_unused_param("coordinates")
    |> fix_unused_param("update_params")
    |> fix_unused_param("behavior_data")
    |> fix_unused_param("ml_metrics")
    |> fix_unused_param("baseline_metrics")
    |> fix_unused_param("current_metrics")
    |> fix_unused_param("performance_data")
    |> fix_unused_param("__data_points")
    |> fix_unused_param("detection_params")
    |> fix_unused_param("historical_data")
  end
  
  defp fix_unused_param(content, param_name) do
    # Pattern for function definitions
    pattern = ~r/(\bdef\w*\s+\w+\([^)]*\b)(#{param_name})\b(?!\s*=)([^)]*\))\s*do(.*?)end/ms
    
    Regex.replace(pattern, content, fn full_match, before, param, after_param, body ->
      # Check if parameter is used in the function body
      if String.contains?(body, param) do
        full_match # Keep as is if used
      else
        # Add underscore if not used
        "#{before}_#{param}#{after_param} do#{body}end"
      end
    end)
  end
  
  defp fix_underscored_misuse(content) do
    # Fix underscored variables that are actually used
    patterns = [
      {"ids", "ids"},
      {"__state", "__state"},
      {"__params", "__params"},
      {"_opts", "__opts"},
      {"_data", "__data"},
      {"_config", "config"}
    ]
    
    Enum.reduce(patterns, content, fn {underscored, normal}, acc ->
      # Only fix if the underscored version is used after assignment
      if Regex.match?(~r/#{Regex.escape(underscored)}\./, acc) ||
         Regex.match?(~r/#{Regex.escape(underscored)}\[/, acc) ||
         Regex.match?(~r/Map\.get\(#{Regex.escape(underscored)}/, acc) do
        String.replace(acc, underscored, normal)
      else
        acc
      end
    end)
  end
  
  defp fix_unused_in_case(content) do
    # Fix unused variables in case __statements
    pattern = ~r/case\s+(.+?)\s+do(.*?)end/ms
    
    Regex.replace(pattern, content, fn full_match, expr, cases ->
      new_cases = Regex.replace(~r/(\s+)(\w+)\s*->/m, cases, fn match, indent, var ->
        # Check if variable is used in its clause
        if String.contains?(cases, var) && !String.starts_with?(var, "_") do
          match
        else
          "#{indent}_#{var} ->"
        end
      end)
      
      "case #{expr} do#{new_cases}end"
    end)
  end
  
  defp count_changes(old_content, new_content) do
    old_lines = String.split(old_content, "\n")
    new_lines = String.split(new_content, "\n")
    
    Enum.zip(old_lines, new_lines)
    |> Enum.count(fn {old, new} -> old != new end)
  end
end

# Execute targeted warning fixes
SOPv511.TargetedWarningFixer.fix_warnings_with_validation()