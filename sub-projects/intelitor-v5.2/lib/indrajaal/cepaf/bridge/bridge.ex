defmodule Indrajaal.CEPAF.Bridge.Bridge do
  @moduledoc """
  CEPAF Bridge - Elixir ↔ F# Communication for v20.0.0

  Implements bidirectional communication between BEAM and .NET runtime:
  - Message serialization/deserialization
  - Type mapping between Elixir and F#
  - Async message passing
  - Health monitoring

  ## Bridge Model

  Communication via named pipes or TCP:
  - Elixir serializes to MessagePack/JSON
  - F# deserializes and processes
  - Response follows reverse path

  ## Type Mapping
  - Elixir atom → F# DU case
  - Elixir map → F# Record
  - Elixir list → F# List
  - Elixir tuple → F# Tuple

  ## STAMP Constraints
  - SC-BRG-001: Message serialization MUST be lossless
  - SC-BRG-002: Bridge health MUST be monitored
  - SC-BRG-003: Timeouts MUST be enforced (30s max)
  - SC-BRG-004: Message ordering MUST be preserved
  """

  use GenServer
  require Logger

  @type message_id :: String.t()
  @type message_type :: :command | :query | :event | :response
  @type bridge_status :: :disconnected | :connecting | :connected | :error

  @type bridge_message :: %{
          id: message_id(),
          type: message_type(),
          payload: term(),
          timestamp: DateTime.t(),
          correlation_id: message_id() | nil
        }

  @type state :: %{
          status: bridge_status(),
          socket: port() | nil,
          pending: map(),
          stats: map(),
          config: map()
        }

  # Connection timeout (ms)
  @connect_timeout 5_000

  # Message timeout (ms)
  @message_timeout 30_000

  # Health check interval
  @health_interval 10_000

  # Default port for F# bridge
  @default_port 9999

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends a command to F# runtime.
  """
  @spec command(atom(), term()) :: {:ok, term()} | {:error, term()}
  def command(name, args) do
    GenServer.call(__MODULE__, {:command, name, args}, @message_timeout)
  end

  @doc """
  Sends a query to F# runtime.
  """
  @spec query(atom(), term()) :: {:ok, term()} | {:error, term()}
  def query(name, args) do
    GenServer.call(__MODULE__, {:query, name, args}, @message_timeout)
  end

  @doc """
  Sends an event to F# runtime (fire-and-forget).
  """
  @spec event(atom(), term()) :: :ok
  def event(name, payload) do
    GenServer.cast(__MODULE__, {:event, name, payload})
  end

  @doc """
  Gets bridge status.
  """
  @spec status() :: bridge_status()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Connects to F# bridge.
  """
  @spec connect() :: :ok | {:error, term()}
  def connect do
    GenServer.call(__MODULE__, :connect, @connect_timeout)
  end

  @doc """
  Disconnects from F# bridge.
  """
  @spec disconnect() :: :ok
  def disconnect do
    GenServer.call(__MODULE__, :disconnect)
  end

  @doc """
  Gets bridge statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      status: :disconnected,
      socket: nil,
      pending: %{},
      buffer: <<>>,
      stats: %{
        messages_sent: 0,
        messages_received: 0,
        commands: 0,
        queries: 0,
        events: 0,
        errors: 0,
        avg_latency_ms: 0
      },
      config: %{
        host: Keyword.get(opts, :host, "localhost"),
        port: Keyword.get(opts, :port, @default_port),
        auto_connect: Keyword.get(opts, :auto_connect, true),
        serializer: Keyword.get(opts, :serializer, :json)
      }
    }

    # Auto-connect if configured
    if state.config.auto_connect do
      send(self(), :auto_connect)
    end

    Logger.info("🌉 CEPAF Bridge initialized")

    {:ok, state}
  end

  @impl true
  def handle_call({:command, name, args}, from, state) do
    if state.status != :connected do
      {:reply, {:error, :not_connected}, state}
    else
      message = create_message(:command, %{name: name, args: args})
      new_state = send_and_track(message, from, state)
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call({:query, name, args}, from, state) do
    if state.status != :connected do
      {:reply, {:error, :not_connected}, state}
    else
      message = create_message(:query, %{name: name, args: args})
      new_state = send_and_track(message, from, state)
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:connect, _from, state) do
    case do_connect(state) do
      {:ok, socket} ->
        # Start health check
        Process.send_after(self(), :health_check, @health_interval)
        Logger.info("🌉 Connected to CEPAF F# bridge at #{state.config.host}:#{state.config.port}")
        {:reply, :ok, %{state | status: :connected, socket: socket}}

      {:error, reason} = error ->
        Logger.warning("🌉 Failed to connect: #{inspect(reason)}")
        {:reply, error, %{state | status: :error}}
    end
  end

  @impl true
  def handle_call(:disconnect, _from, state) do
    if state.socket do
      :gen_tcp.close(state.socket)
    end

    {:reply, :ok, %{state | status: :disconnected, socket: nil}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        status: state.status,
        pending_count: map_size(state.pending)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:event, name, payload}, state) do
    if state.status == :connected do
      message = create_message(:event, %{name: name, payload: payload})
      send_message(state.socket, message, state.config.serializer)

      new_stats = %{
        state.stats
        | events: state.stats.events + 1,
          messages_sent: state.stats.messages_sent + 1
      }

      {:noreply, %{state | stats: new_stats}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:auto_connect, state) do
    case do_connect(state) do
      {:ok, socket} ->
        Process.send_after(self(), :health_check, @health_interval)
        Logger.info("🌉 Auto-connected to CEPAF bridge")
        {:noreply, %{state | status: :connected, socket: socket}}

      {:error, _reason} ->
        # Retry after delay
        Process.send_after(self(), :auto_connect, 5_000)
        {:noreply, %{state | status: :connecting}}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    if state.status == :connected do
      # Send ping
      message = create_message(:command, %{name: :ping, args: []})

      case send_message(state.socket, message, state.config.serializer) do
        :ok ->
          Process.send_after(self(), :health_check, @health_interval)
          {:noreply, state}

        {:error, _} ->
          Logger.warning("🌉 Health check failed, disconnecting")
          :gen_tcp.close(state.socket)
          send(self(), :auto_connect)
          {:noreply, %{state | status: :disconnected, socket: nil}}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:tcp, _socket, data}, state) do
    # Buffer incoming data
    buffer = state.buffer <> data

    # Process complete messages
    {messages, remaining} = parse_messages(buffer, state.config.serializer)

    new_state =
      messages
      |> Enum.reduce(%{state | buffer: remaining}, fn msg, acc ->
        handle_response(msg, acc)
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warning("🌉 Connection closed by F# bridge")
    send(self(), :auto_connect)
    {:noreply, %{state | status: :disconnected, socket: nil}}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("🌉 TCP error: #{inspect(reason)}")
    send(self(), :auto_connect)
    {:noreply, %{state | status: :error, socket: nil}}
  end

  @impl true
  def handle_info({:timeout, message_id}, state) do
    case Map.pop(state.pending, message_id) do
      {nil, _} ->
        {:noreply, state}

      {{from, _sent_at}, new_pending} ->
        GenServer.reply(from, {:error, :timeout})
        new_stats = %{state.stats | errors: state.stats.errors + 1}
        {:noreply, %{state | pending: new_pending, stats: new_stats}}
    end
  end

  # Private helpers

  defp do_connect(state) do
    opts = [:binary, active: true, packet: 4]
    host = String.to_charlist(state.config.host)
    :gen_tcp.connect(host, state.config.port, opts, @connect_timeout)
  end

  defp create_message(type, payload) do
    %{
      id: generate_id(),
      type: type,
      payload: payload,
      timestamp: DateTime.utc_now(),
      correlation_id: nil
    }
  end

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(bytes, case: :lower)
  end

  defp send_and_track(message, from, state) do
    case send_message(state.socket, message, state.config.serializer) do
      :ok ->
        # Track pending response
        new_pending =
          Map.put(state.pending, message.id, {from, System.monotonic_time(:millisecond)})

        # Set timeout
        Process.send_after(self(), {:timeout, message.id}, @message_timeout)

        # Update stats
        stat_key = if message.type == :command, do: :commands, else: :queries

        new_stats = %{
          state.stats
          | stat_key => Map.get(state.stats, stat_key, 0) + 1,
            messages_sent: state.stats.messages_sent + 1
        }

        %{state | pending: new_pending, stats: new_stats}

      {:error, reason} ->
        GenServer.reply(from, {:error, reason})
        state
    end
  end

  defp send_message(socket, message, serializer) do
    encoded = encode_message(message, serializer)
    :gen_tcp.send(socket, encoded)
  end

  defp encode_message(message, :json) do
    Jason.encode!(message)
  end

  defp encode_message(message, :msgpack) do
    # Fallback to JSON if MessagePack not available
    Jason.encode!(message)
  end

  defp parse_messages(buffer, serializer) do
    # Assume length-prefixed messages handled by packet: 4
    case decode_message(buffer, serializer) do
      {:ok, message} ->
        {[message], <<>>}

      :incomplete ->
        {[], buffer}

      :error ->
        {[], <<>>}
    end
  end

  defp decode_message(<<>>, _serializer), do: :incomplete

  defp decode_message(data, :json) do
    case Jason.decode(data) do
      {:ok, decoded} -> {:ok, atomize_keys(decoded)}
      {:error, _} -> :error
    end
  end

  defp decode_message(data, :msgpack) do
    # Fallback to JSON
    decode_message(data, :json)
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  rescue
    _ -> map
  end

  defp atomize_keys(list) when is_list(list), do: list |> Enum.map(&atomize_keys/1)
  defp atomize_keys(value), do: value

  defp handle_response(%{correlation_id: nil} = _msg, state), do: state

  defp handle_response(%{correlation_id: correlation_id, payload: payload}, state) do
    case Map.pop(state.pending, correlation_id) do
      {nil, _} ->
        state

      {{from, sent_at}, new_pending} ->
        # Calculate latency
        latency = System.monotonic_time(:millisecond) - sent_at

        # Reply to caller
        GenServer.reply(from, {:ok, payload})

        # Update stats
        total_messages = state.stats.messages_received + 1

        new_avg =
          (state.stats.avg_latency_ms * state.stats.messages_received + latency) / total_messages

        new_stats = %{
          state.stats
          | messages_received: total_messages,
            avg_latency_ms: new_avg
        }

        %{state | pending: new_pending, stats: new_stats}
    end
  end
end
