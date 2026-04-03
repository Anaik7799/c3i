defmodule Indrajaal.Video.Artery.WebRTCSignalingTest do
  @moduledoc """
  TDG-Compliant tests for WebRTCSignaling module.

  Tests ICE candidate exchange via Zenoh control channel.

  STAMP Constraints:
  - SC-ARTERY-001: Signaling via encrypted channel only
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Video.Artery.WebRTCSignaling

  describe "WebRTCSignaling.start_link/1" do
    test "starts signaling server" do
      assert {:ok, pid} = WebRTCSignaling.start_link(name: :test_sig_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "WebRTCSignaling.create_offer/2" do
    test "creates SDP offer for stream" do
      {:ok, sig} = WebRTCSignaling.start_link(name: :test_sig_2)

      {:ok, offer} = WebRTCSignaling.create_offer(sig, "stream-1")

      assert offer.type == :offer
      assert is_binary(offer.sdp)
      GenServer.stop(sig)
    end
  end

  describe "WebRTCSignaling.handle_offer/3" do
    test "processes incoming offer and creates answer" do
      {:ok, sig} = WebRTCSignaling.start_link(name: :test_sig_3)

      offer = %{type: :offer, sdp: "v=0\r\no=- 1234 1234 IN IP4 0.0.0.0\r\n"}

      {:ok, answer} = WebRTCSignaling.handle_offer(sig, "stream-1", offer)

      assert answer.type == :answer
      assert is_binary(answer.sdp)
      GenServer.stop(sig)
    end
  end

  describe "WebRTCSignaling.add_ice_candidate/3" do
    test "adds ICE candidate for stream" do
      {:ok, sig} = WebRTCSignaling.start_link(name: :test_sig_4)

      candidate = %{
        candidate: "candidate:1 1 UDP 2_122_194_687 192.168.1.100 54_400 typ host",
        sdp_mid: "0",
        sdp_mline_index: 0
      }

      :ok = WebRTCSignaling.add_ice_candidate(sig, "stream-1", candidate)

      candidates = WebRTCSignaling.get_ice_candidates(sig, "stream-1")
      assert length(candidates) == 1
      GenServer.stop(sig)
    end
  end

  describe "WebRTCSignaling.subscribe/2" do
    test "subscribes to signaling events" do
      {:ok, sig} = WebRTCSignaling.start_link(name: :test_sig_5)

      :ok = WebRTCSignaling.subscribe(sig, self())

      # Trigger an event
      WebRTCSignaling.add_ice_candidate(sig, "stream-1", %{
        candidate: "candidate:1",
        sdp_mid: "0",
        sdp_mline_index: 0
      })

      assert_receive {:ice_candidate_added, "stream-1", _}, 1000
      GenServer.stop(sig)
    end
  end

  describe "WebRTCSignaling.get_connection_state/2" do
    test "returns connection state for stream" do
      {:ok, sig} = WebRTCSignaling.start_link(name: :test_sig_6)

      WebRTCSignaling.create_offer(sig, "stream-1")

      state = WebRTCSignaling.get_connection_state(sig, "stream-1")

      assert state in [:new, :connecting, :connected, :disconnected, :failed]
      GenServer.stop(sig)
    end
  end

  describe "WebRTCSignaling.metrics/1" do
    test "returns signaling metrics" do
      {:ok, sig} = WebRTCSignaling.start_link(name: :test_sig_7)

      metrics = WebRTCSignaling.metrics(sig)

      assert Map.has_key?(metrics, :active_sessions)
      assert Map.has_key?(metrics, :total_offers)
      GenServer.stop(sig)
    end
  end
end
