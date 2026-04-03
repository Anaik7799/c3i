defmodule Mix.Tasks.Container.Logs do
  @moduledoc """
  Views logs from containers.

  Displays container logs with filtering, following, and formatting options.
  Supports real - time log streaming and historical log viewing.

  ## Usage

      mix container.logs CONTAINER_NAME [OPTIONS]
      mix container.logs app
      mix container.logs app --follow

  ## Options

    * `--follow` - Follow log output (like tail -f)
    * `--tail LINES` - Number of lines to show from the end (default: 100)
    * `--since TIME` - Show logs since timestamp (e.g., 2h, 30m)
    * `--until TIME` - Show logs until timestamp
    * `--timestamps` - Show timestamps with each log line
    * `--filter PATTERN` - Filter logs by pattern
    * `--json` - Output logs in JSON format
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # View last 100 lines
      mix container.logs app

      # Follow logs in real - time
      mix container.logs app --follow

      # View logs from last 2 hours
      mix container.logs app --since 2h

      # Filter error logs
      mix container.logs app --filter ERROR

  Created: 2025 - 08 - 05 17:45:00 CEST
  Framewor,k: SOPv5.1 + Container Log Management
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "View container logs"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_logs_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    if container_names == [] do
      Mix.raise("Error: Container name __required\nUsage: mix container.logs <name>")
    end

    if length(container_names) > 1 do
      Mix.raise("Error: Only one container can be specified for logs")
    end

    validate_container_runtime!()

    container_name = hd(container_names)

    # Check if container exists
    case get_container_info(container_name) do
      {:ok, _info} ->
        # Log to Claude
        ensure_claude_logging("logs", %{
          container: container_name,
          options: opts
        })

        # View logs
        view_container_logs(container_name, opts)

      {:error, :not_found} ->
        Mix.shell().error("Error: Container not found: #{container_name}")
    end
  end

  @spec parse_logs_options(term()) :: term()
  defp parse_logs_options(args) do
    {opts_parsed, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          follow: :boolean,
          tail: :integer,
          since: :string,
          until: :string,
          timestamps: :boolean,
          filter: :string,
          json: :boolean,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          f: :follow,
          t: :tail,
          s: :since,
          u: :until
        ]
      )

    # Default tail lines
    opts = Keyword.put_new(opts_parsed, :tail, 100)

    {opts, remaining_args}
  end

  @spec view_container_logs(term(), term()) :: term()
  defp view_container_logs(name, opts) do
    Mix.shell().info("📄 Container logs: #{name}")
    Mix.shell().info("=" |> String.duplicate(60))

    # Build podman logs command
    cmd_args = build_logs_command(opts)

    if opts[:follow] do
      Mix.shell().info("Reload: Following logs (Ctrl + C to stop)...")
    end

    # Execute logs command
    if opts[:filter] do
      # Use grep for filtering
      view_filtered_logs(name, cmd_args, opts[:filter], opts)
    else
      view_standard_logs(name, cmd_args, opts)
    end
  end

  @spec build_logs_command(term()) :: term()
  defp build_logs_command(opts) do
    args = ["logs"]

    # Add follow flag
    args = if opts[:follow], do: args ++ ["--follow"], else: args

    # Add tail option
    args =
      if opts[:tail] && !opts[:follow] do
        args ++ ["--tail", to_string(opts[:tail])]
      else
        args
      end

    # Add since option
    args = if opts[:since], do: args ++ ["--since", opts[:since]], else: args

    # Add until option
    args = if opts[:until], do: args ++ ["--until", opts[:until]], else: args

    # Add timestamps
    args = if opts[:timestamps], do: args ++ ["--timestamps"], else: args

    args
  end

  defp view_standard_logs(name, cmd_args, opts) do
    args = cmd_args ++ [name]

    if opts[:json] do
      # Capture output for JSON formatting
      case System.cmd("podman", args, stderr_to_stdout: true) do
        {output, 0} ->
          format_logs_as_json(output)

        {error, _} ->
          Mix.shell().error("Error: Failed to retrieve logs: #{error}")
      end
    else
      # Stream logs directly to console
      run_podman_command(args, into: IO.stream(:stdio, :line))
    end
  end

  defp view_filtered_logs(name, cmd_args, filter, opts) do
    args = cmd_args ++ [name]

    # For following with filter, we need to pipe through grep
    if opts[:follow] do
      # Use shell command for piping
      shell_cmd = "podman #{Enum.join(args, " ")} | grep --line - buffered '#{filter}'"
      System.cmd("sh", ["-c", shell_cmd], into: IO.stream(:stdio, :line))
    else
      # Get logs and filter
      case System.cmd("podman", args, stderr_to_stdout: true) do
        {output, 0} ->
          filtered = filter_log_lines(output, filter)

          if opts[:json] do
            format_logs_as_json(filtered)
          else
            IO.puts(filtered)
          end

        {error, _} ->
          Mix.shell().error("Error: Failed to retrieve logs: #{error}")
      end
    end
  end

  @spec filter_log_lines(term(), term()) :: term()
  defp filter_log_lines(output, filter) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, filter))
    |> Enum.join("\n")
  end

  @spec format_logs_as_json(term()) :: term()
  defp format_logs_as_json(output) do
    lines =
      output
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(fn line ->
        # Try to parse timestamp if present
        case Regex.run(~r/^(\S+)\s+(.*)$/, line) do
          [_, timestamp, message] ->
            %{
              timestamp: timestamp,
              message: message
            }

          _ ->
            %{
              timestamp: nil,
              message: line
            }
        end
      end)

    json = Jason.encode!(%{logs: lines}, pretty: true)
    IO.puts(json)
  end

  @spec return() :: any()
  defp return, do: :ok
end
