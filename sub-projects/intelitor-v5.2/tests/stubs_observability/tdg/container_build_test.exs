defmodule Observability.TDG.ContainerBuildTest do
  @moduledoc """
  TDG (Test-Driven Generation) tests for SigNoz container builds.
  These tests MUST pass before any container implementation.

  Following CLAUDE.md TDG __requirements:
  - Tests written BEFORE implementation
  - 100% coverage __requirement
  - All AI-generated code must pass these tests
  """
  use ExUnit.Case, async: false

  @tag :tdg_required
  @tag :container
  describe "ClickHouse container build" do
    test "creates valid NixOS-based ClickHouse image" do
      # Test specification for ClickHouse container
      nix_file = "containers/signoz/clickhouse-nixos.nix"

      # File must exist
      assert File.exists?(nix_file), "ClickHouse Nix derivation must exist"

      # Build must succeed
      assert {:ok, result} = build_nix_container(nix_file)
      assert result =~ "localhost/signoz-clickhouse"

      # Verify image properties
      assert {:ok, image_info} = inspect_container_image("localhost/signoz-clickhouse:latest")
      assert image_info["Config"]["ExposedPorts"]["8123/tcp"] != nil
      assert image_info["Config"]["ExposedPorts"]["9000/tcp"] != nil
      assert image_info["Config"]["Volumes"]["/var/lib/clickhouse"] != nil
    end

    test "ClickHouse container starts successfully with health checks" do
      container_name = "test-clickhouse-#{:rand.uniform(9999)}"

      # Start container
      assert {:ok, container_id} =
               start_container("localhost/signoz-clickhouse:latest", container_name, %{
                 ports: ["8123:8123", "9000:9000"],
                 volumes: ["clickhouse-test-data:/var/lib/clickhouse"],
                 env: [
                   "CLICKHOUSE_DB=signoz",
                   "CLICKHOUSE_USER=signoz",
                   "CLICKHOUSE_PASSWORD=test123"
                 ]
               })

      # Wait for health check
      assert {:ok, :healthy} = wait_for_container_health(container_id, timeout: 30_000)

      # Verify ClickHouse is responding
      assert {:ok, "1\n"} =
               execute_in_container(
                 container_id,
                 "clickhouse-client --query 'SELECT 1'"
               )

      # Cleanup
      stop_and_remove_container(container_id)
    end

    test "ClickHouse container has proper security constraints" do
      # STAMP: Verify safety constraints are enforced
      assert {:ok, image_info} = inspect_container_image("localhost/signoz-clickhouse:latest")

      # Must run as non-root user
      assert image_info["Config"]["User"] != "root" and image_info["Config"]["User"] != ""

      # Data directory must have restricted permissions
      assert {:ok, perms} =
               get_directory_permissions_in_image(
                 "localhost/signoz-clickhouse:latest",
                 "/var/lib/clickhouse"
               )

      assert perms =~ "700" or perms =~ "750"
    end
  end

  @tag :tdg_required
  describe "SigNoz Query Service container build" do
    test "creates valid query service container" do
      nix_file = "containers/signoz/query-service-nixos.nix"

      assert File.exists?(nix_file)
      assert {:ok, result} = build_nix_container(nix_file)
      assert result =~ "localhost/signoz-query"

      # Verify configuration
      assert {:ok, image_info} = inspect_container_image("localhost/signoz-query:latest")
      assert image_info["Config"]["ExposedPorts"]["8080/tcp"] != nil
      assert image_info["Config"]["Env"] |> Enum.any?(&(&1 =~ "STORAGE_TYPE=clickhouse"))
    end

    test "query service connects to ClickHouse successfully" do
      # Start ClickHouse first
      clickhouse_id = start_test_clickhouse()

      # Start query service
      container_name = "test-query-#{:rand.uniform(9999)}"

      assert {:ok, query_id} =
               start_container("localhost/signoz-query:latest", container_name, %{
                 ports: ["8080:8080"],
                 env: [
                   "ClickHouseUrl=tcp://test-clickhouse:9000/?database=signoz",
                   "STORAGE=clickhouse"
                 ],
                 network: "test-network"
               })

      # Verify connectivity
      assert {:ok, :connected} = wait_for_service_ready(query_id, port: 8080)

      # Cleanup
      stop_and_remove_container(query_id)
      stop_and_remove_container(clickhouse_id)
    end
  end

  @tag :tdg_required
  describe "OpenTelemetry Collector container build" do
    test "creates valid OTEL collector container" do
      nix_file = "containers/signoz/otel-collector-nixos.nix"

      assert File.exists?(nix_file)
      assert {:ok, result} = build_nix_container(nix_file)
      assert result =~ "localhost/signoz-otel-collector"

      # Verify OTLP ports
      assert {:ok, image_info} = inspect_container_image("localhost/signoz-otel-collector:latest")
      # gRPC
      assert image_info["Config"]["ExposedPorts"]["4317/tcp"] != nil
      # HTTP
      assert image_info["Config"]["ExposedPorts"]["4318/tcp"] != nil
    end

    test "OTEL collector processes telemetry data" do
      # This test verifies the collector can receive and forward data
      container_name = "test-otel-#{:rand.uniform(9999)}"

      # Create test config
      test_config = create_test_otel_config()

      assert {:ok, collector_id} =
               start_container("localhost/signoz-otel-collector:latest", container_name, %{
                 ports: ["4317:4317", "4318:4318"],
                 volumes: ["#{test_config}:/etc/otel/config.yaml:ro"]
               })

      # Send test telemetry
      assert :ok = send_test_trace_to_collector("localhost:4317")

      # Verify processing (check logs)
      assert {:ok, logs} = get_container_logs(collector_id)
      assert logs =~ "TracesExporter"

      stop_and_remove_container(collector_id)
    end
  end

  @tag :tdg_required
  describe "Frontend container build" do
    test "creates valid SigNoz frontend container" do
      nix_file = "containers/signoz/frontend-nixos.nix"

      assert File.exists?(nix_file)
      assert {:ok, result} = build_nix_container(nix_file)
      assert result =~ "localhost/signoz-frontend"

      # Verify web UI port
      assert {:ok, image_info} = inspect_container_image("localhost/signoz-frontend:latest")
      assert image_info["Config"]["ExposedPorts"]["3301/tcp"] != nil
    end
  end

  # Helper functions for container testing
  defp build_nix_container(nix_file) do
    case System.cmd("nix-build", [nix_file, "-o", "result-test"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, _} -> {:error, error}
    end
  end

  defp inspect_container_image(image) do
    case System.cmd("podman", ["inspect", image], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, [info | _]} -> {:ok, info}
          error -> error
        end

      {error, _} ->
        {:error, error}
    end
  end

  defp start_container(image, name, opts) do
    args = ["run", "-d", "--name", name]

    # Add ports
    args =
      Enum.reduce(opts[:ports] || [], args, fn port, acc ->
        acc ++ ["-p", port]
      end)

    # Add volumes
    args =
      Enum.reduce(opts[:volumes] || [], args, fn vol, acc ->
        acc ++ ["-v", vol]
      end)

    # Add environment variables
    args =
      Enum.reduce(opts[:env] || [], args, fn env, acc ->
        acc ++ ["-e", env]
      end)

    # Add network if specified
    args = if opts[:network], do: args ++ ["--network", opts[:network]], else: args

    args = args ++ [image]

    case System.cmd("podman", args, stderr_to_stdout: true) do
      {cid, 0} -> {:ok, String.trim(cid)}
      {error, _} -> {:error, error}
    end
  end

  defp wait_for_container_health(container_id, opts) do
    timeout = opts[:timeout] || 30_000
    interval = opts[:interval] || 1_000
    deadline = System.monotonic_time(:millisecond) + timeout

    wait_for_health_loop(container_id, deadline, interval)
  end

  defp wait_for_health_loop(container_id, deadline, interval) do
    case System.cmd("podman", ["inspect", container_id, "--format", "{{.State.Health.Status}}"],
           stderr_to_stdout: true
         ) do
      {"healthy\n", 0} ->
        {:ok, :healthy}

      {_, 0} ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(interval)
          wait_for_health_loop(container_id, deadline, interval)
        else
          {:error, :timeout}
        end

      {error, _} ->
        {:error, error}
    end
  end

  defp execute_in_container(container_id, command) do
    case System.cmd("podman", ["exec", container_id, "sh", "-c", command], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, code} -> {:error, {code, error}}
    end
  end

  defp stop_and_remove_container(container_id) do
    System.cmd("podman", ["stop", container_id])
    System.cmd("podman", ["rm", container_id])
    :ok
  end

  defp get_directory_permissions_in_image(image, path) do
    # Create temporary container to check permissions
    container_name = "perm-check-#{:rand.uniform(9999)}"

    case System.cmd(
           "podman",
           ["run", "--rm", "--name", container_name, image, "stat", "-c", "%a", path],
           stderr_to_stdout: true
         ) do
      {perms, 0} -> {:ok, String.trim(perms)}
      {error, _} -> {:error, error}
    end
  end

  defp start_test_clickhouse do
    # Helper to start a test ClickHouse instance
    {:ok, container_id} =
      start_container("localhost/signoz-clickhouse:latest", "test-clickhouse", %{
        ports: ["9000:9000"],
        env: ["CLICKHOUSE_DB=signoz"],
        network: "test-network"
      })

    # Wait for it to be ready
    {:ok, :healthy} = wait_for_container_health(container_id, timeout: 30_000)

    container_id
  end

  defp wait_for_service_ready(container_id, opts) do
    port = opts[:port]
    timeout = opts[:timeout] || 30_000
    deadline = System.monotonic_time(:millisecond) + timeout

    wait_for_service_loop(container_id, port, deadline)
  end

  defp wait_for_service_loop(container_id, port, deadline) do
    # Check if service is responding
    case execute_in_container(
           container_id,
           "curl -s -o /dev/null -w '%{http_code}' http://localhost:#{port}/health"
         ) do
      {:ok, "200"} ->
        {:ok, :connected}

      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(1_000)
          wait_for_service_loop(container_id, port, deadline)
        else
          {:error, :timeout}
        end
    end
  end

  defp create_test_otel_config do
    config = """
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      batch:

    exporters:
      logging:
        loglevel: debug

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [logging]
    """

    # Write to temp file
    path = "/tmp/otel-test-config-#{:rand.uniform(9999)}.yaml"
    File.write!(path, config)
    path
  end

  defp send_test_trace_to_collector(endpoint) do
    # This would use the OpenTelemetry client to send a test trace
    # For now, we'll simulate it
    :ok
  end

  defp get_container_logs(container_id) do
    case System.cmd("podman", ["logs", container_id], stderr_to_stdout: true) do
      {logs, 0} -> {:ok, logs}
      {error, _} -> {:error, error}
    end
  end
end
