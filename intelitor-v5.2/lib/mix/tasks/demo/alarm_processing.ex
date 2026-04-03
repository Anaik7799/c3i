defmodule Mix.Tasks.Demo.AlarmProcessing do
  @moduledoc """
  Run an interactive demonstration of the alarm processing system.

  Usage:
    mix demo.alarm_processing
  """

  use Mix.Task

  alias Indrajaal.{Accounts, Alarms, Core, Sites}

  alias Indrajaal.Alarms.{
    CorrelationEngine,
    NotificationOrchestrator,
    SeverityEngine,
    StormDetection
  }

  @shortdoc "Demonstrate alarm processing capabilities"

  require Logger

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(_args) do
    # Start the application
    Mix.Task.run("app.start")

    IO.puts("🚀 INTELITOR ALARM PROCESSING DEMONSTRATION")

    IO.puts("TARGET: INTELITOR ALARM PROCESSING DEMONSTRATION")
    IO.puts("=" |> String.duplicate(50))

    # Setup demo data
    case setup_demo_environment() do
      {:ok, context} ->
        run_demonstration_sequence(context)
        IO.puts("\n✅ Demonstration completed successfully!")
        cleanup_demo_data(context)

      {:error, reason} ->
        IO.puts("\nERROR: Failed to setup demo environment: #{inspect(reason)}")
    end
  end

  @spec run_demonstration_sequence(term()) :: term()
  defp run_demonstration_sequence(context) do
    demonstrations = [
      &demonstrate_basic_alarm_processing/1,
      &demonstrate_severity_evaluation/1,
      &demonstrate_correlation_detection/1,
      &demonstrate_notification_system/1,
      &demonstrate_workflow_execution/1,
      &demonstrate_storm_detection/1,
      &demonstrate_alarm_lifecycle/1
    ]

    Enum.each(demonstrations, fn demo_fn ->
      demo_fn.(context)
      Process.sleep(1000)
    end)
  end

  @spec setup_demo_environment() :: any()
  defp setup_demo_environment do
    IO.puts("\n📋 Setting up demo environment...")

    try do
      # Create tenant
      {:ok, tenant} =
        Core.register(%{
          name: "Demo Security Company",
          code: "DEMO#{System.unique_integer([:positive])}"
        })

      # Create site
      {:ok, site} =
        Ash.create(Sites.Site, %{
          tenant_id: tenant.id,
          name: "Demo Corporate Campus",
          address: "123 Security Blvd",
          latitude: 37.7749,
          longitude: -122.4194
        })

      # Create building
      {:ok, building} =
        Sites.Building.create(%{
          tenant_id: tenant.id,
          site_id: site.id,
          name: "Main Building",
          code: "MAIN"
        })

      # Create zones
      zones = create_demo_zones(tenant.id, site.id)

      # Create devices
      devices = create_demo_devices(tenant.id, site.id, zones)

      # Create users
      users = create_demo_users(tenant.id)

      # Create alarm workflow templates
      workflows = create_demo_workflows(tenant.id)

      IO.puts("✓ Demo environment ready")

      {:ok,
       %{
         tenant: tenant,
         site: site,
         building: building,
         zones: zones,
         devices: devices,
         users: users,
         workflows: workflows
       }}
    rescue
      e ->
        Logger.error("Failed to setup demo environment: #{inspect(e)}")
        {:error, e}
    end
  end

  @spec create_demo_zones(term(), term()) :: term()
  defp create_demo_zones(tenant_id, site_id) do
    zones = [
      %{name: "Perimeter", code: "PERIM", type: :outdoor, criticality: :high},
      %{name: "Lobby", code: "LOBBY", type: :public, criticality: :medium},
      %{name: "Server Room", code: "SERVER", type: :restricted, criticality: :critical},
      %{name: "Vault", code: "VAULT", type: :restricted, criticality: :critical},
      %{name: "Office Area", code: "OFFICE", type: :internal, criticality: :low}
    ]

    Enum.map(zones, fn zone_attrs ->
      {:ok, zone} =
        Sites.Zone.create(
          Map.merge(zone_attrs, %{
            tenant_id: tenant_id,
            site_id: site_id
          })
        )

      zone
    end)
  end

  defp create_demo_devices(tenant_id, site_id, zones) do
    # Create devices for each zone
    Enum.flat_map(zones, fn zone ->
      [
        create_device(tenant_id, site_id, zone.id, "Motion Sensor", :sensor),
        create_device(tenant_id, site_id, zone.id, "Door Contact", :sensor),
        create_device(tenant_id, site_id, zone.id, "Camera", :camera)
      ]
    end)
  end

  @spec create_device(String.t(), String.t(), String.t(), String.t(), atom()) ::
          any()
  defp create_device(tenant_id, site_id, zone_id, name, type) do
    {:ok, device_type} =
      Indrajaal.Devices.DeviceType.create(%{
        tenant_id: tenant_id,
        name: "#{name} Type",
        category: type
      })

    {:ok, device} =
      Ash.create(Indrajaal.Devices.Device, %{
        tenant_id: tenant_id,
        site_id: site_id,
        zone_id: zone_id,
        device_type_id: device_type.id,
        name: "#{name} - Zone #{zone_id}",
        status: :online
      })

    device
  end

  @spec create_demo_users(term()) :: term()
  defp create_demo_users(tenant_id) do
    users_data = [
      %{name: "John Operator", role: :operator, email: "operator@demo.com"},
      %{name: "Jane Supervisor", role: :supervisor, email: "supervisor@demo.com"},
      %{name: "Bob Executive", role: :executive, email: "executive@demo.com"}
    ]

    Enum.map(users_data, fn user_attrs ->
      {:ok, user} =
        Ash.create(
          Accounts.User,
          Map.merge(user_attrs, %{
            tenant_id: tenant_id,
            password: "Demo123!"
          })
        )

      user
    end)
  end

  @spec create_demo_workflows(term()) :: term()
  defp create_demo_workflows(_tenant_id) do
    # These would be created through the workflow system
    # For now, returning empty list
    []
  end

  @spec demonstrate_basic_alarm_processing(term()) :: term()
  defp demonstrate_basic_alarm_processing(context) do
    IO.puts("\n🔔 1. BASIC ALARM PROCESSING")
    IO.puts("─" |> String.duplicate(40))

    device = hd(context.devices)

    IO.puts("Creating alarm from device event...")

    device_event = %{
      device_id: device.id,
      event_type: :intrusion,
      event_code: "MOTION_DETECTED",
      description: "Motion detected in restricted area",
      metadata: %{
        sensor_value: 95,
        confidence: 0.98
      }
    }

    case AlarmProcessor.process_alarm(device_event) do
      {:error, reason} ->
        IO.puts("✗ Failed to create alarm: #{inspect(reason)}")
        nil
    end
  end

  @spec demonstrate_severity_evaluation(term()) :: term()
  defp demonstrate_severity_evaluation(context) do
    IO.puts("\n⚖️  2. SEVERITY EVALUATION")
    IO.puts("─" |> String.duplicate(40))

    # Create a test alarm
    {:ok, alarm} =
      Ash.create(Indrajaal.Alarms.Alarm, %{
        tenant_id: context.tenant.id,
        site_id: context.site.id,
        zone_id: hd(context.zones).id,
        device_id: hd(context.devices).id,
        event_type: :intrusion,
        event_code: "INTRUSION_001",
        description: "Test intrusion for severity evaluation"
      })

    IO.puts("Evaluating severity for alarm #{alarm.id}...")

    case SeverityEngine.evaluate(alarm) do
      {:ok, updated_alarm} ->
        IO.puts("✓ Severity evaluated: #{updated_alarm.severity}")

        if updated_alarm.metadata["severity_factors"] do
          IO.puts("\nSeverity Factors:")

          Enum.each(updated_alarm.metadata["severity_factors"], fn factor ->
            IO.puts("  • #{factor["factor"]}: ×#{factor["weight"]} - #{factor["reason"]}")
          end)
        end

      {:error, reason} ->
        IO.puts("✗ Failed to evaluate severity: #{inspect(reason)}")
    end
  end

  @spec demonstrate_correlation_detection(term()) :: term()
  defp demonstrate_correlation_detection(context) do
    IO.puts("\n🔗 3. CORRELATION DETECTION")
    IO.puts("─" |> String.duplicate(40))

    # Create multiple related alarms
    IO.puts("Creating multiple alarms for correlation...")

    zones = Enum.take(context.zones, 3)

    alarms =
      Enum.map(zones, fn zone ->
        {:ok, alarm} =
          Ash.create(Indrajaal.Alarms.Alarm, %{
            tenant_id: context.tenant.id,
            site_id: context.site.id,
            zone_id: zone.id,
            device_id: hd(context.devices).id,
            event_type: :intrusion,
            event_code: "MOTION_#{zone.code}",
            description: "Motion in #{zone.name}"
          })

        alarm
      end)

    # Analyze correlation for the last alarm
    last_alarm = List.last(alarms)

    {:ok, result} = CorrelationEngine.analyze(last_alarm)
    IO.puts("✓ Correlation analysis complete")

    if result.metadata["correlations"] do
      IO.puts("\nDetected Correlations:")

      Enum.each(result.metadata["correlations"], fn corr ->
        if corr["correlated"] do
          IO.puts("  • #{corr["type"]}: #{corr["confidence"] * 100}% confidence")
        end
      end)
    end
  end

  @spec demonstrate_notification_system(term()) :: term()
  defp demonstrate_notification_system(context) do
    IO.puts("\n📢 4. NOTIFICATION SYSTEM")
    IO.puts("─" |> String.duplicate(40))

    # Create a critical alarm
    {:ok, alarm} =
      Ash.create(Indrajaal.Alarms.Alarm, %{
        tenant_id: context.tenant.id,
        site_id: context.site.id,
        zone_id: hd(context.zones).id,
        device_id: hd(context.devices).id,
        event_type: :panic,
        event_code: "PANIC_001",
        severity: :critical,
        description: "Panic button activated"
      })

    IO.puts("Sending notifications for critical alarm...")

    case NotificationOrchestrator.notify_for_alarm(alarm) do
      :ok ->
        IO.puts("✓ Notifications sent successfully")

        # Show notification status
        status = NotificationOrchestrator.get_notification_status(alarm.id)
        IO.puts("\nNotification Status:")
        IO.puts("  • Total sent: #{status.total_sent}")
        IO.puts("  • Channels used: #{Enum.join(status.channels, ", ")}")
        IO.puts("  • Tiers notified: #{Enum.join(status.tiers_notified, ", ")}")

      {:error, reason} ->
        IO.puts("✗ Notification failed: #{inspect(reason)}")
    end
  end

  @spec demonstrate_workflow_execution(term()) :: term()
  defp demonstrate_workflow_execution(context) do
    IO.puts("\n🔄 5. WORKFLOW EXECUTION")
    IO.puts("─" |> String.duplicate(40))

    # Create an alarm that triggers workflow
    {:ok, alarm} =
      Ash.create(Indrajaal.Alarms.Alarm, %{
        tenant_id: context.tenant.id,
        site_id: context.site.id,
        zone_id: hd(context.zones).id,
        device_id: hd(context.devices).id,
        event_type: :intrusion,
        event_code: "INTRUSION_WF",
        severity: :high,
        description: "Intrusion detected - workflow trigger"
      })

    IO.puts("Triggering workflow for alarm...")

    case WorkflowEngine.trigger_for_alarm(alarm) do
      {:error, reason} ->
        IO.puts("✗ Workflow failed: #{inspect(reason)}")
    end
  end

  @spec demonstrate_storm_detection(term()) :: term()
  defp demonstrate_storm_detection(context) do
    IO.puts("\n⛈️  6. STORM DETECTION")
    IO.puts("─" |> String.duplicate(40))

    IO.puts("Simulating alarm storm...")

    # Check current storm status
    storm_status = StormDetection.get_storm_status(context.tenant.id)

    if storm_status.active do
      IO.puts("⚠️  Storm detected: #{storm_status.mode}")
      IO.puts("Mitigation measures activated:")

      case storm_status.mode do
        :light ->
          IO.puts("  • Batching notifications")
          IO.puts("  • 30 - second consolidation window")

        :moderate ->
          IO.puts("  • Grouping related alarms")
          IO.puts("  • Reduced notification channels")

        :severe ->
          IO.puts("  • Critical alarms only")
          IO.puts("  • Executive notifications")

        :critical ->
          IO.puts("  • Emergency mode active")
          IO.puts("  • All non - critical processing suspended")
      end
    else
      IO.puts("✓ No storm detected - system operating normally")
    end
  end

  @spec demonstrate_alarm_lifecycle(term()) :: term()
  defp demonstrate_alarm_lifecycle(context) do
    IO.puts("\n🔄 7. ALARM LIFECYCLE")
    IO.puts("─" |> String.duplicate(40))

    # Create and process an alarm through its lifecycle
    {:ok, alarm} =
      Ash.create(Indrajaal.Alarms.Alarm, %{
        tenant_id: context.tenant.id,
        site_id: context.site.id,
        zone_id: hd(context.zones).id,
        device_id: hd(context.devices).id,
        event_type: :tamper,
        event_code: "TAMPER_001",
        description: "Panel tamper detected"
      })

    IO.puts("Alarm lifecycle demonstration:")
    IO.puts("1. Created: #{alarm.state}")

    # Acknowledge
    {:ok, alarm} = Alarms.acknowledge(alarm, %{acknowledged_by_id: hd(context.__users).id})
    IO.puts("2. Acknowledged: #{alarm.state}")

    # Investigate
    {:ok, alarm} = Alarms.begin_investigation(alarm, %{assigned_to_id: hd(context.__users).id})
    IO.puts("3. Investigating: #{alarm.state}")

    # Resolve
    {:ok, alarm} =
      Indrajaal.Alarms.resolve(alarm, %{
        resolved_by: hd(context.__users).id,
        resolution_notes: "False alarm - maintenance activity"
      })

    IO.puts("4. Resolved: #{alarm.state}")

    IO.puts("\n✓ Complete alarm lifecycle demonstrated")
  end

  @spec cleanup_demo_data(term()) :: term()
  defp cleanup_demo_data(context) do
    IO.puts("\n🧹 Cleaning up demo data...")

    # Delete tenant (cascades to all related data)
    Core.archive(context.tenant)

    IO.puts("✓ Demo data cleaned up")
  end
end
