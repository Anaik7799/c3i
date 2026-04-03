defmodule Indrajaal.SMRITI.Polish.TelemetryHandlerTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Polish.TelemetryHandler

  describe "Telemetry Handler" do
    test "handles event emission" do
      event = %{type: :heartbeat, value: 1}
      assert TelemetryHandler.handle_event(event) == :ok
    end

    test "formats metrics for export" do
      metrics = %{latency: 50}
      formatted = TelemetryHandler.format(metrics)
      assert formatted =~ "latency=50"
    end
  end
end
