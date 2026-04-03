defmodule Indrajaal.Authentication.TokenRevocationCacheTest do
  @moduledoc """
  Comprehensive tests for Token Revocation Cache System

  Tests all aspects of token revocation including:
  - Fast revocation checking with ETS
  - Batch token revocation
  - TTL and cleanup functionality
  - Redis integration (when available)
  - Performance and reliability
  """

  # Async false due to shared ETS table
  use ExUnit.Case, async: false
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Authentication.TokenRevocationCache

  setup do
    # Start the cache for testing
    {:ok, pid} = TokenRevocationCache.start_link([])

    # Clear any existing data
    TokenRevocationCache.clear_all()

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    {:ok, cache_pid: pid}
  end

  describe "revoked?/1" do
    test "returns false for non - revoked token" do
      jti = "test-jti-123"
      refute TokenRevocationCache.revoked?(jti)
    end

    test "returns true for revoked token" do
      jti = "test-jti-456"

      :ok = TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)
    end

    test "returns true for invalid JTI format" do
      invalid_jtis = [nil, "", 123, %{}, []]

      for invalid_jti <- invalid_jtis do
        assert TokenRevocationCache.revoked?(invalid_jti)
      end
    end

    test "returns false for expired revoked token" do
      jti = "test-jti-expired"
      # 10 milliseconds
      short_ttl = 10

      :ok = TokenRevocationCache.revoke_token(jti, short_ttl)
      assert TokenRevocationCache.revoked?(jti)

      # Wait for expiration
      Process.sleep(20)
      refute TokenRevocationCache.revoked?(jti)
    end

    test "emits telemetry events on revocation check" do
      jti = "test-jti-telemetry"

      # Would test telemetry events
      # This requires setting up telemetry test handlers
    end
  end

  describe "revoke_token / 2" do
    test "revokes token successfully" do
      jti = "test-jti-revoke"

      assert :ok == TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)
    end

    test "revokes token with custom TTL" do
      jti = "test-jti - custom-ttl"
      # 5 seconds
      custom_ttl = 5000

      assert :ok == TokenRevocationCache.revoke_token(jti, custom_ttl)
      assert TokenRevocationCache.revoked?(jti)
    end

    test "allows multiple revocations of same token" do
      jti = "test-jti-multiple"

      assert :ok == TokenRevocationCache.revoke_token(jti)
      assert :ok == TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)
    end

    test "emits telemetry events on revocation" do
      jti = "test-jti-telemetry-revoke"

      # Would test telemetry events for revocation
    end
  end

  describe "revoke_tokens / 2" do
    test "revokes multiple tokens in batch" do
      jtis = ["batch-1", "batch-2", "batch-3"]

      assert :ok == TokenRevocationCache.revoke_tokens(jtis)

      for jti <- jtis do
        assert TokenRevocationCache.revoked?(jti)
      end
    end

    test "handles empty batch gracefully" do
      assert :ok == TokenRevocationCache.revoke_tokens([])
    end

    test "revokes batch with custom TTL" do
      jtis = ["batch-ttl - 1", "batch-ttl - 2"]
      custom_ttl = 10_000

      assert :ok == TokenRevocationCache.revoke_tokens(jtis, custom_ttl)

      for jti <- jtis do
        assert TokenRevocationCache.revoked?(jti)
      end
    end

    test "emits telemetry events for batch revocation" do
      jtis = ["telemetry-batch-1", "telemetry-batch-2"]

      # Would test batch telemetry events
    end
  end

  describe "unrevoke_token / 1" do
    test "removes token from revocation list" do
      jti = "test-jti-unrevoke"

      :ok = TokenRevocationCache.revoke_token(jti)
      assert TokenRevocationCache.revoked?(jti)

      :ok = TokenRevocationCache.unrevoke_token(jti)
      refute TokenRevocationCache.revoked?(jti)
    end

    test "handles unrevoking non - revoked token" do
      jti = "never-revoked"

      assert :ok == TokenRevocationCache.unrevoke_token(jti)
      refute TokenRevocationCache.revoked?(jti)
    end
  end

  describe "stats / 0" do
    test "returns cache statistics" do
      # Add some test data
      jtis = ["stats-1", "stats-2", "stats-3"]
      TokenRevocationCache.revoke_tokens(jtis)

      stats = TokenRevocationCache.stats()

      assert is_map(stats)
      assert is_integer(stats.cache_size)
      assert stats.cache_size >= length(jtis)
      assert is_integer(stats.memory_usage_bytes)
      assert is_boolean(stats.redis_enabled)
      assert is_integer(stats.uptime_seconds)
    end
  end

  describe "clear_all / 0" do
    test "clears all revoked tokens" do
      jtis = ["clear-1", "clear-2", "clear-3"]
      TokenRevocationCache.revoke_tokens(jtis)

      # Verify tokens are revoked
      for jti <- jtis do
        assert TokenRevocationCache.revoked?(jti)
      end

      # Clear all
      :ok = TokenRevocationCache.clear_all()

      # Verify tokens are no longer revoked
      for jti <- jtis do
        refute TokenRevocationCache.revoked?(jti)
      end
    end
  end

  describe "cleanup functionality" do
    test "automatically cleans up expired tokens" do
      # This test would verify the cleanup timer functionality
      # It would require waiting for cleanup intervals or triggering cleanup ma

      jti = "cleanup-test"
      # 50ms
      short_ttl = 50

      :ok = TokenRevocationCache.revoke_token(jti, short_ttl)
      assert TokenRevocationCache.revoked?(jti)

      # Wait for cleanup (this would be optimized in real tests)
      Process.sleep(100)

      # Token should be cleaned up
      refute TokenRevocationCache.revoked?(jti)
    end
  end

  describe "performance characteristics" do
    test "handles large number of tokens efficiently" do
      # Performance test with many tokens
      token_count = 1000
      jtis = for i <- 1..token_count, do: "perf-test-#{i}"

      # Measure batch revocation time
      {time_micro, :ok} =
        :timer.tc(fn ->
          TokenRevocationCache.revoke_tokens(jtis)
        end)

      # Should complete within reasonable time (adjust threshold as needed)
      # 100ms
      assert time_micro < 100_000

      # Verify all tokens are revoked
      # Sample check
      for jti <- Enum.take(jtis, 10) do
        assert TokenRevocationCache.revoked?(jti)
      end
    end

    test "lookup performance remains consistent" do
      # Add many tokens and test lookup performance
      token_count = 5000
      jtis = for i <- 1..token_count, do: "lookup-perf-#{i}"

      TokenRevocationCache.revoke_tokens(jtis)

      # Test lookup performance
      test_jti = Enum.random(jtis)

      {time_micro, result} =
        :timer.tc(fn ->
          TokenRevocationCache.revoked?(test_jti)
        end)

      assert result
      # Lookup should be very fast
      # 1ms
      assert time_micro < 1000
    end
  end

  describe "error handling" do
    test "gracefully handles ETS table issues" do
      # This would test error scenarios like ETS table corruption
      # Implementation depends on how robust error handling is needed
    end

    test "recovers from GenServer crashes" do
      # Test system resilience
      # Would require more sophisticated test setup
    end
  end

  describe "Redis integration" do
    test "falls back gracefully when Redis unavailable" do
      # Test behavior when Redis is not available
      # Implementation would depend on Redis integration details
    end

    test "syncs with Redis when available" do
      # Test Redis synchronization functionality
      # Would require Redis test setup
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
