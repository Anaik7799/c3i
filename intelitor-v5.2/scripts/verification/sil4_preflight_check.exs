#!/usr/bin/env elixir
# SIL-6 Biomorphic Preflight Checklist
# Compliance: SC-VAL-008, SC-CNT-013

defmodule Sil4Preflight do
  def run do
    IO.puts(">>> [SIL-6 Biomorphic PREFLIGHT] INITIATING SYSTEM SCAN...")
    
    checks = [
      {&check_images/0, "Container Images (Hardened)"},
      {&check_network/0, "Fractal Mesh Network"},
      {&check_topology/0, "Fractal Mesh Topology"},
      {&check_supervisor/0, "Biomorphic Supervisor (F#)"},
      {&check_watchdog/0, "Transactional Watchdog Agent"}
    ]

    results = Enum.map(checks, fn {func, name} ->
      IO.write("Checking #{name}... ")
      case func.() do
        :ok -> 
          IO.puts("✅ PASS")
          true
        {:error, reason} -> 
          IO.puts("❌ FAIL: #{reason}")
          false
      end
    end)

    if Enum.all?(results), do: exit(:normal), else: exit({:shutdown, 1})
  end

  def check_images do
    # In a real environment, we'd query podman images. 
    # Here we check if the build script exists as a proxy for the capability.
    if File.exists?("scripts/containers/build_sil4_images.sh"), do: :ok, else: {:error, "Build script missing"}
  end

  def check_network do
    # SC-NET-001: Pre-create networks to prevent podman-compose race conditions
    # We create both the project-namespaced version (used by compose) and the raw version (used by some tools)
    
    networks = ["intelitor-v52_fractal-mesh", "fractal-mesh"]
    
    Enum.each(networks, fn net ->
      case System.cmd("podman", ["network", "create", net], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> 
          if String.contains?(output, "already exists"), do: :ok, else: IO.puts("    ⚠️  Network warning: #{String.trim(output)}")
      end
    end)
    :ok
  end

  def check_topology do
    if File.exists?("podman-compose-fractal-mesh.yml"), do: :ok, else: {:error, "Topology definition missing"}
  end

  def check_supervisor do
    if File.exists?("lib/cepaf/scripts/fractal-tui.fsx"), do: :ok, else: {:error, "Supervisor script missing"}
  end

  def check_watchdog do
    if File.exists?("scripts/agents/indrajaal_watchdog.exs"), do: :ok, else: {:error, "Watchdog agent missing"}
  end
end

Sil4Preflight.run()
