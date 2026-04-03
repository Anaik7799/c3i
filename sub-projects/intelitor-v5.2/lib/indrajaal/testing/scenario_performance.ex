defmodule Indrajaal.Testing.ScenarioPerformance do
  @moduledoc """
  Shared scenario performance extraction for test suites.
  Eliminates duplication across enterprise testing modules.
  """

  @spec extract_scenario_performance(map()) :: map()
  def extract_scenario_performance(results) do
    scenarios = Map.get(results, :scenarios, %{})

    Enum.reduce(scenarios, %{}, fn {scenario_name, scenario_data}, acc ->
      metrics = extract_metrics(scenario_data)
      Map.put(acc, scenario_name, metrics)
    end)
  end

  defp extract_metrics(scenario_data) do
    %{
      duration: Map.get(scenario_data, :duration, 0),
      success_rate: Map.get(scenario_data, :success_rate, 0.0),
      error_count: Map.get(scenario_data, :error_count, 0),
      throughput: Map.get(scenario_data, :throughput, 0.0),
      latency_p95: get_in(scenario_data, [:latency, :p95]) || 0,
      latency_p99: get_in(scenario_data, [:latency, :p99]) || 0
    }
  end
end
