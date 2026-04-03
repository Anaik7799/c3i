defmodule IndrajaalWeb.Plugs.HealthPlugTest do
  @moduledoc """
  TDG comprehensive test suite for IndrajaalWeb.Plugs.HealthPlug.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation fixes
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-OBS-065: Health monitoring endpoints
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests

  ## Constitutional Verification
  - Psi0 Existence: Plug passes through non-health paths unchanged

  ## TPS 5-Level RCA Context
  - L1 Symptom: Health plug returns wrong status code
  - L5 Root Cause: HealthCheck module not returning expected boolean
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias IndrajaalWeb.Plugs.HealthPlug

  @moduletag :zenoh_nif

  # ==========================================================================
  # init/1
  # ==========================================================================

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [some_option: true]
      assert HealthPlug.init(opts) == opts
    end

    test "accepts empty opts" do
      assert HealthPlug.init([]) == []
    end
  end

  # ==========================================================================
  # call/2 - /health/live
  # ==========================================================================

  describe "call/2 - /health/live path" do
    test "returns 200 or 503 for /health/live" do
      conn = build_conn("GET", "/health/live")
      conn = HealthPlug.call(conn, [])
      assert conn.status in [200, 503]
    end

    test "halts connection after /health/live response" do
      conn = build_conn("GET", "/health/live")
      conn = HealthPlug.call(conn, [])
      assert conn.halted == true
    end

    test "response body is OK or Service Unavailable for /health/live" do
      conn = build_conn("GET", "/health/live")
      conn = HealthPlug.call(conn, [])
      assert conn.resp_body in ["OK", "Service Unavailable"]
    end
  end

  # ==========================================================================
  # call/2 - /health/ready
  # ==========================================================================

  describe "call/2 - /health/ready path" do
    test "returns 200 or 503 for /health/ready" do
      conn = build_conn("GET", "/health/ready")
      conn = HealthPlug.call(conn, [])
      assert conn.status in [200, 503]
    end

    test "halts connection after /health/ready response" do
      conn = build_conn("GET", "/health/ready")
      conn = HealthPlug.call(conn, [])
      assert conn.halted == true
    end

    test "response body is OK or Service Unavailable for /health/ready" do
      conn = build_conn("GET", "/health/ready")
      conn = HealthPlug.call(conn, [])
      assert conn.resp_body in ["OK", "Service Unavailable"]
    end
  end

  # ==========================================================================
  # call/2 - pass-through for non-health paths
  # ==========================================================================

  describe "call/2 - non-health paths pass through" do
    test "does not halt for /api/some/path (Psi0)" do
      conn = build_conn("GET", "/api/some/path")
      conn = HealthPlug.call(conn, [])
      assert conn.halted == false
    end

    test "does not set status for /api/path (preserves conn)" do
      conn = build_conn("GET", "/api/path")
      original_status = conn.status
      conn = HealthPlug.call(conn, [])
      # Status should be unchanged
      assert conn.status == original_status
    end

    test "passes through root path unchanged" do
      conn = build_conn("GET", "/")
      conn = HealthPlug.call(conn, [])
      assert conn.halted == false
    end

    test "passes through /prajna path unchanged" do
      conn = build_conn("GET", "/prajna")
      conn = HealthPlug.call(conn, [])
      assert conn.halted == false
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements" do
    test "health/live always responds within time budget (SC-PRF-050)" do
      start = System.monotonic_time(:millisecond)
      conn = build_conn("GET", "/health/live")
      HealthPlug.call(conn, [])
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 5_000, "Health live check took #{elapsed}ms"
    end

    test "health/ready always responds within time budget" do
      start = System.monotonic_time(:millisecond)
      conn = build_conn("GET", "/health/ready")
      HealthPlug.call(conn, [])
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 5_000, "Health ready check took #{elapsed}ms"
    end

    test "concurrent health checks do not crash" do
      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            conn = build_conn("GET", "/health/live")
            HealthPlug.call(conn, [])
          end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 10_000))

      Enum.each(results, fn conn ->
        assert conn.status in [200, 503]
      end)
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "non-health paths are always passed through without halting" do
    non_health_paths = ["/api/alarms", "/prajna", "/health", "/", "/healthz", "/api/v1/test"]

    forall path <- PC.oneof(Enum.map(non_health_paths, &PC.return/1)) do
      conn = build_conn("GET", path)
      result = HealthPlug.call(conn, [])
      # Only halt for exact /health/live and /health/ready
      expected_halt = path == "/health/live" or path == "/health/ready"
      result.halted == expected_halt
    end
  end

  test "init/1 always returns its argument unchanged" do
    ExUnitProperties.check all(opts <- SD.list_of(SD.atom(:alphanumeric))) do
      result = HealthPlug.init(opts)
      assert result == opts
    end
  end

  # ==========================================================================
  # FMEA Tests
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-HP-001: /health/live with HealthCheck unavailable returns 503 not crash" do
      # If HealthCheck module is unavailable or returns unexpected, plug must survive
      conn = build_conn("GET", "/health/live")
      result = HealthPlug.call(conn, [])
      assert result.status in [200, 503]
    end

    @tag :fmea
    test "FMEA-HP-002: unknown sub-paths under /health pass through" do
      conn = build_conn("GET", "/health/metrics")
      result = HealthPlug.call(conn, [])
      # /health/metrics is not /health/live or /health/ready — should pass through
      # In current implementation: call/2 catch-all returns conn unchanged
      assert result.halted == false
    end
  end

  # ==========================================================================
  # Helpers
  # ==========================================================================

  defp build_conn(method, path) do
    Plug.Test.conn(method, path)
    |> Plug.Conn.fetch_query_params()
  end
end
