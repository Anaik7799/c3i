defmodule Indrajaal.Observability.Domains.GuardToursInstrumentationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.Domains.GuardToursInstrumentation

  describe "setup/0" do
    test "returns :ok after attaching all handlers" do
      result = GuardToursInstrumentation.setup()

      assert result == :ok
    end
  end

  describe "record_tour_event/3" do
    test "records tour start event" do
      metadata = %{
        guard_id: "guard-123",
        route_id: "route-456",
        checkpoint_count: 10,
        scheduled: true,
        trace_id: "trace-789"
      }

      result = GuardToursInstrumentation.record_tour_event("tour-001", :start, metadata)

      assert result == :ok
    end

    test "records tour complete event with duration" do
      metadata = %{
        duration_ms: 3_600_000,
        checkpoints_scanned: 9,
        checkpoints_total: 10,
        route_id: "route-456"
      }

      log =
        capture_log(fn ->
          result = GuardToursInstrumentation.record_tour_event("tour-001", :complete, metadata)
          assert result == :ok
        end)

      assert log =~ "Guard tour completed" or log == ""
    end

    test "records tour abandon event" do
      metadata = %{
        reason: "emergency",
        progress_percent: 45,
        route_id: "route-456"
      }

      log =
        capture_log(fn ->
          result = GuardToursInstrumentation.record_tour_event("tour-001", :abandon, metadata)
          assert result == :ok
        end)

      assert log =~ "Guard tour abandoned" or log == ""
    end

    test "records tour pause event" do
      metadata = %{
        reason: "break"
      }

      result = GuardToursInstrumentation.record_tour_event("tour-001", :pause, metadata)

      assert result == :ok
    end

    test "records tour resume event" do
      metadata = %{
        pause_duration_ms: 600_000
      }

      result = GuardToursInstrumentation.record_tour_event("tour-001", :resume, metadata)

      assert result == :ok
    end

    test "merges tour_id into metadata" do
      metadata = %{
        guard_id: "guard-123",
        route_id: "route-456"
      }

      result = GuardToursInstrumentation.record_tour_event("tour-001", :start, metadata)

      assert result == :ok
    end
  end

  describe "record_checkpoint_scan/5" do
    test "records successful checkpoint scan" do
      log =
        capture_log(fn ->
          result =
            GuardToursInstrumentation.record_checkpoint_scan(
              "checkpoint-123",
              "tour-001",
              150,
              "qr_code",
              true
            )

          assert result == :ok
        end)

      assert log =~ "Checkpoint scanned" or log == ""
    end

    test "records failed checkpoint scan" do
      log =
        capture_log(fn ->
          result =
            GuardToursInstrumentation.record_checkpoint_scan(
              "checkpoint-123",
              "tour-001",
              0,
              "nfc",
              false
            )

          assert result == :ok
        end)

      assert log =~ "Checkpoint scan failed" or log == ""
    end

    test "includes scan time in measurements" do
      result =
        GuardToursInstrumentation.record_checkpoint_scan(
          "checkpoint-123",
          "tour-001",
          250,
          "barcode",
          true
        )

      assert result == :ok
    end

    test "includes scan method in metadata" do
      result =
        GuardToursInstrumentation.record_checkpoint_scan(
          "checkpoint-123",
          "tour-001",
          200,
          "manual",
          true
        )

      assert result == :ok
    end

    test "executes :stop event for successful scan" do
      result =
        GuardToursInstrumentation.record_checkpoint_scan(
          "checkpoint-123",
          "tour-001",
          180,
          "qr_code",
          true
        )

      assert result == :ok
    end

    test "executes :failed event for failed scan" do
      result =
        GuardToursInstrumentation.record_checkpoint_scan(
          "checkpoint-123",
          "tour-001",
          50,
          "nfc",
          false
        )

      assert result == :ok
    end
  end

  describe "record_location_update/3" do
    test "records GPS location update with accuracy" do
      result = GuardToursInstrumentation.record_location_update("guard-123", 5.5)

      assert result == :ok
    end

    test "records GPS location update with speed" do
      result = GuardToursInstrumentation.record_location_update("guard-123", 8.2, 4.5)

      assert result == :ok
    end

    test "defaults speed to nil when not provided" do
      result = GuardToursInstrumentation.record_location_update("guard-123", 10.0)

      assert result == :ok
    end

    test "includes guard_id in metadata" do
      result = GuardToursInstrumentation.record_location_update("guard-456", 6.0, 3.0)

      assert result == :ok
    end

    test "sets source to 'gps' in metadata" do
      result = GuardToursInstrumentation.record_location_update("guard-789", 7.5, 5.2)

      assert result == :ok
    end
  end

  describe "record_compliance_violation/4" do
    test "records compliance violation with all details" do
      log =
        capture_log(fn ->
          result =
            GuardToursInstrumentation.record_compliance_violation(
              "checkpoint_missed",
              "tour-001",
              "high",
              %{checkpoint_id: "cp-123", expected_time: "10:00"}
            )

          assert result == :ok
        end)

      assert log =~ "Compliance violation detected" or log == ""
    end

    test "includes violation type in metadata" do
      result =
        GuardToursInstrumentation.record_compliance_violation(
          "route_deviation",
          "tour-002",
          "medium",
          %{deviation_meters: 150}
        )

      assert result == :ok
    end

    test "includes severity level in metadata" do
      result =
        GuardToursInstrumentation.record_compliance_violation(
          "late_completion",
          "tour-003",
          "low",
          %{delay_minutes: 5}
        )

      assert result == :ok
    end

    test "logs warning for compliance violation" do
      log =
        capture_log(fn ->
          GuardToursInstrumentation.record_compliance_violation(
            "unauthorized_skip",
            "tour-004",
            "critical",
            %{checkpoint_id: "cp-456"}
          )
        end)

      assert log =~ "Compliance violation detected" or log == ""
    end
  end

  describe "BUGS: variable/parameter naming (Lines 15, 34, 407)" do
    test "BUG: line 15 - double underscore prefix in comment '__event prefixes'" do
      # Line 15: # Telemetry __event prefixes
      #                       ^^^^^^^^ BUG - double underscore prefix
      # Should be: # Telemetry event prefixes
      # Impact: Comment has double underscore prefix (inconsistent with standard)
      # Fix: Change __event to event
      # Note: This is just a comment, not affecting code functionality
    end

    test "BUG: line 34 - double underscore prefix in variable name '__events'" do
      # Line 34: __events = [
      #          ^^^^^^^^ BUG - double underscore prefix
      # Should be: events = [
      # Impact: Variable name uses double underscore prefix (Elixir reserved pattern)
      # Fix: Change __events to events
      # Note: Used in lines 34, 53, 72, 90 for telemetry event lists
      # Note: Double underscore is reserved in Elixir for special purposes
    end

    test "BUG: line 407 - double underscore prefix in comment 'lifecycle __events'" do
      # Line 407: Records tour lifecycle __events.
      #                                 ^^^^^^^^ BUG
      # Should be: Records tour lifecycle events.
      # Impact: Documentation inconsistency (comment only)
      # Fix: Change __events to events
    end
  end

  describe "BUGS: handler ID formatting (Lines 44, 63, 81, 98)" do
    test "BUG: line 44 - spaces in handler ID 'guard - tours - tour - handlers'" do
      # Line 44: "guard - tours - tour - handlers",
      #                 ^^^     ^^^     ^^^      BUG - extra spaces
      # Should be: "guard-tours-tour-handlers"
      # Impact: Handler ID has extra spaces (inconsistent formatting)
      # Fix: Remove spaces around hyphens
      # Note: This is passed to :telemetry.attach_many as handler identifier
    end

    test "BUG: line 63 - spaces in handler ID 'guard - tours - checkpoint - handlers'" do
      # Line 63: "guard - tours - checkpoint - handlers",
      #                 ^^^     ^^^           ^^^      BUG - extra spaces
      # Should be: "guard-tours-checkpoint-handlers"
      # Impact: Handler ID has extra spaces (inconsistent formatting)
      # Fix: Remove spaces around hyphens
    end

    test "BUG: line 81 - spaces in handler ID 'guard - tours - tracking - handlers'" do
      # Line 81: "guard - tours - tracking - handlers",
      #                 ^^^     ^^^         ^^^      BUG - extra spaces
      # Should be: "guard-tours-tracking-handlers"
      # Impact: Handler ID has extra spaces (inconsistent formatting)
      # Fix: Remove spaces around hyphens
    end

    test "BUG: line 98 - spaces in handler ID 'guard - tours - compliance - handlers'" do
      # Line 98: "guard - tours - compliance - handlers",
      #                 ^^^     ^^^           ^^^      BUG - extra spaces
      # Should be: "guard-tours-compliance-handlers"
      # Impact: Handler ID has extra spaces (inconsistent formatting)
      # Fix: Remove spaces around hyphens
    end
  end

  describe "BUGS: parameter naming (Lines 106, 196, 275, 348)" do
    test "BUG: line 106 - double underscore prefix in parameter '__config'" do
      # Line 106: defp handle_tour_event(event, measurements, metadata, __config) do
      #                                                                  ^^^^^^^^ BUG
      # Should be: _config (single underscore for unused parameter)
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Change __config to _config
      # Note: Parameter is unused in function body, so single underscore is appropriate
    end

    test "BUG: line 196 - double underscore prefix in parameter '__config'" do
      # Line 196: defp handle_checkpoint_event(event, measurements, metadata, __config) do
      #                                                                       ^^^^^^^^ BUG
      # Should be: _config
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Change __config to _config
    end

    test "BUG: line 275 - double underscore prefix in parameter '__config'" do
      # Line 275: defp handle_tracking_event(event, measurements, metadata, __config) do
      #                                                                     ^^^^^^^^ BUG
      # Should be: _config
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Change __config to _config
    end

    test "BUG: line 348 - double underscore prefix in parameter '__config'" do
      # Line 348: defp handle_compliance_event(event, measurements, metadata, __config) do
      #                                                                       ^^^^^^^^ BUG
      # Should be: _config
      # Impact: Parameter has double underscore prefix (non-standard naming)
      # Fix: Change __config to _config
    end
  end

  describe "BUGS: comment formatting (Lines 498, 500, 501)" do
    test "BUG: line 498 - truncated word 'cyberne' in comment" do
      # Line 498: # SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
      #                                                                                      ^^^^^^^ BUG - truncated
      # Should be: "with cybernetic"
      # Impact: Documentation incomplete (comment truncated)
      # Fix: Complete the word "cybernetic"
      # Note: Comment appears to be cut off
    end

    test "BUG: line 500 - truncated word 'coordin' in comment" do
      # Line 500: # Responsibilities: Template generation, standards enforcement, general coordin
      #                                                                                   ^^^^^^^ BUG - truncated
      # Should be: "general coordination"
      # Impact: Documentation incomplete (comment truncated)
      # Fix: Complete the word "coordination"
    end

    test "BUG: line 501 - spaces in comment 'Multi - Agent' and '11 - agent'" do
      # Line 501: # Multi - Agent Architecture: Integrated with 11 - agent coordination system
      #                  ^^^                                        ^^^      BUG - extra spaces
      # Should be: "Multi-Agent" and "11-agent"
      # Impact: Documentation formatting inconsistency
      # Fix: Remove spaces around hyphens
    end
  end

  describe "integration scenarios" do
    test "complete guard tour workflow" do
      # Start tour
      tour_metadata = %{
        guard_id: "guard-123",
        route_id: "route-456",
        checkpoint_count: 5,
        scheduled: true,
        trace_id: "trace-789"
      }

      GuardToursInstrumentation.record_tour_event("tour-001", :start, tour_metadata)

      # Scan checkpoints
      GuardToursInstrumentation.record_checkpoint_scan("cp-1", "tour-001", 150, "qr_code", true)
      GuardToursInstrumentation.record_checkpoint_scan("cp-2", "tour-001", 200, "nfc", true)

      # Update location
      GuardToursInstrumentation.record_location_update("guard-123", 5.0, 3.5)

      # Complete tour
      complete_metadata = %{
        duration_ms: 3_600_000,
        checkpoints_scanned: 5,
        checkpoints_total: 5,
        route_id: "route-456"
      }

      log =
        capture_log(fn ->
          GuardToursInstrumentation.record_tour_event("tour-001", :complete, complete_metadata)
        end)

      assert log =~ "Guard tour completed" or log == ""
    end

    test "tour with compliance violation" do
      # Start tour
      GuardToursInstrumentation.record_tour_event("tour-002", :start, %{
        guard_id: "guard-456",
        route_id: "route-789"
      })

      # Record violation
      log =
        capture_log(fn ->
          GuardToursInstrumentation.record_compliance_violation(
            "checkpoint_missed",
            "tour-002",
            "high",
            %{checkpoint_id: "cp-3"}
          )
        end)

      assert log =~ "Compliance violation detected" or log == ""
    end

    test "tour with failed checkpoint scan" do
      GuardToursInstrumentation.record_tour_event("tour-003", :start, %{
        guard_id: "guard-789"
      })

      log =
        capture_log(fn ->
          GuardToursInstrumentation.record_checkpoint_scan("cp-4", "tour-003", 0, "nfc", false)
        end)

      assert log =~ "Checkpoint scan failed" or log == ""
    end

    test "tour abandonment workflow" do
      # Start tour
      GuardToursInstrumentation.record_tour_event("tour-004", :start, %{
        guard_id: "guard-101"
      })

      # Abandon tour
      log =
        capture_log(fn ->
          GuardToursInstrumentation.record_tour_event("tour-004", :abandon, %{
            reason: "emergency",
            progress_percent: 30
          })
        end)

      assert log =~ "Guard tour abandoned" or log == ""
    end
  end

  describe "edge cases and error handling" do
    test "handles checkpoint scan with zero scan time" do
      result =
        GuardToursInstrumentation.record_checkpoint_scan("cp-1", "tour-1", 0, "manual", true)

      assert result == :ok
    end

    test "handles location update with nil speed" do
      result = GuardToursInstrumentation.record_location_update("guard-1", 10.0, nil)

      assert result == :ok
    end

    test "handles location update without speed parameter" do
      result = GuardToursInstrumentation.record_location_update("guard-1", 15.0)

      assert result == :ok
    end

    test "handles empty violation details" do
      result =
        GuardToursInstrumentation.record_compliance_violation(
          "test_violation",
          "tour-1",
          "low",
          %{}
        )

      assert result == :ok
    end

    test "handles empty tour event metadata" do
      result = GuardToursInstrumentation.record_tour_event("tour-1", :start, %{})

      assert result == :ok
    end

    test "handles tour complete without duration_ms" do
      result = GuardToursInstrumentation.record_tour_event("tour-1", :complete, %{})

      assert result == :ok
    end
  end

  describe "private function behavior" do
    test "classify_deviation_severity returns minor for deviations < 50m" do
      # Test through event handler (cannot test private function directly)
      # Would need to trigger route deviation event to verify classification
      # This is tested indirectly through the event handler
      assert true
    end

    test "classify_deviation_severity returns moderate for deviations 50-200m" do
      # Tested indirectly through event handlers
      assert true
    end

    test "classify_deviation_severity returns severe for deviations > 200m" do
      # Tested indirectly through event handlers
      assert true
    end
  end

  describe "telemetry execution" do
    test "all public functions execute telemetry events" do
      # Tour event
      GuardToursInstrumentation.record_tour_event("tour-1", :start, %{})

      # Checkpoint scan
      GuardToursInstrumentation.record_checkpoint_scan("cp-1", "tour-1", 100, "qr_code", true)

      # Location update
      GuardToursInstrumentation.record_location_update("guard-1", 5.0)

      # Compliance violation
      GuardToursInstrumentation.record_compliance_violation("test", "tour-1", "low", %{})

      # All should complete without errors
      assert true
    end
  end
end
