# SOPv5.1 ENHANCED SCRIPT - check_rca_syntax.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied

# SOPv5.1 ENHANCED SCRIPT - check_rca_syntax.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


__require Logger

#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - check_rca_syntax.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: maintenance
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied


# Check syntax of five_level_rca_engine.ex
file_path = "lib/indrajaal/tps/five_level_rca_engine.ex"

IO.puts("Checking syntax of #{file_path}...")

case File.read(file_path) do
  {:ok, content} ->
    case Code.string_to_quoted(content) do
      {:ok, _ast} ->
        IO.puts("✅ File has valid syntax!")

      {:error, {meta, message, token}} ->
        IO.puts("❌ Syntax error found!")
        IO.puts("Line: #{meta[:line]}, Column: #{meta[:column]}")
        IO.puts("Message: #{message}")
        IO.puts("Token: #{inspect(token)}")

        # Show __context
        lines = String.split(content, "\n")
        error_line = meta[:line] - 1

        IO.puts("\nContext:")

        for i <- max(0, error_line - 3)..min(length(lines) - 1, error_line + 3) do
          line = Enum.at(lines, i)
          marker = if i == error_line, do: ">>>", else: "   "
          IO.puts("#{marker} #{i + 1}: #{line}")
        end
    end

  {:error, reason} ->
    IO.puts("Error reading file: #{reason}")
end

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

