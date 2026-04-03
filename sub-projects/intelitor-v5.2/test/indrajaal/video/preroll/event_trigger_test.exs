defmodule Indrajaal.Video.Preroll.EventTriggerTest do
  @moduledoc """
  TDG-Compliant tests for EventTrigger module.

  Tests alarm-triggered buffer freeze functionality.

  STAMP Constraints:
  - SC-PREROLL-001: Non-blocking operations
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Video.Preroll.{EventTrigger, BufferManager}

  describe "EventTrigger.start_link/1" do
    test "starts with buffer manager" do
      {:ok, bm} = BufferManager.start_link(name: :test_et_bm_1)
      assert {:ok, pid} = EventTrigger.start_link(name: :test_et_1, buffer_manager: bm)
      assert Process.alive?(pid)
      GenServer.stop(pid)
      GenServer.stop(bm)
    end
  end

  describe "EventTrigger.trigger_freeze/3" do
    test "freezes buffer on alarm event" do
      {:ok, bm} = BufferManager.start_link(name: :test_et_bm_2)
      {:ok, trigger} = EventTrigger.start_link(name: :test_et_2, buffer_manager: bm)

      BufferManager.create_buffer(bm, "camera-1", [])
      BufferManager.push_frame(bm, "camera-1", %{data: <<1>>, timestamp: 1})
      BufferManager.push_frame(bm, "camera-1", %{data: <<2>>, timestamp: 2})

      {:ok, result} = EventTrigger.trigger_freeze(trigger, "alarm-123", "camera-1")

      assert length(result.frozen.frames) == 2
      assert result.alarm_id == "alarm-123"
      GenServer.stop(trigger)
      GenServer.stop(bm)
    end

    test "returns error for unknown camera" do
      {:ok, bm} = BufferManager.start_link(name: :test_et_bm_3)
      {:ok, trigger} = EventTrigger.start_link(name: :test_et_3, buffer_manager: bm)

      assert {:error, :camera_not_found} =
               EventTrigger.trigger_freeze(trigger, "alarm-1", "unknown-camera")

      GenServer.stop(trigger)
      GenServer.stop(bm)
    end
  end

  describe "EventTrigger.get_frozen_buffers/1" do
    test "returns list of frozen buffers" do
      {:ok, bm} = BufferManager.start_link(name: :test_et_bm_4)
      {:ok, trigger} = EventTrigger.start_link(name: :test_et_4, buffer_manager: bm)

      BufferManager.create_buffer(bm, "camera-1", [])
      BufferManager.push_frame(bm, "camera-1", %{data: <<1>>, timestamp: 1})

      EventTrigger.trigger_freeze(trigger, "alarm-1", "camera-1")

      frozen_list = EventTrigger.get_frozen_buffers(trigger)

      assert length(frozen_list) == 1
      assert hd(frozen_list).alarm_id == "alarm-1"
      GenServer.stop(trigger)
      GenServer.stop(bm)
    end
  end

  describe "EventTrigger.clear_frozen/2" do
    test "removes frozen buffer by alarm id" do
      {:ok, bm} = BufferManager.start_link(name: :test_et_bm_5)
      {:ok, trigger} = EventTrigger.start_link(name: :test_et_5, buffer_manager: bm)

      BufferManager.create_buffer(bm, "camera-1", [])
      BufferManager.push_frame(bm, "camera-1", %{data: <<1>>, timestamp: 1})
      EventTrigger.trigger_freeze(trigger, "alarm-1", "camera-1")

      :ok = EventTrigger.clear_frozen(trigger, "alarm-1")

      frozen_list = EventTrigger.get_frozen_buffers(trigger)
      assert frozen_list == []
      GenServer.stop(trigger)
      GenServer.stop(bm)
    end
  end

  describe "EventTrigger.subscribe/2" do
    test "notifies subscriber on freeze" do
      {:ok, bm} = BufferManager.start_link(name: :test_et_bm_6)
      {:ok, trigger} = EventTrigger.start_link(name: :test_et_6, buffer_manager: bm)

      EventTrigger.subscribe(trigger, self())

      BufferManager.create_buffer(bm, "camera-1", [])
      BufferManager.push_frame(bm, "camera-1", %{data: <<1>>, timestamp: 1})
      EventTrigger.trigger_freeze(trigger, "alarm-1", "camera-1")

      assert_receive {:buffer_frozen, %{alarm_id: "alarm-1"}}, 1000

      GenServer.stop(trigger)
      GenServer.stop(bm)
    end
  end

  describe "EventTrigger.metrics/1" do
    test "returns trigger metrics" do
      {:ok, bm} = BufferManager.start_link(name: :test_et_bm_7)
      {:ok, trigger} = EventTrigger.start_link(name: :test_et_7, buffer_manager: bm)

      metrics = EventTrigger.metrics(trigger)

      assert Map.has_key?(metrics, :total_freezes)
      assert Map.has_key?(metrics, :pending_frozen)
      GenServer.stop(trigger)
      GenServer.stop(bm)
    end
  end
end
