defmodule Indrajaal.Distributed.Mesh.HolographyTest do
  @moduledoc """
  Tests for Indrajaal.Distributed.Mesh.Holography.

  WHAT: Validates distributed holographic state put/get/delete and replication stats.
  WHY: SC-HOL-001 requires state to be recoverable from N-1 nodes.
  CONSTRAINTS: GenServer registered as __MODULE__; async: false to prevent name conflicts.
  Note: Holography.put/3 calls Mycelium.nodes() inside replicate/4.
        Mycelium must be started before Holography.
        All puts use consistency: :one so required = 0 and puts succeed with 0 alive nodes.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Distributed.Mesh.{Holography, Mycelium}

  setup do
    for mod <- [Holography, Mycelium] do
      case Process.whereis(mod) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 1000)
      end
    end

    # Mycelium must start first — Holography.put/3 calls Mycelium.nodes() during replication
    {:ok, _mycelium_pid} = start_supervised({Mycelium, []})
    {:ok, pid} = start_supervised({Holography, []})
    %{pid: pid}
  end

  describe "start_link/1" do
    test "starts and registers the GenServer", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
      assert Process.whereis(Holography) == pid
    end
  end

  describe "put/3" do
    test "returns {:ok, version} for a new key" do
      result = Holography.put(:my_key, "hello", consistency: :one)
      assert match?({:ok, version} when is_integer(version), result)
    end

    test "version starts at 1 for a new key" do
      {:ok, version} = Holography.put(:fresh_key, "value", consistency: :one)
      assert version == 1
    end

    test "version increments on repeated puts for same key" do
      {:ok, v1} = Holography.put(:counter_key, 1, consistency: :one)
      {:ok, v2} = Holography.put(:counter_key, 2, consistency: :one)
      assert v2 > v1
    end

    test "stores map values" do
      result = Holography.put(:config, %{debug: true, env: :test}, consistency: :one)
      assert match?({:ok, _}, result)
    end

    test "stores list values" do
      result = Holography.put(:tags, [:a, :b, :c], consistency: :one)
      assert match?({:ok, _}, result)
    end

    test "stores nil value" do
      result = Holography.put(:nullable, nil, consistency: :one)
      assert match?({:ok, _}, result)
    end
  end

  describe "get/2" do
    test "returns {:error, :not_found} for an unknown key" do
      result = Holography.get(:nonexistent_key_xyz_123)
      assert result == {:error, :not_found}
    end

    test "returns {:ok, value, version} for a key that was put" do
      Holography.put(:readable_key, "stored_value", consistency: :one)
      result = Holography.get(:readable_key)
      assert match?({:ok, "stored_value", _version}, result)
    end

    test "retrieved value matches stored value for map" do
      data = %{x: 1, y: 2}
      Holography.put(:map_key, data, consistency: :one)
      {:ok, retrieved, _version} = Holography.get(:map_key)
      assert retrieved == data
    end

    test "retrieved version matches put version" do
      {:ok, put_version} = Holography.put(:version_key, "v", consistency: :one)
      {:ok, _val, get_version} = Holography.get(:version_key)
      assert get_version == put_version
    end

    test "version increments correctly across multiple puts" do
      Holography.put(:evolving, "v1", consistency: :one)
      {:ok, v2} = Holography.put(:evolving, "v2", consistency: :one)
      {:ok, retrieved, version} = Holography.get(:evolving)
      assert retrieved == "v2"
      assert version == v2
    end
  end

  describe "delete/1" do
    test "returns :ok for an existing key" do
      Holography.put(:to_delete, "bye", consistency: :one)
      result = Holography.delete(:to_delete)
      assert result == :ok
    end

    test "key is not found after deletion" do
      Holography.put(:gone_key, "data", consistency: :one)
      Holography.delete(:gone_key)
      result = Holography.get(:gone_key)
      assert result == {:error, :not_found}
    end

    test "returns :ok for a key that does not exist" do
      result = Holography.delete(:never_existed_key_xyz)
      assert result == :ok
    end

    test "delete is idempotent" do
      Holography.put(:multi_delete, "x", consistency: :one)
      assert Holography.delete(:multi_delete) == :ok
      assert Holography.delete(:multi_delete) == :ok
    end
  end

  describe "keys/0" do
    test "returns a list" do
      result = Holography.keys()
      assert is_list(result)
    end

    test "initially returns an empty list" do
      result = Holography.keys()
      assert result == []
    end

    test "contains key after put" do
      Holography.put(:presence_key, "here", consistency: :one)
      keys = Holography.keys()
      assert :presence_key in keys
    end

    test "does not contain key after delete" do
      Holography.put(:ephemeral, "x", consistency: :one)
      Holography.delete(:ephemeral)
      keys = Holography.keys()
      refute :ephemeral in keys
    end

    test "reflects multiple stored keys" do
      Holography.put(:k1, 1, consistency: :one)
      Holography.put(:k2, 2, consistency: :one)
      keys = Holography.keys()
      assert :k1 in keys
      assert :k2 in keys
    end
  end

  describe "replication_status/1" do
    test "returns {:error, :not_found} for an unknown key" do
      result = Holography.replication_status(:no_such_key)
      assert result == {:error, :not_found}
    end

    test "returns {:ok, map} for an existing key" do
      Holography.put(:replicated_key, "data", consistency: :one)
      result = Holography.replication_status(:replicated_key)
      assert match?({:ok, status} when is_map(status), result)
    end

    test "replication status map includes :key" do
      Holography.put(:status_key, 99, consistency: :one)
      {:ok, status} = Holography.replication_status(:status_key)
      assert Map.has_key?(status, :key)
      assert status.key == :status_key
    end

    test "replication status map includes :version" do
      Holography.put(:ver_key, "v", consistency: :one)
      {:ok, status} = Holography.replication_status(:ver_key)
      assert Map.has_key?(status, :version)
      assert is_integer(status.version)
    end
  end

  describe "stats/0" do
    test "returns a map" do
      result = Holography.stats()
      assert is_map(result)
    end

    test "stats include :reads key" do
      result = Holography.stats()
      assert Map.has_key?(result, :reads)
    end

    test "stats include :writes key" do
      result = Holography.stats()
      assert Map.has_key?(result, :writes)
    end

    test "stats include :syncs key" do
      result = Holography.stats()
      assert Map.has_key?(result, :syncs)
    end

    test "initial write count is zero" do
      result = Holography.stats()
      assert result.writes == 0
    end

    test "write count increases after put" do
      Holography.put(:stats_write_key, "x", consistency: :one)
      stats = Holography.stats()
      assert stats.writes >= 1
    end
  end
end
