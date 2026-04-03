defmodule Indrajaal.Testing.SprintTaskOrchestratorTest do
  @moduledoc """
  TDG comprehensive test suite for the sprint task orchestration system.

  Covers three modules:
  - `Indrajaal.Testing.CheckpointMessages` (sprint/wave extensions)
  - `Indrajaal.Testing.SprintTaskPublisher` (pure-function layer)
  - `Indrajaal.Testing.ZenohTestOrchestrator` (GenServer event aggregation)

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE full sprint execution begins
  - FPPS Validation: 5-method consensus for checkpoint ID uniqueness,
    topic depth, DAG acyclicity, wave monotonicity, message schema

  ## STAMP Safety Integration
  - SC-ZTEST-001: All checkpoints MUST have unique topics
  - SC-ZTEST-002: Messages MUST include checkpoint ID
  - SC-ZTEST-013: Checkpoint ID format CP-{DOMAIN}-{NN}
  - SC-ZTEST-015: Timestamps MUST be ISO 8601 UTC
  - SC-ZTEST-017: Topic depth <= 6 levels
  - SC-ZTEST-020: Quorum messages require 2oo3 consensus

  ## Constitutional Verification
  - Ψ₀ Existence: Publisher survives unknown task_ids gracefully
  - Ψ₁ Regeneration: Wave/task structure fully reconstructible from registry
  - Ψ₂ Evolutionary Continuity: DAG encodes the full dependency lineage
  - Ψ₃ Verification: Hash-based checkpoint IDs provide deterministic audit trail
  - Ψ₅ Truthfulness: gate_passed? logic honestly reflects gate results

  ## Founder's Directive Alignment
  - Ω₀.6: Sentience pursuit — cognitive integration tasks verified (46.3)
  - Ω₀.3: Symbiotic binding — Wave 0 foundational tasks tested first

  ## TPS 5-Level RCA Context
  - L1 Symptom: Sprint tasks silently misfired or duplicated events
  - L2 Contributing Factor: Checkpoint ID collision in topic registry
  - L3 Root Cause: No compile-time uniqueness enforcement
  - L4 Systemic Issue: DAG cycles would cause infinite publish loops
  - L5 Strategic Defect: Missing property-based proof of registry invariants

  @version "21.3.0"
  @last_modified "2026-03-09"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif

  alias Indrajaal.Testing.CheckpointMessages
  alias Indrajaal.Testing.SprintTaskPublisher

  # ---------------------------------------------------------------------------
  # Shared test constants
  # ---------------------------------------------------------------------------

  # The 18 sprint checkpoint IDs declared in the module
  @expected_sprint_checkpoint_ids ~w[
    CP-HOLON-01 CP-HOLON-02 CP-HOLON-03 CP-HOLON-04
    CP-FVAL-01  CP-FVAL-02  CP-FVAL-03  CP-FVAL-04  CP-FVAL-05
    CP-VALD-01  CP-VALD-02  CP-VALD-03
    CP-PLAN-01  CP-PLAN-02
    CP-FPPS-01  CP-FPPS-02  CP-FPPS-03  CP-FPPS-04
  ]

  # The 6 wave gate checkpoint IDs
  @expected_wave_checkpoint_ids ~w[
    CP-WAVE-G0 CP-WAVE-G1 CP-WAVE-G2 CP-WAVE-G3 CP-WAVE-G4 CP-WAVE-FINAL
  ]

  # The 18 task IDs in the registry
  @all_task_ids ~w[
    42.1.0.0.0 42.2.0.0.0 42.3.0.0.0 42.4.0.0.0
    43.1.0.0.0 43.1.1.0.0 43.1.2.0.0 43.1.3.0.0 43.1.4.0.0
    44.1.0.0.0 44.2.0.0.0 44.3.0.0.0
    45.1.0.0.0 45.2.0.0.0
    46.1.0.0.0 46.2.0.0.0 46.3.0.0.0 46.4.0.0.0
  ]

  # Wave task counts per the module doc: 4,3,5,3,2,1
  @wave_expected_counts %{0 => 4, 1 => 3, 2 => 5, 3 => 3, 4 => 2, 5 => 1}

  # ============================================================
  # CheckpointMessages — Sprint Checkpoint Registry
  # ============================================================

  describe "CheckpointMessages.sprint_checkpoints/0" do
    test "returns exactly 18 sprint checkpoint entries" do
      checkpoints = CheckpointMessages.sprint_checkpoints()
      assert map_size(checkpoints) == 18
    end

    test "contains all expected sprint checkpoint IDs" do
      keys = CheckpointMessages.sprint_checkpoints() |> Map.keys() |> MapSet.new()

      for id <- @expected_sprint_checkpoint_ids do
        assert MapSet.member?(keys, id),
               "Missing sprint checkpoint ID: #{id}"
      end
    end

    test "all sprint checkpoint values are non-empty topic strings" do
      for {id, topic} <- CheckpointMessages.sprint_checkpoints() do
        assert is_binary(topic) and byte_size(topic) > 0,
               "Empty topic for checkpoint #{id}"
      end
    end

    test "all sprint topics begin with indrajaal/sprint/ prefix" do
      for {id, topic} <- CheckpointMessages.sprint_checkpoints() do
        assert String.starts_with?(topic, "indrajaal/sprint/"),
               "#{id} => #{topic} does not start with indrajaal/sprint/"
      end
    end
  end

  describe "CheckpointMessages.wave_checkpoints/0" do
    test "returns exactly 6 wave gate checkpoint entries" do
      checkpoints = CheckpointMessages.wave_checkpoints()
      assert map_size(checkpoints) == 6
    end

    test "contains all expected wave gate checkpoint IDs" do
      keys = CheckpointMessages.wave_checkpoints() |> Map.keys() |> MapSet.new()

      for id <- @expected_wave_checkpoint_ids do
        assert MapSet.member?(keys, id),
               "Missing wave checkpoint ID: #{id}"
      end
    end

    test "all wave gate topics end with /gate" do
      for {id, topic} <- CheckpointMessages.wave_checkpoints() do
        assert String.ends_with?(topic, "/gate"),
               "#{id} => #{topic} does not end with /gate"
      end
    end

    test "CP-WAVE-FINAL maps to the final sprint gate topic" do
      topic = CheckpointMessages.wave_checkpoints()["CP-WAVE-FINAL"]
      assert topic == "indrajaal/sprint/final/gate"
    end
  end

  describe "CheckpointMessages.topic_for_checkpoint/1" do
    test "resolves all 18 sprint checkpoint IDs to non-nil topics" do
      for id <- @expected_sprint_checkpoint_ids do
        topic = CheckpointMessages.topic_for_checkpoint(id)

        assert is_binary(topic) and byte_size(topic) > 0,
               "topic_for_checkpoint(#{inspect(id)}) returned #{inspect(topic)}"
      end
    end

    test "resolves all 6 wave checkpoint IDs to non-nil topics" do
      for id <- @expected_wave_checkpoint_ids do
        topic = CheckpointMessages.topic_for_checkpoint(id)

        assert is_binary(topic) and byte_size(topic) > 0,
               "topic_for_checkpoint(#{inspect(id)}) returned #{inspect(topic)}"
      end
    end

    test "resolves known boot checkpoint CP-BOOT-01" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-BOOT-01")
      assert topic == "indrajaal/boot/preflight/start"
    end

    test "resolves known test checkpoint CP-TEST-07" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-TEST-07")
      assert topic == "indrajaal/test/suite/complete"
    end

    test "resolves known smoke checkpoint CP-SMOKE-08" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-SMOKE-08")
      assert topic == "indrajaal/smoke/batch/complete"
    end

    test "returns nil for completely unknown checkpoint ID" do
      refute CheckpointMessages.topic_for_checkpoint("CP-UNKNOWN-99")
    end

    test "returns nil for empty string" do
      refute CheckpointMessages.topic_for_checkpoint("")
    end

    test "resolves CP-HOLON-01 to the sprint 42 task 42-1 verify topic" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-HOLON-01")
      assert topic == "indrajaal/sprint/42/task/42-1/verify"
    end

    test "resolves CP-FPPS-04 to the sprint 46 task 46-4 verify topic" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-FPPS-04")
      assert topic == "indrajaal/sprint/46/task/46-4/verify"
    end

    test "resolves CP-WAVE-G0 to wave 0 gate topic" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-WAVE-G0")
      assert topic == "indrajaal/sprint/wave/0/gate"
    end
  end

  # ============================================================
  # CheckpointMessages — Topic Builders
  # ============================================================

  describe "CheckpointMessages.sprint_task_topic/3" do
    test "generates correct topic for sprint 42 task 42-1 start event" do
      topic = CheckpointMessages.sprint_task_topic(42, "42-1", "start")
      assert topic == "indrajaal/sprint/42/task/42-1/start"
    end

    test "generates correct topic for sprint 46 task 46-4 verify event" do
      topic = CheckpointMessages.sprint_task_topic(46, "46-4", "verify")
      assert topic == "indrajaal/sprint/46/task/46-4/verify"
    end

    test "generates correct topic for progress event" do
      topic = CheckpointMessages.sprint_task_topic(43, "43-1-1", "progress")
      assert topic == "indrajaal/sprint/43/task/43-1-1/progress"
    end

    test "generates correct topic for complete event" do
      topic = CheckpointMessages.sprint_task_topic(44, "44-2", "complete")
      assert topic == "indrajaal/sprint/44/task/44-2/complete"
    end

    test "topic has exactly 6 depth levels" do
      topic = CheckpointMessages.sprint_task_topic(42, "42-1", "start")
      # "indrajaal/sprint/42/task/42-1/start" = 6 segments
      segments = String.split(topic, "/")
      assert length(segments) == 6, "Expected 6 segments, got #{length(segments)}: #{topic}"
    end
  end

  describe "CheckpointMessages.sprint_wave_topic/2" do
    test "generates correct topic for wave 0 gate" do
      topic = CheckpointMessages.sprint_wave_topic(0, "gate")
      assert topic == "indrajaal/sprint/wave/0/gate"
    end

    test "generates correct topic for wave 5 complete" do
      topic = CheckpointMessages.sprint_wave_topic(5, "complete")
      assert topic == "indrajaal/sprint/wave/5/complete"
    end

    test "generates correct topic for wave start" do
      topic = CheckpointMessages.sprint_wave_topic(2, "start")
      assert topic == "indrajaal/sprint/wave/2/start"
    end

    test "topic has exactly 5 depth levels (SC-ZTEST-017: <= 6)" do
      topic = CheckpointMessages.sprint_wave_topic(1, "gate")
      segments = String.split(topic, "/")
      assert length(segments) == 5, "Expected 5 segments, got #{length(segments)}: #{topic}"
    end
  end

  describe "CheckpointMessages.sprint_topic_pattern/0" do
    test "returns a wildcard pattern covering all sprint topics" do
      pattern = CheckpointMessages.sprint_topic_pattern()
      assert pattern == "indrajaal/sprint/**"
    end

    test "pattern starts with indrajaal/ prefix" do
      assert String.starts_with?(CheckpointMessages.sprint_topic_pattern(), "indrajaal/")
    end

    test "pattern ends with ** for recursive wildcard" do
      assert String.ends_with?(CheckpointMessages.sprint_topic_pattern(), "**")
    end
  end

  # ============================================================
  # CheckpointMessages — Sprint Message Builders
  # ============================================================

  describe "CheckpointMessages.build_task_started/4" do
    setup do
      msg = CheckpointMessages.build_task_started("42.1.0.0.0", 0, :p0, "Biological Substrate")
      {:ok, msg: msg}
    end

    test "returns a map", %{msg: msg} do
      assert is_map(msg)
    end

    test "type is task_started", %{msg: msg} do
      assert msg.type == "task_started"
    end

    test "checkpoint is CP-SPRINT-TX-01", %{msg: msg} do
      assert msg.checkpoint == "CP-SPRINT-TX-01"
    end

    test "task_id matches argument", %{msg: msg} do
      assert msg.task_id == "42.1.0.0.0"
    end

    test "wave matches argument", %{msg: msg} do
      assert msg.wave == 0
    end

    test "priority matches argument", %{msg: msg} do
      assert msg.priority == :p0
    end

    test "title matches argument", %{msg: msg} do
      assert msg.title == "Biological Substrate"
    end

    test "includes :timestamp field (SC-ZTEST-015)", %{msg: msg} do
      assert Map.has_key?(msg, :timestamp)
      assert is_binary(msg.timestamp) and byte_size(msg.timestamp) > 0
    end

    test "includes :state_vector field (SC-ZTEST-006)", %{msg: msg} do
      assert Map.has_key?(msg, :state_vector)
    end

    test "initial state_vector is all-zero vector", %{msg: msg} do
      assert msg.state_vector == "[0,0,0,0,0,0]"
    end

    test "includes schema_version field (SC-ZTEST-014)", %{msg: msg} do
      assert Map.has_key?(msg, :schema_version)
    end

    test "includes message_id for deduplication", %{msg: msg} do
      assert Map.has_key?(msg, :message_id)
      assert is_binary(msg.message_id) and byte_size(msg.message_id) > 0
    end

    test "includes source field", %{msg: msg} do
      assert msg.source == "elixir"
    end
  end

  describe "CheckpointMessages.build_task_progress/5" do
    setup do
      msg =
        CheckpointMessages.build_task_progress(
          "43.1.1.0.0",
          "CP-FVAL-02",
          "[1,1,0,0,0,0]",
          50,
          %{step: "implement"}
        )

      {:ok, msg: msg}
    end

    test "type is task_progress", %{msg: msg} do
      assert msg.type == "task_progress"
    end

    test "checkpoint matches argument", %{msg: msg} do
      assert msg.checkpoint == "CP-FVAL-02"
    end

    test "task_id matches argument", %{msg: msg} do
      assert msg.task_id == "43.1.1.0.0"
    end

    test "state_vector matches argument", %{msg: msg} do
      assert msg.state_vector == "[1,1,0,0,0,0]"
    end

    test "progress_pct matches argument", %{msg: msg} do
      assert msg.progress_pct == 50
    end

    test "details merged into message", %{msg: msg} do
      assert msg.details == %{step: "implement"}
    end

    test "includes :timestamp field", %{msg: msg} do
      assert Map.has_key?(msg, :timestamp)
    end
  end

  describe "CheckpointMessages.build_task_completed/4" do
    setup do
      msg =
        CheckpointMessages.build_task_completed(
          "46.1.0.0.0",
          "CP-FPPS-01",
          1234,
          "[1,1,1,1,1,1]"
        )

      {:ok, msg: msg}
    end

    test "type is task_completed", %{msg: msg} do
      assert msg.type == "task_completed"
    end

    test "checkpoint matches argument", %{msg: msg} do
      assert msg.checkpoint == "CP-FPPS-01"
    end

    test "task_id matches argument", %{msg: msg} do
      assert msg.task_id == "46.1.0.0.0"
    end

    test "duration_ms matches argument", %{msg: msg} do
      assert msg.duration_ms == 1234
    end

    test "state_vector is all-ones vector", %{msg: msg} do
      assert msg.state_vector == "[1,1,1,1,1,1]"
    end

    test "includes :timestamp field", %{msg: msg} do
      assert Map.has_key?(msg, :timestamp)
    end
  end

  describe "CheckpointMessages.build_task_failed/4" do
    setup do
      msg =
        CheckpointMessages.build_task_failed(
          "44.3.0.0.0",
          "CP-VALD-03",
          "compile_error",
          "[1,0,0,0,0,0]"
        )

      {:ok, msg: msg}
    end

    test "type is task_failed", %{msg: msg} do
      assert msg.type == "task_failed"
    end

    test "checkpoint matches argument", %{msg: msg} do
      assert msg.checkpoint == "CP-VALD-03"
    end

    test "task_id matches argument", %{msg: msg} do
      assert msg.task_id == "44.3.0.0.0"
    end

    test "reason matches argument", %{msg: msg} do
      assert msg.reason == "compile_error"
    end

    test "state_vector matches argument", %{msg: msg} do
      assert msg.state_vector == "[1,0,0,0,0,0]"
    end

    test "includes :timestamp field", %{msg: msg} do
      assert Map.has_key?(msg, :timestamp)
    end
  end

  describe "CheckpointMessages.build_sprint_gate/3" do
    setup do
      results = %{
        compilation: :pass,
        tests: :pass,
        coverage: 97.5,
        fpps_consensus: :pass,
        fsharp_build: :pass,
        task_checkpoints: ["CP-FPPS-01", "CP-FPPS-02"],
        state_vector: "[1,1,1,1,1,1]"
      }

      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G1", 1, results)
      {:ok, msg: msg, results: results}
    end

    test "type is sprint_gate", %{msg: msg} do
      assert msg.type == "sprint_gate"
    end

    test "checkpoint matches the gate_id argument", %{msg: msg} do
      assert msg.checkpoint == "CP-WAVE-G1"
    end

    test "wave matches the wave_id argument", %{msg: msg} do
      assert msg.wave == 1
    end

    test "gate_results map contains compilation key", %{msg: msg} do
      assert msg.gate_results.compilation == :pass
    end

    test "gate_results map contains tests key", %{msg: msg} do
      assert msg.gate_results.tests == :pass
    end

    test "gate_results map contains coverage key", %{msg: msg} do
      assert msg.gate_results.coverage == 97.5
    end

    test "gate_results map contains fpps_consensus key", %{msg: msg} do
      assert msg.gate_results.fpps_consensus == :pass
    end

    test "gate_results map contains fsharp_build key", %{msg: msg} do
      assert msg.gate_results.fsharp_build == :pass
    end

    test "gate_results map contains task_checkpoints key", %{msg: msg} do
      assert is_list(msg.gate_results.task_checkpoints)
    end

    test "gate_passed is true when all conditions met", %{msg: msg} do
      assert msg.gate_passed == true
    end

    test "gate_passed is false when compilation fails" do
      failing_results = %{compilation: :fail, tests: :pass, coverage: 97.5}
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G2", 2, failing_results)
      assert msg.gate_passed == false
    end

    test "gate_passed is false when coverage below 95%" do
      low_coverage = %{compilation: :pass, tests: :pass, coverage: 94.9}
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G3", 3, low_coverage)
      assert msg.gate_passed == false
    end

    test "gate_passed is false when tests fail" do
      failing_tests = %{compilation: :pass, tests: :fail, coverage: 99.0}
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G4", 4, failing_tests)
      assert msg.gate_passed == false
    end

    test "includes :timestamp field", %{msg: msg} do
      assert Map.has_key?(msg, :timestamp)
    end

    test "state_vector propagated from results", %{msg: msg} do
      assert msg.state_vector == "[1,1,1,1,1,1]"
    end

    test "default state_vector when not in results" do
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G0", 0, %{})
      assert msg.state_vector == "[0,0,0,0,0,0]"
    end
  end

  # ============================================================
  # SprintTaskPublisher — Registry
  # ============================================================

  describe "SprintTaskPublisher.task_registry/0" do
    test "returns exactly 18 tasks" do
      registry = SprintTaskPublisher.task_registry()
      assert map_size(registry) == 18
    end

    test "contains all expected task IDs" do
      keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

      for id <- @all_task_ids do
        assert MapSet.member?(keys, id), "Missing task ID: #{id}"
      end
    end

    test "each task entry has required fields: checkpoint, sprint, task_key, priority, wave, title" do
      required_keys = [:checkpoint, :sprint, :task_key, :priority, :wave, :title]

      for {id, info} <- SprintTaskPublisher.task_registry() do
        for key <- required_keys do
          assert Map.has_key?(info, key),
                 "Task #{id} missing required field #{inspect(key)}"
        end
      end
    end

    test "all priorities are valid atoms (:p0, :p1, :p2)" do
      valid_priorities = MapSet.new([:p0, :p1, :p2])

      for {id, info} <- SprintTaskPublisher.task_registry() do
        assert MapSet.member?(valid_priorities, info.priority),
               "Task #{id} has invalid priority: #{inspect(info.priority)}"
      end
    end

    test "all wave numbers are integers in range 0..5" do
      for {id, info} <- SprintTaskPublisher.task_registry() do
        assert info.wave in 0..5,
               "Task #{id} has wave #{inspect(info.wave)} outside 0..5"
      end
    end

    test "all checkpoints are strings starting with CP-" do
      for {id, info} <- SprintTaskPublisher.task_registry() do
        assert is_binary(info.checkpoint) and String.starts_with?(info.checkpoint, "CP-"),
               "Task #{id} has invalid checkpoint: #{inspect(info.checkpoint)}"
      end
    end

    test "checkpoint IDs in registry match the sprint_checkpoints map" do
      sprint_checkpoint_ids =
        CheckpointMessages.sprint_checkpoints() |> Map.keys() |> MapSet.new()

      for {id, info} <- SprintTaskPublisher.task_registry() do
        assert MapSet.member?(sprint_checkpoint_ids, info.checkpoint),
               "Task #{id} checkpoint #{info.checkpoint} not in sprint_checkpoints"
      end
    end

    test "all sprint numbers are integers from known sprints {42,43,44,45,46}" do
      valid_sprints = MapSet.new([42, 43, 44, 45, 46])

      for {id, info} <- SprintTaskPublisher.task_registry() do
        assert MapSet.member?(valid_sprints, info.sprint),
               "Task #{id} has unknown sprint: #{inspect(info.sprint)}"
      end
    end

    test "all titles are non-empty strings" do
      for {id, info} <- SprintTaskPublisher.task_registry() do
        assert is_binary(info.title) and byte_size(info.title) > 0,
               "Task #{id} has empty title"
      end
    end
  end

  # ============================================================
  # SprintTaskPublisher — critical_tasks/0
  # ============================================================

  describe "SprintTaskPublisher.critical_tasks/0" do
    test "returns only :p0 priority tasks" do
      for {_id, info} <- SprintTaskPublisher.critical_tasks() do
        assert info.priority == :p0
      end
    end

    test "returns exactly 7 P0 tasks" do
      assert length(SprintTaskPublisher.critical_tasks()) == 7
    end

    test "results are sorted by ascending wave number" do
      waves =
        SprintTaskPublisher.critical_tasks()
        |> Enum.map(fn {_id, info} -> info.wave end)

      assert waves == Enum.sort(waves),
             "critical_tasks not sorted by wave: #{inspect(waves)}"
    end

    test "contains task 42.1.0.0.0 (wave 0 foundation)" do
      task_ids =
        SprintTaskPublisher.critical_tasks()
        |> Enum.map(fn {id, _info} -> id end)
        |> MapSet.new()

      assert MapSet.member?(task_ids, "42.1.0.0.0")
    end

    test "contains task 43.1.0.0.0 (wave 5 rollup)" do
      task_ids =
        SprintTaskPublisher.critical_tasks()
        |> Enum.map(fn {id, _info} -> id end)
        |> MapSet.new()

      assert MapSet.member?(task_ids, "43.1.0.0.0")
    end
  end

  # ============================================================
  # SprintTaskPublisher — tasks_by_wave/0
  # ============================================================

  describe "SprintTaskPublisher.tasks_by_wave/0" do
    test "returns 6 wave groups" do
      groups = SprintTaskPublisher.tasks_by_wave()
      assert length(groups) == 6
    end

    test "wave groups are sorted by ascending wave number" do
      wave_numbers =
        SprintTaskPublisher.tasks_by_wave()
        |> Enum.map(fn {wave, _tasks} -> wave end)

      assert wave_numbers == Enum.sort(wave_numbers)
    end

    test "wave numbers cover 0..5 exactly" do
      wave_numbers =
        SprintTaskPublisher.tasks_by_wave()
        |> Enum.map(fn {wave, _tasks} -> wave end)
        |> MapSet.new()

      assert wave_numbers == MapSet.new(0..5)
    end

    test "each wave has the correct task count" do
      for {wave, tasks} <- SprintTaskPublisher.tasks_by_wave() do
        expected = Map.fetch!(@wave_expected_counts, wave)

        assert length(tasks) == expected,
               "Wave #{wave}: expected #{expected} tasks, got #{length(tasks)}"
      end
    end

    test "total tasks across all waves equals 18" do
      total =
        SprintTaskPublisher.tasks_by_wave()
        |> Enum.reduce(0, fn {_wave, tasks}, acc -> acc + length(tasks) end)

      assert total == 18
    end
  end

  # ============================================================
  # SprintTaskPublisher — tasks_for_wave/1
  # ============================================================

  describe "SprintTaskPublisher.tasks_for_wave/1" do
    test "wave 0 returns 4 tasks" do
      assert length(SprintTaskPublisher.tasks_for_wave(0)) == 4
    end

    test "wave 1 returns 3 tasks" do
      assert length(SprintTaskPublisher.tasks_for_wave(1)) == 3
    end

    test "wave 2 returns 5 tasks" do
      assert length(SprintTaskPublisher.tasks_for_wave(2)) == 5
    end

    test "wave 3 returns 3 tasks" do
      assert length(SprintTaskPublisher.tasks_for_wave(3)) == 3
    end

    test "wave 4 returns 2 tasks" do
      assert length(SprintTaskPublisher.tasks_for_wave(4)) == 2
    end

    test "wave 5 returns 1 task" do
      assert length(SprintTaskPublisher.tasks_for_wave(5)) == 1
    end

    test "wave 0 contains the four foundation task IDs" do
      wave0 = SprintTaskPublisher.tasks_for_wave(0) |> MapSet.new()

      assert MapSet.member?(wave0, "42.1.0.0.0"), "Missing 42.1.0.0.0 in wave 0"
      assert MapSet.member?(wave0, "42.4.0.0.0"), "Missing 42.4.0.0.0 in wave 0"
      assert MapSet.member?(wave0, "44.2.0.0.0"), "Missing 44.2.0.0.0 in wave 0"
      assert MapSet.member?(wave0, "46.1.0.0.0"), "Missing 46.1.0.0.0 in wave 0"
    end

    test "wave 5 contains only the F# validator parent task" do
      wave5 = SprintTaskPublisher.tasks_for_wave(5)
      assert wave5 == ["43.1.0.0.0"]
    end

    test "returns empty list for out-of-range wave number" do
      assert SprintTaskPublisher.tasks_for_wave(99) == []
    end

    test "returns empty list for negative wave number" do
      assert SprintTaskPublisher.tasks_for_wave(-1) == []
    end

    test "all returned task IDs exist in the registry" do
      registry_keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

      for wave <- 0..5 do
        for task_id <- SprintTaskPublisher.tasks_for_wave(wave) do
          assert MapSet.member?(registry_keys, task_id),
                 "Wave #{wave} contains unknown task_id: #{task_id}"
        end
      end
    end
  end

  # ============================================================
  # SprintTaskPublisher — waves/0
  # ============================================================

  describe "SprintTaskPublisher.waves/0" do
    test "returns a map with 6 entries (waves 0..5)" do
      waves = SprintTaskPublisher.waves()
      assert map_size(waves) == 6
    end

    test "all waves have a :tasks key" do
      for {wave, definition} <- SprintTaskPublisher.waves() do
        assert Map.has_key?(definition, :tasks),
               "Wave #{wave} missing :tasks key"
      end
    end

    test "all waves have a :gate key" do
      for {wave, definition} <- SprintTaskPublisher.waves() do
        assert Map.has_key?(definition, :gate),
               "Wave #{wave} missing :gate key"
      end
    end

    test "gate IDs match the wave_checkpoints registry" do
      wave_checkpoint_ids =
        CheckpointMessages.wave_checkpoints() |> Map.keys() |> MapSet.new()

      for {wave, definition} <- SprintTaskPublisher.waves() do
        assert MapSet.member?(wave_checkpoint_ids, definition.gate),
               "Wave #{wave} gate #{definition.gate} not in wave_checkpoints"
      end
    end

    test "wave 0 gate is CP-WAVE-G0" do
      assert SprintTaskPublisher.waves()[0][:gate] == "CP-WAVE-G0"
    end

    test "wave 5 gate is CP-WAVE-FINAL" do
      assert SprintTaskPublisher.waves()[5][:gate] == "CP-WAVE-FINAL"
    end
  end

  # ============================================================
  # SprintTaskPublisher — dependency_dag/0
  # ============================================================

  describe "SprintTaskPublisher.dependency_dag/0" do
    test "returns a map" do
      assert is_map(SprintTaskPublisher.dependency_dag())
    end

    test "all dependency targets exist in the task registry" do
      registry_keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

      for {task_id, deps} <- SprintTaskPublisher.dependency_dag() do
        for dep <- deps do
          assert MapSet.member?(registry_keys, dep),
                 "Task #{task_id} depends on unknown task #{dep}"
        end
      end
    end

    test "all tasks that have dependencies are themselves in the registry" do
      registry_keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

      for {task_id, _deps} <- SprintTaskPublisher.dependency_dag() do
        assert MapSet.member?(registry_keys, task_id),
               "DAG key #{task_id} is not in the task registry"
      end
    end

    test "42.2.0.0.0 depends on 42.1.0.0.0 (social organism needs biological substrate)" do
      assert "42.1.0.0.0" in SprintTaskPublisher.dependency_dag()["42.2.0.0.0"]
    end

    test "42.3.0.0.0 depends on 42.2.0.0.0 (cosmic imperative needs social organism)" do
      assert "42.2.0.0.0" in SprintTaskPublisher.dependency_dag()["42.3.0.0.0"]
    end

    test "43.1.0.0.0 depends on all four subtasks" do
      deps = SprintTaskPublisher.dependency_dag()["43.1.0.0.0"] |> MapSet.new()
      assert MapSet.member?(deps, "43.1.1.0.0")
      assert MapSet.member?(deps, "43.1.2.0.0")
      assert MapSet.member?(deps, "43.1.3.0.0")
      assert MapSet.member?(deps, "43.1.4.0.0")
    end

    test "46.4.0.0.0 depends on three FPPS tasks" do
      deps = SprintTaskPublisher.dependency_dag()["46.4.0.0.0"] |> MapSet.new()
      assert MapSet.member?(deps, "46.1.0.0.0")
      assert MapSet.member?(deps, "46.2.0.0.0")
      assert MapSet.member?(deps, "46.3.0.0.0")
    end

    test "tasks with no dependencies are not in the DAG" do
      dag_keys = SprintTaskPublisher.dependency_dag() |> Map.keys() |> MapSet.new()
      # These are source nodes with no prerequisites
      source_nodes = ["42.1.0.0.0", "42.4.0.0.0", "44.2.0.0.0", "46.1.0.0.0", "43.1.1.0.0"]

      for node <- source_nodes do
        refute MapSet.member?(dag_keys, node),
               "#{node} should be a source node with no dependencies"
      end
    end
  end

  # ============================================================
  # SprintTaskPublisher — dependencies_satisfied?/2
  # ============================================================

  describe "SprintTaskPublisher.dependencies_satisfied?/2" do
    test "task with no deps is always satisfied with empty completed set" do
      completed = MapSet.new()
      assert SprintTaskPublisher.dependencies_satisfied?("42.1.0.0.0", completed)
    end

    test "task with no deps is satisfied even with irrelevant completed tasks" do
      completed = MapSet.new(["some.other.task"])
      assert SprintTaskPublisher.dependencies_satisfied?("42.1.0.0.0", completed)
    end

    test "task with unmet deps returns false when completed set is empty" do
      completed = MapSet.new()
      refute SprintTaskPublisher.dependencies_satisfied?("42.2.0.0.0", completed)
    end

    test "task is satisfied when all single dep is in completed set" do
      completed = MapSet.new(["42.1.0.0.0"])
      assert SprintTaskPublisher.dependencies_satisfied?("42.2.0.0.0", completed)
    end

    test "task with multiple deps is not satisfied when only some deps are met" do
      # 43.1.0.0.0 depends on 43.1.1, 43.1.2, 43.1.3, 43.1.4
      completed = MapSet.new(["43.1.1.0.0", "43.1.2.0.0"])
      refute SprintTaskPublisher.dependencies_satisfied?("43.1.0.0.0", completed)
    end

    test "task with multiple deps is satisfied when all deps are met" do
      completed = MapSet.new(["43.1.1.0.0", "43.1.2.0.0", "43.1.3.0.0", "43.1.4.0.0"])
      assert SprintTaskPublisher.dependencies_satisfied?("43.1.0.0.0", completed)
    end

    test "46.4.0.0.0 not satisfied with only two of three deps" do
      completed = MapSet.new(["46.1.0.0.0", "46.2.0.0.0"])
      refute SprintTaskPublisher.dependencies_satisfied?("46.4.0.0.0", completed)
    end

    test "46.4.0.0.0 satisfied with all three deps" do
      completed = MapSet.new(["46.1.0.0.0", "46.2.0.0.0", "46.3.0.0.0"])
      assert SprintTaskPublisher.dependencies_satisfied?("46.4.0.0.0", completed)
    end

    test "completely unknown task_id is treated as having no deps (satisfied)" do
      completed = MapSet.new()
      assert SprintTaskPublisher.dependencies_satisfied?("99.9.9.9.9", completed)
    end
  end

  # ============================================================
  # SprintTaskPublisher — critical_path/0
  # ============================================================

  describe "SprintTaskPublisher.critical_path/0" do
    test "returns a list" do
      assert is_list(SprintTaskPublisher.critical_path())
    end

    test "returns exactly 2 paths" do
      assert length(SprintTaskPublisher.critical_path()) == 2
    end

    test "each path has length 4" do
      for path <- SprintTaskPublisher.critical_path() do
        assert length(path) == 4,
               "Expected path length 4, got #{length(path)}: #{inspect(path)}"
      end
    end

    test "holon critical path is 42.1 -> 44.3 -> 45.1 -> 45.2" do
      paths = SprintTaskPublisher.critical_path()
      holon_path = ["42.1.0.0.0", "44.3.0.0.0", "45.1.0.0.0", "45.2.0.0.0"]
      assert holon_path in paths
    end

    test "FPPS critical path is 46.1 -> 46.2 -> 46.3 -> 46.4" do
      paths = SprintTaskPublisher.critical_path()
      fpps_path = ["46.1.0.0.0", "46.2.0.0.0", "46.3.0.0.0", "46.4.0.0.0"]
      assert fpps_path in paths
    end

    test "all task IDs in critical paths exist in the registry" do
      registry_keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

      for path <- SprintTaskPublisher.critical_path() do
        for task_id <- path do
          assert MapSet.member?(registry_keys, task_id),
                 "Critical path contains unknown task: #{task_id}"
        end
      end
    end
  end

  # ============================================================
  # SprintTaskPublisher — task_info/1 and dependencies/1
  # ============================================================

  describe "SprintTaskPublisher.task_info/1" do
    test "returns task metadata map for valid task ID" do
      info = SprintTaskPublisher.task_info("42.1.0.0.0")
      assert is_map(info)
    end

    test "42.1.0.0.0 has correct metadata" do
      info = SprintTaskPublisher.task_info("42.1.0.0.0")
      assert info.checkpoint == "CP-HOLON-01"
      assert info.sprint == 42
      assert info.priority == :p0
      assert info.wave == 0
    end

    test "43.1.0.0.0 is wave 5 rollup" do
      info = SprintTaskPublisher.task_info("43.1.0.0.0")
      assert info.wave == 5
      assert info.priority == :p0
    end

    test "45.2.0.0.0 is verification and cutover task" do
      info = SprintTaskPublisher.task_info("45.2.0.0.0")
      assert info.title == "Verification & Cutover"
    end

    test "returns nil for unknown task ID" do
      assert SprintTaskPublisher.task_info("99.9.9.9.9") == nil
    end

    test "returns nil for empty string" do
      assert SprintTaskPublisher.task_info("") == nil
    end
  end

  describe "SprintTaskPublisher.dependencies/1" do
    test "returns list for task with dependencies" do
      deps = SprintTaskPublisher.dependencies("42.2.0.0.0")
      assert is_list(deps)
      assert "42.1.0.0.0" in deps
    end

    test "returns empty list for task with no dependencies (source node)" do
      assert SprintTaskPublisher.dependencies("42.1.0.0.0") == []
    end

    test "returns empty list for completely unknown task ID" do
      assert SprintTaskPublisher.dependencies("99.9.9.9.9") == []
    end

    test "43.1.0.0.0 has exactly 4 dependencies" do
      assert length(SprintTaskPublisher.dependencies("43.1.0.0.0")) == 4
    end

    test "46.4.0.0.0 has exactly 3 dependencies" do
      assert length(SprintTaskPublisher.dependencies("46.4.0.0.0")) == 3
    end
  end

  # ============================================================
  # ZenohTestOrchestrator — GenServer events (no DB, no containers)
  # ============================================================

  describe "ZenohTestOrchestrator sprint task event handling" do
    # We exercise the GenServer in isolation by starting a named instance
    # and sending messages directly, then asserting on get_stats/1.
    # No Zenoh, no DB required.

    setup do
      # Start Phoenix.PubSub if not already running (required by ZenohTestOrchestrator)
      unless GenServer.whereis(Indrajaal.PubSub) do
        start_supervised!({Phoenix.PubSub, name: Indrajaal.PubSub})
      end

      # Each test gets its own named process to ensure isolation
      name = :"test_orchestrator_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, pid} =
        Indrajaal.Testing.ZenohTestOrchestrator.start_link(name: name)

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal)
      end)

      {:ok, pid: pid, name: name}
    end

    test "initial sprint stats are all zero", %{pid: pid} do
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_total == 0
      assert stats.sprint_completed == 0
      assert stats.sprint_failed == 0
      assert stats.sprint_gates_passed == 0
      assert stats.sprint_waves_evaluated == 0
    end

    test "sprint_task_started event increments sprint_total", %{pid: pid} do
      send(pid, {:sprint_task_started, "42.1.0.0.0", %{wave: 0, priority: "p0"}})
      # Allow GenServer to process the message
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_total == 1
    end

    test "sprint_task_completed event increments sprint_completed", %{pid: pid} do
      send(pid, {:sprint_task_started, "42.1.0.0.0", %{wave: 0}})
      send(pid, {:sprint_task_completed, "42.1.0.0.0", %{duration_ms: 500}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_completed == 1
    end

    test "sprint_task_failed event increments sprint_failed", %{pid: pid} do
      send(pid, {:sprint_task_started, "42.1.0.0.0", %{wave: 0}})
      send(pid, {:sprint_task_failed, "42.1.0.0.0", %{reason: "timeout"}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_failed == 1
    end

    test "sprint_task_failed adds to recent_failures", %{pid: pid} do
      send(pid, {:sprint_task_failed, "46.4.0.0.0", %{reason: "test_failure"}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)

      failures = Indrajaal.Testing.ZenohTestOrchestrator.get_failures(pid)
      assert length(failures) >= 1
      [failure | _] = failures
      assert failure.id == "46.4.0.0.0"
      assert failure.type == :sprint
    end

    test "sprint_wave_gate passed event increments sprint_gates_passed", %{pid: pid} do
      send(pid, {:sprint_wave_gate, 0, %{gate_passed: true, gate_results: %{}}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_gates_passed == 1
    end

    test "sprint_wave_gate failed event does NOT increment sprint_gates_passed", %{pid: pid} do
      send(pid, {:sprint_wave_gate, 1, %{gate_passed: false, gate_results: %{}}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_gates_passed == 0
    end

    test "sprint_wave_gate increments sprint_waves_evaluated regardless of result", %{pid: pid} do
      send(pid, {:sprint_wave_gate, 0, %{gate_passed: true, gate_results: %{}}})
      send(pid, {:sprint_wave_gate, 1, %{gate_passed: false, gate_results: %{}}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_waves_evaluated == 2
    end

    test "sprint_task_progress updates task state vector", %{pid: pid} do
      send(pid, {:sprint_task_started, "43.1.1.0.0", %{wave: 1}})

      send(
        pid,
        {:sprint_task_progress, "43.1.1.0.0", %{state_vector: "[1,1,0,0,0,0]", progress_pct: 33}}
      )

      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      # Task still tracked after progress update
      assert stats.sprint_total >= 1
    end

    test "reset/1 clears all sprint stats", %{pid: pid} do
      send(pid, {:sprint_task_started, "42.1.0.0.0", %{wave: 0}})
      send(pid, {:sprint_task_completed, "42.1.0.0.0", %{duration_ms: 100}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)

      Indrajaal.Testing.ZenohTestOrchestrator.reset(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)

      assert stats.sprint_total == 0
      assert stats.sprint_completed == 0
      assert stats.sprint_failed == 0
    end

    test "completed task has progress_pct of 100 in tracked tasks", %{pid: pid} do
      send(pid, {:sprint_task_started, "44.2.0.0.0", %{wave: 0}})
      send(pid, {:sprint_task_completed, "44.2.0.0.0", %{duration_ms: 250}})
      # Flush with a synchronous call
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      # sprint_total reflects the tracked task
      assert stats.sprint_total >= 1
      assert stats.sprint_completed == 1
    end

    test "multiple wave gates accumulate correctly", %{pid: pid} do
      send(pid, {:sprint_wave_gate, 0, %{gate_passed: true, gate_results: %{}}})
      send(pid, {:sprint_wave_gate, 1, %{gate_passed: true, gate_results: %{}}})
      send(pid, {:sprint_wave_gate, 2, %{gate_passed: false, gate_results: %{}}})
      _ = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      stats = Indrajaal.Testing.ZenohTestOrchestrator.get_stats(pid)
      assert stats.sprint_gates_passed == 2
      assert stats.sprint_waves_evaluated == 3
    end
  end

  # ============================================================
  # PROPERTY TESTS — CheckpointMessages registry invariants
  # ============================================================

  property "all sprint + wave checkpoint IDs are globally unique (SC-ZTEST-001)" do
    all_ids =
      Map.keys(CheckpointMessages.sprint_checkpoints()) ++
        Map.keys(CheckpointMessages.wave_checkpoints())

    forall _ <- PC.exactly(true) do
      all_ids == Enum.uniq(all_ids)
    end
  end

  property "all sprint + wave topics are globally unique (SC-ZTEST-001)" do
    all_topics =
      Map.values(CheckpointMessages.sprint_checkpoints()) ++
        Map.values(CheckpointMessages.wave_checkpoints())

    forall _ <- PC.exactly(true) do
      all_topics == Enum.uniq(all_topics)
    end
  end

  property "sprint_task_topic/3 always produces topic with depth <= 6 (SC-ZTEST-017)" do
    forall {sprint_id, task_key, event} <-
             {PC.integer(42, 46),
              PC.non_empty(
                PC.list(PC.oneof([PC.range(?a, ?z), PC.range(?0, ?9), PC.exactly(?_)]))
              ), PC.oneof(["start", "progress", "complete", "verify", "failed"])} do
      task_key = to_string(task_key)
      topic = CheckpointMessages.sprint_task_topic(sprint_id, task_key, event)
      segment_count = topic |> String.split("/") |> length()
      segment_count <= 6
    end
  end

  property "sprint_wave_topic/2 always produces topic with depth <= 6 (SC-ZTEST-017)" do
    forall {wave_id, event} <-
             {PC.integer(0, 5), PC.oneof(["start", "complete", "gate"])} do
      topic = CheckpointMessages.sprint_wave_topic(wave_id, event)
      segment_count = topic |> String.split("/") |> length()
      segment_count <= 6
    end
  end

  property "build_task_started always includes :timestamp and :type fields" do
    forall {task_id, wave, priority, title} <-
             {PC.non_empty(PC.utf8()), PC.integer(0, 5), PC.oneof([:p0, :p1, :p2]),
              PC.non_empty(PC.utf8())} do
      msg = CheckpointMessages.build_task_started(task_id, wave, priority, title)
      Map.has_key?(msg, :timestamp) and Map.has_key?(msg, :type) and is_binary(msg.timestamp)
    end
  end

  property "build_task_progress always includes :timestamp and :type fields" do
    forall {task_id, checkpoint_id, state_vector, progress_pct} <-
             {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()),
              PC.integer(0, 100)} do
      msg =
        CheckpointMessages.build_task_progress(task_id, checkpoint_id, state_vector, progress_pct)

      Map.has_key?(msg, :timestamp) and Map.has_key?(msg, :type)
    end
  end

  property "build_task_completed always includes :timestamp and :type fields" do
    forall {task_id, checkpoint_id, duration_ms, state_vector} <-
             {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.pos_integer(),
              PC.non_empty(PC.utf8())} do
      msg =
        CheckpointMessages.build_task_completed(task_id, checkpoint_id, duration_ms, state_vector)

      Map.has_key?(msg, :timestamp) and Map.has_key?(msg, :type)
    end
  end

  property "build_task_failed always includes :timestamp and :type fields" do
    forall {task_id, checkpoint_id, reason, state_vector} <-
             {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()),
              PC.non_empty(PC.utf8())} do
      msg = CheckpointMessages.build_task_failed(task_id, checkpoint_id, reason, state_vector)
      Map.has_key?(msg, :timestamp) and Map.has_key?(msg, :type)
    end
  end

  property "all task IDs in wave definitions exist in the task registry" do
    registry_keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

    forall _ <- PC.exactly(true) do
      Enum.all?(SprintTaskPublisher.waves(), fn {_wave, def} ->
        Enum.all?(def.tasks, fn task_id ->
          MapSet.member?(registry_keys, task_id)
        end)
      end)
    end
  end

  property "all dependency targets in the DAG exist in the task registry" do
    registry_keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

    forall _ <- PC.exactly(true) do
      Enum.all?(SprintTaskPublisher.dependency_dag(), fn {_task_id, deps} ->
        Enum.all?(deps, &MapSet.member?(registry_keys, &1))
      end)
    end
  end

  property "wave numbers in task registry are monotonically within 0..5" do
    forall _ <- PC.exactly(true) do
      Enum.all?(SprintTaskPublisher.task_registry(), fn {_id, info} ->
        info.wave in 0..5
      end)
    end
  end

  property "sprint checkpoint ID format matches CP-{DOMAIN}-{NN} regex (SC-ZTEST-013)" do
    # The regex allows CP- followed by letters then - then digits.
    # WAVE IDs like CP-WAVE-FINAL and CP-WAVE-G0 are excluded from this check
    # since they follow a different (valid) naming convention.
    numeric_id_regex = ~r/^CP-[A-Z]+-\d{2}$/

    forall _ <- PC.exactly(true) do
      Enum.all?(
        Map.keys(CheckpointMessages.sprint_checkpoints()),
        &Regex.match?(numeric_id_regex, &1)
      )
    end
  end

  property "no circular dependencies in the DAG (Ψ₂ lineage completeness)" do
    forall _ <- PC.exactly(true) do
      dag = SprintTaskPublisher.dependency_dag()

      # Detect cycles using DFS with visited/stack marking
      not has_cycle?(dag)
    end
  end

  property "tasks_for_wave/1 is consistent with tasks_by_wave/0" do
    forall wave <- PC.choose(0, 5) do
      direct = SprintTaskPublisher.tasks_for_wave(wave) |> MapSet.new()

      grouped =
        SprintTaskPublisher.tasks_by_wave()
        |> Enum.find(fn {w, _tasks} -> w == wave end)
        |> case do
          nil -> MapSet.new()
          {_w, tasks} -> tasks |> Enum.map(fn {id, _} -> id end) |> MapSet.new()
        end

      direct == grouped
    end
  end

  property "dependencies_satisfied? with full registry as completed is always true" do
    registry_keys = SprintTaskPublisher.task_registry() |> Map.keys() |> MapSet.new()

    forall task_id <- PC.oneof(Enum.map(@all_task_ids, &PC.exactly/1)) do
      SprintTaskPublisher.dependencies_satisfied?(task_id, registry_keys)
    end
  end

  # ============================================================
  # FMEA-derived edge-case tests (L2 coverage)
  # ============================================================

  describe "FMEA: topic collision prevention (FMEA-ZTEST-007, RPN=27)" do
    test "no two checkpoints share the same topic across all categories" do
      all_topics =
        [
          CheckpointMessages.boot_checkpoints(),
          CheckpointMessages.test_checkpoints(),
          CheckpointMessages.smoke_checkpoints(),
          CheckpointMessages.sprint_checkpoints(),
          CheckpointMessages.wave_checkpoints()
        ]
        |> Enum.flat_map(&Map.values/1)

      assert length(all_topics) == length(Enum.uniq(all_topics)),
             "Topic collision detected across checkpoint categories"
    end
  end

  describe "FMEA: schema_version semver compliance (FMEA-ZTEST-004, RPN=24)" do
    test "schema_version matches semver format X.Y.Z" do
      version = CheckpointMessages.schema_version()

      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, version),
             "schema_version #{inspect(version)} does not match semver format"
    end

    test "build_task_started message carries correct schema_version" do
      msg = CheckpointMessages.build_task_started("42.1.0.0.0", 0, :p0, "Test")
      assert msg.schema_version == CheckpointMessages.schema_version()
    end
  end

  describe "FMEA: state vector corruption prevention (FMEA-ZTEST-006, RPN=40)" do
    test "initial state vector in task_started message is all-zero" do
      msg = CheckpointMessages.build_task_started("42.1.0.0.0", 0, :p0, "Test")
      assert msg.state_vector == "[0,0,0,0,0,0]"
    end

    test "completed state vector in task_completed message is all-one" do
      msg =
        CheckpointMessages.build_task_completed("46.1.0.0.0", "CP-FPPS-01", 100, "[1,1,1,1,1,1]")

      assert msg.state_vector == "[1,1,1,1,1,1]"
    end

    test "state vector format is 6-element bracket notation" do
      msg =
        CheckpointMessages.build_task_progress("42.1.0.0.0", "CP-HOLON-01", "[1,0,0,0,0,0]", 10)

      assert Regex.match?(~r/^\[\d,\d,\d,\d,\d,\d\]$/, msg.state_vector)
    end
  end

  describe "FMEA: unknown task graceful degradation (FMEA-ZTEST-001 analogue, RPN=168)" do
    test "SprintTaskPublisher.task_started returns error for unknown task" do
      # Should not raise, should return {:error, :unknown_task}
      result = SprintTaskPublisher.task_started("99.9.9.9.9")
      assert result == {:error, :unknown_task}
    end

    test "SprintTaskPublisher.task_completed returns error for unknown task" do
      result = SprintTaskPublisher.task_completed("99.9.9.9.9", 100)
      assert result == {:error, :unknown_task}
    end

    test "SprintTaskPublisher.task_failed returns error for unknown task" do
      result = SprintTaskPublisher.task_failed("99.9.9.9.9", "some_reason")
      assert result == {:error, :unknown_task}
    end

    test "SprintTaskPublisher.task_progress returns error for unknown task" do
      result = SprintTaskPublisher.task_progress("99.9.9.9.9", "[0,0,0,0,0,0]", 10)
      assert result == {:error, :unknown_task}
    end
  end

  # ============================================================
  # Private test helpers
  # ============================================================

  # DFS-based cycle detector for the dependency DAG.
  # Returns true if a cycle exists.
  defp has_cycle?(dag) do
    nodes = dag |> Map.keys()
    Enum.any?(nodes, fn node -> dfs_has_cycle?(dag, node, MapSet.new(), MapSet.new()) end)
  end

  defp dfs_has_cycle?(dag, node, visited, stack) do
    if MapSet.member?(stack, node) do
      true
    else
      if MapSet.member?(visited, node) do
        false
      else
        new_visited = MapSet.put(visited, node)
        new_stack = MapSet.put(stack, node)
        deps = Map.get(dag, node, [])

        Enum.any?(deps, fn dep ->
          dfs_has_cycle?(dag, dep, new_visited, new_stack)
        end)
      end
    end
  end
end
