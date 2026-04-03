#!/usr/bin/env elixir
# Holon Database Path Migration Script
#
# WHAT: Migrates legacy database paths to UHI-based naming system
# WHY: SC-DBNAME-001 requires all holon databases to follow UHI naming
# CONSTRAINTS: SC-DBNAME-001 to SC-DBNAME-010
#
# Usage:
#   elixir scripts/migration/migrate_database_paths.exs --dry-run
#   elixir scripts/migration/migrate_database_paths.exs --execute

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule DatabasePathMigration do
  @moduledoc """
  Migrates legacy database paths to UHI-based naming system.

  ## Legacy to UHI Mapping

  | Legacy Path | UHI (FQDN) | New Path |
  |-------------|------------|----------|
  | data/kms/holons.db | ex:l3:kms:srv:main:state | data/holons/ex/l3/kms/main/state.sqlite |
  | data/kms/analytics.duckdb | ex:l3:kms:srv:main:history | data/holons/ex/l3/kms/main/history.duckdb |
  | data/kms/smriti.db | ex:l3:kms:str:smriti:state | data/holons/ex/l3/kms/smriti/state.sqlite |
  | data/holons/prajna_register.duckdb | ex:l5:prj:srv:prajna:register | data/holons/ex/l5/prj/prajna/register.duckdb |
  | data/holons/founder_directive/state.sqlite | ex:l5:fnd:reg:founder:state | data/holons/ex/l5/fnd/founder/state.sqlite |
  | data/holons/founder_directive/history.duckdb | ex:l5:fnd:reg:founder:history | data/holons/ex/l5/fnd/founder/history.duckdb |
  | data/smriti/planning.db | fs:l4:pln:srv:main:state | data/holons/fs/l4/pln/main/state.sqlite |
  """

  @legacy_mappings [
    # KMS databases
    {"data/kms/holons.db", "ex:l3:kms:srv:main:state", "data/holons/ex/l3/kms/main/state.sqlite"},
    {"data/kms/analytics.duckdb", "ex:l3:kms:srv:main:history", "data/holons/ex/l3/kms/main/history.duckdb"},
    {"data/kms/smriti.db", "ex:l3:kms:str:smriti:state", "data/holons/ex/l3/kms/smriti/state.sqlite"},
    {"data/kms/semantic.sqlite", "ex:l3:kms:str:semantic:state", "data/holons/ex/l3/kms/semantic/state.sqlite"},

    # Prajna databases
    {"data/holons/prajna_register.duckdb", "ex:l5:prj:srv:prajna:register", "data/holons/ex/l5/prj/prajna/register.duckdb"},

    # Founder Directive databases
    {"data/holons/founder_directive/state.sqlite", "ex:l5:fnd:reg:founder:state", "data/holons/ex/l5/fnd/founder/state.sqlite"},
    {"data/holons/founder_directive/history.duckdb", "ex:l5:fnd:reg:founder:history", "data/holons/ex/l5/fnd/founder/history.duckdb"},

    # F# Planning databases
    {"data/smriti/planning.db", "fs:l4:pln:srv:main:state", "data/holons/fs/l4/pln/main/state.sqlite"},

    # Knowledge databases
    {"data/holons/knowledge.duckdb", "ex:l3:kms:srv:main:analytics", "data/holons/ex/l3/kms/main/analytics.duckdb"},
    {"data/holons/knowledge.sqlite", "ex:l3:kms:srv:main:vectors", "data/holons/ex/l3/kms/main/vectors.sqlite"}
  ]

  def run(args) do
    dry_run = "--dry-run" in args
    execute = "--execute" in args

    IO.puts("""
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║              HOLON DATABASE PATH MIGRATION SCRIPT                          ║
    ║                        UHI Naming System v1.0                              ║
    ╠═══════════════════════════════════════════════════════════════════════════╣
    ║  Mode: #{if execute, do: "EXECUTE", else: "DRY RUN (no changes)"}                                               ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    """)

    results = Enum.map(@legacy_mappings, fn {legacy, fqdn, new_path} ->
      migrate_database(legacy, fqdn, new_path, dry_run: !execute)
    end)

    print_summary(results, execute)
  end

  defp migrate_database(legacy_path, fqdn, new_path, opts) do
    dry_run = Keyword.get(opts, :dry_run, true)
    legacy_exists = File.exists?(legacy_path)
    new_exists = File.exists?(new_path)

    status = cond do
      not legacy_exists and not new_exists -> :not_found
      not legacy_exists and new_exists -> :already_migrated
      legacy_exists and new_exists -> :conflict
      legacy_exists and not new_exists -> :ready
    end

    result = %{
      legacy_path: legacy_path,
      fqdn: fqdn,
      new_path: new_path,
      legacy_exists: legacy_exists,
      new_exists: new_exists,
      status: status,
      migrated: false,
      error: nil
    }

    if dry_run do
      print_migration_plan(result)
      result
    else
      execute_migration(result)
    end
  end

  defp print_migration_plan(result) do
    status_icon = case result.status do
      :not_found -> "⚪"
      :already_migrated -> "✅"
      :conflict -> "⚠️"
      :ready -> "🔄"
    end

    IO.puts("#{status_icon} #{result.legacy_path}")
    IO.puts("   FQDN: #{result.fqdn}")
    IO.puts("   → #{result.new_path}")
    IO.puts("   Status: #{result.status}")
    IO.puts("")
  end

  defp execute_migration(result) do
    case result.status do
      :ready ->
        # Create target directory
        new_dir = Path.dirname(result.new_path)
        File.mkdir_p!(new_dir)

        # Copy file (preserve original as backup)
        case File.copy(result.legacy_path, result.new_path) do
          {:ok, _} ->
            IO.puts("✅ Migrated: #{result.legacy_path} → #{result.new_path}")

            # Create manifest for the holon
            create_manifest(result)

            %{result | migrated: true}

          {:error, reason} ->
            IO.puts("❌ Failed: #{result.legacy_path} - #{inspect(reason)}")
            %{result | error: reason}
        end

      :already_migrated ->
        IO.puts("⏭️  Skipped (already migrated): #{result.legacy_path}")
        result

      :conflict ->
        IO.puts("⚠️  Conflict: Both paths exist - #{result.legacy_path}")
        result

      :not_found ->
        IO.puts("⚪ Not found: #{result.legacy_path}")
        result
    end
  end

  defp create_manifest(result) do
    holon_dir = Path.dirname(result.new_path)
    manifest_path = Path.join(holon_dir, "manifest.json")

    unless File.exists?(manifest_path) do
      manifest = %{
        "$schema" => "https://indrajaal.dev/schemas/holon-manifest-v1.json",
        "version" => "1.0.0",
        "uhi" => extract_uhi(result.fqdn),
        "fqdn" => result.fqdn,
        "migrated_from" => result.legacy_path,
        "migrated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "databases" => %{
          Path.basename(result.new_path) => %{
            "type" => get_db_type(result.new_path),
            "migrated" => true
          }
        }
      }

      File.write!(manifest_path, Jason.encode!(manifest, pretty: true))
      IO.puts("   📋 Created manifest: #{manifest_path}")
    end
  end

  defp extract_uhi(fqdn) do
    # Remove database type suffix to get UHI
    parts = String.split(fqdn, ":")
    parts |> Enum.take(5) |> Enum.join(":")
  end

  defp get_db_type(path) do
    cond do
      String.ends_with?(path, ".sqlite") -> "sqlite"
      String.ends_with?(path, ".duckdb") -> "duckdb"
      String.ends_with?(path, ".db") -> "sqlite"
      true -> "unknown"
    end
  end

  defp print_summary(results, execute) do
    ready = Enum.count(results, &(&1.status == :ready))
    migrated = Enum.count(results, &(&1.migrated == true))
    already = Enum.count(results, &(&1.status == :already_migrated))
    conflicts = Enum.count(results, &(&1.status == :conflict))
    not_found = Enum.count(results, &(&1.status == :not_found))
    errors = Enum.count(results, &(&1.error != nil))

    IO.puts("""

    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                           MIGRATION SUMMARY                                ║
    ╠═══════════════════════════════════════════════════════════════════════════╣
    ║  Total mappings:     #{String.pad_leading("#{length(results)}", 4)}                                            ║
    ║  Ready to migrate:   #{String.pad_leading("#{ready}", 4)}                                            ║
    ║  Already migrated:   #{String.pad_leading("#{already}", 4)}                                            ║
    ║  Conflicts:          #{String.pad_leading("#{conflicts}", 4)}                                            ║
    ║  Not found:          #{String.pad_leading("#{not_found}", 4)}                                            ║
    #{if execute do "║  Successfully migrated: #{String.pad_leading("#{migrated}", 4)}                                         ║\n║  Errors:             #{String.pad_leading("#{errors}", 4)}                                            ║" else "" end}
    ╚═══════════════════════════════════════════════════════════════════════════╝
    """)

    if not execute and ready > 0 do
      IO.puts("""
      To execute the migration, run:
        elixir scripts/migration/migrate_database_paths.exs --execute
      """)
    end

    if conflicts > 0 do
      IO.puts("""
      ⚠️  WARNING: #{conflicts} conflict(s) detected.
      Both legacy and new paths exist. Manual resolution required.
      """)
    end
  end
end

# Run the migration
DatabasePathMigration.run(System.argv())
