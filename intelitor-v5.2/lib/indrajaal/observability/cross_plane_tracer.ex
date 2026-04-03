defmodule Indrajaal.Observability.CrossPlaneTracer do
  @moduledoc """
  [AGENT_RECREATION_GENOME]
  Purpose: Distributed tracing across the Elixir/F# boundary.
  Function: Injects and extracts OTLP span contexts into Zenoh message headers.
  STAMP: SC-OBS-001, T22.3.4
  Recovery:
  - Supervisor: `Indrajaal.Observability.Supervisor`
  - Logic: Uses :otel_propagator_text_map to encode/decode carrier maps.
  [/AGENT_RECREATION_GENOME]
  """
  require Logger

  @doc "Inject current span context into a carrier map for Zenoh headers"
  def inject_context(carrier \\ %{}) do
    if Code.ensure_loaded?(:otel_propagator_text_map) do
      :otel_propagator_text_map.inject(carrier)
    else
      carrier
    end
  end

  @doc "Extract span context from Zenoh headers and continue the trace"
  def extract_context(carrier) do
    if Code.ensure_loaded?(:otel_propagator_text_map) do
      ctx = :otel_propagator_text_map.extract(carrier)
      OpenTelemetry.Tracer.set_current_span(ctx)
      ctx
    else
      :undefined
    end
  end
end
