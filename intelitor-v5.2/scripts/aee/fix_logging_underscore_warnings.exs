#!/usr/bin/env elixir

# Fix underscore warnings in logging.ex
# If a parameter has underscore (_severity) but is used, remove the underscore

IO.puts("🔧 Fixing underscore warnings in logging.ex...")
IO.puts("📅 Started at: #{:calendar.local_time() |> inspect()}")

content = File.read!("lib/indrajaal/logging.ex")

# Fix all functions that have _severity as parameter but use it
# Pattern: def function_name(..., _severity, ...) but then uses _severity

# Replace function signatures to remove underscore from severity parameter
patterns = [
  # log_security_event
  {"def log_security_event(event_type, _severity, context \\\\ %{}) do",
   "def log_security_event(event_type, severity, context \\\\ %{}) do"},
  
  # log_alarm_event  
  {"def log_alarm_event(event_type, _severity, context \\\\ %{}) do",
   "def log_alarm_event(event_type, severity, context \\\\ %{}) do"},
   
  # log_compliance_event
  {"def log_compliance_event(event_type, _severity, context \\\\ %{}) do",
   "def log_compliance_event(event_type, severity, context \\\\ %{}) do"},
   
  # log_system_event
  {"def log_system_event(event_type, _severity, context \\\\ %{}) do", 
   "def log_system_event(event_type, severity, context \\\\ %{}) do"}
]

# Apply pattern replacements
Enum.each(patterns, fn {pattern, replacement} ->
  content = String.replace(content, pattern, replacement)
end)

# Now update all references from _severity to severity in these functions
# Since we changed the parameter name, we need to update references
content = content
|> String.replace("security_level_to_log_level(_severity)", "security_level_to_log_level(severity)")
|> String.replace("severity: _severity", "severity: severity")
|> String.replace("severity_to_number(_severity)", "severity_to_number(severity)")
|> String.replace("severity_level: severity_to_number(_severity)", "severity_level: severity_to_number(severity)")

# For functions that have _event_type but don't use it, keep the underscore
# For business_event and audit_event, they have _event_type and don't use it - that's fine

# Write the fixed content
File.write!("lib/indrajaal/logging.ex", content)

IO.puts("✅ Fixed underscore warnings in logging.ex")