defmodule Indrajaal.Observability.ZenohSafetyPublisher do
  @moduledoc """
  Centralized Zenoh publisher for safety-critical events.

  ## WHAT
  Provides dual-write (log + Zenoh) publishing for all safety subsystem events.
  Uses fire-and-forget patterns to never block safety-critical code paths.

  ## WHY
  The ZUIP analysis identified 77 gaps where safety state mutations were
  invisible to the Zenoh mesh. This module closes those gaps for T0/T1
  (survival/safety) tier events.

  ## CONSTRAINTS
  - SC-ZTEST-008: Dual-write — log fallback ALWAYS written first
  - SC-EMR-057: Emergency events use publish_emergency (bypass GenServer)
  - FM-ZUIP-002: Emergency publish never blocks (<5s SLA)
  - FM-ZUIP-001: Non-emergency uses publish_async (fire-and-forget)

  ## Topics
  - `indrajaal/safety/guardian/*` — Guardian decisions and emergencies
  - `indrajaal/safety/sentinel/*` — Threat detection and quarantine
  - `indrajaal/safety/pattern_hunter/*` — Pre-error pattern detection
  - `indrajaal/safety/symbiotic_defense/*` — Defense level changes
  - `indrajaal/safety/circuit_breaker/*` — Circuit breaker state transitions
  - `indrajaal/safety/jidoka/*` — Stop-and-fix events
  - `indrajaal/cluster/apoptosis` — Self-termination events
  - `indrajaal/deployment/dying_gasp` — Last breath checkpoints
  - `indrajaal/deployment/emergency_response` — Emergency stop events
  """

  require Logger
  alias Indrajaal.Observability.ZenohSession

  # ============================================================
  # EMERGENCY TIER (Bypasses GenServer — FM-ZUIP-002)
  # ============================================================

  @doc "Publish Guardian emergency stop event"
  def publish_guardian_emergency_stop(reason) do
    publish_emergency("indrajaal/safety/guardian/emergency_stop", %{
      type: "emergency_stop",
      reason: reason,
      node: node_id(),
      timestamp: timestamp()
    })
  end

  @doc "Publish emergency response peer notification"
  def publish_emergency_response(container_id, reason) do
    publish_emergency("indrajaal/deployment/emergency_response", %{
      type: "emergency_stop",
      container_id: container_id,
      reason: reason,
      node: node_id(),
      timestamp: timestamp()
    })
  end

  @doc "Publish MasterControl emergency event"
  def publish_master_control_emergency(domain, action, result) do
    publish_emergency("indrajaal/governance/master_control/emergency", %{
      type: "emergency_command",
      domain: to_string(domain),
      action: to_string(action),
      result: inspect(result),
      node: node_id(),
      timestamp: timestamp()
    })
  end

  # ============================================================
  # HIGH PRIORITY (Async, :high — never blocks)
  # ============================================================

  @doc "Publish Guardian veto decision"
  def publish_guardian_veto(proposal, reason) do
    publish_async(
      "indrajaal/safety/guardian/veto",
      %{
        type: "veto",
        proposal: inspect(proposal),
        reason: reason,
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish Sentinel threat report"
  def publish_sentinel_threat(threat_type, source, severity, metadata, timestamp \\ nil) do
    publish_async(
      "indrajaal/safety/sentinel/threat",
      %{
        type: "threat_detected",
        # Fractal Alignment
        fractal_layer: "l4_tactical",
        domain: "safety",
        component: "sentinel",
        # Payload
        threat_type: to_string(threat_type),
        source: inspect(source),
        severity: severity,
        metadata: safe_inspect(metadata),
        node: node_id(),
        timestamp: timestamp || timestamp()
      },
      :high
    )
  end

  @doc "Publish Sentinel antibody deployment"
  def publish_antibody_deployment(antibody) do
    publish_async(
      "indrajaal/safety/sentinel/antibody",
      %{
        type: "antibody_deployed",
        # Fractal Alignment
        fractal_layer: "l4_tactical",
        domain: "safety",
        component: "sentinel",
        # Payload
        antibody_id: antibody.id,
        target: to_string(antibody.target),
        action: to_string(antibody.action),
        pattern: antibody.pattern,
        ttl_ms: antibody.ttl_ms,
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish Sentinel quarantine event"
  def publish_sentinel_quarantine(pid, reason) do
    publish_async(
      "indrajaal/safety/sentinel/quarantine",
      %{
        type: "quarantine",
        # Fractal Alignment
        fractal_layer: "l4_tactical",
        domain: "safety",
        component: "sentinel",
        # Payload
        process: inspect(pid),
        reason: reason,
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish PatternHunter threat detection"
  def publish_pattern_detected(pattern_type, details) do
    publish_async(
      "indrajaal/safety/pattern_hunter/detection",
      %{
        type: "pattern_detected",
        pattern_type: to_string(pattern_type),
        details: safe_inspect(details),
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish DyingGasp last breath checkpoint"
  def publish_dying_gasp(container_id, checkpoint_data) do
    publish_async(
      "indrajaal/deployment/dying_gasp",
      %{
        type: "dying_gasp",
        container_id: container_id,
        checkpoint_size: safe_inspect(checkpoint_data),
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish SymbioticDefense level change"
  def publish_defense_level_change(old_level, new_level, reason) do
    publish_async(
      "indrajaal/safety/symbiotic_defense/level_change",
      %{
        type: "defense_level_change",
        old_level: to_string(old_level),
        new_level: to_string(new_level),
        reason: reason,
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish CircuitBreaker state transition"
  def publish_circuit_breaker_transition(name, old_state, new_state) do
    publish_async(
      "indrajaal/safety/circuit_breaker/transition",
      %{
        type: "circuit_breaker_transition",
        name: to_string(name),
        old_state: to_string(old_state),
        new_state: to_string(new_state),
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish Jidoka halt event"
  def publish_jidoka_halt(domain, reason) do
    publish_async(
      "indrajaal/safety/jidoka/halt",
      %{
        type: "jidoka_halt",
        domain: to_string(domain),
        reason: reason,
        node: node_id(),
        timestamp: timestamp()
      },
      :high
    )
  end

  @doc "Publish Jidoka resume event"
  def publish_jidoka_resume(domain) do
    publish_async(
      "indrajaal/safety/jidoka/resume",
      %{
        type: "jidoka_resume",
        domain: to_string(domain),
        node: node_id(),
        timestamp: timestamp()
      },
      :normal
    )
  end

  # ============================================================
  # NORMAL PRIORITY (Async, :normal — may be load-shed)
  # ============================================================

  @doc "Publish boot phase checkpoint"
  def publish_boot_checkpoint(phase, status, details \\ %{}) do
    publish_async(
      "indrajaal/deployment/boot/checkpoint",
      %{
        type: "boot_checkpoint",
        phase: to_string(phase),
        status: to_string(status),
        details: safe_inspect(details),
        node: node_id(),
        timestamp: timestamp()
      },
      :normal
    )
  end

  @doc "Publish HealthCoordinator FPPS consensus result"
  def publish_fpps_result(consensus_result, methods) do
    publish_async(
      "indrajaal/deployment/health/fpps",
      %{
        type: "fpps_consensus",
        result: to_string(consensus_result),
        methods: safe_inspect(methods),
        node: node_id(),
        timestamp: timestamp()
      },
      :normal
    )
  end

  @doc "Publish WaveExecutor wave completion"
  def publish_wave_complete(wave_id, status, containers) do
    publish_async(
      "indrajaal/deployment/wave/complete",
      %{
        type: "wave_complete",
        wave_id: wave_id,
        status: to_string(status),
        containers: safe_inspect(containers),
        node: node_id(),
        timestamp: timestamp()
      },
      :normal
    )
  end

  @doc "Publish MasterControl circuit breaker state"
  def publish_master_control_cb(domain, state) do
    publish_async(
      "indrajaal/governance/master_control/circuit_breaker",
      %{
        type: "circuit_breaker_state",
        domain: to_string(domain),
        state: to_string(state),
        node: node_id(),
        timestamp: timestamp()
      },
      :normal
    )
  end

  @doc "Publish ImmutableState block append"
  def publish_immutable_block(block_hash, block_type) do
    publish_async(
      "indrajaal/observability/immutable_state/block",
      %{
        type: "block_appended",
        block_hash: block_hash,
        block_type: to_string(block_type),
        node: node_id(),
        timestamp: timestamp()
      },
      :normal
    )
  end

  @doc "Publish Prajna command audit"
  def publish_prajna_command(domain, action, result) do
    publish_async(
      "indrajaal/governance/prajna/command",
      %{
        type: "command_executed",
        domain: to_string(domain),
        action: to_string(action),
        result: safe_inspect(result),
        node: node_id(),
        timestamp: timestamp()
      },
      :normal
    )
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp publish_emergency(topic, data) do
    # SC-ZTEST-008: Log fallback FIRST
    Logger.critical(
      "[ZTEST-CHECKPOINT] topic=#{topic} type=emergency payload=#{Jason.encode!(data)}"
    )

    ZenohSession.publish_emergency(topic, Jason.encode!(data))
  rescue
    _ -> :ok
  end

  defp publish_async(topic, data, priority) do
    # SC-ZTEST-008: Log fallback FIRST
    log_fn = if priority == :high, do: &Logger.warning/1, else: &Logger.debug/1

    log_fn.("[ZTEST-CHECKPOINT] topic=#{topic} type=#{data[:type]} priority=#{priority}")

    ZenohSession.publish_async(topic, Jason.encode!(data), priority)
  rescue
    _ -> :ok
  end

  defp node_id, do: to_string(Node.self())

  defp timestamp, do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp safe_inspect(data) when is_binary(data), do: data
  defp safe_inspect(data) when is_map(data), do: inspect(data, limit: 200)
  defp safe_inspect(data), do: inspect(data, limit: 200)
end
