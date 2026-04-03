defmodule Indrajaal.FLAME.SafeRunnerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FLAME.SafeRunner

  describe "guard_state/0" do
    test "returns :ok when process dictionary has no user keys" do
      # Standard OTP keys like $initial_call are always present and safe
      assert :ok = SafeRunner.guard_state()
    end

    test "returns :ok even when standard OTP process dictionary keys are present" do
      # $initial_call, $ancestors, $callers are filtered as safe by the implementation
      Process.put(:"$initial_call", {SafeRunnerTest, :test, 0})
      result = SafeRunner.guard_state()
      assert result == :ok
    after
      Process.delete(:"$initial_call")
    end

    test "still returns :ok when user keys are present (warns but does not raise)" do
      # The implementation logs a warning but does not raise — returns :ok
      Process.put(:my_custom_state, "some_value")
      result = SafeRunner.guard_state()
      assert result == :ok
    after
      Process.delete(:my_custom_state)
    end

    test "returns :ok with multiple user keys in process dictionary" do
      Process.put(:key_one, 1)
      Process.put(:key_two, 2)
      result = SafeRunner.guard_state()
      assert result == :ok
    after
      Process.delete(:key_one)
      Process.delete(:key_two)
    end

    test "return value is always the atom :ok" do
      assert is_atom(SafeRunner.guard_state())
      assert SafeRunner.guard_state() == :ok
    end
  end
end
