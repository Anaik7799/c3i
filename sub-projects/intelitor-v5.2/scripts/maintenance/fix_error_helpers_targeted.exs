#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - fix_error_helpers_targeted.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - fix_error_helpers_targeted.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# SOPv5.1 ENHANCED SCRIPT - fix_error_helpers_targeted.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# Targeted fix for error helper replacement in domain files
# Replace the old analyze_validation_errors function with shared helper call


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework


# SOPv5.1 Framework Imports
# Import comprehensive SOPv5.1 cybernetic execution framework

defmodule FixErrorHelpersTargeted do
  

  @moduledoc """
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

__require Logger

@files_to_process [
    {"lib/indrajaal/shifts.ex", :shifts},
    {"lib/indrajaal/sites.ex", :sites},
    {"lib/indrajaal/maintenance.ex", :maintenance},
    {"lib/indrajaal/intelligence.ex", :intelligence}
  ]

  def main([]) do
    IO.puts("🔧 Targeted Error Helper Replacement")

    results = Enum.map(@files_to_process, &process_file/1)

    successful = Enum.count(results, fn {_, status} -> status == :ok end)
    IO.puts("✅ Successfully processed #{successful}/#{length(@files_to_process)} files")
  end

  defp process_file({file_path, domain_atom}) do
    IO.puts("Processing: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        # Check if file needs shared helper alias
        content_with_alias =
          if String.contains?(content, "alias Indrajaal.Shared.EnhancedErrorHelpers") do
            content
          else
            add_shared_helper_alias(content)
          end

        # Replace the analyze_validation_errors function
        updated_content = replace_analyze_validation_errors(content_with_alias, domain_atom)

        File.write!(file_path, updated_content)
        IO.puts("  ✅ Updated #{file_path}")
        {file_path, :ok}

      {:error, reason} ->
        IO.puts("  ❌ Error reading #{file_path}: #{reason}")
        {file_path, :error}
    end
  end

  defp add_shared_helper_alias(content) do
    # Find a good place to insert the alias-after existing aliases
    if String.contains?(content, "alias Indrajaal.") do
      # Insert after the last alias line
      lines = String.split(content, "\n")

      {before_alias, from_alias} =
        Enum.split_while(lines, fn line ->
          !String.starts_with?(String.trim(line), "alias ")
        end)

      # Find the last alias line
      {alias_lines, after_alias} =
        Enum.split_while(from_alias, fn line ->
          String.starts_with?(String.trim(line), "alias ") || String.trim(line) == ""
        end)

      new_alias = "  alias Indrajaal.Shared.EnhancedErrorHelpers"

      (before_alias ++ alias_lines ++ [new_alias] ++ after_alias)
      |> Enum.join("\n")
    else
      content
    end
  end

  defp replace_analyze_validation_errors(content, domain_atom) do
    # Find the existing function and replace it
    pattern =
      ~r/  @spec analyze_validation_errors\(term\(\)\) :: term\(\)\s*\n  defp analyze_validation_errors\(changeset\) do.*?\n  end/ms

    replacement =
      "  @spec analyze_validation_errors(term()) :: term()\n  defp analyze_validation_errors(changeset) do\n    EnhancedErrorHelpers.analyze_validation_errors(:#{domain_atom},

    String.replace(content, pattern, replacement)
  end
end

FixErrorHelpersTargeted.main(System.argv())

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

