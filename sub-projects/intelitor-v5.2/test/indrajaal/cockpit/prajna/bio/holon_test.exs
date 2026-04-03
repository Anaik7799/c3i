defmodule Indrajaal.Cockpit.Prajna.Bio.HolonTest do
  @moduledoc """
  Comprehensive tests for the Holon cellular lifecycle manager.

  WHAT: Tests the biomorphic Holon GenServer implementation including
  lifecycle management, self-healing, health monitoring, and autonomy.

  WHY: Validates compliance with STAMP safety constraints:
  - SC-BIO-001: Vital signs latency < 10ms
  - SC-BIO-004: Health check idempotent
  - SC-BIO-005: Self-heal bounded (max 3 attempts)
  - SC-BIO-006: Autonomy level enforcement

  CONSTRAINTS:
  - TDG methodology compliance
  - All tests must be deterministic
  - No external dependencies
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.Bio.Holon
  alias Indrajaal.Cockpit.Prajna.Bio.Holon.State

  # ============================================================
  # TEST SETUP
  # ============================================================

  setup do
    # Start a test Holon with default configuration
    {:ok, holon} =
      Holon.start_link(
        id: "test-holon-#{:erlang.unique_integer([:positive])}",
        type: :process,
        autonomy_level: :supervised
      )

    on_exit(fn ->
      if Process.alive?(holon) do
        try do
          Holon.trigger_apoptosis(holon, :test_cleanup)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    %{holon: holon}
  end

  # ============================================================
  # START_LINK TESTS
  # ============================================================

  describe "start_link/1" do
    test "starts a Holon with default options" do
      {:ok, pid} = Holon.start_link()
      assert Process.alive?(pid)
      Holon.trigger_apoptosis(pid, :test_cleanup)
    end

    test "starts a Holon with custom ID" do
      custom_id = "custom-holon-123"
      {:ok, pid} = Holon.start_link(id: custom_id)

      state = Holon.get_state(pid)
      assert state.id == custom_id

      Holon.trigger_apoptosis(pid, :test_cleanup)
    end

    test "starts a Holon with named registration" do
      {:ok, pid} = Holon.start_link(name: :named_test_holon)

      assert Process.whereis(:named_test_holon) == pid
      Holon.trigger_apoptosis(pid, :test_cleanup)
    end

    test "starts a Holon with all supported types" do
      types = [:system, :cluster, :node, :process]

      for type <- types do
        {:ok, pid} = Holon.start_link(type: type)
        state = Holon.get_state(pid)
        assert state.type == type
        Holon.trigger_apoptosis(pid, :test_cleanup)
      end
    end

    test "starts a Holon with parent reference" do
      {:ok, parent} = Holon.start_link(id: "parent-holon")
      {:ok, child} = Holon.start_link(id: "child-holon", parent: parent)

      child_state = Holon.get_state(child)
      assert child_state.parent_ref == parent

      Holon.trigger_apoptosis(parent, :test_cleanup)
    end

    test "starts a Holon with custom generation" do
      {:ok, pid} = Holon.start_link(generation: 5)

      state = Holon.get_state(pid)
      assert state.generation == 5

      Holon.trigger_apoptosis(pid, :test_cleanup)
    end

    test "starts a Holon with all autonomy levels" do
      levels = [:full, :supervised, :restricted, :passive]

      for level <- levels do
        {:ok, pid} = Holon.start_link(autonomy_level: level)
        state = Holon.get_state(pid)
        assert state.autonomy_level == level
        Holon.trigger_apoptosis(pid, :test_cleanup)
      end
    end

    test "initializes with healthy default state" do
      {:ok, pid} = Holon.start_link()

      state = Holon.get_state(pid)
      assert state.health_score == 1.0
      assert state.stress_score == 0.0
      assert state.energy_score == 1.0
      assert state.heal_attempts == 0
      assert state.intent == :idle
      assert state.target == :stable
      assert state.children == %{}

      Holon.trigger_apoptosis(pid, :test_cleanup)
    end
  end

  # ============================================================
  # VITAL_SIGNS TESTS - SC-BIO-001
  # ============================================================

  describe "get_vital_signs/1 - SC-BIO-001" do
    test "returns vital vector with all required fields", %{holon: holon} do
      vitals = Holon.get_vital_signs(holon)

      assert is_binary(vitals.id)
      assert vitals.type in [:system, :cluster, :node, :process]
      assert is_integer(vitals.generation) and vitals.generation >= 0
      assert is_float(vitals.health_index)
      assert is_float(vitals.stress_index)
      assert is_float(vitals.energy_index)
      assert is_atom(vitals.intent)
      assert is_atom(vitals.target)
    end

    test "SC-BIO-001: vital signs returns within 10ms latency constraint", %{holon: holon} do
      # Run multiple times to ensure consistency
      for _ <- 1..10 do
        {time_us, _result} = :timer.tc(fn -> Holon.get_vital_signs(holon) end)
        time_ms = time_us / 1000

        assert time_ms < 10,
               "Vital signs took #{time_ms}ms, exceeds SC-BIO-001 constraint of 10ms"
      end
    end

    test "vital signs reflect current state values", %{holon: holon} do
      state = Holon.get_state(holon)
      vitals = Holon.get_vital_signs(holon)

      assert vitals.id == state.id
      assert vitals.type == state.type
      assert vitals.generation == state.generation
      assert vitals.health_index == state.health_score
      assert vitals.stress_index == state.stress_score
      assert vitals.energy_index == state.energy_score
      assert vitals.intent == state.intent
      assert vitals.target == state.target
    end

    test "vital signs are idempotent (multiple calls return same result)", %{holon: holon} do
      vitals1 = Holon.get_vital_signs(holon)
      vitals2 = Holon.get_vital_signs(holon)
      vitals3 = Holon.get_vital_signs(holon)

      assert vitals1 == vitals2
      assert vitals2 == vitals3
    end
  end

  # ============================================================
  # HEALTH_CHECK TESTS - SC-BIO-004
  # ============================================================

  describe "request_health_check/1 - SC-BIO-004" do
    test "returns health report with all required fields", %{holon: holon} do
      report = Holon.request_health_check(holon)

      assert report.status in [:healthy, :degraded, :critical, :unknown]
      assert is_float(report.score) and report.score >= 0.0 and report.score <= 1.0
      assert is_list(report.checks)
      assert %DateTime{} = report.timestamp
    end

    test "health check includes expected check types", %{holon: holon} do
      report = Holon.request_health_check(holon)

      check_names = Enum.map(report.checks, fn {name, _result} -> name end)

      assert :memory in check_names
      assert :process_alive in check_names
      assert :energy_level in check_names
      assert :stress_level in check_names
      assert :children_responsive in check_names
    end

    test "SC-BIO-004: health check is idempotent (no side effects on state)", %{holon: holon} do
      state_before = Holon.get_state(holon)
      _report1 = Holon.request_health_check(holon)
      _report2 = Holon.request_health_check(holon)
      _report3 = Holon.request_health_check(holon)
      state_after = Holon.get_state(holon)

      # Core state values should not change from health checks
      assert state_before.id == state_after.id
      assert state_before.type == state_after.type
      assert state_before.generation == state_after.generation
      assert state_before.autonomy_level == state_after.autonomy_level
      assert state_before.children == state_after.children
      assert state_before.intent == state_after.intent
      assert state_before.target == state_after.target
    end

    test "healthy Holon reports healthy status", %{holon: holon} do
      report = Holon.request_health_check(holon)

      # Fresh Holon should be healthy
      assert report.status == :healthy
      assert report.score >= 0.8
    end

    test "check results use valid status atoms", %{holon: holon} do
      report = Holon.request_health_check(holon)

      for {_name, result} <- report.checks do
        assert result in [:pass, :fail, :warn]
      end
    end

    test "health check updates last_health_check timestamp", %{holon: holon} do
      state_before = Holon.get_state(holon)
      # Initial state may have nil last_health_check
      assert is_nil(state_before.last_health_check) or
               match?(%DateTime{}, state_before.last_health_check)

      _report = Holon.request_health_check(holon)
      state_after = Holon.get_state(holon)

      assert %DateTime{} = state_after.last_health_check
    end
  end

  # ============================================================
  # SELF_HEAL TESTS - SC-BIO-005
  # ============================================================

  describe "trigger_heal/2 - SC-BIO-005" do
    test "self-heal returns valid result types", %{holon: holon} do
      result = Holon.trigger_heal(holon, :test_issue)

      assert result in [
               {:ok, :recovered},
               {:ok, :partial},
               {:error, :unrecoverable}
             ]
    end

    test "self-heal increments heal attempts on partial recovery", %{holon: holon} do
      state_before = Holon.get_state(holon)
      assert state_before.heal_attempts == 0

      {:ok, :partial} = Holon.trigger_heal(holon, :critical_health)
      state_after = Holon.get_state(holon)

      assert state_after.heal_attempts == 1
    end

    test "successful recovery resets heal attempts to 0", %{holon: holon} do
      # First trigger a partial heal to increment counter
      {:ok, :partial} = Holon.trigger_heal(holon, :critical_health)
      state_mid = Holon.get_state(holon)
      assert state_mid.heal_attempts == 1

      # Now trigger a successful heal
      {:ok, :recovered} = Holon.trigger_heal(holon, :memory_pressure)
      state_after = Holon.get_state(holon)

      assert state_after.heal_attempts == 0
    end

    test "SC-BIO-005: self-heal is bounded to maximum 3 attempts", %{holon: holon} do
      # Exhaust the 3 allowed attempts
      {:ok, :partial} = Holon.trigger_heal(holon, :critical_health)
      {:ok, :partial} = Holon.trigger_heal(holon, :critical_health)
      {:ok, :partial} = Holon.trigger_heal(holon, :critical_health)

      state = Holon.get_state(holon)
      assert state.heal_attempts == 3

      # 4th attempt should fail with unrecoverable
      result = Holon.trigger_heal(holon, :critical_health)
      assert result == {:error, :unrecoverable}
    end

    test "memory_pressure issue triggers garbage collection recovery", %{holon: holon} do
      result = Holon.trigger_heal(holon, :memory_pressure)
      assert result == {:ok, :recovered}
    end

    test "unrecoverable_state issue returns unrecoverable error", %{holon: holon} do
      result = Holon.trigger_heal(holon, :unrecoverable_state)
      assert result == {:error, :unrecoverable}
    end

    test "system_failure issue returns unrecoverable error", %{holon: holon} do
      result = Holon.trigger_heal(holon, :system_failure)
      assert result == {:error, :unrecoverable}
    end

    test "unknown issues default to recovered", %{holon: holon} do
      result = Holon.trigger_heal(holon, :unknown_issue_type)
      assert result == {:ok, :recovered}
    end

    test "successful heal restores health and reduces stress", %{holon: holon} do
      # First degrade health
      {:ok, :partial} = Holon.trigger_heal(holon, :critical_health)
      state_degraded = Holon.get_state(holon)
      assert state_degraded.health_score == 0.7

      # Now fully recover
      {:ok, :recovered} = Holon.trigger_heal(holon, :memory_pressure)
      state_recovered = Holon.get_state(holon)

      assert state_recovered.health_score == 1.0
      assert state_recovered.stress_score == 0.1
    end
  end

  # ============================================================
  # DECISION TESTS - SC-BIO-006
  # ============================================================

  describe "request_decision/3 - SC-BIO-006" do
    test "returns decision with all required fields", %{holon: holon} do
      decision = Holon.request_decision(holon, :test_stimulus)

      assert is_atom(decision.action)
      assert is_float(decision.confidence)
      assert is_binary(decision.rationale)
      assert is_boolean(decision.delegated)
    end

    test "SC-BIO-006: full autonomy does not delegate decisions" do
      {:ok, full_holon} = Holon.start_link(autonomy_level: :full)

      decision = Holon.request_decision(full_holon, :test_stimulus)
      assert decision.delegated == false

      Holon.trigger_apoptosis(full_holon, :test_cleanup)
    end

    test "SC-BIO-006: supervised autonomy delegates risky decisions" do
      {:ok, supervised_holon} = Holon.start_link(autonomy_level: :supervised)

      # Non-risky decision
      decision_safe = Holon.request_decision(supervised_holon, :test, %{risky: false})
      assert decision_safe.delegated == false

      # Risky decision
      decision_risky = Holon.request_decision(supervised_holon, :test, %{risky: true})
      assert decision_risky.delegated == true

      Holon.trigger_apoptosis(supervised_holon, :test_cleanup)
    end

    test "SC-BIO-006: restricted autonomy always delegates" do
      {:ok, restricted_holon} = Holon.start_link(autonomy_level: :restricted)

      decision = Holon.request_decision(restricted_holon, :test_stimulus)
      assert decision.delegated == true

      Holon.trigger_apoptosis(restricted_holon, :test_cleanup)
    end

    test "SC-BIO-006: passive autonomy always delegates" do
      {:ok, passive_holon} = Holon.start_link(autonomy_level: :passive)

      decision = Holon.request_decision(passive_holon, :test_stimulus)
      assert decision.delegated == true

      Holon.trigger_apoptosis(passive_holon, :test_cleanup)
    end

    test "maps stimuli to appropriate actions", %{holon: holon} do
      stimuli_actions = [
        {:high_stress, :scale_up},
        {:low_stress, :scale_down},
        {:error_detected, :investigate},
        {:health_critical, :self_heal},
        {:unknown_stimulus, :observe}
      ]

      for {stimulus, expected_action} <- stimuli_actions do
        decision = Holon.request_decision(holon, stimulus)
        assert decision.action == expected_action
      end
    end

    test "confidence reflects health state", %{holon: holon} do
      # Healthy Holon should have high confidence
      decision_healthy = Holon.request_decision(holon, :test)
      assert decision_healthy.confidence >= 0.8

      # Degrade health
      {:ok, :partial} = Holon.trigger_heal(holon, :critical_health)
      decision_degraded = Holon.request_decision(holon, :test)

      # Confidence should be lower for degraded health
      assert decision_degraded.confidence < decision_healthy.confidence
    end

    test "delegated decisions have reduced confidence" do
      {:ok, passive_holon} = Holon.start_link(autonomy_level: :passive)

      decision = Holon.request_decision(passive_holon, :test)
      assert decision.delegated == true
      assert decision.confidence == 0.5

      Holon.trigger_apoptosis(passive_holon, :test_cleanup)
    end
  end

  # ============================================================
  # LIFECYCLE STATE TRANSITIONS
  # ============================================================

  describe "lifecycle state transitions" do
    test "SPAWN: Holon initializes in idle/stable state" do
      {:ok, holon} = Holon.start_link()

      state = Holon.get_state(holon)
      assert state.intent == :idle
      assert state.target == :stable

      Holon.trigger_apoptosis(holon, :test_cleanup)
    end

    test "ACTIVE: set_intent changes Holon intent" do
      {:ok, holon} = Holon.start_link()

      assert Holon.get_state(holon).intent == :idle

      :ok = Holon.set_intent(holon, :processing)
      # Allow async cast to process
      Process.sleep(10)

      assert Holon.get_state(holon).intent == :processing

      Holon.trigger_apoptosis(holon, :test_cleanup)
    end

    test "MITOSIS: creates child Holon with incremented generation" do
      {:ok, parent} = Holon.start_link(id: "parent-mitosis", generation: 0)

      {:ok, child_pid} = Holon.trigger_mitosis(parent)
      assert Process.alive?(child_pid)

      child_state = Holon.get_state(child_pid)
      assert child_state.generation == 1
      assert child_state.parent_ref == parent

      parent_state = Holon.get_state(parent)
      assert map_size(parent_state.children) == 1

      Holon.trigger_apoptosis(parent, :test_cleanup)
    end

    test "MITOSIS: reduces parent energy" do
      {:ok, parent} = Holon.start_link(id: "parent-energy")

      state_before = Holon.get_state(parent)
      assert state_before.energy_score == 1.0

      {:ok, _child} = Holon.trigger_mitosis(parent)

      state_after = Holon.get_state(parent)
      assert state_after.energy_score == 0.7

      Holon.trigger_apoptosis(parent, :test_cleanup)
    end

    test "MITOSIS: child inherits demoted autonomy level" do
      {:ok, parent} = Holon.start_link(autonomy_level: :full)

      {:ok, child_pid} = Holon.trigger_mitosis(parent)
      child_state = Holon.get_state(child_pid)

      # Full -> Supervised
      assert child_state.autonomy_level == :supervised

      Holon.trigger_apoptosis(parent, :test_cleanup)
    end

    test "APOPTOSIS: Holon stops cleanly" do
      {:ok, holon} = Holon.start_link()
      assert Process.alive?(holon)

      :ok = Holon.trigger_apoptosis(holon, :test_shutdown)

      # Allow time for shutdown
      Process.sleep(50)
      refute Process.alive?(holon)
    end

    test "APOPTOSIS: cascades to children" do
      {:ok, parent} = Holon.start_link(id: "cascade-parent")
      {:ok, child1} = Holon.trigger_mitosis(parent)
      {:ok, child2} = Holon.trigger_mitosis(parent)

      assert Process.alive?(parent)
      assert Process.alive?(child1)
      assert Process.alive?(child2)

      :ok = Holon.trigger_apoptosis(parent, :cascade_test)

      Process.sleep(100)

      refute Process.alive?(parent)
      refute Process.alive?(child1)
      refute Process.alive?(child2)
    end
  end

  # ============================================================
  # PARENT SIGNAL TESTS
  # ============================================================

  describe "parent_signal/2" do
    test "reduce_autonomy signal demotes autonomy level" do
      {:ok, holon} = Holon.start_link(autonomy_level: :full)

      assert Holon.get_state(holon).autonomy_level == :full

      :ok = Holon.parent_signal(holon, :reduce_autonomy)
      Process.sleep(10)

      assert Holon.get_state(holon).autonomy_level == :supervised

      Holon.trigger_apoptosis(holon, :test_cleanup)
    end

    test "increase_autonomy signal promotes autonomy level" do
      {:ok, holon} = Holon.start_link(autonomy_level: :passive)

      assert Holon.get_state(holon).autonomy_level == :passive

      :ok = Holon.parent_signal(holon, :increase_autonomy)
      Process.sleep(10)

      assert Holon.get_state(holon).autonomy_level == :restricted

      Holon.trigger_apoptosis(holon, :test_cleanup)
    end

    test "set_target signal updates target state" do
      {:ok, holon} = Holon.start_link()

      assert Holon.get_state(holon).target == :stable

      :ok = Holon.parent_signal(holon, {:set_target, :scaling})
      Process.sleep(10)

      assert Holon.get_state(holon).target == :scaling

      Holon.trigger_apoptosis(holon, :test_cleanup)
    end

    test "autonomy level has bounds (passive cannot demote further)" do
      {:ok, holon} = Holon.start_link(autonomy_level: :passive)

      :ok = Holon.parent_signal(holon, :reduce_autonomy)
      Process.sleep(10)

      # Still passive
      assert Holon.get_state(holon).autonomy_level == :passive

      Holon.trigger_apoptosis(holon, :test_cleanup)
    end

    test "autonomy level has bounds (full cannot promote further)" do
      {:ok, holon} = Holon.start_link(autonomy_level: :full)

      :ok = Holon.parent_signal(holon, :increase_autonomy)
      Process.sleep(10)

      # Still full
      assert Holon.get_state(holon).autonomy_level == :full

      Holon.trigger_apoptosis(holon, :test_cleanup)
    end
  end

  # ============================================================
  # CHILD REPORT TESTS
  # ============================================================

  describe "child_report/3" do
    test "child apoptosis report removes child from parent" do
      {:ok, parent} = Holon.start_link(id: "report-parent")
      {:ok, child} = Holon.trigger_mitosis(parent)

      parent_state = Holon.get_state(parent)
      assert map_size(parent_state.children) == 1

      child_id = Holon.get_state(child).id
      :ok = Holon.child_report(parent, child_id, {:apoptosis, :test})
      Process.sleep(10)

      parent_state_after = Holon.get_state(parent)
      assert map_size(parent_state_after.children) == 0

      Holon.trigger_apoptosis(parent, :test_cleanup)
    end
  end

  # ============================================================
  # GET_STATE TESTS
  # ============================================================

  describe "get_state/1" do
    test "returns complete State struct", %{holon: holon} do
      state = Holon.get_state(holon)

      assert %State{} = state
      assert is_binary(state.id)
      assert state.type in [:system, :cluster, :node, :process]
      assert is_float(state.health_score)
      assert is_float(state.stress_score)
      assert is_float(state.energy_score)
      assert state.autonomy_level in [:full, :supervised, :restricted, :passive]
      assert is_map(state.children)
      assert is_integer(state.generation)
      assert is_atom(state.intent)
      assert is_atom(state.target)
      assert is_integer(state.heal_attempts)
      assert %DateTime{} = state.started_at
      assert is_map(state.metadata)
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS
  # ============================================================

  describe "property-based tests" do
    @tag timeout: 60_000
    property "vital_signs always returns valid structure" do
      forall type <- PC.oneof([:system, :cluster, :node, :process]) do
        {:ok, holon} = Holon.start_link(type: type)
        vitals = Holon.get_vital_signs(holon)
        Holon.trigger_apoptosis(holon, :prop_cleanup)

        is_binary(vitals.id) and
          vitals.type == type and
          is_integer(vitals.generation) and
          vitals.generation >= 0 and
          is_float(vitals.health_index) and
          vitals.health_index >= 0.0 and vitals.health_index <= 1.0 and
          is_float(vitals.stress_index) and
          vitals.stress_index >= 0.0 and vitals.stress_index <= 1.0 and
          is_float(vitals.energy_index) and
          vitals.energy_index >= 0.0 and vitals.energy_index <= 1.0 and
          is_atom(vitals.intent) and
          is_atom(vitals.target)
      end
    end

    @tag timeout: 60_000
    property "health_check score is always between 0.0 and 1.0" do
      forall autonomy <- PC.oneof([:full, :supervised, :restricted, :passive]) do
        {:ok, holon} = Holon.start_link(autonomy_level: autonomy)
        report = Holon.request_health_check(holon)
        Holon.trigger_apoptosis(holon, :prop_cleanup)

        report.score >= 0.0 and report.score <= 1.0
      end
    end

    @tag timeout: 60_000
    property "heal attempts never exceed 3 (SC-BIO-005)" do
      forall n <- PC.choose(1, 10) do
        {:ok, holon} = Holon.start_link()

        # Try to heal n times
        for _ <- 1..n do
          Holon.trigger_heal(holon, :critical_health)
        end

        state = Holon.get_state(holon)
        Holon.trigger_apoptosis(holon, :prop_cleanup)

        # Heal attempts should never exceed 3 (reset on success or capped)
        state.heal_attempts <= 3
      end
    end
  end

  # ============================================================
  # CONCURRENCY TESTS
  # ============================================================

  describe "concurrency safety" do
    test "handles concurrent vital_signs requests", %{holon: holon} do
      tasks =
        for _ <- 1..100 do
          Task.async(fn -> Holon.get_vital_signs(holon) end)
        end

      results = Task.await_many(tasks, 5000)

      assert length(results) == 100
      assert Enum.all?(results, fn v -> is_map(v) and Map.has_key?(v, :id) end)
    end

    test "handles concurrent health_check requests", %{holon: holon} do
      tasks =
        for _ <- 1..50 do
          Task.async(fn -> Holon.request_health_check(holon) end)
        end

      results = Task.await_many(tasks, 5000)

      assert length(results) == 50

      assert Enum.all?(results, fn r -> r.status in [:healthy, :degraded, :critical, :unknown] end)
    end
  end
end
