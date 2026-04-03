defmodule Indrajaal.DevicesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Devices

  test "module exists" do
    assert Code.ensure_loaded?(Devices)
  end

  test "is an Ash.Domain via BaseDomain" do
    assert function_exported?(Devices, :spark_dsl_config, 0)
  end
end
