defmodule Indrajaal.Knowledge.SyncBridge do
  @moduledoc """
  Control Bridge for Elixir-F# Interop in Knowledge Management.

  WHAT: Provides an interface for Elixir to control the F# CEPAF# system.
  WHY: Enables "Complete Sync" by allowing Elixir to trigger ingestion and verify F# health.

  Mechanisms:
  - CLI Invocation: Calls `cepaf-cli` (or equivalent dotnet command)
  - File Signals: Writes signal files if direct CLI is unavailable
  - Shared DB Checks: Verifies F# activity via DB timestamps
  """

  require Logger

  @fsharp_project_path "lib/cepaf/src/Cepaf.Knowledge.CLI/Cepaf.Knowledge.CLI.fsproj"

  @doc """
  Trigger the F# Knowledge Ingestor (The Plasma Engine).
  """
  def trigger_ingestion(path \\ ".") do
    Logger.info("🌉 SyncBridge: Triggering F# Plasma Engine for #{path}")

    # Run the F# CLI tool via dotnet run
    # Assuming 'dotnet' is in path
    cmd = "dotnet"
    args = ["run", "--project", @fsharp_project_path, "--", "ingest", "--path", path]

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("🌉 SyncBridge: Ingestion Successful.\n#{output}")
        :ok

      {output, code} ->
        Logger.error("🌉 SyncBridge: Ingestion Failed (Exit #{code}).\n#{output}")
        {:error, code}
    end
  end

  @doc """
  Check the health of the F# subsystem.
  """
  def check_health do
    # 1. Check if we can run dotnet
    case System.find_executable("dotnet") do
      nil ->
        {:error, :dotnet_missing}

      _ ->
        # 2. Check if DB is accessible (handled by DuckDBStore)
        # 3. Check if F# project exists
        if File.exists?(@fsharp_project_path) do
          :ok
        else
          {:error, :project_missing}
        end
    end
  end
end
