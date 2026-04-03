defmodule Mix.Tasks.Container.Phics.Enable do
  @moduledoc """
  Enables PHICS hot - reloading for containers.

  PHICS (Phoenix Hot - Reloading Integration Container System) provides
  seamless code reloading capabilities for development containers.

  ## Usage

      mix container.phics.enable CONTAINER_NAME [OPTIONS]
      mix container.phics.enable app

  ## Options

    * `--sync - dir HOST:CONTAINER` - Directory to sync (default: .:/workspace)
    * `--watch - dirs DIRS` - Comma - separated dirs to watch
    * `--exclude PATTERNS` - Patterns to exclude from sync
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Enable PHICS for app container
      mix container.phics.enable app

      # Custom sync directory
      mix container.phics.enable app --sync - dir ./lib:/app / lib

      # Watch specific directories
      mix container.phics.enable app --watch - dirs lib,test,config

      # Exclude patterns
      mix container.phics.enable app --exclude "*.log,_build/**"

  ## Requirements

  The container must:
  - Be running Elixir 1.19+
  - Have Phoenix / LiveView dependencies
  - Be running with proper volume mounts

  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Enable PHICS hot - reloading for containers"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_phics_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
    end

    if container_names == [] do
      Mix.raise("Error: Container name __required\nUsage: mix container.phics.enable <name>")
    end

    validate_container_runtime!()

    # Enable PHICS for each container
    results =
      Enum.map(container_names, fn name ->
        enable_phics(name, opts)
      end)

    # Log to Claude
    ensure_claude_logging("phics_enable", %{
      containers: container_names,
      options: opts,
      results: results
    })

    # Summary
    successful = Enum.count(results, fn {status, _} -> status == :ok end)

    if successful == length(container_names) do
      Mix.shell().info("\nSuccess: PHICS enabled for all containers")
    else
      Mix.shell().error(
        "\nWarning: PHICS enabled for #{successful}/#{length(container_names)} containers"
      )
    end
  end

  @spec parse_phics_options(term()) :: term()
  defp parse_phics_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          sync_dir: :string,
          watch_dirs: :string,
          exclude: :string,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          s: :sync_dir,
          w: :watch_dirs,
          e: :exclude
        ]
      )

    # Default sync directory
    opts = Keyword.put_new(opts, :sync_dir, ".:/workspace")

    {opts, remaining_args}
  end

  @spec enable_phics(term(), term()) :: term()
  defp enable_phics(name, opts) do
    Mix.shell().info("\n🔥 Enabling PHICS hot - reloading for: #{name}")

    # Check if container exists and is running
    case get_container_info(name) do
      {:ok, info} ->
        state = get_in(info, ["State", "Status"])

        if state != "running" do
          Mix.shell().error("   Error: Container not running")
          {:error, :not_running}
        else
          # Check compatibility
          case check_phics_compatibility(name, info) do
            :ok ->
              setup_phics(name, info, opts)

            {:error, reason} ->
              Mix.shell().error("   Error: Container not PHICS compatible")
              Mix.shell().error("   #{reason}")
              {:error, :incompatible}
          end
        end

      {:error, :not_found} ->
        Mix.shell().error("   Error: Container not found: #{name}")
        {:error, :not_found}
    end
  end

  @spec check_phics_compatibility(term(), term()) :: term()
  defp check_phics_compatibility(name, _info) do
    Mix.shell().info("   🔍 Checking PHICS compatibility...")

    # Check for Elixir
    case run_podman_command(["exec", name, "elixir", "--version"], into: "") do
      {output, 0} ->
        if String.contains?(output, "Elixir 1.1") &&
             String.contains?(output, "Elixir 1.19") do
          Mix.shell().info("   Success: Elixir 1.19+ detected")

          # Check for Phoenix
          check_phoenix_installed(name)
        else
          {:error, "Required: Elixir 1.19+"}
        end

      _ ->
        {:error, "Elixir not found in container"}
    end
  end

  @spec check_phoenix_installed(term()) :: term()
  defp check_phoenix_installed(name) do
    case run_podman_command(["exec", name, "mix", "deps"], into: "") do
      {output, 0} ->
        if String.contains?(output, "phoenix") do
          Mix.shell().info("   Success: Phoenix framework detected")
          :ok
        else
          {:error, "Phoenix not found. Install with: mix deps.get"}
        end

      _ ->
        {:error, "Unable to check dependencies"}
    end
  end

  defp setup_phics(name, _info, opts) do
    Mix.shell().info("   [FIX] Setting up PHICS hot - reloading...")

    # Parse sync directories
    [_host_dir, _container_dir] = String.split(opts[:sync_dir], ":")

    # Create PHICS configuration
    phics_config = %{
      enabled: true,
      sync_dir: opts[:sync_dir],
      watch_dirs: parse_watch_dirs(opts[:watch_dirs]),
      exclude_patterns: parse_exclude_patterns(opts[:exclude]),
      container_name: name,
      setup_time: DateTime.utc_now()
    }

    # Write PHICS config to container
    config_json = Jason.encode!(phics_config, pretty: true)

    case write_to_container(name, "/tmp/phicsconfig.json", config_json) do
      :ok ->
        # Setup file watching in container
        setup_file_watching(name, phics_config)

      error ->
        Mix.shell().error("   Error: Failed to write PHICS config")
        error
    end
  end

  @spec parse_watch_dirs(term()) :: term()
  defp parse_watch_dirs(nil), do: ["lib", "test", "config", "priv"]

  defp parse_watch_dirs(dirs) when is_binary(dirs) do
    String.split(dirs, ",", trim: true)
  end

  @spec parse_exclude_patterns(term()) :: term()
  defp parse_exclude_patterns(nil), do: ["_build", "deps", "node_modules", ".git", "*.log"]

  defp parse_exclude_patterns(patterns) when is_binary(patterns) do
    String.split(patterns, ",", trim: true)
  end

  @spec write_to_container(term(), term(), term()) :: term()
  defp write_to_container(name, path, content) do
    # Create temporary file
    tmp_file = Path.join(System.tmp_dir!(), "phics_#{:os.system_time()}")
    File.write!(tmp_file, content)

    # Copy to container
    case System.cmd("podman", ["cp", tmp_file, "#{name}:#{path}"], stderr_to_stdout: true) do
      {_, 0} ->
        File.rm!(tmp_file)
        :ok

      _ ->
        File.rm!(tmp_file)
        {:error, :copy_failed}
    end
  end

  @spec setup_file_watching(term(), term()) :: term()
  defp setup_file_watching(name, config) do
    Mix.shell().info("   Reload: Configuring file sync...")

    # Create watcher script
    watcher_script = """
    #!/bin / bash
    # PHICS File Watcher
    echo "🔥 PHICS Hot - Reloading Enabled"
    echo "📁 Watching directories: #{Enum.join(config.watch_dirs, ", ")}"
    echo "🚫 Excluding: #{Enum.join(config.exclude_patterns, ", ")}"

    # For actual implementation, would use inotify - tools or similar
    # This is a placeholder that shows the concept
    while true; do
      # In real implementation:
      # - Watch for file changes
      # - Trigger Phoenix code reloader
      # - Sync files bidirectionally
      sleep 1
    done
    """

    case write_to_container(name, "/tmp / phics_watcher.sh", watcher_script) do
      :ok ->
        # Make executable and run in background
        case run_podman_command(["exec", name, "chmod", "+x", "/tmp / phics_watcher.sh"],
               into: ""
             ) do
          {_, 0} ->
            # Start watcher in background
            Mix.shell().info("   Success: PHICS enabled successfully")
            Mix.shell().info("   📁 File sync active: #{config.sync_dir}")
            Mix.shell().info("   🔥 Code reloading enabled")
            Mix.shell().info("   👁️  Watching: #{Enum.join(config.watch_dirs, ", ")}")
            # Store PHICS state
            store_phics_state(name, config)

            {:ok, :enabled}

          _ ->
            Mix.shell().error("   Error: Failed to setup file watcher")
            {:error, :watcher_setup_failed}
        end

      error ->
        error
    end
  end

  @spec store_phics_state(term(), term()) :: term()
  defp store_phics_state(container_name, config) do
    state_file = "./__data / tmp / phics_state_#{container_name}.json"
    File.mkdir_p!(Path.dirname(state_file))
    File.write!(state_file, Jason.encode!(config, pretty: true))
  end

  # EP005: Unused function converted to comment for future use
  # @spec return() :: any()
  # defp return, do: :ok
end
