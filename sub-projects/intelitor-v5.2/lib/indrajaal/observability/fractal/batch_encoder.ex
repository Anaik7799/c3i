defmodule Indrajaal.Observability.Fractal.BatchEncoder do
  @moduledoc """
  Batch Encoder for efficient log transmission.

  WHAT: Message batching with delta encoding, aliasing, and compression.
  WHY: Achieves 70% wire savings through efficient encoding techniques.
  CONSTRAINTS:
    - SC-LOG-007: Batch flush < 10ms
    - Max batch size: 100 entries OR 10ms elapsed
    - 8-byte header with HLC timestamps

  ## Wire Format

  The batch wire format uses a compact binary structure:

  ```
  Header (16+ bytes):
    - Magic: 4 bytes (0x43415246 = "FRAC" little-endian)
    - Version: 1 byte
    - Flags: 1 byte (compression, delta encoding, key aliasing)
    - Entry count: 2 bytes
    - Base HLC physical: 8 bytes
    - Node ID length: 1 byte
    - Node ID: variable
    - Uncompressed size: 4 bytes
    - Compressed size: 4 bytes

  Data (variable):
    - Compressed or uncompressed entry data
  ```

  ## Usage

      # Single-shot encoding
      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      # Accumulator pattern (GenServer)
      BatchEncoder.add(entry)
      # Batch is automatically flushed when ready

      # Manual flush
      BatchEncoder.flush()
  """

  use GenServer
  require Logger

  # ============================================================
  # GENSERVER API (for Supervisor)
  # ============================================================

  @doc """
  Starts the BatchEncoder GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Add an entry to the batch accumulator.
  """
  @spec add(map()) :: :ok
  def add(entry) do
    GenServer.cast(__MODULE__, {:add, entry})
  end

  @doc """
  Flush the current batch immediately.
  """
  @spec flush_batch() :: {:ok, binary()} | {:ok, :empty}
  def flush_batch do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Get current accumulator stats.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    config = Keyword.get(opts, :config, default_config())
    flush_interval = config.max_batch_age_ms

    # Schedule periodic flush check
    Process.send_after(self(), :check_flush, flush_interval)

    state = %{
      entries: [],
      first_entry_time: nil,
      config: config,
      batches_sent: 0,
      entries_processed: 0
    }

    Logger.debug("[BATCH_ENCODER] Started with config: #{inspect(config)}")

    {:ok, state}
  end

  @impl true
  def handle_cast({:add, entry}, state) do
    state = add_entry_to_state(state, entry)
    {:noreply, maybe_flush(state)}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    {result, new_state} = do_flush(state)
    {:reply, result, new_state}
  end

  def handle_call(:stats, _from, state) do
    stats = %{
      pending_entries: length(state.entries),
      batches_sent: state.batches_sent,
      entries_processed: state.entries_processed,
      config: state.config
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:check_flush, state) do
    new_state = maybe_flush_by_age(state)
    Process.send_after(self(), :check_flush, state.config.max_batch_age_ms)
    {:noreply, new_state}
  end

  # ============================================================
  # INTERNAL STATE MANAGEMENT
  # ============================================================

  defp add_entry_to_state(state, entry) do
    entries = [entry | state.entries]
    first_time = state.first_entry_time || System.monotonic_time(:millisecond)
    %{state | entries: entries, first_entry_time: first_time}
  end

  defp maybe_flush(state) do
    if length(state.entries) >= state.config.max_batch_size do
      {_result, new_state} = do_flush(state)
      new_state
    else
      state
    end
  end

  defp maybe_flush_by_age(state) do
    case state.first_entry_time do
      nil ->
        state

      time ->
        elapsed = System.monotonic_time(:millisecond) - time

        if elapsed >= state.config.max_batch_age_ms and length(state.entries) > 0 do
          {_result, new_state} = do_flush(state)
          new_state
        else
          state
        end
    end
  end

  defp do_flush(%{entries: []} = state) do
    {{:ok, :empty}, state}
  end

  defp do_flush(state) do
    entries = Enum.reverse(state.entries)

    case encode(state.config, entries) do
      {:ok, batch} ->
        # Would send to ContentRouter here
        new_state = %{
          state
          | entries: [],
            first_entry_time: nil,
            batches_sent: state.batches_sent + 1,
            entries_processed: state.entries_processed + length(entries)
        }

        {{:ok, batch.data}, new_state}

      {:error, reason} ->
        Logger.warning("[BATCH_ENCODER] Flush failed: #{reason}")
        {{:error, reason}, state}
    end
  end

  # ============================================================
  # TYPES
  # ============================================================

  @type batch_config :: %{
          max_batch_size: pos_integer(),
          max_batch_age_ms: pos_integer(),
          enable_compression: boolean(),
          compression_level: 1..9,
          enable_delta_encoding: boolean(),
          enable_key_aliasing: boolean()
        }

  @type batch_header :: %{
          magic: non_neg_integer(),
          version: non_neg_integer(),
          flags: non_neg_integer(),
          entry_count: non_neg_integer(),
          base_hlc_physical: integer(),
          node_id_length: non_neg_integer(),
          node_id: binary(),
          uncompressed_size: non_neg_integer(),
          compressed_size: non_neg_integer()
        }

  @type encoded_batch :: %{
          header: batch_header(),
          data: binary(),
          encoded_at: DateTime.t(),
          entries_count: non_neg_integer(),
          original_size: non_neg_integer(),
          compressed_size: non_neg_integer(),
          compression_ratio: float()
        }

  @type fractal_entry :: map()

  @type batch_accumulator :: %{
          entries: [fractal_entry()],
          first_entry_time: integer() | nil,
          config: batch_config(),
          lock: reference()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  # "FRAC" in little-endian
  @magic_bytes 0x43415246
  @protocol_version 1
  @flag_compressed 0x01
  @flag_delta_encoded 0x02
  @flag_key_aliased 0x04

  # Level encoding (4 bits)
  @level_to_int %{l1: 1, l2: 2, l3: 3, l4: 4, l5: 5}
  @int_to_level %{1 => :l1, 2 => :l2, 3 => :l3, 4 => :l4, 5 => :l5}

  # Priority encoding (4 bits)
  @priority_to_int %{p0: 0, p1: 1, p2: 2, p3: 3}
  @int_to_priority %{0 => :p0, 1 => :p1, 2 => :p2, 3 => :p3}

  # Event type encoding (1 byte)
  @event_type_to_int %{entry: 0, exit: 1, exception: 2, state: 3, metric: 4, intent: 5}
  @int_to_event_type %{
    0 => :entry,
    1 => :exit,
    2 => :exception,
    3 => :state,
    4 => :metric,
    5 => :intent
  }

  # ============================================================
  # CONFIGURATION
  # ============================================================

  @doc """
  Get the default batch configuration.
  """
  @spec default_config() :: batch_config()
  def default_config do
    %{
      max_batch_size: 100,
      max_batch_age_ms: 10,
      enable_compression: true,
      compression_level: 6,
      enable_delta_encoding: true,
      enable_key_aliasing: true
    }
  end

  @doc """
  Create a custom batch configuration.
  """
  @spec create_config(keyword()) :: batch_config()
  def create_config(opts) do
    %{
      max_batch_size: Keyword.get(opts, :max_batch_size, 100),
      max_batch_age_ms: Keyword.get(opts, :max_batch_age_ms, 10),
      enable_compression: Keyword.get(opts, :enable_compression, true),
      compression_level: Keyword.get(opts, :compression_level, 6),
      enable_delta_encoding: Keyword.get(opts, :enable_delta_encoding, true),
      enable_key_aliasing: Keyword.get(opts, :enable_key_aliasing, true)
    }
  end

  # ============================================================
  # WIRE FORMAT CONSTANTS API
  # ============================================================

  @doc "Get the magic bytes constant."
  @spec magic_bytes() :: non_neg_integer()
  def magic_bytes, do: @magic_bytes

  @doc "Get the protocol version."
  @spec protocol_version() :: non_neg_integer()
  def protocol_version, do: @protocol_version

  @doc "Get the compression flag."
  @spec flag_compressed() :: non_neg_integer()
  def flag_compressed, do: @flag_compressed

  @doc "Get the delta encoding flag."
  @spec flag_delta_encoded() :: non_neg_integer()
  def flag_delta_encoded, do: @flag_delta_encoded

  @doc "Get the key aliasing flag."
  @spec flag_key_aliased() :: non_neg_integer()
  def flag_key_aliased, do: @flag_key_aliased

  # ============================================================
  # SIMPLE BATCH API (Test Compatibility)
  # ============================================================

  @doc """
  Simple batch encoding for testing and backwards compatibility.

  Takes a list of messages, trace ID, and base timestamp,
  returns the encoded binary directly.
  """
  @spec encode_batch([map()], String.t(), integer()) :: binary()
  def encode_batch(messages, trace_id, base_timestamp) do
    # Convert simple messages to full fractal entries
    entries =
      Enum.map(messages, fn msg ->
        %{
          key: Map.get(msg, :key, "test"),
          level: Map.get(msg, :level, :l3),
          priority: :p1,
          event_type: :entry,
          hlc: %{
            physical: Map.get(msg, :timestamp, base_timestamp),
            counter: 0,
            node_id: "test_node"
          },
          trace_id: trace_id,
          payload: Map.get(msg, :message, "")
        }
      end)

    case encode(default_config(), entries) do
      {:ok, batch} -> batch.data
      {:error, _} -> <<>>
    end
  end

  # ============================================================
  # ENCODING
  # ============================================================

  @doc """
  Encode a batch of log entries to wire format.
  """
  @spec encode(batch_config(), [fractal_entry()]) :: {:ok, encoded_batch()} | {:error, String.t()}
  def encode(_config, []) do
    {:error, "Cannot encode empty batch"}
  end

  def encode(config, entries) do
    try do
      # Find base HLC for delta encoding
      base_hlc =
        entries
        |> Enum.map(fn e -> get_hlc_physical(e) end)
        |> Enum.min()

      # Get node ID from first entry
      node_id = get_node_id(entries)
      node_id_bytes = node_id

      # Encode entries to intermediate buffer
      entry_data = encode_entries(config, entries, base_hlc)
      uncompressed_size = byte_size(entry_data)

      # Compress if enabled and data is large enough
      {final_data, flags} = maybe_compress(config, entry_data, uncompressed_size)

      # Add encoding flags
      flags =
        flags
        |> maybe_add_flag(config.enable_delta_encoding, @flag_delta_encoded)
        |> maybe_add_flag(config.enable_key_aliasing, @flag_key_aliased)

      # Build final packet
      header =
        build_header(
          flags,
          length(entries),
          base_hlc,
          node_id_bytes,
          uncompressed_size,
          byte_size(final_data)
        )

      packet = header <> final_data

      {:ok,
       %{
         header: %{
           magic: @magic_bytes,
           version: @protocol_version,
           flags: flags,
           entry_count: length(entries),
           base_hlc_physical: base_hlc,
           node_id_length: byte_size(node_id_bytes),
           node_id: node_id_bytes,
           uncompressed_size: uncompressed_size,
           compressed_size: byte_size(final_data)
         },
         data: packet,
         encoded_at: DateTime.utc_now(),
         entries_count: length(entries),
         original_size: uncompressed_size,
         compressed_size: byte_size(final_data),
         compression_ratio:
           if(uncompressed_size > 0,
             do: 1.0 - byte_size(final_data) / uncompressed_size,
             else: 0.0
           )
       }}
    rescue
      e -> {:error, "Encoding failed: #{inspect(e)}"}
    end
  end

  defp get_hlc_physical(entry) do
    case entry.hlc do
      %{physical: p} -> p
      nil -> System.system_time(:microsecond)
    end
  end

  defp get_node_id(entries) do
    case hd(entries).hlc do
      %{node_id: n} when is_binary(n) -> n
      _ -> "unknown"
    end
  end

  defp encode_entries(config, entries, base_hlc) do
    entries
    |> Enum.map(fn entry -> encode_entry(config, entry, base_hlc) end)
    |> IO.iodata_to_binary()
  end

  defp encode_entry(config, entry, base_hlc) do
    # Key: alias or full
    key_data =
      case entry[:key_alias] do
        alias when is_integer(alias) and config.enable_key_aliasing ->
          <<alias::little-unsigned-16>>

        _ ->
          key = entry.key || ""
          key_bytes = key
          <<0::little-unsigned-16>> <> encode_string(key_bytes)
      end

    # HLC
    hlc_physical = get_hlc_physical(entry)
    hlc_counter = entry.hlc[:counter] || 0

    hlc_data =
      if config.enable_delta_encoding do
        delta = hlc_physical - base_hlc
        encode_varint(delta)
      else
        <<hlc_physical::little-signed-64>>
      end

    hlc_counter_data = <<hlc_counter::little-unsigned-16>>

    # Level and Priority (combined into 1 byte)
    level_byte = Map.get(@level_to_int, entry.level, 3)
    priority_byte = Map.get(@priority_to_int, entry.priority, 1)
    level_priority = Bitwise.bor(Bitwise.bsl(level_byte, 4), priority_byte)

    # Event type
    event_type_byte = Map.get(@event_type_to_int, entry.event_type, 0)

    # Trace ID (optional)
    trace_id_data =
      case entry[:trace_id] do
        nil -> <<0>>
        trace_id -> <<1>> <> encode_string(trace_id)
      end

    # Payload
    payload_bytes = encode_payload(entry.payload)
    payload_data = encode_varint(byte_size(payload_bytes)) <> payload_bytes

    # Combine all
    [
      key_data,
      hlc_data,
      hlc_counter_data,
      <<level_priority::unsigned-8>>,
      <<event_type_byte::unsigned-8>>,
      trace_id_data,
      payload_data
    ]
  end

  defp encode_payload(nil), do: <<>>
  defp encode_payload(payload) when is_binary(payload), do: payload

  defp encode_payload(payload) when is_map(payload) do
    :erlang.term_to_binary(payload)
  end

  defp encode_payload(payload), do: :erlang.term_to_binary(payload)

  defp maybe_compress(config, data, uncompressed_size) do
    if config.enable_compression and uncompressed_size > 64 do
      compressed = :zlib.gzip(data)

      # Only use compression if it actually saves space
      if byte_size(compressed) < uncompressed_size do
        {compressed, @flag_compressed}
      else
        {data, 0}
      end
    else
      {data, 0}
    end
  end

  defp maybe_add_flag(flags, true, flag), do: Bitwise.bor(flags, flag)
  defp maybe_add_flag(flags, false, _flag), do: flags

  defp build_header(
         flags,
         entry_count,
         base_hlc,
         node_id_bytes,
         uncompressed_size,
         compressed_size
       ) do
    node_id_len = byte_size(node_id_bytes)

    <<
      @magic_bytes::little-unsigned-32,
      @protocol_version::unsigned-8,
      flags::unsigned-8,
      entry_count::little-unsigned-16,
      base_hlc::little-signed-64,
      node_id_len::unsigned-8,
      node_id_bytes::binary,
      uncompressed_size::little-signed-32,
      compressed_size::little-signed-32
    >>
  end

  # ============================================================
  # DECODING
  # ============================================================

  @doc """
  Decode a batch from wire format.
  """
  @spec decode(binary()) :: {:ok, [fractal_entry()]} | {:error, String.t()}
  def decode(<<magic::little-unsigned-32, _rest::binary>> = _data) when magic != @magic_bytes do
    {:error, "Invalid magic bytes"}
  end

  def decode(<<
        @magic_bytes::little-unsigned-32,
        version::unsigned-8,
        _rest::binary
      >>)
      when version != @protocol_version do
    {:error, "Unsupported protocol version: #{version}"}
  end

  def decode(<<
        @magic_bytes::little-unsigned-32,
        @protocol_version::unsigned-8,
        flags::unsigned-8,
        entry_count::little-unsigned-16,
        base_hlc::little-signed-64,
        node_id_length::unsigned-8,
        rest::binary
      >>) do
    try do
      <<node_id_bytes::binary-size(node_id_length), rest2::binary>> = rest
      node_id = node_id_bytes

      <<
        _uncompressed_size::little-signed-32,
        compressed_size::little-signed-32,
        compressed_data::binary-size(compressed_size),
        _trailing::binary
      >> = rest2

      # Decompress if needed
      entry_data =
        if Bitwise.band(flags, @flag_compressed) != 0 do
          :zlib.gunzip(compressed_data)
        else
          compressed_data
        end

      is_delta_encoded = Bitwise.band(flags, @flag_delta_encoded) != 0
      is_key_aliased = Bitwise.band(flags, @flag_key_aliased) != 0

      # Parse entries
      entries =
        decode_entries(
          entry_data,
          entry_count,
          base_hlc,
          node_id,
          is_delta_encoded,
          is_key_aliased
        )

      {:ok, entries}
    rescue
      e -> {:error, "Decoding failed: #{inspect(e)}"}
    end
  end

  def decode(_) do
    {:error, "Invalid batch format"}
  end

  defp decode_entries(data, count, base_hlc, node_id, is_delta_encoded, is_key_aliased) do
    decode_entries(data, count, base_hlc, node_id, is_delta_encoded, is_key_aliased, [])
  end

  defp decode_entries(_, 0, _, _, _, _, acc), do: Enum.reverse(acc)

  defp decode_entries(data, count, base_hlc, node_id, is_delta_encoded, is_key_aliased, acc) do
    {entry, rest} = decode_single_entry(data, base_hlc, node_id, is_delta_encoded, is_key_aliased)

    decode_entries(rest, count - 1, base_hlc, node_id, is_delta_encoded, is_key_aliased, [
      entry | acc
    ])
  end

  defp decode_single_entry(data, base_hlc, node_id, is_delta_encoded, _is_key_aliased) do
    # Key
    <<key_alias::little-unsigned-16, rest::binary>> = data

    {key, key_alias_opt, rest} =
      if key_alias == 0 do
        {key_str, rest2} = decode_string(rest)
        {key_str, nil, rest2}
      else
        # Would lookup from FractalControl
        {"alias:#{key_alias}", key_alias, rest}
      end

    # HLC
    {hlc_physical, rest} =
      if is_delta_encoded do
        {delta, rest2} = decode_varint(rest)
        {base_hlc + delta, rest2}
      else
        <<physical::little-signed-64, rest2::binary>> = rest
        {physical, rest2}
      end

    <<hlc_counter::little-unsigned-16, rest::binary>> = rest

    # Level and Priority
    <<combined::unsigned-8, rest::binary>> = rest
    level = Map.get(@int_to_level, Bitwise.bsr(combined, 4), :l3)
    priority = Map.get(@int_to_priority, Bitwise.band(combined, 0x0F), :p1)

    # Event type
    <<event_type_byte::unsigned-8, rest::binary>> = rest
    event_type = Map.get(@int_to_event_type, event_type_byte, :entry)

    # Trace ID
    <<has_trace_id::unsigned-8, rest::binary>> = rest

    {trace_id, rest} =
      if has_trace_id == 1 do
        decode_string(rest)
      else
        {nil, rest}
      end

    # Payload
    {payload_length, rest} = decode_varint(rest)

    {payload_bytes, rest} =
      if payload_length > 0 do
        <<payload::binary-size(payload_length), rest2::binary>> = rest
        {payload, rest2}
      else
        {<<>>, rest}
      end

    # Reconstruct payload
    payload =
      if byte_size(payload_bytes) == 0 do
        nil
      else
        try do
          :erlang.binary_to_term(payload_bytes)
        rescue
          _ -> %{raw: payload_bytes}
        end
      end

    entry = %{
      key: key,
      key_alias: key_alias_opt,
      hlc: %{physical: hlc_physical, counter: hlc_counter, node_id: node_id},
      level: level,
      priority: priority,
      event_type: event_type,
      trace_id: trace_id,
      span_id: nil,
      parent_span_id: nil,
      baggage: %{},
      payload: payload,
      tags: [],
      timestamp: DateTime.from_unix!(div(hlc_physical, 1_000_000)),
      duration: nil,
      node: String.to_atom(node_id),
      module: nil,
      function: nil,
      arity: 0
    }

    {entry, rest}
  end

  # ============================================================
  # BATCH ACCUMULATOR
  # ============================================================

  @doc """
  Create a new batch accumulator.
  """
  @spec create_accumulator(batch_config()) :: batch_accumulator()
  def create_accumulator(config) do
    %{
      entries: [],
      first_entry_time: nil,
      config: config,
      lock: make_ref()
    }
  end

  @doc """
  Add an entry to the accumulator.

  Returns the encoded batch if ready to flush, nil otherwise.
  """
  @spec add_entry(batch_accumulator(), fractal_entry()) :: encoded_batch() | nil
  def add_entry(acc, entry) do
    # Read current state from process dictionary (or use initial acc state)
    key = {:batch_acc, acc.lock}

    current_state =
      Process.get(key, %{entries: acc.entries, first_entry_time: acc.first_entry_time})

    # Add the new entry
    entries = [entry | current_state.entries]

    first_entry_time =
      if current_state.first_entry_time == nil do
        System.monotonic_time(:millisecond)
      else
        current_state.first_entry_time
      end

    # Check if we should flush
    should_flush =
      length(entries) >= acc.config.max_batch_size or
        (first_entry_time != nil and
           System.monotonic_time(:millisecond) - first_entry_time >=
             acc.config.max_batch_age_ms)

    if should_flush do
      entries_to_encode = Enum.reverse(entries)

      # Reset accumulator in process dictionary
      Process.put(key, %{entries: [], first_entry_time: nil})

      case encode(acc.config, entries_to_encode) do
        {:ok, batch} -> batch
        {:error, _} -> nil
      end
    else
      # Store updated state in process dictionary
      Process.put(key, %{entries: entries, first_entry_time: first_entry_time})
      nil
    end
  end

  @doc """
  Force flush the accumulator.

  Note: The batch accumulator uses a simplified process dictionary implementation.
  In production, use a GenServer for proper state management.
  """
  @spec flush(batch_accumulator()) :: encoded_batch() | nil
  def flush(acc) do
    key = {:batch_acc, acc.lock}

    state = Process.get(key, %{entries: acc.entries, first_entry_time: acc.first_entry_time})

    if state.entries == [] do
      nil
    else
      entries = Enum.reverse(state.entries)
      Process.put(key, %{entries: [], first_entry_time: nil})

      case encode(acc.config, entries) do
        {:ok, batch} -> batch
        {:error, _} -> nil
      end
    end
  end

  @doc """
  Get accumulator statistics.
  """
  @spec get_accumulator_stats(batch_accumulator()) :: map()
  def get_accumulator_stats(acc) do
    key = {:batch_acc, acc.lock}
    state = Process.get(key, %{entries: acc.entries, first_entry_time: acc.first_entry_time})

    age_ms =
      case state.first_entry_time do
        nil -> nil
        t -> System.monotonic_time(:millisecond) - t
      end

    %{
      pending_entries: length(state.entries),
      age_ms: age_ms,
      config: acc.config
    }
  end

  # ============================================================
  # STATISTICS
  # ============================================================

  @doc """
  Get compression statistics for a batch.
  """
  @spec get_compression_stats(encoded_batch()) :: map()
  def get_compression_stats(batch) do
    %{
      original_size: batch.original_size,
      compressed_size: batch.compressed_size,
      compression_ratio: batch.compression_ratio,
      bytes_saved: batch.original_size - batch.compressed_size,
      entries_count: batch.entries_count,
      bytes_per_entry: batch.compressed_size / batch.entries_count
    }
  end

  # ============================================================
  # VARINT ENCODING/DECODING
  # ============================================================

  @doc """
  Encode a variable-length integer (1-9 bytes for int64).
  """
  @spec encode_varint(integer()) :: binary()
  def encode_varint(value) when value >= 0 do
    encode_varint(value, [])
  end

  defp encode_varint(value, acc) when value < 128 do
    IO.iodata_to_binary(Enum.reverse([value | acc]))
  end

  defp encode_varint(value, acc) do
    byte = Bitwise.bor(Bitwise.band(value, 0x7F), 0x80)
    encode_varint(Bitwise.bsr(value, 7), [byte | acc])
  end

  @doc """
  Decode a variable-length integer.
  """
  @spec decode_varint(binary()) :: {integer(), binary()}
  def decode_varint(data) do
    decode_varint(data, 0, 0)
  end

  defp decode_varint(<<byte::unsigned-8, rest::binary>>, result, shift)
       when Bitwise.band(byte, 0x80) != 0 do
    value = Bitwise.band(byte, 0x7F)
    decode_varint(rest, Bitwise.bor(result, Bitwise.bsl(value, shift)), shift + 7)
  end

  defp decode_varint(<<byte::unsigned-8, rest::binary>>, result, shift) do
    value = Bitwise.band(byte, 0x7F)
    {Bitwise.bor(result, Bitwise.bsl(value, shift)), rest}
  end

  # ============================================================
  # STRING ENCODING/DECODING
  # ============================================================

  defp encode_string(str) when is_binary(str) do
    len = byte_size(str)
    encode_varint(len) <> str
  end

  defp decode_string(data) do
    {len, rest} = decode_varint(data)
    <<str::binary-size(len), rest2::binary>> = rest
    {str, rest2}
  end
end
