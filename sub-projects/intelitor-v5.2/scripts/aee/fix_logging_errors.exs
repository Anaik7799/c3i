#!/usr/bin/env elixir

# Fix logging.ex compilation errors
# Addresses underscore variable usage and undefined __context issues

defmodule LoggingFixer do
  def fix_file(path) do
    IO.puts("🔧 Fixing logging.ex compilation errors...")
    IO.puts("📅 Started at: #{local_time()}")
    
    # Read the file
    content = File.read!(path)
    
    # Apply fixes
    fixed_content = content
    |> fix_severity_references()
    |> fix_context_references()
    |> fix_event_type_references()
    
    # Write back
    File.write!(path, fixed_content)
    
    IO.puts("✅ Applied fixes to logging.ex")
  end
  
  defp fix_severity_references(content) do
    # Replace severity references where _severity is the parameter
    content
    |> String.replace("security_level_to_log_level(severity)", "security_level_to_log_level(_severity)")
    |> String.replace("severity_to_number(severity)", "severity_to_number(_severity)") 
    |> String.replace("severity: severity", "severity: _severity")
  end
  
  defp fix_context_references(content) do
    # Fix _context being used where __context is expected
    content
    |> String.replace("Map.merge(_context,", "Map.merge(__context,")
    |> String.replace(", _context)", ", __context)")
  end
  
  defp fix_event_type_references(content) do
    # Fix _event_type being used where __event_type is expected
    content
    |> String.replace("__event_type: __event_type", "__event_type: _event_type")
  end
  
  defp local_time do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B CEST", 
      [year, month, day, hour, minute, second])
    |> to_string()
  end
end

# Execute the fix
LoggingFixer.fix_file("lib/indrajaal/logging.ex")