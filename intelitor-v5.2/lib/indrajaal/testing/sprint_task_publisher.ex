defmodule Indrajaal.Testing.SprintTaskPublisher do
  @moduledoc """
  Publisher for sprint task lifecycle events via Zenoh.

  Implements criticality-based execution plan with Zenoh control for 18 sprint
  tasks across 6 execution waves with Jidoka quality gates.

  ## STAMP Constraints
  - SC-ZTEST-001: All checkpoints have unique topics
  - SC-ZTEST-003: Publish latency < 10ms (async Task.start)
  - SC-ZTEST-004: Non-blocking publishing
  - SC-ZTEST-008: Log fallback when Zenoh unavailable

  ## Task State Vector
  6-dimensional: [design, implement, test, integrate, verify, deploy]
  TaskComplete(S) iff product(s_i for i=1..6) = 1

  ## Wave Execution Order
  - Wave 0: Foundations (42.1, 42.4, 44.2, 46.1) - P0
  - Wave 1: Core Logic (43.1.1, 46.2, 42.2) - P0/P1
  - Wave 2: Integration (43.1.2, 43.1.3, 43.1.4, 44.1, 44.3) - P1
  - Wave 3: Higher-Order (45.1, 46.3, 42.3) - P1/P2
  - Wave 4: Verification (45.2, 46.4) - P1/P2
  - Wave 5: Rollup (43.1.0) - P0

  ## Checkpoint Domains
  - HOLON: Sprint 42 (CP-HOLON-01..04)
  - FVAL: Sprint 43 (CP-FVAL-01..05)
  - VALD: Sprint 44 (CP-VALD-01..03)
  - PLAN: Sprint 45 (CP-PLAN-01..02)
  - FPPS: Sprint 46 (CP-FPPS-01..04)
  """

  alias Indrajaal.Testing.CheckpointMessages

  require Logger

  # ============================================================
  # TASK REGISTRY
  # ============================================================

  @task_registry %{
    "42.1.0.0.0" => %{
      checkpoint: "CP-HOLON-01",
      sprint: 42,
      task_key: "42-1",
      priority: :p0,
      wave: 0,
      title: "Biological Substrate (L0-L5)"
    },
    "42.2.0.0.0" => %{
      checkpoint: "CP-HOLON-02",
      sprint: 42,
      task_key: "42-2",
      priority: :p1,
      wave: 1,
      title: "Social Organism (L6-L7)"
    },
    "42.3.0.0.0" => %{
      checkpoint: "CP-HOLON-03",
      sprint: 42,
      task_key: "42-3",
      priority: :p2,
      wave: 3,
      title: "Cosmic Imperative (L8-L9)"
    },
    "42.4.0.0.0" => %{
      checkpoint: "CP-HOLON-04",
      sprint: 42,
      task_key: "42-4",
      priority: :p0,
      wave: 0,
      title: "Great Renaming (ZKMS->SMRITI) [complete]"
    },
    "43.1.0.0.0" => %{
      checkpoint: "CP-FVAL-01",
      sprint: 43,
      task_key: "43-1-0",
      priority: :p0,
      wave: 5,
      title: "F# Validator (Parent)"
    },
    "43.1.1.0.0" => %{
      checkpoint: "CP-FVAL-02",
      sprint: 43,
      task_key: "43-1-1",
      priority: :p0,
      wave: 1,
      title: "Core Logic (F#)"
    },
    "43.1.2.0.0" => %{
      checkpoint: "CP-FVAL-03",
      sprint: 43,
      task_key: "43-1-2",
      priority: :p1,
      wave: 2,
      title: "AI Augmentation"
    },
    "43.1.3.0.0" => %{
      checkpoint: "CP-FVAL-04",
      sprint: 43,
      task_key: "43-1-3",
      priority: :p1,
      wave: 2,
      title: "Orchestration & Supervision"
    },
    "43.1.4.0.0" => %{
      checkpoint: "CP-FVAL-05",
      sprint: 43,
      task_key: "43-1-4",
      priority: :p1,
      wave: 2,
      title: "Telemetry & Observability"
    },
    "44.1.0.0.0" => %{
      checkpoint: "CP-VALD-01",
      sprint: 44,
      task_key: "44-1",
      priority: :p1,
      wave: 2,
      title: "Multiline & Context Awareness"
    },
    "44.2.0.0.0" => %{
      checkpoint: "CP-VALD-02",
      sprint: 44,
      task_key: "44-2",
      priority: :p0,
      wave: 0,
      title: "Full Zenoh Implementation"
    },
    "44.3.0.0.0" => %{
      checkpoint: "CP-VALD-03",
      sprint: 44,
      task_key: "44-3",
      priority: :p1,
      wave: 2,
      title: "Smriti Reality"
    },
    "45.1.0.0.0" => %{
      checkpoint: "CP-PLAN-01",
      sprint: 45,
      task_key: "45-1",
      priority: :p1,
      wave: 3,
      title: "Scaffolding & Core Logic"
    },
    "45.2.0.0.0" => %{
      checkpoint: "CP-PLAN-02",
      sprint: 45,
      task_key: "45-2",
      priority: :p2,
      wave: 4,
      title: "Verification & Cutover"
    },
    "46.1.0.0.0" => %{
      checkpoint: "CP-FPPS-01",
      sprint: 46,
      task_key: "46-1",
      priority: :p0,
      wave: 0,
      title: "Regex Pattern Migration"
    },
    "46.2.0.0.0" => %{
      checkpoint: "CP-FPPS-02",
      sprint: 46,
      task_key: "46-2",
      priority: :p0,
      wave: 1,
      title: "5-Method Consensus Engine"
    },
    "46.3.0.0.0" => %{
      checkpoint: "CP-FPPS-03",
      sprint: 46,
      task_key: "46-3",
      priority: :p2,
      wave: 3,
      title: "Cognitive Integration (L6/L7)"
    },
    "46.4.0.0.0" => %{
      checkpoint: "CP-FPPS-04",
      sprint: 46,
      task_key: "46-4",
      priority: :p1,
      wave: 4,
      title: "FPPS Verification"
    }
  }

  # Dependency DAG: task_id => list of prerequisite task_ids
  @dependency_dag %{
    "42.2.0.0.0" => ["42.1.0.0.0"],
    "42.3.0.0.0" => ["42.2.0.0.0"],
    "43.1.0.0.0" => ["43.1.1.0.0", "43.1.2.0.0", "43.1.3.0.0", "43.1.4.0.0"],
    "43.1.2.0.0" => ["43.1.1.0.0"],
    "43.1.3.0.0" => ["43.1.1.0.0"],
    "43.1.4.0.0" => ["43.1.1.0.0", "44.2.0.0.0"],
    "44.1.0.0.0" => ["43.1.1.0.0"],
    "44.3.0.0.0" => ["42.1.0.0.0", "42.4.0.0.0"],
    "45.1.0.0.0" => ["44.3.0.0.0"],
    "45.2.0.0.0" => ["45.1.0.0.0"],
    "46.2.0.0.0" => ["46.1.0.0.0"],
    "46.3.0.0.0" => ["46.2.0.0.0", "43.1.2.0.0"],
    "46.4.0.0.0" => ["46.1.0.0.0", "46.2.0.0.0", "46.3.0.0.0"]
  }

  # Wave definitions with Jidoka gate requirements
  @waves %{
    0 => %{tasks: ["42.1.0.0.0", "42.4.0.0.0", "44.2.0.0.0", "46.1.0.0.0"], gate: "CP-WAVE-G0"},
    1 => %{tasks: ["43.1.1.0.0", "46.2.0.0.0", "42.2.0.0.0"], gate: "CP-WAVE-G1"},
    2 => %{
      tasks: ["43.1.2.0.0", "43.1.3.0.0", "43.1.4.0.0", "44.1.0.0.0", "44.3.0.0.0"],
      gate: "CP-WAVE-G2"
    },
    3 => %{tasks: ["45.1.0.0.0", "46.3.0.0.0", "42.3.0.0.0"], gate: "CP-WAVE-G3"},
    4 => %{tasks: ["45.2.0.0.0", "46.4.0.0.0"], gate: "CP-WAVE-G4"},
    5 => %{tasks: ["43.1.0.0.0"], gate: "CP-WAVE-FINAL"}
  }

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc "Get the task registry."
  def task_registry, do: @task_registry

  @doc "Get the dependency DAG."
  def dependency_dag, do: @dependency_dag

  @doc "Get the wave definitions."
  def waves, do: @waves

  @doc "Get task info by task_id."
  def task_info(task_id), do: Map.get(@task_registry, task_id)

  @doc "Get tasks for a specific wave."
  def tasks_for_wave(wave_id), do: get_in(@waves, [wave_id, :tasks]) || []

  @doc "Get dependencies for a task."
  def dependencies(task_id), do: Map.get(@dependency_dag, task_id, [])

  @doc "Check if all dependencies are satisfied for a task."
  def dependencies_satisfied?(task_id, completed_tasks) do
    dependencies(task_id)
    |> Enum.all?(&MapSet.member?(completed_tasks, &1))
  end

  # ============================================================
  # TASK LIFECYCLE PUBLISHERS
  # ============================================================

  @doc "Publish task started event."
  def task_started(task_id) do
    case Map.get(@task_registry, task_id) do
      nil ->
        Logger.warning("[SprintTaskPublisher] Unknown task: #{task_id}")
        {:error, :unknown_task}

      info ->
        message =
          CheckpointMessages.build_task_started(
            task_id,
            info.wave,
            to_string(info.priority),
            info.title
          )

        topic = CheckpointMessages.sprint_task_topic(info.sprint, info.task_key, "start")

        log_fallback(topic, info.checkpoint, "task_started", "[0,0,0,0,0,0]")
        emit_telemetry(:task_started, task_id, message)
        publish(topic, message)
    end
  end

  @doc "Publish task progress event with updated state vector."
  def task_progress(task_id, state_vector, progress_pct, details \\ %{}) do
    case Map.get(@task_registry, task_id) do
      nil ->
        {:error, :unknown_task}

      info ->
        message =
          CheckpointMessages.build_task_progress(
            task_id,
            info.checkpoint,
            state_vector,
            progress_pct,
            details
          )

        topic = CheckpointMessages.sprint_task_topic(info.sprint, info.task_key, "progress")

        log_fallback(topic, info.checkpoint, "task_progress", state_vector)
        emit_telemetry(:task_progress, task_id, message)
        publish(topic, message)
    end
  end

  @doc "Publish task completed event."
  def task_completed(task_id, duration_ms) do
    case Map.get(@task_registry, task_id) do
      nil ->
        {:error, :unknown_task}

      info ->
        state_vector = "[1,1,1,1,1,1]"

        message =
          CheckpointMessages.build_task_completed(
            task_id,
            info.checkpoint,
            duration_ms,
            state_vector
          )

        topic = CheckpointMessages.sprint_task_topic(info.sprint, info.task_key, "complete")

        log_fallback(topic, info.checkpoint, "task_completed", state_vector)
        emit_telemetry(:task_completed, task_id, message)
        publish(topic, message)

        # Also publish to verify topic
        verify_topic = CheckpointMessages.sprint_task_topic(info.sprint, info.task_key, "verify")
        publish(verify_topic, message)
    end
  end

  @doc "Publish task failed event."
  def task_failed(task_id, reason) do
    case Map.get(@task_registry, task_id) do
      nil ->
        {:error, :unknown_task}

      info ->
        state_vector = "[0,0,0,0,0,0]"

        message =
          CheckpointMessages.build_task_failed(
            task_id,
            info.checkpoint,
            reason,
            state_vector
          )

        topic = CheckpointMessages.sprint_task_topic(info.sprint, info.task_key, "failed")

        log_fallback(topic, info.checkpoint, "task_failed", state_vector)
        emit_telemetry(:task_failed, task_id, message)
        publish(topic, message)
    end
  end

  # ============================================================
  # WAVE LIFECYCLE PUBLISHERS
  # ============================================================

  @doc "Publish wave started event."
  def wave_started(wave_id) do
    tasks = tasks_for_wave(wave_id)
    topic = CheckpointMessages.sprint_wave_topic(wave_id, "start")

    message = %{
      schema_version: CheckpointMessages.schema_version(),
      message_id: generate_uuid(),
      type: "wave_started",
      wave: wave_id,
      tasks: tasks,
      task_count: length(tasks),
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }

    log_fallback(topic, "CP-WAVE-#{wave_id}", "wave_started", "")
    publish(topic, message)
  end

  @doc "Publish wave completed event."
  def wave_completed(wave_id, duration_ms) do
    topic = CheckpointMessages.sprint_wave_topic(wave_id, "complete")

    message = %{
      schema_version: CheckpointMessages.schema_version(),
      message_id: generate_uuid(),
      type: "wave_completed",
      wave: wave_id,
      duration_ms: duration_ms,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }

    log_fallback(topic, "CP-WAVE-#{wave_id}", "wave_completed", "")
    publish(topic, message)
  end

  @doc """
  Publish Jidoka gate evaluation result.

  Gate results must include :compilation, :tests, :coverage, :fpps_consensus,
  :fsharp_build, :task_checkpoints, and :state_vector.
  """
  def wave_gate(wave_id, results) do
    gate_id = get_in(@waves, [wave_id, :gate]) || "CP-WAVE-G#{wave_id}"
    message = CheckpointMessages.build_sprint_gate(gate_id, wave_id, results)
    topic = CheckpointMessages.sprint_wave_topic(wave_id, "gate")

    log_fallback(topic, gate_id, "sprint_gate", Map.get(results, :state_vector, ""))
    emit_telemetry(:wave_gate, wave_id, message)
    publish(topic, message)
  end

  # ============================================================
  # QUERY API
  # ============================================================

  @doc "Get all P0 critical tasks."
  def critical_tasks do
    @task_registry
    |> Enum.filter(fn {_id, info} -> info.priority == :p0 end)
    |> Enum.sort_by(fn {_id, info} -> info.wave end)
  end

  @doc "Get tasks grouped by wave."
  def tasks_by_wave do
    @task_registry
    |> Enum.group_by(fn {_id, info} -> info.wave end)
    |> Enum.sort_by(fn {wave, _tasks} -> wave end)
  end

  @doc "Get the critical path (longest dependency chain)."
  def critical_path do
    # Two critical paths: holon chain and FPPS chain
    [
      ["42.1.0.0.0", "44.3.0.0.0", "45.1.0.0.0", "45.2.0.0.0"],
      ["46.1.0.0.0", "46.2.0.0.0", "46.3.0.0.0", "46.4.0.0.0"]
    ]
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
        e -> Logger.debug("[SprintTaskPublisher] Publish failed: #{inspect(e)}")
      end
    end)

    :ok
  end

  defp do_publish(topic, payload) do
    case Code.ensure_loaded(Indrajaal.Observability.ZenohSession) do
      {:module, mod} ->
        mod.publish(topic, payload)

      _ ->
        Logger.debug("[SprintTaskPublisher] ZenohSession not available, topic: #{topic}")
    end
  end

  # SC-ZTEST-008: Log fallback ALWAYS written before Zenoh attempt
  defp log_fallback(topic, checkpoint_id, type, state_vector) do
    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=#{checkpoint_id} topic=#{topic} type=#{type} state_vector=#{state_vector} timestamp=#{timestamp()}",
      domain: :zenoh_sprint
    )
  end

  defp emit_telemetry(event, id, data) do
    :telemetry.execute(
      [:indrajaal, :sprint, :task, event],
      %{timestamp: System.monotonic_time(:microsecond)},
      Map.merge(data, %{id: id})
    )
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
