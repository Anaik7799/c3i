defmodule Indrajaal.IntelligenceContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.IntelligenceContext

  test "module exists" do
    assert Code.ensure_loaded?(IntelligenceContext)
  end
end
