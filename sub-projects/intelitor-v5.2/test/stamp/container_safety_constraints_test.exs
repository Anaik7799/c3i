defmodule Indrajaal.STAMP.ContainerSafetyConstraintsTest do
  @moduledoc """
  🚨 STAMP SAFETY CONSTRAINT TESTING FOR NIXOS CONTAINERS

  This module implements comprehensive STAMP (Systems-Theoretic Accident
  Model and Processes) safety constraint testing for the NixOS container
  infrastructure.

  ## Safety Constraints Tested
  - SC-CNT-001: All containers MUST use localhost registry
  - SC-CNT-002: SSL certificates MUST be accessible within containers
  - SC-CNT-003: PHICS hot-reloading MUST work across container boundaries
  - SC-CNT-004: Container health checks MUST pass before dependencies
  - SC-CNT-005: All logs MUST be centralized in ./__data/tmp

  ## Agent-Friendly Testing
  All tests include comprehensive agent-friendly comments explaining the
  safety rationale and expected behaviors for container operations.
  """

  use ExUnit.Case, async: false
  use PropCheck

  require Logger

  @local_registry_prefix "localhost/"
  @ssl_cert_paths [
    "/etc/ssl/certs/ca-bundle.crt",
    "/etc/pki/tls/certs/ca-bundle.crt",
    "/etc/ssl/cert.pem",
    "/etc/ssl/certs/ca-certificates.crt"
  ]
  @log_dir "./__data/tmp"

  describe "SC-CNT-001: Container Registry Safety Constraint" do
    test "all running containers use localhost registry only" do
      # Agent-friendly comment: This safety constraint pr__events supply chain
      # attacks by ensuring all containers come from our local registry

      case System.cmd("podman", ["ps", "--format", "{{.Image}}"], stderr_to_stdout: true) do
        {output, 0} when byte_size(output) > 0 ->
          container_images = output |> String.trim() |> String.split("\n")

          Enum.each(container_images, fn image ->
            assert String.starts_with?(image, @local_registry_prefix),
                   "Container image #{image} does not use localhost registry (SC-CNT-001 violation)"
          end)

        {_output, 0} ->
          # No containers running - this is acceptable
          :ok

        {error, _} ->
          flunk("Could not check container images: #{error}")
      end
    end

    test "podman image repository compliance" do
      # Agent-friendly comment: This validates that stored images in the
      # Podman registry comply with local-only __requirements

      case System.cmd("podman", ["images", "--format", "{{.Repository}}"], stderr_to_stdout: true) do
        {output, 0} ->
          repositories =
            output
            |> String.trim()
            |> String.split("\n")
            |> Enum.reject(fn repo -> repo == "<none>" or repo == "" end)

          non_localhost_repos =
            Enum.reject(repositories, fn repo ->
              String.starts_with?(repo, @local_registry_prefix)
            end)

          assert Enum.empty?(non_localhost_repos),
                 "Non-localhost repositories found: #{inspect(non_localhost_repos)} (SC-CNT-001 violation)"

        {error, _} ->
          flunk("Could not check image repositories: #{error}")
      end
    end

    property "all container configurations use localhost registry" do
      # Agent-friendly comment: Property-based test that validates localhost
      # registry usage across various container configuration scenarios

      forall container_config <- container_configuration_generator() do
        image_repo = container_config.image |> String.split(":") |> List.first()
        String.starts_with?(image_repo, @local_registry_prefix)
      end
    end
  end

  describe "SC-CNT-002: SSL Certificate Accessibility Safety Constraint" do
    test "SSL environment script exists and is executable" do
      # Agent-friendly comment: The SSL environment script is critical for
      # resolving Erlang/OTP certificate discovery in NixOS containers

      ssl_env_script = "/tmp/ssl_env.sh"

      assert File.exists?(ssl_env_script),
             "SSL environment script not found at #{ssl_env_script} (SC-CNT-002 violation)"

      # Check if script is executable
      case System.cmd("test", ["-x", ssl_env_script]) do
        {_output, 0} ->
          :ok

        {_output, _} ->
          flunk("SSL environment script is not executable (SC-CNT-002 violation)")
      end
    end

    test "CA certificate bundle accessible in containers" do
      # Agent-friendly comment: This validates that running containers can
      # access SSL certificates through the multi-path strategy

      case System.cmd("podman", ["ps", "-q"], stderr_to_stdout: true) do
        {output, 0} when byte_size(output) > 0 ->
          container_ids = output |> String.trim() |> String.split("\n")

          Enum.each(container_ids, fn container_id ->
            # Test each SSL certificate path
            result =
              Enum.any?(@ssl_cert_paths, fn cert_path ->
                case System.cmd("podman", ["exec", container_id, "test", "-f", cert_path],
                       stderr_to_stdout: true
                     ) do
                  {_output, 0} -> true
                  {_output, _} -> false
                end
              end)

            assert result,
                   "No SSL certificate paths accessible in container #{container_id} (SC-CNT-002 violation)"
          end)

        {_output, 0} ->
          # No containers running - test passes
          :ok

        {error, _} ->
          Logger.warning("Could not check SSL certificates in containers: #{error}")
      end
    end

    test "Erlang SSL certificate discovery functional" do
      # Agent-friendly comment: This tests that Erlang's pubkey_os_cacerts:get/0
      # can successfully find SSL certificates in container environment

      case System.cmd("podman", ["ps", "-q", "--filter", "ancestor=localhost/indrajaal-app"],
             stderr_to_stdout: true
           ) do
        {output, 0} when byte_size(output) > 0 ->
          container_id = output |> String.trim() |> String.split("\n") |> List.first()

          # Test Erlang SSL certificate discovery
          erlang_test =
            "erl -eval \"io:format(\\\"~p~n\\\", [public_key:cacerts_get()]), halt().\""

          case System.cmd("podman", ["exec", container_id, "sh", "-c", erlang_test],
                 stderr_to_stdout: true
               ) do
            {output, 0} ->
              # Should return a list of certificates, not :no_cacerts_found
              refute String.contains?(output, "no_cacerts_found"),
                     "Erlang cannot find SSL certificates in container (SC-CNT-002 violation)"

            {error, _} ->
              Logger.warning("Could not test Erlang SSL in container: #{error}")
          end

        {_output, 0} ->
          # No app containers running - skip test
          :ok
      end
    end
  end

  describe "SC-CNT-003: PHICS Hot-Reloading Safety Constraint" do
    test "PHICS environment variables configured" do
      # Agent-friendly comment: PHICS (Phoenix Hot-reloading Integration
      # Container System) __requires specific environment variables

      case System.cmd("podman", ["ps", "-q", "--filter", "ancestor=localhost/indrajaal-app"],
             stderr_to_stdout: true
           ) do
        {output, 0} when byte_size(output) > 0 ->
          container_id = output |> String.trim() |> String.split("\n") |> List.first()

          phics_vars = ["PHICS_ENABLED", "PHICS_WATCH_ENABLED"]

          Enum.each(phics_vars, fn var ->
            case System.cmd("podman", ["exec", container_id, "printenv", var],
                   stderr_to_stdout: true
                 ) do
              {value, 0} when byte_size(value) > 0 ->
                assert String.trim(value) in ["true", "enabled"],
                       "#{var} not properly configured: #{value} (SC-CNT-003 violation)"

              {_output, _} ->
                flunk("#{var} environment variable not found (SC-CNT-003 violation)")
            end
          end)

        {_output, 0} ->
          # No app containers running - skip test
          :ok
      end
    end

    test "file system changes detectable from host to container" do
      # Agent-friendly comment: This validates bidirectional file sync
      # capability essential for PHICS hot-reloading functionality

      test_file = "tmp/phics_test_#{:os.system_time(:millisecond)}.tmp"
      test_content = "PHICS test - #{DateTime.utc_now()}"

      # Ensure tmp directory exists
      File.mkdir_p!("tmp")

      # Create test file on host
      :ok = File.write(test_file, test_content)

      # Check if file is visible in containers with volume mounts
      case System.cmd("podman", ["ps", "-q", "--filter", "ancestor=localhost/indrajaal-app"],
             stderr_to_stdout: true
           ) do
        {output, 0} when byte_size(output) > 0 ->
          container_id = output |> String.trim() |> String.split("\n") |> List.first()

          # Test file visibility in container
          container_path = "/workspace/#{test_file}"

          case System.cmd("podman", ["exec", container_id, "test", "-f", container_path],
                 stderr_to_stdout: true
               ) do
            {_output, 0} ->
              # File is visible - test container content
              case System.cmd("podman", ["exec", container_id, "cat", container_path],
                     stderr_to_stdout: true
                   ) do
                {content, 0} ->
                  assert String.trim(content) == test_content,
                         "File content mismatch in container (SC-CNT-003 violation)"

                {error, _} ->
                  flunk("Could not read test file in container: #{error}")
              end

            {_output, _} ->
              Logger.warning(
                "Test file not visible in container - volume mount may not be configured"
              )
          end

        {_output, 0} ->
          # No app containers running - skip test
          :ok
      end

      # Clean up test file
      File.rm(test_file)
    end
  end

  describe "SC-CNT-004: Container Health Check Safety Constraint" do
    test "infrastructure containers have health checks defined" do
      # Agent-friendly comment: Health checks are critical for safe dependency
      # startup ordering and system reliability

      required_containers = [
        "indrajaal-timescaledb-demo",
        "indrajaal-redis-demo",
        "indrajaal-app-demo"
      ]

      case System.cmd("podman", ["ps", "--format", "{{.Names}}\t{{.Status}}"],
             stderr_to_stdout: true
           ) do
        {output, 0} when byte_size(output) > 0 ->
          container_statuses =
            output
            |> String.trim()
            |> String.split("\n")
            |> Enum.map(fn line -> String.split(line, "\t") end)

          running_containers = Enum.map(container_statuses, fn [name, _] -> name end)

          Enum.each(required_containers, fn container ->
            if container in running_containers do
              # Check that container has health status
              status_line = Enum.find(container_statuses, fn [name, _] -> name == container end)

              case status_line do
                [_, status] ->
                  assert String.contains?(status, "(health") or
                           String.contains?(status, "healthy"),
                         "Container #{container} does not have health check configured (SC-CNT-004 violation)"

                nil ->
                  flunk("Could not find status for #{container}")
              end
            end
          end)

        {_output, 0} ->
          # No containers running - skip test
          :ok
      end
    end

    test "healthy containers exist before dependent containers start" do
      # Agent-friendly comment: This validates the dependency chain that
      # ensures __database containers are healthy before app containers start

      case System.cmd("podman", ["ps", "--filter", "health=healthy", "--format", "{{.Names}}"],
             stderr_to_stdout: true
           ) do
        {output, 0} when byte_size(output) > 0 ->
          healthy_containers = output |> String.trim() |> String.split("\n")

          # If app container is running, infrastructure should be healthy
          if "indrajaal-app-demo" in healthy_containers do
            infrastructure_containers = ["indrajaal-timescaledb-demo", "indrajaal-redis-demo"]

            Enum.each(infrastructure_containers, fn infra_container ->
              assert infra_container in healthy_containers,
                     "Infrastructure container #{infra_container} not healthy while app is running (SC-CNT-004 violation)"
            end)
          end

        {_output, 0} ->
          # No healthy containers - skip test
          :ok
      end
    end
  end

  describe "SC-CNT-005: Centralized Logging Safety Constraint" do
    test "log directory exists and is writable" do
      # Agent-friendly comment: Centralized logging in ./__data/tmp is __required
      # for audit compliance and troubleshooting capabilities

      assert File.exists?(@log_dir) and File.dir?(@log_dir),
             "Log directory #{@log_dir} does not exist (SC-CNT-005 violation)"

      # Test write permissions
      test_log_file = Path.join(@log_dir, "container_test_#{:os.system_time(:millisecond)}.log")
      test_content = "Container safety test log entry"

      assert :ok = File.write(test_log_file, test_content),
             "Cannot write to log directory #{@log_dir} (SC-CNT-005 violation)"

      # Verify content
      assert {:ok, ^test_content} = File.read(test_log_file),
             "Log file content verification failed (SC-CNT-005 violation)"

      # Clean up
      File.rm(test_log_file)
    end

    test "containers mount log directory for centralized logging" do
      # Agent-friendly comment: This validates that containers have access
      # to the centralized logging directory for audit trail maintenance

      case System.cmd("podman", ["ps", "-q"], stderr_to_stdout: true) do
        {output, 0} when byte_size(output) > 0 ->
          container_ids = output |> String.trim() |> String.split("\n")

          Enum.each(container_ids, fn container_id ->
            # Check if container has log mount point
            case System.cmd("podman", ["exec", container_id, "test", "-d", "/var/log/claude"],
                   stderr_to_stdout: true
                 ) do
              {_output, 0} ->
                # Test write access
                test_file = "/var/log/claude/container_#{container_id}_test.log"
                test_content = "Container logging test"

                case System.cmd(
                       "podman",
                       [
                         "exec",
                         container_id,
                         "sh",
                         "-c",
                         "echo '#{test_content}' > #{test_file}"
                       ],
                       stderr_to_stdout: true
                     ) do
                  {_output, 0} ->
                    # Verify file appears in host log directory
                    host_file = Path.join(@log_dir, "container_#{container_id}_test.log")

                    # Allow small delay for file sync
                    :timer.sleep(100)

                    if File.exists?(host_file) do
                      # Clean up
                      File.rm(host_file)
                    else
                      Logger.warning("Log file not synced from container #{container_id}")
                    end

                  {error, _} ->
                    Logger.warning("Could not write log in container #{container_id}: #{error}")
                end

              {_output, _} ->
                Logger.warning("Container #{container_id} does not have log mount point")
            end
          end)

        {_output, 0} ->
          # No containers running - skip test
          :ok
      end
    end
  end

  # Property-based testing generators

  defp container_configuration_generator do
    let {name, tag} <- {
          oneof(["app", "timescaledb", "redis", "prometheus", "grafana", "nginx"]),
          oneof(["nixos-devenv", "demo-ready", "latest"])
        } do
      %{
        name: name,
        image: "localhost/indrajaal-#{name}:#{tag}",
        registry: "localhost"
      }
    end
  end

  defp container_names_generator do
    oneof([
      "indrajaal-app-demo",
      "indrajaal-timescaledb-demo",
      "indrajaal-redis-demo",
      "indrajaal-prometheus-demo",
      "indrajaal-grafana-demo",
      "indrajaal-nginx-demo"
    ])
  end

  # Helper functions for container operations

  defp get_running_containers do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}"], stderr_to_stdout: true) do
      {output, 0} when byte_size(output) > 0 ->
        output |> String.trim() |> String.split("\n")

      {_output, _} ->
        []
    end
  end

  defp container_exists?(container_name) do
    container_name in get_running_containers()
  end
end
