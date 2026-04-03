#!/usr/bin/env elixir

defmodule ContainerBuildWrapper do
  @moduledoc """
  🐳 Container Build Wrapper for SOPv5.1 Compliance

  Agent: This script provides a wrapper to execute container builds
  inside a container environment for full SOPv5.1 compliance.

  Updated: 2025-08-02 13:30:00 CEST
  Framework: SOPv5.1 + PHICS + TPS
  """

  @project_root File.cwd!()

  @spec main(term()) :: any()
  def main(args \\ []) do
    IO.puts("""
    🐳 Container Build Wrapper
    =========================
    Executing build inside container for SOPv5.1 compliance
    """)

    # Agent: Check if we're already in a container
    if in_container?() do
      # We're in container, execute build directly
      System.cmd("elixir", ["scripts/containers/git_aware_container_build.exs" | args])
    else
      # We're on host, execute via podman
      execute_in_container(args)
    end
  end

  defp in_container? do
    File.exists?("/.dockerenv") or
      File.exists?("/.phics-container") or
      System.get_env("container") != nil
  end

  defp execute_in_container(args) do
    IO.puts("🔄 Executing build in container environment...")

    # Agent: Use the sopv51-base container if available
    container_name = "indrajaal-build-#{:os.system_time(:second)}"

    # Agent: Mount the project directory
    mount_opts = [
      "-v",
      "#{@project_root}:/workspace:z",
      "-w",
      "/workspace",
      "--rm"
    ]

    # Agent: Environment variables
    env_opts = [
      # Disable enforcement inside container
      "-e",
      "CONTAINER_ENFORCEMENT=false",
      "-e",
      "PHICS_ENABLED=true",
      "-e",
      "NO_TIMEOUT=true",
      "-e",
      "ELIXIR_ERL_OPTIONS=+S 16"
    ]

    # Agent: Create PHICS marker
    phics_opts = [
      "-e",
      "container=podman",
      "--tmpfs",
      "/.phics-container:exec"
    ]

    # Agent: Choose image
    image =
      case get_available_image() do
        {:ok, img} -> img
        # Fallback for now
        :error -> "docker.io/elixir:1.18-alpine"
      end

    # Agent: Build command
    cmd_args =
      [
        "run",
        "--name",
        container_name
      ] ++
        mount_opts ++
        env_opts ++
        phics_opts ++
        [
          image,
          "elixir",
          "scripts/containers/git_aware_container_build.exs"
        ] ++ args

    case System.cmd("podman", cmd_args, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        IO.puts("\n✅ Container build completed successfully")

      {_, code} ->
        IO.puts("\n❌ Container build failed (exit code: #{code})")
        System.halt(1)
    end
  end

  defp get_available_image do
    # Agent: Check for our custom images first
    case System.cmd("podman", ["images", "--format", "{{.Repository}}:{{.Tag}}"]) do
      {output, 0} ->
        images = String.split(output, "\n", trim: true)

        cond do
          "localhost/sopv51-base:latest" in images ->
            {:ok, "localhost/sopv51-base:latest"}

          "localhost/indrajaal-sopv51-base:latest" in images ->
            {:ok, "localhost/indrajaal-sopv51-base:latest"}

          true ->
            :error
        end

      _ ->
        :error
    end
  end
end

# Agent: Execute wrapper
ContainerBuildWrapper.main(System.argv())
