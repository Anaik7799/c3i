defmodule Indrajaal.Intelligence.DHTTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(Indrajaal.Intelligence.DHT)
  end
end
