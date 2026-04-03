defmodule Indrajaal.BillingTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Billing

  test "module exists" do
    assert Code.ensure_loaded?(Billing)
  end

  test "is an Ash.Domain" do
    assert function_exported?(Billing, :spark_dsl_config, 0)
  end
end
