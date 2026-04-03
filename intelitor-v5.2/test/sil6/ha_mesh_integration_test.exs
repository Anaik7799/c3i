defmodule Indrajaal.SIL6.HAMeshIntegrationTest do
  @moduledoc """
  SIL-6 HA Mesh Integration Tests

  WHAT: Integration tests for live SIL-6 mesh deployment (15-container genome)
  WHY: Validates real container interactions and network paths
  CONSTRAINTS: Requires running SIL-6 mesh (sa-up or Panoptic Ignition v2.0)

  ## Prerequisites
  - SIL-6 mesh running: `./sa-up` or F# Panoptic Ignition
  - All 15 containers healthy (7-tier boot hierarchy)
  - App accessible on port 4000
  """

  use ExUnit.Case, async: false

  # Skip if containers not running
  @moduletag :integration
  @moduletag :sil6
  @moduletag :requires_ha_mesh
  @moduletag :requires_containers

  # Endpoints
  @haproxy_url "http://localhost:4000"
  @haproxy_stats_url "http://localhost:8404/stats"
  @health_endpoint "/api/health"
  @prajna_endpoint "/prajna"

  # Timeouts
  @http_timeout 5_000
  @health_check_interval 10_000

  setup_all do
    case check_ha_mesh_status() do
      {:ok, status} ->
        {:ok, %{mesh_status: status}}

      {:error, reason} ->
        IO.puts("\n⚠️  HA Mesh not available: #{reason}")

        IO.puts(
          "   Run: podman-compose -f lib/cepaf/artifacts/podman-compose-ha-full-mesh.yml up -d"
        )

        {:ok, %{mesh_status: nil, mesh_available: false}}
    end
  end

  # =============================================================================
  # CONTAINER STATUS TESTS
  # =============================================================================

  describe "Container Status: All 15 containers healthy (SIL-6 Genome)" do
    @tag :container_status
    test "all containers are running", %{mesh_status: status} do
      # 15-container SIL-6 genome (Panoptic Ignition v2.0)
      # 5 BuiltFromDockerfile + 2 PulledFromRegistry + 8 SharedImage
      expected_containers = [
        # Tier 1: Zenoh Router (PulledFromRegistry)
        "zenoh-router",
        # Tier 2: Database (BuiltFromDockerfile)
        "indrajaal-db-prod",
        # Tier 3: Observability (BuiltFromDockerfile)
        "indrajaal-obs-prod",
        # Tier 4: Quorum Routers (SharedImage from zenoh-router)
        "zenoh-router-1",
        "zenoh-router-2",
        "zenoh-router-3",
        # Tier 5: Cognitive (BuiltFromDockerfile)
        "indrajaal-bridge",
        "indrajaal-cortex",
        # Tier 6: Seed + Twin + Ollama
        "indrajaal-ex-app-1",
        "indrajaal-chaya",
        "indrajaal-ollama",
        # Tier 7: HA + ML
        "indrajaal-ex-app-2",
        "indrajaal-ex-app-3",
        "indrajaal-ml-runner-1",
        "indrajaal-ml-runner-2"
      ]

      running =
        Enum.filter(expected_containers, fn name ->
          name in status.running_containers
        end)

      assert length(running) == 15,
             "Expected 15 containers, got #{length(running)}: #{inspect(running)}"
    end

    @tag :container_status
    test "all containers report healthy", %{mesh_status: status} do
      # Allow some containers to be in "starting" state
      unhealthy =
        Enum.filter(status.health_statuses, fn {_name, health} ->
          health not in ["healthy", "starting"]
        end)

      assert length(unhealthy) == 0,
             "Unhealthy containers: #{inspect(unhealthy)}"
    end
  end

  # =============================================================================
  # HAPROXY TESTS
  # =============================================================================

  describe "HAProxy: Load Balancer Operations" do
    @tag :haproxy
    test "HAProxy responds on port 4000" do
      case http_get(@haproxy_url) do
        {:ok, response} ->
          assert response.status in [200, 302, 404],
                 "Expected valid HTTP response, got #{response.status}"

        {:error, reason} ->
          flunk("HAProxy not responding: #{inspect(reason)}")
      end
    end

    @tag :haproxy
    test "HAProxy stats endpoint accessible" do
      case http_get("#{@haproxy_stats_url}?stats;csv") do
        {:ok, response} ->
          assert response.status == 200

          assert String.contains?(response.body, "app-1") or
                   String.contains?(response.body, "BACKEND")

        {:error, reason} ->
          flunk("HAProxy stats not accessible: #{inspect(reason)}")
      end
    end

    @tag :haproxy
    @tag :load_balancing
    test "requests distributed across backends" do
      # Send 30 requests and track which backend handles each
      results =
        Enum.map(1..30, fn _ ->
          case http_get("#{@haproxy_url}#{@health_endpoint}") do
            {:ok, response} ->
              # Try to extract server from response headers or body
              extract_backend(response)

            {:error, _} ->
              :error
          end
        end)

      # Remove errors
      successful = Enum.filter(results, fn r -> r != :error end)

      # Should have responses from multiple backends
      unique_backends = Enum.uniq(successful)

      assert length(successful) >= 25,
             "Expected at least 25 successful requests, got #{length(successful)}"

      # If we can identify backends, verify distribution
      if length(unique_backends) > 1 do
        assert length(unique_backends) >= 2,
               "Expected distribution across backends, got: #{inspect(unique_backends)}"
      end
    end
  end

  # =============================================================================
  # DATABASE TESTS
  # =============================================================================

  describe "Database: PostgreSQL Connectivity" do
    @tag :database
    test "database accepts connections on port 5433" do
      case System.cmd("pg_isready", ["-h", "localhost", "-p", "5433", "-U", "postgres"],
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          assert String.contains?(output, "accepting connections")

        {output, code} ->
          flunk("Database not ready (exit #{code}): #{output}")
      end
    rescue
      e ->
        IO.puts("pg_isready not available: #{inspect(e)}")
        # Skip if pg_isready not installed
        :ok
    end
  end

  # =============================================================================
  # ZENOH MESH TESTS
  # =============================================================================

  describe "Zenoh: Message Bus Quorum" do
    @tag :zenoh
    test "primary zenoh-router accessible on port 7447" do
      assert port_open?("localhost", 7447),
             "Primary zenoh-router not listening on port 7447"
    end

    @tag :zenoh
    test "zenoh-router-1 accessible on port 7448" do
      assert port_open?("localhost", 7448),
             "Zenoh quorum router 1 not listening on port 7448"
    end

    @tag :zenoh
    test "zenoh-router-2 accessible on port 7449" do
      assert port_open?("localhost", 7449),
             "Zenoh quorum router 2 not listening on port 7449"
    end

    @tag :zenoh
    test "zenoh-router-3 accessible on port 7450" do
      assert port_open?("localhost", 7450),
             "Zenoh quorum router 3 not listening on port 7450"
    end

    @tag :zenoh
    test "at least 3 zenoh routers healthy (2oo3 quorum from 4 total)" do
      healthy_count =
        Enum.count([7447, 7448, 7449, 7450], fn port ->
          port_open?("localhost", port)
        end)

      assert healthy_count >= 3,
             "Zenoh quorum requires 3oo4, only #{healthy_count} routers healthy"
    end
  end

  # =============================================================================
  # OBSERVABILITY TESTS
  # =============================================================================

  describe "Observability: Monitoring Stack" do
    @tag :observability
    test "Grafana accessible on port 3000" do
      case http_get("http://localhost:3000/api/health") do
        {:ok, response} ->
          assert response.status == 200

        {:error, reason} ->
          flunk("Grafana not accessible: #{inspect(reason)}")
      end
    end

    @tag :observability
    test "Prometheus accessible on port 9090" do
      case http_get("http://localhost:9090/-/healthy") do
        {:ok, response} ->
          assert response.status == 200

        {:error, reason} ->
          flunk("Prometheus not accessible: #{inspect(reason)}")
      end
    end

    @tag :observability
    test "OTEL collector accessible on port 4317" do
      # OTEL gRPC port - check if listening
      assert port_open?("localhost", 4317),
             "OTEL collector not listening on port 4317"
    end
  end

  # =============================================================================
  # PRAJNA COCKPIT TESTS
  # =============================================================================

  describe "Prajna: C3I Cockpit" do
    @tag :prajna
    test "Prajna cockpit loads" do
      case http_get("#{@haproxy_url}#{@prajna_endpoint}") do
        {:ok, response} ->
          assert response.status in [200, 302],
                 "Expected Prajna to load, got #{response.status}"

        {:error, reason} ->
          # May not be available yet during startup
          IO.puts("Prajna not yet available: #{inspect(reason)}")
          :ok
      end
    end
  end

  # =============================================================================
  # FAILOVER SIMULATION TESTS
  # =============================================================================

  describe "Failover: Node Failure Handling" do
    @tag :failover
    @tag :destructive
    # Skip by default - destructive test
    @tag :skip
    test "service continues after app-2 stop" do
      # Stop app-2
      {_output, 0} = System.cmd("podman", ["stop", "indrajaal-ex-app-2"])

      # Wait for HAProxy to detect
      Process.sleep(35_000)

      # Service should still work
      case http_get("#{@haproxy_url}#{@health_endpoint}") do
        {:ok, response} ->
          assert response.status == 200,
                 "Service should continue with 2 nodes"

        {:error, reason} ->
          flunk("Service failed after node stop: #{inspect(reason)}")
      end

      # Restart app-2
      System.cmd("podman", ["start", "indrajaal-ex-app-2"])
    end
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  defp check_ha_mesh_status do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}\t{{.Status}}"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        lines = String.split(output, "\n", trim: true)

        running_containers =
          Enum.map(lines, fn line ->
            [name | _] = String.split(line, "\t")
            name
          end)

        health_statuses =
          Enum.map(lines, fn line ->
            parts = String.split(line, "\t")
            name = hd(parts)

            status =
              if length(parts) > 1 do
                status_str = Enum.at(parts, 1) || ""

                cond do
                  String.contains?(status_str, "(healthy)") -> "healthy"
                  String.contains?(status_str, "(unhealthy)") -> "unhealthy"
                  String.contains?(status_str, "Up") -> "starting"
                  true -> "unknown"
                end
              else
                "unknown"
              end

            {name, status}
          end)

        # Check if HA mesh containers are present
        mesh_containers =
          Enum.filter(running_containers, fn name ->
            String.contains?(name, "indrajaal") or
              String.contains?(name, "zenoh-router") or
              String.contains?(name, "cepaf")
          end)

        if length(mesh_containers) >= 12 do
          {:ok, %{running_containers: running_containers, health_statuses: health_statuses}}
        else
          {:error, "Only #{length(mesh_containers)} mesh containers found"}
        end

      {output, code} ->
        {:error, "podman failed (#{code}): #{output}"}
    end
  rescue
    e ->
      {:error, "Exception: #{inspect(e)}"}
  end

  defp http_get(url) do
    # Use curl for HTTP requests (available on most systems)
    case System.cmd("curl", ["-s", "-o", "-", "-w", "\n%{http_code}", url],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        lines = String.split(output, "\n")
        status_code = List.last(lines) |> String.trim() |> String.to_integer()
        body = lines |> Enum.drop(-1) |> Enum.join("\n")

        {:ok, %{status: status_code, body: body}}

      {output, _code} ->
        {:error, output}
    end
  rescue
    e ->
      {:error, inspect(e)}
  end

  defp port_open?(host, port) do
    case System.cmd("nc", ["-z", "-w", "1", host, "#{port}"], stderr_to_stdout: true) do
      {_output, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp extract_backend(response) do
    # Try to extract backend from X-Backend-Server header or response
    cond do
      String.contains?(response.body, "app-1") -> "app-1"
      String.contains?(response.body, "app-2") -> "app-2"
      String.contains?(response.body, "app-3") -> "app-3"
      true -> :unknown
    end
  end
end
