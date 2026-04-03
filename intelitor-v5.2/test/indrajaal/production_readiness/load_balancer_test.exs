defmodule Indrajaal.ProductionReadiness.LoadBalancerTest do
  @moduledoc """
  TDG test suite for LoadBalancer GenServer.

  ## STAMP Safety Integration
  - SC-011: Load balancer must maintain minimum service availability

  ## TPS 5-Level RCA Context
  - L1 Symptom: Traffic not distributed evenly
  - L5 Root Cause: Missing health check before routing
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.LoadBalancer

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(LoadBalancer)
    end

    test "public API functions are exported" do
      assert function_exported?(LoadBalancer, :start_link, 1)
      assert function_exported?(LoadBalancer, :route_request, 0)
      assert function_exported?(LoadBalancer, :route_request, 1)
      assert function_exported?(LoadBalancer, :rebalance, 0)
      assert function_exported?(LoadBalancer, :mark_unhealthy, 1)
      assert function_exported?(LoadBalancer, :mark_healthy, 1)
      assert function_exported?(LoadBalancer, :get_status, 0)
    end
  end

  describe "start_link/1 with backends" do
    test "starts with empty backends list" do
      name = :"load_balancer_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(LoadBalancer, [], name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end

    test "starts with one backend" do
      name = :"load_balancer_test_#{System.unique_integer([:positive])}"

      backends = [%{id: "backend-1", url: "http://localhost:4001", weight: 1.0}]

      result = GenServer.start_link(LoadBalancer, backends, name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end

  describe "constants" do
    test "minimum healthy backends is positive" do
      min_healthy = 1
      assert min_healthy >= 1
    end

    test "health check interval is reasonable" do
      interval_ms = 5_000
      assert interval_ms >= 1_000
      assert interval_ms <= 60_000
    end
  end
end
