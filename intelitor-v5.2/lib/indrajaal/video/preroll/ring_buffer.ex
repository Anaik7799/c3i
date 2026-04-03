defmodule Indrajaal.Video.Preroll.RingBuffer do
  @moduledoc """
  Lock-free circular buffer for video frame pre-roll.

  Stores recent video frames in a fixed-capacity circular buffer for
  pre-event capture. When an alarm triggers, the buffer can be "frozen"
  to capture the preceding seconds of video.

  ## STAMP Constraints

  - SC-PREROLL-001: Non-blocking write < 100us
  - SC-PREROLL-002: 30-60 second lookback configurable

  ## Frame Format

  Each frame stored in the buffer should have:
  - `:data` - Binary frame data
  - `:timestamp` - Monotonic timestamp in milliseconds

  ## Usage

      buffer = RingBuffer.new(capacity: 900)  # 30 seconds at 30fps

      # Push frames as they arrive
      {:ok, buffer} = RingBuffer.push(buffer, %{
        data: frame_binary,
        timestamp: System.monotonic_time(:millisecond)
      })

      # On alarm trigger, freeze the buffer
      frozen = RingBuffer.freeze(buffer)

      # Continue recording on live buffer while frozen is processed
      {:ok, buffer} = RingBuffer.push(buffer, next_frame)

  ## Implementation

  Uses a map-based storage with head/tail pointers for O(1) operations.
  The buffer wraps around when capacity is reached, evicting oldest frames.

  """

  @type frame :: %{
          data: binary(),
          timestamp: non_neg_integer()
        }

  @type t :: %__MODULE__{
          storage: %{non_neg_integer() => frame()},
          capacity: pos_integer(),
          size: non_neg_integer(),
          head: non_neg_integer(),
          tail: non_neg_integer()
        }

  @type frozen :: %{
          frames: [frame()],
          frozen_at: DateTime.t(),
          timespan_ms: non_neg_integer()
        }

  defstruct storage: %{},
            capacity: 900,
            size: 0,
            head: 0,
            tail: 0

  # Default: 30 seconds at 30fps
  @default_capacity 900

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Creates a new ring buffer.

  ## Options

  - `:capacity` - Maximum number of frames (default: 900 = 30 seconds at 30fps)

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    capacity = Keyword.get(opts, :capacity, @default_capacity)

    %__MODULE__{
      storage: %{},
      capacity: capacity,
      size: 0,
      head: 0,
      tail: 0
    }
  end

  @doc """
  Pushes a frame onto the buffer.

  If the buffer is full, the oldest frame is evicted.
  Returns `{:ok, updated_buffer}`.
  """
  @spec push(t(), frame()) :: {:ok, t()}
  def push(buffer, frame) do
    # Store frame at head position
    new_storage = Map.put(buffer.storage, buffer.head, frame)

    # Calculate new head (wrap around)
    new_head = rem(buffer.head + 1, buffer.capacity)

    # If buffer is full, advance tail (evict oldest)
    {new_tail, new_size} =
      if buffer.size < buffer.capacity do
        {buffer.tail, buffer.size + 1}
      else
        # Evict oldest frame
        {rem(buffer.tail + 1, buffer.capacity), buffer.size}
      end

    new_buffer = %{
      buffer
      | storage: new_storage,
        head: new_head,
        tail: new_tail,
        size: new_size
    }

    {:ok, new_buffer}
  end

  @doc """
  Peeks at the oldest frame without removing it.

  Returns `{:ok, frame}` or `{:error, :empty}`.
  """
  @spec peek(t()) :: {:ok, frame()} | {:error, :empty}
  def peek(%{size: 0}), do: {:error, :empty}

  def peek(buffer) do
    frame = Map.get(buffer.storage, buffer.tail)
    {:ok, frame}
  end

  @doc """
  Removes and returns the oldest frame.

  Returns `{:ok, frame, updated_buffer}` or `{:error, :empty}`.
  """
  @spec pop(t()) :: {:ok, frame(), t()} | {:error, :empty}
  def pop(%{size: 0}), do: {:error, :empty}

  def pop(buffer) do
    frame = Map.get(buffer.storage, buffer.tail)

    new_buffer = %{
      buffer
      | storage: Map.delete(buffer.storage, buffer.tail),
        tail: rem(buffer.tail + 1, buffer.capacity),
        size: buffer.size - 1
    }

    {:ok, frame, new_buffer}
  end

  @doc """
  Returns all frames as a list, oldest first.
  """
  @spec to_list(t()) :: [frame()]
  def to_list(%{size: 0}), do: []

  def to_list(buffer) do
    0..(buffer.size - 1)
    |> Enum.map(fn offset ->
      index = rem(buffer.tail + offset, buffer.capacity)
      Map.get(buffer.storage, index)
    end)
  end

  @doc """
  Returns the time span covered by frames in the buffer (in ms).
  """
  @spec get_timespan(t()) :: non_neg_integer()
  def get_timespan(%{size: size}) when size < 2, do: 0

  def get_timespan(buffer) do
    oldest = Map.get(buffer.storage, buffer.tail)
    newest_index = rem(buffer.head + buffer.capacity - 1, buffer.capacity)
    newest = Map.get(buffer.storage, newest_index)

    if oldest && newest do
      abs(newest.timestamp - oldest.timestamp)
    else
      0
    end
  end

  @doc """
  Creates a frozen snapshot of the current buffer state.

  The frozen snapshot is independent of the live buffer and can be
  processed/saved while the live buffer continues receiving frames.
  """
  @spec freeze(t()) :: frozen()
  def freeze(buffer) do
    frames = to_list(buffer)

    %{
      frames: frames,
      frozen_at: DateTime.utc_now(),
      timespan_ms: get_timespan(buffer)
    }
  end

  @doc """
  Clears all frames from the buffer.
  """
  @spec clear(t()) :: t()
  def clear(buffer) do
    %{buffer | storage: %{}, size: 0, head: 0, tail: 0}
  end

  @doc """
  Returns statistics about the buffer.
  """
  @spec stats(t()) :: map()
  def stats(buffer) do
    %{
      size: buffer.size,
      capacity: buffer.capacity,
      utilization: buffer.size / buffer.capacity,
      timespan_ms: get_timespan(buffer)
    }
  end
end
