defmodule Indrajaal.GuardToursContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.GuardToursContext

  test "module exists" do
    assert Code.ensure_loaded?(GuardToursContext)
  end
end
