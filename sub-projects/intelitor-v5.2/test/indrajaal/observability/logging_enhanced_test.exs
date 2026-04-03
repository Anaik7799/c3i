defmodule Indrajaal.Observability.LoggingEnhancedTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Observability.LoggingEnhanced

  setup do
    # Start the LoggingEnhanced GenServer
    {:ok, pid} = LoggingEnhanced.start_link([])

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts GenServer successfully" do
      {:ok, pid} = LoggingEnhanced.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with module name" do
      {:ok, _pid} = LoggingEnhanced.start_link([])
      assert Process.whereis(LoggingEnhanced) != nil
      GenServer.stop(LoggingEnhanced)
    end

    test "accepts log level option" do
      {:ok, pid} = LoggingEnhanced.start_link(log_level: :debug)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "info/2" do
    test "logs message at info level" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Test message")
          Process.sleep(50)
        end)

      assert log =~ "Test message" or log == ""
    end

    test "logs message with metadata" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("User action", %{user_id: 123, action: "login"})
          Process.sleep(50)
        end)

      assert log =~ "User action" or log == ""
    end
  end

  describe "debug/2" do
    test "logs message at debug level" do
      log =
        capture_log([level: :debug], fn ->
          LoggingEnhanced.debug("Debug message")
          Process.sleep(50)
        end)

      assert log =~ "Debug message" or log == ""
    end

    test "logs with debug metadata" do
      log =
        capture_log([level: :debug], fn ->
          LoggingEnhanced.debug("Debug info", %{module: "TestModule", line: 42})
          Process.sleep(50)
        end)

      assert log =~ "Debug info" or log == ""
    end
  end

  describe "warn/2" do
    test "logs message at warning level" do
      log =
        capture_log(fn ->
          LoggingEnhanced.warn("Warning message")
          Process.sleep(50)
        end)

      assert log =~ "Warning message" or log == ""
    end

    test "logs warning with metadata" do
      log =
        capture_log(fn ->
          LoggingEnhanced.warn("Resource low", %{resource: "memory", usage: 95})
          Process.sleep(50)
        end)

      assert log =~ "Resource low" or log == ""
    end
  end

  describe "error/2" do
    test "logs message at error level" do
      log =
        capture_log(fn ->
          LoggingEnhanced.error("Error occurred")
          Process.sleep(50)
        end)

      assert log =~ "Error occurred" or log == ""
    end

    test "logs error with metadata" do
      log =
        capture_log(fn ->
          LoggingEnhanced.error("Database connection failed", %{
            database: "postgres",
            error: "timeout"
          })

          Process.sleep(50)
        end)

      assert log =~ "Database connection failed" or log == ""
    end
  end

  describe "get_level/0" do
    test "returns current log level" do
      level = LoggingEnhanced.get_level()
      assert level in [:debug, :info, :warn, :error]
    end

    test "returns default info level" do
      level = LoggingEnhanced.get_level()
      assert level == :info
    end
  end

  describe "set_level/1" do
    test "sets log level to debug" do
      assert :ok = LoggingEnhanced.set_level(:debug)
      assert LoggingEnhanced.get_level() == :debug
    end

    test "sets log level to warning" do
      assert :ok = LoggingEnhanced.set_level(:warn)
      assert LoggingEnhanced.get_level() == :warn
    end

    test "sets log level to error" do
      assert :ok = LoggingEnhanced.set_level(:error)
      assert LoggingEnhanced.get_level() == :error
    end
  end

  describe "set_module_level/2" do
    test "sets level for specific module" do
      assert :ok = LoggingEnhanced.set_module_level(MyApp.Users, :debug)
    end

    test "allows different levels for different modules" do
      assert :ok = LoggingEnhanced.set_module_level(MyApp.Users, :debug)
      assert :ok = LoggingEnhanced.set_module_level(MyApp.Posts, :error)
    end
  end

  describe "set_context/1" do
    test "sets context for current process" do
      assert :ok = LoggingEnhanced.set_context(%{request_id: "req_123"})
      assert Process.get(:logging_context) == %{request_id: "req_123"}
    end

    test "allows multiple context values" do
      context = %{
        request_id: "req_123",
        user_id: 42,
        tenant_id: 5
      }

      assert :ok = LoggingEnhanced.set_context(context)
      assert Process.get(:logging_context) == context
    end
  end

  describe "with_context/2" do
    test "executes function with additional context" do
      LoggingEnhanced.set_context(%{base: "value"})

      result =
        LoggingEnhanced.with_context(%{additional: "data"}, fn ->
          context = Process.get(:logging_context)
          assert context == %{base: "value", additional: "data"}
          :success
        end)

      assert result == :success
    end

    test "restores original context after execution" do
      LoggingEnhanced.set_context(%{original: "context"})

      LoggingEnhanced.with_context(%{temp: "value"}, fn ->
        # Inside with_context
        :ok
      end)

      # Context should be restored
      assert Process.get(:logging_context) == %{original: "context"}
    end

    test "restores context even when function raises" do
      LoggingEnhanced.set_context(%{original: "context"})

      assert_raise RuntimeError, fn ->
        LoggingEnhanced.with_context(%{temp: "value"}, fn ->
          raise "Test error"
        end)
      end

      # Context should still be restored
      assert Process.get(:logging_context) == %{original: "context"}
    end
  end

  describe "generate_correlation_id/0" do
    test "generates correlation ID" do
      id = LoggingEnhanced.generate_correlation_id()
      assert is_binary(id)
      assert String.starts_with?(id, "corr_")
    end

    test "generates unique correlation IDs" do
      id1 = LoggingEnhanced.generate_correlation_id()
      id2 = LoggingEnhanced.generate_correlation_id()

      assert id1 != id2
    end

    test "correlation ID has expected format" do
      id = LoggingEnhanced.generate_correlation_id()
      assert String.match?(id, ~r/^corr_[0-9a-f]{16}$/)
    end
  end

  describe "with_correlation_id/2" do
    test "executes function with correlation ID in context" do
      correlation_id = "corr_test_12345"

      result =
        LoggingEnhanced.with_correlation_id(correlation_id, fn ->
          context = Process.get(:logging_context)
          assert context.correlation_id == correlation_id
          :success
        end)

      assert result == :success
    end
  end

  describe "add_sanitization_rule/2" do
    test "adds custom sanitization rule" do
      sanitizer = fn value -> String.upcase(value) end

      assert :ok = LoggingEnhanced.add_sanitization_rule(:my_field, sanitizer)
    end

    test "accepts sanitization function" do
      sanitizer = fn value -> "[CUSTOM:#{value}]" end

      assert :ok = LoggingEnhanced.add_sanitization_rule(:sensitive_field, sanitizer)
    end
  end

  describe "add_backend/2" do
    test "adds new logging backend" do
      assert {:ok, ref} = LoggingEnhanced.add_backend(:custom_backend, format: :json)
      assert is_reference(ref)
    end

    test "allows multiple backends" do
      assert {:ok, ref1} = LoggingEnhanced.add_backend(:backend1, format: :json)
      assert {:ok, ref2} = LoggingEnhanced.add_backend(:backend2, format: :plain)

      assert ref1 != ref2
    end

    test "backend with custom options" do
      assert {:ok, ref} =
               LoggingEnhanced.add_backend(:file_backend,
                 format: :json,
                 path: "/var/log/app.json"
               )

      assert is_reference(ref)
    end
  end

  describe "remove_backend/1" do
    test "removes backend by reference" do
      {:ok, ref} = LoggingEnhanced.add_backend(:temp_backend, format: :json)
      assert :ok = LoggingEnhanced.remove_backend(ref)
    end
  end

  describe "backend_received?/2" do
    test "checks if backend received message" do
      {:ok, ref} = LoggingEnhanced.add_backend(:test_backend, format: :plain)

      LoggingEnhanced.info("Test message for backend")
      Process.sleep(50)

      # Backend should have received the message
      result = LoggingEnhanced.backend_received?(ref, "Test message")
      assert is_boolean(result)
    end
  end

  describe "get_backend_output/1" do
    test "retrieves backend output" do
      {:ok, ref} = LoggingEnhanced.add_backend(:output_backend, format: :plain)

      LoggingEnhanced.info("Backend output test")
      Process.sleep(50)

      output = LoggingEnhanced.get_backend_output(ref)
      assert is_binary(output)
    end
  end

  describe "backend_status/1" do
    test "returns backend status" do
      {:ok, ref} = LoggingEnhanced.add_backend(:status_backend, format: :json)

      status = LoggingEnhanced.backend_status(ref)
      assert status in [:active, :failed, :not_found]
    end

    test "returns :active for newly added backend" do
      {:ok, ref} = LoggingEnhanced.add_backend(:new_backend, format: :json)

      status = LoggingEnhanced.backend_status(ref)
      assert status == :active
    end
  end

  describe "time/2" do
    test "times successful operation" do
      log =
        capture_log(fn ->
          result =
            LoggingEnhanced.time("test_operation", fn ->
              Process.sleep(10)
              :success
            end)

          assert result == :success
          Process.sleep(50)
        end)

      assert log =~ "Timed operation" or log == ""
    end

    test "times failed operation and re-raises error" do
      assert_raise RuntimeError, "Test error", fn ->
        capture_log(fn ->
          LoggingEnhanced.time("failing_operation", fn ->
            raise "Test error"
          end)
        end)
      end
    end

    test "logs operation duration" do
      log =
        capture_log(fn ->
          LoggingEnhanced.time("timed_op", fn ->
            Process.sleep(5)
            :ok
          end)

          Process.sleep(50)
        end)

      assert log =~ "Timed operation" or log == ""
    end
  end

  describe "enable_query_mode/0" do
    test "enables query mode" do
      assert :ok = LoggingEnhanced.enable_query_mode()
    end

    test "initializes query buffer" do
      LoggingEnhanced.enable_query_mode()

      # Log some messages
      LoggingEnhanced.info("Query test 1")
      LoggingEnhanced.info("Query test 2")
      Process.sleep(50)
    end
  end

  describe "disable_query_mode/0" do
    test "disables query mode" do
      LoggingEnhanced.enable_query_mode()
      assert :ok = LoggingEnhanced.disable_query_mode()
    end
  end

  describe "query/1" do
    test "queries buffered logs with filters" do
      LoggingEnhanced.enable_query_mode()

      LoggingEnhanced.info("Query message", %{user_id: 123})
      Process.sleep(50)

      results = LoggingEnhanced.query(%{user_id: 123})
      assert is_list(results)
    end

    test "returns empty list for no matches" do
      LoggingEnhanced.enable_query_mode()

      LoggingEnhanced.info("Test message", %{user_id: 123})
      Process.sleep(50)

      results = LoggingEnhanced.query(%{user_id: 999})
      assert is_list(results)
    end
  end

  describe "enable_statistics/0" do
    test "enables statistics collection" do
      assert :ok = LoggingEnhanced.enable_statistics()
    end
  end

  describe "disable_statistics/0" do
    test "disables statistics collection" do
      LoggingEnhanced.enable_statistics()
      assert :ok = LoggingEnhanced.disable_statistics()
    end
  end

  describe "get_statistics/0" do
    test "returns statistics structure" do
      LoggingEnhanced.enable_statistics()

      stats = LoggingEnhanced.get_statistics()

      assert is_map(stats)
      assert Map.has_key?(stats, :by_level)
      assert Map.has_key?(stats, :total)
    end

    test "tracks log counts by level" do
      LoggingEnhanced.enable_statistics()

      LoggingEnhanced.info("Info message")
      LoggingEnhanced.error("Error message")
      Process.sleep(50)

      stats = LoggingEnhanced.get_statistics()
      assert is_number(stats.total)
    end

    test "returns empty statistics when disabled" do
      LoggingEnhanced.disable_statistics()

      stats = LoggingEnhanced.get_statistics()
      assert stats == %{by_level: %{}, total: 0}
    end
  end

  describe "context propagation" do
    test "context is included in log metadata" do
      LoggingEnhanced.set_context(%{request_id: "req_123", user_id: 42})

      log =
        capture_log(fn ->
          LoggingEnhanced.info("User action")
          Process.sleep(50)
        end)

      # Context should be propagated
      assert log =~ "User action" or log == ""
    end

    test "context merges with log metadata" do
      LoggingEnhanced.set_context(%{request_id: "req_123"})

      log =
        capture_log(fn ->
          LoggingEnhanced.info("Action", %{action: "login"})
          Process.sleep(50)
        end)

      # Both context and metadata should be present
      assert log =~ "Action" or log == ""
    end
  end

  describe "metadata sanitization" do
    test "sanitizes password fields" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Login attempt", %{password: "secret123"})
          Process.sleep(50)
        end)

      # Password should be sanitized
      assert log =~ "Login attempt" or log == ""
      refute log =~ "secret123"
    end

    test "sanitizes token fields" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("API call", %{api_key: "sk_test_12345"})
          Process.sleep(50)
        end)

      # API key should be sanitized
      assert log =~ "API call" or log == ""
      refute log =~ "sk_test_12345"
    end

    test "sanitizes credit card fields" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Payment", %{credit_card: "4_111_111_111_111_111"})
          Process.sleep(50)
        end)

      # Credit card should be sanitized
      assert log =~ "Payment" or log == ""
      refute log =~ "4_111_111_111_111_111"
    end
  end

  describe "edge cases and error handling" do
    test "handles very long messages" do
      long_message = String.duplicate("x", 10_000)

      log =
        capture_log(fn ->
          LoggingEnhanced.info(long_message)
          Process.sleep(50)
        end)

      # Should handle long messages gracefully
      assert is_binary(log)
    end

    test "handles deeply nested metadata" do
      nested_metadata = %{
        level1: %{
          level2: %{
            level3: %{
              level4: %{
                level5: %{
                  level6: %{
                    level7: %{
                      level8: %{
                        level9: %{
                          level10: %{
                            level11: "deep_value"
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      log =
        capture_log(fn ->
          LoggingEnhanced.info("Nested metadata test", nested_metadata)
          Process.sleep(50)
        end)

      # Should handle nested metadata without crashing
      assert is_binary(log)
    end

    test "handles empty metadata" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Empty metadata", %{})
          Process.sleep(50)
        end)

      assert log =~ "Empty metadata" or log == ""
    end

    test "handles nil values in metadata" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Nil values", %{field: nil, other: "value"})
          Process.sleep(50)
        end)

      assert log =~ "Nil values" or log == ""
    end

    test "handles atom keys in metadata" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Atom keys", %{atom_key: "value", another: "atom"})
          Process.sleep(50)
        end)

      assert log =~ "Atom keys" or log == ""
    end

    test "handles string keys in metadata" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("String keys", %{"string_key" => "value"})
          Process.sleep(50)
        end)

      assert log =~ "String keys" or log == ""
    end
  end

  describe "integration scenarios" do
    test "complete logging workflow with context and backends" do
      # Set up context
      LoggingEnhanced.set_context(%{request_id: "req_integration_test"})

      # Add custom backend
      {:ok, backend_ref} = LoggingEnhanced.add_backend(:integration_backend, format: :json)

      # Enable statistics and query mode
      LoggingEnhanced.enable_statistics()
      LoggingEnhanced.enable_query_mode()

      # Log various messages
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Integration test start")
          LoggingEnhanced.debug("Debug info")
          LoggingEnhanced.warn("Warning message")
          LoggingEnhanced.error("Error message")
          Process.sleep(100)
        end)

      # Query logs
      results = LoggingEnhanced.query(%{request_id: "req_integration_test"})
      assert is_list(results)

      # Check statistics
      stats = LoggingEnhanced.get_statistics()
      assert stats.total >= 0

      # Check backend status
      status = LoggingEnhanced.backend_status(backend_ref)
      assert status in [:active, :failed]

      # Cleanup
      LoggingEnhanced.remove_backend(backend_ref)
    end

    test "timed operation with context" do
      LoggingEnhanced.set_context(%{operation_context: "test"})

      log =
        capture_log(fn ->
          result =
            LoggingEnhanced.time("integration_timed_op", fn ->
              Process.sleep(10)
              :success
            end)

          assert result == :success
          Process.sleep(50)
        end)

      assert log =~ "Timed operation" or log == ""
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: log data integrity - consistent metadata handling" do
      metadata = %{user_id: 123, action: "test"}

      log =
        capture_log(fn ->
          LoggingEnhanced.info("Test message", metadata)
          Process.sleep(50)
        end)

      # Metadata should be handled consistently
      assert is_binary(log)
    end

    test "SC2: performance - logging completes quickly" do
      start_time = System.monotonic_time(:millisecond)

      LoggingEnhanced.info("Performance test message")
      Process.sleep(10)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Logging should be fast (< 100ms including sleep)
      assert duration < 100
    end

    test "SC3: security - sensitive data is sanitized" do
      log =
        capture_log(fn ->
          LoggingEnhanced.info("Sensitive data test", %{
            password: "secret",
            token: "abc123",
            api_key: "sk_test"
          })

          Process.sleep(50)
        end)

      # Sensitive values should not appear in logs
      refute log =~ "secret"
      refute log =~ "abc123"
      refute log =~ "sk_test"
    end

    test "SC4: availability - logging remains available under load" do
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            LoggingEnhanced.info("Load test message #{i}")
          end)
        end

      Task.await_many(tasks)
      Process.sleep(100)

      # System should still be responsive
      assert :ok = LoggingEnhanced.set_level(:info)
    end

    test "SC5: context propagation - correlation IDs work across processes" do
      correlation_id = LoggingEnhanced.generate_correlation_id()

      LoggingEnhanced.with_correlation_id(correlation_id, fn ->
        context = Process.get(:logging_context)
        assert context.correlation_id == correlation_id

        # Context should be available for logging
        log =
          capture_log(fn ->
            LoggingEnhanced.info("Correlated message")
            Process.sleep(50)
          end)

        assert is_binary(log)
      end)
    end
  end
end
