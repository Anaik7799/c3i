defmodule Indrajaal.AI.Simplex.TelemetryFlow do
  @moduledoc """
  Telemetry data flow for AI operations.

  ## Multi-Destination Streaming

  All AI telemetry is streamed to:
  1. `:telemetry` (Erlang) → OTEL → SigNoz
  2. Zenoh → Distributed mesh
  3. CEPAF F# Bridge → Fractal logging

  ## STAMP Constraints

  - SC-DF-004: Telemetry emitted for all events
  - SC-DF-005: Zenoh streaming async
  - SC-DF-006: CEPAF receives all AI events
  - SC-DF-007: Key expressions follow schema

  ## Zenoh Key Expression Schema

      indrajaal/ai/
      ├── requests/{provider}/{intent}/{model}
      ├── responses/{request_id}
      ├── costs/daily, monthly, by_model
      ├── vetoes/{reason}
      └── evolution/success, near_miss, shadow_diverge
  """

  require Logger

  @doc """
  Emit an AI event to all telemetry destinations.

  ## Parameters

  - `event_name`: List of atoms for the event path (e.g., `[:simplex, :success]`)
  - `measurements`: Map of numeric measurements
  - `metadata`: Map of event metadata
  """
  @spec emit_ai_event(list(atom()), map(), map()) :: :ok
  def emit_ai_event(event_name, measurements, metadata) do
    # 1. Erlang telemetry (synchronous)
    :telemetry.execute([:ai | event_name], measurements, metadata)

    # 2. Zenoh streaming (async)
    spawn_zenoh_publish(event_name, measurements, metadata)

    # 3. CEPAF bridge (async)
    spawn_cepaf_publish(event_name, measurements, metadata)

    :ok
  end

  @doc """
  Emit a cost recording event.
  """
  @spec emit_cost_event(String.t(), atom(), float(), map()) :: :ok
  def emit_cost_event(model, source, cost, usage_stats) do
    emit_ai_event(
      [:cost, :recorded],
      %{
        cost: cost,
        daily_total: usage_stats[:daily_usage] || 0.0,
        monthly_total: usage_stats[:monthly_usage] || 0.0,
        tokens: usage_stats[:tokens] || 0
      },
      %{
        model: model,
        source: source
      }
    )
  end

  @doc """
  Emit a budget alert event.
  """
  @spec emit_budget_alert(atom(), float(), float()) :: :ok
  def emit_budget_alert(alert_type, current, limit) do
    emit_ai_event(
      [:budget, :alert],
      %{
        current: current,
        limit: limit,
        percent: if(limit > 0, do: current / limit * 100, else: 0)
      },
      %{
        alert_type: alert_type,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Emit a Guardian veto event.
  """
  @spec emit_veto_event(String.t(), term(), boolean()) :: :ok
  def emit_veto_event(request_id, reason, fallback_used) do
    emit_ai_event(
      [:guardian, :veto],
      %{
        fallback_used: if(fallback_used, do: 1, else: 0)
      },
      %{
        request_id: request_id,
        reason: inspect(reason),
        timestamp: DateTime.utc_now()
      }
    )
  end

  @doc """
  Emit a TrainingGym episode event.
  """
  @spec emit_training_episode(map()) :: :ok
  def emit_training_episode(episode) do
    emit_ai_event(
      [:training_gym, :episode],
      %{
        divergence: episode[:divergence_score] || 0.0
      },
      %{
        type: episode[:type],
        primary_model: episode[:primary_model],
        shadow_model: episode[:shadow_model],
        timestamp: DateTime.utc_now()
      }
    )
  end

  # ---------------------------------------------------------------------------
  # Private: Zenoh Publishing
  # ---------------------------------------------------------------------------

  defp spawn_zenoh_publish(event_name, measurements, metadata) do
    spawn(fn ->
      try do
        publish_to_zenoh(event_name, measurements, metadata)
      rescue
        _ -> :ok
      end
    end)
  end

  defp publish_to_zenoh(event_name, measurements, metadata) do
    publisher = Indrajaal.Observability.ZenohEvolutionPublisher

    if Code.ensure_loaded?(publisher) and GenServer.whereis(publisher) do
      event_data = %{
        event: event_name,
        measurements: measurements,
        metadata: metadata,
        timestamp: DateTime.utc_now()
      }

      route_zenoh_event(publisher, event_name, measurements, metadata, event_data)
    end
  rescue
    _ -> :ok
  end

  # Extract event routing to reduce cyclomatic complexity of publish_to_zenoh
  defp route_zenoh_event(publisher, event_name, measurements, metadata, event_data) do
    case event_name do
      [:simplex, :success] ->
        safe_zenoh_publish(publisher, :publish_openrouter_call, [
          metadata[:model] || "unknown",
          measurements[:tokens] || 0,
          measurements[:latency_ms] || 0,
          true
        ])

      [:simplex, :failure] ->
        safe_zenoh_publish(publisher, :publish_openrouter_call, [
          metadata[:model] || "unknown",
          measurements[:tokens] || 0,
          measurements[:latency_ms] || 0,
          false
        ])

      [:cost, :recorded] ->
        safe_zenoh_publish(publisher, :publish_training_episode, [event_data])

      [:budget, :alert] ->
        safe_zenoh_publish(publisher, :publish_training_episode, [event_data])

      [:guardian, :veto] ->
        safe_zenoh_publish(publisher, :publish_guardian_validation, [
          metadata[:proposal],
          :vetoed,
          event_data
        ])

      [:training_gym, :episode] ->
        safe_zenoh_publish(publisher, :publish_training_episode, [event_data])

      _ ->
        safe_zenoh_publish(publisher, :publish_training_episode, [event_data])
    end
  end

  # Safe wrapper for Zenoh publisher calls using dynamic apply
  defp safe_zenoh_publish(module, function, args) do
    if function_exported?(module, function, length(args)) do
      apply(module, function, args)
    end
  rescue
    _ -> :ok
  end

  # ---------------------------------------------------------------------------
  # Private: CEPAF Publishing
  # ---------------------------------------------------------------------------

  defp spawn_cepaf_publish(event_name, measurements, metadata) do
    spawn(fn ->
      try do
        publish_to_cepaf(event_name, measurements, metadata)
      rescue
        _ -> :ok
      end
    end)
  end

  defp publish_to_cepaf(event_name, measurements, metadata) do
    # Check if CepafClient is available
    client = Indrajaal.Integration.CepafClient

    if Code.ensure_loaded?(client) do
      telemetry_event = %{
        type: :ai_operation,
        event: event_name,
        data: Map.merge(measurements, metadata),
        timestamp: DateTime.utc_now()
      }

      # Use dynamic call to avoid compile warnings for optional function
      safe_cepaf_call(client, :send_ai_telemetry, [telemetry_event])
    end
  rescue
    _ -> :ok
  end

  # Safe wrapper for CepafClient calls using dynamic apply
  defp safe_cepaf_call(module, function, args) do
    if function_exported?(module, function, length(args)) do
      apply(module, function, args)
    end
  rescue
    _ -> :ok
  end
end
