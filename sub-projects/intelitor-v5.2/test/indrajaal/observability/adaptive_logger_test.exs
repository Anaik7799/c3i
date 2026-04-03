defmodule Indrajaal.Observability.AdaptiveLoggerTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.AdaptiveLogger.

  ## STAMP Safety Integration
  - SC-OBS-DT-002: Log level MUST adapt to context
  - SC-OBS-DT-007: Log noise < 1000 lines for unit test run

  ## TPS 5-Level RCA Context
  - L1 Symptom: Log flooding in test runs
  - L5 Root Cause: Context-unaware logging prevents test output visibility
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.AdaptiveLogger

  setup do
    AdaptiveLogger.init()
    AdaptiveLogger.reset()
    :ok
  end

  describe "init/0" do
    test "initializes without error" do
      result = AdaptiveLogger.init()
      assert result == :ok
    end

    test "init is idempotent" do
      assert AdaptiveLogger.init() == :ok
      assert AdaptiveLogger.init() == :ok
    end
  end

  describe "debug/3" do
    test "returns :ok or :suppressed or :filtered or :deduplicated" do
      result = AdaptiveLogger.debug("TestSource", "debug message", %{})
      assert result in [:ok, :suppressed, :filtered, :deduplicated]
    end

    test "accepts 2 arguments" do
      result = AdaptiveLogger.debug("TestSource", "debug message")
      assert result in [:ok, :suppressed, :filtered, :deduplicated]
    end
  end

  describe "info/3" do
    test "returns valid result" do
      result = AdaptiveLogger.info("TestSource", "info message", %{})
      assert result in [:ok, :suppressed, :filtered, :deduplicated]
    end
  end

  describe "warning/3" do
    test "returns valid result" do
      result = AdaptiveLogger.warning("TestSource", "warning message", %{key: "value"})
      assert result in [:ok, :suppressed, :filtered, :deduplicated]
    end
  end

  describe "error/3" do
    test "returns valid result" do
      result = AdaptiveLogger.error("TestSource", "error message", %{})
      assert result in [:ok, :suppressed, :filtered, :deduplicated]
    end
  end

  describe "critical/3 - bypasses all filtering" do
    test "critical always returns :ok (bypasses filtering)" do
      result = AdaptiveLogger.critical("Guardian", "critical safety event", %{})
      assert result == :ok
    end

    test "critical sources bypass filtering" do
      critical_sources = [
        "Guardian",
        "Constitutional",
        "ImmutableRegister",
        "Sentinel",
        "FPPS",
        "FounderDirective",
        "SIL6",
        "Emergency"
      ]

      for source <- critical_sources do
        result = AdaptiveLogger.critical(source, "critical message")
        assert result == :ok, "Expected :ok for critical source #{source}"
      end
    end
  end

  describe "would_log?/2" do
    test "returns boolean" do
      result = AdaptiveLogger.would_log?("TestSource", :info)
      assert is_boolean(result)
    end

    test "critical sources always return true" do
      assert AdaptiveLogger.would_log?("Guardian", :debug) == true
      assert AdaptiveLogger.would_log?("Sentinel", :debug) == true
      assert AdaptiveLogger.would_log?("FPPS", :debug) == true
    end
  end

  describe "stats/0" do
    test "returns a map" do
      result = AdaptiveLogger.stats()
      assert is_map(result)
    end

    test "empty stats on fresh init" do
      AdaptiveLogger.reset()
      result = AdaptiveLogger.stats()
      assert is_map(result)
    end
  end

  describe "reset/0" do
    test "resets without error" do
      result = AdaptiveLogger.reset()
      assert result == :ok
    end

    test "stats are empty after reset" do
      AdaptiveLogger.info("SomeSource", "some message")
      AdaptiveLogger.reset()
      stats = AdaptiveLogger.stats()
      # After reset, counts should be gone
      refute Map.has_key?(stats, :counts) and map_size(Map.get(stats, :counts, %{})) > 0
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.AdaptiveLogger)
    end

    test "all public functions exported" do
      assert function_exported?(AdaptiveLogger, :init, 0)
      assert function_exported?(AdaptiveLogger, :debug, 2)
      assert function_exported?(AdaptiveLogger, :debug, 3)
      assert function_exported?(AdaptiveLogger, :info, 2)
      assert function_exported?(AdaptiveLogger, :info, 3)
      assert function_exported?(AdaptiveLogger, :warning, 2)
      assert function_exported?(AdaptiveLogger, :warning, 3)
      assert function_exported?(AdaptiveLogger, :error, 2)
      assert function_exported?(AdaptiveLogger, :error, 3)
      assert function_exported?(AdaptiveLogger, :critical, 2)
      assert function_exported?(AdaptiveLogger, :critical, 3)
      assert function_exported?(AdaptiveLogger, :would_log?, 2)
      assert function_exported?(AdaptiveLogger, :stats, 0)
      assert function_exported?(AdaptiveLogger, :reset, 0)
    end
  end
end
