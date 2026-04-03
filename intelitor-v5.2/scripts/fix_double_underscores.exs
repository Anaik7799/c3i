#!/usr/bin/env elixir

defmodule DoubleUnderscoreFixer do
  @moduledoc """
  Fixes double underscore issues that were incorrectly introduced.
  
  Converts variables like var__name back to var_name where appropriate.
  """

  def run do
    IO.puts("🔧 Starting double underscore fixes...")
    
    # Specific double underscore patterns to fix
    patterns = [
      {~r/\bqr_code__data\b/, "qr_code_data"},
      {~r/\baccess__result\b/, "access_result"},
      {~r/\badditional__data\b/, "additional_data"},
      {~r/\brestart__result\b/, "restart_result"},
      {~r/\bfailover__result\b/, "failover_result"},
      {~r/\bscaling__result\b/, "scaling_result"},
      {~r/\bconfig__data\b/, "config_data"},
      {~r/\bresponse__data\b/, "response_data"},
      {~r/\b__request__data\b/, "__request_data"},
      {~r/\bmetadata__info\b/, "metadata_info"},
      {~r/\bvalidation__result\b/, "validation_result"},
      {~r/\bprocessing__context\b/, "processing_context"},
      {~r/\bservice__config\b/, "service_config"},
      {~r/\b__database__config\b/, "__database_config"},
      {~r/\bsecurity__context\b/, "security_context"},
      {~r/\banalysis__context\b/, "analysis_context"},
      {~r/\bexecution__context\b/, "execution_context"},
      {~r/\btask__context\b/, "task_context"},
      {~r/\bmonitoring__data\b/, "monitoring_data"},
      {~r/\bperformance__metrics\b/, "performance_metrics"},
    ]
    
    files_processed = 0
    fixes_applied = 0
    
    # Get all .ex files
    lib_files = Path.wildcard("lib/**/*.ex")
    
    for file <- lib_files do
      case apply_fixes(file, patterns) do
        {:ok, file_fixes} when file_fixes > 0 ->
          files_processed = files_processed + 1
          fixes_applied = fixes_applied + file_fixes
          IO.puts("✅ Fixed #{file_fixes} double underscores in #{Path.relative_to_cwd(file)}")
          
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
    IO.puts("🎯 Double underscore fixes complete!")
  end
  
  defp apply_fixes(file, patterns) do
    case File.read(file) do
      {:ok, content} ->
        original_content = content
        
        # Apply each pattern
        _updated_content = Enum.reduce(patterns, _content, fn {regex, replacement}, acc ->
          String.replace(acc, regex, replacement)
        end)
        
        if updated_content != original_content do
          File.write!(file, updated_content)
          changes = count_changes(original_content, updated_content)
          {:ok, changes}
        else
          {:ok, 0}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp count_changes(original, updated) do
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
    Usage: elixir scripts/fix_double_underscores.exs
    
    Fixes double underscore issues that were incorrectly introduced
    by converting variables like var__name back to var_name.
    """)
    
  _ ->
    DoubleUnderscoreFixer.run()
end