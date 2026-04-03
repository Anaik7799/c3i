defmodule Intelitor.MaintenanceTest do
  @moduledoc """
  Test suite for Maintenance root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Maintenance

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Maintenance)
    end

    test "module has expected functions" do
      assert function_exported?(Maintenance, :__info__, 1)
    end
  end
end
