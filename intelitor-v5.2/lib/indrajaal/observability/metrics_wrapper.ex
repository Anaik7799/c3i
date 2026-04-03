defmodule Indrajaal.Observability.MetricsWrapper do
  @moduledoc """
  Wrapper module for OpenTelemetry metrics to handle missing :otel_metrics module.
  """

  # CLAUDE_AGENT_CONTEXT: Created wrapper for missing OpenTelemetry module
  # Date: 2025-09-03
  # Issue: :otel_metrics.record/3 is undefined
  # Pattern: EP045_UNDEFINED_ERLANG_MODULE
  # Fix: Created wrapper that gracefully handles missing Erlang module
  #
  # This is a defensive programming pattern to handle cases where:
  # - OpenTelemetry is not fully installed
  # - The Erlang :otel_metrics module is not available
  # - We're in a development/test environment without full telemetry
  #
  # The wrapper:
  # 1. Checks if the module is loaded at runtime
  # 2. Delegates to the real module if available
  # 3. Falls back to logging if not available
  #
  # This pr_events compilation failures while maintaining observability

  require Logger

  # Suppress warning for optional Erlang module that may not be available
  @compile {:no_warn_undefined, {:otel_metrics, :record, 3}}

  @doc """
  Records a metric value. This is a wrapper that gracefully handles when :otel_metrics is not available.
  """
  def record(metric_name, value, attributes \\ %{}) do
    if Code.ensure_loaded?(:otel_metrics) do
      # Direct call - Erlang module calls are dynamic at runtime
      :otel_metrics.record(metric_name, value, attributes)
    else
      # Log the metric instead if otel_metrics is not available
      Logger.debug(
        "Metric recorded: #{inspect(metric_name)}, value: #{inspect(value)}, attrs: #{inspect(attributes)}"
      )

      :ok
    end
  end
end
