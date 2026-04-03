defmodule Indrajaal.FleetManagementContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FleetManagementContext

  test "module exists" do
    assert Code.ensure_loaded?(FleetManagementContext)
  end
end
