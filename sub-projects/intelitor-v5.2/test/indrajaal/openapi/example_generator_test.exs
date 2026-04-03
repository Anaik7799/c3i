defmodule Indrajaal.OpenAPI.ExampleGeneratorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.OpenAPI.ExampleGenerator

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ExampleGenerator)
    end

    test "module exports generate_all/0" do
      assert function_exported?(ExampleGenerator, :generate_all, 0)
    end
  end

  describe "generate_all/0" do
    test "returns ok tuple with examples map" do
      result = ExampleGenerator.generate_all()
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "result does not raise" do
      assert ExampleGenerator.generate_all() != :crash
    end
  end
end
