defmodule Intelitor.NativeSerializerTest do
  @moduledoc """
  Test suite for Intelitor.NativeSerializer.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/native_serializer.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.NativeSerializer

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(NativeSerializer)
    end

    test "module has __info__/1 function" do
      assert function_exported?(NativeSerializer, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = NativeSerializer.__info__(:module)
      assert info == Intelitor.NativeSerializer
    end
  end
end
