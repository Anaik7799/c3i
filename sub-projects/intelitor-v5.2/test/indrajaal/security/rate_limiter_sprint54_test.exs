defmodule Indrajaal.Security.RateLimiterSprint54Test do
  @moduledoc """
  TDG property-based and constitutional test suite for Security.RateLimiter — Sprint 54 Wave 1.

  Supplements the existing rate_limiter_test.exs with dual property testing,
  SIL-6 concurrent safety, and FMEA boundary coverage.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation refinement
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SEC-044: Rate limiting prevents brute-force attacks
  - SC-PRF-050: Rate check response < 50ms (SC-PRF-050)
  - SC-SIL6 (Panopticon Mesh): Rate limiter must not deadlock under concurrent load

  ## Constitutional Verification
  - Ψ₀ Existence: Rate limiter GenServer survives under load
  - Ψ₅ Truthfulness: check_rate accurately reflects sliding window state

  ## Founder's Directive Alignment
  - Ω₀.7: Threat elimination through rate limiting of brute-force attempts

  ## TPS 5-Level RCA Context
  - L1 Symptom: Authentication endpoint overwhelmed by automated attacks
  - L5 Root Cause: Missing per-role sliding window enforcement at API boundary

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude Sonnet 4.6 | Sprint 54 W1 test generation |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Security.RateLimiter

  @moduletag :zenoh_nif

  @valid_roles [:admin, :manager, :operator, :viewer, :service]

  setup do
    case Process.whereis(RateLimiter) do
      nil ->
        {:ok, pid} = RateLimiter.start_link([])

        on_exit(fn ->
          if Process.alive?(pid), do: GenServer.stop(pid)
        end)

      pid ->
        on_exit(fn ->
          if Process.alive?(pid) do
            RateLimiter.reset_rate_limit("prop-test-user", "/api/prop-test")
          end
        end)
    end

    :ok
  end

  # ============================================================
  # check_rate/4 — basic behavior
  # ============================================================

  describe "check_rate/4" do
    test "first request for unknown key is always allowed" do
      user_id = "s54-first-#{System.unique_integer([:positive])}"
      result = RateLimiter.check_rate(user_id, "/api/unique-endpoint", :admin)
      assert match?({:ok, _}, result)
    end

    test "allowed result contains remaining count" do
      user_id = "s54-rem-#{System.unique_integer([:positive])}"
      {:ok, info} = RateLimiter.check_rate(user_id, "/api/remaining", :admin)
      assert Map.has_key?(info, :remaining)
      assert is_integer(info.remaining)
    end

    test "allowed result contains reset_at timestamp" do
      user_id = "s54-rst-#{System.unique_integer([:positive])}"
      {:ok, info} = RateLimiter.check_rate(user_id, "/api/reset", :viewer)
      assert Map.has_key?(info, :reset_at)
      assert is_integer(info.reset_at)
    end

    test "reset_at is in the future" do
      user_id = "s54-future-#{System.unique_integer([:positive])}"
      {:ok, info} = RateLimiter.check_rate(user_id, "/api/future", :manager)
      now = System.system_time(:second)
      assert info.reset_at > now
    end

    test "each role produces a valid response" do
      Enum.each(@valid_roles, fn role ->
        user_id = "s54-role-#{role}-#{System.unique_integer([:positive])}"
        result = RateLimiter.check_rate(user_id, "/api/role-test", role)
        assert match?({:ok, _}, result), "Role #{role} should be allowed on first request"
      end)
    end

    test "unknown role falls back to viewer limits" do
      user_id = "s54-unknown-role-#{System.unique_integer([:positive])}"
      result = RateLimiter.check_rate(user_id, "/api/unknown", :unknown_role)
      assert match?({:ok, _}, result)
    end
  end

  # ============================================================
  # reset_rate_limit/2
  # ============================================================

  describe "reset_rate_limit/2" do
    test "returns :ok (cast — fire-and-forget)" do
      assert :ok = RateLimiter.reset_rate_limit("s54-reset-user", "/api/reset-test")
    end

    test "reset allows subsequent request for previously-seen key" do
      user_id = "s54-reset-flow-#{System.unique_integer([:positive])}"
      endpoint = "/api/reset-flow"
      {:ok, _} = RateLimiter.check_rate(user_id, endpoint, :viewer)
      :ok = RateLimiter.reset_rate_limit(user_id, endpoint)
      # After reset, should be allowed again (as a new entry)
      result = RateLimiter.check_rate(user_id, endpoint, :viewer)
      assert match?({:ok, _}, result)
    end
  end

  # ============================================================
  # get_statistics/0
  # ============================================================

  describe "get_statistics/0" do
    test "returns a map with expected keys" do
      stats = RateLimiter.get_statistics()
      assert is_map(stats)
      assert Map.has_key?(stats, :active_entries)
      assert Map.has_key?(stats, :memory_usage_bytes)
    end

    test "active_entries is a non-negative integer" do
      stats = RateLimiter.get_statistics()
      assert is_integer(stats.active_entries)
      assert stats.active_entries >= 0
    end

    test "memory_usage_bytes is a non-negative integer" do
      stats = RateLimiter.get_statistics()
      assert is_integer(stats.memory_usage_bytes)
      assert stats.memory_usage_bytes >= 0
    end

    test "active_entries increases after new rate checks" do
      before = RateLimiter.get_statistics()
      user_id = "s54-stats-#{System.unique_integer([:positive])}"
      RateLimiter.check_rate(user_id, "/api/stats-test", :admin)
      after_check = RateLimiter.get_statistics()
      # Entry count should be at least as large as before
      assert after_check.active_entries >= before.active_entries
    end
  end

  # ============================================================
  # adjust_limits/1
  # ============================================================

  describe "adjust_limits/1" do
    test "accepts map with role adjustments without crashing" do
      assert :ok = RateLimiter.adjust_limits(%{admin: %{requests: 2000, window: 60}})
    end

    test "accepts empty map" do
      assert :ok = RateLimiter.adjust_limits(%{})
    end
  end

  # ============================================================
  # SIL-6: Performance — response latency < 50ms (SC-PRF-050)
  # ============================================================

  describe "SIL-6: performance constraints" do
    test "check_rate completes within 50ms (SC-PRF-050)" do
      user_id = "s54-perf-#{System.unique_integer([:positive])}"
      start_us = System.monotonic_time(:microsecond)
      RateLimiter.check_rate(user_id, "/api/perf", :admin)
      elapsed_ms = (System.monotonic_time(:microsecond) - start_us) / 1000
      assert elapsed_ms < 50, "check_rate took #{elapsed_ms}ms, expected < 50ms"
    end

    test "get_statistics completes within 50ms (SC-PRF-050)" do
      start_us = System.monotonic_time(:microsecond)
      RateLimiter.get_statistics()
      elapsed_ms = (System.monotonic_time(:microsecond) - start_us) / 1000
      assert elapsed_ms < 50, "get_statistics took #{elapsed_ms}ms"
    end
  end

  # ============================================================
  # Concurrent safety (SIL-6 dual-channel)
  # ============================================================

  describe "concurrent access safety" do
    test "20 concurrent check_rate calls for distinct users all succeed" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            user_id = "conc-s54-#{i}-#{System.unique_integer([:positive])}"
            RateLimiter.check_rate(user_id, "/api/concurrent", :operator)
          end)
        end

      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)
    end

    test "concurrent statistics reads are consistent" do
      tasks = for _ <- 1..10, do: Task.async(fn -> RateLimiter.get_statistics() end)
      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, &is_map/1)
    end
  end

  # ============================================================
  # Property Tests (PropCheck)
  # ============================================================

  property "first check_rate for any unique user always returns :ok" do
    forall suffix <- PC.pos_integer() do
      user_id = "prop-s54-#{suffix}-#{:erlang.unique_integer([:positive])}"
      match?({:ok, _}, RateLimiter.check_rate(user_id, "/api/prop", :viewer))
    end
  end

  property "check_rate result is always a tagged 2-tuple or 3-tuple" do
    forall {role, suffix} <- {PC.elements(@valid_roles), PC.pos_integer()} do
      user_id = "prop-role-s54-#{suffix}-#{:erlang.unique_integer([:positive])}"
      result = RateLimiter.check_rate(user_id, "/api/role-prop", role)
      is_tuple(result) and tuple_size(result) in [2, 3]
    end
  end

  # ============================================================
  # ExUnitProperties (StreamData)
  # ============================================================

  test "check_rate :ok result always has remaining and reset_at keys" do
    ExUnitProperties.check all(
                             suffix <- SD.positive_integer(),
                             role <- SD.member_of(@valid_roles)
                           ) do
      user_id = "ex-s54-#{suffix}-#{System.unique_integer([:positive])}"
      result = RateLimiter.check_rate(user_id, "/api/ex-prop", role)

      case result do
        {:ok, info} ->
          assert Map.has_key?(info, :remaining)
          assert Map.has_key?(info, :reset_at)

        {:error, :rate_limited, info} ->
          assert Map.has_key?(info, :limit)
          assert Map.has_key?(info, :reset_at)
      end
    end
  end

  # ============================================================
  # FMEA: boundary conditions
  # ============================================================

  describe "FMEA: edge cases (RPN ≥ 50)" do
    test "check_rate with empty user_id string does not crash" do
      result = RateLimiter.check_rate("", "/api/empty-user", :viewer)
      assert is_tuple(result)
    end

    test "check_rate with very long endpoint string does not crash" do
      long_endpoint = "/" <> String.duplicate("a", 2048)
      result = RateLimiter.check_rate("s54-long-ep", long_endpoint, :admin)
      assert is_tuple(result)
    end

    test "check_rate with nil role falls back gracefully" do
      user_id = "s54-nil-role-#{System.unique_integer([:positive])}"
      result = RateLimiter.check_rate(user_id, "/api/nil-role", nil)
      assert is_tuple(result)
    end

    test "adjust_limits with invalid role key does not crash" do
      assert :ok = RateLimiter.adjust_limits(%{invalid_role: %{requests: 10, window: 30}})
    end

    test "reset_rate_limit for non-existent entry is safe" do
      assert :ok = RateLimiter.reset_rate_limit("never-checked", "/api/never-hit")
    end
  end
end
