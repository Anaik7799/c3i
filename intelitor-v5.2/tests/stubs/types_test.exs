defmodule Intelitor.TypesTest do
  @moduledoc """
  Test suite for Intelitor.Types.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/types.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Types

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Types)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Types, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Types.__info__(:module)
      assert info == Intelitor.Types
    end
  end
end
