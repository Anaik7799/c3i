defmodule Indrajaal.AI.Resources.ChatResourceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AI.Resources.ChatResource

  test "module exists" do
    assert Code.ensure_loaded?(ChatResource)
  end

  test "is an Ash.Resource" do
    assert function_exported?(ChatResource, :spark_dsl_config, 0)
  end
end
