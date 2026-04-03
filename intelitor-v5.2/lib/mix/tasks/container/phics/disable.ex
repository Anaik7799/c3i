defmodule Mix.Tasks.Container.Phics.Disable do
  @moduledoc """
  Disables PHICS hot - reloading for containers.

  This command deactivates the Phoenix Hot - Reloading Integration Container System
  for the specified containers, stopping file synchronization and code reloading.

  ## Usage

      mix container.phics.disable CONTAINER_NAME [OPTIONS]
      mix container.phics.disable app
      mix container.phics.disable --all

  ## Options

    * `--all` - Disable PHICS for all containers
    * `--force` - Force disable even if processes are running
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Disable PHICS for app container
      mix container.phics.disable app

      # Disable PHICS for all containers
      mix container.phics.disable --all

      # Force disable with cleanup
      mix container.phics.disable app --force

  Created: 2025 - 08 - 05 17:31:00 CEST
  Framewor,k: SOPv5.1 + PHICS Container Management
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Disable PHICS hot - reloading for containers"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_disable_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    validate_container_runtime!()

    # Get containers to disable
    containers =
      if opts[:all] do
        get_phics_enabled_containers()
      else
        if container_names == [] do
          Mix.raise("Error: Container name __required or use --all flag")
        end

        container_names
      end

    if containers == [] do
      Mix.shell().info("Info:  No PHICS - enabled containers found")
      return()
    end

    # Disable PHICS for each container
    results =
      Enum.map(containers, fn name ->
        disable_phics(name, opts)
      end)

    # Log to Claude
    ensure_claude_logging("phics_disable", %{
      containers: containers,
      options: opts,
      results: results
    })

    # Summary
    successful = Enum.count(results, fn {status, _} -> status == :ok end)

    if successful == length(containers) do
      Mix.shell().info("\nSuccess: PHICS disabled for all containers")
    else
      Mix.shell().error(
        "\nWarning: PHICS disabled for #{successful}/#{length(containers)} containers"
      )
    end
  end

  @spec parse_disable_options(term()) :: term()
  defp parse_disable_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          all: :boolean,
          force: :boolean,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          a: :all,
          f: :force
        ]
      )

    {opts, remaining_args}
  end

  @spec get_phics_enabled_containers() :: any()
  def get_phics_enabled_containers() do
    # Find all containers with PHICS state files
    case File.ls("./__data / tmp") do
      {:ok, files} ->
        files
        |> Enum.filter(&String.starts_with?(&1, "phics_state_"))
        |> Enum.map(fn file ->
          file
          |> String.replace_prefix("phics_state_", "")
          |> String.replace_suffix(".json", "")
        end)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  @spec disable_phics(term(), term()) :: term()
  defp disable_phics(name, opts) do
    Mix.shell().info("\n🔥 Disabling PHICS hot - reloading for: #{name}")

    # Check if container exists
    case get_container_info(name) do
      {:ok, info} ->
        # Check if PHICS is enabled
        state_file = "./__data / tmp / phics_state_#{name}.json"

        if File.exists?(state_file) do
          do_disable_phics(name, info, opts)
        else
          Mix.shell().info("   Info:  PHICS not enabled for this container")
          {:ok, :not_enabled}
        end

      {:error, :not_found} ->
        Mix.shell().error("   Error: Container not found: #{name}")
        # Clean up state file if it exists
        cleanup_phics_state(name)
        {:error, :not_found}
    end
  end

  defp do_disable_phics(name, _info, opts) do
    Mix.shell().info("   🔍 Checking PHICS processes...")

    # Kill any running PHICS processes (always succeeds)
    :ok = kill_phics_processes(name, opts[:force])
    Mix.shell().info("   Success: PHICS processes stopped")

    # Remove PHICS configuration from container
    Mix.shell().info("   Clean: Cleaning up PHICS configuration...")
    cleanup_container_phics(name)

    # Remove state file
    cleanup_phics_state(name)

    Mix.shell().info("   Success: PHICS disabled successfully")
    Mix.shell().info("   🔒 Hot - reloading deactivated")
    Mix.shell().info("   📁 File sync stopped")

    {:ok, :disabled}
  end

  @spec kill_phics_processes(term(), term()) :: term()
  defp kill_phics_processes(name, force?) do
    # Check for running watcher process
    case run_podman_command(["exec", name, "pgrep", "-f", "phics_watcher"], into: "") do
      {output, 0} ->
        pids = String.split(String.trim(output), "\n")

        # Kill processes
        signal = if force?, do: "-9", else: "-15"

        Enum.each(pids, fn pid ->
          run_podman_command(["exec", name, "kill", signal, pid], into: "")
        end)

        :ok

      _ ->
        # No processes found
        :ok
    end
  end

  @spec cleanup_container_phics(term()) :: term()
  defp cleanup_container_phics(name) do
    # Remove PHICS files from container
    phics_files = [
      "/tmp / phicsconfig.json",
      "/tmp / phics_watcher.sh",
      "/tmp / phics_sync.lock"
    ]

    Enum.each(phics_files, fn file ->
      run_podman_command(["exec", name, "rm", "-f", file], into: "")
    end)
  end

  @spec cleanup_phics_state(term()) :: term()
  defp cleanup_phics_state(name) do
    state_file = "./__data / tmp / phics_state_#{name}.json"
    File.rm(state_file)
  end

  @spec return() :: any()
  defp return, do: :ok
end
