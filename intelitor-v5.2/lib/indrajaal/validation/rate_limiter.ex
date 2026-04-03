defmodule Indrajaal.Validation.RateLimiter do
  @moduledoc """
  Rate limiting implementation for OpenCode API with exponential backoff.

  Features:
  - Token bucket algorithm for request rate limiting
  - Exponential backoff with jitter for retry delays
  - Per-session rate limit tracking
  - Automatic rate limit recovery
  - EP-110/EP-111 prevention through careful state management
  """

  use GenServer
  require Logger

  # Rate limiting configuration
  @max_requests_per_minute 30
  # 2 seconds
  @bucket_refill_interval 2000
  @tokens_per_refill 4

  # Exponential backoff configuration
  @initial_retry_delay 1000
  @backoff_multiplier 2
  @max_retry_delay 30_000
  @jitter_range 0.1
  @max_consecutive_failures 5

  defstruct [
    :session_id,
    :tokens,
    :max_tokens,
    :last_refill,
    :consecutive_failures,
    :rate_limited_until,
    :request_history,
    :total_requests,
    :total_rate_limits
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          tokens: integer(),
          max_tokens: integer(),
          last_refill: integer(),
          consecutive_failures: integer(),
          rate_limited_until: integer() | nil,
          request_history: list(integer()),
          total_requests: integer(),
          total_rate_limits: integer()
        }

  # Public API

  @doc """
  Starts a rate limiter for a specific session.

  ## Examples

      iex> RateLimiter.start_link(session_id: "session_123")
      {:ok, #PID<0.123.0>}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    name = via_tuple(session_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Checks if a request can be made or if rate limiting should be applied.

  ## Examples

      iex> RateLimiter.check_rate_limit("session_123")
      :ok

      iex> RateLimiter.check_rate_limit("session_123")
      {:rate_limited, 5000}
  """
  @spec check_rate_limit(String.t()) :: :ok | {:rate_limited, integer()}
  def check_rate_limit(session_id) do
    GenServer.call(via_tuple(session_id), :check_rate_limit)
  catch
    :exit, {:noproc, _} ->
      # Start rate limiter if it doesn't exist
      {:ok, _pid} = start_link(session_id: session_id)
      check_rate_limit(session_id)
  end

  @doc """
  Records a successful request.

  ## Examples

      iex> RateLimiter.record_success("session_123")
      :ok
  """
  @spec record_success(String.t()) :: :ok
  def record_success(session_id) do
    GenServer.cast(via_tuple(session_id), :record_success)
  end

  @doc """
  Records a failed request that resulted in rate limiting.

  ## Examples

      iex> RateLimiter.record_rate_limit("session_123")
      {:ok, 2000}
  """
  @spec record_rate_limit(String.t()) :: {:ok, integer()}
  def record_rate_limit(session_id) do
    GenServer.call(via_tuple(session_id), :record_rate_limit)
  end

  @doc """
  Gets current rate limiter status for a session.

  ## Examples

      iex> RateLimiter.get_status("session_123")
      %{tokens: 10, consecutive_failures: 0, rate_limited: false}
  """
  @spec get_status(String.t()) :: map()
  def get_status(session_id) do
    GenServer.call(via_tuple(session_id), :get_status)
  catch
    :exit, {:noproc, _} ->
      %{tokens: @max_requests_per_minute, consecutive_failures: 0, rate_limited: false}
  end

  @doc """
  Resets rate limiter for a session (useful for testing).

  ## Examples

      iex> RateLimiter.reset("session_123")
      :ok
  """
  @spec reset(String.t()) :: :ok
  def reset(session_id) do
    GenServer.call(via_tuple(session_id), :reset)
  catch
    :exit, {:noproc, _} -> :ok
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    max_tokens = Keyword.get(opts, :max_tokens, @max_requests_per_minute)

    state = %__MODULE__{
      session_id: session_id,
      tokens: max_tokens,
      max_tokens: max_tokens,
      last_refill: System.monotonic_time(:millisecond),
      consecutive_failures: 0,
      rate_limited_until: nil,
      request_history: [],
      total_requests: 0,
      total_rate_limits: 0
    }

    # Schedule token refill
    Process.send_after(self(), :refill_tokens, @bucket_refill_interval)

    Logger.info("Rate limiter started", session_id: session_id, max_tokens: max_tokens)
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:check_rate_limit, _from, state) do
    now = System.monotonic_time(:millisecond)

    # Check if currently rate limited
    if state.rate_limited_until && now < state.rate_limited_until do
      remaining_ms = state.rate_limited_until - now
      Logger.debug("Rate limited", session_id: state.session_id, remaining_ms: remaining_ms)
      {:reply, {:rate_limited, remaining_ms}, state}
    else
      # Check token bucket
      state = refill_tokens_if_needed(state, now)

      if state.tokens > 0 do
        # Consume a token
        new_state = %{
          state
          | tokens: state.tokens - 1,
            # Keep last 60 requests
            request_history: [now | Enum.take(state.request_history, 59)],
            total_requests: state.total_requests + 1,
            rate_limited_until: nil,
            consecutive_failures: 0
        }

        Logger.debug("Request allowed",
          session_id: state.session_id,
          tokens_remaining: new_state.tokens
        )

        {:reply, :ok, new_state}
      else
        # No tokens available
        backoff_ms = calculate_exponential_backoff(state.consecutive_failures)
        rate_limited_until = now + backoff_ms

        new_state = %{
          state
          | rate_limited_until: rate_limited_until,
            consecutive_failures: min(state.consecutive_failures + 1, @max_consecutive_failures),
            total_rate_limits: state.total_rate_limits + 1
        }

        Logger.warning("Rate limit exceeded",
          session_id: state.session_id,
          backoff_ms: backoff_ms,
          consecutive_failures: new_state.consecutive_failures
        )

        {:reply, {:rate_limited, backoff_ms}, new_state}
      end
    end
  end

  @impl GenServer
  def handle_call(:record_rate_limit, _from, state) do
    backoff_ms = calculate_exponential_backoff(state.consecutive_failures)
    now = System.monotonic_time(:millisecond)

    new_state = %{
      state
      | rate_limited_until: now + backoff_ms,
        consecutive_failures: min(state.consecutive_failures + 1, @max_consecutive_failures),
        total_rate_limits: state.total_rate_limits + 1
    }

    Logger.warning("Rate limit recorded",
      session_id: state.session_id,
      backoff_ms: backoff_ms,
      consecutive_failures: new_state.consecutive_failures
    )

    {:reply, {:ok, backoff_ms}, new_state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    now = System.monotonic_time(:millisecond)

    status = %{
      tokens: state.tokens,
      max_tokens: state.max_tokens,
      consecutive_failures: state.consecutive_failures,
      rate_limited: state.rate_limited_until != nil && now < state.rate_limited_until,
      rate_limited_for_ms: max(0, (state.rate_limited_until || now) - now),
      total_requests: state.total_requests,
      total_rate_limits: state.total_rate_limits,
      requests_in_last_minute: count_recent_requests(state.request_history, now)
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | tokens: state.max_tokens,
        consecutive_failures: 0,
        rate_limited_until: nil,
        request_history: [],
        last_refill: System.monotonic_time(:millisecond)
    }

    Logger.info("Rate limiter reset", session_id: state.session_id)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_cast(:record_success, state) do
    new_state = %{state | consecutive_failures: 0, rate_limited_until: nil}

    Logger.debug("Success recorded, failures reset", session_id: state.session_id)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:refill_tokens, state) do
    now = System.monotonic_time(:millisecond)
    state = refill_tokens_if_needed(state, now)

    # Schedule next refill
    Process.send_after(self(), :refill_tokens, @bucket_refill_interval)

    {:noreply, state}
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Indrajaal.Validation.RateLimiterRegistry, session_id}}
  end

  defp refill_tokens_if_needed(state, now) do
    time_since_refill = now - state.last_refill
    refills_due = div(time_since_refill, @bucket_refill_interval)

    if refills_due > 0 do
      tokens_to_add = refills_due * @tokens_per_refill
      new_tokens = min(state.tokens + tokens_to_add, state.max_tokens)

      %{state | tokens: new_tokens, last_refill: now}
    else
      state
    end
  end

  defp calculate_exponential_backoff(consecutive_failures) do
    attempt = min(consecutive_failures, @max_consecutive_failures)
    base_delay = @initial_retry_delay
    multiplier = :math.pow(@backoff_multiplier, attempt)
    jitter = base_delay * @jitter_range * (:rand.uniform() - 0.5)

    delay = base_delay * multiplier + jitter
    capped_delay = min(delay, @max_retry_delay)
    round(capped_delay)
  end

  defp count_recent_requests(request_history, now) do
    one_minute_ago = now - 60_000

    Enum.count(request_history, fn timestamp ->
      timestamp > one_minute_ago
    end)
  end
end
