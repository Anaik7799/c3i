defmodule Indrajaal.Cognitive.GuardianSafetyIntegrationTest do
  @moduledoc """
  L3.2: Guardian Safety Validation Integration Tests.

  Tests the Guardian module's role as the Simplex Architecture gatekeeper
  for all AI/Autonomic decisions.

  STAMP Constraints:
  - SC-SEC-001: No code execution without review
  - SC-RES-001: Resource limits (prevent exhaustion attacks)
  - SC-ACT-001: Actuator limits (physics-based checks)
  - SC-GUARD-001: Guardian must use Envelope for constraint values
  - SC-GUARD-002: Guardian must integrate with DeadMansSwitch
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Safety.Envelope

  setup do
    # Ensure Guardian is started for tests
    case GenServer.whereis(Guardian) do
      nil ->
        {:ok, _pid} = Guardian.start_link()
        :ok

      _pid ->
        :ok
    end

    :ok
  end

  describe "L3.2: Safe Proposal Validation" do
    test "approves safe scale_up proposal within limits" do
      proposal = %{action: :scale_up, quantity: 2}

      result = Guardian.validate_proposal(proposal)

      assert {:ok, ^proposal} = result
    end

    test "approves safe memory allocation proposal" do
      proposal = %{action: :allocate_memory, mb: 512}

      result = Guardian.validate_proposal(proposal)

      assert {:ok, ^proposal} = result
    end

    test "approves safe connection request" do
      proposal = %{action: :open_connections, count: 10}

      result = Guardian.validate_proposal(proposal)

      assert {:ok, ^proposal} = result
    end

    test "approves harmless proposals without action" do
      proposal = %{data: "test", value: 42}

      result = Guardian.validate_proposal(proposal)

      assert {:ok, ^proposal} = result
    end
  end

  describe "L3.2: Forbidden Operation Detection (SC-SEC)" do
    test "vetoes rm_rf action" do
      proposal = %{action: :rm_rf}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, reason, _fallback} = result
      assert reason in [:forbidden_operation_blocked, :forbidden_operation_detected]
    end

    test "vetoes chmod_777 action" do
      proposal = %{action: :chmod_777}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, reason, _fallback} = result
      assert reason in [:forbidden_operation_blocked, :forbidden_operation_detected]
    end

    test "vetoes exec_unverified action" do
      proposal = %{action: :exec_unverified}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, reason, _fallback} = result
      assert reason in [:forbidden_operation_blocked, :forbidden_operation_detected]
    end

    test "vetoes command containing dangerous patterns" do
      # Using exec_command which checks patterns like chmod 777
      proposal = %{action: :exec_command, command: "chmod 777 /etc/passwd"}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, reason, _fallback} = result
      assert reason in [:forbidden_operation_detected, :dangerous_pattern_detected]
    end

    test "vetoes rm -rf command pattern" do
      proposal = %{action: :exec_command, command: "rm -rf /var/log"}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, reason, _fallback} = result
      assert reason in [:forbidden_operation_detected, :dangerous_pattern_detected]
    end
  end

  describe "L3.2: Resource Limit Enforcement (SC-RES)" do
    test "vetoes excessive scale_up request" do
      # Request more FLAME nodes than allowed
      proposal = %{action: :scale_up, quantity: 1000}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, :resource_limit_exceeded, _fallback} = result
    end

    test "vetoes excessive memory allocation" do
      # Request more RAM than allowed
      proposal = %{action: :allocate_memory, mb: 100_000}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, :memory_limit_exceeded, _fallback} = result
    end

    test "vetoes excessive connection count" do
      # Request more connections than allowed
      proposal = %{action: :open_connections, count: 1000}

      result = Guardian.validate_proposal(proposal)

      assert {:veto, :db_connection_limit_exceeded, _fallback} = result
    end
  end

  describe "L3.2: Guardian Status Tracking" do
    test "status reports running state" do
      status = Guardian.status()

      assert status.running == true
      assert is_integer(status.validations)
      assert is_integer(status.violations)
    end

    test "status tracks validation count" do
      initial_status = Guardian.status()
      initial_validations = initial_status.validations

      # Perform a validation
      Guardian.validate_proposal(%{action: :test})

      new_status = Guardian.status()
      assert new_status.validations == initial_validations + 1
    end

    test "status tracks violation count" do
      initial_status = Guardian.status()
      initial_violations = initial_status.violations

      # Trigger a violation
      Guardian.validate_proposal(%{action: :rm_rf})

      new_status = Guardian.status()
      assert new_status.violations == initial_violations + 1
    end

    test "status includes uptime" do
      status = Guardian.status()

      assert is_integer(status.uptime_seconds)
      assert status.uptime_seconds >= 0
    end
  end

  describe "L3.2: Guardian Health Check" do
    test "health check returns comprehensive status" do
      health = Guardian.health_check()

      assert Map.has_key?(health, :guardian)
      assert Map.has_key?(health, :envelope)
      assert Map.has_key?(health, :dead_mans_switch)
      assert Map.has_key?(health, :overall_healthy)
    end

    test "health check includes DeadMansSwitch metrics" do
      health = Guardian.health_check()

      dms = health.dead_mans_switch
      assert Map.has_key?(dms, :state)
      assert Map.has_key?(dms, :heartbeats_received)
      assert Map.has_key?(dms, :heartbeats_missed)
      assert Map.has_key?(dms, :failsafe_triggers)
    end

    test "health check accepts metrics parameter" do
      metrics = %{cpu: 50, memory: 60}
      health = Guardian.health_check(metrics)

      assert is_map(health)
    end
  end

  describe "L3.2: Envelope Integration (SC-GUARD-001)" do
    test "constraints are retrieved from Envelope" do
      constraints = Guardian.constraints()

      assert is_map(constraints) or is_list(constraints)
    end

    test "forbidden operations come from Envelope" do
      forbidden = Envelope.forbidden_operations()

      assert is_list(forbidden)
      assert :rm_rf in forbidden
    end
  end

  describe "L3.2: Safe Fallback Generation" do
    test "veto includes safe fallback proposal" do
      proposal = %{action: :rm_rf}

      {:veto, _reason, fallback} = Guardian.validate_proposal(proposal)

      assert is_map(fallback)
      assert Map.has_key?(fallback, :action) or Map.has_key?(fallback, :safe_action)
    end

    test "fallback for resource violation suggests reduced allocation" do
      proposal = %{action: :scale_up, quantity: 1000}

      {:veto, :resource_limit_exceeded, fallback} = Guardian.validate_proposal(proposal)

      assert is_map(fallback)
    end
  end

  describe "L3.2: Validation without GenServer" do
    test "validate_proposal works even without running GenServer" do
      # This tests the fallback mechanism
      proposal = %{action: :test_action}

      # Should not crash even if GenServer is temporarily unavailable
      result = Guardian.validate_proposal(proposal)

      # Result should be either {:ok, _} or {:veto, _, _}
      assert match?({:ok, _}, result) or match?({:veto, _, _}, result)
    end
  end
end
