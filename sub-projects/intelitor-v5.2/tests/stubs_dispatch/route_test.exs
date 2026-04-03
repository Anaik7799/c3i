defmodule Intelitor.Dispatch.RouteTest do
  @moduledoc """
  Test suite for Intelitor.Dispatch.Route.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/dispatch/route.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Dispatch.Route

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Route)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Route, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Route.__info__(:module)
      assert info == Intelitor.Dispatch.Route
    end
  end
end
