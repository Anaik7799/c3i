#!/usr/bin/env elixir

# ═══════════════════════════════════════════════════════════════════════════════
# DEPRECATED - REDIRECTING TO F# PLANNING SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

IO.puts(:stderr, """
\u001b[33m
⚠️  DEPRECATION WARNING: scripts/planning/todolist_manager.exs is deprecated.
⚠️  The Planning System has migrated to F# (Cepaf.Planning.CLI).

Redirecting to 'sa-plan' (F# CLI)...
\u001b[0m
""")

# Map arguments to sa-plan
args = System.argv()

cmd_args = case args do
  ["--status"] -> ["status"]
  ["--add", title] -> ["add", title]
  ["--add", title, priority] -> ["add", title, priority]
  ["--update", id, status] -> ["update", id, status]
  ["--list"] -> ["list"]
  ["--backup"] -> ["backup"]
  ["--sync"] -> ["sync"]
  ["--help"] -> ["help"]
  [] -> ["status"]
  _ -> ["help"] # Fallback
end

# Execute F# CLI
# We use into: IO.stream(:stdio, :line) to stream output directly
{_output, exit_code} = System.cmd("dotnet", ["run", "--project", "lib/cepaf/src/Cepaf.Planning.CLI", "--"] ++ cmd_args, into: IO.stream(:stdio, :line))

System.halt(exit_code)