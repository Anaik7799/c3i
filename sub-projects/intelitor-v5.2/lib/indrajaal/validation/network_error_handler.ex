defmodule Indrajaal.Validation.NetworkErrorHandler do
  @moduledoc """
  Network error recovery patterns for OpenCode API client.

  Implements comprehensive error handling strategies including:
  - Automatic retry with exponential backoff
  - Connection pooling and failover
  - Graceful degradation strategies
  - Error classification and recovery actions
  """

  require Logger

  # Error classification
  @retryable_errors [
    :econnrefused,
    :econnreset,
    :etimedout,
    :timeout,
    :closed,
    :nxdomain,
    :ehostunreach,
    :enetunreach,
    :socket_closed_remotely
  ]

  @non_retryable_errors [
    :bad_request,
    :unauthorized,
    :forbidden,
    :not_found,
    :method_not_allowed,
    :unprocessable_entity
  ]

  # Recovery strategies
  @recovery_strategies %{
    network: :retry_with_backoff,
    rate_limit: :wait_and_retry,
    server_error: :circuit_breaker,
    auth_error: :refresh_token,
    client_error: :fail_fast
  }

  @doc """
  Handles network errors with appropriate recovery strategy.

  ## Examples

      iex> NetworkErrorHandler.handle_error({:error, :econnrefused}, opts)
      {:retry, 1000}

      iex> NetworkErrorHandler.handle_error({:error, :unauthorized}, opts)
      {:refresh_auth, :immediate}
  """
  def handle_error(error, opts \\ []) do
    error_type = classify_error(error)
    strategy = get_recovery_strategy(error_type)

    Logger.info("Network error detected",
      error_type: error_type,
      strategy: strategy,
      error: inspect(error)
    )

    execute_recovery_strategy(strategy, error, opts)
  end

  @doc """
  Classifies error into categories for appropriate handling.
  """
  def classify_error({:error, reason}) when is_atom(reason) do
    cond do
      reason in @retryable_errors -> :network
      reason in @non_retryable_errors -> :client_error
      reason == :rate_limited -> :rate_limit
      true -> :unknown
    end
  end

  def classify_error({:error, %{status: status}}) when is_integer(status) do
    cond do
      status == 429 -> :rate_limit
      status in 400..499 -> :client_error
      status in 500..599 -> :server_error
      true -> :unknown
    end
  end

  def classify_error({:error, %Mint.TransportError{reason: reason}}) do
    classify_error({:error, reason})
  end

  def classify_error({:error, %{__struct__: Req.Error, reason: reason}}) do
    classify_error({:error, reason})
  end

  def classify_error(_), do: :unknown

  @doc """
  Gets recovery strategy for error type.
  """
  def get_recovery_strategy(error_type) do
    Map.get(@recovery_strategies, error_type, :fail_fast)
  end

  @doc """
  Executes the appropriate recovery strategy.
  """
  def execute_recovery_strategy(:retry_with_backoff, _error, opts) do
    attempt = Keyword.get(opts, :attempt, 0)
    max_attempts = Keyword.get(opts, :max_attempts, 5)

    if attempt < max_attempts do
      delay = calculate_backoff_delay(attempt)
      {:retry, delay, attempt: attempt + 1}
    else
      {:error, :max_retries_exceeded}
    end
  end

  def execute_recovery_strategy(:wait_and_retry, _error, opts) do
    # For rate limiting, use the delay provided or default
    delay = Keyword.get(opts, :retry_after, 60_000)
    {:retry, delay, reset_attempts: true}
  end

  def execute_recovery_strategy(:circuitbreaker, _error, opts) do
    circuit_state = Keyword.get(opts, :circuit_state, :closed)

    case circuit_state do
      :closed ->
        # Trip the circuit breaker
        {:circuit_break, :open, cooldown: 30_000}

      :half_open ->
        # Failed again, go back to open
        {:circuit_break, :open, cooldown: 60_000}

      :open ->
        # Already open, fail fast
        {:error, :circuit_open}
    end
  end

  def execute_recovery_strategy(:refresh_token, _error, _opts) do
    {:refresh_auth, :immediate}
  end

  def execute_recovery_strategy(:fail_fast, error, _opts) do
    {:error, error}
  end

  def execute_recovery_strategy(_, error, _opts) do
    {:error, error}
  end

  @doc """
  Calculates exponential backoff delay with jitter.
  """
  def calculate_backoff_delay(attempt) do
    # 1 second
    base_delay = 1000
    # 30 seconds
    max_delay = 30_000
    multiplier = :math.pow(2, attempt)
    jitter = :rand.uniform() * 0.1 * base_delay

    delay = base_delay * multiplier + jitter
    min_delay = min(delay, max_delay)
    min_delay |> round()
  end

  @doc """
  Wraps a function call with automatic retry logic.

  ## Examples

      iex> NetworkErrorHandler.with_retry(fn -> make_api_call() end)
      {:ok, result}
  """
  def with_retry(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 5)
    attempt = Keyword.get(opts, :attempt, 0)

    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} = error ->
        case handle_error(error, attempt: attempt, max_attempts: max_attempts) do
          {:retry, delay, new_opts} ->
            Logger.debug("Retrying after #{delay}ms", attempt: attempt + 1)
            Process.sleep(delay)
            with_retry(fun, new_opts ++ [max_attempts: max_attempts])

          {:error, _} = final_error ->
            final_error

          other ->
            {:error, {:unexpected_recovery_result, other}}
        end
    end
  end

  @doc """
  Connection pool health check and failover management.
  """
  def check_connection_health(pool_name) do
    # Check if connection pool is healthy
    case get_pool_stats(pool_name) do
      {:ok, stats} ->
        evaluate_pool_health(stats)

        # Unreachable clause commented out - get_pool_stats/1 (line 217) always returns {:ok, ...}
        # {:error, :pool_not_found} ->
        #   {:error, :pool_not_initialized}
    end
  end

  defp get_pool_stats(_pool_name) do
    # In real implementation, this would check actual pool stats
    # For now, return mock stats
    {:ok,
     %{
       active_connections: 5,
       idle_connections: 10,
       failed_requests: 2,
       success_rate: 0.98
     }}
  end

  defp evaluate_pool_health(stats) do
    cond do
      stats.success_rate < 0.5 ->
        {:unhealthy, :high_failure_rate}

      stats.active_connections == 0 and stats.idle_connections == 0 ->
        {:unhealthy, :no_connections}

      stats.success_rate < 0.9 ->
        {:degraded, :elevated_errors}

      true ->
        {:healthy, stats}
    end
  end

  @doc """
  Implements connection failover to backup endpoints.
  """
  def failover_connection(primary_url, backup_urls) do
    # Try primary first
    case test_connection(primary_url) do
      :ok ->
        {:ok, primary_url}

      {:error, _} ->
        # Try backup URLs in order
        backup_urls
        |> Enum.find_value(fn url ->
          case test_connection(url) do
            :ok -> {:ok, url}
            _ -> nil
          end
        end)
        |> case do
          nil -> {:error, :all_endpoints_failed}
          result -> result
        end
    end
  end

  defp test_connection(url) do
    # Simple connection test
    case Req.head(url, retry: false, timeout: 5000) do
      {:ok, %{status: status}} when status in 200..499 ->
        :ok

      _ ->
        {:error, :connection_failed}
    end
  end
end
