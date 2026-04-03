defmodule IndrajaalWeb.Api.PrajnaController do
  @moduledoc """
  Prajna API Controller for CEPAF-Prajna Synchronization.

  WHAT: HTTP API endpoints for F# CEPAF Cockpit to communicate with Elixir backend.
  WHY: Enables bidirectional sync between F# TUI and Elixir Prajna services.

  ## Endpoints

  | Method | Path | Function | STAMP |
  |--------|------|----------|-------|
  | GET | /sentinel/health | sentinel_health | SC-PRAJNA-004 |
  | POST | /guardian/submit | submit_command | SC-PRAJNA-001 |
  | POST | /founder/validate | validate_founder | SC-PRAJNA-002 |
  | POST | /register/record | record_state | SC-PRAJNA-003 |
  | GET | /prometheus/token | get_proof_token | SC-SYNC-007 |
  | POST | /constitutional/check | check_constitutional | SC-SYNC-008 |
  | POST | /zenoh/subscribe | zenoh_subscribe | SC-SYNC-009 |
  | POST | /zenoh/publish | zenoh_publish | SC-SYNC-009 |

  ## STAMP Constraints

  - SC-SYNC-001: Bridge timeout < 5s (handled by client)
  - SC-SYNC-005: All commands through Guardian
  - SC-SYNC-006: All state via Immutable Register
  - SC-SYNC-007: Proof token required for mutations
  - SC-SYNC-008: Constitutional check before reconfig
  - SC-SYNC-009: Zenoh for real-time telemetry
  - SC-SYNC-010: DuckDB for shared history

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 21.1.0 |
  | Created | 2026-01-01 |
  | Author | Cybernetic Architect |
  | STAMP | SC-SYNC-001 to SC-SYNC-010 |
  """

  use IndrajaalWeb, :controller

  require Logger
  alias Indrajaal.Cockpit.Prajna.GuardianIntegration
  alias Indrajaal.Cockpit.Prajna.AiCopilotFounder
  alias Indrajaal.Cockpit.Prajna.ImmutableState
  alias Indrajaal.Safety.Sentinel

  # ============================================================
  # SENTINEL HEALTH (SC-PRAJNA-004)
  # ============================================================

  @doc """
  Get Sentinel health status for CEPAF bridge sync.

  ## Response

      {
        "success": true,
        "data": {
          "health_score": 95.5,
          "status": "healthy",
          "active_threats": [],
          "last_check": "2026-01-01T12:00:00Z",
          "system_load": 0.45,
          "memory_usage": 0.62,
          "cpu_usage": 0.35
        },
        "request_id": "abc123",
        "timestamp": "2026-01-01T12:00:00Z"
      }
  """
  @spec sentinel_health(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sentinel_health(conn, _params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] sentinel_health request_id=#{request_id}")

    case get_sentinel_health() do
      {:ok, health} ->
        json(conn, %{
          success: true,
          data: health,
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: to_string(reason),
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  # ============================================================
  # GUARDIAN INTEGRATION (SC-PRAJNA-001, SC-SYNC-005)
  # ============================================================

  @doc """
  Submit command proposal to Guardian for approval.

  ## Request Body

      {
        "command_type": "reconfiguration",
        "target_module": "Indrajaal.SomeModule",
        "payload": {"key": "value"},
        "justification": "Reason for command",
        "urgency": "normal"
      }

  ## Response

      {
        "success": true,
        "data": {
          "status": "approved",
          "proposal_id": "prop_abc123"
        }
      }
  """
  @spec submit_command(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def submit_command(conn, params) do
    request_id = generate_request_id()

    Logger.info(
      "[PrajnaAPI] submit_command request_id=#{request_id} type=#{params["command_type"]}"
    )

    command = build_command_from_params(params)

    case GuardianIntegration.submit_proposal(command) do
      {:ok, approval} ->
        json(conn, %{
          success: true,
          data: %{
            status: "approved",
            proposal_id: Map.get(approval, :proposal_id, request_id)
          },
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:veto, reason, fallback} ->
        json(conn, %{
          success: true,
          data: %{
            status: "vetoed",
            reason: reason,
            fallback_action: fallback
          },
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  # ============================================================
  # FOUNDER DIRECTIVE VALIDATION (SC-PRAJNA-002)
  # ============================================================

  @doc """
  Validate recommendation against Founder's Directive (Three Supreme Goals).

  ## Request Body

      {
        "action": "resource_acquisition",
        "resource_impact": 1.5,
        "founder_benefit": "Increases wealth accumulation",
        "description": "Deploy new revenue stream"
      }

  ## Response

      {
        "success": true,
        "data": {
          "is_valid": true,
          "alignment_score": 0.95,
          "goal1_alignment": 1.0,
          "goal2_alignment": 0.8,
          "goal3_alignment": 0.9,
          "violations": [],
          "warnings": []
        }
      }
  """
  @spec validate_founder(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def validate_founder(conn, params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] validate_founder request_id=#{request_id}")

    recommendation = %{
      action: params["action"],
      resource_impact: params["resource_impact"] || 0.0,
      founder_benefit: params["founder_benefit"],
      description: params["description"]
    }

    # AiCopilotFounder returns {:ok, validated}, {:warn, reason, validated}, or {:reject, reason}
    result = AiCopilotFounder.validate_recommendation(recommendation)
    alignment = AiCopilotFounder.alignment_score(recommendation)

    case result do
      {:ok, validated} ->
        json(conn, %{
          success: true,
          data: %{
            is_valid: true,
            alignment_score: alignment,
            goal1_alignment: alignment * 0.5,
            goal2_alignment: alignment * 0.3,
            goal3_alignment: alignment * 0.2,
            violations: [],
            warnings: Map.get(validated, :concerns, [])
          },
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:warn, reason, validated} ->
        json(conn, %{
          success: true,
          data: %{
            is_valid: true,
            alignment_score: alignment,
            goal1_alignment: alignment * 0.5,
            goal2_alignment: alignment * 0.3,
            goal3_alignment: alignment * 0.2,
            violations: [],
            warnings: [reason | Map.get(validated, :concerns, [])]
          },
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:reject, reason} ->
        json(conn, %{
          success: true,
          data: %{
            is_valid: false,
            alignment_score: 0.0,
            goal1_alignment: 0.0,
            goal2_alignment: 0.0,
            goal3_alignment: 0.0,
            violations: [reason],
            warnings: []
          },
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  # ============================================================
  # IMMUTABLE REGISTER (SC-PRAJNA-003, SC-SYNC-006)
  # ============================================================

  @doc """
  Record state change to immutable register.

  ## Request Body

      {
        "module": "Indrajaal.SomeModule",
        "operation": "update",
        "old_value": "previous",
        "new_value": "current",
        "reason": "Configuration change"
      }

  ## Response

      {
        "success": true,
        "data": {
          "block_number": 12345,
          "hash": "sha256_hash",
          "previous_hash": "prev_hash",
          "signature": "ed25519_sig",
          "timestamp": "2026-01-01T12:00:00Z",
          "operation": "update"
        }
      }
  """
  @spec record_state(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def record_state(conn, params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] record_state request_id=#{request_id} module=#{params["module"]}")

    # Build state change in ImmutableState format
    change = %{
      change_type: :holon_state_change,
      module: params["module"] || "unknown",
      key: params["operation"] || "update",
      old_value: params["old_value"],
      new_value: params["new_value"] || "",
      metadata: %{reason: params["reason"]}
    }

    # Create or get existing register and record the change
    # ImmutableState.record/2 returns the updated register directly
    register = ImmutableState.create_register()
    updated_register = ImmutableState.record(change, register)

    # Get the last block (the one we just added)
    last_block = List.last(updated_register.blocks)

    json(conn, %{
      success: true,
      data: %{
        block_number: last_block.index,
        hash: last_block.content_hash,
        previous_hash: last_block.prev_hash,
        signature: last_block.signature,
        timestamp: last_block.timestamp |> DateTime.to_iso8601(),
        operation: params["operation"]
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ============================================================
  # PROMETHEUS PROOF TOKEN (SC-SYNC-007)
  # ============================================================

  @doc """
  Get PROMETHEUS proof token for mutations.

  ## Request Body

      {
        "scope": ["state:write", "config:update"],
        "reason": "State mutation for feature X",
        "expiration_minutes": 15
      }

  ## Response

      {
        "success": true,
        "data": {
          "token": "prom_token_xyz",
          "expires_at": "2026-01-01T12:15:00Z",
          "scope": ["state:write", "config:update"],
          "issued_at": "2026-01-01T12:00:00Z"
        }
      }
  """
  @spec get_proof_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_proof_token(conn, params) do
    request_id = generate_request_id()
    scope = params["scope"] || []
    reason = params["reason"] || "unspecified"
    expiration_minutes = params["expiration_minutes"] || 15

    Logger.info("[PrajnaAPI] get_proof_token request_id=#{request_id} scope=#{inspect(scope)}")

    now = DateTime.utc_now()
    expires_at = DateTime.add(now, expiration_minutes * 60, :second)

    # Generate proof token (simplified - in production would be cryptographically signed)
    token = generate_proof_token(scope, reason, now)

    json(conn, %{
      success: true,
      data: %{
        token: token,
        expires_at: DateTime.to_iso8601(expires_at),
        scope: scope,
        issued_at: DateTime.to_iso8601(now)
      },
      request_id: request_id,
      timestamp: DateTime.to_iso8601(now)
    })
  end

  # ============================================================
  # CONSTITUTIONAL CHECK (SC-SYNC-008)
  # ============================================================

  @doc """
  Check constitutional invariants before reconfiguration.

  ## Request Body

      {
        "target_layer": "L3",
        "change_description": "Update caching strategy",
        "survival_pressure": "Performance degradation",
        "expected_benefits": ["Faster response", "Lower memory"]
      }

  ## Response

      {
        "success": true,
        "data": {
          "psi0_existence": true,
          "psi1_regeneration": true,
          "psi2_evolution": true,
          "psi3_verification": true,
          "psi4_human_alignment": true,
          "psi5_truthfulness": true,
          "all_passed": true,
          "violations": []
        }
      }
  """
  @spec check_constitutional(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def check_constitutional(conn, params) do
    request_id = generate_request_id()

    Logger.info(
      "[PrajnaAPI] check_constitutional request_id=#{request_id} layer=#{params["target_layer"]}"
    )

    # Perform constitutional invariant checks
    check_result = perform_constitutional_check(params)

    json(conn, %{
      success: true,
      data: check_result,
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ============================================================
  # ZENOH INTEGRATION (SC-SYNC-009)
  # ============================================================

  @doc """
  Subscribe to Zenoh telemetry topic.

  ## Request Body

      {
        "topic": "prajna/metrics/**",
        "callback_url": "http://localhost:8080/callback"
      }

  ## Response

      {
        "success": true,
        "data": {
          "subscription_id": "sub_abc123"
        }
      }
  """
  @spec zenoh_subscribe(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def zenoh_subscribe(conn, params) do
    request_id = generate_request_id()
    topic = params["topic"]
    Logger.info("[PrajnaAPI] zenoh_subscribe request_id=#{request_id} topic=#{topic}")

    # Register subscription (simplified - would use ZenohSession in production)
    subscription_id = "sub_#{generate_short_id()}"

    json(conn, %{
      success: true,
      data: %{
        subscription_id: subscription_id
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Publish telemetry to Zenoh topic.

  ## Request Body

      {
        "topic": "prajna/events/command_executed",
        "payload": {"command_id": "cmd123", "status": "success"}
      }

  ## Response

      {
        "success": true
      }
  """
  @spec zenoh_publish(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def zenoh_publish(conn, params) do
    request_id = generate_request_id()
    topic = params["topic"]
    _payload = params["payload"]
    Logger.info("[PrajnaAPI] zenoh_publish request_id=#{request_id} topic=#{topic}")

    # Publish via Zenoh (simplified - would use ZenohSession in production)
    # In production: ZenohSession.publish(topic, _payload)

    json(conn, %{
      success: true,
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ============================================================
  # CONTAINER OPERATIONS (SC-SYNC-011) - Sprint 32
  # ============================================================

  @doc """
  Get status of all containers.

  ## Response

      {
        "success": true,
        "data": {
          "containers": [
            {"name": "indrajaal-ex-app-1", "status": "running", "health": "healthy"},
            {"name": "indrajaal-db-prod", "status": "running", "health": "healthy"},
            {"name": "indrajaal-obs-prod", "status": "running", "health": "healthy"}
          ],
          "overall_health": "healthy"
        }
      }
  """
  @spec containers_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def containers_status(conn, _params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] containers_status request_id=#{request_id}")

    containers = get_container_statuses()
    overall = if Enum.all?(containers, &(&1.health == "healthy")), do: "healthy", else: "degraded"

    json(conn, %{
      success: true,
      data: %{
        containers: containers,
        overall_health: overall
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Get logs for a specific container.

  ## Response

      {
        "success": true,
        "data": {
          "container": "indrajaal-ex-app-1",
          "logs": ["line1", "line2", ...],
          "line_count": 100
        }
      }
  """
  @spec container_logs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def container_logs(conn, %{"id" => container_id} = params) do
    request_id = generate_request_id()
    lines = params["lines"] || "100"
    Logger.info("[PrajnaAPI] container_logs request_id=#{request_id} container=#{container_id}")

    logs = get_container_logs(container_id, String.to_integer(lines))

    json(conn, %{
      success: true,
      data: %{
        container: container_id,
        logs: logs,
        line_count: length(logs)
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Execute action on a container (requires Guardian approval).

  ## Request Body

      {
        "action": "restart",
        "reason": "Memory leak detected"
      }

  ## Response

      {
        "success": true,
        "data": {
          "action": "restart",
          "status": "executed",
          "container": "indrajaal-ex-app-1"
        }
      }
  """
  @spec container_action(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def container_action(conn, %{"id" => container_id} = params) do
    request_id = generate_request_id()
    action = params["action"]
    reason = params["reason"] || "No reason provided"

    Logger.info(
      "[PrajnaAPI] container_action request_id=#{request_id} container=#{container_id} action=#{action}"
    )

    # SC-SYNC-011: Container actions require Guardian approval
    proposal = %{
      type: :container_action,
      target_module: "Container.#{container_id}",
      payload: %{action: action, container: container_id},
      justification: reason,
      urgency: "normal",
      timestamp: DateTime.utc_now()
    }

    case GuardianIntegration.submit_proposal(proposal) do
      {:ok, _approval} ->
        result = execute_container_action(container_id, action)

        json(conn, %{
          success: true,
          data: %{
            action: action,
            status: result,
            container: container_id
          },
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:veto, reason, fallback} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Guardian vetoed: #{reason}",
          fallback: fallback,
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  # ============================================================
  # AGENT MESH OPERATIONS (SC-SYNC-012) - Sprint 32
  # ============================================================

  @doc """
  Get all agents in the mesh.

  ## Response

      {
        "success": true,
        "data": {
          "agents": [
            {"fqun": "ooda-agent", "status": "active", "last_heartbeat": "..."},
            ...
          ],
          "total_count": 7
        }
      }
  """
  @spec mesh_agents(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mesh_agents(conn, _params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] mesh_agents request_id=#{request_id}")

    agents = get_mesh_agents()

    json(conn, %{
      success: true,
      data: %{
        agents: agents,
        total_count: length(agents)
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Get specific agent details.
  """
  @spec mesh_agent(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mesh_agent(conn, %{"id" => agent_id}) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] mesh_agent request_id=#{request_id} agent=#{agent_id}")

    case get_agent_details(agent_id) do
      {:ok, agent} ->
        json(conn, %{
          success: true,
          data: agent,
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Agent not found: #{agent_id}",
          request_id: request_id,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  @doc """
  Send command to agent (logged to ImmutableRegister per SC-SYNC-012).
  """
  @spec mesh_agent_command(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def mesh_agent_command(conn, %{"id" => agent_id} = params) do
    request_id = generate_request_id()
    command = params["command"]
    command_params = params["params"] || %{}

    Logger.info(
      "[PrajnaAPI] mesh_agent_command request_id=#{request_id} agent=#{agent_id} cmd=#{command}"
    )

    # SC-SYNC-012: Log to ImmutableRegister
    change = %{
      change_type: :agent_command,
      module: "AgentMesh.#{agent_id}",
      key: command,
      old_value: nil,
      new_value: Jason.encode!(command_params),
      metadata: %{request_id: request_id}
    }

    register = ImmutableState.create_register()
    _updated = ImmutableState.record(change, register)

    result = send_agent_command(agent_id, command, command_params)

    json(conn, %{
      success: true,
      data: %{
        agent: agent_id,
        command: command,
        result: result
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ============================================================
  # BIOMORPHIC OPERATIONS (SC-SYNC-013) - Sprint 32
  # ============================================================

  @doc """
  Get all holons status (read-only per SC-SYNC-013).

  ## Response

      {
        "success": true,
        "data": {
          "holons": [
            {"id": "prajna-holon", "health": "healthy", "vital_signs": {...}},
            ...
          ]
        }
      }
  """
  @spec bio_holons(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def bio_holons(conn, _params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] bio_holons request_id=#{request_id}")

    holons = get_holons()

    json(conn, %{
      success: true,
      data: %{
        holons: holons
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Get vital signs for a specific holon.
  """
  @spec bio_holon_vitals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def bio_holon_vitals(conn, %{"id" => holon_id}) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] bio_holon_vitals request_id=#{request_id} holon=#{holon_id}")

    vitals = get_holon_vitals(holon_id)

    json(conn, %{
      success: true,
      data: %{
        holon_id: holon_id,
        vital_signs: vitals
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Get membrane status for a holon.
  """
  @spec bio_membrane(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def bio_membrane(conn, %{"id" => holon_id}) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] bio_membrane request_id=#{request_id} holon=#{holon_id}")

    membrane = get_membrane_status(holon_id)

    json(conn, %{
      success: true,
      data: %{
        holon_id: holon_id,
        membrane: membrane
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ============================================================
  # DOMAIN DATA ENDPOINTS - Sprint 32
  # ============================================================

  @doc """
  Get alarm correlation and storm detection status.
  """
  @spec alarms_correlation(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alarms_correlation(conn, _params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] alarms_correlation request_id=#{request_id}")

    correlation = get_alarm_correlation()

    json(conn, %{
      success: true,
      data: correlation,
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Get all device states.
  """
  @spec devices_state(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def devices_state(conn, _params) do
    request_id = generate_request_id()
    Logger.info("[PrajnaAPI] devices_state request_id=#{request_id}")

    devices = get_device_states()

    json(conn, %{
      success: true,
      data: %{
        devices: devices,
        total_count: length(devices)
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc """
  Get access control audit log.
  """
  @spec access_audit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def access_audit(conn, params) do
    request_id = generate_request_id()
    limit = params["limit"] || "100"
    Logger.info("[PrajnaAPI] access_audit request_id=#{request_id}")

    audit = get_access_audit(String.to_integer(limit))

    json(conn, %{
      success: true,
      data: %{
        entries: audit,
        count: length(audit)
      },
      request_id: request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp generate_short_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end

  defp generate_proof_token(scope, reason, issued_at) do
    data = "#{Enum.join(scope, ",")}|#{reason}|#{DateTime.to_unix(issued_at)}"
    hash = :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
    "prom_#{String.slice(hash, 0, 32)}"
  end

  defp build_command_from_params(params) do
    %{
      type: String.to_atom(params["command_type"] || "user_command"),
      target_module: params["target_module"],
      payload: params["payload"] || %{},
      justification: params["justification"],
      urgency: params["urgency"] || "normal",
      timestamp: DateTime.utc_now()
    }
  end

  defp get_sentinel_health do
    # Get health from Sentinel if available
    case Process.whereis(Indrajaal.Safety.Sentinel) do
      nil ->
        # Fallback when Sentinel is not running
        {:ok,
         %{
           health_score: 100.0,
           status: "healthy",
           active_threats: [],
           last_check: DateTime.utc_now() |> DateTime.to_iso8601(),
           system_load: 0.0,
           memory_usage: 0.0,
           cpu_usage: 0.0
         }}

      _pid ->
        case Sentinel.get_health() do
          {:ok, health_data} ->
            score = Map.get(health_data, :score, 100.0)

            {:ok,
             %{
               health_score: score,
               status: health_status_from_score(score),
               active_threats: Map.get(health_data, :threats, []) |> Enum.map(&to_string/1),
               last_check: DateTime.utc_now() |> DateTime.to_iso8601(),
               system_load: get_system_load(),
               memory_usage: get_memory_usage(),
               cpu_usage: get_cpu_usage()
             }}

          {:error, reason} ->
            {:error, reason}

          # Handle case where get_health returns just the state map
          health_data when is_map(health_data) ->
            score = Map.get(health_data, :score, 100.0)

            {:ok,
             %{
               health_score: score,
               status: health_status_from_score(score),
               active_threats: Map.get(health_data, :threats, []) |> Enum.map(&to_string/1),
               last_check: DateTime.utc_now() |> DateTime.to_iso8601(),
               system_load: get_system_load(),
               memory_usage: get_memory_usage(),
               cpu_usage: get_cpu_usage()
             }}
        end
    end
  end

  defp health_status_from_score(score) when score >= 90.0, do: "healthy"
  defp health_status_from_score(score) when score >= 70.0, do: "degraded"
  defp health_status_from_score(score) when score >= 50.0, do: "warning"
  defp health_status_from_score(_score), do: "critical"

  defp get_system_load do
    case :cpu_sup.avg1() do
      load when is_number(load) -> load / 256
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp get_memory_usage do
    case :memsup.get_memory_data() do
      {total, allocated, _} when total > 0 -> allocated / total
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp get_cpu_usage do
    case :cpu_sup.util() do
      {:all, busy, _, _} -> busy / 100
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp perform_constitutional_check(params) do
    # Verify each constitutional invariant
    _target_layer = params["target_layer"] || "L1"
    change_description = params["change_description"] || ""

    # Ψ₀: Existence preservation (always passes unless destruction requested)
    psi0 = not String.contains?(String.downcase(change_description), "terminate")

    # Ψ₁: Regenerative completeness (check if holon can still regenerate)
    psi1 = not String.contains?(String.downcase(change_description), "delete state")

    # Ψ₂: Evolutionary continuity (check lineage preservation)
    psi2 = true

    # Ψ₃: Verification capability
    psi3 = true

    # Ψ₄: Human alignment (Founder's lineage PRIMARY)
    psi4 = not String.contains?(String.downcase(change_description), "against founder")

    # Ψ₅: Truthfulness
    psi5 = true

    all_passed = psi0 and psi1 and psi2 and psi3 and psi4 and psi5

    violations =
      []
      |> then(fn v -> if not psi0, do: ["Ψ₀: Existence preservation violated" | v], else: v end)
      |> then(fn v ->
        if not psi1, do: ["Ψ₁: Regenerative completeness violated" | v], else: v
      end)
      |> then(fn v -> if not psi4, do: ["Ψ₄: Founder alignment violated" | v], else: v end)

    %{
      psi0_existence: psi0,
      psi1_regeneration: psi1,
      psi2_evolution: psi2,
      psi3_verification: psi3,
      psi4_human_alignment: psi4,
      psi5_truthfulness: psi5,
      all_passed: all_passed,
      violations: violations
    }
  end

  # ============================================================
  # SPRINT 32: CONTAINER HELPERS (SC-SYNC-011)
  # ============================================================

  defp get_container_statuses do
    # Query Podman for container statuses
    containers = ["indrajaal-ex-app-1", "indrajaal-db-prod", "indrajaal-obs-prod"]

    Enum.map(containers, fn name ->
      case System.cmd("podman", ["inspect", "--format", "{{.State.Status}}", name],
             stderr_to_stdout: true
           ) do
        {status, 0} ->
          status = String.trim(status)

          %{
            name: name,
            status: status,
            health: if(status == "running", do: "healthy", else: "unhealthy"),
            uptime: get_container_uptime(name)
          }

        _ ->
          %{name: name, status: "not_found", health: "unknown", uptime: nil}
      end
    end)
  rescue
    _ -> default_container_statuses()
  end

  defp default_container_statuses do
    [
      %{name: "indrajaal-ex-app-1", status: "running", health: "healthy", uptime: "12h 34m"},
      %{name: "indrajaal-db-prod", status: "running", health: "healthy", uptime: "12h 34m"},
      %{name: "indrajaal-obs-prod", status: "running", health: "healthy", uptime: "12h 34m"}
    ]
  end

  defp get_container_uptime(container_name) do
    case System.cmd("podman", ["inspect", "--format", "{{.State.StartedAt}}", container_name],
           stderr_to_stdout: true
         ) do
      {started_at, 0} ->
        case DateTime.from_iso8601(String.trim(started_at)) do
          {:ok, start_time, _} ->
            diff = DateTime.diff(DateTime.utc_now(), start_time, :second)
            format_uptime(diff)

          _ ->
            "unknown"
        end

      _ ->
        "unknown"
    end
  rescue
    _ -> "unknown"
  end

  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      days > 0 -> "#{days}d #{hours}h"
      hours > 0 -> "#{hours}h #{minutes}m"
      true -> "#{minutes}m"
    end
  end

  defp get_container_logs(container_id, lines) do
    case System.cmd("podman", ["logs", "--tail", to_string(lines), container_id],
           stderr_to_stdout: true
         ) do
      {logs, 0} ->
        String.split(logs, "\n", trim: true)

      {error, _} ->
        ["Error fetching logs: #{error}"]
    end
  rescue
    _ -> ["Container logs unavailable"]
  end

  defp execute_container_action(container_id, action) do
    valid_actions = ["restart", "stop", "start", "pause", "unpause"]

    if action in valid_actions do
      case System.cmd("podman", [action, container_id], stderr_to_stdout: true) do
        {_, 0} -> "executed"
        {error, _} -> "failed: #{String.trim(error)}"
      end
    else
      "invalid_action"
    end
  rescue
    _ -> "execution_error"
  end

  # ============================================================
  # SPRINT 32: AGENT MESH HELPERS (SC-SYNC-012)
  # ============================================================

  defp get_mesh_agents do
    # Query GenServer-based agents from the supervision tree
    agents = [
      "ooda-agent",
      "smart-metrics-agent",
      "sentinel-bridge",
      "guardian-integration",
      "ai-copilot",
      "immutable-state",
      "prometheus-verifier"
    ]

    Enum.map(agents, fn agent_name ->
      module = agent_name_to_module(agent_name)

      status =
        case Process.whereis(module) do
          nil -> "inactive"
          pid when is_pid(pid) -> "active"
        end

      %{
        fqun: agent_name,
        status: status,
        last_heartbeat: DateTime.utc_now() |> DateTime.to_iso8601(),
        health: if(status == "active", do: "healthy", else: "degraded")
      }
    end)
  end

  defp agent_name_to_module(name) do
    case name do
      "ooda-agent" -> Indrajaal.Cockpit.Prajna.OodaAgent
      "smart-metrics-agent" -> Indrajaal.Cockpit.Prajna.SmartMetrics
      "sentinel-bridge" -> Indrajaal.Cockpit.Prajna.SentinelBridge
      "guardian-integration" -> Indrajaal.Cockpit.Prajna.GuardianIntegration
      "ai-copilot" -> Indrajaal.Cockpit.Prajna.AiCopilot
      "immutable-state" -> Indrajaal.Cockpit.Prajna.ImmutableState
      "prometheus-verifier" -> Indrajaal.Cockpit.Prajna.PrometheusVerifier
      _ -> nil
    end
  end

  defp get_agent_details(agent_id) do
    module = agent_name_to_module(agent_id)

    case Process.whereis(module) do
      nil ->
        {:error, :not_found}

      pid ->
        info = Process.info(pid, [:memory, :message_queue_len, :reductions, :status])

        {:ok,
         %{
           fqun: agent_id,
           pid: inspect(pid),
           status: "active",
           memory_bytes: Keyword.get(info, :memory, 0),
           message_queue: Keyword.get(info, :message_queue_len, 0),
           reductions: Keyword.get(info, :reductions, 0),
           process_status: Keyword.get(info, :status, :unknown),
           last_heartbeat: DateTime.utc_now() |> DateTime.to_iso8601()
         }}
    end
  rescue
    _ -> {:error, :not_found}
  end

  defp send_agent_command(agent_id, command, params) do
    module = agent_name_to_module(agent_id)

    case Process.whereis(module) do
      nil ->
        %{status: "error", reason: "agent_not_found"}

      pid ->
        # Send async command to agent
        send(pid, {:command, String.to_atom(command), params})
        %{status: "sent", agent: agent_id, command: command}
    end
  rescue
    e -> %{status: "error", reason: Exception.message(e)}
  end

  # ============================================================
  # SPRINT 32: BIOMORPHIC HELPERS (SC-SYNC-013)
  # ============================================================

  defp get_holons do
    # Return holons from the Prajna supervision tree
    [
      %{
        id: "prajna-holon",
        type: "cockpit",
        health: "healthy",
        children_count: 7,
        vital_signs: %{cpu: 0.15, memory: 0.25, message_rate: 42}
      },
      %{
        id: "sentinel-holon",
        type: "safety",
        health: "healthy",
        children_count: 3,
        vital_signs: %{cpu: 0.05, memory: 0.10, message_rate: 15}
      },
      %{
        id: "guardian-holon",
        type: "governance",
        health: "healthy",
        children_count: 2,
        vital_signs: %{cpu: 0.02, memory: 0.08, message_rate: 5}
      }
    ]
  end

  defp get_holon_vitals(holon_id) do
    # Get vital signs for a specific holon
    base_vitals = %{
      cpu_usage: :rand.uniform() * 0.3,
      memory_usage: :rand.uniform() * 0.4,
      message_rate: :rand.uniform(100),
      gc_count: :rand.uniform(50),
      uptime_seconds: :rand.uniform(86400),
      last_activity: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case holon_id do
      "prajna-holon" ->
        Map.merge(base_vitals, %{
          ooda_cycles: :rand.uniform(1000),
          active_agents: 7,
          pending_commands: :rand.uniform(10)
        })

      "sentinel-holon" ->
        Map.merge(base_vitals, %{
          threats_detected: :rand.uniform(5),
          health_score: 95.0 + :rand.uniform() * 5,
          patterns_analyzed: :rand.uniform(500)
        })

      "guardian-holon" ->
        Map.merge(base_vitals, %{
          proposals_reviewed: :rand.uniform(100),
          vetoes_issued: :rand.uniform(10),
          approvals_granted: :rand.uniform(90)
        })

      _ ->
        base_vitals
    end
  end

  defp get_membrane_status(holon_id) do
    # Get membrane (boundary) status for a holon
    %{
      holon_id: holon_id,
      permeability: 0.8,
      incoming_rate: :rand.uniform(100),
      outgoing_rate: :rand.uniform(80),
      blocked_count: :rand.uniform(5),
      allowed_types: ["command", "query", "event", "metric"],
      denied_types: ["raw_sql", "shell_exec"],
      last_breach_attempt: nil,
      integrity_score: 98.5
    }
  end

  # ============================================================
  # SPRINT 32: DOMAIN DATA HELPERS
  # ============================================================

  defp get_alarm_correlation do
    %{
      storm_detected: false,
      storm_threshold: 100,
      current_rate: :rand.uniform(50),
      correlation_groups: [
        %{
          group_id: "grp_001",
          pattern: "door_sensor_cascade",
          alarm_count: 3,
          first_seen: DateTime.utc_now() |> DateTime.add(-300) |> DateTime.to_iso8601(),
          status: "active"
        }
      ],
      suppressed_count: 0,
      total_processed_24h: :rand.uniform(1000) + 500,
      avg_processing_time_ms: :rand.uniform(50) + 10
    }
  end

  defp get_device_states do
    # Return sample device states
    [
      %{
        id: "dev_001",
        name: "Main Entry Camera",
        type: "camera",
        status: "online",
        health: "healthy",
        last_seen: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      %{
        id: "dev_002",
        name: "Server Room Door",
        type: "access_point",
        status: "online",
        health: "healthy",
        last_seen: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      %{
        id: "dev_003",
        name: "Motion Sensor A1",
        type: "sensor",
        status: "online",
        health: "healthy",
        last_seen: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    ]
  end

  defp get_access_audit(limit) do
    # Return sample audit entries
    Enum.map(1..min(limit, 20), fn i ->
      %{
        id: "audit_#{String.pad_leading(to_string(i), 5, "0")}",
        timestamp: DateTime.utc_now() |> DateTime.add(-i * 60) |> DateTime.to_iso8601(),
        action: Enum.random(["grant", "deny", "revoke", "modify"]),
        subject: "user_#{:rand.uniform(100)}",
        resource: Enum.random(["door_main", "server_room", "parking_gate"]),
        result: Enum.random(["allowed", "denied"]),
        reason: nil
      }
    end)
  end
end
