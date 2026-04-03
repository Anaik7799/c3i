defmodule Indrajaal.Ecto.JSONTextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ecto.JSONText

  test "module exists" do
    assert Code.ensure_loaded?(JSONText)
  end

  test "cast/1 with map returns ok" do
    assert {:ok, _} = JSONText.cast(%{key: "value"})
  end

  test "cast/1 with binary parses json" do
    assert {:ok, _} = JSONText.cast(~s({"key":"value"}))
  end

  test "cast/1 with invalid input returns error" do
    assert :error = JSONText.cast(:not_json)
  end

  test "load/1 with binary parses json" do
    assert {:ok, _} = JSONText.load(~s({"key":"value"}))
  end

  test "dump/1 with map encodes json" do
    assert {:ok, json} = JSONText.dump(%{key: "value"})
    assert is_binary(json)
  end

  test "type/0 returns :string" do
    assert JSONText.type() == :string
  end
end
