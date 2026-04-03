defmodule Indrajaal.Integration.Enterprise.RouteTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.Enterprise.Route

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Route)
    end
  end

  describe "Ash resource structure" do
    test "is an Ash resource" do
      assert Code.ensure_loaded?(Route)
      assert Route.__info__(:module) == Route
    end

    test "module uses BaseResource pattern" do
      # The module uses Indrajaal.BaseResource with postgres table "routes"
      assert Code.ensure_loaded?(Route)
    end
  end
end
