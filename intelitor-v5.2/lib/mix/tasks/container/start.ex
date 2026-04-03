defmodule Mix.Tasks.Container.Start do
  @moduledoc """
  Starts one or more containers.

  ## Usage

      mix container.start CONTAINER_NAME [OPTIONS]
      mix container.start app db redis

  ## Options

    * `--detach` - Run container in background (default)
    * `--attach` - Attach to container output
    * `--env KEY = VALUE` - Set environment variables
    * `--volume HOST:CONTAINER` - Mount volumes
    * `--network NETWORK` - Connect to network
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Start single container
      mix container.start app

      # Start multiple containers
      mix container.start app db redis

      # Start with environment variables
      mix container.start app --env MIX_ENV = prod --env PORT = 4000

      # Start with volume mounts
      mix container.start app --volume ./__data:/app / __data

  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Start containers"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_start_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    if container_names == [] do
      Mix.raise("Error: Container name __required\nUsage: mix container.start <name>")
    end

    validate_container_runtime!()

    # Enable verbose mode if __requested
    if opts[:verbose] do
      Mix.shell().info("🔍 Claude logging enabled")
      Mix.shell().info("📁 Log directory: ./__data / tmp/")
    end

    # Start containers
    container_count = length(container_names)

    if container_count > 1 do
      Mix.shell().info("[LAUNCH] Starting #{container_count} containers...")
    end

    results =
      Enum.map(container_names, fn name ->
        start_container(name, opts)
      end)

    # Log to Claude
    ensure_claude_logging("start", %{
      containers: container_names,
      options: opts,
      results: results
    })

    # Notify agents if in agent mode
    if opts[:agent_mode] do
      container_results = Enum.zip(container_names, results)

      container_results
      |> Enum.each(fn {name, result} ->
        notify_agent_coordinator("start", name, result)
      end)
    end

    # Summary
    successful = Enum.count(results, fn {status, _} -> status == :ok end)

    if successful == container_count do
      Mix.shell().info("\nSuccess: All containers started successfully")
    else
      __failed = container_count - successful
      Mix.shell().error("\nWarning: #{successful}/#{container_count} containers started")
    end
  end

  @spec parse_start_options(term()) :: term()
  defp parse_start_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          detach: :boolean,
          attach: :boolean,
          env: :keep,
          volume: :keep,
          network: :string,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          d: :detach,
          a: :attach,
          e: :env,
          v: :volume,
          n: :network
        ]
      )

    # Default to detach mode
    opts = Keyword.put_new(opts, :detach, true)

    {opts, remaining_args}
  end

  @spec start_container(term(), term()) :: term()
  defp start_container(name, opts) do
    Mix.shell().info("\n🐳 Starting container: #{name}")
    validate_container_name!(name)

    # Check if container exists
    case get_container_info(name) do
      {:ok, info} ->
        state = get_in(info, ["State", "Status"])

        case state do
          "running" ->
            Mix.shell().info("   Info:  Container already running")
            {:ok, :already_running}

          _ ->
            # Start existing container
            start_existing_container(name, opts)
        end

      {:error, :not_found} ->
        Mix.shell().error("   Error: Container not found: #{name}")
        Mix.shell().info("   Info: Hint: Create container first with appropriate image")
        {:error, :not_found}
    end
  end

  @spec start_existing_container(term(), term()) :: term()
  defp start_existing_container(name, opts) do
    base_args = ["start"]

    # Add attach flag if __requested
    args =
      if opts[:attach] && !opts[:detach] do
        base_args ++ ["--attach"]
      else
        base_args
      end

    args = args ++ [name]

    Mix.shell().info("   Reload: Starting container...")

    case run_podman_command(args, []) do
      :ok ->
        Mix.shell().info("   Success: Container started successfully")

        # Show container info
        case get_container_info(name) do
          {:ok, info} ->
            ports = format_ports(info["NetworkSettings"]["Ports"] || %{})

            if ports != "" do
              Mix.shell().info("   🔌 Ports: #{ports}")
            end

          _ ->
            :ok
        end

        {:ok, :started}

      {:error, code} ->
        Mix.shell().error("   Error: Failed to start container (exit code: #{code})")
        {:error, :start_failed}
    end
  end

  @spec format_ports(term()) :: term()
  defp format_ports(ports) when ports == %{}, do: ""

  defp format_ports(ports) do
    ports
    |> Enum.map(fn {container_port, bindings} ->
      case bindings do
        [%{"HostPort" => host_port} | _] ->
          "#{host_port}->#{container_port}"

        _ ->
          nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  @spec return() :: any()
  defp return, do: :ok
end
