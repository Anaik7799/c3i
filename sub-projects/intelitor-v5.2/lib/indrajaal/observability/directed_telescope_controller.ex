defmodule Indrajaal.Observability.DirectedTelescopeController do
  @moduledoc """
  Directed Telescope Controller - Context-Aware OODA Observability System

  WHAT: Dynamically adjusts observability, logging, and messaging based on
        execution context (production, test, development, integration).

  WHY: Implements SC-OBS-DT-001 through SC-OBS-DT-008 from 8-level RCA.
       Prevents log noise from overwhelming test output while maintaining
       high observability for critical systems when needed.

  DESIGN (OODA Loop):
    - OBSERVE: Detect execution context (MIX_ENV, infrastructure, resources)
    - ORIENT: Classify context (:full_production, :unit_test, etc.)
    - DECIDE: Select observability profile (log levels, intervals, retries)
    - ACT: Apply configuration changes dynamically

  STAMP Constraints:
    - SC-OBS-DT-001: Directed Telescope MUST detect execution context
    - SC-OBS-DT-002: Log level MUST adapt to context
    - SC-OBS-DT-003: Heartbeat interval MUST scale with context
    - SC-OBS-DT-004: Retry policies MUST include silence periods
    - SC-OBS-DT-005: Test mode MUST disable non-essential services
    - SC-OBS-DT-006: Graceful degradation for missing infrastructure
    - SC-OBS-DT-007: Log noise < 1000 lines for unit test run
    - SC-OBS-DT-008: Test output visibility > 90%

  AOR Rules:
    - AOR-OBS-001: Context detection runs on application start
    - AOR-OBS-002: Profile changes logged to telemetry
    - AOR-OBS-003: Critical observability always maintained
    - AOR-OBS-004: Test mode preserves assertion visibility
  """

  use GenServer
  require Logger

  # ============================================================================
  # Context Types & Profiles
  # ============================================================================

  @type execution_context ::
          :full_production
          | :staging
          | :development
          | :integration_test
          | :unit_test
          | :benchmark

  @type observability_profile :: %{
          log_level: :debug | :info | :warning | :error,
          heartbeat_interval_ms: pos_integer(),
          heartbeat_timeout_ms: pos_integer(),
          retry_backoff_base_ms: pos_integer(),
          retry_silence_after: pos_integer(),
          enable_zenoh_reconnect: boolean(),
          enable_libcluster: boolean(),
          enable_watchdog: boolean(),
          enable_mara_chaos: boolean(),
          fractal_log_level: :gossamer | :fiber | :segment | :thorax | :spine,
          telemetry_sampling_rate: float()
        }

  # Default observability profiles per context
  @profiles %{
    full_production: %{
      log_level: :info,
      heartbeat_interval_ms: 500,
      heartbeat_timeout_ms: 300_000,
      retry_backoff_base_ms: 1_000,
      retry_silence_after: 10,
      enable_zenoh_reconnect: true,
      enable_libcluster: true,
      enable_watchdog: true,
      enable_mara_chaos: true,
      fractal_log_level: :segment,
      telemetry_sampling_rate: 1.0
    },
    staging: %{
      log_level: :info,
      heartbeat_interval_ms: 1_000,
      heartbeat_timeout_ms: 300_000,
      retry_backoff_base_ms: 2_000,
      retry_silence_after: 5,
      enable_zenoh_reconnect: true,
      enable_libcluster: true,
      enable_watchdog: true,
      enable_mara_chaos: false,
      fractal_log_level: :segment,
      telemetry_sampling_rate: 0.5
    },
    development: %{
      log_level: :debug,
      heartbeat_interval_ms: 5_000,
      heartbeat_timeout_ms: 300_000,
      retry_backoff_base_ms: 5_000,
      retry_silence_after: 3,
      enable_zenoh_reconnect: true,
      enable_libcluster: false,
      enable_watchdog: true,
      enable_mara_chaos: false,
      fractal_log_level: :fiber,
      telemetry_sampling_rate: 1.0
    },
    integration_test: %{
      log_level: :warning,
      heartbeat_interval_ms: 10_000,
      heartbeat_timeout_ms: 300_000,
      retry_backoff_base_ms: 10_000,
      retry_silence_after: 2,
      enable_zenoh_reconnect: false,
      enable_libcluster: false,
      enable_watchdog: false,
      enable_mara_chaos: false,
      fractal_log_level: :thorax,
      telemetry_sampling_rate: 0.1
    },
    unit_test: %{
      log_level: :error,
      heartbeat_interval_ms: :infinity,
      heartbeat_timeout_ms: :infinity,
      retry_backoff_base_ms: :infinity,
      retry_silence_after: 0,
      enable_zenoh_reconnect: false,
      enable_libcluster: false,
      enable_watchdog: false,
      enable_mara_chaos: false,
      fractal_log_level: :spine,
      telemetry_sampling_rate: 0.0
    },
    benchmark: %{
      log_level: :error,
      heartbeat_interval_ms: :infinity,
      heartbeat_timeout_ms: :infinity,
      retry_backoff_base_ms: :infinity,
      retry_silence_after: 0,
      enable_zenoh_reconnect: false,
      enable_libcluster: false,
      enable_watchdog: false,
      enable_mara_chaos: false,
      fractal_log_level: :spine,
      telemetry_sampling_rate: 0.0
    }
  }

  # Critical sources that always log at :info or above regardless of context
  @critical_sources [
    "Guardian",
    "Constitutional",
    "ImmutableRegister",
    "Sentinel",
    "FPPS",
    "FounderDirective"
  ]

  defstruct context: :development,
            profile: nil,
            infrastructure: %{},
            last_detection: nil,
            subscribers: [],
            override_log_sources: %{}

  # ============================================================================
  # Client API
  # ============================================================================

  @doc "Start the Directed Telescope Controller"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get current execution context"
  @spec get_context() :: execution_context()
  def get_context do
    GenServer.call(__MODULE__, :get_context)
  catch
    :exit, _ -> detect_context_sync()
  end

  @doc "Get current observability profile"
  @spec get_profile() :: observability_profile()
  def get_profile do
    GenServer.call(__MODULE__, :get_profile)
  catch
    :exit, _ -> @profiles[:development]
  end

  @doc "Check if a service should be enabled in current context"
  @spec service_enabled?(atom()) :: boolean()
  def service_enabled?(service) do
    profile = get_profile()

    case service do
      :zenoh_reconnect -> profile.enable_zenoh_reconnect
      :libcluster -> profile.enable_libcluster
      :watchdog -> profile.enable_watchdog
      :mara_chaos -> profile.enable_mara_chaos
      _ -> true
    end
  end

  @doc "Get log level for a specific source"
  @spec log_level_for(String.t()) :: :debug | :info | :warning | :error
  def log_level_for(source) do
    if source in @critical_sources do
      :info
    else
      get_profile().log_level
    end
  end

  @doc "Check if log should be emitted for source at level"
  @spec should_log?(String.t(), atom()) :: boolean()
  def should_log?(source, level) do
    min_level = log_level_for(source)
    level_value(level) >= level_value(min_level)
  end

  @doc "Get heartbeat parameters for current context"
  @spec heartbeat_params() ::
          {interval :: integer() | :infinity, timeout :: integer() | :infinity}
  def heartbeat_params do
    profile = get_profile()
    {profile.heartbeat_interval_ms, profile.heartbeat_timeout_ms}
  end

  @doc "Get retry parameters for current context"
  @spec retry_params() :: {backoff_base :: integer() | :infinity, silence_after :: integer()}
  def retry_params do
    profile = get_profile()
    {profile.retry_backoff_base_ms, profile.retry_silence_after}
  end

  @doc "Check if in test mode (unit_test or integration_test)"
  @spec test_mode?() :: boolean()
  def test_mode? do
    get_context() in [:unit_test, :integration_test, :benchmark]
  end

  @doc "Force context detection refresh"
  @spec refresh_context() :: execution_context()
  def refresh_context do
    GenServer.call(__MODULE__, :refresh_context)
  catch
    :exit, _ -> detect_context_sync()
  end

  @doc "Manually set execution context (for testing or emergency override)"
  @spec set_context(execution_context()) :: :ok
  def set_context(context)
      when context in [
             :full_production,
             :staging,
             :development,
             :integration_test,
             :unit_test,
             :benchmark
           ] do
    GenServer.cast(__MODULE__, {:set_context, context})
  end

  @doc "Override log level for specific source"
  @spec override_log_level(String.t(), atom()) :: :ok
  def override_log_level(source, level) do
    GenServer.cast(__MODULE__, {:override_log_level, source, level})
  end

  @doc "Subscribe to context changes"
  @spec subscribe(pid()) :: :ok
  def subscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  @doc "Get infrastructure availability status"
  @spec infrastructure_status() :: map()
  def infrastructure_status do
    GenServer.call(__MODULE__, :infrastructure_status)
  catch
    :exit, _ -> detect_infrastructure_sync()
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Detect context on startup
    context = detect_context_sync()
    profile = Map.get(@profiles, context, @profiles[:development])
    infrastructure = detect_infrastructure_sync()

    state = %__MODULE__{
      context: context,
      profile: profile,
      infrastructure: infrastructure,
      last_detection: DateTime.utc_now()
    }

    # Apply initial configuration
    apply_profile(profile, context)

    # Schedule periodic re-detection (every 60s)
    Process.send_after(self(), :periodic_detection, 60_000)

    Logger.info(
      "[DirectedTelescope] Started with context=#{context}, log_level=#{profile.log_level}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:get_context, _from, state) do
    {:reply, state.context, state}
  end

  @impl true
  def handle_call(:get_profile, _from, state) do
    {:reply, state.profile, state}
  end

  @impl true
  def handle_call(:refresh_context, _from, state) do
    new_context = detect_context_sync()
    new_infrastructure = detect_infrastructure_sync()
    new_profile = Map.get(@profiles, new_context, @profiles[:development])

    if new_context != state.context do
      apply_profile(new_profile, new_context)
      notify_subscribers(state.subscribers, {:context_changed, state.context, new_context})
    end

    new_state = %{
      state
      | context: new_context,
        profile: new_profile,
        infrastructure: new_infrastructure,
        last_detection: DateTime.utc_now()
    }

    {:reply, new_context, new_state}
  end

  @impl true
  def handle_call(:infrastructure_status, _from, state) do
    {:reply, state.infrastructure, state}
  end

  @impl true
  def handle_cast({:set_context, context}, state) do
    new_profile = Map.get(@profiles, context, @profiles[:development])

    if context != state.context do
      Logger.info("[DirectedTelescope] Context manually set: #{state.context} -> #{context}")
      apply_profile(new_profile, context)
      notify_subscribers(state.subscribers, {:context_changed, state.context, context})
    end

    new_state = %{
      state
      | context: context,
        profile: new_profile,
        last_detection: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:override_log_level, source, level}, state) do
    overrides = Map.put(state.override_log_sources, source, level)
    {:noreply, %{state | override_log_sources: overrides}}
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    subscribers = [pid | state.subscribers] |> Enum.uniq()
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_info(:periodic_detection, state) do
    new_context = detect_context_sync()
    new_infrastructure = detect_infrastructure_sync()

    new_state =
      if new_context != state.context do
        new_profile = Map.get(@profiles, new_context, @profiles[:development])
        apply_profile(new_profile, new_context)
        notify_subscribers(state.subscribers, {:context_changed, state.context, new_context})

        %{
          state
          | context: new_context,
            profile: new_profile,
            infrastructure: new_infrastructure,
            last_detection: DateTime.utc_now()
        }
      else
        %{state | infrastructure: new_infrastructure, last_detection: DateTime.utc_now()}
      end

    Process.send_after(self(), :periodic_detection, 60_000)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Context Detection (OBSERVE Phase)
  # ============================================================================

  defp detect_context_sync do
    cond do
      # Check MIX_ENV first
      mix_env_test?() ->
        if integration_test_indicators?() do
          :integration_test
        else
          :unit_test
        end

      # Check for benchmark mode
      benchmark_mode?() ->
        :benchmark

      # Check for staging indicators
      staging_environment?() ->
        :staging

      # Check for production indicators
      production_environment?() ->
        :full_production

      # Default to development
      true ->
        :development
    end
  end

  defp mix_env_test? do
    case System.get_env("MIX_ENV") do
      "test" -> true
      _ -> Mix.env() == :test
    end
  rescue
    # Mix not available (e.g., in release)
    _ -> System.get_env("MIX_ENV") == "test"
  end

  defp integration_test_indicators? do
    # Check for integration test flags
    System.get_env("INTEGRATION_TEST") == "true" or
      System.get_env("SA_TEST") == "true" or
      container_stack_available?()
  end

  defp benchmark_mode? do
    System.get_env("BENCHMARK_MODE") == "true"
  end

  defp staging_environment? do
    System.get_env("STAGING") == "true" or
      System.get_env("ENVIRONMENT") == "staging"
  end

  defp production_environment? do
    case System.get_env("MIX_ENV") do
      "prod" -> true
      _ -> System.get_env("PRODUCTION") == "true"
    end
  rescue
    _ -> false
  end

  # ============================================================================
  # Infrastructure Detection (ORIENT Phase)
  # ============================================================================

  defp detect_infrastructure_sync do
    %{
      zenoh_available: zenoh_router_available?(),
      containers_available: container_stack_available?(),
      k8s_available: k8s_dns_available?(),
      database_available: database_available?(),
      otel_available: otel_collector_available?()
    }
  end

  defp zenoh_router_available? do
    # Check if Zenoh router is reachable
    case :gen_tcp.connect(~c"zenoh-router", 7447, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      _ ->
        # Also try localhost
        case :gen_tcp.connect(~c"127.0.0.1", 7447, [], 500) do
          {:ok, socket} ->
            :gen_tcp.close(socket)
            true

          _ ->
            false
        end
    end
  rescue
    _ -> false
  end

  defp container_stack_available? do
    # Check if podman containers are running
    case System.cmd("podman", ["ps", "--format", "{{.Names}}"], stderr_to_stdout: true) do
      {output, 0} ->
        String.contains?(output, "indrajaal-app") or
          String.contains?(output, "indrajaal-db") or
          String.contains?(output, "indrajaal-obs")

      _ ->
        false
    end
  rescue
    _ -> false
  end

  defp k8s_dns_available? do
    case :inet.gethostbyname(~c"kubernetes.default.svc") do
      {:ok, _} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp database_available? do
    case :gen_tcp.connect(~c"127.0.0.1", 5433, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      _ ->
        false
    end
  rescue
    _ -> false
  end

  defp otel_collector_available? do
    case :gen_tcp.connect(~c"127.0.0.1", 4317, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      _ ->
        false
    end
  rescue
    _ -> false
  end

  # ============================================================================
  # Profile Application (ACT Phase)
  # ============================================================================

  defp apply_profile(profile, context) do
    # Apply Logger level
    apply_logger_level(profile.log_level)

    # Emit telemetry for profile change
    emit_profile_telemetry(profile, context)

    # Log the change (always at :info regardless of new level)
    Logger.info(
      "[DirectedTelescope] Profile applied: context=#{context}, " <>
        "log_level=#{profile.log_level}, heartbeat=#{profile.heartbeat_interval_ms}ms"
    )
  end

  defp apply_logger_level(level) do
    # Set the Logger level dynamically
    Logger.configure(level: level)

    # Also configure per-backend if available
    if Code.ensure_loaded?(Logger) do
      try do
        Logger.configure(level: level)
      rescue
        _ -> :ok
      end
    end
  end

  defp emit_profile_telemetry(profile, context) do
    :telemetry.execute(
      [:indrajaal, :directed_telescope, :profile_applied],
      %{
        log_level: level_value(profile.log_level),
        heartbeat_interval_ms: profile.heartbeat_interval_ms,
        telemetry_sampling_rate: profile.telemetry_sampling_rate
      },
      %{
        context: context,
        profile: profile
      }
    )
  rescue
    _ -> :ok
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:directed_telescope, message})
      end
    end)
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp level_value(:debug), do: 0
  defp level_value(:info), do: 1
  defp level_value(:warning), do: 2
  defp level_value(:warn), do: 2
  defp level_value(:error), do: 3
  defp level_value(_), do: 1
end
