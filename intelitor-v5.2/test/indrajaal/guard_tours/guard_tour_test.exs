defmodule Indrajaal.GuardTours.GuardTourTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.GuardTours.GuardTour

  test "module exists" do
    assert Code.ensure_loaded?(GuardTour)
  end

  test "is an Ecto schema" do
    assert function_exported?(GuardTour, :__schema__, 1)
  end
end
