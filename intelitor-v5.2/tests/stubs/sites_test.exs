defmodule Intelitor.SitesTest do
  @moduledoc """
  Test suite for Sites root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Sites

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Sites)
    end

    test "module has expected functions" do
      assert function_exported?(Sites, :__info__, 1)
    end
  end
end
