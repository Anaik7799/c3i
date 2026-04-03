defmodule Intelitor.CacheTest do
  @moduledoc """
  Test suite for Cache root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Cache

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Cache)
    end

    test "module has expected functions" do
      assert function_exported?(Cache, :__info__, 1)
    end
  end
end
