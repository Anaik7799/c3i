defmodule Indrajaal.Core.VSM.System1Operations do
  @moduledoc """
  VSM System 1: Operations - The Doing for v20.0.0

  System 1 is the operational core of the Viable System Model:
  - Executes business logic
  - Processes requests
  - Produces outputs
  - Reports to System 3 (Control)

  ## Responsibilities
  - Execute holon-specific operations
  - Track operation metrics
  - Report success/failure to S3
  - Maintain operational state

  ## STAMP Constraints
  - SC-S1-001: Operations MUST be idempotent where possible
  - SC-S1-002: Operations MUST emit telemetry
  - SC-S1-003: Operations MUST complete within configured timeout
  - SC-S1-004: Failed operations MUST be reported to S3

  ## Category Theory
  S1 forms a Monad over the Result type:
  - return : a → Result a
  - bind : Result a → (a → Result b) → Result b
  """

  require Logger

  alias Indrajaal.Core.Holon.Metrics

  @type operation_result :: {:ok, term()} | {:error, term()}
  @type operation_context :: %{
          holon_id: String.t(),
          layer: atom(),
          operation: atom(),
          args: term(),
          timeout: non_neg_integer()
        }

  @default_timeout 5_000

  @doc """
  Executes an operation with monitoring and telemetry.
  """
  @spec execute(operation_context(), (-> operation_result())) :: operation_result()
  def execute(context, operation_fn) do
    start_time = System.monotonic_time(:millisecond)

    result =
      try do
        timeout = Map.get(context, :timeout, @default_timeout)

        task = Task.async(fn -> operation_fn.() end)
        Task.await(task, timeout)
      rescue
        e ->
          Logger.error("S1 Operation failed: #{inspect(e)}")
          {:error, {:exception, Exception.message(e)}}
      catch
        :exit, {:timeout, _} ->
          Logger.warning("S1 Operation timed out")
          {:error, :timeout}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    # Emit telemetry (SC-S1-002)
    Metrics.emit_operation(
      context.holon_id,
      context.layer,
      context.operation,
      duration
    )

    result
  end

  @doc """
  Wraps a value in a successful result.
  """
  @spec return(term()) :: {:ok, term()}
  def return(value), do: {:ok, value}

  @doc """
  Chains operations (monadic bind).
  """
  @spec bind(operation_result(), (term() -> operation_result())) :: operation_result()
  def bind({:ok, value}, fun), do: fun.(value)
  def bind({:error, _} = error, _fun), do: error

  @doc """
  Maps a function over a successful result.
  """
  @spec map(operation_result(), (term() -> term())) :: operation_result()
  def map({:ok, value}, fun), do: {:ok, fun.(value)}
  def map({:error, _} = error, _fun), do: error

  @doc """
  Combines multiple operations, failing fast on first error.
  """
  @spec sequence([operation_result()]) :: operation_result()
  def sequence(results) do
    reduced =
      Enum.reduce_while(results, {:ok, []}, fn
        {:ok, value}, {:ok, acc} -> {:cont, {:ok, [value | acc]}}
        {:error, _} = error, _ -> {:halt, error}
      end)

    reduced
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  @doc """
  Executes operations in parallel and collects results.
  """
  @spec parallel([operation_context()], [(-> operation_result())]) :: [operation_result()]
  def parallel(contexts, operations) when length(contexts) == length(operations) do
    contexts
    |> Enum.zip(operations)
    |> Enum.map(fn {ctx, op} ->
      Task.async(fn -> execute(ctx, op) end)
    end)
    |> Task.await_many(@default_timeout)
  end

  @doc """
  Creates an operation context.
  """
  @spec context(String.t(), atom(), atom(), term(), Keyword.t()) :: operation_context()
  def context(holon_id, layer, operation, args, opts \\ []) do
    %{
      holon_id: holon_id,
      layer: layer,
      operation: operation,
      args: args,
      timeout: Keyword.get(opts, :timeout, @default_timeout)
    }
  end

  @doc """
  Retries an operation with exponential backoff.
  """
  @spec retry(operation_context(), (-> operation_result()), Keyword.t()) :: operation_result()
  def retry(context, operation_fn, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay = Keyword.get(opts, :base_delay, 100)

    do_retry(context, operation_fn, max_attempts, base_delay, 1)
  end

  defp do_retry(_context, _operation_fn, max_attempts, _delay, attempt)
       when attempt > max_attempts do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(context, operation_fn, max_attempts, base_delay, attempt) do
    case execute(context, operation_fn) do
      {:ok, _} = success ->
        success

      {:error, reason} = error ->
        if retryable?(reason) and attempt < max_attempts do
          delay = (base_delay * :math.pow(2, attempt - 1)) |> round()
          Process.sleep(delay)
          do_retry(context, operation_fn, max_attempts, base_delay, attempt + 1)
        else
          error
        end
    end
  end

  defp retryable?(:timeout), do: true
  defp retryable?({:exception, _}), do: true
  defp retryable?(_), do: false
end
