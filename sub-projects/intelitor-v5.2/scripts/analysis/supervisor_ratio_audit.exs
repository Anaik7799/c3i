#!/usr/bin/env elixir

# 🚀 SUPERVISOR RATIO AUDIT - SIL-6 FRACTAL INTEGRITY
# ===================================================
# Purpose: Calculate GenServer/Supervisor ratio and verify ≤ 15.

defmodule SupervisionAudit do
  def run do
    IO.puts("📊 Auditing Supervision Tree...")
    
    supervisors = find_supervisors()
    genservers = find_genservers()
    
    total_supervisors = length(supervisors)
    total_genservers = length(genservers)
    ratio = total_genservers / total_supervisors
    
    IO.puts("Total Supervisors: #{total_supervisors}")
    IO.puts("Total GenServers: #{total_genservers}")
    IO.puts("Overall Ratio: #{Float.round(ratio, 2)}")
    
    if ratio <= 15.0 do
      IO.puts("✅ SUCCESS: Ratio is within SIL-6 biomorphic margins (≤ 15).")
    else
      IO.puts("❌ FAILURE: Ratio #{Float.round(ratio, 2)} exceeds SIL-6 margins.")
    end

    audit_individual_supervisors()
  end

  defp find_supervisors do
    {out, 0} = System.cmd("grep", ["-rl", "use Supervisor", "lib/"])
    String.split(out, "\n", trim: true)
  end

  defp find_genservers do
    {out, 0} = System.cmd("grep", ["-rl", "use GenServer", "lib/"])
    String.split(out, "\n", trim: true)
  end

  defp audit_individual_supervisors do
    IO.puts("\n🔍 Individual Supervisor Load Analysis:")
    
    # Analyze the big ones
    [
      "Indrajaal.Application",
      "Indrajaal.Supervisors.FoundationSupervisor",
      "Indrajaal.Supervisors.InfrastructureSupervisor",
      "Indrajaal.Supervisors.IntelligenceSupervisor",
      "Indrajaal.Supervisors.AutonomicSupervisor"
    ]
    |> Enum.each(fn mod_name ->
      try do
        file = mod_name |> String.replace("Indrajaal.", "") |> Macro.underscore() |> (fn p -> "lib/indrajaal/#{p}.ex" end).()
        # Handle special case for Application
        file = if mod_name == "Indrajaal.Application", do: "lib/indrajaal/application.ex", else: file
        
        if File.exists?(file) do
          content = File.read!(file)
          # Count modules in the children list
          children_count = 
            Regex.scan(~r/\{[A-Z]|Indrajaal\.[A-Z]/, content) |> length()
          
          IO.puts("- #{mod_name}: #{children_count} children")
        else
          # Try supervisors path
          file = mod_name |> String.replace("Indrajaal.Supervisors.", "") |> Macro.underscore() |> (fn p -> "lib/indrajaal/supervisors/#{p}.ex" end).()
          if File.exists?(file) do
            content = File.read!(file)
            children_count = Regex.scan(~r/\{[A-Z]|Indrajaal\.[A-Z]/, content) |> length()
            IO.puts("- #{mod_name}: #{children_count} children")
          end
        end
      rescue
        _ -> :ok
      end
    end)
  end
end

SupervisionAudit.run()
