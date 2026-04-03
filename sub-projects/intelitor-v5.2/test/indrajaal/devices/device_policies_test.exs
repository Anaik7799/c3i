defmodule Indrajaal.Devices.DevicePoliciesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Devices.DevicePolicies

  test "module exists" do
    assert Code.ensure_loaded?(DevicePolicies)
  end

  test "provides common_policies macro" do
    assert macro_exported?(DevicePolicies, :common_policies, 0)
  end
end
