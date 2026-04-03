defmodule Indrajaal.Fractal.L5.NifSafetyTest do
  use ExUnit.Case, async: true
  use PropCheck
  alias Indrajaal.Safety.LineageAuth

  @moduledoc """
  Layer 5: Safety/Chaos Testing.
  Uses PropCheck to fuzz inputs and ensure no BEAM crashes.
  """

  @tag :nif
  @tag :safety
  property "lineage_auth handles random binary garbage" do
    forall {pk, msg, sig} <- {binary(), binary(), binary()} do
      # The NIF should return false or raise an ArgumentError (handled by Rustler),
      # but NEVER segfault or crash the VM.
      try do
        LineageAuth.verify_signature(pk, msg, sig)
        true
      rescue
        ArgumentError -> true
        _ -> false
      end
    end
  end
end
