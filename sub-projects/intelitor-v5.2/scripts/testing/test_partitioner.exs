#!/usr/bin/env elixir
# Test Partitioner & Parallel Runner
# Splits 1928 test files into N partitions for parallel execution
# SC-METRICS-003: Parallelization MANDATORY

defmodule TestPartitioner do
  @moduledoc """
  Partitions test files for parallel CI/CD execution.
  Supports time-based balancing from previous run data.
  """

  @test_dir "test"
  @timing_file "data/tmp/test_timings.json"

  def run(args \\ []) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        partitions: :integer,
        partition: :integer,
        strategy: :string,
        dry_run: :boolean,
        list: :boolean,
        stats: :boolean
      ],
      aliases: [n: :partitions, p: :partition, s: :strategy]
    )

    cond do
      opts[:stats] -> show_stats()
      opts[:list] -> list_partitions(opts[:partitions] || 16)
      opts[:partition] -> run_partition(opts[:partition], opts[:partitions] || 16, opts[:strategy] || "balanced")
      true -> show_stats()
    end
  end

  def show_stats do
    files = discover_test_files()
    {by_dir, by_type} = categorize(files)

    IO.puts("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║  TEST PARTITIONER — #{length(files)} test files                          ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  ┌─ BY DOMAIN ──────────────────────────────────────────────┐   ║
    """)

    for {dir, count} <- Enum.take(Enum.sort_by(by_dir, fn {_, c} -> -c end), 20) do
      bar_len = min(round(count / 10), 30)
      IO.puts("    ║  │  #{String.pad_trailing(dir, 35)} #{String.pad_leading("#{count}", 5)} #{String.duplicate("█", bar_len)}  │   ║")
    end

    IO.puts("""
    ║  └──────────────────────────────────────────────────────────┘   ║
    ║                                                                  ║
    ║  ┌─ BY TYPE ────────────────────────────────────────────────┐   ║
    """)

    for {type, count} <- Enum.sort_by(by_type, fn {_, c} -> -c end) do
      IO.puts("    ║  │  #{String.pad_trailing(type, 35)} #{String.pad_leading("#{count}", 5)}  │   ║")
    end

    IO.puts("""
    ║  └──────────────────────────────────────────────────────────┘   ║
    ║                                                                  ║
    ║  ┌─ RECOMMENDED PARTITIONS ─────────────────────────────────┐   ║
    ║  │  Cores available:     #{String.pad_leading("#{System.schedulers_online()}", 5)}                             │   ║
    ║  │  Optimal partitions:  #{String.pad_leading("#{optimal_partitions(files)}", 5)}                             │   ║
    ║  │  Files per partition:  ~#{String.pad_leading("#{div(length(files), optimal_partitions(files))}", 4)}                             │   ║
    ║  │  Strategy:            balanced (time-weighted)           │   ║
    ║  └──────────────────────────────────────────────────────────┘   ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
  end

  def list_partitions(n) do
    files = discover_test_files()
    partitions = partition_files(files, n, "balanced")

    IO.puts("Test Partitions (#{n} partitions, #{length(files)} files):\n")

    for {partition, idx} <- Enum.with_index(partitions, 1) do
      IO.puts("  Partition #{idx}: #{length(partition)} files")
      for file <- Enum.take(partition, 3) do
        IO.puts("    #{file}")
      end
      if length(partition) > 3, do: IO.puts("    ... and #{length(partition) - 3} more")
      IO.puts("")
    end
  end

  def run_partition(partition_idx, total_partitions, strategy) do
    files = discover_test_files()
    partitions = partition_files(files, total_partitions, strategy)

    if partition_idx < 1 or partition_idx > length(partitions) do
      IO.puts("Error: partition #{partition_idx} out of range 1..#{length(partitions)}")
      System.halt(1)
    end

    selected = Enum.at(partitions, partition_idx - 1)
    IO.puts("Running partition #{partition_idx}/#{total_partitions}: #{length(selected)} files")

    # Output file list for mix test
    file_list = Enum.join(selected, " ")
    IO.puts(file_list)
  end

  # --- Partitioning Strategies ---

  def partition_files(files, n, strategy) do
    case strategy do
      "balanced" -> balanced_partition(files, n)
      "directory" -> directory_partition(files, n)
      "roundrobin" -> round_robin_partition(files, n)
      _ -> balanced_partition(files, n)
    end
  end

  defp balanced_partition(files, n) do
    # Weight files by estimated execution time
    weighted = Enum.map(files, fn file ->
      weight = estimate_weight(file)
      {file, weight}
    end)

    # Sort heaviest first for better balance
    sorted = Enum.sort_by(weighted, fn {_, w} -> -w end)

    # Greedy assignment to lightest partition
    partitions = for _ <- 1..n, do: {[], 0}

    Enum.reduce(sorted, partitions, fn {file, weight}, parts ->
      # Find partition with minimum total weight
      {min_idx, _} = parts
        |> Enum.with_index()
        |> Enum.min_by(fn {{_, total}, _} -> total end)
        |> then(fn {{_, total}, idx} -> {idx, total} end)

      List.update_at(parts, min_idx, fn {files, total} ->
        {[file | files], total + weight}
      end)
    end)
    |> Enum.map(fn {files, _} -> Enum.reverse(files) end)
  end

  defp directory_partition(files, n) do
    files
    |> Enum.group_by(fn f ->
      parts = String.split(f, "/")
      if length(parts) >= 3, do: Enum.at(parts, 1), else: "root"
    end)
    |> Map.values()
    |> Enum.sort_by(&(-length(&1)))
    |> spread_groups(n)
  end

  defp round_robin_partition(files, n) do
    files
    |> Enum.with_index()
    |> Enum.group_by(fn {_, idx} -> rem(idx, n) end)
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map(fn {_, items} -> Enum.map(items, &elem(&1, 0)) end)
  end

  defp spread_groups(groups, n) do
    partitions = for _ <- 1..n, do: []

    Enum.reduce(groups, partitions, fn group, parts ->
      min_idx = parts
        |> Enum.with_index()
        |> Enum.min_by(fn {p, _} -> length(p) end)
        |> elem(1)

      List.update_at(parts, min_idx, &(&1 ++ group))
    end)
  end

  # --- Weight Estimation ---

  defp estimate_weight(file) do
    # Load timing data if available
    timing = load_timings()

    case Map.get(timing, file) do
      nil -> estimate_from_file(file)
      ms -> ms
    end
  end

  defp estimate_from_file(file) do
    case File.read(file) do
      {:ok, content} ->
        lines = String.split(content, "\n") |> length()
        tests = Regex.scan(~r/\btest\s+"/, content) |> length()
        properties = Regex.scan(~r/\bproperty\b|\bforall\b|\bcheck all\b/, content) |> length()
        has_db = String.contains?(content, "DataCase") || String.contains?(content, "Repo")
        has_propcheck = String.contains?(content, "PropCheck")

        base = lines
        test_weight = tests * 50
        prop_weight = properties * 500  # Property tests are expensive
        db_weight = if has_db, do: 200, else: 0
        propcheck_weight = if has_propcheck, do: 300, else: 0

        base + test_weight + prop_weight + db_weight + propcheck_weight

      _ -> 100
    end
  end

  defp load_timings do
    case File.read(@timing_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          _ -> %{}
        end
      _ -> %{}
    end
  end

  # --- File Discovery ---

  def discover_test_files do
    {out, 0} = System.cmd("find", [@test_dir, "-name", "*_test.exs", "-type", "f"])

    out
    |> String.split("\n", trim: true)
    |> Enum.sort()
  end

  defp categorize(files) do
    by_dir = files
      |> Enum.map(fn f ->
        parts = String.split(f, "/")
        cond do
          length(parts) >= 4 -> Enum.slice(parts, 1, 2) |> Enum.join("/")
          length(parts) >= 3 -> Enum.at(parts, 1)
          true -> "root"
        end
      end)
      |> Enum.frequencies()
      |> Enum.to_list()

    by_type = files
      |> Enum.map(fn f ->
        cond do
          String.contains?(f, "property") -> "property"
          String.contains?(f, "integration") -> "integration"
          String.contains?(f, "demo") -> "demo"
          String.contains?(f, "sil6") -> "sil6"
          String.contains?(f, "fractal") -> "fractal"
          String.contains?(f, "stamp") -> "stamp"
          String.contains?(f, "tdg") -> "tdg"
          String.contains?(f, "_web/") -> "web"
          true -> "unit"
        end
      end)
      |> Enum.frequencies()
      |> Enum.to_list()

    {by_dir, by_type}
  end

  defp optimal_partitions(files) do
    cores = System.schedulers_online()
    file_count = length(files)

    cond do
      file_count > 1000 -> cores * 2
      file_count > 500 -> cores
      file_count > 100 -> max(div(cores, 2), 4)
      true -> max(div(cores, 4), 2)
    end
  end
end

TestPartitioner.run(System.argv())
