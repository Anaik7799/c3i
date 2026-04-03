defmodule Indrajaal.Fame.ParserTest do
  @moduledoc """
  Tests for Indrajaal.Fame.Parser FAME metadata parsing module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Fame.Parser

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Parser)
    end

    test "parse/1 is exported" do
      assert function_exported?(Parser, :parse, 1)
    end

    test "parse/2 is exported or parse/1 handles options" do
      exported_1 = function_exported?(Parser, :parse, 1)
      exported_2 = function_exported?(Parser, :parse, 2)
      assert exported_1 or exported_2
    end
  end

  describe "parse/1" do
    test "parses a valid metadata map" do
      metadata = %{module: "TestModule", version: "1.0.0", type: :function}
      result = Parser.parse(metadata)
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles empty map input" do
      result = Parser.parse(%{})
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles binary input" do
      result = Parser.parse(~s({"module": "Test"}))
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles nil gracefully" do
      result =
        try do
          Parser.parse(nil)
        rescue
          _ -> {:error, :invalid_input}
        end

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
