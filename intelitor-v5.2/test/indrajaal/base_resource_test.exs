defmodule Indrajaal.BaseResourceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.BaseResource

  test "module exists" do
    assert Code.ensure_loaded?(BaseResource)
  end

  test "provides __using__ macro" do
    assert macro_exported?(BaseResource, :__using__, 1)
  end
end
