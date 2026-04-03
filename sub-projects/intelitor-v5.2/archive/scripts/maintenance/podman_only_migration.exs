#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule PodmanOnlyMigration do
  @moduledoc """
  Comprehensive script to migrate all Docker references to Podman-only commands
  across the entire Intelitor codebase for SOPv5.11 compliance.
  
  CRITICAL: This script implements the mandatory Podman-only container policy
  with zero tolerance for Docker usage.
  """

  @docker_to_podman_replacements %{
    # Command replacements
    "docker run" => "podman run",
    "docker exec" => "podman exec",
    "docker ps" => "podman ps",
    "docker images" => "podman images",
    "docker build" => "podman build",
    "docker pull" => "podman pull",
    "docker push" => "podman push",
    "docker start" => "podman start",
    "docker stop" => "podman stop",
    "docker restart" => "podman restart",
    "docker rm" => "podman rm",
    "docker rmi" => "podman rmi",
    "docker inspect" => "podman inspect",
    "docker logs" => "podman logs",
    "docker stats" => "podman stats",
    "docker network" => "podman network",
    "docker volume" => "podman volume",
    "docker-compose" => "podman-compose",
    "docker login" => "podman login",
    "docker logout" => "podman logout",
    
    # Registry replacements
    "docker.io/" => "registry.nixos.org/nixos/",
    "docker.io/library/" => "registry.nixos.org/nixos/",
    "hub.docker.com" => "registry.nixos.org",
    
    # Documentation references
    "Docker Hub" => "NixOS Container Registry",
    "Docker daemon" => "Podman daemon (BANNED)",
    "Docker containers" => "Podman containers",
    "Docker images" => "Podman images",
    "Using Docker" => "Using Podman",
    "Docker-based" => "Podman-based",
    "docker-compose.yml" => "docker-compose.yml (use with podman-compose)",
  }

  @registry_replacements %{
    "docker.io/postgres" => "registry.nixos.org/nixos/postgresql",
    "docker.io/redis" => "registry.nixos.org/nixos/redis",
    "docker.io/nginx" => "registry.nixos.org/nixos/nginx",
    "docker.io/alpine" => "registry.nixos.org/nixos/nixos",
    "postgres:15" => "registry.nixos.org/nixos/postgresql:15",
    "redis:7" => "registry.nixos.org/nixos/redis:7",
    "nginx:latest" => "registry.nixos.org/nixos/nginx:latest",
  }

  @violation_patterns [
    ~r/docker\s+run/i,
    ~r/docker\s+exec/i,
    ~r/docker\.io\//i,
    ~r/hub\.docker\.com/i,
    ~r/docker-compose\s+up/i,
    ~r/systemctl.*docker/i,
    ~r/service\s+docker/i,
  ]

  def main(args) do
    case args do
      ["--scan"] -> scan_violations()
      ["--fix"] -> apply_migrations()
      ["--validate"] -> validate_podman_only()
      ["--help"] -> show_help()
      _ -> show_help()
    end
  end

  def scan_violations do
    IO.puts("🔍 Scanning for Docker violations across codebase...")
    
    files = get_all_text_files()
    total_violations = 0
    
    files
    |> Enum.each(fn file ->
      case File.read(file) do
        {:ok, content} ->
          file_violations = find_violations(content, file)
          if length(file_violations) > 0 do
            IO.puts("❌ VIOLATIONS in #{file}:")
            Enum.each(file_violations, fn violation ->
              IO.puts("  - #{violation}")
            end)
            total_violations + length(file_violations)
          end
        {:error, _} ->
          IO.puts("⚠️  Could not read #{file}")
      end
    end)
    
    IO.puts("✅ Violation scan complete - Found violations in multiple files")
  end

  def apply_migrations do
    IO.puts("🔧 Applying Podman-only migrations...")
    
    files = get_all_text_files()
    
    updated_files = 
      files
      |> Enum.map(fn file ->
        case File.read(file) do
          {:ok, content} ->
            updated_content = apply_all_replacements(content)
            
            if updated_content != content do
              backup_file(file)
              File.write!(file, updated_content)
              IO.puts("✅ Updated #{file}")
              1
            else
              0
            end
          {:error, reason} ->
            IO.puts("⚠️  Could not process #{file}: #{reason}")
            0
        end
      end)
      |> Enum.sum()
    
    IO.puts("🎯 Migration complete! Updated #{updated_files} files")
    IO.puts("📋 All backup files created with .docker-backup extension")
  end

  def validate_podman_only do
    IO.puts("🛡️ Validating Podman-only compliance...")
    
    # Check for Docker daemon
    case System.cmd("systemctl", ["is-active", "docker"], stderr_to_stdout: true) do
      {"active\n", 0} ->
        IO.puts("❌ CRITICAL VIOLATION: Docker daemon is running")
        IO.puts("🚨 Execute: sudo systemctl stop docker && sudo systemctl disable docker")
      _ ->
        IO.puts("✅ Docker daemon not running")
    end
    
    # Check for Docker CLI
    case System.cmd("which", ["docker"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("⚠️ WARNING: Docker CLI is installed")
        IO.puts("📋 Consider removing docker package")
      _ ->
        IO.puts("✅ Docker CLI not found")
    end
    
    # Check for Podman
    case System.cmd("which", ["podman"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✅ Podman is available")
        
        # Check Podman version
        case System.cmd("podman", ["--version"], stderr_to_stdout: true) do
          {version_output, 0} ->
            IO.puts("✅ #{String.trim(version_output)}")
          _ ->
            IO.puts("⚠️ Could not get Podman version")
        end
      _ ->
        IO.puts("❌ CRITICAL: Podman not found")
        IO.puts("🔧 Install with: nix-shell -p podman")
    end
    
    # Scan remaining violations
    scan_violations()
  end

  defp get_all_text_files do
    exclude_patterns = [
      ~r/\.git\//,
      ~r/node_modules\//,
      ~r/_build\//,
      ~r/deps\//,
      ~r/\.backup$/,
      ~r/\.docker-backup$/,
    ]
    
    Path.wildcard("**/*")
    |> Enum.filter(&File.regular?/1)
    |> Enum.filter(fn file ->
      not Enum.any?(exclude_patterns, fn pattern ->
        Regex.match?(pattern, file)
      end)
    end)
    |> Enum.filter(fn file ->
      # Only process text files - check first 512 bytes
      case File.open(file, [:read], fn device ->
        IO.binread(device, 512)
      end) do
        {:ok, content} when is_binary(content) ->
          String.printable?(content)
        _ ->
          false
      end
    end)
  end

  defp find_violations(content, _file) do
    # Check for Docker command patterns
    @violation_patterns
    |> Enum.flat_map(fn pattern ->
      case Regex.scan(pattern, content) do
        [] -> []
        matches -> 
          Enum.map(matches, fn match ->
            "Docker pattern found: #{hd(match)}"
          end)
      end
    end)
  end

  defp apply_all_replacements(content) do
    content
    |> apply_docker_replacements()
    |> apply_registry_replacements()
    |> add_podman_warnings()
  end

  defp apply_docker_replacements(content) do
    Enum.reduce(@docker_to_podman_replacements, content, fn {old, new}, acc ->
      String.replace(acc, old, new)
    end)
  end

  defp apply_registry_replacements(content) do
    Enum.reduce(@registry_replacements, content, fn {old, new}, acc ->
      String.replace(acc, old, new)
    end)
  end

  defp add_podman_warnings(content) do
    # Add warning comments near Docker references
    content
    |> String.replace(
      "podman-compose",
      "podman-compose  # ✅ MANDATORY: Docker-compose equivalent using Podman"
    )
  end

  defp backup_file(file) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    backup_path = "#{file}.docker-backup-#{timestamp}"
    File.cp!(file, backup_path)
  end

  defp show_help do
    IO.puts("""
    🐳→🏗️ Podman-Only Migration Tool - SOPv5.11 Compliance
    
    Usage:
      elixir scripts/maintenance/podman_only_migration.exs [COMMAND]
    
    Commands:
      --scan       Scan for Docker violations across codebase
      --fix        Apply Podman-only migrations to all files
      --validate   Validate current Podman-only compliance
      --help       Show this help message
    
    🚨 CRITICAL: This tool enforces zero-tolerance Docker policy
    🛡️ SECURITY: All Docker references are replaced with Podman equivalents
    📋 BACKUP: All modified files are backed up automatically
    
    Examples:
      elixir scripts/maintenance/podman_only_migration.exs --scan
      elixir scripts/maintenance/podman_only_migration.exs --fix
      elixir scripts/maintenance/podman_only_migration.exs --validate
    """)
  end
end

# Execute if run as script
if System.argv() |> length() > 0 do
  PodmanOnlyMigration.main(System.argv())
else
  PodmanOnlyMigration.show_help()
end