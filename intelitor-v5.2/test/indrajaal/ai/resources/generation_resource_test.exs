defmodule Indrajaal.AI.Resources.GenerationResourceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AI.Resources.GenerationResource

  test "module exists" do
    assert Code.ensure_loaded?(GenerationResource)
  end

  test "is an Ash.Resource" do
    assert function_exported?(GenerationResource, :spark_dsl_config, 0)
  end
end
