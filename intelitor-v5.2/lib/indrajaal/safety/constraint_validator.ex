defmodule Indrajaal.Safety.ConstraintValidator do
  @moduledoc """
  STAMP-compliant Safety Constraint Validation System.

  WHAT: Real-time UCA (Unsafe Control Actions) validation with safety gates.
  WHY: SC-IMMUNE-005 requires pre-action constraint checking to prevent unsafe control actions.
  CONSTRAINTS: SC-IMMUNE-005, SC-EMR-057, SC-CTRL-006
  """

  use GenServer
  require Logger

  # UCA definitions covering alarm, access, data integrity, system, and network domains
  @ucas [
    %{
      id: "UCA001",
      control_action: :alarm_acknowledgment,
      context: :alarm_storm,
      unsafe_condition: :delayed_acknowledgment,
      category: :alarm_management,
      severity: :high,
      description: "Alarm acknowledgment during alarm storm must be < 1000ms",
      mitigation: "Enable bulk acknowledgment or auto-acknowledge non-critical alarms"
    },
    %{
      id: "UCA002",
      control_action: :alarm_escalation,
      context: :critical_alarm,
      unsafe_condition: :escalation_delay,
      category: :alarm_management,
      severity: :critical,
      description: "Critical alarms must escalate within 5 minutes if unacknowledged",
      mitigation: "Automatic escalation with notification to backup personnel"
    },
    %{
      id: "UCA003",
      control_action: :alarm_suppression,
      context: :maintenance_mode,
      unsafe_condition: :inappropriate_suppression,
      category: :alarm_management,
      severity: :high,
      description: "Alarm suppression must not affect safety-critical systems",
      mitigation: "Maintain separate safety alarm channels during maintenance"
    },
    %{
      id: "UCA004",
      control_action: :user_authentication,
      context: :emergency_access,
      unsafe_condition: :delayed_authentication,
      category: :access_control,
      severity: :critical,
      description: "Emergency access must not bypass critical security validation",
      mitigation: "Emergency access with enhanced logging and post-incident review"
    },
    %{
      id: "UCA005",
      control_action: :privilege_escalation,
      context: :incident_response,
      unsafe_condition: :excessive_privileges,
      category: :access_control,
      severity: :high,
      description: "Privilege escalation must be time-limited and audited",
      mitigation: "Automatic privilege revocation with approval workflow"
    },
    %{
      id: "UCA006",
      control_action: :session_termination,
      context: :security_incident,
      unsafe_condition: :incomplete_termination,
      category: :access_control,
      severity: :high,
      description: "Security incident must terminate ALL user sessions immediately",
      mitigation: "Global session invalidation with force logout capability"
    },
    %{
      id: "UCA007",
      control_action: :data_modification,
      context: :cross_tenant_operation,
      unsafe_condition: :tenant_boundary_violation,
      category: :data_integrity,
      severity: :critical,
      description: "Data modifications must never cross tenant boundaries",
      mitigation: "Immediate tenant isolation and data integrity verification"
    },
    %{
      id: "UCA008",
      control_action: :backup_restore,
      context: :system_recovery,
      unsafe_condition: :data_corruption_propagation,
      category: :data_integrity,
      severity: :critical,
      description: "Backup restoration must verify data integrity before proceeding",
      mitigation: "Staged restore with integrity checks and rollback capability"
    },
    %{
      id: "UCA009",
      control_action: :database_migration,
      context: :schema_change,
      unsafe_condition: :data_loss_risk,
      category: :data_integrity,
      severity: :high,
      description: "Database migrations must not risk data loss or corruption",
      mitigation: "Pre-migration backup with rollback procedures and validation"
    },
    %{
      id: "UCA010",
      control_action: :service_restart,
      context: :high_load,
      unsafe_condition: :cascade_failure,
      category: :system_control,
      severity: :high,
      description: "Service restarts during high load must not cause cascade failures",
      mitigation: "Load balancing with graceful service degradation"
    },
    %{
      id: "UCA011",
      control_action: :configuration_change,
      context: :production_system,
      unsafe_condition: :system_instability,
      category: :system_control,
      severity: :medium,
      description: "Production configuration changes must be validated and reversible",
      mitigation: "Configuration validation with automatic rollback on failure"
    },
    %{
      id: "UCA012",
      control_action: :resource_scaling,
      context: :performance_degradation,
      unsafe_condition: :resource_exhaustion,
      category: :system_control,
      severity: :medium,
      description: "Resource scaling must not exceed system capacity limits",
      mitigation: "Graduated scaling with resource monitoring and limits"
    },
    %{
      id: "UCA013",
      control_action: :network_isolation,
      context: :security_breach,
      unsafe_condition: :communication_disruption,
      category: :network_control,
      severity: :high,
      description: "Network isolation must maintain emergency communication channels",
      mitigation: "Selective isolation with emergency communication preservation"
    },
    %{
      id: "UCA014",
      control_action: :certificate_renewal,
      context: :automatic_renewal,
      unsafe_condition: :service_disruption,
      category: :network_control,
      severity: :medium,
      description: "Certificate renewal must not disrupt active services",
      mitigation: "Staged renewal with service health monitoring"
    },
    %{
      id: "UCA015",
      control_action: :firewall_rule_change,
      context: :incident_response,
      unsafe_condition: :access_blocking,
      category: :network_control,
      severity: :high,
      description: "Firewall changes must not block emergency response access",
      mitigation: "Emergency access rules with time-limited exceptions"
    }
  ]

  @safety_gates [
    %{
      name: :critical_system_change,
      conditions: [:backup_verified, :rollback_plan, :approval_obtained],
      bypass_authority: :emergency_coordinator,
      description: "Changes affecting critical system components"
    },
    %{
      name: :tenant_data_access,
      conditions: [:tenant_authorization, :access_logging, :isolation_verified],
      bypass_authority: :never,
      description: "Any access to tenant data must pass isolation verification"
    },
    %{
      name: :emergency_override,
      conditions: [:incident_declared, :authority_verified, :audit_trail],
      bypass_authority: :security_officer,
      description: "Emergency procedures that bypass normal safety checks"
    }
  ]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec validate_action(atom(), atom(), map()) :: :ok | {:error, term()} | {:warning, term()}
  def validate_action(action, context, params \\ %{}) do
    GenServer.call(__MODULE__, {:validate_action, action, context, params})
  end

  @spec check_safety_gate(atom(), map()) ::
          :ok | {:ok, :bypassed, map()} | {:error, atom(), map()}
  def check_safety_gate(gate_name, conditions \\ %{}) do
    GenServer.call(__MODULE__, {:check_safety_gate, gate_name, conditions})
  end

  @spec get_validation_statistics() :: map()
  def get_validation_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    ucas_by_action = Enum.group_by(@ucas, & &1.control_action)

    state = %{
      ucas_by_action: ucas_by_action,
      custom_ucas: %{},
      statistics: %{
        ucas_loaded: length(@ucas),
        validations_performed: 0,
        violations_detected: 0,
        safety_gates_checked: 0,
        actions_blocked: 0
      },
      check_mode: Keyword.get(opts, :check_mode, :enforcing)
    }

    Logger.info("[ConstraintValidator] Initialized with #{length(@ucas)} UCAs")
    {:ok, state}
  end

  @impl true
  def handle_call({:validate_action, action, context, params}, _from, state) do
    applicable = get_applicable_ucas(action, context, state)
    violations = check_ucas(applicable, context, params)

    result =
      case violations do
        [] ->
          :ok

        violations when state.check_mode == :monitoring ->
          {:warning, {:unsafe_control_actions, violations}}

        violations ->
          {:error, {:unsafe_control_actions, violations}}
      end

    new_stats =
      state.statistics
      |> Map.update!(:validations_performed, &(&1 + 1))
      |> Map.update!(:violations_detected, &(&1 + length(violations)))

    new_stats =
      if match?({:error, _}, result),
        do: Map.update!(new_stats, :actions_blocked, &(&1 + 1)),
        else: new_stats

    :telemetry.execute(
      [:indrajaal, :safety, :constraint_validation],
      %{violations_count: length(violations), ucas_checked: length(applicable)},
      %{action: action, context: context}
    )

    {:reply, result, %{state | statistics: new_stats}}
  end

  def handle_call({:check_safety_gate, gate_name, conditions}, _from, state) do
    gate = Enum.find(@safety_gates, fn g -> g.name == gate_name end)

    result =
      case gate do
        nil ->
          {:error, :unknown_gate, %{gate: gate_name}}

        gate ->
          missing =
            Enum.filter(gate.conditions, fn c ->
              not Map.get(conditions, c, false)
            end)

          case {missing, Map.get(conditions, :bypass_authority)} do
            {[], _} ->
              :ok

            {_missing, auth} when auth == gate.bypass_authority ->
              {:ok, :bypassed, %{missing_conditions: missing, authority: auth}}

            {missing, _} ->
              {:error, :conditions_not_met, %{missing_conditions: missing}}
          end
      end

    new_stats = Map.update!(state.statistics, :safety_gates_checked, &(&1 + 1))
    {:reply, result, %{state | statistics: new_stats}}
  end

  def handle_call(:get_statistics, _from, state) do
    {:reply, state.statistics, state}
  end

  # Private helpers

  defp get_applicable_ucas(action, context, state) do
    action_ucas = Map.get(state.ucas_by_action, action, [])
    custom = state.custom_ucas |> Map.values() |> Enum.filter(&(&1.control_action == action))

    (action_ucas ++ custom)
    |> Enum.filter(fn uca -> uca.context == context or uca.context == :any or context == :any end)
  end

  defp check_ucas(ucas, context, params) do
    Enum.flat_map(ucas, fn uca ->
      case validate_uca(uca, context, params) do
        :ok -> []
        {:violation, details} -> [Map.merge(uca, %{violation_details: details})]
      end
    end)
  end

  defp validate_uca(%{id: "UCA001"}, :alarm_storm, params) do
    case Map.get(params, :acknowledgment_time) do
      t when is_integer(t) and t > 1000 -> {:violation, %{timing: t, threshold: 1000}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA002"}, :critical_alarm, params) do
    case Map.get(params, :unacknowledged_duration) do
      d when is_integer(d) and d > 300_000 -> {:violation, %{duration: d, threshold: 300_000}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA003"}, :maintenance_mode, params) do
    case Map.get(params, :suppression_scope) do
      scope when scope in [:safety_critical, :all_systems] -> {:violation, %{scope: scope}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA004"}, :emergency_access, params) do
    if Map.get(params, :bypass_security_validation) and
         not Map.get(params, :enhanced_logging, false) do
      {:violation, %{message: "Emergency access must include enhanced logging"}}
    else
      :ok
    end
  end

  defp validate_uca(%{id: "UCA005"}, :incident_response, params) do
    case Map.get(params, :escalation_duration) do
      d when is_integer(d) and d > 3600 -> {:violation, %{duration: d, threshold: 3600}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA006"}, :security_incident, params) do
    case Map.get(params, :termination_scope) do
      :partial ->
        {:violation, %{message: "Security incident requires complete session termination"}}

      _ ->
        :ok
    end
  end

  defp validate_uca(%{id: "UCA007"}, :cross_tenant_operation, params) do
    if Map.get(params, :cross_tenant_access, false) do
      {:violation, %{message: "Cross-tenant data access is prohibited"}}
    else
      :ok
    end
  end

  defp validate_uca(%{id: "UCA008"}, :system_recovery, params) do
    case Map.get(params, :integrity_verified) do
      false -> {:violation, %{message: "Backup integrity must be verified before restore"}}
      nil -> {:violation, %{message: "Backup integrity check required"}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA009"}, :schema_change, params) do
    case Map.get(params, :rollback_plan) do
      nil -> {:violation, %{message: "Database migration requires rollback plan"}}
      false -> {:violation, %{message: "Database migration requires rollback plan"}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA010"}, :high_load, params) do
    case Map.get(params, :system_load) do
      load when is_number(load) and load > 0.8 -> {:violation, %{load: load, threshold: 0.8}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA011"}, :production_system, params) do
    case Map.get(params, :validation_performed) do
      false -> {:violation, %{message: "Production config changes must be validated"}}
      nil -> {:violation, %{message: "Production config changes require validation"}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA012"}, :performance_degradation, params) do
    case Map.get(params, :target_capacity) do
      c when is_number(c) and c > 1.0 -> {:violation, %{capacity: c}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA013"}, :security_breach, params) do
    case Map.get(params, :emergency_channels_preserved) do
      false -> {:violation, %{message: "Network isolation must preserve emergency communication"}}
      nil -> {:violation, %{message: "Emergency communication preservation required"}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA014"}, :automatic_renewal, params) do
    case Map.get(params, :service_disruption_risk) do
      :high -> {:violation, %{message: "Certificate renewal timing may disrupt services"}}
      _ -> :ok
    end
  end

  defp validate_uca(%{id: "UCA015"}, :incident_response, params) do
    if Map.get(params, :emergency_access_blocked, false) do
      {:violation, %{message: "Firewall changes must not block emergency access"}}
    else
      :ok
    end
  end

  defp validate_uca(_uca, _context, _params), do: :ok
end
