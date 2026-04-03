#!/usr/bin/env elixir

# Fix function signatures to remove underscore from severity parameter
# Since the functions use severity, the parameter should not have underscore

IO.puts("🔧 Fixing function signatures in logging.ex...")
IO.puts("📅 Started at: #{:calendar.local_time() |> inspect()}")

content = File.read!("lib/indrajaal/logging.ex")

# Fix function signatures that have _severity but use severity
fixes = [
  # log_security_event - line 17
  {"def log_security_event(event_type, _severity, context \\\\ %{}) do",
   "def log_security_event(event_type, severity, context \\\\ %{}) do"},
  
  # log_alarm_event - line 110
  {"def log_alarm_event(event_type, _severity, context \\\\ %{}) do",
   "def log_alarm_event(event_type, severity, context \\\\ %{}) do"},
   
  # log_compliance_event - line 255
  {"def log_compliance_event(event_type, _severity, context \\\\ %{}) do",
   "def log_compliance_event(event_type, severity, context \\\\ %{}) do"},
   
  # log_system_event - line 286
  {"def log_system_event(event_type, _severity, context \\\\ %{}) do",
   "def log_system_event(event_type, severity, context \\\\ %{}) do"},
   
  # Other functions that have _severity but don't use it - keep those as-is
  # log_device_event, log_video_event, log_access_event, log_business_event, log_audit_event
]

# Apply fixes
Enum.each(fixes, fn {pattern, replacement} ->
  if String.contains?(content, pattern) do
    content = String.replace(content, pattern, replacement)
    IO.puts("  ✅ Fixed: #{pattern |> String.slice(0..40)}...")
  else
    IO.puts("  ⚠️  Pattern not found: #{pattern |> String.slice(0..40)}...")
  end
end)

# Write the fixed content
File.write!("lib/indrajaal/logging.ex", content)

IO.puts("✅ Fixed function signatures in logging.ex")