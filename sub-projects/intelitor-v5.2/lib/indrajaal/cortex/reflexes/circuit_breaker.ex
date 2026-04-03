defmodule Indrajaal.Cortex.Reflexes.CircuitBreaker do
  @moduledoc """
  Reflex System implementing Circuit Breakers as a GenServer.
  Prevents cascading failures in external integrations.

  WHAT: GenServer-based circuit breaker with configurable thresholds and automatic recovery.
  WHY: Provides graceful degradation for external service dependencies.
  CONSTRAINTS: SC-CTX-003, SC-EMR-058, SC-OBS-071

  Task 22.4.2.1
  """
  use GenServer
  require Logger

  @default_failure_threshold 5
  @default_reset_timeout 30_000

  @default_circuits [:database, :external_api, :ml_inference, :flame_pool]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the circuit breaker GenServer.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a new circuit breaker with optional configuration.

  Options:
  - :failure_threshold - Number of failures before tripping (default: 5)
  - :reset_timeout - Time in ms before attempting recovery (default: 30_000)
  """
  @spec register(atom(), keyword()) :: :ok | {:error, term()}
  def register(name, opts \\ []) do
    GenServer.call(__MODULE__, {:register, name, opts})
  end

  @doc """
  Executes a function through the specified circuit breaker.
  Returns {:ok, result}, {:error, :circuit_open}, {:error, :circuit_not_found}, or {:error, exception}.
  """
  @spec call(atom(), (-> any())) :: {:ok, any()} | {:error, atom()} | {:error, Exception.t()}
  def call(name, func) when is_function(func, 0) do
    GenServer.call(__MODULE__, {:call, name, func})
  end

  @doc """
  Returns the status of all circuit breakers.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Returns the status of a specific circuit breaker.
  """
  @spec status(atom()) :: :closed | :open | :half_open | {:error, atom()}
  def status(name) do
    GenServer.call(__MODULE__, {:status, name})
  end

  @doc """
  Manually trips a circuit breaker.
  """
  @spec trip(atom()) :: :ok | {:error, atom()}
  def trip(name) do
    GenServer.call(__MODULE__, {:trip, name})
  end

  @doc """
  Manually resets a circuit breaker to closed state.
  """
  @spec reset(atom()) :: :ok | {:error, atom()}
  def reset(name) do
    GenServer.call(__MODULE__, {:reset, name})
  end

  @doc """
  Returns aggregate metrics for all circuit breakers.
  """
  @spec metrics() :: map()
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  # ============================================================================
  # Legacy API (for backward compatibility)
  # ============================================================================

  @doc """
  Initializes a circuit breaker (fuse) - legacy API.
  """
  @spec init_breaker(atom()) :: :ok | {:error, term()}
  def init_breaker(name) do
    register(name, [])
  end

  @doc """
  Asks the breaker for permission to execute - legacy API.
  """
  @spec ask(atom()) :: :ok | {:error, :circuit_open} | {:error, atom()}
  def ask(name) do
    case status(name) do
      {:ok, %{state: :closed}} ->
        :ok

      {:ok, %{state: :half_open}} ->
        :ok

      {:ok, %{state: :open}} ->
        :blown

      {:error, :not_found} ->
        register(name)
        :ok
    end
  end

  @doc """
  Reports a failure to the breaker - legacy API.
  """
  @spec report_failure(atom()) :: :ok
  def report_failure(name) do
    Logger.warning("CircuitBreaker: Failure reported for #{inspect(name)}")
    call(name, fn -> raise "reported failure" end)
    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Executes a block of code within a circuit breaker - legacy API.
  """
  @spec with_breaker(atom(), (-> any())) :: {:ok, any()} | {:error, atom()}
  def with_breaker(name, func) do
    call(name, func)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      circuits: %{},
      metrics: %{
        total_calls: 0,
        successful_calls: 0,
        failed_calls: 0,
        rejected_calls: 0,
        trips: 0,
        resets: 0
      }
    }

    # Register default circuits
    state =
      Enum.reduce(@default_circuits, state, fn name, acc ->
        register_circuit(acc, name, [])
      end)

    {:ok, state}
  end

  @impl true
  def handle_call({:register, name, opts}, _from, state) do
    state = register_circuit(state, name, opts)
    {:reply, :ok, state}
  end

  def handle_call({:call, name, func}, _from, state) do
    case Map.get(state.circuits, name) do
      nil ->
        {:reply, {:error, :circuit_not_found}, state}

      circuit ->
        {result, state} = execute_call(state, name, circuit, func)
        {:reply, result, state}
    end
  end

  def handle_call(:status, _from, state) do
    status_map =
      state.circuits
      |> Enum.map(fn {name, circuit} -> {name, circuit.state} end)
      |> Enum.into(%{})

    {:reply, status_map, state}
  end

  def handle_call({:status, name}, _from, state) do
    case Map.get(state.circuits, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      circuit ->
        info = %{
          name: name,
          state: circuit.state,
          failure_count: circuit.failure_count,
          failure_threshold: circuit.failure_threshold,
          reset_timeout: circuit.reset_timeout,
          last_failure_at: circuit.last_failure_at
        }

        {:reply, {:ok, info}, state}
    end
  end

  def handle_call({:trip, name}, _from, state) do
    case Map.get(state.circuits, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      circuit ->
        circuit = %{circuit | state: :open, last_failure_at: DateTime.utc_now()}
        state = put_in(state.circuits[name], circuit)
        state = update_in(state.metrics.trips, &(&1 + 1))

        # Schedule half-open transition
        schedule_half_open(name, circuit.reset_timeout)

        {:reply, :ok, state}
    end
  end

  def handle_call({:reset, name}, _from, state) do
    case Map.get(state.circuits, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      circuit ->
        circuit = %{circuit | state: :closed, failure_count: 0}
        state = put_in(state.circuits[name], circuit)
        state = update_in(state.metrics.resets, &(&1 + 1))
        {:reply, :ok, state}
    end
  end

  def handle_call(:metrics, _from, state) do
    circuit_states =
      state.circuits
      |> Enum.group_by(fn {_name, circuit} -> circuit.state end)
      |> Enum.map(fn {state, circuits} -> {state, length(circuits)} end)
      |> Enum.into(%{})

    metrics =
      Map.merge(state.metrics, %{
        circuit_states: circuit_states,
        total_circuits: map_size(state.circuits)
      })

    {:reply, metrics, state}
  end

  @impl true
  def handle_info({:transition_half_open, name}, state) do
    case Map.get(state.circuits, name) do
      nil ->
        {:noreply, state}

      circuit when circuit.state == :open ->
        circuit = %{circuit | state: :half_open}
        state = put_in(state.circuits[name], circuit)
        {:noreply, state}

      _circuit ->
        {:noreply, state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp register_circuit(state, name, opts) do
    circuit = %{
      state: :closed,
      failure_count: 0,
      failure_threshold: Keyword.get(opts, :failure_threshold, @default_failure_threshold),
      reset_timeout: Keyword.get(opts, :reset_timeout, @default_reset_timeout),
      last_failure_at: nil
    }

    put_in(state.circuits[name], circuit)
  end

  defp execute_call(state, name, circuit, func) do
    state = update_in(state.metrics.total_calls, &(&1 + 1))

    case circuit.state do
      :open ->
        state = update_in(state.metrics.rejected_calls, &(&1 + 1))
        {{:error, :circuit_open}, state}

      state_type when state_type in [:closed, :half_open] ->
        try do
          result = func.()
          state = update_in(state.metrics.successful_calls, &(&1 + 1))

          # If half-open and successful, close the circuit
          state =
            if state_type == :half_open do
              circuit = %{circuit | state: :closed, failure_count: 0}
              put_in(state.circuits[name], circuit)
            else
              state
            end

          {{:ok, result}, state}
        rescue
          e ->
            state = update_in(state.metrics.failed_calls, &(&1 + 1))
            state = record_failure(state, name, circuit)
            {{:error, e}, state}
        end
    end
  end

  defp record_failure(state, name, circuit) do
    new_failure_count = circuit.failure_count + 1
    circuit = %{circuit | failure_count: new_failure_count, last_failure_at: DateTime.utc_now()}

    if new_failure_count >= circuit.failure_threshold do
      circuit = %{circuit | state: :open}
      state = update_in(state.metrics.trips, &(&1 + 1))

      # Schedule half-open transition
      schedule_half_open(name, circuit.reset_timeout)

      put_in(state.circuits[name], circuit)
    else
      put_in(state.circuits[name], circuit)
    end
  end

  defp schedule_half_open(name, timeout) do
    Process.send_after(self(), {:transition_half_open, name}, timeout)
  end
end
