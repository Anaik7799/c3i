defmodule Indrajaal.Core.Holon.MetricsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.Metrics

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Metrics)
    end
  end

  describe "emit_operation/4" do
    test "function is exported" do
      assert function_exported?(Metrics, :emit_operation, 4)
    end

    test "emits telemetry event without raising" do
      assert :ok =
               Metrics.emit_operation(:test_holon, :read, %{count: 1}, %{
                 layer: :function
               })
    end
  end

  describe "emit_coordination/4" do
    test "function is exported" do
      assert function_exported?(Metrics, :emit_coordination, 4)
    end

    test "emits coordination metric without raising" do
      assert :ok =
               Metrics.emit_coordination(:test_holon, :sync, %{latency_ms: 5}, %{})
    end
  end

  describe "emit_budget/4" do
    test "function is exported" do
      assert function_exported?(Metrics, :emit_budget, 4)
    end

    test "emits budget metric without raising" do
      assert :ok = Metrics.emit_budget(:test_holon, :cpu, %{used: 0.3}, %{})
    end
  end

  describe "emit_plan/4" do
    test "function is exported" do
      assert function_exported?(Metrics, :emit_plan, 4)
    end

    test "emits plan metric without raising" do
      assert :ok = Metrics.emit_plan(:test_holon, :schedule, %{tasks: 3}, %{})
    end
  end

  describe "emit_policy/4" do
    test "function is exported" do
      assert function_exported?(Metrics, :emit_policy, 4)
    end

    test "emits policy metric without raising" do
      assert :ok = Metrics.emit_policy(:test_holon, :enforce, %{rule: "test"}, %{})
    end
  end

  describe "emit_health/4" do
    test "function is exported" do
      assert function_exported?(Metrics, :emit_health, 4)
    end

    test "emits health metric without raising" do
      assert :ok = Metrics.emit_health(:test_holon, :check, %{score: 0.95}, %{})
    end
  end

  describe "measure/4" do
    test "function is exported" do
      assert function_exported?(Metrics, :measure, 4)
    end

    test "measures and returns function result" do
      result = Metrics.measure(:test_holon, :compute, %{}, fn -> 42 end)
      assert result == 42
    end
  end

  describe "summary/1" do
    test "function is exported" do
      assert function_exported?(Metrics, :summary, 1)
    end

    test "returns map summary for holon id" do
      result = Metrics.summary(:test_holon)
      assert is_map(result)
    end
  end

  describe "attach_handlers/0" do
    test "function is exported" do
      assert function_exported?(Metrics, :attach_handlers, 0)
    end

    test "attach_handlers returns :ok" do
      assert :ok = Metrics.attach_handlers()
    end
  end
end
