#!/usr/bin/env elixir

# AGENT GA PHASE 14: Comprehensive audit_logger.ex fixes
# AEE SOPv5.11 + PHICS + TPS + GDE + TDG + FPPS + 11-Agent Architecture
# JIDOKA: Stop-and-fix all compilation errors systematically

IO.puts """
================================================================================
🚨 AEE SOPv5.11 GA PHASE 14: COMPREHENSIVE AUDIT LOGGER FIX
================================================================================
Target: Fix ALL syntax errors in audit_logger.ex
Issue: Multiple missing function definitions
Strategy: Scan entire file and fix all similar patterns
================================================================================
"""

defmodule GAPhase14ComprehensiveAuditFix do
  @moduledoc """
  AGENT GA PHASE 14: Comprehensive fix for all audit_logger.ex issues
  TPS 5-Level RCA: STUB code generation created invalid function signatures
  """

  def fix_all_audit_issues do
    IO.puts "\n📋 PHASE 14.1: Scanning and fixing ALL audit_logger.ex issues..."
    
    file_path = "lib/indrajaal/security/audit_logger.ex"
    
    if File.exists?(file_path) do
      content = File.read!(file_path)
      
      # Pattern: floating parameter with closing ) do but no function definition
      # We need to find these patterns and add proper function definitions
      
      # Fix pattern 1: log_data_modification (line 148-149)
      fixed_content = content
        |> String.replace(
          ~r/@spec log_data_modification\(String\.t\(\), any\(\), atom\(\), map\(\), map\(\), map\(\)\) :: :ok\n  __context \\\\ %\{\}\n      \) do/,
          "@spec log_data_modification(String.t(), any(), atom(), map(), map(), map()) :: :ok\n  def log_data_modification(user_id, resource, action, before_data, after_data, context \\\\ %{}) do  # AGENT GA PHASE 14 FIX"
        )
      
      # Search for any other similar patterns
      lines = String.split(fixed_content, "\n")
      fixed_lines = []
      i = 0
      
      while i < length(lines) do
        line = Enum.at(lines, i)
        
        # Check if this line has a floating parameter pattern
        if String.contains?(line, " \\\\ %{}") && !String.contains?(line, "def ") do
          # This might be a floating parameter
          next_line = if i + 1 < length(lines), do: Enum.at(lines, i + 1), else: ""
          
          if String.trim(next_line) == ") do" do
            # Found the pattern! Need to construct function definition
            # Look back to find the @spec to understand the function
            spec_line_idx = find_spec_before(lines, i)
            
            if spec_line_idx do
              spec_line = Enum.at(lines, spec_line_idx)
              func_name = extract_function_name(spec_line)
              
              if func_name do
                # Replace the floating parameter with a proper function definition
                IO.puts "  ✓ Fixing function: #{func_name} at line #{i + 1}"
                fixed_line = construct_function_def(func_name, line)
                fixed_lines = fixed_lines ++ [fixed_line]
                i = i + 1  # Skip the ") do" line as it's now part of the function def
              else
                fixed_lines = fixed_lines ++ [line]
              end
            else
              fixed_lines = fixed_lines ++ [line]
            end
          else
            fixed_lines = fixed_lines ++ [line]
          end
        else
          fixed_lines = fixed_lines ++ [line]
        end
        
        i = i + 1
      end
      
      # Final comprehensive replacement
      final_content = Enum.join(fixed_lines, "\n")
      
      # Additional safety check - make sure all floating parameters are fixed
      if String.contains?(final_content, ~r/^\s+\w+ \\\\ %\{\}\s*$/m) do
        IO.puts "  ⚠️  Warning: Some floating parameters may still exist"
      end
      
      File.write!(file_path, final_content)
      IO.puts "  ✓ Comprehensive fixes applied to audit_logger.ex"
    else
      IO.puts "  ⚠️  File not found: #{file_path}"
    end
  end
  
  defp find_spec_before(lines, index) do
    # Search backwards for @spec
    Enum.find_index(Enum.slice(lines, 0..index) |> Enum.reverse(), fn line ->
      String.contains?(line, "@spec ")
    end)
    |> case do
      nil -> nil
      idx -> index - idx
    end
  end
  
  defp extract_function_name(spec_line) do
    case Regex.run(~r/@spec\s+(\w+)\(/, spec_line) do
      [_, name] -> name
      _ -> nil
    end
  end
  
  defp construct_function_def(func_name, param_line) do
    param = String.trim(param_line)
    
    # Common function signatures based on the pattern
    case func_name do
      "log_data_export" ->
        "  def log_data_export(user_id, export_type, record_count, destination, #{param}) do  # AGENT GA PHASE 14 FIX"
      "log_policy_violation" ->
        "  def log_policy_violation(user_id, policy_type, violation, #{param}) do  # AGENT GA PHASE 14 FIX"
      _ ->
        # Generic fallback
        "  def #{func_name}(__user_id, operation, __data, #{param}) do  # AGENT GA PHASE 14 FIX"
    end
  end
end

# For now, let's do a simpler direct fix
defmodule SimpleAuditFix do
  def apply_simple_fix do
    file_path = "lib/indrajaal/security/audit_logger.ex"
    content = File.read!(file_path)
    
    # Fix the known issue at line 148-149
    fixed = content
      |> String.replace(
        "  @spec log_data_modification(String.t(), any(), atom(), map(), map(), map()) :: :ok\n  __context \\\\ %{}\n      ) do",
        "  @spec log_data_modification(String.t(), any(), atom(), map(), map(), map()) :: :ok\n  def log_data_modification(user_id, resource, action, before_data, after_data, context \\\\ %{}) do  # AGENT GA PHASE 14"
      )
    
    File.write!(file_path, fixed)
    IO.puts "  ✓ Applied targeted fix to log_data_modification"
  end
end

# Execute the simple fix first
SimpleAuditFix.apply_simple_fix()

IO.puts """

================================================================================
🎯 PHASE 14 COMPLETE - CONTINUING GA READINESS  
================================================================================
Fixed: Missing function definition for log_data_modification
Strategy: Added proper function signature with all parameters
Next: Continue compilation to identify remaining issues
================================================================================
"""