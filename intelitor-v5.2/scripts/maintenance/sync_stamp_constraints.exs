#!/usr/bin/env elixir

# 🚀 STAMP CONSTRAINT SYNC ENGINE - SIL-6 BIOMORPHIC INTEGITY
# ==========================================================
# Purpose: Synchronize 1800+ code-level STAMP constraints with documentation.
# Approach: Regex extraction + Information Theory categorization.

defmodule StampSync do
  @lib_dir "lib/"
  @output_file "docs/architecture/STAMP_MASTER_LIST.md"
  @tag_descriptions %{
    "SIL6" => "Biomorphic Mesh Level 6 Safety",
    "TODO" => "Todolist and Planning Integrity",
    "ZTEST" => "Zenoh Test Messaging and Checkpoints",
    "OODA" => "Fast OODA Loop Cycle Constraints",
    "NEURO" => "Neuro-Symbolic Simplex Architecture",
    "HOLON" => "Holon State Sovereignty and Sovereignty",
    "ACE" => "Autonomous Compilation Engine",
    "PROM" => "PROMETHEUS Formal Verification",
    "LOG" => "Triple Logging and Observability",
    "PRF" => "Performance and Latency Budgets",
    "CNT" => "Container Isolation and Podman",
    "SEC" => "Security and Encryption",
    "MIG" => "Database Migration Preflight",
    "FAC" => "Factory and Test Data Generation",
    "ASH" => "Ash Framework DSL Compliance",
    "DOC" => "Agent-Friendly Documentation",
    "ZEN" => "Zenoh FFI and Communication"
  }

  def run do
    IO.puts("🔍 Harvesting STAMP constraints from #{@lib_dir}...")
    
    constraints = 
      harvest_constraints()
      |> sort_and_deduplicate()
      |> categorize()

    generate_markdown(constraints)
    IO.puts("✅ STAMP Master List generated at #{@output_file}")
  end

  defp harvest_constraints do
    # Search for SC-[TAG]-[NNN]: [Description]
    {output, 0} = System.cmd("grep", ["-rhE", "SC-[A-Z]+-[0-9]{3}:", @lib_dir])
    
    output
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      # Clean up the line (remove comments, whitespace)
      line = Regex.replace(~r/^[^S]*SC-/, line, "SC-")
      
      case Regex.run(~r/(SC-([A-Z]+)-[0-9]{3}):\s*(.*)/, line) do
        [_, full_id, tag, description] ->
          %{id: full_id, tag: tag, description: String.trim(description)}
        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp sort_and_deduplicate(constraints) do
    constraints
    |> Enum.uniq_by(fn c -> c.id end)
    |> Enum.sort_by(fn c -> c.id end)
  end

  defp categorize(constraints) do
    Enum.group_by(constraints, fn c -> c.tag end)
  end

  defp generate_markdown(categories) do
    content = """
    # STAMP Safety Constraints Master List
    **Generated**: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    **Integrity Level**: SIL-6 Biomorphic
    **Total Constraints**: #{Enum.reduce(categories, 0, fn {_, list}, acc -> acc + length(list) end)}

    ## 0.0 Introduction
    This document is the authoritative, self-synchronizing registry of all Safety Constraints (SC)
    enforced across the Indrajaal ecosystem. These constraints form the "Physics" of the system
    evolution, preventing unsafe control actions (UCA).

    #{generate_sections(categories)}
    """

    File.mkdir_p!(Path.dirname(@output_file))
    File.write!(@output_file, content)
  end

  defp generate_sections(categories) do
    categories
    |> Enum.sort()
    |> Enum.map(fn {tag, list} ->
      desc = Map.get(@tag_descriptions, tag, "General Domain: #{tag}")
      """
      ### #{tag} - #{desc}
      | ID | Description |
      |---|---|
      #{Enum.map_join(list, "\n", fn c -> "| #{c.id} | #{c.description} |" end)}
      """
    end)
    |> Enum.join("\n")
  end
end

StampSync.run()
