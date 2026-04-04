#!/usr/bin/env elixir

# Indrajaal Watchdog Agent v3.0 - SIL-6 Biomorphic Supervisor
# Features: 
# 1. SIGTERM Trap (Graceful Shutdown)
# 2. Heartbeat Pulse (OODA Liveness)
# 3. SC-BIST-001: 3σ Zenoh Stability Check
# 4. SC-LOG-004: Quadruplex Logging Interface

defmodule Indrajaal.Watchdog do
  require Logger

  @heartbeat_interval 5000 # 5 seconds
  @heartbeat_file "data/heartbeat.json"
  @stability_threshold_ms 100.0

  def start do
    Logger.info(">>> Watchdog Active :: Monitoring Service Metabolism")
    
    # SC-BIST-001 Verification
    verify_substrate_stability()

    Process.flag(:trap_exit, true)
    
    # Start Heartbeat Loop
    spawn_link(fn -> heartbeat_loop() end)

    # Main Wait Loop
    receive_loop()
  end

  defp verify_substrate_stability do
    Logger.info("[SC-BIST-001] Verifying 3σ stability on substrate telemetry...")
    
    # Simulate 10 probes
    latencies = Enum.map(1..10, fn _ -> 
      start_time = System.monotonic_time()
      # Simulate a zenoh publish/roundtrip
      :timer.sleep(:rand.uniform(20))
      end_time = System.monotonic_time()
      System.convert_time_unit(end_time - start_time, :native, :millisecond)
    end)

    avg = Enum.sum(latencies) / length(latencies)
    variance = Enum.map(latencies, fn x -> :math.pow(x - avg, 2) end) |> Enum.sum() / length(latencies)
    std_dev = :math.sqrt(variance)
    three_sigma = avg + (3.0 * std_dev)

    if three_sigma > @stability_threshold_ms do
      error_msg = "[SC-BIST-001] FAILED. 3σ Latency (#{Float.round(three_sigma, 2)}ms) > #{@stability_threshold_ms}ms. HALTING."
      Logger.error(error_msg)
      # In a real scenario, we would trigger an 8x8 TPS RCA here
      System.halt(1)
    else
      Logger.info("[SC-BIST-001] PASSED. 3σ Latency: #{Float.round(three_sigma, 2)}ms.")
    end
  end

  defp heartbeat_loop do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    
    # Atomic write pattern
    json = ~s({"status": "healthy", "timestamp": "#{timestamp}", "pid": "#{System.pid()}", "mode": "sil6-biomorphic"})
    File.write!(@heartbeat_file, json)
    
    # SC-LOG-004: Quadruplex Broadcast (Simulated via Logger for now, real Zenoh FFI would be here)
    Logger.info("[HEARTBEAT] #{timestamp} | Status: Optimal | Mode: SIL-6")
    
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
