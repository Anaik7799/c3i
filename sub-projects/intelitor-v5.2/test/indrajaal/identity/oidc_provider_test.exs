defmodule Indrajaal.Identity.OidcProviderTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(Indrajaal.Identity.OidcProvider)
  end
end
