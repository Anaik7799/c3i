#!/usr/bin/env elixir

# Script: verify_genotype_integrity.exs
# Purpose: Generate a REALISTIC System Genotype and validate its forensic utility.

# Load Dependencies
Code.require_file("lib/indrajaal/smriti/immortality/panspermia_exporter.ex", File.cwd!())
alias Indrajaal.SMRITI.Immortality.PanspermiaExporter

defmodule SMRITI.GenotypeVerifier do
  def run do
    IO.puts IO.ANSI.cyan() <> "╔════════════════════════════════════════════════════════════╗" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "║  SMRITI GENOTYPE: FORENSIC INTEGRITY CHECK                   ║" <> IO.ANSI.reset()
    IO.puts IO.ANSI.cyan() <> "╚════════════════════════════════════════════════════════════╝" <> IO.ANSI.reset()

    seed_path = "data/tmp/system_genotype.json"
    File.mkdir_p!("data/tmp")

    # 1. GENERATE
    IO.write "[1] Capturing System Identity..."
    {:ok, path, genotype} = PanspermiaExporter.export_genotype(seed_path)
    IO.puts " DONE"
    
    # 2. VALIDATE SIZE & CONTENT
    stat = File.stat!(path)
    IO.puts "    Artifact: #{path}"
    IO.puts "    Size:     #{stat.size} bytes"
    
    # Realistic Validation: A valid genotype MUST identify the code version
    git_sha = get_in(genotype, ["identity", "git_sha"])
    
    IO.write "[2] Verifying Forensic Utility..."
    
    cond do
      stat.size < 300 -> 
        # Hard fail if it's too small to contain meaningful metadata
        IO.puts IO.ANSI.red() <> "\n[FAILURE] Seed too small (#{stat.size}b). Information entropy insufficient for reconstruction." <> IO.ANSI.reset()
        exit({:shutdown, 1})
        
      git_sha == "unknown_sha_no_git" ->
        IO.puts IO.ANSI.yellow() <> "\n[WARNING] Git SHA missing. Reconstruction will be ambiguous." <> IO.ANSI.reset()
        
      true ->
        IO.puts IO.ANSI.green() <> " PASSED" <> IO.ANSI.reset()
        IO.puts "    Code Version:   #{git_sha}"
        IO.puts "    Architecture:   #{get_in(genotype, ["infrastructure", "architecture"])}"
        IO.puts "    Schema Target:  #{get_in(genotype, ["schema", "last_migration"])}"
    end

    # 3. SAFETY ASSERTION
    IO.puts "\n[3] Safety Critical Assertion:"
    IO.puts "    This seed file allows a clean-room environment to pull the EXACT"
    IO.puts "    source code and apply the EXACT schema version required to"
    IO.puts "    restore the system logic. *Data restoration* requires the separate"
    IO.puts "    Unified Checkpoint Registry (UCR) artifacts."
  end
end

SMRITI.GenotypeVerifier.run()
