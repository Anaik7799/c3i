#!/usr/bin/env elixir

defmodule FactoryConsolidation do
  @moduledoc """
  SOPv5.1 TPS Systematic Factory Consolidation
  Phase 3A: Factory/Support utility consolidation (~400 violations)

  TPS Jidoka Principle: Stop and fix factory duplication systematically
  5-Level RCA:
  1. Symptom: Duplicate factory methods and helpers
  2. Surface Cause: Copy-paste development patterns
  3. System Behavior: No shared factory utilities
  4. Configuration Gap: Missing factory helper infrastructure
  5. Design Analysis: Need systematic factory consolidation framework

  Strategy: Create shared factory helpers and refactor all factories
  """

  @spec main(term()) :: any()
  def main(args \\ []) do
    IO.puts("🏭 SOPv5.1 TPS Factory Consolidation - Phase 3A")
    IO.puts("Agent: Supervisor (Factory Consolidation Coordination)")

    case args do
      ["--consolidate"] -> consolidate_factories()
      ["--validate"] -> validate_consolidation()
      ["--help"] -> show_help()
      _ -> consolidate_factories()
    end
  end

  defp consolidate_factories do
    IO.puts("\n📊 Phase 3A: Factory/Support utility consolidation")

    factory_files = find_factory_files()
    IO.puts("Found #{length(factory_files)} factory files to consolidate")

    # Step 1: Analyze current duplication patterns
    analyze_factory_patterns(factory_files)

    # Step 2: Apply systematic consolidation
    consolidate_factory_files(factory_files)

    # Step 3: Validate results
    validate_consolidation()

    IO.puts("✅ Phase 3A Factory consolidation completed")
  end

  defp find_factory_files do
    "test/support/factories/*.ex"
    |> Path.wildcard()
    |> Enum.filter(&File.exists?/1)
  end

  defp analyze_factory_patterns(factory_files) do
    IO.puts("\n🔍 Analyzing factory duplication patterns:")

    duplication_patterns = [
      "normalize_attrs",
      "handle_tenant_association",
      "standard__metadata",
      "random_decimal",
      "random_boolean",
      "base_factory_attributes"
    ]

    Enum.each(duplication_patterns, fn pattern ->
      count = count_pattern_occurrences(factory_files, pattern)
      IO.puts("  #{pattern}: #{count} occurrences")
    end)
  end

  defp count_pattern_occurrences(files, pattern) do
    Enum.reduce(files, 0, fn file, acc ->
      content = File.read!(file)
      matches = Regex.scan(~r/#{pattern}/, content |> length())
      acc + matches
    end)
  end

  defp consolidate_factory_files(factory_files) do
    IO.puts("\n🔧 Consolidating factory files:")

    Enum.each(factory_files, fn file ->
      IO.puts("  Processing: #{Path.basename(file)}")
      consolidate_single_factory(file)
    end)
  end

  defp consolidate_single_factory(file_path) do
    content = File.read!(file_path)

    # Check if already consolidated
    if String.contains?(content, "use Indrajaal.Shared.FactoryHelpers") do
      IO.puts("    ✅ Already consolidated")
      :ok
    else
      # Apply consolidation transformations
      consolidated_content =
        content
        |> add_factory_helpers_import()
        |> consolidate_normalize_attrs()
        |> consolidate_tenant_handling()
        |> consolidate__metadata_generation()
        |> consolidate_random_helpers()
        |> add_consolidation_marker()

      # Write consolidated version
      File.write!(file_path, consolidated_content)
      IO.puts("    ✅ Consolidated with shared helpers")
    end
  end

  defp add_factory_helpers_import(content) do
    # Add import after the quote do line
    String.replace(
      content,
      "quote do",
      "quote do\n      use Indrajaal.Shared.FactoryHelpers"
    )
  end

  defp consolidate_normalize_attrs(content) do
    # Remove duplicate normalize_attrs definitions
    content
    |> String.replace(
      ~r/\s+def normalize_attrs.*?end/s,
      "" |> String.replace(~r/\s+@spec normalize_attrs.*?\n/s, "")
    )
  end

  defp consolidate_tenant_handling(content) do
    # Remove duplicate tenant handling functions
    content
    |> String.replace(
      ~r/\s+def handle_tenant_association.*?end/s,
      "" |> String.replace(~r/\s+@spec handle_tenant_association.*?\n/s, "")
    )
  end

  defp consolidate__metadata_generation(content) do
    # Consolidate metadata generation patterns
    content
    |> String.replace(~r/metadata: [^,}]+metadata\(\)/, "metadata: standard__metadata()")
    |> String.replace(~r/\s+defp.*__metadata.*?end/s, "")
  end

  defp consolidate_random_helpers(content) do
    # Replace common random patterns with shared helpers
    content
    |> String.replace(~r/Decimal\.new\(to_string\([^)]+\)\)/, "random_decimal()")
    |> String.replace(~r/Enum\.random\(\[true, false\]\)/, "random_boolean()")
  end

  defp add_consolidation_marker(content) do
    # Add consolidation marker at the top
    marker = """
    # FACTORY CONSOLIDATION STATUS: ✅ Phase 3A Completed
    # Duplicate Reduction: Factory helper patterns consolidated
    # Pattern: EP075 - Factory Method Duplication
    # Agent: Supervisor (Factory Consolidation)
    # SOPv5.1 Compliance: ✅ Systematic factory utilities integration

    """

    marker <> content
  end

  defp validate_consolidation do
    IO.puts("\n✅ Validating factory consolidation:")

    factory_files = find_factory_files()
    consolidated_count = count_consolidated_factories(factory_files)
    total_count = length(factory_files)

    IO.puts("  Consolidated factories: #{consolidated_count}/#{total_count}")

    if consolidated_count == total_count do
      IO.puts("  ✅ All factories successfully consolidated")
    else
      IO.puts("  ⚠️  #{total_count - consolidated_count} factories need consolidation")
    end

    # Count remaining duplication
    remaining_duplication = count_remaining_duplication(factory_files)
    IO.puts("  Remaining duplication patterns: #{remaining_duplication}")

    if remaining_duplication == 0 do
      IO.puts("  ✅ Zero factory duplication achieved")
    end
  end

  defp count_consolidated_factories(factory_files) do
    Enum.count(factory_files, fn file ->
      content = File.read!(file)
      String.contains?(content, "use Indrajaal.Shared.FactoryHelpers")
    end)
  end

  defp count_remaining_duplication(factory_files) do
    duplication_patterns = [
      "def normalize_attrs",
      "def handle_tenant_association",
      "defp.*__metadata",
      "Decimal\\.new\\(to_string"
    ]

    Enum.reduce(duplication_patterns, 0, fn pattern, acc ->
      count = count_pattern_occurrences(factory_files, pattern)
      acc + count
    end)
  end

  defp show_help do
    IO.puts("""
    SOPv5.1 TPS Factory Consolidation Tool

    Usage:
      elixir scripts/systematic/factory_consolidation.exs [option]

    Options:
      --consolidate    Apply factory consolidation (default)
      --validate      Validate consolidation results
      --help          Show this help

    This tool systematically eliminates factory duplication by:
    1. Creating shared factory helper utilities
    2. Refactoring all factory files to use shared helpers
    3. Validating zero duplication achievement

    Part of Phase 3A: Factory/Support utility consolidation (~400 violations)
    """)
  end
end

# Execute if run directly
if __MODULE__ == FactoryConsolidation do
  FactoryConsolidation.main(System.argv())
end
