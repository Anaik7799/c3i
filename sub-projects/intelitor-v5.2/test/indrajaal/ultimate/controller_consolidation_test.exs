defmodule Indrajaal.Ultimate.ControllerConsolidationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.ControllerConsolidation

  test "module is loaded" do
    assert Code.ensure_loaded?(ControllerConsolidation)
  end

  test "universal_action/3 macro is defined" do
    assert macro_exported?(ControllerConsolidation, :universal_action, 3)
  end
end
