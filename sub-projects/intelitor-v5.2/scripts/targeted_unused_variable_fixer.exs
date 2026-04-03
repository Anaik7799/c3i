#!/usr/bin/env elixir

defmodule TargetedUnusedVariableFixer do
  @moduledoc """
  Targeted fixer for specific unused variable warnings identified from compilation.
  
  Based on the compilation warnings, this fixes specific instances of unused variables
  by adding underscore prefixes where variables are genuinely not being used.
  """

  def run do
    IO.puts("🔧 Starting targeted unused variable fixes...")
    
    # Specific fixes based on compilation warnings seen
    fixes = [
      # From compilation analysis - common unused variable patterns
      {~r/def\s+(\w+)\([^)]*,\s*__opts\s*\)\s*do\s*\n(?:(?!\b__opts\b).)*?end/s, "__opts", "_opts"},
      {~r/def\s+(\w+)\([^)]*,\s*device_id\s*\)\s*do\s*\n(?:(?!\bdevice_id\b).)*?end/s, "device_id", "_device_id"},
      {~r/def\s+(\w+)\([^)]*,\s*__user_id\s*\)\s*do\s*\n(?:(?!\b__user_id\b).)*?end/s, "__user_id", "_user_id"},
      {~r/def\s+(\w+)\([^)]*,\s*__tenant_id\s*\)\s*do\s*\n(?:(?!\b__tenant_id\b).)*?end/s, "__tenant_id", "_tenant_id"},
      {~r/def\s+(\w+)\([^)]*,\s*__context\s*\)\s*do\s*\n(?:(?!\b__context\b).)*?end/s, "__context", "_context"},
      {~r/def\s+(\w+)\([^)]*,\s*__params\s*\)\s*do\s*\n(?:(?!\b__params\b).)*?end/s, "__params", "__params"},
      {~r/def\s+(\w+)\([^)]*,\s*config\s*\)\s*do\s*\n(?:(?!\bconfig\b).)*?end/s, "config", "_config"},
      {~r/def\s+(\w+)\([^)]*,\s*__state\s*\)\s*do\s*\n(?:(?!\b__state\b).)*?end/s, "__state", "__state"},
      {~r/def\s+(\w+)\([^)]*,\s*result\s*\)\s*do\s*\n(?:(?!\bresult\b).)*?end/s, "result", "_result"},
      {~r/def\s+(\w+)\([^)]*,\s*__data\s*\)\s*do\s*\n(?:(?!\b__data\b).)*?end/s, "__data", "_data"},
    ]
    
    files_processed = 0
    fixes_applied = 0
    
    # Get all .ex files
    lib_files = Path.wildcard("lib/**/*.ex")
    
    for file <- lib_files do
      case apply_targeted_fixes(file, fixes) do
        {:ok, file_fixes} when file_fixes > 0 ->
          files_processed = files_processed + 1
          fixes_applied = fixes_applied + file_fixes
          IO.puts("✅ Fixed #{file_fixes} unused variables in #{Path.relative_to_cwd(file)}")
          
        {:ok, 0} ->
          # No fixes needed
          :ok
          
        {:error, reason} ->
          IO.puts("❌ Error processing #{Path.relative_to_cwd(file)}: #{reason}")
      end
    end
    
    IO.puts("\n📊 SUMMARY:")
    IO.puts("Files processed: #{files_processed}")
    IO.puts("Total fixes applied: #{fixes_applied}")
    IO.puts("🎯 Targeted unused variable fixes complete!")
  end
  
  defp apply_targeted_fixes(file, fixes) do
    case File.read(file) do
      {:ok, content} ->
        original_content = content
        
        # Apply each fix pattern
        _updated_content = Enum.reduce(fixes, _content, fn {pattern, old_var, new_var}, acc ->
          # Simple approach: replace variable names in function signatures 
          # where the function body doesn't use the variable
          simple_pattern = "#{old_var})"
          new_pattern = "#{new_var})"
          
          # Only replace if the variable appears to be unused
          if String.contains?(acc, simple_pattern) and not variable_used_in_body?(acc, old_var) do
            String.replace(acc, simple_pattern, new_pattern)
          else
            acc
          end
        end)
        
        if updated_content != original_content do
          File.write!(file, updated_content)
          changes = count_lines_changed(original_content, updated_content)
          {:ok, changes}
        else
          {:ok, 0}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Simple heuristic to check if variable is used in function body
  defp variable_used_in_body?(content, var_name) do
    # Split into functions and check if variable is referenced
    # This is a simple check - not perfect but good enough for common cases
    String.contains?(content, " #{var_name}.") or
    String.contains?(content, " #{var_name},") or  
    String.contains?(content, "(#{var_name}") or
    String.contains?(content, " #{var_name} ") or
    String.contains?(content, "|> #{var_name}")
  end
  
  defp count_lines_changed(original, updated) do
    original_lines = String.split(original, "\n")
    updated_lines = String.split(updated, "\n")
    
    Enum.zip(original_lines, updated_lines)
    |> Enum.count(fn {orig, upd} -> orig != upd end)
  end
end

# Run the fixer
case System.argv() do
  ["--help"] ->
    IO.puts("""
    Usage: elixir scripts/targeted_unused_variable_fixer.exs
    
    Applies targeted fixes for unused variable warnings based on
    specific patterns identified from compilation output.
    
    Fixes variables like:
    - __opts -> _opts (when not used in function body)
    - device_id -> _device_id (when not used)
    - __user_id -> _user_id (when not used)
    - etc.
    """)
    
  _ ->
    TargetedUnusedVariableFixer.run()
end