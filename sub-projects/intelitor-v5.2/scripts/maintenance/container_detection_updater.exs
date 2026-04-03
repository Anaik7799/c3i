#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ContainerDetectionUpdater do
  @moduledoc """
  Updates container detection logic from Docker-based to Podman-based across all files.
  
  CRITICAL: This script updates /.dockerenv references to use Podman-compatible
  container detection patterns /.containerenv and /run/.containerenv.
  """

  def main(args) do
    case args do
      ["--scan"] -> scan_container_detection()
      ["--fix"] -> fix_container_detection()
      ["--validate"] -> validate_container_detection()
      ["--help"] -> show_help()
      _ -> show_help()
    end
  end

  def scan_container_detection do
    IO.puts("🔍 Scanning for Docker-based container detection patterns...")
    
    files = get_files_with_dockerenv()
    
    Enum.each(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          lines = String.split(content, "\n")
          Enum.with_index(lines, 1)
          |> Enum.each(fn {line, line_num} ->
            if String.contains?(line, ".dockerenv") do
              IO.puts("❌ #{file}:#{line_num} - #{String.trim(line)}")
            end
          end)
        {:error, _} ->
          IO.puts("⚠️ Could not read #{file}")
      end
    end)
    
    IO.puts("✅ Container detection scan complete")
  end

  def fix_container_detection do
    IO.puts("🔧 Updating container detection to Podman-compatible patterns...")
    
    files = get_files_with_dockerenv()
    updated_count = 0
    
    _updated_files = 
      Enum.map(files, fn file ->
        case File.read(file) do
          {:ok, content} ->
            updated_content = update_container_detection_patterns(content)
            
            if updated_content != content do
              backup_file(file)
              File.write!(file, updated_content)
              IO.puts("✅ Updated #{file}")
              1
            else
              0
            end
          {:error, reason} ->
            IO.puts("⚠️ Could not update #{file}: #{reason}")
            0
        end
      end)
      |> Enum.sum()
    
    IO.puts("🎯 Container detection update complete! Updated #{updated_files} files")
    IO.puts("📋 All backup files created with .dockerenv-backup extension")
  end

  def validate_container_detection do
    IO.puts("🛡️ Validating Podman-compatible container detection...")
    
    # Check if we're currently in a container
    container_indicators = [
      {"/.containerenv", "Podman container indicator"},
      {"/run/.containerenv", "Podman runtime container indicator"}, 
      {"/.dockerenv", "Legacy Docker indicator (should be removed)"},
      {"/proc/1/cgroup", "Container cgroup indicator"}
    ]
    
    Enum.each(container_indicators, fn {path, description} ->
      if File.exists?(path) do
        IO.puts("✅ #{description}: #{path} - EXISTS")
      else
        IO.puts("ℹ️ #{description}: #{path} - Not present")
      end
    end)
    
    # Scan for remaining .dockerenv references
    scan_container_detection()
  end

  defp get_files_with_dockerenv do
    Path.wildcard("**/*")
    |> Enum.filter(&File.regular?/1)
    |> Enum.filter(fn file ->
      case File.read(file) do
        {:ok, content} -> 
          String.contains?(content, ".dockerenv")
        _ -> 
          false
      end
    end)
    |> Enum.reject(fn file ->
      # Exclude backup files and build directories
      String.contains?(file, ".backup") or
      String.contains?(file, "_build/") or
      String.contains?(file, ".git/") or
      String.contains?(file, "deps/")
    end)
  end

  defp update_container_detection_patterns(content) do
    content
    # Update simple file existence checks
    |> String.replace(
      "File.exists?(\"/.dockerenv\")",
      "File.exists?(\"/.containerenv\")"
    )
    # Update complex container detection logic - first pattern
    |> String.replace(
      "File.exists?(\"/.dockerenv\") or File.exists?(\"/run/.containerenv\")",
      "File.exists?(\"/.containerenv\") or File.exists?(\"/run/.containerenv\")"
    )
    # Update complex container detection logic - second pattern
    |> String.replace(
      "File.exists?(\"/.dockerenv\") or\n        File.exists?(\"/run/.containerenv\")",
      "File.exists?(\"/.containerenv\") or\n        File.exists?(\"/run/.containerenv\")"
    )
    # Update single-line patterns
    |> String.replace(
      "/.dockerenv",
      "/.containerenv"
    )
    # Update environment variable patterns
    |> String.replace(
      "DOCKERENV",
      "CONTAINERENV" 
    )
    # Update comments mentioning Docker container detection
    |> String.replace(
      "Check /.dockerenv",
      "Check /.containerenv (Podman equivalent)"
    )
    |> String.replace(
      "Docker container detection",
      "Podman container detection"
    )
    |> String.replace(
      "docker container environment",
      "podman container environment"
    )
    # Update more complex variable assignments
    |> String.replace(
      "container_env = File.exists?(\"/.dockerenv\") or File.exists?(\"/run/.containerenv\")",
      "container_env = File.exists?(\"/.containerenv\") or File.exists?(\"/run/.containerenv\")"
    )
  end

  defp backup_file(file) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    backup_path = "#{file}.dockerenv-backup-#{timestamp}"
    File.cp!(file, backup_path)
  end

  defp show_help do
    IO.puts("""
    🐳→🏗️ Container Detection Updater - Podman Compatibility
    
    Usage:
      elixir scripts/maintenance/container_detection_updater.exs [COMMAND]
    
    Commands:
      --scan       Scan for Docker-based container detection patterns
      --fix        Update all container detection to use Podman patterns
      --validate   Validate current container detection setup
      --help       Show this help message
    
    🚨 CRITICAL: Updates container detection from /.dockerenv to /.containerenv
    🛡️ PODMAN: Uses Podman-compatible container detection patterns
    📋 BACKUP: All modified files are backed up automatically
    
    Container Detection Patterns:
      /.dockerenv          → /.containerenv (Podman equivalent)
      /run/.containerenv   → /run/.containerenv (Podman runtime)
      Docker container     → Podman container
    
    Examples:
      elixir scripts/maintenance/container_detection_updater.exs --scan
      elixir scripts/maintenance/container_detection_updater.exs --fix
      elixir scripts/maintenance/container_detection_updater.exs --validate
    """)
  end
end

# Execute if run as script
if System.argv() |> length() > 0 do
  ContainerDetectionUpdater.main(System.argv())
else
  ContainerDetectionUpdater.show_help()
end