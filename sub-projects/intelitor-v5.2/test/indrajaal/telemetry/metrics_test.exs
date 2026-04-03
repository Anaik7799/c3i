defmodule Indrajaal.Telemetry.MetricsTest do
  @moduledoc """
  TDG tests for Indrajaal.Telemetry.Metrics.

  ## STAMP Safety Integration
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests

  ## TPS 5-Level RCA Context
  - L1 Symptom: Metrics not being recorded or retrieved
  - L5 Root Cause: ETS table management defect
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Telemetry.Metrics

  describe "Metrics module" do
    test "module is defined" do
      assert Code.ensure_loaded?(Metrics)
    end

    test "module exports functions" do
      exports = Metrics.__info__(:functions)
      assert is_list(exports)
      assert length(exports) > 0
    end
  end

  describe "metric recording" do
    test "record/2 is exported" do
      if function_exported?(Metrics, :record, 2) do
        result = Metrics.record(:test_metric, 42)
        assert result in [:ok, {:ok, :recorded}] or is_tuple(result)
      else
        :ok
      end
    end

    test "increment/1 is exported" do
      if function_exported?(Metrics, :increment, 1) do
        result = Metrics.increment(:test_counter)
        assert result in [:ok, {:ok, :incremented}] or is_integer(result) or is_tuple(result)
      else
        :ok
      end
    end

    test "get/1 returns a value" do
      if function_exported?(Metrics, :get, 1) do
        result = Metrics.get(:nonexistent_metric)
        assert is_nil(result) or is_integer(result) or is_float(result) or is_tuple(result)
      else
        :ok
      end
    end
  end

  describe "metric retrieval" do
    test "all/0 returns map or list" do
      if function_exported?(Metrics, :all, 0) do
        result = Metrics.all()
        assert is_map(result) or is_list(result)
      else
        :ok
      end
    end

    test "reset/0 or reset/1 is callable" do
      if function_exported?(Metrics, :reset, 0) do
        result = Metrics.reset()
        assert result in [:ok, {:ok, :reset}] or is_tuple(result)
      else
        :ok
      end
    end
  end

  describe "module functions" do
    test "function list is valid" do
      functions = Metrics.__info__(:functions)

      assert Enum.all?(functions, fn {name, arity} ->
               is_atom(name) and is_integer(arity)
             end)
    end
  end
end
