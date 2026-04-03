defmodule Indrajaal.Realtime.OfflineQueueTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Realtime.OfflineQueue

  test "module exists" do
    assert Code.ensure_loaded?(OfflineQueue)
  end

  test "deliver_to_user/2 is exported" do
    assert function_exported?(OfflineQueue, :deliver_to_user, 2)
  end

  test "deliver_to_user/2 returns :ok" do
    assert :ok = OfflineQueue.deliver_to_user(self(), %{type: :test, data: "message"})
  end
end
