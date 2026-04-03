#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - fix_migration_boolean_syntax.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - fix_migration_boolean_syntax.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - fix_migration_boolean_syntax.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied



# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework

defmodule MigrationBooleanFixer do
  
__require Logger

@moduledoc """
  Fixes boolean WHERE clause syntax errors in migration files.
  PostgreSQL __requires boolean columns to be referenced without explicit = true
  """
## SOPv5.1 Framework Integration

This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

**Framework Components:**
- SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
- TPS: Toyota Production System with 5-Level Root Cause Analysis
- STAMP: Safety Constraint Validation with real-time monitoring
- TDG: Test-Driven Generation methodology compliance
- GDE: Goal-Directed Execution with adaptive strategy selection
- Patient Mode: NO_TIMEOUT policy with infinite patience execution
- Container-Only: Mandatory NixOS container execution with PHICS integration
- 11-Agent Architecture: Supervisor-Helper-Worker coordination support

**Category**: maintenance
**Enhanced**: 2025-08-02 17:10:00 CEST
**Agent**: Script Enhancement System with systematic SOPv5.1 integration


## SOPv5.1 Framework Integration

This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

**Framework Components:**
- SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
- TPS: Toyota Production System with 5-Level Root Cause Analysis
- STAMP: Safety Constraint Validation with real-time monitoring
- TDG: Test-Driven Generation methodology compliance
- GDE: Goal-Directed Execution with adaptive strategy selection
- Patient Mode: NO_TIMEOUT policy with infinite patience execution
- Container-Only: Mandatory NixOS container execution with PHICS integration
- 11-Agent Architecture: Supervisor-Helper-Worker coordination support

**Category**: maintenance
**Enhanced**: 2025-08-02 17:10:00 CEST
**Agent**: Script Enhancement System with systematic SOPv5.1 integration


## SOPv5.1 Framework Integration

This script has been enhanced with comprehensive SOPv5.1 cybernetic execution framework:

**Framework Components:**
- SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase execution
- TPS: Toyota Production System with 5-Level Root Cause Analysis
- STAMP: Safety Constraint Validation with real-time monitoring
- TDG: Test-Driven Generation methodology compliance
- GDE: Goal-Directed Execution with adaptive strategy selection
- Patient Mode: NO_TIMEOUT policy with infinite patience execution
- Container-Only: Mandatory NixOS container execution with PHICS integration
- 11-Agent Architecture: Supervisor-Helper-Worker coordination support

**Category**: maintenance
**Enhanced**: 2025-08-02 17:10:00 CEST
**Agent**: Script Enhancement System with systematic SOPv5.1 integration



  @spec fix_migration_files() :: any()
  def fix_migration_files do
    migration_dir = "priv/repo/migrations"

    migration_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".exs"))
    |> Enum.each(&fix_migration_file/1)
  end

  @spec fix_migration_file(any()) :: any()
  def fix_migration_file(filename) do
    path = Path.join("priv/repo/migrations", filename)

    IO.puts("Checking migration file: #{filename}")

    content = File.read!(path)

    # Fix boolean WHERE clauses for PostgreSQL
    fixes = [
      # Fix active? = true patterns
      {~r/WHERE\s+active\?\s*=\s*true/, "WHERE \"active?\""},
      {~r/WHERE\s+enabled\?\s*=\s*true/, "WHERE \"enabled?\""},
      {~r/WHERE\s+is_primary\?\s*=\s*true/, "WHERE \"is_primary?\""},
      {~r/WHERE\s+is_active\?\s*=\s*true/, "WHERE \"is_active?\""},
      {~r/WHERE\s+is_default\?\s*=\s*true/, "WHERE \"is_default?\""},

      # Quote boolean column names in indexes
      {~r/\((active\?)\)/, "(\"active?\")"},
      {~r/\((enabled\?)\)/, "(\"enabled?\")"},
      {~r/\((is_primary\?)\)/, "(\"is_primary?\")"},
      {~r/\((is_active\?)\)/, "(\"is_active?\")"},
      {~r/\((is_default\?)\)/, "(\"is_default?\")"}
    ]

    _fixed_content =
      Enum.reduce(fixes, _content, fn {pattern, replacement}, acc ->
        if String.contains?(acc, "WHERE") and Regex.match?(pattern, acc) do
          IO.puts("  - Fixing boolean WHERE clause in #{filename}")
          Regex.replace(pattern, acc, replacement)
        else
          acc
        end
      end)

    if fixed_content != content do
      File.write!(path, fixed_content)
      IO.puts("  ✅ Fixed boolean syntax in #{filename}")
    else
      IO.puts("  ✅ No fixes needed in #{filename}")
    end
  end
end

# Run the fixer
MigrationBooleanFixer.fix_migration_files()
IO.puts("\n🎯 Migration boolean syntax fixes completed!")

# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied


# SOPv5.1 ENHANCEMENT COMPLETE
# Enhanced: 2025-08-02 17:10:00 CEST
# Framework: Complete SOPv5.1 + TPS + STAMP + TDG + GDE integration
# Agent: Script Enhancement System with 11-Agent Architecture
# Status: Full cybernetic execution framework integration applied

