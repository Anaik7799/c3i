defmodule Indrajaal.Observability.AuditLoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.AuditLogger.

  ## STAMP Safety Integration
  - SC-OBS-001: Audit events must be logged for all key operations

  ## TPS 5-Level RCA Context
  - L1 Symptom: Missing audit trail for operations
  - L5 Root Cause: Prevents accountability and forensic analysis
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.AuditLogger

  describe "log_audit_event/4" do
    test "returns :ok for a basic audit event" do
      result = AuditLogger.log_audit_event("user_action", "create_user", %{user_id: 123})
      assert result == :ok
    end

    test "returns :ok with metadata" do
      result =
        AuditLogger.log_audit_event("user_action", "update_user", %{user_id: 456},
          tenant_id: 1,
          actor: "admin"
        )

      assert result == :ok
    end

    test "accepts map details" do
      result = AuditLogger.log_audit_event("system", "startup", %{version: "21.3.0"})
      assert result == :ok
    end

    test "accepts empty metadata list" do
      result = AuditLogger.log_audit_event("billing", "charge", %{amount: 100}, [])
      assert result == :ok
    end

    test "works without metadata (defaults to empty list)" do
      result = AuditLogger.log_audit_event("security", "login", %{ip: "127.0.0.1"})
      assert result == :ok
    end

    test "handles empty details map" do
      result = AuditLogger.log_audit_event("test", "noop", %{})
      assert result == :ok
    end

    test "handles delete operation subtype" do
      result = AuditLogger.log_audit_event("user_action", "delete", %{resource_id: "abc"})
      assert result == :ok
    end

    test "handles complex nested details" do
      details = %{
        resource: %{type: :alarm, id: "xyz"},
        changes: %{status: "acknowledged"},
        actor: "admin"
      }

      result = AuditLogger.log_audit_event("alarms", "acknowledge", details)
      assert result == :ok
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.AuditLogger)
    end

    test "log_audit_event/3 exported" do
      assert function_exported?(Indrajaal.Observability.AuditLogger, :log_audit_event, 3)
    end

    test "log_audit_event/4 exported" do
      assert function_exported?(Indrajaal.Observability.AuditLogger, :log_audit_event, 4)
    end
  end
end
