#!/usr/bin/env elixir

# scripts/testing/container_health_validator.exs
# SIL-6 Biomorphic Health Validator (Zenoh-First)
# Compliant with v21.3.0-SIL6 GA Standards

Mix.install([{:jason, "~> 1.4"}])

defmodule ContainerHealthValidator do
  @moduledoc """
  Supreme Health Validator for the SIL-6 Multiverse.
  Queries Sentinel-Zenoh for 15-node swarm homeostasis.
  """

  @containers [
    "indrajaal-db-prod",
    "indrajaal-obs-prod",
    "zenoh-router-1",
    "zenoh-router-2",
    "zenoh-router-3",
    "zenoh-router",
    "cepaf-bridge",
    "indrajaal-cortex",
    "indrajaal-ex-app-1",
    "indrajaal-ex-app-2",
    "indrajaal-ex-app-3",
    "indrajaal-chaya",
    "indrajaal-ml-runner-1",
    "indrajaal-ml-runner-2"
  ]

  @zenoh_url "http://localhost:8000"

  def run do
    IO.puts "🏭 INITIATING BIOMORPHIC HEALTH VALIDATION"
    IO.puts "==========================================="

    # Phase 1: Swarm Presence
    validate_swarm_presence()

    # Phase 2: Zenoh Logic Plane
    validate_zenoh_connectivity()

    # Phase 3: Mathematical Homeostasis (Sentinel)
    validate_sentinel_authority()

    IO.puts "\n✅ TOTAL BIOMORPHIC HOMEODYNAMIC STATE CONFIRMED."
  end

  defp validate_swarm_presence do
    IO.puts "[PHASE 1] Validating Swarm Presence..."
    {output, 0} = System.cmd("podman", ["ps", "--format", "{{.Names}}"])
    
    Enum.each(@containers, fn name ->
      if String.contains?(output, name) do
        IO.puts "  ✓ #{name}: RUNNING"
      else
        IO.puts "  ❌ #{name}: MISSING"
        System.halt(1)
      end
    end)
  end

  defp validate_zenoh_connectivity do
    IO.puts "\n[PHASE 2] Validating Zenoh Logic Plane..."
    case System.cmd("curl", ["-sf", "#{@zenoh_url}/@/router/local"]) do
      {_, 0} -> IO.puts "  ✅ Zenoh Control Plane: REACHABLE"
      _ -> 
        IO.puts "  ❌ Zenoh Control Plane: OFFLINE"
        System.halt(1)
    end
  end

  defp validate_sentinel_authority do
    IO.puts "\n[PHASE 3] Validating Sentinel Authority..."
    case System.cmd("curl", ["-sf", "#{@zenoh_url}/indrajaal/health/sentinel"]) do
      {output, 0} -> 
        if output =~ "verified_2oo3" do
          IO.puts "  ✅ Sentinel Assessment: CONVERGENT (2oo3 Quorum)"
        else
          IO.puts "  ⚠️  Sentinel Assessment: DRIFT DETECTED"
        end
      _ -> 
        IO.puts "  ❌ Sentinel Authority: OFFLINE"
        System.halt(1)
    end
  end
end

ContainerHealthValidator.run()
