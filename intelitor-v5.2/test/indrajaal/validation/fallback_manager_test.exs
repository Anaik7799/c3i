defmodule Indrajaal.Validation.FallbackManagerTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.FallbackManager.

  Tests GenServer-based live/mock fallback management.
  Uses async: false because FallbackManager registers under its module name
  and creates a named ETS table (:fallback_cache).
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.FallbackManager

  setup do
    # Ensure any existing ETS table is cleaned up and process is stopped
    if :ets.whereis(:fallback_cache) != :undefined do
      :ets.delete(:fallback_cache)
    end

    case Process.whereis(FallbackManager) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    {:ok, _pid} = start_supervised!(FallbackManager)
    :ok
  end

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(FallbackManager)
    end

    test "start_link/1 is exported" do
      assert function_exported?(FallbackManager, :start_link, 1)
    end

    test "validate_with_fallback/3 is exported" do
      assert function_exported?(FallbackManager, :validate_with_fallback, 3)
    end

    test "set_mode/1 is exported" do
      assert function_exported?(FallbackManager, :set_mode, 1)
    end

    test "get_stats/0 is exported" do
      assert function_exported?(FallbackManager, :get_stats, 0)
    end

    test "set_canary_percentage/1 is exported" do
      assert function_exported?(FallbackManager, :set_canary_percentage, 1)
    end
  end

  describe "validate_with_fallback/3" do
    test "returns ok when live function succeeds" do
      live_fn = fn -> {:ok, :live_result} end
      mock_fn = fn -> {:ok, :mock_result} end

      {result, _source} = FallbackManager.validate_with_fallback(live_fn, mock_fn)
      assert match?({:ok, _}, result)
    end

    test "returns source atom indicating which path was used" do
      live_fn = fn -> {:ok, :live_result} end
      mock_fn = fn -> {:ok, :mock_result} end

      {_result, source} = FallbackManager.validate_with_fallback(live_fn, mock_fn)
      assert source in [:live, :mock, :cache]
    end

    test "falls back to mock when live function fails" do
      live_fn = fn -> {:error, :api_down} end
      mock_fn = fn -> {:ok, :mock_result} end

      {result, source} =
        FallbackManager.validate_with_fallback(live_fn, mock_fn, mode: :live_with_mock)

      assert match?({:ok, _}, result)
      assert source == :mock
    end

    test "uses mock only mode when specified" do
      live_fn = fn -> {:ok, :should_not_be_called} end
      mock_fn = fn -> {:ok, :mock_result} end

      {result, source} =
        FallbackManager.validate_with_fallback(live_fn, mock_fn, mode: :mock_only)

      assert match?({:ok, _}, result)
      assert source == :mock
    end

    test "live only mode uses live function" do
      live_fn = fn -> {:ok, :live_result} end
      mock_fn = fn -> {:ok, :mock_result} end

      {result, source} =
        FallbackManager.validate_with_fallback(live_fn, mock_fn, mode: :live_only)

      assert match?({:ok, _}, result)
      assert source == :live
    end

    test "returns tuple of {result, source}" do
      live_fn = fn -> {:ok, :data} end
      mock_fn = fn -> {:ok, :mock} end

      response = FallbackManager.validate_with_fallback(live_fn, mock_fn)
      assert is_tuple(response)
      assert tuple_size(response) == 2
    end
  end

  describe "get_stats/0" do
    test "returns a map" do
      stats = FallbackManager.get_stats()
      assert is_map(stats)
    end

    test "stats contains mode key" do
      stats = FallbackManager.get_stats()
      assert Map.has_key?(stats, :mode)
    end

    test "stats contains total_requests key" do
      stats = FallbackManager.get_stats()
      assert Map.has_key?(stats, :total_requests)
      assert is_integer(stats.total_requests)
    end

    test "stats contains live_success key" do
      stats = FallbackManager.get_stats()
      assert Map.has_key?(stats, :live_success)
    end

    test "stats contains mock_used key" do
      stats = FallbackManager.get_stats()
      assert Map.has_key?(stats, :mock_used)
    end

    test "stats contains circuit_breaker key" do
      stats = FallbackManager.get_stats()
      assert Map.has_key?(stats, :circuit_breaker)
      assert stats.circuit_breaker in [:closed, :open, :half_open]
    end

    test "stats contains success_rate key" do
      stats = FallbackManager.get_stats()
      assert Map.has_key?(stats, :success_rate)
      assert is_float(stats.success_rate)
    end
  end

  describe "set_canary_percentage/1" do
    test "returns ok for valid percentage" do
      assert :ok = FallbackManager.set_canary_percentage(50)
    end

    test "returns ok for 0 percent" do
      assert :ok = FallbackManager.set_canary_percentage(0)
    end

    test "returns ok for 100 percent" do
      assert :ok = FallbackManager.set_canary_percentage(100)
    end
  end
end
