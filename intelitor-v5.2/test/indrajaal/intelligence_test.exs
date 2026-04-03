defmodule Indrajaal.IntelligenceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Intelligence

  test "module exists" do
    assert Code.ensure_loaded?(Intelligence)
  end
end
