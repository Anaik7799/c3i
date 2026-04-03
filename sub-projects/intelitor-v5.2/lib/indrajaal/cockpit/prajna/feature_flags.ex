defmodule Indrajaal.Cockpit.Prajna.FeatureFlags do
  @moduledoc """
  Feature Flag System inspired by Azure App Configuration.

  WHAT: Dynamic feature control for Prajna components.
  WHY: Enables gradual rollouts and A/B testing (SC-CONFIG-006).

  ## Flag Types
  - Boolean: Simple on/off
  - Percentage: Gradual rollout (10%, 50%, 100%)
  - Targeting: User/group-based activation
  - Time Window: Scheduled activation

  ## Fractal Integration
  Flag changes are logged to the appropriate fractal level based on flag configuration:
  - L5 (Spine): Constitutional flags requiring Guardian
  - L4 (Thorax): Container-level flags
  - L3 (Segment): Agent-level flags

  CONSTRAINTS:
    - SC-PRAJNA-001: Flags requiring Guardian must pass approval
    - SC-BIO-007: Graceful degradation on rate limit
    - SC-CONFIG-006: Feature flag support mandatory
    - SC-FRAC-CONFIG-001: All changes logged to appropriate fractal level

  ## Usage

      # Check if feature is enabled
      FeatureFlags.enabled?(:guardian_circuit_breaker)

      # Check with context (for percentage rollouts)
      FeatureFlags.enabled?(:new_dashboard_ui, %{user_id: 123})

      # Enable a flag
      FeatureFlags.enable(:my_feature)

      # Set percentage rollout
      FeatureFlags.set_percentage(:new_feature, 25)
  """

  use GenServer
  require Logger
  alias Indrajaal.Observability.FractalLogger
  alias Indrajaal.Cockpit.Prajna.Config

  @type flag_name :: atom()
  @type flag_value :: boolean() | non_neg_integer() | map() | nil
  @type flag_type :: :boolean | :percentage | :time_window | :targeting
  @type flag_level :: :l1 | :l2 | :l3 | :l4 | :l5

  # ============================================================================
  # Flag Definitions
  # ============================================================================

  @flags %{
    # Sprint 31 feature flags
    guardian_circuit_breaker: %{
      type: :boolean,
      default: true,
      level: :l4,
      requires_guardian: false,
      description: "Enable circuit breaker for Guardian calls"
    },
    immutable_state_duckdb: %{
      type: :boolean,
      default: true,
      level: :l5,
      requires_guardian: true,
      description: "Persist ImmutableState to DuckDB"
    },
    ai_copilot_founder_validation: %{
      type: :boolean,
      default: true,
      level: :l4,
      requires_guardian: true,
      description: "Validate AI recommendations against Founder's Directive"
    },
    sentinel_bridge_sync: %{
      type: :boolean,
      default: true,
      level: :l3,
      requires_guardian: false,
      description: "Enable bidirectional Sentinel sync"
    },
    fractal_config_distribution: %{
      type: :boolean,
      default: true,
      level: :l4,
      requires_guardian: false,
      description: "Enable Zenoh-based config distribution"
    },
    config_change_logging: %{
      type: :boolean,
      default: true,
      level: :l3,
      requires_guardian: false,
      description: "Log all config changes to FractalLogger"
    },

    # Gradual rollout flags
    new_dashboard_ui: %{
      type: :percentage,
      default: 0,
      level: :l2,
      requires_guardian: false,
      description: "New dashboard UI rollout percentage"
    },
    enhanced_metrics_display: %{
      type: :percentage,
      default: 0,
      level: :l2,
      requires_guardian: false,
      description: "Enhanced metrics display rollout"
    },

    # Time-based flags
    maintenance_mode: %{
      type: :time_window,
      default: nil,
      level: :l4,
      requires_guardian: true,
      description: "Scheduled maintenance window"
    },

    # Debug/Development flags
    debug_logging: %{
      type: :boolean,
      default: false,
      level: :l1,
      requires_guardian: false,
      description: "Enable verbose debug logging"
    },
    mock_guardian: %{
      type: :boolean,
      default: false,
      level: :l1,
      requires_guardian: false,
      description: "Use mock Guardian for testing"
    }
  }

  @doc """
  Returns the flag definition schema.
  """
  @spec flags() :: map()
  def flags, do: @flags

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the FeatureFlags GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Check if a feature flag is enabled.

  ## Parameters
    - `flag`: The flag name (atom)
    - `context`: Optional context for percentage/targeting evaluation

  ## Examples

      iex> FeatureFlags.enabled?(:guardian_circuit_breaker)
      true

      iex> FeatureFlags.enabled?(:new_dashboard_ui, %{user_id: 123})
      false  # Based on percentage and hash of context
  """
  @spec enabled?(flag_name(), map()) :: boolean()
  def enabled?(flag, context \\ %{}) when is_atom(flag) do
    GenServer.call(__MODULE__, {:enabled?, flag, context})
  end

  @doc """
  Enable a boolean feature flag.

  Flags marked with `requires_guardian: true` will first submit a proposal
  to Guardian for approval before enabling.

  ## Examples

      iex> FeatureFlags.enable(:debug_logging)
      :ok

      iex> FeatureFlags.enable(:immutable_state_duckdb)
      {:error, {:guardian_veto, "Not authorized"}}
  """
  @spec enable(flag_name(), keyword()) :: :ok | {:error, term()}
  def enable(flag, opts \\ []) when is_atom(flag) do
    GenServer.call(__MODULE__, {:enable, flag, opts})
  end

  @doc """
  Disable a boolean feature flag.
  """
  @spec disable(flag_name()) :: :ok | {:error, term()}
  def disable(flag) when is_atom(flag) do
    GenServer.call(__MODULE__, {:disable, flag})
  end

  @doc """
  Set percentage for gradual rollout flags (0-100).

  ## Examples

      iex> FeatureFlags.set_percentage(:new_dashboard_ui, 25)
      :ok
  """
  @spec set_percentage(flag_name(), 0..100) :: :ok | {:error, term()}
  def set_percentage(flag, percentage)
      when is_atom(flag) and is_integer(percentage) and percentage >= 0 and percentage <= 100 do
    GenServer.call(__MODULE__, {:set_percentage, flag, percentage})
  end

  @doc """
  Set time window for time-based flags.

  ## Examples

      iex> FeatureFlags.set_time_window(:maintenance_mode, ~U[2026-01-03 02:00:00Z], ~U[2026-01-03 06:00:00Z])
      :ok
  """
  @spec set_time_window(flag_name(), DateTime.t(), DateTime.t()) :: :ok | {:error, term()}
  def set_time_window(flag, start_time, end_time) when is_atom(flag) do
    GenServer.call(__MODULE__, {:set_time_window, flag, start_time, end_time})
  end

  @doc """
  Get current value of a flag.
  """
  @spec get_value(flag_name()) :: {:ok, flag_value()} | {:error, :unknown_flag}
  def get_value(flag) when is_atom(flag) do
    GenServer.call(__MODULE__, {:get_value, flag})
  end

  @doc """
  Get all flag states as a map.
  """
  @spec all() :: map()
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @doc """
  Reset a flag to its default value.
  """
  @spec reset(flag_name()) :: :ok | {:error, term()}
  def reset(flag) when is_atom(flag) do
    GenServer.call(__MODULE__, {:reset, flag})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    # Load flag overrides from config
    overrides = Config.get(:feature_flag_overrides, %{})

    # Merge defaults with overrides
    state =
      Enum.reduce(@flags, %{}, fn {name, spec}, acc ->
        override_value = Map.get(overrides, name)
        value = if override_value != nil, do: override_value, else: spec.default
        Map.put(acc, name, Map.put(spec, :value, value))
      end)

    Logger.info("[FeatureFlags] Initialized with #{map_size(state)} flags")
    log_flag_init(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:enabled?, flag, context}, _from, state) do
    result =
      case Map.get(state, flag) do
        nil ->
          false

        %{type: :boolean, value: value} when is_boolean(value) ->
          value

        %{type: :boolean} = spec ->
          Map.get(spec, :value, spec.default)

        %{type: :percentage} = spec ->
          percentage = Map.get(spec, :value, spec.default) || 0
          evaluate_percentage(percentage, context)

        %{type: :time_window} = spec ->
          window = Map.get(spec, :value, spec.default)
          in_time_window?(window)

        %{type: :targeting} = spec ->
          targets = Map.get(spec, :value, spec.default) || %{}
          evaluate_targeting(targets, context)
      end

    # Log flag evaluation at Gossamer level (trace)
    log_flag_evaluation(flag, result, context)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:enable, flag, _opts}, _from, state) do
    case Map.get(state, flag) do
      nil ->
        {:reply, {:error, :unknown_flag}, state}

      spec ->
        case maybe_check_guardian(spec, :enable, flag) do
          :ok ->
            new_spec = Map.put(spec, :value, true)
            new_state = Map.put(state, flag, new_spec)
            log_flag_change(flag, spec, new_spec, :enable)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:disable, flag}, _from, state) do
    case Map.get(state, flag) do
      nil ->
        {:reply, {:error, :unknown_flag}, state}

      spec ->
        case maybe_check_guardian(spec, :disable, flag) do
          :ok ->
            new_spec = Map.put(spec, :value, false)
            new_state = Map.put(state, flag, new_spec)
            log_flag_change(flag, spec, new_spec, :disable)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:set_percentage, flag, percentage}, _from, state) do
    case Map.get(state, flag) do
      nil ->
        {:reply, {:error, :unknown_flag}, state}

      %{type: :percentage} = spec ->
        case maybe_check_guardian(spec, :set_percentage, flag) do
          :ok ->
            new_spec = Map.put(spec, :value, percentage)
            new_state = Map.put(state, flag, new_spec)
            log_flag_change(flag, spec, new_spec, :set_percentage)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _ ->
        {:reply, {:error, :not_percentage_flag}, state}
    end
  end

  @impl GenServer
  def handle_call({:set_time_window, flag, start_time, end_time}, _from, state) do
    case Map.get(state, flag) do
      nil ->
        {:reply, {:error, :unknown_flag}, state}

      %{type: :time_window} = spec ->
        case maybe_check_guardian(spec, :set_time_window, flag) do
          :ok ->
            window = %{start: start_time, end: end_time}
            new_spec = Map.put(spec, :value, window)
            new_state = Map.put(state, flag, new_spec)
            log_flag_change(flag, spec, new_spec, :set_time_window)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _ ->
        {:reply, {:error, :not_time_window_flag}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_value, flag}, _from, state) do
    case Map.get(state, flag) do
      nil -> {:reply, {:error, :unknown_flag}, state}
      spec -> {:reply, {:ok, Map.get(spec, :value, spec.default)}, state}
    end
  end

  @impl GenServer
  def handle_call(:all, _from, state) do
    result =
      Map.new(state, fn {name, spec} ->
        {name,
         %{
           type: spec.type,
           value: Map.get(spec, :value, spec.default),
           level: spec.level,
           requires_guardian: spec.requires_guardian
         }}
      end)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:reset, flag}, _from, state) do
    case Map.get(state, flag) do
      nil ->
        {:reply, {:error, :unknown_flag}, state}

      spec ->
        new_spec = Map.put(spec, :value, spec.default)
        new_state = Map.put(state, flag, new_spec)
        log_flag_change(flag, spec, new_spec, :reset)
        {:reply, :ok, new_state}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp evaluate_percentage(percentage, _context) when percentage >= 100, do: true
  defp evaluate_percentage(percentage, _context) when percentage <= 0, do: false

  defp evaluate_percentage(percentage, context) do
    # Use context hash for consistent bucketing
    hash = :erlang.phash2(context, 100)
    hash < percentage
  end

  defp in_time_window?(nil), do: false

  defp in_time_window?(%{start: start_time, end: end_time}) do
    now = DateTime.utc_now()

    DateTime.compare(now, start_time) in [:gt, :eq] and
      DateTime.compare(now, end_time) in [:lt, :eq]
  end

  defp in_time_window?(_), do: false

  defp evaluate_targeting(targets, context) when is_map(targets) and is_map(context) do
    # Check if any targeting rule matches
    Enum.any?(targets, fn {key, allowed_values} ->
      context_value = Map.get(context, key)
      context_value != nil and context_value in List.wrap(allowed_values)
    end)
  end

  defp evaluate_targeting(_, _), do: false

  defp maybe_check_guardian(%{requires_guardian: true, level: level}, action, flag) do
    # SC-SIL4-001: Fail-closed for safety-critical flags
    # L5 (Constitutional) flags MUST have Guardian approval - never bypass
    case check_guardian_available() do
      {:ok, mod} ->
        proposal = %{
          type: :feature_flag,
          action: action,
          flag: flag,
          level: level,
          timestamp: DateTime.utc_now()
        }

        case mod.submit_proposal(proposal) do
          {:ok, _} -> :ok
          {:veto, reason, _} -> {:error, {:guardian_veto, reason}}
          {:error, :circuit_open} -> handle_circuit_open(level, action, flag)
          {:error, :timeout} -> handle_guardian_timeout(level, action, flag)
          _ -> :ok
        end

      {:error, :not_loaded} ->
        handle_guardian_unavailable(level, action, flag)
    end
  end

  defp maybe_check_guardian(%{requires_guardian: true}, action, flag) do
    # Fallback for flags without level specification - assume L4
    maybe_check_guardian(%{requires_guardian: true, level: :l4}, action, flag)
  end

  defp maybe_check_guardian(_spec, _action, _flag), do: :ok

  # SC-SIL4-001: Helper to check if Guardian module is loaded
  defp check_guardian_available do
    case Code.ensure_loaded(Indrajaal.Cockpit.Prajna.GuardianIntegration) do
      {:module, mod} -> {:ok, mod}
      {:error, _} -> {:error, :not_loaded}
    end
  end

  # SC-SIL4-002: Handle Guardian unavailable - fail-closed for L5
  defp handle_guardian_unavailable(:l5, action, flag) do
    # L5 (Constitutional) flags MUST NEVER proceed without Guardian
    Logger.error(
      "[FeatureFlags] BLOCKED: Guardian unavailable for L5 flag #{flag} action #{action}"
    )

    emit_sil4_violation(:guardian_unavailable, %{flag: flag, action: action, level: :l5})
    {:error, {:guardian_unavailable, "L5 flags require Guardian approval"}}
  end

  defp handle_guardian_unavailable(level, action, flag) do
    # L4 and below: allow in dev/test only, fail-closed in prod
    if allow_bypass_in_current_env?() do
      Logger.warning(
        "[FeatureFlags] Guardian unavailable, allowing #{action} on #{flag} (#{level}) in #{Mix.env()}"
      )

      :ok
    else
      Logger.error(
        "[FeatureFlags] BLOCKED: Guardian unavailable for #{flag} action #{action} in production"
      )

      emit_sil4_violation(:guardian_unavailable, %{flag: flag, action: action, level: level})
      {:error, {:guardian_unavailable, "Guardian required in production"}}
    end
  end

  # SC-SIL4-003: Handle circuit breaker open - fail-closed for L5
  defp handle_circuit_open(:l5, action, flag) do
    Logger.error("[FeatureFlags] BLOCKED: Circuit open for L5 flag #{flag} action #{action}")

    emit_sil4_violation(:circuit_open, %{flag: flag, action: action, level: :l5})
    {:error, {:circuit_open, "L5 flags cannot bypass circuit breaker"}}
  end

  defp handle_circuit_open(level, action, flag) do
    if allow_bypass_in_current_env?() do
      Logger.warning(
        "[FeatureFlags] Circuit open, allowing #{action} on #{flag} (#{level}) in #{Mix.env()}"
      )

      :ok
    else
      Logger.error("[FeatureFlags] BLOCKED: Circuit open for #{flag} action #{action}")

      {:error, {:circuit_open, "Guardian circuit breaker is open"}}
    end
  end

  # SC-SIL4-004: Handle Guardian timeout - fail-closed for L5
  defp handle_guardian_timeout(:l5, action, flag) do
    Logger.error("[FeatureFlags] BLOCKED: Guardian timeout for L5 flag #{flag} action #{action}")

    emit_sil4_violation(:guardian_timeout, %{flag: flag, action: action, level: :l5})
    {:error, {:guardian_timeout, "L5 flags require Guardian response"}}
  end

  defp handle_guardian_timeout(level, action, flag) do
    if allow_bypass_in_current_env?() do
      Logger.warning(
        "[FeatureFlags] Guardian timeout, allowing #{action} on #{flag} (#{level}) in #{Mix.env()}"
      )

      :ok
    else
      Logger.error("[FeatureFlags] BLOCKED: Guardian timeout for #{flag} action #{action}")

      {:error, {:guardian_timeout, "Guardian did not respond in time"}}
    end
  end

  # Only allow bypass in dev/test environments
  defp allow_bypass_in_current_env? do
    Mix.env() in [:dev, :test]
  end

  # Emit SIL-4 violation telemetry for monitoring
  defp emit_sil4_violation(violation_type, context) do
    :telemetry.execute(
      [:indrajaal, :prajna, :sil4, :violation],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      Map.merge(context, %{violation_type: violation_type, severity: :critical})
    )
  end

  defp log_flag_init(state) do
    enabled_count =
      Enum.count(state, fn {_, spec} -> Map.get(spec, :value, spec.default) == true end)

    FractalLogger.segment(
      "FeatureFlags",
      "Initialized #{map_size(state)} flags, #{enabled_count} enabled",
      %{flag_count: map_size(state), enabled_count: enabled_count}
    )
  end

  defp log_flag_evaluation(flag, result, context) do
    FractalLogger.gossamer(
      "FeatureFlags",
      "Evaluated #{flag} = #{result}",
      %{flag: flag, result: result, context: context}
    )
  end

  defp log_flag_change(flag, old_spec, new_spec, action) do
    level = Map.get(new_spec, :level, :l3)

    change = %{
      flag: flag,
      action: action,
      old_value: Map.get(old_spec, :value, old_spec.default),
      new_value: Map.get(new_spec, :value, new_spec.default),
      timestamp: DateTime.utc_now()
    }

    # Log to appropriate fractal level based on flag configuration
    case level do
      :l5 ->
        FractalLogger.spine("FeatureFlags", "Flag #{flag} changed: #{action}", change)

      :l4 ->
        FractalLogger.thorax("FeatureFlags", "Flag #{flag} changed: #{action}", change)

      :l3 ->
        FractalLogger.segment("FeatureFlags", "Flag #{flag} changed: #{action}", change)

      :l2 ->
        FractalLogger.fiber("FeatureFlags", "Flag #{flag} changed: #{action}", change)

      _ ->
        FractalLogger.gossamer("FeatureFlags", "Flag #{flag} changed: #{action}", change)
    end

    # Also emit telemetry
    :telemetry.execute(
      [:indrajaal, :prajna, :feature_flag, :change],
      %{timestamp: System.system_time(:millisecond)},
      change
    )
  end
end
