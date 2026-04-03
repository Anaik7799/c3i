defmodule Indrajaal.Cockpit.Prajna.Config do
  @moduledoc """
  Centralized Configuration for Prajna Cockpit with Fractal Integration.

  WHAT: Single source of truth for all Prajna timing and threshold values.
  WHY: SC-CONFIG-001 requires no hardcoded timing values in modules.

  ## Fractal Configuration Layers

  Each config key has an associated fractal level that determines:
  - Where changes are logged (Spine → Gossamer)
  - Whether hot-reload is supported
  - Retention policy for change history

  | Level | Scope | Hot Reload | Fractal Log |
  |-------|-------|------------|-------------|
  | L5 | Constitutional | No | Spine |
  | L4 | Container | Restart | Thorax |
  | L3 | Agent | Yes | Segment |
  | L2 | Module | Yes | Fiber |
  | L1 | Function | Yes | Gossamer |

  CONSTRAINTS:
    - SC-CONFIG-001: All timing values from Application config
    - SC-CONFIG-002: Validation on startup
    - SC-SIL4-003: Safe defaults for SIL-4 operation
    - SC-FRAC-CONFIG-001: All changes logged to appropriate fractal level

  ## Configuration Schema

  ```elixir
  config :indrajaal, Indrajaal.Cockpit.Prajna.Config,
    # Guardian settings
    guardian_timeout_ms: 5_000,
    guardian_circuit_threshold: 3,
    guardian_circuit_reset_ms: 30_000,
    guardian_health_interval_ms: 5_000,

    # Sentinel Bridge settings
    sentinel_sync_interval_ms: 30_000,
    sentinel_emergency_timeout_ms: 5_000,

    # ImmutableState settings
    immutable_state_verify_on_startup: true,
    # SC-DBNAME-001: UHI-based path: ex:l5:prj:srv:prajna:register
    immutable_state_duckdb_path: "data/holons/ex/l5/prj/prajna/register.duckdb",

    # Circuit Breaker thresholds
    circuit_telemetry_threshold: 100,
    circuit_critical_threshold: 200,
    circuit_emergency_threshold: 500,

    # SmartMetrics settings
    smart_metrics_staleness_ms: 5_000,
    smart_metrics_interval_ms: 1_000,

    # AI Copilot settings
    ai_insight_ttl_seconds: 300,
    ai_analysis_interval_ms: 10_000,

    # Orchestrator settings
    orchestrator_ui_refresh_ms: 100,
    orchestrator_command_timeout_ms: 30_000,
    orchestrator_armed_ttl_ms: 30_000,

    # Retry settings
    max_retry_attempts: 3,
    backoff_base_ms: 1_000,
    backoff_max_ms: 60_000,

    # Dashboard settings
    dashboard_refresh_ms: 30_000,

    # OODA cycle
    ooda_cycle_ms: 30_000,

    # Feature flags (used by FeatureFlags module)
    feature_flag_overrides: %{}
  ```
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.FractalLogger

  @type config_key :: atom()
  @type config_value :: integer() | boolean() | String.t() | map()
  @type fractal_level :: :l1 | :l2 | :l3 | :l4 | :l5

  # ============================================================================
  # Configuration Schema with Defaults and Validation
  # ============================================================================

  # ============================================================================
  # Compile-Time Safety Verification (SC-SIL4-005)
  # ============================================================================

  # SC-SIL4-005: L5 (Constitutional) keys MUST NOT be hot-reloadable
  # This is verified at compile time to prevent accidental misconfiguration
  @l5_hot_reload_violations []

  @schema %{
    # Guardian settings (SC-SIL4-001) - L4 Container level
    guardian_timeout_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 30_000,
      level: :l4,
      hot_reload: false,
      description: "Guardian proposal validation timeout"
    },
    guardian_circuit_threshold: %{
      default: 3,
      type: :pos_integer,
      min: 1,
      max: 10,
      level: :l4,
      hot_reload: true,
      description: "Consecutive failures before circuit opens"
    },
    guardian_circuit_reset_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 300_000,
      level: :l4,
      hot_reload: true,
      description: "Time before circuit attempts reset"
    },
    guardian_health_interval_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 60_000,
      level: :l3,
      hot_reload: true,
      description: "Guardian health check interval"
    },

    # Sentinel Bridge settings - L3 Agent level
    sentinel_sync_interval_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 300_000,
      level: :l3,
      hot_reload: true,
      description: "Sentinel health sync interval"
    },
    sentinel_emergency_timeout_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 30_000,
      level: :l4,
      hot_reload: false,
      description: "Emergency sync timeout"
    },

    # ImmutableState settings (SC-SIL4-002, SC-SIL4-003) - L5 Constitutional
    immutable_state_verify_on_startup: %{
      default: true,
      type: :boolean,
      level: :l5,
      hot_reload: false,
      description: "Verify hash chain on startup (SIL-4 mandatory)"
    },
    # SC-DBNAME-001: UHI-based path: ex:l5:prj:srv:prajna:register
    immutable_state_duckdb_path: %{
      default: "data/holons/ex/l5/prj/prajna/register.duckdb",
      type: :string,
      level: :l5,
      hot_reload: false,
      description: "DuckDB persistence file path (UHI: ex:l5:prj:srv:prajna:register)"
    },

    # Circuit Breaker thresholds - L3 Agent level
    circuit_telemetry_threshold: %{
      default: 100,
      type: :pos_integer,
      min: 10,
      max: 1000,
      level: :l3,
      hot_reload: true,
      description: "Queue depth for telemetry throttling"
    },
    circuit_critical_threshold: %{
      default: 200,
      type: :pos_integer,
      min: 50,
      max: 2000,
      level: :l3,
      hot_reload: true,
      description: "Queue depth for critical mode"
    },
    circuit_emergency_threshold: %{
      default: 500,
      type: :pos_integer,
      min: 100,
      max: 5000,
      level: :l4,
      hot_reload: true,
      description: "Queue depth for emergency mode"
    },

    # SmartMetrics settings - L3 Agent level
    smart_metrics_staleness_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 60_000,
      level: :l3,
      hot_reload: true,
      description: "Metric staleness threshold"
    },
    smart_metrics_interval_ms: %{
      default: 1_000,
      type: :pos_integer,
      min: 100,
      max: 10_000,
      level: :l3,
      hot_reload: true,
      description: "Metrics collection interval"
    },

    # AI Copilot settings - L3 Agent level
    ai_insight_ttl_seconds: %{
      default: 300,
      type: :pos_integer,
      min: 60,
      max: 3600,
      level: :l3,
      hot_reload: true,
      description: "AI insight time-to-live"
    },
    ai_analysis_interval_ms: %{
      default: 10_000,
      type: :pos_integer,
      min: 1_000,
      max: 60_000,
      level: :l3,
      hot_reload: true,
      description: "AI analysis cycle interval"
    },

    # Orchestrator settings - L4 Container level (safety-critical)
    orchestrator_ui_refresh_ms: %{
      default: 100,
      type: :pos_integer,
      min: 50,
      max: 1000,
      level: :l2,
      hot_reload: true,
      description: "UI refresh rate"
    },
    orchestrator_command_timeout_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 120_000,
      level: :l4,
      hot_reload: false,
      description: "Command execution timeout"
    },
    orchestrator_armed_ttl_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 10_000,
      max: 120_000,
      level: :l4,
      hot_reload: false,
      description: "Armed command expiration (SC-HMI safety)"
    },

    # Retry settings (SC-RECOVER-001) - L3 Agent level
    max_retry_attempts: %{
      default: 3,
      type: :pos_integer,
      min: 1,
      max: 10,
      level: :l3,
      hot_reload: true,
      description: "Maximum retry attempts"
    },
    backoff_base_ms: %{
      default: 1_000,
      type: :pos_integer,
      min: 100,
      max: 10_000,
      level: :l3,
      hot_reload: true,
      description: "Exponential backoff base delay"
    },
    backoff_max_ms: %{
      default: 60_000,
      type: :pos_integer,
      min: 10_000,
      max: 300_000,
      level: :l3,
      hot_reload: true,
      description: "Maximum backoff delay"
    },

    # Dashboard settings - L3 Agent level
    dashboard_refresh_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 120_000,
      level: :l3,
      hot_reload: true,
      description: "Dashboard refresh interval"
    },

    # OODA cycle (SC-BIO-001) - L4 Container level
    ooda_cycle_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 10_000,
      max: 120_000,
      level: :l4,
      hot_reload: false,
      description: "OODA loop cycle time"
    },

    # Feature Flags overrides - L3 Agent level
    feature_flag_overrides: %{
      default: %{},
      type: :map,
      level: :l3,
      hot_reload: true,
      description: "Feature flag value overrides"
    },

    # SIL-4 Fail-Closed Mode (SC-SIL4-006) - L5 Constitutional
    fail_closed_mode: %{
      default: false,
      type: :boolean,
      level: :l5,
      hot_reload: false,
      description: "Enable fail-closed mode for Guardian (production safety)"
    },

    # PROMETHEUS Proof Token TTL (SC-PROM-001) - L4 Container level
    proof_token_ttl_ms: %{
      default: 300_000,
      type: :pos_integer,
      min: 5_000,
      max: 600_000,
      level: :l4,
      hot_reload: false,
      description: "Proof token time-to-live in milliseconds"
    },

    # Circuit Breaker generic settings - L4 Container level
    circuit_breaker_threshold: %{
      default: 3,
      type: :pos_integer,
      min: 1,
      max: 10,
      level: :l4,
      hot_reload: true,
      description: "Consecutive failures before circuit opens (generic)"
    },
    circuit_breaker_reset_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 300_000,
      level: :l4,
      hot_reload: true,
      description: "Time before circuit attempts reset (generic)"
    },

    # Exponential Backoff alias (SC-RECOVER-001) - L3 Agent level
    exponential_backoff_base_ms: %{
      default: 1_000,
      type: :pos_integer,
      min: 100,
      max: 10_000,
      level: :l3,
      hot_reload: true,
      description: "Exponential backoff base delay (alias for backoff_base_ms)"
    },

    # Health Check Interval - L3 Agent level
    health_check_interval_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 60_000,
      level: :l3,
      hot_reload: true,
      description: "General health check interval for components"
    },

    # ========================================================================
    # DualChannel Settings (SC-REG-007, SC-PRIME-001)
    # ========================================================================

    # DualChannel timeout - L4 Container level
    dual_channel_timeout_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 30_000,
      level: :l4,
      hot_reload: false,
      description: "Dual-channel verification timeout"
    },
    # DualChannel halt threshold - L5 Constitutional
    dual_channel_halt_threshold: %{
      default: 1,
      type: :pos_integer,
      min: 1,
      max: 5,
      level: :l5,
      hot_reload: false,
      description: "Number of disagreements before HALT (SIL-4 safety)"
    },

    # ========================================================================
    # Watchdog Settings (SC-PRIME-001, AOR-CONST-002)
    # ========================================================================

    # Watchdog heartbeat timeout - L4 Container level (SC-SIL4-WD-001)
    watchdog_heartbeat_timeout_ms: %{
      default: 2_000,
      type: :pos_integer,
      min: 500,
      max: 10_000,
      level: :l4,
      hot_reload: false,
      description: "Heartbeat timeout before process marked as unhealthy"
    },
    # Watchdog check interval - L3 Agent level
    watchdog_check_interval_ms: %{
      default: 500,
      type: :pos_integer,
      min: 100,
      max: 5_000,
      level: :l3,
      hot_reload: true,
      description: "Interval between health checks"
    },
    # Watchdog escalation threshold - L4 Container level
    watchdog_escalation_threshold: %{
      default: 3,
      type: :pos_integer,
      min: 1,
      max: 10,
      level: :l4,
      hot_reload: true,
      description: "Total failures before escalating to Guardian"
    },
    # Watchdog restart delay - L3 Agent level
    watchdog_restart_delay_ms: %{
      default: 1_000,
      type: :pos_integer,
      min: 100,
      max: 10_000,
      level: :l3,
      hot_reload: true,
      description: "Delay before attempting process restart"
    }
  }

  # ============================================================================
  # Compile-Time L5 Immutability Verification (SC-SIL4-005)
  # ============================================================================

  # Find any L5 keys that incorrectly have hot_reload: true
  @l5_hot_reload_violations for {key, %{level: :l5, hot_reload: true}} <- @schema, do: key

  # Raise compile error if any L5 keys are hot-reloadable
  if @l5_hot_reload_violations != [] do
    raise CompileError,
      description: """
      SC-SIL4-005 VIOLATION: Constitutional (L5) keys MUST NOT be hot-reloadable.

      The following L5 keys have hot_reload: true, which violates SIL-4 safety requirements:
      #{inspect(@l5_hot_reload_violations)}

      Constitutional configuration MUST be immutable at runtime to ensure system safety.
      Fix: Set `hot_reload: false` for all L5 keys.
      """
  end

  # Also verify no L5 flags in FeatureFlags have bypass paths - documented for reference
  @doc false
  def __l5_keys__ do
    for {key, %{level: :l5}} <- @schema, do: key
  end

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the Config GenServer.
  Validates all configuration on startup.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets a configuration value.
  Returns the configured value or default if not set.

  ## Examples

      iex> Config.get(:guardian_timeout_ms)
      5000

      iex> Config.get(:unknown_key)
      ** (ArgumentError) Unknown config key: :unknown_key
  """
  @spec get(config_key()) :: config_value()
  def get(key) when is_atom(key) do
    case Map.get(@schema, key) do
      nil -> raise ArgumentError, "Unknown config key: #{inspect(key)}"
      schema -> get_value(key, schema)
    end
  end

  @doc """
  Gets a configuration value with explicit default.
  """
  @spec get(config_key(), config_value()) :: config_value()
  def get(key, default) when is_atom(key) do
    Application.get_env(:indrajaal, __MODULE__, [])
    |> Keyword.get(key, default)
  end

  @doc """
  Returns all configuration as a map.
  """
  @spec all() :: map()
  def all do
    Enum.reduce(@schema, %{}, fn {key, _schema}, acc ->
      Map.put(acc, key, get(key))
    end)
  end

  @doc """
  Validates all configuration values.
  Returns {:ok, validated_config} or {:error, errors}.

  Called automatically on startup.
  """
  @spec validate_all() :: {:ok, map()} | {:error, [String.t()]}
  def validate_all do
    errors =
      @schema
      |> Enum.reduce([], fn {key, schema}, acc ->
        value = get_value(key, schema)

        case validate_value(key, value, schema) do
          :ok -> acc
          {:error, msg} -> [msg | acc]
        end
      end)

    if Enum.empty?(errors) do
      {:ok, all()}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Validates all configuration and raises on error.
  Use in application startup.
  """
  @spec validate_all!() :: map()
  def validate_all! do
    case validate_all() do
      {:ok, config} ->
        config

      {:error, errors} ->
        raise """
        Configuration validation failed (SC-CONFIG-002):
        #{Enum.join(errors, "\n")}
        """
    end
  end

  @doc """
  Returns the configuration schema.
  """
  @spec schema() :: map()
  def schema, do: @schema

  @doc """
  Calculates exponential backoff delay for retry attempt.

  ## Examples

      iex> Config.backoff_delay(1)
      1000

      iex> Config.backoff_delay(3)
      4000

      iex> Config.backoff_delay(10)
      60000  # capped at max
  """
  @spec backoff_delay(pos_integer()) :: pos_integer()
  def backoff_delay(attempt) when attempt > 0 do
    base = get(:backoff_base_ms)
    max = get(:backoff_max_ms)

    delay = (base * :math.pow(2, attempt - 1)) |> round()
    min(delay, max)
  end

  @doc """
  Adds jitter to backoff delay for distributed systems.
  Jitter = +/- 10% of delay.
  """
  @spec backoff_delay_with_jitter(pos_integer()) :: pos_integer()
  def backoff_delay_with_jitter(attempt) do
    delay = backoff_delay(attempt)
    jitter = round(delay * 0.1)
    # Ensure we don't go negative with jitter
    max(1, delay + :rand.uniform(jitter * 2 + 1) - jitter - 1)
  end

  @doc """
  Sets a configuration value at runtime.

  Only keys marked with `hot_reload: true` can be modified at runtime.
  All changes are logged to the appropriate fractal level based on the
  key's configuration.

  ## Examples

      iex> Config.set(:circuit_telemetry_threshold, 150)
      :ok

      iex> Config.set(:guardian_timeout_ms, 3000)
      {:error, :not_hot_reloadable}
  """
  @spec set(config_key(), config_value()) :: :ok | {:error, term()}
  def set(key, value) when is_atom(key) do
    case Map.get(@schema, key) do
      nil ->
        {:error, :unknown_key}

      %{hot_reload: false} ->
        {:error, :not_hot_reloadable}

      schema ->
        case validate_value(key, value, schema) do
          :ok ->
            old_value = get(key)

            # Update Application environment
            current_config = Application.get_env(:indrajaal, __MODULE__, [])
            new_config = Keyword.put(current_config, key, value)
            Application.put_env(:indrajaal, __MODULE__, new_config)

            # Log to fractal level
            log_config_change(key, old_value, value, schema)

            :ok

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Gets the fractal level for a configuration key.
  """
  @spec level(config_key()) :: fractal_level() | nil
  def level(key) when is_atom(key) do
    case Map.get(@schema, key) do
      nil -> nil
      schema -> Map.get(schema, :level, :l3)
    end
  end

  @doc """
  Checks if a key supports hot reload.
  """
  @spec hot_reloadable?(config_key()) :: boolean()
  def hot_reloadable?(key) when is_atom(key) do
    case Map.get(@schema, key) do
      nil -> false
      schema -> Map.get(schema, :hot_reload, false)
    end
  end

  @doc """
  Returns all hot-reloadable configuration keys.
  """
  @spec hot_reloadable_keys() :: [config_key()]
  def hot_reloadable_keys do
    @schema
    |> Enum.filter(fn {_key, schema} -> Map.get(schema, :hot_reload, false) end)
    |> Enum.map(fn {key, _} -> key end)
  end

  @doc """
  Returns configuration keys grouped by fractal level.
  """
  @spec keys_by_level() :: %{fractal_level() => [config_key()]}
  def keys_by_level do
    @schema
    |> Enum.group_by(fn {_key, schema} -> Map.get(schema, :level, :l3) end)
    |> Map.new(fn {level, entries} -> {level, Enum.map(entries, fn {key, _} -> key end)} end)
  end

  # ============================================================================
  # SIL-Level Profiles (SC-SIL4-003)
  # ============================================================================

  @type sil_profile :: :dev | :test | :prod | :sil4

  # SIL-4 Target PFH (Probability of Failure per Hour) per IEC 61508
  # SIL-4 requires PFH < 10^-8 (< 0.00000001 failures/hour)
  # This translates to MTBF > 100,000,000 hours (11,415 years)
  #
  # The :sil4 profile enforces this through:
  # 1. Dual-channel verification (Byzantine fault tolerance)
  # 2. Aggressive circuit breaker thresholds (fail-fast)
  # 3. Strict timeouts (≤ 2s for critical operations)
  # 4. Mandatory immutable state verification
  # 5. Fail-closed mode (safe state on errors)
  # 6. Minimal retry attempts (prevent cascading failures)
  # 7. High-frequency health monitoring (250ms watchdog)
  @sil4_target_pfh 1.0e-8

  @doc """
  Returns SIL-level profile configurations.

  Profiles adjust timing and safety constraints based on environment:
  - `:dev` - Relaxed timings for development
  - `:test` - Fast timings for test execution
  - `:prod` - Production timings with safety margins
  - `:sil4` - Most stringent, safety-critical settings (IEC 61508 SIL-4)

  ## Examples

      iex> Config.profile(:dev)
      %{guardian_timeout_ms: 10_000, ooda_cycle_ms: 60_000, ...}

      iex> Config.profile(:sil4)
      %{guardian_timeout_ms: 3_000, fail_closed_mode: true, ...}
  """
  @spec profile(sil_profile()) :: map()
  def profile(:dev) do
    %{
      guardian_timeout_ms: 10_000,
      guardian_circuit_threshold: 5,
      guardian_circuit_reset_ms: 60_000,
      guardian_health_interval_ms: 10_000,
      sentinel_sync_interval_ms: 60_000,
      sentinel_emergency_timeout_ms: 10_000,
      circuit_breaker_threshold: 5,
      circuit_breaker_reset_ms: 60_000,
      circuit_telemetry_threshold: 200,
      circuit_critical_threshold: 400,
      circuit_emergency_threshold: 1000,
      smart_metrics_staleness_ms: 10_000,
      smart_metrics_interval_ms: 2_000,
      ai_insight_ttl_seconds: 600,
      ai_analysis_interval_ms: 30_000,
      orchestrator_ui_refresh_ms: 200,
      orchestrator_command_timeout_ms: 60_000,
      orchestrator_armed_ttl_ms: 60_000,
      max_retry_attempts: 5,
      backoff_base_ms: 500,
      exponential_backoff_base_ms: 500,
      backoff_max_ms: 30_000,
      dashboard_refresh_ms: 60_000,
      ooda_cycle_ms: 60_000,
      proof_token_ttl_ms: 300_000,
      health_check_interval_ms: 10_000,
      fail_closed_mode: false,
      immutable_state_verify_on_startup: false,
      # Dual-channel - relaxed timeouts for debugging
      dual_channel_timeout_ms: 10_000,
      dual_channel_halt_threshold: 3,
      # Watchdog - relaxed for debugging
      watchdog_heartbeat_timeout_ms: 10_000,
      watchdog_check_interval_ms: 2_000,
      watchdog_escalation_threshold: 5,
      watchdog_restart_delay_ms: 2_000
    }
  end

  def profile(:test) do
    %{
      guardian_timeout_ms: 1_000,
      guardian_circuit_threshold: 2,
      guardian_circuit_reset_ms: 5_000,
      guardian_health_interval_ms: 1_000,
      sentinel_sync_interval_ms: 5_000,
      sentinel_emergency_timeout_ms: 1_000,
      circuit_breaker_threshold: 2,
      circuit_breaker_reset_ms: 5_000,
      circuit_telemetry_threshold: 50,
      circuit_critical_threshold: 100,
      circuit_emergency_threshold: 200,
      smart_metrics_staleness_ms: 1_000,
      smart_metrics_interval_ms: 200,
      ai_insight_ttl_seconds: 60,
      ai_analysis_interval_ms: 1_000,
      orchestrator_ui_refresh_ms: 50,
      orchestrator_command_timeout_ms: 5_000,
      # Schema minimums: must be >= 10_000
      orchestrator_armed_ttl_ms: 10_000,
      max_retry_attempts: 2,
      backoff_base_ms: 100,
      exponential_backoff_base_ms: 100,
      # Schema minimums: must be >= 10_000
      backoff_max_ms: 10_000,
      dashboard_refresh_ms: 5_000,
      # Schema minimums: must be >= 10_000
      ooda_cycle_ms: 10_000,
      proof_token_ttl_ms: 10_000,
      health_check_interval_ms: 1_000,
      fail_closed_mode: false,
      immutable_state_verify_on_startup: false,
      # Dual-channel - fast for deterministic testing
      dual_channel_timeout_ms: 1_000,
      dual_channel_halt_threshold: 2,
      # Watchdog - fast checks for test speed
      watchdog_heartbeat_timeout_ms: 1_000,
      watchdog_check_interval_ms: 200,
      watchdog_escalation_threshold: 2,
      watchdog_restart_delay_ms: 500
    }
  end

  def profile(:prod) do
    %{
      guardian_timeout_ms: 5_000,
      guardian_circuit_threshold: 3,
      guardian_circuit_reset_ms: 30_000,
      guardian_health_interval_ms: 5_000,
      sentinel_sync_interval_ms: 30_000,
      sentinel_emergency_timeout_ms: 5_000,
      circuit_breaker_threshold: 3,
      circuit_breaker_reset_ms: 30_000,
      circuit_telemetry_threshold: 100,
      circuit_critical_threshold: 200,
      circuit_emergency_threshold: 500,
      smart_metrics_staleness_ms: 5_000,
      smart_metrics_interval_ms: 1_000,
      ai_insight_ttl_seconds: 300,
      ai_analysis_interval_ms: 10_000,
      orchestrator_ui_refresh_ms: 100,
      orchestrator_command_timeout_ms: 30_000,
      orchestrator_armed_ttl_ms: 30_000,
      max_retry_attempts: 3,
      backoff_base_ms: 1_000,
      exponential_backoff_base_ms: 1_000,
      backoff_max_ms: 60_000,
      dashboard_refresh_ms: 30_000,
      ooda_cycle_ms: 30_000,
      proof_token_ttl_ms: 300_000,
      health_check_interval_ms: 5_000,
      fail_closed_mode: false,
      immutable_state_verify_on_startup: true,
      # Dual-channel - balanced for production
      dual_channel_timeout_ms: 5_000,
      dual_channel_halt_threshold: 1,
      # Watchdog - balanced monitoring
      watchdog_heartbeat_timeout_ms: 2_000,
      watchdog_check_interval_ms: 500,
      watchdog_escalation_threshold: 3,
      watchdog_restart_delay_ms: 1_000
    }
  end

  def profile(:sil4) do
    %{
      # Guardian - strict 2s timeout (IEC 61508 SIL-4)
      guardian_timeout_ms: 2_000,
      guardian_circuit_threshold: 1,
      guardian_circuit_reset_ms: 60_000,
      guardian_health_interval_ms: 1_000,
      # Sentinel - strict emergency response
      sentinel_sync_interval_ms: 5_000,
      sentinel_emergency_timeout_ms: 2_000,
      # Circuit breaker - aggressive thresholds
      circuit_breaker_threshold: 1,
      circuit_breaker_reset_ms: 60_000,
      circuit_telemetry_threshold: 25,
      circuit_critical_threshold: 50,
      circuit_emergency_threshold: 100,
      # Metrics - high frequency monitoring
      smart_metrics_staleness_ms: 1_000,
      smart_metrics_interval_ms: 250,
      # AI - limited due to safety criticality
      ai_insight_ttl_seconds: 60,
      ai_analysis_interval_ms: 2_000,
      # Orchestrator - fast UI, strict command timeout
      orchestrator_ui_refresh_ms: 50,
      orchestrator_command_timeout_ms: 10_000,
      # Schema minimums: must be >= 10_000
      orchestrator_armed_ttl_ms: 10_000,
      # Retry - minimal attempts with slower backoff
      max_retry_attempts: 1,
      backoff_base_ms: 2_000,
      exponential_backoff_base_ms: 2_000,
      # Schema minimums: must be >= 10_000
      backoff_max_ms: 60_000,
      # Dashboard - frequent updates for safety monitoring
      # Schema minimums: must be >= 10_000
      dashboard_refresh_ms: 10_000,
      # Schema minimums: must be >= 10_000
      ooda_cycle_ms: 10_000,
      # PROMETHEUS - strict proof token expiry
      proof_token_ttl_ms: 15_000,
      health_check_interval_ms: 2_000,
      # Safety modes - ALL enabled for SIL-4
      fail_closed_mode: true,
      immutable_state_verify_on_startup: true,
      # Dual-channel - MANDATORY for SIL-4, strict 2s timeout
      dual_channel_timeout_ms: 2_000,
      dual_channel_halt_threshold: 1,
      # Watchdog - aggressive monitoring for safety
      watchdog_heartbeat_timeout_ms: 1_000,
      watchdog_check_interval_ms: 250,
      watchdog_escalation_threshold: 1,
      watchdog_restart_delay_ms: 500
    }
  end

  @doc """
  Returns the current active profile name based on Mix.env or config.

  ## Examples

      iex> Config.current_profile()
      :prod
  """
  @spec current_profile() :: sil_profile()
  def current_profile do
    Application.get_env(:indrajaal, __MODULE__, [])
    |> Keyword.get(:active_profile, env_to_profile())
  end

  @doc """
  Applies a SIL-level profile, merging it with current configuration.

  Only applies to hot-reloadable keys. Non-hot-reloadable keys require restart.

  Returns `{:ok, applied_keys}` with list of keys that were applied,
  or `{:error, :restart_required, non_hot_keys}` if non-hot keys differ.

  ## Examples

      iex> Config.apply_profile(:sil4)
      {:ok, [:guardian_circuit_threshold, :smart_metrics_interval_ms, ...]}
  """
  @spec apply_profile(sil_profile()) ::
          {:ok, [config_key()]} | {:error, :restart_required, [config_key()]}
  def apply_profile(profile_name) when profile_name in [:dev, :test, :prod, :sil4] do
    profile_config = profile(profile_name)

    {hot_keys, cold_keys} =
      profile_config
      |> Enum.split_with(fn {key, _value} -> hot_reloadable?(key) end)

    # Apply hot-reloadable keys
    applied =
      Enum.filter(hot_keys, fn {key, value} ->
        case set(key, value) do
          :ok -> true
          {:error, _} -> false
        end
      end)
      |> Enum.map(fn {key, _} -> key end)

    # Check if cold keys differ from current
    cold_diffs =
      Enum.filter(cold_keys, fn {key, value} ->
        get(key) != value
      end)
      |> Enum.map(fn {key, _} -> key end)

    # Log profile application
    log_to_fractal(:l4, "Config", "Profile applied: #{profile_name}", %{
      profile: profile_name,
      hot_applied: applied,
      cold_diffs: cold_diffs
    })

    if Enum.empty?(cold_diffs) do
      {:ok, applied}
    else
      {:error, :restart_required, cold_diffs}
    end
  end

  @doc """
  Validates a configuration map against the schema.

  Useful for validating profile configurations or external configs.

  ## Examples

      iex> Config.validate(%{guardian_timeout_ms: 5000})
      {:ok, %{guardian_timeout_ms: 5000}}

      iex> Config.validate(%{guardian_timeout_ms: -1})
      {:error, ["guardian_timeout_ms: value -1 below minimum 1000"]}
  """
  @spec validate(map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate(config) when is_map(config) do
    errors =
      config
      |> Enum.reduce([], fn {key, value}, acc ->
        case Map.get(@schema, key) do
          nil ->
            ["Unknown config key: #{key}" | acc]

          schema ->
            case validate_value(key, value, schema) do
              :ok -> acc
              {:error, msg} -> [msg | acc]
            end
        end
      end)

    if Enum.empty?(errors) do
      {:ok, config}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Returns all available profile names.
  """
  @spec available_profiles() :: [sil_profile()]
  def available_profiles, do: [:dev, :test, :prod, :sil4]

  @doc """
  Returns the SIL-4 target PFH (Probability of Failure per Hour).

  Per IEC 61508, SIL-4 requires PFH < 10^-8 (< 0.00000001 failures/hour).

  ## Examples

      iex> Config.sil4_target_pfh()
      1.0e-8
  """
  @spec sil4_target_pfh() :: float()
  def sil4_target_pfh, do: @sil4_target_pfh

  @doc """
  Returns a summary of profile characteristics.

  ## Examples

      iex> Config.profile_summary(:sil4)
      %{
        name: :sil4,
        max_timeout_ms: 2_000,
        circuit_breaker: :aggressive,
        dual_channel: :mandatory,
        fail_mode: :closed,
        verification: :mandatory,
        target_pfh: 1.0e-8
      }
  """
  @spec profile_summary(sil_profile()) :: map()
  def profile_summary(:dev) do
    %{
      name: :dev,
      description: "Development - relaxed timeouts, verbose logging",
      max_timeout_ms: 10_000,
      circuit_breaker: :relaxed,
      dual_channel: :enabled,
      fail_mode: :open,
      verification: :optional,
      watchdog: :relaxed
    }
  end

  def profile_summary(:test) do
    %{
      name: :test,
      description: "Test - fast deterministic timing, mock-friendly",
      max_timeout_ms: 1_000,
      circuit_breaker: :fast,
      dual_channel: :enabled,
      fail_mode: :open,
      verification: :optional,
      watchdog: :fast
    }
  end

  def profile_summary(:prod) do
    %{
      name: :prod,
      description: "Production - balanced timeouts, circuit breaker enabled",
      max_timeout_ms: 5_000,
      circuit_breaker: :balanced,
      dual_channel: :enabled,
      fail_mode: :open,
      verification: :mandatory,
      watchdog: :balanced
    }
  end

  def profile_summary(:sil4) do
    %{
      name: :sil4,
      description: "SIL-4 - strict 2s timeouts, all safety mechanisms enabled",
      max_timeout_ms: 2_000,
      circuit_breaker: :aggressive,
      dual_channel: :mandatory,
      fail_mode: :closed,
      verification: :mandatory,
      watchdog: :aggressive,
      target_pfh: @sil4_target_pfh,
      redundancy: :dual_channel,
      iec_61508: "SIL-4"
    }
  end

  @doc """
  Compares current configuration with a profile.

  Returns a map of `{key, {current_value, profile_value}}` for differing keys.
  """
  @spec diff_with_profile(sil_profile()) :: map()
  def diff_with_profile(profile_name) when profile_name in [:dev, :test, :prod, :sil4] do
    profile_config = profile(profile_name)
    current_config = all()

    profile_config
    |> Enum.filter(fn {key, profile_value} ->
      current_value = Map.get(current_config, key)
      current_value != profile_value
    end)
    |> Enum.into(%{}, fn {key, profile_value} ->
      {key, {Map.get(current_config, key), profile_value}}
    end)
  end

  # Maps Mix.env to default profile
  defp env_to_profile do
    case Application.get_env(:indrajaal, :env) || Mix.env() do
      :dev -> :dev
      :test -> :test
      :prod -> :prod
      _ -> :prod
    end
  rescue
    # Mix.env() not available in production
    _ -> :prod
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    Logger.info("[Prajna.Config] Validating configuration (SC-CONFIG-002)...")

    case validate_all() do
      {:ok, config} ->
        Logger.info("[Prajna.Config] Configuration valid: #{map_size(config)} keys loaded")
        emit_config_loaded(config)
        {:ok, config}

      {:error, errors} ->
        Logger.error("[Prajna.Config] Configuration invalid: #{length(errors)} errors")
        Enum.each(errors, &Logger.error("[Prajna.Config] #{&1}"))
        {:stop, {:config_invalid, errors}}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp get_value(key, schema) do
    Application.get_env(:indrajaal, __MODULE__, [])
    |> Keyword.get(key, schema.default)
  end

  defp validate_value(key, value, schema) do
    with :ok <- validate_type(key, value, schema.type),
         :ok <- validate_min(key, value, schema) do
      validate_max(key, value, schema)
    end
  end

  defp validate_type(_key, value, :pos_integer) when is_integer(value) and value > 0, do: :ok
  defp validate_type(_key, value, :boolean) when is_boolean(value), do: :ok
  defp validate_type(_key, value, :string) when is_binary(value), do: :ok
  defp validate_type(_key, value, :map) when is_map(value), do: :ok

  defp validate_type(key, value, expected) do
    {:error, "#{key}: expected #{expected}, got #{inspect(value)}"}
  end

  defp validate_min(_key, _value, %{min: nil}), do: :ok
  defp validate_min(_key, _value, schema) when not is_map_key(schema, :min), do: :ok
  defp validate_min(_key, value, %{min: min}) when value >= min, do: :ok

  defp validate_min(key, value, %{min: min}) do
    {:error, "#{key}: value #{value} below minimum #{min}"}
  end

  defp validate_max(_key, _value, %{max: nil}), do: :ok
  defp validate_max(_key, _value, schema) when not is_map_key(schema, :max), do: :ok
  defp validate_max(_key, value, %{max: max}) when value <= max, do: :ok

  defp validate_max(key, value, %{max: max}) do
    {:error, "#{key}: value #{value} above maximum #{max}"}
  end

  defp emit_config_loaded(config) do
    :telemetry.execute(
      [:indrajaal, :prajna, :config, :loaded],
      %{key_count: map_size(config), timestamp: System.system_time(:millisecond)},
      %{config: config}
    )

    # Log initialization to Segment level (L2)
    log_to_fractal(:l3, "Config", "Configuration loaded", %{
      key_count: map_size(config),
      keys: Map.keys(config)
    })
  end

  defp log_config_change(key, old_value, new_value, schema) do
    level = Map.get(schema, :level, :l3)

    change_data = %{
      key: key,
      old_value: old_value,
      new_value: new_value,
      timestamp: DateTime.utc_now(),
      hot_reload: Map.get(schema, :hot_reload, false)
    }

    log_to_fractal(level, "Config", "Configuration changed: #{key}", change_data)

    # Emit telemetry event
    :telemetry.execute(
      [:indrajaal, :prajna, :config, :changed],
      %{timestamp: System.system_time(:millisecond)},
      change_data
    )
  end

  defp log_to_fractal(level, source, message, context) do
    # Only log if FractalLogger is available
    case Code.ensure_loaded(Indrajaal.Observability.FractalLogger) do
      {:module, _} ->
        case level do
          :l5 -> FractalLogger.spine(source, message, context)
          :l4 -> FractalLogger.thorax(source, message, context)
          :l3 -> FractalLogger.segment(source, message, context)
          :l2 -> FractalLogger.fiber(source, message, context)
          :l1 -> FractalLogger.gossamer(source, message, context)
          _ -> FractalLogger.segment(source, message, context)
        end

      {:error, _} ->
        # FractalLogger not available, log to standard Logger
        Logger.info("[#{source}] #{message} #{inspect(context)}")
    end
  end
end
