defmodule Indrajaal.AccessControlDomainTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControlDomain

  test "module exists" do
    assert Code.ensure_loaded?(AccessControlDomain)
  end

  test "is an Ash.Domain" do
    assert function_exported?(AccessControlDomain, :spark_dsl_config, 0)
  end
end
