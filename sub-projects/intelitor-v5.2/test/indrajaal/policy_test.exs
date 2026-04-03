defmodule Indrajaal.PolicyTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Policy

  test "module exists" do
    assert Code.ensure_loaded?(Policy)
  end
end
