defmodule Indrajaal.SMRITI.Automation.HealthMonitoringTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Automation.HealthMonitoring

  describe "Health Monitoring" do
    test "checks system vitals" do
      report = HealthMonitoring.check_health()
      assert Map.has_key?(report, :status)
      assert Map.has_key?(report, :cpu_usage)
      assert Map.has_key?(report, :memory_free)
    end

    test "identifies unhealthy state" do
      # Mocking unhealthy metrics
      bad_metrics = %{cpu_usage: 99, memory_free: 10}
      assert HealthMonitoring.analyze_metrics(bad_metrics) == :critical
    end
  end
end
