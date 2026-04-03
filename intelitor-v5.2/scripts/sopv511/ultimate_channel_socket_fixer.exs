#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule UltimateChannelSocketFixer do
  @moduledoc """
  SOPv5.11 Ultimate Channel Socket Parameter Fixer
  
  Applies TPS 5-Level RCA methodology to systematically fix undefined socket variable errors
  across all Phoenix channel files using cybernetic 15-agent coordination principles.
  
  🎯 CRITICAL: This script fixes the root cause of channel socket parameter issues
  using systematic pattern matching and replacement based on Phoenix Channel __requirements.
  """

  __require Logger

  @channel_files [
    "lib/indrajaal_web/channels/alarm_channel.ex",
    "lib/indrajaal_web/channels/config_channel.ex", 
    "lib/indrajaal_web/channels/device_channel.ex",
    "lib/indrajaal_web/channels/notification_channel.ex",
    "lib/indrajaal_web/channels/site_channel.ex",
    "lib/indrajaal_web/channels/sync_channel.ex",
    "lib/indrajaal_web/channels/mobile_socket.ex"
  ]

  @socket_parameter_patterns [
    # Pattern 1: join/3 function with _socket parameter
    {~r/def join\((.*?), (.*?), (_socket)\) do/, "def join(\\1, \\2, socket) do"},
    
    # Pattern 2: handle_info/2 function with _socket parameter  
    {~r/def handle_info\((.*?), (_socket)\) do/, "def handle_info(\\1, socket) do"},
    
    # Pattern 3: handle_in/3 function with _socket parameter
    {~r/def handle_in\((.*?), (.*?), (_socket)\) do/, "def handle_in(\\1, \\2, socket) do"}
  ]

  def main(args \\ []) do
    IO.puts("🚀 SOPv5.11 Ultimate Channel Socket Fixer - EXECUTING")
    IO.puts("🏭 TPS 5-Level RCA: Systematic socket parameter correction")
    IO.puts("🤖 50-Agent Coordination: Channel-specific error resolution")
    IO.puts("")

    case Enum.at(args, 0) do
      "--analyze" -> analyze_socket_errors()
      "--fix" -> fix_all_socket_errors()
      "--validate" -> validate_fixes()
      _ -> display_help()
    end
  end

  defp display_help do
    IO.puts("""
    🎯 SOPv5.11 Ultimate Channel Socket Fixer
    
    Usage:
      --analyze   : Analyze socket parameter errors across all channels
      --fix       : Apply systematic fixes to all socket parameter errors
      --validate  : Validate that fixes are applied correctly
      
    🏭 TPS 5-Level RCA Applied:
    Level 1: Symptom - undefined variable "socket" errors
    Level 2: Surface Cause - _socket parameters not available in function body
    Level 3: System Behavior - Phoenix Channel functions need socket in specific positions  
    Level 4: Configuration Gap - Code generation stripped socket parameters
    Level 5: Design Analysis - Channel pattern matching __requirements
    """)
  end

  defp analyze_socket_errors do
    IO.puts("📊 Phase 1: TPS Analysis - Socket Parameter Error Detection")
    
    total_files = 0
    total_errors = 0
    
    @channel_files
    |> Enum.filter(&File.exists?/1)
    |> Enum.each(fn file_path ->
      IO.puts("🔍 Analyzing: #{Path.basename(file_path)}")
      
      case File.read(file_path) do
        {:ok, content} ->
          file_errors = count_socket_errors(content)
          total_errors = total_errors + file_errors
          total_files = total_files + 1
          
          if file_errors > 0 do
            IO.puts("  ❌ Found #{file_errors} socket parameter errors")
          else
            IO.puts("  ✅ No socket errors detected")
          end
          
        {:error, reason} ->
          IO.puts("  ⚠️  Error reading file: #{reason}")
      end
    end)
    
    IO.puts("")
    IO.puts("📋 TPS Analysis Summary:")
    IO.puts("  Files analyzed: #{total_files}")  
    IO.puts("  Total socket errors: #{total_errors}")
    IO.puts("  Root Cause: Phoenix Channel functions need socket parameter access")
    IO.puts("")
  end

  defp fix_all_socket_errors do
    IO.puts("🔧 Phase 2: SOPv5.11 Systematic Socket Error Resolution")
    IO.puts("🏭 Applying TPS Jidoka: Stop-and-fix methodology")
    
    _total_fixes = 0
    
    @channel_files
    |> Enum.filter(&File.exists?/1) 
    |> Enum.each(fn file_path ->
      IO.puts("🛠️  Fixing: #{Path.basename(file_path)}")
      
      case File.read(file_path) do
        {:ok, content} ->
          {_fixed_content, _fixes_count} = apply_socket_fixes(content)
          
          if fixes_count > 0 do
            File.write!(file_path, fixed_content)
            IO.puts("  ✅ Applied #{fixes_count} socket parameter fixes")
            total_fixes = total_fixes + fixes_count
          else
            IO.puts("  ℹ️  No fixes needed")
          end
          
        {:error, reason} ->
          IO.puts("  ❌ Error reading file: #{reason}")
      end
    end)
    
    IO.puts("")
    IO.puts("🎯 SOPv5.11 Fix Summary:")
    IO.puts("  Total fixes applied: #{total_fixes}")
    IO.puts("  Root cause resolution: Socket parameters now accessible")
    IO.puts("  TPS methodology: Systematic pattern-based correction")
    IO.puts("")
  end

  defp validate_fixes do
    IO.puts("✅ Phase 3: STAMP Safety Validation - Socket Parameter Compliance")
    
    all_valid = true
    
    @channel_files
    |> Enum.filter(&File.exists?/1)
    |> Enum.each(fn file_path ->
      IO.puts("🔍 Validating: #{Path.basename(file_path)}")
      
      case File.read(file_path) do
        {:ok, content} ->
          errors = count_socket_errors(content)
          
          if errors == 0 do
            IO.puts("  ✅ All socket parameters correct")
          else
            IO.puts("  ❌ Still has #{errors} socket errors")
            all_valid = false
          end
          
        {:error, reason} ->
          IO.puts("  ❌ Error reading file: #{reason}")
          all_valid = false
      end
    end)
    
    IO.puts("")
    if all_valid do
      IO.puts("🏆 VALIDATION SUCCESS: All socket parameters fixed!")
      IO.puts("🎯 SOPv5.11 Compliance: 100% channel socket accessibility achieved")
    else
      IO.puts("❌ VALIDATION FAILURE: Some socket errors remain")
      IO.puts("🔄 Recommendation: Re-run --fix command")
    end
    IO.puts("")
  end

  defp count_socket_errors(content) do
    # Count undefined socket variable patterns
    socket_usage_count = Regex.scan(~r/\bsocket\b/, content) |> length()
    socket_param_count = Regex.scan(~r/_socket\b/, content) |> length()
    
    # If socket is used but only _socket parameters exist, we have errors
    if socket_usage_count > 0 and socket_param_count > 0 do
      socket_param_count  # Return number of _socket parameters that need fixing
    else
      0
    end
  end

  defp apply_socket_fixes(content) do
    {_fixed_content, _total_fixes} = 
      @socket_parameter_patterns
      |> Enum.reduce({content, 0}, fn {pattern, replacement}, {current_content, fixes} ->
        matches = Regex.scan(pattern, current_content)
        new_content = Regex.replace(pattern, current_content, replacement)
        new_fixes = length(matches)
        
        {new_content, fixes + new_fixes}
      end)
    
    {fixed_content, total_fixes}
  end
end

# Execute the fixer
UltimateChannelSocketFixer.main(System.argv())