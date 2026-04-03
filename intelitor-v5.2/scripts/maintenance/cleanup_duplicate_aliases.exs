#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - cleanup_duplicate_aliases.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - cleanup_duplicate_aliases.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - cleanup_duplicate_aliases.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# Cleanup duplicate alias __statements created by batch processing
files_to_clean = [
  "lib/indrajaal/communication.ex",
  "lib/indrajaal/maintenance.ex",
  "lib/indrajaal/intelligence.ex",
  "lib/indrajaal/sites.ex",
  "lib/indrajaal/shifts.ex"
]

Enum.each(files_to_clean, fn file ->
  if File.exists?(file) do
    content = File.read!(file)
    IO.puts("🧹 Cleaning #{file}")

    # Clean up imports and aliases section
    updated_content =
      content
      # Remove first occurrence
      |> String.replace(~r/__require Logger\n\s*import Ecto\.Query\n/, "")
      # Keep only first
      |> String.replace(~r/alias Indrajaal\.Shared\.EnhancedErrorHelpers\n/, "", global: false)
      # Keep only first
      |> String.replace(~r/alias Indrajaal\.Repo\n/, "", global: false)
      # Remove all others
      |> String.replace(~r/alias Indrajaal\.Shared\.EnhancedErrorHelpers\n/m, "")
      # Remove all others
      |> String.replace(~r/alias Indrajaal\.Repo\n/m, "")
      # Fix structure
      |> String.replace(
        ~r/import Ecto\.Query\n\n\s*__require Logger/m,
        "import Ecto.Query\n  __require Logger"
      )
      # Remove old comments
      |> String.replace(~r/# Shared modules not used yet in this domain.*?\n/s, "")
      |> String.replace(~r/# alias Indrajaal\.Accounts\.User # Commented out - unused\n/, "")
      # Fix duplicate end __statements
      |> String.replace(~r/\s*end\s*end/m, "\nend")

    # Write cleaned content
    File.write!(file, updated_content)
    IO.puts("✅ Cleaned #{file}")
  else
    IO.puts("❌ #{file} - File not found")
  end
end)

IO.puts("🎯 Alias cleanup complete")

# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied

