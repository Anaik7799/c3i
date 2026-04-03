defmodule Intelitor.IntegrationTest do
  @moduledoc """
  Test suite for Integration root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Integration

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Integration)
    end

    test "module has expected functions" do
      assert function_exported?(Integration, :__info__, 1)
    end
  end
end
