#!/usr/bin/env elixir

# AEE Fix Remaining Warnings
# Date: 2025-09-07 10:20:00 CEST
# Purpose: Fix the 4 remaining warnings found

defmodule AEE.FixRemainingWarnings do
  def main(_args) do
    IO.puts """
    🔧 AEE Fixing Remaining Warnings
    ================================
    Target: 4 warnings in logging.ex and analytics.ex
    """

    # Fix 1: logging.ex - log_alarm_event
    fix_logging_alarm_event()
    
    # Fix 2: logging.ex - log_compliance_event  
    fix_logging_compliance_event()
    
    # Fix 3: logging.ex - log_system_event
    fix_logging_system_event()
    
    # Fix 4: analytics.ex - unused ids variable
    fix_analytics_ids()

    IO.puts "\n✅ All fixes applied"
  end

  defp fix_logging_alarm_event do
    IO.puts "\n🔧 Fixing log_alarm_event severity parameter..."
    
    file_path = "lib/indrajaal/logging.ex"
    content = File.read!(file_path)
    
    # Fix the function signature - add underscore to unused severity parameter
    updated_content = String.replace(
      content,
      "def log_alarm_event(event_type, severity, context \\\\ %{}) do",
      "def log_alarm_event(event_type, _severity, context \\\\ %{}) do"
    )
    
    File.write!(file_path, updated_content)
    IO.puts "  ✅ Fixed log_alarm_event"
  end

  defp fix_logging_compliance_event do
    IO.puts "\n🔧 Fixing log_compliance_event severity parameter..."
    
    file_path = "lib/indrajaal/logging.ex"
    content = File.read!(file_path)
    
    # Fix the function signature - add underscore to unused severity parameter
    updated_content = String.replace(
      content,
      "def log_compliance_event(event_type, severity, context \\\\ %{}) do",
      "def log_compliance_event(event_type, _severity, context \\\\ %{}) do"
    )
    
    File.write!(file_path, updated_content)
    IO.puts "  ✅ Fixed log_compliance_event"
  end

  defp fix_logging_system_event do
    IO.puts "\n🔧 Fixing log_system_event severity parameter..."
    
    file_path = "lib/indrajaal/logging.ex"
    content = File.read!(file_path)
    
    # Fix the function signature - add underscore to unused severity parameter
    updated_content = String.replace(
      content,
      "def log_system_event(event_type, severity, context \\\\ %{}) do",
      "def log_system_event(event_type, _severity, context \\\\ %{}) do"
    )
    
    File.write!(file_path, updated_content)
    IO.puts "  ✅ Fixed log_system_event"
  end

  defp fix_analytics_ids do
    IO.puts "\n🔧 Fixing unused ids variable in analytics..."
    
    # First, find the file with the warning
    {_output, __} = System.cmd("grep", ["-r", "ids = Map.get(__params, :ids", "lib/"], stderr_to_stdout: true)
    
    files = output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ".ex:"))
    |> Enum.map(fn line ->
      [file | _] = String.split(line, ":")
      file
    end)
    |> Enum.uniq()
    
    Enum.each(files, fn file ->
      IO.puts "  Processing #{file}..."
      
      content = File.read!(file)
      
      # Fix the unused variable by prefixing with underscore
      updated_content = String.replace(
        content,
        "ids = Map.get(__params, :ids, []) || Map.get(__params, \"ids\", [])",
        "ids = Map.get(__params, :ids, []) || Map.get(__params, \"ids\", [])"
      )
      
      File.write!(file, updated_content)
      IO.puts "  ✅ Fixed unused ids in #{file}"
    end)
  end
end

# Run the fixes
AEE.FixRemainingWarnings.main(System.argv())