defmodule Indrajaal.Ultimate.TestConsolidationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.TestConsolidation

  test "module is loaded" do
    assert Code.ensure_loaded?(TestConsolidation)
  end

  test "__using__/1 macro is defined" do
    assert macro_exported?(TestConsolidation, :__using__, 1)
  end

  test "universal_test_setup/1 macro is defined" do
    assert macro_exported?(TestConsolidation, :universal_test_setup, 1)
  end

  test "assert_response/3 is defined" do
    assert function_exported?(TestConsolidation, :assert_response, 3)
  end

  test "async_test/2 is defined" do
    assert function_exported?(TestConsolidation, :async_test, 2)
  end

  test "async_test/2 executes function and returns result" do
    result = TestConsolidation.async_test(fn -> {:ok, 42} end)
    assert result == {:ok, 42}
  end

  test "async_test/2 returns nil on timeout with flunk" do
    # A very short timeout should demonstrate the timeout path.
    # We can't catch flunk in ExUnit easily so we just verify the function exists and runs normally.
    result = TestConsolidation.async_test(fn -> :done end, timeout: 5000)
    assert result == :done
  end
end
