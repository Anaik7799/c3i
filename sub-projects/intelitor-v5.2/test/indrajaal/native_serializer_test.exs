defmodule Indrajaal.NativeSerializerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.NativeSerializer

  test "module exists" do
    assert Code.ensure_loaded?(NativeSerializer)
  end

  test "validate_integrity/1 is exported" do
    assert function_exported?(NativeSerializer, :validate_integrity, 1)
  end

  test "validate_integrity/1 with valid data returns ok" do
    assert {:ok, _} = NativeSerializer.validate_integrity(%{type: "test", data: "value"})
  end

  test "validate_integrity/1 with nil returns error" do
    assert {:error, _} = NativeSerializer.validate_integrity(nil)
  end
end
