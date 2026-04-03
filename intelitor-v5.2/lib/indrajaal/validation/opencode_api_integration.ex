defmodule Indrajaal.Validation.OpenCodeApiIntegration do
  @moduledoc """
  Unified OpenCode API integration combining all components:
  - Authentication management
  - Rate limiting
  - Network error handling
  - Timeout management
  - Circuit breaker protection

  This module provides the main interface for interacting with
  the OpenCode API in production environments.
  """

  alias Indrajaal.Validation.{
    OpenCodeApiClient,
    RateLimiter,
    NetworkErrorHandler,
    TimeoutHandler,
    CircuitBreaker
  }

  require Logger

  @default_timeout 30_000
  @circuit_breaker_name :opencode_api_breaker

  @doc """
  Initializes the API integration components.
  Must be called during application startup.
  """
  def init do
    # Initialize timeout cache
    TimeoutHandler.init_cache()

    # Start circuit breaker
    {:ok, _} =
      CircuitBreaker.start_link(
        name: @circuit_breaker_name,
        failure_threshold: 5,
        success_threshold: 2,
        timeout: 30_000
      )

    Logger.info("OpenCode API integration initialized")
    :ok
  end

  @doc """
  Validates code using the OpenCode API with full error handling.

  ## Options
  - `:session_id` - Session identifier for rate limiting
  - `:timeout` - Request timeout in milliseconds
  - `:retries` - Maximum number of retry attempts
  - `:cache` - Whether to use cached results on timeout

  ## Examples

      iex> OpenCodeApiIntegration.validate_code("def hello, do: :world", session_id: "123")
      {:ok, %{valid: true, issues: []}}

      iex> OpenCodeApiIntegration.validate_code("invalid", session_id: "123")
      {:ok, %{valid: false, issues: ["syntax error"]}}
  """
  def validate_code(code, opts \\ []) do
    session_id = Keyword.get(opts, :session_id, "default")
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    # Check rate limiting first
    case RateLimiter.check_rate_limit(session_id) do
      :ok ->
        execute_validation(code, session_id, timeout, opts)

      {:rate_limited, retry_after} ->
        Logger.warning("Rate limited, retry after #{retry_after}ms",
          session_id: session_id
        )

        # Record rate limit hit
        RateLimiter.record_rate_limit(session_id)

        {:error, {:rate_limited, retry_after}}
    end
  end

  @doc """
  Gets validation status with circuit breaker protection.
  """
  def get_validation_status(validation_id, opts \\ []) do
    session_id = Keyword.get(opts, :session_id, "default")

    case RateLimiter.check_rate_limit(session_id) do
      :ok ->
        CircuitBreaker.call(@circuit_breaker_name, fn ->
          execute_status_check(validation_id, opts)
        end)

      {:rate_limited, retry_after} ->
        {:error, {:rate_limited, retry_after}}
    end
  end

  @doc """
  Submits batch validation with automatic retry and error handling.
  """
  def validate_batch(code_samples, opts \\ []) do
    session_id = Keyword.get(opts, :session_id, "default")

    # Check rate limit
    case RateLimiter.check_rate_limit(session_id) do
      :ok ->
        execute_batch_validation(code_samples, session_id, opts)

      {:rate_limited, retry_after} ->
        {:error, {:rate_limited, retry_after}}
    end
  end

  # Private functions

  # Note: session_id parameter prefixed with underscore (EP302 - unused variable)
  # session_id would be used for RateLimiter.record_success when OpenCodeApiClient implementation is complete
  defp execute_validation(code, _session_id, timeout, opts) do
    CircuitBreaker.call(@circuit_breaker_name, fn ->
      perform_validation_with_timeout(code, timeout, opts)
    end)
  end

  defp perform_validation_with_timeout(code, timeout, opts) do
    TimeoutHandler.with_timeout(
      fn -> perform_validation_with_retry(code, opts) end,
      timeout: timeout,
      degradation: :partial,
      cache_key: {:validation, hash_code(code)}
    )
  end

  defp perform_validation_with_retry(code, opts) do
    NetworkErrorHandler.with_retry(
      fn -> OpenCodeApiClient.validate_code(code) end,
      max_attempts: Keyword.get(opts, :retries, 3)
    )
  end

  defp execute_status_check(validation_id, opts) do
    TimeoutHandler.with_timeout(
      fn ->
        NetworkErrorHandler.with_retry(
          fn ->
            # This would call the actual API
            # For now, return mock response
            {:ok,
             %{
               id: validation_id,
               status: "completed",
               result: %{valid: true, issues: []}
             }}
          end,
          max_attempts: 2
        )
      end,
      timeout: Keyword.get(opts, :timeout, 10_000),
      degradation: :minimal
    )
  end

  defp execute_batch_validation(code_samples, session_id, opts) do
    # Process batch with concurrency control
    max_concurrent = Keyword.get(opts, :max_concurrent, 5)

    code_samples
    |> Task.async_stream(
      fn sample ->
        validate_code(sample, session_id: session_id, timeout: 60_000)
      end,
      max_concurrency: max_concurrent,
      timeout: 120_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, :timeout} -> {:error, :timeout}
      {:exit, reason} -> {:error, reason}
    end)
  end

  defp hash_code(code) do
    hash = :crypto.hash(:sha256, code)

    hash
    |> Base.encode16()
    |> String.slice(0..7)
  end

  @doc """
  Health check for the API integration.
  Returns status of all components.
  """
  def health_check do
    %{
      circuit_breaker: CircuitBreaker.get_state(@circuit_breaker_name),
      rate_limiter: check_rate_limiter_health(),
      api_client: OpenCodeApiClient.health_check(),
      integration: :healthy
    }
  end

  defp check_rate_limiter_health do
    # Check a test session
    case RateLimiter.get_status("health_check") do
      %{tokens: tokens} when tokens > 0 -> :healthy
      _ -> :degraded
    end
  end
end
