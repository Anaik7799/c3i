defmodule Indrajaal.MaintenanceContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MaintenanceContext

  test "module exists" do
    assert Code.ensure_loaded?(MaintenanceContext)
  end
end
