defmodule Indrajaal.CommunicationDomainTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.CommunicationDomain

  test "module exists" do
    assert Code.ensure_loaded?(CommunicationDomain)
  end

  test "is an Ash.Domain" do
    assert function_exported?(CommunicationDomain, :spark_dsl_config, 0)
  end
end
