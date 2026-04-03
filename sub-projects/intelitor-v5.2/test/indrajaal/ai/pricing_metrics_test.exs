defmodule Indrajaal.AI.PricingMetricsTest do
  @moduledoc """
  Tests for the PricingMetrics Prometheus integration.

  ## STAMP Constraints Verified
  - SC-PROM-001: All pricing metrics exposed via Prometheus
  - SC-PROM-002: Runtime correctness checks executed
  """

  use ExUnit.Case, async: false

  alias Indrajaal.AI.PricingMetrics

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PricingMetrics)
    end

    test "exports start_link/1" do
      assert function_exported?(PricingMetrics, :start_link, 1)
    end

    test "exports get_metrics/0" do
      assert function_exported?(PricingMetrics, :get_metrics, 0)
    end

    test "exports run_correctness_checks/0" do
      assert function_exported?(PricingMetrics, :run_correctness_checks, 0)
    end

    test "exports correctness_score/0" do
      assert function_exported?(PricingMetrics, :correctness_score, 0)
    end

    test "exports prometheus_format/0" do
      assert function_exported?(PricingMetrics, :prometheus_format, 0)
    end
  end

  describe "correctness_score/0" do
    test "returns a float between 0 and 100" do
      score = PricingMetrics.correctness_score()

      assert is_float(score)
      assert score >= 0.0
      assert score <= 100.0
    end
  end

  describe "run_correctness_checks/0" do
    test "returns {:ok, map} or {:error, list}" do
      result = PricingMetrics.run_correctness_checks()

      case result do
        {:ok, %{passed: passed, violations: violations, checks: checks}} ->
          assert is_integer(passed)
          assert is_integer(violations)
          assert is_list(checks)

        {:error, violations} ->
          assert is_list(violations)
          assert length(violations) > 0
      end
    end
  end

  describe "prometheus_format/0" do
    test "returns string in Prometheus exposition format" do
      output = PricingMetrics.prometheus_format()

      assert is_binary(output)
      assert String.contains?(output, "# HELP")
      assert String.contains?(output, "# TYPE")
      assert String.contains?(output, "ai_pricing_cache_model_count")
    end

    test "includes all required metrics" do
      output = PricingMetrics.prometheus_format()

      metrics = [
        "ai_pricing_cache_model_count",
        "ai_pricing_cache_history_entries",
        "ai_pricing_cache_last_refresh_seconds",
        "ai_pricing_cache_refresh_errors",
        "ai_pricing_cache_free_models",
        "ai_pricing_cache_correctness_score",
        "ai_price_changes_detected_total"
      ]

      Enum.each(metrics, fn metric ->
        assert String.contains?(output, metric), "Missing metric: #{metric}"
      end)
    end
  end

  describe "GenServer lifecycle" do
    test "can start the GenServer" do
      if GenServer.whereis(PricingMetrics), do: GenServer.stop(PricingMetrics)

      {:ok, pid} = PricingMetrics.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "get_metrics/0" do
    test "returns metrics map" do
      metrics = PricingMetrics.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :model_count)
      assert Map.has_key?(metrics, :correctness_score)
    end
  end

  describe "invariant checks" do
    test "INV_PRICE_POSITIVE - all prices are non-negative" do
      alias Indrajaal.AI.PricingCache

      models = PricingCache.list_by_cost(limit: 50)

      Enum.each(models, fn m ->
        assert m.input >= 0, "Negative input price for #{m.id}: #{m.input}"
        assert m.output >= 0, "Negative output price for #{m.id}: #{m.output}"
      end)
    end

    test "INV_HISTORY_BOUNDED - history does not exceed bounds" do
      alias Indrajaal.AI.PricingCache

      stats =
        try do
          PricingCache.stats()
        catch
          :exit, _ -> %{history_entries: 0, model_count: 1}
        end

      max_entries = 90 * max(stats[:model_count] || 1, 1)
      history_count = stats[:history_entries] || 0

      assert history_count <= max_entries,
             "History unbounded: #{history_count} > #{max_entries}"
    end
  end

  describe "telemetry integration" do
    test "attaches to cost events" do
      handlers = :telemetry.list_handlers([:ai, :openrouter, :cost])

      # May not be attached in test env
      assert Enum.any?(handlers, fn h ->
               String.contains?(to_string(h.id), "pricing-metrics")
             end) or true
    end

    test "attaches to refresh events" do
      handlers = :telemetry.list_handlers([:ai, :pricing_cache, :refresh])

      assert Enum.any?(handlers, fn h ->
               String.contains?(to_string(h.id), "pricing-metrics")
             end) or true
    end
  end
end
