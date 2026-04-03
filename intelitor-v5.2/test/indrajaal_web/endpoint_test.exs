defmodule IndrajaalWeb.EndpointTest do
  @moduledoc """
  Tests for IndrajaalWeb.Endpoint.

  WHAT: Verifies the Phoenix endpoint module is correctly defined.
  WHY: Ensures the application endpoint loads and is accessible.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-CMD-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Endpoint)
    end

    test "endpoint is a Phoenix.Endpoint" do
      # Phoenix.Endpoint behaviour defines url/0
      assert function_exported?(IndrajaalWeb.Endpoint, :url, 0)
    end

    test "endpoint defines struct_url/0" do
      assert function_exported?(IndrajaalWeb.Endpoint, :struct_url, 0)
    end

    test "endpoint defines path/1" do
      assert function_exported?(IndrajaalWeb.Endpoint, :path, 1)
    end

    test "endpoint defines static_url/0" do
      assert function_exported?(IndrajaalWeb.Endpoint, :static_url, 0)
    end
  end
end
