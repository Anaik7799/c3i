defmodule Indrajaal.Observability.DualLoggingTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.DualLogging

  describe "validate_dual_logging!/0" do
    setup do
      # Save original configuration
      original_backends = Application.get_env(:logger, :backends, [])

      on_exit(fn ->
        # Restore original configuration
        Application.put_env(:logger, :backends, original_backends)
      end)

      %{original_backends: original_backends}
    end

    test "validates successfully when both backends are configured" do
      # Configure both required backends
      Application.put_env(:logger, :backends, [:console, LoggerJSON])

      log =
        capture_log(fn ->
          assert :ok = DualLogging.validate_dual_logging!()
        end)

      assert log =~ "Dual logging system validated successfully"
      assert log =~ "console_enabled"
      assert log =~ "json_enabled"
    end

    test "raises error when console backend is missing" do
      # Configure without console backend
      Application.put_env(:logger, :backends, [LoggerJSON])

      assert_raise RuntimeError, ~r/Console logging backend not found/, fn ->
        DualLogging.validate_dual_logging!()
      end
    end

    test "raises error when LoggerJSON backend is missing" do
      # Configure without LoggerJSON backend
      Application.put_env(:logger, :backends, [:console])

      assert_raise RuntimeError, ~r/LoggerJSON backend not found/, fn ->
        DualLogging.validate_dual_logging!()
      end
    end

    test "raises error when no backends are configured" do
      # Configure with empty backends
      Application.put_env(:logger, :backends, [])

      assert_raise RuntimeError, ~r/Console logging backend not found/, fn ->
        DualLogging.validate_dual_logging!()
      end
    end
  end

  describe "configure_console_format/1" do
    setup do
      # Save original console configuration
      original_console_config = Application.get_env(:logger, :console, [])

      on_exit(fn ->
        # Restore original console configuration
        Application.put_env(:logger, :console, original_console_config)
      end)

      %{original_console_config: original_console_config}
    end

    test "configures minimal format" do
      log =
        capture_log(fn ->
          assert :ok = DualLogging.configure_console_format(:minimal)
        end)

      assert log =~ "Console format configured"
      assert log =~ "format: :minimal"

      console_config = Application.get_env(:logger, :console)
      assert console_config[:format] == "$time [$level] $message\n"
    end

    test "configures detailed format (default)" do
      log =
        capture_log(fn ->
          assert :ok = DualLogging.configure_console_format(:detailed)
        end)

      assert log =~ "Console format configured"
      assert log =~ "format: :detailed"

      console_config = Application.get_env(:logger, :console)
      assert console_config[:format] == "$time $metadata[$level] $message\n"
    end

    test "configures verbose format" do
      log =
        capture_log(fn ->
          assert :ok = DualLogging.configure_console_format(:verbose)
        end)

      assert log =~ "Console format configured"
      assert log =~ "format: :verbose"

      console_config = Application.get_env(:logger, :console)
      assert console_config[:format] == "$date $time [$level] $metadata\n$message\n"
    end

    test "defaults to detailed format for unknown format types" do
      log =
        capture_log(fn ->
          assert :ok = DualLogging.configure_console_format(:unknown_format)
        end)

      assert log =~ "Console format configured"

      console_config = Application.get_env(:logger, :console)
      assert console_config[:format] == "$time $metadata[$level] $message\n"
    end

    test "uses detailed format when no argument provided" do
      log =
        capture_log(fn ->
          assert :ok = DualLogging.configure_console_format()
        end)

      assert log =~ "Console format configured"
      assert log =~ "format: :detailed"
    end
  end

  describe "log_domain_event/4" do
    test "logs domain event with all required metadata" do
      log =
        capture_log(fn ->
          assert :ok =
                   DualLogging.log_domain_event(
                     :access_control,
                     :door_opened,
                     %{user_id: 123, door_id: 456},
                     :info
                   )
        end)

      assert log =~ "[ACCESS_CONTROL] door_opened"
      assert log =~ "user_id"
      assert log =~ "door_id"
    end

    test "includes dual_logging flag in metadata" do
      log =
        capture_log([metadata: :all], fn ->
          assert :ok =
                   DualLogging.log_domain_event(
                     :alarms,
                     :alarm_triggered,
                     %{alarm_id: 789}
                   )
        end)

      assert log =~ "dual_logging"
      assert log =~ "[ALARMS] alarm_triggered"
    end

    test "defaults to info level when level not specified" do
      log =
        capture_log(fn ->
          assert :ok =
                   DualLogging.log_domain_event(
                     :analytics,
                     :report_generated,
                     %{report_id: 999}
                   )
        end)

      assert log =~ "[info]" or log =~ "INFO"
      assert log =~ "[ANALYTICS] report_generated"
    end

    test "supports different log levels" do
      # Test debug level
      log_debug =
        capture_log(fn ->
          DualLogging.log_domain_event(:devices, :status_updated, %{}, :debug)
        end)

      # Test warn level
      log_warn =
        capture_log(fn ->
          DualLogging.log_domain_event(:devices, :low_battery, %{}, :warn)
        end)

      # Test error level
      log_error =
        capture_log(fn ->
          DualLogging.log_domain_event(:devices, :connection_failed, %{}, :error)
        end)

      assert log_debug =~ "[DEVICES] status_updated"
      assert log_warn =~ "[DEVICES] low_battery"
      assert log_error =~ "[DEVICES] connection_failed"
    end

    test "handles empty metadata map" do
      log =
        capture_log(fn ->
          assert :ok = DualLogging.log_domain_event(:sites, :site_added, %{})
        end)

      assert log =~ "[SITES] site_added"
    end

    test "merges custom metadata with enhanced metadata" do
      custom_metadata = %{
        user_id: 123,
        action: "manual_trigger",
        source: "web_ui"
      }

      log =
        capture_log([metadata: :all], fn ->
          assert :ok =
                   DualLogging.log_domain_event(
                     :maintenance,
                     :work_order_created,
                     custom_metadata
                   )
        end)

      assert log =~ "[MAINTENANCE] work_order_created"
      assert log =~ "user_id"
      assert log =~ "action"
      assert log =~ "source"
    end
  end

  describe "log_important/3" do
    test "logs important message with emoji markers" do
      log =
        capture_log(fn ->
          assert :ok =
                   DualLogging.log_important(
                     :warn,
                     "System memory usage at 90%",
                     user: "admin"
                   )
        end)

      assert log =~ "🚨 System memory usage at 90% 🚨"
    end

    test "includes importance flag in metadata" do
      log =
        capture_log([metadata: :all], fn ->
          assert :ok =
                   DualLogging.log_important(
                     :error,
                     "Critical database connection failure",
                     []
                   )
        end)

      assert log =~ "importance"
      assert log =~ "🚨 Critical database connection failure 🚨"
    end

    test "defaults to empty metadata when not provided" do
      log =
        capture_log(fn ->
          assert :ok =
                   DualLogging.log_important(
                     :info,
                     "Important system notification"
                   )
        end)

      assert log =~ "🚨 Important system notification 🚨"
    end

    test "merges custom metadata with enhanced metadata" do
      log =
        capture_log([metadata: :all], fn ->
          assert :ok =
                   DualLogging.log_important(
                     :warn,
                     "High CPU usage detected",
                     cpu_percent: 95,
                     threshold: 80
                   )
        end)

      assert log =~ "🚨 High CPU usage detected 🚨"
      assert log =~ "cpu_percent"
      assert log =~ "threshold"
      assert log =~ "importance"
    end

    test "supports different log levels for important messages" do
      # Info level
      log_info =
        capture_log(fn ->
          DualLogging.log_important(:info, "Important info message")
        end)

      # Warn level
      log_warn =
        capture_log(fn ->
          DualLogging.log_important(:warn, "Important warning message")
        end)

      # Error level
      log_error =
        capture_log(fn ->
          DualLogging.log_important(:error, "Important error message")
        end)

      assert log_info =~ "🚨 Important info message 🚨"
      assert log_warn =~ "🚨 Important warning message 🚨"
      assert log_error =~ "🚨 Important error message 🚨"
    end

    test "includes dual_logging and timestamp in metadata" do
      log =
        capture_log([metadata: :all], fn ->
          assert :ok =
                   DualLogging.log_important(
                     :info,
                     "Test message",
                     test: true
                   )
        end)

      assert log =~ "dual_logging"
      assert log =~ "timestamp"
      assert log =~ "🚨 Test message 🚨"
    end
  end

  describe "integration tests" do
    test "all functions return :ok for chaining" do
      # Configure backends first
      Application.put_env(:logger, :backends, [:console, LoggerJSON])

      result =
        capture_log(fn ->
          # Chain all operations
          assert :ok = DualLogging.validate_dual_logging!()
          assert :ok = DualLogging.configure_console_format(:detailed)
          assert :ok = DualLogging.log_domain_event(:test, :test_event, %{})
          assert :ok = DualLogging.log_important(:info, "Test message")
        end)

      assert result =~ "Dual logging system validated"
      assert result =~ "Console format configured"
      assert result =~ "[TEST] test_event"
      assert result =~ "🚨 Test message 🚨"
    end

    test "dual logging works with both backends configured" do
      # Ensure both backends are present
      Application.put_env(:logger, :backends, [:console, LoggerJSON])

      log =
        capture_log(fn ->
          DualLogging.validate_dual_logging!()

          # Log to both backends
          DualLogging.log_domain_event(
            :observability,
            :dual_logging_test,
            %{test: "integration"}
          )
        end)

      # Verify log appears (it will be in console, JSON backend is tested separately)
      assert log =~ "[OBSERVABILITY] dual_logging_test"
    end
  end
end
