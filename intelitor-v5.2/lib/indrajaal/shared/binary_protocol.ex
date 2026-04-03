defmodule Indrajaal.Shared.BinaryProtocol do
  @moduledoc """
  High-performance Binary Protocol for Elixir↔F# Communication.
  Uses MessagePack (Msgpax) to reduce payload size and CPU distortion.

  STAMP: SC-BINARY-001 (Zero-Copy), SC-FRAC-007 (Versioned Payloads)
  """

  @protocol_version <<1>>

  @doc """
  Encodes a map into a versioned binary payload.
  """
  def encode(map) when is_map(map) do
    data = Msgpax.pack!(map)
    @protocol_version <> data
  end

  @doc """
  Decodes a versioned binary payload into a map.
  """
  def decode(<<@protocol_version, rest::binary>>) do
    Msgpax.unpack(rest)
  end

  def decode(binary) when is_binary(binary) do
    {:error, :unsupported_version}
  end
end
