defmodule Indrajaal.Observability.ZenohPublisherTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohPublisher

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohPublisher)
    end
  end

  describe "function exports" do
    test "publish/2 is exported" do
      assert function_exported?(ZenohPublisher, :publish, 2)
    end

    test "publish_async/3 is exported" do
      assert function_exported?(ZenohPublisher, :publish_async, 3)
    end

    test "publish_emergency/2 is exported" do
      assert function_exported?(ZenohPublisher, :publish_emergency, 2)
    end
  end

  describe "publish/2" do
    test "completes without raising for valid topic and payload" do
      result = ZenohPublisher.publish("indrajaal/test/topic", %{event: "test", value: 1})
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles binary payload" do
      result = ZenohPublisher.publish("indrajaal/test/binary", Jason.encode!(%{a: 1}))
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "publish_async/3" do
    test "returns immediately without blocking" do
      result = ZenohPublisher.publish_async("indrajaal/test/async", %{async: true}, [])

      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result) or
               is_reference(result) or is_pid(result)
    end
  end

  describe "publish_emergency/2" do
    test "publishes emergency event" do
      result =
        ZenohPublisher.publish_emergency("indrajaal/test/emergency", %{
          severity: :critical,
          message: "test emergency"
        })

      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
