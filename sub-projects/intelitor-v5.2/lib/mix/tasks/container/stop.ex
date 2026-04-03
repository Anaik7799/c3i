defmodule Mix.Tasks.Container.Stop do
  @moduledoc """
  Stops one or more running containers.

  ## Usage

      mix container.stop CONTAINER_NAME [OPTIONS]
      mix container.stop app db redis
      mix container.stop --all

  ## Options

    * `--timeout SECONDS` - Timeout for graceful shutdown (default: 10)
    * `--force` - Force stop containers (SIGKILL)
    * `--all` - Stop all running containers
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Stop single container
      mix container.stop app

      # Stop with custom timeout
      mix container.stop app --timeout 30

      # Force stop
      mix container.stop app --force

      # Stop all containers
      mix container.stop --all

  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Stop running containers"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_stop_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    validate_container_runtime!()

    # Get containers to stop
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
      Mix.shell().info("Info:  No containers to stop")
      return()
    end

    # Stop containers
    container_count = length(containers)

    if container_count > 1 do
      Mix.shell().info("Stopping #{container_count} containers...")
    end

    if opts[:timeout] && opts[:timeout] > 10 do
      Mix.shell().info("Graceful shutdown with #{opts[:timeout]}s timeout")
    end

    results =
      Enum.map(containers, fn name ->
        stop_container(name, opts)
      end)

    # Log to Claude
    ensure_claude_logging("stop", %{
      containers: containers,
      options: opts,
      results: results
    })

    # Notify agents if in agent mode
    if opts[:agent_mode] do
      container_results = Enum.zip(containers, results)

      container_results
      |> Enum.each(fn {name, result} ->
        notify_agent_coordinator("stop", name, result)
      end)
    end

    # Summary
    successful = Enum.count(results, fn {status, _} -> status == :ok end)

    if successful == container_count do
      Mix.shell().info("\nSuccess: All containers stopped successfully")
    else
      __failed = container_count - successful
      Mix.shell().error("\nWarning:  #{successful}/#{container_count} containers stopped")
    end
  end

  @spec parse_stop_options(term()) :: term()
  defp parse_stop_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          timeout: :integer,
          force: :boolean,
          all: :boolean,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          t: :timeout,
          f: :force
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

  @spec stop_container(term(), term()) :: term()
  defp stop_container(name, opts) do
    Mix.shell().info("\nStopping container: #{name}")

    # Check if container exists and is running
    case get_container_info(name) do
      {:ok, info} ->
        state = get_in(info, ["State", "Status"])

        case state do
          "running" ->
            do_stop_container(name, opts)

          _ ->
            Mix.shell().info("   Info:  Container not running")
            {:ok, :not_running}
        end

      {:error, :not_found} ->
        Mix.shell().error("   Error: Container not found: #{name}")
        {:error, :not_found}
    end
  end

  @spec do_stop_container(term(), term()) :: term()
  defp do_stop_container(name, opts) do
    base_args = ["stop"]

    # Add timeout
    args_with_timeout =
      if opts[:timeout] do
        base_args ++ ["--timeout", to_string(opts[:timeout])]
      else
        base_args
      end

    args = args_with_timeout ++ [name]

    if opts[:force] do
      Mix.shell().info("   Fast: Force stopping container...")
    else
      Mix.shell().info("   Reload: Stopping container gracefully...")
    end

    case run_podman_command(args, []) do
      :ok ->
        Mix.shell().info("   Success: Container stopped successfully")
        {:ok, :stopped}

      {:error, code} ->
        if opts[:force] do
          # Try kill if stop failed
          Mix.shell().info("   Fast: Force killing container...")

          case run_podman_command(["kill", name], []) do
            :ok ->
              Mix.shell().info("   Success: Container killed successfully")
              {:ok, :killed}

            {:error, _} ->
              Mix.shell().error("   Error: Failed to kill container")
              {:error, :kill_failed}
          end
        else
          Mix.shell().error("   Error: Failed to stop container (exit code: #{code})")
          Mix.shell().info("   Info: Hint: Try --force flag to force stop")
          {:error, :stop_failed}
        end
    end
  end

  @spec return() :: any()
  defp return, do: :ok
end
