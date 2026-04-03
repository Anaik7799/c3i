defmodule Mix.Tasks.Container.Status do
  @moduledoc """

  Shows the status of containers.

  ## Usage

      mix container.status [CONTAINER_NAME] [OPTIONS]
      mix container.status
      mix container.status app

  ## Options

    * `--all`-Show all containers including stopped ones
    * `--json`-Output in JSON format
    * `--verbose`-Show detailed information
    * `--agent-mode`-Enable agent coordination

  ## Examples

      # Show all running containers
      mix container.status

      # Show specific container status
      mix container.status app

      # Show all containers including stopped
      mix container.status --all

      # Get JSON output for automation
      mix container.status --json

  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Show container status"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_common_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    validate_container_runtime!()

    # Get container __data
    containers =
      if container_names == [] do
        get_all_containers(opts[:all])
      else
        get_specific_containers(container_names)
      end

    if containers == [] do
      Mix.shell().info("Info:  No containers found")
      return()
    end

    # Log to Claude
    ensure_claude_logging("status", %{
      containers: length(containers),
      options: opts
    })

    # Output results
    if opts[:json] do
      output_json(containers)
    else
      output_table(containers, opts[:verbose])
    end

    # Notify agents if in agent mode
    if opts[:agent_mode] do
      notify_agent_coordinator("status", "all", {:ok, length(containers)})
    end
  end

  @spec get_all_containers(term()) :: term()
  defp get_all_containers(all?) do
    filter = if all?, do: [], else: ["--filter", "status = running"]

    case System.cmd("podman", ["ps", "--format", "json"] ++ filter, stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, containers} -> format_containers(containers)
          _ -> []
        end

      _ ->
        []
    end
  end

  @spec get_specific_containers(term()) :: term()
  defp get_specific_containers(names) do
    names
    |> Enum.map(fn name ->
      case get_container_info(name) do
        {:ok, info} -> format_container_info(info)
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @spec format_containers(term()) :: term()
  defp format_containers(containers) do
    Enum.map(containers, &format_container/1)
  end

  @spec format_container(term()) :: term()
  defp format_container(container) do
    %{
      name: get_name(container),
      id: String.slice(container["Id"] || "", 0, 12),
      image: container["Image"],
      status: container["Status"],
      state: container["State"],
      created: format_time(container["Created"]),
      ports: format_container_ports(container["Ports"]),
      cpu: "N / A",
      memory: "N / A",
      uptime: calculate_uptime(container)
    }
  end

  @spec format_container_info(term()) :: term()
  defp format_container_info(info) do
    %{
      name: info["Name"] |> String.trim_leading("/"),
      id: String.slice(info["Id"], 0, 12),
      image: info["Config"]["Image"],
      status: get_in(info, ["State", "Status"]),
      state: get_in(info, ["State", "Status"]),
      created: format_time(info["Created"]),
      ports: format_ports_from_info(info),
      cpu: "N / A",
      memory: "N / A",
      uptime: calculate_uptime_from_info(info)
    }
  end

  @spec get_name(term()) :: term()
  defp get_name(container) do
    case container["Names"] do
      [name | _] -> name
      _ -> container["Name"] || "unknown"
    end
  end

  @spec format_container_ports(term()) :: term()
  defp format_container_ports(nil), do: "-"
  defp format_container_ports([]), do: "-"

  defp format_container_ports(ports) when is_list(ports) do
    ports
    |> Enum.map(&format_port/1)
    |> Enum.filter(& &1)
    |> Enum.join(", ")
    |> case do
      "" -> "-"
      formatted -> formatted
    end
  end

  @spec format_port(map()) :: term()
  defp format_port(%{"host Port" => host, "container Port" => container}) do
    "#{host}->#{container}"
  end

  @spec format_port(term()) :: term()
  defp format_port(_), do: nil

  defp format_ports_from_info(info) do
    ports = get_in(info, ["Network Settings", "Ports"]) || %{}

    ports
    |> Enum.map(fn {container_port, bindings} ->
      case bindings do
        [%{"Host Port" => host_port} | _] -> "#{host_port}->#{container_port}"
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.join(", ")
    |> case do
      "" -> "-"
      formatted -> formatted
    end
  end

  @spec format_time(term()) :: term()
  defp format_time(nil), do: "unknown"

  defp format_time(time) when is_integer(time) do
    # Unix timestamp
    datetime = DateTime.from_unix!(time)
    DateTime.to_string(datetime)
  end

  @spec format_time(term()) :: term()
  defp format_time(time) when is_binary(time) do
    # ISO 8601 or other string format
    case DateTime.from_iso8601(time) do
      {:ok, datetime, _} ->
        Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

      _ ->
        time
    end
  end

  @spec calculate_uptime(map()) :: term()
  defp calculate_uptime(%{"Status" => status}) when is_binary(status) do
    # Extract uptime from status string like "Up 2 hours"
    case Regex.run(~r/Up\s+(.+)/, status) do
      [_, uptime] -> uptime
      _ -> "-"
    end
  end

  @spec calculate_uptime(term()) :: term()
  defp calculate_uptime(_), do: "-"

  defp calculate_uptime_from_info(info) do
    case get_in(info, ["State", "Started At"]) do
      nil ->
        "-"

      started ->
        case DateTime.from_iso8601(started) do
          {:ok, start_time, _} ->
            diff = DateTime.diff(DateTime.utc_now(), start_time)
            format_duration(diff)

          _ ->
            "-"
        end
    end
  end

  @spec format_duration(term()) :: term()
  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    "#{minutes}m"
  end

  @spec format_duration(term()) :: term()
  defp format_duration(seconds) when seconds < 86_400 do
    hours = div(seconds, 3600)
    "#{hours}h"
  end

  @spec format_duration(term()) :: term()
  defp format_duration(seconds) do
    days = div(seconds, 86_400)
    "#{days}d"
  end

  @spec output_json(term()) :: term()
  defp output_json(containers) do
    json = Jason.encode!(%{containers: containers}, pretty: true)
    IO.puts(json)
  end

  @spec output_table(term(), term()) :: term()
  defp output_table(containers, verbose?) do
    Mix.shell().info("\n[STATS] Container Status Report")
    Mix.shell().info("=" |> String.duplicate(80))

    headers =
      if verbose? do
        ["Name", "ID", "Image", "Status", "Uptime", "Ports", "CPU", "Memory"]
      else
        ["Name", "Status", "Uptime", "Ports"]
      end

    rows =
      Enum.map(containers, fn c ->
        if verbose? do
          [c.name, c.id, c.image, c.status, c.uptime, c.ports, c.cpu, c.memory]
        else
          [c.name, c.status, c.uptime, c.ports]
        end
      end)

    table = format_table(rows, headers)
    Mix.shell().info(table)

    # Summary
    running = Enum.count(containers, fn c -> c.state == "running" end)
    total = length(containers)
    Mix.shell().info("\n📈 Summary: #{running} running, #{total - running} stopped")
  end

  @spec return() :: any()
  defp return, do: :ok
end
