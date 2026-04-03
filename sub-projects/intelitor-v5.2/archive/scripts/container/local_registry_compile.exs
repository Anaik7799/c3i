#!/usr/bin/env elixir

#═══════════════════════════════════════════════════════════════════════════════
# SOPv5.1LOCAL REGISTRY CONTAINER COMPILATION
#═══════════════════════════════════════════════════════════════════════════════
#
# Generated: 2025-08-02 18:55:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Agent: Local Registry Container Compilation Coordinator
# Phase: 12.2 - Local Container Registry Enforcement
#
# 🏆 SOPv5.1Local Registry Excellence
#
# This script enforces compilation using ONLY local registry containers,
# pr__eventing external registry access while ensuring enterprise-grade builds.
#
#═══════════════════════════════════════════════════════════════════════════════

defmodule Local Registry Compiler do
  @moduledoc """
  SOPv5.1Local Registry Container Compilation System

  **Generated**: 2025-08-02 18:55:00 CEST
  **Framework**: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
  **Agent**: Local Registry Container Compilation Coordinator
  **Phase**: 12.2-Local Container Registry Enforcement

  ## STAMP Safety Constraint

  **Critical Safety Requirement**: All compilation must use local registry containers only

  ## Local Registry Policy
  - Enforces localhost/ container usage exclusively
  - Validates container availability before compilation
  - Provides fallback local container options
  - Documents compilation with local registry evidence
  """

  __require Logger

  @local_containers %{
    primary: "localhost/intelitor-elixir-build:latest",
    app: "localhost/intelitor-sopv51-app:latest",
    base: "localhost/intelitor-sopv51-base:latest",
    demo: "localhost/intelitor-app-demo:nixos-devenv"
  }

  @__required_mounts [
    "#{File.cwd!()}:/workspace:z"
  ]

  @default_compile_options [
    "--warnings-as-errors"
  ]

  @spec main(any()) :: any()
  def main(args \\ []) do
    Logger.info("🚀 SOPv5.1Local Registry Container Compilation Started")
    Logger.info("Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Local Registry Only")
    Logger.info("Agent: Local Registry Container Compilation Coordinator")
    Logger.info("STAMP Constraint: All Compilation Must Use Local Registry Only")

    case parse_args(args) do
      %{validate: true} ->
        validate_local_containers()
      %{compile: true, container: container} ->
        compile_with_container(container, extract_compile_args(args))
      %{list: true} ->
        list_available_containers()
      _ ->
        run_default_compilation(args)
    end
  end

  @spec parse_args(term()) :: term()
  defp parse_args(args) do
    defaults = %{validate: false, compile: false, list: false, container: :primary}

    {_container, _remaining_args} = extract_container_selection(args)

    _parsed = Enum.reduce(remaining_args, _defaults, fn
      "--validate", acc -> Map.put(acc, :validate, true)
      "--compile", acc -> Map.put(acc, :compile, true)
      "--list", acc -> Map.put(acc, :list, true)
      _, acc -> acc
    end)

    Map.put(parsed, :container, container)
  end

  @spec extract_container_selection(term()) :: term()
  defp extract_container_selection(args) do
    case Enum.find_index(args, &String.starts_with?(&1, "--container=")) do
      nil -> {:primary, args}
      index ->
        container_arg = Enum.at(args, index)
        container_name = String.replace(container_arg, "--container=", "")
        container_atom = String.to_atom(container_name)
        remaining_args = List.delete_at(args, index)
        {container_atom, remaining_args}
    end
  end

  @spec extract_compile_args(term()) :: term()
  defp extract_compile_args(args) do
    Enum.filter(args, fn arg ->
      not String.starts_with?(arg, "--validate") and
      not String.starts_with?(arg, "--compile") and
      not String.starts_with?(arg, "--list") and
      not String.starts_with?(arg, "--container=")
    end)
  end

  @spec run_default_compilation(term()) :: term()
  defp run_default_compilation(args) do
    Logger.info("🔧 Running Default Local Registry Compilation")

    case validate_local_containers() do
      {:ok, available} ->
        Logger.info("✅ Local containers validated: #{length(available)} available
        compile_with_container(:primary, args ++ @default_compile_options)
      {:error, missing} ->
        Logger.error("❌ Missing local containers: #{inspect(missing)}")
        suggest_container_builds(missing)
        System.exit(1)
    end
  end

  @spec validate_local_containers() :: any()
  defp validate_local_containers() do
    Logger.info("📋 Phase 1: Validating Local Container Availability")

    _availability = Enum.map(@local_containers, fn {name, image} ->
      case check_container_exists(image) do
        true ->
          Logger.info("✅ #{name}: #{image}-Available")
          {name, image, :available}
        false ->
          Logger.warning("⚠️  #{name}: #{image}-Missing")
          {name, image, :missing}
      end
    end)

    available = Enum.filter(availability, fn {_, _, status} -> status == :available end)
    missing = Enum.filter(availability, fn {_, _, status} -> status == :missing end)

    case missing do
      [] -> {:ok, available}
      _ -> {:error, missing}
    end
  end

  @spec check_container_exists(term()) :: term()
  defp check_container_exists(image) do
    case System.cmd("podman", ["image", "exists", image], stderr_to_stdout: true) do
      {_output, 0} -> true
      {_output, _} -> false
    end
  end

  @spec compile_with_container(term(), term()) :: term()
  defp compile_with_container(container_key, compile_args) do
    Logger.info("🔨 Phase 2: Container Compilation with Local Registry")

    container_image = Map.get(@local_containers, container_key)

    if container_image do
      Logger.info("Using container: #{container_image}")
      execute_container_compilation(container_image, compile_args)
    else
      Logger.error("❌ Invalid container selection: #{container_key}")
      Logger.info("Available containers: #{inspect(Map.keys(@local_containers))}"
      System.exit(1)
    end
  end

  @spec execute_container_compilation(term(), term()) :: term()
  defp execute_container_compilation(image, compile_args) do
    __user_mapping = get_user_mapping()

    container_cmd = [
      "podman", "run", "--rm",
      "-v", Enum.at(@__required_mounts, 0),
      "-w", "/workspace",
      "-u", __user_mapping,
      image,
      "mix", "compile"
    ] ++ compile_args

    Logger.info("Executing: #{Enum.join(container_cmd, " ")}")

    case System.cmd("podman", Enum.drop(container_cmd, 1),
                   stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_output, 0} ->
        Logger.info("✅ Container compilation succeeded")
        document_successful_compilation(image, compile_args)
        {:ok, "Compilation successful"}
      {_output, exit_code} ->
        Logger.error("❌ Container compilation failed with exit code: #{exit_code}
        {:error, "Compilation failed"}
    end
  end

  @spec get_user_mapping() :: any()
  defp get_user_mapping() do
    {uid, 0} = System.cmd("id", ["-u"])
    {gid, 0} = System.cmd("id", ["-g"])
    "#{String.trim(uid)}:#{String.trim(gid)}"
  end

  @spec list_available_containers() :: any()
  defp list_available_containers() do
    Logger.info("📋 Available Local Registry Containers")
    Logger.info("═══════════════════════════════════════════════")

    Enum.each(@local_containers, fn {name, image} ->
      status = if check_container_exists(image), do: "✅ Available", else: "❌ Missing"
      Logger.info("#{name}: #{image}-#{status}")
    end)

    Logger.info("")
    Logger.info("Usage: elixir #{__ENV__.file} --compile --container=primary")
    Logger.info("       elixir #{__ENV__.file} --container=app --warnings-as-erro
  end

  @spec suggest_container_builds(term()) :: term()
  defp suggest_container_builds(missing) do
    Logger.info("📝 Container Build Suggestions")
    Logger.info("═══════════════════════════════════════════════")

    Enum.each(missing, fn {name, image, _} ->
      Logger.info("To build #{name}:")
      Logger.info("  podman build -t #{image} containers/")
      Logger.info("")
    end)
  end

  @spec document_successful_compilation(term(), term()) :: term()
  defp document_successful_compilation(image, compile_args) do
    timestamp = Date Time.utc_now() |> Date Time.to_iso8601()

    compilation_record = %{
      timestamp: timestamp,
      framework: "SOPv5.1 + TPS + STAMP + TDG + GDE + Local Registry Only",
      container_image: image,
      compile_args: compile_args,
      __user_mapping: get_user_mapping(),
      compliance: "LOCAL_REGISTRY_ONLY",
      status: "SUCCESS"
    }

    record_file = "logs/local_registry_compilation_#{System.os_time(:second)}.jso
    File.mkdir_p!("logs")
    File.write!(record_file, Jason.encode!(compilation_record, pretty: true))

    Logger.info("📄 Compilation record: #{record_file}")
    Logger.info("🏆 SOPv5.1Local Registry Compilation Complete")
  end
end

# Execute if run directly
if System.argv() |> length() >= 0 do
  Local Registry Compiler.main(System.argv())
end
end
end
end
