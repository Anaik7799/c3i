defmodule Indrajaal.Federation.ProtocolTest do
  @moduledoc """
  Tests for Indrajaal.Federation.Protocol.

  Pure functions (create_message/4, stats/0) are tested with real assertions.
  Functions that call external dependencies (Cryptography, Constitution, network)
  are tested at the structural / return-shape level only.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Federation.Protocol

  # ---------------------------------------------------------------------------
  # create_message/4
  # ---------------------------------------------------------------------------

  describe "create_message/4" do
    test "returns a map with required fields" do
      msg = Protocol.create_message(:heartbeat, "dest_node", %{ping: true})

      assert is_map(msg)
      assert Map.has_key?(msg, :id)
      assert Map.has_key?(msg, :type)
      assert Map.has_key?(msg, :destination)
      assert Map.has_key?(msg, :payload)
      assert Map.has_key?(msg, :timestamp)
      assert Map.has_key?(msg, :ttl)
    end

    test "sets the correct message type" do
      msg = Protocol.create_message(:sync, "dest", %{})
      assert msg.type == :sync
    end

    test "sets the correct destination" do
      msg = Protocol.create_message(:event, "node_42", %{})
      assert msg.destination == "node_42"
    end

    test "embeds the payload unchanged" do
      payload = %{key: "value", count: 7}
      msg = Protocol.create_message(:event, "dest", payload)
      assert msg.payload == payload
    end

    test "generates a unique id on each call" do
      m1 = Protocol.create_message(:event, "d", %{})
      m2 = Protocol.create_message(:event, "d", %{})
      assert m1.id != m2.id
    end

    test "id has the expected msg_ prefix" do
      msg = Protocol.create_message(:event, "d", %{})
      assert String.starts_with?(msg.id, "msg_")
    end

    test "default TTL is a positive integer" do
      msg = Protocol.create_message(:event, "d", %{})
      assert is_integer(msg.ttl)
      assert msg.ttl > 0
    end

    test "custom ttl option is respected" do
      msg = Protocol.create_message(:event, "d", %{}, ttl: 3)
      assert msg.ttl == 3
    end

    test "timestamp is a DateTime" do
      msg = Protocol.create_message(:heartbeat, "d", %{})
      assert %DateTime{} = msg.timestamp
    end

    test "signature is nil on a fresh message" do
      msg = Protocol.create_message(:request, "d", %{})
      assert is_nil(msg.signature)
    end

    test "accepts all valid message types" do
      for type <- [:heartbeat, :sync, :event, :request, :response, :broadcast] do
        msg = Protocol.create_message(type, "dest", %{})
        assert msg.type == type
      end
    end
  end

  # ---------------------------------------------------------------------------
  # stats/0
  # ---------------------------------------------------------------------------

  describe "stats/0" do
    test "returns a map" do
      assert is_map(Protocol.stats())
    end

    test "includes a :version key" do
      assert Map.has_key?(Protocol.stats(), :version)
    end

    test "version is a positive integer" do
      assert Protocol.stats().version >= 1
    end

    test "includes counter fields" do
      stats = Protocol.stats()

      for field <- [:messages_sent, :messages_received, :bytes_sent, :bytes_received, :errors] do
        assert Map.has_key?(stats, field), "missing field: #{field}"
      end
    end

    test "counter fields are non-negative integers" do
      stats = Protocol.stats()

      for field <- [:messages_sent, :messages_received, :bytes_sent, :bytes_received, :errors] do
        assert is_integer(stats[field]) and stats[field] >= 0
      end
    end
  end

  # ---------------------------------------------------------------------------
  # verify_message/1 - unsigned messages
  # ---------------------------------------------------------------------------

  describe "verify_message/1 - unsigned message" do
    test "returns {:error, :unsigned} for a message with nil signature" do
      msg = Protocol.create_message(:event, "dest", %{data: 1})
      assert {:error, :unsigned} = Protocol.verify_message(msg)
    end

    test "returns an error tuple for an unsigned message" do
      msg = %{
        id: "test_id",
        type: :event,
        source: "src",
        destination: "dst",
        payload: %{},
        timestamp: DateTime.utc_now(),
        ttl: 10,
        signature: nil
      }

      assert match?({:error, _}, Protocol.verify_message(msg))
    end
  end

  # ---------------------------------------------------------------------------
  # broadcast/2 - pure return-shape test (transmit is a stub)
  # ---------------------------------------------------------------------------

  describe "broadcast/2" do
    test "returns a list when called with an empty destination list" do
      result = Protocol.broadcast(%{data: "test"}, [])
      assert result == []
    end

    test "returns a list with one element per destination" do
      # transmit/2 always returns :ok so sign_message / encrypt may fail
      # depending on Constitution availability. We only assert shape.
      result = Protocol.broadcast(%{data: "test"}, ["node_1", "node_2"])
      assert is_list(result)
      assert length(result) == 2
    end

    test "each result element is a map" do
      result = Protocol.broadcast(%{data: "test"}, ["node_1"])
      assert [entry] = result
      assert is_map(entry)
    end
  end

  # ---------------------------------------------------------------------------
  # API surface
  # ---------------------------------------------------------------------------

  describe "public API surface" do
    for {fun, arity} <- [
          create_message: 3,
          create_message: 4,
          sign_message: 1,
          verify_message: 1,
          encrypt_message: 1,
          decrypt_message: 1,
          send_message: 2,
          send_message: 3,
          receive_frame: 1,
          heartbeat: 1,
          broadcast: 2,
          request: 3,
          stats: 0
        ] do
      @fun fun
      @arity arity
      test "exports #{fun}/#{arity}" do
        assert function_exported?(Protocol, @fun, @arity)
      end
    end
  end
end
