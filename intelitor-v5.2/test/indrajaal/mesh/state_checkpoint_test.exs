defmodule Indrajaal.Mesh.StateCheckpointTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Mesh.StateCheckpoint

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(StateCheckpoint)
    end

    test "module defines a struct" do
      assert function_exported?(StateCheckpoint, :__struct__, 0)
      assert function_exported?(StateCheckpoint, :__struct__, 1)
    end
  end

  describe "struct definition" do
    test "struct has required :id field" do
      fields = StateCheckpoint.__struct__() |> Map.keys()
      assert :id in fields
    end

    test "struct has required :timestamp field" do
      fields = StateCheckpoint.__struct__() |> Map.keys()
      assert :timestamp in fields
    end

    test "struct has required :state_hash field" do
      fields = StateCheckpoint.__struct__() |> Map.keys()
      assert :state_hash in fields
    end

    test "struct has required :holons field" do
      fields = StateCheckpoint.__struct__() |> Map.keys()
      assert :holons in fields
    end

    test "can construct a valid StateCheckpoint" do
      checkpoint = %StateCheckpoint{
        id: "cp-001",
        timestamp: DateTime.utc_now(),
        state_hash: "abc123def456",
        holons: []
      }

      assert checkpoint.id == "cp-001"
      assert is_binary(checkpoint.state_hash)
      assert is_list(checkpoint.holons)
    end

    test "missing required field raises ArgumentError" do
      assert_raise(ArgumentError, fn ->
        struct!(StateCheckpoint, %{id: "cp-001"})
      end)
    end
  end
end
