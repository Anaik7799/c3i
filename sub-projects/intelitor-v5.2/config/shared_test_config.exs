# Shared Test Configuration
# Common test database and configuration settings
#
# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINER-ONLY DATABASE POLICY (SC-CNT-009)
# ═══════════════════════════════════════════════════════════════════════════════
#
# ALL database tests in dev environment MUST run ONLY on the container database:
#   Container: indrajaal-db (Podman)
#   Port: 5433 (mapped from container's 5432)
#   User: indrajaal
#   Password: indrajaal_dev (via environment variable)
#
# This ensures:
#   1. Consistent test environment across all developers
#   2. Isolation from any local PostgreSQL installations
#   3. STAMP compliance with container-only execution (SC-CNT-009)
#   4. Reproducible test results
#
# To run tests:
#   POSTGRES_USER=indrajaal POSTGRES_PASSWORD=indrajaal_dev MIX_ENV=test mix test
#
# ═══════════════════════════════════════════════════════════════════════════════

defmodule SharedTestConfig do
  @moduledoc """
  Shared database configuration for test environments.

  CONTAINER-ONLY POLICY: All database tests run exclusively on the
  indrajaal-db Podman container (port 5433). This is enforced by
  STAMP safety constraint SC-CNT-009.
  """

  @container_port 5433

  def database_config do
    # Use DATABASE_URL if set (for container environments), otherwise fall back to defaults
    case System.get_env("DATABASE_URL") do
      nil ->
        # Local development - connect to localhost
        [
          username: System.get_env("POSTGRES_USER", "indrajaal"),
          password: System.get_env("POSTGRES_PASSWORD", "indrajaal_dev"),
          hostname: "localhost",
          # CRITICAL: Port 5433 is the container database
          # DO NOT change to 5432 (local PostgreSQL)
          port: @container_port,
          database: "indrajaal_test#{System.get_env("MIX_TEST_PARTITION")}",
          pool: Ecto.Adapters.SQL.Sandbox,
          pool_size: System.schedulers_online() * 2
        ]

      url ->
        # Container environment - parse DATABASE_URL
        uri = URI.parse(url)
        [username, password] = String.split(uri.userinfo || "indrajaal:indrajaal_test", ":")

        [
          username: username,
          password: password,
          hostname: uri.host || "localhost",
          port: uri.port || @container_port,
          database:
            String.trim_leading(uri.path || "/indrajaal_test", "/") <>
              "#{System.get_env("MIX_TEST_PARTITION")}",
          pool: Ecto.Adapters.SQL.Sandbox,
          pool_size: System.schedulers_online() * 2
        ]
    end
  end

  def common_test_config do
    [
      # Add other common test configurations here
      show_sensitive_data_on_connection_error: true,
      stacktrace_depth: 20
    ]
  end

  @doc """
  Validates that the database connection is to the container.
  Returns :ok if connected to port 5433, raises otherwise.
  """
  def validate_container_database! do
    config = database_config()

    if config[:port] != @container_port do
      raise """
      CONTAINER-ONLY VIOLATION (SC-CNT-009)

      Database tests must run ONLY on the container database (port #{@container_port}).
      Current configuration points to port #{config[:port]}.

      Ensure the indrajaal-db container is running:
        podman ps | grep indrajaal-db
      """
    end

    :ok
  end
end
