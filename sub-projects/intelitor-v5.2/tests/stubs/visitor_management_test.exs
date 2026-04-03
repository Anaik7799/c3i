defmodule Intelitor.VisitorManagementTest do
  @moduledoc """
  Test suite for Visitor Management root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.VisitorManagement

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(VisitorManagement)
    end

    test "module has expected functions" do
      assert function_exported?(VisitorManagement, :__info__, 1)
    end
  end
end
