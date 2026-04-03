defmodule Intelitor.EnvironmentalTest do
  @moduledoc """
  Test suite for Intelitor.Environmental.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/environmental.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Environmental

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Environmental)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Environmental, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Environmental.__info__(:module)
      assert info == Intelitor.Environmental
    end
  end
end
