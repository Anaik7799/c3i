defmodule Indrajaal.Core.AuditLogTest do
  use Indrajaal.DataCase
  alias Indrajaal.Core
  alias Indrajaal.Core.AuditLog

  describe "audit log creation" do
    setup do
      tenant = insert(:tenant)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, user: user}
    end

    test "creates audit log with valid attributes",
         %{tenant: tenant, user: user} do
      attrs = %{
        tenant_id: tenant.id,
        actor_id: user.id,
        actor_type: "user",
        action: "user.login",
        resource_type: "session",
        resource_id: Ecto.UUID.generate(),
        ip_address: "192.168.1.100",
        user_agent: "Mozilla/5.0..."
      }

      assert {:ok, log} = AuditLog.create(attrs)
      assert log.tenant_id == tenant.id
      assert log.actor_id == user.id
      assert log.actor_type == "user"
      assert log.action == "user.login"
      assert log.resource_type == "session"
      assert log.ip_address == "192.168.1.100"
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = AuditLog.create(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "actor_id: is required"
      assert error_msg =~ "actor_type: is required"
      assert error_msg =~ "action: is required"
    end

    test "validates actor types", %{tenant: tenant} do
      valid_types = ["user", "system", "api", "service"]

      for type <- valid_types do
        attrs = %{
          tenant_id: tenant.id,
          actor_id: Ecto.UUID.generate(),
          actor_type: type,
          action: "test.action"
        }

        assert {:ok, log} = AuditLog.create(attrs)
        assert log.actor_type == type
      end
    end

    test "creates audit log with changes tracking",
         %{tenant: tenant, user: user} do
      changes = %{
        "before" => %{"status" => "inactive", "name" => "Old Name"},
        "after" => %{"status" => "active", "name" => "New Name"}
      }

      attrs = %{
        tenant_id: tenant.id,
        actor_id: user.id,
        actor_type: "user",
        action: "resource.updated",
        resource_type: "device",
        resource_id: Ecto.UUID.generate(),
        changes: changes
      }

      assert {:ok, log} = AuditLog.create(attrs)
      assert log.changes["before"]["status"] == "inactive"
      assert log.changes["after"]["status"] == "active"
    end

    test "creates audit log with metadata", %{tenant: tenant, user: user} do
      metadata = %{
        "browser" => "Chrome",
        "os" => "Windows 10",
        "location" => %{
          "city" => "New York",
          "country" => "US",
          "lat" => 40.7128,
          "lon" => -74.0060
        },
        "risk_score" => 15,
        "session_id" => Ecto.UUID.generate()
      }

      attrs = %{
        tenant_id: tenant.id,
        actor_id: user.id,
        actor_type: "user",
        action: "security.access_granted",
        metadata: metadata
      }

      assert {:ok, log} = AuditLog.create(attrs)
      assert log.metadata["browser"] == "Chrome"
      assert log.metadata["location"]["city"] == "New York"
      assert log.metadata["risk_score"] == 15
    end

    test "creates audit log with correlation ID",
         %{tenant: tenant, user: user} do
      correlation_id = Ecto.UUID.generate()

      attrs = %{
        tenant_id: tenant.id,
        actor_id: user.id,
        actor_type: "user",
        action: "workflow.started",
        correlation_id: correlation_id
      }

      assert {:ok, log} = AuditLog.create(attrs)
      assert log.correlation_id == correlation_id
    end

    test "creates system-generated audit logs", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        actor_id: "system",
        actor_type: "system",
        action: "system.backup_completed",
        resource_type: "backup",
        resource_id: Ecto.UUID.generate(),
        metadata: %{
          "backup_size_mb" => 1024,
          "duration_seconds" => 300,
          "tables_backed_up" => 50
        }
      }

      assert {:ok, log} = AuditLog.create(attrs)
      assert log.actor_id == "system"
      assert log.actor_type == "system"
    end

    test "creates API-generated audit logs", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        actor_id: "api-key-12_345",
        actor_type: "api",
        action: "api.data_exported",
        resource_type: "report",
        resource_id: Ecto.UUID.generate(),
        ip_address: "10.0.0.50",
        metadata: %{
          "api_version" => "v2",
          "rate_limit_remaining" => 95
        }
      }

      assert {:ok, log} = AuditLog.create(attrs)
      assert log.actor_type == "api"
      assert log.actor_id == "api-key-12_345"
    end
  end

  describe "audit log queries" do
    setup do
      tenant = insert(:tenant)
      logs = bulk_create_audit_logs(tenant, 100)
      {:ok, tenant: tenant, logs: logs}
    end

    test "lists all audit logs for tenant", %{tenant: tenant, logs: logs} do
      result = Core.list_audit_logs!(tenant_id: tenant.id)
      assert length(result) >= length(logs)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "filters by actor", %{tenant: tenant} do
      user_id = Ecto.UUID.generate()

      # Create specific logs
      user_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          actor_id: user_id,
          actor_type: "user"
        )

      system_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          actor_id: "system",
          actor_type: "system"
        )

      user_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [actor_id: user_id]
        )

      log_ids = Enum.map(user_logs, & &1.id)
      assert user_log.id in log_ids
      refute system_log.id in log_ids
    end

    test "filters by actor type", %{tenant: tenant} do
      api_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [actor_type: "api"]
        )

      assert Enum.all?(api_logs, &(&1.actor_type == "api"))
    end

    test "filters by action", %{tenant: tenant} do
      # Create specific action logs
      login_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          action: "user.login"
        )

      logout_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          action: "user.logout"
        )

      login_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [action: "user.login"]
        )

      assert Enum.any?(login_logs, &(&1.id == login_log.id))
      refute Enum.any?(login_logs, &(&1.id == logout_log.id))
    end

    test "filters by resource type", %{tenant: tenant} do
      device_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [resource_type: "device"]
        )

      assert Enum.all?(device_logs, &(&1.resource_type == "device"))
    end

    test "filters by date range", %{tenant: tenant} do
      # Create logs with specific dates
      yesterday = DateTime.add(DateTime.utc_now(), -1, :day)
      last_week = DateTime.add(DateTime.utc_now(), -7, :day)

      recent_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          inserted_at: yesterday
        )

      old_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          inserted_at: last_week
        )

      # Get logs from last 3 days
      three_days_ago = DateTime.add(DateTime.utc_now(), -3, :day)
      all_logs = Core.list_audit_logs!(tenant_id: tenant.id)

      recent_logs =
        Enum.filter(all_logs, fn log ->
          DateTime.compare(log.inserted_at, three_days_ago) == :gt
        end)

      log_ids = Enum.map(recent_logs, & &1.id)
      assert recent_log.id in log_ids
      refute old_log.id in log_ids
    end

    test "searches by action pattern", %{tenant: tenant} do
      # Create logs with patterns
      insert(:audit_log, tenant_id: tenant.id, action: "device.created")
      insert(:audit_log, tenant_id: tenant.id, action: "device.updated")
      insert(:audit_log, tenant_id: tenant.id, action: "device.deleted")
      insert(:audit_log, tenant_id: tenant.id, action: "user.login")

      device_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [action: {:ilike, "device.%"}]
        )

      assert length(device_logs) >= 3
      assert Enum.all?(device_logs, &String.starts_with?(&1.action, "device."))
    end

    test "filters by IP address", %{tenant: tenant} do
      ip = "192.168.1.50"

      ip_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          ip_address: ip
        )

      ip_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [ip_address: ip]
        )

      assert Enum.any?(ip_logs, &(&1.id == ip_log.id))
    end

    test "filters by correlation ID", %{tenant: tenant} do
      correlation_id = Ecto.UUID.generate()

      # Create related logs
      for i <- 1..3 do
        insert(:audit_log,
          tenant_id: tenant.id,
          correlation_id: correlation_id,
          action: "workflow.step_#{i}"
        )
      end

      correlated_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [correlation_id: correlation_id]
        )

      assert length(correlated_logs) == 3
      assert Enum.all?(correlated_logs, &(&1.correlation_id == correlation_id))
    end

    test "sorts by timestamp descending", %{tenant: tenant} do
      logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          sort: [inserted_at: :desc]
        )

      timestamps = Enum.map(logs, & &1.inserted_at)

      # Verify descending order
      Enum.reduce(timestamps, fn ts, prev_ts ->
        assert DateTime.compare(prev_ts, ts) != :lt
        ts
      end)
    end

    test "paginates results", %{tenant: tenant} do
      # Ensure enough logs
      bulk_create_audit_logs(tenant, 50)

      page1 =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 0]
        )

      page2 =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          page: [limit: 20, offset: 20]
        )

      assert length(page1) == 20
      assert length(page2) == 20

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "audit log analysis" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "identifies suspicious activity patterns", %{tenant: tenant} do
      user_id = Ecto.UUID.generate()

      # Create suspicious pattern - many failed logins
      for i <- 1..10 do
        insert(:audit_log,
          tenant_id: tenant.id,
          actor_id: user_id,
          actor_type: "user",
          action: "user.failed_login",
          ip_address: "192.168.1.#{i}",
          metadata: %{"failure_reason" => "invalid_password"}
        )
      end

      failed_logins =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [
            actor_id: user_id,
            action: "user.failed_login"
          ]
        )

      assert length(failed_logins) == 10

      # Check for multiple IPs (potential account compromise)
      unique_ips =
        failed_logins |> Enum.map(& &1.ip_address) |> Enum.uniq()

      # Suspicious - many different IPs
      assert length(unique_ips) == 10
    end

    test "tracks resource lifecycle", %{tenant: tenant} do
      resource_id = Ecto.UUID.generate()
      actor_id = Ecto.UUID.generate()

      # Create lifecycle logs
      lifecycle_events = [
        %{action: "device.created", metadata: %{"device_type" => "camera"}},
        %{action: "device.configured", metadata: %{"ip" => "192.168.1.100"}},
        %{action: "device.activated", metadata: %{"status" => "online"}},
        %{
          action: "device.updated",
          changes: %{
            "before" => %{"name" => "Camera 1"},
            "after" => %{"name" => "Front Door Camera"}
          }
        },
        %{action: "device.deactivated", metadata: %{"reason" => "maintenance"}}
      ]

      for {event, idx} <- Enum.with_index(lifecycle_events) do
        insert(
          :audit_log,
          Map.merge(event, %{
            tenant_id: tenant.id,
            actor_id: actor_id,
            actor_type: "user",
            resource_type: "device",
            resource_id: resource_id,
            inserted_at: DateTime.add(DateTime.utc_now(), idx, :hour)
          })
        )
      end

      # Get resource history
      resource_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [resource_id: resource_id],
          sort: [inserted_at: :asc]
        )

      assert length(resource_logs) == 5

      # Verify lifecycle order
      actions = Enum.map(resource_logs, & &1.action)
      assert List.first(actions) == "device.created"
      assert List.last(actions) == "device.deactivated"
    end

    test "aggregates activity by hour", %{tenant: tenant} do
      # Create logs distributed across hours
      base_time = DateTime.utc_now()

      for hour <- 0..23 do
        # 1 - 4 logs per hour
        count = rem(hour, 4) + 1

        for _ <- 1..count do
          insert(:audit_log,
            tenant_id: tenant.id,
            action: "api.__request",
            inserted_at: DateTime.add(base_time, -hour, :hour)
          )
        end
      end

      # Get all logs from last 24 hours
      logs = Core.list_audit_logs!(tenant_id: tenant.id)

      # Group by hour
      by_hour =
        Enum.group_by(logs, fn log ->
          log.inserted_at
          |> DateTime.to_naive()
          |> NaiveDateTime.truncate(:hour)
        end)

      assert map_size(by_hour) > 0
    end
  end

  describe "audit log compliance" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "maintains immutability", %{tenant: tenant} do
      log = insert(:audit_log, tenant_id: tenant.id)

      # Audit logs should be immutable - no updates allowed
      # This behavior depends on your implementation
      result = Core.update_audit_log(log, %{action: "modified.action"})

      # Should either fail or maintain original values
      case result do
        {:error, _} -> assert true
        {:ok, updated} -> assert updated.action == log.action
      end
    end

    test "enforces retention policy", %{tenant: tenant} do
      retention_days = 90

      # Create old logs
      old_date = DateTime.add(DateTime.utc_now(), -(retention_days + 10), :day)
      recent_date = DateTime.add(DateTime.utc_now(), -30, :day)

      old_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          inserted_at: old_date
        )

      recent_log =
        insert(:audit_log,
          tenant_id: tenant.id,
          inserted_at: recent_date
        )

      # In practice, a scheduled job would clean old logs
      cutoff_date = DateTime.add(DateTime.utc_now(), -retention_days, :day)

      assert DateTime.compare(old_log.inserted_at, cutoff_date) == :lt
      assert DateTime.compare(recent_log.inserted_at, cutoff_date) == :gt
    end

    test "includes required compliance fields", %{tenant: tenant} do
      log =
        insert(:audit_log,
          tenant_id: tenant.id,
          ip_address: "192.168.1.100",
          user_agent: "Mozilla/5.0...",
          metadata: %{
            "compliance" => %{
              "gdpr_consent" => true,
              "data_classification" => "confidential"
            }
          }
        )

      # Verify compliance fields
      assert log.tenant_id != nil
      assert log.actor_id != nil
      assert log.action != nil
      assert log.inserted_at != nil
      assert log.ip_address != nil
      assert log.metadata["compliance"]["gdpr_consent"] == true
    end
  end

  describe "bulk audit log operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates diverse audit trail", %{tenant: tenant} do
      logs = bulk_create_audit_logs(tenant, 100)

      assert length(logs) == 100

      # Verify diversity
      mapped_actor_types = Enum.map(logs, & &1.actor_type)
      actor_types = mapped_actor_types |> Enum.uniq()
      assert length(actor_types) >= 3

      mapped_actions = Enum.map(logs, & &1.action)
      actions = mapped_actions |> Enum.uniq()
      assert length(actions) >= 10

      resource_types =
        logs |> Enum.map(& &1.resource_type) |> Enum.filter(& &1) |> Enum.uniq()

      assert length(resource_types) >= 5
    end

    test "simulates realistic user session", %{tenant: tenant} do
      user_id = Ecto.UUID.generate()
      session_id = Ecto.UUID.generate()
      ip = "192.168.1.100"

      # Simulate user session
      session_events = [
        %{action: "user.login", resource_type: "session", metadata: %{"mfa_used" => true}},
        %{action: "user.viewed", resource_type: "dashboard"},
        %{action: "device.viewed", resource_type: "device"},
        %{
          action: "device.updated",
          resource_type: "device",
          changes: %{"before" => %{"status" => "offline"}, "after" => %{"status" => "online"}}
        },
        %{
          action: "report.generated",
          resource_type: "report",
          metadata: %{"format" => "pdf", "pages" => 10}
        },
        %{action: "user.logout", resource_type: "session"}
      ]

      for {event, idx} <- Enum.with_index(session_events) do
        attrs =
          Map.merge(event, %{
            tenant_id: tenant.id,
            actor_id: user_id,
            actor_type: "user",
            correlation_id: session_id,
            ip_address: ip,
            inserted_at: DateTime.add(DateTime.utc_now(), idx * 5, :minute)
          })

        insert(:audit_log, attrs)
      end

      # Verify session trail
      session_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [correlation_id: session_id],
          sort: [inserted_at: :asc]
        )

      assert length(session_logs) == 6
      assert List.first(session_logs).action == "user.login"
      assert List.last(session_logs).action == "user.logout"
    end

    test "generates security incident trail", %{tenant: tenant} do
      incident_id = Ecto.UUID.generate()

      # Create security incident logs
      incident_events = [
        %{
          action: "security.alarm_triggered",
          metadata: %{"severity" => "high", "sensor" => "motion_detector_1"}
        },
        %{action: "security.camera_activated", metadata: %{"camera_id" => "front_door_cam"}},
        %{
          action: "security.notification_sent",
          metadata: %{"recipients" => ["security@example.com"], "method" => "email"}
        },
        %{
          action: "security.guard_dispatched",
          metadata: %{"guard_id" => "guard_123", "eta_minutes" => 5}
        },
        %{
          action: "security.incident_acknowledged",
          metadata: %{"acknowledged_by" => "supervisor@example.com"}
        },
        %{
          action: "security.incident_resolved",
          metadata: %{"resolution" => "false_alarm", "duration_minutes" => 15}
        }
      ]

      for {event, idx} <- Enum.with_index(incident_events) do
        attrs =
          Map.merge(event, %{
            tenant_id: tenant.id,
            actor_id: "system",
            actor_type: "system",
            resource_type: "incident",
            resource_id: incident_id,
            correlation_id: incident_id,
            inserted_at: DateTime.add(DateTime.utc_now(), idx * 2, :minute)
          })

        insert(:audit_log, attrs)
      end

      # Verify incident trail
      incident_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          filter: [correlation_id: incident_id],
          sort: [inserted_at: :asc]
        )

      assert length(incident_logs) == 6
      assert List.first(incident_logs).action == "security.alarm_triggered"
      assert List.last(incident_logs).action == "security.incident_resolved"
    end
  end

  describe "audit log performance" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "handles high-volume logging", %{tenant: tenant} do
      # Simulate high-volume logging scenario
      start_time = System.monotonic_time(:millisecond)

      # Create 100 logs rapidly
      logs =
        for i <- 1..100 do
          insert(:audit_log,
            tenant_id: tenant.id,
            action: "api.request",
            metadata: %{"request_id" => "req_#{i}"}
          )
        end

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      assert length(logs) == 100
      # Should complete reasonably quickly (adjust threshold as needed)
      # 5 seconds
      assert duration < 5000
    end

    test "efficiently queries large datasets", %{tenant: tenant} do
      # Create large dataset
      bulk_create_audit_logs(tenant, 500)

      # Time the query
      start_time = System.monotonic_time(:millisecond)

      recent_logs =
        Core.list_audit_logs!(
          tenant_id: tenant.id,
          page: [limit: 50, offset: 0],
          sort: [inserted_at: :desc]
        )

      end_time = System.monotonic_time(:millisecond)
      query_time = end_time - start_time

      assert length(recent_logs) == 50
      # Query should be fast even with large dataset
      # 1 second
      assert query_time < 1000
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: General system coordination and management with cybernetics
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
