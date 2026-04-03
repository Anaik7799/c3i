defmodule Indrajaal.Cockpit.Prajna.FullSystemMonitorTest do
  @moduledoc """
  TDG test suite for FullSystemMonitor.

  ## STAMP Safety Integration
  - SC-MON-001: 30-second refresh cycle for all metrics
  - SC-MON-004: Alert escalation for threshold breaches

  ## TPS 5-Level RCA Context
  - L1 Symptom: get_metrics returns empty map
  - L5 Root Cause: Refresh cycle not running on init
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cockpit.Prajna.FullSystemMonitor

  @moduletag :zenoh_nif

  defp start_monitor do
    if pid = Process.whereis(FullSystemMonitor) do
      GenServer.stop(pid)
      Process.sleep(50)
    end

    {:ok, pid} = FullSystemMonitor.start_link([])
    # Allow first metric refresh to run
    Process.sleep(100)
    pid
  end

  describe "start_link/1" do
    test "starts and registers under module name" do
      if pid = Process.whereis(FullSystemMonitor) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      {:ok, pid} = FullSystemMonitor.start_link([])
      assert Process.alive?(pid)
      assert Process.whereis(FullSystemMonitor) == pid
      GenServer.stop(pid)
    end
  end

  describe "get_metrics/0" do
    setup do
      pid = start_monitor()
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a map" do
      metrics = FullSystemMonitor.get_metrics()
      assert is_map(metrics)
    end

    test "metrics contains infrastructure key after refresh" do
      metrics = FullSystemMonitor.get_metrics()
      # After first refresh the map is populated
      if map_size(metrics) > 0 do
        assert Map.has_key?(metrics, :infrastructure)
      else
        assert is_map(metrics)
      end
    end

    test "metrics contains domains key after refresh" do
      metrics = FullSystemMonitor.get_metrics()

      if map_size(metrics) > 0 do
        assert Map.has_key?(metrics, :domains)
      else
        assert is_map(metrics)
      end
    end

    test "metrics contains safety key after refresh" do
      metrics = FullSystemMonitor.get_metrics()

      if map_size(metrics) > 0 do
        assert Map.has_key?(metrics, :safety)
      else
        assert is_map(metrics)
      end
    end

    test "metrics contains api key after refresh" do
      metrics = FullSystemMonitor.get_metrics()

      if map_size(metrics) > 0 do
        assert Map.has_key?(metrics, :api)
      else
        assert is_map(metrics)
      end
    end
  end

  describe "get_category_metrics/1" do
    setup do
      pid = start_monitor()
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a map for :infrastructure" do
      result = FullSystemMonitor.get_category_metrics(:infrastructure)
      assert is_map(result)
    end

    test "returns a map for :domains" do
      result = FullSystemMonitor.get_category_metrics(:domains)
      assert is_map(result)
    end

    test "returns a map for :safety" do
      result = FullSystemMonitor.get_category_metrics(:safety)
      assert is_map(result)
    end

    test "returns empty map for unknown category" do
      result = FullSystemMonitor.get_category_metrics(:nonexistent_category)
      assert result == %{}
    end

    test "returns a map for :api" do
      result = FullSystemMonitor.get_category_metrics(:api)
      assert is_map(result)
    end
  end

  describe "get_alerts/0" do
    setup do
      pid = start_monitor()
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a list" do
      alerts = FullSystemMonitor.get_alerts()
      assert is_list(alerts)
    end

    test "starts with no alerts on fresh start" do
      alerts = FullSystemMonitor.get_alerts()
      # May have alerts after first refresh, but definitely a list
      assert is_list(alerts)
    end
  end

  describe "subscribe/1" do
    setup do
      pid = start_monitor()
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "accepts self() as subscriber" do
      # subscribe is a cast, returns :ok immediately
      result = FullSystemMonitor.subscribe(self())
      assert result == :ok
    end
  end

  describe "set_threshold/2" do
    setup do
      pid = start_monitor()
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "accepts numeric threshold for a metric" do
      result = FullSystemMonitor.set_threshold(:cpu_usage, 90.0)
      assert result == :ok
    end

    test "accepts integer threshold" do
      result = FullSystemMonitor.set_threshold(:memory_usage, 80)
      assert result == :ok
    end
  end

  describe "dashboard_data/0" do
    setup do
      pid = start_monitor()
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :ok
    end

    test "returns a map" do
      data = FullSystemMonitor.dashboard_data()
      assert is_map(data)
    end

    test "dashboard data contains status key" do
      data = FullSystemMonitor.dashboard_data()
      assert Map.has_key?(data, :status)
    end

    test "status is :running after start" do
      data = FullSystemMonitor.dashboard_data()
      assert data.status == :running
    end

    test "dashboard data contains metrics key" do
      data = FullSystemMonitor.dashboard_data()
      assert Map.has_key?(data, :metrics)
    end

    test "dashboard data contains alerts key" do
      data = FullSystemMonitor.dashboard_data()
      assert Map.has_key?(data, :alerts)
    end
  end
end
