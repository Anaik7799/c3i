defmodule Mix.Tasks.Container.Phics.Status do
  @moduledoc """
  Shows PHICS hot - reloading status for containers.

  Displays detailed information about the Phoenix Hot - Reloading Integration
  Container System status for specified containers.

  ## Usage

      mix container.phics.status [CONTAINER_NAME]
      mix container.phics.status
      mix container.phics.status app

  ## Options

    * `--json` - Output in JSON format
    * `--verbose` - Show detailed configuration
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Show PHICS status for all containers
      mix container.phics.status

      # Show PHICS status for specific container
      mix container.phics.status app

      # Get JSON output for automation
      mix container.phics.status --json

  Created: 2025 - 08 - 05 17:34:00 CEST
  Framework: SOPv5.1 + PHICS Container Management
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Show PHICS hot - reloading status"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_common_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    validate_container_runtime!()

    # Get containers to check
    containers =
      if container_names == [] do
        get_all_containers_with_phics()
      else
        container_names
      end

    if containers == [] do
      Mix.shell().info("Info:  No containers to check")
      return()
    end

    # Get PHICS status for each container
    statuses =
      Enum.map(containers, fn name ->
        get_phics_status(name, opts)
      end)

    # Log to Claude
    ensure_claude_logging("phics_status", %{
      containers: containers,
      options: opts,
      statuses: statuses
    })

    # Output results
    if opts[:json] do
      output_json_status(statuses)
    else
      output_table_status(statuses, opts[:verbose])
    end
  end

  @spec get_all_containers_with_phics() :: any()
  def get_all_containers_with_phics() do
    # Get all running containers
    case System.cmd("podman", ["ps", "--format", "{{.Names}}"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.filter(&(&1 != ""))

      _ ->
        []
    end
  end

  @spec get_phics_status(term(), term()) :: term()
  defp get_phics_status(name, _opts) do
    base_status = %{
      name: name,
      enabled: false,
      status: "disabled",
      sync_dir: nil,
      watch_dirs: [],
      exclude_patterns: [],
      setup_time: nil,
      processes: [],
      file_changes: 0
    }

    state_file = "./__data / tmp / phics_state_#{name}.json"

    if File.exists?(state_file) do
      load_phics_status_from_file(base_status, name, state_file)
    else
      check_phics_container_status(base_status, name)
    end
  end

  @spec load_phics_status_from_file(map(), String.t(), String.t()) :: map()
  defp load_phics_status_from_file(base_status, name, state_file) do
    case File.read(state_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, state} ->
            merge_phics_state(base_status, name, state)

          _ ->
            base_status
        end

      _ ->
        base_status
    end
  end

  @spec merge_phics_state(map(), String.t(), map()) :: map()
  defp merge_phics_state(base_status, name, state) do
    case get_container_info(name) do
      {:ok, _info} ->
        processes = check_phics_processes(name)

        Map.merge(base_status, %{
          enabled: true,
          status: if(processes != [], do: "active", else: "inactive"),
          sync_dir: state["sync_dir"],
          watch_dirs: state["watch_dirs"] || [],
          exclude_patterns: state["exclude_patterns"] || [],
          setup_time: state["setup_time"],
          processes: processes
        })

      {:error, :not_found} ->
        Map.merge(base_status, %{status: "container_not_found"})
    end
  end

  @spec check_phics_container_status(map(), String.t()) :: map()
  defp check_phics_container_status(base_status, name) do
    case get_container_info(name) do
      {:ok, _} ->
        base_status

      {:error, :not_found} ->
        Map.merge(base_status, %{status: "container_not_found"})
    end
  end

  @spec check_phics_processes(term()) :: term()
  defp check_phics_processes(name) do
    case run_podman_command(["exec", name, "ps", "aux"], into: "") do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, "phics"))
        |> Enum.map(fn line ->
          parts = String.split(line)

          %{
            pid: Enum.at(parts, 1),
            cpu: Enum.at(parts, 2),
            mem: Enum.at(parts, 3),
            command: parts |> Enum.drop(10) |> Enum.join(" ")
          }
        end)

      _ ->
        []
    end
  end

  @spec output_json_status(term()) :: term()
  defp output_json_status(statuses) do
    json = Jason.encode!(%{phics_status: statuses}, pretty: true)
    IO.puts(json)
  end

  @spec output_table_status(term(), term()) :: term()
  defp output_table_status(statuses, verbose?) do
    Mix.shell().info("\n🔥 PHICS Hot - Reloading Status")
    Mix.shell().info("=" |> String.duplicate(80))

    Enum.each(statuses, fn status ->
      output_container_status(status, verbose?)
    end)

    # Summary
    enabled = Enum.count(statuses, fn s -> s.enabled end)
    active = Enum.count(statuses, fn s -> s.status == "active" end)
    total = length(statuses)

    Mix.shell().info("\n[STATS] Summary: #{enabled} enabled, #{active} active (#{total} total)")
  end

  @spec output_container_status(term(), term()) :: term()
  defp output_container_status(status, verbose?) do
    Mix.shell().info("\n🐳 Container: #{status.name}")

    status_icon =
      case status.status do
        "active" -> "Success:"
        "inactive" -> "Warning:"
        "disabled" -> "🔒"
        "container_not_found" -> "Error:"
        _ -> "❓"
      end

    Mix.shell().info("   Status: #{status_icon} #{status.status}")

    if status.enabled do
      output_enabled_phics_status(status, verbose?)
    else
      Mix.shell().info("   PHICS: 🔒 Disabled")
    end
  end

  @spec output_enabled_phics_status(term(), term()) :: term()
  defp output_enabled_phics_status(status, verbose?) do
    Mix.shell().info("   PHICS: 🔥 Enabled")

    if status.sync_dir do
      Mix.shell().info("   Sync: #{status.sync_dir}")
    end

    if verbose? do
      output_phics_verbose_details(status)
    end
  end

  @spec output_phics_verbose_details(term()) :: term()
  defp output_phics_verbose_details(status) do
    if status.watch_dirs != [] do
      Mix.shell().info("   Watching: #{Enum.join(status.watch_dirs, ", ")}")
    end

    if status.exclude_patterns != [] do
      Mix.shell().info("   Excluding: #{Enum.join(status.exclude_patterns, ", ")}")
    end

    if status.setup_time do
      Mix.shell().info("   Setup: #{format_datetime(status.setup_time)}")
    end

    if status.processes != [] do
      Mix.shell().info("   Processes:")

      Enum.each(status.processes, fn proc ->
        Mix.shell().info("     - PID #{proc.pid}: #{proc.command}")
      end)
    end
  end

  @spec format_datetime(term()) :: term()
  defp format_datetime(nil), do: "unknown"

  defp format_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} ->
        Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")

      _ ->
        datetime_string
    end
  end

  @spec return() :: any()
  defp return, do: :ok
end
