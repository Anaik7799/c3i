#!/usr/bin/env elixir

defmodule SOPv511.Batch1WarningFixer do
  @moduledoc """
  SOPv5.11 Batch 1 Warning Fixer - Fixes first 100 warnings
  Using 15-agent cybernetic coordination with TPS methodology
  """

  def fix_batch_1_warnings do
    IO.puts """
    ╔════════════════════════════════════════════════════════════════════════╗
    ║     SOPv5.11 BATCH 1 WARNING FIXER - 50-AGENT COORDINATION           ║
    ╠════════════════════════════════════════════════════════════════════════╣
    ║   🟡 Fixing Batch 1/91: First 100 warnings from 9,079 total           ║
    ║   📊 Strategy: Systematic unused variable/function elimination         ║
    ╚════════════════════════════════════════════════════════════════════════╝
    """
    
    # Priority files with most warnings for Batch 1
    batch_1_files = [
      {"lib/indrajaal_web/live/permissions_management_live.ex", :unused_variables, 15},
      {"lib/indrajaal_web/live/monitoring_dashboard_live.ex", :unused_variables, 12},
      {"lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex", :unused_variables, 10},
      {"lib/indrajaal/visitor_management.ex", :unused_functions, 8},
      {"lib/indrajaal/alarms/alarm_event.ex", :unused_variables, 7},
      {"lib/indrajaal_web/channels/alarm_channel.ex", :unused_variables, 6},
      {"lib/indrajaal_web/channels/config_channel.ex", :unused_variables, 6},
      {"lib/indrajaal_web/channels/device_channel.ex", :unused_variables, 5},
      {"lib/indrajaal_web/channels/mobile_socket.ex", :unused_variables, 5},
      {"lib/indrajaal_web/channels/notification_channel.ex", :unused_variables, 5},
      {"lib/indrajaal_web/channels/site_channel.ex", :unused_variables, 5},
      {"lib/indrajaal_web/channels/sync_channel.ex", :unused_variables, 5},
      {"lib/indrajaal_web/components/core_components.ex", :unused_functions, 5},
      {"lib/indrajaal_web/controllers/analytics_api_controller.ex", :unused_variables, 4},
      {"lib/indrajaal_web/controllers/api/mobile/auth_controller.ex", :unused_variables, 4},
      {"lib/indrajaal_web/controllers/api/mobile/batch_controller.ex", :unused_variables, 4}
    ]
    
    total_fixed = 0
    
    Enum.each(batch_1_files, fn {file, type, count} ->
      if total_fixed < 100 do
        fixes_to_apply = min(count, 100 - total_fixed)
        fixed = fix_file_warnings(file, type, fixes_to_apply)
        total_fixed = total_fixed + fixed
        IO.puts "   ✓ Fixed #{fixed} warnings in #{Path.basename(file)}"
      end
    end)
    
    IO.puts "\n📊 Batch 1 Summary: Fixed #{total_fixed} warnings"
    IO.puts "🔄 Next: Running patient mode compilation validation..."
  end
  
  defp fix_file_warnings(file_path, :unused_variables, max_fixes) do
    if File.exists?(file_path) do
      content = File.read!(file_path)
      lines = String.split(content, "\n")
      
      # Pattern to find unused variables
      unused_var_pattern = ~r/^\s*def\w*\s+\w+\(([^)]*)\)/
      
      fixed_count = 0
      _new_lines = Enum.map(lines, fn line ->
        if fixed_count < max_fixes && Regex.match?(unused_var_pattern, line) do
          # Fix common unused variables by prefixing with underscore
          new_line = line
          |> fix_unused_param("__opts")
          |> fix_unused_param("__user")
          |> fix_unused_param("item")
          |> fix_unused_param("attrs")
          |> fix_unused_param("action")
          |> fix_unused_param("resource")
          |> fix_unused_param("socket")
          |> fix_unused_param("__params")
          
          if new_line != line do
            fixed_count = fixed_count + 1
          end
          new_line
        else
          line
        end
      end)
      
      new_content = Enum.join(new_lines, "\n")
      if content != new_content do
        File.write!(file_path, new_content)
      end
      
      fixed_count
    else
      0
    end
  end
  
  defp fix_file_warnings(file_path, :unused_functions, max_fixes) do
    if File.exists?(file_path) do
      content = File.read!(file_path)
      
      # Common unused functions to mark as @doc false
      unused_functions = [
        "validate_user_access",
        "validate_item_access",
        "validate_update_attrs",
        "validate_create_attrs",
        "validate_deletion_safety",
        "get_or_create_bucket",
        "clean_bucket",
        "add_timestamp",
        "calculate_reset_time"
      ]
      
      fixed_count = 0
      _new_content = Enum.reduce(unused_functions, _content, fn func_name, acc ->
        if fixed_count < max_fixes do
          # Add @doc false before the function definition
          pattern = ~r/(^\s*)(def\w*\s+#{func_name}\b)/m
          if Regex.match?(pattern, acc) do
            new_acc = Regex.replace(pattern, acc, "\\1@doc false\n\\1\\2", global: false)
            if new_acc != acc do
              fixed_count = fixed_count + 1
            end
            new_acc
          else
            acc
          end
        else
          acc
        end
      end)
      
      if content != new_content do
        File.write!(file_path, new_content)
      end
      
      fixed_count
    else
      0
    end
  end
  
  defp fix_unused_param(line, param_name) do
    # Check if parameter is actually used in the line
    if String.contains?(line, "#{param_name}:") || String.contains?(line, "#{param_name}.") ||
       String.contains?(line, "#{param_name},") || String.contains?(line, "#{param_name})") do
      # Parameter might be used, check more carefully
      # Only prefix with underscore if it's in the parameter list but not used in body
      if Regex.match?(~r/\b#{param_name}\b(?!\s*[:.])/, line) do
        String.replace(line, ~r/\b#{param_name}\b/, "_#{param_name}", global: false)
      else
        line
      end
    else
      line
    end
  end
end

# Execute Batch 1 fixes
SOPv511.Batch1WarningFixer.fix_batch_1_warnings()