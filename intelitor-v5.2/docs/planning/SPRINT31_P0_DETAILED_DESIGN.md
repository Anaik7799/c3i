# Sprint 31 P0 Detailed Design Specification

**Version**: 1.0.0
**Date**: 2026-01-02
**Author**: Cybernetic Architect (Claude Opus 4.5)
**Status**: DRAFT - Pending Approval
**Target**: IEC 61508 SIL-6 Biomorphic Compliance

---

## Table of Contents

1. [Overview](#1-overview)
2. [31.3: Prajna.Config Module](#2-313-prajnaconfig-module)
3. [31.1: Guardian Resilience](#3-311-guardian-resilience)
4. [31.2: ImmutableState Persistence](#4-312-immutablestate-persistence)
5. [Dependencies & Execution Order](#5-dependencies--execution-order)
6. [Test Strategy](#6-test-strategy)
7. [Rollback Plan](#7-rollback-plan)

---

## 1. Overview

### 1.1 Scope

This document specifies the detailed design for Sprint 31 P0 components required to address critical SIL-6 Biomorphic compliance gaps:

| Component | Gap Addressed | SIL-6 Biomorphic Impact |
|-----------|---------------|--------------|
| Prajna.Config | 40+ hardcoded values | SC-CONFIG-001 |
| Guardian Timeout | Infinite hang risk | PFH improvement |
| Guardian Circuit Breaker | Cascade failure | SFF > 99% |
| Guardian Health Check | Silent failure | DC > 99% |
| ImmutableState DuckDB | In-memory only | SC-HOLON-001 |
| Chain Verification | Manual only | SC-REG-002 |

### 1.2 Design Principles

1. **Fail-Safe Defaults**: All defaults must be safe for SIL-6 Biomorphic operation
2. **Explicit Over Implicit**: No silent fallbacks that bypass safety
3. **Observable**: Every state change emits telemetry
4. **Configurable**: All timing values from Application config
5. **Testable**: Every function has property-based tests

### 1.3 STAMP Constraints Applied

```
SC-SIL6-001: Guardian MUST have configurable timeout (default 5000ms)
SC-SIL6-002: ImmutableState MUST persist to DuckDB
SC-SIL6-003: Hash chain verified automatically on startup
SC-CONFIG-001: No hardcoded timing values in modules
SC-CONFIG-002: Configuration validation on startup
SC-RECOVER-001: Exponential backoff on all retries
```

---

## 2. 31.3: Prajna.Config Module

### 2.1 Purpose

Centralized configuration management for all Prajna cockpit modules with:
- Startup validation
- Type checking
- Default values with SIL-6 Biomorphic safe defaults
- Runtime introspection (no hot reload for safety)

### 2.2 Module Structure

```elixir
defmodule Indrajaal.Cockpit.Prajna.Config do
  @moduledoc """
  Centralized Configuration for Prajna Cockpit.

  WHAT: Single source of truth for all Prajna timing and threshold values.
  WHY: SC-CONFIG-001 requires no hardcoded timing values in modules.

  CONSTRAINTS:
    - SC-CONFIG-001: All timing values from Application config
    - SC-CONFIG-002: Validation on startup
    - SC-SIL6-003: Safe defaults for SIL-6 Biomorphic operation

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
    immutable_state_duckdb_path: "data/holons/prajna_register.duckdb",

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
    ooda_cycle_ms: 30_000
  ```
  """

  use GenServer
  require Logger

  @type config_key :: atom()
  @type config_value :: integer() | boolean() | String.t()

  # ============================================================================
  # Configuration Schema with Defaults and Validation
  # ============================================================================

  @schema %{
    # Guardian settings (SC-SIL6-001)
    guardian_timeout_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 30_000,
      description: "Guardian proposal validation timeout"
    },
    guardian_circuit_threshold: %{
      default: 3,
      type: :pos_integer,
      min: 1,
      max: 10,
      description: "Consecutive failures before circuit opens"
    },
    guardian_circuit_reset_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 300_000,
      description: "Time before circuit attempts reset"
    },
    guardian_health_interval_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 60_000,
      description: "Guardian health check interval"
    },

    # Sentinel Bridge settings
    sentinel_sync_interval_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 300_000,
      description: "Sentinel health sync interval"
    },
    sentinel_emergency_timeout_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 30_000,
      description: "Emergency sync timeout"
    },

    # ImmutableState settings (SC-SIL6-002, SC-SIL6-003)
    immutable_state_verify_on_startup: %{
      default: true,
      type: :boolean,
      description: "Verify hash chain on startup (SIL-6 Biomorphic mandatory)"
    },
    immutable_state_duckdb_path: %{
      default: "data/holons/prajna_register.duckdb",
      type: :string,
      description: "DuckDB persistence file path"
    },

    # Circuit Breaker thresholds
    circuit_telemetry_threshold: %{
      default: 100,
      type: :pos_integer,
      min: 10,
      max: 1000,
      description: "Queue depth for telemetry throttling"
    },
    circuit_critical_threshold: %{
      default: 200,
      type: :pos_integer,
      min: 50,
      max: 2000,
      description: "Queue depth for critical mode"
    },
    circuit_emergency_threshold: %{
      default: 500,
      type: :pos_integer,
      min: 100,
      max: 5000,
      description: "Queue depth for emergency mode"
    },

    # SmartMetrics settings
    smart_metrics_staleness_ms: %{
      default: 5_000,
      type: :pos_integer,
      min: 1_000,
      max: 60_000,
      description: "Metric staleness threshold"
    },
    smart_metrics_interval_ms: %{
      default: 1_000,
      type: :pos_integer,
      min: 100,
      max: 10_000,
      description: "Metrics collection interval"
    },

    # AI Copilot settings
    ai_insight_ttl_seconds: %{
      default: 300,
      type: :pos_integer,
      min: 60,
      max: 3600,
      description: "AI insight time-to-live"
    },
    ai_analysis_interval_ms: %{
      default: 10_000,
      type: :pos_integer,
      min: 1_000,
      max: 60_000,
      description: "AI analysis cycle interval"
    },

    # Orchestrator settings
    orchestrator_ui_refresh_ms: %{
      default: 100,
      type: :pos_integer,
      min: 50,
      max: 1000,
      description: "UI refresh rate"
    },
    orchestrator_command_timeout_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 120_000,
      description: "Command execution timeout"
    },
    orchestrator_armed_ttl_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 10_000,
      max: 120_000,
      description: "Armed command expiration (SC-HMI safety)"
    },

    # Retry settings (SC-RECOVER-001)
    max_retry_attempts: %{
      default: 3,
      type: :pos_integer,
      min: 1,
      max: 10,
      description: "Maximum retry attempts"
    },
    backoff_base_ms: %{
      default: 1_000,
      type: :pos_integer,
      min: 100,
      max: 10_000,
      description: "Exponential backoff base delay"
    },
    backoff_max_ms: %{
      default: 60_000,
      type: :pos_integer,
      min: 10_000,
      max: 300_000,
      description: "Maximum backoff delay"
    },

    # Dashboard settings
    dashboard_refresh_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 5_000,
      max: 120_000,
      description: "Dashboard refresh interval"
    },

    # OODA cycle (SC-BIO-001)
    ooda_cycle_ms: %{
      default: 30_000,
      type: :pos_integer,
      min: 10_000,
      max: 120_000,
      description: "OODA loop cycle time"
    }
  }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the Config GenServer.
  Validates all configuration on startup.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
      {:ok, config} -> config
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

    delay = base * :math.pow(2, attempt - 1) |> round()
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
    delay + :rand.uniform(jitter * 2) - jitter
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
         :ok <- validate_min(key, value, schema),
         :ok <- validate_max(key, value, schema) do
      :ok
    end
  end

  defp validate_type(_key, value, :pos_integer) when is_integer(value) and value > 0, do: :ok
  defp validate_type(_key, value, :boolean) when is_boolean(value), do: :ok
  defp validate_type(_key, value, :string) when is_binary(value), do: :ok
  defp validate_type(key, value, expected) do
    {:error, "#{key}: expected #{expected}, got #{inspect(value)}"}
  end

  defp validate_min(_key, _value, %{min: nil}), do: :ok
  defp validate_min(_key, value, %{min: min}) when value >= min, do: :ok
  defp validate_min(key, value, %{min: min}) do
    {:error, "#{key}: value #{value} below minimum #{min}"}
  end

  defp validate_max(_key, _value, %{max: nil}), do: :ok
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
  end
end
```

### 2.3 Integration Pattern

```elixir
# Before (hardcoded):
@sync_interval_ms 30_000

defp schedule_sync(state) do
  Process.send_after(self(), :sync_tick, @sync_interval_ms)
  state
end

# After (configurable):
alias Indrajaal.Cockpit.Prajna.Config

defp schedule_sync(state) do
  interval = Config.get(:sentinel_sync_interval_ms)
  Process.send_after(self(), :sync_tick, interval)
  state
end
```

### 2.4 Telemetry Events

| Event | Measurements | Metadata |
|-------|--------------|----------|
| `[:indrajaal, :prajna, :config, :loaded]` | key_count, timestamp | config map |
| `[:indrajaal, :prajna, :config, :validation_failed]` | error_count | errors list |

---

## 3. 31.1: Guardian Resilience

### 3.1 Purpose

Add timeout, circuit breaker, and health monitoring to Guardian integration to prevent system hangs and cascade failures.

### 3.2 Module Changes: GuardianIntegration

```elixir
defmodule Indrajaal.Cockpit.Prajna.GuardianIntegration do
  @moduledoc """
  Guardian Integration Layer for Prajna Cockpit.

  WHAT: Safety gate that validates all Prajna commands through Guardian.
  WHY: SC-PRAJNA-001 requires all commands pass Guardian approval.

  CONSTRAINTS:
    - SC-PRAJNA-001: All commands through Guardian pre-approval
    - SC-SIL6-001: Configurable timeout (default 5000ms)
    - SC-RECOVER-001: Exponential backoff on transient failures
    - AOR-PRAJNA-001: Guardian gate mandatory

  ## Resilience Features (Sprint 31)

  1. **Timeout**: Configurable via Config.get(:guardian_timeout_ms)
  2. **Circuit Breaker**: Opens after Config.get(:guardian_circuit_threshold) failures
  3. **Health Check**: Periodic liveness probe via Guardian.alive?/0
  4. **Exponential Backoff**: Retries with jitter on transient failures
  """

  use GenServer
  require Logger
  alias Indrajaal.Cockpit.Prajna.Config
  alias Indrajaal.Cockpit.Prajna.ImmutableState
  alias Indrajaal.Safety.Guardian

  # Circuit breaker states
  @type circuit_state :: :closed | :open | :half_open

  defstruct [
    :circuit_state,
    :failure_count,
    :last_failure_time,
    :last_health_check,
    :health_status
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the GuardianIntegration GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Submits a proposal to Guardian for validation.

  Returns:
    - {:ok, :approved} - Proposal approved
    - {:veto, reason, fallback} - Proposal vetoed with fallback action
    - {:error, :timeout} - Guardian did not respond within timeout
    - {:error, :circuit_open} - Circuit breaker is open
    - {:error, reason} - Other error

  ## Examples

      iex> GuardianIntegration.submit_proposal(%{action: :scale_up, agent_count: 5})
      {:ok, :approved}

      iex> GuardianIntegration.submit_proposal(%{action: :terminate_all})
      {:veto, "Violates Ψ₀", :scale_down}
  """
  @spec submit_proposal(map()) ::
    {:ok, :approved} |
    {:veto, String.t(), atom()} |
    {:error, atom()}
  def submit_proposal(proposal) when is_map(proposal) do
    timeout = Config.get(:guardian_timeout_ms)
    GenServer.call(__MODULE__, {:submit_proposal, proposal}, timeout + 1000)
  catch
    :exit, {:timeout, _} ->
      Logger.error("[GuardianIntegration] Proposal timeout after #{timeout}ms")
      emit_timeout(proposal)
      {:error, :timeout}
  end

  @doc """
  Checks if Guardian is healthy and responsive.
  """
  @spec healthy?() :: boolean()
  def healthy? do
    GenServer.call(__MODULE__, :healthy?, 5_000)
  catch
    :exit, _ -> false
  end

  @doc """
  Returns current circuit breaker state.
  """
  @spec circuit_state() :: circuit_state()
  def circuit_state do
    GenServer.call(__MODULE__, :circuit_state, 5_000)
  catch
    :exit, _ -> :unknown
  end

  @doc """
  Forces circuit breaker reset (for testing/emergency).
  """
  @spec reset_circuit() :: :ok
  def reset_circuit do
    GenServer.call(__MODULE__, :reset_circuit, 5_000)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    Logger.info("[GuardianIntegration] Starting with circuit breaker (SC-SIL6-001)")
    schedule_health_check()

    state = %__MODULE__{
      circuit_state: :closed,
      failure_count: 0,
      last_failure_time: nil,
      last_health_check: nil,
      health_status: :unknown
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:submit_proposal, proposal}, _from, state) do
    case check_circuit(state) do
      {:ok, state} ->
        result = execute_proposal(proposal, state)
        {:reply, elem(result, 0), elem(result, 1)}

      {:error, :circuit_open} = error ->
        emit_circuit_rejected(proposal)
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:healthy?, _from, state) do
    {:reply, state.health_status == :healthy and state.circuit_state != :open, state}
  end

  @impl GenServer
  def handle_call(:circuit_state, _from, state) do
    {:reply, state.circuit_state, state}
  end

  @impl GenServer
  def handle_call(:reset_circuit, _from, state) do
    Logger.info("[GuardianIntegration] Circuit breaker manually reset")
    emit_circuit_reset(:manual)
    {:reply, :ok, %{state | circuit_state: :closed, failure_count: 0}}
  end

  @impl GenServer
  def handle_info(:health_check, state) do
    new_state = perform_health_check(state)
    schedule_health_check()
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:circuit_half_open, state) do
    Logger.info("[GuardianIntegration] Circuit transitioning to half-open")
    emit_circuit_state_change(:half_open)
    {:noreply, %{state | circuit_state: :half_open}}
  end

  # ============================================================================
  # Private: Circuit Breaker Logic
  # ============================================================================

  defp check_circuit(%{circuit_state: :open} = state) do
    reset_ms = Config.get(:guardian_circuit_reset_ms)
    elapsed = System.monotonic_time(:millisecond) - (state.last_failure_time || 0)

    if elapsed >= reset_ms do
      {:ok, %{state | circuit_state: :half_open}}
    else
      {:error, :circuit_open}
    end
  end

  defp check_circuit(state), do: {:ok, state}

  defp execute_proposal(proposal, state) do
    timeout = Config.get(:guardian_timeout_ms)

    try do
      case Guardian.validate_proposal(proposal, timeout: timeout) do
        {:ok, validated} ->
          new_state = record_success(state)
          log_to_immutable_register(proposal, :approved, nil)
          emit_proposal_approved(proposal)
          {{:ok, :approved}, new_state}

        {:veto, reason, fallback} ->
          new_state = record_success(state)  # Veto is a valid response
          log_to_immutable_register(proposal, :vetoed, reason)
          emit_proposal_vetoed(proposal, reason)
          {{:veto, reason, fallback}, new_state}

        {:error, reason} ->
          new_state = record_failure(state, reason)
          emit_proposal_error(proposal, reason)
          {{:error, reason}, new_state}
      end
    catch
      :exit, {:timeout, _} ->
        new_state = record_failure(state, :timeout)
        emit_proposal_timeout(proposal)
        {{:error, :timeout}, new_state}

      kind, reason ->
        Logger.error("[GuardianIntegration] Unexpected error: #{kind} #{inspect(reason)}")
        new_state = record_failure(state, :internal_error)
        {{:error, :internal_error}, new_state}
    end
  end

  defp record_success(%{circuit_state: :half_open} = state) do
    Logger.info("[GuardianIntegration] Circuit closing after successful call")
    emit_circuit_state_change(:closed)
    %{state | circuit_state: :closed, failure_count: 0}
  end

  defp record_success(state) do
    %{state | failure_count: max(0, state.failure_count - 1)}
  end

  defp record_failure(state, reason) do
    threshold = Config.get(:guardian_circuit_threshold)
    new_count = state.failure_count + 1
    now = System.monotonic_time(:millisecond)

    if new_count >= threshold do
      Logger.warning("[GuardianIntegration] Circuit OPEN after #{new_count} failures")
      emit_circuit_state_change(:open)
      schedule_circuit_reset()
      %{state | circuit_state: :open, failure_count: new_count, last_failure_time: now}
    else
      Logger.warning("[GuardianIntegration] Failure #{new_count}/#{threshold}: #{reason}")
      %{state | failure_count: new_count, last_failure_time: now}
    end
  end

  defp schedule_circuit_reset do
    reset_ms = Config.get(:guardian_circuit_reset_ms)
    Process.send_after(self(), :circuit_half_open, reset_ms)
  end

  # ============================================================================
  # Private: Health Check Logic
  # ============================================================================

  defp schedule_health_check do
    interval = Config.get(:guardian_health_interval_ms)
    Process.send_after(self(), :health_check, interval)
  end

  defp perform_health_check(state) do
    now = System.system_time(:millisecond)

    health_status =
      try do
        case Guardian.alive?(timeout: 2_000) do
          true -> :healthy
          false -> :unhealthy
        end
      catch
        _, _ -> :unreachable
      end

    if health_status != state.health_status do
      Logger.info("[GuardianIntegration] Health status: #{state.health_status} -> #{health_status}")
      emit_health_status_change(health_status)
    end

    %{state | health_status: health_status, last_health_check: now}
  end

  # ============================================================================
  # Private: Immutable Register Logging
  # ============================================================================

  defp log_to_immutable_register(proposal, decision, reason) do
    payload = %{
      change_type: :guardian_decision,
      module: "GuardianIntegration",
      key: Map.get(proposal, :action, :unknown) |> to_string(),
      old_value: nil,
      new_value: decision,
      metadata: %{
        proposal: proposal,
        reason: reason,
        timestamp: DateTime.utc_now()
      }
    }

    case ImmutableState.record(payload) do
      {:ok, block_hash} ->
        Logger.debug("[GuardianIntegration] Decision logged: #{block_hash}")

      {:error, reason} ->
        Logger.error("[GuardianIntegration] Failed to log decision: #{inspect(reason)}")
        # SC-SIL6-002: This is a critical failure - decision made but not logged
        emit_audit_failure(proposal, reason)
    end
  end

  # ============================================================================
  # Private: Telemetry
  # ============================================================================

  defp emit_proposal_approved(proposal) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :proposal_approved],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      %{action: Map.get(proposal, :action)}
    )
  end

  defp emit_proposal_vetoed(proposal, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :proposal_vetoed],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      %{action: Map.get(proposal, :action), reason: reason}
    )
  end

  defp emit_proposal_error(proposal, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :proposal_error],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      %{action: Map.get(proposal, :action), reason: reason}
    )
  end

  defp emit_proposal_timeout(proposal) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :proposal_timeout],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      %{action: Map.get(proposal, :action)}
    )
  end

  defp emit_timeout(proposal) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :client_timeout],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      %{action: Map.get(proposal, :action)}
    )
  end

  defp emit_circuit_state_change(new_state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :circuit_state],
      %{timestamp: System.system_time(:millisecond)},
      %{state: new_state}
    )
  end

  defp emit_circuit_rejected(proposal) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :circuit_rejected],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      %{action: Map.get(proposal, :action)}
    )
  end

  defp emit_circuit_reset(reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :circuit_reset],
      %{timestamp: System.system_time(:millisecond)},
      %{reason: reason}
    )
  end

  defp emit_health_status_change(status) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :health_status],
      %{timestamp: System.system_time(:millisecond)},
      %{status: status}
    )
  end

  defp emit_audit_failure(proposal, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :guardian, :audit_failure],
      %{count: 1, timestamp: System.system_time(:millisecond)},
      %{action: Map.get(proposal, :action), reason: reason}
    )
  end
end
```

### 3.3 Guardian Module Extension

```elixir
# In lib/indrajaal/safety/guardian.ex - Add these functions:

@doc """
Validates a proposal with configurable timeout.

## Options
  - :timeout - Maximum time to wait (default: 5000ms)
"""
@spec validate_proposal(map(), keyword()) ::
  {:ok, map()} | {:veto, String.t(), atom()} | {:error, term()}
def validate_proposal(proposal, opts \\ []) do
  timeout = Keyword.get(opts, :timeout, 5_000)
  GenServer.call(__MODULE__, {:validate_proposal, proposal}, timeout)
end

@doc """
Checks if Guardian process is alive and responsive.

## Options
  - :timeout - Maximum time to wait for response (default: 2000ms)
"""
@spec alive?(keyword()) :: boolean()
def alive?(opts \\ []) do
  timeout = Keyword.get(opts, :timeout, 2_000)

  try do
    GenServer.call(__MODULE__, :ping, timeout) == :pong
  catch
    :exit, _ -> false
  end
end

# Add to handle_call:
def handle_call(:ping, _from, state) do
  {:reply, :pong, state}
end
```

### 3.4 Telemetry Events

| Event | Measurements | Metadata |
|-------|--------------|----------|
| `[:indrajaal, :prajna, :guardian, :proposal_approved]` | count, timestamp | action |
| `[:indrajaal, :prajna, :guardian, :proposal_vetoed]` | count, timestamp | action, reason |
| `[:indrajaal, :prajna, :guardian, :proposal_error]` | count, timestamp | action, reason |
| `[:indrajaal, :prajna, :guardian, :proposal_timeout]` | count, timestamp | action |
| `[:indrajaal, :prajna, :guardian, :circuit_state]` | timestamp | state |
| `[:indrajaal, :prajna, :guardian, :circuit_rejected]` | count, timestamp | action |
| `[:indrajaal, :prajna, :guardian, :health_status]` | timestamp | status |
| `[:indrajaal, :prajna, :guardian, :audit_failure]` | count, timestamp | action, reason |

---

## 4. 31.2: ImmutableState Persistence

### 4.1 Purpose

Add DuckDB persistence to ImmutableState with automatic chain verification on startup.

### 4.2 DuckDB Schema

```sql
-- Table: prajna_immutable_blocks
CREATE TABLE IF NOT EXISTS prajna_immutable_blocks (
    block_index INTEGER PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    prev_hash VARCHAR(64) NOT NULL,
    content_hash VARCHAR(64) NOT NULL,
    block_hash VARCHAR(64) NOT NULL,
    signature VARCHAR(128) NOT NULL,
    content JSON NOT NULL,
    protocol_version VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for hash lookups
CREATE INDEX IF NOT EXISTS idx_block_hash ON prajna_immutable_blocks(block_hash);

-- Index for content type filtering
CREATE INDEX IF NOT EXISTS idx_content_type ON prajna_immutable_blocks(
    JSON_EXTRACT_STRING(content, '$.change_type')
);
```

### 4.3 Module Changes: ImmutableState

```elixir
defmodule Indrajaal.Cockpit.Prajna.ImmutableState do
  @moduledoc """
  Immutable Register for Prajna State Mutations (GenServer + DuckDB).

  WHAT: Cryptographically verifiable append-only log of all Prajna state changes.
  WHY: SC-REG-001 requires all mutations to be recorded in the register.

  CONSTRAINTS:
    - SC-REG-001: All state changes via append-only register
    - SC-REG-002: Hash chain MUST be unbroken
    - SC-REG-003: All blocks MUST be signed
    - SC-SIL6-002: Persist to DuckDB
    - SC-SIL6-003: Verify chain on startup
    - SC-HOLON-019: DuckDB history is immutable/append-only

  ## Sprint 31 Enhancements

  1. **DuckDB Persistence**: All blocks persisted immediately
  2. **Startup Verification**: Chain integrity verified before accepting writes
  3. **Recovery**: Load existing blocks from DuckDB on restart
  """

  use GenServer
  require Logger
  alias Indrajaal.Cockpit.Prajna.Config

  @genesis_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @protocol_version "21.1.0"

  defstruct [
    :blocks,
    :last_index,
    :last_hash,
    :created_at,
    :last_updated,
    :duckdb_conn,
    :verified
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the ImmutableState GenServer.
  Loads existing blocks from DuckDB and verifies chain integrity.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a single state mutation to the register.
  Persists to DuckDB before returning.

  Returns {:ok, block_hash} on success.
  """
  @spec record(map()) :: {:ok, String.t()} | {:error, term()}
  def record(payload) when is_map(payload) and not is_struct(payload) do
    timeout = Config.get(:orchestrator_command_timeout_ms)
    GenServer.call(__MODULE__, {:record, payload}, timeout)
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, {:noproc, _} -> {:error, :not_running}
  end

  @doc """
  Verifies the integrity of the hash chain.
  """
  @spec verify_chain() :: :valid | {:invalid, String.t()}
  def verify_chain do
    GenServer.call(__MODULE__, :verify_chain, 30_000)
  catch
    :exit, _ -> {:error, :not_running}
  end

  @doc """
  Returns true if the chain has been verified on startup.
  """
  @spec verified?() :: boolean()
  def verified? do
    GenServer.call(__MODULE__, :verified?, 5_000)
  catch
    :exit, _ -> false
  end

  @doc """
  Gets a block by index.
  """
  @spec get_block(integer()) :: map() | nil
  def get_block(index) do
    GenServer.call(__MODULE__, {:get_block, index}, 5_000)
  catch
    :exit, _ -> nil
  end

  @doc """
  Gets blocks filtered by change type.
  """
  @spec get_blocks_by_type(atom()) :: [map()]
  def get_blocks_by_type(change_type) do
    GenServer.call(__MODULE__, {:get_blocks_by_type, change_type}, 10_000)
  catch
    :exit, _ -> []
  end

  @doc """
  Computes the Merkle root of all blocks in the register.
  """
  @spec compute_merkle_root() :: String.t()
  def compute_merkle_root do
    GenServer.call(__MODULE__, :compute_merkle_root, 30_000)
  catch
    :exit, _ -> hash("empty_merkle_root")
  end

  @doc """
  Returns a summary of the register state.
  """
  @spec summary() :: String.t()
  def summary do
    GenServer.call(__MODULE__, :summary, 5_000)
  catch
    :exit, _ -> "ImmutableState: not running"
  end

  @doc """
  Returns the current block count.
  """
  @spec block_count() :: non_neg_integer()
  def block_count do
    GenServer.call(__MODULE__, :block_count, 5_000)
  catch
    :exit, _ -> 0
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    Logger.info("[ImmutableState] Initializing with DuckDB persistence (SC-SIL6-002)")

    duckdb_path = Config.get(:immutable_state_duckdb_path)
    verify_on_startup = Config.get(:immutable_state_verify_on_startup)

    with {:ok, conn} <- open_duckdb(duckdb_path),
         :ok <- ensure_schema(conn),
         {:ok, blocks} <- load_blocks(conn),
         {:ok, state} <- build_state(conn, blocks),
         {:ok, verified_state} <- maybe_verify_chain(state, verify_on_startup) do

      emit_initialized(verified_state)
      {:ok, verified_state}
    else
      {:error, reason} ->
        Logger.error("[ImmutableState] Initialization failed: #{inspect(reason)}")
        {:stop, {:init_failed, reason}}
    end
  end

  @impl GenServer
  def handle_call({:record, payload}, _from, %{verified: false} = state) do
    {:reply, {:error, :chain_not_verified}, state}
  end

  @impl GenServer
  def handle_call({:record, payload}, _from, state) do
    case do_record(payload, state) do
      {:ok, block, new_state} ->
        case persist_block(state.duckdb_conn, block) do
          :ok ->
            emit_block_created(block)
            {:reply, {:ok, block.block_hash}, new_state}

          {:error, reason} ->
            Logger.error("[ImmutableState] DuckDB persist failed: #{inspect(reason)}")
            emit_persist_failure(block, reason)
            # Rollback in-memory state
            {:reply, {:error, :persist_failed}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:verify_chain, _from, state) do
    result = verify_blocks(state.blocks, @genesis_hash)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:verified?, _from, state) do
    {:reply, state.verified, state}
  end

  @impl GenServer
  def handle_call({:get_block, index}, _from, state) do
    block = Enum.find(state.blocks, fn b -> b.index == index end)
    {:reply, block, state}
  end

  @impl GenServer
  def handle_call({:get_blocks_by_type, change_type}, _from, state) do
    blocks = Enum.filter(state.blocks, fn b ->
      b.content.change_type == change_type
    end)
    {:reply, blocks, state}
  end

  @impl GenServer
  def handle_call(:compute_merkle_root, _from, state) do
    root = compute_merkle_root_impl(state.blocks)
    {:reply, root, state}
  end

  @impl GenServer
  def handle_call(:summary, _from, state) do
    summary = """
    ImmutableState Register Summary:
    - #{length(state.blocks)} blocks
    - verified: #{state.verified}
    - last_hash: #{state.last_hash}
    - created: #{DateTime.to_iso8601(state.created_at)}
    - updated: #{DateTime.to_iso8601(state.last_updated)}
    """
    {:reply, summary, state}
  end

  @impl GenServer
  def handle_call(:block_count, _from, state) do
    {:reply, length(state.blocks), state}
  end

  # ============================================================================
  # Private: DuckDB Operations
  # ============================================================================

  defp open_duckdb(path) do
    # Ensure directory exists
    path |> Path.dirname() |> File.mkdir_p!()

    case Duckdbex.open(path) do
      {:ok, conn} ->
        Logger.info("[ImmutableState] DuckDB opened: #{path}")
        {:ok, conn}

      {:error, reason} ->
        Logger.error("[ImmutableState] DuckDB open failed: #{inspect(reason)}")
        {:error, {:duckdb_open_failed, reason}}
    end
  end

  defp ensure_schema(conn) do
    sql = """
    CREATE TABLE IF NOT EXISTS prajna_immutable_blocks (
      block_index INTEGER PRIMARY KEY,
      timestamp TIMESTAMP NOT NULL,
      prev_hash VARCHAR(64) NOT NULL,
      content_hash VARCHAR(64) NOT NULL,
      block_hash VARCHAR(64) NOT NULL,
      signature VARCHAR(128) NOT NULL,
      content JSON NOT NULL,
      protocol_version VARCHAR(20) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_block_hash
      ON prajna_immutable_blocks(block_hash);
    """

    case Duckdbex.query(conn, sql) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, {:schema_failed, reason}}
    end
  end

  defp load_blocks(conn) do
    sql = "SELECT * FROM prajna_immutable_blocks ORDER BY block_index ASC"

    case Duckdbex.query(conn, sql) do
      {:ok, result} ->
        blocks = Enum.map(result.rows, &row_to_block/1)
        Logger.info("[ImmutableState] Loaded #{length(blocks)} blocks from DuckDB")
        {:ok, blocks}

      {:error, reason} ->
        {:error, {:load_failed, reason}}
    end
  end

  defp row_to_block([index, timestamp, prev_hash, content_hash, block_hash,
                     signature, content_json, protocol_version, _created_at]) do
    %{
      index: index,
      timestamp: timestamp,
      prev_hash: prev_hash,
      content_hash: content_hash,
      block_hash: block_hash,
      signature: signature,
      content: Jason.decode!(content_json, keys: :atoms),
      protocol_version: protocol_version
    }
  end

  defp build_state(conn, []) do
    now = DateTime.utc_now()
    state = %__MODULE__{
      blocks: [],
      last_index: -1,
      last_hash: @genesis_hash,
      created_at: now,
      last_updated: now,
      duckdb_conn: conn,
      verified: true  # Empty chain is valid
    }
    {:ok, state}
  end

  defp build_state(conn, blocks) do
    last_block = List.last(blocks)
    now = DateTime.utc_now()

    state = %__MODULE__{
      blocks: blocks,
      last_index: last_block.index,
      last_hash: last_block.block_hash,
      created_at: hd(blocks).timestamp,
      last_updated: now,
      duckdb_conn: conn,
      verified: false  # Must verify before accepting writes
    }
    {:ok, state}
  end

  defp maybe_verify_chain(state, false) do
    Logger.warning("[ImmutableState] Skipping chain verification (SC-SIL6-003 VIOLATION)")
    {:ok, %{state | verified: true}}
  end

  defp maybe_verify_chain(%{blocks: []} = state, true) do
    Logger.info("[ImmutableState] Empty chain - verified")
    {:ok, %{state | verified: true}}
  end

  defp maybe_verify_chain(state, true) do
    Logger.info("[ImmutableState] Verifying chain integrity (SC-SIL6-003)...")

    case verify_blocks(state.blocks, @genesis_hash) do
      :valid ->
        Logger.info("[ImmutableState] Chain verified: #{length(state.blocks)} blocks valid")
        emit_chain_verified(state)
        {:ok, %{state | verified: true}}

      {:invalid, reason} ->
        Logger.error("[ImmutableState] Chain verification FAILED: #{reason}")
        emit_chain_verification_failed(reason)
        {:error, {:chain_invalid, reason}}
    end
  end

  defp persist_block(conn, block) do
    sql = """
    INSERT INTO prajna_immutable_blocks
      (block_index, timestamp, prev_hash, content_hash, block_hash,
       signature, content, protocol_version)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """

    params = [
      block.index,
      block.timestamp,
      block.prev_hash,
      block.content_hash,
      block.block_hash,
      block.signature,
      Jason.encode!(block.content),
      block.protocol_version
    ]

    case Duckdbex.query(conn, sql, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # Private: Block Creation
  # ============================================================================

  defp do_record(change, state) do
    new_index = state.last_index + 1
    now = DateTime.utc_now()

    with {:ok, content_json} <- safe_encode(change) do
      content_hash = hash(content_json)
      block_data = "#{state.last_hash}|#{content_hash}|#{new_index}|#{DateTime.to_iso8601(now)}"
      block_hash = hash(block_data)
      signature = sign(block_hash)

      block = %{
        index: new_index,
        timestamp: now,
        prev_hash: state.last_hash,
        content_hash: content_hash,
        block_hash: block_hash,
        signature: signature,
        content: change,
        protocol_version: @protocol_version
      }

      new_state = %{
        state
        | blocks: state.blocks ++ [block],
          last_index: new_index,
          last_hash: block_hash,
          last_updated: now
      }

      {:ok, block, new_state}
    end
  end

  defp safe_encode(change) do
    {:ok, Jason.encode!(change)}
  rescue
    e in Jason.EncodeError ->
      Logger.error("[ImmutableState] JSON encode failed: #{inspect(e)}")
      {:error, :encode_failed}
  end

  # ============================================================================
  # Private: Chain Verification
  # ============================================================================

  defp verify_blocks([], _expected_prev), do: :valid

  defp verify_blocks([block | rest], expected_prev) do
    with :ok <- verify_prev_hash(block, expected_prev),
         :ok <- verify_content_hash(block),
         :ok <- verify_block_hash(block),
         :ok <- verify_signature(block) do
      verify_blocks(rest, block.block_hash)
    end
  end

  defp verify_prev_hash(block, expected) do
    if block.prev_hash == expected do
      :ok
    else
      emit_hash_mismatch(block, expected)
      {:invalid, "Chain broken at block #{block.index}: prev_hash mismatch"}
    end
  end

  defp verify_content_hash(block) do
    computed = hash(Jason.encode!(block.content))
    if block.content_hash == computed do
      :ok
    else
      {:invalid, "Block #{block.index}: content_hash mismatch"}
    end
  end

  defp verify_block_hash(block) do
    block_data = "#{block.prev_hash}|#{block.content_hash}|#{block.index}|#{DateTime.to_iso8601(block.timestamp)}"
    computed = hash(block_data)
    if block.block_hash == computed do
      :ok
    else
      {:invalid, "Block #{block.index}: block_hash mismatch"}
    end
  end

  defp verify_signature(block) do
    expected = sign(block.block_hash)
    if block.signature == expected do
      :ok
    else
      emit_signature_invalid(block)
      {:invalid, "Block #{block.index}: signature invalid"}
    end
  end

  # ============================================================================
  # Private: Merkle Root
  # ============================================================================

  defp compute_merkle_root_impl([]), do: hash("empty_merkle_root")
  defp compute_merkle_root_impl(blocks) do
    hashes = Enum.map(blocks, & &1.content_hash)
    compute_merkle_recursive(hashes)
  end

  defp compute_merkle_recursive([single]), do: single
  defp compute_merkle_recursive(hashes) do
    hashes
    |> Enum.chunk_every(2)
    |> Enum.map(fn
      [a, b] -> hash(a <> b)
      [a] -> hash(a <> a)
    end)
    |> compute_merkle_recursive()
  end

  # ============================================================================
  # Private: Crypto
  # ============================================================================

  defp hash(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  # TODO: Replace with Ed25519 for SC-SIL6-004
  @signing_key "prajna_immutable_state_hmac_key_v21"
  defp sign(data) do
    :crypto.mac(:hmac, :sha512, @signing_key, data) |> Base.encode16(case: :lower)
  end

  # ============================================================================
  # Private: Telemetry
  # ============================================================================

  defp emit_initialized(state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :initialized],
      %{block_count: length(state.blocks), timestamp: System.system_time(:millisecond)},
      %{verified: state.verified}
    )
  end

  defp emit_block_created(block) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :block_created],
      %{block_height: block.index, timestamp: System.system_time(:millisecond)},
      %{content_type: Map.get(block.content, :change_type, :unknown)}
    )
  end

  defp emit_chain_verified(state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :chain_verified],
      %{block_count: length(state.blocks), timestamp: System.system_time(:millisecond)},
      %{}
    )
  end

  defp emit_chain_verification_failed(reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :verification_failed],
      %{timestamp: System.system_time(:millisecond)},
      %{reason: reason}
    )
  end

  defp emit_persist_failure(block, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :persist_failed],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{reason: reason}
    )
  end

  defp emit_hash_mismatch(block, expected) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :hash_mismatch],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{expected: expected, actual: block.prev_hash}
    )
  end

  defp emit_signature_invalid(block) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :signature_invalid],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{}
    )
  end
end
```

### 4.4 Telemetry Events

| Event | Measurements | Metadata |
|-------|--------------|----------|
| `[:indrajaal, :prajna, :immutable_state, :initialized]` | block_count, timestamp | verified |
| `[:indrajaal, :prajna, :immutable_state, :block_created]` | block_height, timestamp | content_type |
| `[:indrajaal, :prajna, :immutable_state, :chain_verified]` | block_count, timestamp | - |
| `[:indrajaal, :prajna, :immutable_state, :verification_failed]` | timestamp | reason |
| `[:indrajaal, :prajna, :immutable_state, :persist_failed]` | block_index, timestamp | reason |
| `[:indrajaal, :prajna, :immutable_state, :hash_mismatch]` | block_index, timestamp | expected, actual |
| `[:indrajaal, :prajna, :immutable_state, :signature_invalid]` | block_index, timestamp | - |

---

## 5. Dependencies & Execution Order

### 5.1 Implementation Order

```
1. Prajna.Config (foundational)
   ↓
2. Guardian.alive?/1 (prerequisite for health check)
   ↓
3. GuardianIntegration (timeout + circuit breaker + health check)
   ↓
4. ImmutableState (DuckDB + verification)
   ↓
5. Integration Tests
```

### 5.2 Supervisor Child Order Update

```elixir
# In lib/indrajaal/cockpit/prajna/supervisor.ex

def init(opts) do
  children = [
    # 1. Config must start first (validates all settings)
    {Indrajaal.Cockpit.Prajna.Config, opts},

    # 2. Persistence layer
    {Indrajaal.Cockpit.Prajna.ImmutableState, opts},

    # 3. Safety gate (depends on ImmutableState for logging)
    {Indrajaal.Cockpit.Prajna.GuardianIntegration, opts},

    # 4. Metrics collection
    {Indrajaal.Cockpit.Prajna.SmartMetrics, opts},

    # 5. Health bridge (depends on SmartMetrics)
    {Indrajaal.Cockpit.Prajna.SentinelBridge, opts},

    # ... rest unchanged
  ]

  Supervisor.init(children, strategy: :one_for_one)
end
```

---

## 6. Test Strategy

### 6.1 Unit Tests

```elixir
# test/indrajaal/cockpit/prajna/config_test.exs
describe "Config.get/1" do
  test "returns default for unconfigured key"
  test "returns configured value when set"
  test "raises on unknown key"
end

describe "Config.validate_all!/0" do
  test "passes with valid configuration"
  test "raises with invalid type"
  test "raises with value below minimum"
  test "raises with value above maximum"
end

describe "Config.backoff_delay/1" do
  test "returns base delay for attempt 1"
  test "doubles delay per attempt"
  test "caps at max delay"
end
```

```elixir
# test/indrajaal/cockpit/prajna/guardian_integration_test.exs
describe "submit_proposal/1" do
  test "returns {:ok, :approved} for valid proposal"
  test "returns {:veto, reason, fallback} for rejected proposal"
  test "returns {:error, :timeout} when Guardian hangs"
  test "returns {:error, :circuit_open} when circuit is open"
end

describe "circuit breaker" do
  test "opens after threshold consecutive failures"
  test "transitions to half-open after reset timeout"
  test "closes after successful call in half-open state"
end

describe "health check" do
  test "detects Guardian availability"
  test "emits telemetry on status change"
end
```

```elixir
# test/indrajaal/cockpit/prajna/immutable_state_persistence_test.exs
describe "DuckDB persistence" do
  test "persists block on record/1"
  test "loads blocks on startup"
  test "verifies chain on startup"
  test "rejects writes when chain verification fails"
end

describe "chain verification" do
  test "validates empty chain"
  test "validates single block"
  test "validates multi-block chain"
  test "detects prev_hash mismatch"
  test "detects content_hash mismatch"
  test "detects signature mismatch"
end
```

### 6.2 Property Tests

```elixir
# PropCheck properties
property "Config values within bounds" do
  forall key <- oneof(Map.keys(Config.schema())) do
    value = Config.get(key)
    schema = Config.schema()[key]

    value >= Map.get(schema, :min, value) and
    value <= Map.get(schema, :max, value)
  end
end

property "Block append preserves chain integrity" do
  forall changes <- list(change_generator()) do
    register = ImmutableState.create_register()

    final = Enum.reduce(changes, register, fn change, acc ->
      ImmutableState.record(change, acc)
    end)

    ImmutableState.verify_chain(final) == :valid
  end
end

property "Circuit breaker state machine" do
  forall events <- list(oneof([:success, :failure])) do
    # Verify state transitions match expected FSM
  end
end
```

---

## 7. Rollback Plan

### 7.1 Feature Flags

```elixir
# In config/config.exs
config :indrajaal, :feature_flags,
  guardian_circuit_breaker: true,
  immutable_state_duckdb: true,
  config_validation: true
```

### 7.2 Rollback Procedure

1. **Disable feature flags** in config
2. **Deploy previous version** of modules
3. **Verify Guardian** responds without timeout wrapper
4. **Verify ImmutableState** uses in-memory mode
5. **Monitor** for stability

### 7.3 Data Migration

- DuckDB blocks are append-only; no data loss on rollback
- In-memory state starts fresh but DuckDB history preserved
- Re-enable DuckDB persistence resumes from last block

---

## Appendix A: Configuration Reference

| Key | Type | Default | Min | Max | Description |
|-----|------|---------|-----|-----|-------------|
| guardian_timeout_ms | integer | 5000 | 1000 | 30000 | Guardian proposal timeout |
| guardian_circuit_threshold | integer | 3 | 1 | 10 | Failures before circuit opens |
| guardian_circuit_reset_ms | integer | 30000 | 5000 | 300000 | Circuit reset timeout |
| guardian_health_interval_ms | integer | 5000 | 1000 | 60000 | Health check interval |
| sentinel_sync_interval_ms | integer | 30000 | 5000 | 300000 | Sentinel sync interval |
| immutable_state_verify_on_startup | boolean | true | - | - | Verify chain on startup |
| immutable_state_duckdb_path | string | data/holons/... | - | - | DuckDB file path |
| max_retry_attempts | integer | 3 | 1 | 10 | Max retry attempts |
| backoff_base_ms | integer | 1000 | 100 | 10000 | Backoff base delay |
| backoff_max_ms | integer | 60000 | 10000 | 300000 | Max backoff delay |

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Status | DRAFT |
| Created | 2026-01-02 |
| Author | Cybernetic Architect |
| STAMP | SC-SIL6-*, SC-CONFIG-*, SC-REG-*, SC-RECOVER-* |
| Review Required | Yes |
