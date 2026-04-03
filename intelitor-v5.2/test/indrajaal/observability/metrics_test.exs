defmodule Indrajaal.Observability.MetricsTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Metrics

  # Helper: start an isolated Metrics GenServer for tests that need GenServer.call
  defp start_metrics(_context) do
    name = :"metrics_#{System.unique_integer([:positive])}"
    {:ok, pid} = start_supervised({Metrics, name: name})
    %{pid: pid, name: name}
  end

  describe "increment/3" do
    test "returns :ok with default value and tags" do
      assert :ok == Metrics.increment("test.counter.default")
    end

    test "returns :ok with explicit value" do
      assert :ok == Metrics.increment("test.counter.explicit", 5)
    end

    test "returns :ok with value and tags map" do
      assert :ok ==
               Metrics.increment("test.counter.tagged", 1, %{severity: "high", tenant_id: "acme"})
    end

    test "returns :ok for string metric name" do
      assert :ok == Metrics.increment("alarms.acknowledged", 1, %{})
    end

    test "returns :ok with zero value" do
      assert :ok == Metrics.increment("test.counter.zero", 0)
    end

    test "returns :ok with large value" do
      assert :ok == Metrics.increment("test.counter.large", 99_999, %{env: "prod"})
    end
  end

  describe "gauge/3" do
    test "returns :ok with name, value, and default tags" do
      assert :ok == Metrics.gauge("system.active_connections", 42)
    end

    test "returns :ok with explicit tags" do
      assert :ok == Metrics.gauge("system.memory_usage", 1.8, %{unit: "gb", host: "app-01"})
    end

    test "returns :ok for float value" do
      assert :ok == Metrics.gauge("test.gauge.float", 3.14, %{})
    end

    test "returns :ok for zero value" do
      assert :ok == Metrics.gauge("test.gauge.zero", 0)
    end

    test "returns :ok for negative value" do
      assert :ok == Metrics.gauge("test.gauge.negative", -5.0, %{tenant_id: "acme"})
    end

    test "returns :ok for large integer value" do
      assert :ok == Metrics.gauge("test.gauge.large", 1_073_741_824)
    end
  end

  describe "histogram/3" do
    test "returns :ok with name and value" do
      assert :ok == Metrics.histogram("api.response_time", 145.2)
    end

    test "returns :ok with name, value, and tags" do
      assert :ok ==
               Metrics.histogram("api.response_time", 145.2, %{
                 endpoint: "/api/alarms",
                 method: "GET"
               })
    end

    test "returns :ok for integer millisecond value" do
      assert :ok == Metrics.histogram("query.duration_ms", 23)
    end

    test "returns :ok for very small float value" do
      assert :ok == Metrics.histogram("test.histogram.small", 0.001, %{})
    end

    test "returns :ok for very large value" do
      assert :ok == Metrics.histogram("test.histogram.large", 99_999.9, %{env: "prod"})
    end

    test "returns :ok with empty tags map" do
      assert :ok == Metrics.histogram("test.histogram.notags", 100.0, %{})
    end
  end

  describe "summary/3" do
    test "returns :ok with name and value" do
      assert :ok == Metrics.summary("query.execution_time", 23.4)
    end

    test "returns :ok with name, value, and tags" do
      assert :ok ==
               Metrics.summary("query.execution_time", 23.4, %{
                 query_type: "complex",
                 tenant_id: "acme"
               })
    end

    test "returns :ok with empty tags" do
      assert :ok == Metrics.summary("test.summary.empty", 1.0, %{})
    end

    test "returns :ok for zero value" do
      assert :ok == Metrics.summary("test.summary.zero", 0)
    end
  end

  describe "record_business_metric/3" do
    test "returns :ok for known :histogram metric key" do
      assert :ok == Metrics.record_business_metric(:alarm_response_time, 2.5, %{priority: "high"})
    end

    test "returns :ok for known :counter metric key" do
      assert :ok ==
               Metrics.record_business_metric(:user_login_success, 1, %{auth_method: "oauth"})
    end

    test "returns :ok for known :counter feature_usage key" do
      assert :ok == Metrics.record_business_metric(:feature_usage, 1, %{feature: "alarms"})
    end

    test "returns :ok for known :gauge tenant_activity key" do
      assert :ok == Metrics.record_business_metric(:tenant_activity, 0.87, %{tenant_id: "acme"})
    end

    test "returns :ok for unknown metric key (defaults to :gauge)" do
      assert :ok == Metrics.record_business_metric(:unknown_metric_xyz, 42, %{})
    end

    test "returns :ok with default empty tags" do
      assert :ok == Metrics.record_business_metric(:alarm_response_time, 1.0)
    end
  end

  describe "track_kpi/3" do
    test "returns :ok for a named KPI with value" do
      assert :ok == Metrics.track_kpi("revenue_per_tenant", 12_500.0, %{tenant_id: "acme"})
    end

    test "returns :ok with default empty metadata" do
      assert :ok == Metrics.track_kpi("active_users_daily", 450)
    end

    test "returns :ok for string KPI name" do
      assert :ok == Metrics.track_kpi("alarm_ack_rate", 0.97, %{region: "apac"})
    end

    test "returns :ok for zero value KPI" do
      assert :ok == Metrics.track_kpi("failed_logins_today", 0)
    end
  end

  describe "batch_record/1" do
    test "returns :ok for empty list" do
      assert :ok == Metrics.batch_record([])
    end

    test "returns :ok for single counter metric tuple" do
      assert :ok == Metrics.batch_record([{:counter, "test.batch.counter", 1, %{}}])
    end

    test "returns :ok for single gauge metric tuple" do
      assert :ok == Metrics.batch_record([{:gauge, "test.batch.gauge", 42, %{host: "app-01"}}])
    end

    test "returns :ok for single histogram metric tuple" do
      assert :ok == Metrics.batch_record([{:histogram, "test.batch.histogram", 123.4, %{}}])
    end

    test "returns :ok for single summary metric tuple" do
      assert :ok == Metrics.batch_record([{:summary, "test.batch.summary", 9.9, %{}}])
    end

    test "returns :ok for mixed-type batch" do
      metrics = [
        {:counter, "alarms.received", 1, %{severity: "high"}},
        {:gauge, "system.connections", 88, %{}},
        {:histogram, "api.latency", 22.5, %{endpoint: "/health"}},
        {:summary, "db.query", 3.1, %{query_type: "read"}}
      ]

      assert :ok == Metrics.batch_record(metrics)
    end

    test "returns :ok for large batch" do
      metrics = for i <- 1..20, do: {:counter, "test.batch.item_#{i}", i, %{}}
      assert :ok == Metrics.batch_record(metrics)
    end
  end

  describe "export_prometheus/0 (process required)" do
    setup :start_metrics

    test "returns a string", %{pid: pid} do
      # Allow the GenServer to initialize
      :sys.get_status(pid)
      result = GenServer.call(pid, :export_prometheus)
      assert is_binary(result)
    end

    test "returns non-empty Prometheus text with header lines", %{pid: pid} do
      :sys.get_status(pid)
      result = GenServer.call(pid, :export_prometheus)
      assert String.contains?(result, "# HELP")
      assert String.contains?(result, "# TYPE")
    end

    test "Prometheus output ends with newline", %{pid: pid} do
      :sys.get_status(pid)
      result = GenServer.call(pid, :export_prometheus)
      assert String.ends_with?(result, "\n")
    end
  end

  describe "get_metric_value/1 (process required)" do
    setup :start_metrics

    test "returns nil for unknown metric name", %{pid: pid} do
      :sys.get_status(pid)
      result = GenServer.call(pid, {:get_metric_value, "nonexistent.metric"})
      assert is_nil(result)
    end

    test "returns value after gauge is recorded via cast", %{pid: pid} do
      # Send a gauge cast directly to the isolated process
      GenServer.cast(
        pid,
        {:record_metric, :gauge, "test.active_sessions", 77, %{tenant_id: "default"}}
      )

      # Allow the cast to be processed
      :sys.get_status(pid)
      result = GenServer.call(pid, {:get_metric_value, "test.active_sessions"})
      assert result == 77
    end

    test "returns nil for counter (not stored in registry)", %{pid: pid} do
      GenServer.cast(pid, {:record_metric, :counter, "test.counter.check", 5, %{}})
      :sys.get_status(pid)
      result = GenServer.call(pid, {:get_metric_value, "test.counter.check"})
      assert is_nil(result)
    end
  end

  describe "GenServer lifecycle" do
    test "starts successfully as an isolated instance" do
      name = :"metrics_lifecycle_#{System.unique_integer([:positive])}"
      assert {:ok, pid} = start_supervised({Metrics, name: name})
      assert Process.alive?(pid)
    end

    test "started process responds to :sys.get_status" do
      name = :"metrics_status_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({Metrics, name: name})
      assert {:status, ^pid, _mod, _data} = :sys.get_status(pid)
    end

    test "process terminates cleanly via GenServer.stop" do
      name = :"metrics_stop_#{System.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({Metrics, name: name})
      GenServer.stop(pid, :normal)
      refute Process.alive?(pid)
    end
  end

  describe "module API" do
    test "exports increment/3" do
      assert function_exported?(Metrics, :increment, 3)
    end

    test "exports gauge/3" do
      assert function_exported?(Metrics, :gauge, 3)
    end

    test "exports histogram/3" do
      assert function_exported?(Metrics, :histogram, 3)
    end

    test "exports summary/3" do
      assert function_exported?(Metrics, :summary, 3)
    end

    test "exports record_business_metric/3" do
      assert function_exported?(Metrics, :record_business_metric, 3)
    end

    test "exports export_prometheus/0" do
      assert function_exported?(Metrics, :export_prometheus, 0)
    end

    test "exports get_metric_value/1" do
      assert function_exported?(Metrics, :get_metric_value, 1)
    end

    test "exports track_kpi/3" do
      assert function_exported?(Metrics, :track_kpi, 3)
    end

    test "exports batch_record/1" do
      assert function_exported?(Metrics, :batch_record, 1)
    end

    test "exports start_link/1" do
      assert function_exported?(Metrics, :start_link, 1)
    end

    test "exports init/1" do
      assert function_exported?(Metrics, :init, 1)
    end

    test "module is loaded" do
      assert Code.ensure_loaded?(Metrics)
    end
  end
end
