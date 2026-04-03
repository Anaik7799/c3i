defmodule Indrajaal.CrmTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm

  test "module exists" do
    assert Code.ensure_loaded?(Crm)
  end

  test "is an Ash.Domain" do
    assert function_exported?(Crm, :spark_dsl_config, 0)
  end
end
