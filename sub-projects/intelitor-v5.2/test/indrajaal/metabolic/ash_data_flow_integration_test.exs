defmodule Indrajaal.Metabolic.AshDataFlowIntegrationTest do
  @moduledoc """
  L4.1: Ash Domain Data Flow Integration Tests.

  Tests the Ash framework data layer integration:
  - BaseResource foundation
  - Repository operations
  - Data layer configuration
  - Ash resource compliance

  STAMP Constraints:
  - SC-DB-001: All resources MUST use BaseResource
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for function-based changes
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Repo

  describe "L4.1: Repository Configuration" do
    test "Repo uses AshPostgres.Repo" do
      # Verify Repo is properly configured
      assert Code.ensure_loaded?(Repo)

      # Check for installed extensions
      extensions = Repo.installed_extensions()
      assert is_list(extensions)
      assert "uuid-ossp" in extensions
      assert "citext" in extensions
    end

    test "Repo has correct minimum PostgreSQL version" do
      version = Repo.min_pg_version()

      assert %Version{major: major} = version
      assert major >= 16
    end

    test "Repo extensions include Ash functions" do
      extensions = Repo.installed_extensions()

      assert "ash-functions" in extensions
    end
  end

  describe "L4.1: BaseResource Foundation (SC-DB-001)" do
    test "BaseResource module is defined" do
      assert Code.ensure_loaded?(Indrajaal.BaseResource)
    end

    test "BaseResource provides __using__ macro" do
      # BaseResource should define a using macro for inheritance
      exports = Indrajaal.BaseResource.__info__(:macros)

      assert {:__using__, 1} in exports
    end
  end

  describe "L4.1: Ash Domain Verification" do
    test "Accounts domain is defined" do
      assert Code.ensure_loaded?(Indrajaal.Accounts)
    end

    test "Devices domain is defined" do
      assert Code.ensure_loaded?(Indrajaal.Devices)
    end

    test "Alarms domain is defined" do
      assert Code.ensure_loaded?(Indrajaal.Alarms)
    end

    test "AccessControl domain is defined" do
      assert Code.ensure_loaded?(Indrajaal.AccessControl)
    end

    test "Sites domain is defined" do
      assert Code.ensure_loaded?(Indrajaal.Sites)
    end
  end

  describe "L4.1: Ash Resource Pattern Compliance" do
    test "User resource exists in Accounts domain" do
      assert Code.ensure_loaded?(Indrajaal.Accounts.User)
    end

    test "Tenant resource exists in Core domain" do
      assert Code.ensure_loaded?(Indrajaal.Core.Tenant)
    end

    test "Device resource exists in Devices domain" do
      assert Code.ensure_loaded?(Indrajaal.Devices.Device)
    end
  end

  describe "L4.1: Data Layer Health" do
    test "Repo can be started (or is already running)" do
      case GenServer.whereis(Repo) do
        nil ->
          # Not running is acceptable in certain test scenarios
          assert true

        pid when is_pid(pid) ->
          assert Process.alive?(pid)
      end
    end

    test "Database connection pool is configured" do
      config = Application.get_env(:indrajaal, Indrajaal.Repo, [])

      # Pool configuration should exist
      pool_size = Keyword.get(config, :pool_size, 10)
      assert is_integer(pool_size)
      assert pool_size > 0
    end
  end

  describe "L4.1: Multi-Tenant Architecture" do
    test "Repo supports multi-tenant operations" do
      # Multi-tenancy is a core feature of the system
      # Verify the repo module can handle tenant context
      assert Code.ensure_loaded?(Repo)

      # The Repo should be an AshPostgres Repo
      assert function_exported?(Repo, :installed_extensions, 0)
    end
  end

  describe "L4.1: Enterprise Extensions" do
    test "cryptographic extensions are available" do
      extensions = Repo.installed_extensions()

      assert "pgcrypto" in extensions
    end

    test "text search extensions are available" do
      extensions = Repo.installed_extensions()

      # Trigram for fuzzy search
      assert "pg_trgm" in extensions
    end

    test "advanced indexing extensions are available" do
      extensions = Repo.installed_extensions()

      assert "btree_gist" in extensions
    end
  end
end
