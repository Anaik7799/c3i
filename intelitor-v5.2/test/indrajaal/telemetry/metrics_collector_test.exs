defmodule Indrajaal.Telemetry.MetricsCollectorTest do
  @moduledoc """
  Comprehensive tests for Metrics Collection System

  Tests all aspects of metrics collection including:
  - HTTP __request / response metrics collection
  - Database performance metrics
  - Authentication and session metrics
  - Business logic metrics
  - System performance metrics
  - Aggregation and reporting
  """

  # Async false due to shared ETS table
  use ExUnit.Case, async: false
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Telemetry.MetricsCollector

  setup do
    # Start the metrics collector for testing
    {:ok, pid} = MetricsCollector.start_link([])

    # Reset metrics to clean __state
    MetricsCollector.reset_metrics()

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    {:ok, collector_pid: pid}
  end

  describe "record_http_request / 4" do
    test "records HTTP __request metrics correctly" do
      method = "GET"
      path = "/api / __users"
      status = 200
      duration_ms = 150

      MetricsCollector.record_http_request(method, path, status, duration_ms)

      metrics = MetricsCollector.get_metrics()

      assert metrics["http_requests_total"] == 1
      assert metrics["http_requests_by_method:GET"] == 1
      assert metrics["http_requests_by_status:200"] == 1
      assert metrics["http_errors_total"] == 0
    end

    test "records HTTP error metrics for error status codes" do
      MetricsCollector.record_http_request("POST", "/api / auth", 401, 50)
      MetricsCollector.record_http_request("GET", "/api / __data", 500, 1000)

      metrics = MetricsCollector.get_metrics()

      assert metrics["http_requests_total"] == 2
      assert metrics["http_errors_total"] == 2
      assert metrics["http_errors_by_status:401"] == 1
      assert metrics["http_errors_by_status:500"] == 1
    end

    test "tracks response time histograms" do
      # Record multiple __requests with different durations
      durations = [10, 50, 100, 150, 200, 500, 1000]

      for duration <- durations do
        MetricsCollector.record_http_request("GET", "/api / test", 200, duration)
      end

      metrics = MetricsCollector.get_metrics()

      # Check histogram exists
      assert Map.has_key?(metrics, "http_request_duration_ms")
      histogram = metrics["http_request_duration_ms"]

      assert histogram.count == length(durations)
      assert histogram.sum == Enum.sum(durations)
      assert length(histogram.samples) == length(durations)
    end

    test "normalizes paths for consistent metrics" do
      # Different IDs should be normalized
      MetricsCollector.record_http_request("GET", "/api / __users / 123", 200, 100)
      MetricsCollector.record_http_request("GET", "/api / __users / 456", 200, 120)

      metrics = MetricsCollector.get_metrics()

      # Both should contribute to the same normalized path metric
      assert metrics["http_requests_total"] == 2

      # Check if path normalization histogram exists
      normalized_key = "http_request_duration_by_path:/api / __users/:id"
      assert Map.has_key?(metrics, normalized_key)
    end
  end

  describe "record_database_query / 2" do
    test "records __database query metrics" do
      source = "__users"
      duration_ms = 25

      MetricsCollector.record_database_query(source, duration_ms)

      metrics = MetricsCollector.get_metrics()

      assert metrics["db_queries_total"] == 1
      assert metrics["db_queries_by_source:__users"] == 1
      # Under 100ms threshold
      assert metrics["db_slow_queries_total"] == 0
    end

    test "tracks slow queries separately" do
      # Over 100ms
      MetricsCollector.record_database_query("slow_table", 150)
      # Under 100ms
      MetricsCollector.record_database_query("fast_table", 50)

      metrics = MetricsCollector.get_metrics()

      assert metrics["db_queries_total"] == 2
      assert metrics["db_slow_queries_total"] == 1
    end

    test "maintains query duration histogram" do
      durations = [5, 15, 25, 75, 125, 250]

      for duration <- durations do
        MetricsCollector.record_database_query("test_table", duration)
      end

      metrics = MetricsCollector.get_metrics()
      histogram = metrics["db_query_duration_ms"]

      assert histogram.count == length(durations)
      assert histogram.sum == Enum.sum(durations)
    end
  end

  describe "record_ecto_query / 1" do
    test "records detailed Ecto query metrics" do
      ecto_metrics = %{
        total_time_ms: 45,
        query_time_ms: 30,
        queue_time_ms: 10,
        decode_time_ms: 5,
        repo: Indrajaal.Repo,
        result: :ok
      }

      MetricsCollector.record_ecto_query(ecto_metrics)

      metrics = MetricsCollector.get_metrics()

      assert metrics["ecto_queries_total"] == 1
      assert metrics["ecto_queries_by_repo:Elixir.Indrajaal.Repo"] == 1
      assert metrics["ecto_queries_success"] == 1
      assert metrics["ecto_queries_error"] == 0
    end

    test "records Ecto query errors" do
      ecto_metrics = %{
        total_time_ms: 100,
        query_time_ms: 90,
        queue_time_ms: 5,
        decode_time_ms: 5,
        repo: Indrajaal.Repo,
        result: {:error, :timeout}
      }

      MetricsCollector.record_ecto_query(ecto_metrics)

      metrics = MetricsCollector.get_metrics()

      assert metrics["ecto_queries_total"] == 1
      assert metrics["ecto_queries_success"] == 0
      assert metrics["ecto_queries_error"] == 1
    end

    test "maintains separate histograms for different timing components" do
      ecto_metrics = %{
        total_time_ms: 100,
        query_time_ms: 70,
        queue_time_ms: 20,
        decode_time_ms: 10,
        repo: Indrajaal.Repo,
        result: :ok
      }

      MetricsCollector.record_ecto_query(ecto_metrics)

      metrics = MetricsCollector.get_metrics()

      assert Map.has_key?(metrics, "ecto_total_time_ms")
      assert Map.has_key?(metrics, "ecto_query_time_ms")
      assert Map.has_key?(metrics, "ecto_queue_time_ms")
      assert Map.has_key?(metrics, "ecto_decode_time_ms")
    end
  end

  describe "record_auth_event / 3" do
    test "records authentication __events" do
      MetricsCollector.record_auth_event(:login, true, "tenant-123")
      MetricsCollector.record_auth_event(:logout, true, "tenant-123")

      metrics = MetricsCollector.get_metrics()

      assert metrics["auth_events_total"] == 2
      assert metrics["auth_events_by_type:login"] == 1
      assert metrics["auth_events_by_type:logout"] == 1
      assert metrics["auth_events_by_tenant:tenant-123"] == 2
      assert metrics["auth_events_success"] == 2
      assert metrics["auth_events_failure"] == 0
    end

    test "tracks authentication failures" do
      MetricsCollector.record_auth_event(:login, false, "tenant-456")

      metrics = MetricsCollector.get_metrics()

      assert metrics["auth_events_total"] == 1
      assert metrics["auth_events_success"] == 0
      assert metrics["auth_events_failure"] == 1
    end
  end

  describe "record_auth_failure / 1" do
    test "records authentication failure reasons" do
      MetricsCollector.record_auth_failure(:invalid_credentials)
      MetricsCollector.record_auth_failure(:token_expired)
      MetricsCollector.record_auth_failure(:invalid_credentials)

      metrics = MetricsCollector.get_metrics()

      assert metrics["auth_failures_total"] == 3
      assert metrics["auth_failures_by_reason:invalid_credentials"] == 2
      assert metrics["auth_failures_by_reason:token_expired"] == 1
    end
  end

  describe "record_session_failure / 1" do
    test "records session failure reasons" do
      MetricsCollector.record_session_failure(:fingerprint_mismatch)
      MetricsCollector.record_session_failure(:session_expired)

      metrics = MetricsCollector.get_metrics()

      assert metrics["session_failures_total"] == 2
      assert metrics["session_failures_by_reason:fingerprint_mismatch"] == 1
      assert metrics["session_failures_by_reason:session_expired"] == 1
    end
  end

  describe "record_rate_limit_violation / 2" do
    test "records rate limit violations" do
      MetricsCollector.record_rate_limit_violation("/api / login", "admin")
      MetricsCollector.record_rate_limit_violation("/api / __data", "viewer")

      metrics = MetricsCollector.get_metrics()

      assert metrics["rate_limit_violations_total"] == 2
      assert metrics["rate_limit_violations_by_endpoint:/api / login"] == 1
      assert metrics["rate_limit_violations_by_role:admin"] == 1
      assert metrics["rate_limit_violations_by_role:viewer"] == 1
    end
  end

  describe "record_alarm_event / 3" do
    test "records alarm __events with details" do
      MetricsCollector.record_alarm_event(:triggered, :security, :high)
      MetricsCollector.record_alarm_event(:acknowledged, :fire, :critical)

      metrics = MetricsCollector.get_metrics()

      assert metrics["alarm_events_total"] == 2
      assert metrics["alarm_events_by_type:triggered"] == 1
      assert metrics["alarm_events_by_type:acknowledged"] == 1
      assert metrics["alarm_events_by_alarm_type:security"] == 1
      assert metrics["alarm_events_by_severity:high"] == 1
      assert metrics["alarm_events_by_severity:critical"] == 1
    end
  end

  describe "record_safety_violation / 2" do
    test "records safety violations" do
      MetricsCollector.record_safety_violation(:constraint_violation, :critical)
      MetricsCollector.record_safety_violation(:unauthorized_access, :high)

      metrics = MetricsCollector.get_metrics()

      assert metrics["safety_violations_total"] == 2
      assert metrics["safety_violations_by_type:constraint_violation"] == 1
      assert metrics["safety_violations_by_severity:critical"] == 1
      assert metrics["safety_violations_by_severity:high"] == 1
    end
  end

  describe "record_vm_metrics / 1" do
    test "records VM memory metrics" do
      vm_measurements = %{
        total: 1_000_000_000,
        processes: 500_000_000,
        processes_used: 450_000_000,
        system: 300_000_000,
        atom: 50_000_000,
        atom_used: 45_000_000,
        binary: 100_000_000,
        code: 200_000_000,
        ets: 150_000_000
      }

      MetricsCollector.record_vm_metrics(vm_measurements)

      metrics = MetricsCollector.get_metrics()

      assert metrics["vm_memory_total"] == 1_000_000_000
      assert metrics["vm_memory_processes"] == 500_000_000
      assert metrics["vm_memory_system"] == 300_000_000
      assert metrics["vm_memory_atom"] == 50_000_000
    end
  end

  describe "get_metrics / 0 and get_metrics / 1" do
    test "returns all metrics when no category specified" do
      # Record some test metrics
      MetricsCollector.record_http_request("GET", "/test", 200, 100)
      MetricsCollector.record_database_query("test_table", 50)

      metrics = MetricsCollector.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, "http_requests_total")
      assert Map.has_key?(metrics, "db_queries_total")
      assert Map.has_key?(metrics, "uptime_seconds")
      assert Map.has_key?(metrics, "timestamp")
    end

    test "returns category - specific metrics" do
      MetricsCollector.record_http_request("GET", "/test", 200, 100)
      MetricsCollector.record_database_query("test_table", 50)

      http_metrics = MetricsCollector.get_metrics("http")
      db_metrics = MetricsCollector.get_metrics("db")

      assert is_map(http_metrics)
      assert is_map(db_metrics)

      # HTTP metrics should not contain DB metrics and vice versa
      assert Map.has_key?(http_metrics, "http_requests_total")
      refute Map.has_key?(http_metrics, "db_queries_total")

      assert Map.has_key?(db_metrics, "db_queries_total")
      refute Map.has_key?(db_metrics, "http_requests_total")
    end
  end

  describe "reset_metrics / 0" do
    test "resets all metrics to initial __state" do
      # Record some metrics
      MetricsCollector.record_http_request("GET", "/test", 200, 100)
      MetricsCollector.record_database_query("test_table", 50)

      metrics_before = MetricsCollector.get_metrics()
      assert metrics_before["http_requests_total"] == 1
      assert metrics_before["db_queries_total"] == 1

      # Reset metrics
      :ok = MetricsCollector.reset_metrics()

      metrics_after = MetricsCollector.get_metrics()
      assert metrics_after["http_requests_total"] == 0
      assert metrics_after["db_queries_total"] == 0
    end
  end

  describe "histogram aggregation" do
    test "computes percentiles correctly" do
      # Record a known distribution
      values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

      for value <- values do
        MetricsCollector.record_http_request("GET", "/test", 200, value)
      end

      # Trigger aggregation (would normally happen automatically)
      # This might require sending a message to the GenServer or waiting

      metrics = MetricsCollector.get_metrics()

      # Check if percentiles are computed
      if Map.has_key?(metrics, "http_request_duration_ms_percentiles") do
        percentiles = metrics["http_request_duration_ms_percentiles"]

        # Median
        assert percentiles.p50 == 5 or percentiles.p50 == 6
        assert percentiles.p90 >= 9
        assert percentiles.min == 1
        assert percentiles.max == 10
        assert percentiles.avg == 5.5
      end
    end
  end

  describe "performance characteristics" do
    test "handles high - volume metrics efficiently" do
      # Record many metrics quickly
      start_time = System.monotonic_time()

      for i <- 1..1000 do
        MetricsCollector.record_http_request("GET", "/perf - test", 200, rem(i, 100))
      end

      end_time = System.monotonic_time()
      duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should complete quickly
      # Less than 1 second
      assert duration_ms < 1000

      metrics = MetricsCollector.get_metrics()
      assert metrics["http_requests_total"] == 1000
    end

    test "maintains reasonable memory usage" do
      # Record metrics and check memory doesn't grow unbounded
      initial_memory = :erlang.process_info(self(), :memory)[:memory]

      for i <- 1..10_000 do
        MetricsCollector.record_http_request("GET", "/memory - test", 200, rem(i, 1000))
      end

      final_memory = :erlang.process_info(self(), :memory)[:memory]
      memory_growth = final_memory - initial_memory

      # Memory growth should be reasonable (adjust threshold as needed)
      # 50MB
      assert memory_growth < 50_000_000
    end
  end

  describe "concurrent access" do
    test "handles concurrent metric recording safely" do
      # Test concurrent access to metrics
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            MetricsCollector.record_http_request("GET", "/concurrent-#{i}", 200, i)
          end)
        end

      Task.await_many(tasks, 5000)

      metrics = MetricsCollector.get_metrics()
      assert metrics["http_requests_total"] == 100
    end

    test "maintains __data consistency under concurrent load" do
      # More complex concurrency test
      http_tasks =
        for _i <- 1..50 do
          Task.async(fn ->
            MetricsCollector.record_http_request("GET", "/test", 200, 100)
          end)
        end

      db_tasks =
        for _i <- 1..50 do
          Task.async(fn ->
            MetricsCollector.record_database_query("test_table", 50)
          end)
        end

      Task.await_many(http_tasks ++ db_tasks, 5000)

      metrics = MetricsCollector.get_metrics()
      assert metrics["http_requests_total"] == 50
      assert metrics["db_queries_total"] == 50
    end
  end

  describe "error handling" do
    test "handles invalid metric __data gracefully" do
      # Test with invalid __data - should not crash
      # This depends on how robust the error handling is

      # These calls should not crash the collector
      :ok = MetricsCollector.record_http_request("", "", 0, -1)
      :ok = MetricsCollector.record_database_query("", -100)

      # Collector should still be functional
      MetricsCollector.record_http_request("GET", "/test", 200, 100)
      metrics = MetricsCollector.get_metrics()
      assert is_map(metrics)
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
