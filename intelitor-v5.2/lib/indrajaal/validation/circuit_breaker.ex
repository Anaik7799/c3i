defmodule Indrajaal.Validation.CircuitBreaker do
  @moduledoc """
  Circuit breaker pattern implementation for OpenCode API client.

  Prevents cascading failures by monitoring error rates and temporarily
  blocking requests to failing services.

  States:
  - :closed - Normal operation, requests pass through
  - :open - Circuit tripped, requests fail fast
  - :half_open - Testing if service recovered

  Features:
  - Automatic state transitions based on failure thresholds
  - Configurable failure thresholds and timeouts
  - Success/failure counting with sliding window
  - Telemetry integration for monitoring
  """

  use GenServer
  require Logger

  # Circuit breaker configuration
  @default_config %{
    # Failures to trip circuit
    failure_threshold: 5,
    # Successes to close circuit
    success_threshold: 2,
    # Time before trying half-open
    timeout: 30_000,
    # Sliding window for metrics
    window_size: 60_000,
    # Max requests in half-open state
    half_open_requests: 3
  }

  defstruct [
    :name,
    :state,
    :config,
    :failure_count,
    :success_count,
    :last_failure_time,
    :state_changed_at,
    :half_open_requests,
    :metrics_window
  ]

  @type t :: %__MODULE__{
          name: atom(),
          state: :closed | :open | :half_open,
          config: map(),
          failure_count: integer(),
          success_count: integer(),
          last_failure_time: integer() | nil,
          state_changed_at: integer(),
          half_open_requests: integer(),
          metrics_window: list()
        }

  # Public API

  @doc """
  Starts a circuit breaker process.

  ## Options
  - `:name` - Circuit breaker name (required)
  - `:failure_threshold` - Number of failures to open circuit
  - `:success_threshold` - Number of successes to close circuit
  - `:timeout` - Time in ms before attempting half-open
  - `:window_size` - Sliding window size for metrics
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Executes a function through the circuit breaker.

  ## Examples

      iex> CircuitBreaker.call(:api_breaker, fn -> make_request() end)
      {:ok, result}

      iex> CircuitBreaker.call(:api_breaker, fn -> failing_request() end)
      {:error, :circuit_open}
  """
  @spec call(atom(), function()) :: {:ok, any()} | {:error, any()}
  def call(name, fun) do
    GenServer.call(via_tuple(name), {:call, fun}, 60_000)
  catch
    :exit, {:noproc, _} ->
      # Circuit breaker not started, execute directly
      Logger.warning("Circuit breaker #{name} not started, executing directly")
      execute_function(fun)
  end

  @doc """
  Gets the current state of the circuit breaker.

  ## Examples

      iex> CircuitBreaker.get_state(:api_breaker)
      {:closed, %{failures: 0, successes: 10}}
  """
  @spec get_state(atom()) :: {atom(), map()}
  def get_state(name) do
    GenServer.call(via_tuple(name), :get_state)
  catch
    :exit, {:noproc, _} ->
      {:error, :not_started}
  end

  @doc """
  Manually resets the circuit breaker to closed state.
  """
  @spec reset(atom()) :: :ok
  def reset(name) do
    GenServer.call(via_tuple(name), :reset)
  catch
    :exit, {:noproc, _} ->
      {:error, :not_started}
  end

  @doc """
  Manually trips the circuit breaker to open state.
  """
  @spec trip(atom()) :: :ok
  def trip(name) do
    GenServer.call(via_tuple(name), :trip)
  catch
    :exit, {:noproc, _} ->
      {:error, :not_started}
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    name = Keyword.fetch!(opts, :name)

    config =
      @default_config
      |> Map.merge(
        Map.new(
          Keyword.take(opts, [
            :failure_threshold,
            :success_threshold,
            :timeout,
            :window_size,
            :half_open_requests
          ])
        )
      )

    state = %__MODULE__{
      name: name,
      state: :closed,
      config: config,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      state_changed_at: System.monotonic_time(:millisecond),
      half_open_requests: 0,
      metrics_window: []
    }

    Logger.info("Circuit breaker started",
      name: name,
      config: config
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:call, fun}, _from, state) do
    case state.state do
      :closed ->
        handle_closed_call(fun, state)

      :open ->
        handle_open_call(fun, state)

      :half_open ->
        handle_half_open_call(fun, state)
    end
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    info = %{
      state: state.state,
      failures: state.failure_count,
      successes: state.success_count,
      last_failure: state.last_failure_time,
      state_duration: System.monotonic_time(:millisecond) - state.state_changed_at
    }

    {:reply, {state.state, info}, state}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | state: :closed,
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil,
        state_changed_at: System.monotonic_time(:millisecond),
        half_open_requests: 0
    }

    Logger.info("Circuit breaker manually reset", name: state.name)
    emit_telemetry(new_state, :reset)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:trip, _from, state) do
    new_state = transition_to_open(state, :manual_trip)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:check_timeout, state) do
    # Check if we should transition from open to half-open
    if state.state == :open do
      time_in_open = System.monotonic_time(:millisecond) - state.state_changed_at

      if time_in_open >= state.config.timeout do
        new_state = transition_to_half_open(state)
        {:noreply, new_state}
      else
        # Schedule next check
        Process.send_after(self(), :check_timeout, state.config.timeout - time_in_open)
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  # Private functions

  defp via_tuple(name) do
    {:via, Registry, {Indrajaal.Validation.CircuitBreakerRegistry, name}}
  end

  defp handle_closed_call(fun, state) do
    case execute_function(fun) do
      {:ok, result} ->
        new_state = record_success(state)
        {:reply, {:ok, result}, new_state}

      {:error, _reason} = error ->
        new_state = record_failure(state)

        # Check if we should open the circuit
        new_state =
          if new_state.failure_count >= state.config.failure_threshold do
            transition_to_open(new_state, :threshold_exceeded)
          else
            new_state
          end

        {:reply, error, new_state}
    end
  end

  defp handle_open_call(fun, state) do
    # Check if timeout has passed
    time_in_open = System.monotonic_time(:millisecond) - state.state_changed_at

    if time_in_open >= state.config.timeout do
      # Transition to half-open and try the request
      new_state = transition_to_half_open(state)
      handle_half_open_call(fun, new_state)
    else
      # Fail fast
      Logger.debug("Circuit open, failing fast", name: state.name)
      {:reply, {:error, :circuit_open}, state}
    end
  end

  defp handle_half_open_call(fun, state) do
    if state.half_open_requests >= state.config.half_open_requests do
      # Too many requests in half-open, fail fast
      {:reply, {:error, :circuit_half_open_limit}, state}
    else
      new_state = %{state | half_open_requests: state.half_open_requests + 1}

      case execute_function(fun) do
        {:ok, result} ->
          new_state = record_success(new_state)

          # Check if we should close the circuit
          new_state =
            if new_state.success_count >= state.config.success_threshold do
              transition_to_closed(new_state)
            else
              new_state
            end

          {:reply, {:ok, result}, new_state}

        {:error, _reason} = error ->
          # Single failure in half-open reopens the circuit
          new_state = record_failure(new_state)
          new_state = transition_to_open(new_state, :half_open_failure)
          {:reply, error, new_state}
      end
    end
  end

  defp execute_function(fun) do
    try do
      case fun.() do
        {:ok, _} = success -> success
        {:error, _} = error -> error
        result -> {:ok, result}
      end
    rescue
      error ->
        Logger.error("Function execution failed", error: inspect(error))
        {:error, error}
    end
  end

  defp record_success(state) do
    now = System.monotonic_time(:millisecond)

    %{
      state
      | success_count: state.success_count + 1,
        metrics_window:
          update_metrics_window(state.metrics_window, {:success, now}, state.config.window_size)
    }
  end

  defp record_failure(state) do
    now = System.monotonic_time(:millisecond)

    %{
      state
      | failure_count: state.failure_count + 1,
        last_failure_time: now,
        metrics_window:
          update_metrics_window(state.metrics_window, {:failure, now}, state.config.window_size)
    }
  end

  defp update_metrics_window(window, event, window_size) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - window_size

    # Remove old events and add new one
    window
    |> Enum.filter(fn {_type, time} -> time > cutoff end)
    |> Enum.concat([event])
    # Limit window size to prevent memory issues
    |> Enum.take(-1000)
  end

  defp transition_to_open(state, reason) do
    new_state = %{
      state
      | state: :open,
        state_changed_at: System.monotonic_time(:millisecond),
        half_open_requests: 0
    }

    Logger.warning("Circuit breaker opened",
      name: state.name,
      reason: reason,
      failures: state.failure_count
    )

    emit_telemetry(new_state, :opened)

    # Schedule timeout check
    Process.send_after(self(), :check_timeout, state.config.timeout)

    new_state
  end

  defp transition_to_half_open(state) do
    new_state = %{
      state
      | state: :half_open,
        state_changed_at: System.monotonic_time(:millisecond),
        failure_count: 0,
        success_count: 0,
        half_open_requests: 0
    }

    Logger.info("Circuit breaker half-open", name: state.name)
    emit_telemetry(new_state, :half_opened)

    new_state
  end

  defp transition_to_closed(state) do
    new_state = %{
      state
      | state: :closed,
        state_changed_at: System.monotonic_time(:millisecond),
        failure_count: 0,
        success_count: 0,
        half_open_requests: 0
    }

    Logger.info("Circuit breaker closed", name: state.name)
    emit_telemetry(new_state, :closed)

    new_state
  end

  defp emit_telemetry(state, event) do
    :telemetry.execute(
      [:circuit_breaker, event],
      %{
        failures: state.failure_count,
        successes: state.success_count,
        state: state.state
      },
      %{name: state.name}
    )
  end
end
