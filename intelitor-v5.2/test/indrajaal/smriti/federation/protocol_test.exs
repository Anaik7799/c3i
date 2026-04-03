defmodule Indrajaal.SMRITI.Federation.ProtocolTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Federation.Protocol

  describe "Federation Protocol" do
    test "defines message types" do
      assert Protocol.message_type(:sync_request) == "SYNC_REQ"
      assert Protocol.message_type(:sync_ack) == "SYNC_ACK"
    end

    test "serializes sync packet" do
      vector = %{"node_a" => 1}
      payload = Protocol.encode_sync_request("node_b", vector)

      assert is_binary(payload)
      assert {:ok, decoded} = Protocol.decode(payload)
      assert decoded["type"] == "SYNC_REQ"
      assert decoded["sender"] == "node_b"
      assert decoded["vector"] == %{"node_a" => 1}
    end
  end
end
