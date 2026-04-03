defmodule Indrajaal.EventStreamingTest do
  @moduledoc """
  Tests for EventStreaming context stub module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module structure" do
    test "EventStreaming module is loaded" do
      assert Code.ensure_loaded?(EventStreaming)
    end

    test "publish/2 is exported" do
      assert function_exported?(EventStreaming, :publish, 2)
    end

    test "subscribe/2 is exported" do
      assert function_exported?(EventStreaming, :subscribe, 2)
    end

    test "unsubscribe/2 is exported" do
      assert function_exported?(EventStreaming, :unsubscribe, 2)
    end

    test "list_streams/0 is exported" do
      assert function_exported?(EventStreaming, :list_streams, 0)
    end

    test "create_stream/1 is exported" do
      assert function_exported?(EventStreaming, :create_stream, 1)
    end
  end

  describe "publish/2" do
    test "returns error tuple for stub" do
      result = EventStreaming.publish("test-stream", %{event: "test"})
      assert {:error, _} = result
    end
  end

  describe "subscribe/2" do
    test "returns error tuple for stub" do
      result = EventStreaming.subscribe("test-stream", self())
      assert {:error, _} = result
    end
  end

  describe "list_streams/0" do
    test "returns error tuple for stub" do
      result = EventStreaming.list_streams()
      assert {:error, _} = result
    end
  end
end
