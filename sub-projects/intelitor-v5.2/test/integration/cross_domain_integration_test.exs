defmodule Indrajaal.Integration.CrossDomainIntegrationTest do
  @moduledoc """
  Cross-domain integration tests covering interactions between all domains
  """

  use Indrajaal.DataCase
  use Oban.Testing, repo: Indrajaal.Repo

  alias Indrajaal.DomainApi
  alias Indrajaal.Alarms.Api, as: AlarmsApi

  describe "alarms + devices + sites integration" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Cross Domain Test Corp",
            slug: "cross-domain-test"
          },
          actor: %{is_system: true}
        )

      {:ok, organization} =
        DomainApi.create_organization(
          %{
            name: "Test Organization",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, site} =
        DomainApi.create_site(
          %{
            name: "Main Campus",
            location: "123 Security St",
            tenant_id: tenant.id,
            organization_id: organization.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, building} =
        DomainApi.create_building(
          %{
            name: "Building A",
            site_id: site.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, zone} =
        DomainApi.create_zone(
          %{
            name: "Secure Zone",
            building_id: building.id,
            site_id: site.id,
            tenant_id: tenant.id,
            criticality: :high
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, device} =
        DomainApi.create_device(
          %{
            name: "Main Panel",
            device_type: :panel,
            site_id: site.id,
            zone_id: zone.id,
            tenant_id: tenant.id,
            account_number: "PANEL001"
          },
          actor: %{tenant_id: tenant.id}
        )

      %{
        tenant: tenant,
        organization: organization,
        site: site,
        building: building,
        zone: zone,
        device: device
      }
    end

    test "alarm creation with full site hierarchy", %{
      tenant: tenant,
      site: site,
      building: building,
      zone: zone,
      device: device
    } do
      # Create alarm with complete location __context
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "CD001",
            __event_type: :intrusion,
            severity: :high,
            description: "Intrusion detected in secure zone",
            device_id: device.id,
            site_id: site.id,
            zone_id: zone.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify alarm has all location relationships
      assert alarm.device_id == device.id
      assert alarm.site_id == site.id
      assert alarm.zone_id == zone.id

      # Verify we can query by any location level
      {:ok, site_alarms} =
        AlarmsApi.list_alarm_events(
          %{site_id: site.id},
          actor: %{tenant_id: tenant.id}
        )

      assert Enum.any?(site_alarms, &(&1.id == alarm.id))

      {:ok, zone_alarms} =
        AlarmsApi.list_alarm_events(
          %{zone_id: zone.id},
          actor: %{tenant_id: tenant.id}
        )

      assert Enum.any?(zone_alarms, &(&1.id == alarm.id))
    end

    test "device health affects alarm severity", %{tenant: tenant, device: device} do
      # Simulate device with poor health
      {:ok, _updated_device} =
        DomainApi.update_device(
          device,
          %{
            status: :maintenance,
            metadata: %{health_score: 0.3, recent_failures: 5}
          },
          actor: %{tenant_id: tenant.id}
        )

      # Create alarm from unhealthy device
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "DH001",
            __event_type: :tamper,
            severity: :medium,
            description: "Device tamper detected",
            device_id: device.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify severity factors include device health
      assert alarm.severity_factors["device_health"] != nil
      assert alarm.severity_factors["device_reliability"] != nil
    end
  end

  describe "alarms + communication + __users integration" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Communication Test Corp",
            slug: "comm-test"
          },
          actor: %{is_system: true}
        )

      {:ok, user} =
        DomainApi.create_user(
          %{
            email: "operator@test.com",
            first_name: "Test",
            last_name: "Operator",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, role} =
        DomainApi.create_role(
          %{
            name: "Alarm Operator",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, _user_role} =
        DomainApi.assign_user_role(
          user.id,
          role.id,
          %{
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      %{tenant: tenant, user: user, role: role}
    end

    test "alarm notification workflow", %{tenant: tenant, user: user} do
      # Create critical alarm that should trigger notifications
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "CN001",
            __event_type: :panic,
            severity: :critical,
            description: "Panic button activated",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify notification job was enqueued
      assert_enqueued(
        worker: Indrajaal.Jobs.AlarmEscalation,
        args: %{alarm_id: alarm.id}
      )

      # Process notification job
      perform_job(Indrajaal.Jobs.AlarmEscalation, %{alarm_id: alarm.id})

      # Verify communication record was created
      {:ok, notifications} =
        DomainApi.list_notifications(
          %{
            alarm_id: alarm.id
          },
          actor: %{tenant_id: tenant.id}
        )

      assert length(notifications) > 0

      notification = List.first(notifications)
      assert notification.alarm_id == alarm.id
      assert notification.recipient_id == user.id
    end

    test "notification preferences respected", %{tenant: tenant, user: user} do
      # Set user communication preferences
      {:ok, _preference} =
        DomainApi.create_contact_preference(
          %{
            user_id: user.id,
            channel: :email,
            enabled: true,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, _preference} =
        DomainApi.create_contact_preference(
          %{
            user_id: user.id,
            channel: :sms,
            enabled: false,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Create alarm that triggers notifications
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "NP001",
            __event_type: :fire,
            severity: :critical,
            description: "Fire alarm activated",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process notifications
      perform_job(Indrajaal.Jobs.AlarmEscalation, %{alarm_id: alarm.id})

      # Verify only email notification was sent (SMS disabled)
      {:ok, notifications} =
        DomainApi.list_notifications(
          %{
            alarm_id: alarm.id,
            recipient_id: user.id
          },
          actor: %{tenant_id: tenant.id}
        )

      email_notifications = Enum.filter(notifications, &(&1.channel == :email))
      sms_notifications = Enum.filter(notifications, &(&1.channel == :sms))

      assert not Enum.empty?(email_notifications)
      assert Enum.empty?(sms_notifications)
    end
  end

  describe "alarms + video + analytics integration" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Video Test Corp",
            slug: "video-test"
          },
          actor: %{is_system: true}
        )

      {:ok, site} =
        DomainApi.create_site(
          %{
            name: "Monitored Site",
            location: "Video Test Location",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, camera} =
        DomainApi.create_camera(
          %{
            name: "Security Camera 1",
            camera_type: :dome,
            site_id: site.id,
            tenant_id: tenant.id,
            stream_url: "rtsp://test.camera/stream"
          },
          actor: %{tenant_id: tenant.id}
        )

      %{tenant: tenant, site: site, camera: camera}
    end

    test "alarm triggers video recording", %{tenant: tenant, site: site, camera: camera} do
      # Create alarm that should trigger video capture
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "VR001",
            __event_type: :motion,
            severity: :medium,
            description: "Motion detected near camera",
            site_id: site.id,
            tenant_id: tenant.id,
            metadata: %{camera_id: camera.id}
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify video recording job was enqueued
      assert_enqueued(
        worker: Indrajaal.Jobs.VideoCapture,
        args: %{alarm_id: alarm.id, camera_id: camera.id}
      )

      # Simulate video recording creation
      {:ok, recording} =
        DomainApi.create_video_recording(
          %{
            camera_id: camera.id,
            start_time: DateTime.utc_now(),
            duration: 30,
            trigger_type: :alarm,
            trigger_id: alarm.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify recording is linked to alarm
      assert recording.trigger_id == alarm.id
      assert recording.trigger_type == :alarm
    end

    test "analytics correlation with alarms", %{tenant: tenant, site: site} do
      # Create anomaly detection result
      {:ok, anomaly} =
        DomainApi.create_anomaly_detection(
          %{
            site_id: site.id,
            detection_type: :unusual_activity,
            confidence_score: 0.85,
            description: "Unusual movement pattern detected",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Create alarm that could be correlated
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "AC001",
            __event_type: :motion,
            severity: :medium,
            description: "Motion alarm",
            site_id: site.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process correlation
      perform_job(Indrajaal.Jobs.AlarmCorrelation, %{alarm_id: alarm.id})

      # Verify analytics correlation was detected
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})
      assert updated_alarm.correlation_data["analytics_correlation"] != nil
    end
  end

  describe "alarms + access control integration" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Access Control Test Corp",
            slug: "access-test"
          },
          actor: %{is_system: true}
        )

      {:ok, site} =
        DomainApi.create_site(
          %{
            name: "Secure Facility",
            location: "Access Test Location",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, reader} =
        DomainApi.create_reader(
          %{
            name: "Main Entrance Reader",
            site_id: site.id,
            tenant_id: tenant.id,
            location: "Main Entrance"
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, user} =
        DomainApi.create_user(
          %{
            email: "employee@test.com",
            first_name: "Test",
            last_name: "Employee",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      %{tenant: tenant, site: site, reader: reader, user: user}
    end

    test "access denial creates alarm", %{tenant: tenant, reader: reader, user: user} do
      # Create access denial log
      {:ok, access_log} =
        DomainApi.create_access_log(
          %{
            reader_id: reader.id,
            user_id: user.id,
            access_granted: false,
            denial_reason: "Invalid credentials",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Simulate alarm creation from access denial
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "AD001",
            __event_type: :access_denied,
            severity: :medium,
            description: "Access denied at main entrance",
            device_id: reader.id,
            tenant_id: tenant.id,
            metadata: %{access_log_id: access_log.id, user_id: user.id}
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify alarm contains access control __context
      assert alarm.metadata["access_log_id"] == access_log.id
      assert alarm.metadata["__user_id"] == user.id
      assert alarm.__event_type == :access_denied
    end

    test "multiple access denials increase severity", %{
      tenant: tenant,
      reader: reader,
      user: user
    } do
      # Create multiple access denial attempts
      for i <- 1..3 do
        {:ok, _access_log} =
          DomainApi.create_access_log(
            %{
              reader_id: reader.id,
              user_id: user.id,
              access_granted: false,
              denial_reason: "Invalid credentials",
              tenant_id: tenant.id,
              attempted_at: DateTime.add(DateTime.utc_now(), -i * 30, :second)
            },
            actor: %{tenant_id: tenant.id}
          )
      end

      # Create alarm after multiple denials
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "AD002",
            __event_type: :access_denied,
            severity: :low,
            description: "Repeated access denials",
            device_id: reader.id,
            tenant_id: tenant.id,
            metadata: %{user_id: user.id, attempt_count: 3}
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process severity evaluation
      perform_job(Indrajaal.Jobs.AlarmSeverityEvaluation, %{alarm_id: alarm.id})

      # Verify severity was escalated due to repeated attempts
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})
      assert updated_alarm.severity in [:medium, :high]
      assert updated_alarm.severity_factors["repeated_attempts"] != nil
    end
  end

  describe "alarms + dispatch integration" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Dispatch Test Corp",
            slug: "dispatch-test"
          },
          actor: %{is_system: true}
        )

      {:ok, team} =
        DomainApi.create_dispatch_team(
          %{
            name: "Security Team Alpha",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, officer} =
        DomainApi.create_dispatch_officer(
          %{
            badge_number: "SEC001",
            first_name: "Security",
            last_name: "Officer",
            team_id: team.id,
            tenant_id: tenant.id,
            status: :available
          },
          actor: %{tenant_id: tenant.id}
        )

      %{tenant: tenant, team: team, officer: officer}
    end

    test "critical alarm creates dispatch assignment", %{tenant: tenant, officer: officer} do
      # Create critical alarm
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "DA001",
            __event_type: :panic,
            severity: :critical,
            description: "Panic alarm - immediate response __required",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify dispatch assignment job was enqueued
      assert_enqueued(
        worker: Indrajaal.Jobs.DispatchAssignment,
        args: %{alarm_id: alarm.id}
      )

      # Process dispatch assignment
      perform_job(Indrajaal.Jobs.DispatchAssignment, %{alarm_id: alarm.id})

      # Verify assignment was created
      {:ok, assignments} =
        DomainApi.list_dispatch_assignments(
          %{
            alarm_id: alarm.id
          },
          actor: %{tenant_id: tenant.id}
        )

      assert length(assignments) > 0

      assignment = List.first(assignments)
      assert assignment.alarm_id == alarm.id
      assert assignment.officer_id == officer.id
      assert assignment.status == :assigned
    end

    test "officer response updates alarm", %{tenant: tenant, officer: officer} do
      # Create alarm and assignment
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "OR001",
            __event_type: :intrusion,
            severity: :high,
            description: "Intrusion detected",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, assignment} =
        DomainApi.create_dispatch_assignment(
          %{
            alarm_id: alarm.id,
            officer_id: officer.id,
            priority: :high,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Officer acknowledges assignment
      {:ok, _updated_assignment} =
        DomainApi.update_dispatch_assignment(
          assignment,
          %{
            status: :en_route,
            acknowledged_at: DateTime.utc_now()
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify alarm metadata is updated
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})
      assert updated_alarm.metadata["dispatch_status"] == "en_route"
      assert updated_alarm.metadata["assigned_officer"] == officer.id
    end
  end

  describe "error handling and resilience" do
    test "graceful degradation when services unavailable" do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Resilience Test Corp",
            slug: "resilience-test"
          },
          actor: %{is_system: true}
        )

      # Create alarm when notification service might be unavailable
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "RES001",
            __event_type: :fire,
            severity: :critical,
            description: "Fire detected - notification service test",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Alarm should still be created even if notifications fail
      assert alarm.id != nil
      assert alarm.__state == :triggered

      # Jobs should be enqueued for retry
      assert_enqueued(worker: Indrajaal.Jobs.AlarmEscalation)
    end

    test "cross-domain transaction rollback on failure" do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Transaction Test Corp",
            slug: "transaction-test"
          },
          actor: %{is_system: true}
        )

      # Attempt to create alarm with invalid references
      result =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "TR001",
            __event_type: :intrusion,
            severity: :high,
            description: "Transaction test alarm",
            # Non-existent device
            device_id: Ash.UUID.generate(),
            # Non-existent site
            site_id: Ash.UUID.generate(),
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Should fail due to invalid references
      assert {:error, _} = result

      # Verify no partial __data was created
      {:ok, alarms} = AlarmsApi.list_alarm_events(%{}, actor: %{tenant_id: tenant.id})
      assert not Enum.any?(alarms, &(&1.__event_code == "TR001"))
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
