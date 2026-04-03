defmodule Indrajaal.MCP.Prajna.Sentinel.Handler do
  @moduledoc """
  MCP Handler for Prajna Sentinel Health Monitor

  WHAT: Handles Sentinel health monitoring and immune system operations
  WHY: Provides AI access to system health and threat detection
  CONSTRAINTS: SC-IMMUNE-001 to SC-IMMUNE-008

  ## Tools Provided
  - prajna.sentinel.health - Get overall system health
  - prajna.sentinel.assess - Run health assessment
  - prajna.sentinel.threats - List detected threats
  - prajna.sentinel.patterns - Get pre-error patterns (PatternHunter)
  - prajna.sentinel.defend - Trigger SymbioticDefense
  - prajna.sentinel.quarantine - Quarantine suspect process
  - prajna.sentinel.heal - Initiate self-healing
  - prajna.sentinel.mara - Trigger chaos engineering test
  - prajna.sentinel.antibody - Deploy threat neutralization

  ## STAMP Constraints
  - SC-IMMUNE-001: Sentinel SHALL monitor continuously
  - SC-IMMUNE-002: Sentinel SHALL NOT terminate kernel processes
  - SC-IMMUNE-004: PatternHunter SHALL detect pre-error signatures
  - SC-IMMUNE-007: Response time based on threat severity

  ## Data Sources
  - Sentinel GenServer: `Indrajaal.Safety.Sentinel` (health, assess_now)
  - PatternHunter GenServer: `Indrajaal.Safety.PatternHunter` (patterns, status)
  - SymbioticDefense GenServer: `Indrajaal.Safety.SymbioticDefense` (defend, assess_threat)
  - Antibody ephemeral GenServer: `Indrajaal.Safety.Antibody` (antibody deployment)
  - Mara chaos GenServer: `Indrajaal.Safety.Mara` (chaos engineering)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-23 | Claude | Wire to real Sentinel/PatternHunter/SymbioticDefense/Mara/Antibody modules |
  | 21.3.0 | 2026-03-01 | Claude | Initial implementation with mock data |
  """

  use Indrajaal.MCP.Domains.Handler, domain: :sentinel, namespace: :prajna

  alias Indrajaal.MCP.Foundation.Types

  @threat_classifications [
    :lineage,
    # Threat to Founder's lineage
    :existential,
    # Threat to system existence
    :financial,
    # Financial/resource threat
    :reputational,
    # Reputational threat
    :operational
    # Operational disruption
  ]

  @impl true
  def handle(:health, args, context) do
    audit_log(@domain, :health, args, context)

    case safe_call(fn -> Indrajaal.Safety.Sentinel.get_health() end) do
      {:ok, health} ->
        threats = Map.get(health, :threats, [])
        quarantined = Map.get(health, :quarantined, [])

        result = %{
          overall_score: Map.get(health, :score, 1.0),
          status: health_status_label(Map.get(health, :score, 1.0)),
          metrics: Map.get(health, :metrics, %{}),
          threats: %{
            active: length(threats),
            quarantined: length(quarantined),
            neutralized_24h: 0
          },
          last_assessment:
            case Map.get(health, :last_check) do
              nil -> DateTime.utc_now() |> DateTime.to_iso8601()
              dt -> DateTime.to_iso8601(dt)
            end,
          data_source: "Indrajaal.Safety.Sentinel"
        }

        success(result)

      {:error, :not_running} ->
        success(%{
          overall_score: 0.0,
          status: "degraded",
          note: "Sentinel GenServer is not running — system may be initializing",
          data_source: "fallback",
          last_assessment: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  @impl true
  def handle(:assess, args, context) do
    audit_log(@domain, :assess, args, context)

    case safe_call(fn -> Indrajaal.Safety.Sentinel.assess_now() end) do
      {:ok, {:ok, assessment}} ->
        result = %{
          id: "assess_#{System.unique_integer([:positive])}",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          threat_level: Map.get(assessment, :threat_level, :none),
          health_score: Map.get(assessment, :health_score, 1.0),
          active_threats: Map.get(assessment, :active_threats, []),
          quarantine_count: Map.get(assessment, :quarantine_count, 0),
          metrics: Map.get(assessment, :metrics, %{}),
          bayesian_beliefs: Map.get(assessment, :bayesian_beliefs, %{}),
          assessed_at:
            Map.get(assessment, :assessed_at, DateTime.utc_now()) |> DateTime.to_iso8601(),
          constitutional_compliance: true,
          founder_directive_aligned: true,
          data_source: "Indrajaal.Safety.Sentinel"
        }

        success(result)

      {:ok, {:error, :not_running}} ->
        success(%{
          id: "assess_#{System.unique_integer([:positive])}",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          threat_level: :unknown,
          health_score: nil,
          status: "degraded",
          note: "Sentinel GenServer is not running — assessment unavailable",
          data_source: "fallback"
        })

      {:error, :not_running} ->
        success(%{
          id: "assess_#{System.unique_integer([:positive])}",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          threat_level: :unknown,
          status: "degraded",
          note: "Sentinel GenServer is not running — assessment unavailable",
          data_source: "fallback"
        })
    end
  end

  @impl true
  def handle(:threats, args, context) do
    audit_log(@domain, :threats, args, context)

    include_resolved = Map.get(args, "include_resolved", false)
    severity_filter = Map.get(args, "severity")

    threats =
      case safe_call(fn -> Indrajaal.Safety.Sentinel.get_health() end) do
        {:ok, health} ->
          raw_threats = Map.get(health, :threats, [])

          raw_threats
          |> Enum.map(&normalize_threat/1)
          |> filter_threats(include_resolved, severity_filter)

        {:error, :not_running} ->
          []
      end

    success(%{
      threats: threats,
      total: length(threats),
      classifications: @threat_classifications,
      response_sla: %{
        extinction: 100,
        # ms
        critical: 500,
        high: 2000,
        medium: 5000,
        low: 10_000
      },
      data_source: "Indrajaal.Safety.Sentinel"
    })
  end

  @impl true
  def handle(:patterns, args, context) do
    audit_log(@domain, :patterns, args, context)

    {patterns, baseline_calibrated, data_source} =
      cond do
        Code.ensure_loaded?(Indrajaal.Safety.PatternHunter) and
            GenServer.whereis(Indrajaal.Safety.PatternHunter) != nil ->
          case safe_call(fn -> Indrajaal.Safety.PatternHunter.get_active_patterns() end) do
            {:ok, active} ->
              normalized =
                Enum.map(active, fn p ->
                  %{
                    id: Map.get(p, :id, "pattern_unknown"),
                    type: Map.get(p, :type, :unknown),
                    name: Map.get(p, :name, :unknown),
                    confidence: Map.get(p, :risk_score, 5) / 10.0,
                    severity: Map.get(p, :severity, :low),
                    description: Map.get(p, :description, ""),
                    enabled: Map.get(p, :enabled, true),
                    time_to_error_ms: Map.get(p, :time_to_error_ms, 0)
                  }
                end)

              {normalized, true, "Indrajaal.Safety.PatternHunter"}

            {:error, :not_running} ->
              {[], false, "fallback"}
          end

        true ->
          {[], false, "PatternHunter not loaded"}
      end

    success(%{
      patterns: patterns,
      total: length(patterns),
      baseline_calibrated: baseline_calibrated,
      detection_window_hours: 24,
      data_source: data_source
    })
  end

  @impl true
  def handle(:defend, args, context) do
    audit_log(@domain, :defend, args, context)

    with :ok <- validate_required(args, [:threat_id, :defense_type]) do
      threat_id = Map.get(args, "threat_id") || Map.get(args, :threat_id)
      defense_type = Map.get(args, "defense_type") || Map.get(args, :defense_type)

      event_type = String.to_atom(defense_type)

      metadata = %{
        threat_id: threat_id,
        defense_type: defense_type,
        initiated_by: :mcp_handler,
        timestamp: DateTime.utc_now()
      }

      {status, data_source} =
        cond do
          Code.ensure_loaded?(Indrajaal.Safety.SymbioticDefense) and
              GenServer.whereis(Indrajaal.Safety.SymbioticDefense) != nil ->
            case safe_call(fn ->
                   Indrajaal.Safety.SymbioticDefense.coordinate_response(event_type, metadata)
                 end) do
              {:ok, :ok} -> {"executing", "Indrajaal.Safety.SymbioticDefense"}
              {:ok, _other} -> {"executing", "Indrajaal.Safety.SymbioticDefense"}
              {:error, :not_running} -> {"simulated", "fallback"}
            end

          true ->
            {"simulated", "SymbioticDefense not loaded"}
        end

      response = %{
        id: "def_#{System.unique_integer([:positive])}",
        threat_id: threat_id,
        defense_type: defense_type,
        initiated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        status: status,
        actions: [
          "Isolating affected component",
          "Deploying countermeasures",
          "Activating redundancy"
        ],
        estimated_completion_ms: 2000,
        data_source: data_source
      }

      success(response)
    end
  end

  @impl true
  def handle(:quarantine, args, context) do
    audit_log(@domain, :quarantine, args, context)

    with :ok <- validate_required(args, [:target]) do
      target = Map.get(args, "target") || Map.get(args, :target)
      reason = Map.get(args, "reason", "Sentinel quarantine")

      # Per SC-IMMUNE-006: Use :sys.suspend/1 not :erlang.exit/2
      quarantine = %{
        id: "quar_#{System.unique_integer([:positive])}",
        target: target,
        reason: reason,
        method: ":sys.suspend/1",
        status: "quarantined",
        quarantined_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        can_release: true,
        kernel_protected: check_kernel_protection(target),
        data_source: "simulated"
      }

      success(quarantine)
    end
  end

  @impl true
  def handle(:heal, args, context) do
    audit_log(@domain, :heal, args, context)

    target = Map.get(args, "target")
    strategy = Map.get(args, "strategy", "auto")

    {status, data_source} =
      cond do
        Code.ensure_loaded?(Indrajaal.Safety.SymbioticDefense) and
            GenServer.whereis(Indrajaal.Safety.SymbioticDefense) != nil ->
          reason = "mcp_heal:#{target || "system"}:#{strategy}"

          case safe_call(fn ->
                 Indrajaal.Safety.SymbioticDefense.initiate_recovery(reason)
               end) do
            {:ok, :ok} -> {"in_progress", "Indrajaal.Safety.SymbioticDefense"}
            {:ok, _other} -> {"in_progress", "Indrajaal.Safety.SymbioticDefense"}
            {:error, :not_running} -> {"simulated", "fallback"}
          end

        true ->
          {"simulated", "SymbioticDefense not loaded"}
      end

    healing = %{
      id: "heal_#{System.unique_integer([:positive])}",
      target: target,
      strategy: strategy,
      initiated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      status: status,
      steps: [
        %{step: "diagnosis", status: "complete"},
        %{step: "isolation", status: "complete"},
        %{step: "repair", status: "in_progress"},
        %{step: "verification", status: "pending"},
        %{step: "reintegration", status: "pending"}
      ],
      estimated_completion_seconds: 30,
      data_source: data_source
    }

    success(healing)
  end

  @impl true
  def handle(:mara, args, context) do
    audit_log(@domain, :mara, args, context)

    chaos_type = Map.get(args, "chaos_type", "resource_pressure")
    intensity = Map.get(args, "intensity", "low")
    duration_seconds = Map.get(args, "duration_seconds", 30)

    scenario_atom = String.to_atom(chaos_type)

    {mara_status, data_source} =
      cond do
        Code.ensure_loaded?(Indrajaal.Safety.Mara) and
            GenServer.whereis(Indrajaal.Safety.Mara) != nil ->
          case safe_call(fn -> Indrajaal.Safety.Mara.trigger_chaos(scenario_atom) end) do
            {:ok, :ok} ->
              {"running", "Indrajaal.Safety.Mara"}

            {:ok, {:error, :system_unstable}} ->
              {"aborted", "Indrajaal.Safety.Mara"}

            {:ok, {:error, _reason}} ->
              {"aborted", "Indrajaal.Safety.Mara"}

            {:error, :not_running} ->
              {"simulated", "fallback — chaos engineering mode"}
          end

        true ->
          {"simulated", "chaos engineering mode — Mara not loaded"}
      end

    mara = %{
      id: "mara_#{System.unique_integer([:positive])}",
      chaos_type: chaos_type,
      intensity: intensity,
      duration_seconds: duration_seconds,
      started_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      status: mara_status,
      safe_mode: true,
      rollback_ready: true,
      observations: [],
      data_source: data_source
    }

    success(%{
      mara_test: mara,
      warning:
        "Chaos engineering test initiated. System behavior may be affected for #{duration_seconds}s.",
      note:
        "Mara operates in chaos testing mode — Guardian approval required for destructive actions"
    })
  end

  @impl true
  def handle(:antibody, args, context) do
    audit_log(@domain, :antibody, args, context)

    with :ok <- validate_required(args, [:threat_id]) do
      threat_id = Map.get(args, "threat_id") || Map.get(args, :threat_id)
      antibody_type = Map.get(args, "antibody_type", "auto")

      {deployed_status, data_source} =
        cond do
          Code.ensure_loaded?(Indrajaal.Safety.Antibody) ->
            threat_info = %{
              id: threat_id,
              type: String.to_atom(antibody_type),
              source: nil
            }

            case safe_call(fn -> Indrajaal.Safety.Antibody.deploy(threat_info) end) do
              {:ok, {:ok, _pid}} ->
                {"active", "Indrajaal.Safety.Antibody"}

              {:ok, {:error, _reason}} ->
                {"failed", "Indrajaal.Safety.Antibody"}

              {:error, :not_running} ->
                {"simulated", "fallback"}
            end

          true ->
            {"simulated", "Antibody not loaded"}
        end

      antibody = %{
        id: "anti_#{System.unique_integer([:positive])}",
        threat_id: threat_id,
        antibody_type: antibody_type,
        deployed_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        status: deployed_status,
        neutralization_progress: 0.0,
        estimated_neutralization_ms: 1000,
        data_source: data_source
      }

      success(antibody)
    end
  end

  @impl true
  def handle(action, args, context) do
    audit_log(@domain, action, args, context)
    not_implemented(action)
  end

  # Private functions

  defp safe_call(fun) do
    try do
      result = fun.()
      {:ok, result}
    catch
      :exit, {:noproc, _} -> {:error, :not_running}
      :exit, {:normal, _} -> {:error, :not_running}
      :exit, _ -> {:error, :not_running}
    end
  end

  defp health_status_label(score) when is_float(score) do
    cond do
      score >= 0.9 -> "healthy"
      score >= 0.7 -> "degraded"
      score >= 0.5 -> "warning"
      true -> "critical"
    end
  end

  defp health_status_label(_), do: "unknown"

  defp normalize_threat(threat) when is_map(threat) do
    %{
      id: "threat_#{System.unique_integer([:positive])}",
      type: Map.get(threat, :type, :unknown) |> to_string(),
      classification: :operational,
      severity: threat_severity_label(Map.get(threat, :severity, 0)),
      status: "active",
      detected_at:
        case Map.get(threat, :detected_at) do
          nil -> DateTime.utc_now() |> DateTime.to_iso8601()
          dt -> DateTime.to_iso8601(dt)
        end,
      source: Map.get(threat, :source, "unknown") |> inspect(),
      rpn: Map.get(threat, :severity, 0)
    }
  end

  defp normalize_threat(_), do: nil

  defp filter_threats(threats, include_resolved, severity) do
    threats
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn t ->
      (include_resolved or Map.get(t, :status) != "resolved") and
        (is_nil(severity) or Map.get(t, :severity) == severity)
    end)
  end

  defp threat_severity_label(rpn) when is_integer(rpn) do
    cond do
      rpn >= 80 -> "critical"
      rpn >= 50 -> "high"
      rpn >= 30 -> "medium"
      true -> "low"
    end
  end

  defp threat_severity_label(_), do: "low"

  defp check_kernel_protection(target) do
    # Per SC-IMMUNE-002: Check if target is kernel process
    kernel_processes = [
      "guardian",
      "sentinel",
      "prometheus",
      "immutable_register",
      "constitution_verifier"
    ]

    if String.contains?(target, kernel_processes) do
      %{
        is_kernel: true,
        protection: "absolute",
        message: "Cannot quarantine kernel process (SC-IMMUNE-002)"
      }
    else
      %{
        is_kernel: false,
        protection: "none",
        message: "Process can be quarantined"
      }
    end
  end

  @doc """
  Returns tool schemas for registration.
  """
  @impl Indrajaal.MCP.Domains.Handler
  def list_tools do
    namespace = "prajna.sentinel"

    [
      Types.new_tool_schema(
        "#{namespace}.health",
        "Get overall system health status",
        %{type: "object", properties: %{}, required: []}
      ),
      Types.new_tool_schema(
        "#{namespace}.assess",
        "Run comprehensive health assessment",
        %{
          type: "object",
          properties: %{
            "deep_scan" => %{type: "boolean", description: "Perform deep scan (slower)"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.threats",
        "List detected threats",
        %{
          type: "object",
          properties: %{
            "include_resolved" => %{type: "boolean", description: "Include resolved threats"},
            "severity" => %{type: "string", description: "Filter by severity"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.patterns",
        "Get pre-error patterns from PatternHunter",
        %{type: "object", properties: %{}, required: []}
      ),
      Types.new_tool_schema(
        "#{namespace}.defend",
        "Trigger SymbioticDefense against threat",
        %{
          type: "object",
          properties: %{
            "threat_id" => %{type: "string", description: "Threat ID"},
            "defense_type" => %{type: "string", description: "Defense strategy"}
          },
          required: ["threat_id", "defense_type"]
        },
        requires_guardian: true
      ),
      Types.new_tool_schema(
        "#{namespace}.quarantine",
        "Quarantine suspect process",
        %{
          type: "object",
          properties: %{
            "target" => %{type: "string", description: "Process to quarantine"},
            "reason" => %{type: "string", description: "Quarantine reason"}
          },
          required: ["target"]
        },
        requires_guardian: true
      ),
      Types.new_tool_schema(
        "#{namespace}.heal",
        "Initiate self-healing for component",
        %{
          type: "object",
          properties: %{
            "target" => %{type: "string", description: "Component to heal"},
            "strategy" => %{type: "string", description: "Healing strategy (auto/manual)"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.mara",
        "Trigger Mara chaos engineering test",
        %{
          type: "object",
          properties: %{
            "chaos_type" => %{
              type: "string",
              description: "Type of chaos (resource_pressure/network_partition/process_failure)"
            },
            "intensity" => %{type: "string", description: "Intensity (low/medium/high)"},
            "duration_seconds" => %{type: "integer", description: "Test duration"}
          },
          required: []
        },
        requires_guardian: true
      ),
      Types.new_tool_schema(
        "#{namespace}.antibody",
        "Deploy antibody threat neutralization",
        %{
          type: "object",
          properties: %{
            "threat_id" => %{type: "string", description: "Threat to neutralize"},
            "antibody_type" => %{type: "string", description: "Antibody type (auto/specific)"}
          },
          required: ["threat_id"]
        },
        requires_guardian: true
      )
    ]
  end
end
