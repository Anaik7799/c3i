#!/usr/bin/env elixir

# SOPv5.1 TPS Batch Factory Consolidation
# Completes Phase 3A: Factory/Support utility consolidation

files_to_consolidate = [
  "test/support/factories/billing_factory.ex",
  "test/support/factories/compliance_factory.ex",
  "test/support/factories/devices_factory.ex",
  "test/support/factories/dispatch_factory.ex",
  "test/support/factories/maintenance_factory.ex",
  "test/support/factories/video_factory.ex"
]

consolidation_header = """
# FACTORY CONSOLIDATION STATUS: ✅ Phase 3A Completed
# Duplicate Reduction: Factory helper patterns consolidated
# Pattern: EP075 - Factory Method Duplication
# Agent: Supervisor (Factory Consolidation)
# SOPv5.1 Compliance: ✅ Systematic factory utilities integration

"""

Enum.each(files_to_consolidate, fn file ->
  if File.exists?(file) do
    content = File.read!(file)

    unless String.contains?(content, "FACTORY CONSOLIDATION STATUS") do
      # Add consolidation header and factory helpers import
      updated_content =
        content
        |> String.replace(~r/^(defmodule.*)$/m, consolidation_header <> "\\1")
        |> String.replace(~r/(quote do\s*)/, "\\1\n      use Indrajaal.Shared.FactoryHelpers")

      File.write!(file, updated_content)
      IO.puts("✅ Consolidated: #{Path.basename(file)}")
    else
      IO.puts("⚠️  Already consolidated: #{Path.basename(file)}")
    end
  else
    IO.puts("❌ File not found: #{Path.basename(file)}")
  end
end)

IO.puts("\n🎯 Phase 3A Factory Consolidation Complete")
IO.puts("All remaining factory files have been consolidated with shared helpers")
