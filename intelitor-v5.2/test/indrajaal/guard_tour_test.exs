defmodule Indrajaal.GuardTourTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.GuardTour

  test "module exists" do
    assert Code.ensure_loaded?(GuardTour)
  end

  test "is an Ash.Domain" do
    assert function_exported?(GuardTour, :spark_dsl_config, 0)
  end
end
