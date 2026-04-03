defmodule Indrajaal.AI.OpenRouter.RetryStrategy do
  @moduledoc """
  Exponential backoff with jitter for OpenRouter API resilience.

  Implements intelligent retry logic that handles transient failures
  while avoiding retry storms through randomized jitter.

  ## STAMP Constraints

  - SC-AI-RETRY-001: Maximum 3 retry attempts with exponential backoff
  - SC-AI-RETRY-002: Jitter factor 0.1-0.3 prevents thundering herd
  - SC-AI-RETRY-003: Non-retryable errors fail fast

  ## Usage

      RetryStrategy.execute(fn ->
        OpenRouterClient.chat(messages, opts)
      end, max_attempts: 3, base_delay_ms: 1000)

  ## Retryable Errors

  The following error types trigger retry:
  - Rate limits (429)
  - Timeouts (connect, recv)
  - Network errors (econnrefused, closed)
  - Server errors (500, 502, 503, 504)

  ## Non-Retryable Errors

  These errors fail immediately:
  - Authentication (401, 403)
  - Bad request (400)
  - Not found (404)
  - Invalid API key
  - Content policy violations
  """

  require Logger

  @type retry_opts :: [
          max_attempts: pos_integer(),
          base_delay_ms: pos_integer(),
          max_delay_ms: pos_integer(),
          jitter_factor: float()
        ]

  @type result :: {:ok, term()} | {:error, term()}

  @default_max_attempts 3
  @default_base_delay_ms 1_000
  @default_max_delay_ms 30_000
  @default_jitter_factor 0.2

  # Retryable HTTP status codes
  @retryable_status_codes [429, 500, 502, 503, 504]

  # Retryable error atoms
  @retryable_errors [
    :rate_limited,
    :timeout,
    :connect_timeout,
    :recv_timeout,
    :network_error,
    :econnrefused,
    :closed,
    :nxdomain,
    :ehostunreach
  ]

  # Non-retryable error atoms (fail fast)
  @non_retryable_errors [
    :invalid_api_key,
    :invalid_model,
    :context_length_exceeded,
    :content_policy_violation,
    :insufficient_quota,
    :invalid_request
  ]

  @doc """
  Returns the default retry options.
  """
  @spec default_options() :: retry_opts()
  def default_options do
    [
      max_attempts: @default_max_attempts,
      base_delay_ms: @default_base_delay_ms,
      max_delay_ms: @default_max_delay_ms,
      jitter_factor: @default_jitter_factor
    ]
  end

  @doc """
  Executes a function with retry logic.

  The function will be retried up to `max_attempts` times on retryable errors,
  with exponential backoff and jitter between attempts.

  ## Options

  - `:max_attempts` - Maximum number of attempts (default: 3)
  - `:base_delay_ms` - Base delay in milliseconds (default: 1000)
  - `:max_delay_ms` - Maximum delay cap in milliseconds (default: 30_000)
  - `:jitter_factor` - Jitter factor 0.0-1.0 (default: 0.2)

  ## Examples

      iex> RetryStrategy.execute(fn -> {:ok, "success"} end)
      {:ok, "success"}

      iex> RetryStrategy.execute(fn -> {:error, :timeout} end, max_attempts: 3)
      {:error, :timeout}  # After 3 attempts

  """
  @spec execute((-> result()), retry_opts()) :: result()
  def execute(fun, opts \\ []) when is_function(fun, 0) do
    opts = Keyword.merge(default_options(), opts)
    max_attempts = Keyword.fetch!(opts, :max_attempts)

    do_execute(fun, opts, 1, max_attempts)
  end

  @doc """
  Calculates the delay for a given attempt number.

  Uses exponential backoff with optional jitter:
  - Base formula: `base_delay_ms * 2^(attempt-1)`
  - Capped at `max_delay_ms`
  - Jitter applied as `delay * (1 ± jitter_factor)`

  ## Examples

      iex> RetryStrategy.calculate_delay(1, base_delay_ms: 1000, jitter_factor: 0.0)
      1000

      iex> RetryStrategy.calculate_delay(3, base_delay_ms: 1000, jitter_factor: 0.0)
      4000

  """
  @spec calculate_delay(pos_integer(), retry_opts()) :: pos_integer()
  def calculate_delay(attempt, opts) do
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)
    jitter_factor = Keyword.get(opts, :jitter_factor, @default_jitter_factor)

    # Calculate exponential delay: base * 2^(attempt-1)
    raw_delay = base_delay_ms * :math.pow(2, attempt - 1)

    # Cap at max delay
    capped_delay = min(raw_delay, max_delay_ms)

    # Apply jitter
    apply_jitter(capped_delay, jitter_factor)
  end

  @doc """
  Determines if an error is retryable.

  Returns `true` for transient errors that may succeed on retry:
  - Rate limits (429)
  - Timeouts
  - Network errors
  - Server errors (5xx)

  Returns `false` for permanent errors:
  - Authentication errors (401, 403)
  - Bad requests (400)
  - Invalid API keys
  - Content policy violations

  ## Examples

      iex> RetryStrategy.retryable_error?(:timeout)
      true

      iex> RetryStrategy.retryable_error?(:invalid_api_key)
      false

      iex> RetryStrategy.retryable_error?({:http_error, 429})
      true

  """
  @spec retryable_error?(term()) :: boolean()
  def retryable_error?(error) when error in @retryable_errors, do: true
  def retryable_error?(error) when error in @non_retryable_errors, do: false

  # HTTP error tuples
  def retryable_error?({:http_error, status}) when status in @retryable_status_codes, do: true

  def retryable_error?({:http_error, status, _body}) when status in @retryable_status_codes,
    do: true

  def retryable_error?({:http_error, _status}), do: false
  def retryable_error?({:http_error, _status, _body}), do: false

  # Default: assume non-retryable for safety
  def retryable_error?(_), do: false

  # Private implementation

  defp do_execute(fun, opts, attempt, max_attempts) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} = error ->
        if attempt < max_attempts and retryable_error?(reason) do
          delay = calculate_delay(attempt, opts)

          Logger.debug(
            "[RetryStrategy] Attempt #{attempt}/#{max_attempts} failed with #{inspect(reason)}. " <>
              "Retrying in #{delay}ms"
          )

          Process.sleep(delay)
          do_execute(fun, opts, attempt + 1, max_attempts)
        else
          if attempt >= max_attempts do
            Logger.warning(
              "[RetryStrategy] All #{max_attempts} attempts exhausted. Last error: #{inspect(reason)}"
            )
          end

          error
        end
    end
  end

  defp apply_jitter(delay, jitter_factor) when jitter_factor == 0.0, do: trunc(delay)

  defp apply_jitter(delay, jitter_factor) do
    # Generate random factor in range [1-jitter, 1+jitter]
    jitter = 1.0 + (:rand.uniform() * 2 - 1) * jitter_factor
    trunc(delay * jitter)
  end
end
