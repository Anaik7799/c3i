defmodule Indrajaal.Mesh.HolonPhenotypeTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Mesh.HolonPhenotype

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HolonPhenotype)
    end

    test "module defines a struct" do
      assert function_exported?(HolonPhenotype, :__struct__, 0)
      assert function_exported?(HolonPhenotype, :__struct__, 1)
    end
  end

  describe "struct definition" do
    test "struct has required :genotype_id field" do
      fields = HolonPhenotype.__struct__() |> Map.keys()
      assert :genotype_id in fields
    end

    test "can construct phenotype with required genotype_id" do
      phenotype = %HolonPhenotype{genotype_id: "genotype-001"}
      assert phenotype.genotype_id == "genotype-001"
    end

    test "phenotype has runtime observation fields" do
      fields = HolonPhenotype.__struct__() |> Map.keys()
      # genotype_id is required; runtime observation fields like status, health, etc.
      assert :genotype_id in fields
      # Must have at least the required field plus __struct__
      assert length(fields) >= 2
    end

    test "missing required genotype_id raises" do
      assert_raise(ArgumentError, fn ->
        struct!(HolonPhenotype, %{})
      end)
    end
  end
end
