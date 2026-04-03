defmodule Indrajaal.Shared.ConfigHelpersTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.ConfigHelpers module.

  Tests standardized configuration patterns for:
  - logger_config function
  - __database_config function
  - endpoint_config function

  Created: 2025-11-27 16:30:00 CEST
  Phase: 3.0 - C2 High-Impact Testing (Configuration Systems)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.ConfigHelpers

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "ConfigHelpers module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.ConfigHelpers)
    end

    test "module exports logger_config function" do
      functions = Indrajaal.Shared.ConfigHelpers.__info__(:functions)
      assert {:logger_config, 1} in functions
    end

    test "module exports __database_config function" do
      functions = Indrajaal.Shared.ConfigHelpers.__info__(:functions)
      assert {:__database_config, 1} in functions
    end

    test "module exports endpoint_config function" do
      functions = Indrajaal.Shared.ConfigHelpers.__info__(:functions)
      assert {:endpoint_config, 0} in functions
    end
  end

  # ============================================================================
  # LOGGER_CONFIG TESTS
  # ============================================================================

  describe "logger_config/1" do
    test "returns keyword list with default level :info" do
      result = ConfigHelpers.logger_config()

      assert is_list(result)
      assert Keyword.keyword?(result)
      assert Keyword.get(result, :level) == :info
    end

    test "returns keyword list with custom level" do
      result = ConfigHelpers.logger_config(:debug)

      assert Keyword.get(result, :level) == :debug
    end

    test "includes backends configuration" do
      result = ConfigHelpers.logger_config()

      assert Keyword.has_key?(result, :backends)
      backends = Keyword.get(result, :backends)
      assert :console in backends
    end

    test "includes compile_time_purge_matching" do
      result = ConfigHelpers.logger_config()

      assert Keyword.has_key?(result, :compile_time_purge_matching)
    end

    test "accepts warning level" do
      result = ConfigHelpers.logger_config(:warning)

      assert Keyword.get(result, :level) == :warning
    end

    test "accepts error level" do
      result = ConfigHelpers.logger_config(:error)

      assert Keyword.get(result, :level) == :error
    end
  end

  # ============================================================================
  # __DATABASE_CONFIG TESTS
  # ============================================================================

  describe "__database_config/1" do
    test "returns map with database configuration" do
      result = ConfigHelpers.__database_config(:dev)

      assert is_map(result)
    end

    test "includes hostname key" do
      result = ConfigHelpers.__database_config(:test)

      assert Map.has_key?(result, :hostname)
    end

    test "includes password key" do
      result = ConfigHelpers.__database_config(:prod)

      assert Map.has_key?(result, :password)
    end

    test "includes port key" do
      result = ConfigHelpers.__database_config(:dev)

      assert Map.has_key?(result, :port)
      assert is_integer(result.port)
    end

    test "generates database name based on environment" do
      result = ConfigHelpers.__database_config(:test)

      # Should have __database key with environment suffix
      assert Map.has_key?(result, :__database)
      assert String.contains?(result.__database, "test")
    end

    test "uses default values when env vars not set" do
      result = ConfigHelpers.__database_config(:dev)

      # Defaults should be applied
      assert result.hostname != nil
      assert result.password != nil
    end
  end

  # ============================================================================
  # ENDPOINT_CONFIG TESTS
  # ============================================================================

  describe "endpoint_config/0" do
    test "returns keyword list" do
      result = ConfigHelpers.endpoint_config()

      assert is_list(result)
      assert Keyword.keyword?(result)
    end

    test "includes http configuration" do
      result = ConfigHelpers.endpoint_config()

      assert Keyword.has_key?(result, :http)
    end

    test "http config has ip tuple" do
      result = ConfigHelpers.endpoint_config()

      http_config = Keyword.get(result, :http)
      assert is_list(http_config)
      assert Keyword.has_key?(http_config, :ip)
      assert is_tuple(Keyword.get(http_config, :ip))
    end

    test "http config has port" do
      result = ConfigHelpers.endpoint_config()

      http_config = Keyword.get(result, :http)
      assert Keyword.get(http_config, :port) == 4000
    end

    test "includes render_errors configuration" do
      result = ConfigHelpers.endpoint_config()

      assert Keyword.has_key?(result, :render_errors)
    end

    test "includes pubsub_server configuration" do
      result = ConfigHelpers.endpoint_config()

      assert Keyword.has_key?(result, :pubsub_server)
      assert Keyword.get(result, :pubsub_server) == Indrajaal.PubSub
    end

    test "includes live_view configuration" do
      result = ConfigHelpers.endpoint_config()

      assert Keyword.has_key?(result, :live_view)
      live_view_config = Keyword.get(result, :live_view)
      assert Keyword.has_key?(live_view_config, :signing_salt)
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "logger_config always returns keyword list" do
      forall level <- PC.oneof([:debug, :info, :warning, :error]) do
        result = ConfigHelpers.logger_config(level)
        is_list(result) and Keyword.keyword?(result)
      end
    end

    property "logger_config always includes level" do
      forall level <- PC.oneof([:debug, :info, :warning, :error]) do
        result = ConfigHelpers.logger_config(level)
        Keyword.get(result, :level) == level
      end
    end

    property "__database_config always returns map with required keys" do
      forall env <- PC.oneof([:dev, :test, :prod]) do
        result = ConfigHelpers.__database_config(env)

        is_map(result) and
          Map.has_key?(result, :hostname) and
          Map.has_key?(result, :password) and
          Map.has_key?(result, :port)
      end
    end

    property "__database_config port is always integer" do
      forall env <- PC.oneof([:dev, :test, :prod]) do
        result = ConfigHelpers.__database_config(env)
        is_integer(result.port)
      end
    end

    property "endpoint_config is deterministic" do
      forall _ <- PC.integer() do
        result1 = ConfigHelpers.endpoint_config()
        result2 = ConfigHelpers.endpoint_config()
        result1 == result2
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "logger_config with nil level uses default" do
      # Should handle nil gracefully or use default
      result = ConfigHelpers.logger_config(nil)
      assert is_list(result)
    end

    test "module info returns expected structure" do
      info = ConfigHelpers.__info__(:module)
      assert info == Indrajaal.Shared.ConfigHelpers
    end

    test "module has compile time information" do
      compile_info = ConfigHelpers.__info__(:compile)
      assert is_list(compile_info)
    end

    test "endpoint_config render_errors has formats" do
      result = ConfigHelpers.endpoint_config()

      render_errors = Keyword.get(result, :render_errors)
      assert Keyword.has_key?(render_errors, :formats)
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/config_helpers.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/config_helpers.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/config_helpers.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.ConfigHelpers")
    end

    test "logger_config has @spec" do
      source = File.read!("lib/indrajaal/shared/config_helpers.ex")
      assert String.contains?(source, "@spec logger_config")
    end

    test "__database_config has @spec" do
      source = File.read!("lib/indrajaal/shared/config_helpers.ex")
      assert String.contains?(source, "@spec __database_config")
    end

    test "defines endpoint_config function" do
      source = File.read!("lib/indrajaal/shared/config_helpers.ex")
      assert String.contains?(source, "def endpoint_config")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "all configuration functions return valid structures" do
      logger = ConfigHelpers.logger_config()
      database = ConfigHelpers.__database_config(:test)
      endpoint = ConfigHelpers.endpoint_config()

      assert is_list(logger)
      assert is_map(database)
      assert is_list(endpoint)
    end

    test "configuration values are consistent types" do
      # Logger always returns keyword list
      assert Keyword.keyword?(ConfigHelpers.logger_config(:info))
      assert Keyword.keyword?(ConfigHelpers.logger_config(:debug))

      # Database always returns map
      assert is_map(ConfigHelpers.__database_config(:dev))
      assert is_map(ConfigHelpers.__database_config(:test))

      # Endpoint always returns keyword list
      assert Keyword.keyword?(ConfigHelpers.endpoint_config())
    end

    test "logger backends configuration is valid" do
      result = ConfigHelpers.logger_config()
      backends = Keyword.get(result, :backends)

      assert is_list(backends)
      assert length(backends) > 0
    end
  end
end
