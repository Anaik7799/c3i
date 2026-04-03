defmodule Indrajaal.Deployment.VTOOrchestrator do
  @moduledoc """
  VTO Orchestrator: Verify-Then-Orchestrate Engine (Library Module)

  This module orchestrates the startup and shutdown of the container ecosystem.
  It is designed to be called from Mix tasks or other application code.
  """

  require Logger
  alias Indrajaal.Deployment.Config

  def run(env_profile, action) do
    case action do
      "start" -> start_sequence(env_profile)
      "stop" -> stop_sequence()
      _ -> {:error, "Invalid action: #{action}"}
    end
  end

  defp start_sequence(env_profile) do
    Logger.info("🚀 ACE: Initiating VTO Protocol [Profile: #{env_profile}]")
    ensure_network()

    # Reload config to ensure we have the latest definition
    # (Though in a running app, Config.containers should be static or dynamic lookup)
    container_list = Config.containers(env_profile)
    containers = container_list |> Enum.sort_by(& &1.dependency_order)

    results =
      Enum.reduce_while(containers, :ok, fn container, _acc ->
        Logger.info("📦 Processing Service: #{container.service_name}")

        case run_vto_loop(container) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    case results do
      :ok ->
        Logger.info("✅ ACE: All services CERTIFIED. System is OPERATIONAL.")
        generate_compose_file(env_profile)
        :ok

      {:error, reason} ->
        Logger.error("❌ ACE: JIDOKA HALT. Deployment failed: #{reason}")
        {:error, reason}
    end
  end

  defp stop_sequence do
    Logger.info("🛑 ACE: Executing Sterilization Protocol...")

    {output, 0} =
      System.cmd("podman", ["ps", "-a", "--filter", "name=intelitor", "--format", "{{.Names}}"])

    split_output = String.split(output, "\n", trim: true)
    all_indrajaal_containers = split_output |> Enum.filter(&(&1 != ""))

    if Enum.any?(all_indrajaal_containers) do
      Logger.info("  -> Terminating: #{Enum.join(all_indrajaal_containers, ", ")}")
      System.cmd("podman", ["stop"] ++ all_indrajaal_containers)
      Logger.info("  -> Purging: #{Enum.join(all_indrajaal_containers, ", ")}")
      System.cmd("podman", ["rm", "-f"] ++ all_indrajaal_containers)
    else
      Logger.info("  -> No Indrajaal-managed containers found.")
    end

    Logger.info("✅ Sterilization complete.")
    :ok
  end

  defp ensure_network do
    Logger.info("🌐 Verifying network 'indrajaal-network'...")

    case System.cmd("podman", ["network", "exists", "indrajaal-network"]) do
      {_, 0} ->
        Logger.info("  -> Network exists.")

      _ ->
        Logger.info("  -> Network not found. Creating...")
        System.cmd("podman", ["network", "create", "indrajaal-network"])
    end
  end

  defp run_vto_loop(container) do
    name = container.service_name

    case start_container(container) do
      :ok ->
        Logger.info("🔍 Verifying health for #{name}...")

        case Config.run_health_check_for(name) do
          :ok ->
            :ok

          error ->
            Logger.error("❌ Health check failed for #{name}. Dumping logs:")
            {logs, _} = System.cmd("podman", ["logs", "--tail", "50", name])
            Logger.error(logs)
            error
        end

      error ->
        error
    end
  end

  defp start_container(container) do
    name = container.service_name
    image = "localhost/#{container.image_name}:#{container.image_tag}"

    System.cmd("podman", ["rm", "-f", name])
    Logger.info("  -> Launching #{name}...")

    args = ["run", "-d", "--name", name, "--network", "indrajaal-network"]
    port_args = Enum.flat_map(container[:ports] || [], &["-p", &1])
    env_args = Enum.flat_map(container[:env] || [], &["-e", &1])
    vol_args = Enum.flat_map(container[:volumes] || [], &["-v", &1])
    full_args = args ++ port_args ++ env_args ++ vol_args ++ [image]

    # Log the command for debugging (Quadplex Pillar 2)
    Logger.info("CMD: podman #{Enum.join(full_args, " ")}")

    case System.cmd("podman", full_args) do
      {_id, 0} -> :ok
      {msg, _} -> {:error, msg}
    end
  end

  defp generate_compose_file(env) do
    Logger.info("📄 Generating podman-compose.yml for reference...")

    # Ideally this logic should also be in a module, but shelling out is okay for now as it's a side effect
    System.cmd("elixir", ["scripts/deployment/generate_compose.exs", "--env", Atom.to_string(env)])
  end
end
