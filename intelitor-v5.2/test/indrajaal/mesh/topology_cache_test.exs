defmodule Indrajaal.Mesh.TopologyCacheTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Mesh.TopologyCache

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TopologyCache)
    end

    test "module defines a struct" do
      assert function_exported?(TopologyCache, :__struct__, 0)
      assert function_exported?(TopologyCache, :__struct__, 1)
    end
  end

  describe "struct definition" do
    test "struct has required :version field" do
      fields = TopologyCache.__struct__() |> Map.keys()
      assert :version in fields
    end

    test "struct has required :config_hash field" do
      fields = TopologyCache.__struct__() |> Map.keys()
      assert :config_hash in fields
    end

    test "struct has required :start_order field" do
      fields = TopologyCache.__struct__() |> Map.keys()
      assert :start_order in fields
    end

    test "struct has required :shutdown_order field" do
      fields = TopologyCache.__struct__() |> Map.keys()
      assert :shutdown_order in fields
    end

    test "struct has required :created_at field" do
      fields = TopologyCache.__struct__() |> Map.keys()
      assert :created_at in fields
    end

    test "can construct a valid TopologyCache" do
      cache = %TopologyCache{
        version: 1,
        config_hash: "sha256abc",
        start_order: ["db", "obs", "app"],
        shutdown_order: ["app", "obs", "db"],
        created_at: DateTime.utc_now()
      }

      assert cache.version == 1
      assert is_binary(cache.config_hash)
      assert is_list(cache.start_order)
      assert is_list(cache.shutdown_order)
    end

    test "missing required field raises ArgumentError" do
      assert_raise(ArgumentError, fn ->
        struct!(TopologyCache, %{version: 1, config_hash: "abc"})
      end)
    end
  end
end
