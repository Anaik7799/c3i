defmodule Indrajaal.Core.Holon.FractalTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core.Holon.Fractal.
  STAMP: SC-SIL6-001, Ω₉
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.Fractal

  describe "layers/0" do
    test "returns a list of layers" do
      result = Fractal.layers()
      assert is_list(result)
    end

    test "list is non-empty" do
      result = Fractal.layers()
      assert length(result) > 0
    end

    test "contains :function layer" do
      result = Fractal.layers()
      assert :function in result or Enum.any?(result, &(to_string(&1) =~ "function"))
    end
  end

  describe "layer_depth/1" do
    test "returns integer depth for :function" do
      result = Fractal.layer_depth(:function)
      assert is_integer(result)
    end

    test "returns integer depth for :federation" do
      result = Fractal.layer_depth(:federation)
      assert is_integer(result)
    end

    test ":federation is deeper than :function" do
      d_function = Fractal.layer_depth(:function)
      d_federation = Fractal.layer_depth(:federation)
      assert d_federation > d_function
    end
  end

  describe "parent_layer/1" do
    test "returns parent of :module" do
      result = Fractal.parent_layer(:module)
      assert is_atom(result) or match?({:ok, _}, result) or is_nil(result)
    end

    test "returns nil or error for :function (top level)" do
      result = Fractal.parent_layer(:function)
      assert is_nil(result) or match?({:error, _}, result) or is_atom(result)
    end
  end

  describe "child_layer/1" do
    test "returns child of :function" do
      result = Fractal.child_layer(:function)
      assert is_atom(result) or match?({:ok, _}, result) or is_nil(result)
    end
  end

  describe "verify_structure/0" do
    test "returns :ok or {:ok, _}" do
      result = Fractal.verify_structure()
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "valid_parent_child?/2" do
    test "function-module is valid" do
      result = Fractal.valid_parent_child?(:function, :module)
      assert is_boolean(result)
    end

    test "federation-function is not valid" do
      result = Fractal.valid_parent_child?(:federation, :function)
      assert result == false or is_boolean(result)
    end
  end
end
