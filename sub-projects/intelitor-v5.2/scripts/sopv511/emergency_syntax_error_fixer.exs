#!/usr/bin/env elixir
# SOPv5.11 Emergency Syntax Error Fixer
# TPS Jidoka IMMEDIATE Stop-and-Fix for Critical Syntax Errors

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.EmergencySyntaxErrorFixer do
  @moduledoc """
  Emergency TPS Jidoka fix for critical syntax errors caused by aggressive regex replacement.
  
  Critical Issue: `def join(, __params, socket) do` missing first parameter
  Root Cause: Regex replacement removed channel identifiers
  """

  def main(args \\ []) do
    IO.puts "\n🚨 SOPv5.11 EMERGENCY SYNTAX ERROR FIXER"
    IO.puts "=========================================="
    IO.puts "🏭 TPS Jidoka: IMMEDIATE Stop-and-Fix"
    IO.puts "🎯 Target: Channel join function syntax errors"
    
    case args do
      ["--fix"] -> execute_emergency_fixes()
      ["--scan"] -> scan_syntax_errors()
      _ -> show_help()
    end
  end

  defp execute_emergency_fixes do
    IO.puts "\n🔥 EXECUTING EMERGENCY SYNTAX FIXES"
    IO.puts "===================================="
    
    # Known problematic channel files with proper identifiers
    channel_fixes = %{
      "lib/indrajaal_web/channels/alarm_channel.ex" => "alarm:",
      "lib/indrajaal_web/channels/config_channel.ex" => "config:",  
      "lib/indrajaal_web/channels/device_channel.ex" => "device:",
      "lib/indrajaal_web/channels/sync_channel.ex" => "sync:"
    }
    
    Enum.each(channel_fixes, fn {file_path, prefix} ->
      if File.exists?(file_path) do
        fix_channel_syntax_error(file_path, prefix)
      else
        IO.puts "⚠️ File not found: #{file_path}"
      end
    end)
    
    # Final compilation test
    IO.puts "\n🧪 Testing compilation after emergency fixes..."
    {__output, _exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    
    if exit_code == 0 do
      IO.puts "✅ EMERGENCY FIXES SUCCESSFUL - Compilation working"
    else
      IO.puts "❌ More syntax errors remain - need additional fixes"
    end
  end

  defp fix_channel_syntax_error(file_path, channel_prefix) do
    IO.puts "🔧 Fixing syntax error in: #{file_path}"
    
    content = File.read!(file_path)
    
    # Fix the broken join function pattern
    fixed_content = String.replace(
      content, 
      "def join(, __params, socket) do",
      "def join(\"#{channel_prefix}\" <> channel_id, __params, socket) do"
    )
    
    # Also fix any potential handle_in patterns
    fixed_content = String.replace(
      fixed_content,
      "def handle_in(, __params, socket) do",
      "def handle_in(__event, __params, socket) do"
    )
    
    if fixed_content != content do
      File.write!(file_path, fixed_content)
      IO.puts "   ✅ Fixed #{file_path}"
    else
      IO.puts "   ℹ️ No fixes needed for #{file_path}"
    end
  end

  defp scan_syntax_errors do
    IO.puts "\n🔍 SCANNING FOR SYNTAX ERRORS"
    IO.puts "=============================="
    
    # Try compilation and capture errors
    {_output, __exit_code} = System.cmd("mix", ["compile"], stderr_to_stdout: true)
    
    # Look for syntax errors
    syntax_errors = String.split(output, "\n")
    |> Enum.filter(&String.contains?(&1, "SyntaxError"))
    |> Enum.take(5)
    
    IO.puts "Found #{length(syntax_errors)} syntax errors:"
    Enum.each(syntax_errors, fn error ->
      IO.puts "❌ #{error}"
    end)
    
    # Look for the specific pattern
    broken_joins = String.split(output, "\n")
    |> Enum.filter(&String.contains?(&1, "def join(,"))
    
    if length(broken_joins) > 0 do
      IO.puts "\n🚨 Found broken join functions:"
      Enum.each(broken_joins, fn join ->
        IO.puts "❌ #{join}"
      end)
    end
  end

  defp show_help do
    IO.puts """
    
    🚨 SOPv5.11 Emergency Syntax Error Fixer
    ========================================
    
    Available commands:
    
      --fix    Execute emergency syntax fixes
      --scan   Scan for syntax errors
      --help   Show this help message
    
    Example usage:
      elixir scripts/sopv511/emergency_syntax_error_fixer.exs --fix
    
    🎯 This script fixes critical syntax errors in channel join functions
       caused by aggressive regex replacements.
    """
  end
end

SOPv511.EmergencySyntaxErrorFixer.main(System.argv())