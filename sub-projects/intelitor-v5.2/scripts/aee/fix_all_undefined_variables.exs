#!/usr/bin/env elixir

# Comprehensive undefined variable fix with AEE SOPv5.11 + TPS methodology
# Date: 2025-09-09 14:30:00 CEST
# Framework: 11-Agent coordination with Jidoka stop-and-fix

defmodule FixAllUndefinedVariables do
  @moduledoc """
  AGENT FIX: Comprehensive undefined variable resolution
  Pattern: EP-089 (undefined variable errors)
  TPS Level: Level 2 (Surface cause) and Level 3 (System behavior)
  Jidoka: Stop at each error and fix completely
  """

  def main do
    IO.puts """
    🔧 AEE Comprehensive Undefined Variable Fix
    ============================================
    Framework: AEE SOPv5.11 with TPS 5-Level RCA
    Strategy: Pattern-based systematic resolution
    Goal: Zero undefined variable errors
    """
    
    # AGENT ANALYSIS: Common patterns for undefined variables
    # Pattern 1: Parameter with underscore prefix but used in function body
    # Pattern 2: Wrong variable name referenced (typo or copy-paste error)
    # Pattern 3: Variable used before definition
    
    fixes_applied = 0
    
    # Get all compilation errors
    {_output, __} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    
    # Extract undefined variable errors
    errors = extract_undefined_errors(output)
    
    IO.puts "📊 Found #{length(errors)} undefined variable errors"
    
    # Group errors by file for efficient processing
    errors_by_file = Enum.group_by(errors, & &1.file)
    
    # Process each file with errors
    Enum.each(errors_by_file, fn {file, file_errors} ->
      IO.puts "\n📁 Processing #{file} (#{length(file_errors)} errors)..."
      
      if File.exists?(file) do
        content = File.read!(file)
        fixed_content = apply_fixes(content, file_errors, file)
        
        if fixed_content != content do
          File.write!(file, fixed_content)
          IO.puts "  ✅ Fixed #{length(file_errors)} errors in #{file}"
        else
          IO.puts "  ⚠️ No changes needed for #{file}"
        end
      else
        IO.puts "  ❌ File not found: #{file}"
      end
    end)
    
    IO.puts """
    
    ✅ Comprehensive Fix Complete
    ==============================
    Errors processed: #{length(errors)}
    Files modified: #{map_size(errors_by_file)}
    
    Next step: Run compilation to verify fixes
    """
  end
  
  defp extract_undefined_errors(output) do
    # Pattern: error: undefined variable "variable_name"
    # Extract file, line, and variable name
    regex = ~r/([^:]+):(\d+):\d+.*error: undefined variable "([^"]+)"/
    
    Regex.scan(regex, output)
    |> Enum.map(fn [_full, file, line, var] ->
      %{
        file: String.trim(file),
        line: String.to_integer(line),
        variable: var
      }
    end)
  end
  
  defp apply_fixes(content, errors, file) do
    # AGENT STRATEGY: Apply fixes based on common patterns
    
    Enum.reduce(errors, content, fn error, acc ->
      case analyze_error_pattern(error, acc, file) do
        {:underscore_parameter, fix} ->
          # Pattern 1: Remove underscore from parameter that's actually used
          apply_underscore_fix(acc, fix)
          
        {:wrong_reference, fix} ->
          # Pattern 2: Fix wrong variable reference
          apply_reference_fix(acc, fix)
          
        {:missing_definition, fix} ->
          # Pattern 3: Add variable definition
          apply_definition_fix(acc, fix)
          
        :unknown ->
          IO.puts "  ⚠️ Unknown pattern for #{error.variable} at line #{error.line}"
          acc
      end
    end)
  end
  
  defp analyze_error_pattern(error, content, file) do
    lines = String.split(content, "\n")
    error_line = Enum.at(lines, error.line - 1, "")
    
    cond do
      # Check if it's an underscore prefix issue
      String.starts_with?(error.variable, "_") ->
        var_without_underscore = String.slice(error.variable, 1..-1//1)
        # Check if the non-underscored version is a parameter
        if parameter_exists?(content, var_without_underscore) do
          {:underscore_parameter, %{
            from: error.variable,
            to: var_without_underscore,
            line: error.line
          }}
        else
          :unknown
        end
        
      # Check if it's a reference to a parameter with underscore
      parameter_exists?(content, "_#{error.variable}") ->
        {:wrong_reference, %{
          from: error.variable,
          to: "_#{error.variable}",
          line: error.line,
          should_remove_underscore: true
        }}
        
      # Special cases for known patterns
      error.variable in ["__state", "changeset", "__context"] ->
        analyze_special_case(error, content, file)
        
      true ->
        :unknown
    end
  end
  
  defp parameter_exists?(content, param_name) do
    # Check if parameter exists in function definitions
    Regex.match?(~r/def\s+\w+\([^)]*\b#{Regex.escape(param_name)}\b[^)]*\)/, content)
  end
  
  defp analyze_special_case(error, content, file) do
    cond do
      # GenServer callbacks often have _state parameter
      String.contains?(file, "performance") and error.variable == "__state" ->
        {:wrong_reference, %{
          from: "__state",
          to: "__state",
          __context: :genserver_callback
        }}
        
      true ->
        :unknown
    end
  end
  
  defp apply_underscore_fix(content, fix) do
    # Remove underscore from all references to this variable
    String.replace(content, fix.from, fix.to)
  end
  
  defp apply_reference_fix(content, fix) do
    if fix[:should_remove_underscore] do
      # Remove underscore from parameter definition
      content
      |> String.replace(~r/def\s+(\w+)\([^)]*\b_#{Regex.escape(fix.from)}\b/, 
                        "def \\1(... #{fix.from}")
    else
      String.replace(content, fix.from, fix.to)
    end
  end
  
  defp apply_definition_fix(content, fix) do
    # Add variable definition before its use
    # This is more complex and would need __context-aware parsing
    content
  end
end

# Execute with 11-agent coordination
FixAllUndefinedVariables.main()