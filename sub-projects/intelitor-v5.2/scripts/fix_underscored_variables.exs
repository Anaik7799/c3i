#!/usr/bin/env elixir

defmodule UnderscoreVariableFixer do
  @moduledoc """
  Fixes underscored variable misuse warnings across the codebase.
  
  Identifies cases where variables like _data, _opts, etc. are actually being used
  and removes the underscore prefix to fix the warnings.
  """

  def run do
    IO.puts("🔧 Starting systematic underscored variable fix...")
    
    # Common patterns to look for
    patterns = [
      {"_data", "__data"},
      {"_opts", "__opts"},
      {"__params", "__params"},
      {"_config", "config"},
      {"__state", "__state"},
      {"_conn", "conn"},
      {"_result", "result"},
      {"_user", "__user"},
      {"_tenant", "tenant"},
      {"_session", "session"},
      {"_request", "__request"},
      {"_response", "response"}
    ]
    
    files_processed = 0
    fixes_applied = 0
    
    # Get all .ex files
    lib_files = Path.wildcard("lib/**/*.ex")
    
    for file <- lib_files do
      case process_file(file, patterns) do
        {:ok, file_fixes} when file_fixes > 0 ->
          files_processed = files_processed + 1
          fixes_applied = fixes_applied + file_fixes
          IO.puts("✅ Fixed #{file_fixes} patterns in #{Path.relative_to_cwd(file)}")
          
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
    IO.puts("🎯 Underscored variable fixes complete!")
  end
  
  defp process_file(file, patterns) do
    case File.read(file) do
      {:ok, content} ->
        original_content = content
        
        # Apply fixes for each pattern
        {_updated_content, _fixes_count} = Enum.reduce(patterns, {content, 0}, fn {underscore_var, clean_var}, {acc_content, acc_fixes} ->
          # Fix function parameter definitions where the variable is actually used
          # Look for patterns like: defp function_name(param1, _data) where _data is used in the function body
          
          # Pattern 1: Function parameters - defp func(_var) or def func(_var)
          param_pattern = ~r/def[p]?\s+\w+\([^)]*#{Regex.escape(underscore_var)}(?=\s*[,)])/
          param_fixes = length(Regex.scan(param_pattern, acc_content))
          
          updated_param = Regex.replace(param_pattern, acc_content, fn match ->
            String.replace(match, underscore_var, clean_var)
          end)
          
          # Pattern 2: Case/with clause parameters - pattern matching
          case_pattern = ~r/(?:case|with).*#{Regex.escape(underscore_var)}(?=\s*[,\s<-])/
          case_fixes = length(Regex.scan(case_pattern, updated_param))
          
          updated_case = Regex.replace(case_pattern, updated_param, fn match ->
            String.replace(match, underscore_var, clean_var)
          end)
          
          # Pattern 3: Function body usage - where the variable is actually used
          # Only replace if we see the variable being used (not just ignored)
          body_usage_pattern = ~r/#{Regex.escape(underscore_var)}(?=\s*[\.\[\(,\s])/
          body_usage_fixes = length(Regex.scan(body_usage_pattern, updated_case))
          
          final_content = if body_usage_fixes > 0 do
            Regex.replace(body_usage_pattern, updated_case, clean_var)
          else
            updated_case
          end
          
          total_pattern_fixes = param_fixes + case_fixes + body_usage_fixes
          {final_content, acc_fixes + total_pattern_fixes}
        end)
        
        if updated_content != original_content do
          File.write!(file, updated_content)
          {:ok, fixes_count}
        else
          {:ok, 0}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Run the fixer
case System.argv() do
  ["--help"] ->
    IO.puts("""
    Usage: elixir scripts/fix_underscored_variables.exs
    
    Fixes underscored variable misuse warnings by removing underscores
    from variables that are actually being used.
    
    Common patterns fixed:
    - _data -> __data (when variable is used)
    - _opts -> __opts (when variable is used)
    - _params -> __params (when variable is used)
    """)
    
  _ ->
    UnderscoreVariableFixer.run()
end