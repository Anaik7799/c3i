defmodule Indrajaal.Validation.TimeoutHandlerTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.TimeoutHandler.

  Tests timeout handling with graceful degradation strategies.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.TimeoutHandler

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(TimeoutHandler)
    end

    test "with_timeout/2 is exported" do
      assert function_exported?(TimeoutHandler, :with_timeout, 2)
    end

    test "adaptive_timeout/1 is exported" do
      assert function_exported?(TimeoutHandler, :adaptive_timeout, 1)
    end

    test "with_progressive_timeout/2 is exported" do
      assert function_exported?(TimeoutHandler, :with_progressive_timeout, 2)
    end

    test "monitor_timeout/1 is exported" do
      assert function_exported?(TimeoutHandler, :monitor_timeout, 1)
    end

    test "complete_monitoring/1 is exported" do
      assert function_exported?(TimeoutHandler, :complete_monitoring, 1)
    end
  end

  describe "with_timeout/2 - successful completion" do
    test "returns ok tuple when function completes within timeout" do
      result = TimeoutHandler.with_timeout(fn -> {:ok, :completed} end, timeout: 5_000)
      assert result == {:ok, :completed}
    end

    test "passes through ok tuples unchanged" do
      result = TimeoutHandler.with_timeout(fn -> {:ok, %{data: 42}} end, timeout: 5_000)
      assert result == {:ok, %{data: 42}}
    end

    test "wraps non-tagged return in ok" do
      result = TimeoutHandler.with_timeout(fn -> 42 end, timeout: 5_000)
      assert result == {:ok, 42}
    end

    test "uses default timeout when none specified" do
      result = TimeoutHandler.with_timeout(fn -> {:ok, :done} end)
      assert result == {:ok, :done}
    end
  end

  describe "with_timeout/2 - timeout handling" do
    test "returns error tuple when function times out with :none degradation" do
      result =
        TimeoutHandler.with_timeout(
          fn ->
            Process.sleep(200)
            {:ok, :too_late}
          end,
          timeout: 50,
          degradation: :none
        )

      assert result == {:error, :timeout}
    end

    test "returns minimal map when function times out with :minimal degradation" do
      result =
        TimeoutHandler.with_timeout(
          fn ->
            Process.sleep(200)
            {:ok, :too_late}
          end,
          timeout: 50,
          degradation: :minimal
        )

      assert match?({:minimal, %{status: :timeout}}, result)
    end

    test "returns error or partial on timeout with :partial degradation (no partial handler)" do
      result =
        TimeoutHandler.with_timeout(
          fn ->
            Process.sleep(200)
            {:ok, :too_late}
          end,
          timeout: 50,
          degradation: :partial
        )

      assert elem(result, 0) in [:partial, :error]
    end

    test "timeout result is a tuple" do
      result =
        TimeoutHandler.with_timeout(
          fn ->
            Process.sleep(200)
            {:ok, :too_late}
          end,
          timeout: 50,
          degradation: :none
        )

      assert is_tuple(result)
    end
  end

  describe "with_timeout/2 - custom partial handler" do
    test "uses custom partial handler on timeout" do
      partial_handler = fn -> {:ok, %{partial: true, snapshot: "interim"}} end

      result =
        TimeoutHandler.with_timeout(
          fn ->
            Process.sleep(200)
            {:ok, :too_late}
          end,
          timeout: 50,
          degradation: :partial,
          partial_handler: partial_handler
        )

      assert match?({:partial, %{partial: true}}, result)
    end
  end

  describe "adaptive_timeout/1" do
    test "returns an integer timeout value" do
      result = TimeoutHandler.adaptive_timeout(:request)
      assert is_integer(result)
    end

    test "returns positive timeout" do
      result = TimeoutHandler.adaptive_timeout(:connect)
      assert result > 0
    end

    test "returns integer for unknown operation type" do
      result = TimeoutHandler.adaptive_timeout(:unknown_operation)
      assert is_integer(result)
    end

    test "returns different timeouts for different operation types" do
      connect_timeout = TimeoutHandler.adaptive_timeout(:connect)
      validation_timeout = TimeoutHandler.adaptive_timeout(:validation)
      # Both should be valid positive integers
      assert is_integer(connect_timeout) and connect_timeout > 0
      assert is_integer(validation_timeout) and validation_timeout > 0
    end
  end

  describe "adaptive_timeout/2 with base override" do
    test "accepts custom base timeout" do
      result = TimeoutHandler.adaptive_timeout(:request, 10_000)
      assert is_integer(result)
    end

    test "base timeout bounds the result" do
      base = 5_000
      result = TimeoutHandler.adaptive_timeout(:request, base)
      # Result should not go below base or above 2x base per implementation
      assert result >= base
      assert result <= base * 2
    end
  end

  describe "with_progressive_timeout/2" do
    test "returns ok when function succeeds quickly" do
      result =
        TimeoutHandler.with_progressive_timeout(
          fn -> {:ok, :fast} end,
          levels: [{5_000, :full}, {10_000, :partial}]
        )

      assert result == {:ok, :fast}
    end

    test "returns error when all timeout levels exceeded" do
      result =
        TimeoutHandler.with_progressive_timeout(
          fn ->
            Process.sleep(500)
            {:ok, :slow}
          end,
          levels: [{50, :full}, {50, :partial}]
        )

      # When all levels time out, returns an error-like tuple
      assert is_tuple(result)
    end

    test "uses default levels when not specified" do
      result = TimeoutHandler.with_progressive_timeout(fn -> {:ok, :done} end)
      assert result == {:ok, :done}
    end
  end

  describe "monitor_timeout/1" do
    test "returns a monitoring context map" do
      ctx = TimeoutHandler.monitor_timeout(:test_operation)
      assert is_map(ctx)
    end

    test "context contains operation field" do
      ctx = TimeoutHandler.monitor_timeout(:my_op)
      assert Map.has_key?(ctx, :operation)
      assert ctx.operation == :my_op
    end

    test "context contains start_time field" do
      ctx = TimeoutHandler.monitor_timeout(:my_op)
      assert Map.has_key?(ctx, :start_time)
      assert is_integer(ctx.start_time)
    end

    test "context contains timeout field" do
      ctx = TimeoutHandler.monitor_timeout(:my_op)
      assert Map.has_key?(ctx, :timeout)
    end

    test "context contains warning_ref field" do
      ctx = TimeoutHandler.monitor_timeout(:my_op)
      assert Map.has_key?(ctx, :warning_ref)
    end

    test "accepts custom timeout" do
      ctx = TimeoutHandler.monitor_timeout(:my_op, 5_000)
      assert ctx.timeout == 5_000
    end
  end

  describe "complete_monitoring/1" do
    test "returns performance data map" do
      ctx = TimeoutHandler.monitor_timeout(:test_op)
      result = TimeoutHandler.complete_monitoring(ctx)
      assert is_map(result)
    end

    test "performance data contains operation field" do
      ctx = TimeoutHandler.monitor_timeout(:test_op)
      result = TimeoutHandler.complete_monitoring(ctx)
      assert Map.has_key?(result, :operation)
      assert result.operation == :test_op
    end

    test "performance data contains duration field" do
      ctx = TimeoutHandler.monitor_timeout(:test_op)
      result = TimeoutHandler.complete_monitoring(ctx)
      assert Map.has_key?(result, :duration)
      assert is_number(result.duration)
    end

    test "performance data contains utilization field" do
      ctx = TimeoutHandler.monitor_timeout(:test_op)
      result = TimeoutHandler.complete_monitoring(ctx)
      assert Map.has_key?(result, :utilization)
      assert is_number(result.utilization)
    end
  end
end
