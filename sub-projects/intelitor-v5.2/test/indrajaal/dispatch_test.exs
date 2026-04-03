defmodule Indrajaal.DispatchTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Dispatch

  test "module exists" do
    assert Code.ensure_loaded?(Dispatch)
  end

  test "is an Ash.Domain via BaseDomain" do
    assert function_exported?(Dispatch, :spark_dsl_config, 0)
  end
end
