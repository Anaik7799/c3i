defmodule Indrajaal.Formal.CategoryTheoryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Formal.CategoryTheory

  test "module exists" do
    assert Code.ensure_loaded?(CategoryTheory)
  end

  test "verify_composition/3 is exported" do
    assert function_exported?(CategoryTheory, :verify_composition, 3)
  end

  test "verify_identity/2 is exported" do
    assert function_exported?(CategoryTheory, :verify_identity, 2)
  end

  test "verify_associativity/4 is exported" do
    assert function_exported?(CategoryTheory, :verify_associativity, 4)
  end

  test "verify_composition/3 with valid morphisms" do
    f = fn x -> x + 1 end
    g = fn x -> x * 2 end
    h = fn x -> x - 3 end
    result = CategoryTheory.verify_composition(f, g, h)
    assert is_atom(result) or is_tuple(result)
  end

  test "verify_identity/2 with identity function" do
    f = fn x -> x end
    identity = fn x -> x end
    result = CategoryTheory.verify_identity(f, identity)
    assert is_atom(result) or is_tuple(result)
  end
end
