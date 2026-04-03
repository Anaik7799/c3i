#!/usr/bin/env elixir

# Script: verify_shell_dna_reconstruction.exs
# Purpose: Verify the Self-Extracting Shell Script works.

Code.require_file("lib/indrajaal/smriti/immortality/panspermia_exporter.ex", File.cwd!())
alias Indrajaal.SMRITI.Immortality.PanspermiaExporter

defmodule SMRITI.GenesisProtocol do
  def run do
    IO.puts IO.ANSI.cyan() <> "╔════════════════════════════════════════════════════════════╗" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "║  SMRITI DNA: SHELL SCRIPT RECONSTRUCTION CHECK               ║" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "╚════════════════════════════════════════════════════════════╝" <> IO.ANSI.reset()

    seed_path = "data/tmp/system_dna.sh"
    clean_room = "data/tmp/genesis_clean_room_sh"
    
    File.mkdir_p!("data/tmp")
    File.rm_rf(clean_room)
    File.mkdir_p!(clean_room)

    # 1. HARVEST
    IO.write "[1] Generating DNA Script..."
    {:ok, path, size} = PanspermiaExporter.export_dna(seed_path)
    IO.puts " DONE (#{size} bytes payload)"

    # 2. TRANSPORT
    IO.write "[2] Transporting to Clean Room..."
    dest_seed = Path.join(clean_room, "restore.sh")
    File.cp!(seed_path, dest_seed)
    IO.puts " DONE"

    # 3. EXECUTE (The Test)
    IO.write "[3] Executing Reconstruction..."
    
    # We execute the shell script inside the clean room
    {output, exit_code} = System.cmd("sh", ["./restore.sh"], cd: clean_room, stderr_to_stdout: true)
    
    if exit_code == 0 do
      IO.puts " DONE"
      IO.puts "    Output: #{String.trim(output)}"
    else
      IO.puts " FAILED"
      IO.puts "    Output: #{output}"
      exit({:shutdown, 1})
    end

    # 4. VERIFY FILES
    IO.write "[4] Verifying Organism..."
    
    required_files = ["mix.exs", "lib/indrajaal/application.ex", "config/config.exs"]
    
    missing = Enum.filter(required_files, fn f -> 
      !File.exists?(Path.join(clean_room, f))
    end)
    
    if missing == [] do
      IO.puts IO.ANSI.green() <> " PASSED" <> IO.ANSI.reset()
      IO.puts "    The system is alive in #{clean_room}"
    else
      IO.puts IO.ANSI.red() <> " FAILED" <> IO.ANSI.reset()
      IO.puts "    Missing: #{inspect(missing)}"
      exit({:shutdown, 1})
    end
  end
end

SMRITI.GenesisProtocol.run()
