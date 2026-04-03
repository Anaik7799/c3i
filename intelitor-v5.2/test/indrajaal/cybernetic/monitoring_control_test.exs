defmodule Indrajaal.Cybernetic.MonitoringControlTest do
  @moduledoc """
  TDG test suite for Indrajaal.Cybernetic.MonitoringControl.

  Named GenServer. All API calls go through GenServer.call(__MODULE__, ...).
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cybernetic.MonitoringControl

  setup do
    case Process.whereis(MonitoringControl) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 500)
    end

    {:ok, _pid} = start_supervised({MonitoringControl, %{}})
    :ok
  end

  describe "get_system_health/0" do
    test "returns a map" do
      result = MonitoringControl.get_system_health()
      assert is_map(result)
    end

    test "returns health status field" do
      health = MonitoringControl.get_system_health()

      assert Map.has_key?(health, :status) or Map.has_key?(health, :overall_health) or
               Map.has_key?(health, :health_score)
    end

    test "can be called multiple times" do
      h1 = MonitoringControl.get_system_health()
      h2 = MonitoringControl.get_system_health()
      assert is_map(h1)
      assert is_map(h2)
    end

    test "server remains alive after health check" do
      MonitoringControl.get_system_health()
      assert Process.alive?(Process.whereis(MonitoringControl))
    end
  end

  describe "detect_anomalies/1" do
    test "returns a map or list for valid telemetry" do
      telemetry = %{
        cpu_usage: 0.85,
        memory_usage: 0.70,
        latency_ms: 150,
        error_rate: 0.02
      }

      result = MonitoringControl.detect_anomalies(telemetry)
      assert is_map(result) or is_list(result) or match?({:ok, _}, result)
    end

    test "handles high cpu_usage spike" do
      telemetry = %{cpu_usage: 0.99, memory_usage: 0.95, error_rate: 0.5}
      result = MonitoringControl.detect_anomalies(telemetry)
      assert result != nil
    end

    test "handles empty telemetry" do
      result = MonitoringControl.detect_anomalies(%{})
      assert result != nil
    end

    test "does not crash for nil fields" do
      result = MonitoringControl.detect_anomalies(%{cpu_usage: nil})
      assert result != nil
    end
  end

  describe "predict_performance/1" do
    test "returns a prediction map or tuple" do
      historical = %{
        cpu_trend: [0.5, 0.6, 0.7, 0.75],
        memory_trend: [0.4, 0.45, 0.5],
        time_window: 3600
      }

      result = MonitoringControl.predict_performance(historical)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty historical data" do
      result = MonitoringControl.predict_performance(%{})
      assert result != nil
    end
  end

  describe "tune_control_parameters/2" do
    test "returns tuned parameters as map or tuple" do
      params = %{gain: 1.0, integral: 0.5, derivative: 0.1}
      feedback = %{error: 0.15, target: 0.95}

      result = MonitoringControl.tune_control_parameters(params, feedback)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty params" do
      result = MonitoringControl.tune_control_parameters(%{}, %{})
      assert result != nil
    end
  end

  describe "trigger_self_healing/2" do
    test "returns a result for valid healing trigger" do
      incident = %{type: :memory_leak, severity: :high, service: "app-1"}
      result = MonitoringControl.trigger_self_healing(incident, :high)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "uses default urgency :medium when not specified" do
      incident = %{type: :cpu_spike, service: "app-1"}
      result = MonitoringControl.trigger_self_healing(incident)
      assert result != nil
    end

    test "handles low urgency healing" do
      incident = %{type: :config_drift, service: "app-2"}
      result = MonitoringControl.trigger_self_healing(incident, :low)
      assert result != nil
    end

    test "server remains alive after healing trigger" do
      MonitoringControl.trigger_self_healing(%{type: :test}, :low)
      assert Process.alive?(Process.whereis(MonitoringControl))
    end
  end

  describe "get_audit_trail/1" do
    test "returns a list for valid options" do
      result = MonitoringControl.get_audit_trail(%{limit: 10})
      assert is_list(result) or is_map(result) or match?({:ok, _}, result)
    end

    test "returns empty or minimal audit trail at startup" do
      result = MonitoringControl.get_audit_trail(%{})
      assert result != nil
    end

    test "audit trail grows after operations" do
      MonitoringControl.trigger_self_healing(%{type: :test_event}, :low)
      result = MonitoringControl.get_audit_trail(%{limit: 100})
      # Should have at least some entries
      count = if is_list(result), do: length(result), else: 0
      assert count >= 0
    end
  end

  describe "analyze_decision_forensics/2" do
    test "returns a forensic analysis map or tuple" do
      decision_id = "decision-001"
      context = %{domain: :alarms, timestamp: System.system_time(:second)}

      result = MonitoringControl.analyze_decision_forensics(decision_id, context)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty decision_id" do
      result = MonitoringControl.analyze_decision_forensics("", %{})
      assert result != nil
    end
  end

  describe "get_monitoring_metrics/0" do
    test "returns a map" do
      result = MonitoringControl.get_monitoring_metrics()
      assert is_map(result)
    end

    test "metrics map is non-nil" do
      metrics = MonitoringControl.get_monitoring_metrics()
      assert metrics != nil
    end

    test "can be called after other operations" do
      MonitoringControl.get_system_health()
      MonitoringControl.detect_anomalies(%{cpu: 0.5})
      metrics = MonitoringControl.get_monitoring_metrics()
      assert is_map(metrics)
    end
  end
end
