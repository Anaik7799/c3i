defmodule Mix.Tasks.Container.Performance do
  @moduledoc """
  Monitors container performance metrics.

  Provides real - time and historical performance monitoring for containers,
  including CPU, memory, network, and disk I / O statistics.

  ## Usage

      mix container.performance [CONTAINER_NAME] [OPTIONS]
      mix container.performance
      mix container.performance app --interval 5

  ## Options

    * `--interval SECONDS` - Update interval (default: 2)
    * `--duration SECONDS` - Monitoring duration (default: continuous)
    * `--export FILE` - Export metrics to file
    * `--format FORMAT` - Output format (live, json, csv)
    * `--metrics METRICS` - Comma - separated metrics to show
    * `--threshold KEY = VALUE` - Alert thresholds
    * `--verbose` - Show detailed metrics
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Monitor all containers
      mix container.performance

      # Monitor specific container every 5 seconds
      mix container.performance app --interval 5

      # Export metrics to CSV
      mix container.performance --export metrics.csv --format csv

      # Set CPU alert threshold
      mix container.performance --threshold cpu = 80

  Created: 2025 - 08 - 05 17:54:00 CEST
  Framewor,k: SOPv5.1 + Container Performance Monitoring
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Monitor container performance"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, container_names} = parse_performance_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
    end

    validate_container_runtime!()

    # Get containers to monitor
    containers =
      if container_names == [] do
        get_all_running_containers()
      else
        container_names
      end

    if containers == [] do
      Mix.shell().info("Info:  No containers to monitor")
    end

    # Log to Claude
    ensure_claude_logging("performance", %{
      containers: containers,
      options: opts
    })

    # Start monitoring
    monitor_performance(containers, opts)
  end

  @spec parse_performance_options(term()) :: term()
  defp parse_performance_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          interval: :integer,
          duration: :integer,
          export: :string,
          format: :string,
          metrics: :string,
          threshold: :keep,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          i: :interval,
          d: :duration,
          e: :export,
          f: :format
        ]
      )

    # Defaults
    opts =
      opts
      |> Keyword.put_new(:interval, 2)
      |> Keyword.put_new(:format, "live")
      |> Keyword.put_new(:metrics, "cpu,memory,network,disk")

    # Parse thresholds
    thresholds = parse_thresholds(Keyword.get_values(opts, :threshold))
    opts = Keyword.put(opts, :thresholds, thresholds)

    {opts, remaining_args}
  end

  @spec parse_thresholds(term()) :: term()
  defp parse_thresholds(threshold_list) do
    Enum.reduce(threshold_list, %{}, fn threshold, acc ->
      case String.split(threshold, "=", parts: 2) do
        [key, value] ->
          case Float.parse(value) do
            {num, _} -> Map.put(acc, key, num)
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  @spec get_all_running_containers() :: any()
  def get_all_running_containers() do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}", "--filter", "_status =running"],
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

  @spec monitor_performance(term(), term()) :: term()
  defp monitor_performance(containers, opts) do
    # Initialize export file if needed
    export_file = initialize_export(opts)

    # Start monitoring loop
    case opts[:format] do
      "json" ->
        monitor_json(containers, opts, export_file)

      "csv" ->
        monitor_csv(containers, opts, export_file)

      _ ->
        monitor_live(containers, opts)
    end

    # Close export file
    if export_file, do: File.close(export_file)
  end

  @spec initialize_export(term()) :: term()
  defp initialize_export(opts) do
    if opts[:export] do
      case File.open(opts[:export], [:write, :utf8]) do
        {:ok, file} ->
          # Write headers for CSV
          if opts[:format] == "csv" do
            IO.write(
              file,
              "timestamp,container,cpu_percent,mem_percent,mem_usage,net_rx,net_tx,disk_read,disk_write\n"
            )
          end

          file

        _ ->
          Mix.shell().error("Warning:  Failed to open export file: #{opts[:export]}")
          nil
      end
    else
      nil
    end
  end

  @spec monitor_live(term(), term()) :: term()
  defp monitor_live(containers, opts) do
    Mix.shell().info("[STATS] Container Performance Monitor")
    Mix.shell().info("Reload: Updating every #{opts[:interval]}s (Ctrl + C to stop)")

    if opts[:thresholds] != %{} do
      Mix.shell().info("Alert: Alert thresholds: #{inspect(opts[:thresholds])}")
    end

    Mix.shell().info("")

    # Clear screen and move cursor to top
    IO.write("\e[2J\e[H")

    start_time = System.monotonic_time(:second)
    monitor_loop(containers, opts, start_time, 0)
  end

  @spec monitor_loop(term(), term(), term(), term()) :: term()
  defp monitor_loop(containers, opts, start_time, iteration) do
    # Check duration limit
    if opts[:duration] && System.monotonic_time(:second) - start_time >= opts[:duration] do
      Mix.shell().info("\nSuccess: Monitoring duration reached")
      return()
    end

    # Clear screen for live view
    if opts[:format] == "live" && iteration > 0 do
      IO.write("\e[2J\e[H")
    end

    # Get current metrics
    timestamp = DateTime.utc_now()
    metrics = collect_metrics(containers, opts)

    # Display metrics
    display_live_metrics(metrics, timestamp, opts)

    # Check thresholds
    check_thresholds(metrics, opts[:thresholds])

    # Wait for next interval
    Process.sleep(opts[:interval] * 1000)

    # Continue loop
    monitor_loop(containers, opts, start_time, iteration + 1)
  end

  defp monitor_json(containers, opts, export_file) do
    Mix.shell().info("[STATS] Collecting performance metrics...")

    metrics_list = collect_metrics_batch(containers, opts)

    json = Jason.encode!(%{performance_metrics: metrics_list}, pretty: true)

    if export_file do
      IO.write(export_file, json)
      Mix.shell().info("Success: Metrics exported to: #{opts[:export]}")
    else
      IO.puts(json)
    end
  end

  defp monitor_csv(containers, opts, export_file) do
    Mix.shell().info("[STATS] Collecting performance metrics...")

    metrics_list = collect_metrics_batch(containers, opts)

    Enum.each(metrics_list, fn metrics ->
      Enum.each(metrics.containers, fn {name, data} ->
        line = format_csv_line(metrics.timestamp, name, data)

        if export_file do
          IO.write(export_file, line)
        else
          IO.write(line)
        end
      end)
    end)

    if export_file do
      Mix.shell().info("Success: Metrics exported to: #{opts[:export]}")
    end
  end

  @spec collect_metrics_batch(term(), term()) :: term()
  defp collect_metrics_batch(containers, opts) do
    # Collect multiple samples if duration is specified
    samples =
      if opts[:duration] do
        div(opts[:duration], opts[:interval])
      else
        1
      end

    Enum.map(1..samples, fn i ->
      if i > 1, do: Process.sleep(opts[:interval] * 1000)

      %{
        timestamp: DateTime.utc_now(),
        containers: collect_metrics(containers, opts)
      }
    end)
  end

  @spec collect_metrics(term(), term()) :: term()
  defp collect_metrics(containers, opts) do
    # Get stats for all containers
    case System.cmd("podman", ["stats", "--no - stream", "--format", "json"] ++ containers,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, stats_list} when is_list(stats_list) ->
            Map.new(stats_list, fn stats ->
              {get_stat_name(stats), parse_container_stats(stats, opts)}
            end)

          _ ->
            %{}
        end

      _ ->
        %{}
    end
  end

  @spec get_stat_name(term()) :: term()
  defp get_stat_name(stats) do
    stats["Name"] || stats["Container"] || "unknown"
  end

  @spec parse_container_stats(term(), term()) :: term()
  defp parse_container_stats(stats, opts) do
    metrics = String.split(opts[:metrics], ",")

    base_stats = %{}

    base_stats =
      if "cpu" in metrics do
        Map.put(base_stats, :cpu_percent, parse_percentage(stats["cpu_percent"] || stats["CPU"]))
      else
        base_stats
      end

    base_stats =
      if "memory" in metrics do
        base_stats
        |> Map.put(:mem_percent, parse_percentage(stats["mem_percent"] || stats["MemPerc"]))
        |> Map.put(:mem_usage, stats["mem_usage"] || stats["MemUsage"] || "0")
      else
        base_stats
      end

    base_stats =
      if "network" in metrics do
        {rx, tx} = parse_network_io(stats)

        base_stats
        |> Map.put(:net_rx, rx)
        |> Map.put(:net_tx, tx)
      else
        base_stats
      end

    base_stats =
      if "disk" in metrics do
        {read, write} = parse_disk_io(stats)

        base_stats
        |> Map.put(:disk_read, read)
        |> Map.put(:disk_write, write)
      else
        base_stats
      end

    base_stats
  end

  @spec parse_percentage(term()) :: term()
  defp parse_percentage(nil), do: 0.0

  defp parse_percentage(value) when is_binary(value) do
    value
    |> String.replace("%", "")
    |> Float.parse()
    |> case do
      {num, _} -> Float.round(num, 2)
      _ -> 0.0
    end
  end

  @spec parse_percentage(term()) :: term()
  defp parse_percentage(value) when is_number(value), do: Float.round(value, 2)

  defp parse_network_io(stats) do
    net_io = stats["net_io"] || stats["NetIO"] || "0B / 0B"

    case String.split(net_io, " / ") do
      [rx, tx] -> {rx, tx}
      _ -> {"0B", "0B"}
    end
  end

  @spec parse_disk_io(term()) :: term()
  defp parse_disk_io(stats) do
    disk_io = stats["block_io"] || stats["BlockIO"] || "0B / 0B"

    case String.split(disk_io, " / ") do
      [read, write] -> {read, write}
      _ -> {"0B", "0B"}
    end
  end

  defp display_live_metrics(metrics, timestamp, opts) do
    Mix.shell().info("[STATS] Container Performance Monitor")
    Mix.shell().info("Time: #{Calendar.strftime(timestamp, "%H:%M:%S")}")
    Mix.shell().info("=" |> String.duplicate(80))

    if map_size(metrics) == 0 do
      Mix.shell().info("No metrics available")
      return()
    end

    # Table headers
    headers = ["Container", "CPU %", "Memory %", "Memory", "Net I / O", "Disk I / O"]

    rows =
      Enum.map(metrics, fn {name, stats} ->
        [
          String.slice(name, 0, 15),
          format_metric(stats[:cpu_percent], "%"),
          format_metric(stats[:mem_percent], "%"),
          stats[:mem_usage] || "N / A",
          format_network_io(stats),
          format_disk_io(stats)
        ]
      end)

    table = format_table(rows, headers)
    Mix.shell().info(table)

    if opts[:verbose] do
      Mix.shell().info("\n📓 Detailed Metrics:")

      Enum.each(metrics, fn {name, stats} ->
        Mix.shell().info("  #{name}:")

        Enum.each(stats, fn {key, value} ->
          Mix.shell().info("    #{key}: #{value}")
        end)
      end)
    end
  end

  @spec format_metric(term(), term()) :: term()
  defp format_metric(nil, _suffix), do: "N / A"
  defp format_metric(value, suffix), do: "#{value}#{suffix}"

  @spec format_network_io(map()) :: term()
  defp format_network_io(%{net_rx: rx, net_tx: tx}), do: "#{rx} / #{tx}"
  defp format_network_io(_), do: "N / A"

  @spec format_disk_io(map()) :: term()
  defp format_disk_io(%{disk_read: read, disk_write: write}), do: "#{read} / #{write}"
  defp format_disk_io(_), do: "N / A"

  @spec check_thresholds(term(), term()) :: term()
  defp check_thresholds(_metrics, thresholds) when thresholds == %{}, do: :ok

  defp check_thresholds(metrics, thresholds) do
    Enum.each(metrics, fn {container, stats} ->
      Enum.each(thresholds, fn {metric, threshold} ->
        check_single_threshold(container, stats, metric, threshold)
      end)
    end)
  end

  defp check_single_threshold(container, stats, "cpu", threshold) do
    if stats[:cpu_percent] && stats[:cpu_percent] > threshold do
      Mix.shell().error("Alert: ALERT: #{container} CPU usage #{stats[:cpu_percent]}%")
    end
  end

  defp check_single_threshold(container, stats, "memory", threshold) do
    if stats[:mem_percent] && stats[:mem_percent] > threshold do
      Mix.shell().error("Alert: ALERT: #{container} memory usage #{stats[:mem_percent]}%")
    end
  end

  @spec format_csv_line(term(), term(), term()) :: term()
  defp format_csv_line(timestamp, name, data) do
    "#{timestamp},#{name},#{data[:cpu_percent] || 0},#{data[:mem_percent] || 0},#{data[:mem_usage] || "0"},#{data[:net_rx] || "0B"},#{data[:net_tx] || "0B"},#{data[:disk_read] || "0B"},#{data[:disk_write] || "0B"}\n"
  end

  @spec return() :: any()
  defp return, do: :ok
end
