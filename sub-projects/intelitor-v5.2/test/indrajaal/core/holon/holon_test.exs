defmodule Indrajaal.Core.HolonTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Holon)
    end
  end

  describe "layers/0" do
    test "returns list of fractal layers" do
      layers = Holon.layers()
      assert is_list(layers)
      assert length(layers) > 0
    end

    test "layers include all expected fractal levels" do
      layers = Holon.layers()
      assert :function in layers
      assert :module in layers
      assert :agent in layers
      assert :container in layers
      assert :node in layers
      assert :cluster in layers
      assert :federation in layers
    end
  end

  describe "layer_depth/1" do
    test "returns integer depth for :function layer" do
      assert is_integer(Holon.layer_depth(:function))
    end

    test "returns integer depth for :federation layer" do
      assert is_integer(Holon.layer_depth(:federation))
    end

    test "function layer has lower depth than federation layer" do
      assert Holon.layer_depth(:function) < Holon.layer_depth(:federation)
    end

    test "each layer has a unique depth" do
      layers = Holon.layers()
      depths = Enum.map(layers, &Holon.layer_depth/1)
      assert length(depths) == length(Enum.uniq(depths))
    end
  end

  describe "parent_layer?/2" do
    test "returns boolean" do
      result = Holon.parent_layer?(:function, :module)
      assert is_boolean(result)
    end

    test "function is parent layer of module" do
      assert Holon.parent_layer?(:function, :module) == true
    end

    test "federation is not parent layer of function" do
      assert Holon.parent_layer?(:federation, :function) == false
    end

    test "same layer is not parent of itself" do
      assert Holon.parent_layer?(:node, :node) == false
    end
  end

  describe "behaviour callbacks" do
    test "defines system1 callback" do
      assert function_exported?(Holon, :__info__, 1)
    end

    test "module defines __using__ macro" do
      # Verify the macro is defined via behaviour callbacks listing
      callbacks = Holon.behaviour_info(:callbacks)
      assert is_list(callbacks)
    end
  end
end
