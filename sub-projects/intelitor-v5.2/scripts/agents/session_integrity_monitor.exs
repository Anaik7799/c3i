#!/usr/bin/env elixir

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION INTEGRITY MONITOR (BACKGROUND AGENT)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Enforces SC-ASSP-001: Mandatory Session Resume on Startup.
# Usage: elixir scripts/agents/session_integrity_monitor.exs
#
# ═══════════════════════════════════════════════════════════════════════════════

Code.require_file("scripts/planning/todolist_manager.exs")

defmodule SessionIntegrityMonitor do
  def run do
    IO.puts("🕵️  SESSION INTEGRITY MONITOR STARTING...")
    
    # 1. Run Resume Protocol
    IO.puts("🔄 Executing SC-ASSP-001: Session Resume...")
    TodolistManager.resume_session()
    
    # 2. Check for active sessions in directory
    agent_id = System.get_env("USER") || "Gemini"
    active_sessions_dir = ".active_sessions"
    
    has_active_session = 
      if File.dir?(active_sessions_dir) do
        File.ls!(active_sessions_dir)
        |> Enum.any?(fn file -> 
          # Check if file contains agent_id (heuristic) or just read it
          # File format: TASKID_AGENTID_TIMESTAMP.json
          String.contains?(file, "_#{agent_id}_")
        end)
      else
        false
      end

    if has_active_session do
      IO.puts("✅ Active session found for #{agent_id}. Constraints SC-ASSP-002 met.")
    else
      IO.puts("⚠️  No active session for #{agent_id}. Agent is IDLE.")
      IO.puts("👉 ACTION REQUIRED: Use 'mix todo --start ID' before modifying code.")
    end
    
    IO.puts("✅ Session Integrity Verification Complete.")
  end
end

SessionIntegrityMonitor.run()
