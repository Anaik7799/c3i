#!/usr/bin/env elixir

defmodule LocalRegistrySetup do
  @moduledoc """
  📦 Local Container Registry Setup for SOPv5.1

  Agent: This script sets up a local Podman registry for NixOS containers
  with comprehensive features:-Local registry deployment with Podman
  - TLS certificate generation
  - Registry authentication setup
  - Container-only execution enforcement
  - PHICS integration validation
  - No timeout restrictions
  - Maximum parallelization
  - TPS 5-Level RCA for failures

  Updated: 2025-08-02 12:20:00 CEST
  Framework: SOPv5.1 + PHICS + TPS + STAMP + TDG + GDE
  """

  require Logger

  @project_root File.cwd!()
  @registry_dir Path.join(@project_root, ".local-registry")
  @registry_port 5000
  @registry_name "intelitor-registry"

  @spec main(any()) :: any()
  def main(args \\ []) do
    # Agent: Current timestamp for tracking
    current_time = DateTime.utc_now()

    IO.puts """
    📦 Local Container Registry Setup
    =================================
    Project Root: #{@project_root}
    Timestamp: #{current_time |> DateTime.to_iso8601()}
    Framework: SOPv5.1 Cybernetic Goal-Oriented Execution

    🏭 TPS 5-Level RCA Preemptive Analysis:
    Level 1: Enable local container storage
    Level 2: Secure registry with TLS
    Level 3: Fast container distribution
    Level 4: Automated registry management
    Level 5: Systematic deployment workflow
    """

    # Agent: Parse command options
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        deploy: :boolean,
        stop: :boolean,
        status: :boolean,
        push: :string,
        pull: :string,
        list: :boolean,
        cleanup: :boolean,
        configure_tls: :boolean
      ]
    )

    # Agent: Phase 0-Goal Analysis (GDE)
    registry_goal = analyze_registry_goal(opts)
    IO.puts("\n🎯 Registry Goal: #{registry_goal}")

    # Agent: Phase 1-Environment Validation
    case validate_registry_environment() do
      :ok ->
        IO.puts("✅ Registry environment validated")

        # Agent: Phase 2-Execute registry operations
        execute_registry_operations(opts)

      {:error, reason} ->
        IO.puts("❌ Registry environment validation failed")
        perform_registry_rca(reason)
        System.halt(1)
    end
  end

  @spec analyze_registry_goal(term()) :: term()
  defp analyze_registry_goal(opts) do
    cond do
      opts[:deploy] -> "Deploy local container registry"
      opts[:stop] -> "Stop registry container"
      opts[:status] -> "Check registry status"
      opts[:push] -> "Push container: #{opts[:push]}"
      opts[:pull] -> "Pull container: #{opts[:pull]}"
      opts[:list] -> "List registry contents"
      opts[:cleanup] -> "Clean up registry data"
      opts[:configure_tls] -> "Configure TLS certificates"
      true -> "Complete registry setup"
    end
  end

  @spec validate_registry_environment() :: any()
  defp validate_registry_environment do
    # Agent: Check container environment
    unless in_container?() do
      {:error, :not_in_container}
    else
      # Agent: Check PHICS enabled
      unless System.get_env("PHICS_ENABLED") == "true" do
        {:error, :phics_disabled}
      else
        # Agent: Check Podman availability
        case System.cmd("podman", ["--version"]) do
          {_, 0} -> :ok
          _ -> {:error, :podman_not_available}
        end
      end
    end
  end

  @spec in_container?() :: any()
  defp in_container? do
    File.exists?("/.containerenv") or
    File.exists?("/run/.containerenv") or
    File.exists?("/.phics-container") or
    System.get_env("CONTAINER_ENFORCEMENT") == "true"
  end

  @spec execute_registry_operations(term()) :: term()
  defp execute_registry_operations(opts) do
    # Agent: Ensure registry directory exists
    File.mkdir_p!(@registry_dir)
    File.mkdir_p!(Path.join(@registry_dir, "data"))
    File.mkdir_p!(Path.join(@registry_dir, "certs"))
    File.mkdir_p!(Path.join(@registry_dir, "auth"))

    # Agent: Execute requested operations
    cond do
      opts[:deploy] -> deploy_registry()
      opts[:stop] -> stop_registry()
      opts[:status] -> check_registry_status()
      opts[:push] -> push_container(opts[:push])
      opts[:pull] -> pull_container(opts[:pull])
      opts[:list] -> list_registry_contents()
      opts[:cleanup] -> cleanup_registry()
      opts[:configure_tls] -> configure_tls()
      true -> complete_setup()
    end
  end

  @spec deploy_registry() :: any()
  defp deploy_registry do
    IO.puts("\n🚀 Deploying local registry...")

    # Agent: Check if registry already running
    case System.cmd("podman", ["ps", "-a", "--filter", "name=#{@registry_name}",
      {"running\n", 0} ->
        IO.puts("  ⚠️  Registry already running")

      _ ->
        # Agent: Generate TLS certificates first
        unless File.exists?(Path.join(@registry_dir, "certs/registry.crt")) do
          configure_tls()
        end

        # Agent: Create htpasswd for authentication
        create_auth_file()

        # Agent: Deploy registry container
        deploy_cmd = [
          "run", "-d",
          "--name", @registry_name,
          "-p", "#{@registry_port}:5000",
          "-v", "#{@registry_dir}/data:/var/lib/registry:z",
          "-v", "#{@registry_dir}/certs:/certs:z",
          "-v", "#{@registry_dir}/auth:/auth:z",
          "-e", "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt",
          "-e", "REGISTRY_HTTP_TLS_KEY=/certs/registry.key",
          "-e", "REGISTRY_AUTH=htpasswd",
          "-e", "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm",
          "-e", "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd",
          "-e", "REGISTRY_STORAGE_DELETE_ENABLED=true",
          "--restart", "always",
          "registry.nixos.org/nixos/registry:2"
        ]

        IO.puts("  🐳 Starting registry container...")

        case System.cmd("podman", deploy_cmd) do
          {container_id, 0} ->
            IO.puts("  ✅ Registry deployed: #{String.trim(container_id)}")
            IO.puts("  📍 Registry URL: https://localhost:#{@registry_port}")

            # Agent: Wait for registry to be healthy
            :timer.sleep(3000)

            # Agent: Test registry connectivity
            test_registry_connection()

          {error, _} ->
            IO.puts("  ❌ Deployment failed: #{error}")
        end
    end
  end

  @spec stop_registry() :: any()
  defp stop_registry do
    IO.puts("\n🛑 Stopping registry...")

    case System.cmd("podman", ["stop", @registry_name]) do
      {_, 0} ->
        IO.puts("  ✅ Registry stopped")

        case System.cmd("podman", ["rm", @registry_name]) do
          {_, 0} -> IO.puts("  ✅ Registry container removed")
          _ -> IO.puts("  ⚠️  Could not remove container")
        end

      {error, _} ->
        IO.puts("  ❌ Stop failed: #{error}")
    end
  end

  @spec check_registry_status() :: any()
  defp check_registry_status do
    IO.puts("\n📊 Registry Status")
    IO.puts("==================")

    # Agent: Check container status
    case System.cmd("podman", ["ps", "-a", "--filter", "name=#{@registry_name}",
      {output, 0} ->
        IO.puts(output)

        # Agent: Check registry catalog if running
        case System.cmd("podman", ["ps", "--filter", "name=#{@registry_name}", "-
          {"running\n", 0} ->
            IO.puts("\n📚 Registry Catalog:")
            list_registry_contents()

          _ ->
            IO.puts("\n⚠️  Registry not running")
        end

      {error, _} ->
        IO.puts("  ❌ Status check failed: #{error}")
    end
  end

  @spec push_container(term()) :: term()
  defp push_container(container) do
    IO.puts("\n📤 Pushing container: #{container}")

    # Agent: Tag container for local registry
    local_tag = "localhost:#{@registry_port}/#{container}"

    IO.puts("  🏷️  Tagging as: #{local_tag}")

    case System.cmd("podman", ["tag", container, local_tag]) do
      {_, 0} ->
        IO.puts("  ✅ Tagged successfully")

        # Agent: Push to registry with no timeout
        IO.puts("  📤 Pushing to registry (no timeout)...")

        case System.cmd("podman", ["push", "--tls-verify=false", local_tag],
                        into: IO.stream(:stdio, :line)) do
          {_, 0} ->
            IO.puts("  ✅ Push completed successfully")

          {error, _} ->
            IO.puts("  ❌ Push failed: #{error}")
        end

      {error, _} ->
        IO.puts("  ❌ Tagging failed: #{error}")
    end
  end

  @spec pull_container(term()) :: term()
  defp pull_container(container) do
    IO.puts("\n📥 Pulling container: #{container}")

    local_tag = "localhost:#{@registry_port}/#{container}"

    case System.cmd("podman", ["pull", "--tls-verify=false", local_tag],
                    into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        IO.puts("  ✅ Pull completed successfully")

      {error, _} ->
        IO.puts("  ❌ Pull failed: #{error}")
    end
  end

  @spec list_registry_contents() :: any()
  defp list_registry_contents do
    # Agent: Use curl to access registry API
    catalog_url = "https://localhost:#{@registry_port}/v2/_catalog"

    case System.cmd("curl", ["-k", "-s", catalog_url]) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, %{"repositories" => repos}} ->
            if Enum.empty?(repos) do
              IO.puts("  (empty)")
            else
              Enum.each(repos, fn repo ->
                IO.puts("-#{repo}")
                list_repository_tags(repo)
              end)
            end

          _ ->
            IO.puts("  ⚠️  Could not parse catalog response")
        end

      {error, _} ->
        IO.puts("  ❌ Catalog request failed: #{error}")
    end
  end

  @spec list_repository_tags(term()) :: term()
  defp list_repository_tags(repo) do
    tags_url = "https://localhost:#{@registry_port}/v2/#{repo}/tags/list"

    case System.cmd("curl", ["-k", "-s", tags_url]) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, %{"tags" => tags}} when is_list(tags) ->
            Enum.each(tags, fn tag ->
              IO.puts("    └─ #{tag}")
            end)

          _ -> nil
        end

      _ -> nil
    end
  end

  @spec cleanup_registry() :: any()
  defp cleanup_registry do
    IO.puts("\n🧹 Cleaning up registry...")

    # Agent: Stop registry first
    stop_registry()

    # Agent: Remove registry data
    if File.exists?(@registry_dir) do
      IO.puts("  🗑️  Removing registry data...")
      File.rm_rf!(@registry_dir)
      IO.puts("  ✅ Registry data removed")
    end
  end

  @spec configure_tls() :: any()
  defp configure_tls do
    IO.puts("\n🔐 Configuring TLS certificates...")

    certs_dir = Path.join(@registry_dir, "certs")
    cert_file = Path.join(certs_dir, "registry.crt")
    key_file = Path.join(certs_dir, "registry.key")

    if File.exists?(cert_file) do
      IO.puts("  ⚠️  Certificates already exist")
    else
      # Agent: Generate self-signed certificate
      openssl_cmd = [
        "req", "-newkey", "rsa:4096",
        "-nodes", "-sha256",
        "-keyout", key_file,
        "-x509", "-days", "365",
        "-out", cert_file,
        "-subj", "/C=US/ST=State/L=City/O=Intelitor/CN=localhost"
      ]

      case System.cmd("openssl", openssl_cmd) do
        {_, 0} ->
          IO.puts("  ✅ TLS certificates generated")

          # Agent: Set proper permissions
          File.chmod!(cert_file, 0o644)
          File.chmod!(key_file, 0o600)

        {error, _} ->
          IO.puts("  ❌ Certificate generation failed: #{error}")
      end
    end
  end

  @spec create_auth_file() :: any()
  defp create_auth_file do
    IO.puts("\n🔑 Creating authentication file...")

    auth_dir = Path.join(@registry_dir, "auth")
    htpasswd_file = Path.join(auth_dir, "htpasswd")

    if File.exists?(htpasswd_file) do
      IO.puts("  ⚠️  Auth file already exists")
    else
      # Agent: Create htpasswd with default credentials
      # Username: intelitor, Password: sopv51secure
      htpasswd_cmd = [
        "run", "--rm",
        "--entrypoint", "htpasswd",
        "registry.nixos.org/nixos/httpd:2.4",
        "-Bbn", "intelitor", "sopv51secure"
      ]

      case System.cmd("podman", htpasswd_cmd) do
        {htpasswd_data, 0} ->
          File.write!(htpasswd_file, htpasswd_data)
          IO.puts("  ✅ Authentication configured")
          IO.puts("  👤 Username: intelitor")
          IO.puts("  🔐 Password: sopv51secure")

        {error, _} ->
          IO.puts("  ❌ Auth creation failed: #{error}")
      end
    end
  end

  @spec test_registry_connection() :: any()
  defp test_registry_connection do
    IO.puts("\n🧪 Testing registry connection...")

    # Agent: Test registry API
    case System.cmd("curl", ["-k", "-s", "https://localhost:#{@registry_port}/v2/
      {"{}", 0} ->
        IO.puts("  ✅ Registry API accessible")

      {error, _} ->
        IO.puts("  ❌ Connection test failed: #{error}")
    end
  end

  @spec complete_setup() :: any()
  defp complete_setup do
    IO.puts("\n📋 Complete Registry Setup")
    IO.puts("=========================")

    # Agent: Run all setup steps
    configure_tls()
    deploy_registry()

    IO.puts("\n📝 Registry Configuration:")
    IO.puts("  URL: https://localhost:#{@registry_port}")
    IO.puts("  Username: intelitor")
    IO.puts("  Password: sopv51secure")
    IO.puts("  TLS: Self-signed certificate")

    IO.puts("\n🔧 Usage Examples:")
    IO.puts("  # Tag and push:")
    IO.puts("  podman tag myimage localhost:#{@registry_port}/myimage:latest")
    IO.puts("  podman push --tls-verify=false localhost:#{@registry_port}/myimage
    IO.puts("\n  # Pull from registry:")
    IO.puts("  podman pull --tls-verify=false localhost:#{@registry_port}/myimage
  end

  @spec perform_registry_rca(term()) :: term()
  defp perform_registry_rca(reason) do
    IO.puts """

    🏭 TPS 5-Level Root Cause Analysis
    ==================================

    Registry Environment Failure: #{inspect(reason)}

    Level 1 (Symptom): Registry environment validation failed
    Level 2 (Surface Cause): #{get_registry_surface_cause(reason)}
    Level 3 (System Behavior): #{get_registry_system_behavior(reason)}
    Level 4 (Configuration Gap): #{get_registry_config_gap(reason)}
    Level 5 (Design Analysis): #{get_registry_design_analysis(reason)}
    """
  end

  @spec get_registry_surface_cause(term()) :: term()
  defp get_registry_surface_cause(:not_in_container), do: "Registry setup outside container"
  defp get_registry_surface_cause(:phics_disabled), do: "PHICS not enabled"
  defp get_registry_surface_cause(:podman_not_available), do: "Podman not installed"
  @spec get_registry_surface_cause(term()) :: term()
  defp get_registry_surface_cause(_), do: "Environment configuration issue"

  defp get_registry_system_behavior(:not_in_container), do: "Registry isolation not guaranteed"
  @spec get_registry_system_behavior(term()) :: term()
  defp get_registry_system_behavior(:phics_disabled), do: "Development workflow broken"
  defp get_registry_system_behavior(:podman_not_available), do: "Cannot manage containers"
  defp get_registry_system_behavior(_), do: "Registry reliability compromised"

  @spec get_registry_config_gap(term()) :: term()
  defp get_registry_config_gap(:not_in_container), do: "Container enforcement missing"
  defp get_registry_config_gap(:phics_disabled), do: "PHICS auto-enablement needed"
  defp get_registry_config_gap(:podman_not_available), do: "Podman installation required"
  @spec get_registry_config_gap(term()) :: term()
  defp get_registry_config_gap(_), do: "Configuration automation needed"

  defp get_registry_design_analysis(:not_in_container), do: "Implement container-only registry"
  @spec get_registry_design_analysis(term()) :: term()
  defp get_registry_design_analysis(:phics_disabled), do: "Enable PHICS by default"
  defp get_registry_design_analysis(:podman_not_available), do: "Include Podman in environment"
  defp get_registry_design_analysis(_), do: "Comprehensive registry validation"
end

# Agent: Install Jason for JSON handling
Mix.install([{:jason, "~> 1.4"}])

# Agent: Execute local registry setup
LocalRegistrySetup.main(System.argv())
end
end
end
end
end
end
end
end
end
end
end
end
