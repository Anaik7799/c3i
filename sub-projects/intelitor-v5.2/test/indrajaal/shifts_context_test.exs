defmodule Indrajaal.ShiftsContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "Shifts context module exists" do
    assert Code.ensure_loaded?(Indrajaal.Shifts)
  end

  test "Shift resource module exists" do
    assert Code.ensure_loaded?(Indrajaal.Shifts.Shift)
  end
end
