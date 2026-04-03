defmodule Indrajaal.Observability.AccessControlManagerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.AccessControlManager

  setup do
    # Start the AccessControlManager GenServer
    {:ok, pid} = AccessControlManager.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = AccessControlManager.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = AccessControlManager.start_link([])
      assert Process.whereis(AccessControlManager) != nil
      GenServer.stop(AccessControlManager)
    end
  end

  describe "validate_data_access/5" do
    test "validates data access with analyst role and confidential data" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "confidential",
          %{user_role: "analyst", clearance_level: "confidential"}
        )

      assert is_map(access_info)
      assert Map.has_key?(access_info, :access_granted)
      assert Map.has_key?(access_info, :access_reason)
      assert Map.has_key?(access_info, :audit_logged)
      assert Map.has_key?(access_info, :security_validation)
    end

    test "denies access for guest role to confidential data" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_002",
          "tenant_a",
          "observability_data",
          "confidential",
          %{user_role: "guest", clearance_level: "public"}
        )

      assert access_info.access_granted == false
      assert access_info.access_reason =~ "clearance_insufficient"
    end

    test "validates security validation structure" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_003",
          "tenant_a",
          "observability_data",
          "internal",
          %{user_role: "operator", clearance_level: "internal"}
        )

      assert Map.has_key?(access_info.security_validation, :tenant_isolation)
      assert Map.has_key?(access_info.security_validation, :role_validation)
      assert Map.has_key?(access_info.security_validation, :clearance_validation)
      assert Map.has_key?(access_info.security_validation, :policy_validation)
    end

    test "includes validation details in response" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_004",
          "tenant_a",
          "observability_data",
          "public",
          %{user_role: "viewer", clearance_level: "public"}
        )

      assert Map.has_key?(access_info, :validation_details)
      assert Map.has_key?(access_info.validation_details, :role_check)
      assert Map.has_key?(access_info.validation_details, :clearance_check)
      assert Map.has_key?(access_info.validation_details, :tenant_check)
    end

    test "creates audit log when audit_access is true" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_005",
          "tenant_a",
          "observability_data",
          "internal",
          %{user_role: "analyst", clearance_level: "internal", audit_access: true}
        )

      assert access_info.audit_logged == true
    end

    test "skips audit log when audit_access is false" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_006",
          "tenant_a",
          "observability_data",
          "public",
          %{user_role: "viewer", clearance_level: "public", audit_access: false}
        )

      assert access_info.audit_logged == false
    end

    test "includes access metadata with timestamp" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_007",
          "tenant_a",
          "observability_data",
          "internal",
          %{user_role: "operator", clearance_level: "internal"}
        )

      assert Map.has_key?(access_info, :access_metadata)
      assert Map.has_key?(access_info.access_metadata, :timestamp)
      assert Map.has_key?(access_info.access_metadata, :validation_id)
      assert Map.has_key?(access_info.access_metadata, :tenant_id)
    end
  end

  describe "validate_role_permissions/5" do
    test "validates admin role permissions for write operation" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_001",
          "admin",
          "write",
          "system_configuration",
          %{tenant_id: "tenant_a"}
        )

      assert permission_info.permission_granted == true
      assert permission_info.role_level == 8
      assert permission_info.access_scope == :tenant
    end

    test "denies viewer role permissions for write operation" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_002",
          "viewer",
          "write",
          "system_configuration",
          %{tenant_id: "tenant_a"}
        )

      assert permission_info.permission_granted == false
    end

    test "validates super_admin has all permissions" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_003",
          "super_admin",
          "delete",
          "user_management",
          %{tenant_id: "tenant_a"}
        )

      assert permission_info.permission_granted == true
      assert permission_info.role_level == 10
      assert :read in permission_info.effective_permissions
      assert :write in permission_info.effective_permissions
      assert :delete in permission_info.effective_permissions
    end

    test "returns error for invalid role" do
      {:error, reason} =
        AccessControlManager.validate_role_permissions(
          "user_004",
          "invalid_role",
          "read",
          "observability_data",
          %{tenant_id: "tenant_a"}
        )

      assert reason == :invalid_role
    end

    test "includes clearance levels in permission info" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_005",
          "security_analyst",
          "read",
          "security_logs",
          %{tenant_id: "tenant_a"}
        )

      assert is_list(permission_info.clearance_levels)
      assert "confidential" in permission_info.clearance_levels
      assert "restricted" in permission_info.clearance_levels
    end

    test "includes audit level in permission info" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_006",
          "analyst",
          "read",
          "observability_data",
          %{tenant_id: "tenant_a"}
        )

      assert permission_info.audit_level == :standard
    end
  end

  describe "enforce_tenant_isolation/4" do
    test "enforces strict tenant isolation for same tenant access" do
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          "user_001",
          "tenant_a",
          "observability_data",
          %{target_tenant_id: "tenant_a", cross_tenant_check: false}
        )

      assert isolation_info.isolation_enforced == true
      assert isolation_info.tenant_boundary_valid == true
      assert isolation_info.cross_tenant_access_denied == false
    end

    test "denies cross-tenant access in strict isolation mode" do
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          "user_002",
          "tenant_a",
          "observability_data",
          %{target_tenant_id: "tenant_b", cross_tenant_check: true}
        )

      assert isolation_info.isolation_enforced == false
      assert isolation_info.tenant_boundary_valid == false
      assert isolation_info.cross_tenant_access_denied == true
    end

    test "allows cross-tenant access with admin override in moderate mode" do
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          "user_003",
          "tenant_a",
          "observability_data",
          %{
            target_tenant_id: "tenant_b",
            isolation_level: "moderate",
            admin_override: true
          }
        )

      assert isolation_info.isolation_enforced == true
      assert isolation_info.isolation_level == "moderate"
    end

    test "allows all access in relaxed isolation mode" do
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          "user_004",
          "tenant_a",
          "observability_data",
          %{target_tenant_id: "tenant_b", isolation_level: "relaxed"}
        )

      assert isolation_info.isolation_enforced == true
      assert isolation_info.isolation_level == "relaxed"
    end

    test "includes tenant details in response" do
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          "user_005",
          "tenant_a",
          "observability_data",
          %{target_tenant_id: "tenant_a"}
        )

      assert Map.has_key?(isolation_info, :tenant_details)
      assert isolation_info.tenant_details.user_tenant_id == "tenant_a"
      assert isolation_info.tenant_details.target_tenant_id == "tenant_a"
    end

    test "includes validation metadata with timestamp" do
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          "user_006",
          "tenant_a",
          "observability_data",
          %{}
        )

      assert Map.has_key?(isolation_info, :validation_metadata)
      assert Map.has_key?(isolation_info.validation_metadata, :timestamp)
      assert Map.has_key?(isolation_info.validation_metadata, :user_id)
    end
  end

  describe "create_audit_log/4" do
    test "creates audit log entry for ACCESS_GRANTED event" do
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "ACCESS_GRANTED",
          "user_001",
          "tenant_a",
          %{resource: "observability_data", operation: "read"}
        )

      assert is_map(audit_info)
      assert String.starts_with?(audit_info.audit_id, "AUDIT-")
      assert audit_info.event_type == "ACCESS_GRANTED"
      assert audit_info.user_id == "user_001"
      assert audit_info.tenant_id == "tenant_a"
    end

    test "includes retention date in audit log" do
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "ACCESS_DENIED",
          "user_002",
          "tenant_a",
          %{reason: "insufficient_clearance"}
        )

      assert Map.has_key?(audit_info, :logged_at)
      assert Map.has_key?(audit_info, :retention_until)

      # Retention should be 365 days from logged_at
      retention_days =
        DateTime.diff(audit_info.retention_until, audit_info.logged_at, :day)

      assert retention_days == 365
    end

    test "includes tamper-proof hash in audit log" do
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "PERMISSION_CHANGE",
          "user_003",
          "tenant_a",
          %{old_role: "viewer", new_role: "analyst"}
        )

      assert Map.has_key?(audit_info, :tamper_proof_hash)
      assert is_binary(audit_info.tamper_proof_hash)
      assert String.length(audit_info.tamper_proof_hash) == 64
    end

    test "includes compliance flags for GDPR data" do
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "ACCESS_GRANTED",
          "user_004",
          "tenant_a",
          %{data_sensitivity: "confidential"}
        )

      assert "gdpr" in audit_info.compliance_flags
    end

    test "includes compliance flags for SOX financial data" do
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "ACCESS_GRANTED",
          "user_005",
          "tenant_a",
          %{data_type: "financial_data"}
        )

      assert "sox" in audit_info.compliance_flags
    end

    test "includes compliance flags for HIPAA health data" do
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "ACCESS_GRANTED",
          "user_006",
          "tenant_a",
          %{data_type: "health_data"}
        )

      assert "hipaa" in audit_info.compliance_flags
    end

    test "includes audit metadata with system context" do
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "SECURITY_EVENT",
          "user_007",
          "tenant_a",
          %{event_details: "anomaly_detected"}
        )

      assert Map.has_key?(audit_info, :audit_metadata)
      assert Map.has_key?(audit_info.audit_metadata, :log_version)
      assert Map.has_key?(audit_info.audit_metadata, :system_context)
    end
  end

  describe "test_access_validation/1" do
    test "returns validation result with accuracy score" do
      {:ok, result} = AccessControlManager.test_access_validation(%{})

      assert is_map(result)
      assert Map.has_key?(result, :accuracy_score)
      assert result.accuracy_score >= 0.95
      assert result.accuracy_score <= 1.00
    end

    test "returns validation result with isolation score" do
      {:ok, result} = AccessControlManager.test_access_validation(%{})

      assert Map.has_key?(result, :isolation_score)
      assert result.isolation_score >= 0.99
      assert result.isolation_score <= 1.00
    end

    test "generates validation results based on tenant count" do
      {:ok, result} =
        AccessControlManager.test_access_validation(%{tenant_count: 5})

      assert is_list(result.validation_results)
      assert length(result.validation_results) >= 5
    end

    test "generates validation results based on role complexity" do
      {:ok, result} =
        AccessControlManager.test_access_validation(%{
          tenant_count: 2,
          role_complexity: :complex
        })

      # Complex = 2 tenants * 3 complexity = 6 results
      assert length(result.validation_results) == 6
    end

    test "includes test_passed flag" do
      {:ok, result} = AccessControlManager.test_access_validation(%{})

      assert result.test_passed == true
    end
  end

  describe "role hierarchy validation" do
    test "super_admin has highest level and all permissions" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_001",
          "super_admin",
          "delete",
          "system_configuration",
          %{}
        )

      assert permission_info.role_level == 10
      assert permission_info.permission_granted == true
    end

    test "guest has lowest level and limited permissions" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_002",
          "guest",
          "write",
          "observability_data",
          %{}
        )

      assert permission_info.role_level == 1
      assert permission_info.permission_granted == false
    end

    test "security_analyst has restricted access scope" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_003",
          "security_analyst",
          "read",
          "security_logs",
          %{}
        )

      assert permission_info.access_scope == :security_domain
      assert permission_info.permission_granted == true
    end
  end

  describe "data sensitivity and clearance mapping" do
    test "public data accessible with public clearance" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "public",
          %{user_role: "guest", clearance_level: "public"}
        )

      assert access_info.security_validation.clearance_validation == true
    end

    test "confidential data requires confidential clearance" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_002",
          "tenant_a",
          "observability_data",
          "confidential",
          %{user_role: "analyst", clearance_level: "confidential"}
        )

      assert access_info.security_validation.clearance_validation == true
    end

    test "top_secret data requires top_secret clearance" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_003",
          "tenant_a",
          "observability_data",
          "top_secret",
          %{user_role: "super_admin", clearance_level: "top_secret"}
        )

      assert access_info.security_validation.clearance_validation == true
    end
  end

  describe "access policy enforcement" do
    test "viewer can read observability_data" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_001",
          "viewer",
          "read",
          "observability_data",
          %{}
        )

      assert permission_info.permission_granted == true
    end

    test "viewer cannot write observability_data" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_002",
          "viewer",
          "write",
          "observability_data",
          %{}
        )

      assert permission_info.permission_granted == false
    end

    test "only super_admin can delete user_management" do
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          "user_003",
          "admin",
          "delete",
          "user_management",
          %{}
        )

      assert permission_info.permission_granted == false

      {:ok, super_admin_permission} =
        AccessControlManager.validate_role_permissions(
          "user_004",
          "super_admin",
          "delete",
          "user_management",
          %{}
        )

      assert super_admin_permission.permission_granted == true
    end
  end

  describe "concurrent access validation" do
    test "handles concurrent access validation requests" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            AccessControlManager.validate_data_access(
              "user_#{i}",
              "tenant_a",
              "observability_data",
              "internal",
              %{user_role: "analyst", clearance_level: "internal"}
            )
          end)
        end

      results = Task.await_many(tasks)

      assert length(results) == 10
      Enum.each(results, fn {:ok, access_info} -> assert is_map(access_info) end)
    end

    test "maintains validation accuracy under concurrent load" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            AccessControlManager.validate_role_permissions(
              "user_#{i}",
              "operator",
              "read",
              "observability_data",
              %{tenant_id: "tenant_a"}
            )
          end)
        end

      results = Task.await_many(tasks)

      assert length(results) == 20

      Enum.each(results, fn {:ok, permission_info} ->
        assert permission_info.permission_granted == true
        assert permission_info.role_level == 5
      end)
    end
  end

  describe "edge cases and error handling" do
    test "handles empty config map" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "public",
          %{}
        )

      # Should use defaults: viewer role, medium clearance
      assert is_map(access_info)
    end

    test "handles missing security context" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_002",
          "tenant_a",
          "observability_data",
          "internal",
          %{user_role: "viewer", clearance_level: "internal", security_context: nil}
        )

      assert is_map(access_info)
    end

    test "handles special characters in user_id" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user@#$%^&*()_001",
          "tenant_a",
          "observability_data",
          "public",
          %{user_role: "viewer", clearance_level: "public"}
        )

      assert access_info.access_metadata.validation_id > 0
    end

    test "handles audit log for very long event types" do
      long_event = String.duplicate("EVENT_", 100)

      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          long_event,
          "user_001",
          "tenant_a",
          %{data: "test"}
        )

      assert is_binary(audit_info.audit_id)
    end
  end

  describe "integration scenarios" do
    test "complete access control workflow" do
      user_id = "user_001"
      tenant_id = "tenant_a"

      # Step 1: Validate role permissions
      {:ok, permission_info} =
        AccessControlManager.validate_role_permissions(
          user_id,
          "analyst",
          "read",
          "observability_data",
          %{tenant_id: tenant_id}
        )

      assert permission_info.permission_granted == true

      # Step 2: Enforce tenant isolation
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          user_id,
          tenant_id,
          "observability_data",
          %{target_tenant_id: tenant_id}
        )

      assert isolation_info.isolation_enforced == true

      # Step 3: Validate data access
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          user_id,
          tenant_id,
          "observability_data",
          "confidential",
          %{user_role: "analyst", clearance_level: "confidential", audit_access: true}
        )

      assert access_info.access_granted == true
      assert access_info.audit_logged == true
    end

    test "cross-tenant access denial workflow" do
      # Attempt cross-tenant access
      {:ok, isolation_info} =
        AccessControlManager.enforce_tenant_isolation(
          "user_001",
          "tenant_a",
          "observability_data",
          %{target_tenant_id: "tenant_b", cross_tenant_check: true}
        )

      assert isolation_info.cross_tenant_access_denied == true

      # Verify access is denied
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_b",
          "observability_data",
          "internal",
          %{
            user_role: "analyst",
            clearance_level: "internal",
            security_context: %{session_tenant_id: "tenant_a"}
          }
        )

      assert access_info.access_granted == false
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: data integrity - access control decisions preserved" do
      config = %{user_role: "analyst", clearance_level: "confidential"}

      # Validate multiple times - should get consistent results
      {:ok, result1} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "confidential",
          config
        )

      {:ok, result2} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "confidential",
          config
        )

      assert result1.access_granted == result2.access_granted
      assert result1.access_reason == result2.access_reason
    end

    test "SC2: performance - access control maintains acceptable response times" do
      start_time = System.monotonic_time(:millisecond)

      {:ok, _access_info} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "internal",
          %{user_role: "analyst", clearance_level: "internal"}
        )

      end_time = System.monotonic_time(:millisecond)
      processing_time = end_time - start_time

      # Should complete in under 25ms target (using 100ms for test tolerance)
      assert processing_time < 100
    end

    test "SC3: security - access permissions properly validated and audited" do
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "restricted",
          %{
            user_role: "security_analyst",
            clearance_level: "restricted",
            audit_access: true
          }
        )

      # Verify all security validations performed
      assert access_info.security_validation.tenant_isolation == true
      assert access_info.security_validation.role_validation == true
      assert access_info.security_validation.clearance_validation == true
      assert access_info.security_validation.policy_validation == true

      # Verify audit logged
      assert access_info.audit_logged == true
    end

    test "SC4: availability - access control operational during high validation loads" do
      # Test system continues working under load
      for _i <- 1..50 do
        spawn(fn ->
          AccessControlManager.validate_data_access(
            "load_test_user",
            "tenant_a",
            "observability_data",
            "public",
            %{user_role: "viewer", clearance_level: "public"}
          )
        end)
      end

      Process.sleep(200)

      # System should still respond
      {:ok, access_info} =
        AccessControlManager.validate_data_access(
          "user_001",
          "tenant_a",
          "observability_data",
          "public",
          %{user_role: "viewer", clearance_level: "public"}
        )

      assert is_map(access_info)
    end

    test "SC5: compliance - complete audit trail and regulatory validation" do
      # Create audit log with compliance data
      {:ok, audit_info} =
        AccessControlManager.create_audit_log(
          "ACCESS_GRANTED",
          "user_001",
          "tenant_a",
          %{
            data_type: "financial_data",
            data_sensitivity: "confidential",
            operation: "export"
          }
        )

      # Verify audit trail completeness
      assert Map.has_key?(audit_info, :audit_id)
      assert Map.has_key?(audit_info, :logged_at)
      assert Map.has_key?(audit_info, :retention_until)
      assert Map.has_key?(audit_info, :tamper_proof_hash)

      # Verify compliance flags
      assert "gdpr" in audit_info.compliance_flags
      assert "sox" in audit_info.compliance_flags
    end
  end
end
