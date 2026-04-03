defmodule Indrajaal.Cockpit.Prajna.Bio.Membrane do
  @moduledoc """
  ## The Holon Membrane - Protection Boundaries for Domain APIs

  WHAT: Acts as a proxy/firewall for every Holon, enforcing protection boundaries
        around domain APIs with rate limiting, circuit breaking, and health-aware
        routing.

  WHY: Implements the biological membrane metaphor where the cell membrane controls
       what enters and exits the cell. In our system, this protects domain boundaries
       from overload, unhealthy dependencies, and cascading failures.

  CONSTRAINTS:
    - SC-BIO-002: Rejects non-conforming messages
    - SC-PRF-050: Response time < 50ms
    - SC-CIRCUIT-001: Circuit breaker integration
    - SC-OBS-069: Telemetry emission for all crossings

  ## Features

  1. **Ingest Inspection**: Validates message schema (GeneticPayload)
  2. **Metabolic Metering**: Enforces rate limits (backpressure)
  3. **Immunological Tagging**: Allows Antibodies to attach markers
  4. **Circuit Breaker Integration**: Prevents cascading failures
  5. **Health-Aware Routing**: Bypasses unhealthy endpoints
  6. **Telemetry Emission**: Full observability of membrane crossings

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-29 |
  | Author | L3-BIO-2 (Biomorphic Architecture Worker) |
  | STAMP | SC-BIO-002, SC-PRF-050, SC-CIRCUIT-001, SC-OBS-069 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.Bio.Types
  # CircuitBreaker integration is handled through internal state management
  # See: @circuit_failure_threshold and circuit breaker state transitions
  alias Types.GeneticPayload

  # ═══════════════════════════════════════════════════════════════════════════
  # CONFIGURATION
  # ═══════════════════════════════════════════════════════════════════════════

  # Rate limiting defaults
  @default_rate_limit 1000
  @rate_window_ms 60_000

  # Health check defaults
  @health_check_interval_ms 5_000
  @unhealthy_threshold 3

  # Circuit breaker thresholds
  @circuit_failure_threshold 5
  @circuit_reset_timeout_ms 30_000

  # ═══════════════════════════════════════════════════════════════════════════
  # STATE STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════════

  defstruct [
    :name,
    :target_pid,
    :target_module,
    :genetic_schema,
    :metabolic_rate,
    :immune_tags,
    :msg_count,
    :rate_limit,
    :rate_window_start,
    :health_status,
    :consecutive_failures,
    :circuit_state,
    :circuit_failure_count,
    :circuit_last_failure,
    :endpoint_health_cache,
    :telemetry_prefix
  ]

  @type t :: %__MODULE__{
          name: atom() | nil,
          target_pid: pid() | nil,
          target_module: module() | nil,
          genetic_schema: module() | nil,
          metabolic_rate: non_neg_integer(),
          immune_tags: list(atom()),
          msg_count: non_neg_integer(),
          rate_limit: non_neg_integer(),
          rate_window_start: integer(),
          health_status: :healthy | :degraded | :unhealthy,
          consecutive_failures: non_neg_integer(),
          circuit_state: :closed | :open | :half_open,
          circuit_failure_count: non_neg_integer(),
          circuit_last_failure: integer() | nil,
          endpoint_health_cache: %{atom() => health_entry()},
          telemetry_prefix: list(atom())
        }

  @type health_entry :: %{
          status: :healthy | :unhealthy,
          last_check: integer(),
          failure_count: non_neg_integer()
        }

  @type crossing_result :: {:ok, term()} | {:error, crossing_error()}

  @type crossing_error ::
          :compromised
          | :invalid_genome
          | :metabolic_limit
          | :circuit_open
          | :endpoint_unhealthy
          | :rate_limited

  # ═══════════════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Start a Membrane GenServer protecting a target process.

  ## Options
    - `:name` - Registration name (required)
    - `:target` - Target PID or module to protect (required)
    - `:rate_limit` - Max messages per rate window (default: #{@default_rate_limit})
    - `:telemetry_prefix` - Custom telemetry event prefix

  ## Examples

      iex> Membrane.start_link(name: :accounts_membrane, target: Indrajaal.Accounts)
      {:ok, pid}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Cross the membrane with a message, enforcing all protection policies.

  This is the primary entry point for protected domain API calls.
  Returns {:ok, result} on success or {:error, reason} on rejection.

  ## Examples

      iex> Membrane.cross(:accounts_membrane, {:get_user, user_id})
      {:ok, %User{}}

      iex> Membrane.cross(:accounts_membrane, {:get_user, user_id})
      {:error, :rate_limited}
  """
  @spec cross(GenServer.server(), term(), keyword()) :: crossing_result()
  def cross(membrane, message, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    GenServer.call(membrane, {:cross, message}, timeout)
  end

  @doc """
  Wrap a domain API function with membrane protection.

  Returns a function that automatically routes through the membrane.

  ## Examples

      protected_get_user = Membrane.wrap(:accounts_membrane, &Accounts.get_user/1)
      protected_get_user.(user_id)
  """
  @spec wrap(GenServer.server(), (... -> term())) :: (... -> crossing_result())
  def wrap(membrane, fun) when is_function(fun) do
    fn args ->
      cross(membrane, {:call, fun, args})
    end
  end

  @doc """
  Protect a domain API module by wrapping all its public functions.

  Returns a map of wrapped functions keyed by function name.
  """
  @spec protect_module(GenServer.server(), module()) :: %{atom() => function()}
  def protect_module(membrane, module) do
    functions = module.__info__(:functions)

    functions
    |> Enum.map(fn {name, arity} ->
      wrapper = create_wrapper(membrane, module, name, arity)
      {name, wrapper}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Attach an immune tag to the membrane (used by Antibodies).
  """
  @spec attach_tag(GenServer.server(), atom()) :: :ok
  def attach_tag(membrane, tag) do
    GenServer.cast(membrane, {:immune_tag, tag})
  end

  @doc """
  Get the current health status of the membrane.
  """
  @spec health(GenServer.server()) :: %{status: atom(), metrics: map()}
  def health(membrane) do
    GenServer.call(membrane, :health)
  end

  @doc """
  Update endpoint health status (called by health monitors).
  """
  @spec update_endpoint_health(GenServer.server(), atom(), :healthy | :unhealthy) :: :ok
  def update_endpoint_health(membrane, endpoint, status) do
    GenServer.cast(membrane, {:update_endpoint_health, endpoint, status})
  end

  @doc """
  Reset the circuit breaker (manual intervention).
  """
  @spec reset_circuit(GenServer.server()) :: :ok
  def reset_circuit(membrane) do
    GenServer.cast(membrane, :reset_circuit)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl true
  def init(opts) do
    # Schedule periodic health check
    Process.send_after(self(), :health_check, @health_check_interval_ms)

    state = %__MODULE__{
      name: Keyword.get(opts, :name),
      target_pid: resolve_target(opts[:target]),
      target_module: extract_module(opts[:target]),
      genetic_schema: opts[:schema],
      metabolic_rate: 0,
      immune_tags: [],
      msg_count: 0,
      rate_limit: Keyword.get(opts, :rate_limit, @default_rate_limit),
      rate_window_start: System.monotonic_time(:millisecond),
      health_status: :healthy,
      consecutive_failures: 0,
      circuit_state: :closed,
      circuit_failure_count: 0,
      circuit_last_failure: nil,
      endpoint_health_cache: %{},
      telemetry_prefix: Keyword.get(opts, :telemetry_prefix, [:indrajaal, :membrane])
    }

    emit_telemetry(state, :started, %{target: inspect(opts[:target])})

    {:ok, state}
  end

  @impl true
  def handle_call({:cross, message}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    case attempt_crossing(message, state) do
      {:ok, new_state} ->
        # Forward to target and track timing
        result = execute_crossing(message, new_state)
        duration = System.monotonic_time(:microsecond) - start_time

        emit_crossing_telemetry(new_state, :success, message, duration)

        case result do
          {:ok, {:error, _} = response} ->
            # Target returned error tuple - counts as failure for circuit breaker
            {:reply, {:ok, response}, record_failure(new_state, :target_error)}

          {:ok, response} ->
            {:reply, {:ok, response}, record_success(new_state)}

          {:error, reason} ->
            {:reply, {:error, reason}, record_failure(new_state, reason)}
        end

      {:error, reason} = error ->
        duration = System.monotonic_time(:microsecond) - start_time
        emit_crossing_telemetry(state, :rejected, message, duration, reason)
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:health, _from, state) do
    health_report = %{
      status: state.health_status,
      metrics: %{
        message_count: state.msg_count,
        rate_limit: state.rate_limit,
        circuit_state: state.circuit_state,
        circuit_failures: state.circuit_failure_count,
        consecutive_failures: state.consecutive_failures,
        immune_tags: state.immune_tags,
        endpoints: map_size(state.endpoint_health_cache)
      }
    }

    {:reply, health_report, state}
  end

  @impl true
  def handle_cast({:immune_tag, tag}, state) do
    Logger.info("[Membrane:#{state.name}] Antibody attached tag: #{tag}")
    emit_telemetry(state, :immune_tag_attached, %{tag: tag})
    {:noreply, %{state | immune_tags: [tag | state.immune_tags]}}
  end

  @impl true
  def handle_cast({:update_endpoint_health, endpoint, status}, state) do
    # Accumulate failure counts instead of replacing
    existing = Map.get(state.endpoint_health_cache, endpoint, %{failure_count: 0})
    existing_count = Map.get(existing, :failure_count, 0)

    new_failure_count =
      case status do
        :unhealthy -> existing_count + 1
        :healthy -> 0
      end

    entry = %{
      status: status,
      last_check: System.monotonic_time(:millisecond),
      failure_count: new_failure_count
    }

    new_cache = Map.put(state.endpoint_health_cache, endpoint, entry)

    emit_telemetry(state, :endpoint_health_updated, %{
      endpoint: endpoint,
      status: status
    })

    {:noreply, %{state | endpoint_health_cache: new_cache}}
  end

  @impl true
  def handle_cast(:reset_circuit, state) do
    Logger.info("[Membrane:#{state.name}] Circuit breaker manually reset")
    emit_telemetry(state, :circuit_reset, %{previous_state: state.circuit_state})

    {:noreply, %{state | circuit_state: :closed, circuit_failure_count: 0}}
  end

  @impl true
  def handle_cast(msg, state) do
    # Legacy message handling (backward compatibility)
    new_count = state.msg_count + 1

    with :ok <- check_immune_status(state),
         :ok <- validate_schema(msg),
         :ok <- check_metabolism(new_count, state.rate_limit) do
      if state.target_pid do
        GenServer.cast(state.target_pid, extract_dna(msg))
      end

      {:noreply, %{state | msg_count: new_count}}
    else
      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    # Periodic health check
    new_state = perform_health_check(state)
    Process.send_after(self(), :health_check, @health_check_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:circuit_half_open, state) do
    # Transition from open to half-open for testing
    if state.circuit_state == :open do
      Logger.info("[Membrane:#{state.name}] Circuit transitioning to half-open")
      emit_telemetry(state, :circuit_half_open, %{})
      {:noreply, %{state | circuit_state: :half_open}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # CROSSING LOGIC - Core Protection Policies
  # ═══════════════════════════════════════════════════════════════════════════

  @spec attempt_crossing(term(), t()) :: {:ok, t()} | {:error, crossing_error()}
  defp attempt_crossing(message, state) do
    with :ok <- check_immune_status(state),
         :ok <- check_circuit_breaker(state),
         {:ok, new_state} <- check_rate_limit(state),
         :ok <- validate_schema(message),
         :ok <- check_endpoint_health(message, state) do
      {:ok, new_state}
    end
  end

  defp check_immune_status(%{immune_tags: tags}) do
    if :compromised in tags do
      {:error, :compromised}
    else
      :ok
    end
  end

  defp check_circuit_breaker(%{circuit_state: :open}) do
    {:error, :circuit_open}
  end

  defp check_circuit_breaker(%{circuit_state: :half_open}) do
    # Allow limited traffic in half-open state
    :ok
  end

  defp check_circuit_breaker(_state), do: :ok

  defp check_rate_limit(state) do
    now = System.monotonic_time(:millisecond)

    # Reset window if expired
    {window_start, count} =
      if now - state.rate_window_start > @rate_window_ms do
        {now, 0}
      else
        {state.rate_window_start, state.msg_count}
      end

    if count >= state.rate_limit do
      {:error, :rate_limited}
    else
      {:ok, %{state | rate_window_start: window_start, msg_count: count + 1}}
    end
  end

  defp validate_schema(%GeneticPayload{} = _msg), do: :ok
  defp validate_schema({:call, _fun, _args}), do: :ok
  defp validate_schema({_action, _args}), do: :ok
  defp validate_schema(_msg), do: {:error, :invalid_genome}

  defp check_endpoint_health({:call, _fun, _args}, _state), do: :ok

  defp check_endpoint_health({action, _args}, state) do
    case Map.get(state.endpoint_health_cache, action) do
      %{status: :unhealthy, failure_count: count} when count >= @unhealthy_threshold ->
        {:error, :endpoint_unhealthy}

      _ ->
        :ok
    end
  end

  defp check_endpoint_health(_msg, _state), do: :ok

  # ═══════════════════════════════════════════════════════════════════════════
  # EXECUTION - Actually perform the protected call
  # ═══════════════════════════════════════════════════════════════════════════

  defp execute_crossing({:call, fun, args}, _state) when is_function(fun) do
    try do
      result = apply(fun, List.wrap(args))
      {:ok, result}
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  defp execute_crossing({action, args}, state) when is_atom(action) do
    cond do
      # First priority: Forward to PID target if available
      state.target_pid ->
        try do
          result = GenServer.call(state.target_pid, {action, args})
          {:ok, result}
        catch
          :exit, reason -> {:error, {:exit, reason}}
        end

      # Second priority: Apply to module target
      state.target_module ->
        try do
          result = apply(state.target_module, action, List.wrap(args))
          {:ok, result}
        rescue
          e -> {:error, {:exception, Exception.message(e)}}
        catch
          :exit, reason -> {:error, {:exit, reason}}
        end

      true ->
        {:error, :no_target}
    end
  end

  defp execute_crossing(msg, state) do
    if state.target_pid do
      try do
        result = GenServer.call(state.target_pid, msg)
        {:ok, result}
      catch
        :exit, reason -> {:error, {:exit, reason}}
      end
    else
      {:error, :no_target}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # CIRCUIT BREAKER MANAGEMENT
  # ═══════════════════════════════════════════════════════════════════════════

  defp record_success(state) do
    new_state = %{state | consecutive_failures: 0}

    # If in half-open and successful, close the circuit
    if state.circuit_state == :half_open do
      Logger.info("[Membrane:#{state.name}] Circuit closed after successful test")
      emit_telemetry(new_state, :circuit_closed, %{})
      %{new_state | circuit_state: :closed, circuit_failure_count: 0}
    else
      new_state
    end
  end

  defp record_failure(state, reason) do
    new_failure_count = state.circuit_failure_count + 1
    new_consecutive = state.consecutive_failures + 1

    new_state = %{
      state
      | circuit_failure_count: new_failure_count,
        circuit_last_failure: System.monotonic_time(:millisecond),
        consecutive_failures: new_consecutive
    }

    # Check if we should open the circuit
    cond do
      new_failure_count >= @circuit_failure_threshold and state.circuit_state == :closed ->
        Logger.warning(
          "[Membrane:#{state.name}] Circuit opened after #{new_failure_count} failures"
        )

        emit_telemetry(new_state, :circuit_opened, %{failures: new_failure_count, reason: reason})

        # Schedule half-open transition
        Process.send_after(self(), :circuit_half_open, @circuit_reset_timeout_ms)

        %{new_state | circuit_state: :open}

      state.circuit_state == :half_open ->
        # Failed during half-open test, go back to open
        Logger.warning("[Membrane:#{state.name}] Circuit re-opened after half-open test failure")
        emit_telemetry(new_state, :circuit_reopened, %{reason: reason})

        Process.send_after(self(), :circuit_half_open, @circuit_reset_timeout_ms)

        %{new_state | circuit_state: :open}

      true ->
        new_state
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HEALTH MANAGEMENT
  # ═══════════════════════════════════════════════════════════════════════════

  defp perform_health_check(state) do
    # Determine overall health based on metrics
    health_status =
      cond do
        state.circuit_state == :open -> :unhealthy
        state.consecutive_failures >= @unhealthy_threshold -> :degraded
        :compromised in state.immune_tags -> :unhealthy
        true -> :healthy
      end

    if health_status != state.health_status do
      Logger.info(
        "[Membrane:#{state.name}] Health status changed: #{state.health_status} -> #{health_status}"
      )

      emit_telemetry(state, :health_changed, %{from: state.health_status, to: health_status})
    end

    %{state | health_status: health_status}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # TELEMETRY - Observability for membrane crossings
  # ═══════════════════════════════════════════════════════════════════════════

  defp emit_telemetry(state, event, metadata) do
    event_name = state.telemetry_prefix ++ [event]

    :telemetry.execute(
      event_name,
      %{count: 1, timestamp: System.system_time(:microsecond)},
      Map.merge(metadata, %{membrane: state.name})
    )
  end

  defp emit_crossing_telemetry(state, result, message, duration_us, reason \\ nil) do
    event_name = state.telemetry_prefix ++ [:crossing]

    metadata = %{
      membrane: state.name,
      result: result,
      message_type: extract_message_type(message),
      circuit_state: state.circuit_state,
      queue_length: state.msg_count
    }

    metadata = if reason, do: Map.put(metadata, :reason, reason), else: metadata

    :telemetry.execute(
      event_name,
      %{duration: duration_us, count: 1},
      metadata
    )
  end

  defp extract_message_type({action, _args}) when is_atom(action), do: action
  defp extract_message_type({:call, fun, _args}) when is_function(fun), do: :function_call
  defp extract_message_type(%GeneticPayload{}), do: :genetic_payload
  defp extract_message_type(_), do: :unknown

  # ═══════════════════════════════════════════════════════════════════════════
  # HELPER FUNCTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  defp check_metabolism(msg_count, rate_limit) do
    if msg_count > rate_limit, do: {:error, :metabolic_limit}, else: :ok
  end

  defp extract_dna(%GeneticPayload{dna: dna}), do: dna
  defp extract_dna(msg), do: msg

  defp resolve_target(pid) when is_pid(pid), do: pid
  defp resolve_target(name) when is_atom(name), do: Process.whereis(name)
  defp resolve_target(module) when is_atom(module), do: nil
  defp resolve_target(_), do: nil

  defp extract_module(module) when is_atom(module) do
    if function_exported?(module, :__info__, 1), do: module, else: nil
  rescue
    _ -> nil
  end

  defp extract_module(_), do: nil

  defp create_wrapper(membrane, module, name, arity) do
    case arity do
      0 ->
        fn -> cross(membrane, {name, []}) end

      1 ->
        fn a1 -> cross(membrane, {name, [a1]}) end

      2 ->
        fn a1, a2 -> cross(membrane, {name, [a1, a2]}) end

      3 ->
        fn a1, a2, a3 -> cross(membrane, {name, [a1, a2, a3]}) end

      4 ->
        fn a1, a2, a3, a4 -> cross(membrane, {name, [a1, a2, a3, a4]}) end

      _ ->
        fn args -> cross(membrane, {:call, &apply(module, name, &1), args}) end
    end
  end
end
