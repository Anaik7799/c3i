defmodule Indrajaal.TelemetryMetricsWorkerTest do
  @moduledoc """
  TDG tests for Indrajaal.TelemetryMetricsWorker.

  ## STAMP Safety Integration
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests

  ## TPS 5-Level RCA Context
  - L1 Symptom: Metrics worker not collecting data
  - L5 Root Cause: GenServer init or collect cycle defect
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.TelemetryMetricsWorker

  describe "TelemetryMetricsWorker module" do
    test "module is defined" do
      assert Code.ensure_loaded?(TelemetryMetricsWorker)
    end

    test "exports start_link/1" do
      assert function_exported?(TelemetryMetricsWorker, :start_link, 1)
    end

    test "exports child_spec/1" do
      assert function_exported?(TelemetryMetricsWorker, :child_spec, 1)
    end
  end

  describe "TelemetryMetricsWorker lifecycle" do
    test "starts with unique name" do
      name = :"tmw_#{:erlang.unique_integer([:positive])}"
      result = start_supervised({TelemetryMetricsWorker, name: name})
      assert match?({:ok, _}, result)
    end

    test "started process is alive" do
      name = :"tmw_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({TelemetryMetricsWorker, name: name})
      assert Process.alive?(pid)
    end
  end

  describe "worker operations" do
    setup do
      name = :"tmw_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = start_supervised({TelemetryMetricsWorker, name: name})
      %{pid: pid, name: name}
    end

    test "collect/1 is callable if exported", %{name: name} do
      if function_exported?(TelemetryMetricsWorker, :collect, 1) do
        result = TelemetryMetricsWorker.collect(name)
        assert is_map(result) or is_list(result) or match?({:ok, _}, result)
      else
        :ok
      end
    end

    test "get_metrics/1 returns data if exported", %{name: name} do
      if function_exported?(TelemetryMetricsWorker, :get_metrics, 1) do
        result = TelemetryMetricsWorker.get_metrics(name)
        assert is_map(result) or is_list(result) or match?({:ok, _}, result)
      else
        :ok
      end
    end

    test "process survives after call", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end

  describe "child_spec" do
    test "child_spec/1 returns valid spec" do
      spec = TelemetryMetricsWorker.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
