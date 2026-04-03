defmodule Mix.Tasks.Container.Cleanup do
  @moduledoc """
  Cleans up stopped containers and unused resources.

  Removes stopped containers, dangling images, unused volumes, and networks
  to free up system resources and maintain a clean container environment.

  ## Usage

      mix container.cleanup [OPTIONS]
      mix container.cleanup
      mix container.cleanup --all

  ## Options

    * `--containers` - Clean up stopped containers (default: true)
    * `--images` - Clean up dangling images
    * `--volumes` - Clean up unused volumes
    * `--networks` - Clean up unused networks
    * `--all` - Clean up everything
    * `--dry - run` - Show what would be cleaned without doing it
    * `--force` - Skip confirmation prompts
    * `--older - than DURATION` - Clean resources older than duration (e.g., 24h, 7d)
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # Clean up stopped containers
      mix container.cleanup

      # Clean up everything with confirmation
      mix container.cleanup --all

      # Dry run to see what would be cleaned
      mix container.cleanup --all --dry - run

      # Clean containers older than 7 days
      mix container.cleanup --older - than 7d

  Created: 2025 - 08 - 05 17:57:00 CEST
  Framewor,k: SOPv5.1 + Container Resource Management
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Clean up stopped containers and unused resources"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, _} = parse_cleanup_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    validate_container_runtime!()

    # Determine what to clean
    cleanup_config = determine_cleanup_config(opts)

    # Perform cleanup analysis
    Mix.shell().info("🔍 Analyzing resources to clean up...")
    cleanup_plan = analyze_cleanup(cleanup_config, opts)

    # Show cleanup plan
    display_cleanup_plan(cleanup_plan, opts)

    # Execute cleanup if not dry run
    if opts[:dry_run] do
      Mix.shell().info("\nLock: Dry run mode - no changes made")
    else
      if cleanup_plan.total_items > 0 do
        if opts[:force] || confirm_cleanup(cleanup_plan) do
          execute_cleanup(cleanup_plan, opts)
        else
          Mix.shell().info("\nCleanup cancelled")
        end
      end
    end

    # Log to Claude
    ensure_claude_logging("cleanup", %{
      options: opts,
      plan: cleanup_plan,
      executed: !opts[:dry_run]
    })
  end

  @spec parse_cleanup_options(term()) :: term()
  defp parse_cleanup_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          containers: :boolean,
          images: :boolean,
          volumes: :boolean,
          networks: :boolean,
          all: :boolean,
          dry_run: :boolean,
          force: :boolean,
          older_than: :string,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          c: :containers,
          i: :images,
          v: :volumes,
          n: :networks,
          d: :dry_run,
          f: :force
        ]
      )

    # Default to cleaning containers if nothing specified
    final_opts =
      if !opts[:all] && !opts[:images] && !opts[:volumes] && !opts[:networks] do
        Keyword.put(opts, :containers, true)
      else
        opts
      end

    {final_opts, remaining_args}
  end

  @spec determine_cleanup_config(term()) :: term()
  defp determine_cleanup_config(opts) do
    if opts[:all] do
      %{
        containers: true,
        images: true,
        volumes: true,
        networks: true
      }
    else
      %{
        containers: opts[:containers] || false,
        images: opts[:images] || false,
        volumes: opts[:volumes] || false,
        networks: opts[:networks] || false
      }
    end
  end

  @spec analyze_cleanup(term(), term()) :: term()
  defp analyze_cleanup(config, opts) do
    plan = %{
      containers: [],
      images: [],
      volumes: [],
      networks: [],
      space_to_reclaim: 0,
      total_items: 0
    }

    plan =
      if config.containers do
        analyze_containers(plan, opts)
      else
        plan
      end

    plan =
      if config.images do
        analyze_images(plan, opts)
      else
        plan
      end

    plan =
      if config.volumes do
        analyze_volumes(plan, opts)
      else
        plan
      end

    plan =
      if config.networks do
        analyze_networks(plan, opts)
      else
        plan
      end

    # Calculate totals
    %{
      plan
      | total_items:
          length(plan.containers) + length(plan.images) +
            length(plan.volumes) + length(plan.networks)
    }
  end

  @spec analyze_containers(term(), term()) :: term()
  defp analyze_containers(plan, opts) do
    # Get stopped containers
    filter_args = ["ps", "-a", "--filter", "status = exited", "--format", "json"]

    # Add age filter if specified
    filter_args =
      if opts[:older_than] do
        filter_args ++ ["--filter", "_until =#{opts[:older_than]}"]
      else
        filter_args
      end

    case System.cmd("podman", filter_args, stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, containers} when is_list(containers) ->
            container_info =
              Enum.map(containers, fn c ->
                %{
                  id: String.slice(c["Id"] || "", 0, 12),
                  name: get_container_name(c),
                  image: c["Image"],
                  created: c["Created"],
                  size: parse_size(c["Size"]),
                  status: c["Status"]
                }
              end)

            total_size =
              Enum.reduce(container_info, 0, fn c, acc ->
                acc + c.size
              end)

            %{
              plan
              | containers: container_info,
                space_to_reclaim: plan.space_to_reclaim + total_size
            }

          _ ->
            plan
        end

      _ ->
        plan
    end
  end

  @spec analyze_images(term(), term()) :: term()
  defp analyze_images(plan, opts) do
    # Get dangling images
    case System.cmd("podman", ["images", "--filter", "dangling = true", "--format", "json"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, images} when is_list(images) ->
            image_info =
              Enum.map(images, fn img ->
                %{
                  id: String.slice(img["Id"] || "", 0, 12),
                  repository: img["Repository"] || "<none>",
                  tag: img["Tag"] || "<none>",
                  created: img["Created"],
                  size: parse_image_size(img["Size"])
                }
              end)

            # Filter by age if specified
            image_info =
              if opts[:older_than] do
                filter_by_age(image_info, opts[:older_than])
              else
                image_info
              end

            total_size =
              Enum.reduce(image_info, 0, fn img, acc ->
                acc + img.size
              end)

            %{plan | images: image_info, space_to_reclaim: plan.space_to_reclaim + total_size}

          _ ->
            plan
        end

      _ ->
        plan
    end
  end

  @spec analyze_volumes(term(), term()) :: term()
  defp analyze_volumes(plan, _opts) do
    # Get unused volumes
    case System.cmd("podman", ["volume", "ls", "--filter", "dangling = true", "--format", "json"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, volumes} when is_list(volumes) ->
            volume_info =
              Enum.map(volumes, fn vol ->
                %{
                  name: vol["Name"],
                  driver: vol["Driver"] || "local",
                  created: vol["CreatedAt"],
                  # Size calculation would require inspection
                  size: 0
                }
              end)

            %{plan | volumes: volume_info}

          _ ->
            plan
        end

      _ ->
        plan
    end
  end

  @spec analyze_networks(term(), term()) :: term()
  defp analyze_networks(plan, _opts) do
    # Get custom networks (excluding default ones)
    case System.cmd("podman", ["network", "ls", "--format", "json"], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, networks} when is_list(networks) ->
            # Filter out default networks
            custom_networks =
              networks
              |> Enum.filter(fn net ->
                name = net["Name"] || ""
                name not in ["bridge", "host", "none", "podman"]
              end)
              |> Enum.map(fn net ->
                %{
                  name: net["Name"],
                  driver: net["Driver"] || "bridge",
                  created: net["Created"]
                }
              end)

            %{plan | networks: custom_networks}

          _ ->
            plan
        end

      _ ->
        plan
    end
  end

  @spec get_container_name(term()) :: term()
  defp get_container_name(container) do
    case container["Names"] do
      [name | _] -> name
      _ -> container["Name"] || "unknown"
    end
  end

  @spec parse_size(term()) :: term()
  defp parse_size(nil), do: 0

  defp parse_size(size) when is_binary(size) do
    # Parse size string like "1.2 MB" or "500 KB"
    case Regex.run(~r/^([0 - 9.]+)\s*([A - Z]+)$/i, size) do
      [_, num_str, unit] ->
        case Float.parse(num_str) do
          {num, _} -> convert_to_bytes(num, String.upcase(unit))
          _ -> 0
        end

      _ ->
        0
    end
  end

  @spec parse_size(term()) :: term()
  defp parse_size(size) when is_number(size), do: size

  defp parse_image_size(size) when is_number(size), do: size
  @spec parse_image_size(term()) :: term()
  defp parse_image_size(_), do: 0

  defp convert_to_bytes(num, "B"), do: round(num)
  defp convert_to_bytes(num, "KB"), do: round(num * 1024)
  defp convert_to_bytes(num, "MB"), do: round(num * 1024 * 1024)
  defp convert_to_bytes(num, "GB"), do: round(num * 1024 * 1024 * 1024)
  defp convert_to_bytes(_, _), do: 0

  defp filter_by_age(items, _age_spec) do
    # TODO: Implement age filtering
    # For now, return all items
    items
  end

  @spec display_cleanup_plan(term(), term()) :: term()
  defp display_cleanup_plan(plan, opts) do
    Mix.shell().info("\\nClean: Cleanup Plan")
    Mix.shell().info("=" |> String.duplicate(60))

    if plan.total_items == 0 do
      Mix.shell().info("Success: Nothing to clean up!")
      return()
    end

    if plan.containers != [] do
      container_count = length(plan.containers)

      Mix.shell().info(
        "Container: Stopped Items - " <> Integer.to_string(container_count) <> " total"
      )

      Enum.each(plan.containers, fn c ->
        size_str = format_bytes(c.size)
        Mix.shell().info("  - #{c.name} (#{c.id}) - #{c.image} [#{size_str}]")

        if opts[:verbose] do
          Mix.shell().info("    Status: #{c.status}")
        end
      end)
    end

    if plan.images != [] do
      Mix.shell().info("\nImage:  Dangling Images (#{length(plan.images)}):")

      Enum.each(plan.images, fn img ->
        size_str = format_bytes(img.size)
        Mix.shell().info("  - #{img.id} - #{img.repository}:#{img.tag} [#{size_str}]")
      end)
    end

    if plan.volumes != [] do
      Mix.shell().info("\nStorage: Unused Volumes (#{length(plan.volumes)}):")

      Enum.each(plan.volumes, fn vol ->
        Mix.shell().info("  - #{vol.name} (#{vol.driver})")
      end)
    end

    if plan.networks != [] do
      Mix.shell().info("\nNetwork: Unused Networks (#{length(plan.networks)}):")

      Enum.each(plan.networks, fn net ->
        Mix.shell().info("  - #{net.name} (#{net.driver})")
      end)
    end

    Mix.shell().info("\n[STATS] Summary:")
    Mix.shell().info("  Total items to clean: #{plan.total_items}")

    if plan.space_to_reclaim > 0 do
      Mix.shell().info("  Space to reclaim: #{format_bytes(plan.space_to_reclaim)}")
    end
  end

  @spec format_bytes(term()) :: term()
  defp format_bytes(0), do: "0B"
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"

  defp format_bytes(bytes) when bytes < 1024 * 1024 do
    kb = Float.round(bytes / 1024, 1)
    "#{kb}KB"
  end

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024 do
    mb = Float.round(bytes / (1024 * 1024), 1)
    "#{mb}MB"
  end

  defp format_bytes(bytes) do
    gb = Float.round(bytes / (1024 * 1024 * 1024), 2)
    "#{gb}GB"
  end

  @spec confirm_cleanup(term()) :: term()
  defp confirm_cleanup(_plan) do
    Mix.shell().yes?("\nQuestion: Do you want to proceed with cleanup?")
  end

  @spec execute_cleanup(term(), term()) :: term()
  defp execute_cleanup(plan, opts) do
    Mix.shell().info("\nClean: Executing cleanup...")

    results = %{
      containers: 0,
      images: 0,
      volumes: 0,
      networks: 0,
      errors: []
    }

    # Clean containers
    results =
      if plan.containers != [] do
        clean_containers(plan.containers, results, opts)
      else
        results
      end

    # Clean images
    results =
      if plan.images != [] do
        clean_images(plan.images, results, opts)
      else
        results
      end

    # Clean volumes
    results =
      if plan.volumes != [] do
        clean_volumes(plan.volumes, results, opts)
      else
        results
      end

    # Clean networks
    results =
      if plan.networks != [] do
        clean_networks(plan.networks, results, opts)
      else
        results
      end

    # Display results
    display_cleanup_results(results, plan)
  end

  defp clean_containers(containers, results, opts) do
    Mix.shell().info("\nContainer: Cleaning containers...")

    Enum.reduce(containers, results, fn container, acc ->
      if opts[:verbose] do
        Mix.shell().info("  Removing #{container.name}...")
      end

      case System.cmd("podman", ["rm", container.id], stderr_to_stdout: true) do
        {_, 0} ->
          %{acc | containers: acc.containers + 1}

        {error, _} ->
          %{acc | errors: acc.errors ++ [{:container, container.name, String.trim(error)}]}
      end
    end)
  end

  defp clean_images(images, results, opts) do
    Mix.shell().info("\nImage:  Cleaning images...")

    Enum.reduce(images, results, fn image, acc ->
      if opts[:verbose] do
        Mix.shell().info("  Removing image #{image.id}...")
      end

      case System.cmd("podman", ["rmi", image.id], stderr_to_stdout: true) do
        {_, 0} ->
          %{acc | images: acc.images + 1}

        {error, _} ->
          %{acc | errors: acc.errors ++ [{:image, image.id, String.trim(error)}]}
      end
    end)
  end

  defp clean_volumes(volumes, results, opts) do
    Mix.shell().info("\nStorage: Cleaning volumes...")

    Enum.reduce(volumes, results, fn volume, acc ->
      if opts[:verbose] do
        Mix.shell().info("  Removing volume #{volume.name}...")
      end

      case System.cmd("podman", ["volume", "rm", volume.name], stderr_to_stdout: true) do
        {_, 0} ->
          %{acc | volumes: acc.volumes + 1}

        {error, _} ->
          %{acc | errors: acc.errors ++ [{:volume, volume.name, String.trim(error)}]}
      end
    end)
  end

  defp clean_networks(networks, results, opts) do
    Mix.shell().info("\nNetwork: Cleaning networks...")

    Enum.reduce(networks, results, fn network, acc ->
      if opts[:verbose] do
        Mix.shell().info("  Removing network #{network.name}...")
      end

      case System.cmd("podman", ["network", "rm", network.name], stderr_to_stdout: true) do
        {_, 0} ->
          %{acc | networks: acc.networks + 1}

        {error, _} ->
          %{acc | errors: acc.errors ++ [{:network, network.name, String.trim(error)}]}
      end
    end)
  end

  @spec display_cleanup_results(term(), term()) :: term()
  defp display_cleanup_results(results, plan) do
    Mix.shell().info("\nResults: Cleanup Results")
    Mix.shell().info("=" |> String.duplicate(60))

    if results.containers > 0 do
      Mix.shell().info("Success: Removed #{results.containers} containers")
    end

    if results.images > 0 do
      Mix.shell().info("Success: Removed #{results.images} images")
    end

    if results.volumes > 0 do
      Mix.shell().info("Success: Removed #{results.volumes} volumes")
    end

    if results.networks > 0 do
      Mix.shell().info("Success: Removed #{results.networks} networks")
    end

    if results.errors != [] do
      Mix.shell().error("\nWarning:  Errors encountered:")

      Enum.each(results.errors, fn {type, name, error} ->
        Mix.shell().error("  - Failed to remove #{type} '#{name}': #{error}")
      end)
    end

    total_cleaned = results.containers + results.images + results.volumes + results.networks

    if total_cleaned > 0 && plan.space_to_reclaim > 0 do
      Mix.shell().info("\nStorage: Space reclaimed: #{format_bytes(plan.space_to_reclaim)}")
    end
  end

  @spec return() :: any()
  defp return, do: :ok
end
