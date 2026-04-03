defmodule Indrajaal.Observability.TraceContext do
  @moduledoc """
  ## SYNAPTIC LINK (L3-INTEGRATION)
  Propagates Causal Context (Trace ID, Span ID) across the Zenoh boundary.

  **Mechanism**:
  - Uses `OpenTelemetry` TextMapPropagator (W3C TraceContext).
  - Injects into Zenoh metadata.
  - Extracts from Zenoh metadata to link spans.
  """

  @doc "Injects current OTEL context into a map"
  def inject(carrier \\ %{}) do
    :otel_propagator_text_map.inject(carrier)
  end

  @doc "Extracts OTEL context from a map and sets it as current"
  def extract(carrier) do
    :otel_propagator_text_map.extract(carrier)
  end

  @doc "Set Baggage (Distributed Context)"
  def set_baggage(key, value) do
    OpenTelemetry.Baggage.set(key, value)
  end

  @doc "Get Baggage"
  def get_baggage(key) do
    OpenTelemetry.Baggage.get_all() |> Map.get(key)
  end
end
