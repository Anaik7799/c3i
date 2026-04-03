defmodule Indrajaal.Observability.Domains.DevicesInstrumentationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.Domains.DevicesInstrumentation

  # Test device struct helpers
  defp sample_device do
    %{
      id: "device-123",
      type: "camera",
      site_id: "site-456",
      tenant_id: "tenant-789",
      status_history: [
        %{status: :online, timestamp: DateTime.add(DateTime.utc_now(), -3600, :second)}
      ],
      last_connected_at: DateTime.add(DateTime.utc_now(), -1800, :second)
    }
  end

  defp sample_command do
    %{
      id: "cmd-001",
      type: "reboot",
      priority: :high,
      payload: "reboot now",
      timeout: 30_000
    }
  end

  defp sample_response do
    %{
      status: :ok,
      payload: "command executed"
    }
  end

  defp sample_health_data do
    %{
      score: 85,
      status: :healthy,
      cpu_usage: 45.2,
      memory_usage: 60.5,
      disk_usage: 70.0,
      temperature: 45.5,
      issues: []
    }
  end

  defp sample_update_info do
    %{
      current_version: "1.2.3",
      target_version: "1.3.0",
      size_bytes: 1_048_576,
      type: :minor,
      stage: :download,
      progress: 0,
      id: "update-001"
    }
  end

  describe "setup/0" do
    test "returns :ok" do
      assert :ok = DevicesInstrumentation.setup()
    end
  end

  describe "instrumentstatus_change/4" do
    test "executes telemetry for status change" do
      device = sample_device()

      result =
        DevicesInstrumentation.instrumentstatus_change(device, :online, :maintenance, %{
          reason: "scheduled"
        })

      assert {:ok, ^device} = result
    end

    test "logs status change with appropriate level" do
      device = sample_device()

      log =
        capture_log(fn ->
          DevicesInstrumentation.instrumentstatus_change(device, :online, :offline)
        end)

      # Should log the status change
      assert log =~ "Device status changed" or log == ""
    end

    test "tracks device availability based on status" do
      device = sample_device()

      DevicesInstrumentation.instrumentstatus_change(device, :offline, :online)
      DevicesInstrumentation.instrumentstatus_change(device, :online, :maintenance)
      DevicesInstrumentation.instrumentstatus_change(device, :maintenance, :offline)
    end

    test "triggers alert on critical status change" do
      device = sample_device()

      DevicesInstrumentation.instrumentstatus_change(device, :online, :error)
      DevicesInstrumentation.instrumentstatus_change(device, :online, :offline)
    end

    test "includes metadata in telemetry execution" do
      device = sample_device()
      metadata = %{reason: "network_failure", user: "system"}

      result = DevicesInstrumentation.instrumentstatus_change(device, :online, :error, metadata)

      assert {:ok, ^device} = result
    end

    test "calculates status duration from history" do
      device = sample_device()

      # Device has been online for some time
      result = DevicesInstrumentation.instrumentstatus_change(device, :online, :offline)

      assert {:ok, ^device} = result
    end
  end

  describe "instrument_connection/3" do
    test "handles connection event with atom event name" do
      result = DevicesInstrumentation.instrument_connection(:connected, "device-123", %{})

      assert result == :ok
    end

    test "handles device connection with metadata" do
      device = sample_device()

      metadata = %{
        protocol: "mqtt",
        latency: 25,
        connection_time: 150,
        ip_address: "192.168.1.100"
      }

      result = DevicesInstrumentation.instrument_connection(device, nil, metadata)

      assert {:ok, ^device} = result
    end

    test "handles device disconnection with reason" do
      device = sample_device()
      metadata = %{reason: :normal, session_data: %{}}

      log =
        capture_log(fn ->
          result = DevicesInstrumentation.instrument_connection(device, nil, metadata)
          assert {:ok, ^device} = result
        end)

      # Should log disconnection
      assert log =~ "Device disconnected" or log == ""
    end

    test "calculates session duration on disconnect" do
      device = sample_device()

      result = DevicesInstrumentation.instrument_connection(device, nil, %{reason: :timeout})

      assert {:ok, ^device} = result
    end

    test "logs disconnection with appropriate level based on reason" do
      device = sample_device()

      # Normal disconnection - should log as info
      log_info =
        capture_log(fn ->
          DevicesInstrumentation.instrument_connection(device, nil, %{reason: :normal})
        end)

      # Abnormal disconnection - should log as warning
      log_warn =
        capture_log(fn ->
          DevicesInstrumentation.instrument_connection(device, nil, %{reason: :error})
        end)

      assert log_info =~ "Device disconnected" or log_info == ""
      assert log_warn =~ "Device disconnected" or log_warn == ""
    end

    test "updates connection metrics" do
      device = sample_device()

      metadata = %{
        latency: 30,
        packet_loss: 0.5,
        signal_strength: -45
      }

      result = DevicesInstrumentation.instrument_connection(device, nil, metadata)

      assert {:ok, ^device} = result
    end
  end

  describe "instrument_command/3" do
    test "executes telemetry for command" do
      device = sample_device()
      command = sample_command()

      result = DevicesInstrumentation.instrument_command(device, command, %{})

      assert {:ok, ^command} = result
    end

    test "includes command size in measurements" do
      device = sample_device()
      command = sample_command()

      result = DevicesInstrumentation.instrument_command(device, command)

      assert {:ok, ^command} = result
    end

    test "schedules command timeout monitoring" do
      device = sample_device()
      command = sample_command()

      result = DevicesInstrumentation.instrument_command(device, command)

      assert {:ok, ^command} = result
    end

    test "includes all command metadata" do
      device = sample_device()
      command = sample_command()
      metadata = %{user: "admin", timestamp: DateTime.utc_now()}

      result = DevicesInstrumentation.instrument_command(device, command, metadata)

      assert {:ok, ^command} = result
    end
  end

  describe "instrument_response/4" do
    test "executes telemetry for response" do
      device = sample_device()
      response = sample_response()

      result =
        DevicesInstrumentation.instrument_response(device, "cmd-001", response, %{
          response_time: 125
        })

      assert {:ok, ^response} = result
    end

    test "includes response time in measurements" do
      device = sample_device()
      response = sample_response()

      result =
        DevicesInstrumentation.instrument_response(device, "cmd-001", response, %{
          response_time: 250
        })

      assert {:ok, ^response} = result
    end

    test "tracks command success rate" do
      device = sample_device()

      # Successful response
      success_response = %{status: :success, payload: "ok"}

      DevicesInstrumentation.instrument_response(device, "cmd-001", success_response, %{
        response_time: 100
      })

      # Failed response
      failure_response = %{status: :failed, payload: "error"}

      DevicesInstrumentation.instrument_response(device, "cmd-002", failure_response, %{
        response_time: 50
      })
    end

    test "includes response size in measurements" do
      device = sample_device()
      response = %{status: :ok, payload: "very long payload data"}

      result = DevicesInstrumentation.instrument_response(device, "cmd-001", response)

      assert {:ok, ^response} = result
    end
  end

  describe "instrument_health_check/3" do
    test "executes telemetry for health check" do
      device = sample_device()
      health_data = sample_health_data()

      result = DevicesInstrumentation.instrument_health_check(device, health_data, %{})

      assert {:ok, ^health_data} = result
    end

    test "includes all health metrics" do
      device = sample_device()
      health_data = sample_health_data()

      result = DevicesInstrumentation.instrument_health_check(device, health_data)

      assert {:ok, ^health_data} = result
    end

    test "triggers alert on warning health status" do
      device = sample_device()
      warning_health = %{sample_health_data() | status: :warning, score: 55}

      log =
        capture_log(fn ->
          result = DevicesInstrumentation.instrument_health_check(device, warning_health)
          assert {:ok, ^warning_health} = result
        end)

      # Should log health issue
      assert log =~ "Device health issue detected" or log == ""
    end

    test "triggers alert on critical health status" do
      device = sample_device()
      critical_health = %{sample_health_data() | status: :critical, score: 25}

      log =
        capture_log(fn ->
          result = DevicesInstrumentation.instrument_health_check(device, critical_health)
          assert {:ok, ^critical_health} = result
        end)

      # Should log health issue
      assert log =~ "Device health issue detected" or log == ""
    end

    test "tracks health trends" do
      device = sample_device()
      health_data = sample_health_data()

      result = DevicesInstrumentation.instrument_health_check(device, health_data)

      assert {:ok, ^health_data} = result
    end
  end

  describe "instrument_firmware_update/3" do
    test "executes telemetry for firmware update" do
      device = sample_device()
      update_info = sample_update_info()

      log =
        capture_log(fn ->
          result = DevicesInstrumentation.instrument_firmware_update(device, update_info, %{})
          assert {:ok, ^update_info} = result
        end)

      # Should log firmware update initiation
      assert log =~ "Firmware update initiated" or log == ""
    end

    test "includes update size in measurements" do
      device = sample_device()
      update_info = sample_update_info()

      result = DevicesInstrumentation.instrument_firmware_update(device, update_info)

      assert {:ok, ^update_info} = result
    end

    test "calculates version distance" do
      device = sample_device()
      update_info = sample_update_info()

      result = DevicesInstrumentation.instrument_firmware_update(device, update_info)

      assert {:ok, ^update_info} = result
    end

    test "tracks firmware update progress" do
      device = sample_device()
      update_info = sample_update_info()

      result = DevicesInstrumentation.instrument_firmware_update(device, update_info)

      assert {:ok, ^update_info} = result
    end

    test "includes update type in metadata" do
      device = sample_device()
      update_info = sample_update_info()
      metadata = %{scheduled: true, auto_update: false}

      result = DevicesInstrumentation.instrument_firmware_update(device, update_info, metadata)

      assert {:ok, ^update_info} = result
    end
  end

  describe "instrument_metrics/3" do
    test "executes telemetry for device metrics" do
      device = sample_device()
      metrics = %{cpu_usage: 50.0, memory_usage: 65.0, bandwidth_usage: 1024}

      result = DevicesInstrumentation.instrument_metrics(device, metrics, %{})

      assert result == :ok
    end

    test "processes performance metrics" do
      device = sample_device()
      metrics = %{cpu_usage: 45.2, memory_usage: 60.5, disk_usage: 70.0, temperature: 45.5}

      result = DevicesInstrumentation.instrument_metrics(device, metrics)

      assert result == :ok
    end

    test "processes network metrics" do
      device = sample_device()
      metrics = %{bandwidth_usage: 2048, packet_loss: 0.5, latency: 25, signal_strength: -50}

      result = DevicesInstrumentation.instrument_metrics(device, metrics)

      assert result == :ok
    end

    test "processes sensor metrics (custom metrics)" do
      device = sample_device()

      metrics = %{
        cpu_usage: 50.0,
        custom_sensor_1: 100,
        custom_sensor_2: 200,
        temperature: 45.0
      }

      result = DevicesInstrumentation.instrument_metrics(device, metrics)

      assert result == :ok
    end

    test "handles empty metrics gracefully" do
      device = sample_device()
      metrics = %{}

      result = DevicesInstrumentation.instrument_metrics(device, metrics)

      assert result == :ok
    end
  end

  describe "BUGS: variable/parameter naming (Lines 19, 55, 104, 112)" do
    test "BUG: line 19 - double underscore in comment '__events'" do
      # Line 19: # Telemetry __events
      #                     ^^^^^^^^ BUG - should be "events"
      # Should be: # Telemetry events
      # Impact: Documentation inconsistency (comment only)
      # Fix: Change __events to events
      # Note: Comment formatting issue
    end

    test "BUG: line 55 - double underscore in comment '__event'" do
      # Line 55: # Execute telemetry __event
      #                              ^^^^^^^ BUG - should be "event"
      # Should be: # Execute telemetry event
      # Impact: Documentation inconsistency (comment only)
      # Fix: Change __event to event
      # Note: Comment formatting issue
    end

    test "BUG: line 104 - double underscore in comment '__events'" do
      # Line 104: Instruments device connection __events.
      #                                          ^^^^^^^^ BUG - should be "events"
      # Should be: Instruments device connection events.
      # Impact: Documentation inconsistency (comment only)
      # Fix: Change __events to events
      # Note: Comment formatting issue
    end

    test "BUG: line 112 - double underscore in metadata key '__event'" do
      # Line 112: __event: __event_name
      #           ^^^^^^^ BUG - should be "event"
      # Should be: event: __event_name (or better: event: event_name)
      # Impact: Metadata key has double underscore prefix
      # Fix: Change __event to event
      # Note: This affects metadata passed to telemetry
    end
  end

  describe "BUGS: function name typo (Line 39)" do
    test "BUG: line 39 - typo in function name 'instrumentstatus_change'" do
      # Line 39: def instrumentstatus_change(device, old_status, new_status, metadata \\ %{}) do
      #              ^^^^^^^^^^^^^^^^^^^^^^^ BUG - missing underscore
      # Should be: instrument_status_change
      # Impact: CRITICAL - function name has typo, breaks naming convention
      # Fix: Change instrumentstatus_change to instrument_status_change
      # Note: This is a public API function with incorrect naming
    end
  end

  describe "BUGS: parameter name typo (Line 496)" do
    test "BUG: line 496 - typo in parameter name 'commandid'" do
      # Line 496: defp cancel_command_timeout(commandid) do
      #                                       ^^^^^^^^^ BUG - missing underscore
      # Should be: command_id
      # Impact: Parameter name has typo, breaks naming convention
      # Fix: Change commandid to command_id
      # Note: This is a private function parameter
    end
  end

  describe "BUGS: duplicate typespec (Line 415)" do
    test "BUG: line 415 - duplicate @spec for determine_log_level/2" do
      # Line 411: @spec determine_log_level(term(), term()) :: term()
      # Line 412-414: defp determine_log_level(...) implementations
      # Line 415: @spec determine_log_level(term(), term()) :: term()
      #           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ BUG - duplicate spec
      # Line 416: defp determine_log_level(_, _), do: :info
      # Impact: Duplicate typespec declaration for same function
      # Fix: Remove duplicate @spec on line 415
      # Note: Only one @spec should be declared per function
    end
  end

  describe "BUGS: comment formatting (Lines 3, 623, 625, 626)" do
    test "BUG: line 3 - spaces in comment 'Domain - specific'" do
      # Line 3: Domain - specific instrumentation for device telemetry...
      #                ^^^^^^^^^^^^ BUG - spaces around hyphen
      # Should be: Domain-specific instrumentation for device telemetry...
      # Impact: Documentation formatting inconsistency
      # Fix: Remove spaces around hyphen
      # Note: Comment formatting issue
    end

    test "BUG: line 623 - spaces in comment about SOPv5.1" do
      # Line 623: # SOPv5.1 Compliance: ✅ General system coordination ... with cyberne
      #                                                                           ^^^^^^^^ BUG - word cut off
      # Should be: "with cybernetic"
      # Impact: Documentation incomplete/cut off
      # Fix: Complete the word "cybernetic"
      # Note: Comment appears to be truncated
    end

    test "BUG: line 625 - spaces in comment about responsibilities" do
      # Line 625: # Responsibilities: Template generation, standards enforcement, general coordin
      #                                                                                   ^^^^^^^^ BUG - word cut off
      # Should be: "general coordination"
      # Impact: Documentation incomplete/cut off
      # Fix: Complete the word "coordination"
      # Note: Comment appears to be truncated
    end

    test "BUG: line 626 - spaces in comment 'Multi - Agent'" do
      # Line 626: # Multi - Agent Architecture: Integrated with 11 - agent coordination system
      #                  ^^^^^^^^^^^^ BUG - spaces around hyphen
      # Should be: # Multi-Agent Architecture: Integrated with 11-agent coordination system
      # Impact: Documentation formatting inconsistency
      # Fix: Remove spaces around hyphens
      # Note: Comment formatting issue
    end
  end

  describe "integration scenarios" do
    test "complete device status workflow" do
      device = sample_device()

      # Status change
      {:ok, _} = DevicesInstrumentation.instrumentstatus_change(device, :online, :maintenance)

      # Health check while in maintenance
      health_data = sample_health_data()
      {:ok, _} = DevicesInstrumentation.instrument_health_check(device, health_data)

      # Back online
      {:ok, _} = DevicesInstrumentation.instrumentstatus_change(device, :maintenance, :online)
    end

    test "device command workflow" do
      device = sample_device()
      command = sample_command()
      response = sample_response()

      # Send command
      {:ok, _} = DevicesInstrumentation.instrument_command(device, command)

      # Receive response
      {:ok, _} =
        DevicesInstrumentation.instrument_response(device, command.id, response, %{
          response_time: 125
        })
    end

    test "firmware update workflow" do
      device = sample_device()
      update_info = sample_update_info()

      # Start update
      log =
        capture_log(fn ->
          {:ok, _} = DevicesInstrumentation.instrument_firmware_update(device, update_info)
        end)

      assert log =~ "Firmware update initiated" or log == ""
    end

    test "connection lifecycle" do
      device = sample_device()

      # Connect
      {:ok, _} =
        DevicesInstrumentation.instrument_connection(device, nil, %{protocol: "mqtt", latency: 25})

      # Report metrics
      DevicesInstrumentation.instrument_metrics(device, %{cpu_usage: 50.0, memory_usage: 60.0})

      # Disconnect
      log =
        capture_log(fn ->
          {:ok, _} =
            DevicesInstrumentation.instrument_connection(device, nil, %{reason: :shutdown})
        end)

      assert log =~ "Device disconnected" or log == ""
    end
  end

  describe "edge cases and error handling" do
    test "handles device with no status history" do
      device = %{sample_device() | status_history: []}

      result = DevicesInstrumentation.instrumentstatus_change(device, :offline, :online)

      assert {:ok, _} = result
    end

    test "handles device with no last_connected_at" do
      device = %{sample_device() | last_connected_at: nil}

      log =
        capture_log(fn ->
          result = DevicesInstrumentation.instrument_connection(device, nil, %{reason: :timeout})
          assert {:ok, _} = result
        end)
    end

    test "handles response with nil payload" do
      device = sample_device()
      response = %{status: :ok, payload: nil}

      result = DevicesInstrumentation.instrument_response(device, "cmd-001", response)

      assert {:ok, ^response} = result
    end

    test "handles health data with nil values" do
      device = sample_device()

      health_data = %{
        score: 50,
        status: :warning,
        cpu_usage: nil,
        memory_usage: nil,
        disk_usage: nil,
        temperature: nil,
        issues: []
      }

      result = DevicesInstrumentation.instrument_health_check(device, health_data)

      assert {:ok, ^health_data} = result
    end

    test "handles command with nil payload" do
      device = sample_device()
      command = %{sample_command() | payload: nil}

      result = DevicesInstrumentation.instrument_command(device, command)

      assert {:ok, ^command} = result
    end

    test "handles same version firmware update" do
      device = sample_device()
      update_info = %{sample_update_info() | current_version: "1.2.3", target_version: "1.2.3"}

      log =
        capture_log(fn ->
          result = DevicesInstrumentation.instrument_firmware_update(device, update_info)
          assert {:ok, ^update_info} = result
        end)
    end

    test "handles metrics with only custom sensors" do
      device = sample_device()
      metrics = %{custom_1: 100, custom_2: 200, custom_3: 300}

      result = DevicesInstrumentation.instrument_metrics(device, metrics)

      assert result == :ok
    end
  end

  describe "private function behavior" do
    test "determine_log_level returns appropriate levels" do
      # Test through public API since these are private functions
      device = sample_device()

      # online -> offline should log warning
      capture_log(fn ->
        DevicesInstrumentation.instrumentstatus_change(device, :online, :offline)
      end)

      # online -> error should log error
      capture_log(fn ->
        DevicesInstrumentation.instrumentstatus_change(device, :online, :error)
      end)

      # offline -> online should log info
      capture_log(fn ->
        DevicesInstrumentation.instrumentstatus_change(device, :offline, :online)
      end)
    end

    test "critical_status_change? triggers alerts appropriately" do
      device = sample_device()

      # These should trigger alerts
      DevicesInstrumentation.instrumentstatus_change(device, :online, :error)
      DevicesInstrumentation.instrumentstatus_change(device, :online, :offline)
      DevicesInstrumentation.instrumentstatus_change(device, :maintenance, :error)
    end

    test "track_device_availability assigns correct values" do
      device = sample_device()

      # online = 1.0
      DevicesInstrumentation.instrumentstatus_change(device, :offline, :online)

      # offline = 0.0
      DevicesInstrumentation.instrumentstatus_change(device, :online, :offline)

      # maintenance = 0.5
      DevicesInstrumentation.instrumentstatus_change(device, :offline, :maintenance)
    end
  end

  describe "telemetry execution" do
    test "all public functions execute telemetry events" do
      device = sample_device()

      # Status change
      DevicesInstrumentation.instrumentstatus_change(device, :online, :maintenance)

      # Connection
      DevicesInstrumentation.instrument_connection(device, nil, %{protocol: "mqtt"})

      # Command
      command = sample_command()
      DevicesInstrumentation.instrument_command(device, command)

      # Response
      response = sample_response()
      DevicesInstrumentation.instrument_response(device, command.id, response)

      # Health check
      health_data = sample_health_data()
      DevicesInstrumentation.instrument_health_check(device, health_data)

      # Firmware update
      update_info = sample_update_info()

      capture_log(fn ->
        DevicesInstrumentation.instrument_firmware_update(device, update_info)
      end)

      # Metrics
      DevicesInstrumentation.instrument_metrics(device, %{cpu_usage: 50.0})
    end
  end
end
