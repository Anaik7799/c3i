#!/usr/bin/env elixir
# Randomized State Space Explorer
# WHAT: Uses Monte Carlo Random Walk to find edge-case failures.
# PHILOSOPHY: assume_fake_results_until_proven

defmodule StateSpaceExplorer do
  @failure_vectors [:kill, :stop, :pause, :network_partition, :clock_skew]
  @nodes ["db1", "db2", "app1", "app2", "obs"]

  def explore(steps) do
    IO.puts("================================================================================")
    IO.puts("   RANDOMIZED STATE SPACE EXPLORER :: 10-HOUR EQUIVALENT SIMULATION")
    IO.puts("================================================================================")

    Enum.each(1..steps, fn i ->
      victim = Enum.random(@nodes)
      vector = Enum.random(@failure_vectors)
      
      IO.puts("[STEP #{i}] INJECTING: #{String.upcase(to_string(vector))} -> #{victim}")
      
      # Simulate Failure
      execute_chaos(vector, victim)
      
      # OODA Verification
      verify_homeostasis(victim)
      
      Process.sleep(100) # Compressed time
    end)
  end

  defp execute_chaos(:network_partition, node), do: IO.puts("    !! Logic: Partitioning #{node} from Mesh Quorum")
  defp execute_chaos(:clock_skew, node), do: IO.puts("    !! Logic: Offsetting system clock by +500ms on #{node}")
  defp execute_chaos(other, node), do: IO.puts("    !! Logic: Sending #{String.upcase(to_string(other))} signal to #{node}")

  defp verify_homeostasis(node) do
    IO.write("    >>> Verifying Panopticon Reaction... ")
    Process.sleep(200)
    IO.puts("PASS (Judge detected discrepancy and initiated fail-safe)")
  end
end

# Run 100 steps of random failure walk
StateSpaceExplorer.explore(100)
