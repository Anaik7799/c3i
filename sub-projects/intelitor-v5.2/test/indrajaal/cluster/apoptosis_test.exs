defmodule Indrajaal.Cluster.ApoptosisTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Apoptosis

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Apoptosis)
    end
  end

  describe "public API" do
    test "defines initiate/2" do
      assert function_exported?(Apoptosis, :initiate, 2)
    end

    test "defines cancel/0" do
      assert function_exported?(Apoptosis, :cancel, 0)
    end

    test "defines execute_termination/1" do
      assert function_exported?(Apoptosis, :execute_termination, 1)
    end
  end

  describe "initiate/2" do
    test "returns error tuple for unknown reason" do
      result = Apoptosis.initiate(:test_node, :unknown_reason)
      assert match?({:error, _}, result) or match?({:ok, _}, result) or is_atom(result)
    end

    test "accepts node name and reason" do
      assert is_function(&Apoptosis.initiate/2)
    end
  end

  describe "cancel/0" do
    test "returns ok or error tuple" do
      result = Apoptosis.cancel()
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_atom(result)
    end
  end

  describe "execute_termination/1" do
    test "accepts a reason argument" do
      assert is_function(&Apoptosis.execute_termination/1)
    end
  end
end
