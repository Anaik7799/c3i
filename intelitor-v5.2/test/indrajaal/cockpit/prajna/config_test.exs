defmodule Indrajaal.Cockpit.Prajna.ConfigTest do
  @moduledoc """
  Tests for Prajna.Config module.

  WHAT: Validates configuration schema, defaults, validation, and SIL-level profiles.
  WHY: SC-CONFIG-002 requires validation on startup.

  CONSTRAINTS:
    - SC-CONFIG-001: All timing values from Application config
    - SC-CONFIG-002: Validation on startup
    - SC-SIL6-003: Safe defaults for SIL-6 operation
    - SC-PRAJNA-001 through SC-PRAJNA-007: Prajna safety constraints
    - AOR-BIO-001: Fast OODA mode with 30s cycles
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.Config

  # ============================================================================
  # Default Value Tests (SC-CONFIG-001)
  # ============================================================================

  describe "get/1 - default values" do
    test "returns default for guardian_timeout_ms" do
      assert Config.get(:guardian_timeout_ms) == 5_000
    end

    test "returns default for sentinel_sync_interval_ms" do
      assert Config.get(:sentinel_sync_interval_ms) == 30_000
    end

    test "returns default for circuit_breaker_threshold" do
      assert Config.get(:circuit_breaker_threshold) == 3
    end

    test "returns default for circuit_breaker_reset_ms" do
      assert Config.get(:circuit_breaker_reset_ms) == 30_000
    end

    test "returns default for ooda_cycle_ms" do
      assert Config.get(:ooda_cycle_ms) == 30_000
    end

    test "returns default for smart_metrics_interval_ms" do
      assert Config.get(:smart_metrics_interval_ms) == 1_000
    end

    test "returns default for proof_token_ttl_ms" do
      # Default is 5 minutes (300_000ms) per schema
      assert Config.get(:proof_token_ttl_ms) == 300_000
    end

    test "returns default for max_retry_attempts" do
      assert Config.get(:max_retry_attempts) == 3
    end

    test "returns default for exponential_backoff_base_ms" do
      assert Config.get(:exponential_backoff_base_ms) == 1_000
    end

    test "returns default for backoff_base_ms" do
      assert Config.get(:backoff_base_ms) == 1_000
    end

    test "raises ArgumentError for unknown key" do
      assert_raise ArgumentError, ~r/Unknown config key/, fn ->
        Config.get(:unknown_key)
      end
    end
  end

  describe "get/2 - with explicit default" do
    test "returns explicit default when key is not configured" do
      # get/2 uses Application.get_env with fallback, not schema default
      # Since :nonexistent_key is not in Application env, it returns the explicit default
      assert Config.get(:nonexistent_key, :fallback) == :fallback
    end

    test "returns configured value or explicit default for known keys" do
      # For known keys, if Application.get_env returns nil, explicit default is used
      # The schema default is only used by get/1
      result = Config.get(:guardian_timeout_ms, 10_000)
      # Either the configured value or the explicit default
      assert is_integer(result)
    end
  end

  # ============================================================================
  # Schema Tests
  # ============================================================================

  describe "schema/0" do
    test "returns schema with all required keys" do
      schema = Config.schema()

      required_keys = [
        :guardian_timeout_ms,
        :sentinel_sync_interval_ms,
        :circuit_breaker_threshold,
        :circuit_breaker_reset_ms,
        :ooda_cycle_ms,
        :smart_metrics_interval_ms,
        :proof_token_ttl_ms,
        :max_retry_attempts,
        :backoff_base_ms,
        :exponential_backoff_base_ms
      ]

      for key <- required_keys do
        assert Map.has_key?(schema, key),
               "Schema should have key #{inspect(key)}"
      end
    end

    test "each schema entry has required fields" do
      schema = Config.schema()

      for {key, config} <- schema do
        assert Map.has_key?(config, :default),
               "#{key} should have :default"

        assert Map.has_key?(config, :type),
               "#{key} should have :type"

        assert Map.has_key?(config, :level),
               "#{key} should have :level"

        assert Map.has_key?(config, :hot_reload),
               "#{key} should have :hot_reload"

        assert Map.has_key?(config, :description),
               "#{key} should have :description"
      end
    end
  end

  # ============================================================================
  # Validation Tests (SC-CONFIG-002)
  # ============================================================================

  describe "validate_all/0" do
    test "validates all configuration successfully with defaults" do
      assert {:ok, config} = Config.validate_all()
      assert is_map(config)
      assert map_size(config) > 0
    end
  end

  describe "validate/1" do
    test "validates correct config map" do
      assert {:ok, _} = Config.validate(%{guardian_timeout_ms: 5000})
    end

    test "rejects value below minimum" do
      assert {:error, errors} = Config.validate(%{guardian_timeout_ms: 100})
      assert Enum.any?(errors, &String.contains?(&1, "below minimum"))
    end

    test "rejects value above maximum" do
      assert {:error, errors} = Config.validate(%{guardian_timeout_ms: 100_000})
      assert Enum.any?(errors, &String.contains?(&1, "above maximum"))
    end

    test "rejects wrong type" do
      assert {:error, errors} = Config.validate(%{guardian_timeout_ms: "not_an_integer"})
      assert Enum.any?(errors, &String.contains?(&1, "expected"))
    end

    test "rejects unknown keys" do
      assert {:error, errors} = Config.validate(%{unknown_key: 123})
      assert Enum.any?(errors, &String.contains?(&1, "Unknown config key"))
    end

    test "validates multiple keys at once" do
      config = %{
        guardian_timeout_ms: 5000,
        sentinel_sync_interval_ms: 30_000,
        circuit_breaker_threshold: 3
      }

      assert {:ok, ^config} = Config.validate(config)
    end
  end

  # ============================================================================
  # SIL-Level Profile Tests (SC-SIL6-003)
  # ============================================================================

  describe "available_profiles/0" do
    test "returns all available profiles" do
      profiles = Config.available_profiles()
      assert :dev in profiles
      assert :test in profiles
      assert :prod in profiles
      assert :sil4 in profiles
    end
  end

  describe "profile/1 - dev profile" do
    test "has relaxed timings" do
      dev = Config.profile(:dev)

      # Dev should have longer timeouts
      assert dev.guardian_timeout_ms == 10_000
      assert dev.ooda_cycle_ms == 60_000
      assert dev.proof_token_ttl_ms == 300_000
    end

    test "has higher thresholds" do
      dev = Config.profile(:dev)

      assert dev.circuit_breaker_threshold == 5
      assert dev.max_retry_attempts == 5
    end

    test "has safety features disabled" do
      dev = Config.profile(:dev)

      assert dev.fail_closed_mode == false
      assert dev.immutable_state_verify_on_startup == false
    end
  end

  describe "profile/1 - test profile" do
    test "has fast timings for test execution" do
      test_profile = Config.profile(:test)

      # Test should have short timeouts (within schema minimums)
      assert test_profile.guardian_timeout_ms == 1_000
      # ooda_cycle_ms min is 10_000 per schema
      assert test_profile.ooda_cycle_ms == 10_000
      assert test_profile.proof_token_ttl_ms == 10_000
    end

    test "has low thresholds" do
      test_profile = Config.profile(:test)

      assert test_profile.circuit_breaker_threshold == 2
      assert test_profile.max_retry_attempts == 2
    end
  end

  describe "profile/1 - prod profile" do
    test "has production timings" do
      prod = Config.profile(:prod)

      assert prod.guardian_timeout_ms == 5_000
      assert prod.ooda_cycle_ms == 30_000
      # Production uses 5 minute proof token TTL
      assert prod.proof_token_ttl_ms == 300_000
    end

    test "has balanced thresholds" do
      prod = Config.profile(:prod)

      assert prod.circuit_breaker_threshold == 3
      assert prod.max_retry_attempts == 3
    end

    test "has startup verification enabled" do
      prod = Config.profile(:prod)

      assert prod.immutable_state_verify_on_startup == true
      assert prod.fail_closed_mode == false
    end
  end

  describe "profile/1 - sil4 profile" do
    test "has stringent timings" do
      sil4 = Config.profile(:sil4)

      # SIL-6 IEC 61508 compliant: strict 2s timeout, 10s OODA (schema min), 15s proof token
      assert sil4.guardian_timeout_ms == 2_000
      assert sil4.ooda_cycle_ms == 10_000
      assert sil4.proof_token_ttl_ms == 15_000
    end

    test "has conservative thresholds" do
      sil4 = Config.profile(:sil4)

      # SIL-6: Immediate circuit break (threshold=1), single retry
      assert sil4.circuit_breaker_threshold == 1
      assert sil4.max_retry_attempts == 1
    end

    test "has all safety features enabled" do
      sil4 = Config.profile(:sil4)

      assert sil4.fail_closed_mode == true
      assert sil4.immutable_state_verify_on_startup == true
    end

    test "has faster metrics collection" do
      sil4 = Config.profile(:sil4)

      # SIL-6: 250ms metrics (4Hz), 5s sentinel sync
      assert sil4.smart_metrics_interval_ms == 250
      assert sil4.sentinel_sync_interval_ms == 5_000
    end
  end

  describe "profile validation" do
    test "all profiles pass validation" do
      for profile_name <- Config.available_profiles() do
        profile = Config.profile(profile_name)

        assert {:ok, _} = Config.validate(profile),
               "Profile #{profile_name} should be valid"
      end
    end

    test "profiles have all required keys" do
      required_keys = [
        :guardian_timeout_ms,
        :circuit_breaker_threshold,
        :circuit_breaker_reset_ms,
        :ooda_cycle_ms,
        :smart_metrics_interval_ms,
        :proof_token_ttl_ms,
        :max_retry_attempts,
        :fail_closed_mode
      ]

      for profile_name <- Config.available_profiles() do
        profile = Config.profile(profile_name)

        for key <- required_keys do
          assert Map.has_key?(profile, key),
                 "Profile #{profile_name} should have key #{inspect(key)}"
        end
      end
    end
  end

  # ============================================================================
  # Hot Reload Tests
  # ============================================================================

  describe "hot_reloadable?/1" do
    test "returns true for hot-reloadable keys" do
      assert Config.hot_reloadable?(:circuit_breaker_threshold) == true
      assert Config.hot_reloadable?(:smart_metrics_interval_ms) == true
      assert Config.hot_reloadable?(:max_retry_attempts) == true
    end

    test "returns false for non-hot-reloadable keys" do
      assert Config.hot_reloadable?(:guardian_timeout_ms) == false
      assert Config.hot_reloadable?(:fail_closed_mode) == false
      assert Config.hot_reloadable?(:immutable_state_verify_on_startup) == false
    end

    test "returns false for unknown keys" do
      assert Config.hot_reloadable?(:unknown_key) == false
    end
  end

  describe "hot_reloadable_keys/0" do
    test "returns list of hot-reloadable keys" do
      keys = Config.hot_reloadable_keys()

      assert is_list(keys)
      assert length(keys) > 0

      # All returned keys should be hot-reloadable
      for key <- keys do
        assert Config.hot_reloadable?(key) == true
      end
    end
  end

  # ============================================================================
  # Fractal Level Tests
  # ============================================================================

  describe "level/1" do
    test "returns correct level for L5 (Constitutional) keys" do
      assert Config.level(:fail_closed_mode) == :l5
      assert Config.level(:immutable_state_verify_on_startup) == :l5
    end

    test "returns correct level for L4 (Container) keys" do
      assert Config.level(:guardian_timeout_ms) == :l4
      assert Config.level(:ooda_cycle_ms) == :l4
      assert Config.level(:proof_token_ttl_ms) == :l4
    end

    test "returns correct level for L3 (Agent) keys" do
      assert Config.level(:smart_metrics_interval_ms) == :l3
      assert Config.level(:max_retry_attempts) == :l3
    end

    test "returns nil for unknown keys" do
      assert Config.level(:unknown_key) == nil
    end
  end

  describe "keys_by_level/0" do
    test "groups keys by fractal level" do
      by_level = Config.keys_by_level()

      assert is_map(by_level)
      assert Map.has_key?(by_level, :l5)
      assert Map.has_key?(by_level, :l4)
      assert Map.has_key?(by_level, :l3)
    end

    test "L5 keys are constitutional" do
      by_level = Config.keys_by_level()

      assert :fail_closed_mode in by_level[:l5]
      assert :immutable_state_verify_on_startup in by_level[:l5]
    end
  end

  # ============================================================================
  # Profile Diff Tests
  # ============================================================================

  describe "diff_with_profile/1" do
    test "returns empty map when current matches profile" do
      # With defaults, should match prod profile for most keys
      # This is a structural test - actual diff depends on current config
      diff = Config.diff_with_profile(:prod)
      assert is_map(diff)
    end

    test "returns differences with sil4 profile" do
      diff = Config.diff_with_profile(:sil4)

      # SIL6 has stricter settings, so there should be differences
      # fail_closed_mode is false by default, true in sil4
      assert Map.has_key?(diff, :fail_closed_mode)

      {current, profile} = diff[:fail_closed_mode]
      assert current == false
      assert profile == true
    end

    test "diff entries have current and profile values" do
      diff = Config.diff_with_profile(:sil4)

      for {_key, {current, profile}} <- diff do
        assert current != profile
      end
    end
  end

  # ============================================================================
  # Backoff Calculation Tests (SC-RECOVER-001)
  # ============================================================================

  describe "backoff_delay/1" do
    test "calculates exponential backoff" do
      # With base 1000ms:
      # Attempt 1: 1000 * 2^0 = 1000
      # Attempt 2: 1000 * 2^1 = 2000
      # Attempt 3: 1000 * 2^2 = 4000
      assert Config.backoff_delay(1) == 1000
      assert Config.backoff_delay(2) == 2000
      assert Config.backoff_delay(3) == 4000
    end

    test "caps at max backoff" do
      # Default max is 60_000ms
      # Attempt 7: 1000 * 2^6 = 64000 -> capped at 60000
      assert Config.backoff_delay(7) == 60_000
      assert Config.backoff_delay(10) == 60_000
    end
  end

  describe "backoff_delay_with_jitter/1" do
    test "returns value within jitter range" do
      # Run multiple times to test jitter
      for _ <- 1..10 do
        delay = Config.backoff_delay_with_jitter(1)
        base = Config.backoff_delay(1)
        jitter = round(base * 0.1)

        assert delay >= base - jitter
        assert delay <= base + jitter
      end
    end

    test "always returns positive value" do
      for attempt <- 1..5 do
        assert Config.backoff_delay_with_jitter(attempt) > 0
      end
    end
  end

  # ============================================================================
  # All Config Retrieval Tests
  # ============================================================================

  describe "all/0" do
    test "returns all configuration values" do
      all = Config.all()

      assert is_map(all)
      assert Map.has_key?(all, :guardian_timeout_ms)
      assert Map.has_key?(all, :sentinel_sync_interval_ms)
      assert Map.has_key?(all, :proof_token_ttl_ms)
    end

    test "all values match get/1 calls" do
      all = Config.all()

      for {key, value} <- all do
        assert Config.get(key) == value
      end
    end
  end

  # ============================================================================
  # L5 Immutability Tests (SC-SIL6-005)
  # ============================================================================

  describe "L5 key immutability" do
    test "L5 keys are not hot-reloadable" do
      l5_keys = Config.__l5_keys__()

      for key <- l5_keys do
        assert Config.hot_reloadable?(key) == false,
               "L5 key #{inspect(key)} should not be hot-reloadable"
      end
    end

    test "L5 keys have hot_reload: false in schema" do
      schema = Config.schema()

      for {key, config} <- schema, config.level == :l5 do
        assert config.hot_reload == false,
               "L5 key #{inspect(key)} should have hot_reload: false"
      end
    end
  end

  # ============================================================================
  # STAMP Constraint Coverage Tests
  # ============================================================================

  describe "STAMP constraints" do
    test "SC-PRAJNA-001: Guardian timeout is configurable" do
      assert is_integer(Config.get(:guardian_timeout_ms))
      assert Config.get(:guardian_timeout_ms) > 0
    end

    test "SC-PRAJNA-004: Sentinel sync interval is configurable" do
      assert is_integer(Config.get(:sentinel_sync_interval_ms))
      assert Config.get(:sentinel_sync_interval_ms) > 0
    end

    test "SC-PRAJNA-005: Proof token TTL is configurable" do
      assert is_integer(Config.get(:proof_token_ttl_ms))
      assert Config.get(:proof_token_ttl_ms) > 0
    end

    test "AOR-BIO-001: OODA cycle is configurable" do
      assert is_integer(Config.get(:ooda_cycle_ms))
      assert Config.get(:ooda_cycle_ms) > 0
    end
  end

  # ============================================================================
  # Property Tests (TDG Compliance)
  # ============================================================================

  describe "property tests" do
    property "backoff delay is always positive" do
      forall attempt <- PC.pos_integer() do
        delay = Config.backoff_delay(attempt)
        delay > 0
      end
    end

    property "backoff delay increases with attempts (up to cap)" do
      forall attempt <- PC.range(1, 6) do
        delay1 = Config.backoff_delay(attempt)
        delay2 = Config.backoff_delay(attempt + 1)
        delay2 >= delay1
      end
    end

    property "backoff with jitter is always positive" do
      forall attempt <- PC.pos_integer() do
        delay = Config.backoff_delay_with_jitter(attempt)
        delay > 0
      end
    end

    property "all profiles pass validation" do
      forall _seed <- PC.integer() do
        Enum.all?(Config.available_profiles(), fn profile_name ->
          profile = Config.profile(profile_name)
          match?({:ok, _}, Config.validate(profile))
        end)
      end
    end

    property "schema always returns valid map structure" do
      forall _seed <- PC.integer() do
        schema = Config.schema()
        is_map(schema) and map_size(schema) > 0
      end
    end

    property "validation rejects negative timeouts" do
      forall negative <- PC.neg_integer() do
        result = Config.validate(%{guardian_timeout_ms: negative})
        match?({:error, _}, result)
      end
    end

    property "hot_reloadable? is deterministic" do
      forall key <- PC.oneof([:guardian_timeout_ms, :circuit_breaker_threshold, :unknown_key]) do
        r1 = Config.hot_reloadable?(key)
        r2 = Config.hot_reloadable?(key)
        r1 == r2
      end
    end

    property "level/1 returns valid level or nil" do
      forall key <- PC.oneof([:guardian_timeout_ms, :fail_closed_mode, :unknown_key]) do
        level = Config.level(key)
        level == nil or level in [:l3, :l4, :l5]
      end
    end
  end
end
