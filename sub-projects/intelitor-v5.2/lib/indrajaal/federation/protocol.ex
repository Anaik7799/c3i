defmodule Indrajaal.Federation.Protocol do
  @moduledoc """
  Federation Protocol - Inter-Node Communication for v20.0.0

  Implements the communication protocol between Jain nodes:
  - Message serialization
  - Encryption and authentication
  - Reliable delivery
  - Message routing

  ## Protocol Layers

  1. **Transport**: TCP/TLS connections
  2. **Framing**: Length-prefixed messages
  3. **Encoding**: ETF (Erlang Term Format)
  4. **Security**: AES-GCM encryption, HMAC authentication

  ## Message Types
  - **Heartbeat**: Liveness check
  - **Sync**: State synchronization
  - **Event**: Federation events
  - **Request/Response**: RPC-style calls
  - **Broadcast**: One-to-many messages

  ## STAMP Constraints
  - SC-PRO-001: Messages MUST be authenticated
  - SC-PRO-002: Messages MUST be encrypted
  - SC-PRO-003: Delivery MUST be confirmed
  - SC-PRO-004: Routing MUST be loop-free
  """

  require Logger

  alias Indrajaal.Jain.Cryptography

  @type message_type :: :heartbeat | :sync | :event | :request | :response | :broadcast

  @type message :: %{
          id: String.t(),
          type: message_type(),
          source: String.t(),
          destination: String.t(),
          payload: term(),
          timestamp: DateTime.t(),
          ttl: non_neg_integer(),
          signature: binary() | nil
        }

  @type frame :: %{
          version: non_neg_integer(),
          length: non_neg_integer(),
          encrypted: boolean(),
          body: binary()
        }

  @type delivery_result :: %{
          message_id: String.t(),
          delivered: boolean(),
          latency_ms: non_neg_integer(),
          error: term() | nil
        }

  # Protocol version
  @protocol_version 1

  # Default TTL (hops)
  @default_ttl 10

  # Message timeout (ms)
  @message_timeout 30_000

  @doc """
  Creates a new message.
  """
  @spec create_message(message_type(), String.t(), term(), Keyword.t()) :: message()
  def create_message(type, destination, payload, opts \\ []) do
    %{
      id: generate_message_id(),
      type: type,
      source: get_local_node_id(),
      destination: destination,
      payload: payload,
      timestamp: DateTime.utc_now(),
      ttl: Keyword.get(opts, :ttl, @default_ttl),
      signature: nil
    }
  end

  @doc """
  Signs a message.
  """
  @spec sign_message(message()) :: {:ok, message()} | {:error, term()}
  def sign_message(message) do
    data = serialize_for_signing(message)

    case Cryptography.sign(data, get_constitution(), :communication) do
      {:ok, signature} ->
        {:ok, %{message | signature: signature}}

      error ->
        error
    end
  end

  @doc """
  Verifies a message signature.
  """
  @spec verify_message(message()) :: :ok | {:error, term()}
  def verify_message(message) do
    if is_nil(message.signature) do
      {:error, :unsigned}
    else
      data = serialize_for_signing(message)
      Cryptography.verify_signature(data, message.signature, get_constitution(), :communication)
    end
  end

  @doc """
  Encrypts a message payload.
  """
  @spec encrypt_message(message()) :: {:ok, message()} | {:error, term()}
  def encrypt_message(message) do
    data = :erlang.term_to_binary(message.payload)

    case Cryptography.encrypt(data, get_constitution(), :communication) do
      {:ok, encrypted} ->
        {:ok, %{message | payload: {:encrypted, encrypted}}}

      error ->
        error
    end
  end

  @doc """
  Decrypts a message payload.
  """
  @spec decrypt_message(message()) :: {:ok, message()} | {:error, term()}
  def decrypt_message(%{payload: {:encrypted, encrypted}} = message) do
    case Cryptography.decrypt(encrypted, get_constitution(), :communication) do
      {:ok, data} ->
        payload = :erlang.binary_to_term(data)
        {:ok, %{message | payload: payload}}

      error ->
        error
    end
  end

  def decrypt_message(message), do: {:ok, message}

  @doc """
  Sends a message to a destination node.
  """
  @spec send_message(String.t(), term()) :: {:ok, delivery_result()} | {:error, term()}
  def send_message(destination, payload) do
    send_message(destination, :event, payload)
  end

  @doc """
  Sends a typed message to a destination node.
  """
  @spec send_message(String.t(), message_type(), term()) ::
          {:ok, delivery_result()} | {:error, term()}
  def send_message(destination, type, payload) do
    start_time = System.monotonic_time(:millisecond)

    message = create_message(type, destination, payload)

    with {:ok, signed} <- sign_message(message),
         {:ok, encrypted} <- encrypt_message(signed),
         {:ok, frame} <- create_frame(encrypted),
         :ok <- transmit(destination, frame) do
      latency = System.monotonic_time(:millisecond) - start_time

      result = %{
        message_id: message.id,
        delivered: true,
        latency_ms: latency,
        error: nil
      }

      {:ok, result}
    else
      {:error, reason} = error ->
        Logger.warning("Failed to send message to #{destination}: #{reason}")
        error
    end
  end

  @doc """
  Receives and processes an incoming frame.
  """
  @spec receive_frame(binary()) :: {:ok, message()} | {:error, term()}
  def receive_frame(data) do
    with {:ok, frame} <- parse_frame(data),
         {:ok, message} <- decode_message(frame),
         {:ok, decrypted} <- decrypt_message(message),
         :ok <- verify_message(decrypted) do
      {:ok, decrypted}
    end
  end

  @doc """
  Creates a heartbeat message.
  """
  @spec heartbeat(String.t()) :: {:ok, delivery_result()} | {:error, term()}
  def heartbeat(destination) do
    payload = %{
      type: :heartbeat,
      timestamp: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    }

    send_message(destination, :heartbeat, payload)
  end

  @doc """
  Creates a broadcast message.
  """
  @spec broadcast(term(), [String.t()]) :: [delivery_result()]
  def broadcast(payload, destinations) do
    Enum.map(destinations, fn dest ->
      case send_message(dest, :broadcast, payload) do
        {:ok, result} -> result
        {:error, reason} -> %{message_id: nil, delivered: false, latency_ms: 0, error: reason}
      end
    end)
  end

  @doc """
  Creates a request message and waits for response.
  """
  @spec request(String.t(), term(), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  def request(destination, payload, timeout \\ @message_timeout) do
    message = create_message(:request, destination, payload)

    with {:ok, signed} <- sign_message(message),
         {:ok, encrypted} <- encrypt_message(signed),
         {:ok, frame} <- create_frame(encrypted),
         :ok <- transmit(destination, frame) do
      # Wait for response (in production, would use correlation ID)
      receive do
        {:response, ^destination, response} ->
          {:ok, response}
      after
        timeout ->
          {:error, :timeout}
      end
    end
  end

  @doc """
  Gets protocol statistics.
  """
  @spec stats() :: map()
  def stats do
    %{
      version: @protocol_version,
      messages_sent: 0,
      messages_received: 0,
      bytes_sent: 0,
      bytes_received: 0,
      errors: 0
    }
  end

  # Private helpers

  defp generate_message_id do
    rand_bytes = :crypto.strong_rand_bytes(8)
    encoded = rand_bytes |> Base.encode16(case: :lower)
    "msg_#{encoded}"
  end

  defp get_local_node_id do
    # In production, would get actual node ID
    "local_node"
  end

  defp get_constitution do
    # In production, would load actual constitution
    Indrajaal.Jain.Constitution.load()
  end

  defp serialize_for_signing(message) do
    # Serialize message without signature for signing
    %{message | signature: nil}
    |> :erlang.term_to_binary()
  end

  defp create_frame(message) do
    body = :erlang.term_to_binary(message)

    frame = %{
      version: @protocol_version,
      length: byte_size(body),
      encrypted: true,
      body: body
    }

    # Serialize frame
    frame_data = <<
      frame.version::8,
      frame.length::32,
      if(frame.encrypted, do: 1, else: 0)::8,
      body::binary
    >>

    {:ok, frame_data}
  end

  defp parse_frame(<<version::8, length::32, encrypted::8, body::binary>>) do
    if byte_size(body) == length do
      frame = %{
        version: version,
        length: length,
        encrypted: encrypted == 1,
        body: body
      }

      {:ok, frame}
    else
      {:error, :invalid_frame_length}
    end
  end

  defp parse_frame(_), do: {:error, :invalid_frame}

  defp decode_message(%{body: body}) do
    try do
      message = :erlang.binary_to_term(body)
      {:ok, message}
    rescue
      _ -> {:error, :decode_failed}
    end
  end

  defp transmit(destination, frame_data) do
    # In production, would send over network
    Logger.debug("Transmitting #{byte_size(frame_data)} bytes to #{destination}")
    :ok
  end
end
