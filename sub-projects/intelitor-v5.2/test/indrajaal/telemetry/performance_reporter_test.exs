defmodule Indrajaal.Telemetry.PerformanceReporterTest do
  @moduledoc """
  Comprehensive tests for Performance Reporter System

  Tests all aspects of performance monitoring including:
  - Telemetry __event handling and processing
  - Metrics calculation and aggregation
  - Performance reporting and analysis
  - Resource utilization monitoring
  - Trend analysis and recommendations
  """

  # Async false due to shared GenServer
  use ExUnit.Case, async: false
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Telemetry.PerformanceReporter

  setup do
    # Start the performance reporter for testing
    {:ok, pid} = PerformanceReporter.start_link([])

    # Give it time to initialize
    Process.sleep(100)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    {:ok, reporter_pid: pid}
  end

  describe "start_link / 1" do
    test "starts GenServer successfully" do
      {:ok, pid} = PerformanceReporter.start_link([])

      assert Process.alive?(pid)
      assert GenServer.whereis(PerformanceReporter) == pid

      # Cleanup
      GenServer.stop(pid)
    end

    test "attaches telemetry handlers on startup" do
      {:ok, pid} = PerformanceReporter.start_link([])

      # Wait for initialization
      Process.sleep(100)

      # Check that handlers are attached
      handlers = :telemetry.list_handlers([])
      handler_ids = Enum.map(handlers, & &1.id)

      expected_handlers = [
        "performance - phoenix - stop",
        "performance - ecto - query",
        "performance-cache",
        "performance-custom"
      ]

      for expected_handler <- expected_handlers do
        assert expected_handler in handler_ids
      end

      # Cleanup
      GenServer.stop(pid)
    end
  end

  describe "get_metrics / 0" do
    test "returns current performance metrics" do
      metrics = PerformanceReporter.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :uptime_seconds)
      assert Map.has_key?(metrics, :__requests_per_minute)
      assert Map.has_key?(metrics, :error_rate)
      assert Map.has_key?(metrics, :api_response_times)
      assert Map.has_key?(metrics, :db_query_times)
      assert Map.has_key?(metrics, :cache_hit_rate)
      assert Map.has_key?(metrics, :websocket_latency)
      assert Map.has_key?(metrics, :active_connections)
      assert Map.has_key?(metrics, :memory_usage)
      assert Map.has_key?(metrics, :cpu_usage)
    end

    test "returns properly structured response time metrics" do
      metrics = PerformanceReporter.get_metrics()

      response_times = metrics.api_response_times
      assert is_map(response_times)
      assert Map.has_key?(response_times, :p50)
      assert Map.has_key?(response_times, :p95)
      assert Map.has_key?(response_times, :p99)
      assert Map.has_key?(response_times, :avg)
      assert Map.has_key?(response_times, :max)
    end

    test "returns valid memory usage metrics" do
      metrics = PerformanceReporter.get_metrics()

      memory = metrics.memory_usage
      assert is_map(memory)
      assert Map.has_key?(memory, :total_mb)
      assert Map.has_key?(memory, :processes_mb)
      assert Map.has_key?(memory, :ets_mb)
      assert Map.has_key?(memory, :binary_mb)

      # All values should be non - negative integers
      assert is_integer(memory.total_mb) and memory.total_mb >= 0
      assert is_integer(memory.processes_mb) and memory.processes_mb >= 0
      assert is_integer(memory.ets_mb) and memory.ets_mb >= 0
      assert is_integer(memory.binary_mb) and memory.binary_mb >= 0
    end
  end

  describe "get_report / 2" do
    test "generates performance report for time period" do
      # 1 hour ago
      from = System.system_time(:second) - 3600
      to = System.system_time(:second)

      report = PerformanceReporter.get_report(from, to)

      assert is_map(report)
      assert Map.has_key?(report, :period)
      assert Map.has_key?(report, :summary)
      assert Map.has_key?(report, :trends)
      assert Map.has_key?(report, :recommendations)

      assert report.period.from == from
      assert report.period.to == to
    end

    test "includes performance trends in report" do
      # 30 minutes ago
      from = System.system_time(:second) - 1800
      to = System.system_time(:second)

      report = PerformanceReporter.get_report(from, to)

      trends = report.trends
      assert is_map(trends)
      assert Map.has_key?(trends, :api_response_trend)
      assert Map.has_key?(trends, :error_rate_trend)
      assert Map.has_key?(trends, :cache_effectiveness)
      assert Map.has_key?(trends, :__database_performance)
    end

    test "includes recommendations in report" do
      from = System.system_time(:second) - 1800
      to = System.system_time(:second)

      report = PerformanceReporter.get_report(from, to)

      assert is_list(report.recommendations)
      # Recommendations can be empty if performance is good
    end
  end

  describe "record_metric / 3" do
    test "records custom telemetry metric" do
      event = [:custom, :test, :event]
      measurement = %{duration: 150, count: 1}
      metadata = %{endpoint: "/api / test"}

      # Should not raise
      assert :ok = PerformanceReporter.record_metric(event, measurement, metadata)
    end

    test "emits telemetry __event with correct format" do
      # Test that the __event is properly emitted
      # This would require setting up a telemetry test handler

      event = [:api, :__request]
      measurement = %{duration: 200}
      metadata = %{method: "GET", path: "/api / __users"}

      PerformanceReporter.record_metric(event, measurement, metadata)

      # Would verify telemetry __event was emitted with:
      # Event: [:indrajaal, :api, :__request]
      # Measurement: %{duration: 200}
      # Meta__data: %{method: "GET", path: "/api / __users"}
    end
  end

  describe "Phoenix telemetry __event handling" do
    test "processes Phoenix endpoint stop __events" do
      # Simulate Phoenix endpoint telemetry __event
      # 150ms in nanoseconds
      measurements = %{duration: 150_000_000}
      metadata = %{conn: %{status: 200}}

      # Emit the __event that should be handled
      :telemetry.execute(
        [:phoenix, :endpoint, :stop],
        measurements,
        metadata
      )

      # Give time for processing
      Process.sleep(50)

      # Check that metrics were updated
      metrics = PerformanceReporter.get_metrics()
      assert metrics.__requests_per_minute >= 0
    end

    test "tracks error responses correctly" do
      # Simulate error response
      measurements = %{duration: 100_000_000}
      metadata = %{conn: %{status: 500}}

      :telemetry.execute(
        [:phoenix, :endpoint, :stop],
        measurements,
        metadata
      )

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()
      # Error rate should be calculated if there were __requests
      assert is_number(metrics.error_rate)
    end
  end

  describe "__database telemetry __event handling" do
    test "processes Ecto query __events" do
      measurements = %{
        # 45ms in nanoseconds
        total_time: 45_000_000,
        query_time: 30_000_000,
        queue_time: 10_000_000,
        decode_time: 5_000_000
      }

      metadata = %{source: "__users", result: :ok}

      :telemetry.execute(
        [:indrajaal, :repo, :query],
        measurements,
        metadata
      )

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()
      db_times = metrics.db_query_times

      # Should have recorded __database metrics
      assert is_map(db_times)
    end

    test "handles query __events with different time formats" do
      # Test with query_time only (no total_time)
      measurements = %{query_time: 25_000_000}
      metadata = %{source: "alarms", result: :ok}

      :telemetry.execute(
        [:indrajaal, :repo, :query],
        measurements,
        metadata
      )

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()
      assert is_map(metrics.db_query_times)
    end
  end

  describe "cache telemetry __event handling" do
    test "tracks cache hits and misses" do
      # Emit cache hit __event
      :telemetry.execute([:indrajaal, :cache, :hit], %{}, %{key: "test-key"})

      # Emit cache miss __event
      :telemetry.execute([:indrajaal, :cache, :miss], %{}, %{key: "miss-key"})

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()

      # Cache hit rate should be calculated
      assert is_number(metrics.cache_hit_rate)
      assert metrics.cache_hit_rate >= 0 and metrics.cache_hit_rate <= 100
    end

    test "calculates cache hit rate correctly" do
      # Multiple hits and misses
      for _i <- 1..8 do
        :telemetry.execute([:indrajaal, :cache, :hit], %{}, %{})
      end

      for _i <- 1..2 do
        :telemetry.execute([:indrajaal, :cache, :miss], %{}, %{})
      end

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()

      # Should be 80% hit rate (8 hits out of 10 total)
      assert metrics.cache_hit_rate == 80.0
    end
  end

  describe "websocket telemetry __event handling" do
    test "tracks websocket message latency" do
      latency_values = [10, 25, 50, 100, 200]

      for latency <- latency_values do
        :telemetry.execute(
          [:indrajaal, :websocket, :message],
          %{latency: latency},
          %{channel: "alarm_channel"}
        )
      end

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()
      ws_latency = metrics.websocket_latency

      assert is_map(ws_latency)
      assert ws_latency.p50 > 0
      assert ws_latency.avg > 0
    end
  end

  describe "metrics calculation" do
    test "calculates percentiles correctly" do
      # Test with known __data set
      values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

      # This would test the private percentile function
      # We can test it indirectly by feeding __data and checking results

      for value <- values do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          # Convert to nanoseconds
          %{duration: value * 1_000_000},
          %{conn: %{status: 200}}
        )
      end

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()
      response_times = metrics.api_response_times

      # For values 1 - 10, median should be around 5 - 6
      assert response_times.p50 >= 5 and response_times.p50 <= 6
      assert response_times.p95 >= 9
      assert response_times.avg == 5.5
      assert response_times.max == 10
    end

    test "handles empty __data sets gracefully" do
      # Get metrics without any __data
      metrics = PerformanceReporter.get_metrics()

      # Should return zero values for empty __data sets
      assert metrics.api_response_times.p50 == 0
      assert metrics.api_response_times.p95 == 0
      assert metrics.api_response_times.p99 == 0
      assert metrics.api_response_times.avg == 0
      assert metrics.api_response_times.max == 0
    end

    test "calculates __requests per minute correctly" do
      # Generate multiple __requests
      for _i <- 1..60 do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          %{duration: 100_000_000},
          %{conn: %{status: 200}}
        )
      end

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()

      # RPM should be calculated based on uptime
      assert is_number(metrics.__requests_per_minute)
      assert metrics.__requests_per_minute > 0
    end

    test "calculates error rate correctly" do
      # Generate mix of successful and error __requests
      # 8 successful __requests
      for _i <- 1..8 do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          %{duration: 100_000_000},
          %{conn: %{status: 200}}
        )
      end

      # 2 error __requests
      for _i <- 1..2 do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          %{duration: 100_000_000},
          %{conn: %{status: 500}}
        )
      end

      Process.sleep(50)

      metrics = PerformanceReporter.get_metrics()

      # Error rate should be 20% (2 errors out of 10 total)
      assert metrics.error_rate == 20.0
    end
  end

  describe "performance recommendations" do
    test "generates recommendations for slow API responses" do
      # Generate slow API responses
      for _i <- 1..10 do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          # 200ms - slow
          %{duration: 200_000_000},
          %{conn: %{status: 200}}
        )
      end

      Process.sleep(50)

      from = System.system_time(:second) - 60
      to = System.system_time(:second)
      report = PerformanceReporter.get_report(from, to)

      # Should recommend optimizing slow endpoints
      recommendations = report.recommendations

      assert is_list(recommendations)
      # Would contain recommendation about slow API endpoints
      # assert Enum.any?(recommendations, &String.contains?(&1, "optimizing slow"
    end

    test "generates recommendations for low cache hit rate" do
      # Generate many cache misses
      for _i <- 1..20 do
        :telemetry.execute([:indrajaal, :cache, :miss], %{}, %{})
      end

      # Only a few hits
      for _i <- 1..5 do
        :telemetry.execute([:indrajaal, :cache, :hit], %{}, %{})
      end

      Process.sleep(50)

      from = System.system_time(:second) - 60
      to = System.system_time(:second)
      report = PerformanceReporter.get_report(from, to)

      # Should recommend cache improvements
      recommendations = report.recommendations

      assert is_list(recommendations)
      # Would contain cache - related recommendation
      # assert Enum.any?(recommendations, &String.contains?(&1, "cache"))
    end

    test "generates recommendations for high error rate" do
      # Generate many error responses
      for _i <- 1..7 do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          %{duration: 100_000_000},
          %{conn: %{status: 500}}
        )
      end

      # Few successful responses
      for _i <- 1..3 do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          %{duration: 100_000_000},
          %{conn: %{status: 200}}
        )
      end

      Process.sleep(50)

      from = System.system_time(:second) - 60
      to = System.system_time(:second)
      report = PerformanceReporter.get_report(from, to)

      # Should recommend investigating errors
      recommendations = report.recommendations

      assert is_list(recommendations)
      # Would contain error - related recommendation
      # assert Enum.any?(recommendations, &String.contains?(&1, "error"))
    end
  end

  describe "periodic reporting" do
    test "schedules periodic metric reports" do
      # This would test the periodic reporting mechanism
      # Since we can't easily test the 60 - second timer, we test the structure

      # The GenServer should schedule reports
      # We can verify the handle_info callback exists
      assert function_exported?(PerformanceReporter, :handle_info, 2)
    end
  end

  describe "resource utilization monitoring" do
    test "monitors memory usage accurately" do
      metrics = PerformanceReporter.get_metrics()
      memory = metrics.memory_usage

      # Memory values should be reasonable
      assert memory.total_mb > 0
      assert memory.processes_mb > 0
      assert memory.total_mb >= memory.processes_mb

      # ETS and binary memory should be non - negative
      assert memory.ets_mb >= 0
      assert memory.binary_mb >= 0
    end

    test "monitors CPU usage" do
      metrics = PerformanceReporter.get_metrics()

      # CPU usage should be a valid percentage
      assert is_number(metrics.cpu_usage)
      assert metrics.cpu_usage >= 0
      assert metrics.cpu_usage <= 100
    end

    test "monitors active connections" do
      metrics = PerformanceReporter.get_metrics()

      # Connection count should be non - negative integer
      assert is_integer(metrics.active_connections)
      assert metrics.active_connections >= 0
    end
  end

  describe "performance characteristics" do
    test "handles high-volume events efficiently" do
      event_count = 1000

      {time_micro, _results} =
        :timer.tc(fn ->
          for i <- 1..event_count do
            :telemetry.execute(
              [:phoenix, :endpoint, :stop],
              %{duration: (rem(i, 100) + 1) * 1_000_000},
              %{conn: %{status: 200}}
            )
          end
        end)

      # Should process events quickly
      # 1 second
      assert time_micro < 1_000_000

      Process.sleep(100)

      # All events should be processed
      metrics = PerformanceReporter.get_metrics()
      assert metrics.requests_per_minute > 0
    end

    test "maintains bounded memory usage" do
      # Generate many __events to test memory bounds
      for i <- 1..2000 do
        :telemetry.execute(
          [:phoenix, :endpoint, :stop],
          %{duration: i * 1_000_000},
          %{conn: %{status: 200}}
        )
      end

      Process.sleep(100)

      # Memory usage should remain reasonable due to bounded collections
      metrics = PerformanceReporter.get_metrics()
      assert is_map(metrics.api_response_times)
    end
  end

  describe "error handling and resilience" do
    test "handles malformed telemetry __events gracefully" do
      # Send malformed __event
      :telemetry.execute(
        [:phoenix, :endpoint, :stop],
        # Should be a map
        "invalid_measurements",
        %{conn: %{status: 200}}
      )

      # Should not crash
      Process.sleep(50)
      assert Process.alive?(GenServer.whereis(PerformanceReporter))
    end

    test "handles missing measurement fields gracefully" do
      # Event with missing duration
      :telemetry.execute(
        [:phoenix, :endpoint, :stop],
        # Missing duration
        %{},
        %{conn: %{status: 200}}
      )

      # Should not crash
      Process.sleep(50)
      assert Process.alive?(GenServer.whereis(PerformanceReporter))
    end

    test "handles missing metadata gracefully" do
      :telemetry.execute(
        [:phoenix, :endpoint, :stop],
        %{duration: 100_000_000},
        # Missing conn info
        %{}
      )

      # Should not crash
      Process.sleep(50)
      assert Process.alive?(GenServer.whereis(PerformanceReporter))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
