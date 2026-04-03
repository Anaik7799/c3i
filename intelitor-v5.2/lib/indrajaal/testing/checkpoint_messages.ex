defmodule Indrajaal.Testing.CheckpointMessages do
  @moduledoc """
  Zenoh message schemas for real-time test feedback system.

  ## Version
  Schema Version: 2.0.0 | Compliance: SC-ZTEST-001 to SC-ZTEST-020

  ## STAMP Constraints (Core)
  - SC-ZTEST-001: All checkpoints have unique topics
  - SC-ZTEST-002: Messages include checkpoint ID (format: CP-{DOMAIN}-{NN})
  - SC-ZTEST-005: Orchestrator aggregate < 100ms
  - SC-ZTEST-006: Boot checkpoints include state vector
  - SC-ZTEST-007: Test failures include full context (≥3 fields)

  ## STAMP Constraints (Extended)
  - SC-ZTEST-012: Message ordering MUST be FIFO per topic
  - SC-ZTEST-013: Checkpoint ID format: CP-{DOMAIN}-{NN}
  - SC-ZTEST-014: Schema version MUST be semver compliant
  - SC-ZTEST-015: Timestamp MUST be ISO 8601 UTC
  - SC-ZTEST-016: Payload size < 64KB

  ## Mathematical Foundations
  - State Vector: $\\vec{S} \\in \\{0,1\\}^6$ [Compile, Migrations, Containers, Zenoh, Health, Quorum]
  - Latency Budget: $L_{total} < 100ms$
  - Quorum: $Q(N) = \\lfloor N/2 \\rfloor + 1$

  ## TDG Properties (Test-Driven Generation)
  - TDG-ZTEST-001: checkpoint_id_gen - Unique IDs
  - TDG-ZTEST-002: state_vector_gen - Valid vectors
  - TDG-ZTEST-004: timestamp_gen - ISO 8601 format

  ## FMEA Mitigations
  - FMEA-ZTEST-001: Zenoh unavailable → Log fallback
  - FMEA-ZTEST-007: Topic collision → Registry validation

  ## Checkpoint Categories
  - CP-BOOT-*: Boot phase checkpoints (01-10)
  - CP-TEST-*: Test phase checkpoints (01-08)
  - CP-SMOKE-*: Smoke test checkpoints (01-08)
  - CP-HOLON-*: Sprint 42 Holon Architecture (01-04)
  - CP-FVAL-*: Sprint 43 F# Validator (01-05)
  - CP-VALD-*: Sprint 44 Validation Enhancement (01-03)
  - CP-PLAN-*: Sprint 45 Planning System (01-02)
  - CP-FPPS-*: Sprint 46 FPPS Evolution (01-04)
  - CP-WAVE-*: Wave Jidoka gates (G0-G4, FINAL)
  - CP-AGENT-*: F# TestAgent lifecycle (01-05)
  - CP-*-TX-*: Transaction messages within phases

  ## Topic Hierarchy
  ```
  indrajaal/
  ├── boot/   - Boot phase events
  ├── test/   - ExUnit test events
  ├── smoke/  - F# smoke test events
  ├── sprint/ - Sprint task lifecycle events
  │   ├── {sprint_id}/task/{task_id}/{start|progress|complete|verify}
  │   └── wave/{wave_id}/{start|complete|gate}
  └── orchestrator/ - Aggregation events
  ```

  ## Related Documents
  - docs/specifications/ZENOH_TEST_MESSAGING_STAMP_COMPLETE.md
  - docs/specifications/ZENOH_TEST_MESSAGING_FMEA_DAG.md
  """

  @schema_version "2.0.0"

  # ============================================================
  # BOOT CHECKPOINTS (CP-BOOT-01 to CP-BOOT-10)
  # ============================================================

  @boot_checkpoints %{
    "CP-BOOT-01" => "indrajaal/boot/preflight/start",
    "CP-BOOT-02" => "indrajaal/boot/preflight/complete",
    "CP-BOOT-03" => "indrajaal/boot/foundation/db_ready",
    "CP-BOOT-04" => "indrajaal/boot/foundation/obs_ready",
    "CP-BOOT-05" => "indrajaal/boot/mesh/quorum",
    "CP-BOOT-06" => "indrajaal/boot/cognitive/bridge",
    "CP-BOOT-07" => "indrajaal/boot/cognitive/cortex",
    "CP-BOOT-08" => "indrajaal/boot/app/seed_ready",
    "CP-BOOT-09" => "indrajaal/boot/homeostasis/verified",
    "CP-BOOT-10" => "indrajaal/boot/complete"
  }

  # ============================================================
  # TEST CHECKPOINTS (CP-TEST-01 to CP-TEST-08)
  # ============================================================

  @test_checkpoints %{
    "CP-TEST-01" => "indrajaal/test/suite/start",
    "CP-TEST-02" => "indrajaal/test/compile/complete",
    "CP-TEST-03" => "indrajaal/test/db/sandbox_ready",
    "CP-TEST-04" => "indrajaal/test/factories/loaded",
    "CP-TEST-05" => "indrajaal/test/module/{name}/start",
    "CP-TEST-06" => "indrajaal/test/module/{name}/complete",
    "CP-TEST-07" => "indrajaal/test/suite/complete",
    "CP-TEST-08" => "indrajaal/test/coverage/report"
  }

  # ============================================================
  # SMOKE TEST CHECKPOINTS (CP-SMOKE-01 to CP-SMOKE-08)
  # ============================================================

  @smoke_checkpoints %{
    "CP-SMOKE-01" => "indrajaal/smoke/batch/start",
    "CP-SMOKE-02" => "indrajaal/smoke/api/complete",
    "CP-SMOKE-03" => "indrajaal/smoke/db/complete",
    "CP-SMOKE-04" => "indrajaal/smoke/zenoh/complete",
    "CP-SMOKE-05" => "indrajaal/smoke/perf/complete",
    "CP-SMOKE-06" => "indrajaal/smoke/security/complete",
    "CP-SMOKE-07" => "indrajaal/smoke/resilience/complete",
    "CP-SMOKE-08" => "indrajaal/smoke/batch/complete"
  }

  # ============================================================
  # SPRINT TASK CHECKPOINTS (CP-HOLON-*, CP-FVAL-*, CP-VALD-*, CP-PLAN-*, CP-FPPS-*)
  # Criticality-based execution plan with Zenoh control
  # ============================================================

  @sprint_checkpoints %{
    # Sprint 42 - Holon Architecture
    "CP-HOLON-01" => "indrajaal/sprint/42/task/42-1/verify",
    "CP-HOLON-02" => "indrajaal/sprint/42/task/42-2/verify",
    "CP-HOLON-03" => "indrajaal/sprint/42/task/42-3/verify",
    "CP-HOLON-04" => "indrajaal/sprint/42/task/42-4/verify",
    # Sprint 43 - F# Validator
    "CP-FVAL-01" => "indrajaal/sprint/43/task/43-1-0/verify",
    "CP-FVAL-02" => "indrajaal/sprint/43/task/43-1-1/verify",
    "CP-FVAL-03" => "indrajaal/sprint/43/task/43-1-2/verify",
    "CP-FVAL-04" => "indrajaal/sprint/43/task/43-1-3/verify",
    "CP-FVAL-05" => "indrajaal/sprint/43/task/43-1-4/verify",
    # Sprint 44 - Validation Enhancement
    "CP-VALD-01" => "indrajaal/sprint/44/task/44-1/verify",
    "CP-VALD-02" => "indrajaal/sprint/44/task/44-2/verify",
    "CP-VALD-03" => "indrajaal/sprint/44/task/44-3/verify",
    # Sprint 45 - Planning System
    "CP-PLAN-01" => "indrajaal/sprint/45/task/45-1/verify",
    "CP-PLAN-02" => "indrajaal/sprint/45/task/45-2/verify",
    # Sprint 46 - FPPS Evolution
    "CP-FPPS-01" => "indrajaal/sprint/46/task/46-1/verify",
    "CP-FPPS-02" => "indrajaal/sprint/46/task/46-2/verify",
    "CP-FPPS-03" => "indrajaal/sprint/46/task/46-3/verify",
    "CP-FPPS-04" => "indrajaal/sprint/46/task/46-4/verify"
  }

  # F# TestAgent lifecycle checkpoints (SC-MCP-TEST-001 to SC-MCP-TEST-004)
  # Published by Cepaf.Testing.TestAgent via ZenohPublish triple-write
  @agent_checkpoints %{
    "CP-AGENT-01" => "indrajaal/regression/agent/start",
    "CP-AGENT-02" => "indrajaal/regression/agent/running",
    "CP-AGENT-03" => "indrajaal/regression/agent/done",
    "CP-AGENT-04" => "indrajaal/regression/agent/stop",
    "CP-AGENT-05" => "indrajaal/regression/agent/error"
  }

  # Wave gate checkpoints
  @wave_checkpoints %{
    "CP-WAVE-G0" => "indrajaal/sprint/wave/0/gate",
    "CP-WAVE-G1" => "indrajaal/sprint/wave/1/gate",
    "CP-WAVE-G2" => "indrajaal/sprint/wave/2/gate",
    "CP-WAVE-G3" => "indrajaal/sprint/wave/3/gate",
    "CP-WAVE-G4" => "indrajaal/sprint/wave/4/gate",
    "CP-WAVE-FINAL" => "indrajaal/sprint/final/gate"
  }

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc "Get the schema version for all messages."
  def schema_version, do: @schema_version

  @doc "Get all boot checkpoint mappings."
  def boot_checkpoints, do: @boot_checkpoints

  @doc "Get all test checkpoint mappings."
  def test_checkpoints, do: @test_checkpoints

  @doc "Get all smoke test checkpoint mappings."
  def smoke_checkpoints, do: @smoke_checkpoints

  @doc "Get all sprint task checkpoint mappings."
  def sprint_checkpoints, do: @sprint_checkpoints

  @doc "Get all wave gate checkpoint mappings."
  def wave_checkpoints, do: @wave_checkpoints

  @doc "Get all F# TestAgent checkpoint mappings."
  def agent_checkpoints, do: @agent_checkpoints

  @doc "Get topic for a checkpoint ID."
  def topic_for_checkpoint(checkpoint_id) do
    Map.get(@boot_checkpoints, checkpoint_id) ||
      Map.get(@test_checkpoints, checkpoint_id) ||
      Map.get(@smoke_checkpoints, checkpoint_id) ||
      Map.get(@sprint_checkpoints, checkpoint_id) ||
      Map.get(@wave_checkpoints, checkpoint_id) ||
      Map.get(@agent_checkpoints, checkpoint_id)
  end

  # ============================================================
  # MESSAGE BUILDERS - BOOT
  # ============================================================

  @doc """
  Build a boot checkpoint message.

  ## Example
      iex> build_boot_checkpoint("CP-BOOT-03", %{port: 5433})
      %{type: "boot_checkpoint", checkpoint: "CP-BOOT-03", ...}
  """
  def build_boot_checkpoint(checkpoint_id, payload \\ %{}) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "boot_checkpoint",
      checkpoint: checkpoint_id,
      topic: Map.get(@boot_checkpoints, checkpoint_id),
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id(),
      payload: payload
    }
    |> with_trace_context()
  end

  @doc "Build container started message."
  def build_container_started(container_name, wave, port) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "container_started",
      checkpoint: "CP-BOOT-TX-01",
      container: container_name,
      wave: wave,
      port: port,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build container health check message."
  def build_container_health(container_name, healthy, duration_ms, details) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "container_health",
      checkpoint: "CP-BOOT-TX-02",
      container: container_name,
      healthy: healthy,
      check_duration_ms: duration_ms,
      details: details,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build quorum status message."
  def build_quorum_status(status, healthy_count, total_count, routers) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "quorum_status",
      checkpoint: "CP-BOOT-TX-03",
      status: status,
      healthy_count: healthy_count,
      total_count: total_count,
      routers: routers,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build state vector message."
  def build_state_vector(vector, components) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "state_vector",
      checkpoint: "CP-BOOT-TX-04",
      vector: vector,
      components: components,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  # ============================================================
  # MESSAGE BUILDERS - TEST
  # ============================================================

  @doc "Build test started message."
  def build_test_started(test_id, module, name, file, line, tags \\ []) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "test_started",
      checkpoint: "CP-TEST-TX-01",
      test_id: test_id,
      module: to_string(module),
      name: name,
      file: "#{file}:#{line}",
      tags: tags,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build test passed message."
  def build_test_passed(test_id, duration_us, assertions \\ 0) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "test_passed",
      checkpoint: "CP-TEST-TX-02",
      test_id: test_id,
      duration_us: duration_us,
      assertions: assertions,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build test failed message."
  def build_test_failed(test_id, duration_us, failure) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "test_failed",
      checkpoint: "CP-TEST-TX-03",
      test_id: test_id,
      duration_us: duration_us,
      failure: failure,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build test skipped message."
  def build_test_skipped(test_id, reason) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "test_skipped",
      checkpoint: "CP-TEST-TX-04",
      test_id: test_id,
      reason: reason,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build suite started message."
  def build_suite_started(suite_id, test_count) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "suite_started",
      checkpoint: "CP-TEST-01",
      suite_id: suite_id,
      test_count: test_count,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build suite finished message."
  def build_suite_finished(suite_id, total, passed, failed, skipped, duration_ms) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "suite_finished",
      checkpoint: "CP-TEST-07",
      suite_id: suite_id,
      total: total,
      passed: passed,
      failed: failed,
      skipped: skipped,
      duration_ms: duration_ms,
      pass_rate: if(total > 0, do: passed / total, else: 0.0),
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
    |> with_trace_context()
  end

  @doc "Build module started message."
  def build_module_started(module_name) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "module_started",
      checkpoint: "CP-TEST-05",
      module: to_string(module_name),
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build module finished message."
  def build_module_finished(module_name, tests_run, passed, failed, duration_ms) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "module_finished",
      checkpoint: "CP-TEST-06",
      module: to_string(module_name),
      tests_run: tests_run,
      passed: passed,
      failed: failed,
      duration_ms: duration_ms,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  # ============================================================
  # MESSAGE BUILDERS - SMOKE TESTS
  # ============================================================

  @doc "Build smoke test result message."
  def build_smoke_result(test_id, category, criticality, status, duration_ms, metrics, evidence) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "smoke_result",
      checkpoint: "CP-SMOKE-TX-01",
      test_id: test_id,
      category: category,
      criticality: criticality,
      status: status,
      duration_ms: duration_ms,
      metrics: metrics,
      evidence: evidence,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build smoke node summary message."
  def build_smoke_node_summary(node_id_str, tests_run, passed, failed, duration_ms, failures) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "smoke_node_summary",
      checkpoint: "CP-SMOKE-TX-02",
      node_id: node_id_str,
      tests_run: tests_run,
      tests_passed: passed,
      tests_failed: failed,
      pass_rate: if(tests_run > 0, do: passed / tests_run, else: 0.0),
      duration_ms: duration_ms,
      failures: failures,
      timestamp: timestamp(),
      source: "elixir"
    }
  end

  @doc "Build smoke batch checkpoint message."
  def build_smoke_batch_checkpoint(checkpoint_id, batch_id, payload \\ %{}) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "smoke_batch_checkpoint",
      checkpoint: checkpoint_id,
      batch_id: batch_id,
      payload: payload,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  # ============================================================
  # MESSAGE BUILDERS - ORCHESTRATOR
  # ============================================================

  @doc "Build orchestrator aggregate message."
  def build_aggregate(stats) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "aggregate",
      total_tests: Map.get(stats, :total, 0),
      passed: Map.get(stats, :passed, 0),
      failed: Map.get(stats, :failed, 0),
      skipped: Map.get(stats, :skipped, 0),
      running: Map.get(stats, :running, 0),
      pass_rate: Map.get(stats, :pass_rate, 0.0),
      agent_total: Map.get(stats, :agent_total, 0),
      agent_passed: Map.get(stats, :agent_passed, 0),
      agent_failed: Map.get(stats, :agent_failed, 0),
      duration_ms: Map.get(stats, :duration_ms, 0),
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build orchestrator alert message."
  def build_alert(severity, message, context \\ %{}) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "alert",
      severity: severity,
      message: message,
      context: context,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  # ============================================================
  # MESSAGE BUILDERS - SPRINT TASKS
  # ============================================================

  @doc "Build sprint task started message."
  def build_task_started(task_id, wave, priority, title) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "task_started",
      checkpoint: "CP-SPRINT-TX-01",
      task_id: task_id,
      wave: wave,
      priority: priority,
      title: title,
      state_vector: "[0,0,0,0,0,0]",
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build sprint task progress message."
  def build_task_progress(task_id, checkpoint_id, state_vector, progress_pct, details \\ %{}) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "task_progress",
      checkpoint: checkpoint_id,
      task_id: task_id,
      state_vector: state_vector,
      progress_pct: progress_pct,
      details: details,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build sprint task completed message."
  def build_task_completed(task_id, checkpoint_id, duration_ms, state_vector) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "task_completed",
      checkpoint: checkpoint_id,
      task_id: task_id,
      duration_ms: duration_ms,
      state_vector: state_vector,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc "Build sprint task failed message."
  def build_task_failed(task_id, checkpoint_id, reason, state_vector) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "task_failed",
      checkpoint: checkpoint_id,
      task_id: task_id,
      reason: reason,
      state_vector: state_vector,
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  @doc """
  Build wave Jidoka gate message.

  Gate results map must include: compilation, tests, coverage, fpps_consensus,
  fsharp_build, and task_checkpoints.
  """
  def build_sprint_gate(gate_id, wave_id, results) do
    %{
      schema_version: @schema_version,
      message_id: generate_uuid(),
      type: "sprint_gate",
      checkpoint: gate_id,
      wave: wave_id,
      gate_results: %{
        compilation: Map.get(results, :compilation, :unknown),
        tests: Map.get(results, :tests, :unknown),
        coverage: Map.get(results, :coverage, 0.0),
        fpps_consensus: Map.get(results, :fpps_consensus, :unknown),
        fsharp_build: Map.get(results, :fsharp_build, :skip),
        task_checkpoints: Map.get(results, :task_checkpoints, [])
      },
      state_vector: Map.get(results, :state_vector, "[0,0,0,0,0,0]"),
      gate_passed: gate_passed?(results),
      timestamp: timestamp(),
      source: "elixir",
      node_id: node_id()
    }
  end

  defp gate_passed?(results) do
    Map.get(results, :compilation) == :pass and
      Map.get(results, :tests) == :pass and
      Map.get(results, :coverage, 0.0) >= 95.0
  end

  # ============================================================
  # TOPIC PATTERNS
  # ============================================================

  @doc "Get wildcard pattern for all boot events."
  def boot_topic_pattern, do: "indrajaal/boot/**"

  @doc "Get wildcard pattern for all test events."
  def test_topic_pattern, do: "indrajaal/test/**"

  @doc "Get wildcard pattern for all smoke events."
  def smoke_topic_pattern, do: "indrajaal/smoke/**"

  @doc "Get wildcard pattern for orchestrator events."
  def orchestrator_topic_pattern, do: "indrajaal/orchestrator/**"

  @doc "Get wildcard pattern for all sprint events."
  def sprint_topic_pattern, do: "indrajaal/sprint/**"

  @doc "Get topic for sprint task events."
  def sprint_task_topic(sprint_id, task_id, event) do
    "indrajaal/sprint/#{sprint_id}/task/#{task_id}/#{event}"
  end

  @doc "Get topic for sprint wave events."
  def sprint_wave_topic(wave_id, event) do
    "indrajaal/sprint/wave/#{wave_id}/#{event}"
  end

  @doc "Get topic for test case events."
  def test_case_topic(test_id, event) do
    "indrajaal/test/case/#{test_id}/#{event}"
  end

  @doc "Get topic for module events."
  def module_topic(module_name, event) do
    "indrajaal/test/module/#{module_name}/#{event}"
  end

  @doc "Get topic for container events."
  def container_topic(container_name, event) do
    "indrajaal/boot/container/#{container_name}/#{event}"
  end

  @doc "Get topic for smoke node events."
  def smoke_node_topic(node_id_str) do
    "indrajaal/smoke/node/#{node_id_str}/result"
  end

  @doc "Get topic for smoke category events."
  def smoke_category_topic(category) do
    "indrajaal/smoke/category/#{category}/complete"
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp generate_uuid do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
    |> format_uuid()
  end

  defp format_uuid(hex) do
    "#{String.slice(hex, 0, 8)}-#{String.slice(hex, 8, 4)}-#{String.slice(hex, 12, 4)}-#{String.slice(hex, 16, 4)}-#{String.slice(hex, 20, 12)}"
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp node_id do
    to_string(Node.self())
  end

  @doc false
  # Inject W3C trace context into checkpoint message for cross-runtime correlation.
  # SC-OTEL-MATH-009: context propagation integrity
  # Uses TracePropagator.inject/1 when available, graceful no-op otherwise.
  def with_trace_context(message) when is_map(message) do
    case safe_inject_trace_context() do
      nil -> message
      trace_ctx -> Map.put(message, :trace_context, trace_ctx)
    end
  end

  defp safe_inject_trace_context do
    try do
      case Indrajaal.Cluster.Zenoh.TracePropagator.inject(%{}) do
        {:ok, ctx} when map_size(ctx) > 0 -> ctx
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end
end
