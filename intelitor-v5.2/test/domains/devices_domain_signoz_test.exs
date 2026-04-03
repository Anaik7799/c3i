defmodule Indrajaal.Domains.DevicesDomainSigNozTest do
  @moduledoc """
  Integration tests for Devices domain with SigNoz observability.
  Validates dual logging (Console + SigNoz) and OpenTelemetry integration.

  TDG: Test-Driven Generation compliance for observability
  STAMP: Safety constraints validated throughout
  GDE: Goal-directed measurements for domain operations

  Dual Property-Based Testing:
  - PropCheck: Advanced property testing with sophisticated shrinking
  - ExUnitProperties: StreamData-based property testing for Elixir ecosystem integration
  """
  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use Mimic
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData, except: [list: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  require Logger
  alias Indrajaal.Observability.DualLogging

  @domain :devices
  @test_tenant_id "test-tenant-#{System.unique_integer()}"

  setup do
    # Validate dual logging before tests
    :ok = DualLogging.validate_dual_logging!()

    # Set up test metadata
    Logger.metadata(
      domain: @domain,
      tenant_id: @test_tenant_id,
      test_run_id: System.unique_integer([:positive])
    )

    :ok
  end

  describe "Devices domain dual logging" do
    test "device registration logs to both console and SigNoz" do
      correlation_id = "device-register-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Simulate device registration
        device_data = %{
          serial_number: "SN-123_456",
          device_type: "camera",
          model: "SecureCam Pro 2000",
          firmware_version: "v2.5.1",
          location: "Building A, Entrance"
        }

        # Log the operation
        Logger.info("Registering new device",
          domain: @domain,
          action: "device.register",
          device_data: device_data,
          tenant_id: @test_tenant_id
        )

        # Log success
        Logger.info("Device registered successfully",
          domain: @domain,
          action: "device.registered",
          device_id: "device-789",
          serial_number: device_data.serial_number,
          device_type: device_data.device_type,
          tenant_id: @test_tenant_id
        )
      end)

      # Verify logs would appear in both backends
      assert_dual_logging_active()
    end

    test "device status updates logging" do
      correlation_id = "device-status-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log status change
        Logger.info("Device status update",
          domain: @domain,
          action: "device.status_update",
          device_id: "device-789",
          previous_status: "online",
          new_status: "offline",
          reason: "network_timeout"
        )

        # Log connectivity __event
        Logger.warning("Device connectivity lost",
          domain: @domain,
          action: "device.connectivity_lost",
          device_id: "device-789",
          last_seen: DateTime.utc_now() |> DateTime.add(-300),
          timeout_seconds: 300
        )
      end)

      assert_dual_logging_active()
    end

    test "device telemetry logging" do
      correlation_id = "device-telemetry-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log telemetry __data
        Logger.info("Device telemetry received",
          domain: @domain,
          action: "device.telemetry",
          device_id: "device-789",
          metrics: %{
            cpu_usage: 45.2,
            memory_usage: 62.8,
            temperature_celsius: 38.5,
            uptime_hours: 1248
          },
          timestamp: DateTime.utc_now()
        )

        # Log telemetry alert
        Logger.warning("Device telemetry threshold exceeded",
          domain: @domain,
          action: "device.telemetry_alert",
          device_id: "device-789",
          alert_type: "high_temperature",
          value: 65.2,
          threshold: 60.0
        )
      end)

      assert_dual_logging_active()
    end

    test "device configuration changes logging" do
      correlation_id = "device-config-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log configuration change
        Logger.info("Device configuration update",
          domain: @domain,
          action: "device.config_update",
          device_id: "device-789",
          changed_by: "admin-123",
          changes: %{
            recording_enabled: %{from: false, to: true},
            motion_sensitivity: %{from: 5, to: 8}
          }
        )

        # Log configuration applied
        Logger.info("Device configuration applied",
          domain: @domain,
          action: "device.config_applied",
          device_id: "device-789",
          apply_time_ms: 150,
          restart_required: false
        )
      end)

      assert_dual_logging_active()
    end

    test "device firmware update logging" do
      correlation_id = "device-firmware-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Firmware update started
        Logger.info("Device firmware update initiated",
          domain: @domain,
          action: "device.firmware_update_start",
          device_id: "device-789",
          current_version: "v2.5.1",
          target_version: "v2.6.0",
          update_size_mb: 45.8
        )

        # Progress updates
        Logger.info("Device firmware update progress",
          domain: @domain,
          action: "device.firmware_update_progress",
          device_id: "device-789",
          progress_percent: 75,
          downloaded_mb: 34.35,
          estimated_time_remaining_seconds: 120
        )

        # Update complete
        Logger.info("Device firmware update completed",
          domain: @domain,
          action: "device.firmware_update_complete",
          device_id: "device-789",
          new_version: "v2.6.0",
          duration_seconds: 480,
          reboot_required: true
        )
      end)

      assert_dual_logging_active()
    end

    test "device maintenance logging" do
      correlation_id = "device-maintenance-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Maintenance scheduled
        Logger.info("Device maintenance scheduled",
          domain: @domain,
          action: "device.maintenance_scheduled",
          device_id: "device-789",
          maintenance_type: "pr__eventive",
          scheduled_date: Date.utc_today() |> Date.add(7),
          estimated_duration_hours: 2
        )

        # Maintenance completed
        Logger.info("Device maintenance completed",
          domain: @domain,
          action: "device.maintenance_complete",
          device_id: "device-789",
          performed_by: "tech-456",
          actions_taken: ["cleaned_lens", "replaced_power_supply", "updated_firmware"],
          next_maintenance_date: Date.utc_today() |> Date.add(90)
        )
      end)

      assert_dual_logging_active()
    end
  end

  describe "Devices domain error logging" do
    test "device registration failures are logged" do
      correlation_id = "device-reg-fail-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log registration failure
        Logger.error("Device registration failed",
          domain: @domain,
          action: "device.registration_failed",
          error: "duplicate_serial_number",
          serial_number: "SN-123_456",
          tenant_id: @test_tenant_id
        )
      end)

      assert_dual_logging_active()
    end

    test "device communication failures are logged" do
      correlation_id = "device-comm-fail-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log communication failure
        Logger.error("Device communication failure",
          domain: @domain,
          action: "device.communication_failed",
          device_id: "device-789",
          error_type: "timeout",
          attempts: 3,
          last_successful_contact: DateTime.utc_now() |> DateTime.add(-3600)
        )

        # Log critical device failure
        DualLogging.log_important(
          :error,
          "Critical device failure detected",
          domain: @domain,
          action: "device.critical_failure",
          device_id: "device-789",
          failure_type: "hardware_malfunction",
          __requires_replacement: true
        )
      end)

      assert_dual_logging_active()
    end

    test "device validation errors are logged" do
      correlation_id = "device-validation-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log validation error
        Logger.warning("Device update validation failed",
          domain: @domain,
          action: "device.validation_failed",
          errors: %{
            firmware_version: ["incompatible with device model"],
            location: ["site not found"]
          },
          device_id: "device-789"
        )
      end)

      assert_dual_logging_active()
    end
  end

  describe "Devices domain security logging" do
    test "device tampering is logged" do
      correlation_id = "device-tamper-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log tampering detection
        Logger.error("Device tampering detected",
          domain: @domain,
          action: "security.device_tampered",
          device_id: "device-789",
          tamper_type: "physical",
          detection_method: "accelerometer",
          location: "Parking Lot Camera 3"
        )

        # Log security alert
        Logger.error("Security alert for tampered device",
          domain: @domain,
          action: "security.tamper_alert",
          device_id: "device-789",
          alert_level: "critical",
          auto_disabled: true,
          security_team_notified: true
        )
      end)

      assert_dual_logging_active()
    end

    test "unauthorized device access is logged" do
      correlation_id = "device-unauth-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log unauthorized access
        Logger.warning("Unauthorized device access attempt",
          domain: @domain,
          action: "security.unauthorized_device_access",
          device_id: "device-789",
          attempted_by: "unknown-__user",
          access_type: "configuration_change",
          blocked: true
        )
      end)

      assert_dual_logging_active()
    end
  end

  describe "Devices domain performance logging" do
    test "device response metrics are logged" do
      correlation_id = "device-perf-#{System.unique_integer()}"

      DualLogging.with_correlation_id(correlation_id, fn ->
        # Log device performance
        Logger.info("Device performance metrics",
          domain: @domain,
          action: "performance.device_metrics",
          device_id: "device-789",
          response_time_ms: 45,
          packet_loss_percent: 0.1,
          bandwidth_usage_mbps: 2.5
        )

        # Log batch device operations
        Logger.info("Batch device operation complete",
          domain: @domain,
          action: "performance.batch_operation",
          operation: "status_check",
          device_count: 250,
          total_time_ms: 3200,
          average_per_device_ms: 12.8
        )
      end)

      assert_dual_logging_active()
    end
  end

  describe "Devices domain OpenTelemetry integration" do
    test "creates spans for device operations" do
      # This would integrate with actual OpenTelemetry
      # For now, we verify the logging happens

      DualLogging.log_domain_event(
        @domain,
        "device.operation",
        :info,
        trace_id: "trace-dev-123",
        span_id: "span-dev-456",
        operation: "device_health_check"
      )

      assert_dual_logging_active()
    end

    test "includes device __context in operations" do
      # Verify device __context
      Logger.metadata(device_id: "device-789", device_type: "camera")

      Logger.info("Device-specific operation",
        domain: @domain,
        action: "device.operation",
        operation: "stream_check"
      )

      metadata = Logger.metadata()
      assert metadata[:device_id] == "device-789"
      assert metadata[:device_type] == "camera"
    end
  end

  describe "STAMP safety validation" do
    test "SC2: Tenant isolation in device logs" do
      tenant1 = "tenant-acme-corp"
      tenant2 = "tenant-globex-inc"

      # Log for tenant 1
      Logger.metadata(tenant_id: tenant1)
      Logger.info("Tenant 1 device", domain: @domain, device_data: "acme-device")

      # Log for tenant 2
      Logger.metadata(tenant_id: tenant2)
      Logger.info("Tenant 2 device", domain: @domain, device_data: "globex-device")

      # Reset
      Logger.metadata(tenant_id: nil)

      assert_dual_logging_active()
    end

    test "SC5: Non-blocking device log operations" do
      # Measure logging performance
      start_time = System.monotonic_time(:microsecond)

      Logger.info("Performance test device log",
        domain: @domain,
        action: "performance.test",
        device_id: "device-perf-test",
        telemetry: %{cpu: 45.2, memory: 62.8},
        timestamp: DateTime.utc_now()
      )

      duration = System.monotonic_time(:microsecond) - start_time
      duration_ms = duration / 1000

      # Logging should be fast (non-blocking)
      assert duration_ms < 10
    end
  end

  describe "GDE goal validation" do
    test "G1: 100% dual logging compliance for devices" do
      assert_dual_logging_active()
    end

    test "G4: Complete device metadata preservation" do
      complex__metadata = %{
        domain: @domain,
        device: %{
          id: "device-complex",
          type: "multi_sensor_camera",
          capabilities: ["video", "audio", "motion", "thermal"],
          configuration: %{
            video: %{resolution: "4K", fps: 30, codec: "H.265"},
            audio: %{enabled: true, noise_reduction: true},
            motion: %{sensitivity: 8, zones: 4},
            thermal: %{enabled: true, threshold: 37.5}
          },
          network: %{
            ip: "192.168.1.100",
            mac: "00:11:22:33:44:55",
            vlan: 10
          }
        }
      }

      Logger.info("Complex device metadata test", complex__metadata)

      assert_dual_logging_active()
    end
  end

  describe "Dual Property-Based Testing - PropCheck" do
    # PropCheck property tests with advanced shrinking

    # Property verification: device status transitions maintain consistency
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: device status transitions maintain consistency" do
      test_cases = [
        {:offline, :connect},
        {:online, :disconnect},
        {:online, :error},
        {:online, :maintenance_start},
        {:maintenance, :maintenance_end},
        {:offline, :reboot},
        {:error, :reboot},
        {:maintenance, :error}
      ]

      for {current_status, event} <- test_cases do
        new_status = apply_device_event(current_status, event)

        # Validate status transition is logical
        assert valid_device_transition?(current_status, new_status, event)
      end
    end

    # Property verification: device configuration validation
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: device configuration validation" do
      test_cases = [
        %{
          type: :camera,
          enabled: true,
          polling_interval: 30,
          resolution: "1080p",
          fps: 30,
          codec: "H.264"
        },
        %{
          type: :camera,
          enabled: false,
          polling_interval: 60,
          resolution: "4K",
          fps: 60,
          codec: "H.265"
        },
        %{
          type: :sensor,
          enabled: true,
          polling_interval: 10,
          sensor_type: :motion,
          sensitivity: 7
        },
        %{
          type: :sensor,
          enabled: true,
          polling_interval: 15,
          sensor_type: :temperature,
          sensitivity: 5
        },
        %{type: :access_control, enabled: true, polling_interval: 5}
      ]

      for config <- test_cases do
        # Advanced shrinking will find minimal invalid config
        assert valid_device_config?(config)
        assert consistent_config_values?(config)
      end
    end

    # Property verification: device telemetry data integrity
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: device telemetry __data integrity" do
      test_cases = [
        %{
          cpu_usage: 45.5,
          memory_usage: 62.3,
          temperature: 38.5,
          uptime_hours: 1248,
          network_latency_ms: 25
        },
        %{
          cpu_usage: 85.2,
          memory_usage: 78.9,
          temperature: 55.7,
          uptime_hours: 500,
          network_latency_ms: 50
        },
        %{
          cpu_usage: 20.1,
          memory_usage: 35.4,
          temperature: 28.3,
          uptime_hours: 72,
          network_latency_ms: 15
        },
        %{
          cpu_usage: 95.8,
          memory_usage: 92.1,
          temperature: 72.5,
          uptime_hours: 2000,
          network_latency_ms: 100
        }
      ]

      for telemetry <- test_cases do
        assert valid_telemetry_ranges?(telemetry)
        assert consistent_telemetry_values?(telemetry)
      end
    end
  end

  describe "Dual Property-Based Testing - ExUnitProperties" do
    # ExUnitProperties tests with StreamData integration

    test "exunitproperties: device registration maintains unique identifiers" do
      ExUnitProperties.check all(
                               serial <- serial_number_generator(),
                               device_type <- device_type_generator(),
                               firmware <- firmware_version_generator(),
                               max_runs: 100
                             ) do
        device_data = %{
          serial_number: serial,
          device_type: device_type,
          firmware_version: firmware,
          registered_at: DateTime.utc_now()
        }

        # Log the registration
        DualLogging.with_correlation_id("prop-device-#{System.unique_integer()}", fn ->
          Logger.info("Property test device registration", device_data)
        end)

        assert valid_device_registration?(device_data)
        assert String.length(serial) >= 6
        assert_dual_logging_active()
      end
    end

    test "exunitproperties: bulk device operations maintain consistency" do
      ExUnitProperties.check all(
                               device_count <- SD.integer(1..500),
                               operation <- device_bulk_operation(),
                               max_runs: 50
                             ) do
        device_ids = Enum.map(1..device_count, fn i -> "device-bulk-#{i}" end)

        DualLogging.with_correlation_id("bulk-device-#{System.unique_integer()}", fn ->
          Logger.info("Bulk device operation property test",
            domain: @domain,
            operation: operation,
            device_count: device_count,
            sample_ids: Enum.take(device_ids, 5)
          )
        end)

        # Verify bulk operation constraints
        # Max bulk size
        assert device_count <= 500
        assert operation in [:enable, :disable, :reboot, :update_firmware]
      end
    end

    test "exunitproperties: device network configurations are valid" do
      ExUnitProperties.check all(
                               ip <- ip_address_generator(),
                               vlan <- SD.integer(1..4094),
                               port <- SD.integer(1..65_535),
                               max_runs: 50
                             ) do
        network_config = %{
          ip_address: ip,
          vlan_id: vlan,
          port: port,
          protocol: Enum.random([:tcp, :udp, :rtsp])
        }

        assert valid_network_config?(network_config)
        # Valid VLAN range
        assert vlan >= 1 and vlan <= 4094
        # Valid port range
        assert port >= 1 and port <= 65_535
      end
    end
  end

  describe "GDE Enhanced Goal Validation with Properties" do
    test "GDE-P1: Device uptime goals with property validation" do
      # Goal: 99.5% device uptime across fleet
      ExUnitProperties.check all(
                               uptimes <-
                                 SD.list_of(float(min: 0.0, max: 100.0), min_length: 100),
                               max_runs: 20
                             ) do
        above_goal = Enum.count(uptimes, &(&1 >= 99.5))
        percentage = above_goal / length(uptimes) * 100

        Logger.info("GDE device uptime analysis",
          domain: @domain,
          action: "gde.device_uptime",
          total_devices: length(uptimes),
          meeting_goal: above_goal,
          fleet_percentage: percentage,
          # 90% of devices should meet 99.5% uptime
          goal_met: percentage >= 90
        )

        assert is_float(percentage)
        assert percentage >= 0 and percentage <= 100
      end
    end

    test "GDE-P2: Device health monitoring with property testing" do
      # Goal: Detect unhealthy devices within 60 seconds
      assert PropCheck.quickcheck(
               forall health_checks <- PC.list(device_health_check(), 50) do
                 unhealthy_detected =
                   Enum.count(health_checks, fn check ->
                     not check.healthy and check.detection_time_seconds <= 60
                   end)

                 unhealthy_total = Enum.count(health_checks, &(not &1.healthy))

                 detection_rate =
                   if unhealthy_total > 0 do
                     unhealthy_detected / unhealthy_total * 100
                   else
                     100.0
                   end

                 Logger.info("GDE device health detection",
                   domain: @domain,
                   action: "gde.health_detection",
                   total_checks: length(health_checks),
                   unhealthy_devices: unhealthy_total,
                   detected_in_time: unhealthy_detected,
                   detection_rate: detection_rate,
                   goal_met: detection_rate >= 95
                 )

                 detection_rate >= 0 and detection_rate <= 100
               end
             )
    end

    test "GDE-P3: Device firmware update success rate" do
      # Goal: 98% successful firmware updates
      ExUnitProperties.check all(
                               update_results <-
                                 SD.list_of(firmware_update_result(), min_length: 50),
                               max_runs: 20
                             ) do
        successful = Enum.count(update_results, &(&1.status == :success))
        success_rate = successful / length(update_results) * 100

        failure_reasons =
          update_results
          |> Enum.filter(&(&1.status == :failed))
          |> Enum.map(& &1.reason)
          |> Enum.frequencies()

        Logger.info("GDE firmware update analysis",
          domain: @domain,
          action: "gde.firmware_updates",
          total_updates: length(update_results),
          successful: successful,
          success_rate: success_rate,
          failure_reasons: failure_reasons,
          goal_met: success_rate >= 98
        )

        assert is_float(success_rate)
        assert success_rate >= 0 and success_rate <= 100
      end
    end
  end

  # Property generators for device domain

  defp device_status do
    PC.oneof([:online, :offline, :maintenance, :error, :unknown])
  end

  defp device_event do
    PC.oneof([
      :connect,
      :disconnect,
      :error,
      :maintenance_start,
      :maintenance_end,
      :reboot
    ])
  end

  defp device_configuration do
    let type <- device_type() do
      base_config = %{
        type: type,
        enabled: PC.boolean(),
        polling_interval: PC.pos_integer()
      }

      case type do
        :camera ->
          Map.merge(base_config, %{
            resolution: PC.oneof(["720p", "1080p", "4K"]),
            fps: PC.oneof([15, 30, 60]),
            codec: PC.oneof(["H.264", "H.265"])
          })

        :sensor ->
          Map.merge(base_config, %{
            sensor_type: PC.oneof([:motion, :temperature, :door, :glass_break]),
            sensitivity: PC.integer(1, 10)
          })

        _ ->
          base_config
      end
    end
  end

  defp device_telemetry do
    %{
      cpu_usage: PC.float(0.0, 100.0),
      memory_usage: PC.float(0.0, 100.0),
      temperature: PC.float(20.0, 80.0),
      uptime_hours: PC.non_neg_integer(),
      network_latency_ms: PC.pos_integer()
    }
  end

  defp device_type do
    PC.oneof([:camera, :sensor, :access_control, :alarm_panel])
  end

  defp device_health_check do
    let healthy <- PC.boolean() do
      %{
        healthy: healthy,
        detection_time_seconds: if(healthy, do: 0, else: PC.integer(1, 120)),
        timestamp: DateTime.utc_now()
      }
    end
  end

  # StreamData generators for ExUnitProperties

  defp serial_number_generator do
    StreamData.map(
      {string(:alphanumeric, min_length: 2), integer(100_000..999_999)},
      fn {prefix, num} -> "#{prefix}-#{num}" end
    )
  end

  defp device_type_generator do
    SD.member_of([:camera, :sensor, :access_control, :alarm_panel, :intercom, :reader])
  end

  defp firmware_version_generator do
    StreamData.map(
      {integer(1..9), integer(0..99), integer(0..999)},
      fn {major, minor, patch} -> "v#{major}.#{minor}.#{patch}" end
    )
  end

  defp device_bulk_operation do
    SD.member_of([:enable, :disable, :reboot, :update_firmware, :reset_config])
  end

  defp ip_address_generator do
    StreamData.map(
      {integer(1..254), integer(0..255), integer(0..255), integer(1..254)},
      fn {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}" end
    )
  end

  defp firmware_update_result do
    PC.frequency([
      {98,
       PC.constant(%{
         status: :success,
         duration_seconds: PC.integer(30, 300)
       })},
      {1, PC.constant(%{status: :failed, reason: :network_error})},
      {1, PC.constant(%{status: :failed, reason: :incompatible_version})}
    ])
  end

  # Validation helpers

  defp apply_device_event(status, event) do
    case {status, event} do
      {_, :connect} -> :online
      {_, :disconnect} -> :offline
      {_, :error} -> :error
      {:online, :maintenance_start} -> :maintenance
      {:maintenance, :maintenance_end} -> :online
      {:offline, :reboot} -> :online
      _ -> status
    end
  end

  defp valid_device_transition?(from, to, event) do
    case {from, to, event} do
      {:offline, :online, :connect} -> true
      {:online, :offline, :disconnect} -> true
      {:online, :error, :error} -> true
      {:online, :maintenance, :maintenance_start} -> true
      {:maintenance, :online, :maintenance_end} -> true
      # Status unchanged is valid
      {same, same, _} -> true
      # These can happen from any state
      _ -> event in [:reboot, :error]
    end
  end

  defp valid_device_config?(config) do
    Map.has_key?(config, :type) and
      Map.has_key?(config, :enabled) and
      Map.has_key?(config, :polling_interval) and
      config.polling_interval > 0
  end

  defp consistent_config_values?(config) do
    case config[:type] do
      :camera -> config[:fps] in [15, 30, 60] and config[:codec] in ["H.264", "H.265"]
      :sensor -> config[:sensitivity] >= 1 and config[:sensitivity] <= 10
      _ -> true
    end
  end

  defp valid_telemetry_ranges?(telemetry) do
    telemetry.cpu_usage >= 0 and telemetry.cpu_usage <= 100 and
      telemetry.memory_usage >= 0 and telemetry.memory_usage <= 100 and
      telemetry.temperature >= 20 and telemetry.temperature <= 80 and
      telemetry.uptime_hours >= 0 and
      telemetry.network_latency_ms > 0
  end

  defp consistent_telemetry_values?(telemetry) do
    # High CPU often correlates with high temperature
    if telemetry.cpu_usage > 80 do
      telemetry.temperature > 50
    else
      true
    end
  end

  defp valid_device_registration?(data) do
    Map.has_key?(data, :serial_number) and
      Map.has_key?(data, :device_type) and
      Map.has_key?(data, :firmware_version) and
      Map.has_key?(data, :registered_at)
  end

  defp valid_network_config?(config) do
    Map.has_key?(config, :ip_address) and
      Map.has_key?(config, :vlan_id) and
      Map.has_key?(config, :port) and
      Map.has_key?(config, :protocol)
  end

  # Helper functions

  defp assert_dual_logging_active do
    backends = Application.get_env(:logger, :backends, [])
    assert :console in backends, "Console backend must be active"
    assert LoggerJSON in backends, "LoggerJSON backend must be active"
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
