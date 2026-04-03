#!/usr/bin/env elixir

defmodule UnderscoreWarningFixer do
  @moduledoc """
  Fixes underscore warnings in Elixir files.
  """

  def fix_files do
    files_to_fix = [
      "lib/indrajaal/access_control/compliance_reporter.ex",
      "lib/indrajaal/access_control/analytics_engine.ex",
      "lib/indrajaal/access_control/domain_hooks.ex",
      "lib/indrajaal/access_control/timescale_integration.ex",
      "lib/indrajaal/agent_comments/comprehensive_agent_integrator.ex",
      "lib/indrajaal/alarms/notification_orchestrator.ex",
      "lib/indrajaal/alarms/performance_optimizer.ex",
      "lib/indrajaal/alarms/processing_engine.ex",
      "lib/indrajaal/alarms/real_time_processor.ex",
      "lib/indrajaal/alarms/storm_detection.ex"
    ]
    
    Enum.each(files_to_fix, &fix_file/1)
  end

  defp fix_file(file_path) do
    if File.exists?(file_path) do
      content = File.read!(file_path)
      
      # Fix patterns where underscore variables are used
      fixed_content = content
        |> String.replace(~r/_opts(?=\s*[,\)\]])/, "opts")
        |> String.replace(~r/_context(?=\s*[,\)\]])/, "context")
        |> String.replace(~r/_state(?=\s*[,\)\]])/, "state")
        |> String.replace(~r/_data(?=\s*[,\)\]])/, "data")
        |> String.replace(~r/_params(?=\s*[,\)\]])/, "params")
        |> String.replace(~r/_config(?=\s*[,\)\]])/, "config")
        |> String.replace(~r/def\s+\w+\([^)]*_opts[^)]*\)/, fn match ->
          String.replace(match, "_opts", "opts")
        end)
        |> String.replace(~r/def\s+\w+\([^)]*_context[^)]*\)/, fn match ->
          String.replace(match, "_context", "context")
        end)
      
      if content != fixed_content do
        File.write!(file_path, fixed_content)
        IO.puts("✅ Fixed: #{file_path}")
      else
        IO.puts("ℹ️  No changes needed: #{file_path}")
      end
    else
      IO.puts("⚠️  File not found: #{file_path}")
    end
  end
end

UnderscoreWarningFixer.fix_files()
