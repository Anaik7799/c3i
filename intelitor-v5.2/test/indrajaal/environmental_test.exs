defmodule Indrajaal.EnvironmentalTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Environmental

  test "module exists" do
    assert Code.ensure_loaded?(Environmental)
  end

  test "list_environmental/1 is exported" do
    assert function_exported?(Environmental, :list_environmental, 1)
  end

  test "get_sensor/2 is exported" do
    assert function_exported?(Environmental, :get_sensor, 2)
  end

  test "create_sensor/2 is exported" do
    assert function_exported?(Environmental, :create_sensor, 2)
  end
end
