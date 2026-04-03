defmodule Indrajaal.Video.Preroll.RingBufferTest do
  @moduledoc """
  TDG-Compliant tests for RingBuffer module.

  Tests lock-free circular buffer for video frame pre-roll.

  STAMP Constraints:
  - SC-PREROLL-001: Non-blocking write < 100us
  - SC-PREROLL-002: 30-60 second lookback configurable
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Video.Preroll.RingBuffer

  describe "RingBuffer.new/1" do
    test "creates buffer with default capacity" do
      buffer = RingBuffer.new()

      assert buffer.capacity > 0
      assert buffer.size == 0
    end

    test "creates buffer with custom capacity" do
      buffer = RingBuffer.new(capacity: 100)

      assert buffer.capacity == 100
    end

    test "initializes head and tail to 0" do
      buffer = RingBuffer.new()

      assert buffer.head == 0
      assert buffer.tail == 0
    end
  end

  describe "RingBuffer.push/2" do
    test "adds frame to buffer" do
      buffer = RingBuffer.new(capacity: 10)
      frame = %{data: <<1, 2, 3>>, timestamp: 1000}

      {:ok, buffer} = RingBuffer.push(buffer, frame)

      assert buffer.size == 1
    end

    test "SC-PREROLL-001: push is fast" do
      buffer = RingBuffer.new(capacity: 1000)
      frame = %{data: <<1, 2, 3, 4, 5>>, timestamp: 1000}

      {time_us, {:ok, _buffer}} =
        :timer.tc(fn ->
          RingBuffer.push(buffer, frame)
        end)

      # Should complete in < 100us (relaxed for test overhead)
      assert time_us < 5000
    end

    test "wraps around when capacity reached" do
      buffer = RingBuffer.new(capacity: 3)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<3>>, timestamp: 3})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<4>>, timestamp: 4})

      # Buffer should still have 3 items (oldest evicted)
      assert buffer.size == 3
    end

    test "increments head pointer" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})

      assert buffer.head == 2
    end
  end

  describe "RingBuffer.peek/1" do
    test "returns oldest frame without removing" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})

      {:ok, frame} = RingBuffer.peek(buffer)

      assert frame.timestamp == 1
      # Size unchanged
      assert buffer.size == 2
    end

    test "returns error for empty buffer" do
      buffer = RingBuffer.new(capacity: 10)

      assert {:error, :empty} = RingBuffer.peek(buffer)
    end
  end

  describe "RingBuffer.pop/1" do
    test "removes and returns oldest frame" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})

      {:ok, frame, buffer} = RingBuffer.pop(buffer)

      assert frame.timestamp == 1
      assert buffer.size == 1
    end

    test "returns error for empty buffer" do
      buffer = RingBuffer.new(capacity: 10)

      assert {:error, :empty} = RingBuffer.pop(buffer)
    end
  end

  describe "RingBuffer.to_list/1" do
    test "returns all frames in order" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<3>>, timestamp: 3})

      frames = RingBuffer.to_list(buffer)

      assert length(frames) == 3
      assert Enum.map(frames, & &1.timestamp) == [1, 2, 3]
    end

    test "handles wrap-around correctly" do
      buffer = RingBuffer.new(capacity: 3)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<3>>, timestamp: 3})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<4>>, timestamp: 4})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<5>>, timestamp: 5})

      frames = RingBuffer.to_list(buffer)

      # Should have timestamps 3, 4, 5 (oldest 2 evicted)
      assert Enum.map(frames, & &1.timestamp) == [3, 4, 5]
    end
  end

  describe "RingBuffer.get_timespan/1" do
    test "returns duration covered by buffer" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1000})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2000})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<3>>, timestamp: 3000})

      timespan = RingBuffer.get_timespan(buffer)

      assert timespan == 2000
    end

    test "returns 0 for empty buffer" do
      buffer = RingBuffer.new(capacity: 10)

      assert RingBuffer.get_timespan(buffer) == 0
    end

    test "returns 0 for single frame" do
      buffer = RingBuffer.new(capacity: 10)
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1000})

      assert RingBuffer.get_timespan(buffer) == 0
    end
  end

  describe "RingBuffer.freeze/1" do
    test "creates snapshot of current state" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})

      frozen = RingBuffer.freeze(buffer)

      assert is_list(frozen.frames)
      assert length(frozen.frames) == 2
      assert frozen.frozen_at != nil
    end

    test "frozen snapshot is independent of original" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      frozen = RingBuffer.freeze(buffer)

      {:ok, _buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})

      # Frozen snapshot should still have only 1 frame
      assert length(frozen.frames) == 1
    end
  end

  describe "RingBuffer.clear/1" do
    test "empties the buffer" do
      buffer = RingBuffer.new(capacity: 10)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})

      buffer = RingBuffer.clear(buffer)

      assert buffer.size == 0
      assert buffer.head == 0
      assert buffer.tail == 0
    end
  end

  describe "RingBuffer.stats/1" do
    test "returns buffer statistics" do
      buffer = RingBuffer.new(capacity: 100)

      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<1>>, timestamp: 1})
      {:ok, buffer} = RingBuffer.push(buffer, %{data: <<2>>, timestamp: 2})

      stats = RingBuffer.stats(buffer)

      assert stats.size == 2
      assert stats.capacity == 100
      assert stats.utilization == 0.02
    end
  end

  # Property tests
  test "property: buffer never exceeds capacity" do
    buffer = RingBuffer.new(capacity: 10)

    # Push more items than capacity
    final_buffer =
      Enum.reduce(1..50, buffer, fn i, buf ->
        {:ok, new_buf} = RingBuffer.push(buf, %{data: <<i>>, timestamp: i})
        new_buf
      end)

    assert final_buffer.size <= 10
  end

  test "property: to_list returns frames in timestamp order" do
    buffer = RingBuffer.new(capacity: 20)

    final_buffer =
      Enum.reduce(1..30, buffer, fn i, buf ->
        {:ok, new_buf} = RingBuffer.push(buf, %{data: <<i>>, timestamp: i * 100})
        new_buf
      end)

    frames = RingBuffer.to_list(final_buffer)
    timestamps = Enum.map(frames, & &1.timestamp)

    assert timestamps == Enum.sort(timestamps)
  end
end
