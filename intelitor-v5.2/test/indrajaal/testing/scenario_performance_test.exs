defmodule Indrajaal.Testing.ScenarioPerformanceTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Testing.ScenarioPerformance

  describe "extract_scenario_performance/1" do
    test "returns empty map when results has no :scenarios key" do
      result = ScenarioPerformance.extract_scenario_performance(%{})
      assert result == %{}
    end

    test "returns empty map when :scenarios value is an empty map" do
      result = ScenarioPerformance.extract_scenario_performance(%{scenarios: %{}})
      assert result == %{}
    end

    test "extracts all six metric fields for a single scenario" do
      input = %{
        scenarios: %{
          "login_flow" => %{
            duration: 1500,
            success_rate: 0.98,
            error_count: 2,
            throughput: 10.5,
            latency: %{p95: 120, p99: 250}
          }
        }
      }

      result = ScenarioPerformance.extract_scenario_performance(input)

      assert Map.has_key?(result, "login_flow")
      metrics = result["login_flow"]
      assert metrics.duration == 1500
      assert metrics.success_rate == 0.98
      assert metrics.error_count == 2
      assert metrics.throughput == 10.5
      assert metrics.latency_p95 == 120
      assert metrics.latency_p99 == 250
    end

    test "extracts metrics for multiple scenarios independently" do
      input = %{
        scenarios: %{
          "scenario_a" => %{
            duration: 100,
            success_rate: 1.0,
            error_count: 0,
            throughput: 5.0,
            latency: %{p95: 50, p99: 80}
          },
          "scenario_b" => %{
            duration: 200,
            success_rate: 0.9,
            error_count: 10,
            throughput: 20.0,
            latency: %{p95: 90, p99: 150}
          }
        }
      }

      result = ScenarioPerformance.extract_scenario_performance(input)

      assert map_size(result) == 2
      assert result["scenario_a"].duration == 100
      assert result["scenario_b"].duration == 200
      assert result["scenario_a"].success_rate == 1.0
      assert result["scenario_b"].error_count == 10
    end

    test "fills in zero defaults for all missing fields" do
      input = %{scenarios: %{"minimal" => %{}}}
      result = ScenarioPerformance.extract_scenario_performance(input)

      metrics = result["minimal"]
      assert metrics.duration == 0
      assert metrics.success_rate == 0.0
      assert metrics.error_count == 0
      assert metrics.throughput == 0.0
      assert metrics.latency_p95 == 0
      assert metrics.latency_p99 == 0
    end

    test "fills in 0 for latency_p95 and latency_p99 when :latency key is absent" do
      input = %{scenarios: %{"no_latency" => %{duration: 500, success_rate: 0.95}}}
      result = ScenarioPerformance.extract_scenario_performance(input)

      assert result["no_latency"].latency_p95 == 0
      assert result["no_latency"].latency_p99 == 0
    end

    test "fills in 0 for latency when :latency map has no p95 or p99 keys" do
      input = %{scenarios: %{"empty_latency" => %{latency: %{}}}}
      result = ScenarioPerformance.extract_scenario_performance(input)

      assert result["empty_latency"].latency_p95 == 0
      assert result["empty_latency"].latency_p99 == 0
    end

    test "extracts p95 only when p99 is absent" do
      input = %{scenarios: %{"p95_only" => %{latency: %{p95: 75}}}}
      result = ScenarioPerformance.extract_scenario_performance(input)

      assert result["p95_only"].latency_p95 == 75
      assert result["p95_only"].latency_p99 == 0
    end

    test "extracts p99 only when p95 is absent" do
      input = %{scenarios: %{"p99_only" => %{latency: %{p99: 300}}}}
      result = ScenarioPerformance.extract_scenario_performance(input)

      assert result["p99_only"].latency_p95 == 0
      assert result["p99_only"].latency_p99 == 300
    end

    test "output metrics map has exactly the six expected keys" do
      input = %{
        scenarios: %{
          "check_keys" => %{
            duration: 1,
            success_rate: 0.5,
            error_count: 3,
            throughput: 2.0,
            latency: %{p95: 10, p99: 20}
          }
        }
      }

      result = ScenarioPerformance.extract_scenario_performance(input)
      metrics = result["check_keys"]

      expected_keys =
        MapSet.new([
          :duration,
          :success_rate,
          :error_count,
          :throughput,
          :latency_p95,
          :latency_p99
        ])

      assert MapSet.equal?(MapSet.new(Map.keys(metrics)), expected_keys)
    end

    test "preserves string scenario name as output map key" do
      input = %{scenarios: %{"my_custom_scenario_name" => %{}}}
      result = ScenarioPerformance.extract_scenario_performance(input)
      assert Map.has_key?(result, "my_custom_scenario_name")
    end

    test "preserves atom scenario names as output map keys" do
      input = %{scenarios: %{login: %{duration: 500, success_rate: 1.0}}}
      result = ScenarioPerformance.extract_scenario_performance(input)

      assert Map.has_key?(result, :login)
      assert result[:login].duration == 500
    end

    test "returns a plain map, not a struct" do
      result = ScenarioPerformance.extract_scenario_performance(%{scenarios: %{"x" => %{}}})
      assert is_map(result)
      refute is_struct(result)
    end
  end
end
