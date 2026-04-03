defmodule Indrajaal.Video.Preroll.BufferManagerTest do
  @moduledoc """
  TDG-Compliant tests for BufferManager module.

  Tests per-camera buffer management for video pre-roll.

  STAMP Constraints:
  - SC-PREROLL-003: One buffer per active stream
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Video.Preroll.BufferManager

  describe "BufferManager.start_link/1" do
    test "starts with default options" do
      assert {:ok, pid} = BufferManager.start_link(name: :test_bm_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "BufferManager.create_buffer/3" do
    test "SC-PREROLL-003: creates buffer for camera" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_2)

      :ok = BufferManager.create_buffer(pid, "camera-1", capacity: 900)

      assert BufferManager.buffer_exists?(pid, "camera-1")
      GenServer.stop(pid)
    end

    test "returns error for duplicate camera" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_3)

      :ok = BufferManager.create_buffer(pid, "camera-1", [])

      assert {:error, :already_exists} = BufferManager.create_buffer(pid, "camera-1", [])
      GenServer.stop(pid)
    end
  end

  describe "BufferManager.push_frame/3" do
    test "pushes frame to camera buffer" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_4)
      BufferManager.create_buffer(pid, "camera-1", [])

      frame = %{data: <<1, 2, 3>>, timestamp: 1000}
      :ok = BufferManager.push_frame(pid, "camera-1", frame)

      stats = BufferManager.get_stats(pid, "camera-1")
      assert stats.size == 1
      GenServer.stop(pid)
    end

    test "returns error for unknown camera" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_5)

      assert {:error, :not_found} =
               BufferManager.push_frame(pid, "unknown", %{data: <<>>, timestamp: 0})

      GenServer.stop(pid)
    end
  end

  describe "BufferManager.freeze_buffer/2" do
    test "freezes buffer for camera" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_6)
      BufferManager.create_buffer(pid, "camera-1", [])

      BufferManager.push_frame(pid, "camera-1", %{data: <<1>>, timestamp: 1})
      BufferManager.push_frame(pid, "camera-1", %{data: <<2>>, timestamp: 2})

      {:ok, frozen} = BufferManager.freeze_buffer(pid, "camera-1")

      assert length(frozen.frames) == 2
      assert frozen.frozen_at != nil
      GenServer.stop(pid)
    end
  end

  describe "BufferManager.destroy_buffer/2" do
    test "removes camera buffer" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_7)
      BufferManager.create_buffer(pid, "camera-1", [])

      assert BufferManager.buffer_exists?(pid, "camera-1")

      :ok = BufferManager.destroy_buffer(pid, "camera-1")

      refute BufferManager.buffer_exists?(pid, "camera-1")
      GenServer.stop(pid)
    end
  end

  describe "BufferManager.list_cameras/1" do
    test "lists all active cameras" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_8)

      BufferManager.create_buffer(pid, "camera-1", [])
      BufferManager.create_buffer(pid, "camera-2", [])
      BufferManager.create_buffer(pid, "camera-3", [])

      cameras = BufferManager.list_cameras(pid)

      assert length(cameras) == 3
      assert "camera-1" in cameras
      assert "camera-2" in cameras
      GenServer.stop(pid)
    end
  end

  describe "BufferManager.metrics/1" do
    test "returns aggregate metrics" do
      {:ok, pid} = BufferManager.start_link(name: :test_bm_9)

      BufferManager.create_buffer(pid, "camera-1", [])
      BufferManager.create_buffer(pid, "camera-2", [])

      metrics = BufferManager.metrics(pid)

      assert metrics.active_buffers == 2
      GenServer.stop(pid)
    end
  end
end
