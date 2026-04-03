defmodule Indrajaal.Boot.ZenohBootPublisher do
  @moduledoc """
  Publisher for boot phase transitions to Zenoh.

  ## STAMP Constraints
  - SC-ZTEST-009: Publish on every phase transition
  - SC-ZTEST-010: Include state vector in every message
  - SC-ZTEST-011: Quorum status within 1s of change

  ## Checkpoints Published
  - CP-BOOT-01: Preflight start
  - CP-BOOT-02: Preflight complete
  - CP-BOOT-03: DB ready
  - CP-BOOT-04: Observability ready
  - CP-BOOT-05: Zenoh quorum achieved
  - CP-BOOT-06: CEPAF bridge connected
  - CP-BOOT-07: Cortex online
  - CP-BOOT-08: App seed ready
  - CP-BOOT-09: Homeostasis verified
  - CP-BOOT-10: Boot complete

  ## Usage
  ```elixir
  ZenohBootPublisher.phase_started(:preflight, 0, [])
  ZenohBootPublisher.container_health("indrajaal-db-prod", true, 234, "PostgreSQL ready")
  ZenohBootPublisher.quorum_achieved(2, 3, routers)
  ZenohBootPublisher.phase_finished(:preflight, 0, 5000, true)
  ```
  """

  alias Indrajaal.Testing.CheckpointMessages

  require Logger

  # ============================================================
  # PHASE EVENTS
  # ============================================================

  @doc """
  Publish phase started event.

  ## Parameters
  - phase: :preflight | :foundation | :mesh | :cognitive | :app | :homeostasis | :swarm
  - wave: Wave number (1-5)
  - containers: List of containers in this phase
  - state_vector: Optional state vector string
  """
  def phase_started(phase, wave, containers, state_vector \\ "[0,0,0,0,0,0]") do
    checkpoint_id = phase_to_start_checkpoint(phase)
    topic = checkpoint_to_topic(checkpoint_id, phase, "start")

    message =
      CheckpointMessages.build_boot_checkpoint(checkpoint_id, %{
        phase: to_string(phase),
        wave: wave,
        containers: containers,
        state_vector: state_vector
      })

    publish(topic, message)
  end

  @doc """
  Publish phase finished event.

  ## Parameters
  - phase: Phase atom
  - wave: Wave number
  - duration_ms: Phase duration in milliseconds
  - success: Boolean indicating success
  - state_vector: Updated state vector
  """
  def phase_finished(phase, wave, duration_ms, success, state_vector \\ "[1,1,1,1,1,1]") do
    checkpoint_id = phase_to_complete_checkpoint(phase)
    topic = checkpoint_to_topic(checkpoint_id, phase, "complete")

    message =
      CheckpointMessages.build_boot_checkpoint(checkpoint_id, %{
        phase: to_string(phase),
        wave: wave,
        duration_ms: duration_ms,
        success: success,
        state_vector: state_vector
      })

    publish(topic, message)
  end

  # ============================================================
  # CONTAINER EVENTS
  # ============================================================

  @doc "Publish container started event."
  def container_started(container_name, wave, port) do
    message = CheckpointMessages.build_container_started(container_name, wave, port)
    topic = CheckpointMessages.container_topic(container_name, "started")
    publish(topic, message)
  end

  @doc "Publish container health check event."
  def container_health(container_name, healthy, duration_ms, details) do
    message =
      CheckpointMessages.build_container_health(container_name, healthy, duration_ms, details)

    topic = CheckpointMessages.container_topic(container_name, "health")
    publish(topic, message)
  end

  @doc "Publish container ready event."
  def container_ready(container_name, healthy) do
    message = %{
      schema_version: CheckpointMessages.schema_version(),
      message_id: generate_uuid(),
      type: "container_ready",
      checkpoint: "CP-BOOT-TX-05",
      container: container_name,
      healthy: healthy,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }

    topic = CheckpointMessages.container_topic(container_name, "ready")
    publish(topic, message)
  end

  # ============================================================
  # QUORUM EVENTS
  # ============================================================

  @doc """
  Publish quorum status update.

  ## Parameters
  - status: "Achieved" | "NotAchieved" | "InsufficientNodes"
  - healthy_count: Number of healthy routers
  - total_count: Total number of routers
  - routers: List of router status maps
  """
  def quorum_status(status, healthy_count, total_count, routers) do
    message = CheckpointMessages.build_quorum_status(status, healthy_count, total_count, routers)
    publish("indrajaal/boot/mesh/quorum", message)
  end

  @doc "Shorthand for quorum achieved event."
  def quorum_achieved(healthy_count, total_count, routers) do
    quorum_status("Achieved", healthy_count, total_count, routers)

    # Also publish the checkpoint message
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-05", %{
        healthy: healthy_count,
        total: total_count,
        routers: Enum.map(routers, & &1.name)
      })

    publish("indrajaal/boot/mesh/quorum", message)
  end

  # ============================================================
  # STATE VECTOR EVENTS
  # ============================================================

  @doc """
  Publish state vector update.

  ## Parameters
  - vector: String representation like "[1,1,0,0,0,0]"
  - components: Map of component states
  """
  def state_vector(vector, components) do
    message = CheckpointMessages.build_state_vector(vector, components)
    publish("indrajaal/boot/state_vector", message)
  end

  # ============================================================
  # SPECIFIC CHECKPOINT SHORTCUTS
  # ============================================================

  @doc "Publish preflight start."
  def preflight_start(state_vector \\ "[0,0,0,0,0,0]") do
    phase_started(:preflight, 0, [], state_vector)
  end

  @doc "Publish preflight complete."
  def preflight_complete(duration_ms, state_vector \\ "[1,0,0,0,0,0]") do
    phase_finished(:preflight, 0, duration_ms, true, state_vector)
  end

  @doc "Publish database ready."
  def db_ready(duration_ms) do
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-03", %{
        port: 5433,
        duration_ms: duration_ms,
        healthy: true
      })

    publish("indrajaal/boot/foundation/db_ready", message)
  end

  @doc "Publish observability ready."
  def obs_ready(duration_ms) do
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-04", %{
        ports: [4317, 4318, 9090, 3000, 3100],
        duration_ms: duration_ms,
        healthy: true
      })

    publish("indrajaal/boot/foundation/obs_ready", message)
  end

  @doc "Publish CEPAF bridge connected."
  def bridge_connected(duration_ms) do
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-06", %{
        port: 9876,
        duration_ms: duration_ms
      })

    publish("indrajaal/boot/cognitive/bridge", message)
  end

  @doc "Publish Cortex online."
  def cortex_online(duration_ms) do
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-07", %{
        port: 9877,
        duration_ms: duration_ms
      })

    publish("indrajaal/boot/cognitive/cortex", message)
  end

  @doc "Publish app seed ready."
  def app_ready(container_name, duration_ms) do
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-08", %{
        container: container_name,
        port: 4000,
        duration_ms: duration_ms
      })

    publish("indrajaal/boot/app/seed_ready", message)
  end

  @doc "Publish homeostasis verified."
  def homeostasis_verified(health_checks) do
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-09", %{
        checks: health_checks,
        all_healthy: Enum.all?(health_checks, fn {_, v} -> v end)
      })

    publish("indrajaal/boot/homeostasis/verified", message)
  end

  @doc "Publish boot complete."
  def boot_complete(total_duration_ms, container_count, state_vector) do
    message =
      CheckpointMessages.build_boot_checkpoint("CP-BOOT-10", %{
        total_duration_ms: total_duration_ms,
        containers: container_count,
        state_vector: state_vector,
        status: "operational"
      })

    publish("indrajaal/boot/complete", message)
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp publish(topic, message) do
    Task.start(fn ->
      try do
        payload = Jason.encode!(message)
        do_publish(topic, payload)
      rescue
        e ->
          Logger.debug("[ZenohBootPublisher] Publish failed: #{inspect(e)}")
      end
    end)

    :ok
  end

  defp do_publish(topic, payload) do
    # SC-ZTEST-008: ALWAYS write log fallback first (guaranteed durability before Zenoh attempt)
    checkpoint = extract_checkpoint(payload)
    type = extract_type(payload)

    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=#{checkpoint} topic=#{topic} type=#{type} payload=#{payload}"
    )

    # Then attempt Zenoh publish (best-effort real-time delivery via async)
    case Code.ensure_loaded(Indrajaal.Observability.ZenohSession) do
      {:module, mod} ->
        mod.publish_async(topic, payload)

      _ ->
        Logger.debug(
          "[ZenohBootPublisher] ZenohSession not available, log fallback already written, topic: #{topic}"
        )
    end
  end

  defp extract_checkpoint(payload) do
    case Jason.decode(payload) do
      {:ok, %{"checkpoint" => cp}} -> cp
      _ -> "unknown"
    end
  end

  defp extract_type(payload) do
    case Jason.decode(payload) do
      {:ok, %{"type" => t}} -> t
      _ -> "boot_checkpoint"
    end
  end

  defp phase_to_start_checkpoint(phase) do
    case phase do
      :preflight -> "CP-BOOT-01"
      :foundation -> "CP-BOOT-03"
      :mesh -> "CP-BOOT-05"
      :cognitive -> "CP-BOOT-06"
      :app -> "CP-BOOT-08"
      :homeostasis -> "CP-BOOT-09"
      :swarm -> "CP-BOOT-10"
      _ -> "CP-BOOT-01"
    end
  end

  defp phase_to_complete_checkpoint(phase) do
    case phase do
      :preflight -> "CP-BOOT-02"
      :foundation -> "CP-BOOT-04"
      :mesh -> "CP-BOOT-05"
      :cognitive -> "CP-BOOT-07"
      :app -> "CP-BOOT-08"
      :homeostasis -> "CP-BOOT-09"
      :swarm -> "CP-BOOT-10"
      _ -> "CP-BOOT-02"
    end
  end

  defp checkpoint_to_topic(checkpoint_id, phase, event) do
    case checkpoint_id do
      "CP-BOOT-01" -> "indrajaal/boot/preflight/start"
      "CP-BOOT-02" -> "indrajaal/boot/preflight/complete"
      "CP-BOOT-03" -> "indrajaal/boot/foundation/db_ready"
      "CP-BOOT-04" -> "indrajaal/boot/foundation/obs_ready"
      "CP-BOOT-05" -> "indrajaal/boot/mesh/quorum"
      "CP-BOOT-06" -> "indrajaal/boot/cognitive/bridge"
      "CP-BOOT-07" -> "indrajaal/boot/cognitive/cortex"
      "CP-BOOT-08" -> "indrajaal/boot/app/seed_ready"
      "CP-BOOT-09" -> "indrajaal/boot/homeostasis/verified"
      "CP-BOOT-10" -> "indrajaal/boot/complete"
      _ -> "indrajaal/boot/#{phase}/#{event}"
    end
  end

  defp generate_uuid do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp node_id do
    to_string(Node.self())
  end
end
