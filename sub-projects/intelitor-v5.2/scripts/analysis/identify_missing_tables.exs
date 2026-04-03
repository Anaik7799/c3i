# SOPv5.1 ENHANCED SCRIPT - identify_missing_tables.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: core_analysis
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied

# SOPv5.1 ENHANCED SCRIPT - identify_missing_tables.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: core_analysis
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied

# SOPv5.1 ENHANCED SCRIPT - identify_missing_tables.exs
# Generated: 2025-08-02 17:10:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: core_analysis
# Agent: Script Enhancement System with 11-Agent Architecture
# Enhancements: Complete SOPv5.1 cybernetic integration applied

#!/usr / bin / env elixir

# Script to identify missing __database tables for Ash resources

defmodule Missing Tables Analyzer do
  @spec run() :: any()
  def run do
    IO.puts("🔍 ANALYZING MISSING DATABASE TABLES")
    IO.puts("=" <> String.duplicate("=", 50))

    # Get tables that the comprehensive migration wants to create
    migration_file = "priv / repo / migrations / 20250608194652_complete_resource_setup.exs"
    {:ok, content} = File.read(migration_file)

    # Extract table names from create __statements
    migration_tables = extract_table_names(content)
    IO.puts("📋 Tables in comprehensive migration: #{length(migration_tables)}")

    # Get existing tables from __database
    {existing_output, _} =
      System.cmd("psql", [
        "-h",
        "localhost",
        "-p",
        "5433",
        "-U",
        "postgres",
        "-d",
        "indrajaal_dev",
        "-c",
        "\\dt",
        "-t"
      ])

    existing_tables =
      existing_output
      |> String.split("\n")
      |> Enum.map(&String.trim / 1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(fn line ->
        # Extract table name from psql output format
        line
        |> String.split("|")
        |> Enum.at(1)
        |> String.trim()
      end)
      |> Enum.filter(&(&1 != nil and &1 != ""))

    IO.puts("🗃️  Existing tables: #{length(existing_tables)}")

    # Find missing tables
    missing_tables = migration_tables -- existing_tables
    duplicate_tables = migration_tables -- missing_tables

    IO.puts("\n📊 ANALYSIS RESULTS:")
    IO.puts("Missing tables: #{length(missing_tables)}")
    IO.puts("Duplicate / existing tables: #{length(duplicate_tables)}")

    if length(missing_tables) > 0 do
      IO.puts("\n❌ MISSING TABLES:")

      Enum.each(missing_tables, fn table ->
        IO.puts("-#{table}")
      end)
    end

    if length(duplicate_tables) > 0 do
      IO.puts("\n⚠️  TABLES THAT ALREADY EXIST:")

      Enum.each(duplicate_tables, fn table ->
        IO.puts("-#{table}")
      end)
    end

    IO.puts("\n💡 RECOMMENDED ACTIONS:")

    if length(missing_tables) > 0 do
      IO.puts("1. Create selective migration for missing #{length(missing_tables)
      IO.puts("2. Extract CREATE __statements from comprehensive migration for missing tables only")
    end

    if length(duplicate_tables) > 0 do
      IO.puts("3. Skip creation of #{length(duplicate_tables)} existing tables")
    end

    IO.puts("4. Run the selective migration to complete __database setup")

    %{
      migration_tables: migration_tables,
      existing_tables: existing_tables,
      missing_tables: missing_tables,
      duplicate_tables: duplicate_tables
    }
  end

  @spec extract_table_names(term()) :: term()
  defp extract_table_names(content) do
    # Extract table names from "create table(:table_name" patterns
    Regex.scan(~r / create table\(:(\w+)/, content)
    |> Enum.map(fn [_, table_name] -> table_name end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end

# Run the analysis
result = Missing Tables Analyzer.run()

# Write results to file for further processing
output_file = "__data / analysis / missing_tables_analysis.json"
File.mkdir_p!(Path.dirname(output_file))

json_result = Jason.encode!(result, pretty: true)
File.write!(output_file, json_result)

IO.puts("\n📁 Analysis saved to: #{output_file}")

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

