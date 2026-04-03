defmodule Indrajaal.Fractal.L4.NifStressTest do
  use ExUnit.Case, async: true
  alias Indrajaal.Safety.LineageAuth

  @moduledoc """
  Layer 4: Stress/Performance Testing.
  Loops NIF calls to check for memory leaks or scheduler blocking.
  """

  @tag :nif
  @tag :stress
  test "lineage_auth rapid fire" do
    pub_key = :crypto.strong_rand_bytes(32)
    sig = :crypto.strong_rand_bytes(64)
    msg = "Stress Test"

    # Run 1000 iterations
    for _i <- 1..1000 do
      assert LineageAuth.verify_signature(pub_key, msg, sig) == false
    end
  end
end
