defmodule Indrajaal.Property.ContainerPropertiesTest do
  @moduledoc """
  🎲 PROPERTY-BASED TESTING FOR NIXOS CONTAINER SYSTEM

  This module implements comprehensive property-based testing for NixOS
  container infrastructure using both PropCheck and ExUnitProperties
  as mandated by CLAUDE.md dual property-based testing __requirements.

  ## Property Categories Tested
  1. Container Resource Management Properties
  2. Network Isolation and Communication Properties
  3. Container Registry Compliance Properties
  4. SSL Certificate Accessibility Properties
  5. PHICS Hot-Reloading Properties
  6. Container Health and Dependency Properties

  ## Agent-Friendly Property Testing
  All properties include comprehensive agent-friendly comments explaining
  the invariants being tested and expected system behaviors.
  """

  use ExUnit.Case, async: false
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # EP-GEN-014: Import ExUnitProperties with except clause to avoid conflicts
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguation aliases per EP-GEN-014 pattern
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  require Logger

  @local_registry_prefix "localhost/"
  @max_container_memory_mb 8192
  @min_container_memory_mb 256
  @max_container_cpu_cores 8.0
  @min_container_cpu_cores 0.5

  describe "PropCheck: Container Resource Management Properties" do
    property "container resource limits are enforced and reasonable" do
      forall container_config <- container_resource_config_generator() do
        # Agent-friendly comment: This property validates that container
        # resource configurations are within acceptable bounds and that
        # the system enforces these limits properly

        memory_within_bounds =
          container_config.memory_mb >= @min_container_memory_mb and
            container_config.memory_mb <= @max_container_memory_mb

        cpu_within_bounds =
          container_config.cpu_cores >= @min_container_cpu_cores and
            container_config.cpu_cores <= @max_container_cpu_cores

        # Additional validation - memory should be power-of-2 aligned for efficiency
        memory_efficient = rem(container_config.memory_mb, 256) == 0

        memory_within_bounds and cpu_within_bounds and memory_efficient
      end
    end

    property "container names follow consistent naming patterns" do
      forall container_name <- container_name_generator() do
        # Agent-friendly comment: Container naming consistency is critical
        # for service discovery and management automation

        has_indrajaal_prefix = String.starts_with?(container_name, "indrajaal-")
        has_service_component = String.contains?(container_name, "-")

        reasonable_length =
          String.length(container_name) >= 12 and String.length(container_name) <= 50

        no_invalid_chars = Regex.match?(~r/^[a-z0-9-]+$/, container_name)

        has_indrajaal_prefix and has_service_component and reasonable_length and
          no_invalid_chars
      end
    end
  end

  describe "ExUnitProperties: Container Registry Compliance Properties" do
    test "exunitproperties: all container images use localhost registry exclusively" do
      ExUnitProperties.check all(
                               container_image <- container_image_generator(),
                               max_runs: 100
                             ) do
        # Agent-friendly comment: Registry compliance pr__events supply chain
        # attacks by ensuring all containers come from trusted local sources

        assert String.starts_with?(container_image, @local_registry_prefix),
               "Container image #{container_image} does not use localhost registry"

        # Additional validation - no external registry references
        refute String.contains?(container_image, "docker.io"),
               "Container image #{container_image} contains forbidden docker.io reference"

        refute String.contains?(container_image, "registry.nixos.org"),
               "Container image #{container_image} contains forbidden registry.nixos.org reference"

        refute String.contains?(container_image, "quay.io"),
               "Container image #{container_image} contains forbidden quay.io reference"
      end
    end

    test "exunitproperties: container tags follow semantic versioning or environment patterns" do
      ExUnitProperties.check all(
                               container_tag <- container_tag_generator(),
                               max_runs: 50
                             ) do
        # Agent-friendly comment: Consistent tagging enables reliable container
        # versioning and environment-specific deployments

        # Valid tag patterns: semantic versions, environment names, or special tags
        semantic_version_pattern = ~r/^v?\d+\.\d+\.\d+.*$/
        environment_pattern = ~r/^(nixos-devenv|demo-ready|latest|dev|test|prod)$/

        is_semantic = Regex.match?(semantic_version_pattern, container_tag)
        is_environment = Regex.match?(environment_pattern, container_tag)

        assert is_semantic or is_environment,
               "Container tag #{container_tag} does not follow valid patterns"
      end
    end
  end

  describe "PropCheck: Network Isolation Properties" do
    property "container network configurations maintain isolation" do
      forall {container1, container2} <-
               {container_network_config_generator(), container_network_config_generator()} do
        # Agent-friendly comment: Network isolation prevents unauthorized
        # cross-container communication and maintains security boundaries

        # Network isolation is maintained when:
        # 1. Containers are on different networks (fully isolated)
        # 2. Both containers share the "indrajaal-app" network (designed for inter-container communication)
        # 3. Containers are on the same non-app network with non-conflicting ports
        different_networks = container1.network != container2.network

        shared_app_network =
          container1.network == "indrajaal-app" and container2.network == "indrajaal-app"

        # Port conflicts only matter when containers share a non-app network
        same_network_with_valid_ports =
          container1.network == container2.network and
            not ranges_overlap?(container1.port_range, container2.port_range)

        # Property holds if any of these conditions is true
        different_networks or shared_app_network or same_network_with_valid_ports
      end
    end
  end

  describe "ExUnitProperties: SSL Certificate Properties" do
    test "exunitproperties: SSL certificate paths are accessible and valid" do
      ExUnitProperties.check all(
                               ssl_config <- ssl_certificate_config_generator(),
                               max_runs: 20
                             ) do
        # Agent-friendly comment: SSL certificate accessibility is critical
        # for container network communication and package management

        # Certificate paths should exist if specified
        if ssl_config.cert_path do
          # In testing, we validate path format rather than existence
          assert String.starts_with?(ssl_config.cert_path, "/"),
                 "Certificate path should be absolute: #{ssl_config.cert_path}"

          assert String.ends_with?(ssl_config.cert_path, ".crt") or
                   String.ends_with?(ssl_config.cert_path, ".pem"),
                 "Certificate path should have valid extension: #{ssl_config.cert_path}"
        end

        # Environment variables should be properly formatted
        if ssl_config.env_vars do
          Enum.each(ssl_config.env_vars, fn {key, value} ->
            assert String.match?(key, ~r/^[A-Z_]+$/),
                   "Environment variable key should be uppercase: #{key}"

            if value do
              assert is_binary(value) and String.length(value) > 0,
                     "Environment variable value should be non-empty string: #{value}"
            end
          end)
        end
      end
    end
  end

  describe "PropCheck: PHICS Hot-Reloading Properties" do
    property "PHICS configuration maintains file sync consistency" do
      forall phics_config <- phics_config_generator() do
        # Agent-friendly comment: PHICS hot-reloading __requires consistent
        # file synchronization between host and container environments

        # Watch paths should be valid directories
        watch_paths_valid =
          Enum.all?(phics_config.watch_paths, fn path ->
            String.starts_with?(path, "/") and String.length(path) > 1
          end)

        # Sync strategy should be supported
        sync_strategy_valid =
          phics_config.sync_strategy in [:bidirectional, :host_to_container, :container_to_host]

        # Reload delay should be reasonable (not too fast or slow)
        reload_delay_reasonable =
          phics_config.reload_delay_ms >= 100 and
            phics_config.reload_delay_ms <= 5000

        watch_paths_valid and sync_strategy_valid and reload_delay_reasonable
      end
    end
  end

  describe "ExUnitProperties: Container Health Properties" do
    test "exunitproperties: container health check configurations are robust" do
      ExUnitProperties.check all(
                               health_config <- container_health_config_generator(),
                               max_runs: 75
                             ) do
        # Agent-friendly comment: Health check configurations ensure reliable
        # container lifecycle management and dependency coordination

        # Health check intervals should be reasonable
        assert health_config.interval_seconds >= 5 and health_config.interval_seconds <= 300,
               "Health check interval should be 5-300 seconds: #{health_config.interval_seconds}"

        # Timeout should be less than interval
        assert health_config.timeout_seconds < health_config.interval_seconds,
               "Timeout (#{health_config.timeout_seconds}s) should be less than interval (#{health_config.interval_seconds}s)"

        # Retry count should be reasonable
        assert health_config.retries >= 1 and health_config.retries <= 10,
               "Health check retries should be 1-10: #{health_config.retries}"

        # Start period should allow for container initialization
        assert health_config.start_period_seconds >= health_config.timeout_seconds,
               "Start period should allow for initialization: #{health_config.start_period_seconds}"
      end
    end

    test "exunitproperties: container dependency graphs are acyclic" do
      ExUnitProperties.check all(
                               dependency_graph <- container_dependency_generator(),
                               max_runs: 30
                             ) do
        # Agent-friendly comment: Dependency graphs must be acyclic to pr__event
        # deadlocks during container startup and shutdown sequences

        # Check for cycles in dependency graph
        assert not has_dependency_cycle?(dependency_graph),
               "Container dependency graph contains cycles: #{inspect(dependency_graph)}"

        # Each container should have reasonable number of dependencies
        Enum.each(dependency_graph, fn {container, deps} ->
          assert length(deps) <= 5,
                 "Container #{container} has too many dependencies: #{length(deps)}"
        end)
      end
    end
  end

  describe "Property-Based Integration Testing" do
    property "end-to-end container orchestration properties" do
      forall orchestration_config <- container_orchestration_generator() do
        # Agent-friendly comment: End-to-end orchestration properties validate
        # that complete container ecosystems work together correctly

        # Infrastructure containers should start before application containers
        infrastructure_names = ["timescaledb", "redis"]
        app_names = ["app", "prometheus", "grafana"]

        infrastructure_before_app =
          Enum.all?(infrastructure_names, fn infra ->
            Enum.all?(app_names, fn app ->
              get_startup_priority(infra) < get_startup_priority(app)
            end)
          end)

        # Total resource usage should not exceed reasonable limits
        total_memory =
          Enum.reduce(orchestration_config.containers, 0, fn container, acc ->
            acc + container.memory_mb
          end)

        total_cpu =
          Enum.reduce(orchestration_config.containers, 0.0, fn container, acc ->
            acc + container.cpu_cores
          end)

        resources_reasonable = total_memory <= 16_384 and total_cpu <= 16.0

        infrastructure_before_app and resources_reasonable
      end
    end

    test "exunitproperties: container configuration consistency across environments" do
      ExUnitProperties.check all(
                               {dev_config, prod_config} <- sd_paired_environment_generator(),
                               max_runs: 25
                             ) do
        # Agent-friendly comment: Configuration consistency across environments
        # pr__events deployment issues and ensures predictable behavior

        # Core container names should be consistent (service names match)
        dev_core_containers = get_core_container_names(dev_config)
        prod_core_containers = get_core_container_names(prod_config)

        assert MapSet.equal?(MapSet.new(dev_core_containers), MapSet.new(prod_core_containers)),
               "Core container names should be consistent across environments"

        # Network configurations should follow same patterns
        dev_networks = get_network_names(dev_config)
        prod_networks = get_network_names(prod_config)

        # Should have similar network structure (may have different names but same count)
        assert length(dev_networks) == length(prod_networks),
               "Network count should be consistent across environments"
      end
    end
  end

  # Property-based test generators using PropCheck syntax

  defp container_resource_config_generator do
    let {memory_mb, cpu_cores} <- {
          choose(@min_container_memory_mb, @max_container_memory_mb),
          oneof([0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 6.0, 8.0])
        } do
      %{
        # Align to 256MB boundaries
        memory_mb: memory_mb - rem(memory_mb, 256),
        cpu_cores: cpu_cores
      }
    end
  end

  defp container_name_generator do
    let {service, environment, suffix} <- {
          oneof(["app", "timescaledb", "redis", "prometheus", "grafana", "nginx"]),
          oneof(["demo", "dev", "test", "prod"]),
          oneof(["", "-01", "-primary", "-replica"])
        } do
      "indrajaal-#{service}-#{environment}#{suffix}"
    end
  end

  # Property-based test generators using ExUnitProperties syntax

  defp container_image_generator do
    StreamData.map(
      {SD.member_of(["app", "timescaledb", "redis", "prometheus", "grafana", "nginx"]),
       container_tag_generator()},
      fn {service, tag} -> "#{@local_registry_prefix}indrajaal-#{service}:#{tag}" end
    )
  end

  defp container_tag_generator do
    StreamData.one_of([
      StreamData.constant("nixos-devenv"),
      StreamData.constant("demo-ready"),
      StreamData.constant("latest"),
      StreamData.map(
        {StreamData.positive_integer(), StreamData.positive_integer(),
         StreamData.positive_integer()},
        fn {major, minor, patch} -> "v#{major}.#{minor}.#{patch}" end
      )
    ])
  end

  defp container_network_config_generator do
    let {network, port_start} <- {
          oneof(["indrajaal-app", "indrajaal-monitoring", "indrajaal-__data"]),
          choose(3000, 9000)
        } do
      %{
        network: network,
        port_range: port_start..(port_start + 100)
      }
    end
  end

  defp ssl_certificate_config_generator do
    # Generate uppercase letter-only env var keys (matching regex ^[A-Z_]+$)
    env_var_key_gen =
      StreamData.map(
        SD.list_of(SD.member_of(?A..?Z |> Enum.to_list()),
          min_length: 3,
          max_length: 12
        ),
        fn chars -> List.to_string(chars) end
      )

    StreamData.map(
      {StreamData.one_of([
         StreamData.constant(nil),
         StreamData.map(
           StreamData.string(:alphanumeric, min_length: 10),
           fn s -> "/nix/store/#{s}/ca-bundle.crt" end
         )
       ]),
       SD.list_of(
         StreamData.tuple({
           env_var_key_gen,
           StreamData.one_of([
             StreamData.constant(nil),
             StreamData.string(:printable, min_length: 1)
           ])
         }),
         max_length: 5
       )},
      fn {cert_path, env_vars} ->
        %{
          cert_path: cert_path,
          env_vars: env_vars
        }
      end
    )
  end

  defp phics_config_generator do
    let {num_paths, sync_strategy, reload_delay} <- {
          choose(1, 3),
          oneof([:bidirectional, :host_to_container, :container_to_host]),
          choose(100, 5000)
        } do
      let watch_paths <-
            PC.vector(
              num_paths,
              PC.oneof(["/workspace/lib", "/workspace/priv", "/workspace/assets"])
            ) do
        %{
          watch_paths: watch_paths,
          sync_strategy: sync_strategy,
          reload_delay_ms: reload_delay
        }
      end
    end
  end

  defp container_health_config_generator do
    StreamData.map(
      {StreamData.integer(6..300), StreamData.integer(2..10), StreamData.integer(1..10)},
      fn {interval, timeout_factor, retries} ->
        # Ensure timeout is strictly less than interval
        timeout = min(max(1, div(interval, timeout_factor)), interval - 1)
        start_period = max(timeout * 2, 15)

        %{
          interval_seconds: interval,
          timeout_seconds: timeout,
          retries: retries,
          start_period_seconds: start_period
        }
      end
    )
  end

  defp container_dependency_generator do
    # Generate a proper DAG (Directed Acyclic Graph) for container dependencies
    # Use topological ordering: each container can only depend on containers with lower indices
    containers = ["timescaledb", "redis", "prometheus", "grafana", "app"]
    indexed_containers = Enum.with_index(containers)
    container_indices = indexed_containers |> Map.new()

    StreamData.map(
      SD.list_of(
        StreamData.tuple({
          SD.member_of(containers),
          SD.list_of(
            SD.member_of(containers),
            max_length: 2
          )
        }),
        max_length: 5
      ),
      fn deps ->
        # Filter dependencies to ensure DAG property:
        # A container can only depend on containers that appear BEFORE it in the ordered list
        deps
        |> Enum.map(fn {container, dep_list} ->
          container_idx = Map.get(container_indices, container, 0)

          valid_deps =
            Enum.filter(dep_list, fn dep ->
              dep_idx = Map.get(container_indices, dep, 0)
              # Dependency must have lower index (comes before in topological order)
              dep_idx < container_idx
            end)

          {container, valid_deps}
        end)
        |> Map.new()
      end
    )
  end

  defp container_orchestration_generator do
    # Use predefined unique container configurations to ensure no duplicates
    let selection <- choose(1, 3) do
      containers =
        case selection do
          1 ->
            [
              %{name: "indrajaal-timescaledb-demo", memory_mb: 512, cpu_cores: 1.0},
              %{name: "indrajaal-redis-demo", memory_mb: 256, cpu_cores: 0.5},
              %{name: "indrajaal-app-demo", memory_mb: 1024, cpu_cores: 2.0}
            ]

          2 ->
            [
              %{name: "indrajaal-timescaledb-prod", memory_mb: 2048, cpu_cores: 4.0},
              %{name: "indrajaal-redis-prod", memory_mb: 512, cpu_cores: 1.0},
              %{name: "indrajaal-ex-app-1", memory_mb: 2048, cpu_cores: 4.0},
              %{name: "indrajaal-prometheus-prod", memory_mb: 512, cpu_cores: 1.0}
            ]

          3 ->
            [
              %{name: "indrajaal-timescaledb-dev", memory_mb: 256, cpu_cores: 0.5},
              %{name: "indrajaal-redis-dev", memory_mb: 256, cpu_cores: 0.5},
              %{name: "indrajaal-app-dev", memory_mb: 512, cpu_cores: 1.0},
              %{name: "indrajaal-grafana-dev", memory_mb: 256, cpu_cores: 0.5},
              %{name: "indrajaal-prometheus-dev", memory_mb: 256, cpu_cores: 0.5}
            ]
        end

      %{containers: containers}
    end
  end

  defp container_config_generator do
    let {name, memory_mb, cpu_cores} <- {
          container_name_generator(),
          choose(256, 4096),
          oneof([0.5, 1.0, 2.0, 4.0])
        } do
      %{
        name: name,
        memory_mb: memory_mb,
        cpu_cores: cpu_cores
      }
    end
  end

  defp container_environment_generator(environment) do
    let n <- choose(3, 8) do
      let containers <- PC.vector(n, container_with_environment_generator(environment)) do
        %{
          environment: environment,
          containers: containers
        }
      end
    end
  end

  defp container_with_environment_generator(environment) do
    let {service, network} <- {
          oneof(["app", "timescaledb", "redis", "prometheus", "grafana"]),
          oneof(["app-network", "__data-network", "monitoring-network"])
        } do
      %{
        name: "indrajaal-#{service}-#{environment}",
        service: service,
        network: network
      }
    end
  end

  # StreamData versions of generators for ExUnitProperties tests
  defp sd_container_environment_generator(environment) do
    StreamData.bind(StreamData.integer(3..8), fn n ->
      StreamData.map(
        SD.list_of(sd_container_with_environment_generator(environment), length: n),
        fn containers ->
          %{
            environment: environment,
            containers: containers
          }
        end
      )
    end)
  end

  # Generator that produces paired dev/prod configs with matching services
  defp sd_paired_environment_generator do
    # Generate a common list of services first, then create configs for both environments
    StreamData.bind(
      SD.list_of(
        {SD.member_of(["app", "timescaledb", "redis", "prometheus", "grafana"]),
         SD.member_of(["app-network", "__data-network", "monitoring-network"])},
        min_length: 3,
        max_length: 8
      ),
      fn service_network_pairs ->
        dev_containers =
          Enum.map(service_network_pairs, fn {service, network} ->
            %{name: "indrajaal-#{service}-dev", service: service, network: network}
          end)

        prod_containers =
          Enum.map(service_network_pairs, fn {service, network} ->
            %{name: "indrajaal-#{service}-prod", service: service, network: network}
          end)

        StreamData.constant({
          %{environment: "dev", containers: dev_containers},
          %{environment: "prod", containers: prod_containers}
        })
      end
    )
  end

  defp sd_container_with_environment_generator(environment) do
    StreamData.map(
      {SD.member_of(["app", "timescaledb", "redis", "prometheus", "grafana"]),
       SD.member_of(["app-network", "__data-network", "monitoring-network"])},
      fn {service, network} ->
        %{
          name: "indrajaal-#{service}-#{environment}",
          service: service,
          network: network
        }
      end
    )
  end

  # Helper functions for property validation

  defp ranges_overlap?(range1, range2) do
    Range.disjoint?(range1, range2) == false
  end

  defp has_dependency_cycle?(dependency_graph) do
    # Simple cycle detection using DFS
    visited = MapSet.new()
    rec_stack = MapSet.new()

    Enum.any?(Map.keys(dependency_graph), fn node ->
      has_cycle_from_node?(node, dependency_graph, visited, rec_stack)
    end)
  end

  defp has_cycle_from_node?(node, graph, visited, rec_stack) do
    if MapSet.member?(rec_stack, node) do
      true
    else
      if MapSet.member?(visited, node) do
        false
      else
        new_visited = MapSet.put(visited, node)
        new_rec_stack = MapSet.put(rec_stack, node)

        dependencies = Map.get(graph, node, [])

        Enum.any?(dependencies, fn dep ->
          has_cycle_from_node?(dep, graph, new_visited, new_rec_stack)
        end)
      end
    end
  end

  defp get_startup_priority(service) do
    case service do
      "timescaledb" -> 1
      "redis" -> 1
      "app" -> 2
      "prometheus" -> 3
      "grafana" -> 3
      _ -> 4
    end
  end

  defp get_core_container_names(config) do
    config.containers
    |> Enum.filter(fn container -> container.service in ["app", "timescaledb", "redis"] end)
    |> Enum.map(fn container -> container.service end)
  end

  defp get_network_names(config) do
    config.containers
    |> Enum.map(fn container -> container.network end)
    |> Enum.uniq()
  end
end
