#!/usr/bin/env elixir

file_path = "lib/indrajaal/logging.ex"
IO.puts("Reading #{file_path}...")

content = File.read!(file_path)

# Apply all fixes
fixed =
  content
  |> String.replace("_severity, context", "severity, context")
  |> String.replace("severity: _severity,", "severity: severity,")
  |> String.replace("Map.merge(_context,", "Map.merge(context,")
  |> String.replace(
    "def store_audit_record(action, resource, metadata) do",
    "def store_audit_record(action, resource, context) do"
  )

# Additional fix for store_audit_record body
fixed =
  Regex.replace(
    ~r/action: context\[:action\],\s*\n\s*resource: context\[:resource\],\s*\n\s*context: context/,
    fixed,
    "action: action,\n      resource: resource,\n      context: context"
  )

File.write!(file_path, fixed)
IO.puts("Fixed logging.ex")
