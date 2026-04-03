defmodule Indrajaal.Native.ZenohTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Native.Zenoh

  test "module exists" do
    assert Code.ensure_loaded?(Zenoh)
  end

  test "open_session/1 is exported" do
    assert function_exported?(Zenoh, :open_session, 1)
  end

  test "close_session/1 is exported" do
    assert function_exported?(Zenoh, :close_session, 1)
  end

  test "publish/3 is exported" do
    assert function_exported?(Zenoh, :publish, 3)
  end

  test "subscribe/3 is exported" do
    assert function_exported?(Zenoh, :subscribe, 3)
  end

  test "poll_messages/2 is exported" do
    assert function_exported?(Zenoh, :poll_messages, 2)
  end

  test "Zenoh.Config struct exists" do
    assert Code.ensure_loaded?(Indrajaal.Native.Zenoh.Config)
  end

  test "Zenoh.Message struct exists" do
    assert Code.ensure_loaded?(Indrajaal.Native.Zenoh.Message)
  end

  test "Zenoh.Stats struct exists" do
    assert Code.ensure_loaded?(Indrajaal.Native.Zenoh.Stats)
  end

  test "Config struct has expected fields" do
    config = %Indrajaal.Native.Zenoh.Config{}
    assert Map.has_key?(config, :connect)
    assert Map.has_key?(config, :mode)
    assert Map.has_key?(config, :multicast_scouting)
  end
end
