defmodule Indrajaal.Video.Artery.JellyfishAdapterTest do
  @moduledoc """
  TDG-Compliant tests for JellyfishAdapter module.

  Tests SFU (Selective Forwarding Unit) fallback for symmetric NAT situations.

  STAMP Constraints:
  - SC-ARTERY-002: P2P preferred, SFU fallback
  - SC-ARTERY-003: Jellyfish SFU only when P2P fails
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Video.Artery.JellyfishAdapter

  describe "JellyfishAdapter.start_link/1" do
    test "starts adapter with server config" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      assert {:ok, pid} = JellyfishAdapter.start_link(name: :test_jf_1, config: config)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "JellyfishAdapter.create_room/2" do
    test "creates room for stream relay" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_2, config: config)

      {:ok, room} = JellyfishAdapter.create_room(adapter, "stream-1")

      assert room.room_id =~ ~r/^room-/
      assert room.stream_id == "stream-1"
      GenServer.stop(adapter)
    end

    test "returns existing room if already created" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_3, config: config)

      {:ok, room1} = JellyfishAdapter.create_room(adapter, "stream-1")
      {:ok, room2} = JellyfishAdapter.create_room(adapter, "stream-1")

      assert room1.room_id == room2.room_id
      GenServer.stop(adapter)
    end
  end

  describe "JellyfishAdapter.add_peer/3" do
    test "adds peer to room" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_4, config: config)

      {:ok, _room} = JellyfishAdapter.create_room(adapter, "stream-1")
      {:ok, peer} = JellyfishAdapter.add_peer(adapter, "stream-1", "peer-1")

      assert peer.peer_id == "peer-1"
      assert peer.token != nil
      GenServer.stop(adapter)
    end

    test "returns error for unknown room" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_5, config: config)

      assert {:error, :room_not_found} =
               JellyfishAdapter.add_peer(adapter, "unknown-stream", "peer-1")

      GenServer.stop(adapter)
    end
  end

  describe "JellyfishAdapter.remove_peer/3" do
    test "removes peer from room" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_6, config: config)

      {:ok, _room} = JellyfishAdapter.create_room(adapter, "stream-1")
      {:ok, _peer} = JellyfishAdapter.add_peer(adapter, "stream-1", "peer-1")
      :ok = JellyfishAdapter.remove_peer(adapter, "stream-1", "peer-1")

      peers = JellyfishAdapter.get_peers(adapter, "stream-1")
      assert peers == []
      GenServer.stop(adapter)
    end
  end

  describe "JellyfishAdapter.get_peers/2" do
    test "returns list of peers in room" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_7, config: config)

      {:ok, _room} = JellyfishAdapter.create_room(adapter, "stream-1")
      {:ok, _p1} = JellyfishAdapter.add_peer(adapter, "stream-1", "peer-1")
      {:ok, _p2} = JellyfishAdapter.add_peer(adapter, "stream-1", "peer-2")

      peers = JellyfishAdapter.get_peers(adapter, "stream-1")

      assert length(peers) == 2
      GenServer.stop(adapter)
    end
  end

  describe "JellyfishAdapter.destroy_room/2" do
    test "destroys room and removes all peers" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_8, config: config)

      {:ok, _room} = JellyfishAdapter.create_room(adapter, "stream-1")
      {:ok, _p1} = JellyfishAdapter.add_peer(adapter, "stream-1", "peer-1")

      :ok = JellyfishAdapter.destroy_room(adapter, "stream-1")

      rooms = JellyfishAdapter.list_rooms(adapter)
      assert rooms == []
      GenServer.stop(adapter)
    end
  end

  describe "JellyfishAdapter.get_sfu_endpoint/2" do
    test "SC-ARTERY-003: returns SFU WebSocket endpoint for peer" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_9, config: config)

      {:ok, _room} = JellyfishAdapter.create_room(adapter, "stream-1")
      {:ok, peer} = JellyfishAdapter.add_peer(adapter, "stream-1", "peer-1")

      endpoint = JellyfishAdapter.get_sfu_endpoint(adapter, peer.token)

      assert endpoint =~ "ws://localhost:5002"
      assert endpoint =~ peer.token
      GenServer.stop(adapter)
    end
  end

  describe "JellyfishAdapter.metrics/1" do
    test "returns adapter metrics" do
      config = %{server_url: "http://localhost:5002", api_key: "test-key"}
      {:ok, adapter} = JellyfishAdapter.start_link(name: :test_jf_10, config: config)

      metrics = JellyfishAdapter.metrics(adapter)

      assert Map.has_key?(metrics, :active_rooms)
      assert Map.has_key?(metrics, :total_peers)
      GenServer.stop(adapter)
    end
  end
end
