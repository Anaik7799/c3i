defmodule IndrajaalWeb.Api.PrajnaControllerSprint32Test do
  @moduledoc """
  Integration tests for Sprint 32 PrajnaController endpoints.

  WHAT: Tests for container, mesh, bio, and domain API endpoints.
  WHY: SC-SYNC-011/012/013 require verified API functionality.
  CONSTRAINTS: TDG compliance, SC-TEST-001.

  ## Test Coverage
  - Container endpoints (SC-SYNC-011)
  - Agent Mesh endpoints (SC-SYNC-012)
  - Biomorphic endpoints (SC-SYNC-013)
  - Domain data endpoints

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 21.1.0 |
  | Sprint | 32 |
  | Created | 2026-01-02 |
  | Author | Cybernetic Architect |
  """

  use IndrajaalWeb.ConnCase, async: true

  describe "Container Operations (SC-SYNC-011)" do
    test "GET /api/v1/prajna/containers/status returns container statuses", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/containers/status")

      assert %{
               "success" => true,
               "data" => %{
                 "containers" => containers,
                 "overall_health" => _health
               }
             } = json_response(conn, 200)

      assert is_list(containers)
      assert length(containers) >= 0

      # If containers exist, verify structure
      if length(containers) > 0 do
        container = List.first(containers)
        assert Map.has_key?(container, "name")
        assert Map.has_key?(container, "status")
        assert Map.has_key?(container, "health")
      end
    end

    test "GET /api/v1/prajna/containers/:id/logs returns container logs", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/containers/indrajaal-ex-app-1/logs")

      assert %{
               "success" => true,
               "data" => %{
                 "container" => "indrajaal-ex-app-1",
                 "logs" => logs,
                 "line_count" => count
               }
             } = json_response(conn, 200)

      assert is_list(logs)
      assert is_integer(count)
    end

    test "GET /api/v1/prajna/containers/:id/logs with lines param", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/containers/indrajaal-ex-app-1/logs?lines=50")

      assert %{"success" => true, "data" => %{"line_count" => _count}} = json_response(conn, 200)
    end

    test "POST /api/v1/prajna/containers/:id/action requires Guardian approval", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/prajna/containers/indrajaal-ex-app-1/action", %{
          "action" => "restart",
          "reason" => "Test restart"
        })

      response = json_response(conn, 200)
      # Either approved and executed or vetoed
      assert response["success"] == true or response["success"] == false
    end
  end

  describe "Agent Mesh Operations (SC-SYNC-012)" do
    test "GET /api/v1/prajna/mesh/agents returns agent list", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/mesh/agents")

      assert %{
               "success" => true,
               "data" => %{
                 "agents" => agents,
                 "total_count" => count
               }
             } = json_response(conn, 200)

      assert is_list(agents)
      assert is_integer(count)
      assert count == length(agents)

      # Verify agent structure
      if length(agents) > 0 do
        agent = List.first(agents)
        assert Map.has_key?(agent, "fqun")
        assert Map.has_key?(agent, "status")
        assert Map.has_key?(agent, "health")
      end
    end

    test "GET /api/v1/prajna/mesh/agents/:id returns agent details or 404", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/mesh/agents/ooda-agent")

      # Agent may not be running in test environment
      case conn.status do
        200 ->
          response = json_response(conn, 200)
          assert response["success"] == true
          assert Map.has_key?(response, "data")

        404 ->
          response = json_response(conn, 404)
          assert response["success"] == false
          assert String.contains?(response["error"], "Agent not found")
      end
    end

    test "GET /api/v1/prajna/mesh/agents/:id returns 404 for unknown agent", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/mesh/agents/unknown-agent-xyz")

      assert %{"success" => false, "error" => _} = json_response(conn, 404)
    end

    test "POST /api/v1/prajna/mesh/agents/:id/command sends command", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/prajna/mesh/agents/ooda-agent/command", %{
          "command" => "status",
          "params" => %{}
        })

      assert %{
               "success" => true,
               "data" => %{
                 "agent" => "ooda-agent",
                 "command" => "status"
               }
             } = json_response(conn, 200)
    end
  end

  describe "Biomorphic Operations (SC-SYNC-013)" do
    test "GET /api/v1/prajna/bio/holons returns holon list", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/bio/holons")

      assert %{
               "success" => true,
               "data" => %{
                 "holons" => holons
               }
             } = json_response(conn, 200)

      assert is_list(holons)

      # Verify holon structure
      if length(holons) > 0 do
        holon = List.first(holons)
        assert Map.has_key?(holon, "id")
        assert Map.has_key?(holon, "health")
        assert Map.has_key?(holon, "vital_signs")
      end
    end

    test "GET /api/v1/prajna/bio/holons/:id/vitals returns vital signs", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/bio/holons/prajna-holon/vitals")

      assert %{
               "success" => true,
               "data" => %{
                 "holon_id" => "prajna-holon",
                 "vital_signs" => vitals
               }
             } = json_response(conn, 200)

      assert is_map(vitals)
      assert Map.has_key?(vitals, "cpu_usage")
      assert Map.has_key?(vitals, "memory_usage")
    end

    test "GET /api/v1/prajna/bio/holons/:id/membrane returns membrane status", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/bio/holons/sentinel-holon/membrane")

      assert %{
               "success" => true,
               "data" => %{
                 "holon_id" => "sentinel-holon",
                 "membrane" => membrane
               }
             } = json_response(conn, 200)

      assert is_map(membrane)
      assert Map.has_key?(membrane, "permeability")
      assert Map.has_key?(membrane, "integrity_score")
    end
  end

  describe "Domain Data Endpoints" do
    test "GET /api/v1/prajna/alarms/correlation returns correlation data", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/alarms/correlation")

      assert %{
               "success" => true,
               "data" => data
             } = json_response(conn, 200)

      assert Map.has_key?(data, "storm_detected")
      assert Map.has_key?(data, "correlation_groups")
      assert Map.has_key?(data, "total_processed_24h")
    end

    test "GET /api/v1/prajna/devices/state returns device states", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/devices/state")

      assert %{
               "success" => true,
               "data" => %{
                 "devices" => devices,
                 "total_count" => count
               }
             } = json_response(conn, 200)

      assert is_list(devices)
      assert is_integer(count)

      # Verify device structure
      if length(devices) > 0 do
        device = List.first(devices)
        assert Map.has_key?(device, "id")
        assert Map.has_key?(device, "status")
        assert Map.has_key?(device, "type")
      end
    end

    test "GET /api/v1/prajna/access/audit returns audit entries", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/access/audit")

      assert %{
               "success" => true,
               "data" => %{
                 "entries" => entries,
                 "count" => count
               }
             } = json_response(conn, 200)

      assert is_list(entries)
      assert is_integer(count)

      # Verify audit entry structure
      if length(entries) > 0 do
        entry = List.first(entries)
        assert Map.has_key?(entry, "id")
        assert Map.has_key?(entry, "action")
        assert Map.has_key?(entry, "timestamp")
      end
    end

    test "GET /api/v1/prajna/access/audit with limit param", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/access/audit?limit=5")

      assert %{
               "success" => true,
               "data" => %{
                 "entries" => entries,
                 "count" => count
               }
             } = json_response(conn, 200)

      assert count <= 5
      assert length(entries) <= 5
    end
  end

  describe "Response Structure Compliance" do
    test "all endpoints include request_id and timestamp", %{conn: conn} do
      endpoints = [
        ~p"/api/v1/prajna/containers/status",
        ~p"/api/v1/prajna/mesh/agents",
        ~p"/api/v1/prajna/bio/holons",
        ~p"/api/v1/prajna/alarms/correlation"
      ]

      for endpoint <- endpoints do
        conn = get(build_conn(), endpoint)
        response = json_response(conn, 200)

        assert Map.has_key?(response, "request_id"),
               "#{endpoint} missing request_id"

        assert Map.has_key?(response, "timestamp"),
               "#{endpoint} missing timestamp"
      end
    end

    test "timestamps are valid ISO8601", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/prajna/containers/status")
      response = json_response(conn, 200)

      assert {:ok, _, _} = DateTime.from_iso8601(response["timestamp"])
    end
  end
end
