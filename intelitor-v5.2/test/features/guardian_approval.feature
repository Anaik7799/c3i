# PRAJNA Guardian Approval Feature
# STAMP: SC-COV-004, SC-BDD-001, SC-PRAJNA-001, SC-PRAJNA-006, SC-PRAJNA-007
# Author: Cybernetic Architect
# Date: 2026-01-02
# Purpose: BDD validation of Guardian command approval flows in Prajna cockpit

Feature: Guardian Command Approval & Constitutional Validation
  As a Prajna operator
  I want all commands to be validated by Guardian
  So that unauthorized actions are prevented and constitutional invariants are preserved

  Background:
    Given the Guardian service is running
    And the Prajna cockpit is initialized
    And the GuardianIntegration GenServer is active
    And the circuit breaker is in "closed" state
    And I am authenticated as operator "prajna-admin"

  # =====================================================
  # CRITICAL: GUARDIAN APPROVAL WORKFLOWS
  # =====================================================

  @critical @SC-PRAJNA-001 @smoke
  Scenario: Successful command approval flow
    Given a valid command "refresh_metrics" with action type "monitoring"
    When I submit the command to Guardian via Prajna
    Then the Guardian should validate the command
    And the command should be approved
    And the command should be executed immediately
    And an audit record should be created in the immutable register
    And telemetry should emit "proposal_approved" event
    And the response should include the approved proposal

  @critical @SC-PRAJNA-001 @smoke
  Scenario: Command rejection due to constitutional violation
    Given a command that violates constitutional invariant "Ψ₀ Existence"
    When I submit the command to Guardian via Prajna
    Then the Guardian should validate the command
    And the Guardian should check constitutional invariants
    And the command should be vetoed
    And the veto reason should be "Constitutional violation: Ψ₀"
    And no execution should occur
    And an audit record should show the veto
    And telemetry should emit "proposal_vetoed" event

  @critical @SC-PRAJNA-001
  Scenario: Command with empty proposal rejected
    Given an empty proposal map
    When I submit the command to Guardian via Prajna
    Then the Guardian should reject during pre-validation
    And the error should be "empty_proposal"
    And telemetry should emit "prevalidation_failure" event
    And no Guardian validation should occur

  @critical @SC-PRAJNA-001
  Scenario: Command with forbidden fields rejected
    Given a command proposal with forbidden field "__struct__"
    When I submit the command to Guardian via Prajna
    Then the Guardian should reject during pre-validation
    And the error should be "forbidden_fields"
    And telemetry should emit "prevalidation_failure" event
    And no execution should occur

  # =====================================================
  # CRITICAL: TIMEOUT & RESILIENCE
  # =====================================================

  @critical @SC-SIL4-001 @resilience
  Scenario: Guardian timeout with graceful failure
    Given the Guardian timeout is configured to 1000ms
    And the Guardian service is slow to respond (2000ms latency)
    When I submit a command to Guardian via Prajna
    And the Guardian fails to respond within the timeout
    Then the command should fail with timeout error
    And the circuit breaker should record a failure
    And the failure count should increment
    And telemetry should emit "proposal_timeout" event
    And the client should receive {:error, :timeout}

  @critical @SC-SIL4-001 @resilience
  Scenario: Client timeout when waiting for GenServer
    Given the GuardianIntegration GenServer is very slow (10s processing)
    When I submit a command with 5000ms client timeout
    And the GenServer processing exceeds the timeout
    Then the submit should raise an :exit exception
    And the exception should be caught as timeout
    And the response should be {:error, :timeout}
    And telemetry should emit "client_timeout" event
    And the command should NOT be executed

  # =====================================================
  # CRITICAL: CIRCUIT BREAKER
  # =====================================================

  @critical @SC-SIL4-001 @circuit-breaker
  Scenario: Circuit breaker activation after threshold
    Given the circuit breaker threshold is 3 failures
    And the circuit is in "closed" state
    When I submit 3 commands that all timeout
    Then the circuit breaker should remain closed on failures 1-2
    And on the 3rd failure, the circuit should transition to "open"
    And a circuit state change event should be emitted
    And the last_failure_time should be recorded

  @critical @SC-SIL4-001 @circuit-breaker
  Scenario: Circuit breaker rejects new commands when open
    Given the circuit breaker is in "open" state
    When I submit a new command to Guardian
    Then the command should be rejected immediately
    And the error should be {:error, :circuit_open}
    And no Guardian validation should occur
    And telemetry should emit "circuit_rejected" event

  @critical @SC-SIL4-001 @circuit-breaker
  Scenario: Circuit breaker half-open transition
    Given the circuit breaker is in "open" state
    And the circuit reset timeout is 30000ms
    And 30000ms have elapsed since the last failure
    When I check the circuit state
    Then the circuit should transition to "half_open" state
    And a success on the next request should close the circuit
    And telemetry should emit "circuit_state" event with "half_open"

  @critical @SC-SIL4-001 @circuit-breaker
  Scenario: Circuit breaker recovery on successful call
    Given the circuit breaker is in "half_open" state
    When I submit a valid command that succeeds
    Then the Guardian should approve the command
    And the circuit should transition to "closed" state
    And the failure_count should reset to 0
    And telemetry should emit "circuit_state" event with "closed"

  # =====================================================
  # CRITICAL: CONSTITUTIONAL RECONFIGURATION
  # =====================================================

  @critical @SC-PRAJNA-006 @constitutional
  Scenario: Successful reconfiguration with constitutional check
    Given a reconfiguration proposal for "scale_workers"
    And the proposal targets "worker_agents"
    And the proposed_state is valid and regenerable
    When I submit the reconfiguration to Guardian
    Then the GuardianIntegration should route to ConstitutionalChecker
    And ConstitutionalChecker should verify all Ψ₀-Ψ₅ invariants
    And all invariants should pass
    And Guardian should approve the proposal
    And telemetry should emit "constitutional_passed" event
    And the reconfiguration should be executed

  @critical @SC-PRAJNA-006 @constitutional
  Scenario: Reconfiguration rejected - Ψ₁ regeneration violation
    Given a reconfiguration proposal for "deploy_system"
    And the proposed_state requires external dependencies
    And the state is NOT reconstructible from SQLite/DuckDB alone
    When I submit the reconfiguration to Guardian
    Then ConstitutionalChecker should detect Ψ₁ violation
    And the reconfiguration should be rejected
    And the error should be "Constitutional violation: psi_1_regeneration"
    And telemetry should emit "constitutional_violated" event with invariant "psi_1_regeneration"

  @critical @SC-PRAJNA-006 @constitutional
  Scenario: Reconfiguration rejected - Ψ₂ evolution violation
    Given a reconfiguration proposal with action "delete_history"
    When I submit the reconfiguration to Guardian
    Then ConstitutionalChecker should detect Ψ₂ violation
    And the error should indicate "Evolution history destruction"
    And telemetry should emit "constitutional_violated" event with invariant "psi_2_evolution"
    And the DuckDB history should remain unchanged

  @critical @SC-PRAJNA-006 @constitutional
  Scenario: Reconfiguration rejected - Ψ₃ verification violation
    Given a reconfiguration proposal with action "disable_verification"
    When I submit the reconfiguration to Guardian
    Then ConstitutionalChecker should detect Ψ₃ violation
    And the error should include "Verification capability"
    And telemetry should emit "constitutional_violated" event with invariant "psi_3_verification"

  @critical @SC-PRAJNA-006 @constitutional
  Scenario: Reconfiguration rejected - Guardian veto during constitutional check
    Given a valid reconfiguration proposal (all Ψ₀-Ψ₅ pass)
    But Guardian decides to veto the proposal
    When I submit the reconfiguration to Guardian
    Then ConstitutionalChecker should pass all invariants
    And request_guardian_approval should return {:error, :guardian_veto, reason}
    And GuardianIntegration should return {:error, :guardian_veto, reason}
    And telemetry should emit "constitutional_vetoed" event

  # =====================================================
  # HIGH: TWO-STEP COMMIT FOR DESTRUCTIVE ACTIONS
  # =====================================================

  @high @SC-PRAJNA-007 @two-step-commit
  Scenario: Two-step commit initiation
    Given a destructive action "clear_all_metrics"
    And the action requires two-step confirmation
    When I initiate the action with Guardian
    Then the Guardian should recognize it as destructive
    And a confirmation request should be generated
    And the confirmation token should be unique and time-limited
    And confirmation timeout should be 30 seconds
    And telemetry should emit "destructive_action_initiated" event

  @high @SC-PRAJNA-007 @two-step-commit
  Scenario: Two-step commit with confirmation
    Given a destructive action "delete_all_agents"
    And the confirmation token is valid
    And the confirmation is within the 30-second window
    When I submit the confirmation
    Then the destructive action should be executed
    And an immutable record should be created in the register
    And the confirmation_token should be marked as consumed
    And telemetry should emit "destructive_action_executed" event

  @high @SC-PRAJNA-007 @two-step-commit
  Scenario: Two-step commit confirmation timeout
    Given a destructive action "purge_history"
    And the confirmation was initiated 30 seconds ago
    When I attempt to confirm the action
    Then the confirmation should be rejected
    And the error should be "Confirmation expired"
    And no changes should occur
    And telemetry should emit "destructive_action_timeout" event

  @high @SC-PRAJNA-007 @two-step-commit
  Scenario: Two-step commit cancellation
    Given a destructive action "clear_registry"
    And a pending confirmation
    When I cancel the action before confirmation
    Then the confirmation token should be invalidated
    And no execution should occur
    And telemetry should emit "destructive_action_cancelled" event

  # =====================================================
  # HIGH: HEALTH & LIVENESS
  # =====================================================

  @high @SC-PRAJNA-004 @health
  Scenario: Guardian health check success
    Given Guardian is running and responsive
    When I call GuardianIntegration.healthy?/0
    Then the function should return true
    And the circuit state should be "closed" or "half_open"
    And the health_status should be "healthy"

  @high @SC-PRAJNA-004 @health
  Scenario: Guardian health check failure
    Given Guardian service is unreachable
    When I call GuardianIntegration.healthy?/0
    Then the function should return false
    And the circuit state may transition to "open"
    And telemetry should track the health degradation

  @high @SC-PRAJNA-004 @health
  Scenario: Guardian alive check
    Given the GuardianIntegration GenServer is running
    When I call GuardianIntegration.alive?/0
    Then the function should return true
    And it should attempt to reach Guardian.alive?/0 with 1000ms timeout
    And telemetry should emit "alive_check" event

  @high @SC-PRAJNA-004 @health
  Scenario: Periodic health monitoring
    Given the health check interval is 5000ms
    When the health_check timer fires
    Then Guardian.alive?/0 should be called
    And the health_status should be updated
    And if status changed, telemetry should emit "health_status" event

  # =====================================================
  # MEDIUM: RETRY LOGIC & EXPONENTIAL BACKOFF
  # =====================================================

  @medium @SC-API-003 @retry
  Scenario: Automatic retry on transient timeout
    Given a command that initially times out
    And submit_proposal_with_retry is called with max_attempts: 3
    When the first attempt times out
    And the second attempt succeeds
    Then the retry should wait using exponential backoff
    And the backoff delay should be calculated with jitter
    And the final result should be {:ok, approved}
    And telemetry should emit "retry_waiting" event

  @medium @SC-API-003 @retry
  Scenario: Max retries exceeded
    Given a command that always times out
    And submit_proposal_with_retry is called with max_attempts: 2
    When both attempts timeout
    Then the function should return {:error, :max_retries_exceeded}
    And telemetry should emit "max_retries_exceeded" event
    And the circuit breaker should record failures

  @medium @SC-API-003 @retry
  Scenario: Non-retryable errors not retried
    Given a command with non-retryable error "invalid_proposal_type"
    When I call submit_proposal_with_retry
    Then the first attempt should return {:error, :invalid_proposal_type}
    And no retry should be attempted
    And telemetry should emit error event

  @medium @SC-API-003 @retry
  Scenario: Veto is not retried
    Given a command that Guardian vetoes
    When I call submit_proposal_with_retry
    Then the result should be {:veto, reason, fallback}
    And no retry should be attempted
    And telemetry should emit "proposal_vetoed" event

  # =====================================================
  # MEDIUM: IMMUTABLE REGISTER LOGGING
  # =====================================================

  @medium @SC-PRAJNA-003 @immutable-register
  Scenario: Guardian decision logged to immutable register
    Given a command is submitted to Guardian
    When Guardian makes a decision (approve or veto)
    Then log_to_immutable_register should be called
    And the payload should include:
      | Field | Description |
      | change_type | "guardian_decision" |
      | request_id | UUID of the request |
      | proposal_type | Type of command |
      | proposal_action | Action within the command |
      | decision | "approved" or "vetoed" |
      | reason | If vetoed, the reason |
      | timestamp | UTC timestamp |
    And telemetry should emit "immutable_log" event with block_hash

  @medium @SC-PRAJNA-003 @immutable-register
  Scenario: Immutable register logging failure handling
    Given ImmutableState.record fails
    When I submit a command that gets approved
    Then the approval should still complete
    And ImmutableState logging failure should be caught
    And a warning should be logged
    And telemetry should emit "audit_failure" event

  # =====================================================
  # MEDIUM: FALLBACK & GRACEFUL DEGRADATION
  # =====================================================

  @medium @SC-BIO-007 @fallback
  Scenario: Fallback action on scaling veto
    Given a command of type "scaling" that is vetoed
    When Guardian rejects the proposal
    Then the fallback should be calculated
    And the fallback action should be "maintain_current"
    And the reason should be "safety_veto"
    And the system should maintain its current agent count

  @medium @SC-BIO-007 @fallback
  Scenario: Fallback action on deployment veto
    Given a command of type "deployment" that is vetoed
    When Guardian rejects the proposal
    Then the fallback action should be "rollback"
    And any partial deployment should be reversed

  @medium @SC-BIO-007 @fallback
  Scenario: Default fallback for unknown command types
    Given a command of unknown type that is vetoed
    When Guardian rejects the proposal
    Then the fallback action should be "noop"
    And the system should make no changes

  # =====================================================
  # MEDIUM: STATELESS FALLBACK (DEV MODE)
  # =====================================================

  @medium @test-mode @fallback
  Scenario: GenServer unavailable in dev mode - stateless fallback
    Given the GuardianIntegration GenServer is not running
    And the environment is "dev"
    When I call submit_proposal with a command
    Then execute_stateless should be used as fallback
    And Guardian.validate_proposal should still be called
    And the command should be processed (if approved)
    And a warning should be logged

  @critical @test-mode @fallback
  Scenario: GenServer unavailable in production mode - fail-closed
    Given the GuardianIntegration GenServer is not running
    And the environment is "prod"
    And fail_closed_mode is enabled
    When I call submit_proposal with a command
    Then the response should be {:error, :guardian_unavailable}
    And no execution should occur
    And telemetry should emit "sil4_violation" event
    And an error should be logged

  # =====================================================
  # MEDIUM: APPROVAL RATE TRACKING
  # =====================================================

  @medium @metrics
  Scenario: Approval rate calculation
    Given a GuardianIntegration state with:
      | approval_count | 8 |
      | veto_count | 2 |
    When I call calculate_approval_rate/1
    Then the approval_rate should be 0.8 (80%)
    And this should be included in guardian_health/0 response

  @medium @metrics
  Scenario: Approval rate with no decisions
    Given a GuardianIntegration state with:
      | approval_count | 0 |
      | veto_count | 0 |
    When I call calculate_approval_rate/1
    Then the approval_rate should be 1.0 (100% default)

  # =====================================================
  # MEDIUM: PRODUCTION MODE DETECTION
  # =====================================================

  @medium @production
  Scenario: Production mode detection
    Given Mix.env() returns :prod
    When I call production_mode?/0
    Then the function should return true
    And Guardian startup verification should be mandatory

  @medium @production
  Scenario: Dev mode detection
    Given Mix.env() returns :dev
    When I call production_mode?/0
    Then the function should return false
    And Guardian startup verification should be skipped

  # =====================================================
  # INTEGRATION: END-TO-END WORKFLOWS
  # =====================================================

  @integration @smoke
  Scenario: Complete approval workflow with audit trail
    Given a valid command for "refresh_metrics"
    When I submit the command to Guardian
    And Guardian approves the command
    And execute_with_approval wrapper is used
    Then the execution function should be called
    And the immutable register should log the decision
    And telemetry should emit all relevant events:
      | Event |
      | proposal_submitted |
      | proposal_approved |
      | immutable_log |
    And the command result should be returned to the caller

  @integration @smoke
  Scenario: Complete veto workflow with fallback
    Given a command that violates constitutional invariants
    When I submit the command to Guardian
    And Guardian vetoes the proposal
    And execute_with_approval wrapper is used with fallback
    Then the fallback function should be called
    And the immutable register should log the veto
    And telemetry should emit all relevant events:
      | Event |
      | proposal_vetoed |
      | immutable_log |
    And the fallback result should be returned

  @integration @resilience
  Scenario: Complete resilience workflow - timeout, retry, success
    Given a command that times out once, then succeeds
    When I call submit_proposal_with_retry with max_attempts: 3
    Then the first attempt should timeout
    Then the circuit breaker should record a failure
    And exponential backoff should delay the retry
    And the second attempt should succeed
    Then the result should be {:ok, approved}
    And the circuit breaker should reset on success

  @integration @resilience
  Scenario: Complete failure scenario - all retries exhausted
    Given a command that always times out
    When I call submit_proposal_with_retry with max_attempts: 3
    Then all 3 attempts should timeout
    And the circuit breaker should open after 3 failures
    And subsequent commands should fail fast without retrying
    And the final result should be {:error, :max_retries_exceeded}

  # =====================================================
  # SAFETY CRITICAL: FAIL-SAFE BEHAVIORS
  # =====================================================

  @critical @safety @SIL4
  Scenario: Unknown Guardian response triggers fail-safe deny
    Given ConstitutionalChecker.request_guardian_approval is called
    And Guardian returns an unexpected value (not a known type)
    When the response is processed
    Then the system should fail-safe DENY the proposal
    And telemetry should emit "fail_safe_deny" event
    And an error should be logged
    And the result should be {:error, :guardian_veto, "Fail-safe: Unknown Guardian response"}

  @critical @safety @SIL4
  Scenario: Constitutional invariant failure triggers immediate halt
    Given a reconfiguration proposal
    When ConstitutionalChecker detects any Ψ₀-Ψ₅ violation
    Then the verification should immediately halt
    And no Guardian validation should proceed
    And telemetry should emit "constitutional_violated" event
    And the proposal should be rejected

  @critical @safety @SIL4
  Scenario: Circuit breaker prevents cascading failures
    Given Guardian service is experiencing issues
    And circuit breaker threshold is 3
    When 3 failures occur within a short timeframe
    Then the circuit should open immediately
    And subsequent commands should be rejected fast
    And system resources should be preserved
    And manual reset should be required to recover
