# scripts/telemetry/console_bridge.exs
# WHAT: Subscribes to Mesh Telemetry and streams to Console
# WHY: Standardized infrastructure visibility

defmodule MeshTelemetryBridge do
  require Logger

  def start do
    IO.puts("\u001b[36m📡 Telemetry Bridge: Listening for Mesh Events...\u001b[0m")
    
    # Attach to core telemetry events
    events = [
      [:indrajaal, :compilation, :start],
      [:indrajaal, :compilation, :stop],
      [:indrajaal, :validation, :complete],
      [:quadplex, :log, :info],
      [:quadplex, :log, :error],
      [:quadplex, :log, :warning]
    ]

    :telemetry.attach_many("console-bridge", events, &handle_event/4, nil)
    
    # Keep script alive
    Process.sleep(:infinity)
  end

  def handle_event(event, measurements, metadata, _config) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    IO.puts("#{timestamp} [METRIC] #{inspect(event)}: #{inspect(measurements)} | #{inspect(metadata)}")
  end
end

MeshTelemetryBridge.start()
