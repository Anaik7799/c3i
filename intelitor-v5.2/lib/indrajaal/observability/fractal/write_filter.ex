defmodule Indrajaal.Observability.Fractal.WriteFilter do
  @moduledoc """
  Write Filter using Bloom Filter for publisher-side emission control.

  WHAT: Bloom filter-based write filtering and time-bucket deduplication.
  WHY: Prevents redundant log emissions for identical events, reducing noise
       and improving system performance.
  CONSTRAINTS:
    - Performance: <500ns per check (SC-LOG-008)
    - False negative rate: <1% (SC-LOG-008)
    - Time bucket deduplication: 50ms buckets

  ## Architecture

  Uses a two-filter rotation scheme:
  - Current filter: Active filter for all new entries
  - Previous filter: Retained for lookback during rotation window

  ## STAMP Compliance

  - SC-LOG-008: <1% false negative rate (Bloom filters have 0% by design)

  ## Usage

      # Check and record an emission
      key = WriteFilter.build_key("Module", "event", "content_hash")
      if WriteFilter.should_emit?(key) do
        # Emit the log entry
      end

      # Time-based deduplication (50ms buckets)
      key = WriteFilter.build_key_with_time("Module", "event", hlc_physical)
      WriteFilter.should_emit?(key)
  """

  use GenServer
  require Logger

  # ============================================================
  # TYPES
  # ============================================================

  @type bloom_config :: %{
          expected_size: pos_integer(),
          false_positive_rate: float(),
          bit_count: pos_integer(),
          hash_count: pos_integer()
        }

  @type bloom_filter :: %{
          config: bloom_config(),
          bits: :atomics.atomics_ref(),
          count: :counters.counters_ref(),
          created_at: integer()
        }

  @type state :: %{
          current: bloom_filter(),
          previous: bloom_filter() | nil,
          config: bloom_config(),
          rotation_interval_ms: pos_integer(),
          last_rotation: integer(),
          insert_count: :counters.counters_ref(),
          hit_count: :counters.counters_ref(),
          miss_count: :counters.counters_ref()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  # 50ms in microseconds
  @time_bucket_us 50_000

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the WriteFilter GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize the write filter with custom parameters.
  """
  @spec initialize(keyword()) :: :ok
  def initialize(opts \\ []) do
    expected_size = Keyword.get(opts, :expected_size, 10_000)
    fpr = Keyword.get(opts, :fpr, 0.01)
    rotation_interval_ms = Keyword.get(opts, :rotation_interval_ms, 300_000)

    case Process.whereis(__MODULE__) do
      nil ->
        {:ok, _pid} =
          start_link(
            expected_size: expected_size,
            fpr: fpr,
            rotation_interval_ms: rotation_interval_ms
          )

        :ok

      _pid ->
        GenServer.call(__MODULE__, {:reinitialize, expected_size, fpr, rotation_interval_ms})
    end
  end

  @doc """
  Reset the filter to uninitialized state.
  """
  @spec reset() :: :ok
  def reset do
    case Process.whereis(__MODULE__) do
      nil ->
        :ok

      pid ->
        GenServer.stop(pid, :normal, 5_000)
        :ok
    end
  rescue
    _ -> :ok
  end

  @doc """
  Build a filter key from log entry components.
  """
  @spec build_key(String.t(), String.t(), String.t()) :: String.t()
  def build_key(module_key, event_type, content_hash) do
    "#{module_key}|#{event_type}|#{content_hash}"
  end

  @doc """
  Build a filter key with HLC timestamp for time-sensitive filtering.

  Rounds to 50ms buckets for temporal deduplication.
  """
  @spec build_key_with_time(String.t(), String.t(), integer()) :: String.t()
  def build_key_with_time(module_key, event_type, hlc_physical) do
    # Round to 50ms buckets (50_000 microseconds)
    bucket = div(hlc_physical, @time_bucket_us)
    "#{module_key}|#{event_type}|#{bucket}"
  end

  @doc """
  Check if a log entry should be emitted.

  Returns true if the entry is new (should emit), false if duplicate (suppress).
  """
  @spec should_emit?(String.t()) :: boolean()
  def should_emit?(filter_key) do
    ensure_started()
    GenServer.call(__MODULE__, {:should_emit, filter_key})
  end

  @doc """
  Check and record in one operation, returns whether to emit.
  """
  @spec check_and_record(String.t(), String.t(), String.t()) :: boolean()
  def check_and_record(module_key, event_type, content_hash) do
    key = build_key(module_key, event_type, content_hash)
    should_emit?(key)
  end

  @doc """
  Register a subscriber (pre-populate the bloom filter).
  """
  @spec register_subscriber(String.t()) :: :ok
  def register_subscriber(filter_key) do
    ensure_started()
    GenServer.call(__MODULE__, {:pre_register, filter_key})
  end

  @doc """
  Force add a key (for pre-registration).
  """
  @spec pre_register(String.t()) :: :ok
  def pre_register(filter_key) do
    register_subscriber(filter_key)
  end

  @doc """
  Record a key in the filter (alias for pre_register).

  Used for explicitly adding keys to the filter without emission check.
  """
  @spec record(String.t()) :: :ok
  def record(filter_key) do
    register_subscriber(filter_key)
  end

  @doc """
  Clear all filters.
  """
  @spec clear() :: :ok
  def clear do
    ensure_started()
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Get current filter statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    ensure_started()
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Check if the filter is healthy (SC-LOG-008 compliance).
  """
  @spec healthy?() :: boolean()
  def healthy? do
    stats = get_stats()

    stats.current_filter_fill < 0.8 and
      stats.current_estimated_fpr < stats.config.false_positive_rate * 2.0
  end

  # ============================================================
  # BLOOM FILTER CONFIGURATION API
  # ============================================================

  @doc """
  Create configuration with optimal parameters.

  Uses formulas:
  - Bit count: m = -n * ln(p) / (ln(2)^2)
  - Hash count: k = (m/n) * ln(2)
  """
  @spec create_config(pos_integer(), float()) :: bloom_config()
  def create_config(expected_size, fpr) do
    bit_count = calculate_bit_count(expected_size, fpr)
    hash_count = calculate_hash_count(bit_count, expected_size)

    %{
      expected_size: expected_size,
      false_positive_rate: fpr,
      bit_count: bit_count,
      hash_count: hash_count
    }
  end

  @doc """
  Create a new Bloom filter.
  """
  @spec create_filter(bloom_config()) :: bloom_filter()
  def create_filter(config) do
    # Use atomics for lock-free bit operations
    # Each atomic slot holds 64 bits
    slots = div(config.bit_count, 64) + 1
    bits = :atomics.new(slots, signed: false)
    count = :counters.new(1, [])

    %{
      config: config,
      bits: bits,
      count: count,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Add an element to the Bloom filter.
  """
  @spec add(bloom_filter(), String.t()) :: :ok
  def add(filter, element) do
    indices = get_hash_indices(element, filter.config.hash_count, filter.config.bit_count)

    Enum.each(indices, fn idx ->
      slot = div(idx, 64) + 1
      bit_pos = rem(idx, 64)
      mask = Bitwise.bsl(1, bit_pos)

      # Atomic OR operation
      current = :atomics.get(filter.bits, slot)
      :atomics.put(filter.bits, slot, Bitwise.bor(current, mask))
    end)

    :counters.add(filter.count, 1, 1)
    :ok
  end

  @doc """
  Check if an element might be in the filter.

  Returns true if might exist (or definitely exists), false if definitely doesn't exist.
  """
  @spec might_contain?(bloom_filter(), String.t()) :: boolean()
  def might_contain?(filter, element) do
    indices = get_hash_indices(element, filter.config.hash_count, filter.config.bit_count)

    Enum.all?(indices, fn idx ->
      slot = div(idx, 64) + 1
      bit_pos = rem(idx, 64)
      mask = Bitwise.bsl(1, bit_pos)

      current = :atomics.get(filter.bits, slot)
      Bitwise.band(current, mask) != 0
    end)
  end

  @doc """
  Add and check in one operation (returns true if was already present).
  """
  @spec add_and_check?(bloom_filter(), String.t()) :: boolean()
  def add_and_check?(filter, element) do
    indices = get_hash_indices(element, filter.config.hash_count, filter.config.bit_count)

    was_present =
      Enum.all?(indices, fn idx ->
        slot = div(idx, 64) + 1
        bit_pos = rem(idx, 64)
        mask = Bitwise.bsl(1, bit_pos)

        current = :atomics.get(filter.bits, slot)
        Bitwise.band(current, mask) != 0
      end)

    # Always add
    Enum.each(indices, fn idx ->
      slot = div(idx, 64) + 1
      bit_pos = rem(idx, 64)
      mask = Bitwise.bsl(1, bit_pos)

      current = :atomics.get(filter.bits, slot)
      :atomics.put(filter.bits, slot, Bitwise.bor(current, mask))
    end)

    :counters.add(filter.count, 1, 1)
    was_present
  end

  @doc """
  Get current fill rate (approximate).
  """
  @spec fill_rate(bloom_filter()) :: float()
  def fill_rate(filter) do
    slots = div(filter.config.bit_count, 64) + 1

    set_bits =
      Enum.reduce(1..slots, 0, fn slot, acc ->
        val = :atomics.get(filter.bits, slot)
        acc + count_bits(val)
      end)

    set_bits / filter.config.bit_count
  end

  @doc """
  Estimate actual false positive rate based on fill.
  """
  @spec estimated_fpr(bloom_filter()) :: float()
  def estimated_fpr(filter) do
    fill = fill_rate(filter)
    :math.pow(fill, filter.config.hash_count)
  end

  # ============================================================
  # CONTENT HASHING
  # ============================================================

  @doc """
  Quick hash for content deduplication.
  """
  @spec hash_content(String.t()) :: String.t()
  def hash_content(content) do
    sha_hash = :crypto.hash(:sha256, content)

    sha_hash
    |> binary_part(0, 8)
    |> Base.encode64()
  end

  @doc """
  Hash structured data for deduplication.
  """
  @spec hash_payload([{String.t(), term()}]) :: String.t()
  def hash_payload(fields) do
    content =
      fields
      |> Enum.sort_by(fn {key, _val} -> key end)
      |> Enum.map_join("", fn {key, val} -> "#{key}:#{val};" end)

    hash_content(content)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    expected_size = Keyword.get(opts, :expected_size, 10_000)
    fpr = Keyword.get(opts, :fpr, 0.01)
    rotation_interval_ms = Keyword.get(opts, :rotation_interval_ms, 300_000)

    config = create_config(expected_size, fpr)

    state = %{
      current: create_filter(config),
      previous: nil,
      config: config,
      rotation_interval_ms: rotation_interval_ms,
      last_rotation: System.monotonic_time(:millisecond),
      insert_count: :counters.new(1, []),
      hit_count: :counters.new(1, []),
      miss_count: :counters.new(1, [])
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:should_emit, filter_key}, _from, state) do
    state = maybe_rotate(state)

    # Check current filter
    if might_contain?(state.current, filter_key) do
      # Found in current, definitely a duplicate
      :counters.add(state.hit_count, 1, 1)
      {:reply, false, state}
    else
      # Check previous filter if exists
      case state.previous do
        nil ->
          # Not found anywhere, emit and add to current
          add(state.current, filter_key)
          :counters.add(state.miss_count, 1, 1)
          :counters.add(state.insert_count, 1, 1)
          {:reply, true, state}

        prev ->
          if might_contain?(prev, filter_key) do
            # Found in previous, likely a duplicate but add to current
            add(state.current, filter_key)
            :counters.add(state.hit_count, 1, 1)
            :counters.add(state.insert_count, 1, 1)
            {:reply, false, state}
          else
            # Not found anywhere, emit and add to current
            add(state.current, filter_key)
            :counters.add(state.miss_count, 1, 1)
            :counters.add(state.insert_count, 1, 1)
            {:reply, true, state}
          end
      end
    end
  end

  def handle_call({:pre_register, filter_key}, _from, state) do
    add(state.current, filter_key)
    :counters.add(state.insert_count, 1, 1)
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    new_state = %{
      state
      | current: create_filter(state.config),
        previous: nil,
        last_rotation: System.monotonic_time(:millisecond)
    }

    :counters.put(state.insert_count, 1, 0)
    :counters.put(state.hit_count, 1, 0)
    :counters.put(state.miss_count, 1, 0)

    {:reply, :ok, new_state}
  end

  def handle_call(:get_stats, _from, state) do
    current_fill = fill_rate(state.current)

    previous_fill =
      case state.previous do
        nil -> nil
        prev -> fill_rate(prev)
      end

    insert_count = :counters.get(state.insert_count, 1)
    hit_count = :counters.get(state.hit_count, 1)
    miss_count = :counters.get(state.miss_count, 1)

    hit_rate =
      if hit_count + miss_count > 0 do
        hit_count / (hit_count + miss_count)
      else
        0.0
      end

    stats = %{
      insert_count: insert_count,
      hit_count: hit_count,
      miss_count: miss_count,
      hit_rate: hit_rate,
      current_filter_fill: current_fill,
      previous_filter_fill: previous_fill,
      current_estimated_fpr: estimated_fpr(state.current),
      bit_count: state.config.bit_count,
      hash_count: state.config.hash_count,
      expected_size: state.config.expected_size,
      target_fpr: state.config.false_positive_rate,
      rotation_interval_ms: state.rotation_interval_ms,
      last_rotation: state.last_rotation,
      time_since_rotation_ms: System.monotonic_time(:millisecond) - state.last_rotation,
      config: state.config
    }

    {:reply, stats, state}
  end

  def handle_call({:reinitialize, expected_size, fpr, rotation_interval_ms}, _from, _state) do
    config = create_config(expected_size, fpr)

    new_state = %{
      current: create_filter(config),
      previous: nil,
      config: config,
      rotation_interval_ms: rotation_interval_ms,
      last_rotation: System.monotonic_time(:millisecond),
      insert_count: :counters.new(1, []),
      hit_count: :counters.new(1, []),
      miss_count: :counters.new(1, [])
    }

    {:reply, :ok, new_state}
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _pid -> :ok
    end
  end

  defp maybe_rotate(state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.last_rotation

    if elapsed >= state.rotation_interval_ms do
      # Rotate: current becomes previous, new filter becomes current
      %{
        state
        | previous: state.current,
          current: create_filter(state.config),
          last_rotation: now
      }
    else
      state
    end
  end

  defp calculate_bit_count(expected_size, fpr) do
    # Formula: m = -n * ln(p) / (ln(2)^2)
    n = expected_size * 1.0
    p = fpr
    m = -n * :math.log(p) / :math.pow(:math.log(2.0), 2)
    trunc(Float.ceil(m))
  end

  defp calculate_hash_count(bit_count, expected_size) do
    # Formula: k = (m/n) * ln(2)
    m = bit_count * 1.0
    n = expected_size * 1.0
    k = m / n * :math.log(2.0)
    max(1, round(k))
  end

  defp get_hash_indices(element, hash_count, bit_count) do
    # Use double hashing technique: h_i(x) = h1(x) + i * h2(x)
    hash = :crypto.hash(:sha256, element)

    <<h1::signed-integer-size(64), h2::signed-integer-size(64), _rest::binary>> = hash

    for i <- 0..(hash_count - 1) do
      combined = h1 + i * h2
      abs(rem(combined, bit_count))
    end
  end

  defp count_bits(0), do: 0

  defp count_bits(n) when is_integer(n) do
    # Population count (Hamming weight)
    count_bits(n, 0)
  end

  defp count_bits(0, acc), do: acc

  defp count_bits(n, acc) do
    count_bits(Bitwise.band(n, n - 1), acc + 1)
  end
end
