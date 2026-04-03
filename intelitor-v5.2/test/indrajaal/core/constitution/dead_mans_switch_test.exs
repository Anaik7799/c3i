defmodule Indrajaal.Core.Constitution.DeadMansSwitchTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core.Constitution.DeadMansSwitch.
  STAMP: SC-CONST-007, Ψ₄
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Constitution.DeadMansSwitch

  describe "sterility_status/0" do
    test "returns a status atom or map" do
      result = DeadMansSwitch.sterility_status()
      assert is_atom(result) or is_map(result) or match?({:ok, _}, result)
    end
  end

  describe "can_replicate?/0" do
    test "returns a boolean" do
      result = DeadMansSwitch.can_replicate?()
      assert is_boolean(result)
    end
  end

  describe "derive_replication_key/0" do
    test "returns a binary or error" do
      result = DeadMansSwitch.derive_replication_key()

      assert is_binary(result) or match?({:ok, key} when is_binary(key), result) or
               match?({:error, _}, result)
    end
  end

  describe "attempt_replication/0" do
    test "returns ok or error tuple" do
      result = DeadMansSwitch.attempt_replication()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "function exports" do
    test "sterility_status/0 exported" do
      assert function_exported?(DeadMansSwitch, :sterility_status, 0)
    end

    test "can_replicate?/0 exported" do
      assert function_exported?(DeadMansSwitch, :can_replicate?, 0)
    end

    test "derive_replication_key/0 exported" do
      assert function_exported?(DeadMansSwitch, :derive_replication_key, 0)
    end

    test "attempt_replication/0 exported" do
      assert function_exported?(DeadMansSwitch, :attempt_replication, 0)
    end
  end
end
