defmodule Indrajaal.Observability.LoggingTest do
  @moduledoc """
  Test suite for enhanced logging capabilities.

  This module tests:
  - Structured logging with consistent formats
  - Log level management and filtering
  - Contextual logging with correlation IDs
  - Log sanitization and PII protection
  - Multi-backend logging (console + SigNoz)
  """
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Indrajaal.Observability.Logging

  describe "structured logging" do
    test "logs with consistent structure" do
      # When logging a message
      log =
        capture_log(fn ->
          Logging.info("User logged in", %{__user_id: 123, action: "login"})
        end)

      # Then it should have consistent structure
      assert log =~ "User logged in"
      assert log =~ "__user_id=123"
      assert log =~ "action=login"
      assert log =~ ~r/timestamp=\d{4}-\d{2}-\d{2}T/
    end

    test "includes automatic metadata" do
      # Given a process with __context
      Logging.set_context(%{__request_id: "__req_123", tenant_id: "tenant_456"})

      # When logging
      log =
        capture_log(fn ->
          Logging.info("Processing __request")
        end)

      # Then __context should be included
      assert log =~ "__request_id=__req_123"
      assert log =~ "tenant_id=tenant_456"
    end

    test "formats complex __data structures" do
      # When logging complex __data
      log =
        capture_log(fn ->
          Logging.debug("Complex __data", %{
            __user: %{id: 1, name: "John"},
            items: [%{sku: "ABC", price: 10.99}],
            metadata: %{tags: ["new", "featured"]}
          })
        end)

      # Then it should be properly formatted
      assert log =~ "user.id=1"
      assert log =~ "__user.name=John"
      assert log =~ "items.0.sku=ABC"
      assert log =~ "items.0.price=10.99"
      assert log =~ "metadata.tags=[new, featured]"
    end
  end

  describe "log level management" do
    test "respects log level configuration" do
      # Given log level set to warn
      original_level = Logging.get_level()
      Logging.set_level(:warn)

      # When logging at different levels
      logs =
        capture_log(fn ->
          Logging.debug("Debug message")
          Logging.info("Info message")
          Logging.warn("Warning message")
          Logging.error("Error message")
        end)

      # Then only warn and above should appear
      refute logs =~ "Debug message"
      refute logs =~ "Info message"
      assert logs =~ "Warning message"
      assert logs =~ "Error message"

      # Cleanup
      Logging.set_level(original_level)
    end

    test "supports module-specific log levels" do
      # Given different levels for different modules
      Logging.set_module_level(Indrajaal.Accounts, :debug)
      Logging.set_module_level(Indrajaal.Payments, :error)

      # When modules log
      account_logs =
        capture_log(fn ->
          Logging.debug("Account debug", module: Indrajaal.Accounts)
        end)

      payment_logs =
        capture_log(fn ->
          Logging.debug("Payment debug", module: Indrajaal.Payments)
        end)

      # Then module levels should be respected
      assert account_logs =~ "Account debug"
      refute payment_logs =~ "Payment debug"
    end

    test "supports dynamic log level changes" do
      # Given a running system
      original = Logging.get_level()

      # When changing log level
      Logging.set_level(:debug)
      assert Logging.get_level() == :debug

      # And can change again
      Logging.set_level(:info)
      assert Logging.get_level() == :info

      # Cleanup
      Logging.set_level(original)
    end
  end

  describe "__contextual logging" do
    test "maintains __context across function calls" do
      # Given initial __context
      Logging.with_context(%{operation: "__user_import"}, fn ->
        Logging.info("Starting import")

        # When adding more __context
        Logging.with_context(%{batch_id: "batch_123"}, fn ->
          log =
            capture_log(fn ->
              Logging.info("Processing batch")
            end)

          # Then both __contexts should be present
          assert log =~ "operation=__user_import"
          assert log =~ "batch_id=batch_123"
        end)
      end)
    end

    test "isolates __context between processes" do
      # Given two processes with different __contexts
      parent = self()

      spawn(fn ->
        Logging.set_context(%{process: "worker_1"})
        send(parent, {:log1, capture_log(fn -> Logging.info("Worker 1 log") end)})
      end)

      spawn(fn ->
        Logging.set_context(%{process: "worker_2"})
        send(parent, {:log2, capture_log(fn -> Logging.info("Worker 2 log") end)})
      end)

      # Then __contexts should be isolated
      assert_receive {:log1, log1}
      assert_receive {:log2, log2}

      assert log1 =~ "process=worker_1"
      assert log2 =~ "process=worker_2"
      refute log1 =~ "worker_2"
      refute log2 =~ "worker_1"
    end

    test "supports correlation ID propagation" do
      # Given a correlation ID
      correlation_id = Logging.generate_correlation_id()

      # When using it across operations
      Logging.with_correlation_id(correlation_id, fn ->
        log1 = capture_log(fn -> Logging.info("Operation 1") end)
        log2 = capture_log(fn -> Logging.info("Operation 2") end)

        # Then same correlation ID appears
        assert log1 =~ "correlation_id=#{correlation_id}"
        assert log2 =~ "correlation_id=#{correlation_id}"
      end)
    end
  end

  describe "log sanitization" do
    test "redacts sensitive fields" do
      # When logging sensitive __data
      log =
        capture_log(fn ->
          Logging.info("User __data", %{
            email: "__user@example.com",
            password: "secret123",
            credit_card: "4_111_111_111_111_111",
            ssn: "123-45-6789"
          })
        end)

      # Then sensitive __data should be redacted
      assert log =~ "email=__user@[REDACTED]"
      assert log =~ "password=[REDACTED]"
      assert log =~ "credit_card=[REDACTED]"
      assert log =~ "ssn=[REDACTED]"
    end

    test "allows configurable sanitization rules" do
      # Given custom sanitization rules
      Logging.add_sanitization_rule(:api_key, fn value ->
        "#{String.slice(value, 0..3)}...[REDACTED]"
      end)

      # When logging
      log =
        capture_log(fn ->
          Logging.info("API call", %{api_key: "sk_test_1234567890"})
        end)

      # Then custom rule should apply
      assert log =~ "api_key=sk_t...[REDACTED]"
    end

    test "sanitizes nested structures" do
      # When logging nested sensitive __data
      log =
        capture_log(fn ->
          Logging.info("Nested __data", %{
            __user: %{
              name: "John",
              credentials: %{
                password: "secret",
                token: "token123"
              }
            }
          })
        end)

      # Then nested fields should be sanitized
      assert log =~ "__user.name=John"
      assert log =~ "__user.credentials.password=[REDACTED]"
      assert log =~ "__user.credentials.token=[REDACTED]"
    end
  end

  describe "multi-backend logging" do
    test "logs to multiple backends simultaneously" do
      # Given multiple backends configured
      {:ok, console_backend} = Logging.add_backend(:console, level: :info)
      {:ok, file_backend} = Logging.add_backend(:file, path: "/tmp/test.log", level: :debug)

      # When logging
      Logging.info("Multi-backend message")

      # Then both backends should receive the log
      assert Logging.backend_received?(console_backend, "Multi-backend message")
      assert Logging.backend_received?(file_backend, "Multi-backend message")

      # Cleanup
      Logging.remove_backend(console_backend)
      Logging.remove_backend(file_backend)
    end

    test "supports backend-specific formatting" do
      # Given backends with different formats
      {:ok, json_backend} = Logging.add_backend(:json, format: :json)
      {:ok, text_backend} = Logging.add_backend(:text, format: :plain)

      # When logging
      Logging.info("Formatted message", %{key: "value"})

      # Then each backend should format differently
      json_log = Logging.get_backend_output(json_backend)
      assert json_log =~ ~r/\{"message":"Formatted message","key":"value"/

      text_log = Logging.get_backend_output(text_backend)
      assert text_log =~ "Formatted message key=value"

      # Cleanup
      Logging.remove_backend(json_backend)
      Logging.remove_backend(text_backend)
    end

    test "handles backend failures gracefully" do
      # Given a failing backend
      {:ok, failing_backend} =
        Logging.add_backend(:failing,
          on_log: fn _msg -> raise "Backend error" end
        )

      # When logging
      result = Logging.info("Test message")

      # Then logging should still succeed
      assert result == :ok

      # And backend should be marked as failed
      assert Logging.backend_status(failing_backend) == :failed

      # Cleanup
      Logging.remove_backend(failing_backend)
    end
  end

  describe "performance logging" do
    test "logs execution time for operations" do
      # When timing an operation
      log =
        capture_log(fn ->
          Logging.time("__database_query", fn ->
            Process.sleep(100)
            {:ok, :result}
          end)
        end)

      # Then duration should be logged
      assert log =~ "operation=__database_query"
      assert log =~ ~r/duration_ms=\d+/
      assert log =~ "status=success"
    end

    test "logs failures with timing" do
      # When timing a failing operation
      log =
        capture_log(fn ->
          try do
            Logging.time("failing_operation", fn ->
              Process.sleep(50)
              raise "Operation failed"
            end)
          rescue
            _ -> :ok
          end
        end)

      # Then failure should be logged with timing
      assert log =~ "operation=failing_operation"
      assert log =~ ~r/duration_ms=\d+/
      assert log =~ "status=error"
      assert log =~ "error=Operation failed"
    end
  end

  describe "log querying and analysis" do
    test "supports structured queries" do
      # Given logged __events
      Logging.enable_query_mode()

      Logging.info("User login", %{__user_id: 1, action: "login", status: "success"})
      Logging.info("User login", %{__user_id: 2, action: "login", status: "success"})
      Logging.info("User login", %{__user_id: 3, action: "login", status: "failed"})

      # When querying logs
      results = Logging.query(%{action: "login", status: "success"})

      # Then matching logs should be returned
      assert length(results) == 2
      assert Enum.all?(results, &(&1.metadata.status == "success"))

      # Cleanup
      Logging.disable_query_mode()
    end

    test "provides log statistics" do
      # Given various log __events
      Logging.enable_statistics()

      Logging.info("Info message")
      Logging.warn("Warning message")
      Logging.error("Error message")
      Logging.error("Another error")

      # When getting statistics
      stats = Logging.get_statistics()

      # Then counts should be correct
      assert stats.by_level.info == 1
      assert stats.by_level.warn == 1
      assert stats.by_level.error == 2
      assert stats.total == 4

      # Cleanup
      Logging.disable_statistics()
    end
  end

  describe "STAMP safety constraints" do
    test "prevents log flooding" do
      # When attempting to flood logs
      results =
        Enum.map(1..1000, fn i ->
          Logging.info("Flood message #{i}")
        end)

      # Then rate limiting should kick in
      dropped_count = Enum.count(results, &(&1 == {:dropped, :rate_limited}))
      assert dropped_count > 0

      # And warning should be logged
      assert_receive {:log_flood_detected, count}
    end

    test "limits log message size" do
      # Given a huge message
      huge_data = String.duplicate("x", 1_000_000)

      # When logging
      log =
        capture_log(fn ->
          Logging.info("Large message", %{data: huge_data})
        end)

      # Then message should be truncated
      assert log =~ "data=[TRUNCATED"
      assert String.length(log) < 10_000
    end

    test "enforces maximum context depth" do
      # Given deeply nested context
      deep_context = create_nested_map(100)

      # When logging with deep context
      log =
        capture_log(fn ->
          Logging.info("Deep context", deep_context)
        end)

      # Then context should be limited
      assert log =~ "context_truncated=true"
      assert log =~ "max_depth_exceeded"
    end
  end

  defp create_nested_map(0), do: %{value: "leaf"}
  defp create_nested_map(n), do: %{nested: create_nested_map(n - 1)}
end
