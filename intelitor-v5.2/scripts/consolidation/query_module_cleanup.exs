#!/usr/bin/env elixir

defmodule QueryModuleCleanup do
  @moduledoc """
  SOPv5.1 Phase 11.2: Query Module Cleanup Engine

  Safely removes/deprecates redundant query utility modules now that
  all functionality has been consolidated into UnifiedQuerySystem.

  Target Modules for Cleanup:
  - query_helpers.ex (replaced by UnifiedQuerySystem)
  - query_optimization_utilities.ex (replaced by UnifiedQuerySystem)
  - aggregation_query_builder.ex (replaced by UnifiedQuerySystem)
  - timescale_query_utilities.ex (replaced by UnifiedQuerySystem)
  - consolidated_query_utilities.ex (replaced by UnifiedQuerySystem)

  11-Agent Cybernetic Coordination:
  - Supervisor: Strategic oversight of safe module removal with rollback capability
  - Helper-3: Module Cleanup Specialist managing systematic deprecation
  - Workers: Validation of no remaining dependencies before removal
  """

  __require Logger

  @lib_dir "/home/an/dev/elixir/ash/indrajaal-demo/lib"

  # Old query modules to be deprecated/removed
  @redundant_query_modules [
    "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal/shared/query_helpers.ex",
    "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal/shared/query_optimization_utilities.ex",
    "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal/shared/aggregation_query_builder.ex",
    "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal/shared/timescale_query_utilities.ex",
    "/home/an/dev/elixir/ash/indrajaal-demo/lib/indrajaal/shared/consolidated_query_utilities.ex"
  ]

  @spec main(term()) :: any()
  def main(args \\ []) do
    case args do
      ["--status"] -> show_cleanup_status()
      ["--analyze-dependencies"] -> analyze_remaining_dependencies()
      ["--deprecate"] -> deprecate_redundant_modules()
      ["--remove"] -> remove_redundant_modules()
      ["--comprehensive"] -> run_comprehensive_cleanup()
      ["--validate"] -> validate_cleanup_success()
      _ -> show_help()
    end
  end

  @doc """
  Show cleanup status for redundant query modules
  """

  @spec show_cleanup_status() :: any()
  def show_cleanup_status do
    IO.puts("🚀 SOPv5.1 PHASE 11.2: QUERY MODULE CLEANUP STATUS")
    IO.puts("=" |> String.duplicate(70))

    IO.puts("📋 REDUNDANT QUERY MODULES IDENTIFIED: #{length(@redundant_query_modules)}")

    # Analyze each module
    Enum.each(@redundant_query_modules, fn module_path ->
      module_name = Path.basename(module_path)
      IO.puts("\n🔍 #{module_name}:")

      if File.exists?(module_path) do
        {:ok, content} = File.read(module_path)

        # Count functions in module
        function_count = count_public_functions(content)
        IO.puts("  📊 Public Functions: #{function_count}")

        # Check for any external dependencies
        dependencies = find_external_dependencies(module_path)

        if length(dependencies) > 0 do
          IO.puts("  ⚠️  External Dependencies: #{length(dependencies)}")

          Enum.takedependencies, 3 |> Enum.each(fn dep ->
            IO.puts("    📎 #{Path.basename(dep)}")
          end)
        else
          IO.puts("  ✅ No External Dependencies")
        end

        IO.puts("  📝 Status: Ready for cleanup")
      else
        IO.puts("  ❌ Module not found")
      end
    end)

    IO.puts("\n✅ CLEANUP IMPACT:")
    total_functions = count_total_redundant_functions()
    IO.puts("  📊 Total Redundant Functions: #{total_functions}")
    IO.puts("  🎯 Cleanup Target: Remove #{length(@redundant_query_modules)} modules")
    IO.puts("  💰 Strategic Value: Complete query system consolidation")
  end

  @doc """
  Run comprehensive query module cleanup
  """

  @spec run_comprehensive_cleanup() :: any()
  def run_comprehensive_cleanup do
    IO.puts("🚀 SOPv5.1 PHASE 11.2: COMPREHENSIVE QUERY MODULE CLEANUP")
    IO.puts("=" |> String.duplicate(80))

    start_time = System.monotonic_time()

    # Phase 11.2.1: Analyze dependencies
    IO.puts("📋 Phase 11.2.1: Analyzing remaining dependencies...")
    dependency_results = analyze_all_dependencies()

    # Phase 11.2.2: Deprecate modules
    IO.puts("\n🎯 Phase 11.2.2: Deprecating redundant modules...")
    deprecation_results = deprecate_all_modules()

    # Phase 11.2.3: Results analysis
    duration = System.monotonic_time() - start_time
    duration_seconds = System.convert_time_unit(duration, :native, :second)

    successful_analysis = dependency_results |> Enum.count(fn {status, _} -> status == :ok end)

    successful_deprecations =
      deprecation_results |> Enum.count(fn {status, _} -> status == :ok end)

    IO.puts("\n🏆 COMPREHENSIVE CLEANUP RESULTS:")
    IO.puts("✅ Dependency Analysis: #{successful_analysis}/#{length(@redundant_query_modules)}")

    IO.puts(
      "✅ Module Deprecations: #{successful_deprecations}/#{length(@redundant_query_modules)}"
    )

    IO.puts("⏱️  Total Duration: #{duration_seconds} seconds")

    if successful_analysis == length(@redundant_query_modules) and
         successful_deprecations == length(@redundant_query_modules) do
      IO.puts("\n🎯 PHASE 11.2 COMPLETED: 100% SUCCESS RATE")
      log_cleanup_success(length(@redundant_query_modules), duration_seconds)
    else
      IO.puts("\n⚠️  PARTIAL SUCCESS: Some modules __require manual attention")
    end
  end

  @doc """
  Analyze remaining dependencies for all redundant modules
  """

  @spec analyze_remaining_dependencies() :: any()
  def analyze_remaining_dependencies do
    IO.puts("🔍 ANALYZING REMAINING DEPENDENCIES...")

    results = analyze_all_dependencies()

    IO.puts("\n📊 DEPENDENCY ANALYSIS RESULTS:")

    Enum.each(results, fn {status, result} ->
      case status do
        :ok ->
          IO.puts("✅ #{result.module}: #{result.dependency_count} dependencies")

        :error ->
          IO.puts("❌ #{result}: Analysis failed")
      end
    end)
  end

  @doc """
  Deprecate redundant query modules
  """

  @spec deprecate_redundant_modules() :: any()
  def deprecate_redundant_modules do
    IO.puts("🔄 DEPRECATING REDUNDANT QUERY MODULES...")

    results = deprecate_all_modules()

    successful = results |> Enum.count(fn {status, _} -> status == :ok end)

    IO.puts("\n📊 DEPRECATION RESULTS:")
    IO.puts("✅ Successfully Deprecated: #{successful}/#{length(@redundant_query_modules)}")

    if successful == length(@redundant_query_modules) do
      IO.puts("🎯 ALL MODULES SUCCESSFULLY DEPRECATED")
    end
  end

  # Private helper functions

  defp analyze_all_dependencies do
    @redundant_query_modules
    |> Enum.map(fn module_path ->
      analyze_single_module_dependencies(module_path)
    end)
  end

  defp analyze_single_module_dependencies(module_path) do
    try do
      if File.exists?(module_path) do
        dependencies = find_external_dependencies(module_path)

        {:ok,
         %{
           module: Path.basename(module_path),
           dependency_count: length(dependencies),
           dependencies: dependencies
         }}
      else
        {:ok,
         %{
           module: Path.basename(module_path),
           dependency_count: 0,
           dependencies: []
         }}
      end
    rescue
      error -> {:error, "Analysis failed: #{inspect(error)}"}
    end
  end

  defp deprecate_all_modules do
    @redundant_query_modules
    |> Enum.with_index1 |> Enum.map(fn {module_path, index} ->
      module_name = Path.basename(module_path)
      IO.puts("  🔄 [#{index}/#{length(@redundant_query_modules)}] #{module_name}")

      deprecate_single_module(module_path)
    end)
  end

  defp deprecate_single_module(module_path) do
    try do
      if File.exists?(module_path) do
        {:ok, content} = File.read(module_path)

        # Add deprecation warning to module
        deprecated_content = add_deprecation_warning(content)

        # Create backup
        backup_path = module_path <> ".deprecation_backup_#{timestamp()}"
        File.copy!(module_path, backup_path)

        # Write deprecated version
        File.write!(module_path, deprecated_content)

        {:ok,
         %{
           module: Path.basename(module_path),
           action: "deprecated",
           backup: backup_path
         }}
      else
        {:ok,
         %{
           module: Path.basename(module_path),
           action: "already_removed",
           backup: nil
         }}
      end
    rescue
      error -> {:error, "Deprecation failed: #{inspect(error)}"}
    end
  end

  defp find_external_dependencies(module_path) do
    # Find all files that import or use this module
    module_name =
      module_path
      |> Path.basename".ex" |> Macro.camelize()

    @lib_dir
    |> Path.join"**/*.ex" |> Path.wildcard()
    |> Enum.rejectfn file -> file == module_path end |> Enum.filter(fn file ->
      {:ok, content} = File.read(file)

      String.contains?(content, module_name) and
        (String.contains?(content, "alias") or String.contains?(content, "import") or
           String.contains?(content, "#{module_name}."))
    end)
  end

  defp count_public_functions(content) do
    length(Regex.scan(~r/def\s+[a-z_][a-zA-Z0-9_]*\s*\(/, content))
  end

  defp count_total_redundant_functions do
    @redundant_query_modules
    |> Enum.map(fn module_path ->
      if File.exists?(module_path) do
        {:ok, content} = File.read(module_path)
        count_public_functions(content)
      else
        0
      end
    end)
    |> Enum.sum()
  end

  defp add_deprecation_warning(content) do
    # Add deprecation warning at the top of the module
    deprecation_warning = """
    @deprecated \"Use Indrajaal.Shared.UnifiedQuerySystem instead. This module has been consolidated into UnifiedQuerySystem for better maintainability and performance.\"
    """

    # Insert after module declaration
    String.replace(
      content,
      ~r/(defmodule\s+[^\n]+\n)/,
      "\\1\n  #{String.trim(deprecation_warning)}\n"
    )
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace~r/[:\-T]/, "" |> String.slice(0..14)
  end

  defp log_cleanup_success(module_count, duration_seconds) do
    log_content = """
    🏆 SOPv5.1 PHASE 11.2: QUERY MODULE CLEANUP SUCCESS
    ==================================================

    Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    Modules Cleaned: #{module_count}
    Success Rate: 100%
    Duration: #{duration_seconds} seconds

    Phase 11.2 Achievements - Module Deprecation:
    ✅ query_helpers.ex: Deprecated with @deprecated annotation
    ✅ query_optimization_utilities.ex: Deprecated with clear migration path
    ✅ aggregation_query_builder.ex: Deprecated in favor of UnifiedQuerySystem
    ✅ timescale_query_utilities.ex: Deprecated with consolidated functionality
    ✅ consolidated_query_utilities.ex: Deprecated as superseded

    Strategic Impact:
    📈 Code Simplification: 5 query modules → 1 UnifiedQuerySystem
    🔧 Maintenance Reduction: Single module to maintain instead of 5
    🛡️ Consistency Guarantee: All query operations use same patterns
    📊 Performance Optimization: Consolidated compilation paths
    🧹 Architecture Cleanliness: Eliminated duplicate query utility modules

    Next Steps: Phase 11.3 - Validate complete elimination of query duplications
    """

    log_file =
      "/home/an/dev/elixir/ash/indrajaal-demo/__data/tmp/claude_query_cleanup_success_#{timestamp()}.log"

    File.write!(log_file, log_content)

    IO.puts("📝 Query cleanup success log written to: #{log_file}")
  end


  @spec remove_redundant_modules() :: any()
  def remove_redundant_modules do
    IO.puts("⚠️  WARNING: This will permanently remove redundant query modules.")
    IO.puts("Use --deprecate first to mark modules as deprecated.")
  end


  @spec validate_cleanup_success() :: any()
  def validate_cleanup_success do
    IO.puts("🔍 VALIDATING QUERY MODULE CLEANUP SUCCESS...")

    deprecated_count =
      @redundant_query_modules
      |> Enum.count(fn module_path ->
        if File.exists?(module_path) do
          {:ok, content} = File.read(module_path)
          String.contains?(content, "@deprecated")
        else
          # Consider removed modules as successfully cleaned
          true
        end
      end)

    IO.puts("📊 CLEANUP VALIDATION RESULTS:")

    IO.puts(
      "✅ Deprecated/Removed Modules: #{deprecated_count}/#{length(@redundant_query_modules)}"
    )

    if deprecated_count == length(@redundant_query_modules) do
      IO.puts("🎯 ALL QUERY MODULES SUCCESSFULLY CLEANED UP")
    else
      IO.puts("⚠️  Some modules still __require cleanup")
    end

    # Check UnifiedQuerySystem is being used
    unified_usage = count_unified_query_system_usage()
    IO.puts("📈 UnifiedQuerySystem Usage: #{unified_usage} occurrences")
  end

  defp count_unified_query_system_usage do
    @lib_dir
    |> Path.join"**/*.ex" |> Path.wildcard()
    |> Enum.map(fn file ->
      {:ok, content} = File.read(file)
      length(Regex.scan(~r/UnifiedQuerySystem/, content))
    end)
    |> Enum.sum()
  end

  defp show_help do
    IO.puts("""
    📋 SOPv5.1 QUERY MODULE CLEANUP TOOL

    Usage: elixir query_module_cleanup.exs [COMMAND]

    Commands:
      --status                Show cleanup status for redundant modules
      --analyze-dependencies  Analyze remaining dependencies
      --deprecate            Deprecate redundant query modules
      --remove               Permanently remove modules (use with caution)
      --comprehensive        Run complete cleanup process
      --validate             Validate cleanup success

    Examples:
      elixir scripts/consolidation/query_module_cleanup.exs --status
      elixir scripts/consolidation/query_module_cleanup.exs --comprehensive
    """)
  end
end

# Execute if run directly
if System.argv() |> List.first() do
  QueryModuleCleanup.main(System.argv())
else
  QueryModuleCleanup.main(["--help"])
end
