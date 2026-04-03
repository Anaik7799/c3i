defmodule Indrajaal.AssetManagementTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AssetManagement

  test "module exists" do
    assert Code.ensure_loaded?(AssetManagement)
  end

  test "is an Ash.Domain" do
    assert function_exported?(AssetManagement, :spark_dsl_config, 0)
  end
end
