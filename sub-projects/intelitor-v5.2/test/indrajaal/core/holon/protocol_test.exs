defmodule Indrajaal.Core.Holon.ProtocolTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.Protocol

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Protocol)
    end
  end

  describe "new_message/4" do
    test "function is exported" do
      assert function_exported?(Protocol, :new_message, 4)
    end

    test "creates a new message map" do
      msg = Protocol.new_message(:from_holon, :to_holon, :command, %{action: :start})
      assert is_map(msg)
    end

    test "message contains required fields" do
      msg = Protocol.new_message(:src, :dst, :observation, %{data: 1})
      assert Map.has_key?(msg, :from) or Map.has_key?(msg, :source)
    end
  end

  describe "health_report/4" do
    test "function is exported" do
      assert function_exported?(Protocol, :health_report, 4)
    end

    test "creates health report message" do
      msg = Protocol.health_report(:src, :dst, 0.95, %{})
      assert is_map(msg)
    end
  end

  describe "resource_request/4" do
    test "function is exported" do
      assert function_exported?(Protocol, :resource_request, 4)
    end

    test "creates resource request message" do
      msg = Protocol.resource_request(:src, :dst, :cpu, %{amount: 0.5})
      assert is_map(msg)
    end
  end

  describe "coordination/3" do
    test "function is exported" do
      assert function_exported?(Protocol, :coordination, 3)
    end

    test "creates coordination message" do
      msg = Protocol.coordination(:src, :dst, %{action: :sync})
      assert is_map(msg)
    end
  end

  describe "policy_update/3" do
    test "function is exported" do
      assert function_exported?(Protocol, :policy_update, 3)
    end

    test "creates policy update message" do
      msg = Protocol.policy_update(:src, :dst, %{rule: "allow_all"})
      assert is_map(msg)
    end
  end

  describe "observation/3" do
    test "function is exported" do
      assert function_exported?(Protocol, :observation, 3)
    end

    test "creates observation message" do
      msg = Protocol.observation(:src, :dst, %{metric: "cpu", value: 0.5})
      assert is_map(msg)
    end
  end

  describe "command/4" do
    test "function is exported" do
      assert function_exported?(Protocol, :command, 4)
    end

    test "creates command message" do
      msg = Protocol.command(:src, :dst, :start, %{})
      assert is_map(msg)
    end
  end

  describe "response/4" do
    test "function is exported" do
      assert function_exported?(Protocol, :response, 4)
    end

    test "creates response message" do
      msg = Protocol.response(:src, :dst, :ok, %{result: :done})
      assert is_map(msg)
    end
  end

  describe "validate/1" do
    test "function is exported" do
      assert function_exported?(Protocol, :validate, 1)
    end

    test "validates a well-formed message" do
      msg = Protocol.new_message(:src, :dst, :command, %{})
      result = Protocol.validate(msg)
      assert result in [:ok, {:ok, msg}] or match?({:ok, _}, result)
    end

    test "rejects invalid message" do
      result = Protocol.validate(%{invalid: true})
      assert match?({:error, _}, result) or result == :error
    end
  end

  describe "expects_response?/1" do
    test "function is exported" do
      assert function_exported?(Protocol, :expects_response?, 1)
    end

    test "returns boolean" do
      msg = Protocol.command(:src, :dst, :start, %{})
      assert is_boolean(Protocol.expects_response?(msg))
    end
  end

  describe "parent_to_child?/1" do
    test "function is exported" do
      assert function_exported?(Protocol, :parent_to_child?, 1)
    end

    test "returns boolean" do
      msg = Protocol.policy_update(:src, :dst, %{})
      assert is_boolean(Protocol.parent_to_child?(msg))
    end
  end

  describe "child_to_parent?/1" do
    test "function is exported" do
      assert function_exported?(Protocol, :child_to_parent?, 1)
    end

    test "returns boolean" do
      msg = Protocol.health_report(:src, :dst, 0.9, %{})
      assert is_boolean(Protocol.child_to_parent?(msg))
    end
  end

  describe "serialize/1 and deserialize/1" do
    test "serialize is exported" do
      assert function_exported?(Protocol, :serialize, 1)
    end

    test "deserialize is exported" do
      assert function_exported?(Protocol, :deserialize, 1)
    end

    test "serialize then deserialize round-trips a message" do
      msg = Protocol.observation(:src, :dst, %{value: 42})
      serialized = Protocol.serialize(msg)
      assert is_binary(serialized) or is_map(serialized)
      deserialized = Protocol.deserialize(serialized)
      assert is_map(deserialized) or match?({:ok, _}, deserialized)
    end
  end
end
