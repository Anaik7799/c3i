defmodule Intelitor.ShiftsContextTest do
  @moduledoc """
  Test suite for Intelitor.ShiftsContext.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/shifts_context.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.ShiftsContext

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ShiftsContext)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ShiftsContext, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ShiftsContext.__info__(:module)
      assert info == Intelitor.ShiftsContext
    end
  end
end
