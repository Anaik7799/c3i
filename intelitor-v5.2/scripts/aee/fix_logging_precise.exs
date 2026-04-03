#!/usr/bin/env elixir

# Precise fix for logging.ex compilation errors
# Handles the specific pattern of underscore variables correctly

defmodule PreciseLoggingFixer do
  def fix_file(path) do
    IO.puts("🔧 Applying precise fixes to logging.ex...")
    IO.puts("📅 Started at: #{local_time()}")
    
    # Read the file
    content = File.read!(path)
    
    # Track which functions have which parameters
    functions_with_underscore_event_type = [
      "log_security_event",
      "log_auth_event", 
      "log_device_event",
      "log_alarm_event",
      "log_video_event",
      "log_access_event",
      "log_business_event",
      "log_compliance_event",
      "log_system_event",
      "log_audit_event"
    ]
    
    # Apply targeted fixes
    fixed_content = content
    
    # Fix each function that has __event_type without underscore
    Enum.each(functions_with_underscore_event_type, fn func_name ->
      # Check if this function has __event_type or _event_type as parameter
      case Regex.run(~r/def #{func_name}\(([^)]+)\)/, content) do
        [_, __params] ->
          if String.contains?(__params, "_event_type") do
            # Parameter is _event_type, so references should use _event_type
            IO.puts("  ✅ #{func_name} already uses _event_type correctly")
          else
            # Parameter is __event_type (not underscored), fix references to _event_type
            IO.puts("  🔄 Fixing #{func_name} to use __event_type (removing underscore from references)")
            fixed_content = fix_event_type_references_in_function(fixed_content, func_name)
          end
        _ -> 
          IO.puts("  ⚠️  Could not parse #{func_name}")
      end
    end)
    
    # Write back
    File.write!(path, fixed_content)
    
    IO.puts("✅ Applied precise fixes to logging.ex")
  end
  
  defp fix_event_type_references_in_function(content, func_name) do
    # Find the function and fix _event_type references to __event_type within it
    case Regex.run(~r/(def #{func_name}\([^)]+\) do\s*)(.*?)(\n  end)/ms, content) do
      [full_match, func_start, func_body, func_end] ->
        # In the function body, replace _event_type with __event_type
        fixed_body = String.replace(func_body, "_event_type", "__event_type")
        fixed_function = func_start <> fixed_body <> func_end
        String.replace(content, full_match, fixed_function)
      _ ->
        content
    end
  end
  
  defp local_time do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B CEST", 
      [year, month, day, hour, minute, second])
    |> to_string()
  end
end

# Execute the fix
PreciseLoggingFixer.fix_file("lib/indrajaal/logging.ex")