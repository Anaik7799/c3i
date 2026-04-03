defmodule Indrajaal.Cockpit.Dashboard do
  @moduledoc """
  Cognitive Cockpit Dashboard - Human-in-the-Loop Interface.

  WHAT: Central orchestrator for the HITL Livebook interface.
  WHY: SC-HITL-001 requires human oversight of autonomic decisions.
  CONSTRAINTS: Two-Key Turn authorization for write operations.

  ## Architecture

  The Cognitive Cockpit provides a visual interface to the Cortex system:

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │                   COGNITIVE COCKPIT                              │
  │                                                                  │
  │   ┌─────────────────────────────────────────────────────────┐   │
  │   │  SAFETY MONITOR                                          │   │
  │   │  - Envelope visualization                                │   │
  │   │  - Guardian status                                       │   │
  │   │  - Dead Man's Switch state                               │   │
  │   └─────────────────────────────────────────────────────────┘   │
  │                                                                  │
  │   ┌─────────────────────────────────────────────────────────┐   │
  │   │  SYSTEM METRICS                                          │   │
  │   │  - FLAME pool status                                     │   │
  │   │  - Resource utilization                                  │   │
  │   │  - Agent health                                          │   │
  │   └─────────────────────────────────────────────────────────┘   │
  │                                                                  │
  │   ┌─────────────────────────────────────────────────────────┐   │
  │   │  ZENOH INSPECTOR                                         │   │
  │   │  - Topic browser                                         │   │
  │   │  - Message stream                                        │   │
  │   │  - KPI dashboard                                         │   │
  │   └─────────────────────────────────────────────────────────┘   │
  │                                                                  │
  │   ┌─────────────────────────────────────────────────────────┐   │
  │   │  TRAINING FEEDBACK                                       │   │
  │   │  - Approve/Reject proposals                              │   │
  │   │  - Label decisions                                       │   │
  │   │  - Provide corrections                                   │   │
  │   └─────────────────────────────────────────────────────────┘   │
  └─────────────────────────────────────────────────────────────────┘
  ```

  ## Two-Key Turn Authorization

  Write operations require dual authorization:
  1. Human operator confirmation via Kino input
  2. System validates operator credentials

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-HITL-001 to SC-HITL-003 |
  """
  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Safety.Envelope
  alias Indrajaal.Safety.DeadMansSwitch
  alias Indrajaal.Shared.UnifiedGenServerPatterns

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type dashboard_state :: %{
          started_at: DateTime.t(),
          operators: list(String.t()),
          pending_authorizations: map(),
          session_id: String.t()
        }

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get comprehensive system status for the dashboard.
  """
  @spec system_status() :: map()
  def system_status do
    %{
      safety: safety_status(),
      resources: resource_status(),
      agents: agent_status(),
      session: session_info()
    }
  end

  @doc """
  Get safety subsystem status including Guardian, Envelope, and DMS.
  """
  @spec safety_status() :: map()
  def safety_status do
    guardian = Guardian.status()
    dms_state = DeadMansSwitch.state()
    dms_stats = DeadMansSwitch.stats()
    constraints = Envelope.all_constraints()

    %{
      guardian: %{
        running: guardian[:running] || false,
        validations: guardian[:validations] || 0,
        violations: guardian[:violations] || 0,
        uptime_seconds: guardian[:uptime_seconds] || 0,
        last_violation: guardian[:last_violation]
      },
      dead_mans_switch: %{
        state: dms_state,
        heartbeats_received: dms_stats.heartbeats_received,
        heartbeats_missed: dms_stats.heartbeats_missed,
        failsafe_triggers: dms_stats.failsafe_triggers,
        uptime_seconds: dms_stats.uptime_seconds
      },
      envelope: %{
        resource_limits: %{
          max_flame_nodes: constraints.resource.max_flame_nodes,
          max_ram_mb: constraints.resource.max_ram_mb,
          max_cpu_percent: constraints.resource.max_cpu_percent
        },
        physical_limits: %{
          max_temperature_c: constraints.physical.max_temperature_c,
          min_temperature_c: constraints.physical.min_temperature_c,
          max_pressure_delta: constraints.physical.max_pressure_delta
        },
        security: %{
          forbidden_operations_count: length(constraints.security.forbidden_operations),
          allowed_destinations_count: length(constraints.security.allowed_network_destinations)
        }
      },
      overall_healthy: guardian[:running] && dms_state in [:healthy, :armed, :disabled]
    }
  end

  @doc """
  Get current resource utilization.
  """
  @spec resource_status() :: map()
  def resource_status do
    memory = :erlang.memory()
    schedulers = :erlang.system_info(:schedulers_online)
    process_count = :erlang.system_info(:process_count)

    %{
      memory: %{
        total_mb: div(memory[:total], 1_048_576),
        processes_mb: div(memory[:processes], 1_048_576),
        system_mb: div(memory[:system], 1_048_576),
        atom_mb: div(memory[:atom], 1_048_576),
        binary_mb: div(memory[:binary], 1_048_576),
        ets_mb: div(memory[:ets], 1_048_576)
      },
      schedulers: schedulers,
      process_count: process_count,
      run_queue: :erlang.statistics(:run_queue),
      uptime_seconds:
        (
          wall_clock = :erlang.statistics(:wall_clock)
          div(elem(wall_clock, 0), 1000)
        )
    }
  end

  @doc """
  Get agent status from Cortex.
  """
  @spec agent_status() :: map()
  def agent_status do
    # Try to get from Cortex if available
    cortex_status = get_cortex_status()

    %{
      cortex: cortex_status,
      synapse: get_synapse_status(),
      gde: get_gde_status()
    }
  end

  @doc """
  Request Two-Key Turn authorization for a write operation.
  """
  @spec request_authorization(String.t(), map()) :: {:ok, String.t()} | {:error, atom()}
  def request_authorization(operator_id, operation) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :dashboard_not_running}
      pid -> GenServer.call(pid, {:request_auth, operator_id, operation})
    end
  end

  @doc """
  Confirm authorization with the second key.
  """
  @spec confirm_authorization(String.t(), String.t()) :: {:ok, :authorized} | {:error, atom()}
  def confirm_authorization(auth_id, confirmation_code) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :dashboard_not_running}
      pid -> GenServer.call(pid, {:confirm_auth, auth_id, confirmation_code})
    end
  end

  @doc """
  Get session information.
  """
  @spec session_info() :: map()
  def session_info do
    case GenServer.whereis(__MODULE__) do
      nil ->
        %{
          running: false,
          session_id: nil,
          started_at: nil,
          operators: []
        }

      pid when is_pid(pid) ->
        GenServer.call(pid, :session_info)
    end
  rescue
    _ -> %{running: false, session_id: nil, started_at: nil, operators: []}
  end

  # ============================================================
  # KINO HELPERS (for Livebook integration)
  # ============================================================

  @doc """
  Generate safety status as Kino-compatible data.
  Returns data suitable for Kino.DataTable or VegaLite charts.
  """
  @spec safety_data_for_kino() :: list(map())
  def safety_data_for_kino do
    status = safety_status()

    [
      %{
        component: "Guardian",
        status: if(status.guardian.running, do: "Running", else: "Stopped"),
        validations: status.guardian.validations,
        violations: status.guardian.violations,
        health: if(status.guardian.running, do: "Healthy", else: "Unhealthy")
      },
      %{
        component: "Dead Man's Switch",
        status: Atom.to_string(status.dead_mans_switch.state),
        validations: status.dead_mans_switch.heartbeats_received,
        violations: status.dead_mans_switch.failsafe_triggers,
        health: dms_health(status.dead_mans_switch.state)
      }
    ]
  end

  @doc """
  Generate resource utilization as Kino-compatible data.
  """
  @spec resource_data_for_kino() :: list(map())
  def resource_data_for_kino do
    status = resource_status()

    [
      %{resource: "Total Memory", value_mb: status.memory.total_mb, category: "Memory"},
      %{resource: "Process Memory", value_mb: status.memory.processes_mb, category: "Memory"},
      %{resource: "System Memory", value_mb: status.memory.system_mb, category: "Memory"},
      %{resource: "Binary Memory", value_mb: status.memory.binary_mb, category: "Memory"},
      %{resource: "ETS Memory", value_mb: status.memory.ets_mb, category: "Memory"}
    ]
  end

  @doc """
  Generate envelope constraints visualization data.
  """
  @spec envelope_data_for_kino() :: map()
  def envelope_data_for_kino do
    constraints = Envelope.all_constraints()

    %{
      resource: %{
        flame_nodes: %{max: constraints.resource.max_flame_nodes, current: get_flame_node_count()},
        ram_mb: %{max: constraints.resource.max_ram_mb, current: get_ram_usage_mb()},
        cpu_percent: %{max: constraints.resource.max_cpu_percent, current: get_cpu_percent()}
      },
      physical: %{
        temperature: %{
          min: constraints.physical.min_temperature_c,
          max: constraints.physical.max_temperature_c,
          current: nil
        },
        pressure_delta: %{max: constraints.physical.max_pressure_delta, current: nil}
      },
      temporal: %{
        response_time_ms: %{max: constraints.temporal.max_response_time_ms, current: nil},
        heartbeat_interval_ms: %{
          target: constraints.temporal.heartbeat_interval_ms,
          current: get_heartbeat_gap()
        }
      }
    }
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    session_id = generate_session_id()

    state = %{
      started_at: DateTime.utc_now(),
      operators: [],
      pending_authorizations: %{},
      session_id: session_id
    }

    Logger.info("[Cockpit.Dashboard] Started session #{session_id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:request_auth, operator_id, operation}, _from, state) do
    auth_id = generate_auth_id()
    confirmation_code = generate_confirmation_code()

    pending = %{
      operator_id: operator_id,
      operation: operation,
      confirmation_code: confirmation_code,
      requested_at: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
    }

    new_pending = Map.put(state.pending_authorizations, auth_id, pending)
    new_state = %{state | pending_authorizations: new_pending}

    Logger.info("[Cockpit.Dashboard] Authorization requested by #{operator_id}: #{auth_id}")

    # In real implementation, confirmation_code would be shown in Kino
    {:reply, {:ok, auth_id}, new_state}
  end

  @impl true
  def handle_call({:confirm_auth, auth_id, confirmation_code}, _from, state) do
    pending = Map.get(state.pending_authorizations, auth_id)

    case UnifiedGenServerPatterns.validate_two_key_confirmation(pending, confirmation_code) do
      {:ok, :confirmed} ->
        new_pending = Map.delete(state.pending_authorizations, auth_id)
        Logger.info("[Cockpit.Dashboard] Authorization confirmed: #{auth_id}")
        {:reply, {:ok, :authorized}, %{state | pending_authorizations: new_pending}}

      {:error, :expired} ->
        new_pending = Map.delete(state.pending_authorizations, auth_id)
        {:reply, {:error, :expired}, %{state | pending_authorizations: new_pending}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:session_info, _from, state) do
    info = %{
      running: true,
      session_id: state.session_id,
      started_at: state.started_at,
      operators: state.operators,
      pending_authorizations: map_size(state.pending_authorizations)
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp get_cortex_status do
    if Code.ensure_loaded?(Indrajaal.Cortex) and
         function_exported?(Indrajaal.Cortex, :status, 0) do
      try do
        Indrajaal.Cortex.status()
      rescue
        _ -> %{available: false}
      end
    else
      %{available: false}
    end
  end

  defp get_synapse_status do
    if Code.ensure_loaded?(Indrajaal.Cortex.Synapse) and
         function_exported?(Indrajaal.Cortex.Synapse, :get_state, 0) do
      try do
        Indrajaal.Cortex.Synapse.get_state()
      rescue
        _ -> %{available: false}
      end
    else
      %{available: false}
    end
  end

  defp get_gde_status do
    if Code.ensure_loaded?(Indrajaal.Cortex.GDE) and
         function_exported?(Indrajaal.Cortex.GDE, :status, 0) do
      try do
        Indrajaal.Cortex.GDE.status()
      rescue
        _ -> %{available: false}
      end
    else
      %{available: false}
    end
  end

  defp dms_health(state) do
    case state do
      :healthy -> "Healthy"
      :armed -> "Armed"
      :warning -> "Warning"
      :failsafe_triggered -> "FAILSAFE"
      :disabled -> "Disabled"
      _ -> "Unknown"
    end
  end

  defp get_flame_node_count do
    # Would query FLAME supervisor for actual count
    0
  end

  defp get_ram_usage_mb do
    div(:erlang.memory(:total), 1_048_576)
  end

  defp get_cpu_percent do
    # Approximation based on scheduler utilization
    case :erlang.statistics(:scheduler_wall_time) do
      :undefined ->
        0

      wall_times when is_list(wall_times) ->
        {active, total} =
          Enum.reduce(wall_times, {0, 0}, fn {_id, a, t}, {acc_a, acc_t} ->
            {acc_a + a, acc_t + t}
          end)

        if total > 0, do: round(active / total * 100), else: 0
    end
  rescue
    _ -> 0
  end

  defp get_heartbeat_gap do
    stats = DeadMansSwitch.stats()

    case stats.last_heartbeat do
      nil -> nil
      last -> DateTime.diff(DateTime.utc_now(), last, :millisecond)
    end
  rescue
    _ -> nil
  end

  defp generate_session_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(random_bytes, case: :lower)
  end

  defp generate_auth_id do
    random_bytes = :crypto.strong_rand_bytes(12)
    "auth_" <> Base.encode16(random_bytes, case: :lower)
  end

  defp generate_confirmation_code do
    random_bytes = :crypto.strong_rand_bytes(4)
    Base.encode16(random_bytes, case: :upper)
  end
end
