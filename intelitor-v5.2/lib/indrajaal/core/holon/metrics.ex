defmodule Indrajaal.Core.Holon.Metrics do
  @moduledoc """
  Holon Metrics - Telemetry and Observability for v20.0.0

  Provides metrics collection and reporting for holons:
  1. VSM system metrics (S1-S5)
  2. Structural metrics (children, depth)
  3. Performance metrics (latency, throughput)
  4. Health metrics (status, violations)

  ## Telemetry Events
  - [:indrajaal, :holon, :operation] - S1 operation completed
  - [:indrajaal, :holon, :coordination] - S2 coordination cycle
  - [:indrajaal, :holon, :budget] - S3 budget check
  - [:indrajaal, :holon, :plan] - S4 plan generated
  - [:indrajaal, :holon, :policy] - S5 policy check
  - [:indrajaal, :holon, :health] - Health status change

  ## STAMP Constraints
  - SC-MET-001: All VSM operations MUST emit telemetry
  - SC-MET-002: Metrics collection MUST be non-blocking
  - SC-MET-003: Metrics MUST include holon layer and ID
  """

  require Logger

  alias Indrajaal.Core.Holon

  @type metric_value :: number() | boolean() | atom()
  @type metric_metadata :: %{
          holon_id: Holon.holon_id(),
          layer: Holon.layer(),
          timestamp: DateTime.t()
        }

  @doc """
  Emits an S1 operation metric.
  """
  @spec emit_operation(Holon.holon_id(), Holon.layer(), atom(), number()) :: :ok
  def emit_operation(holon_id, layer, operation, duration_ms) do
    :telemetry.execute(
      [:indrajaal, :holon, :operation],
      %{duration_ms: duration_ms},
      %{holon_id: holon_id, layer: layer, operation: operation, timestamp: DateTime.utc_now()}
    )
  end

  @doc """
  Emits an S2 coordination metric.
  """
  @spec emit_coordination(Holon.holon_id(), Holon.layer(), non_neg_integer(), number()) :: :ok
  def emit_coordination(holon_id, layer, peer_count, duration_ms) do
    :telemetry.execute(
      [:indrajaal, :holon, :coordination],
      %{duration_ms: duration_ms, peer_count: peer_count},
      %{holon_id: holon_id, layer: layer, timestamp: DateTime.utc_now()}
    )
  end

  @doc """
  Emits an S3 budget check metric.
  """
  @spec emit_budget(Holon.holon_id(), Holon.layer(), boolean(), map()) :: :ok
  def emit_budget(holon_id, layer, within_budget, usage) do
    :telemetry.execute(
      [:indrajaal, :holon, :budget],
      %{within_budget: within_budget},
      Map.merge(
        %{holon_id: holon_id, layer: layer, timestamp: DateTime.utc_now()},
        usage
      )
    )
  end

  @doc """
  Emits an S4 plan generation metric.
  """
  @spec emit_plan(Holon.holon_id(), Holon.layer(), float(), number()) :: :ok
  def emit_plan(holon_id, layer, confidence, duration_ms) do
    :telemetry.execute(
      [:indrajaal, :holon, :plan],
      %{confidence: confidence, duration_ms: duration_ms},
      %{holon_id: holon_id, layer: layer, timestamp: DateTime.utc_now()}
    )
  end

  @doc """
  Emits an S5 policy check metric.
  """
  @spec emit_policy(Holon.holon_id(), Holon.layer(), boolean(), number()) :: :ok
  def emit_policy(holon_id, layer, verified, duration_ms) do
    :telemetry.execute(
      [:indrajaal, :holon, :policy],
      %{verified: verified, duration_ms: duration_ms},
      %{holon_id: holon_id, layer: layer, timestamp: DateTime.utc_now()}
    )
  end

  @doc """
  Emits a health status change metric.
  """
  @spec emit_health(Holon.holon_id(), Holon.layer(), Holon.health(), Holon.health()) :: :ok
  def emit_health(holon_id, layer, old_health, new_health) do
    :telemetry.execute(
      [:indrajaal, :holon, :health],
      %{degraded: health_to_number(new_health) > health_to_number(old_health)},
      %{
        holon_id: holon_id,
        layer: layer,
        old_health: old_health,
        new_health: new_health,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Measures the duration of a function and emits a metric.
  """
  @spec measure(Holon.holon_id(), Holon.layer(), atom(), (-> result)) :: result
        when result: term()
  def measure(holon_id, layer, operation, fun) do
    start = System.monotonic_time(:millisecond)
    result = fun.()
    duration = System.monotonic_time(:millisecond) - start

    emit_operation(holon_id, layer, operation, duration)
    result
  end

  @doc """
  Returns a summary of holon metrics for a given holon.
  """
  @spec summary(Holon.holon_id()) :: map()
  def summary(holon_id) do
    # This would typically aggregate from a metrics store
    # For now, return a template
    %{
      holon_id: holon_id,
      operations: %{count: 0, avg_duration_ms: 0},
      coordinations: %{count: 0, avg_duration_ms: 0},
      budget_checks: %{count: 0, violations: 0},
      plans: %{count: 0, avg_confidence: 0.0},
      policy_checks: %{count: 0, violations: 0},
      health_changes: %{count: 0}
    }
  end

  @doc """
  Attaches telemetry handlers for holon metrics.
  """
  @spec attach_handlers() :: :ok
  def attach_handlers do
    events = [
      [:indrajaal, :holon, :operation],
      [:indrajaal, :holon, :coordination],
      [:indrajaal, :holon, :budget],
      [:indrajaal, :holon, :plan],
      [:indrajaal, :holon, :policy],
      [:indrajaal, :holon, :health]
    ]

    :telemetry.attach_many(
      "holon-metrics-handler",
      events,
      &handle_event/4,
      nil
    )

    Logger.debug("Attached holon metrics handlers")
    :ok
  end

  # Private

  defp handle_event([:indrajaal, :holon, event_type], measurements, metadata, _config) do
    Logger.debug(
      "Holon #{event_type}: #{metadata.holon_id} at #{metadata.layer} - #{inspect(measurements)}"
    )
  end

  defp health_to_number(:healthy), do: 0
  defp health_to_number(:degraded), do: 1
  defp health_to_number(:critical), do: 2
  defp health_to_number(:failed), do: 3
end
