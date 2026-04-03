#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}, {:yaml_elixir, "~> 2.9"}])

defmodule ContainerStrategyVerifier do
  @moduledoc """
  Verifies the 5-Level Container Environment Strategy artifacts.
  Parses podman-compose files and checks for SOPv5.11 compliance.
  """

  require Logger

  @levels %{
    1 => %{file: "podman-compose-3container.yml", name: "Foundation (Dev)", constraints: [:phics, :nixos]},
    2 => %{file: "podman-compose-testing.yml", name: "Resilience (Test)", constraints: [:ha_cluster, :nixos]},
    3 => %{file: "podman-compose.yml", name: "Visibility (Demo)", constraints: [:observability, :phics]},
    4 => %{file: "podman-compose-secure.yml", name: "Security (Prod)", constraints: [:readonly, :rootless]},
    5 => %{file: "podman-compose-cluster.yml", name: "Distribution (Mesh)", constraints: [:tailscale]}
  }

  def run do
    IO.puts("🛡️  Starting 5-Level Container Strategy Verification")
    IO.puts("==================================================")

    results = Enum.map(@levels, fn {level, config} ->
      verify_level(level, config)
    end)

    failures = Enum.filter(results, fn r -> r.status == :error end)

    if Enum.empty?(failures) do
      IO.puts("\n✅ ALL 5 LEVELS VERIFIED SUCCESSFULLY")
      System.halt(0)
    else
      IO.puts("\n❌ VERIFICATION FAILED")
      Enum.each(failures, fn f -> IO.puts("   - Level #{f.level}: #{f.message}") end)
      System.halt(1)
    end
  end

  defp verify_level(level, config) do
    IO.write("👉 Level #{level}: #{config.name} (#{config.file})... ")
    
    if File.exists?(config.file) do
      content = File.read!(config.file)
      # Basic string check since we might not want to depend on full YAML parser logic for simple checks
      # or if yaml_elixir isn't fully set up in the environment.
      # But we can try to check for key strings.
      
      errors = Enum.reduce(config.constraints, [], fn constraint, acc ->
        case check_constraint(constraint, content) do
          :ok -> acc
          {:error, msg} -> [msg | acc]
        end
      end)

      if Enum.empty?(errors) do
        IO.puts("✅ PASS")
        %{level: level, status: :ok}
      else
        IO.puts("❌ FAIL")
        Enum.each(errors, fn e -> IO.puts("      ⚠️  #{e}") end)
        %{level: level, status: :error, message: Enum.join(errors, ", ")}
      end
    else
      IO.puts("❌ MISSING")
      %{level: level, status: :error, message: "File not found"}
    end
  end

  defp check_constraint(:phics, content) do
    if String.contains?(content, "PHICS_ENABLED") do
      :ok
    else
      {:error, "Missing PHICS_ENABLED configuration"}
    end
  end

  defp check_constraint(:nixos, content) do
    if String.contains?(content, "nixos") do
      :ok
    else
      {:error, "Missing NixOS image reference"}
    end
  end

  defp check_constraint(:ha_cluster, content) do
    if String.contains?(content, "app-1") and String.contains?(content, "app-2") do
      :ok
    else
      {:error, "Missing HA Cluster configuration (app-1, app-2)"}
    end
  end

  defp check_constraint(:observability, content) do
    if String.contains?(content, "prometheus") and String.contains?(content, "grafana") do
      :ok
    else
      {:error, "Missing Observability stack"}
    end
  end

  defp check_constraint(:readonly, content) do
    if String.contains?(content, "read_only: true") do
      :ok
    else
      {:error, "Missing read_only: true security constraint"}
    end
  end

  defp check_constraint(:rootless, content) do
    if String.contains?(content, "user: \"1000:1000\"") do
      :ok
    else
      {:error, "Missing non-root user configuration"}
    end
  end

  defp check_constraint(:tailscale, content) do
    if String.contains?(content, "TAILSCALE_DNS_SUFFIX") do
      :ok
    else
      {:error, "Missing Tailscale configuration"}
    end
  end
end

ContainerStrategyVerifier.run()
