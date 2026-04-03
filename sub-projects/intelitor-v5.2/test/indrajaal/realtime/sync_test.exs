defmodule Indrajaal.Realtime.SyncTest do
  @moduledoc """
  Test suite for real - time __data synchronization.

  Following TDG methodology - tests written before implementation.

  Agent: Helper - 2 manages sync testing
  SOPv5.1 Compliance: ✅
  """

  use Indrajaal.DataCase

  alias Indrajaal.{Alarms, Devices, Sites}
  alias Indrajaal.Realtime.{Sync, ChangeTracker, OfflineQueue}

  describe "change tracking" do
    test "tracks create operations" do
      {:ok, alarm} =
        Alarms.create_alarm(%{
          name: "Test Alarm",
          severity: "high",
          source: "test",
          tenant_id: tenant_id()
        })

      changes = ChangeTracker.get_changes_since(alarm.tenant_id, ~U[2025-01-01 00:00:00Z])

      assert Enum.any?(changes, fn change ->
               change.entity_type == "alarm" &&
                 change.entity_id == alarm.id &&
                 change.operation == "create"
             end)
    end

    test "tracks update operations" do
      {:ok, device} = create_test_device()

      {:ok, updated} = Devices.update_device(device, %{name: "Updated Device"})

      changes =
        ChangeTracker.get_changes_since(
          device.tenant_id,
          device.inserted_at
        )

      assert Enum.any?(changes, fn change ->
               change.entity_type == "device" &&
                 change.entity_id == device.id &&
                 change.operation == "update" &&
                 change.changes["name"] == "Updated Device"
             end)
    end

    test "tracks delete operations" do
      {:ok, site} = create_test_site()

      {:ok, _} = Sites.delete_site(site)

      changes =
        ChangeTracker.get_changes_since(
          site.tenant_id,
          site.inserted_at
        )

      assert Enum.any?(changes, fn change ->
               change.entity_type == "site" &&
                 change.entity_id == site.id &&
                 change.operation == "delete"
             end)
    end

    test "respects tenant isolation" do
      tenant1 = tenant_id()
      tenant2 = Ecto.UUID.generate()

      {:ok, alarm1} =
        Alarms.create_alarm(%{
          name: "Tenant 1 Alarm",
          severity: "high",
          source: "test",
          tenant_id: tenant1
        })

      {:ok, alarm2} =
        Alarms.create_alarm(%{
          name: "Tenant 2 Alarm",
          severity: "high",
          source: "test",
          tenant_id: tenant2
        })

      # Get changes for tenant 1
      changes = ChangeTracker.get_changes_since(tenant1, ~U[2025-01-01 00:00:00Z])

      # Should only see tenant 1's alarm
      assert Enum.any?(changes, &(&1.entity_id == alarm1.id))
      refute Enum.any?(changes, &(&1.entity_id == alarm2.id))
    end
  end

  describe "sync protocol" do
    test "performs initial sync" do
      # Create some test __data
      {:ok, alarm} = create_test_alarm()
      {:ok, device} = create_test_device()
      {:ok, site} = create_test_site()

      # Perform initial sync (no last_sync_timestamp)
      {:ok, sync_data} = Sync.get_sync_data(tenant_id(), nil)

      assert Map.has_key?(sync_data, :alarms)
      assert Map.has_key?(sync_data, :devices)
      assert Map.has_key?(sync_data, :sites)
      assert Map.has_key?(sync_data, :sync_timestamp)

      # Should include all data
      assert Enum.any?(sync_data.alarms, &(&1.id == alarm.id))
      assert Enum.any?(sync_data.devices, &(&1.id == device.id))
      assert Enum.any?(sync_data.sites, &(&1.id == site.id))
    end

    test "performs differential sync" do
      # Create initial __data
      {:ok, alarm1} = create_test_alarm(name: "Alarm 1")
      {:ok, device1} = create_test_device(name: "Device 1")

      # Get initial sync timestamp
      {:ok, initial_sync} = Sync.get_sync_data(tenant_id(), nil)
      sync_timestamp = initial_sync.sync_timestamp

      # Create new __data after sync
      {:ok, alarm2} = create_test_alarm(name: "Alarm 2")
      {:ok, device2} = create_test_device(name: "Device 2")

      # Update existing __data
      {:ok, _} = Alarms.update_alarm(alarm1, %{severity: "critical"})

      # Perform differential sync
      {:ok, diff_sync} = Sync.get_sync_data(tenant_id(), sync_timestamp)

      # Should only include changes after sync_timestamp
      # 2 creates + 1 update
      assert length(diff_sync.changes) == 3

      assert Enum.any?(diff_sync.changes, fn change ->
               change.entity_id == alarm2.id && change.operation == "create"
             end)

      assert Enum.any?(diff_sync.changes, fn change ->
               change.entity_id == device2.id && change.operation == "create"
             end)

      assert Enum.any?(diff_sync.changes, fn change ->
               change.entity_id == alarm1.id && change.operation == "update"
             end)
    end

    test "handles sync acknowledgment" do
      # Create test __data
      {:ok, alarm} = create_test_alarm()

      # Get sync __data
      {:ok, sync_data} = Sync.get_sync_data(tenant_id(), nil)

      # Acknowledge sync
      device_id = "mobile - device-123"
      {:ok, ack} = Sync.acknowledge_sync(tenant_id(), device_id, sync_data.sync_id)

      assert ack.device_id == device_id
      assert ack.sync_id == sync_data.sync_id
      assert ack.acknowledged_at != nil
    end
  end

  describe "conflict resolution" do
    test "detects conflicts" do
      {:ok, alarm} = create_test_alarm()

      # Simulate two clients updating the same record
      client1_update = %{
        entity_type: "alarm",
        entity_id: alarm.id,
        operation: "update",
        changes: %{severity: "high"},
        client_timestamp: ~U[2025-08-04 10:00:00Z],
        version: alarm.lock_version
      }

      client2_update = %{
        entity_type: "alarm",
        entity_id: alarm.id,
        operation: "update",
        changes: %{severity: "critical"},
        client_timestamp: ~U[2025-08-04 10:00:01Z],
        version: alarm.lock_version
      }

      # First update should succeed
      {:ok, _} = Sync.apply_client_change(tenant_id(), client1_update)

      # Second update should detect conflict
      {:error, :conflict} = Sync.apply_client_change(tenant_id(), client2_update)
    end

    test "resolves conflicts using last - write - wins" do
      {:ok, device} = create_test_device()

      # Two conflicting updates
      update1 = %{
        entity_type: "device",
        entity_id: device.id,
        operation: "update",
        changes: %{status: "online"},
        client_timestamp: ~U[2025-08-04 10:00:00Z],
        version: device.lock_version
      }

      update2 = %{
        entity_type: "device",
        entity_id: device.id,
        operation: "update",
        changes: %{status: "offline"},
        client_timestamp: ~U[2025-08-04 10:00:01Z],
        version: device.lock_version
      }

      # Apply with last - write - wins strategy
      {:ok, result} = Sync.resolve_conflict(tenant_id(), [update1, update2], :last_write_wins)

      # Later timestamp should win
      assert result.changes.status == "offline"
    end

    test "resolves conflicts using merge strategy" do
      {:ok, site} = create_test_site()

      # Two updates touching different fields
      update1 = %{
        entity_type: "site",
        entity_id: site.id,
        operation: "update",
        changes: %{name: "Updated Name"},
        client_timestamp: ~U[2025-08-04 10:00:00Z],
        version: site.lock_version
      }

      update2 = %{
        entity_type: "site",
        entity_id: site.id,
        operation: "update",
        changes: %{address: "Updated Address"},
        client_timestamp: ~U[2025-08-04 10:00:01Z],
        version: site.lock_version
      }

      # Apply with merge strategy
      {:ok, result} = Sync.resolve_conflict(tenant_id(), [update1, update2], :merge)

      # Both changes should be applied
      assert result.changes.name == "Updated Name"
      assert result.changes.address == "Updated Address"
    end
  end

  describe "offline queue" do
    test "queues changes when offline" do
      device_id = "mobile - device-123"

      # Queue some changes
      change1 = %{
        entity_type: "alarm",
        entity_id: Ecto.UUID.generate(),
        operation: "create",
        __data: %{name: "Offline Alarm", severity: "high"}
      }

      change2 = %{
        entity_type: "device",
        entity_id: Ecto.UUID.generate(),
        operation: "update",
        changes: %{status: "maintenance"}
      }

      {:ok, _} = OfflineQueue.add(device_id, change1)
      {:ok, _} = OfflineQueue.add(device_id, change2)

      # Get queued changes
      changes = OfflineQueue.get_pending(device_id)

      assert length(changes) == 2
      assert Enum.any?(changes, &(&1.entity_type == "alarm"))
      assert Enum.any?(changes, &(&1.entity_type == "device"))
    end

    test "processes offline queue on reconnect" do
      device_id = "mobile - device-123"
      tenant_id = tenant_id()

      # Queue a change
      change = %{
        entity_type: "alarm",
        entity_id: Ecto.UUID.generate(),
        operation: "create",
        __data: %{
          name: "Offline Alarm",
          severity: "high",
          source: "mobile",
          tenant_id: tenant_id
        }
      }

      {:ok, _} = OfflineQueue.add(device_id, change)

      # Process queue
      {:ok, results} = OfflineQueue.process(device_id, tenant_id)

      assert length(results) == 1
      assert hd(results).status == :success

      # Queue should be empty
      assert OfflineQueue.get_pending(device_id) == []
    end

    test "handles failures in offline queue processing" do
      device_id = "mobile - device-123"

      # Queue an invalid change
      invalid_change = %{
        entity_type: "alarm",
        entity_id: Ecto.UUID.generate(),
        operation: "create",
        __data: %{
          # Missing __required fields
          name: "Invalid Alarm"
        }
      }

      {:ok, _} = OfflineQueue.add(device_id, invalid_change)

      # Process queue
      {:ok, results} = OfflineQueue.process(device_id, tenant_id())

      assert length(results) == 1
      assert hd(results).status == :error
      assert hd(results).error != nil

      # Failed item should remain in queue
      pending = OfflineQueue.get_pending(device_id)
      assert length(pending) == 1
    end
  end

  describe "sync optimization" do
    test "compresses redundant changes" do
      # Multiple updates to same entity
      changes = [
        %{
          entity_type: "device",
          entity_id: "device - 1",
          operation: "update",
          changes: %{status: "online"},
          timestamp: ~U[2025-08-04 10:00:00Z]
        },
        %{
          entity_type: "device",
          entity_id: "device - 1",
          operation: "update",
          changes: %{status: "offline"},
          timestamp: ~U[2025-08-04 10:00:01Z]
        },
        %{
          entity_type: "device",
          entity_id: "device - 1",
          operation: "update",
          changes: %{status: "maintenance"},
          timestamp: ~U[2025-08-04 10:00:02Z]
        }
      ]

      compressed = Sync.compress_changes(changes)

      # Should compress to single change with final __state
      assert length(compressed) == 1
      assert hd(compressed).changes.status == "maintenance"
    end

    test "batches changes efficiently" do
      # Create many changes
      changes =
        for i <- 1..100 do
          %{
            entity_type: "alarm",
            entity_id: Ecto.UUID.generate(),
            operation: "create",
            __data: %{name: "Alarm #{i}", severity: "low"}
          }
        end

      # Batch changes
      batches = Sync.batch_changes(changes, batch_size: 20)

      assert length(batches) == 5
      assert Enum.all?(batches, &(length(&1) == 20))
    end
  end

  # Helper functions

  defp tenant_id do
    # Return a consistent tenant ID for testing
    "11_111_111 - 1111 - 1111 - 1111 - 111_111_111_111"
  end

  defp create_test_alarm(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Alarm #{System.unique_integer()}",
      severity: "medium",
      source: "test",
      status: "active",
      tenant_id: tenant_id()
    }

    Alarms.create_alarm(Map.merge(default_attrs, attrs))
  end

  defp create_test_device(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Device #{System.unique_integer()}",
      type: "camera",
      status: "online",
      tenant_id: tenant_id()
    }

    Devices.create_device(Map.merge(default_attrs, attrs))
  end

  defp create_test_site(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Site #{System.unique_integer()}",
      address: "123 Test St",
      tenant_id: tenant_id()
    }

    Sites.create_site(Map.merge(default_attrs, attrs))
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
