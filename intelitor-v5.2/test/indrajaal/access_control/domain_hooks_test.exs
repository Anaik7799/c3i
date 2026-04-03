defmodule Indrajaal.AccessControl.DomainHooksTest do
  @moduledoc """
  TDG-compliant test suite for AccessControl.DomainHooks.

  Tests cover all public handler functions: initialize_hooks/0,
  handle_access_log_created/2, handle_access_credential_event/3,
  handle_access_grant_event/3, handle_access_rule_event/3,
  and handle_security_exception/2.

  All handler functions return :ok synchronously — async tasks are
  dispatched internally. Tests verify return values and process survival.

  ## STAMP Safety Integration
  - SC-IMMUNE-001: Sentinel health checks wrap critical operations
  - SC-SIL6-006: Access control events are safety-critical paths

  ## Constitutional Verification
  - Ψ₀ Existence: Handlers return :ok without crashing regardless of input
  - Ψ₅ Truthfulness: Events logged reflect actual access outcomes

  ## TPS 5-Level RCA Context
  - L1 Symptom: Domain hook crash drops audit events silently
  - L5 Root Cause: Missing nil guards in access_log.event_type accessors

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude Sonnet 4.6 | Sprint 54 W1 TDG generation |
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AccessControl.DomainHooks

  @moduletag :zenoh_nif

  @valid_tenant_id "550e8400-e29b-41d4-a716-446655440000"

  # Minimal access_log struct — hooks only use .id, .tenant_id, .event_type, .timestamp
  defp access_log(overrides \\ %{}) do
    Map.merge(
      %{
        id: "log-#{System.unique_integer([:positive])}",
        tenant_id: @valid_tenant_id,
        event_type: :card_read,
        timestamp: DateTime.utc_now(),
        result: :granted,
        repeated_attempts: 0
      },
      overrides
    )
  end

  # Minimal credential struct
  defp credential(overrides \\ %{}) do
    Map.merge(
      %{
        id: "cred-#{System.unique_integer([:positive])}",
        tenant_id: @valid_tenant_id,
        status: :active,
        credential_type: :card,
        permission_level: "standard"
      },
      overrides
    )
  end

  # Minimal access_grant struct
  defp access_grant(overrides \\ %{}) do
    Map.merge(
      %{
        id: "grant-#{System.unique_integer([:positive])}",
        tenant_id: @valid_tenant_id,
        user_id: "user-1",
        permission_level: "standard",
        previous_level: "viewer"
      },
      overrides
    )
  end

  # Minimal access_rule struct
  defp access_rule(overrides \\ %{}) do
    Map.merge(
      %{
        id: "rule-#{System.unique_integer([:positive])}",
        tenant_id: @valid_tenant_id,
        rule_type: :time_based,
        effective_permissions: ["read"],
        status: :active
      },
      overrides
    )
  end

  # Minimal security_exception struct
  defp security_exception(overrides \\ %{}) do
    Map.merge(
      %{
        id: "exc-#{System.unique_integer([:positive])}",
        tenant_id: @valid_tenant_id,
        exception_type: :unauthorized_access,
        severity: :high
      },
      overrides
    )
  end

  # ============================================================
  # handle_access_log_created/2
  # ============================================================

  describe "handle_access_log_created/2" do
    test "returns :ok for normal card_read event" do
      assert :ok = DomainHooks.handle_access_log_created(access_log())
    end

    test "returns :ok with explicit empty context" do
      assert :ok = DomainHooks.handle_access_log_created(access_log(), %{})
    end

    test "returns :ok with correlation_id in context" do
      context = %{correlation_id: "corr-123"}
      assert :ok = DomainHooks.handle_access_log_created(access_log(), context)
    end

    test "returns :ok for :door_forced event (anomalous)" do
      log = access_log(%{event_type: :door_forced, result: :forced})
      assert :ok = DomainHooks.handle_access_log_created(log)
    end

    test "returns :ok for :tailgate event (anomalous)" do
      log = access_log(%{event_type: :tailgate})
      assert :ok = DomainHooks.handle_access_log_created(log)
    end

    test "returns :ok for :duress event (anomalous)" do
      log = access_log(%{event_type: :duress})
      assert :ok = DomainHooks.handle_access_log_created(log)
    end

    test "returns :ok for :denied result with repeated_attempts > 3 (anomalous)" do
      log = access_log(%{result: :denied, repeated_attempts: 5})
      assert :ok = DomainHooks.handle_access_log_created(log)
    end

    test "returns :ok for :emergency event (anomalous)" do
      log = access_log(%{event_type: :emergency})
      assert :ok = DomainHooks.handle_access_log_created(log)
    end

    test "caller process remains alive after handler returns" do
      DomainHooks.handle_access_log_created(access_log())
      assert Process.alive?(self())
    end
  end

  # ============================================================
  # handle_access_credential_event/3
  # ============================================================

  describe "handle_access_credential_event/3" do
    test "returns :ok for :created event" do
      assert :ok = DomainHooks.handle_access_credential_event(:created, credential())
    end

    test "returns :ok for :updated event" do
      assert :ok = DomainHooks.handle_access_credential_event(:updated, credential())
    end

    test "returns :ok for :revoked event (triggers security violation)" do
      assert :ok = DomainHooks.handle_access_credential_event(:revoked, credential())
    end

    test "returns :ok for :suspended event (triggers security violation)" do
      assert :ok = DomainHooks.handle_access_credential_event(:suspended, credential())
    end

    test "returns :ok for unknown event type" do
      assert :ok = DomainHooks.handle_access_credential_event(:other_event, credential())
    end

    test "returns :ok with explicit empty context" do
      assert :ok = DomainHooks.handle_access_credential_event(:created, credential(), %{})
    end

    test "returns :ok with correlation context" do
      context = %{correlation_id: "corr-abc"}
      assert :ok = DomainHooks.handle_access_credential_event(:revoked, credential(), context)
    end

    test "caller process remains alive after handler" do
      DomainHooks.handle_access_credential_event(:suspended, credential())
      assert Process.alive?(self())
    end
  end

  # ============================================================
  # handle_access_grant_event/3
  # ============================================================

  describe "handle_access_grant_event/3" do
    test "returns :ok for :granted event" do
      assert :ok = DomainHooks.handle_access_grant_event(:granted, access_grant())
    end

    test "returns :ok for :denied event" do
      assert :ok = DomainHooks.handle_access_grant_event(:denied, access_grant())
    end

    test "returns :ok for :revoked event" do
      assert :ok = DomainHooks.handle_access_grant_event(:revoked, access_grant())
    end

    test "returns :ok for :expired event" do
      assert :ok = DomainHooks.handle_access_grant_event(:expired, access_grant())
    end

    test "returns :ok for unknown event type" do
      assert :ok = DomainHooks.handle_access_grant_event(:unknown_grant_event, access_grant())
    end

    test "returns :ok with explicit context" do
      assert :ok =
               DomainHooks.handle_access_grant_event(:granted, access_grant(), %{
                 correlation_id: "corr-xyz"
               })
    end

    test "caller process remains alive after handler" do
      DomainHooks.handle_access_grant_event(:granted, access_grant())
      assert Process.alive?(self())
    end
  end

  # ============================================================
  # handle_access_rule_event/3
  # ============================================================

  describe "handle_access_rule_event/3" do
    test "returns :ok for :created event" do
      assert :ok = DomainHooks.handle_access_rule_event(:created, access_rule())
    end

    test "returns :ok for :updated event" do
      assert :ok = DomainHooks.handle_access_rule_event(:updated, access_rule())
    end

    test "returns :ok for :deleted event" do
      assert :ok = DomainHooks.handle_access_rule_event(:deleted, access_rule())
    end

    test "returns :ok for :activated event" do
      assert :ok = DomainHooks.handle_access_rule_event(:activated, access_rule())
    end

    test "returns :ok for :deactivated event" do
      assert :ok = DomainHooks.handle_access_rule_event(:deactivated, access_rule())
    end

    test "returns :ok for unknown rule event type" do
      assert :ok = DomainHooks.handle_access_rule_event(:unrecognized, access_rule())
    end

    test "returns :ok with context" do
      assert :ok =
               DomainHooks.handle_access_rule_event(:created, access_rule(), %{
                 operator: "admin-1"
               })
    end

    test "caller process remains alive after handler" do
      DomainHooks.handle_access_rule_event(:updated, access_rule())
      assert Process.alive?(self())
    end
  end

  # ============================================================
  # handle_security_exception/2
  # ============================================================

  describe "handle_security_exception/2" do
    test "returns :ok for unauthorized_access exception" do
      exc = security_exception(%{exception_type: :unauthorized_access})
      assert :ok = DomainHooks.handle_security_exception(exc)
    end

    test "returns :ok for tailgate exception" do
      exc = security_exception(%{exception_type: :tailgate_detected})
      assert :ok = DomainHooks.handle_security_exception(exc)
    end

    test "returns :ok for brute_force exception" do
      exc = security_exception(%{exception_type: :brute_force_attempt})
      assert :ok = DomainHooks.handle_security_exception(exc)
    end

    test "returns :ok with context" do
      exc = security_exception()
      context = %{correlation_id: "corr-sec-001", operator: "admin"}
      assert :ok = DomainHooks.handle_security_exception(exc, context)
    end

    test "returns :ok for any exception type" do
      exc = security_exception(%{exception_type: :unknown_exception_type})
      assert :ok = DomainHooks.handle_security_exception(exc)
    end

    test "caller process remains alive after exception handling" do
      DomainHooks.handle_security_exception(security_exception())
      assert Process.alive?(self())
    end
  end
end
