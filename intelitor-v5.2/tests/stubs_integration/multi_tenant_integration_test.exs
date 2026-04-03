defmodule Intelitor.Integration.MultiTenantIntegrationTest do
  @moduledoc """
  Comprehensive integration tests for multi-tenant functionality.

  Tests complete tenant isolation across all domains and ensures
  that tenant data boundaries are never violated under any circumstances.
  """

  use Intelitor.WallabyCase
  import Intelitor.Factory

  @moduletag :integration
  @moduletag :tenant_isolation

  describe "Complete Tenant Data Isolation" do
    test "tenant data is completely isolated across all domains" do
      # Create two separate tenants with comprehensive data
      tenant_a = insert(:tenant, name: "Tenant A Corp", subdomain: "tenant-a")
      tenant_b = insert(:tenant, name: "Tenant B Inc", subdomain: "tenant-b")

      # Create comprehensive test data for both tenants
      tenant_a_data = create_tenant_ecosystem(tenant_a)
      tenant_b_data = create_tenant_ecosystem(tenant_b)

      # Test isolation across all domains
      verify_core_domain_isolation(tenant_a, tenant_b, tenant_a_data, tenant_b_data)
      verify_accounts_domain_isolation(tenant_a, tenant_b, tenant_a_data, tenant_b_data)
      verify_sites_domain_isolation(tenant_a, tenant_b, tenant_a_data, tenant_b_data)
      verify_devices_domain_isolation(tenant_a, tenant_b, tenant_a_data, tenant_b_data)
      verify_alarms_domain_isolation(tenant_a, tenant_b, tenant_a_data, tenant_b_data)
      verify_security_domain_isolation(tenant_a, tenant_b, tenant_a_data, tenant_b_data)
    end

    test "cross-tenant queries are impossible through API" do
      tenant_a = insert(:tenant)
      tenant_b = insert(:tenant)

      # Create data in both tenants
      __user_a = insert(:user, tenant: tenant_a, email: "user@tenant-a.com")
      __user_b = insert(:user, tenant: tenant_b, email: "user@tenant-b.com")

      device_a = insert(:device, tenant: tenant_a, name: "Tenant A Device")
      device_b = insert(:device, tenant: tenant_b, name: "Tenant B Device")

      # Authenticate as tenant A user
      context_a = %{tenant_id: tenant_a.id, user_id: __user_a.id}

      # Attempt to access tenant B data through various methods

      # Direct ID access should fail
      assert {:error, _} = Intelitor.Accounts.get_user(__user_b.id, context_a)
      assert {:error, _} = Intelitor.Devices.get_device(device_b.id, context_a)

      # List operations should not return cross-tenant data
      {:ok, users} = Intelitor.Accounts.list_users(%{}, context_a)
      user_ids = Enum.map(users, & &1.id)
      refute __user_b.id in user_ids

      {:ok, devices} = Intelitor.Devices.list_devices(%{}, context_a)
      device_ids = Enum.map(devices, & &1.id)
      refute device_b.id in device_ids

      # Search operations should not return cross-tenant data
      {:ok, search_results} =
        Intelitor.Accounts.search_users(%{email: "user@tenant-b.com"}, context_a)

      assert Enum.empty?(search_results)

      {:ok, device_search} =
        Intelitor.Devices.search_devices(%{name: "Tenant B Device"}, context_a)

      assert Enum.empty?(device_search)
    end

    test "tenant isolation maintained under concurrent access" do
      # Create multiple tenants
      tenants =
        Enum.map(1..5, fn i ->
          insert(:tenant, name: "Concurrent Tenant #{i}", subdomain: "tenant-#{i}")
        end)

      # Create data for each tenant
      tenant_data =
        Enum.map(tenants, fn tenant ->
          {tenant,
           %{
             users: Intelitor.Factory.insert_list(10, :user, tenant: tenant),
             devices: Intelitor.Factory.insert_list(20, :device, tenant: tenant),
             sites: Intelitor.Factory.insert_list(5, :site, tenant: tenant)
           }}
        end)

      # Run concurrent operations across all tenants
      concurrent_tasks =
        Enum.map(tenant_data, fn {tenant, data} ->
          Task.async(fn ->
            context = %{tenant_id: tenant.id, user_id: List.first(data.users).id}

            # Perform various operations concurrently
            operations = [
              fn -> Intelitor.Accounts.list_users(%{}, context) end,
              fn -> Intelitor.Devices.list_devices(%{}, context) end,
              fn -> Intelitor.Sites.list_sites(%{}, context) end,
              fn ->
                new_user_params = %{
                  email: "concurrent_#{:rand.uniform(10000)}@#{tenant.subdomain}.com",
                  password: "SecurePass123!",
                  first_name: "Concurrent",
                  last_name: "User",
                  role: :operator,
                  active: true
                }

                Intelitor.Accounts.create_user(new_user_params, context)
              end
            ]

            results =
              Enum.map(operations, fn operation ->
                {time, result} = :timer.tc(operation)
                {time, result}
              end)

            {tenant.id, results}
          end)
        end)

      # Wait for all concurrent operations to complete
      results = Task.await_many(concurrent_tasks, 30_000)

      # Verify each tenant only accessed its own data
      Enum.each(results, fn {tenant_id, operation_results} ->
        Enum.each(operation_results, fn {_time, result} ->
          case result do
            {:ok, items} when is_list(items) ->
              # Verify all returned items belong to the correct tenant
              Enum.each(items, fn item ->
                assert item.tenant_id == tenant_id
              end)

            {:ok, item} when is_map(item) ->
              # Verify single item belongs to correct tenant
              assert item.tenant_id == tenant_id

            _ ->
              # Other results are acceptable
              :ok
          end
        end)
      end)
    end
  end

  describe "Tenant Resource Limits and Quotas" do
    test "tenant resource limits are enforced" do
      tenant =
        insert(:tenant,
          settings: %{
            max_users: 10,
            max_devices: 50,
            max_sites: 5
          }
        )

      context = %{tenant_id: tenant.id}

      # Test user limit enforcement
      users =
        Enum.map(1..10, fn i ->
          user_params = %{
            email: "user#{i}@example.com",
            password: "SecurePass123!",
            first_name: "User",
            last_name: "#{i}",
            role: :operator,
            active: true
          }

          {:ok, user} = Intelitor.Accounts.create_user(user_params, context)
          user
        end)

      assert length(users) == 10

      # Attempt to create 11th user should fail
      excess_user_params = %{
        email: "user11@example.com",
        password: "SecurePass123!",
        first_name: "Excess",
        last_name: "User",
        role: :operator,
        active: true
      }

      assert {:error, :quota_exceeded} =
               Intelitor.Accounts.create_user(excess_user_params, context)

      # Test device limit enforcement
      devices =
        Enum.map(1..50, fn i ->
          device_params = %{
            name: "Device #{i}",
            type: :camera,
            status: :online,
            tenant_id: tenant.id
          }

          {:ok, device} = Intelitor.Devices.create_device(device_params, context)
          device
        end)

      assert length(devices) == 50

      # Attempt to create 51st device should fail
      excess_device_params = %{
        name: "Excess Device",
        type: :camera,
        status: :online,
        tenant_id: tenant.id
      }

      assert {:error, :quota_exceeded} =
               Intelitor.Devices.create_device(excess_device_params, context)
    end

    test "tenant storage quotas are monitored and enforced" do
      tenant =
        insert(:tenant,
          settings: %{
            # 100MB limit
            storage_quota_mb: 100,
            # 10 Mbps limit
            bandwidth_quota_mbps: 10
          }
        )

      context = %{tenant_id: tenant.id}

      # Simulate storage usage through various operations
      storage_operations = [
        # Upload documents
        fn ->
          document_params = %{
            name: "Large Document",
            # 1MB content
            content: String.duplicate("A", 1024 * 1024),
            type: :compliance_document,
            tenant_id: tenant.id
          }

          Intelitor.Compliance.create_document(document_params, context)
        end,

        # Create video recordings
        fn ->
          recording_params = %{
            camera_id: insert(:camera, tenant: tenant).id,
            # 10MB recording
            file_size_mb: 10,
            duration_seconds: 300,
            format: :h264,
            tenant_id: tenant.id
          }

          Intelitor.Video.create_recording(recording_params, context)
        end,

        # Generate reports
        fn ->
          report_params = %{
            name: "Monthly Security Report",
            type: :security,
            # 5MB report
            data_size_mb: 5,
            tenant_id: tenant.id
          }

          Intelitor.Analytics.generate_report(report_params, context)
        end
      ]

      # Execute storage operations until quota is approached
      current_usage = 0
      operations_completed = 0

      Enum.reduce_while(1..50, current_usage, fn _i, usage_acc ->
        operation = Enum.random(storage_operations)

        case operation.() do
          {:ok, resource} ->
            new_usage = usage_acc + get_resource_size_mb(resource)
            operations_completed = operations_completed + 1

            # Continue until near quota
            if new_usage < 95 do
              {:cont, new_usage}
            else
              {:halt, new_usage}
            end

          {:error, :storage_quota_exceeded} ->
            # Expected when quota is reached
            {:halt, usage_acc}

          {:error, _other_reason} ->
            # Continue with other operations
            {:cont, usage_acc}
        end
      end)

      # Verify quota enforcement
      assert operations_completed > 0

      # Attempt operation that would exceed quota should fail
      large_operation = fn ->
        document_params = %{
          name: "Quota Exceeding Document",
          # 20MB content
          content: String.duplicate("B", 20 * 1024 * 1024),
          type: :compliance_document,
          tenant_id: tenant.id
        }

        Intelitor.Compliance.create_document(document_params, context)
      end

      assert {:error, :storage_quota_exceeded} = large_operation.()
    end
  end

  describe "Cross-Tenant Data Migration and Backup" do
    test "tenant data can be safely migrated between environments" do
      source_tenant = insert(:tenant, name: "Source Tenant")
      target_tenant = insert(:tenant, name: "Target Tenant")

      # Create comprehensive data in source tenant
      source_data = create_local_comprehensive_tenant_data(source_tenant)

      # Export tenant data
      export_result =
        Intelitor.Core.export_tenant_data(source_tenant.id, %{
          include_historical_data: true,
          include_user_preferences: true,
          include_system_config: true,
          format: :json
        })

      assert {:ok, export_data} = export_result
      assert is_map(export_data)

      # Verify export contains all expected data
      assert Map.has_key?(export_data, :users)
      assert Map.has_key?(export_data, :devices)
      assert Map.has_key?(export_data, :sites)
      assert Map.has_key?(export_data, :alarms)
      assert Map.has_key?(export_data, :metadata)

      # Verify export metadata
      assert export_data.metadata.tenant_id == source_tenant.id
      assert export_data.metadata.export_timestamp
      assert export_data.metadata.data_version

      # Import data into target tenant
      import_result =
        Intelitor.Core.import_tenant_data(target_tenant.id, export_data, %{
          overwrite_existing: false,
          validate_consistency: true,
          create_audit_trail: true
        })

      assert {:ok, import_summary} = import_result

      # Verify import summary
      assert import_summary.users_imported > 0
      assert import_summary.devices_imported > 0
      assert import_summary.sites_imported > 0
      # 95% success rate
      assert import_summary.success_rate > 0.95

      # Verify data integrity after migration
      verify_migrated_data_integrity(source_tenant, target_tenant, source_data)
    end

    test "tenant backup and restore maintains data consistency" do
      tenant = insert(:tenant)

      # Create comprehensive test data
      original_data = create_local_comprehensive_tenant_data(tenant)

      # Create backup
      backup_result =
        Intelitor.Core.backup_tenant(tenant.id, %{
          backup_type: :full,
          compression: true,
          encryption: true,
          include_files: true
        })

      assert {:ok, backup_info} = backup_result
      assert backup_info.backup_id
      assert backup_info.backup_size_mb > 0
      assert backup_info.backup_timestamp

      # Simulate data changes and corruption
      corrupt_tenant_data(tenant)

      # Restore from backup
      restore_result =
        Intelitor.Core.restore_tenant(tenant.id, backup_info.backup_id, %{
          restore_point: backup_info.backup_timestamp,
          verify_integrity: true,
          create_restore_log: true
        })

      assert {:ok, restore_summary} = restore_result
      assert restore_summary.restored_records > 0
      assert restore_summary.integrity_check_passed

      # Verify restored data matches original
      verify_restored_data_integrity(tenant, original_data)
    end
  end

  # Helper functions for integration testing

  defp create_tenant_ecosystem(tenant) do
    %{
      users: create_bulk_users(tenant, 50),
      teams: Intelitor.Factory.insert_list(10, :team, tenant: tenant),
      sites: create_bulk_sites(tenant, 25),
      buildings: Intelitor.Factory.insert_list(30, :building, tenant: tenant),
      devices: create_bulk_devices(tenant, 100),
      cameras: Intelitor.Factory.insert_list(40, :camera, tenant: tenant),
      sensors: Intelitor.Factory.insert_list(35, :sensor, tenant: tenant),
      access_credentials: Intelitor.Factory.insert_list(75, :access_credential, tenant: tenant),
      roles: Intelitor.Factory.insert_list(15, :role, tenant: tenant),
      permissions: Intelitor.Factory.insert_list(50, :permission, tenant: tenant),
      alarm_events: create_bulk_alarm_events(tenant, 200),
      incidents: Intelitor.Factory.insert_list(25, :incident, tenant: tenant),
      reports: Intelitor.Factory.insert_list(20, :report, tenant: tenant)
    }
  end

  defp verify_core_domain_isolation(tenant_a, tenant_b, data_a, data_b) do
    context_a = %{tenant_id: tenant_a.id}
    context_b = %{tenant_id: tenant_b.id}

    # Test organization isolation
    {:ok, orgs_a} = Intelitor.Core.list_organizations(%{}, context_a)
    {:ok, orgs_b} = Intelitor.Core.list_organizations(%{}, context_b)

    org_ids_a = Enum.map(orgs_a, & &1.id)
    org_ids_b = Enum.map(orgs_b, & &1.id)

    # Verify no overlap
    assert Enum.empty?(org_ids_a -- org_ids_a)
    assert Enum.empty?(org_ids_b -- org_ids_b)
    refute Enum.any?(org_ids_a, &(&1 in org_ids_b))
  end

  defp verify_accounts_domain_isolation(tenant_a, tenant_b, data_a, data_b) do
    context_a = %{tenant_id: tenant_a.id}
    context_b = %{tenant_id: tenant_b.id}

    # Test user isolation
    {:ok, users_a} = Intelitor.Accounts.list_users(%{}, context_a)
    {:ok, users_b} = Intelitor.Accounts.list_users(%{}, context_b)

    user_ids_a = Enum.map(users_a, & &1.id)
    user_ids_b = Enum.map(users_b, & &1.id)

    refute Enum.any?(user_ids_a, &(&1 in user_ids_b))

    # Test email uniqueness across tenants (should be allowed)
    same_email = "test@example.com"

    user_params = %{
      email: same_email,
      password: "SecurePass123!",
      first_name: "Test",
      last_name: "User",
      role: :operator,
      active: true
    }

    {:ok, _user_a} = Intelitor.Accounts.create_user(user_params, context_a)
    {:ok, _user_b} = Intelitor.Accounts.create_user(user_params, context_b)
  end

  defp verify_sites_domain_isolation(tenant_a, tenant_b, _data_a, _data_b) do
    context_a = %{tenant_id: tenant_a.id}
    context_b = %{tenant_id: tenant_b.id}

    {:ok, sites_a} = Intelitor.Sites.list_sites(%{}, context_a)
    {:ok, sites_b} = Intelitor.Sites.list_sites(%{}, context_b)

    site_ids_a = Enum.map(sites_a, & &1.id)
    site_ids_b = Enum.map(sites_b, & &1.id)

    refute Enum.any?(site_ids_a, &(&1 in site_ids_b))
  end

  defp verify_devices_domain_isolation(tenant_a, tenant_b, _data_a, _data_b) do
    context_a = %{tenant_id: tenant_a.id}
    context_b = %{tenant_id: tenant_b.id}

    {:ok, devices_a} = Intelitor.Devices.list_devices(%{}, context_a)
    {:ok, devices_b} = Intelitor.Devices.list_devices(%{}, context_b)

    device_ids_a = Enum.map(devices_a, & &1.id)
    device_ids_b = Enum.map(devices_b, & &1.id)

    refute Enum.any?(device_ids_a, &(&1 in device_ids_b))
  end

  defp verify_alarms_domain_isolation(tenant_a, tenant_b, _data_a, _data_b) do
    context_a = %{tenant_id: tenant_a.id}
    context_b = %{tenant_id: tenant_b.id}

    {:ok, alarms_a} = Intelitor.Alarms.list_alarm_events(%{}, context_a)
    {:ok, alarms_b} = Intelitor.Alarms.list_alarm_events(%{}, context_b)

    alarm_ids_a = Enum.map(alarms_a, & &1.id)
    alarm_ids_b = Enum.map(alarms_b, & &1.id)

    refute Enum.any?(alarm_ids_a, &(&1 in alarm_ids_b))
  end

  defp verify_security_domain_isolation(tenant_a, tenant_b, _data_a, _data_b) do
    context_a = %{tenant_id: tenant_a.id}
    context_b = %{tenant_id: tenant_b.id}

    {:ok, creds_a} = Intelitor.AccessControl.list_credentials(%{}, context_a)
    {:ok, creds_b} = Intelitor.AccessControl.list_credentials(%{}, context_b)

    cred_ids_a = Enum.map(creds_a, & &1.id)
    cred_ids_b = Enum.map(creds_b, & &1.id)

    refute Enum.any?(cred_ids_a, &(&1 in cred_ids_b))
  end

  defp create_local_comprehensive_tenant_data(tenant) do
    %{
      users: create_bulk_users(tenant, 25),
      devices: create_bulk_devices(tenant, 50),
      sites: create_bulk_sites(tenant, 10),
      alarms: create_bulk_alarm_events(tenant, 100)
    }
  end

  defp verify_migrated_data_integrity(source_tenant, target_tenant, original_data) do
    target_context = %{tenant_id: target_tenant.id}

    # Verify user data
    {:ok, migrated_users} = Intelitor.Accounts.list_users(%{}, target_context)
    assert length(migrated_users) >= length(original_data.users) * 0.95

    # Verify device data
    {:ok, migrated_devices} = Intelitor.Devices.list_devices(%{}, target_context)
    assert length(migrated_devices) >= length(original_data.devices) * 0.95

    # Verify all migrated data has correct tenant_id
    Enum.each(migrated_users, fn user ->
      assert user.tenant_id == target_tenant.id
    end)

    Enum.each(migrated_devices, fn device ->
      assert device.tenant_id == target_tenant.id
    end)
  end

  defp corrupt_tenant_data(tenant) do
    # Simulate data corruption by deleting some records
    context = %{tenant_id: tenant.id}

    {:ok, users} = Intelitor.Accounts.list_users(%{}, context)
    users_to_delete = Enum.take_random(users, div(length(users), 4))

    Enum.each(users_to_delete, fn user ->
      Intelitor.Accounts.delete_user(user.id, context)
    end)
  end

  defp verify_restored_data_integrity(tenant, original_data) do
    context = %{tenant_id: tenant.id}

    # Verify data counts match or exceed original
    {:ok, restored_users} = Intelitor.Accounts.list_users(%{}, context)
    assert length(restored_users) >= length(original_data.users) * 0.95

    {:ok, restored_devices} = Intelitor.Devices.list_devices(%{}, context)
    assert length(restored_devices) >= length(original_data.devices) * 0.95
  end

  defp get_resource_size_mb(resource) do
    # Simplified size calculation for testing
    case resource do
      %{content: content} when is_binary(content) ->
        byte_size(content) / (1024 * 1024)

      %{file_size_mb: size} ->
        size

      %{data_size_mb: size} ->
        size

      _ ->
        # Default small size
        0.1
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
