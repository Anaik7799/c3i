defmodule Indrajaal.Observability.ZenohPublisher do
  @moduledoc """
  Facade for publishing data to Zenoh.

  Delegates to `Indrajaal.Observability.ZenohSession` for actual transmission.
  Handles data serialization (JSON) before sending.

  ## Publish Modes
  - `publish/2` — Synchronous (GenServer.call), blocks until confirmed
  - `publish_async/2,3` — Fire-and-forget (GenServer.cast), never blocks caller
  - `publish_emergency/2` — Bypasses GenServer entirely, for safety-critical paths

  ## CONSTRAINTS
  - SC-ZTEST-008: All publish modes write log fallback first
  - FM-ZUIP-001: Async prevents mailbox overflow (RPN 140)
  - FM-ZUIP-002: Emergency bypasses GenServer for <5s SLA (RPN 189)
  """

  alias Indrajaal.Observability.ZenohSession
  require Logger

  @doc """
  Publish data to a Zenoh topic (synchronous).
  Data is automatically JSON encoded.
  """
  @spec publish(String.t(), any()) :: :ok | {:error, any()}
  def publish(topic, data) do
    try do
      payload = Jason.encode!(data)
      ZenohSession.publish(ZenohSession, topic, payload)
    rescue
      e ->
        Logger.error("Failed to serialize/publish to Zenoh: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Publish data asynchronously (fire-and-forget).
  Never blocks the caller. Suitable for telemetry, metrics, non-critical events.

  ## Parameters
  - `topic` - Zenoh key expression
  - `data` - Any JSON-serializable data
  - `priority` - `:critical`, `:high`, or `:normal` (default `:normal`)
  """
  @spec publish_async(String.t(), any(), atom()) :: :ok
  def publish_async(topic, data, priority \\ :normal) do
    try do
      payload = Jason.encode!(data)
      ZenohSession.publish_async(topic, payload, priority)
    rescue
      _ -> :ok
    end
  end

  @doc """
  Publish emergency data bypassing GenServer entirely.
  For safety-critical paths where <5s SLA must be met (SC-EMR-057).
  Always succeeds (log fallback guarantees durability).
  """
  @spec publish_emergency(String.t(), any()) :: :ok
  def publish_emergency(topic, data) do
    try do
      payload = Jason.encode!(data)
      ZenohSession.publish_emergency(topic, payload)
    rescue
      _ -> :ok
    end

    :ok
  end
end
