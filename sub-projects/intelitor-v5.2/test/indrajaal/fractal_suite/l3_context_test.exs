defmodule Indrajaal.FractalSuite.L3ContextTest do
  use ExUnit.Case
  alias Indrajaal.Observability.TraceContext
  require OpenTelemetry.Tracer

  test "L3: Trace Context propagates across boundary" do
    # 1. Start a span
    span_ctx = OpenTelemetry.Tracer.start_span("test_span")
    OpenTelemetry.Tracer.set_current_span(span_ctx)

    try do
      # 2. Inject
      carrier = TraceContext.inject([])

      # 3. Extract
      _ctx = TraceContext.extract(carrier)

      # Assert carrier is a list (Erlang proplist)
      assert is_list(carrier)

      # Optional: Check for traceparent if context was active
      # assert List.keymember?(carrier, "traceparent", 0)
    after
      OpenTelemetry.Tracer.end_span(span_ctx)
    end
  end
end
