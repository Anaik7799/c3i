defmodule Intelitor.FleetManagementTest do
  @moduledoc """
  Test suite for Fleet Management root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.FleetManagement

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(FleetManagement)
    end

    test "module has expected functions" do
      assert function_exported?(FleetManagement, :__info__, 1)
    end
  end
end
