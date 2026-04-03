defmodule Indrajaal.IntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration

  test "module exists" do
    assert Code.ensure_loaded?(Integration)
  end
end
