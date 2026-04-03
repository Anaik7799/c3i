#!/usr/bin/env elixir

# ═══════════════════════════════════════════════════════════════════════════════
# ASSP ENVIRONMENT SETUP
# ═══════════════════════════════════════════════════════════════════════════════
#
# Configures environment variables and aliases for the Active State 
# Synchronization Protocol (ASSP).
#
# Usage: source scripts/env/assp_setup.sh
# ═══════════════════════════════════════════════════════════════════════════════

defmodule AssPSetup do
  def run do
    IO.puts("🔧 CONFIGURING ASSP ENVIRONMENT...")
    
    # 1. Verify Directory Structure
    File.mkdir_p!(".active_sessions")
    File.mkdir_p!("backups/todolist")
    
    # 2. Check Git Integration
    {git_status, _} = System.cmd("git", ["status", "--porcelain"])
    IO.puts("📊 Git Status Check: #{if String.length(git_status) > 0, do: "Dirty", else: "Clean"}")
    
    # 3. Create convenience aliases (printed for user to source)
    IO.puts("\n✅ ASSP Environment Ready.")
    IO.puts("\n👉 Add these aliases to your shell profile for efficiency:")
    IO.puts("   alias todo='elixir scripts/planning/todolist_manager.exs'")
    IO.puts("   alias resume='todo --resume'")
    IO.puts("   alias start='todo --start'")
    IO.puts("   alias done='todo --complete'")
  end
end

AssPSetup.run()
