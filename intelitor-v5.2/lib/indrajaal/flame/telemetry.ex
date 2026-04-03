defmodule Indrajaal.FLAME.Telemetry do
  @moduledoc """
  FLAME Telemetry Handler for distributed tracing and metrics.

  STAMP Compliance:
  - SC-FLAME-005: Distributed Tracing Enabled
  - SC-OBS-065: Observability for all domain operations
  - SC-CLU-001: Identity-based networking via Tailscale DNS

  Attaches to FLAME events and emits:
  - OpenTelemetry spans for distributed tracing (with Tailscale DNS names)
  - Prometheus metrics for monitoring
  - Structured logs for debugging
  """

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias Indrajaal.Cluster.TailscaleDNS

  @flame_events [
    [:flame, :pool, :start],
    [:flame, :pool, :stop],
    [:flame, :runner, :start],
    [:flame, :runner, :stop],
    [:flame, :runner, :exception],
    [:flame, :call, :start],
    [:flame, :call, :stop],
    [:flame, :call, :exception]
  ]

  @doc """
  Attach all FLAME telemetry handlers.
  Should be called during application startup.
  """
  def attach do
    :telemetry.attach_many(
      "indrajaal-flame-telemetry",
      @flame_events,
      &handle_event/4,
      nil
    )
  end

  @doc """
  Detach FLAME telemetry handlers.
  """
  def detach do
    :telemetry.detach("indrajaal-flame-telemetry")
  end

  # Pool start event
  def handle_event([:flame, :pool, :start], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"

    Logger.debug("🔥 FLAME Pool starting: #{inspect(pool_name)}")

    Tracer.with_span "flame.pool.start", kind: :internal do
      Tracer.set_attributes([
        {"flame.pool.name", inspect(pool_name)},
        {"flame.pool.min", metadata[:min] || 0},
        {"flame.pool.max", metadata[:max] || 10}
      ])
    end

    :telemetry.execute(
      [:indrajaal, :flame, :pool, :start],
      measurements,
      Map.put(metadata, :pool_name, pool_name)
    )
  end

  # Pool stop event
  def handle_event([:flame, :pool, :stop], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"
    duration = measurements[:duration] || 0

    Logger.debug("🔥 FLAME Pool stopped: #{inspect(pool_name)} (duration: #{duration}ns)")

    :telemetry.execute(
      [:indrajaal, :flame, :pool, :stop],
      Map.put(measurements, :duration_ms, div(duration, 1_000_000)),
      Map.put(metadata, :pool_name, pool_name)
    )
  end

  # Runner start event
  def handle_event([:flame, :runner, :start], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"
    runner_id = metadata[:runner_id] || generate_runner_id()

    # SC-CLU-001: Get Tailscale DNS runner name
    runner_node_name = TailscaleDNS.get_flame_runner_name(to_string(pool_name), runner_id)
    tailnet_suffix = TailscaleDNS.get_tailnet_suffix()

    Logger.info("🚀 FLAME Runner spawning for pool: #{inspect(pool_name)} as #{runner_node_name}")

    Tracer.with_span "flame.runner.spawn", kind: :internal do
      Tracer.set_attributes([
        {"flame.pool.name", inspect(pool_name)},
        {"flame.runner.node", to_string(Node.self())},
        {"flame.runner.tailscale_name", to_string(runner_node_name)},
        {"flame.runner.tailnet_suffix", tailnet_suffix},
        {"flame.runner.id", runner_id}
      ])
    end

    :telemetry.execute(
      [:indrajaal, :flame, :runner, :spawn],
      measurements,
      Map.merge(metadata, %{
        runner_node_name: runner_node_name,
        runner_id: runner_id,
        tailnet_suffix: tailnet_suffix
      })
    )
  end

  # Runner stop event
  def handle_event([:flame, :runner, :stop], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"
    duration = measurements[:duration] || 0

    Logger.info(
      "✅ FLAME Runner completed for pool: #{inspect(pool_name)} (#{div(duration, 1_000_000)}ms)"
    )

    :telemetry.execute(
      [:indrajaal, :flame, :runner, :complete],
      Map.put(measurements, :duration_ms, div(duration, 1_000_000)),
      metadata
    )
  end

  # Runner exception event
  def handle_event([:flame, :runner, :exception], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"
    error = metadata[:reason] || metadata[:error] || "unknown"

    Logger.error("❌ FLAME Runner exception in pool #{inspect(pool_name)}: #{inspect(error)}")

    Tracer.with_span "flame.runner.exception", kind: :internal do
      Tracer.set_attributes([
        {"flame.pool.name", inspect(pool_name)},
        {"flame.error", inspect(error)},
        {"flame.error.type", "runner_exception"}
      ])

      Tracer.set_status(:error, inspect(error))
    end

    :telemetry.execute(
      [:indrajaal, :flame, :runner, :error],
      measurements,
      Map.merge(metadata, %{error_type: :runner_exception, error: error})
    )
  end

  # Call start event
  def handle_event([:flame, :call, :start], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"

    Tracer.with_span "flame.call", kind: :client do
      Tracer.set_attributes([
        {"flame.pool.name", inspect(pool_name)},
        {"flame.call.type", "sync"}
      ])
    end

    :telemetry.execute(
      [:indrajaal, :flame, :call, :start],
      measurements,
      metadata
    )
  end

  # Call stop event
  def handle_event([:flame, :call, :stop], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"
    duration = measurements[:duration] || 0
    duration_ms = div(duration, 1_000_000)

    # Log slow calls
    if duration_ms > 1000 do
      Logger.warning("⚠️ Slow FLAME call to #{inspect(pool_name)}: #{duration_ms}ms")
    end

    :telemetry.execute(
      [:indrajaal, :flame, :call, :complete],
      Map.put(measurements, :duration_ms, duration_ms),
      metadata
    )
  end

  # Call exception event
  def handle_event([:flame, :call, :exception], measurements, metadata, _config) do
    pool_name = metadata[:pool] || "unknown"
    error = metadata[:reason] || metadata[:error] || "unknown"

    Logger.error("❌ FLAME call exception to #{inspect(pool_name)}: #{inspect(error)}")

    Tracer.with_span "flame.call.exception", kind: :client do
      Tracer.set_attributes([
        {"flame.pool.name", inspect(pool_name)},
        {"flame.error", inspect(error)}
      ])

      Tracer.set_status(:error, inspect(error))
    end

    :telemetry.execute(
      [:indrajaal, :flame, :call, :error],
      measurements,
      Map.merge(metadata, %{error_type: :call_exception, error: error})
    )
  end

  # Catch-all for unhandled events
  def handle_event(event, measurements, _metadata, _config) do
    Logger.debug("FLAME event: #{inspect(event)}, measurements: #{inspect(measurements)}")
    :ok
  end

  # Generate unique runner ID for tracking
  defp generate_runner_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end
end
