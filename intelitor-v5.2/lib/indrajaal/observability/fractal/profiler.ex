defmodule Indrajaal.Observability.Fractal.Profiler do
  @moduledoc """
  ## FRACTAL PROFILER (L1-CELLULAR)
  Provides nanosecond-scale execution tracing for critical cellular functions.

  **Mechanism**:
  - Wraps function execution.
  - Measures monotonic time delta.
  - Emits `:telemetry` events with rich metadata.

  **Integration**:
  - Feeds into Fractal Logging Stream.
  - Compatible with Datadog APM spans.
  """
  require Logger

  def trace(name, metadata \\ %{}, fun) do
    start_time = System.monotonic_time()

    result = fun.()

    end_time = System.monotonic_time()
    duration_ns = end_time - start_time

    # Emit Telemetry for Fractal Logger
    :telemetry.execute(
      [:indrajaal, :fractal, :profile],
      %{duration_ns: duration_ns},
      Map.merge(metadata, %{name: name})
    )

    # Log if threshold exceeded (Adaptive Alerting)
    # 100ms
    if duration_ns > 100_000_000 do
      Logger.warning("🐢 [PROFILER] Slow Function: #{name} took #{duration_ns}ns")
    end

    result
  end
end
