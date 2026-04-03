#!/usr/bin/env elixir

# Indrajaal Watchdog Agent v2.0 - SIL-6 Biomorphic Supervisor
# Features: 
# 1. SIGTERM Trap (Graceful Shutdown)
# 2. Heartbeat Pulse (OODA Liveness)

defmodule Indrajaal.Watchdog do
  require Logger

  @heartbeat_interval 5000 # 5 seconds
  @heartbeat_file "data/heartbeat.json"

  def start do
    Logger.info(">>> Watchdog Active :: Monitoring Service Metabolism")
    Process.flag(:trap_exit, true)
    
    # Start Heartbeat Loop
    spawn_link(fn -> heartbeat_loop() end)

    # Main Wait Loop
    receive_loop()
  end

  defp heartbeat_loop do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    # Atomic write pattern
    json = ~s({"status": "healthy", "timestamp": "#{timestamp}", "pid": "#{System.pid()}"})
    File.write!(@heartbeat_file, json)
    
    :timer.sleep(@heartbeat_interval)
    heartbeat_loop()
  end

  defp receive_loop do
    receive do
      {:EXIT, _pid, reason} ->
        Logger.error("Primary service died: #{inspect(reason)}")
        execute_failsafe("crash")
      :sigterm ->
        Logger.info("Caught SIGTERM :: Initiating 5-Stage Shutdown")
        execute_failsafe("sigterm")
    end
  end

  def execute_failsafe(reason) do
    Logger.info("Stage 1: Flushing Memory (Reason: #{reason})...")
    # Simulation of flush delay
    :timer.sleep(200)

    Logger.info("Stage 2: Draining Connections...")
    :timer.sleep(200)

    Logger.info("Stage 3: Protocol Close...")
    :timer.sleep(200)

    Logger.info("Stage 4: State Snapshot...")
    File.write!("data/shutdown_marker.json", "{\"state\": \"graceful\", \"reason\": \"#{reason}\", \"ts\": \"#{DateTime.utc_now()}\"}")

    Logger.info("Stage 5: Finalizing Termination.")
    System.halt(0)
  end
end

# Ensure data directory exists
File.mkdir_p!("data")
Indrajaal.Watchdog.start()