defmodule Indrajaal.ConfigManagementTest do
  @moduledoc """
  Comprehensive test suite for configuration management features.

  Following TDG methodology - tests written BEFORE implementation.
  Covers bulk operations, import / export, versioning, and approval workflows.

  SOPv5.1 Compliance: ✅
  Agent: Helper - 1 designs configuration tests
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms
  alias Indrajaal.ConfigManagement
  alias Indrajaal.ConfigManagement.{BulkOperations, ImportExport, Versioning, ApprovalWorkflow}
  alias Indrajaal.Devices

  @tag :tdg_required
  @tag :container_only
  @tag timeout: :infinity

  describe "bulk operations" do
    @tag :unit
    test "bulk create devices with validation" do
      devices_data = [
        %{name: "Device 1", type: "camera", status: "active"},
        %{name: "Device 2", type: "sensor", status: "active"},
        %{name: "Device 3", type: "alarm_panel", status: "inactive"}
      ]

      assert {:ok, result} = BulkOperations.bulk_create(Devices, devices_data)
      assert result.success_count == 3
      assert result.error_count == 0
      assert length(result.created_records) == 3
    end

    @tag :unit
    test "bulk update with partial failures" do
      # Create test devices
      devices = for i <- 1..5, do: insert(:device, name: "Device #{i}")

      updates = [
        %{id: Enum.at(devices, 0).id, status: "active"},
        %{id: Enum.at(devices, 1).id, status: "maintenance"},
        # This should fail
        %{id: "invalid-id", status: "active"},
        %{id: Enum.at(devices, 3).id, status: "inactive"},
        # This should fai
        %{id: Enum.at(devices, 4).id, status: "invalid_status"}
      ]

      assert {:ok, result} = BulkOperations.bulk_update(Devices, updates)
      assert result.success_count == 3
      assert result.error_count == 2
      assert length(result.errors) == 2
    end

    @tag :unit
    test "bulk delete with confirmation" do
      devices = for _i <- 1..3, do: insert(:device)
      device_ids = Enum.map(devices, & &1.id)

      assert {:ok, result} = BulkOperations.bulk_delete(Devices, device_ids, confirm: true)
      assert result.deleted_count == 3
      assert result.errors == []
    end

    @tag :unit
    test "bulk operations respect tenant isolation" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      # Create devices for different tenants
      device1 = insert(:device, tenant_id: tenant1.id)
      device2 = insert(:device, tenant_id: tenant2.id)

      # Try to bulk update across tenants (should fail)
      updates = [
        %{id: device1.id, status: "active"},
        %{id: device2.id, status: "active"}
      ]

      assert {:error, :cross_tenant_operation} =
               BulkOperations.bulk_update(Devices, updates, tenant_id: tenant1.id)
    end
  end

  describe "import / export functionality" do
    @tag :unit
    test "export devices to CSV format" do
      devices = for i <- 1..3, do: insert(:device, name: "Device #{i}")
      _suppress_warning = devices

      assert {:ok, csv_data} =
               ImportExport.export(Devices, :csv, tenant_id: hd(devices).tenant_id)

      lines = String.split(csv_data, "
# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n")
      # Header + 3 devices
      assert length(lines) >= 4
      assert hd(lines) =~ "name,type,status"
    end

    @tag :unit
    test "export alarms to JSON format" do
      alarms = for _i <- 1..2, do: insert(:alarm, priority: "high")

      assert {:ok, json_data} =
               ImportExport.export(Alarms, :json, tenant_id: hd(alarms).tenant_id)

      assert {:ok, decoded} = Jason.decode(json_data)
      assert length(decoded["alarms"]) == 2
      assert decoded["export_metadata"]["version"] == "1.0"
    end

    @tag :unit
    test "export with filtering and field selection" do
      Indrajaal.Factory.insert_list(5, :device, status: "active")
      Indrajaal.Factory.insert_list(3, :device, status: "inactive")

      opts = [
        filter: %{status: "active"},
        fields: [:id, :name, :status],
        tenant_id: insert(:tenant).id
      ]

      assert {:ok, csv_data} = ImportExport.export(Devices, :csv, opts)
      split_lines = String.split(csv_data, "\n")
      lines = split_lines |> Enum.filter(&(&1 != ""))
      # Header + 5 active devices
      assert length(lines) == 6
    end

    @tag :unit
    test "import devices from CSV with validation" do
      csv_data = """
      name,type,status,location
      Camera 1,camera,active,Building A
      Sensor 1,sensor,active,Building B
      Invalid Device,,active,Building C
      """

      tenant_id = insert(:tenant).id

      assert {:ok, result} = ImportExport.import(Devices, :csv, csv_data, tenant_id: tenant_id)
      assert result.imported_count == 2
      assert result.error_count == 1
      assert length(result.errors) == 1
    end

    @tag :unit
    test "import with duplicate detection" do
      existing_device = insert(:device, name: "Existing Device", serial_number: "SN123")

      csv_data = """
      name,serial_number,type,status
      New Device,SN456,camera,active
      Existing Device,SN123,sensor,active
      Another Device,SN789,alarm_panel,active
      """

      opts = [
        tenant_id: existing_device.tenant_id,
        duplicate_strategy: :skip,
        duplicate_key: :serial_number
      ]

      assert {:ok, result} = ImportExport.import(Devices, :csv, csv_data, opts)
      assert result.imported_count == 2
      assert result.skipped_count == 1
      assert result.duplicates == ["SN123"]
    end
  end

  describe "configuration templates" do
    @tag :unit
    test "create configuration template" do
      template_data = %{
        name: "Standard Camera Config",
        domain: "devices",
        template_type: "camera",
        fields: %{
          type: "camera",
          status: "active",
          settings: %{
            resolution: "1080p",
            fps: 30,
            night_vision: true
          }
        }
      }

      assert {:ok, template} = ConfigManagement.create_template(template_data)
      assert template.name == "Standard Camera Config"
      assert template.fields["settings"]["resolution"] == "1080p"
    end

    @tag :unit
    test "apply template to create configurations" do
      template =
        insert(:config_template,
          domain: "devices",
          fields: %{type: "sensor", status: "active", sensitivity: "high"}
        )

      instances = [
        %{name: "Sensor 1", location: "Room 101"},
        %{name: "Sensor 2", location: "Room 102"},
        %{name: "Sensor 3", location: "Room 103"}
      ]

      assert {:ok, result} = ConfigManagement.apply_template(template, instances)
      assert length(result.created) == 3
      assert Enum.all?(result.created, &(&1.type == "sensor"))
      assert Enum.all?(result.created, &(&1.sensitivity == "high"))
    end

    @tag :unit
    test "template inheritance and overrides" do
      base_template =
        insert(:config_template,
          name: "Base Alarm Config",
          fields: %{priority: "medium", auto_escalate: true}
        )

      derived_template_data = %{
        name: "High Priority Alarm Config",
        parent_template_id: base_template.id,
        field_overrides: %{priority: "high", notification_delay: 0}
      }

      assert {:ok, derived} = ConfigManagement.create_template(derived_template_data)
      assert derived.fields["priority"] == "high"
      # Inherited
      assert derived.fields["auto_escalate"] == true
      # New field
      assert derived.fields["notification_delay"] == 0
    end
  end

  describe "change approval workflows" do
    @tag :unit
    test "create change request for configuration update" do
      device = insert(:device, status: "active")
      user = insert(:user, role: "operator")

      change_data = %{
        entity_type: "device",
        entity_id: device.id,
        changes: %{status: "maintenance"},
        reason: "Scheduled maintenance",
        requested_by: user.id
      }

      assert {:ok, request} = ApprovalWorkflow.create_change_request(change_data)
      assert request.status == "pending"
      assert request.entity_type == "device"
      assert request.changes["status"] == "maintenance"
    end

    @tag :unit
    test "approve change request with authorization check" do
      request = insert(:change_request, status: "pending", required_approvals: 1)
      approver = insert(:user, role: "manager")

      assert {:ok, approval} = ApprovalWorkflow.approve_request(request, approver)
      assert approval.status == "approved"
      assert approval.approved_by == approver.id
      assert approval.approved_at != nil
    end

    @tag :unit
    test "multi-level approval workflow" do
      # High - risk change __requires multiple approvals
      request =
        insert(:change_request,
          risk_level: "high",
          required_approvals: 2,
          status: "pending"
        )

      manager = insert(:user, role: "manager")
      admin = insert(:user, role: "admin")

      # First approval
      assert {:ok, request} = ApprovalWorkflow.approve_request(request, manager)
      assert request.status == "partially_approved"
      assert request.approval_count == 1

      # Second approval completes the workflow
      assert {:ok, request} = ApprovalWorkflow.approve_request(request, admin)
      assert request.status == "approved"
      assert request.approval_count == 2

      # Changes are automatically applied
      assert request.applied_at != nil
    end

    @tag :unit
    test "reject change request with reason" do
      request = insert(:change_request, status: "pending")
      reviewer = insert(:user, role: "manager")

      assert {:ok, rejection} =
               ApprovalWorkflow.reject_request(request, reviewer,
                 reason: "Changes could impact system stability"
               )

      assert rejection.status == "rejected"
      assert rejection.rejected_by == reviewer.id
      assert rejection.rejection_reason =~ "system stability"
    end

    @tag :unit
    test "emergency changes bypass approval" do
      device = insert(:device, status: "active")
      admin = insert(:user, role: "admin")

      emergency_change = %{
        entity_type: "device",
        entity_id: device.id,
        changes: %{status: "emergency_shutdown"},
        emergency: true,
        reason: "Security breach detected",
        requested_by: admin.id
      }

      assert {:ok, request} = ApprovalWorkflow.create_change_request(emergency_change)
      assert request.status == "auto_approved"
      assert request.applied_at != nil
    end
  end

  describe "configuration versioning" do
    @tag :unit
    test "track configuration changes with versioning" do
      device = insert(:device, settings: %{threshold: 50})

      # Make first change
      assert {:ok, v1} = Versioning.update_with_version(device, %{settings: %{threshold: 75}})
      assert v1.version_number == 1
      assert v1.previous_value["settings"]["threshold"] == 50
      assert v1.new_value["settings"]["threshold"] == 75

      # Make second change
      assert {:ok, v2} = Versioning.update_with_version(device, %{settings: %{threshold: 100}})
      assert v2.version_number == 2
      assert v2.previous_value["settings"]["threshold"] == 75
    end

    @tag :unit
    test "rollback to previous version" do
      alarm = insert(:alarm, priority: "low", threshold: 10)

      # Create versions
      {:ok, _} = Versioning.update_with_version(alarm, %{priority: "medium", threshold: 20})
      {:ok, _} = Versioning.update_with_version(alarm, %{priority: "high", threshold: 30})

      # Current state
      current = Alarms.get_alarm!(alarm.id)
      assert current.priority == "high"
      assert current.threshold == 30

      # Rollback to version 1
      assert {:ok, rolled_back} = Versioning.rollback(alarm, version: 1)
      assert rolled_back.priority == "medium"
      assert rolled_back.threshold == 20
    end

    @tag :unit
    test "version comparison and diff" do
      device = insert(:device)

      {:ok, v1} = Versioning.update_with_version(device, %{name: "Camera A", status: "active"})

      {:ok, v2} =
        Versioning.update_with_version(
          device,
          %{name: "Camera A", status: "maintenance"}
        )

      {:ok, v3} =
        Versioning.update_with_version(device, %{name: "Camera A - 1", location: "Lobby"})

      assert {:ok, diff} =
               Versioning.compare_versions(device, v1.version_number, v3.version_number)

      assert diff.changes == %{
               name: %{from: "Camera A", to: "Camera A - 1"},
               status: %{from: "active", to: "maintenance"},
               location: %{from: nil, to: "Lobby"}
             }
    end
  end

  describe "configuration validation" do
    @tag :unit
    test "validate configuration against schema" do
      device_schema = %{
        type: :string,
        status: {:enum, ["active", "inactive", "maintenance"]},
        settings: %{
          threshold: {:number, min: 0, max: 100},
          enabled: :boolean
        }
      }

      valid_config = %{
        type: "sensor",
        status: "active",
        settings: %{threshold: 75, enabled: true}
      }

      invalid_config = %{
        type: "sensor",
        status: "invalid_status",
        settings: %{threshold: 150, enabled: "yes"}
      }

      assert :ok = ConfigManagement.validate_config(valid_config, device_schema)
      assert {:error, errors} = ConfigManagement.validate_config(invalid_config, device_schema)
      assert length(errors) == 3
    end

    @tag :unit
    test "cross - reference validation between domains" do
      # Create alarm type
      alarm_type = insert(:alarm_type, requires_device: true)

      # Try to create alarm without device
      alarm_data = %{
        type_id: alarm_type.id,
        priority: "high",
        device_id: nil
      }

      assert {:error, :device_required} =
               ConfigManagement.validate_references(alarm_data, :alarm)
    end
  end

  describe "configuration synchronization" do
    @tag :unit
    test "sync configurations between environments" do
      # Source environment configs
      source_configs = [
        insert(:device, name: "Device 1", sync_id: "sync - 1"),
        insert(:device, name: "Device 2", sync_id: "sync - 2"),
        insert(:device, name: "Device 3", sync_id: "sync - 3")
      ]

      # Target has one matching, one different, one missing
      target_tenant = insert(:tenant)
      insert(:device, name: "Device 1", sync_id: "sync - 1", tenant_id: target_tenant.id)
      insert(:device, name: "Device 2 Modified", sync_id: "sync - 2", tenant_id: target_tenant.id)

      source_tenant_id = hd(source_configs).tenant_id

      assert {:ok, result} =
               ConfigManagement.sync_configurations(
                 source_tenant_id,
                 target_tenant.id,
                 domain: :devices
               )

      assert result.unchanged_count == 1
      assert result.updated_count == 1
      assert result.created_count == 1
      assert result.conflicts == []
    end

    @tag :unit
    test "handle sync conflicts with resolution strategy" do
      source_device =
        insert(:device, sync_id: "conflict-1", updated_at: ~N[2025-08-04 10:00:00])

      target_device =
        insert(:device, sync_id: "conflict-1", updated_at: ~N[2025-08-04 11:00:00])

      # Source is older, target is newer - conflict!
      assert {:ok, result} =
               ConfigManagement.sync_configurations(
                 source_device.tenant_id,
                 target_device.tenant_id,
                 domain: :devices,
                 conflict_resolution: :newest_wins
               )

      assert result.conflicts_resolved == 1
      assert result.resolution_strategy == :newest_wins
    end
  end

  # Property - based tests
  describe "property - based configuration tests" do
    @tag :property
    test "bulk operations maintain data integrity" do
      assert PropCheck.quickcheck(
               forall count <- PC.integer(1, 100) do
                 devices = for i <- 1..count, do: %{name: "Device #{i}", type: "sensor"}

                 {:ok, result} = BulkOperations.bulk_create(Devices, devices)
                 result.success_count == count
               end
             )
    end

    @tag :property
    test "version numbers always increment" do
      ExUnitProperties.check all(
                               changes <-
                                 SD.list_of(SD.map_of(SD.atom(:alphanumeric), SD.term()),
                                   min_length: 2
                                 )
                             ) do
        device = insert(:device)

        versions =
          Enum.reduce(changes, [], fn change, acc ->
            {:ok, version} = Versioning.update_with_version(device, change)
            [version | acc]
          end)

        version_map = Enum.map(versions, & &1.version_number)
        version_numbers = version_map |> Enum.reverse()
        assert version_numbers == Enum.sort(version_numbers)
      end
    end
  end

  # Integration tests
  describe "end - to - end configuration management" do
    @tag :integration
    test "complete configuration lifecycle" do
      tenant = insert(:tenant)
      user = insert(:user, role: "operator", tenant_id: tenant.id)
      approver = insert(:user, role: "manager", tenant_id: tenant.id)

      # 1. Create template
      template =
        insert(:config_template,
          domain: "devices",
          fields: %{type: "camera", status: "active"}
        )

      # 2. Bulk create using template
      instances = for i <- 1..5, do: %{name: "Camera #{i}"}
      {:ok, result} = ConfigManagement.apply_template(template, instances, tenant_id: tenant.id)
      devices = result.created

      # 3. Export configurations
      {:ok, export_data} = ImportExport.export(Devices, :json, tenant_id: tenant.id)

      # 4. Request change with approval workflow
      change_request = %{
        entity_type: "device",
        entity_id: hd(devices).id,
        changes: %{status: "maintenance"},
        requested_by: user.id
      }

      {:ok, request} = ApprovalWorkflow.create_change_request(change_request)
      {:ok, request} = ApprovalWorkflow.approve_request(request, approver)

      # 5. Verify versioning
      versions = Versioning.get_versions(hd(devices))
      assert length(versions) == 1
      assert hd(versions).new_value["status"] == "maintenance"

      # 6. Rollback change
      {:ok, rolled_back} = Versioning.rollback(hd(devices), version: 0)
      assert rolled_back.status == "active"
    end
  end
end
