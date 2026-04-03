defmodule Indrajaal.Alarms.AlarmLifecycleTrackerTest do
  @moduledoc """
  Comprehensive alarm lifecycle step tracker with detailed execution analysis.

  This module tracks the complete alarm lifecycle from initial trigger through
  resolution, providing detailed step-by-step analysis of timing, performance,
  state changes, and business rule execution at each phase.
  """

  use Indrajaal.DataCase
  # Factory functions and capture_log are already provided via DataCase

  alias Indrajaal.Alarms.{AlarmEvent, Response, Notification}
  alias Indrajaal.Core.{Tenant, Organization}
  alias Indrajaal.Sites.{Site, Zone}
  alias Indrajaal.Accounts.User
  alias Indrajaal.Devices.Device

  describe "Complete Alarm Lifecycle Tracking" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)
      zone = insert(:zone, tenant: tenant, site: site)
      device = insert(:device, tenant: tenant, site: site)
      user = insert(:user, tenant: tenant)

      # Setup lifecycle tracker
      lifecycle_tracker = %{
        phases: [],
        state_changes: [],
        performance_metrics: %{},
        business_events: [],
        error_events: [],
        audit_trail: [],
        start_time: System.monotonic_time(:microsecond),
        checkpoints: %{}
      }

      {:ok,
       tenant: tenant,
       site: site,
       zone: zone,
       device: device,
       user: user,
       lifecycle_tracker: lifecycle_tracker}
    end

    test "tracks complete alarm lifecycle with detailed step analysis", context do
      %{
        tenant: tenant,
        site: site,
        zone: zone,
        device: device,
        user: user,
        lifecycle_tracker: tracker
      } = context

      IO.puts("
# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n=== ALARM LIFECYCLE TRACKING ANALYSIS ===")
      IO.puts("Tracking ID: #{Ecto.UUID.generate()}")
      IO.puts("Start Time: #{DateTime.utc_now()}")

      # === PHASE 1: ALARM CREATION ===
      phase_1_start = System.monotonic_time(:microsecond)
      IO.puts("\n>>> PHASE 1: ALARM CREATION <<<")

      tracker =
        track_phase_start(tracker, "alarm_creation", %{
          description: "Initial alarm trigger and creation",
          expected_duration_ms: 50
        })

      # Step 1.1: Pre-creation setup
      step_start = System.monotonic_time(:microsecond)
      IO.puts("[STEP 1.1] Pre-creation setup and validation")

      alarm_attrs = %{
        event_code: "LIFE001",
        event_type: :intrusion,
        severity: :high,
        priority: 7,
        site_id: site.id,
        zone_id: zone.id,
        device_id: device.id,
        location_details: "Main entrance sensor",
        description: "Motion detected in secure area during after hours",
        sia_code: "BA",
        account_number: "ACCT12345",
        tenant_id: tenant.id
      }

      step_duration = System.monotonic_time(:microsecond) - step_start

      tracker =
        track_step(tracker, "pre_creation_setup", step_duration, %{
          attributes_prepared: map_size(alarm_attrs),
          validation_status: :passed
        })

      # Step 1.2: Database transaction and persistence
      step_start = System.monotonic_time(:microsecond)
      IO.puts("[STEP 1.2] Database transaction and alarm creation")

      capture_log(fn ->
        {:ok, alarm} = AlarmEvent.create(alarm_attrs)

        step_duration = System.monotonic_time(:microsecond) - step_start

        tracker =
          track_step(tracker, "database_creation", step_duration, %{
            alarm_id: alarm.id,
            initial_state: alarm.state,
            created_at: alarm.inserted_at
          })

        IO.puts("  Alarm Created: ID #{alarm.id}")
        IO.puts("  Initial State: #{alarm.state}")
        IO.puts("  Priority: #{alarm.priority}")
        IO.puts("  Creation Time: #{step_duration}μs")

        tracker = track_state_change(tracker, nil, alarm.state, "initial_creation", alarm.id)

        phase_1_duration = System.monotonic_time(:microsecond) - phase_1_start

        tracker =
          track_phase_end(tracker, "alarm_creation", phase_1_duration, %{
            alarm_id: alarm.id,
            success: true
          })

        # === PHASE 2: ACKNOWLEDGMENT ===
        phase_2_start = System.monotonic_time(:microsecond)
        IO.puts("\n>>> PHASE 2: ALARM ACKNOWLEDGMENT <<<")

        tracker =
          track_phase_start(tracker, "acknowledgment", %{
            description: "Alarm acknowledgment by operator",
            current_state: alarm.state,
            expected_duration_ms: 30
          })

        # Step 2.1: Pre-acknowledgment validation
        step_start = System.monotonic_time(:microsecond)
        IO.puts("[STEP 2.1] Pre-acknowledgment validation")

        ack_validations = [
          {:state_allows_ack, alarm.state == :triggered},
          {:user_authorized, user.id != nil},
          {:not_already_acked, is_nil(alarm.acknowledged_by)},
          {:within_tenant, alarm.tenant_id == tenant.id}
        ]

        validation_results =
          Enum.map(ack_validations, fn {check, result} ->
            status = if result, do: "✓", else: "✗"
            IO.puts("    #{check}: #{status}")
            {check, result}
          end)

        step_duration = System.monotonic_time(:microsecond) - step_start

        tracker =
          track_step(tracker, "ack_validation", step_duration, %{
            validations: validation_results,
            all_passed: Enum.all?(validation_results, fn {_, r} -> r end)
          })

        # Step 2.2: Acknowledgment execution
        step_start = System.monotonic_time(:microsecond)
        IO.puts("[STEP 2.2] Acknowledgment execution")

        {:ok, ack_alarm} = AlarmEvent.acknowledge(alarm, %{acknowledged_by: user.id})

        step_duration = System.monotonic_time(:microsecond) - step_start

        tracker =
          track_step(tracker, "ack_execution", step_duration, %{
            acknowledged_by: ack_alarm.acknowledged_by,
            acknowledged_at: ack_alarm.acknowledged_at,
            response_time: ack_alarm.response_time_seconds
          })

        IO.puts("  Acknowledged By: #{ack_alarm.acknowledged_by}")
        IO.puts("  Response Time: #{ack_alarm.response_time_seconds} seconds")
        IO.puts("  Execution Time: #{step_duration}μs")

        tracker =
          track_state_change(tracker, :triggered, :acknowledged, "acknowledgment", ack_alarm.id)

        phase_2_duration = System.monotonic_time(:microsecond) - phase_2_start

        tracker =
          track_phase_end(tracker, "acknowledgment", phase_2_duration, %{
            new_state: ack_alarm.state,
            response_time: ack_alarm.response_time_seconds
          })

        # === PHASE 3: INVESTIGATION ===
        phase_3_start = System.monotonic_time(:microsecond)
        IO.puts("\n>>> PHASE 3: INVESTIGATION <<<")

        tracker =
          track_phase_start(tracker, "investigation", %{
            description: "Alarm investigation and analysis",
            current_state: ack_alarm.state,
            expected_duration_ms: 100
          })

        # Step 3.1: Investigation initiation
        step_start = System.monotonic_time(:microsecond)
        IO.puts("[STEP 3.1] Investigation initiation")

        {:ok, inv_alarm} = AlarmEvent.begin_investigation(ack_alarm, %{investigating_by: user.id})

        step_duration = System.monotonic_time(:microsecond) - step_start

        tracker =
          track_step(tracker, "investigation_start", step_duration, %{
            investigating_by: inv_alarm.investigating_by,
            investigating_at: inv_alarm.investigating_at,
            auto_acknowledged: inv_alarm.acknowledged_at != nil
          })

        IO.puts("  Investigation Started By: #{inv_alarm.investigating_by}")
        IO.puts("  Investigation Time: #{step_duration}μs")

        tracker =
          track_state_change(
            tracker,
            :acknowledged,
            :investigating,
            "begin_investigation",
            inv_alarm.id
          )

        # Step 3.2: Verification process
        step_start = System.monotonic_time(:microsecond)
        IO.puts("[STEP 3.2] Verification process")

        # Simulate verification delay
        :timer.sleep(5)

        {:ok, verified_alarm} =
          AlarmEvent.verify(inv_alarm, %{
            verified?: true,
            verification_method: :video,
            verification_details: "Video confirms unauthorized person in secure area"
          })

        step_duration = System.monotonic_time(:microsecond) - step_start

        tracker =
          track_step(tracker, "verification", step_duration, %{
            verified: verified_alarm.verified?,
            verification_method: verified_alarm.verification_method,
            verification_details: verified_alarm.verification_details
          })

        IO.puts("  Verified: #{verified_alarm.verified?}")
        IO.puts("  Method: #{verified_alarm.verification_method}")
        IO.puts("  Verification Time: #{step_duration}μs")

        phase_3_duration = System.monotonic_time(:microsecond) - phase_3_start

        tracker =
          track_phase_end(tracker, "investigation", phase_3_duration, %{
            verified: verified_alarm.verified?,
            verification_method: verified_alarm.verification_method
          })

        # === PHASE 4: RESOLUTION ===
        phase_4_start = System.monotonic_time(:microsecond)
        IO.puts("\n>>> PHASE 4: RESOLUTION <<<")

        tracker =
          track_phase_start(tracker, "resolution", %{
            description: "Alarm resolution and closure",
            current_state: verified_alarm.state,
            expected_duration_ms: 40
          })

        # Step 4.1: Resolution execution
        step_start = System.monotonic_time(:microsecond)
        IO.puts("[STEP 4.1] Resolution execution")

        {:ok, resolved_alarm} =
          AlarmEvent.resolve(verified_alarm, %{
            resolved_by: user.id,
            resolution_notes:
              "Security breach confirmed. Authorities notified and premises secured."
          })

        step_duration = System.monotonic_time(:microsecond) - step_start

        tracker =
          track_step(tracker, "resolution_execution", step_duration, %{
            resolved_by: resolved_alarm.resolved_by,
            resolved_at: resolved_alarm.resolved_at,
            resolution_time: resolved_alarm.resolution_time_seconds,
            resolution_notes: resolved_alarm.resolution_notes
          })

        IO.puts("  Resolved By: #{resolved_alarm.resolved_by}")
        IO.puts("  Total Resolution Time: #{resolved_alarm.resolution_time_seconds} seconds")
        IO.puts("  Resolution Execution Time: #{step_duration}μs")

        tracker =
          track_state_change(
            tracker,
            :investigating,
            :resolved,
            "resolution",
            resolved_alarm.id
          )

        phase_4_duration = System.monotonic_time(:microsecond) - phase_4_start

        tracker =
          track_phase_end(tracker, "resolution", phase_4_duration, %{
            final_state: resolved_alarm.state,
            total_resolution_time: resolved_alarm.resolution_time_seconds
          })

        # === LIFECYCLE ANALYSIS ===
        total_lifecycle_time = System.monotonic_time(:microsecond) - tracker.start_time

        tracker =
          finalize_lifecycle_tracking(tracker, %{
            alarm_id: resolved_alarm.id,
            final_state: resolved_alarm.state,
            total_time: total_lifecycle_time,
            phases_completed: 4,
            state_transitions: 3,
            verification_completed: true,
            resolution_success: true
          })

        # Generate detailed lifecycle report
        generate_lifecycle_report(tracker, resolved_alarm)

        # Assertions for lifecycle validation
        assert resolved_alarm.state == :resolved
        assert length(tracker.phases) == 4
        # Including initial creation
        assert length(tracker.state_changes) == 4
        assert resolved_alarm.response_time_seconds != nil
        assert resolved_alarm.resolution_time_seconds != nil
        assert resolved_alarm.verified? == true
      end)
    end

    test "tracks alarm lifecycle with alternative workflow paths", context do
      %{tenant: tenant, site: site, user: user, lifecycle_tracker: tracker} = context

      IO.puts("\n=== ALTERNATIVE WORKFLOW PATH TRACKING ===")

      # Create alarm for false alarm scenario
      alarm =
        insert(:alarm_event,
          tenant: tenant,
          site: site,
          state: :triggered,
          event_type: :intrusion,
          severity: :medium
        )

      IO.puts("Tracking False Alarm Workflow Path")
      IO.puts("Alarm ID: #{alarm.id}")

      tracker =
        track_phase_start(tracker, "false_alarm_workflow", %{
          description: "False alarm identification and closure",
          alarm_id: alarm.id
        })

      # Acknowledge alarm
      {:ok, ack_alarm} = AlarmEvent.acknowledge(alarm, %{acknowledged_by: user.id})

      tracker =
        track_state_change(tracker, :triggered, :acknowledged, "acknowledgment", ack_alarm.id)

      # Begin investigation
      {:ok, inv_alarm} = AlarmEvent.begin_investigation(ack_alarm, %{investigating_by: user.id})

      tracker =
        track_state_change(
          tracker,
          :acknowledged,
          :investigating,
          "investigation",
          inv_alarm.id
        )

      # Mark as false alarm instead of resolving
      step_start = System.monotonic_time(:microsecond)

      {:ok, false_alarm} =
        AlarmEvent.mark_false_alarm(inv_alarm, %{
          resolved_by: user.id,
          false_alarm_reason: "Motion sensor triggered by cleaning crew - authorized personnel"
        })

      step_duration = System.monotonic_time(:microsecond) - step_start

      tracker =
        track_step(tracker, "false_alarm_marking", step_duration, %{
          marked_by: false_alarm.resolved_by,
          reason: false_alarm.false_alarm_reason,
          final_state: false_alarm.state
        })

      tracker =
        track_state_change(
          tracker,
          :investigating,
          :false_alarm,
          "mark_false_alarm",
          false_alarm.id
        )

      IO.puts("\n--- FALSE ALARM WORKFLOW RESULTS ---")
      IO.puts("Final State: #{false_alarm.state}")
      IO.puts("False Alarm Reason: #{false_alarm.false_alarm_reason}")
      IO.puts("Resolution Time: #{false_alarm.resolution_time_seconds} seconds")
      IO.puts("Workflow Path: triggered → acknowledged → investigating → false_alarm")

      assert false_alarm.state == :false_alarm
      assert false_alarm.false_alarm_reason != nil
    end

    test "tracks alarm lifecycle performance metrics and bottlenecks", context do
      %{tenant: tenant, site: site, user: user, lifecycle_tracker: tracker} = context

      IO.puts("\n=== PERFORMANCE METRICS AND BOTTLENECK ANALYSIS ===")

      # Create multiple alarms to analyze performance patterns
      performance_data = []

      for i <- 1..5 do
        IO.puts("\n--- Performance Test #{i} ---")

        test_start = System.monotonic_time(:microsecond)

        # Create alarm
        create_start = System.monotonic_time(:microsecond)
        alarm = insert(:alarm_event, tenant: tenant, site: site, state: :triggered)
        create_time = System.monotonic_time(:microsecond) - create_start

        # Acknowledge
        ack_start = System.monotonic_time(:microsecond)
        {:ok, ack_alarm} = AlarmEvent.acknowledge(alarm, %{acknowledged_by: user.id})
        ack_time = System.monotonic_time(:microsecond) - ack_start

        # Investigate
        inv_start = System.monotonic_time(:microsecond)
        {:ok, inv_alarm} = AlarmEvent.begin_investigation(ack_alarm, %{investigating_by: user.id})
        inv_time = System.monotonic_time(:microsecond) - inv_start

        # Resolve
        res_start = System.monotonic_time(:microsecond)

        {:ok, res_alarm} =
          AlarmEvent.resolve(inv_alarm, %{
            resolved_by: user.id,
            resolution_notes: "Performance test resolution #{i}"
          })

        res_time = System.monotonic_time(:microsecond) - res_start

        total_time = System.monotonic_time(:microsecond) - test_start

        test_metrics = %{
          test_number: i,
          create_time: create_time,
          ack_time: ack_time,
          inv_time: inv_time,
          res_time: res_time,
          total_time: total_time,
          response_time_seconds: res_alarm.response_time_seconds,
          resolution_time_seconds: res_alarm.resolution_time_seconds
        }

        performance_data = [test_metrics | performance_data]

        IO.puts("  Create: #{create_time}μs")
        IO.puts("  Acknowledge: #{ack_time}μs")
        IO.puts("  Investigate: #{inv_time}μs")
        IO.puts("  Resolve: #{res_time}μs")
        IO.puts("  Total: #{total_time}μs")
      end

      # Analyze performance metrics
      IO.puts("\n=== PERFORMANCE ANALYSIS SUMMARY ===")

      avg_create = performance_data |> Enum.map(& &1.create_time) |> average()
      avg_ack = performance_data |> Enum.map(& &1.ack_time) |> average()
      avg_inv = performance_data |> Enum.map(& &1.inv_time) |> average()
      avg_res = performance_data |> Enum.map(& &1.res_time) |> average()
      avg_total = performance_data |> Enum.map(& &1.total_time) |> average()

      IO.puts("Average Timings (μs):")
      IO.puts("  Creation: #{Float.round(avg_create, 2)}")
      IO.puts("  Acknowledgment: #{Float.round(avg_ack, 2)}")
      IO.puts("  Investigation: #{Float.round(avg_inv, 2)}")
      IO.puts("  Resolution: #{Float.round(avg_res, 2)}")
      IO.puts("  Total Workflow: #{Float.round(avg_total, 2)}")

      # Identify bottlenecks
      timings = [
        {"Creation", avg_create},
        {"Acknowledgment", avg_ack},
        {"Investigation", avg_inv},
        {"Resolution", avg_res}
      ]

      {bottleneck_phase, bottleneck_time} = Enum.max_by(timings, fn {_, time} -> time end)

      IO.puts("\nBottleneck Analysis:")
      IO.puts("  Slowest Phase: #{bottleneck_phase}")
      IO.puts("  Time: #{Float.round(bottleneck_time, 2)}μs")
      IO.puts("  Percentage of Total: #{Float.round(bottleneck_time / avg_total * 100, 1)}%")

      # Performance assertions
      assert length(performance_data) == 5
      assert avg_total > 0
      assert bottleneck_time > 0
    end
  end

  # Helper functions for lifecycle tracking

  defp track_phase_start(tracker, phase_name, metadata) do
    phase = %{
      name: phase_name,
      start_time: System.monotonic_time(:microsecond),
      end_time: nil,
      duration: nil,
      metadata: metadata,
      steps: []
    }

    IO.puts("  Phase Started: #{phase_name}")
    IO.puts("  Description: #{metadata.description}")

    Map.update(tracker, :phases, [phase], fn phases -> [phase | phases] end)
  end

  defp track_phase_end(tracker, phase_name, duration, metadata) do
    phases =
      Enum.map(tracker.phases, fn phase ->
        if phase.name == phase_name do
          %{
            phase
            | end_time: System.monotonic_time(:microsecond),
              duration: duration,
              metadata: Map.merge(phase.metadata, metadata)
          }
        else
          phase
        end
      end)

    IO.puts("  Phase Completed: #{phase_name}")
    IO.puts("  Duration: #{duration}μs (#{Float.round(duration / 1000, 2)}ms)")

    %{tracker | phases: phases}
  end

  defp track_step(tracker, step_name, duration, metadata) do
    step = %{
      name: step_name,
      duration: duration,
      timestamp: System.monotonic_time(:microsecond),
      metadata: metadata
    }

    IO.puts("    Step: #{step_name} (#{duration}μs)")

    # Add step to current phase
    phases =
      case tracker.phases do
        [current_phase | other_phases] ->
          updated_phase = %{current_phase | steps: [step | current_phase.steps]}
          [updated_phase | other_phases]

        [] ->
          []
      end

    %{tracker | phases: phases}
  end

  defp track_state_change(tracker, from_state, to_state, trigger, alarm_id) do
    state_change = %{
      from: from_state,
      to: to_state,
      trigger: trigger,
      alarm_id: alarm_id,
      timestamp: System.monotonic_time(:microsecond)
    }

    IO.puts("    State Change: #{from_state || "nil"} → #{to_state} (#{trigger})")

    Map.update(tracker, :state_changes, [state_change], fn changes ->
      [state_change | changes]
    end)
  end

  defp finalize_lifecycle_tracking(tracker, summary) do
    final_tracker = %{tracker | summary: summary, end_time: System.monotonic_time(:microsecond)}

    IO.puts("\n=== LIFECYCLE TRACKING COMPLETED ===")
    IO.puts("Alarm ID: #{summary.alarm_id}")
    IO.puts("Final State: #{summary.final_state}")

    IO.puts(
      "Total Time: #{summary.total_time}μs (#{Float.round(summary.total_time / 1000, 2)}ms)"
    )

    IO.puts("Phases: #{summary.phases_completed}")
    IO.puts("State Transitions: #{summary.state_transitions}")
    IO.puts("======================================")

    final_tracker
  end

  defp generate_lifecycle_report(tracker, alarm) do
    IO.puts("\n=== DETAILED LIFECYCLE REPORT ===")
    IO.puts("Alarm ID: #{alarm.id}")
    IO.puts("Event Type: #{alarm.event_type}")
    IO.puts("Severity: #{alarm.severity}")
    IO.puts("Final State: #{alarm.state}")
    IO.puts("")

    IO.puts("Phase Summary:")

    tracker.phases
    |> Enum.reverse()
    |> Enum.with_index(1)
    |> Enum.each(fn {phase, index} ->
      IO.puts("  #{index}. #{phase.name}")
      IO.puts("     Duration: #{phase.duration}μs")
      IO.puts("     Steps: #{length(phase.steps)}")

      if phase.metadata[:description] do
        IO.puts("     Description: #{phase.metadata.description}")
      end
    end)

    IO.puts("")
    IO.puts("State Transition History:")

    tracker.state_changes
    |> Enum.reverse()
    |> Enum.with_index(1)
    |> Enum.each(fn {change, index} ->
      IO.puts("  #{index}. #{change.from || "nil"} → #{change.to} (#{change.trigger})")
    end)

    IO.puts("")
    IO.puts("Performance Metrics:")
    IO.puts("  Response Time: #{alarm.response_time_seconds} seconds")
    IO.puts("  Resolution Time: #{alarm.resolution_time_seconds} seconds")
    IO.puts("  Verified: #{alarm.verified?}")
    IO.puts("  Resolution Notes: #{alarm.resolution_notes}")
    IO.puts("==================================")
  end

  defp average([]), do: 0

  defp average(list) do
    Enum.sum(list) / length(list)
  end
end
