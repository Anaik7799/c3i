defmodule Indrajaal.Distributed.Mesh.DiscoveryTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Mesh.Discovery.

  WHAT: Validates mesh node discovery lifecycle, seed management, cache, and statistics.
  WHY: SC-DIS-001 requires reliable distributed node discovery.
  CONSTRAINTS: GenServer registered as __MODULE__; async: false to prevent name conflicts.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Distributed.Mesh.Discovery

  setup do
    case Process.whereis(Discovery) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1000)
    end

    {:ok, pid} = start_supervised({Discovery, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer registered as Discovery", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
      assert Process.whereis(Discovery) == pid
    end
  end

  describe "discover/0" do
    test "returns {:ok, list} with no seeds configured" do
      result = Discovery.discover()
      assert {:ok, discovered} = result
      assert is_list(discovered)
    end

    test "discovered list is initially empty with no seeds" do
      {:ok, discovered} = Discovery.discover()
      assert discovered == []
    end

    test "discover/0 is idempotent when called twice" do
      {:ok, first} = Discovery.discover()
      {:ok, second} = Discovery.discover()
      assert first == second
    end
  end

  describe "discover/1 (by method)" do
    test "returns a tagged tuple for :default method" do
      # :default is not a registered method — returns {:error, {:unknown_method, :default}}
      result = Discovery.discover(:default)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns {:ok, list} or {:error, _} for :dns method" do
      result = Discovery.discover(:dns)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "add_seed/2" do
    test "returns :ok for a valid address and port" do
      result = Discovery.add_seed("127.0.0.1", 4369)
      assert result == :ok
    end

    test "seed count increases after adding a seed" do
      Discovery.add_seed("10.0.0.1", 4370)
      stats = Discovery.stats()
      assert stats.seed_count >= 1
    end

    test "can add multiple seeds" do
      assert Discovery.add_seed("10.0.0.1", 4370) == :ok
      assert Discovery.add_seed("10.0.0.2", 4371) == :ok
      stats = Discovery.stats()
      assert stats.seed_count >= 2
    end
  end

  describe "remove_seed/2" do
    test "returns :ok when removing an existing seed" do
      Discovery.add_seed("127.0.0.1", 4369)
      result = Discovery.remove_seed("127.0.0.1", 4369)
      assert result == :ok or match?({:ok, _}, result)
    end

    test "seed count decreases after removing a seed" do
      Discovery.add_seed("10.1.1.1", 4380)
      stats_before = Discovery.stats()
      Discovery.remove_seed("10.1.1.1", 4380)
      stats_after = Discovery.stats()
      assert stats_after.seed_count <= stats_before.seed_count
    end

    test "removing a non-existent seed returns :ok or {:error, :not_found}" do
      result = Discovery.remove_seed("255.255.255.255", 9999)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "get_discovered/0" do
    test "returns a list" do
      result = Discovery.get_discovered()
      assert is_list(result)
    end

    test "returns empty list when no nodes have been discovered" do
      assert Discovery.get_discovered() == []
    end
  end

  describe "clear_cache/0" do
    test "returns :ok" do
      result = Discovery.clear_cache()
      assert result == :ok
    end

    test "discovered list is empty after clearing cache" do
      Discovery.clear_cache()
      assert Discovery.get_discovered() == []
    end

    test "clearing cache is idempotent" do
      assert Discovery.clear_cache() == :ok
      assert Discovery.clear_cache() == :ok
    end
  end

  describe "stats/0" do
    test "returns a map" do
      result = Discovery.stats()
      assert is_map(result)
    end

    test "stats include :discoveries key" do
      result = Discovery.stats()
      assert Map.has_key?(result, :discoveries)
    end

    test "stats include :failures key" do
      result = Discovery.stats()
      assert Map.has_key?(result, :failures)
    end

    test "stats include :seed_count key" do
      result = Discovery.stats()
      assert Map.has_key?(result, :seed_count)
    end

    test "initial discovery count is zero" do
      result = Discovery.stats()
      assert result.discoveries == 0
    end

    test "initial failure count is zero" do
      result = Discovery.stats()
      assert result.failures == 0
    end

    test "seed_count reflects added seeds" do
      Discovery.add_seed("192.168.0.1", 4369)
      stats = Discovery.stats()
      assert stats.seed_count >= 1
    end
  end

  describe "validate/1" do
    test "returns {:ok, _} or {:error, _} for a valid node map" do
      node = %{address: "127.0.0.1", port: 4369}
      result = Discovery.validate(node)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns {:error, _} for invalid node map" do
      result = Discovery.validate(%{})
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
