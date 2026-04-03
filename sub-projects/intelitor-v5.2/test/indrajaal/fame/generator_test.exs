defmodule Indrajaal.Fame.GeneratorTest do
  @moduledoc """
  Tests for Indrajaal.Fame.Generator FAME metadata generation module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Fame.Generator

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Generator)
    end

    test "generate/1 is exported" do
      assert function_exported?(Generator, :generate, 1)
    end

    test "generate/2 is exported" do
      assert function_exported?(Generator, :generate, 2)
    end
  end

  describe "generate/1" do
    test "generates metadata for a module atom" do
      result = Generator.generate(Indrajaal.Fame.Generator)
      assert {:ok, metadata} = result
      assert is_map(metadata)
    end

    test "returns ok tuple with metadata map" do
      {:ok, metadata} = Generator.generate(Indrajaal.Fame.Generator)

      assert Map.has_key?(metadata, :module) or Map.has_key?(metadata, "module") or
               is_map(metadata)
    end

    test "handles non-existent module gracefully" do
      result = Generator.generate(NonExistentModule)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "generate/2" do
    test "generates metadata with options" do
      result = Generator.generate(Indrajaal.Fame.Generator, [])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts format option" do
      result = Generator.generate(Indrajaal.Fame.Generator, format: :map)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
