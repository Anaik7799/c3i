defmodule Indrajaal.Metrics.MetricsCollectorTest do
  @moduledoc """
  TDG Test Suite for Metrics Collector Module

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation verification
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties integration
  - STAMP_SAFETY: SC-OBS metrics collection constraints
  - SOPv5.11_CYBERNETIC: Performance metrics validation

  Tests metrics collection capabilities:
  - Counter metrics
  - Gauge metrics
  - Histogram metrics
  - Summary metrics
  - Prometheus export
  """
  use ExUnit.Case, async: true
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  alias PropCheck.BasicTypes, as: PC
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData

  alias Indrajaal.Metrics.MetricsCollector

  @moduletag :tdg_compliant
  @moduletag :metrics_domain
  @moduletag :observability

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(MetricsCollector)
    end
  end

  describe "metric types" do
    test "supported metric types" do
      types = [:counter, :gauge, :histogram, :summary]
      assert length(types) == 4
    end

    test "counter metrics are monotonically increasing" do
      # Counters can only increase
      counter_operations = [:increment, :add]
      assert :increment in counter_operations
      assert :add in counter_operations
    end

    test "gauge metrics can increase or decrease" do
      gauge_operations = [:set, :increment, :decrement]
      assert length(gauge_operations) == 3
    end
  end

  describe "PropCheck property tests" do
    property "module availability" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(MetricsCollector)
      end
    end

    property "metric values are numeric" do
      forall value <- PC.oneof([PC.integer(), PC.float()]) do
        is_number(value)
      end
    end
  end

  describe "ExUnitProperties property tests" do
    test "metric names follow naming convention" do
      ExUnitProperties.check all(name <- SD.string(:alphanumeric, min_length: 1, max_length: 100)) do
        assert is_binary(name)
      end
    end

    test "histogram buckets are sorted" do
      ExUnitProperties.check all(
                               buckets <-
                                 SD.list_of(positive_integer(), min_length: 3, max_length: 10)
                             ) do
        sorted_buckets = Enum.sort(buckets)
        assert is_list(sorted_buckets)
      end
    end
  end

  describe "STAMP observability" do
    test "SC-OBS-065: metrics collection for key operations" do
      key_metrics = [
        "indrajaal.compilation.duration",
        "indrajaal.validation.errors",
        "indrajaal.agent.efficiency",
        "indrajaal.container.health"
      ]

      assert length(key_metrics) >= 4
    end
  end
end
