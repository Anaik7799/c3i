defmodule Indrajaal.Formal.RuntimeTypeVerifierTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Formal.RuntimeTypeVerifier

  test "module exists" do
    assert Code.ensure_loaded?(RuntimeTypeVerifier)
  end

  test "check_morphism/2 is exported" do
    assert function_exported?(RuntimeTypeVerifier, :check_morphism, 2)
  end

  test "verify_functor_laws/3 is exported" do
    assert function_exported?(RuntimeTypeVerifier, :verify_functor_laws, 3)
  end
end
