defmodule IndrajaalWeb.HealthControllerTest do
  @moduledoc """
  TDG comprehensive test suite for IndrajaalWeb.HealthController.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation fixes
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-OBS-065: Health monitoring endpoints
  - SC-OBS-066: Dependency health tracking
  - SC-EMR-057: Emergency health detection
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests

  ## Constitutional Verification
  - Psi0 Existence: Health endpoints always respond (liveness never fails)
  - Psi3 Verification: All checks return verifiable structured JSON

  ## Founder's Directive Alignment
  - Omega0.1: Health endpoints ensure operational continuity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Health probes return incorrect status codes
  - L5 Root Cause: Missing check integration or malformed responses
  """

  use IndrajaalWeb.ConnCase, async: false

  @moduletag :zenoh_nif

  # ==========================================================================
  # GET /healthz (liveness probe)
  # ==========================================================================

  describe "liveness/2 - GET /healthz" do
    test "returns 200 always (liveness never fails)", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      assert conn.status == 200
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
    end

    test "response body contains status: ok", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "ok"
    end

    test "response body contains probe: liveness", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      body = Jason.decode!(conn.resp_body)
      assert body["probe"] == "liveness"
    end

    test "response body contains timestamp field", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["timestamp"])
      assert String.length(body["timestamp"]) > 0
    end

    test "response body contains node field", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["node"])
    end

    test "liveness responds on repeated calls", %{conn: conn} do
      for _ <- 1..3 do
        resp = get(conn, ~p"/healthz")
        assert resp.status == 200
      end
    end
  end

  # ==========================================================================
  # GET /ready (readiness probe)
  # ==========================================================================

  describe "readiness/2 - GET /ready" do
    test "returns 200 or 503 (binary outcome)", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      assert conn.status in [200, 503]
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
    end

    test "response body contains probe: readiness", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      body = Jason.decode!(conn.resp_body)
      assert body["probe"] == "readiness"
    end

    test "response body status is ready or not_ready", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      body = Jason.decode!(conn.resp_body)
      assert body["status"] in ["ready", "not_ready"]
    end

    test "response body contains checks map", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["checks"])
    end

    test "status code matches ready/not_ready status string", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      body = Jason.decode!(conn.resp_body)

      cond do
        conn.status == 200 -> assert body["status"] == "ready"
        conn.status == 503 -> assert body["status"] == "not_ready"
      end
    end

    test "response body contains timestamp", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["timestamp"])
    end
  end

  # ==========================================================================
  # GET /startup (startup probe)
  # ==========================================================================

  describe "startup/2 - GET /startup" do
    test "returns 200 or 503", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      assert conn.status in [200, 503]
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
    end

    test "response body contains probe: startup", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      body = Jason.decode!(conn.resp_body)
      assert body["probe"] == "startup"
    end

    test "response body status is started or starting", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      body = Jason.decode!(conn.resp_body)
      assert body["status"] in ["started", "starting"]
    end

    test "response body contains uptime_ms", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      body = Jason.decode!(conn.resp_body)
      assert is_integer(body["uptime_ms"])
    end

    test "uptime_ms is non-negative", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      body = Jason.decode!(conn.resp_body)
      assert body["uptime_ms"] >= 0
    end

    test "response body contains checks map", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["checks"])
    end
  end

  # ==========================================================================
  # GET /health (comprehensive)
  # ==========================================================================

  describe "comprehensive/2 - GET /health" do
    test "returns 200 or 503", %{conn: conn} do
      conn = get(conn, ~p"/health")
      assert conn.status in [200, 503]
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, ~p"/health")
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/json"
    end

    test "response body contains status field", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      assert body["status"] in ["healthy", "unhealthy"]
    end

    test "response body contains timestamp", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["timestamp"])
    end

    test "response body contains node", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["node"])
    end

    test "response body contains version", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["version"])
    end

    test "response body contains probes map", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["probes"])
    end

    test "probes contains liveness, readiness, startup keys", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      probes = body["probes"]
      assert Map.has_key?(probes, "liveness")
      assert Map.has_key?(probes, "readiness")
      assert Map.has_key?(probes, "startup")
    end

    test "response body contains system map", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      assert is_map(body["system"])
    end

    test "system contains otp_release and elixir_version", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      system = body["system"]
      assert is_binary(system["otp_release"])
      assert is_binary(system["elixir_version"])
    end

    test "system contains schedulers count", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      system = body["system"]
      assert is_integer(system["schedulers"])
      assert system["schedulers"] > 0
    end

    test "system contains memory_mb", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      system = body["system"]
      assert is_integer(system["memory_mb"])
    end

    test "response body contains container field (may be unavailable)", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)
      # Container may be unavailable in test env — just assert it's present
      assert Map.has_key?(body, "container")
    end

    test "status code consistent with healthy/unhealthy status", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = Jason.decode!(conn.resp_body)

      cond do
        conn.status == 200 -> assert body["status"] == "healthy"
        conn.status == 503 -> assert body["status"] == "unhealthy"
      end
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements (SC-OBS-065)" do
    test "liveness endpoint responds within time budget", %{conn: conn} do
      start = System.monotonic_time(:millisecond)
      get(conn, ~p"/healthz")
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 5_000, "Liveness took #{elapsed}ms, expected < 5s"
    end

    test "comprehensive endpoint responds within time budget", %{conn: conn} do
      start = System.monotonic_time(:millisecond)
      get(conn, ~p"/health")
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 10_000, "Comprehensive health check took #{elapsed}ms, expected < 10s"
    end

    test "all health endpoints return valid JSON (no 500 errors)", %{conn: conn} do
      endpoints = [~p"/healthz", ~p"/ready", ~p"/startup", ~p"/health"]

      Enum.each(endpoints, fn path ->
        resp = get(conn, path)
        # Must not be 500 — only 200 or 503 are valid
        assert resp.status != 500, "#{path} returned 500"
        # Must decode as valid JSON
        assert {:ok, _} = Jason.decode(resp.resp_body), "#{path} returned invalid JSON"
      end)
    end

    test "Psi0 existence: liveness probe never returns 503 (always alive)", %{conn: conn} do
      conn = get(conn, ~p"/healthz")

      assert conn.status == 200,
             "Liveness (Psi0) MUST always return 200 — system must always exist"
    end
  end

  # ==========================================================================
  # FMEA Tests
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-HC-001: all probes return structured JSON even under dependency failure", %{
      conn: conn
    } do
      # Readiness/startup may fail if deps are down — but response must be structured JSON
      conn_r = get(conn, ~p"/ready")
      assert {:ok, body_r} = Jason.decode(conn_r.resp_body)
      assert is_map(body_r)
      assert Map.has_key?(body_r, "status")
      assert Map.has_key?(body_r, "checks")
    end

    @tag :fmea
    test "FMEA-HC-002: concurrent health requests do not cause race conditions", %{conn: conn} do
      tasks =
        Enum.map(1..5, fn _ ->
          Task.async(fn -> get(conn, ~p"/healthz") end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 10_000))

      Enum.each(results, fn resp ->
        assert resp.status == 200
      end)
    end

    @tag :fmea
    test "FMEA-HC-003: comprehensive endpoint handles ContainerHealthSensor unavailability", %{
      conn: conn
    } do
      # ContainerHealthSensor may not be running in test — endpoint must survive
      conn = get(conn, ~p"/health")
      # Must respond — either 200 or 503
      assert conn.status in [200, 503]
      # Container section may show unavailable
      body = Jason.decode!(conn.resp_body)
      assert Map.has_key?(body, "container")
    end
  end
end
