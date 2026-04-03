defmodule Indrajaal.Video.Artery.SplitPlaneTest do
  @moduledoc """
  TDG-Compliant tests for SplitPlane module.

  Tests split-plane video architecture (control via Tailscale, pixels via WebRTC).

  STAMP Constraints:
  - SC-ARTERY-001: Signaling via encrypted channel only
  - SC-ARTERY-002: P2P preferred, SFU fallback
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Video.Artery.SplitPlane

  describe "SplitPlane.new/1" do
    test "creates split plane connection" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      assert conn.stream_id == "stream-1"
      assert conn.state == :initializing
    end

    test "defaults to P2P mode" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      assert conn.mode == :p2p
    end
  end

  describe "SplitPlane.configure_control_plane/2" do
    test "SC-ARTERY-001: configures encrypted control channel" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      conn =
        SplitPlane.configure_control_plane(conn, %{
          endpoint: "100.64.0.1:4000",
          encryption: :tailscale
        })

      assert conn.control_plane.endpoint == "100.64.0.1:4000"
      assert conn.control_plane.encryption == :tailscale
    end
  end

  describe "SplitPlane.configure_pixel_plane/2" do
    test "configures WebRTC pixel channel" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      conn =
        SplitPlane.configure_pixel_plane(conn, %{
          protocol: :webrtc,
          codec: :h264
        })

      assert conn.pixel_plane.protocol == :webrtc
      assert conn.pixel_plane.codec == :h264
    end
  end

  describe "SplitPlane.start_connection/1" do
    test "transitions to connecting state" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      conn =
        SplitPlane.configure_control_plane(conn, %{endpoint: "100.64.0.1", encryption: :tailscale})

      conn = SplitPlane.configure_pixel_plane(conn, %{protocol: :webrtc, codec: :h264})

      {:ok, conn} = SplitPlane.start_connection(conn)

      assert conn.state == :connecting
    end

    test "returns error without control plane configured" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      assert {:error, :control_plane_not_configured} = SplitPlane.start_connection(conn)
    end
  end

  describe "SplitPlane.add_ice_candidate/2" do
    test "adds ICE candidate for P2P connection" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      conn =
        SplitPlane.configure_control_plane(conn, %{endpoint: "100.64.0.1", encryption: :tailscale})

      conn = SplitPlane.configure_pixel_plane(conn, %{protocol: :webrtc, codec: :h264})

      candidate = %{
        candidate: "candidate:1 1 UDP 2_122_194_687 192.168.1.100 54_400 typ host",
        sdp_mid: "0",
        sdp_mline_index: 0
      }

      conn = SplitPlane.add_ice_candidate(conn, candidate)

      assert length(conn.ice_candidates) == 1
    end
  end

  describe "SplitPlane.fallback_to_sfu/1" do
    test "SC-ARTERY-002: falls back to SFU mode" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      conn =
        SplitPlane.configure_control_plane(conn, %{endpoint: "100.64.0.1", encryption: :tailscale})

      conn = SplitPlane.configure_pixel_plane(conn, %{protocol: :webrtc, codec: :h264})

      {:ok, conn} = SplitPlane.fallback_to_sfu(conn)

      assert conn.mode == :sfu
    end
  end

  describe "SplitPlane.get_stats/1" do
    test "returns connection statistics" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      conn =
        SplitPlane.configure_control_plane(conn, %{endpoint: "100.64.0.1", encryption: :tailscale})

      stats = SplitPlane.get_stats(conn)

      assert Map.has_key?(stats, :stream_id)
      assert Map.has_key?(stats, :state)
      assert Map.has_key?(stats, :mode)
    end
  end

  describe "SplitPlane.is_encrypted?/1" do
    test "returns true for Tailscale control plane" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      conn =
        SplitPlane.configure_control_plane(conn, %{endpoint: "100.64.0.1", encryption: :tailscale})

      assert SplitPlane.is_encrypted?(conn)
    end

    test "returns false without encryption" do
      conn = SplitPlane.new(stream_id: "stream-1", local_node: "node-1")

      refute SplitPlane.is_encrypted?(conn)
    end
  end
end
