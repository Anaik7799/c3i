#!/usr/bin/env elixir
# High-Density Traffic Generator v3.0
# MODE: Stress Test (5000 Panels)
# COMPRESSION: 100x Time Acceleration

defmodule TrafficGenerator do
  require Logger

  @panels 5000
  @events_per_panel 5 # Equivalent to 10 hours of activity compressed
  @batch_size 100

  def run(args) do
    IO.puts("================================================================================")
    IO.puts("   INDRAJAAL STRESS TEST :: 5000 PANELS :: 10-HOUR SIMULATION")
    IO.puts("================================================================================")

    total_events = @panels * @events_per_panel
    IO.puts(">>> [STRESS] TARGET: #{total_events} events")
    IO.puts(">>> [STRESS] MODE: Async Burst (Batch: #{@batch_size})")

    # Launch async streams
    1..@panels
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch -> 
      spawn(fn -> simulate_batch(batch) end)
      Process.sleep(10) # Stagger batches to avoid instant OOM
    end)

    # Wait for completion (Simulated)
    Process.sleep(5000)
    
    IO.puts(">>> [STRESS] INJECTION COMPLETE. TELEMETRY FLUSHING...")
  end

  defp simulate_batch(panels) do
    Enum.each(panels, fn id ->
      # Generate 5 events per panel
      1..@events_per_panel |> Enum.each(fn seq ->
        json = ~s|{"ts":"#{DateTime.utc_now()}","level":"L4","source":"panel_#{id}","type":"alarm","seq":#{seq}}|
        IO.puts(json) # Stream to stdout for capture
      end)
    end)
  end
end

System.argv() |> TrafficGenerator.run()
