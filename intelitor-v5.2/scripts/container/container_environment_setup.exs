#!/usr/bin/env elixir

#═══════════════════════════════════════════════════════════════════════════════
# SOPv5.1CONTAINER ENVIRONMENT SETUP
#═══════════════════════════════════════════════════════════════════════════════
#
# Generated: 2025-08-02 18:54:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Agent: Container Environment Setup Coordinator
# Phase: 12.2 - Container Environment Preparation for Local Registry
#
#═══════════════════════════════════════════════════════════════════════════════

defmodule Container Environment Setup do
  @moduledoc """
  SOPv5.1Container Environment Setup System

  Sets up complete container environment with Hex, dependencies, and proper
  permissions using local registry containers only.
  """

  __require Logger

  @local_container "localhost/indrajaal-elixir-build:latest"

  @spec main(any()) :: any()
  def main(args \\ []) do
    Logger.info("🚀 SOPv5.1Container Environment Setup Started")
    Logger.info("Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Local Registry Only")

    setup_container_environment()
  end

  @spec setup_container_environment() :: any()
  defp setup_container_environment() do
    Logger.info("🔧 Setting up container environment with local registry")

    # First, ensure clean __state
    clean_build_artifacts()

    # Setup container with Hex and dependencies
    setup_hex_in_container()
    setup_dependencies_in_container()
    test_container_compilation()
  end

  @spec clean_build_artifacts() :: any()
  defp clean_build_artifacts() do
    Logger.info("🧹 Cleaning build artifacts")

    case System.cmd("rm", ["-rf", "_build", ".mix", ".hex"], stderr_to_stdout: true) do
      {_output, 0} -> Logger.info("✅ Build artifacts cleaned")
      {error, _} -> Logger.warning("⚠️  Cleanup warning: #{String.trim(error)}")
    end
  end

  @spec setup_hex_in_container() :: any()
  defp setup_hex_in_container() do
    Logger.info("📦 Setting up Hex in container")

    hex_cmd = [
      "podman", "run", "--rm",
      "-v", "#{File.cwd!()}:/workspace:z",
      "-w", "/workspace",
      "-u", get_user_mapping(),
      @local_container,
      "mix", "local.hex", "--force"
    ]

    case System.cmd("podman", Enum.drop(hex_cmd, 1), stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("✅ Hex setup completed in container")
      {error, _} ->
        Logger.warning("⚠️  Hex setup warning: #{String.slice(error, 0, 200)}...")
    end
  end

  @spec setup_dependencies_in_container() :: any()
  defp setup_dependencies_in_container() do
    Logger.info("📚 Setting up dependencies in container")

    deps_cmd = [
      "podman", "run", "--rm",
      "-v", "#{File.cwd!()}:/workspace:z",
      "-w", "/workspace",
      "-u", get_user_mapping(),
      @local_container,
      "mix", "deps.get"
    ]

    case System.cmd("podman", Enum.drop(deps_cmd, 1), stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("✅ Dependencies setup completed in container")
      {error, _} ->
        Logger.warning("⚠️  Dependencies warning: #{String.slice(error, 0, 200)}..
    end
  end

  @spec test_container_compilation() :: any()
  defp test_container_compilation() do
    Logger.info("🧪 Testing container compilation")

    compile_cmd = [
      "podman", "run", "--rm",
      "-v", "#{File.cwd!()}:/workspace:z",
      "-w", "/workspace",
      "-u", get_user_mapping(),
      @local_container,
      "mix", "compile"
    ]

    case System.cmd("podman", Enum.drop(compile_cmd, 1), stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("✅ Container compilation test successful")
        {:ok, "Container environment ready"}
      {error, _} ->
        Logger.info("ℹ️  Compilation output: #{String.slice(error, 0, 300)}...")
        {:warning, "Compilation completed with issues"}
    end
  end

  @spec get_user_mapping() :: any()
  defp get_user_mapping() do
    {uid, 0} = System.cmd("id", ["-u"])
    {gid, 0} = System.cmd("id", ["-g"])
    "#{String.trim(uid)}:#{String.trim(gid)}"
  end
end

# Execute if run directly
if System.argv() |> length() >= 0 do
  Container Environment Setup.main(System.argv())
end
