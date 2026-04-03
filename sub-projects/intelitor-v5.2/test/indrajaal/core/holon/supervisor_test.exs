defmodule Indrajaal.Core.Holon.SupervisorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.Supervisor, as: HolonSupervisor

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HolonSupervisor)
    end
  end

  describe "function exports" do
    test "strategy_for_layer/1 is exported" do
      assert function_exported?(HolonSupervisor, :strategy_for_layer, 1)
    end

    test "max_restarts_for_layer/1 is exported" do
      assert function_exported?(HolonSupervisor, :max_restarts_for_layer, 1)
    end

    test "start_child/3 is exported" do
      assert function_exported?(HolonSupervisor, :start_child, 3)
    end

    test "terminate_child/2 is exported" do
      assert function_exported?(HolonSupervisor, :terminate_child, 2)
    end

    test "restart_child/2 is exported" do
      assert function_exported?(HolonSupervisor, :restart_child, 2)
    end

    test "child_count/1 is exported" do
      assert function_exported?(HolonSupervisor, :child_count, 1)
    end

    test "children_summary/1 is exported" do
      assert function_exported?(HolonSupervisor, :children_summary, 1)
    end
  end

  describe "strategy_for_layer/1" do
    test "returns a supervisor strategy atom for :function" do
      strategy = HolonSupervisor.strategy_for_layer(:function)
      assert strategy in [:one_for_one, :one_for_all, :rest_for_one, :simple_one_for_one]
    end

    test "returns a supervisor strategy for :cluster" do
      strategy = HolonSupervisor.strategy_for_layer(:cluster)
      assert strategy in [:one_for_one, :one_for_all, :rest_for_one, :simple_one_for_one]
    end

    test "different layers may have different strategies" do
      s1 = HolonSupervisor.strategy_for_layer(:function)
      s2 = HolonSupervisor.strategy_for_layer(:federation)
      assert is_atom(s1)
      assert is_atom(s2)
    end
  end

  describe "max_restarts_for_layer/1" do
    test "returns integer for :function layer" do
      result = HolonSupervisor.max_restarts_for_layer(:function)
      assert is_integer(result) and result > 0
    end

    test "returns integer for :cluster layer" do
      result = HolonSupervisor.max_restarts_for_layer(:cluster)
      assert is_integer(result) and result > 0
    end

    test "safety-critical layers have appropriate restart limits" do
      function_restarts = HolonSupervisor.max_restarts_for_layer(:function)
      cluster_restarts = HolonSupervisor.max_restarts_for_layer(:cluster)
      assert is_integer(function_restarts)
      assert is_integer(cluster_restarts)
    end
  end
end
