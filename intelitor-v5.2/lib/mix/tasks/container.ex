defmodule Mix.Tasks.Container do
  @moduledoc """
  Container management Mix tasks for Indrajaal.

  This module provides the base functionality for all container - related Mix tasks,
  ensuring SOPv5.1 compliance and integration with the enterprise framework.

  ## Available Tasks

  * `mix container.start` - Start containers
  * `mix container.stop` - Stop containers
  * `mix container.restart` - Restart containers
  * `mix container.status` - Show container status
  * `mix container.health` - Check container health
  * `mix container.logs` - View container logs
  * `mix container.exec` - Execute commands in containers
  * `mix container.list` - List all containers
  * `mix container.phics.enable` - Enable PHICS hot - reloading
  * `mix container.phics.disable` - Disable PHICS hot - reloading
  * `mix container.phics.status` - Show PHICS status
  * `mix container.performance` - Monitor container performance
  * `mix container.cleanup` - Clean up stopped containers

  Created: 2025 - 08 - 05 16:28:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container - Only
  """

  @doc false
  @spec validate_container_runtime!() :: any()
  def validate_container_runtime! do
    case System.get_env("CONTAINER_RUNTIME", "podman") do
      "podman" ->
        :ok

      other ->
        Mix.raise("""
        Invalid container runtime: #{other}
        Required: podman

        This project __requires Podman for container management.
        Please ensure Podman is installed and CONTAINER_RUNTIME is set correctly.
        """)
    end
  end

  @doc false
  @spec validate_container_name!(any()) :: any()
  def validate_container_name!(name) do
    if Regex.match?(~r/^[a - zA - Z0 - 9][a - zA - Z0 - 9_.-]*$/, name) do
      :ok
    else
      Mix.raise("""
      Invalid container name: #{name}

      Container names must:
      - Start with a letter or number
      - Contain only letters, numbers, underscores, dots, or hyphens
      """)
    end
  end

  @doc false
  @spec ensure_claude_logging(any(), any()) :: any()
  def ensure_claude_logging(taskname, metadata \\ %{}) do
    merged =
      Map.merge(metadata, %{
        task: "mix container.#{taskname}",
        timestamp: DateTime.utc_now(),
        framework: "SOPv5.1",
        runtime: "podman"
      })

    log_entry = merged |> sanitize_for_json()

    log_file = "./data/tmp/claude_container_#{taskname}_#{System.system_time(:second)}.log"
    File.mkdir_p!(Path.dirname(log_file))

    File.write!(log_file, Jason.encode!(log_entry, pretty: true))
    :ok
  end

  defp sanitize_for_json(data) when is_struct(data), do: data

  defp sanitize_for_json(data) when is_list(data) do
    if Keyword.keyword?(data) do
      Map.new(data, fn {k, v} -> {k, sanitize_for_json(v)} end)
    else
      Enum.map(data, &sanitize_for_json/1)
    end
  end

  defp sanitize_for_json(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {k, sanitize_for_json(v)} end)
  end

  defp sanitize_for_json(data), do: data

  @doc false
  @spec run_podman_command(any(), any()) :: any()
  def run_podman_command(args, opts \\ []) do
    validate_container_runtime!()

    cmd_opts =
      [
        stderr_to_stdout: true,
        into: IO.stream(:stdio, :line)
      ] ++ opts

    case System.cmd("podman", args, cmd_opts) do
      {_, 0} -> :ok
      {_, code} -> {:error, code}
    end
  end

  @doc false
  @spec get_container_info(any()) :: any()
  def get_container_info(name) do
    validate_container_runtime!()

    case System.cmd("podman", ["inspect", name, "--format", "json"], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, [info | _]} -> {:ok, info}
          _ -> {:error, :invalid_json}
        end

      {_, _} ->
        {:error, :not_found}
    end
  end

  @doc false
  @spec format_table(any(), any()) :: any()
  def format_table(headers, rows) do
    # Calculate column widths
    widths =
      [headers | rows]
      |> Enum.map(fn row ->
        Enum.map(row, &String.length/1)
      end)
      |> Enum.zip()
      |> Enum.map(&Tuple.to_list/1)
      |> Enum.map(&Enum.max/1)

    # Format header
    header_line =
      headers
      |> Enum.zip(widths)
      |> Enum.map_join(" | ", fn {header, width} ->
        String.pad_trailing(header, width)
      end)

    separator = String.duplicate("-", String.length(header_line))

    # Format rows
    formatted_rows =
      rows
      |> Enum.map(fn row ->
        row
        |> Enum.zip(widths)
        |> Enum.map_join(" | ", fn {cell, width} ->
          String.pad_trailing(cell, width)
        end)
      end)

    [header_line, separator | formatted_rows]
    |> Enum.join("\n")
  end

  @doc false
  @spec parse_common_options(any()) :: any()
  def parse_common_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          verbose: :boolean,
          json: :boolean,
          help: :boolean,
          agent_mode: :boolean
        ],
        aliases: [
          v: :verbose,
          j: :json,
          h: :help
        ]
      )

    {opts, remaining_args}
  end

  @doc false
  @spec notify_agent_coordinator(term(), term(), term()) :: term()
  def notify_agent_coordinator(action, containername, result) do
    if System.get_env("AGENT_COORDINATION_MODE") == "true" do
      IO.puts("Agent coordination mode: Supervisor notified")
      IO.puts("   Action: #{action}")
      IO.puts("   Container: #{containername}")
      IO.puts("   Result: #{inspect(result)}")
    end
  end
end
