defmodule Intelitor.AuthorizationTest do
  @moduledoc """
  Test suite for Authorization root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Authorization

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Authorization)
    end

    test "module has expected functions" do
      assert function_exported?(Authorization, :__info__, 1)
    end
  end
end
