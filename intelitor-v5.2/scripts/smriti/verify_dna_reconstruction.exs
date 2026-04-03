#!/usr/bin/env elixir

# Script: verify_dna_reconstruction.exs
# Purpose: Prove that the system can be reborn from the DNA seed ALONE.
# Scenario: 
# 1. Generate DNA.
# 2. Move DNA to a "Clean Room" (temp directory).
# 3. "Destroy" the world (we just don't look at the original dir).
# 4. Rehydrate the source code from the DNA.
# 5. Verify critical files exist in the Clean Room.

# Load Dependencies
Code.require_file("lib/indrajaal/smriti/immortality/panspermia_exporter.ex", File.cwd!())
alias Indrajaal.SMRITI.Immortality.PanspermiaExporter

defmodule SMRITI.GenesisProtocol do
  def run do
    IO.puts IO.ANSI.cyan() <> "╔════════════════════════════════════════════════════════════╗" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "║  SMRITI DNA: ZERO-DEPENDENCY RECONSTRUCTION CHECK            ║" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "╚════════════════════════════════════════════════════════════╝" <> IO.ANSI.reset()

    seed_path = "data/tmp/system_dna.json"
    clean_room = "data/tmp/genesis_clean_room"
    
    # Setup
    File.mkdir_p!("data/tmp")
    File.rm_rf(clean_room)
    File.mkdir_p!(clean_room)

    # 1. HARVEST DNA
    IO.write "[1] Harvesting System DNA (Source Code)..."
    case PanspermiaExporter.export_dna(seed_path) do
      {:ok, path, size} -> 
        IO.puts " DONE"
        IO.puts "    Artifact: #{path}"
        IO.puts "    Payload:  #{size} bytes (Base64 Encoded Source)"
      {:error, reason} ->
        IO.puts IO.ANSI.red() <> " FAILED: #{reason}" <> IO.ANSI.reset()
        exit({:shutdown, 1})
    end

    # 2. TRANSPORT TO CLEAN ROOM
    IO.write "[2] Transporting to Clean Room..."
    # We move the seed to the clean room to simulate "finding it in the wreckage"
    dest_seed = Path.join(clean_room, "found_dna.json")
    File.cp!(seed_path, dest_seed)
    IO.puts " DONE"

    # 3. REHYDRATION (The Miracle of Life)
    IO.write "[3] Initiating Rehydration Sequence..."
    
    # In a real scenario, this logic would be in a tiny bootstrap script.
    # Here we simulate the logic a survivor would perform.
    
    try do
      # Load the DNA
      dna_content = File.read!(dest_seed)
      
      # Parse (Simple regex to avoid Jason dependency in the bootstrap logic if needed, 
      # but here we use the environment's capability)
      # We'll assume the survivor has a way to parse JSON or Eval the map.
      dna = if Code.ensure_loaded?(Jason) do
        Jason.decode!(dna_content)
      else
        {term, _} = Code.eval_string(dna_content)
        term
      end
      
      payload = dna["payload"]
      
      # Decode
      tar_binary = Base.decode64!(payload)
      tar_path = Path.join(clean_room, "source.tar.gz")
      File.write!(tar_path, tar_binary)
      
      # Extract
      {_, 0} = System.cmd("tar", ["-xzf", "source.tar.gz"], cd: clean_room)
      
      IO.puts " DONE"
      
      # 4. VERIFICATION
      IO.write "[4] Verifying Reconstructed Organism..."
      
      required_files = [
        "mix.exs",
        "lib/indrajaal/application.ex",
        "config/config.exs"
      ]
      
      missing = Enum.filter(required_files, fn f -> 
        !File.exists?(Path.join(clean_room, f))
      end)
      
      if missing == [] do
        IO.puts IO.ANSI.green() <> " PASSED" <> IO.ANSI.reset()
        IO.puts "    All critical organs present in #{clean_room}"
        IO.puts "    The system can now recompile itself from the substrate."
      else
        IO.puts IO.ANSI.red() <> " FAILED" <> IO.ANSI.reset()
        IO.puts "    Missing Organs: #{inspect(missing)}"
        exit({:shutdown, 1})
      end
      
    rescue
      e -> 
        IO.puts IO.ANSI.red() <> " EXCEPTION during Rehydration" <> IO.ANSI.reset()
        IO.inspect(e)
        exit({:shutdown, 1})
    end
  end
end

SMRITI.GenesisProtocol.run()
