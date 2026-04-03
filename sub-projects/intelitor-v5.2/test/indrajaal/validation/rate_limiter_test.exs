defmodule Indrajaal.Validation.RateLimiterTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.RateLimiter.

  Tests token bucket rate limiting with exponential backoff.
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.RateLimiter
  alias Indrajaal.Validation.RateLimiterRegistry

  setup do
    case Registry.start_link(keys: :unique, name: RateLimiterRegistry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    session_id = "test_session_#{System.unique_integer([:positive])}"
    {:ok, _pid} = RateLimiter.start_link(session_id: session_id)
    {:ok, session_id: session_id}
  end

  describe "start_link/1" do
    test "starts a rate limiter process", %{session_id: _session_id} do
      new_session = "new_session_#{System.unique_integer([:positive])}"
      assert {:ok, pid} = RateLimiter.start_link(session_id: new_session)
      assert is_pid(pid)
    end
  end

  describe "check_rate_limit/1" do
    test "returns :ok when tokens are available", %{session_id: session_id} do
      result = RateLimiter.check_rate_limit(session_id)
      assert result == :ok
    end

    test "returns :ok or rate_limited tuple", %{session_id: session_id} do
      result = RateLimiter.check_rate_limit(session_id)
      assert result == :ok or match?({:rate_limited, _}, result)
    end
  end

  describe "get_status/1" do
    test "returns status map with tokens key", %{session_id: session_id} do
      status = RateLimiter.get_status(session_id)
      assert is_map(status)
      assert Map.has_key?(status, :tokens)
    end

    test "returns status with consecutive_failures key", %{session_id: session_id} do
      status = RateLimiter.get_status(session_id)
      assert Map.has_key?(status, :consecutive_failures)
    end

    test "returns status with rate_limited boolean key", %{session_id: session_id} do
      status = RateLimiter.get_status(session_id)
      assert Map.has_key?(status, :rate_limited)
      assert is_boolean(status.rate_limited)
    end

    test "returns default status for unknown session" do
      status = RateLimiter.get_status("unknown_session_xyz")
      assert is_map(status)
      assert Map.has_key?(status, :tokens)
    end
  end

  describe "record_success/1" do
    test "returns :ok", %{session_id: session_id} do
      # This is a cast so no return value to check directly
      # Just verify it doesn't crash
      RateLimiter.record_success(session_id)
      status = RateLimiter.get_status(session_id)
      assert status.consecutive_failures == 0
    end
  end

  describe "record_rate_limit/1" do
    test "returns ok tuple with backoff milliseconds", %{session_id: session_id} do
      result = RateLimiter.record_rate_limit(session_id)
      assert match?({:ok, ms} when is_integer(ms) and ms > 0, result)
    end
  end

  describe "reset/1" do
    test "returns :ok", %{session_id: session_id} do
      assert :ok = RateLimiter.reset(session_id)
    end

    test "resets consecutive failures to 0", %{session_id: session_id} do
      RateLimiter.record_rate_limit(session_id)
      RateLimiter.reset(session_id)
      status = RateLimiter.get_status(session_id)
      assert status.consecutive_failures == 0
    end

    test "returns :ok for non-existent session" do
      assert :ok = RateLimiter.reset("unknown_session_xyz")
    end
  end
end
