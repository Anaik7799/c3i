defmodule Intelitor.Realtime.OfflineQueueTest do
  @moduledoc """
  Test suite for Intelitor.Realtime.OfflineQueue.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/realtime/_offline_queue.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Realtime.OfflineQueue

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(OfflineQueue)
    end

    test "module has __info__/1 function" do
      assert function_exported?(OfflineQueue, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = OfflineQueue.__info__(:module)
      assert info == Intelitor.Realtime.OfflineQueue
    end
  end
end
