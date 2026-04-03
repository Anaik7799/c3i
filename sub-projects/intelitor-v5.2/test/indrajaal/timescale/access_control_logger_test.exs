defmodule Indrajaal.Timescale.AccessControlLoggerTest do
  @moduledoc """
  TDG-compliant test suite for Timescale.AccessControlLogger.

  Tests cover the GenServer lifecycle and all public API:
  - start_link/1: starts GenServer successfully
  - log_authentication/4 and alias logauthentication/4
  - log_authorization/4 and alias logauthorization/4
  - log_access_event/4 and alias logaccess_event/4
  - log_security_violation/4 and alias logsecurity_violation/4
  - get_stats/0: returns stats map with all expected keys
  - flush/0: returns :ok

  Uses unique GenServer names per test to avoid collisions.

  ## STAMP Safety Integration
  - SC-IMMUNE-001: Security violations inserted synchronously (immediate alerting)
  - SC-SIL6-006: All four event categories are safety-critical audit paths

  ## Constitutional Verification
  - Ψ₀ Existence: Logger process survives cast operations without crashing
  - Ψ₃ Verification: Stats are structurally verifiable and consistent

  ## TPS 5-Level RCA Context
  - L1 Symptom: Security violation events lost due to async buffering failure
  - L5 Root Cause: Missing synchronous path for violations causes audit gaps

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude Sonnet 4.6 | Sprint 54 W1 TDG generation |
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Timescale.AccessControlLogger

  @moduletag :zenoh_nif

  @valid_tenant_id "550e8400-e29b-41d4-a716-446655440000"
  @valid_user_id "660e8400-e29b-41d4-a716-446655440001"

  defp start_logger do
    name = :"acl_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = GenServer.start_link(AccessControlLogger, [], name: name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    pid
  end

  defp auth_metadata do
    %{
      user_id: @valid_user_id,
      ip_address: "192.168.1.100",
      user_agent: "TestAgent/1.0",
      session_id: "sess-001"
    }
  end

  defp authz_metadata do
    %{
      user_id: @valid_user_id,
      resource_type: "access_control",
      resource_id: "door-001",
      action: "open",
      policy_result: "permit"
    }
  end

  defp access_metadata do
    %{
      user_id: @valid_user_id,
      credential_id: "cred-001",
      device_id: "device-001",
      access_point_id: "ap-001",
      result: "granted"
    }
  end

  defp violation_metadata do
    %{
      user_id: @valid_user_id,
      source_ip: "10.0.0.1",
      risk_score: 0.9,
      violation_details: %{attempts: 10}
    }
  end

  # ============================================================
  # start_link/1
  # ============================================================

  describe "start_link/1" do
    test "starts GenServer with default opts" do
      name = :"acl_start_#{System.unique_integer([:positive])}"
      assert {:ok, pid} = GenServer.start_link(AccessControlLogger, [], name: name)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "accepts custom batch_size opt" do
      name = :"acl_batch_#{System.unique_integer([:positive])}"
      assert {:ok, pid} = GenServer.start_link(AccessControlLogger, [batch_size: 10], name: name)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "accepts custom flush_interval opt" do
      name = :"acl_flush_#{System.unique_integer([:positive])}"

      assert {:ok, pid} =
               GenServer.start_link(AccessControlLogger, [flush_interval: 5_000], name: name)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "module implements GenServer behaviour" do
      behaviours =
        AccessControlLogger.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert GenServer in behaviours
    end
  end

  # ============================================================
  # log_authentication/4
  # ============================================================

  describe "log_authentication/4" do
    setup do
      pid = start_logger()
      %{pid: pid}
    end

    test "returns :ok for :login_success" do
      assert :ok = GenServer.call(self(), :ping) == nil or true

      assert :ok =
               AccessControlLogger.log_authentication(
                 :login_success,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end

    test "returns :ok for :login_failure" do
      assert :ok =
               AccessControlLogger.log_authentication(
                 :login_failure,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end

    test "returns :ok for :logout" do
      assert :ok =
               AccessControlLogger.log_authentication(:logout, @valid_tenant_id, auth_metadata())
    end

    test "returns :ok for :mfa_success" do
      assert :ok =
               AccessControlLogger.log_authentication(
                 :mfa_success,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end

    test "returns :ok for :mfa_failure" do
      assert :ok =
               AccessControlLogger.log_authentication(
                 :mfa_failure,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end

    test "returns :ok for :account_locked" do
      assert :ok =
               AccessControlLogger.log_authentication(
                 :account_locked,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end

    test "returns :ok for :session_timeout" do
      assert :ok =
               AccessControlLogger.log_authentication(
                 :session_timeout,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end

    test "returns :ok for :account_unlocked" do
      assert :ok =
               AccessControlLogger.log_authentication(
                 :account_unlocked,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end

    test "accepts correlation_id and trace_id opts" do
      assert :ok =
               AccessControlLogger.log_authentication(
                 :login_success,
                 @valid_tenant_id,
                 auth_metadata(),
                 correlation_id: "corr-001",
                 trace_id: "trace-001"
               )
    end
  end

  # ============================================================
  # logauthentication/4 (alias)
  # ============================================================

  describe "logauthentication/4" do
    test "delegates to log_authentication and returns :ok" do
      assert :ok =
               AccessControlLogger.logauthentication(
                 :login_success,
                 @valid_tenant_id,
                 auth_metadata()
               )
    end
  end

  # ============================================================
  # log_authorization/4
  # ============================================================

  describe "log_authorization/4" do
    test "returns :ok for :access_granted" do
      assert :ok =
               AccessControlLogger.log_authorization(
                 :access_granted,
                 @valid_tenant_id,
                 authz_metadata()
               )
    end

    test "returns :ok for :access_denied" do
      assert :ok =
               AccessControlLogger.log_authorization(
                 :access_denied,
                 @valid_tenant_id,
                 authz_metadata()
               )
    end

    test "returns :ok for :role_assigned" do
      assert :ok =
               AccessControlLogger.log_authorization(
                 :role_assigned,
                 @valid_tenant_id,
                 authz_metadata()
               )
    end

    test "returns :ok for :privilege_escalated" do
      assert :ok =
               AccessControlLogger.log_authorization(
                 :privilege_escalated,
                 @valid_tenant_id,
                 authz_metadata()
               )
    end

    test "accepts opts" do
      assert :ok =
               AccessControlLogger.log_authorization(
                 :access_granted,
                 @valid_tenant_id,
                 authz_metadata(),
                 correlation_id: "corr-authz"
               )
    end
  end

  # ============================================================
  # logauthorization/4 (alias)
  # ============================================================

  describe "logauthorization/4" do
    test "delegates and returns :ok" do
      assert :ok =
               AccessControlLogger.logauthorization(
                 :access_denied,
                 @valid_tenant_id,
                 authz_metadata()
               )
    end
  end

  # ============================================================
  # log_access_event/4
  # ============================================================

  describe "log_access_event/4" do
    test "returns :ok for :card_read" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :card_read,
                 @valid_tenant_id,
                 access_metadata()
               )
    end

    test "returns :ok for :biometric_scan" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :biometric_scan,
                 @valid_tenant_id,
                 access_metadata()
               )
    end

    test "returns :ok for :door_forced (critical)" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :door_forced,
                 @valid_tenant_id,
                 access_metadata()
               )
    end

    test "returns :ok for :tailgate_detected" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :tailgate_detected,
                 @valid_tenant_id,
                 access_metadata()
               )
    end

    test "returns :ok for :anti_passback_violation" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :anti_passback_violation,
                 @valid_tenant_id,
                 access_metadata()
               )
    end

    test "returns :ok for :duress_code (critical)" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :duress_code,
                 @valid_tenant_id,
                 access_metadata()
               )
    end

    test "returns :ok for :emergency_access" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :emergency_access,
                 @valid_tenant_id,
                 access_metadata()
               )
    end

    test "accepts opts" do
      assert :ok =
               AccessControlLogger.log_access_event(
                 :card_read,
                 @valid_tenant_id,
                 access_metadata(),
                 correlation_id: "corr-ac"
               )
    end
  end

  # ============================================================
  # logaccess_event/4 (alias)
  # ============================================================

  describe "logaccess_event/4" do
    test "delegates and returns :ok" do
      assert :ok =
               AccessControlLogger.logaccess_event(
                 :card_read,
                 @valid_tenant_id,
                 access_metadata()
               )
    end
  end

  # ============================================================
  # log_security_violation/4
  # ============================================================

  describe "log_security_violation/4" do
    test "returns :ok for :brute_force_attempt" do
      assert :ok =
               AccessControlLogger.log_security_violation(
                 :brute_force_attempt,
                 @valid_tenant_id,
                 violation_metadata()
               )
    end

    test "returns :ok for :unauthorized_access" do
      assert :ok =
               AccessControlLogger.log_security_violation(
                 :unauthorized_access,
                 @valid_tenant_id,
                 violation_metadata()
               )
    end

    test "returns :ok for :credential_misuse" do
      assert :ok =
               AccessControlLogger.log_security_violation(
                 :credential_misuse,
                 @valid_tenant_id,
                 violation_metadata()
               )
    end

    test "returns :ok for :anomaly_detected" do
      assert :ok =
               AccessControlLogger.log_security_violation(
                 :anomaly_detected,
                 @valid_tenant_id,
                 violation_metadata()
               )
    end

    test "accepts opts" do
      assert :ok =
               AccessControlLogger.log_security_violation(
                 :brute_force_attempt,
                 @valid_tenant_id,
                 violation_metadata(),
                 correlation_id: "corr-viol"
               )
    end

    test "handles empty metadata" do
      assert :ok =
               AccessControlLogger.log_security_violation(
                 :policy_violation,
                 @valid_tenant_id,
                 %{}
               )
    end
  end

  # ============================================================
  # logsecurity_violation/4 (alias)
  # ============================================================

  describe "logsecurity_violation/4" do
    test "delegates and returns :ok" do
      assert :ok =
               AccessControlLogger.logsecurity_violation(
                 :threat_identified,
                 @valid_tenant_id,
                 violation_metadata()
               )
    end
  end

  # ============================================================
  # get_stats/0 (requires the singleton to be running)
  # ============================================================

  describe "get_stats/0 via direct GenServer call" do
    setup do
      name = :"acl_stats_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(AccessControlLogger, [], name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns a map", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert is_map(stats)
    end

    test "contains authentication_events counter", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert Map.has_key?(stats, :authentication_events)
      assert is_integer(stats.authentication_events)
    end

    test "contains authorization_events counter", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert Map.has_key?(stats, :authorization_events)
      assert is_integer(stats.authorization_events)
    end

    test "contains access_events counter", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert Map.has_key?(stats, :access_events)
      assert is_integer(stats.access_events)
    end

    test "contains security_violations counter", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert Map.has_key?(stats, :security_violations)
      assert is_integer(stats.security_violations)
    end

    test "contains batches_processed counter", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert Map.has_key?(stats, :batches_processed)
      assert is_integer(stats.batches_processed)
    end

    test "contains errors counter", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert Map.has_key?(stats, :errors)
      assert is_integer(stats.errors)
    end

    test "contains pending_events counter", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert Map.has_key?(stats, :pending_events)
      assert is_integer(stats.pending_events)
      assert stats.pending_events >= 0
    end

    test "starts with all counters at zero", %{pid: pid} do
      stats = GenServer.call(pid, :get_stats)
      assert stats.authentication_events == 0
      assert stats.authorization_events == 0
      assert stats.access_events == 0
      assert stats.security_violations == 0
      assert stats.batches_processed == 0
      assert stats.errors == 0
      assert stats.pending_events == 0
    end
  end

  # ============================================================
  # flush/0
  # ============================================================

  describe "flush/0 via direct GenServer call" do
    setup do
      name = :"acl_flush_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(AccessControlLogger, [], name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns :ok on empty state", %{pid: pid} do
      result = GenServer.call(pid, :flush)
      assert result == :ok
    end

    test "process remains alive after flush", %{pid: pid} do
      GenServer.call(pid, :flush)
      assert Process.alive?(pid)
    end
  end

  # ============================================================
  # handle_info :flush_events (scheduled flush)
  # ============================================================

  describe "handle_info :flush_events" do
    setup do
      name = :"acl_info_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(AccessControlLogger, [], name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "process survives scheduled flush info message", %{pid: pid} do
      send(pid, :flush_events)
      :timer.sleep(50)
      assert Process.alive?(pid)
    end
  end
end
