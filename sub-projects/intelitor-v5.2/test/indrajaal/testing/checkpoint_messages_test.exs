defmodule Indrajaal.Testing.CheckpointMessagesTest do
  @moduledoc """
  TDG test suite for CheckpointMessages.

  ## STAMP Safety Integration
  - SC-ZTEST-001: All checkpoints have unique topics
  - SC-ZTEST-002: Messages include checkpoint ID
  - SC-ZTEST-013: Checkpoint ID format: CP-{DOMAIN}-{NN}
  - SC-ZTEST-014: Schema version MUST be semver compliant

  ## TPS 5-Level RCA Context
  - L1 Symptom: topic_for_checkpoint returns nil for valid ID
  - L5 Root Cause: Checkpoint registry lookup defect
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Testing.CheckpointMessages

  # ============================================================================
  # schema_version/0
  # ============================================================================

  describe "schema_version/0" do
    test "returns a semver string" do
      version = CheckpointMessages.schema_version()
      assert is_binary(version)
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, version)
    end

    test "current version is 2.0.0" do
      assert CheckpointMessages.schema_version() == "2.0.0"
    end
  end

  # ============================================================================
  # Checkpoint registry accessors
  # ============================================================================

  describe "boot_checkpoints/0" do
    test "returns a map" do
      assert is_map(CheckpointMessages.boot_checkpoints())
    end

    test "contains 10 boot checkpoints" do
      assert map_size(CheckpointMessages.boot_checkpoints()) == 10
    end

    test "CP-BOOT-01 maps to preflight start topic" do
      topic = CheckpointMessages.boot_checkpoints()["CP-BOOT-01"]
      assert topic == "indrajaal/boot/preflight/start"
    end

    test "CP-BOOT-10 maps to boot complete topic" do
      topic = CheckpointMessages.boot_checkpoints()["CP-BOOT-10"]
      assert topic == "indrajaal/boot/complete"
    end

    test "all keys follow CP-BOOT-NN format" do
      CheckpointMessages.boot_checkpoints()
      |> Enum.each(fn {key, _} ->
        assert Regex.match?(~r/^CP-BOOT-\d{2}$/, key)
      end)
    end
  end

  describe "test_checkpoints/0" do
    test "returns a map" do
      assert is_map(CheckpointMessages.test_checkpoints())
    end

    test "contains 8 test checkpoints" do
      assert map_size(CheckpointMessages.test_checkpoints()) == 8
    end

    test "CP-TEST-01 maps to test suite start" do
      topic = CheckpointMessages.test_checkpoints()["CP-TEST-01"]
      assert topic == "indrajaal/test/suite/start"
    end

    test "CP-TEST-07 maps to test suite complete" do
      topic = CheckpointMessages.test_checkpoints()["CP-TEST-07"]
      assert topic == "indrajaal/test/suite/complete"
    end
  end

  describe "smoke_checkpoints/0" do
    test "returns a map" do
      assert is_map(CheckpointMessages.smoke_checkpoints())
    end

    test "contains 8 smoke checkpoints" do
      assert map_size(CheckpointMessages.smoke_checkpoints()) == 8
    end

    test "CP-SMOKE-01 maps to smoke batch start" do
      topic = CheckpointMessages.smoke_checkpoints()["CP-SMOKE-01"]
      assert topic == "indrajaal/smoke/batch/start"
    end

    test "CP-SMOKE-08 maps to batch complete" do
      topic = CheckpointMessages.smoke_checkpoints()["CP-SMOKE-08"]
      assert topic == "indrajaal/smoke/batch/complete"
    end
  end

  describe "sprint_checkpoints/0" do
    test "returns a map" do
      assert is_map(CheckpointMessages.sprint_checkpoints())
    end

    test "contains sprint 42-46 checkpoints" do
      checkpoints = CheckpointMessages.sprint_checkpoints()
      assert Map.has_key?(checkpoints, "CP-HOLON-01")
      assert Map.has_key?(checkpoints, "CP-FVAL-01")
      assert Map.has_key?(checkpoints, "CP-FPPS-01")
    end
  end

  describe "wave_checkpoints/0" do
    test "returns a map" do
      assert is_map(CheckpointMessages.wave_checkpoints())
    end

    test "contains wave gate checkpoints G0 through G4 and FINAL" do
      checkpoints = CheckpointMessages.wave_checkpoints()
      assert Map.has_key?(checkpoints, "CP-WAVE-G0")
      assert Map.has_key?(checkpoints, "CP-WAVE-G4")
      assert Map.has_key?(checkpoints, "CP-WAVE-FINAL")
    end

    test "CP-WAVE-FINAL maps to final gate topic" do
      topic = CheckpointMessages.wave_checkpoints()["CP-WAVE-FINAL"]
      assert topic == "indrajaal/sprint/final/gate"
    end
  end

  # ============================================================================
  # topic_for_checkpoint/1
  # ============================================================================

  describe "topic_for_checkpoint/1" do
    test "resolves boot checkpoint CP-BOOT-01" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-BOOT-01")
      assert topic == "indrajaal/boot/preflight/start"
    end

    test "resolves test checkpoint CP-TEST-01" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-TEST-01")
      assert topic == "indrajaal/test/suite/start"
    end

    test "resolves smoke checkpoint CP-SMOKE-01" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-SMOKE-01")
      assert topic == "indrajaal/smoke/batch/start"
    end

    test "resolves sprint checkpoint CP-HOLON-01" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-HOLON-01")
      refute is_nil(topic)
    end

    test "resolves wave checkpoint CP-WAVE-G0" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-WAVE-G0")
      assert topic == "indrajaal/sprint/wave/0/gate"
    end

    test "returns nil for unknown checkpoint" do
      topic = CheckpointMessages.topic_for_checkpoint("CP-UNKNOWN-99")
      assert is_nil(topic)
    end
  end

  # ============================================================================
  # Message builders - Boot
  # ============================================================================

  describe "build_boot_checkpoint/2" do
    test "returns map with type boot_checkpoint" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert msg.type == "boot_checkpoint"
    end

    test "includes checkpoint ID" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-03")
      assert msg.checkpoint == "CP-BOOT-03"
    end

    test "includes schema_version" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert msg.schema_version == "2.0.0"
    end

    test "includes timestamp in ISO 8601 format" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert is_binary(msg.timestamp)
      assert String.contains?(msg.timestamp, "T")
    end

    test "includes source as elixir" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert msg.source == "elixir"
    end

    test "includes node_id" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert is_binary(msg.node_id)
    end

    test "merges custom payload" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-03", %{port: 5433})
      assert msg.payload == %{port: 5433}
    end

    test "includes message_id as UUID format" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert is_binary(msg.message_id)

      assert Regex.match?(
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
               msg.message_id
             )
    end

    test "topic is set from checkpoint registry" do
      msg = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert msg.topic == "indrajaal/boot/preflight/start"
    end
  end

  describe "build_container_started/3" do
    test "returns container_started type" do
      msg = CheckpointMessages.build_container_started("indrajaal-db-prod", 1, 5433)
      assert msg.type == "container_started"
    end

    test "includes container name" do
      msg = CheckpointMessages.build_container_started("indrajaal-db-prod", 1, 5433)
      assert msg.container == "indrajaal-db-prod"
    end

    test "includes wave and port" do
      msg = CheckpointMessages.build_container_started("indrajaal-db-prod", 2, 4317)
      assert msg.wave == 2
      assert msg.port == 4317
    end
  end

  describe "build_container_health/4" do
    test "returns container_health type" do
      msg = CheckpointMessages.build_container_health("indrajaal-db-prod", true, 150, %{})
      assert msg.type == "container_health"
    end

    test "records healthy status" do
      msg = CheckpointMessages.build_container_health("db", true, 100, %{})
      assert msg.healthy == true
    end

    test "records unhealthy status" do
      msg = CheckpointMessages.build_container_health("db", false, 100, %{reason: "timeout"})
      assert msg.healthy == false
    end

    test "includes duration_ms" do
      msg = CheckpointMessages.build_container_health("db", true, 200, %{})
      assert msg.check_duration_ms == 200
    end
  end

  describe "build_quorum_status/4" do
    test "returns quorum_status type" do
      msg = CheckpointMessages.build_quorum_status(:achieved, 2, 3, ["r1", "r2"])
      assert msg.type == "quorum_status"
    end

    test "includes counts" do
      msg = CheckpointMessages.build_quorum_status(:achieved, 2, 3, [])
      assert msg.healthy_count == 2
      assert msg.total_count == 3
    end

    test "includes router list" do
      msg = CheckpointMessages.build_quorum_status(:achieved, 2, 3, ["router-1", "router-2"])
      assert msg.routers == ["router-1", "router-2"]
    end
  end

  describe "build_state_vector/2" do
    test "returns state_vector type" do
      msg = CheckpointMessages.build_state_vector("[1,1,0,0,0,0]", %{compile: 1})
      assert msg.type == "state_vector"
    end

    test "includes vector string" do
      msg = CheckpointMessages.build_state_vector("[1,1,1,1,1,1]", %{})
      assert msg.vector == "[1,1,1,1,1,1]"
    end
  end

  # ============================================================================
  # Message builders - Test
  # ============================================================================

  describe "build_test_started/5" do
    test "returns test_started type" do
      msg =
        CheckpointMessages.build_test_started("tid-001", MyTest, "test name", "my_test.exs", 42)

      assert msg.type == "test_started"
    end

    test "converts module to string" do
      msg = CheckpointMessages.build_test_started("tid-001", MyTest, "test name", "f.exs", 1)
      assert is_binary(msg.module)
    end

    test "file includes line number" do
      msg = CheckpointMessages.build_test_started("tid-001", MyTest, "test name", "file.exs", 99)
      assert msg.file == "file.exs:99"
    end

    test "includes tags list" do
      msg = CheckpointMessages.build_test_started("tid-001", M, "n", "f.exs", 1, [:slow])
      assert msg.tags == [:slow]
    end

    test "default tags is empty list" do
      msg = CheckpointMessages.build_test_started("tid-001", M, "n", "f.exs", 1)
      assert msg.tags == []
    end
  end

  describe "build_test_passed/2" do
    test "returns test_passed type" do
      msg = CheckpointMessages.build_test_passed("tid-001", 1234)
      assert msg.type == "test_passed"
    end

    test "includes duration_us" do
      msg = CheckpointMessages.build_test_passed("tid-001", 5678)
      assert msg.duration_us == 5678
    end

    test "default assertions is 0" do
      msg = CheckpointMessages.build_test_passed("tid-001", 100)
      assert msg.assertions == 0
    end

    test "accepts assertions count" do
      msg = CheckpointMessages.build_test_passed("tid-001", 100, 5)
      assert msg.assertions == 5
    end
  end

  describe "build_test_failed/3" do
    test "returns test_failed type" do
      failure = %{message: "Expected true, got false"}
      msg = CheckpointMessages.build_test_failed("tid-001", 9999, failure)
      assert msg.type == "test_failed"
    end

    test "includes failure context" do
      failure = %{type: "assertion", message: "mismatch", left: "a", right: "b"}
      msg = CheckpointMessages.build_test_failed("tid-001", 100, failure)
      assert msg.failure == failure
    end

    test "includes checkpoint CP-TEST-TX-03" do
      msg = CheckpointMessages.build_test_failed("tid-001", 100, %{})
      assert msg.checkpoint == "CP-TEST-TX-03"
    end
  end

  describe "build_test_skipped/2" do
    test "returns test_skipped type" do
      msg = CheckpointMessages.build_test_skipped("tid-001", "skipped because :slow")
      assert msg.type == "test_skipped"
    end

    test "includes reason" do
      msg = CheckpointMessages.build_test_skipped("tid-001", "no db")
      assert msg.reason == "no db"
    end
  end

  describe "build_suite_started/2" do
    test "returns suite_started type" do
      msg = CheckpointMessages.build_suite_started("suite-001", 100)
      assert msg.type == "suite_started"
    end

    test "includes test count" do
      msg = CheckpointMessages.build_suite_started("suite-001", 250)
      assert msg.test_count == 250
    end

    test "uses CP-TEST-01 checkpoint" do
      msg = CheckpointMessages.build_suite_started("suite-001", 10)
      assert msg.checkpoint == "CP-TEST-01"
    end
  end

  describe "build_suite_finished/6" do
    test "returns suite_finished type" do
      msg = CheckpointMessages.build_suite_finished("suite-001", 100, 98, 2, 0, 5000)
      assert msg.type == "suite_finished"
    end

    test "calculates pass_rate correctly" do
      msg = CheckpointMessages.build_suite_finished("s", 100, 80, 20, 0, 1000)
      assert msg.pass_rate == 0.8
    end

    test "pass_rate is 0.0 when total is 0" do
      msg = CheckpointMessages.build_suite_finished("s", 0, 0, 0, 0, 0)
      assert msg.pass_rate == 0.0
    end

    test "uses CP-TEST-07 checkpoint" do
      msg = CheckpointMessages.build_suite_finished("s", 10, 10, 0, 0, 100)
      assert msg.checkpoint == "CP-TEST-07"
    end
  end

  describe "build_module_started/1" do
    test "returns module_started type" do
      msg = CheckpointMessages.build_module_started(MyModule)
      assert msg.type == "module_started"
    end

    test "converts module to string" do
      msg = CheckpointMessages.build_module_started(MyModule)
      assert is_binary(msg.module)
    end
  end

  describe "build_module_finished/5" do
    test "returns module_finished type" do
      msg = CheckpointMessages.build_module_finished(MyModule, 10, 9, 1, 500)
      assert msg.type == "module_finished"
    end

    test "includes all counts" do
      msg = CheckpointMessages.build_module_finished(MyModule, 10, 9, 1, 500)
      assert msg.tests_run == 10
      assert msg.passed == 9
      assert msg.failed == 1
      assert msg.duration_ms == 500
    end
  end

  # ============================================================================
  # Message builders - Smoke
  # ============================================================================

  describe "build_smoke_result/7" do
    test "returns smoke_result type" do
      msg = CheckpointMessages.build_smoke_result("t001", :api, :p0, :passed, 45, %{}, [])
      assert msg.type == "smoke_result"
    end

    test "includes category and criticality" do
      msg =
        CheckpointMessages.build_smoke_result("t001", :api, :p0, :passed, 45, %{}, ["HTTP 200"])

      assert msg.category == :api
      assert msg.criticality == :p0
    end

    test "includes evidence list" do
      msg =
        CheckpointMessages.build_smoke_result("t001", :db, :p1, :failed, 100, %{}, [
          "conn refused"
        ])

      assert msg.evidence == ["conn refused"]
    end
  end

  describe "build_smoke_node_summary/6" do
    test "returns smoke_node_summary type" do
      msg = CheckpointMessages.build_smoke_node_summary("node-1", 10, 9, 1, 5000, [])
      assert msg.type == "smoke_node_summary"
    end

    test "calculates pass_rate" do
      msg = CheckpointMessages.build_smoke_node_summary("node-1", 10, 8, 2, 5000, [])
      assert msg.pass_rate == 0.8
    end

    test "pass_rate is 0.0 for empty run" do
      msg = CheckpointMessages.build_smoke_node_summary("node-1", 0, 0, 0, 0, [])
      assert msg.pass_rate == 0.0
    end
  end

  # ============================================================================
  # Message builders - Orchestrator
  # ============================================================================

  describe "build_aggregate/1" do
    test "returns aggregate type" do
      msg = CheckpointMessages.build_aggregate(%{total: 100, passed: 95, failed: 5})
      assert msg.type == "aggregate"
    end

    test "uses 0 as default for missing stats" do
      msg = CheckpointMessages.build_aggregate(%{})
      assert msg.total_tests == 0
      assert msg.passed == 0
      assert msg.failed == 0
    end

    test "uses provided stats" do
      msg =
        CheckpointMessages.build_aggregate(%{total: 50, passed: 48, failed: 2, pass_rate: 0.96})

      assert msg.total_tests == 50
      assert msg.passed == 48
    end
  end

  describe "build_alert/3" do
    test "returns alert type" do
      msg = CheckpointMessages.build_alert(:critical, "System failure")
      assert msg.type == "alert"
    end

    test "includes severity and message" do
      msg = CheckpointMessages.build_alert(:warning, "Low disk space")
      assert msg.severity == :warning
      assert msg.message == "Low disk space"
    end

    test "accepts context map" do
      msg = CheckpointMessages.build_alert(:info, "Test", %{disk: "90%"})
      assert msg.context == %{disk: "90%"}
    end

    test "default context is empty map" do
      msg = CheckpointMessages.build_alert(:info, "Test")
      assert msg.context == %{}
    end
  end

  # ============================================================================
  # Message builders - Sprint
  # ============================================================================

  describe "build_task_started/4" do
    test "returns task_started type" do
      msg = CheckpointMessages.build_task_started("task-001", 1, :p0, "Implement Feature X")
      assert msg.type == "task_started"
    end

    test "includes task_id, wave, priority, title" do
      msg = CheckpointMessages.build_task_started("t-001", 2, :p1, "My Task")
      assert msg.task_id == "t-001"
      assert msg.wave == 2
      assert msg.priority == :p1
      assert msg.title == "My Task"
    end

    test "initial state_vector is all zeros" do
      msg = CheckpointMessages.build_task_started("t-001", 1, :p0, "Task")
      assert msg.state_vector == "[0,0,0,0,0,0]"
    end
  end

  describe "build_task_progress/4" do
    test "returns task_progress type" do
      msg = CheckpointMessages.build_task_progress("t-001", "CP-HOLON-01", "[1,0,0,0,0,0]", 50)
      assert msg.type == "task_progress"
    end

    test "includes progress_pct" do
      msg = CheckpointMessages.build_task_progress("t-001", "CP-HOLON-01", "[1,0,0,0,0,0]", 75)
      assert msg.progress_pct == 75
    end
  end

  describe "build_task_completed/4" do
    test "returns task_completed type" do
      msg = CheckpointMessages.build_task_completed("t-001", "CP-HOLON-01", 1200, "[1,1,1,1,1,1]")
      assert msg.type == "task_completed"
    end

    test "includes duration_ms" do
      msg = CheckpointMessages.build_task_completed("t-001", "CP-HOLON-01", 3500, "[1,1,1,1,1,1]")
      assert msg.duration_ms == 3500
    end
  end

  describe "build_task_failed/4" do
    test "returns task_failed type" do
      msg =
        CheckpointMessages.build_task_failed(
          "t-001",
          "CP-HOLON-01",
          "compile error",
          "[0,0,0,0,0,0]"
        )

      assert msg.type == "task_failed"
    end

    test "includes reason" do
      msg =
        CheckpointMessages.build_task_failed("t-001", "CP-HOLON-01", "timeout", "[0,0,0,0,0,0]")

      assert msg.reason == "timeout"
    end
  end

  describe "build_sprint_gate/3" do
    test "returns sprint_gate type" do
      results = %{compilation: :pass, tests: :pass, coverage: 96.0}
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G1", 1, results)
      assert msg.type == "sprint_gate"
    end

    test "gate_passed is true when compile and tests pass and coverage >= 95" do
      results = %{compilation: :pass, tests: :pass, coverage: 95.0}
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G1", 1, results)
      assert msg.gate_passed == true
    end

    test "gate_passed is false when coverage below 95" do
      results = %{compilation: :pass, tests: :pass, coverage: 94.9}
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G1", 1, results)
      assert msg.gate_passed == false
    end

    test "gate_passed is false when compilation fails" do
      results = %{compilation: :fail, tests: :pass, coverage: 96.0}
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G1", 1, results)
      assert msg.gate_passed == false
    end

    test "gate_results uses defaults for missing keys" do
      msg = CheckpointMessages.build_sprint_gate("CP-WAVE-G0", 0, %{})
      assert msg.gate_results.compilation == :unknown
      assert msg.gate_results.tests == :unknown
      assert msg.gate_results.coverage == 0.0
    end
  end

  # ============================================================================
  # Topic pattern functions
  # ============================================================================

  describe "boot_topic_pattern/0" do
    test "returns boot wildcard pattern" do
      assert CheckpointMessages.boot_topic_pattern() == "indrajaal/boot/**"
    end
  end

  describe "test_topic_pattern/0" do
    test "returns test wildcard pattern" do
      assert CheckpointMessages.test_topic_pattern() == "indrajaal/test/**"
    end
  end

  describe "smoke_topic_pattern/0" do
    test "returns smoke wildcard pattern" do
      assert CheckpointMessages.smoke_topic_pattern() == "indrajaal/smoke/**"
    end
  end

  describe "sprint_task_topic/3" do
    test "builds sprint task topic" do
      topic = CheckpointMessages.sprint_task_topic(42, "42-1", "start")
      assert topic == "indrajaal/sprint/42/task/42-1/start"
    end
  end

  describe "sprint_wave_topic/2" do
    test "builds wave topic" do
      topic = CheckpointMessages.sprint_wave_topic(1, "gate")
      assert topic == "indrajaal/sprint/wave/1/gate"
    end
  end

  describe "test_case_topic/2" do
    test "builds test case topic" do
      topic = CheckpointMessages.test_case_topic("test-123", "pass")
      assert topic == "indrajaal/test/case/test-123/pass"
    end
  end

  describe "module_topic/2" do
    test "builds module topic" do
      topic = CheckpointMessages.module_topic("MyModule", "complete")
      assert topic == "indrajaal/test/module/MyModule/complete"
    end
  end

  describe "container_topic/2" do
    test "builds container topic" do
      topic = CheckpointMessages.container_topic("indrajaal-db-prod", "started")
      assert topic == "indrajaal/boot/container/indrajaal-db-prod/started"
    end
  end

  describe "smoke_node_topic/1" do
    test "builds smoke node topic" do
      topic = CheckpointMessages.smoke_node_topic("node-1")
      assert topic == "indrajaal/smoke/node/node-1/result"
    end
  end

  describe "smoke_category_topic/1" do
    test "builds smoke category topic" do
      topic = CheckpointMessages.smoke_category_topic("api")
      assert topic == "indrajaal/smoke/category/api/complete"
    end
  end

  # ============================================================================
  # Uniqueness invariants (SC-ZTEST-001)
  # ============================================================================

  describe "checkpoint uniqueness (SC-ZTEST-001)" do
    test "all boot checkpoint topics are unique" do
      topics = Map.values(CheckpointMessages.boot_checkpoints())
      assert length(topics) == length(Enum.uniq(topics))
    end

    test "all test checkpoint topics are unique" do
      topics = Map.values(CheckpointMessages.test_checkpoints())
      assert length(topics) == length(Enum.uniq(topics))
    end

    test "all smoke checkpoint topics are unique" do
      topics = Map.values(CheckpointMessages.smoke_checkpoints())
      assert length(topics) == length(Enum.uniq(topics))
    end

    test "each message build produces unique message_id" do
      msg1 = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      msg2 = CheckpointMessages.build_boot_checkpoint("CP-BOOT-01")
      assert msg1.message_id != msg2.message_id
    end
  end
end
