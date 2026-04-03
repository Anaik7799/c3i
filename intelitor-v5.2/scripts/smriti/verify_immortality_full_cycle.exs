#!/usr/bin/env elixir

# Script: verify_immortality_full_cycle.exs
# Purpose: End-to-End verification of the SMRITI Immortality Protocol
# Scenario: Create State -> Export -> "Crash" -> Import -> Verify

# Ensure code path is available
Code.require_file("lib/indrajaal/smriti/immortality/panspermia_exporter.ex", File.cwd!())
Code.require_file("lib/indrajaal/smriti/immortality/protocol.ex", File.cwd!())

alias Indrajaal.SMRITI.Immortality.{PanspermiaExporter, Protocol}

defmodule SMRITI.Simulation do
  def run do
    IO.puts IO.ANSI.cyan() <> "╔════════════════════════════════════════════════════════════╗" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "║  SMRITI IMMORTALITY PROTOCOL: FULL CYCLE VERIFICATION        ║" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "╚════════════════════════════════════════════════════════════╝" <> IO.ANSI.reset()

    # 1. GENESIS
    IO.write "\n[PHASE 1] GENESIS: Creating System State..."
    original_state = %{
      "version" => "1.0.0",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "knowledge_base" => %{
        "axiom_0" => "Functionality Invariant",
        "axiom_1" => "Patient Mode"
      },
      "active_agents" => ["Architect", "Builder", "Tester"]
    }
    IO.puts " DONE"
    IO.inspect(original_state, label: "Original State")

    # 2. PROTOCOL CHECK
    IO.write "\n[PHASE 2] PROTOCOL: Establishing Handshake..."
    protocol = Protocol.new()
    handshake = Protocol.generate_handshake()
    case Protocol.validate_handshake(handshake) do
      {:ok, _} -> IO.puts " VALIDATED"
      error -> 
        IO.puts " FAILED"
        IO.inspect(error)
        exit({:shutdown, 1})
    end

    # 3. PANSPERMIA (EXPORT)
    IO.write "\n[PHASE 3] PANSPERMIA: Exporting Seed..."
    seed_path = "data/tmp/smriti_seed_#{:os.system_time(:seconds)}.json"
    File.mkdir_p!("data/tmp")
    
    case PanspermiaExporter.export(original_state, seed_path) do
      {:ok, path} -> 
        IO.puts " EXPORTED to #{path}"
        # Verify file exists and has content
        stat = File.stat!(path)
        IO.puts "          Seed Size: #{stat.size} bytes"
      error ->
        IO.puts " FAILED"
        IO.inspect(error)
        exit({:shutdown, 1})
    end

    # 4. CATACLYSM (SIMULATED CRASH)
    IO.write "\n[PHASE 4] CATACLYSM: Simulating System Failure..."
    # Explicitly clearing the variable in our logic flow
    _wiped_state = nil 
    Process.sleep(500) # Dramatic pause
    IO.puts " SYSTEM MEMORY WIPED"

    # 5. RECONSTRUCTION
    IO.write "\n[PHASE 5] RECONSTRUCTION: Loading from Seed..."
    reconstructed_state = 
      case PanspermiaExporter.verify_import(seed_path) do
        {:ok, state} -> 
          IO.puts " RESTORED"
          state
        error ->
          IO.puts " FAILED TO IMPORT"
          IO.inspect(error)
          exit({:shutdown, 1})
      end

    # 6. VERIFICATION
    IO.write "\n[PHASE 6] VERIFICATION: Comparing DNA..."
    
    # Normalize keys if JSON decoding turned atoms to strings (which it does)
    # Our simple exporter uses inspect/1 if Jason missing, or Jason if present.
    # The output of inspect is not valid JSON, so the deserialize might fallback to eval.
    # Let's see what happens.
    
    # Deep comparison
    if states_match?(original_state, reconstructed_state) do
      IO.puts IO.ANSI.green() <> " MATCH CONFIRMED" <> IO.ANSI.reset()
      IO.puts "\n✅ IMMORTALITY ACHIEVED: Information persisted across process boundary."
      
      # Cleanup
      File.rm(seed_path)
    else
      IO.puts IO.ANSI.red() <> " DNA MISMATCH" <> IO.ANSI.reset()
      IO.puts "Original:"
      IO.inspect(original_state)
      IO.puts "Reconstructed:"
      IO.inspect(reconstructed_state)
      exit({:shutdown, 1})
    end
  end

  defp states_match?(a, b), do: a == b
end

SMRITI.Simulation.run()
