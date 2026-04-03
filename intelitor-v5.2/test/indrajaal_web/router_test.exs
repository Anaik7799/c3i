defmodule IndrajaalWeb.RouterTest do
  @moduledoc """
  Tests for IndrajaalWeb.Router.

  WHAT: Verifies the Phoenix router module is correctly defined.
  WHY: Ensures route definitions are accessible and the router compiles.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Router)
    end

    test "router defines __routes__/0" do
      assert function_exported?(IndrajaalWeb.Router, :__routes__, 0)
    end

    test "routes list is non-empty" do
      routes = IndrajaalWeb.Router.__routes__()
      assert is_list(routes)
      assert length(routes) > 0
    end

    test "has health route" do
      routes = IndrajaalWeb.Router.__routes__()

      health_route =
        Enum.find(routes, fn route ->
          String.contains?(route.path, "health")
        end)

      assert health_route != nil
    end
  end
end
