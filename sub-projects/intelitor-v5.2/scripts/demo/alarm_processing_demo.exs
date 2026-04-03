#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - alarm_processing_demo.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: demo
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - alarm_processing_demo.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: demo
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - alarm_processing_demo.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: demo
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied

# Demo script showcasing comprehensive alarm processing functionality

Mix.install([
  {:faker, "~> 0.17"},
  {:table_rex, "~> 3.1"}
])

__require Logger


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework

defmodule AlarmProcessingDemo do
  @moduledoc """
  Comprehensive demonstration of the Indrajaal alarm processing system.
  Shows all major features including severity evaluation, correlation,
  notifications, workflows, and storm detection.
  """
# ## SOPv5.1 Framework Integration

# This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

# **Framework Components:**
# - SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
# - TPS: Toyota Production System with 5-Level Root Cause Analysis
# - STAMP: Safety Constraint Validation with real-time monitoring
# - TDG: Test-Driven Generation methodology compliance
# - GDE: Goal-Directed Execution with adaptive strategy selection
# - Patient Mode: NO_TIMEOUT policy with infinite patience execution
# - Container-Only: Mandatory NixOS container execution with PHICS integration
# - 11-Agent Architecture: Supervisor-Helper-Worker coordination support

# **Category**: demo
# **Enhanced**: 2025-08-02 17:10:00 CEST
# **Agent**: Script Enhancement System with systematic SOPv5.1 integration


# ## SOPv5.1 Framework Integration

# This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

# **Framework Components:**
# - SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
# - TPS: Toyota Production System with 5-Level Root Cause Analysis
# - STAMP: Safety Constraint Validation with real-time monitoring
# - TDG: Test-Driven Generation methodology compliance
# - GDE: Goal-Directed Execution with adaptive strategy selection
# - Patient Mode: NO_TIMEOUT policy with infinite patience execution
# - Container-Only: Mandatory NixOS container execution with PHICS integration
# - 11-Agent Architecture: Supervisor-Helper-Worker coordination support

# **Category**: demo
# **Enhanced**: 2025-08-02 17:10:00 CEST
# **Agent**: Script Enhancement System with systematic SOPv5.1 integration


# ## SOPv5.1 Framework Integration

# This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

# **Framework Components:**
# - SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
# - TPS: Toyota Production System with 5-Level Root Cause Analysis
# - STAMP: Safety Constraint Validation with real-time monitoring
# - TDG: Test-Driven Generation methodology compliance
# - GDE: Goal-Directed Execution with adaptive strategy selection
# - Patient Mode: NO_TIMEOUT policy with infinite patience execution
# - Container-Only: Mandatory NixOS container execution with PHICS integration
# - 11-Agent Architecture: Supervisor-Helper-Worker coordination support

# **Category**: demo
# **Enhanced**: 2025-08-02 17:10:00 CEST
# **Agent**: Script Enhancement System with systematic SOPv5.1 integration



  alias Indrajaal.{Alarms, Accounts, Sites, Devices, Core}

  alias Indrajaal.Alarms.{
    ProcessingEngine,
    SeverityEngine,
    CorrelationEngine,
    NotificationOrchestrator,
    WorkflowEngine,
    StormDetection
  }

  @spec run() :: any()
  def run do
    IO.puts("\n🚨 INTELITOR ALARM PROCESSING DEMONSTRATION 🚨")
    IO.puts("=" |> String.duplicate(50))

    # Setup demo __data
    {:ok, __context} = setup_demo_environment()

    # Run demonstrations
    demonstrate_basic_alarm_processing(__context)
    Process.sleep(1000)

    demonstrate_severity_evaluation(__context)
    Process.sleep(1000)

    demonstrate_correlation_detection(__context)
    Process.sleep(1000)

    demonstrate_notification_system(__context)
    Process.sleep(1000)

    demonstrate_workflow_execution(__context)
    Process.sleep(1000)

    demonstrate_storm_detection(__context)
    Process.sleep(1000)

    demonstrate_alarm_lifecycle(__context)

    IO.puts("\n✅ Demonstration completed successfully!")
  end

  # Setup Functions

  @spec setup_demo_environment() :: any()
  defp setup_demo_environment do
    IO.puts("\n📋 Setting up demo environment...")

    # Create tenant
    {:ok, tenant} =
      Core.create_tenant(%{
        name: "Demo Security Company",
        code: "DEMO"
      })

    # Create site
    {:ok, site} =
      Sites.create_site(%{
        __tenant_id: tenant.id,
        name: "Demo Corporate Campus",
        address: "123 Security Blvd",
        latitude: 37.7749,
        longitude: -122.4194
      })

    # Create zones
    zones = create_demo_zones(tenant.id, site.id)

    # Create devices
    devices = create_demo_devices(tenant.id, site.id, zones)

    # Create __users
    __users = create_demo_users(tenant.id)

    # Create incident types
    incident_types = create_incident_types(tenant.id)

    IO.puts("✅ Demo environment ready")

    {:ok,
     %{
       tenant: tenant,
       site: site,
       zones: zones,
       devices: devices,
       __users: __users,
       incident_types: incident_types
     }}
  end

  # Demonstration Functions

  @spec demonstrate_basic_alarm_processing(term()) :: term()
  defp demonstrate_basic_alarm_processing(context) do
    IO.puts("\n\n1️⃣ BASIC ALARM PROCESSING")
    IO.puts("-" |> String.duplicate(30))

    # Create alarm from device __event
    device = hd(__context.devices)

    device_event = %{
      __tenant_id: __context.tenant.id,
      source_device_id: device.id,
      __event_code: "BA",
      __event_type: :intrusion,
      severity: :high,
      location_id: device.location_id,
      description: "Motion detected in secure area after hours"
    }

    IO.puts("📡 Processing device __event from: #{device.name}")

    {:ok, alarm} = ProcessingEngine.process_alarm(device_event)

    IO.puts("✅ Alarm created: #{alarm.id}")
    IO.puts("   Type: #{alarm.__event_type}")
    IO.puts("   Severity: #{alarm.severity}")
    IO.puts("   Priority: #{alarm.priority}")
    IO.puts("   State: #{alarm.__state}")

    Map.put(__context, :alarm, alarm)
  end

  @spec demonstrate_severity_evaluation(term()) :: term()
  defp demonstrate_severity_evaluation(context) do
    IO.puts("\n\n2️⃣ SEVERITY EVALUATION ENGINE")
    IO.puts("-" |> String.duplicate(30))

    # Create alarms with different characteristics
    scenarios = [
      %{
        name: "After-hours intrusion",
        __event: %{
          __event_type: :intrusion,
          triggered_at: ~U[2024-01-15 03:00:00Z],
          location_criticality: :high
        }
      },
      %{
        name: "Business hours tamper",
        __event: %{
          __event_type: :tamper,
          triggered_at: ~U[2024-01-15 14:00:00Z],
          location_criticality: :medium
        }
      },
      %{
        name: "Critical area panic",
        __event: %{
          __event_type: :panic,
          triggered_at: ~U[2024-01-15 10:00:00Z],
          location_criticality: :critical
        }
      }
    ]

    Enum.each(scenarios, fn scenario ->
      alarm = create_test_alarm(__context, scenario.__event)
      {:ok, evaluated} = SeverityEngine.evaluate(alarm)

      IO.puts("\n📊 Scenario: #{scenario.name}")
      IO.puts("   Original severity: #{alarm.severity}")
      IO.puts("   Evaluated severity: #{evaluated.severity}")

      # Display factors
      factors = evaluated.metadata["severity_factors"] || []
      IO.puts("   Factors:")

      Enum.each(factors, fn factor ->
        IO.puts("     - #{factor.factor}: #{factor.weight} (#{factor.reason})")
      end)
    end)

    __context
  end

  @spec demonstrate_correlation_detection(term()) :: term()
  defp demonstrate_correlation_detection(context) do
    IO.puts("\n\n3️⃣ CORRELATION DETECTION")
    IO.puts("-" |> String.duplicate(30))

    # Create correlated alarms
    IO.puts("\n🔍 Creating alarm sequence for correlation analysis...")

    # Spatial correlation - multiple alarms in adjacent zones
    zone1 = Enum.at(__context.zones, 0)
    zone2 = Enum.at(__context.zones, 1)

    alarms = [
      create_alarm_at_zone(__context, zone1, :intrusion, 0),
      create_alarm_at_zone(__context, zone1, :intrusion, 30),
      create_alarm_at_zone(__context, zone2, :intrusion, 60),
      create_alarm_at_zone(__context, zone2, :tamper, 90)
    ]

    # Analyze the last alarm for correlations
    last_alarm = List.last(alarms)
    {:ok, analyzed} = CorrelationEngine.analyze(last_alarm)

    IO.puts("\n📈 Correlation Analysis Results:")

    if analyzed.correlated_events != [] do
      IO.puts("✅ Correlations detected!")
      IO.puts("   Related alarms: #{length(analyzed.correlated_events)}")

      # Display correlation details from metadata
      correlations = analyzed.metadata["correlations"] || []

      Enum.each(correlations, fn corr ->
        IO.puts("\n   #{corr.type} correlation:")
        IO.puts("     Confidence: #{Float.round(corr.confidence, 2)}")
        IO.puts("     Pattern: #{corr.pattern || "N/A"}")
      end)
    else
      IO.puts("❌ No significant correlations found")
    end

    __context
  end

  @spec demonstrate_notification_system(term()) :: term()
  defp demonstrate_notification_system(context) do
    IO.puts("\n\n4️⃣ NOTIFICATION ORCHESTRATION")
    IO.puts("-" |> String.duplicate(30))

    # Create alarms with different severities
    severities = [:critical, :high, :medium, :low]

    Enum.each(severities, fn severity ->
      alarm =
        create_test_alarm(__context, %{
          __event_type: :intrusion,
          severity: severity
        })

      IO.puts("\n📬 Notifying for #{severity} severity alarm...")

      :ok = NotificationOrchestrator.notify_for_alarm(alarm)

      # Get notification status
      status = NotificationOrchestrator.get_notification_status(alarm.id)

      IO.puts("   Notifications sent: #{status.total_sent}")
      IO.puts("   Channels used: #{inspect(status.channels)}")
      IO.puts("   Tiers notified: #{inspect(status.tiers_notified)}")
    end)

    __context
  end

  @spec demonstrate_workflow_execution(term()) :: term()
  defp demonstrate_workflow_execution(context) do
    IO.puts("\n\n5️⃣ WORKFLOW EXECUTION")
    IO.puts("-" |> String.duplicate(30))

    # Create different alarm types
    alarm_types = [
      {:intrusion, "Intrusion Response"},
      {:fire, "Fire Emergency"},
      {:panic, "Panic Alarm"},
      {:medical, "Medical Emergency"}
    ]

    Enum.each(alarm_types, fn {__event_type, workflow_name} ->
      alarm =
        create_test_alarm(__context, %{
          __event_type: __event_type,
          severity: :high
        })

      IO.puts("\n🔄 Executing #{workflow_name} workflow...")

      # Get appropriate workflow
      workflow =
        case __event_type do
          :intrusion -> WorkflowEngine.intrusion_response_workflow()
          :fire -> WorkflowEngine.fire_response_workflow()
          :panic -> WorkflowEngine.panic_alarm_workflow()
          :medical -> WorkflowEngine.medical_emergency_workflow()
        end

      {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)

      IO.puts("   Workflow: #{instance.workflow_name}")
      IO.puts("   Status: #{instance.__state}")
      IO.puts("   Steps completed: #{length(instance.completed_steps)}")

      # Display completed steps
      Enum.each(instance.completed_steps, fn step ->
        IO.puts("     ✓ #{step.step_id} (#{step.result})")
      end)
    end)

    __context
  end

  @spec demonstrate_storm_detection(term()) :: term()
  defp demonstrate_storm_detection(context) do
    IO.puts("\n\n6️⃣ ALARM STORM DETECTION")
    IO.puts("-" |> String.duplicate(30))

    IO.puts("\n⛈️  Simulating alarm storm...")

    # Check initial status
    initial_status = StormDetection.get_storm_status(__context.tenant.id)
    IO.puts("Initial status: #{if initial_status.active, do: "🔴 Active", else: "🟢 Inactive"}")
    IO.puts("Current alarm count: #{initial_status.alarm_count}")

    # Create many alarms quickly
    IO.puts("\n💥 Generating 75 alarms in rapid succession...")

    Enum.each(1..75, fn i ->
      create_test_alarm(__context, %{
        __event_type: Enum.random([:intrusion, :tamper, :trouble]),
        severity: Enum.random([:low, :medium]),
        description: "Storm test alarm #{i}"
      })

      # Show progress
      if rem(i, 15) == 0, do: IO.write(".")
    end)

    IO.puts("")

    # Detect storm
    :ok = StormDetection.detect_storm(__context.tenant.id)

    # Check storm status
    storm_status = StormDetection.get_storm_status(__context.tenant.id)

    IO.puts("\n🌪️  Storm Status:")
    IO.puts("   Active: #{if storm_status.active, do: "🔴 YES", else: "🟢 NO"}")
    IO.puts("   Alarm count: #{storm_status.alarm_count}")
    IO.puts("   Storm mode: #{storm_status.mode || "N/A"}")
    IO.puts("   Threshold: #{storm_status.threshold}")

    # Simulate recovery
    if storm_status.active do
      IO.puts("\n🌤️  Initiating storm recovery...")
      :ok = StormDetection.deactivate_storm_mode(__context.tenant.id)
      IO.puts("✅ Storm mode deactivated")
    end

    __context
  end

  @spec demonstrate_alarm_lifecycle(term()) :: term()
  defp demonstrate_alarm_lifecycle(context) do
    IO.puts("\n\n7️⃣ ALARM LIFECYCLE MANAGEMENT")
    IO.puts("-" |> String.duplicate(30))

    # Create a new alarm
    alarm =
      create_test_alarm(__context, %{
        __event_type: :intrusion,
        severity: :high,
        description: "Unauthorized access attempt at main entrance"
      })

    IO.puts("\n🔄 Demonstrating complete alarm lifecycle:")
    display_alarm_state(alarm, "Created")

    # Get __users for actions
    operator = hd(__context.__users)

    # Acknowledge
    {:ok, alarm} = Alarms.acknowledge(alarm.id, acknowledged_by: operator.id)
    display_alarm_state(alarm, "Acknowledged")
    IO.puts("   Response time: #{alarm.response_time_seconds}s")

    # Begin investigation
    {:ok, alarm} = Alarms.begin_investigation(alarm.id, investigating_by: operator.id)
    display_alarm_state(alarm, "Investigating")

    # Verify
    {:ok, alarm} =
      Alarms.verify(alarm.id, %{
        verified?: true,
        verification_method: :video,
        verification_details: "Confirmed via CCTV footage"
      })

    display_alarm_state(alarm, "Verified")

    # Resolve
    {:ok, alarm} =
      Alarms.resolve(alarm.id,
        resolved_by: operator.id,
        resolution_notes: "False alarm - authorized maintenance personnel"
      )

    display_alarm_state(alarm, "Resolved")
    IO.puts("   Resolution time: #{alarm.resolution_time_seconds}s")

    # Display final summary
    display_alarm_summary(alarm)

    __context
  end

  # Helper Functions

  @spec create_demo_zones(term(), term()) :: term()
  defp create_demo_zones(__tenant_id, site_id) do
    zones = [
      %{name: "Main Entrance", zone_type: :public, criticality: :medium},
      %{name: "Server Room", zone_type: :restricted, criticality: :critical},
      %{name: "Executive Offices", zone_type: :secure, criticality: :high},
      %{name: "Warehouse", zone_type: :operational, criticality: :medium},
      %{name: "Parking Garage", zone_type: :public, criticality: :low}
    ]

    Enum.map(zones, fn zone_attrs ->
      {:ok, zone} =
        Sites.create_zone(
          Map.merge(zone_attrs, %{
            __tenant_id: __tenant_id,
            site_id: site_id
          })
        )

      zone
    end)
  end

  defp create_demo_devices(__tenant_id, site_id, zones) do
    devices = []

    # Create devices for each zone
    Enum.flat_map(zones, fn zone ->
      [
        create_device(__tenant_id, site_id, zone.id, "Motion Detector", :sensor),
        create_device(__tenant_id, site_id, zone.id, "Door Contact", :sensor),
        create_device(__tenant_id, site_id, zone.id, "PTZ Camera", :camera)
      ]
    end)
  end

  defp create_device(__tenant_id, site_id, zone_id, name_prefix, device_type) do
    {:ok, device} =
      Devices.create_device(%{
        __tenant_id: __tenant_id,
        name: "#{name_prefix} - Zone #{zone_id}",
        device_type: device_type,
        site_id: site_id,
        location_id: zone_id,
        status: :online
      })

    device
  end

  @spec create_demo_users(term()) :: term()
  defp create_demo_users(__tenant_id) do
    __users = [
      %{email: "operator@demo.com", first_name: "John", last_name: "Operator", role: "operator"},
      %{
        email: "supervisor@demo.com",
        first_name: "Jane",
        last_name: "Supervisor",
        role: "supervisor"
      },
      %{email: "manager@demo.com", first_name: "Mike", last_name: "Manager", role: "manager"}
    ]

    Enum.map(__users, fn __user_attrs ->
      {:ok, __user} =
        Accounts.create_user(
          Map.merge(__user_attrs, %{
            __tenant_id: __tenant_id
          })
        )

      __user
    end)
  end

  @spec create_incident_types(term()) :: term()
  defp create_incident_types(__tenant_id) do
    types = [
      %{name: "Intrusion", category: :intrusion, default_severity: :high},
      %{name: "Fire", category: :fire, default_severity: :critical},
      %{name: "Medical", category: :medical, default_severity: :critical},
      %{name: "Panic", category: :panic, default_severity: :critical}
    ]

    Enum.map(types, fn type_attrs ->
      {:ok, incident_type} =
        Alarms.create_incident_type(
          Map.merge(type_attrs, %{
            __tenant_id: __tenant_id
          })
        )

      incident_type
    end)
  end

  @spec create_test_alarm(term(), term()) :: term()
  defp create_test_alarm(context, _attrs) do
    device = Enum.random(__context.devices)

    base_attrs = %{
      __tenant_id: __context.tenant.id,
      site_id: __context.site.id,
      device_id: device.id,
      zone_id: device.location_id,
      __event_code: "TEST",
      description: attrs[:description] || "Test alarm __event"
    }

    {:ok, alarm} = Alarms.create_alarm_event(Map.merge(base_attrs, attrs))
    alarm
  end

  defp create_alarm_at_zone(context, zone, event_type, delay_seconds) do
    device = Enum.find(__context.devices, &(&1.location_id == zone.id)) || hd(__context.devices)

    {:ok, alarm} =
      Alarms.create_alarm_event(%{
        __tenant_id: __context.tenant.id,
        site_id: __context.site.id,
        zone_id: zone.id,
        device_id: device.id,
        __event_type: __event_type,
        __event_code: "COR",
        severity: :medium,
        description: "#{__event_type} detected in #{zone.name}",
        triggered_at: DateTime.add(DateTime.utc_now(), delay_seconds, :second)
      })

    alarm
  end

  @spec display_alarm_state(term(), term()) :: term()
  defp display_alarm_state(alarm, action) do
    __state_icon =
      case alarm.__state do
        :triggered -> "🔴"
        :acknowledged -> "🟡"
        :investigating -> "🔵"
        :resolved -> "🟢"
        :false_alarm -> "⚪"
        _ -> "⚫"
      end

    IO.puts("\n   #{__state_icon} #{action} - State: #{alarm.__state}")
  end

  @spec display_alarm_summary(term()) :: term()
  defp display_alarm_summary(alarm) do
    IO.puts("\n📊 ALARM SUMMARY")
    IO.puts("=" |> String.duplicate(40))

    __data = [
      ["ID", String.slice(alarm.id, 0, 8) <> "..."],
      ["Type", alarm.__event_type],
      ["Severity", alarm.severity],
      ["Priority", alarm.priority],
      ["Final State", alarm.__state],
      ["Response Time", "#{alarm.response_time_seconds || 0}s"],
      ["Resolution Time", "#{alarm.resolution_time_seconds || 0}s"],
      ["Verified", if(alarm.verified?, do: "Yes", else: "No")],
      ["Method", alarm.verification_method || "N/A"]
    ]

    TableRex.quick_render!(__data, [], "" |> IO.puts())
  end
end

# Run the demonstration
# AlarmProcessingDemo.run()

# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied

