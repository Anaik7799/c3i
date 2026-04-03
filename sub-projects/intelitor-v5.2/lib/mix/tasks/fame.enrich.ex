defmodule Mix.Tasks.Fame.Enrich do
  @moduledoc """
  Enriches Elixir modules with FAME metadata skeletons.

  WHAT: Adds @fame_* module attributes to files that don't have them.
  WHY: Enables mass enrichment of 8,375+ artifacts per SC-FAME-005.
  CONSTRAINTS: Must not overwrite existing FAME metadata; SC-BATCH-001 limits.

  ## Usage

      # Enrich a single file
      mix fame.enrich lib/indrajaal/accounts/user.ex

      # Enrich a directory (all .ex files)
      mix fame.enrich lib/indrajaal/accounts

      # Enrich with complete metadata (all 12 blocks)
      mix fame.enrich lib/indrajaal/accounts --complete

      # Dry run (show what would be changed)
      mix fame.enrich lib/indrajaal/accounts --dry-run

      # Enrich with specific criticality tier
      mix fame.enrich lib/indrajaal/accounts --tier p0

  ## Options

  - `--complete` - Generate all 12 FAME blocks (default: 4 required blocks)
  - `--dry-run` - Show what would be changed without modifying files
  - `--force` - Overwrite existing FAME metadata
  - `--tier` - Set criticality tier (p0, p1, p2, p3, p4)
  - `--batch-size` - Number of files per batch (default: 10, max: 10)
  - `--json` - Output results as JSON

  ## STAMP Compliance
  - SC-BATCH-001: Max 10 files per batch
  - SC-FAME-005: Mass enrichment capability

  ## AOR Compliance
  - AOR-BATCH-001: Batch size <= 10
  """

  use Mix.Task

  @shortdoc "Enrich modules with FAME metadata"

  @switches [
    complete: :boolean,
    dry_run: :boolean,
    force: :boolean,
    tier: :string,
    batch_size: :integer,
    json: :boolean,
    help: :boolean
  ]

  @aliases [
    c: :complete,
    d: :dry_run,
    f: :force,
    t: :tier,
    b: :batch_size,
    j: :json,
    h: :help
  ]

  @max_batch_size 10

  @impl Mix.Task
  def run(args) do
    {opts, paths, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if opts[:help] do
      print_help()
    else
      run_enrichment(paths, opts)
    end
  end

  defp run_enrichment([], _opts) do
    Mix.shell().error("No path specified. Usage: mix fame.enrich <path> [options]")
    System.halt(1)
  end

  defp run_enrichment(paths, opts) do
    batch_size = min(opts[:batch_size] || @max_batch_size, @max_batch_size)
    mode = if opts[:complete], do: :complete, else: :minimal
    tier = parse_tier(opts[:tier])
    dry_run = opts[:dry_run] || false
    force = opts[:force] || false

    # Collect all files to enrich
    files = collect_files(paths)

    if Enum.empty?(files) do
      Mix.shell().info("No Elixir files found in specified path(s)")
      System.halt(0)
    end

    # Check for existing FAME metadata
    {already_enriched, needs_enrichment} =
      files
      |> Enum.split_with(&has_fame_metadata?/1)

    files_to_process =
      if force do
        files
      else
        needs_enrichment
      end

    if Enum.empty?(files_to_process) do
      Mix.shell().info("All #{length(files)} files already have FAME metadata")
      System.halt(0)
    end

    # Print summary
    print_summary(files, already_enriched, files_to_process, dry_run, mode, tier)

    # Process in batches
    results =
      files_to_process
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {batch, batch_num} ->
        Mix.shell().info(
          "\nProcessing batch #{batch_num}/#{ceil(length(files_to_process) / batch_size)}..."
        )

        process_batch(batch, mode, tier, dry_run)
      end)

    # Print results
    if opts[:json] do
      print_json_results(results)
    else
      print_results(results)
    end

    # Exit with appropriate code
    failures = Enum.count(results, fn {_, status, _} -> status == :error end)

    if failures > 0 and not dry_run do
      System.halt(1)
    end
  end

  defp collect_files(paths) do
    paths
    |> Enum.flat_map(fn path ->
      cond do
        File.dir?(path) ->
          Path.wildcard(Path.join(path, "**/*.ex"))

        File.exists?(path) and String.ends_with?(path, ".ex") ->
          [path]

        true ->
          Mix.shell().error("Path not found or not an Elixir file: #{path}")
          []
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp has_fame_metadata?(file_path) do
    case File.read(file_path) do
      {:ok, content} -> String.contains?(content, "@fame_meta")
      _ -> false
    end
  end

  defp process_batch(files, mode, tier, dry_run) do
    Enum.map(files, fn file_path ->
      process_file(file_path, mode, tier, dry_run)
    end)
  end

  defp process_file(file_path, mode, tier, dry_run) do
    case generate_fame_for_file(file_path, mode, tier) do
      {:ok, fame_content} ->
        if dry_run do
          {file_path, :would_enrich, fame_content}
        else
          case insert_fame_metadata(file_path, fame_content) do
            :ok -> {file_path, :enriched, nil}
            {:error, reason} -> {file_path, :error, reason}
          end
        end

      {:error, reason} ->
        {file_path, :error, reason}
    end
  end

  defp generate_fame_for_file(file_path, mode, tier) do
    artifact_id = infer_artifact_id(file_path)
    artifact_type = infer_artifact_type(file_path)

    fame_block =
      case mode do
        :complete ->
          Indrajaal.FAME.Schema.new_complete(artifact_id, artifact_type)

        :minimal ->
          Indrajaal.FAME.Schema.new_minimal(artifact_id, artifact_type)
      end

    # Apply tier-specific settings
    fame_block = apply_tier_settings(fame_block, tier)

    # Generate Elixir code for the FAME attributes
    fame_code = generate_fame_code(fame_block)

    {:ok, fame_code}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp infer_artifact_id(file_path) do
    file_path
    |> Path.rootname()
    |> String.replace(~r"^lib/", "")
    |> String.replace("/", ".")
  end

  defp infer_artifact_type(file_path) do
    cond do
      String.contains?(file_path, "/resources/") -> :resource
      String.contains?(file_path, "_test.exs") -> :test
      String.ends_with?(file_path, ".exs") -> :script
      true -> :module
    end
  end

  defp apply_tier_settings(fame_block, nil), do: fame_block

  defp apply_tier_settings(fame_block, tier) do
    stability =
      case tier do
        :p0 -> :frozen
        :p1 -> :stable
        :p2 -> :evolving
        _ -> :volatile
      end

    coverage =
      case tier do
        :p0 -> 1.0
        :p1 -> 0.95
        :p2 -> 0.80
        _ -> 0.60
      end

    fame_block
    |> put_in([:evolution, :stability], stability)
    |> put_in([:boundaries, :tdg, :coverage_min], coverage)
  end

  defp generate_fame_code(fame_block) do
    """

      # ============================================================================
      # FAME Metadata - Fractal Artifact Metadata Enrichment v2.0.0-BIO
      # Generated: #{Date.utc_today() |> Date.to_iso8601()}
      # ============================================================================

      @fame_meta #{inspect(fame_block.meta, pretty: true, limit: :infinity)}

      @fame_impact #{inspect(fame_block.impact, pretty: true, limit: :infinity)}

      @fame_boundaries #{inspect(fame_block.boundaries, pretty: true, limit: :infinity)}

      @fame_evolution #{inspect(fame_block.evolution, pretty: true, limit: :infinity)}
    #{generate_optional_blocks(fame_block)}
      # Suppress unused attribute warnings
      _ = {@fame_meta, @fame_impact, @fame_boundaries, @fame_evolution}

    """
  end

  defp generate_optional_blocks(fame_block) do
    optional =
      [
        :knowledge,
        :formal,
        :agent_context,
        :metabolism,
        :invariants,
        :stigmergy,
        :contracts,
        :observability
      ]
      |> Enum.filter(&Map.has_key?(fame_block, &1))
      |> Enum.map_join("\n", fn key ->
        value = Map.get(fame_block, key)
        "  @fame_#{key} #{inspect(value, pretty: true, limit: :infinity)}\n"
      end)

    if optional != "" do
      "\n" <> optional
    else
      ""
    end
  end

  defp insert_fame_metadata(file_path, fame_code) do
    case File.read(file_path) do
      {:ok, content} ->
        # Find the end of @moduledoc
        new_content =
          content
          |> insert_after_moduledoc(fame_code)

        File.write(file_path, new_content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp insert_after_moduledoc(content, fame_code) do
    # Pattern to find end of @moduledoc
    patterns = [
      # Triple-quoted moduledoc
      ~r/(@moduledoc\s+"""[\s\S]*?""")/,
      # Single-line moduledoc
      ~r/(@moduledoc\s+"[^"]*")/,
      # False moduledoc
      ~r/(@moduledoc\s+false)/
    ]

    result =
      Enum.find_value(patterns, fn pattern ->
        case Regex.run(pattern, content, return: :index) do
          [{start, length}] ->
            insert_pos = start + length

            String.slice(content, 0, insert_pos) <>
              fame_code <>
              String.slice(content, insert_pos..-1//1)

          _ ->
            nil
        end
      end)

    # If no moduledoc found, insert after defmodule
    result ||
      Regex.replace(
        ~r/(defmodule\s+[\w.]+\s+do\s*\n)/,
        content,
        "\\1#{fame_code}",
        global: false
      )
  end

  defp parse_tier(nil), do: nil
  defp parse_tier("p0"), do: :p0
  defp parse_tier("p1"), do: :p1
  defp parse_tier("p2"), do: :p2
  defp parse_tier("p3"), do: :p3
  defp parse_tier("p4"), do: :p4

  defp parse_tier(other) do
    Mix.shell().error("Unknown tier: #{other}. Valid: p0, p1, p2, p3, p4")
    nil
  end

  defp print_summary(files, already_enriched, files_to_process, dry_run, mode, tier) do
    action = if dry_run, do: "Would enrich", else: "Enriching"

    Mix.shell().info("""

    FAME Enrichment #{if dry_run, do: "(DRY RUN)", else: ""}
    ==================
    Total files found:     #{length(files)}
    Already enriched:      #{length(already_enriched)}
    #{action}:          #{length(files_to_process)}
    Mode:                  #{mode}
    Tier:                  #{tier || "default"}
    """)
  end

  defp print_results(results) do
    enriched = Enum.count(results, fn {_, status, _} -> status == :enriched end)
    would_enrich = Enum.count(results, fn {_, status, _} -> status == :would_enrich end)
    errors = Enum.filter(results, fn {_, status, _} -> status == :error end)

    Mix.shell().info("""

    Results
    =======
    Enriched:     #{enriched}
    Would enrich: #{would_enrich}
    Errors:       #{length(errors)}
    """)

    if length(errors) > 0 do
      Mix.shell().error("\nErrors:")

      Enum.each(errors, fn {path, :error, reason} ->
        Mix.shell().error("  #{path}: #{reason}")
      end)
    end
  end

  defp print_json_results(results) do
    json =
      results
      |> Enum.map(fn {path, status, reason} ->
        %{path: path, status: status, reason: reason}
      end)
      |> Jason.encode!(pretty: true)

    Mix.shell().info(json)
  end

  defp print_help do
    Mix.shell().info("""
    FAME Enrich - Add FAME metadata to Elixir modules

    Usage:
      mix fame.enrich <path> [options]

    Arguments:
      path    File or directory to enrich

    Options:
      -c, --complete     Generate all 12 FAME blocks
      -d, --dry-run      Show what would be changed
      -f, --force        Overwrite existing FAME metadata
      -t, --tier TIER    Set criticality tier (p0, p1, p2, p3, p4)
      -b, --batch-size N Process N files per batch (max: 10)
      -j, --json         Output results as JSON
      -h, --help         Show this help

    Examples:
      mix fame.enrich lib/indrajaal/accounts
      mix fame.enrich lib/indrajaal/accounts --complete --tier p1
      mix fame.enrich lib/indrajaal --dry-run
    """)
  end
end
