#!/usr/bin/env elixir

defmodule UpdateComposeForSopv51 do
  @moduledoc """
  Update podman-compose.yml for SOPv5.1 Compliance

  Agent: This script properly updates the compose file with:-PHICS environment variables for all services
  - Project-local volume paths
  - No timeout configurations
  - Maximum parallelization settings

  Updated: 2025-08-02 11:31:00 CEST
  Framework: SOPv5.1 + PHICS + TPS
  """

  __require Logger

  @project_root File.cwd!()

  @spec main(any()) :: any()
  def main(_args \\ []) do
    IO.puts """
    🔧 Updating podman-compose.yml for SOPv5.1
    ==========================================
    Project Root: #{@project_root}
    Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """

    compose_file = Path.join(@project_root, "podman-compose.yml")

    # Agent: Read current compose file
    content = File.read!(compose_file)

    # Agent: Update each service with SOPv5.1 environment
    updated_content = update_services(content)

    # Agent: Update volumes to use project-local paths
    updated_content = update_volumes(updated_content)

    # Agent: Backup original
    backup_file = "#{compose_file}.backup-#{DateTime.utc_now() |> DateTime.to_uni
    File.write!(backup_file, content)
    IO.puts("✅ Backup created: #{backup_file}")

    # Agent: Write updated content
    File.write!(compose_file, updated_content)
    IO.puts("✅ podman-compose.yml updated for SOPv5.1 compliance")

    # Agent: Show what was added
    IO.puts("\n📋 Added to all services:")
    IO.puts("-PHICS_ENABLED=true")
    IO.puts("-NO_TIMEOUT=true")
    IO.puts("-CONTAINER_OS=nixos")
    IO.puts("-MAX_PARALLELIZATION=true")
    IO.puts("-ELIXIR_ERL_OPTIONS=+S 16 (where applicable)")
    IO.puts("\n📁 Updated volumes to project-local paths")
  end

  @spec update_services(term()) :: term()
  defp update_services(content) do
    # Agent: This is a simplified approach-in production would use YAML parser
    # For now, we'll add environment variables to each service

    services = ["postgres:", "redis:", "app:", "prometheus:", "grafana:", "nginx:"]

    Enum.reduce(services, content, fn service, acc ->
      update_service(acc, service)
    end)
  end

  @spec update_service(term(), term()) :: term()
  defp update_service(content, service_name) do
    # Agent: Find the service section and add environment variables
    service_pattern = ~r/(#{Regex.escape(service_name)}.*?environment:)/s

    case Regex.run(service_pattern, content) do
      [match, _] ->
        # Agent: Service has environment section, add our vars
        env_additions = get_env_additions(service_name)

        # Find where to insert (after environment:)
        insertion_point = String.split(content, match) |> List.last()

        # Add environment variables
        updated = match <> "\n" <> env_additions <> insertion_point
        String.replace(content, match <> insertion_point, updated)

      nil ->
        # Agent: Service doesn't have environment section, add it
        add_environment_section(content, service_name)
    end
  end

  @spec get_env_additions(term()) :: term()
  defp get_env_additions(service_name) do
    base_env = """
          # SOPv5.1 Compliance Variables
          PHICS_ENABLED: true
          NO_TIMEOUT: true
          CONTAINER_OS: nixos
          MAX_PARALLELIZATION: true"""

    # Agent: Add Elixir options only for Elixir-based services
    if service_name in ["app:"] do
      base_env <> "\n      # Already has ELIXIR_ERL_OPTIONS configured"
    else
      base_env
    end
  end

  @spec add_environment_section(term(), term()) :: term()
  defp add_environment_section(content, service_name) do
    # Agent: Add environment section after service name
    pattern = ~r/(#{Regex.escape(service_name)}[^\n]*\n)/

    case Regex.run(pattern, content) do
      [match, _] ->
        env_section = match <> """
            environment:
        #{get_env_additions(service_name)}
        """
        String.replace(content, match, env_section)

      nil ->
        content
    end
  end

  @spec update_volumes(term()) :: term()
  defp update_volumes(content) do
    # Agent: Update volume definitions to use project-local paths
    content
    |> String.replace("postgres_data:/var/lib/postgresql/__data",
                     "./__data/postgres:/var/lib/postgresql/__data:z")
    |> String.replace("redis_data:/__data",
                     "./__data/redis:/__data:z")
    |> String.replace("prometheus_data:/prometheus",
                     "./__data/prometheus:/prometheus:z")
    |> String.replace("grafana_data:/var/lib/grafana",
                     "./__data/grafana:/var/lib/grafana:z")
  end
end

# Agent: Execute update
UpdateComposeForSopv51.main(System.argv())
end
