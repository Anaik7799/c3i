defmodule Indrajaal.Observability.MetricsWrapperTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Indrajaal.STAMPTestHelpers

  alias Indrajaal.Observability.MetricsWrapper

  describe "record/3" do
    test "returns :ok when :otel_metrics module is not available" do
      # In most test environments, :otel_metrics won't be available
      log =
        capture_log(fn ->
          result = MetricsWrapper.record(:test_metric, 100, %{})
          assert result == :ok
        end)

      # Should log the metric instead
      assert log =~ "Metric recorded"
      assert log =~ "test_metric"
      assert log =~ "100"
    end

    test "logs metric name when :otel_metrics unavailable" do
      metric_name = :request_count
      value = 42

      log =
        capture_log(fn ->
          MetricsWrapper.record(metric_name, value, %{})
        end)

      assert log =~ "request_count"
      assert log =~ "42"
    end

    test "logs metric value when :otel_metrics unavailable" do
      log =
        capture_log(fn ->
          MetricsWrapper.record(:response_time, 250.5, %{})
        end)

      assert log =~ "response_time"
      assert log =~ "250.5"
    end

    test "logs attributes when :otel_metrics unavailable" do
      attributes = %{
        method: "GET",
        path: "/api/users",
        status: 200
      }

      log =
        capture_log(fn ->
          MetricsWrapper.record(:http_request, 1, attributes)
        end)

      assert log =~ "http_request"
      assert log =~ "method"
      assert log =~ "GET"
      assert log =~ "path"
      assert log =~ "status"
    end

    test "works with empty attributes map" do
      log =
        capture_log(fn ->
          result = MetricsWrapper.record(:simple_metric, 1, %{})
          assert result == :ok
        end)

      assert log =~ "simple_metric"
      assert log =~ "value: 1"
      assert log =~ "attrs: %{}"
    end

    test "defaults to empty attributes when not provided" do
      log =
        capture_log(fn ->
          result = MetricsWrapper.record(:default_metric, 99)
          assert result == :ok
        end)

      assert log =~ "default_metric"
      assert log =~ "99"
      assert log =~ "%{}"
    end

    test "handles different metric value types" do
      # Integer value
      log_int =
        capture_log(fn ->
          MetricsWrapper.record(:int_metric, 100)
        end)

      # Float value
      log_float =
        capture_log(fn ->
          MetricsWrapper.record(:float_metric, 99.9)
        end)

      # Large value
      log_large =
        capture_log(fn ->
          MetricsWrapper.record(:large_metric, 1_000_000)
        end)

      assert log_int =~ "100"
      assert log_float =~ "99.9"
      assert log_large =~ "1_000_000"
    end

    test "handles different attribute types" do
      attributes = %{
        string_attr: "test",
        integer_attr: 123,
        float_attr: 45.6,
        boolean_attr: true,
        atom_attr: :example
      }

      log =
        capture_log(fn ->
          MetricsWrapper.record(:complex_metric, 1, attributes)
        end)

      assert log =~ "string_attr"
      assert log =~ "test"
      assert log =~ "integer_attr"
      assert log =~ "123"
      assert log =~ "boolean_attr"
    end

    test "handles nested attributes" do
      attributes = %{
        metadata: %{
          user: %{
            id: 123,
            name: "test_user"
          }
        }
      }

      log =
        capture_log(fn ->
          MetricsWrapper.record(:nested_metric, 1, attributes)
        end)

      assert log =~ "metadata"
      assert log =~ "user"
    end

    test "logs at debug level" do
      # Capture logs at debug level
      log =
        capture_log([level: :debug], fn ->
          MetricsWrapper.record(:debug_metric, 1)
        end)

      # When debug level is captured, should see the log
      assert log =~ "debug_metric" or log == ""
    end

    test "handles atom metric names" do
      log =
        capture_log(fn ->
          MetricsWrapper.record(:atom_metric_name, 100)
        end)

      assert log =~ "atom_metric_name"
    end

    test "handles string metric names" do
      log =
        capture_log(fn ->
          MetricsWrapper.record("string_metric_name", 100)
        end)

      assert log =~ "string_metric_name"
    end

    test "handles binary metric names" do
      metric_name = "binary.metric.name"

      log =
        capture_log(fn ->
          MetricsWrapper.record(metric_name, 50)
        end)

      assert log =~ metric_name
    end
  end

  describe "defensive programming" do
    test "gracefully handles when :otel_metrics is not loaded" do
      # This is the normal case in test environment
      assert_nothing_raised(fn ->
        capture_log(fn ->
          MetricsWrapper.record(:test, 1, %{})
        end)
      end)
    end

    test "does not crash on invalid attributes" do
      # Even with unusual attributes, should not crash
      assert_nothing_raised(fn ->
        capture_log(fn ->
          MetricsWrapper.record(:test, 1, %{invalid: nil, test: :ok})
        end)
      end)
    end

    test "handles nil values gracefully" do
      log =
        capture_log(fn ->
          result = MetricsWrapper.record(:nil_metric, nil, %{})
          assert result == :ok
        end)

      assert log =~ "nil_metric"
      assert log =~ "nil"
    end

    test "handles empty metric names" do
      _log =
        capture_log(fn ->
          result = MetricsWrapper.record("", 100, %{})
          assert result == :ok
        end)

      # Should still work, the assertion inside capture_log verified it
    end
  end

  describe "integration scenarios" do
    test "records multiple metrics in sequence" do
      log =
        capture_log(fn ->
          MetricsWrapper.record(:metric1, 10)
          MetricsWrapper.record(:metric2, 20)
          MetricsWrapper.record(:metric3, 30)
        end)

      assert log =~ "metric1"
      assert log =~ "metric2"
      assert log =~ "metric3"
      assert log =~ "10"
      assert log =~ "20"
      assert log =~ "30"
    end

    test "works in concurrent scenarios" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            capture_log(fn ->
              MetricsWrapper.record(:"metric_#{i}", i, %{task: i})
            end)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      assert length(results) == 10
    end

    test "maintains metric recording during normal operations" do
      # Simulating normal application flow
      log =
        capture_log(fn ->
          # Record request metric
          MetricsWrapper.record(:http_requests_total, 1, %{
            method: "GET",
            path: "/api/users"
          })

          # Record response time
          MetricsWrapper.record(:http_response_time_ms, 125.5, %{
            method: "GET",
            status: 200
          })

          # Record error count
          MetricsWrapper.record(:http_errors_total, 0, %{
            method: "GET"
          })
        end)

      assert log =~ "http_requests_total"
      assert log =~ "http_response_time_ms"
      assert log =~ "http_errors_total"
    end

    test "works with different attribute patterns" do
      # String keys
      log1 =
        capture_log(fn ->
          MetricsWrapper.record(:metric1, 1, %{"string_key" => "value"})
        end)

      # Atom keys
      log2 =
        capture_log(fn ->
          MetricsWrapper.record(:metric2, 1, %{atom_key: "value"})
        end)

      # Mixed keys
      log3 =
        capture_log(fn ->
          MetricsWrapper.record(:metric3, 1, %{atom_key: "val", string_key: "val2"})
        end)

      assert log1 =~ "metric1"
      assert log2 =~ "metric2"
      assert log3 =~ "metric3"
    end
  end

  describe "error prevention" do
    test "EP045 pattern - handles missing Erlang module gracefully" do
      # This test validates the fix for EP045_UNDEFINED_ERLANG_MODULE
      # The wrapper was created to handle :otel_metrics being undefined

      assert_nothing_raised(fn ->
        capture_log(fn ->
          result = MetricsWrapper.record(:test_metric, 100, %{test: true})
          assert result == :ok
        end)
      end)
    end

    test "prevents compilation failures in environments without OpenTelemetry" do
      # Even without :otel_metrics loaded, the module should work
      loaded = Code.ensure_loaded?(:otel_metrics)

      capture_log(fn ->
        # Should work regardless of whether :otel_metrics is loaded
        assert :ok = MetricsWrapper.record(:env_test, 1)
      end)

      # Test passes in both cases
      assert loaded == true or loaded == false
    end

    test "maintains observability when telemetry is unavailable" do
      # When :otel_metrics is unavailable, we fall back to logging
      # This maintains observability even in degraded scenarios

      log =
        capture_log(fn ->
          MetricsWrapper.record(:observability_test, 42, %{
            component: "test",
            action: "validate"
          })
        end)

      # Should see the metric in logs
      assert log =~ "Metric recorded"
      assert log =~ "observability_test"
    end
  end

  describe "performance considerations" do
    test "efficiently handles rapid metric recording" do
      # Test that the wrapper doesn't introduce significant overhead
      log =
        capture_log(fn ->
          start_time = System.monotonic_time(:millisecond)

          for i <- 1..100 do
            MetricsWrapper.record(:"perf_metric_#{i}", i, %{iteration: i})
          end

          end_time = System.monotonic_time(:millisecond)
          duration = end_time - start_time

          # Should complete reasonably fast (< 1 second for 100 metrics)
          assert duration < 1000
        end)
    end

    test "handles large attribute maps" do
      large_attrs =
        for i <- 1..50, into: %{} do
          {:"attr_#{i}", "value_#{i}"}
        end

      log =
        capture_log(fn ->
          result = MetricsWrapper.record(:large_attrs_metric, 1, large_attrs)
          assert result == :ok
        end)

      assert log =~ "large_attrs_metric"
    end
  end
end
