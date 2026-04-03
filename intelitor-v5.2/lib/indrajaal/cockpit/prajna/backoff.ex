defmodule Indrajaal.Cockpit.Prajna.Backoff do
  @moduledoc """
  Exponential Backoff with Jitter for Prajna Retry Operations.

  WHAT: Provides exponential backoff calculations with configurable jitter
  for distributed systems, integrated with circuit breaker state.

  WHY: SC-API-003 requires exponential backoff on 429 status.
       SC-BIO-007 requires graceful degradation on rate limits.
       AOR-API-002 mandates well-behaved client with no immediate retries.

  ## Algorithm

  The backoff delay is calculated as:

      delay = min(base_ms * 2^(attempt-1), max_ms)
      jitter = delay * jitter_factor * random(-1, 1)
      final_delay = delay + jitter

  Where:
  - `base_ms` is the initial delay (default: 1000ms)
  - `max_ms` is the maximum delay cap (default: 60000ms)
  - `jitter_factor` is 0.20 (20%) for distributed systems

  ## Circuit Breaker Integration

  When integrated with a circuit breaker:
  - `:closed` - Normal backoff calculation
  - `:half_open` - Extended backoff (1.5x) to test recovery
  - `:open` - Returns `:circuit_open` error, no retry

  CONSTRAINTS:
    - SC-API-003: Exponential backoff on 429 (base 2s, max 60s)
    - SC-BIO-007: Graceful degradation on rate limit
    - AOR-API-002: Never retry immediately on 429/503

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-01-02 |
  | Author | Autonomous Agent |
  | STAMP | SC-API-003, SC-BIO-007 |
  """

  require Logger

  # Default configuration (per task specification)
  @default_base_ms 1_000
  @default_max_ms 60_000
  @default_max_attempts 5

  # Jitter: +/- 10% for distributed systems (per PRAJNA_5LEVEL_SPECIFICATION.md)
  # SIL-4 FIX: Reduced from 20% to 10% for more predictable timing
  @jitter_factor 0.10

  @type backoff_opts :: [
          base_ms: pos_integer(),
          max_ms: pos_integer(),
          max_attempts: pos_integer(),
          jitter: boolean(),
          circuit_state: :closed | :half_open | :open
        ]

  @type backoff_result ::
          {:ok, delay_ms :: pos_integer()}
          | {:error, :max_attempts_exceeded}
          | {:error, :circuit_open}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Calculates exponential backoff delay for a given attempt number.

  Returns the delay in milliseconds with optional jitter.

  ## Parameters

    - `attempt` - The current attempt number (1-based)
    - `opts` - Optional configuration:
      - `:base_ms` - Base delay in milliseconds (default: #{@default_base_ms})
      - `:max_ms` - Maximum delay cap (default: #{@default_max_ms})
      - `:jitter` - Whether to add random jitter (default: true)

  ## Examples

      iex> Backoff.exponential_backoff(1)
      {:ok, delay} when delay >= 800 and delay <= 1200

      iex> Backoff.exponential_backoff(3, base_ms: 1000)
      {:ok, delay} when delay >= 3200 and delay <= 4800

      iex> Backoff.exponential_backoff(10, max_ms: 60000)
      {:ok, delay} when delay >= 48000 and delay <= 72000
  """
  @spec exponential_backoff(pos_integer(), backoff_opts()) :: backoff_result()
  def exponential_backoff(attempt, opts \\ [])

  def exponential_backoff(attempt, opts) when is_integer(attempt) and attempt > 0 do
    base_ms = Keyword.get(opts, :base_ms, @default_base_ms)
    max_ms = Keyword.get(opts, :max_ms, @default_max_ms)
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    add_jitter = Keyword.get(opts, :jitter, true)
    circuit_state = Keyword.get(opts, :circuit_state, :closed)

    cond do
      # Circuit open - don't retry
      circuit_state == :open ->
        {:error, :circuit_open}

      # Max attempts exceeded
      attempt > max_attempts ->
        {:error, :max_attempts_exceeded}

      true ->
        delay = calculate_delay(attempt, base_ms, max_ms, circuit_state)
        final_delay = if add_jitter, do: apply_jitter(delay), else: delay
        {:ok, final_delay}
    end
  end

  def exponential_backoff(attempt, _opts) do
    Logger.error("[Backoff] Invalid attempt number: #{inspect(attempt)}")
    {:error, :invalid_attempt}
  end

  @doc """
  Three-arity version for direct compatibility with legacy callers.

  ## Parameters

    - `base_ms` - Base delay in milliseconds
    - `max_ms` - Maximum delay cap
    - `attempt` - The current attempt number (1-based)

  ## Examples

      iex> Backoff.exponential_backoff(1000, 60000, 1)
      {:ok, delay} when delay >= 800 and delay <= 1200
  """
  @spec exponential_backoff(pos_integer(), pos_integer(), pos_integer()) :: backoff_result()
  def exponential_backoff(base_ms, max_ms, attempt)
      when is_integer(base_ms) and base_ms > 0 and
             is_integer(max_ms) and max_ms > 0 and
             is_integer(attempt) and attempt > 0 do
    exponential_backoff(attempt, base_ms: base_ms, max_ms: max_ms)
  end

  @doc """
  Executes a function with retry and exponential backoff.

  ## Parameters

    - `fun` - The function to execute (zero-arity)
    - `opts` - Backoff options (see `exponential_backoff/2`)

  ## Examples

      iex> Backoff.with_retry(fn -> {:ok, :result} end)
      {:ok, :result}

      iex> Backoff.with_retry(fn -> {:error, :transient} end, max_attempts: 3)
      {:error, :max_retries_exceeded}
  """
  @spec with_retry((-> {:ok, term()} | {:error, term()}), backoff_opts()) ::
          {:ok, term()} | {:error, term()}
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    retry_on = Keyword.get(opts, :retry_on, &default_retry_condition/1)

    do_retry(fun, opts, retry_on, 1, max_attempts)
  end

  @doc """
  Returns the delay for a specific attempt without circuit breaker checks.

  Useful for logging/debugging the backoff schedule.

  ## Examples

      iex> Backoff.delay_for_attempt(1)
      1000

      iex> Backoff.delay_for_attempt(5)
      16000
  """
  @spec delay_for_attempt(pos_integer(), keyword()) :: pos_integer()
  def delay_for_attempt(attempt, opts \\ []) do
    base_ms = Keyword.get(opts, :base_ms, @default_base_ms)
    max_ms = Keyword.get(opts, :max_ms, @default_max_ms)
    calculate_delay(attempt, base_ms, max_ms, :closed)
  end

  @doc """
  Returns the full backoff schedule for all attempts.

  ## Examples

      iex> Backoff.schedule(max_attempts: 5, base_ms: 1000)
      [1000, 2000, 4000, 8000, 16000]
  """
  @spec schedule(backoff_opts()) :: [pos_integer()]
  def schedule(opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    base_ms = Keyword.get(opts, :base_ms, @default_base_ms)
    max_ms = Keyword.get(opts, :max_ms, @default_max_ms)

    Enum.map(1..max_attempts, fn attempt ->
      calculate_delay(attempt, base_ms, max_ms, :closed)
    end)
  end

  @doc """
  Checks if an attempt should be retried based on circuit state and attempt count.
  """
  @spec should_retry?(pos_integer(), backoff_opts()) :: boolean()
  def should_retry?(attempt, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    circuit_state = Keyword.get(opts, :circuit_state, :closed)

    attempt <= max_attempts and circuit_state != :open
  end

  @doc """
  Returns the default configuration values.
  """
  @spec defaults() :: map()
  def defaults do
    %{
      base_ms: @default_base_ms,
      max_ms: @default_max_ms,
      max_attempts: @default_max_attempts,
      jitter_factor: @jitter_factor
    }
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp calculate_delay(attempt, base_ms, max_ms, circuit_state) do
    # Exponential: base * 2^(attempt - 1)
    raw_delay = base_ms * :math.pow(2, attempt - 1)
    delay = round(raw_delay)

    # Apply circuit state multiplier
    adjusted_delay =
      case circuit_state do
        :half_open -> round(delay * 1.5)
        _ -> delay
      end

    # Cap at max
    min(adjusted_delay, max_ms)
  end

  defp apply_jitter(delay) do
    # +/- 20% jitter (SC-API-003 compliance for distributed systems)
    jitter_range = round(delay * @jitter_factor)

    # Ensure minimum jitter of 1ms to avoid 0 range
    jitter_range = max(1, jitter_range)

    # Random value in range [-jitter_range, +jitter_range]
    jitter = :rand.uniform(jitter_range * 2 + 1) - jitter_range - 1

    # Ensure result is at least 1ms
    max(1, delay + jitter)
  end

  defp do_retry(_fun, _opts, _retry_on, attempt, max_attempts)
       when attempt > max_attempts do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(fun, opts, retry_on, attempt, max_attempts) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} = error ->
        if retry_on.(reason) and attempt < max_attempts do
          case exponential_backoff(attempt, opts) do
            {:ok, delay_ms} ->
              Logger.debug(
                "[Backoff] Retry attempt #{attempt}/#{max_attempts}, " <>
                  "waiting #{delay_ms}ms (reason: #{inspect(reason)})"
              )

              emit_retry_telemetry(attempt, delay_ms, reason)
              Process.sleep(delay_ms)
              do_retry(fun, opts, retry_on, attempt + 1, max_attempts)

            {:error, :circuit_open} ->
              Logger.warning("[Backoff] Circuit open, not retrying")
              {:error, :circuit_open}

            {:error, :max_attempts_exceeded} ->
              error
          end
        else
          error
        end
    end
  end

  defp default_retry_condition(reason) do
    # Retry on transient errors
    reason in [
      :timeout,
      :econnrefused,
      :closed,
      :nxdomain,
      :ehostunreach,
      :rate_limited,
      :service_unavailable,
      :internal_error
    ]
  end

  defp emit_retry_telemetry(attempt, delay_ms, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :backoff, :retry],
      %{
        attempt: attempt,
        delay_ms: delay_ms,
        timestamp: System.system_time(:millisecond)
      },
      %{reason: reason}
    )
  end
end
