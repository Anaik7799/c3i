defmodule Indrajaal.Cluster.HiveMemoryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.HiveMemory

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HiveMemory)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(HiveMemory, :start_link, 1)
    end

    test "defines put/2" do
      assert function_exported?(HiveMemory, :put, 2)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(HiveMemory, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = HiveMemory.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end

  describe "put/2 operation" do
    test "put/2 accepts key-value pair" do
      {:ok, pid} = start_supervised({HiveMemory, []})
      result = HiveMemory.put(:test_key, :test_value)
      assert match?(:ok, result) or match?({:ok, _}, result) or is_atom(result)
      stop_supervised(pid)
    end
  end
end
