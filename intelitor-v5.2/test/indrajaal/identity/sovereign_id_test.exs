defmodule Indrajaal.Identity.SovereignIDTest do
  use ExUnit.Case
  alias Indrajaal.Identity.SovereignID

  test "create_identity returns DID" do
    {:ok, did} = SovereignID.create_identity(%{})
    assert String.starts_with?(did, "did:indrajaal:")
  end
end
