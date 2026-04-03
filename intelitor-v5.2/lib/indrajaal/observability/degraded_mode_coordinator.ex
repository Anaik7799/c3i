defmodule Indrajaal.Observability.DegradedModeCoordinator do
  @moduledoc """
  Degraded Mode Coordinator - Graceful Handling of Missing Infrastructure

  WHAT: Coordinates system behavior when infrastructure components are
        unavailable (Zenoh, containers, K8s, databases).

  WHY: Implements SC-OBS-DT-006 to prevent continuous retry storms and
       log flooding when infrastructure is intentionally unavailable
       (e.g., during unit tests).

  DESIGN:
    - Tracks infrastructure availability per component
    - Implements exponential backoff with silence periods
    - Provides fallback behaviors for missing services
    - Coordinates with DirectedTelescopeController for context

  STAMP Constraints:
    - SC-OBS-DT-004: Retry policies MUST include silence periods
    - SC-OBS-DT-005: Test mode MUST disable non-essential services
    - SC-OBS-DT-006: Graceful degradation for missing infrastructure

  Components Managed:
    - :zenoh_router - Zenoh pub/sub mesh
    - :libcluster - K8s DNS cluster discovery
    - :container_stack - Podman containers
    - :otel_collector - OpenTelemetry collector
    - :database - PostgreSQL connection
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.DirectedTelescopeController

  # Backoff configuration
  @initial_backoff_ms 1_000
  @max_backoff_ms 300_000
  @silence_threshold 5

  @type component :: :zenoh_router | :libcluster | :container_stack | :otel_collector | :database

  @type component_state :: %{
          available: boolean(),
          last_check: DateTime.t() | nil,
          retry_count: non_neg_integer(),
          backoff_ms: pos_integer(),
          in_silence: boolean(),
          silence_until: DateTime.t() | nil,
          last_error: term() | nil
        }

  defstruct components: %{},
            degraded_services: [],
            last_report: nil,
            subscribers: []

  # ============================================================================
  # Client API
  # ============================================================================

  @doc "Start the Degraded Mode Coordinator"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Check if a component is available"
  @spec available?(component()) :: boolean()
  def available?(component) do
    GenServer.call(__MODULE__, {:available?, component})
  catch
    :exit, _ -> check_component_directly(component)
  end

  @doc "Report a component as unavailable"
  @spec report_unavailable(component(), term()) :: :ok
  def report_unavailable(component, reason \\ :unknown) do
    GenServer.cast(__MODULE__, {:unavailable, component, reason})
  end

  @doc "Report a component as available"
  @spec report_available(component()) :: :ok
  def report_available(component) do
    GenServer.cast(__MODULE__, {:available, component})
  end

  @doc "Should retry connection to component?"
  @spec should_retry?(component()) :: boolean()
  def should_retry?(component) do
    GenServer.call(__MODULE__, {:should_retry?, component})
  catch
    :exit, _ -> false
  end

  @doc "Record a retry attempt"
  @spec record_retry(component()) :: :ok
  def record_retry(component) do
    GenServer.cast(__MODULE__, {:record_retry, component})
  end

  @doc "Get current backoff for component"
  @spec get_backoff(component()) :: pos_integer()
  def get_backoff(component) do
    GenServer.call(__MODULE__, {:get_backoff, component})
  catch
    :exit, _ -> @max_backoff_ms
  end

  @doc "Check if component is in silence period"
  @spec in_silence?(component()) :: boolean()
  def in_silence?(component) do
    GenServer.call(__MODULE__, {:in_silence?, component})
  catch
    :exit, _ -> true
  end

  @doc "Get all degraded services"
  @spec degraded_services() :: [component()]
  def degraded_services do
    GenServer.call(__MODULE__, :degraded_services)
  catch
    :exit, _ -> []
  end

  @doc "Get full status report"
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  catch
    :exit, _ -> %{components: %{}, degraded_count: 0}
  end

  @doc "Force reset for a component"
  @spec reset(component()) :: :ok
  def reset(component) do
    GenServer.cast(__MODULE__, {:reset, component})
  end

  @doc "Subscribe to degradation events"
  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Initialize component states
    components = %{
      zenoh_router: init_component_state(),
      libcluster: init_component_state(),
      container_stack: init_component_state(),
      otel_collector: init_component_state(),
      database: init_component_state()
    }

    state = %__MODULE__{
      components: components,
      degraded_services: [],
      last_report: DateTime.utc_now()
    }

    # Schedule periodic health check
    Process.send_after(self(), :health_check, 30_000)

    Logger.info("[DegradedModeCoordinator] Started - managing 5 infrastructure components")

    {:ok, state}
  end

  @impl true
  def handle_call({:available?, component}, _from, state) do
    comp_state = Map.get(state.components, component, init_component_state())
    {:reply, comp_state.available, state}
  end

  @impl true
  def handle_call({:should_retry?, component}, _from, state) do
    comp_state = Map.get(state.components, component, init_component_state())

    should_retry =
      cond do
        # In test mode, don't retry non-essential services
        test_mode?() and not essential_component?(component) ->
          false

        # In silence period
        comp_state.in_silence and not silence_expired?(comp_state) ->
          false

        # Already available
        comp_state.available ->
          false

        true ->
          true
      end

    {:reply, should_retry, state}
  end

  @impl true
  def handle_call({:get_backoff, component}, _from, state) do
    comp_state = Map.get(state.components, component, init_component_state())
    {:reply, comp_state.backoff_ms, state}
  end

  @impl true
  def handle_call({:in_silence?, component}, _from, state) do
    comp_state = Map.get(state.components, component, init_component_state())
    in_silence = comp_state.in_silence and not silence_expired?(comp_state)
    {:reply, in_silence, state}
  end

  @impl true
  def handle_call(:degraded_services, _from, state) do
    {:reply, state.degraded_services, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      components:
        Map.new(state.components, fn {k, v} ->
          {k,
           %{
             available: v.available,
             retry_count: v.retry_count,
             backoff_ms: v.backoff_ms,
             in_silence: v.in_silence and not silence_expired?(v),
             last_error: v.last_error
           }}
        end),
      degraded_count: length(state.degraded_services),
      degraded_services: state.degraded_services,
      test_mode: test_mode?()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:unavailable, component, reason}, state) do
    comp_state = Map.get(state.components, component, init_component_state())

    # Calculate new backoff
    new_backoff = min(comp_state.backoff_ms * 2, @max_backoff_ms)
    new_retry_count = comp_state.retry_count + 1

    # Enter silence if threshold reached
    {in_silence, silence_until} =
      if new_retry_count >= @silence_threshold do
        {true, DateTime.add(DateTime.utc_now(), div(@max_backoff_ms, 1000), :second)}
      else
        {comp_state.in_silence, comp_state.silence_until}
      end

    new_comp_state = %{
      comp_state
      | available: false,
        last_check: DateTime.utc_now(),
        retry_count: new_retry_count,
        backoff_ms: new_backoff,
        in_silence: in_silence,
        silence_until: silence_until,
        last_error: reason
    }

    components = Map.put(state.components, component, new_comp_state)

    degraded_services =
      if component in state.degraded_services do
        state.degraded_services
      else
        [component | state.degraded_services]
      end

    # Only log on first failure or when entering silence
    if comp_state.available or (in_silence and not comp_state.in_silence) do
      log_degradation(component, reason, in_silence)
    end

    # Notify subscribers
    notify_subscribers(state.subscribers, {:degraded, component, reason})

    {:noreply, %{state | components: components, degraded_services: degraded_services}}
  end

  @impl true
  def handle_cast({:available, component}, state) do
    comp_state = Map.get(state.components, component, init_component_state())

    new_comp_state = %{
      comp_state
      | available: true,
        last_check: DateTime.utc_now(),
        retry_count: 0,
        backoff_ms: @initial_backoff_ms,
        in_silence: false,
        silence_until: nil,
        last_error: nil
    }

    components = Map.put(state.components, component, new_comp_state)
    degraded_services = List.delete(state.degraded_services, component)

    # Log recovery
    if not comp_state.available do
      Logger.info("[DegradedModeCoordinator] #{component} recovered")
    end

    # Notify subscribers
    notify_subscribers(state.subscribers, {:recovered, component})

    {:noreply, %{state | components: components, degraded_services: degraded_services}}
  end

  @impl true
  def handle_cast({:record_retry, component}, state) do
    comp_state = Map.get(state.components, component, init_component_state())

    new_comp_state = %{
      comp_state
      | retry_count: comp_state.retry_count + 1,
        last_check: DateTime.utc_now()
    }

    components = Map.put(state.components, component, new_comp_state)
    {:noreply, %{state | components: components}}
  end

  @impl true
  def handle_cast({:reset, component}, state) do
    components = Map.put(state.components, component, init_component_state())
    degraded_services = List.delete(state.degraded_services, component)
    {:noreply, %{state | components: components, degraded_services: degraded_services}}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    subscribers = [pid | state.subscribers] |> Enum.uniq()
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_info(:health_check, state) do
    # Only run active checks if not in test mode
    new_state =
      if test_mode?() do
        state
      else
        perform_health_checks(state)
      end

    # Report summary if degraded (with rate limiting)
    final_state =
      if length(new_state.degraded_services) > 0 do
        time_since_report = DateTime.diff(DateTime.utc_now(), new_state.last_report, :second)

        if time_since_report >= 300 do
          Logger.warning(
            "[DegradedModeCoordinator] #{length(new_state.degraded_services)} components degraded: #{inspect(new_state.degraded_services)}"
          )

          %{new_state | last_report: DateTime.utc_now()}
        else
          new_state
        end
      else
        new_state
      end

    Process.send_after(self(), :health_check, 30_000)
    {:noreply, final_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp init_component_state do
    %{
      available: true,
      last_check: nil,
      retry_count: 0,
      backoff_ms: @initial_backoff_ms,
      in_silence: false,
      silence_until: nil,
      last_error: nil
    }
  end

  defp test_mode? do
    try do
      DirectedTelescopeController.test_mode?()
    rescue
      _ -> System.get_env("MIX_ENV") == "test"
    catch
      :exit, _ -> System.get_env("MIX_ENV") == "test"
    end
  end

  defp essential_component?(component) do
    component in [:database]
  end

  defp silence_expired?(comp_state) do
    case comp_state.silence_until do
      nil -> true
      until -> DateTime.compare(DateTime.utc_now(), until) == :gt
    end
  end

  defp log_degradation(component, reason, entering_silence) do
    if entering_silence do
      Logger.warning(
        "[DegradedModeCoordinator] #{component} entering silence period - " <>
          "too many failures. Reason: #{inspect(reason)}"
      )
    else
      Logger.info("[DegradedModeCoordinator] #{component} marked unavailable: #{inspect(reason)}")
    end
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:degraded_mode, message})
      end
    end)
  end

  defp perform_health_checks(state) do
    # Check each component
    Enum.reduce(state.components, state, fn {component, comp_state}, acc ->
      if not comp_state.in_silence or silence_expired?(comp_state) do
        available = check_component_directly(component)

        if available and not comp_state.available do
          # Component recovered
          {:noreply, new_state} = handle_cast({:available, component}, acc)
          new_state
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp check_component_directly(component) do
    case component do
      :zenoh_router ->
        check_tcp_port("127.0.0.1", 7447, 500)

      :libcluster ->
        case :inet.gethostbyname(~c"kubernetes.default.svc") do
          {:ok, _} -> true
          _ -> false
        end

      :container_stack ->
        case System.cmd("podman", ["ps", "-q"], stderr_to_stdout: true) do
          {output, 0} when output != "" -> true
          _ -> false
        end

      :otel_collector ->
        check_tcp_port("127.0.0.1", 4317, 500)

      :database ->
        check_tcp_port("127.0.0.1", 5433, 1000)

      _ ->
        false
    end
  rescue
    _ -> false
  end

  defp check_tcp_port(host, port, timeout) do
    case :gen_tcp.connect(String.to_charlist(host), port, [], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      _ ->
        false
    end
  rescue
    _ -> false
  end
end
