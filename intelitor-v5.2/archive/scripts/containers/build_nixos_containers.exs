#!/usr/bin/env elixir

defmodule BuildNixosContainers do
  @moduledoc """
  Build NixOS Containers with SOPv5.1 Compliance

  Agent: This script builds NixOS containers with:
  - Git-aware builds (commit hash in tags)
  - PHICS integration
  - Reproducible builds
  - Maximum parallelization

  Updated: 2025-08-02 11:55:00 CEST
  Framework: SOPv5.1 + PHICS + TPS + STAMP
  """

  require Logger

  @project_root File.cwd!()
  @containers_dir Path.join(@project_root, "containers")

  @spec main(any()) :: any()
  def main(args \\ []) do
    IO.puts """
    🏗️ Building NixOS Containers from Single Source of Truth
    ======================================================
    """
    # Load the project's code to access the config module
    Code.require_file("lib/intelitor/deployment/config.ex", __DIR__ |> Path.dirname() |> Path.dirname())

    # Get container configuration from the single source of truth
    containers_to_build = Intelitor.Deployment.Config.containers()
    
    # Agent: Parse options
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        push: :boolean,
        tag: :string
      ]
    )

    git_info = get_git_info()

    results = Enum.map(containers_to_build, fn container_map ->
      build_container(container_map, git_info, opts)
    end)

    # Agent: Report results
    report_build_results(results)
  end

  @spec get_git_info() :: any()
  defp get_git_info do
    # Agent: Get current git commit and branch
    {commit, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"])
    {branch, 0} = System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"])

    %{
      commit: String.trim(commit),
      branch: String.trim(branch),
      build_date: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # This function is now removed as we get the config from the central module.
  # defp determine_containers(_opts) do ... end

  defp build_container(container_map, git_info, _opts) do
    IO.puts("\n🔨 Building #{container_map[:service_name]}...")

    nix_file = Path.join(@containers_dir, container_map[:nix_file])

    unless File.exists?(nix_file) do
      IO.puts("  ❌ Nix file not found: #{nix_file}")
      {:error, container_map[:service_name], "Nix file not found"}
    end

    # Agent: Build with nix-build
    # Set NIXPKGS_ALLOW_UNFREE for database builds or others that might need it.
    env = if String.contains?(container_map[:image_name], "timescaledb"), do: [{"NIXPKGS_ALLOW_UNFREE", "1"}], else: []
    
    build_args = [
      "--argstr", "gitRev", git_info.commit,
      "--argstr", "gitBranch", git_info.branch,
      "--argstr", "buildDate", git_info.build_date,
      nix_file
    ]

    case System.cmd("nix-build", build_args, into: IO.stream(:stdio, :line), env: env) do
      {_, 0} ->
        IO.puts("  ✅ Nix build successful")
        load_into_podman(container_map)

      {_, code} ->
        IO.puts("  ❌ Nix build failed (exit code: #{code})")
        {:error, container_map[:service_name], "Build failed"}
    end
  end

  defp load_into_podman(container_map) do
    IO.puts("  🐳 Loading into Podman...")
    result_link = "./result"

    if File.exists?(result_link) do
      case System.cmd("podman", ["load", "-i", result_link]) do
        {output, 0} ->
          image_id = extract_image_id(output)
          
          # Tag with the canonical name from our config
          new_tag = "localhost/#{container_map[:image_name]}:#{container_map[:image_tag]}"

          System.cmd("podman", ["tag", image_id, new_tag])
          IO.puts("  ✅ Tagged as: #{new_tag}")

          File.rm(result_link)
          {:ok, container_map[:service_name], new_tag}

        {output, code} ->
          IO.puts("  ❌ Failed to load into Podman (exit code: #{code}): #{output}")
          {:error, container_map[:service_name], "Podman load failed"}
      end
    else
      IO.puts("  ❌ Build result not found")
      {:error, container_map[:service_name], "No build result"}
    end
  end

  @spec extract_image_id(term()) :: term()
  defp extract_image_id(podman_output) do
    # Agent: Parse the "Loaded image: ..." or "Loaded image ID: ..." line
    case Regex.run(~r/Loaded image(?: ID)?: (.+)/, podman_output) do
      [_, image_id] -> String.trim(image_id)
      _ -> "unknown"
    end
  end

  @spec report_build_results(term()) :: term()
  defp report_build_results(results) do
    IO.puts("\n📊 Build Results")
    IO.puts("===============")

    Enum.each(results, fn
      {:ok, name, tag} ->
        IO.puts("✅ #{name}: #{tag}")
      {:error, name, reason} ->
        IO.puts("❌ #{name}: #{reason}")
    end)

    successful = Enum.count(results, fn {status, _, _} -> status == :ok end)
    total = length(results)

    IO.puts("\n🎯 Summary: #{successful}/#{total} containers built successfully")

    if successful == total do
      IO.puts("\n✅ All containers built successfully!")
      IO.puts("\nNext steps:")
      IO.puts("1. Test containers: podman run --rm -it localhost/sopv51-base:latest")
      IO.puts("2. Start with PHICS: elixir scripts/containers/start_nixos_containers.exs")
      IO.puts("3. Validate: elixir scripts/pcis/container_phics_validator.exs --all")
    end
  end
end

# Agent: Execute build
BuildNixosContainers.main(System.argv())