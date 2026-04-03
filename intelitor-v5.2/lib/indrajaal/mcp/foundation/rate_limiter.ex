defmodule Indrajaal.MCP.Foundation.RateLimiter do
  @moduledoc """
  MCP Rate Limiter — Token bucket per client

  WHAT: Enforces per-client rate limiting for MCP requests using token bucket algorithm.
  WHY: Prevents abuse and ensures fair resource allocation across MCP clients (SC-MCP-073).
  CONSTRAINTS: SC-MCP-073, SC-API-001, AOR-API-002

  ## Algorithm
  Token bucket with configurable:
  - tokens_per_second: default 10
  - bucket_size: default 20 (allows burst)
  - refill_interval_ms: default 100

  ## STAMP Constraints
  - SC-MCP-073: Rate limiting MUST be enforced per MCP client
  - SC-API-001: Exponential backoff for rate-limited clients
  - AOR-API-002: Well-behaved clients implement backoff on 429/503

  ## Change History
  | Version | Date       | Author          | Change                 |
  |---------|------------|-----------------|------------------------|
  | 21.3.0  | 2026-03-23 | Claude Opus 4.6 | Initial implementation |
  """

  use GenServer
  require Logger

  @default_rate 10
  @default_burst 20
  @refill_ms 100

  # Separate ETS table from Auth module's :mcp_rate_limits table
  @table :mcp_token_buckets

  # Client API

  @doc """
  Starts the rate limiter service.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Check if request is allowed for client_id.

  Uses token bucket algorithm with O(1) ETS lookup.

  Returns `:ok` or `{:error, :rate_limited}`.
  """
  @spec check(String.t()) :: :ok | {:error, :rate_limited}
  def check(client_id) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, client_id) do
      [{^client_id, tokens, last_refill, rate, burst}] ->
        elapsed = now - last_refill
        refilled = tokens + elapsed / @refill_ms * rate / (1000 / @refill_ms)
        new_tokens = min(refilled, burst * 1.0)

        if new_tokens >= 1.0 do
          :ets.insert(@table, {client_id, new_tokens - 1.0, now, rate, burst})
          :ok
        else
          :ets.insert(@table, {client_id, new_tokens, now, rate, burst})
          Logger.warning("[MCP RateLimiter] Rate limited client=#{client_id}")
          {:error, :rate_limited}
        end

      [] ->
        # First request from this client — initialize bucket with burst-1 tokens
        :ets.insert(@table, {client_id, @default_burst - 1.0, now, @default_rate, @default_burst})
        :ok
    end
  end

  @doc """
  Configure rate limit for a specific client.

  Options:
  - `rate`: tokens per second (default: #{@default_rate})
  - `burst`: bucket capacity (default: #{@default_burst})
  """
  @spec configure(String.t(), keyword()) :: :ok
  def configure(client_id, opts) do
    rate = Keyword.get(opts, :rate, @default_rate)
    burst = Keyword.get(opts, :burst, @default_burst)
    now = System.monotonic_time(:millisecond)
    :ets.insert(@table, {client_id, burst * 1.0, now, rate, burst})
    :ok
  end

  @doc """
  Get current rate limit status for a client.

  Returns a map with tokens_remaining, rate, and burst capacity.
  """
  @spec status(String.t()) :: map()
  def status(client_id) do
    case :ets.lookup(@table, client_id) do
      [{^client_id, tokens, _last_refill, rate, burst}] ->
        %{
          client_id: client_id,
          tokens_remaining: Float.round(tokens, 1),
          rate: rate,
          burst: burst
        }

      [] ->
        %{
          client_id: client_id,
          tokens_remaining: @default_burst * 1.0,
          rate: @default_rate,
          burst: @default_burst
        }
    end
  end

  @doc """
  Reset the token bucket for a client (admin use).
  """
  @spec reset(String.t()) :: :ok
  def reset(client_id) do
    :ets.delete(@table, client_id)
    :ok
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    Logger.info(
      "[MCP RateLimiter] Started — default rate=#{@default_rate}/s burst=#{@default_burst}"
    )

    {:ok, %{table: table}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ets.delete(@table)
    :ok
  end
end
