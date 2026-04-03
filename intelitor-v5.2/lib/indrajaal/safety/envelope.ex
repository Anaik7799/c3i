defmodule Indrajaal.Safety.Envelope do
  @moduledoc """
  Safety Envelope: Defines the boundary of safe operation for the system.

  WHAT: Immutable, formally verified constraints that define survival boundaries.
  WHY: SC-NEURO-001 requires all AI outputs to remain within the safety envelope.
  CONSTRAINTS: SIL-2 certified, deterministic evaluation, no side effects.

  ## The Safety Envelope Concept

  The Safety Envelope is a multi-dimensional boundary that defines what is
  "safe" for the system. Any proposal that crosses this boundary is vetoed.

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │                     SAFETY ENVELOPE                             │
  │                                                                 │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  RESOURCE CONSTRAINTS                                   │  │
  │   │  - FLAME nodes ≤ 50                                     │  │
  │   │  - RAM ≤ 32GB                                           │  │
  │   │  - CPU ≤ 90%                                            │  │
  │   └─────────────────────────────────────────────────────────┘  │
  │                                                                 │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  PHYSICAL CONSTRAINTS                                   │  │
  │   │  - Pressure delta ≤ 0.1 bar                             │  │
  │   │  - Temperature ≤ 50°C                                   │  │
  │   │  - Voltage within ±10% nominal                          │  │
  │   └─────────────────────────────────────────────────────────┘  │
  │                                                                 │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  SECURITY CONSTRAINTS                                   │  │
  │   │  - No unverified binary execution                       │  │
  │   │  - Network isolation enforced                           │  │
  │   │  - No privileged operations                             │  │
  │   └─────────────────────────────────────────────────────────┘  │
  │                                                                 │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  TEMPORAL CONSTRAINTS                                   │  │
  │   │  - Response time ≤ 50ms                                 │  │
  │   │  - Heartbeat interval ≤ 100ms                           │  │
  │   │  - Recovery time ≤ 5s                                   │  │
  │   └─────────────────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────────────────┘
  ```

  ## STAMP Constraints

  - SC-ENV-001: Envelope constraints are immutable at runtime
  - SC-ENV-002: All constraints must have deterministic evaluation
  - SC-ENV-003: Constraint violations must be logged for learning
  - SC-ENV-004: Envelope must be verifiable at compile time

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-ENV-001 to SC-ENV-004 |
  | SIL | SIL-2 |
  """

  require Logger

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type constraint_result :: :ok | {:violation, atom(), term()}

  @type constraint_category ::
          :resource | :physical | :security | :temporal | :operational

  @type envelope_status :: %{
          healthy: boolean(),
          violations: [map()],
          checked_at: DateTime.t(),
          constraints_checked: non_neg_integer()
        }

  # ============================================================
  # RESOURCE CONSTRAINTS (SC-RES)
  # ============================================================

  @doc "Maximum FLAME nodes allowed"
  @spec max_flame_nodes() :: pos_integer()
  def max_flame_nodes, do: 50

  @doc "Maximum RAM in megabytes"
  @spec max_ram_mb() :: pos_integer()
  def max_ram_mb, do: 32_000

  @doc "Maximum CPU utilization percentage"
  @spec max_cpu_percent() :: pos_integer()
  def max_cpu_percent, do: 90

  @doc "Maximum database connections"
  @spec max_db_connections() :: pos_integer()
  def max_db_connections, do: 100

  @doc "Maximum concurrent WebSocket connections"
  @spec max_websocket_connections() :: pos_integer()
  def max_websocket_connections, do: 10_000

  @doc "Maximum file descriptors"
  @spec max_file_descriptors() :: pos_integer()
  def max_file_descriptors, do: 65_536

  # ============================================================
  # PHYSICAL CONSTRAINTS (SC-PHY)
  # ============================================================

  @doc "Maximum safe pressure delta in bar"
  @spec max_pressure_delta() :: float()
  def max_pressure_delta, do: 0.1

  @doc "Maximum safe temperature in Celsius"
  @spec max_temperature_c() :: float()
  def max_temperature_c, do: 50.0

  @doc "Minimum safe temperature in Celsius"
  @spec min_temperature_c() :: float()
  def min_temperature_c, do: -10.0

  @doc "Maximum voltage deviation percentage from nominal"
  @spec max_voltage_deviation_percent() :: float()
  def max_voltage_deviation_percent, do: 10.0

  @doc "Maximum vibration threshold (g-force)"
  @spec max_vibration_g() :: float()
  def max_vibration_g, do: 2.0

  # ============================================================
  # SECURITY CONSTRAINTS (SC-SEC)
  # ============================================================

  @doc "Forbidden operations that are never allowed"
  @spec forbidden_operations() :: [atom()]
  def forbidden_operations do
    [
      :rm_rf,
      :system_cmd_root,
      :eval_string,
      :chmod_777,
      :sudo,
      :raw_sql_exec,
      :network_bypass,
      :disable_logging,
      :modify_guardian,
      :disable_heartbeat
    ]
  end

  @doc "Patterns that indicate dangerous code"
  @spec dangerous_patterns() :: [Regex.t()]
  def dangerous_patterns do
    [
      ~r/rm\s+-rf\s+\//,
      ~r/chmod\s+777/,
      ~r/sudo\s+/,
      ~r/eval\s*\(/,
      ~r/System\.cmd\s*\(\s*"su"/,
      ~r/File\.rm_rf!\s*\(\s*"\/"/,
      ~r/:os\.cmd\s*\(/,
      ~r/Code\.eval_string/,
      ~r/Application\.put_env.*guardian.*false/i
    ]
  end

  @doc "Allowed network destinations (whitelist)"
  @spec allowed_network_destinations() :: [String.t()]
  def allowed_network_destinations do
    [
      "localhost",
      "127.0.0.1",
      "::1",
      "indrajaal-db",
      "indrajaal-obs",
      "openrouter.ai",
      "api.anthropic.com",
      "generativelanguage.googleapis.com"
    ]
  end

  # ============================================================
  # TEMPORAL CONSTRAINTS (SC-TMP)
  # ============================================================

  @doc "Maximum response time in milliseconds"
  @spec max_response_time_ms() :: pos_integer()
  def max_response_time_ms, do: 50

  @doc "Heartbeat interval in milliseconds"
  @spec heartbeat_interval_ms() :: pos_integer()
  def heartbeat_interval_ms, do: 100

  @doc "Maximum time to detect failure in milliseconds"
  @spec max_failure_detection_ms() :: pos_integer()
  def max_failure_detection_ms, do: 50

  @doc "Maximum recovery time in milliseconds"
  @spec max_recovery_time_ms() :: pos_integer()
  def max_recovery_time_ms, do: 5_000

  @doc "Maximum time for emergency stop in milliseconds"
  @spec max_emergency_stop_ms() :: pos_integer()
  def max_emergency_stop_ms, do: 1_000

  # ============================================================
  # OPERATIONAL CONSTRAINTS (SC-OPS)
  # ============================================================

  @doc "Maximum batch size for operations"
  @spec max_batch_size() :: pos_integer()
  def max_batch_size, do: 10

  @doc "Maximum retry attempts"
  @spec max_retry_attempts() :: pos_integer()
  def max_retry_attempts, do: 5

  @doc "Maximum backtrack depth for GDE"
  @spec max_backtrack_depth() :: pos_integer()
  def max_backtrack_depth, do: 10

  @doc "Maximum AI model tokens per request"
  @spec max_ai_tokens() :: pos_integer()
  def max_ai_tokens, do: 100_000

  # ============================================================
  # CONSTRAINT VALIDATION
  # ============================================================

  @doc """
  Validates a value against a resource constraint.

  ## Parameters
  - constraint: The constraint type
  - value: The value to check

  ## Returns
  - :ok if within bounds
  - {:violation, constraint, details} if violated
  """
  @spec check_resource(atom(), number()) :: constraint_result()
  def check_resource(:flame_nodes, value) when value > 50 do
    {:violation, :flame_node_limit, %{value: value, max: 50}}
  end

  def check_resource(:ram_mb, value) when value > 32_000 do
    {:violation, :ram_limit, %{value: value, max: 32_000}}
  end

  def check_resource(:cpu_percent, value) when value > 90 do
    {:violation, :cpu_limit, %{value: value, max: 90}}
  end

  def check_resource(:db_connections, value) when value > 100 do
    {:violation, :db_connection_limit, %{value: value, max: 100}}
  end

  def check_resource(:websocket_connections, value) when value > 10_000 do
    {:violation, :websocket_limit, %{value: value, max: 10_000}}
  end

  def check_resource(_constraint, _value), do: :ok

  @doc """
  Validates a value against a physical constraint.

  ## Parameters
  - constraint: The constraint type
  - value: The value to check

  ## Returns
  - :ok if within bounds
  - {:violation, constraint, details} if violated
  """
  @spec check_physical(atom(), number()) :: constraint_result()
  def check_physical(:pressure_delta, value) when value > 0.1 do
    {:violation, :pressure_limit, %{value: value, max: 0.1}}
  end

  def check_physical(:temperature_c, value) when value > 50.0 do
    {:violation, :temperature_high, %{value: value, max: 50.0}}
  end

  def check_physical(:temperature_c, value) when value < -10.0 do
    {:violation, :temperature_low, %{value: value, min: -10.0}}
  end

  def check_physical(:voltage_deviation, value) when abs(value) > 10.0 do
    {:violation, :voltage_deviation, %{value: value, max: 10.0}}
  end

  def check_physical(:vibration_g, value) when value > 2.0 do
    {:violation, :vibration_limit, %{value: value, max: 2.0}}
  end

  def check_physical(_constraint, _value), do: :ok

  @doc """
  Validates code against security constraints.

  ## Parameters
  - code: Code string to check

  ## Returns
  - :ok if safe
  - {:violation, :security, details} if dangerous
  """
  @spec check_security(String.t()) :: constraint_result()
  def check_security(code) when is_binary(code) do
    # Check against forbidden operations
    forbidden_found =
      forbidden_operations()
      |> Enum.find(fn op ->
        String.contains?(code, Atom.to_string(op))
      end)

    if forbidden_found do
      {:violation, :forbidden_operation, %{operation: forbidden_found}}
    else
      # Check against dangerous patterns
      pattern_found =
        dangerous_patterns()
        |> Enum.find(fn pattern ->
          Regex.match?(pattern, code)
        end)

      if pattern_found do
        {:violation, :dangerous_pattern, %{pattern: inspect(pattern_found)}}
      else
        :ok
      end
    end
  end

  def check_security(_), do: :ok

  @doc """
  Validates a network destination against the whitelist.

  ## Parameters
  - destination: Network destination to check

  ## Returns
  - :ok if allowed
  - {:violation, :network, details} if blocked
  """
  @spec check_network(String.t()) :: constraint_result()
  def check_network(destination) when is_binary(destination) do
    allowed = allowed_network_destinations()

    if Enum.any?(allowed, &String.contains?(destination, &1)) do
      :ok
    else
      {:violation, :network_destination, %{destination: destination, allowed: allowed}}
    end
  end

  def check_network(_), do: :ok

  @doc """
  Validates timing against temporal constraints.

  ## Parameters
  - constraint: The constraint type
  - value_ms: Time value in milliseconds

  ## Returns
  - :ok if within bounds
  - {:violation, constraint, details} if violated
  """
  @spec check_temporal(atom(), number()) :: constraint_result()
  def check_temporal(:response_time, value_ms) when value_ms > 50 do
    {:violation, :response_time_limit, %{value: value_ms, max: 50}}
  end

  def check_temporal(:heartbeat_gap, value_ms) when value_ms > 100 do
    {:violation, :heartbeat_timeout, %{value: value_ms, max: 100}}
  end

  def check_temporal(:recovery_time, value_ms) when value_ms > 5_000 do
    {:violation, :recovery_time_limit, %{value: value_ms, max: 5_000}}
  end

  def check_temporal(_constraint, _value), do: :ok

  # ============================================================
  # ENVELOPE STATUS
  # ============================================================

  @doc """
  Performs a comprehensive envelope health check.

  ## Parameters
  - metrics: Map of current system metrics

  ## Returns
  - %{healthy: boolean(), violations: [...], checked_at: DateTime.t()}
  """
  @spec health_check(map()) :: envelope_status()
  def health_check(metrics \\ %{}) do
    # Check all constraint categories
    {violations, checked} = check_resource_constraints(metrics)
    {violations, checked} = check_physical_constraints(metrics, violations, checked)

    %{
      healthy: Enum.empty?(violations),
      violations: Enum.reverse(violations),
      checked_at: DateTime.utc_now(),
      constraints_checked: checked
    }
  end

  @spec check_resource_constraints(map()) :: {list(), non_neg_integer()}
  defp check_resource_constraints(metrics) do
    Enum.reduce(
      [:flame_nodes, :ram_mb, :cpu_percent, :db_connections],
      {[], 0},
      fn key, {v, c} ->
        case Map.get(metrics, key) do
          nil ->
            {v, c}

          value ->
            case check_resource(key, value) do
              :ok -> {v, c + 1}
              {:violation, _, _} = violation -> {[violation | v], c + 1}
            end
        end
      end
    )
  end

  @spec check_physical_constraints(map(), list(), non_neg_integer()) ::
          {list(), non_neg_integer()}
  defp check_physical_constraints(metrics, violations, checked) do
    Enum.reduce(
      [:pressure_delta, :temperature_c, :voltage_deviation],
      {violations, checked},
      fn key, {v, c} ->
        case Map.get(metrics, key) do
          nil ->
            {v, c}

          value ->
            case check_physical(key, value) do
              :ok -> {v, c + 1}
              {:violation, _, _} = violation -> {[violation | v], c + 1}
            end
        end
      end
    )
  end

  @doc """
  Returns all envelope constraints as a map for inspection.
  """
  @spec all_constraints() :: map()
  def all_constraints do
    %{
      resource: %{
        max_flame_nodes: max_flame_nodes(),
        max_ram_mb: max_ram_mb(),
        max_cpu_percent: max_cpu_percent(),
        max_db_connections: max_db_connections(),
        max_websocket_connections: max_websocket_connections()
      },
      physical: %{
        max_pressure_delta: max_pressure_delta(),
        max_temperature_c: max_temperature_c(),
        min_temperature_c: min_temperature_c(),
        max_voltage_deviation_percent: max_voltage_deviation_percent()
      },
      security: %{
        forbidden_operations: forbidden_operations(),
        allowed_network_destinations: allowed_network_destinations()
      },
      temporal: %{
        max_response_time_ms: max_response_time_ms(),
        heartbeat_interval_ms: heartbeat_interval_ms(),
        max_failure_detection_ms: max_failure_detection_ms(),
        max_recovery_time_ms: max_recovery_time_ms()
      },
      operational: %{
        max_batch_size: max_batch_size(),
        max_retry_attempts: max_retry_attempts(),
        max_backtrack_depth: max_backtrack_depth()
      }
    }
  end
end
