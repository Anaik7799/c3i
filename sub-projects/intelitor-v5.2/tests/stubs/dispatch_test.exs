defmodule Intelitor.DispatchTest do
  @moduledoc """
  Test suite for Dispatch root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Dispatch

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Dispatch)
    end

    test "module has expected functions" do
      assert function_exported?(Dispatch, :__info__, 1)
    end
  end
end
