defmodule Mix.Tasks.AshMigrationHelper do
  @moduledoc """
  Utility task for managing Ash PostgreSQL migrations with improved error
    handling.

  TPS Analysis Applied:
  - Jidoka: Stop and fix migration issues systematically
  - Just - in - Time: Generate migrations only when needed
  - Continuous Improvement: Provide better feedback and error handling
  - Respect for People: Clear error messages and guidance

  ## Usage

      mix ash_migration_helper.generate [name]
      mix ash_migration_helper.check
      mix ash_migration_helper.status
  """

  use Mix.Task

  @shortdoc "Helper for managing Ash PostgreSQL migrations"

  @spec run(any()) :: any()
  def run(["generate" | args]) do
    name =
      case args do
        [provided_name] ->
          provided_name

        [] ->
          generate_migration_name()

        _ ->
          Mix.shell().error("Usage: mix ash_migration_helper.generate [name]")
          exit(1)
      end

    IO.puts("[FIX] Generating Ash migrations: #{name}")

    case Mix.Task.run("ash_postgres.generate_migrations", [name]) do
      :ok ->
        IO.puts("✅ Migration generated successfully: #{name}")
        :ok

      {:error, reason} ->
        IO.puts("❌ Migration generation failed: #{inspect(reason)}")
        provide_troubleshooting_guidance()
        {:error, reason}

      _ ->
        IO.puts("⚠️  No new migrations needed")
        :ok
    end
  end

  @spec run(any()) :: any()
  def run(["check"]) do
    IO.puts("🔍 Checking for migration drift...")

    case Mix.Task.run("ash_postgres.generate_migrations", ["--check"]) do
      :ok ->
        IO.puts("✅ No migration drift detected")

      _ ->
        IO.puts("⚠️  Migration drift detected - resources may need updates")
        IO.puts("💡 Run: mix ash_migration_helper.generate <name> to create missing migrations")
    end
  end

  @spec run(any()) :: any()
  def run(["status"]) do
    IO.puts("[STATS] Ash Migration Status Report")
    IO.puts("=" |> String.duplicate(40))

    # Check existing migrations
    migration_count = count_existing_migrations()
    IO.puts("📁 Existing migrations: #{migration_count}")

    # Check for drift
    case Mix.Task.run("ash_postgres.generate_migrations", ["--dry - run"]) do
      :ok ->
        IO.puts("✅ No migration drift")

      _ ->
        IO.puts("⚠️  Migration drift detected")
    end

    # Check __database status
    check_database_status()

    IO.puts("

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n[FIX] Available commands:")
    IO.puts("  mix ash_migration_helper.generate <name>  - Generate new migrations")
    IO.puts("  mix ash_migration_helper.check            - Check for drift")
    IO.puts("  mix ash_migration_helper.status           - Show this status")
  end

  @spec run(any()) :: any()
  def run([]) do
    run(["status"])
  end

  @spec run(any()) :: any()
  def run(_args) do
    IO.puts("""
    Ash Migration Helper - TPS - Based Migration Management

    Usage:
      mix ash_migration_helper.generate [name]  - Generate migrations with
        optional name
      mix ash_migration_helper.check            - Check for migration drift
      mix ash_migration_helper.status           - Show migration status

    Examples:
      mix ash_migration_helper.generate __user_updates
      mix ash_migration_helper.check
      mix ash_migration_helper.status
    """)
  end

  @spec generate_migration_name() :: any()
  defp generate_migration_name do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "ash_migration_#{timestamp}"
  end

  @spec count_existing_migrations() :: any()
  def count_existing_migrations() do
    case File.ls("priv / repo / migrations") do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".exs"))
        |> length()

      {:error, _} ->
        0
    end
  end

  @spec check_database_status() :: any()
  def check_database_status() do
    case System.cmd(
           "psql",
           [
             "-h",
             "localhost",
             "-p",
             "5433",
             "-U",
             "postgres",
             "-d",
             "indrajaal_dev",
             "-c",
             "SELECT 1;",
             "-t"
           ],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        IO.puts("✅ Database connection: OK")

      {error, _} ->
        IO.puts("❌ Database connection: FAILED")
        IO.puts("   #{String.trim(error)}")
        IO.puts("💡 Make sure PostgreSQL is running: devenv shell")
    end
  end

  @spec provide_troubleshooting_guidance() :: any()
  defp provide_troubleshooting_guidance do
    IO.puts("""

    🚨 Migration Generation Failed - TPS Troubleshooting Guide
    =========================================================

    Common Causes & Solutions:

    1. 📋 Resource Definition Issues:
       - Check for syntax errors in resource files
       - Verify all attributes have proper types
       - Ensure relationships are correctly defined

    2. [FIX] Database Connection Issues:
       - Verify PostgreSQL is running: pg_isready -h localhost -p 5433
       - Check __database exists: psql -h localhost -p 5433 -U postgres -d
         indrajaal_dev -c "SELECT 1;"
       - Recreate if needed: dropdb / createdb with UTF8 encoding

    3. ⚠️  Complex Default Values:
       - The warnings about EctoMigrationDefault are normal for complex types
       - Migrations will use nil defaults and can be manually edited
       - Default values are applied at the application level

    4. 🔄 Recovery Steps:
       - Run: mix ash_migration_helper.check
       - Try: mix ash_postgres.generate_migrations --dev
       - Manual: Edit generated migrations to fix default values

    💡 For more help: Check CLAUDE.md migration troubleshooting section
    """)
  end
end
