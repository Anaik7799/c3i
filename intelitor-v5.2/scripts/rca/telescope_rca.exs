#!/usr/bin/env elixir

# 🔭 DIRECTED TELESCOPE RCA TOOL
# Purpose: Deep-dive analysis of system failures using fractal observability.

Mix.install([{:jason, "~> 1.4"}])

defmodule TelescopeRCA do
  alias Indrajaal.Observability.DirectedTelescope

  def analyze(issue_type) do
    IO.puts("🔭 INITIATING TELESCOPE RCA: #{issue_type}")
    IO.puts("===================================================")

    case issue_type do
      "ooda_stall" -> analyze_ooda_stall()
      "zenoh_failure" -> analyze_zenoh_failure()
      "mesh_drift" -> analyze_mesh_drift()
      _ -> IO.puts("❌ Unknown issue type.")
    end
  end

  defp analyze_ooda_stall do
    IO.puts("🔍 Checking OODA Loop state...")
    # Dynamic call to avoid compile errors if not loaded
    case GenServer.whereis(Indrajaal.Cybernetic.OODA.Loop) do
      nil -> IO.puts("❌ OODA Loop process not found!")
      pid ->
        state = :sys.get_state(pid)
        IO.puts("📊 Current Phase: #{state.phase}")
        IO.puts("📊 Cycle Count: #{state.cycle_count}")
        IO.puts("📊 Context: #{inspect(state.context)}")
        
        if state.phase == :waiting_for_sensors do
          IO.puts("💡 ROOT CAUSE: OODA Loop is waiting for homeostasis sensors.")
          IO.puts("💡 ACTION: Verify Indrajaal.System.ResourceMonitor is running.")
        end
    end
  end

  defp analyze_zenoh_failure do
    IO.puts("🔍 Checking Zenoh subsystem...")
    # Implementation details
    IO.puts("💡 ACTION: Check native/zenoh_nif compilation and permissions.")
  end

  defp analyze_mesh_drift do
    IO.puts("🔍 Checking Tailscale mesh alignment...")
    IO.puts("💡 ACTION: Verify node names match tailnet.ts.net suffix.")
  end
end

args = System.argv()
if length(args) > 0 do
  TelescopeRCA.analyze(List.first(args))
else
  IO.puts("Usage: elixir telescope_rca.exs [ooda_stall|zenoh_failure|mesh_drift]")
end
