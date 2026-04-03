defmodule Indrajaal.AI.Resources.SynapseResourceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AI.Resources.SynapseResource

  test "module exists" do
    assert Code.ensure_loaded?(SynapseResource)
  end

  test "is an Ash.Resource" do
    assert function_exported?(SynapseResource, :spark_dsl_config, 0)
  end
end
