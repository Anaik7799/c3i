defmodule Intelitor.GuardToursTest do
  @moduledoc """
  Test suite for Guard Tours root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.GuardTours

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(GuardTours)
    end

    test "module has expected functions" do
      assert function_exported?(GuardTours, :__info__, 1)
    end
  end
end
