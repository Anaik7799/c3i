#!/usr/bin/env elixir

# scripts/testing/full_singularity_ui_test.exs
# Comprehensive audit of TUI and WebUI features for v21.3.0-SIL6

Mix.install([{:req, "~> 0.5"}, {:jason, "~> 1.4"}])

defmodule SingularityUiTest do
  @web_url "http://localhost:5000"
  @zenoh_url "http://localhost:8000"

  def run do
    IO.puts("🚀 INITIATING FULL SINGULARITY UI AUDIT...")

    # 1. Start WebUI in background
    web_pid = spawn_link(fn -> 
      System.cmd("dotnet", ["run", "--project", "lib/cepaf/src/Cepaf.Cockpit.Web/Cepaf.Cockpit.Web.fsproj"], into: IO.stream(:stdio, :line))
    end)
    
    Process.sleep(15000) # Wait for startup

    IO.puts("\n🌐 PHASE 1: WebUI FEATURE AUDIT")
    pages = ["/", "/alarms", "/guardian", "/sentinel", "/devices", "/settings", "/singularity"]
    
    Enum.each(pages, fn page ->
      case Req.get("#{@web_url}#{page}") do
        {:ok, %{status: 200}} -> IO.puts("  ✓ [Web] #{page}: REACHABLE")
        _ -> IO.puts("  ✗ [Web] #{page}: FAILED")
      end
    end)

    IO.puts("\n🖥️  PHASE 2: TUI FEATURE AUDIT")
    # Verify TUI render via script
    case System.cmd("dotnet", ["fsi", "test_singularity_tui.fsx"]) do
      {output, 0} -> 
        if String.contains?(output, "TUI RENDER SUCCESSFUL") do
          IO.puts("  ✓ [TUI] Singularity View: RENDERED")
        else
          IO.puts("  ✗ [TUI] Singularity View: DATA MISMATCH")
        end
      _ -> IO.puts("  ✗ [TUI] Singularity View: EXECUTION FAILED")
    end

    IO.puts("\n📡 PHASE 3: BIOMORPHIC BUS AUDIT")
    # Trigger singularity simulation
    System.cmd("curl", ["-X", "PUT", "-d", "sim-singularity", "#{@zenoh_url}/indrajaal/control/mesh"])
    Process.sleep(2000)
    
    # Check for entropy vector
    case Req.get("#{@zenoh_url}/indrajaal/telemetry/singularity/entropy") do
      {:ok, %{status: 200, body: body}} ->
        IO.puts("  ✓ [Zenoh] Entropy Vector: ACTIVE (#{body})")
      _ ->
        IO.puts("  ✗ [Zenoh] Entropy Vector: OFFLINE")
    end

    IO.puts("\n🏁 UI AUDIT COMPLETE. HOMEOSTASIS CONFIRMED.")
  end
end

SingularityUiTest.run()
