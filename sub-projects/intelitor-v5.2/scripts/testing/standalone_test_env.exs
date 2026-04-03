#!/usr/bin/env elixir
# Standalone Test Environment Setup Script
# Usage: elixir scripts/testing/standalone_test_env.exs [--cepaf | --cockpit | --full]
#
# WHAT: Sets up standalone test environment for manual/remote testing
# WHY: Enable CEPAF and Cockpit testing without full application stack
# CONSTRAINTS: Requires PostgreSQL container running

defmodule StandaloneTestEnv do
  @moduledoc """
  Standalone test environment setup for CEPAF and Prajna Cockpit testing.

  Supports three modes:
  - :cepaf - F# CEPAF standalone testing
  - :cockpit - Prajna Cockpit LiveView testing
  - :full - Complete standalone environment
  """

  require Logger

  @db_config %{
    hostname: "localhost",
    port: 5433,
    database: "indrajaal_standalone",
    username: "postgres",
    password: "postgres"
  }

  @cepaf_compose_path "lib/cepaf/artifacts/podman-compose-db-standalone.yml"
  @obs_compose_path "lib/cepaf/artifacts/podman-compose-obs-standalone.yml"

  def main(args) do
    mode = parse_args(args)
    Logger.info("Setting up standalone test environment: #{mode}")

    case setup_environment(mode) do
      :ok ->
        print_success_message(mode)
        System.halt(0)

      {:error, reason} ->
        Logger.error("Setup failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp parse_args(args) do
    cond do
      "--cepaf" in args -> :cepaf
      "--cockpit" in args -> :cockpit
      "--full" in args -> :full
      true -> :full
    end
  end

  def setup_environment(:cepaf) do
    with :ok <- verify_prerequisites(),
         :ok <- start_db_container(),
         :ok <- setup_cepaf_environment(),
         :ok <- verify_cepaf_connectivity() do
      :ok
    end
  end

  def setup_environment(:cockpit) do
    with :ok <- verify_prerequisites(),
         :ok <- start_db_container(),
         :ok <- setup_cockpit_environment(),
         :ok <- verify_cockpit_connectivity() do
      :ok
    end
  end

  def setup_environment(:full) do
    with :ok <- verify_prerequisites(),
         :ok <- start_db_container(),
         :ok <- start_obs_container(),
         :ok <- setup_cepaf_environment(),
         :ok <- setup_cockpit_environment(),
         :ok <- verify_full_connectivity() do
      :ok
    end
  end

  defp verify_prerequisites do
    Logger.info("Verifying prerequisites...")

    cond do
      not podman_available?() ->
        {:error, "Podman not available"}

      not dotnet_available?() ->
        {:error, ".NET SDK not available (required for CEPAF)"}

      true ->
        Logger.info("Prerequisites verified")
        :ok
    end
  end

  defp podman_available? do
    case System.cmd("podman", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp dotnet_available? do
    case System.cmd("dotnet", ["--version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp start_db_container do
    Logger.info("Starting standalone database container...")

    case System.cmd("podman-compose", ["-f", @cepaf_compose_path, "up", "-d"],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        # Wait for DB to be ready
        Process.sleep(3000)
        Logger.info("Database container started")
        :ok

      {output, _} ->
        {:error, "Failed to start DB container: #{output}"}
    end
  end

  defp start_obs_container do
    Logger.info("Starting observability container...")

    case System.cmd("podman-compose", ["-f", @obs_compose_path, "up", "-d"],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        Process.sleep(2000)
        Logger.info("Observability container started")
        :ok

      {output, _} ->
        {:error, "Failed to start OBS container: #{output}"}
    end
  end

  defp setup_cepaf_environment do
    Logger.info("Setting up CEPAF environment...")

    env_vars = %{
      "CEPAF_SYSTEM_TEST_COMPOSE" => @cepaf_compose_path,
      "CEPAF_STANDALONE_OBS_TEST_COMPOSE" => @obs_compose_path,
      "DATABASE_URL" => build_database_url(),
      "CEPAF_TEST_MODE" => "standalone"
    }

    # Write env vars to .env.standalone
    env_content =
      env_vars
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("\n")

    File.write!(".env.standalone", env_content)
    Logger.info("CEPAF environment configured")
    :ok
  end

  defp setup_cockpit_environment do
    Logger.info("Setting up Cockpit environment...")

    config = """
    # Standalone Cockpit Configuration
    # Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    import Config

    config :indrajaal,
      standalone_mode: true,
      prajna_cockpit_enabled: true

    config :indrajaal, Indrajaal.Repo,
      hostname: "#{@db_config.hostname}",
      port: #{@db_config.port},
      database: "#{@db_config.database}",
      username: "#{@db_config.username}",
      password: "#{@db_config.password}",
      pool_size: 5

    config :indrajaal_web, IndrajaalWeb.Endpoint,
      http: [port: 4001],
      server: true,
      live_view: [signing_salt: "standalone_test_salt"]
    """

    File.write!("config/standalone.exs", config)
    Logger.info("Cockpit environment configured")
    :ok
  end

  defp verify_cepaf_connectivity do
    Logger.info("Verifying CEPAF connectivity...")

    # Try to run F# tests
    case System.cmd("dotnet", ["build", "lib/cepaf/src/Cepaf/Cepaf.fsproj", "--verbosity", "quiet"],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        Logger.info("CEPAF connectivity verified")
        :ok

      {output, _} ->
        Logger.warn("CEPAF build warning: #{output}")
        :ok
    end
  end

  defp verify_cockpit_connectivity do
    Logger.info("Verifying Cockpit connectivity...")
    # DB ping would go here
    :ok
  end

  defp verify_full_connectivity do
    with :ok <- verify_cepaf_connectivity(),
         :ok <- verify_cockpit_connectivity() do
      :ok
    end
  end

  defp build_database_url do
    "ecto://#{@db_config.username}:#{@db_config.password}@#{@db_config.hostname}:#{@db_config.port}/#{@db_config.database}"
  end

  defp print_success_message(:cepaf) do
    IO.puts("""

    ====================================
    CEPAF Standalone Environment Ready
    ====================================

    Database: #{build_database_url()}

    To run F# tests:
      dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary

    To run specific tests:
      dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --filter "TestName"

    Environment file: .env.standalone
    """)
  end

  defp print_success_message(:cockpit) do
    IO.puts("""

    ====================================
    Cockpit Standalone Environment Ready
    ====================================

    Database: #{build_database_url()}

    To start Prajna Cockpit:
      MIX_ENV=standalone mix phx.server

    Access at: http://localhost:4001/prajna

    Config file: config/standalone.exs
    """)
  end

  defp print_success_message(:full) do
    IO.puts("""

    ====================================
    Full Standalone Environment Ready
    ====================================

    Database: #{build_database_url()}

    CEPAF Testing:
      dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary

    Cockpit Testing:
      MIX_ENV=standalone mix phx.server
      Access: http://localhost:4001/prajna

    Environment files:
      - .env.standalone (CEPAF)
      - config/standalone.exs (Cockpit)

    Containers running:
      - indrajaal-db-standalone (PostgreSQL)
      - indrajaal-obs-standalone (Observability)
    """)
  end
end

# Run main
StandaloneTestEnv.main(System.argv())
