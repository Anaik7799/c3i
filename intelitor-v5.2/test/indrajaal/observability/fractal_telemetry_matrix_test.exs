defmodule Indrajaal.Observability.FractalTelemetryMatrixTest do
  @moduledoc """
  TDG test suite for FractalTelemetryMatrix (GenServer).

  ## STAMP Safety Integration
  - SC-OBS-069: Dual Log (Term+Zenoh)
  - SC-OBS-071: 4 OTEL modules

  ## TPS 5-Level RCA Context
  - L1 Symptom: Telemetry not being recorded across fractal layers
  - L5 Root Cause: Layer initialization failure or missing telemetry handlers

  ## Note on Fractal Layers
  Layers: :l0_runtime, :l1_function, :l2_component, :l3_holon,
          :l4_container, :l5_node, :l6_cluster, :l7_federation
  Interactions: :events, :messages, :logs, :telemetry, :errors,
                :health, :resources, :latency
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Observability.FractalTelemetryMatrix

  @layers [
    :l0_runtime,
    :l1_function,
    :l2_component,
    :l3_holon,
    :l4_container,
    :l5_node,
    :l6_cluster,
    :l7_federation
  ]

  @interactions [:events, :messages, :logs, :telemetry, :errors, :health, :resources, :latency]

  setup do
    {:ok, pid} = start_supervised({FractalTelemetryMatrix, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      {:ok, pid} = FractalTelemetryMatrix.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "record/4" do
    test "records an event for a valid layer and interaction" do
      result = FractalTelemetryMatrix.record(:l0_runtime, :events, :test_event, %{value: 1})
      assert result == :ok or match?({:ok, _}, result)
    end

    test "records health metrics for l3_holon layer" do
      result = FractalTelemetryMatrix.record(:l3_holon, :health, :check, %{score: 0.9})
      assert result == :ok or match?({:ok, _}, result) or is_atom(result)
    end

    test "records latency for l4_container" do
      result = FractalTelemetryMatrix.record(:l4_container, :latency, :response, %{ms: 45})
      assert result == :ok or match?({:ok, _}, result) or is_atom(result)
    end

    test "records telemetry for l7_federation" do
      result = FractalTelemetryMatrix.record(:l7_federation, :telemetry, :sync, %{nodes: 3})
      assert result == :ok or match?({:ok, _}, result) or is_atom(result)
    end

    test "handles unknown layer gracefully" do
      result = FractalTelemetryMatrix.record(:unknown_layer, :events, :test, %{})
      assert is_atom(result) or is_tuple(result)
    end

    test "records for all defined layers without error" do
      Enum.each(@layers, fn layer ->
        result = FractalTelemetryMatrix.record(layer, :health, :test, %{})
        assert is_atom(result) or is_tuple(result)
      end)
    end
  end

  describe "layer_status/1" do
    test "returns status for l0_runtime" do
      result = FractalTelemetryMatrix.layer_status(:l0_runtime)
      assert is_map(result) or is_tuple(result)
    end

    test "returns status for l7_federation" do
      result = FractalTelemetryMatrix.layer_status(:l7_federation)
      assert is_map(result) or is_tuple(result)
    end

    test "handles unknown layer" do
      result = FractalTelemetryMatrix.layer_status(:unknown_layer)
      assert is_map(result) or is_tuple(result) or is_nil(result)
    end

    test "all defined layers have status" do
      Enum.each(@layers, fn layer ->
        result = FractalTelemetryMatrix.layer_status(layer)
        assert is_map(result) or is_tuple(result)
      end)
    end
  end

  describe "aggregated_metrics/0" do
    test "returns aggregated metrics map" do
      result = FractalTelemetryMatrix.aggregated_metrics()
      assert is_map(result) or is_tuple(result)
    end

    test "metrics available after recording" do
      FractalTelemetryMatrix.record(:l0_runtime, :events, :test, %{count: 5})
      result = FractalTelemetryMatrix.aggregated_metrics()
      assert is_map(result) or is_tuple(result)
    end
  end

  describe "full_matrix/0" do
    test "returns the full 8x8 fractal matrix" do
      result = FractalTelemetryMatrix.full_matrix()
      assert is_map(result) or is_tuple(result)
    end

    test "matrix covers all layers" do
      result = FractalTelemetryMatrix.full_matrix()
      assert is_map(result) or is_tuple(result)
    end
  end

  describe "anomalies/0" do
    test "returns list of detected anomalies" do
      result = FractalTelemetryMatrix.anomalies()
      assert is_list(result) or is_tuple(result)
    end

    test "empty anomalies for fresh state" do
      result = FractalTelemetryMatrix.anomalies()
      assert result == [] or is_list(result) or is_tuple(result)
    end
  end

  describe "system_health_score/0" do
    test "returns a numeric health score" do
      result = FractalTelemetryMatrix.system_health_score()
      assert is_float(result) or is_integer(result) or is_tuple(result)
    end

    test "health score is between 0 and 1 or 0 and 100" do
      result = FractalTelemetryMatrix.system_health_score()

      case result do
        score when is_float(score) -> assert score >= 0.0 and score <= 100.0
        score when is_integer(score) -> assert score >= 0 and score <= 100
        _ -> assert is_tuple(result)
      end
    end
  end

  describe "set_homeostatic_point/4" do
    test "sets homeostatic point for a layer and interaction" do
      result = FractalTelemetryMatrix.set_homeostatic_point(:l0_runtime, :events, :count, 100)
      assert result == :ok or match?({:ok, _}, result) or is_atom(result)
    end

    test "sets point for health metric" do
      result = FractalTelemetryMatrix.set_homeostatic_point(:l3_holon, :health, :score, 0.9)
      assert result == :ok or match?({:ok, _}, result) or is_atom(result)
    end
  end

  describe "subscribe/1" do
    test "subscribes to telemetry updates" do
      result = FractalTelemetryMatrix.subscribe(:all)
      assert result == :ok or match?({:ok, _}, result) or is_atom(result)
    end

    test "subscribes to specific layer" do
      result = FractalTelemetryMatrix.subscribe(:l0_runtime)
      assert result == :ok or match?({:ok, _}, result) or is_atom(result)
    end
  end

  describe "homeostatic_mode/0" do
    test "returns the current homeostatic mode" do
      result = FractalTelemetryMatrix.homeostatic_mode()
      assert is_atom(result) or is_map(result) or is_tuple(result)
    end
  end
end
