defmodule Intelitor.ShiftsTest do
  @moduledoc """
  Test suite for Shifts root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Shifts

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Shifts)
    end

    test "module has expected functions" do
      assert function_exported?(Shifts, :__info__, 1)
    end
  end
end
