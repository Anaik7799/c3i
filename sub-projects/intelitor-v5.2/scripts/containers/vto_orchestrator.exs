#!/usr/bin/env elixir
# VTO Orchestrator: Verify-Then-Orchestrate Engine (v4 - Compose Aware)
# -----------------------------------------------------------------------------
# Delegates execution to the Scripting.Runner for Quadplex compliance.
# This version uses podman-compose to ensure healthchecks are respected.
# -----------------------------------------------------------------------------

Code.require_file("lib/indrajaal/scripting/runner.ex", File.cwd!)
Code.require_file("lib/indrajaal/deployment/config.ex", File.cwd!)
alias Indrajaal.Deployment.Config

defmodule VTOOrchestrator do
  def main(args \\ []) do
    {opts, _, _} = OptionParser.parse(args, switches: [env: :string, action: :string])
    
    env_profile = opts[:env] |> then(&if &1, do: String.to_atom(&1), else: :demo)
    action = opts[:action] || "start"

    case action do
      "start" -> start_sequence(env_profile)
      "stop" -> stop_sequence()
      _ -> Logger.warn("Usage: vto_orchestrator.exs --env [dev|...] --action [start|stop]")
    end
  end

  defp get_compose_file(env_profile) do
    case env_profile do
      :dev -> "podman-compose.dev.yml"
      :test -> "podman-compose.testing.yml"
      :prod -> "podman-compose.secure.yml"
      _ -> "podman-compose.yml"
    end
  end

  defp start_sequence(env_profile) do
    Logger.info("🚀 ACE: Initiating VTO Protocol (Compose) [Profile: #{env_profile}]")
    
    compose_file = get_compose_file(env_profile)
    
    Logger.info("  ▶️  Using compose file: #{compose_file}")

    # First, ensure everything is down to start clean
    System.cmd("podman-compose", ["-f", compose_file, "down", "--volumes"], stderr_to_stdout: true)

    Logger.info("  ▶️  Launching all services via podman-compose...")
    
    # The `up -d` command will start all services and run healthchecks automatically.
    # The command will only exit with code 0 if all containers start and become healthy.
    case System.cmd("podman-compose", ["-f", compose_file, "up", "-d"], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("✅ ACE: All services started and healthy.")
        :ok
      {output, code} ->
        Logger.error("❌ Deployment failed with exit code #{code}. Output:\n#{output}")
        # Automatically dump logs from failed containers
        System.cmd("podman-compose", ["-f", compose_file, "logs"], into: IO.stream(:stderr, :line))
        {:error, :compose_up_failed}
    end
  end

  defp stop_sequence do
    Logger.info("🛑 ACE: Executing Sterilization Protocol via Compose...")
    # Stop services defined in all known compose files to be safe
    compose_files = ["podman-compose.yml", "podman-compose.dev.yml", "podman-compose.testing.yml", "podman-compose.secure.yml"]
    
    Enum.each(compose_files, fn file ->
      if File.exists?(file) do
        Logger.info("  -> Downing services from #{file}")
        System.cmd("podman-compose", ["-f", file, "down", "--volumes"], stderr_to_stdout: true)
      end
    end)
    Logger.info("✅ Sterilization complete.")
  end
end

Indrajaal.Scripting.Runner.run(VTOOrchestrator, :main, System.argv())