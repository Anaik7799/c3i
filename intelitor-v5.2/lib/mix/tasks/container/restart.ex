defmodule Mix.Tasks.Container.Restart do
  @moduledoc """
  Restarts one or more containers.

  This task stops and then starts containers, preserving their configuration
  and ensuring a clean restart cycle.

  ## Usage

      mix container.restart CONTAINER_NAME [OPTIONS]
      mix container.restart app db redis
      mix container.restart --all

  ## Options

    * `--timeout SECONDS` - Timeout for graceful shutdown (default: 10)
    * `--force` - Force restart containers
    * `--all` - Restart all running containers
    * `--health - check` - Wait for health check after restart
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Restart single container
      mix container.restart app

      # Restart with health check
      mix container.restart app --health - check

      # Force restart all containers
      mix container.restart --all --force

  Created: 2025 - 08 - 05 17:37:00 CEST
  Framework: SOPv5.1 + Container Management
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Restart containers"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_restart_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    validate_container_runtime!()

    # Get containers to restart
    containers =
      if opts[:all] do
        get_all_running_containers()
      else
        if container_names == [] do
          Mix.raise("Error: Container name __required or use --all flag")
        end

        container_names
      end

    if containers == [] do
      Mix.shell().info("Info:  No containers to restart")
      return()
    end

    # Restart containers
    container_count = length(containers)

    if container_count > 1 do
      Mix.shell().info("Reload: Restarting #{container_count} containers...")
    end

    results =
      Enum.map(containers, fn name ->
        restart_container(name, opts)
      end)

    # Log to Claude
    ensure_claude_logging("restart", %{
      containers: containers,
      options: opts,
      results: results
    })

    # Summary
    successful = Enum.count(results, fn {status, _} -> status == :ok end)

    if successful == container_count do
      Mix.shell().info("\nSuccess: All containers restarted successfully")
    else
      failed = container_count - successful

      Mix.shell().error(
        "\nWarning:  #{successful}/#{container_count} containers restarted, #{failed} failed"
      )
    end
  end

  @spec parse_restart_options(term()) :: term()
  defp parse_restart_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          timeout: :integer,
          force: :boolean,
          all: :boolean,
          health_check: :boolean,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          t: :timeout,
          f: :force,
          h: :health_check
        ]
      )

    # Default timeout
    opts = Keyword.put_new(opts, :timeout, 10)

    {opts, remaining_args}
  end

  @spec get_all_running_containers() :: any()
  def get_all_running_containers() do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}", "--filter", "status = running"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.filter(&(&1 != ""))

      _ ->
        []
    end
  end

  @spec restart_container(term(), term()) :: term()
  defp restart_container(name, opts) do
    Mix.shell().info("\n🐳 Restarting container: #{name}")

    case get_container_info(name) do
      {:ok, info} ->
        original_ports = get_in(info, ["NetworkSettings", "Ports"]) || %{}
        restart_and_check_health(name, opts, original_ports)

      {:error, :not_found} ->
        Mix.shell().error("   Error: Container not found: #{name}")
        {:error, :not_found}
    end
  end

  @spec restart_and_check_health(term(), term(), term()) :: term()
  defp restart_and_check_health(name, opts, original_ports) do
    Mix.shell().info("   🛑 Stopping container...")
    stop_result = stop_container_for_restart(name, opts)

    case stop_result do
      {:ok, _} ->
        Process.sleep(500)
        continue_with_start(name, opts, original_ports)

      error ->
        Mix.shell().error("   Error: Failed to stop container")
        error
    end
  end

  @spec continue_with_start(term(), term(), term()) :: term()
  defp continue_with_start(name, opts, original_ports) do
    Mix.shell().info("   [LAUNCH] Starting container...")
    start_result = start_container_after_stop(name, opts)

    case start_result do
      {:ok, _} ->
        if opts[:health_check] do
          perform_health_check(name, original_ports)
        else
          Mix.shell().info("   Success: Container restarted successfully")
          {:ok, :restarted}
        end

      error ->
        Mix.shell().error("   Error: Failed to start container")
        error
    end
  end

  @spec stop_container_for_restart(term(), term()) :: term()
  defp stop_container_for_restart(name, opts) do
    args = ["stop"]

    args =
      if opts[:timeout] do
        args ++ ["--timeout", to_string(opts[:timeout])]
      else
        args
      end

    args = args ++ [name]

    case run_podman_command(args, []) do
      {_, 0} ->
        {:ok, :stopped}

      _ ->
        if opts[:force] do
          # Try kill if stop failed
          case run_podman_command(["kill", name], []) do
            {_, 0} -> {:ok, :killed}
            _ -> {:error, :stop_failed}
          end
        else
          {:error, :stop_failed}
        end
    end
  end

  @spec start_container_after_stop(term(), term()) :: term()
  defp start_container_after_stop(name, _opts) do
    case run_podman_command(["start", name], []) do
      {_, 0} ->
        {:ok, :started}

      _ ->
        {:error, :start_failed}
    end
  end

  @spec perform_health_check(term(), term()) :: term()
  defp perform_health_check(name, original_ports) do
    Mix.shell().info("   Health: Performing health check...")

    # Wait for container to be fully up
    max_attempts = 30
    attempt = check_container_health(name, original_ports, 1, max_attempts)

    if attempt <= max_attempts do
      Mix.shell().info("   Success: Health check passed (#{attempt} attempts)")
      {:ok, :healthy}
    else
      Mix.shell().error("   Warning:  Health check timeout")
      {:ok, :restarted_unhealthy}
    end
  end

  @spec check_container_health(term(), term(), integer(), integer()) :: integer()
  defp check_container_health(_name, _original_ports, attempt, max_attempts)
       when attempt > max_attempts do
    attempt
  end

  defp check_container_health(name, original_ports, attempt, max_attempts) do
    # Check if container is running
    case get_container_info(name) do
      {:ok, info} ->
        state = get_in(info, ["State", "Status"])

        if state == "running" do
          # Check if ports are available
          current_ports = get_in(info, ["NetworkSettings", "Ports"]) || %{}

          if map_size(current_ports) >= map_size(original_ports) do
            # Container is healthy
            attempt
          else
            # Ports not ready yet
            Process.sleep(1000)
            check_container_health(name, original_ports, attempt + 1, max_attempts)
          end
        else
          # Container not running yet
          Process.sleep(1000)
          check_container_health(name, original_ports, attempt + 1, max_attempts)
        end

      _ ->
        # Container not found
        Process.sleep(1000)
        check_container_health(name, original_ports, attempt + 1, max_attempts)
    end
  end

  @spec return() :: any()
  defp return, do: :ok
end
