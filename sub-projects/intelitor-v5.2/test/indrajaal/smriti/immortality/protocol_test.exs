defmodule Indrajaal.SMRITI.Immortality.ProtocolTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Immortality.Protocol

  describe "Immortality Protocol" do
    test "initializes with correct version and state" do
      state = Protocol.new()
      assert state.version == "1.0.0"
      assert state.status == :dormant
    end

    test "generates handshake payload" do
      payload = Protocol.generate_handshake()
      assert Map.has_key?(payload, :timestamp)
      assert Map.has_key?(payload, :node_id)
      assert payload.type == :immortality_handshake
    end

    test "validates incoming handshake" do
      valid_payload = %{
        type: :immortality_handshake,
        node_id: "node_1",
        timestamp: DateTime.utc_now()
      }

      assert {:ok, _} = Protocol.validate_handshake(valid_payload)

      invalid_payload = %{type: :ping}
      assert {:error, :invalid_type} = Protocol.validate_handshake(invalid_payload)
    end
  end
end
