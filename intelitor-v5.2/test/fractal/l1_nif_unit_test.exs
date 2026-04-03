defmodule Indrajaal.Fractal.L1.NifUnitTest do
  use ExUnit.Case, async: true
  alias Indrajaal.Native.Zenoh
  alias Indrajaal.Safety.LineageAuth

  @moduledoc """
  Layer 1: Unit Testing for NIFs.
  Verifies basic function calls and return types.
  """

  describe "Zenoh NIF L1" do
    test "check_nif_loaded/0 returns true" do
      # If NIF is not loaded, this will return false or raise
      assert Zenoh.check_nif_loaded() == true
    end

    test "declare_publisher/1 returns reference or error" do
      case Zenoh.declare_publisher("test/l1/key") do
        {:ok, ref} -> assert is_reference(ref)
        {:error, _} -> flunk("Failed to declare publisher")
      end
    end
  end

  describe "LineageAuth NIF L1" do
    test "verify_signature/3 handles valid inputs structure" do
      # We don't need a valid signature here, just testing the NIF boundary
      # An invalid signature should return false, not crash
      pub_key = :crypto.strong_rand_bytes(32)
      sig = :crypto.strong_rand_bytes(64)
      msg = "test"

      assert LineageAuth.verify_signature(pub_key, msg, sig) == false
    end
  end
end
