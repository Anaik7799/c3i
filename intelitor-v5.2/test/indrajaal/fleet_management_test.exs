defmodule Indrajaal.FleetManagementTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FleetManagement

  test "module exists" do
    assert Code.ensure_loaded?(FleetManagement)
  end

  test "list_fleet/1 is exported" do
    assert function_exported?(FleetManagement, :list_fleet, 1)
  end
end
