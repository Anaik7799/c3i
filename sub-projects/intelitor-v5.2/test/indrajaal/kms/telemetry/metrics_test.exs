defmodule Indrajaal.KMS.Telemetry.MetricsTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Telemetry.Metrics.
  Tests metrics/0 — Telemetry.Metrics definitions.
  STAMP: SC-OBS-069 (dual log), SC-MON-003 (domain metrics per domain)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Telemetry.Metrics

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Metrics)
    end

    test "exports metrics/0" do
      assert function_exported?(Metrics, :metrics, 0)
    end
  end

  describe "metrics/0" do
    test "returns a non-empty list" do
      result = Metrics.metrics()
      assert is_list(result)
      assert length(result) > 0
    end

    test "all items are Telemetry.Metrics structs" do
      result = Metrics.metrics()

      Enum.each(result, fn metric ->
        # Each metric is a struct from Telemetry.Metrics
        assert is_struct(metric)
      end)
    end

    test "includes holon count gauge" do
      result = Metrics.metrics()
      names = Enum.map(result, fn m -> to_string(m.name) end)
      has_holons = Enum.any?(names, &String.contains?(&1, "holon"))
      assert has_holons
    end

    test "includes health score metric" do
      result = Metrics.metrics()
      names = Enum.map(result, fn m -> to_string(m.name) end)
      has_health = Enum.any?(names, &String.contains?(&1, "health"))
      assert has_health
    end

    test "includes immortality counter" do
      result = Metrics.metrics()
      names = Enum.map(result, fn m -> to_string(m.name) end)
      has_immortality = Enum.any?(names, &String.contains?(&1, "immortality"))
      assert has_immortality
    end
  end
end
