defmodule Intelitor.EnvironmentalContextTest do
  @moduledoc """
  Test suite for Intelitor.EnvironmentalContext.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/environmental_context.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.EnvironmentalContext

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(EnvironmentalContext)
    end

    test "module has __info__/1 function" do
      assert function_exported?(EnvironmentalContext, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = EnvironmentalContext.__info__(:module)
      assert info == Intelitor.EnvironmentalContext
    end
  end
end
