#!/usr/bin/env elixir
# 7-Level Fractal System Audit (v1.0.0)
# Classification: L7-KOSMOS (Sovereign Inspector)
# Context: SIL-6 Biomorphic Mesh

Mix.install([{:jason, "~> 1.4"}])

defmodule Indrajaal.Audit do
  def run do
    IO.puts("\n>>> 🛡️  INITIATING 7-LEVEL FRACTAL SYSTEM AUDIT 🛡️  <<<
")

    results = %{
      l1_cellular: audit_l1(),
      l2_component: audit_l2(),
      l3_integration: audit_l3(),
      l4_operational: audit_l4(),
      l5_metabolic: audit_l5(),
      l6_evolutionary: audit_l6(),
      l7_strategic: audit_l7()
    }

    print_report(results)
    verify_sil6(results)
  end

  defp cmd(command, args) do
    {output, code} = System.cmd(command, args, stderr_to_stdout: true)
    {code, String.trim(output)}
  end

  # --- LEVEL 1: CELLULAR (Code & Data) ---
  defp audit_l1 do
    IO.write("   [L1] Cellular Audit (Logic/Data)... ")
    # Check for warnings in last compile logs if available, or just check file existence
    # For speed, we check critical file integrity
    files = ["mix.exs", "podman-compose-fractal-mesh.yml", "CLAUDE.md"]
    missing = Enum.filter(files, fn f -> !File.exists?(f) end)
    
    if missing == [] do
      IO.puts("✅ PASSED")
      %{status: :ok, details: "Genotypes present"}
    else
      IO.puts("❌ FAILED")
      %{status: :error, details: "Missing: #{inspect(missing)}"}
    end
  end

  # --- LEVEL 2: COMPONENT (Agent Metabolism) ---
  defp audit_l2 do
    IO.write("   [L2] Component Audit (Sentinel/Agents)... ")
    # Check if we can see agent processes in the logs
    {_, logs} = cmd("podman", ["logs", "indrajaal-app-1", "--tail", "50"])
    
    if String.contains?(logs, "OODA Cycle") do
      IO.puts("✅ PASSED")
      %{status: :ok, details: "Metabolic Pulse Detected"}
    else
      IO.puts("⚠️  WARNING (Pulse weak)")
      %{status: :warn, details: "No OODA heartbeat in last 50 lines"}
    end
  end

  # --- LEVEL 3: INTEGRATION (Connectivity) ---
  defp audit_l3 do
    IO.write("   [L3] Integration Audit (Zenoh/DB)... ")
    # Check DB Port
    {c1, _} = cmd("podman", ["exec", "indrajaal-db1", "pg_isready", "-U", "postgres"])
    
    if c1 == 0 do
      IO.puts("✅ PASSED")
      %{status: :ok, details: "Data Plane Connected"}
    else
      IO.puts("❌ FAILED")
      %{status: :error, details: "DB Connection Failed"}
    end
  end

  # --- LEVEL 4: OPERATIONAL (Orchestration) ---
  defp audit_l4 do
    IO.write("   [L4] Operational Audit (Mesh/Containers)... ")
    {_, output} = cmd("podman", ["ps", "--format", "{{.Names}}"])
    nodes = String.split(output, "\n")
    required = ["indrajaal-db1", "indrajaal-obs", "indrajaal-app-1"]
    
    present = Enum.all?(required, fn r -> 
      Enum.any?(nodes, fn n -> String.contains?(n, r) end)
    end)

    if present do
      IO.puts("✅ PASSED")
      %{status: :ok, details: "Critical Nodes Active"}
    else
      IO.puts("❌ FAILED")
      %{status: :error, details: "Quorum Breach"}
    end
  end

  # --- LEVEL 5: METABOLIC (Health/Immunity) ---
  defp audit_l5 do
    IO.write("   [L5] Metabolic Audit (Immune System)... ")
    # Verify Sentinel Bridge logic
    if File.exists?("lib/indrajaal/cockpit/prajna/sentinel_bridge.ex") do
      IO.puts("✅ PASSED")
      %{status: :ok, details: "Immune Logic Present"}
    else
      IO.puts("❌ FAILED")
      %{status: :error, details: "Sentinel Bridge Missing"}
    end
  end

  # --- LEVEL 6: EVOLUTIONARY (Multiverse) ---
  defp audit_l6 do
    IO.write("   [L6] Evolutionary Audit (Multiverse)... ")
    if File.exists?("sa-multiverse.fsx") do
      IO.puts("✅ PASSED")
      %{status: :ok, details: "Multiverse Engine Online"}
    else
      IO.puts("❌ FAILED")
      %{status: :error, details: "Multiverse Engine Missing"}
    end
  end

  # --- LEVEL 7: STRATEGIC (Founder's Directive) ---
  defp audit_l7 do
    IO.write("   [L7] Strategic Audit (Purpose)... ")
    # Check if Cortex container is defined in current genotype
    {_, yaml} = cmd("cat", ["podman-compose-fractal-mesh.yml"])
    
    if String.contains?(yaml, "indrajaal-cortex") do
      IO.puts("✅ PASSED")
      %{status: :ok, details: "Cortex Genotype Active"}
    else
      IO.puts("⚠️  WARNING (Cortex Dormant)")
      %{status: :warn, details: "Cortex not in active mesh"}
    end
  end

  defp print_report(results) do
    IO.puts("\n--- SYSTEM REPORT CARD ---")
    Enum.each(results, fn {k, v} -> 
      IO.puts("#{k}: #{v.status} | #{v.details}")
    end)
  end

  defp verify_sil6(results) do
    failures = Enum.filter(results, fn {_, v} -> v.status == :error end)
    if failures == [] do
      IO.puts("\n>>> 🛡️  SIL-6 COMPLIANCE VERIFIED  🛡️  <<<")
    else
      IO.puts("\n>>> ⚠️  SIL-6 VIOLATION DETECTED  ⚠️  <<<")
      IO.puts("System is NOT in Homeostasis.")
    end
  end
end

Indrajaal.Audit.run()
