#!/usr/bin/env elixir

# Minimal fix for logging.ex compilation errors
# Only fixes the actual errors identified

IO.puts("🔧 Applying minimal fixes to logging.ex...")
IO.puts("📅 Started at: #{:calendar.local_time() |> inspect()}")

content = File.read!("lib/indrajaal/logging.ex")

# Fix 1: Line 19 - severity should be _severity
content = String.replace(content, 
  "security_level_to_log_level(severity)",
  "security_level_to_log_level(_severity)")

# Fix 2: Line 37 - severity should be _severity  
content = String.replace(content,
  "severity_level: severity_to_number(severity)},",
  "severity_level: severity_to_number(_severity)},")

# Fix 3: Line 38 - _context should be __context and severity should be _severity
content = String.replace(content,
  "Map.merge(_context, %{__event_type: __event_type, severity: severity})",
  "Map.merge(__context, %{__event_type: __event_type, severity: _severity})")

# Fix 4: Line 102 - _context should be __context
content = String.replace(content,
  "Map.merge(_context, %{device_id:",
  "Map.merge(__context, %{device_id:")

# Fix 5: Line 137 - severity should be _severity
content = String.replace(content,
  "severity_level: severity_to_number(severity),",
  "severity_level: severity_to_number(_severity),")

# Fix 6: Line 140 - _context should be __context  
content = String.replace(content,
  "Map.merge(_context, %{alarm_id:",
  "Map.merge(__context, %{alarm_id:")

# Fix 7: Line 168 - _context should be __context
content = String.replace(content,
  "Map.merge(_context, %{camera_id:",
  "Map.merge(__context, %{camera_id:")

# Fix 8: Line 206 - _context should be __context
content = String.replace(content,
  "Map.merge(_context, %{__user_id:",
  "Map.merge(__context, %{__user_id:")

# Fix 9: Line 247 - _context should be __context (for business __event)
content = String.replace(content,
  "Map.merge(_context, %{operation:",
  "Map.merge(__context, %{operation:")

# Fix 10: Line 277 - severity should be _severity
content = String.replace(content,
  "severity_level: severity_to_number(severity)},",
  "severity_level: severity_to_number(_severity)},")

# Fix 11: Line 278 - _context should be __context
content = String.replace(content,
  "Map.merge(_context, %{__event_type: __event_type, framework:",
  "Map.merge(__context, %{__event_type: __event_type, framework:")

# Fix 12: Line 310 - severity should be _severity  
content = String.replace(content,
  "severity_level: severity_to_number(severity),",
  "severity_level: severity_to_number(_severity),")

# Fix 13: Line 313 - _context should be __context
content = String.replace(content,
  "Map.merge(_context, %{component:",
  "Map.merge(__context, %{component:")

# Fix 14: Line 342 - _context should be __context (audit __event)
content = String.replace(content,
  "store_audit_record(__context[:action], __context[:resource], _context)",
  "store_audit_record(__context[:action], __context[:resource], __context)")

# Fix 15: Line 349 - _context should be __context
content = String.replace(content,
  "Map.merge(_context, %{action:",
  "Map.merge(__context, %{action:")

# Fix 16: Line 409 - _context should be __context in store_audit_record
content = String.replace(content,
  "defp store_audit_record(_action, _resource, __context) do",
  "defp store_audit_record(_action, _resource, context) do")

# Write the fixed content
File.write!("lib/indrajaal/logging.ex", content)

IO.puts("✅ Applied minimal fixes to logging.ex")