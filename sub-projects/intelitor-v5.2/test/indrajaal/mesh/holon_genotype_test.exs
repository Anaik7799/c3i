defmodule Indrajaal.Mesh.HolonGenotypeTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Mesh.HolonGenotype

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HolonGenotype)
    end

    test "module defines a struct" do
      assert function_exported?(HolonGenotype, :__struct__, 0)
      assert function_exported?(HolonGenotype, :__struct__, 1)
    end
  end

  describe "struct definition" do
    test "struct has required :id field" do
      fields = HolonGenotype.__struct__() |> Map.keys()
      assert :id in fields
    end

    test "struct has required :name field" do
      fields = HolonGenotype.__struct__() |> Map.keys()
      assert :name in fields
    end

    test "struct has required :role field" do
      fields = HolonGenotype.__struct__() |> Map.keys()
      assert :role in fields
    end

    test "struct has required :image field" do
      fields = HolonGenotype.__struct__() |> Map.keys()
      assert :image in fields
    end

    test "can construct a genotype with required fields" do
      genotype = %HolonGenotype{
        id: "genotype-001",
        name: "indrajaal-db-prod",
        role: :database,
        image: "localhost/indrajaal-db:latest"
      }

      assert genotype.id == "genotype-001"
      assert genotype.name == "indrajaal-db-prod"
      assert genotype.role == :database
      assert genotype.image == "localhost/indrajaal-db:latest"
    end

    test "missing required field raises KeyError or ArgumentError" do
      assert_raise(ArgumentError, fn ->
        struct!(HolonGenotype, %{id: "g1", name: "n1"})
      end)
    end
  end
end
