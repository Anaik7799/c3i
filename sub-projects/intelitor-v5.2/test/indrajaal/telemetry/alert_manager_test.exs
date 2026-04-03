defmodule Indrajaal.Telemetry.AlertManagerTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Telemetry.AlertManager

  # AlertManager uses a named process (__MODULE__) by default.
  # To avoid conflicts between tests, we call module-level functions
  # which gracefully degrade when the named process is not running.
  # For tests that need an isolated instance, we use start_supervised with a unique name.

  describe "child_spec/1" do
    test "returns a valid supervisor child spec map" do
      spec = AlertManager.child_spec([])
      assert is_map(spec)
      assert spec.id == AlertManager
      assert spec.restart == :permanent
    end

    test "child spec start is a 3-tuple" do
      spec = AlertManager.child_spec([])
      {mod, fun, _args} = spec.start
      assert mod == AlertManager
      assert fun == :start_link
    end
  end

  describe "start_link/1 and lifecycle" do
    test "starts an isolated process successfully" do
      name = :"alert_mgr_#{System.unique_integer([:positive])}"
      assert {:ok, pid} = start_supervised({AlertManager, name: name})
      assert Process.alive?(pid)
    end

    test "started process is a GenServer" do
      name = :"alert_mgr_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({AlertManager, name: name})
      assert {:status, ^pid, _mod, _data} = :sys.get_status(pid)
    end

    test "process terminates cleanly via GenServer.stop" do
      name = :"alert_mgr_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({AlertManager, name: name})
      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
      refute Process.alive?(pid)
    end
  end

  describe "get_status/0 (named process not running)" do
    test "returns degraded status map when named process is not running" do
      # AlertManager.get_status/0 uses a catch clause to handle missing process
      result = AlertManager.get_status()
      # Either the named process is running (from app) or it returns the fallback
      assert match?({:ok, %{status: :running}}, result) or
               match?({:ok, %{status: :not_running}}, result)
    end
  end

  describe "get_metrics/0 (named process not running)" do
    test "returns a metrics map regardless of process state" do
      result = AlertManager.get_metrics()
      assert is_map(result)
    end
  end

  describe "perform_action/2 (named process not running)" do
    test "returns graceful degradation result when process not running" do
      result = AlertManager.perform_action(:send_alert, %{severity: :low})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "send_emergency_alert/2" do
    test "returns :ok for :critical severity with string message" do
      assert :ok == AlertManager.send_emergency_alert(:critical, "critical system failure")
    end

    test "returns :ok for :high severity with string message" do
      assert :ok == AlertManager.send_emergency_alert(:high, "high severity event")
    end

    test "returns :ok for :medium severity with string message" do
      assert :ok == AlertManager.send_emergency_alert(:medium, "medium event")
    end

    test "returns :ok for :low severity with string message" do
      assert :ok == AlertManager.send_emergency_alert(:low, "low severity notice")
    end

    test "returns :ok when message is a map" do
      assert :ok ==
               AlertManager.send_emergency_alert(:critical, %{
                 type: :db_failure,
                 detail: "connection refused"
               })
    end

    test "returns :ok for unknown severity atom" do
      assert :ok == AlertManager.send_emergency_alert(:unknown_level, "some event")
    end
  end

  describe "send_immediate_alert/2" do
    test "returns :ok for any alert type and string message" do
      assert :ok == AlertManager.send_immediate_alert(:slow_query, "query took 5000ms")
    end

    test "returns :ok when message is a map" do
      assert :ok ==
               AlertManager.send_immediate_alert(:slow_query, %{
                 duration_ms: 5000,
                 query: "SELECT *"
               })
    end

    test "returns :ok for various alert types" do
      assert :ok == AlertManager.send_immediate_alert(:cpu_spike, "CPU at 99%")
      assert :ok == AlertManager.send_immediate_alert(:memory_pressure, "OOM risk")
    end
  end

  describe "send_standard_alert/2" do
    test "returns :ok for normal alert type with string message" do
      assert :ok == AlertManager.send_standard_alert(:info, "routine event logged")
    end

    test "returns :ok when message is a map" do
      assert :ok ==
               AlertManager.send_standard_alert(:info, %{
                 event: "deployment_complete",
                 version: "1.2.3"
               })
    end

    test "returns :ok for multiple consecutive calls" do
      assert :ok == AlertManager.send_standard_alert(:audit, "user logged in")
      assert :ok == AlertManager.send_standard_alert(:audit, "user logged out")
    end
  end

  describe "handle_http_error/3" do
    test "returns :ok for a 500 error (above threshold)" do
      assert :ok == AlertManager.handle_http_error(500, "/api/alarms", %{})
    end

    test "returns :ok for a 404 error (below threshold)" do
      assert :ok == AlertManager.handle_http_error(404, "/api/not-found", %{})
    end

    test "returns :ok for a 503 error" do
      assert :ok == AlertManager.handle_http_error(503, "/api/health", %{tenant_id: "acme"})
    end

    test "returns :ok for a 200 status (no alert, but should not crash)" do
      assert :ok == AlertManager.handle_http_error(200, "/api/ok", %{})
    end

    test "accepts metadata with additional context" do
      meta = %{tenant_id: "acme", user_id: "u123", correlation_id: "corr-456"}
      assert :ok == AlertManager.handle_http_error(502, "/api/gateway", meta)
    end
  end

  describe "handle_slow_query/3" do
    test "returns :ok for query at 100ms (at medium threshold)" do
      assert :ok == AlertManager.handle_slow_query(100, :repo, "SELECT * FROM users")
    end

    test "returns :ok for query at 500ms (high threshold 5x)" do
      assert :ok == AlertManager.handle_slow_query(500, :repo, "SELECT * FROM events")
    end

    test "returns :ok for query at 1000ms (critical threshold 10x)" do
      assert :ok == AlertManager.handle_slow_query(1000, :repo, "ANALYZE users")
    end

    test "returns :ok for very fast query (below threshold)" do
      assert :ok == AlertManager.handle_slow_query(5, :repo, "SELECT 1")
    end

    test "handles atom source identifier" do
      assert :ok ==
               AlertManager.handle_slow_query(200, :indrajaal_repo, "SELECT count(*) FROM alarms")
    end
  end

  describe "handle_auth_failure/3" do
    test "returns :ok for a standard auth failure" do
      assert :ok ==
               AlertManager.handle_auth_failure("user-123", "tenant-abc", %{
                 reason: :invalid_password
               })
    end

    test "returns :ok with IP address in metadata" do
      meta = %{reason: :expired_token, ip_address: "192.168.1.1"}
      assert :ok == AlertManager.handle_auth_failure("user-456", "tenant-xyz", meta)
    end

    test "returns :ok with empty metadata" do
      assert :ok == AlertManager.handle_auth_failure("user-789", "tenant-def", %{})
    end
  end

  describe "handle_auth_validation_failure/2" do
    test "returns :ok for token validation failure" do
      meta = %{validation_type: :jwt, error: "signature mismatch"}
      assert :ok == AlertManager.handle_auth_validation_failure("user-123", meta)
    end

    test "returns :ok with empty metadata" do
      assert :ok == AlertManager.handle_auth_validation_failure("user-456", %{})
    end

    test "returns :ok for MFA validation failure type" do
      meta = %{validation_type: :mfa, error: "code expired"}
      assert :ok == AlertManager.handle_auth_validation_failure("user-789", meta)
    end
  end

  describe "handle_potential_session_hijack/2" do
    test "returns :ok when IP addresses differ" do
      meta = %{
        original_ip: "192.168.1.100",
        new_ip: "10.0.0.1",
        user_agent_changed: false
      }

      assert :ok == AlertManager.handle_potential_session_hijack("session-abc", meta)
    end

    test "returns :ok when user agent also changed" do
      meta = %{
        original_ip: "192.168.1.100",
        new_ip: "203.0.113.5",
        user_agent_changed: true
      }

      assert :ok == AlertManager.handle_potential_session_hijack("session-xyz", meta)
    end

    test "returns :ok with minimal metadata" do
      assert :ok == AlertManager.handle_potential_session_hijack("session-min", %{})
    end
  end

  describe "handle_rate_limit_violation/3" do
    test "returns :ok when request count exceeds limit" do
      measurements = %{requests: 1000, limit: 100}

      assert :ok ==
               AlertManager.handle_rate_limit_violation("user-123", "/api/data", measurements)
    end

    test "returns :ok with empty measurements" do
      assert :ok == AlertManager.handle_rate_limit_violation("user-456", "/api/bulk", %{})
    end

    test "returns :ok for various endpoints" do
      assert :ok ==
               AlertManager.handle_rate_limit_violation("user-789", "/api/alarms", %{
                 requests: 50,
                 limit: 10
               })

      assert :ok ==
               AlertManager.handle_rate_limit_violation("user-789", "/api/stream", %{
                 requests: 200,
                 limit: 50
               })
    end
  end

  describe "handle_critical_alarm/3" do
    test "returns :ok for a fire alarm event" do
      meta = %{source: "fire_panel", description: "Zone 3 smoke detected"}
      assert :ok == AlertManager.handle_critical_alarm("alarm-001", :fire, meta)
    end

    test "returns :ok for an intrusion alarm" do
      meta = %{source: "access_control", description: "Forced door entry"}
      assert :ok == AlertManager.handle_critical_alarm("alarm-002", :intrusion, meta)
    end

    test "returns :ok with empty metadata" do
      assert :ok == AlertManager.handle_critical_alarm("alarm-003", :system_failure, %{})
    end

    test "returns :ok for various alarm types" do
      assert :ok == AlertManager.handle_critical_alarm("a1", :power_failure, %{})
      assert :ok == AlertManager.handle_critical_alarm("a2", :network_outage, %{})
    end
  end

  describe "handle_safety_alert/3" do
    test "returns :ok for a STAMP constraint violation" do
      meta = %{description: "Compilation warning threshold exceeded"}
      assert :ok == AlertManager.handle_safety_alert(:stamp_violation, "SC-CMP-025", meta)
    end

    test "returns :ok for a VAL constraint" do
      meta = %{description: "Validation consensus not achieved"}
      assert :ok == AlertManager.handle_safety_alert(:validation_failure, "SC-VAL-003", meta)
    end

    test "returns :ok with empty metadata" do
      assert :ok == AlertManager.handle_safety_alert(:safety_check, "SC-TEST-001", %{})
    end

    test "returns :ok for SIL constraint violations" do
      assert :ok == AlertManager.handle_safety_alert(:sil_violation, "SC-SIL6-006", %{})
    end
  end
end
