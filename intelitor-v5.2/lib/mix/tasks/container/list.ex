defmodule Mix.Tasks.Container.List do
  @moduledoc """
  Lists containers with filtering options.

  Provides a comprehensive view of containers with support for filtering
  by status, name patterns, labels, and other criteria.

  ## Usage

      mix container.list [OPTIONS]
      mix container.list
      mix container.list --running

  ## Options

    * `--all` - Show all containers (default shows only running)
    * `--running` - Show only running containers
    * `--stopped` - Show only stopped containers
    * `--filter KEY = VALUE` - Filter containers (status, name, label)
    * `--format FORMAT` - Output format (table, json, yaml)
    * `--quiet` - Only display container names
    * `--verbose` - Show detailed information
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # List all running containers
      mix container.list

      # List all containers including stopped
      mix container.list --all

      # Filter by name pattern
      mix container.list --filter name = app*

      # Get JSON output
      mix container.list --format json

  Created: 2025 - 08 - 05 17:51:00 CEST
  Framewor,k: SOPv5.1 + Container Listing
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "List containers with filtering"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, _} = parse_list_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    validate_container_runtime!()

    # Get containers based on filters
    containers = get_filtered_containers(opts)

    # Log to Claude
    ensure_claude_logging("list", %{
      options: opts,
      container_count: length(containers)
    })

    # Output results
    output_containers(containers, opts)
  end

  @spec parse_list_options(term()) :: term()
  defp parse_list_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          all: :boolean,
          running: :boolean,
          stopped: :boolean,
          filter: :keep,
          format: :string,
          quiet: :boolean,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          a: :all,
          f: :filter,
          q: :quiet
        ]
      )

    # Default format
    opts = Keyword.put_new(opts, :format, "table")

    {opts, remaining_args}
  end

  @spec get_filtered_containers(term()) :: term()
  defp get_filtered_containers(opts) do
    # Build podman ps command
    ps_args = build_ps_command(opts)

    case System.cmd("podman", ps_args, stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, containers} ->
            containers
            |> apply_additional_filters(opts)
            |> format_container_data(opts)

          _ ->
            []
        end

      _ ->
        []
    end
  end

  @spec build_ps_command(term()) :: term()
  defp build_ps_command(opts) do
    args = ["ps", "--format", "json"]

    # Add all flag
    cond do
      opts[:all] ->
        args ++ ["--all"]

      opts[:stopped] ->
        args ++ ["--all", "--filter", "status = exited"]

      opts[:running] || true ->
        args ++ ["--filter", "status = running"]
    end
  end

  @spec apply_additional_filters(term(), term()) :: term()
  defp apply_additional_filters(containers, opts) do
    filters = Keyword.get_values(opts, :filter)

    Enum.reduce(filters, containers, fn filter, acc ->
      apply_single_filter(acc, filter)
    end)
  end

  @spec apply_single_filter(term(), term()) :: term()
  defp apply_single_filter(containers, filter) do
    case String.split(filter, "=", parts: 2) do
      ["name", pattern] ->
        regex = glob_to_regex(pattern)

        Enum.filter(containers, fn c ->
          name = get_container_name(c)
          Regex.match?(regex, name)
        end)

      ["label", label_filter] ->
        Enum.filter(containers, fn c ->
          labels = c["Labels"] || %{}
          check_label_filter(labels, label_filter)
        end)

      _ ->
        containers
    end
  end

  @spec glob_to_regex(term()) :: term()
  defp glob_to_regex(pattern) do
    replaced_star = String.replace(pattern, "*", ".*")
    replaced_all = String.replace(replaced_star, "?", ".")
    with_anchors = (fn p -> "^#{p}$" end).(replaced_all)
    Regex.compile!(with_anchors)
  end

  @spec check_label_filter(term(), term()) :: term()
  defp check_label_filter(labels, filter) do
    case String.split(filter, "=", parts: 2) do
      [key, value] ->
        labels[key] == value

      [key] ->
        Map.has_key?(labels, key)
    end
  end

  @spec get_container_name(term()) :: term()
  defp get_container_name(container) do
    case container["Names"] do
      [name | _] -> name
      _ -> container["Name"] || "unknown"
    end
  end

  @spec format_container_data(term(), term()) :: term()
  defp format_container_data(containers, opts) do
    Enum.map(containers, fn container ->
      base_data = %{
        "id" => String.slice(container["Id"] || "", 0, 12),
        "name" => get_container_name(container),
        "image" => container["Image"],
        "command" => format_command(container["Command"]),
        "created" => format_created(container["Created"]),
        "status" => container["Status"],
        "state" => container["State"],
        "ports" => format_ports(container["Ports"]),
        "size" => container["Size"] || "N / A"
      }

      if opts[:verbose] do
        Map.merge(base_data, %{
          "labels" => container["Labels"] || %{},
          "mounts" => format_mounts(container["Mounts"]),
          "networks" => get_networks(container)
        })
      else
        base_data
      end
    end)
  end

  @spec format_command(term()) :: term()
  defp format_command(nil), do: "N / A"

  defp format_command(cmd) when is_binary(cmd) do
    if String.length(cmd) > 20 do
      String.slice(cmd, 0, 20) <> "..."
    else
      cmd
    end
  end

  @spec format_created(term()) :: term()
  defp format_created(nil), do: "unknown"

  defp format_created(created) when is_integer(created) do
    # Unix timestamp
    dt = DateTime.from_unix!(created)
    dt |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  defp format_created(created), do: created

  defp format_ports(nil), do: []
  @spec format_ports(term()) :: term()
  defp format_ports(ports) when is_list(ports) do
    port_list =
      Enum.map(ports, fn port ->
        host = port["hostPort"] || port["HostPort"]
        container = port["containerPort"] || port["ContainerPort"]

        if host && container do
          "#{host}->#{container}"
        else
          nil
        end
      end)

    port_list |> Enum.filter(& &1)
  end

  @spec format_mounts(term()) :: term()
  defp format_mounts(nil), do: []

  defp format_mounts(mounts) when is_list(mounts) do
    Enum.map(mounts, fn mount ->
      "#{mount["Source"]}:#{mount["Destination"]}"
    end)
  end

  @spec get_networks(term()) :: term()
  defp get_networks(container) do
    case container["NetworkMode"] do
      nil -> "default"
      mode -> mode
    end
  end

  @spec output_containers(term(), term()) :: term()
  defp output_containers(containers, opts) do
    cond do
      opts[:quiet] ->
        output_quiet(containers)

      opts[:format] == "json" ->
        output_json(containers)

      opts[:format] == "yaml" ->
        output_yaml(containers)

      true ->
        output_table(containers, opts)
    end
  end

  @spec output_quiet(term()) :: term()
  defp output_quiet(containers) do
    containers
    |> Enum.map(& &1["name"])
    |> Enum.each(&IO.puts/1)
  end

  @spec output_json(term()) :: term()
  defp output_json(containers) do
    json = Jason.encode!(%{containers: containers}, pretty: true)
    IO.puts(json)
  end

  @spec output_yaml(term()) :: term()
  defp output_yaml(containers) do
    # Simple YAML output
    IO.puts("containers:")

    Enum.each(containers, fn container ->
      IO.puts("  - id: #{container.id}")
      IO.puts("    name: #{container.name}")
      IO.puts("    image: #{container.image}")
      IO.puts("    status: #{container.status}")
      IO.puts("    state: #{container.state}")

      if container.ports != [] do
        IO.puts("    ports:")

        Enum.each(container.ports, fn port ->
          IO.puts("      - #{port}")
        end)
      end

      IO.puts("")
    end)
  end

  @spec output_table(term(), term()) :: term()
  defp output_table(containers, opts) do
    if containers == [] do
      Mix.shell().info("Info:  No containers found")
      return()
    end

    Mix.shell().info("\n📦 Container List")
    Mix.shell().info("=" |> String.duplicate(100))

    headers =
      if opts[:verbose] do
        ["ID", "Name", "Image", "Status", "Created", "Ports", "Size"]
      else
        ["ID", "Name", "Image", "Status", "Ports"]
      end

    rows =
      Enum.map(containers, fn c ->
        if opts[:verbose] do
          [
            c.id,
            c.name,
            String.slice(c.image, 0, 30),
            c.status,
            c.created,
            Enum.join(c.ports, ","),
            c.size
          ]
        else
          [
            c.id,
            c.name,
            String.slice(c.image, 0, 30),
            c.status,
            Enum.join(c.ports, ",")
          ]
        end
      end)

    table = format_table(rows, headers)
    Mix.shell().info(table)

    # Summary
    running = Enum.count(containers, fn c -> c.state == "running" end)
    total = length(containers)

    Mix.shell().info("\n[STATS] Summary: #{running} running, #{total - running} stopped")

    if opts[:verbose] do
      output_verbose_details(containers)
    end
  end

  @spec output_verbose_details(term()) :: term()
  defp output_verbose_details(containers) do
    Mix.shell().info("\n📝 Additional Details:")

    Enum.each(containers, fn c ->
      output_container_labels(c)
    end)
  end

  @spec output_container_labels(term()) :: term()
  defp output_container_labels(c) do
    if map_size(c[:labels] || %{}) > 0 do
      Mix.shell().info("\n🏷️  Labels for #{c.name}:")

      Enum.each(c.labels, fn {k, v} ->
        Mix.shell().info("   #{k}: #{v}")
      end)
    end
  end

  @spec return() :: any()
  defp return, do: :ok
end
