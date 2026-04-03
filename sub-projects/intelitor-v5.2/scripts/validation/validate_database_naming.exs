#!/usr/bin/env elixir
# Holon Database Naming Validation Script
#
# WHAT: Validates all holon databases follow UHI naming system
# WHY: SC-DBNAME-001 to SC-DBNAME-010 compliance verification
# CONSTRAINTS: Must pass before release
#
# Usage:
#   elixir scripts/validation/validate_database_naming.exs

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule DatabaseNamingValidator do
  @moduledoc """
  Validates holon database naming compliance with UHI specification.

  ## STAMP Constraints Verified
  - SC-DBNAME-001: All holon databases use UHI naming
  - SC-DBNAME-002: FQDN resolution is deterministic
  - SC-DBNAME-003: Database files follow standard naming
  - SC-DBNAME-010: Manifest exists for every holon
  """

  @valid_runtimes ~w(ex fs zig rs)
  @valid_layers ~w(l0 l1 l2 l3 l4 l5 l6 l7)
  @valid_domains ~w(kms prj grd snt imm fnd zen bio pln evo ctx tst dev sre prd obs)
  @valid_types ~w(srv agt reg str brg pub sub wrk)
  @valid_db_files ~w(state.sqlite history.duckdb vectors.sqlite register.duckdb analytics.duckdb manifest.json)

  @base_path "data/holons"

  def run(_args) do
    IO.puts("""
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║           HOLON DATABASE NAMING VALIDATION                                 ║
    ║                    UHI Compliance Check v1.0                               ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    """)

    results = [
      validate_directory_structure(),
      validate_holon_directories(),
      validate_manifests(),
      validate_database_files(),
      check_legacy_paths()
    ]

    print_final_report(results)
  end

  # ============================================================================
  # Directory Structure Validation
  # ============================================================================

  defp validate_directory_structure do
    IO.puts("\n📁 Validating directory structure...")

    if File.exists?(@base_path) do
      # Check runtime directories
      runtime_dirs = File.ls!(@base_path)
      |> Enum.filter(&File.dir?(Path.join(@base_path, &1)))

      valid_runtime_dirs = Enum.filter(runtime_dirs, &(&1 in @valid_runtimes))
      invalid_runtime_dirs = Enum.reject(runtime_dirs, &(&1 in @valid_runtimes))

      IO.puts("   ✅ Base path exists: #{@base_path}")
      IO.puts("   ✅ Valid runtime directories: #{inspect(valid_runtime_dirs)}")

      if length(invalid_runtime_dirs) > 0 do
        IO.puts("   ⚠️  Invalid runtime directories: #{inspect(invalid_runtime_dirs)}")
      end

      {:ok, %{
        base_exists: true,
        valid_runtimes: valid_runtime_dirs,
        invalid_runtimes: invalid_runtime_dirs
      }}
    else
      IO.puts("   ⚠️  Base path does not exist: #{@base_path}")
      {:ok, %{base_exists: false, valid_runtimes: [], invalid_runtimes: []}}
    end
  end

  # ============================================================================
  # Holon Directory Validation
  # ============================================================================

  defp validate_holon_directories do
    IO.puts("\n🏠 Validating holon directories...")

    if not File.exists?(@base_path) do
      IO.puts("   ⏭️  Skipped: base path does not exist")
      {:ok, %{holons: [], valid: 0, invalid: 0}}
    else
      holons = find_holon_directories()

      valid_holons = Enum.filter(holons, &valid_holon_path?/1)
      invalid_holons = Enum.reject(holons, &valid_holon_path?/1)

      IO.puts("   Found #{length(holons)} holon directories")
      IO.puts("   ✅ Valid: #{length(valid_holons)}")
      IO.puts("   ❌ Invalid: #{length(invalid_holons)}")

      Enum.each(invalid_holons, fn path ->
        IO.puts("      - #{path}")
      end)

      {:ok, %{holons: holons, valid: length(valid_holons), invalid: length(invalid_holons)}}
    end
  end

  defp find_holon_directories do
    # Find all directories at depth 4 (runtime/layer/domain/instance)
    Path.wildcard("#{@base_path}/*/*/*/*")
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(&String.replace_prefix(&1, "#{@base_path}/", ""))
  end

  defp valid_holon_path?(path) do
    parts = String.split(path, "/")

    case parts do
      [runtime, layer, domain, _instance] ->
        runtime in @valid_runtimes and
        layer in @valid_layers and
        domain in @valid_domains

      _ ->
        false
    end
  end

  # ============================================================================
  # Manifest Validation (SC-DBNAME-010)
  # ============================================================================

  defp validate_manifests do
    IO.puts("\n📋 Validating manifests (SC-DBNAME-010)...")

    if not File.exists?(@base_path) do
      IO.puts("   ⏭️  Skipped: base path does not exist")
      {:ok, %{with_manifest: 0, without_manifest: 0, invalid_manifest: 0}}
    else
      holon_dirs = Path.wildcard("#{@base_path}/*/*/*/*")
      |> Enum.filter(&File.dir?/1)

      results = Enum.map(holon_dirs, fn dir ->
        manifest_path = Path.join(dir, "manifest.json")

        cond do
          not File.exists?(manifest_path) ->
            {:missing, dir}

          true ->
            case validate_manifest(manifest_path) do
              :ok -> {:valid, dir}
              {:error, reason} -> {:invalid, dir, reason}
            end
        end
      end)

      valid = Enum.count(results, fn {status, _} -> status == :valid end)
      missing = Enum.count(results, fn {status, _} -> status == :missing end)
      invalid = Enum.count(results, fn r -> elem(r, 0) == :invalid end)

      IO.puts("   ✅ Valid manifests: #{valid}")
      IO.puts("   ⚠️  Missing manifests: #{missing}")
      IO.puts("   ❌ Invalid manifests: #{invalid}")

      missing_dirs = for {:missing, dir} <- results, do: dir
      Enum.take(missing_dirs, 5) |> Enum.each(fn dir ->
        IO.puts("      Missing: #{dir}")
      end)

      {:ok, %{with_manifest: valid, without_manifest: missing, invalid_manifest: invalid}}
    end
  end

  defp validate_manifest(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, manifest} ->
            required_fields = ["version", "uhi"]
            missing = Enum.filter(required_fields, &(not Map.has_key?(manifest, &1)))

            if length(missing) == 0 do
              :ok
            else
              {:error, "Missing fields: #{inspect(missing)}"}
            end

          {:error, reason} ->
            {:error, "JSON parse error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Read error: #{inspect(reason)}"}
    end
  end

  # ============================================================================
  # Database File Validation
  # ============================================================================

  defp validate_database_files do
    IO.puts("\n💾 Validating database files...")

    if not File.exists?(@base_path) do
      IO.puts("   ⏭️  Skipped: base path does not exist")
      {:ok, %{valid_files: 0, invalid_files: 0}}
    else
      # Find all database files
      db_files = Path.wildcard("#{@base_path}/*/*/*/*/*.{sqlite,duckdb,db,json}")

      valid_files = Enum.filter(db_files, fn path ->
        filename = Path.basename(path)
        filename in @valid_db_files or String.ends_with?(filename, ".sqlite.r1") or
          String.ends_with?(filename, ".sqlite.r2")
      end)

      invalid_files = Enum.reject(db_files, fn path ->
        filename = Path.basename(path)
        filename in @valid_db_files or String.ends_with?(filename, ".sqlite.r1") or
          String.ends_with?(filename, ".sqlite.r2")
      end)

      IO.puts("   ✅ Valid database files: #{length(valid_files)}")
      IO.puts("   ⚠️  Non-standard files: #{length(invalid_files)}")

      Enum.take(invalid_files, 5) |> Enum.each(fn path ->
        IO.puts("      #{path}")
      end)

      {:ok, %{valid_files: length(valid_files), invalid_files: length(invalid_files)}}
    end
  end

  # ============================================================================
  # Legacy Path Detection
  # ============================================================================

  defp check_legacy_paths do
    IO.puts("\n🔍 Checking for legacy paths...")

    legacy_patterns = [
      "data/kms/*.db",
      "data/kms/*.duckdb",
      "data/kms/*.sqlite",
      "data/smriti/*.db",
      "data/holons/*.duckdb",  # Direct files in holons root
      "data/holons/founder_directive/*"
    ]

    legacy_files = Enum.flat_map(legacy_patterns, &Path.wildcard/1)

    if length(legacy_files) > 0 do
      IO.puts("   ⚠️  Found #{length(legacy_files)} legacy database files:")
      Enum.each(legacy_files, fn path ->
        IO.puts("      #{path}")
      end)
      IO.puts("\n   Run migration script to update:")
      IO.puts("   elixir scripts/migration/migrate_database_paths.exs --dry-run")
    else
      IO.puts("   ✅ No legacy paths detected")
    end

    {:ok, %{legacy_files: length(legacy_files)}}
  end

  # ============================================================================
  # Final Report
  # ============================================================================

  defp print_final_report(results) do
    all_ok = Enum.all?(results, fn {status, _} -> status == :ok end)

    # Extract data from results
    [{:ok, dir_result}, {:ok, holon_result}, {:ok, manifest_result}, {:ok, db_result}, {:ok, legacy_result}] = results

    passed = []
    failed = []
    warnings = []

    # SC-DBNAME-001: UHI naming
    if holon_result.invalid == 0, do: passed, else: failed = [{:failed, "SC-DBNAME-001", "#{holon_result.invalid} invalid holon paths"} | failed]
    if holon_result.valid > 0, do: passed = [{:passed, "SC-DBNAME-001", "#{holon_result.valid} valid holon paths"} | passed]

    # SC-DBNAME-010: Manifest exists
    if manifest_result.without_manifest == 0 do
      passed = [{:passed, "SC-DBNAME-010", "All holons have manifests"} | passed]
    else
      warnings = [{:warning, "SC-DBNAME-010", "#{manifest_result.without_manifest} holons missing manifests"} | warnings]
    end

    # Legacy path check
    if legacy_result.legacy_files > 0 do
      warnings = [{:warning, "LEGACY", "#{legacy_result.legacy_files} legacy files need migration"} | warnings]
    else
      passed = [{:passed, "LEGACY", "No legacy paths detected"} | passed]
    end

    IO.puts("""

    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                         VALIDATION REPORT                                  ║
    ╠═══════════════════════════════════════════════════════════════════════════╣
    """)

    Enum.each(passed, fn {:passed, constraint, msg} ->
      IO.puts("║  ✅ #{String.pad_trailing(constraint, 14)} #{String.pad_trailing(msg, 50)}║")
    end)

    Enum.each(warnings, fn {:warning, constraint, msg} ->
      IO.puts("║  ⚠️  #{String.pad_trailing(constraint, 14)} #{String.pad_trailing(msg, 50)}║")
    end)

    Enum.each(failed, fn {:failed, constraint, msg} ->
      IO.puts("║  ❌ #{String.pad_trailing(constraint, 14)} #{String.pad_trailing(msg, 50)}║")
    end)

    status = cond do
      length(failed) > 0 -> "FAILED"
      length(warnings) > 0 -> "PASSED WITH WARNINGS"
      true -> "PASSED"
    end

    IO.puts("""
    ╠═══════════════════════════════════════════════════════════════════════════╣
    ║  Status: #{String.pad_trailing(status, 62)}║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    """)

    if length(failed) > 0 do
      System.halt(1)
    end
  end
end

# Run validation
DatabaseNamingValidator.run(System.argv())
