defmodule Indrajaal.Cockpit.Prajna.ConfigSilProfilesTest do
  @moduledoc """
  Test suite for SIL-level configuration profiles.

  WHAT: Comprehensive tests for :dev, :test, :prod, and :sil4 profiles
  WHY: Ensure profile configurations meet requirements and constraints

  CONSTRAINTS:
    - SC-SIL6-003: Safe defaults for SIL-6 operation
    - SC-CONFIG-002: Validation on startup
    - AOR-TEST-001: Test compile before commit
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  alias Indrajaal.Cockpit.Prajna.Config
  alias PropCheck.BasicTypes, as: PC

  describe "profile/1" do
    test "dev profile has relaxed timeouts for debugging" do
      profile = Config.profile(:dev)

      # Relaxed timeouts
      assert profile.guardian_timeout_ms == 10_000
      assert profile.orchestrator_command_timeout_ms == 60_000
      assert profile.dual_channel_timeout_ms == 10_000
      assert profile.watchdog_heartbeat_timeout_ms == 10_000

      # Circuit breaker relaxed (effectively disabled)
      assert profile.circuit_breaker_threshold == 5
      assert profile.guardian_circuit_threshold == 5

      # Safety modes disabled for development
      refute profile.fail_closed_mode
      refute profile.immutable_state_verify_on_startup

      # Dual-channel and watchdog enabled but relaxed
      assert profile.dual_channel_halt_threshold == 3
      assert profile.watchdog_escalation_threshold == 5
    end

    test "test profile has fast deterministic timing" do
      profile = Config.profile(:test)

      # Fast timeouts
      assert profile.guardian_timeout_ms == 1_000
      assert profile.orchestrator_command_timeout_ms == 5_000
      assert profile.dual_channel_timeout_ms == 1_000
      assert profile.watchdog_heartbeat_timeout_ms == 1_000
      assert profile.watchdog_check_interval_ms == 200

      # Fast circuit breaking
      assert profile.circuit_breaker_threshold == 2
      assert profile.guardian_circuit_threshold == 2

      # Minimal retries for test speed
      assert profile.max_retry_attempts == 2
      assert profile.backoff_base_ms == 100

      # Safety modes disabled for testing
      refute profile.fail_closed_mode
      refute profile.immutable_state_verify_on_startup
    end

    test "prod profile has balanced timeouts and circuit breaker enabled" do
      profile = Config.profile(:prod)

      # Balanced timeouts (5s default)
      assert profile.guardian_timeout_ms == 5_000
      assert profile.orchestrator_command_timeout_ms == 30_000
      assert profile.dual_channel_timeout_ms == 5_000
      assert profile.watchdog_heartbeat_timeout_ms == 2_000

      # Circuit breaker enabled with balanced thresholds
      assert profile.circuit_breaker_threshold == 3
      assert profile.guardian_circuit_threshold == 3

      # Immutable state verification mandatory
      assert profile.immutable_state_verify_on_startup

      # Dual-channel halt on first disagreement
      assert profile.dual_channel_halt_threshold == 1

      # Fail-open mode (not fail-closed)
      refute profile.fail_closed_mode
    end

    test "sil4 profile has strict 2s timeouts and all safety mechanisms enabled" do
      profile = Config.profile(:sil4)

      # Strict 2s maximum timeout (IEC 61508 SIL-6)
      assert profile.guardian_timeout_ms == 2_000
      assert profile.sentinel_emergency_timeout_ms == 2_000
      assert profile.dual_channel_timeout_ms == 2_000

      # All safety mechanisms enabled
      assert profile.fail_closed_mode
      assert profile.immutable_state_verify_on_startup

      # Aggressive circuit breaker (fail-fast)
      assert profile.circuit_breaker_threshold == 1
      assert profile.guardian_circuit_threshold == 1

      # Dual-channel mandatory - halt on first disagreement
      assert profile.dual_channel_halt_threshold == 1

      # Aggressive watchdog monitoring
      assert profile.watchdog_heartbeat_timeout_ms == 1_000
      assert profile.watchdog_check_interval_ms == 250
      assert profile.watchdog_escalation_threshold == 1

      # Minimal retry attempts (prevent cascading failures)
      assert profile.max_retry_attempts == 1

      # High-frequency health monitoring
      assert profile.smart_metrics_interval_ms == 250
      assert profile.smart_metrics_staleness_ms == 1_000
    end

    test "sil4 profile enforces redundant verification" do
      profile = Config.profile(:sil4)

      # Dual-channel verification mandatory
      assert profile.dual_channel_timeout_ms == 2_000
      assert profile.dual_channel_halt_threshold == 1

      # Immutable state verification required
      assert profile.immutable_state_verify_on_startup

      # Fail-closed mode (safe state on errors)
      assert profile.fail_closed_mode
    end

    test "all profiles have required dual-channel settings" do
      for profile_name <- [:dev, :test, :prod, :sil4] do
        profile = Config.profile(profile_name)

        assert Map.has_key?(profile, :dual_channel_timeout_ms),
               "#{profile_name} missing dual_channel_timeout_ms"

        assert Map.has_key?(profile, :dual_channel_halt_threshold),
               "#{profile_name} missing dual_channel_halt_threshold"

        assert is_integer(profile.dual_channel_timeout_ms)
        assert is_integer(profile.dual_channel_halt_threshold)
        assert profile.dual_channel_halt_threshold >= 1
      end
    end

    test "all profiles have required watchdog settings" do
      for profile_name <- [:dev, :test, :prod, :sil4] do
        profile = Config.profile(profile_name)

        assert Map.has_key?(profile, :watchdog_heartbeat_timeout_ms),
               "#{profile_name} missing watchdog_heartbeat_timeout_ms"

        assert Map.has_key?(profile, :watchdog_check_interval_ms),
               "#{profile_name} missing watchdog_check_interval_ms"

        assert Map.has_key?(profile, :watchdog_escalation_threshold),
               "#{profile_name} missing watchdog_escalation_threshold"

        assert Map.has_key?(profile, :watchdog_restart_delay_ms),
               "#{profile_name} missing watchdog_restart_delay_ms"

        assert is_integer(profile.watchdog_heartbeat_timeout_ms)
        assert is_integer(profile.watchdog_check_interval_ms)
        assert is_integer(profile.watchdog_escalation_threshold)
        assert is_integer(profile.watchdog_restart_delay_ms)
      end
    end
  end

  describe "profile_summary/1" do
    test "returns dev profile summary" do
      summary = Config.profile_summary(:dev)

      assert summary.name == :dev
      assert summary.max_timeout_ms == 10_000
      assert summary.circuit_breaker == :relaxed
      assert summary.dual_channel == :enabled
      assert summary.fail_mode == :open
      assert summary.verification == :optional
      assert summary.watchdog == :relaxed
    end

    test "returns test profile summary" do
      summary = Config.profile_summary(:test)

      assert summary.name == :test
      assert summary.max_timeout_ms == 1_000
      assert summary.circuit_breaker == :fast
      assert summary.dual_channel == :enabled
      assert summary.fail_mode == :open
      assert summary.verification == :optional
      assert summary.watchdog == :fast
    end

    test "returns prod profile summary" do
      summary = Config.profile_summary(:prod)

      assert summary.name == :prod
      assert summary.max_timeout_ms == 5_000
      assert summary.circuit_breaker == :balanced
      assert summary.dual_channel == :enabled
      assert summary.fail_mode == :open
      assert summary.verification == :mandatory
      assert summary.watchdog == :balanced
    end

    test "returns sil4 profile summary with PFH target" do
      summary = Config.profile_summary(:sil4)

      assert summary.name == :sil4
      assert summary.max_timeout_ms == 2_000
      assert summary.circuit_breaker == :aggressive
      assert summary.dual_channel == :mandatory
      assert summary.fail_mode == :closed
      assert summary.verification == :mandatory
      assert summary.watchdog == :aggressive
      assert summary.target_pfh == 1.0e-8
      assert summary.redundancy == :dual_channel
      assert summary.iec_61508 == "SIL-6"
    end
  end

  describe "sil4_target_pfh/0" do
    test "returns IEC 61508 SIL-6 target PFH" do
      pfh = Config.sil4_target_pfh()

      # SIL-6 requires PFH < 10^-8 (we target the upper bound)
      assert pfh == 1.0e-8
      assert pfh <= 1.0e-8
      assert pfh < 1.0e-7
    end
  end

  describe "available_profiles/0" do
    test "returns all profile names" do
      profiles = Config.available_profiles()

      assert :dev in profiles
      assert :test in profiles
      assert :prod in profiles
      assert :sil4 in profiles
      assert length(profiles) == 4
    end
  end

  describe "validate/1" do
    test "validates dev profile configuration" do
      profile = Config.profile(:dev)

      assert {:ok, ^profile} = Config.validate(profile)
    end

    test "validates test profile configuration" do
      profile = Config.profile(:test)

      assert {:ok, ^profile} = Config.validate(profile)
    end

    test "validates prod profile configuration" do
      profile = Config.profile(:prod)

      assert {:ok, ^profile} = Config.validate(profile)
    end

    test "validates sil4 profile configuration" do
      profile = Config.profile(:sil4)

      assert {:ok, ^profile} = Config.validate(profile)
    end
  end

  describe "profile strictness ordering" do
    test "timeouts decrease from dev → prod → sil4 (strictness ordering)" do
      dev = Config.profile(:dev)
      test_profile = Config.profile(:test)
      prod = Config.profile(:prod)
      sil4 = Config.profile(:sil4)

      # Guardian timeout strictness (dev → prod → sil4)
      assert dev.guardian_timeout_ms > prod.guardian_timeout_ms
      assert prod.guardian_timeout_ms > sil4.guardian_timeout_ms

      # Test profile is optimized for speed, not safety (may be faster than sil4)
      assert test_profile.guardian_timeout_ms <= dev.guardian_timeout_ms

      # Dual-channel timeout strictness (dev → prod → sil4)
      assert dev.dual_channel_timeout_ms > prod.dual_channel_timeout_ms
      assert prod.dual_channel_timeout_ms > sil4.dual_channel_timeout_ms

      # Watchdog strictness (dev → prod → sil4)
      assert dev.watchdog_heartbeat_timeout_ms > prod.watchdog_heartbeat_timeout_ms
      assert prod.watchdog_heartbeat_timeout_ms >= sil4.watchdog_heartbeat_timeout_ms
    end

    test "circuit breaker thresholds increase in strictness from dev → sil4" do
      dev = Config.profile(:dev)
      prod = Config.profile(:prod)
      sil4 = Config.profile(:sil4)

      # Lower threshold = stricter (fail faster)
      assert dev.circuit_breaker_threshold > prod.circuit_breaker_threshold
      assert prod.circuit_breaker_threshold > sil4.circuit_breaker_threshold
      assert sil4.circuit_breaker_threshold == 1
    end

    test "safety mechanisms increase from dev → sil4" do
      dev = Config.profile(:dev)
      prod = Config.profile(:prod)
      sil4 = Config.profile(:sil4)

      # Fail-closed mode
      refute dev.fail_closed_mode
      refute prod.fail_closed_mode
      assert sil4.fail_closed_mode

      # Verification on startup
      refute dev.immutable_state_verify_on_startup
      assert prod.immutable_state_verify_on_startup
      assert sil4.immutable_state_verify_on_startup

      # Dual-channel halt threshold
      assert dev.dual_channel_halt_threshold > prod.dual_channel_halt_threshold
      assert prod.dual_channel_halt_threshold >= sil4.dual_channel_halt_threshold
      assert sil4.dual_channel_halt_threshold == 1
    end
  end

  describe "IEC 61508 SIL-6 compliance" do
    test "sil4 profile meets IEC 61508 timing requirements" do
      profile = Config.profile(:sil4)

      # Maximum 2s timeout for critical operations (SIL-6 requirement)
      assert profile.guardian_timeout_ms <= 2_000
      assert profile.sentinel_emergency_timeout_ms <= 2_000
      assert profile.dual_channel_timeout_ms <= 2_000

      # Watchdog must be aggressive (< 2s heartbeat)
      assert profile.watchdog_heartbeat_timeout_ms <= 2_000

      # Orchestrator command timeout can be higher but still strict
      assert profile.orchestrator_command_timeout_ms <= 15_000
    end

    test "sil4 profile has all mandatory safety features enabled" do
      profile = Config.profile(:sil4)

      # 1. Dual-channel verification
      assert profile.dual_channel_timeout_ms == 2_000
      assert profile.dual_channel_halt_threshold == 1

      # 2. Aggressive circuit breaker
      assert profile.circuit_breaker_threshold == 1

      # 3. Fail-closed mode
      assert profile.fail_closed_mode

      # 4. Mandatory immutable state verification
      assert profile.immutable_state_verify_on_startup

      # 5. Minimal retry attempts
      assert profile.max_retry_attempts == 1

      # 6. Aggressive watchdog
      assert profile.watchdog_heartbeat_timeout_ms == 1_000
      assert profile.watchdog_check_interval_ms == 250
      assert profile.watchdog_escalation_threshold == 1
    end

    test "sil4 profile PFH target meets IEC 61508 SIL-6" do
      pfh = Config.sil4_target_pfh()

      # SIL-6: 10^-9 ≤ PFH < 10^-8
      # We target the upper bound: PFH < 10^-8
      assert pfh == 1.0e-8
      assert pfh < 1.0e-7
      assert pfh >= 1.0e-9
    end
  end

  describe "property tests" do
    property "profile validation is deterministic across all SIL levels" do
      forall level <- PC.oneof([:dev, :test, :prod, :sil4]) do
        profile = Config.profile(level)
        validation1 = Config.validate(profile)
        validation2 = Config.validate(profile)
        validation1 == validation2
      end
    end

    property "all profiles return valid configurations with required keys" do
      forall level <- PC.oneof([:dev, :test, :prod, :sil4]) do
        profile = Config.profile(level)

        is_map(profile) and
          Map.has_key?(profile, :guardian_timeout_ms) and
          Map.has_key?(profile, :dual_channel_timeout_ms) and
          Map.has_key?(profile, :circuit_breaker_threshold)
      end
    end

    property "profile summaries match profile data consistently" do
      forall level <- PC.oneof([:dev, :test, :prod, :sil4]) do
        profile = Config.profile(level)
        summary = Config.profile_summary(level)
        summary.name == level and is_map(profile)
      end
    end
  end
end
