@planning @circuit_breaker @resilience @critical
Feature: Planning System Circuit Breaker for Violation Handling
  As the Circuit Breaker mechanism
  I need to protect the Planning System from cascading failures due to repeated violations
  So that the system can gracefully degrade and recover without catastrophic failure

  Background:
    Given the Circuit Breaker is initialized with configuration:
      | parameter                     | value     |
      | violation_threshold           | 5         |
      | time_window                   | 60s       |
      | circuit_open_duration         | 30s       |
      | half_open_test_requests       | 3         |
      | circuit_break_cooldown        | 300s      |
    And the Safety Kernel is monitoring all planning operations
    And violation counters are reset to 0
    And the circuit is in CLOSED state

  # ============================================================================
  # SINGLE VIOLATION SCENARIOS
  # ============================================================================

  @smoke @single_violation @low_severity
  Scenario: Single low-severity violation is logged but doesn't trip circuit
    Given the circuit is in CLOSED state
    When an AI Agent attempts to read PROJECT_TODOLIST.md (SC-TODO-001 violation)
    Then the violation should be:
      | attribute         | value                 |
      | severity          | CRITICAL              |
      | violation_type    | SC-TODO-001           |
      | entity            | AI_Agent              |
      | action            | read_file             |
      | blocked           | true                  |
    And the violation counter should be incremented to 1
    And the circuit should remain in CLOSED state
    And the violation should be logged to Immutable Register
    And Prajna Sentinel should receive a warning alert

  @single_violation @medium_severity
  Scenario: Single medium-severity violation increments counter
    Given the circuit is in CLOSED state
    And the violation counter is at 2
    When a planning operation violates SC-BRIDGE-002 (Latency Budget)
    Then the violation counter should be incremented to 3
    And the circuit should remain in CLOSED state
    And the operation should be allowed to complete
    And a warning should be logged about approaching threshold

  @single_violation @high_severity
  Scenario: Single high-severity violation counts double
    Given the circuit is in CLOSED state
    And the violation counter is at 3
    When a constitutional invariant violation (Ψ₁) is detected
    Then the violation should count as 2 violations
    And the violation counter should jump to 5
    And the circuit should OPEN immediately (threshold reached)
    And all subsequent operations should be blocked

  @single_violation @recovery
  Scenario: Violation counter decays over time
    Given the circuit is in CLOSED state
    And the violation counter is at 3
    When 60 seconds pass without new violations
    Then the violation counter should decay by 50%
    And the counter should be reduced to 1.5 (rounded to 2)
    And the decay should continue every 60 seconds until counter reaches 0

  # ============================================================================
  # MULTIPLE VIOLATION SCENARIOS
  # ============================================================================

  @smoke @multiple_violations @threshold
  Scenario: Multiple violations within time window trip circuit
    Given the circuit is in CLOSED state
    And the violation counter is at 0
    When the following violations occur within 60 seconds:
      | time_offset | violation_type  | severity  | count_increment |
      | 0s          | SC-TODO-001     | CRITICAL  | 1               |
      | 10s         | SC-TODO-001     | CRITICAL  | 1               |
      | 20s         | SC-PLAN-001     | CRITICAL  | 1               |
      | 30s         | SC-FUNC-003     | CRITICAL  | 1               |
      | 40s         | SC-TODO-001     | CRITICAL  | 1               |
    Then the violation counter should reach 5
    And the circuit should transition to OPEN state
    And a critical alert should be sent to Prajna Sentinel
    And the state change should be logged to Immutable Register

  @multiple_violations @burst
  Scenario: Burst of violations in short period
    Given the circuit is in CLOSED state
    When 10 violations occur within 5 seconds
    Then the circuit should OPEN immediately
    And subsequent operations should be blocked
    And an emergency alert should be triggered
    And the burst should be analyzed for:
      | analysis_aspect           | action                        |
      | Common violation pattern  | Identify root cause           |
      | Violating entity          | Potential security threat     |
      | Operation type            | System misconfiguration       |
    And automated remediation should be attempted if pattern is recognized

  @multiple_violations @different_types
  Scenario: Multiple violation types accumulate
    Given the circuit is in CLOSED state
    When violations of different types occur:
      | violation_type  | count | severity  |
      | SC-TODO-001     | 2     | CRITICAL  |
      | SC-PLAN-002     | 1     | HIGH      |
      | SC-FUNC-001     | 1     | INFINITE  |
      | SC-BRIDGE-002   | 1     | HIGH      |
    Then all violations should accumulate in counter
    And the counter should be at 5 (2+1+1+1)
    And the circuit should OPEN
    And violation breakdown should be available in telemetry

  @multiple_violations @cascade
  Scenario: Cascading failures trigger circuit faster
    Given the circuit is in CLOSED state
    When a primary failure causes secondary violations:
      | sequence | failure_type              | cascades_to                  | count |
      | 1        | SQLite connection lost    | -                            | 1     |
      | 2        | Task creation fails       | SQLite connection lost       | 1     |
      | 3        | DuckDB append fails       | SQLite connection lost       | 1     |
      | 4        | Zenoh publish fails       | SQLite connection lost       | 1     |
      | 5        | State sync fails          | SQLite connection lost       | 1     |
    Then the circuit should detect cascade pattern
    And should OPEN circuit at 3 violations (accelerated threshold)
    And should identify SQLite connection as root cause
    And should trigger targeted remediation (reconnect SQLite)

  # ============================================================================
  # CIRCUIT BREAKER ACTIVATION SCENARIOS
  # ============================================================================

  @smoke @activation @immediate
  Scenario: Circuit opens immediately on threshold breach
    Given the circuit is in CLOSED state
    And the violation counter is at 4
    When one more violation occurs
    Then the circuit should transition to OPEN state within 100ms
    And all pending operations should be evaluated:
      | operation_state       | action            |
      | Not started           | Blocked           |
      | In pre-validation     | Allowed to finish |
      | In execution          | Allowed to finish |
      | In post-validation    | Allowed to finish |
    And a circuit OPEN event should be published to Zenoh

  @activation @blocking
  Scenario: Circuit OPEN blocks new operations
    Given the circuit is in OPEN state
    When a user attempts to create a new task
    Then the operation should be blocked immediately
    And the user should receive error message:
      """
      Planning System is temporarily unavailable due to safety violations.
      Circuit Breaker is active. Please try again in 30 seconds.
      Incident ID: [incident-id]
      """
    And the blocked operation should be logged
    And the user should be provided with incident ID for tracking

  @activation @queueing
  Scenario: Circuit OPEN queues non-critical operations
    Given the circuit is in OPEN state
    When a non-critical planning operation is requested
    Then the operation should be queued for later execution
    And the queue should have:
      | property          | value         |
      | max_queue_size    | 1000          |
      | max_queue_time    | 5 minutes     |
      | queue_order       | FIFO          |
    And the user should receive confirmation of queueing
    And when circuit closes, queued operations should execute automatically

  @activation @critical_operations
  Scenario: Circuit OPEN allows critical operations with Guardian approval
    Given the circuit is in OPEN state
    When a P0 priority operation is requested by authorized user
    Then the operation should be routed to Guardian for evaluation
    And Guardian should assess:
      | criterion                     | weight |
      | Operation criticality         | 0.40   |
      | Risk of further violations    | 0.30   |
      | Founder's Directive alignment | 0.20   |
      | System recovery impact        | 0.10   |
    And if Guardian approves, operation should execute with enhanced monitoring
    And if Guardian rejects, operation should be queued

  @activation @telemetry
  Scenario: Circuit activation publishes comprehensive telemetry
    Given the circuit transitions from CLOSED to OPEN
    Then telemetry should be published to:
      | topic                                     | content                           |
      | indrajaal/circuit_breaker/state           | State change event                |
      | indrajaal/circuit_breaker/violations      | Violation history (last 100)      |
      | indrajaal/circuit_breaker/metrics         | Counter, threshold, time window   |
      | indrajaal/sentinel/alerts                 | Critical alert                    |
      | indrajaal/prajna/incidents                | Incident report                   |
    And telemetry should include:
      | field                 | type          |
      | circuit_state         | String        |
      | violation_count       | Integer       |
      | time_to_close         | Duration      |
      | recent_violations     | Array         |
      | suggested_remediation | String        |

  # ============================================================================
  # CIRCUIT BREAKER RESET SCENARIOS
  # ============================================================================

  @smoke @reset @timer
  Scenario: Circuit transitions to HALF_OPEN after timeout
    Given the circuit is in OPEN state for 28 seconds
    When 30 seconds have elapsed since circuit opened
    Then the circuit should automatically transition to HALF_OPEN state
    And a limited number of test requests should be allowed
    And test requests should be monitored closely
    And the transition should be logged

  @reset @half_open @success
  Scenario: Successful test requests close circuit
    Given the circuit is in HALF_OPEN state
    When 3 consecutive test requests succeed without violations
    Then the circuit should transition to CLOSED state
    And the violation counter should be reset to 0
    And normal operations should resume
    And a circuit CLOSED event should be published
    And the recovery should be logged to Immutable Register

  @reset @half_open @failure
  Scenario: Failed test request reopens circuit
    Given the circuit is in HALF_OPEN state
    And 2 test requests have succeeded
    When the 3rd test request causes a violation
    Then the circuit should immediately transition back to OPEN state
    And the circuit_open_duration should be doubled to 60 seconds
    And the failure should be logged with detailed diagnostics
    And an alert should notify operators of persistent issue

  @reset @manual
  Scenario: Operator manually resets circuit with Guardian approval
    Given the circuit is in OPEN state
    And an operator has identified and fixed the root cause
    When the operator requests manual circuit reset
    Then the request should be routed to Guardian
    And Guardian should verify:
      | verification_check                | required |
      | Root cause identified             | true     |
      | Fix has been applied              | true     |
      | Fix has been tested               | true     |
      | No violations in last 5 minutes   | true     |
    And if verified, Guardian should approve reset
    And circuit should transition to HALF_OPEN for gradual recovery

  @reset @decay
  Scenario: Violation counter decays during OPEN state
    Given the circuit is in OPEN state with counter at 5
    When 60 seconds pass
    Then the violation counter should decay by 20% (to 4)
    And decay should continue every 60 seconds
    And when counter reaches 0, circuit should attempt HALF_OPEN transition
    And decay rate should be slower in OPEN state than CLOSED state

  # ============================================================================
  # CIRCUIT BREAKER STATE TRANSITIONS
  # ============================================================================

  @state_transitions @closed_to_open
  Scenario: Valid CLOSED -> OPEN transition
    Given the circuit is in CLOSED state
    When violation threshold is exceeded
    Then the state transition should be:
      | from_state  | to_state | trigger                  | validation        |
      | CLOSED      | OPEN     | Threshold exceeded       | Immediate         |
    And state transition should be atomic
    And transition should be logged with:
      | field                 | required |
      | timestamp             | true     |
      | from_state            | true     |
      | to_state              | true     |
      | trigger_event         | true     |
      | violation_count       | true     |
      | decision_maker        | true     |

  @state_transitions @open_to_half_open
  Scenario: Valid OPEN -> HALF_OPEN transition
    Given the circuit is in OPEN state
    When the open duration timeout expires
    Then the state transition should be:
      | from_state  | to_state    | trigger               | validation        |
      | OPEN        | HALF_OPEN   | Timeout expired       | Timer-based       |
    And test request quota should be initialized to 3
    And enhanced monitoring should be activated

  @state_transitions @half_open_to_closed
  Scenario: Valid HALF_OPEN -> CLOSED transition
    Given the circuit is in HALF_OPEN state
    When all test requests succeed
    Then the state transition should be:
      | from_state  | to_state | trigger                  | validation             |
      | HALF_OPEN   | CLOSED   | All tests passed         | Success verification   |
    And violation counter should be reset to 0
    And normal operation mode should be restored
    And success should be celebrated in telemetry

  @state_transitions @half_open_to_open
  Scenario: Valid HALF_OPEN -> OPEN transition
    Given the circuit is in HALF_OPEN state
    When a test request fails with violation
    Then the state transition should be:
      | from_state  | to_state | trigger                  | validation        |
      | HALF_OPEN   | OPEN     | Test failed              | Failure detection |
    And open duration should be extended
    And failure analysis should be performed

  @state_transitions @invalid
  Scenario: Invalid state transitions are rejected
    Given the circuit is in any state
    When an invalid state transition is attempted:
      | from_state  | to_state    | reason                      |
      | CLOSED      | HALF_OPEN   | Can't skip OPEN             |
      | OPEN        | CLOSED      | Must go through HALF_OPEN   |
      | HALF_OPEN   | HALF_OPEN   | Already in state            |
    Then the transition should be rejected
    And an error should be logged
    And the circuit should remain in current state
    And an alert should be sent for investigation

  # ============================================================================
  # INTEGRATION WITH SAFETY SYSTEMS
  # ============================================================================

  @integration @guardian
  Scenario: Circuit Breaker coordinates with Guardian
    Given the circuit detects a pattern of violations
    When the circuit is about to open
    Then it should notify Guardian with:
      | information               | included |
      | Violation history         | true     |
      | Root cause analysis       | true     |
      | Suggested remediation     | true     |
      | Impact assessment         | true     |
    And Guardian should provide strategic guidance
    And Guardian may override circuit decision if warranted

  @integration @sentinel
  Scenario: Circuit Breaker feeds data to Sentinel
    Given the circuit is monitoring violations
    When violations occur
    Then violation data should be sent to Sentinel for:
      | analysis_type                 | purpose                       |
      | Threat pattern recognition    | Security threat detection     |
      | Anomaly detection             | Unusual behavior              |
      | Predictive analysis           | Pre-failure warning           |
      | Health scoring                | System health degradation     |
    And Sentinel should use data to improve threat detection

  @integration @prajna
  Scenario: Circuit Breaker status displayed in Prajna Cockpit
    Given Prajna Cockpit is running
    When the circuit state changes
    Then Prajna should display:
      | widget                    | content                           |
      | Circuit Status            | Current state (color-coded)       |
      | Violation Counter         | Current count / threshold         |
      | Recent Violations         | Last 10 violations with details   |
      | Time to Recovery          | Countdown timer                   |
      | Remediation Actions       | Suggested operator actions        |
    And the display should update in real-time via Zenoh

  @integration @chaya
  Scenario: Circuit Breaker state reflected in Digital Twin
    Given Chaya Digital Twin is active
    When the circuit state changes
    Then Chaya should update its twin state with:
      | twin_property             | value                     |
      | circuit_state             | Current state             |
      | violation_metrics         | Counters and rates        |
      | health_impact             | Degraded/normal           |
      | operation_queue_size      | Queued operations count   |
    And Chaya should use twin state for autonomous decision making

  # ============================================================================
  # PERFORMANCE AND RESILIENCE
  # ============================================================================

  @performance @overhead
  Scenario: Circuit Breaker adds minimal overhead to operations
    Given normal planning operations are running
    When the circuit is monitoring in CLOSED state
    Then the overhead should be:
      | metric                    | overhead      | acceptable    |
      | Pre-operation check       | < 1ms         | < 5ms         |
      | Post-operation logging    | < 2ms         | < 10ms        |
      | Memory footprint          | < 10MB        | < 50MB        |
      | CPU utilization           | < 1%          | < 5%          |
    And overhead should not impact user experience

  @resilience @circuit_failure
  Scenario: System handles Circuit Breaker component failure
    Given the Circuit Breaker component fails
    When planning operations are attempted
    Then the system should:
      | fallback_behavior                     | priority  |
      | Default to fail-safe mode (allow)     | CRITICAL  |
      | Log all operations for manual review  | HIGH      |
      | Alert operators of component failure  | CRITICAL  |
      | Attempt to restart Circuit Breaker    | HIGH      |
    And core planning functionality should remain available

  @resilience @state_persistence
  Scenario: Circuit Breaker state survives system restart
    Given the circuit is in OPEN state with counter at 3
    When the Planning System is restarted
    Then the Circuit Breaker should:
      | recovery_action                       | timing    |
      | Load state from SQLite                | < 100ms   |
      | Verify state integrity                | < 50ms    |
      | Resume from saved state               | immediate |
      | Continue countdown timer              | immediate |
    And no violations should be lost
    And state should be consistent

  # ============================================================================
  # ERROR HANDLING AND EDGE CASES
  # ============================================================================

  @error_handling @counter_overflow
  Scenario: Violation counter handles overflow gracefully
    Given the violation counter is at maximum integer value
    When one more violation occurs
    Then the counter should:
      | behavior                  | action                        |
      | Cap at maximum value      | No overflow                   |
      | Trigger emergency circuit | Immediate OPEN                |
      | Alert operators           | Critical overflow condition   |
    And special handling should be logged

  @edge_case @rapid_state_changes
  Scenario: Circuit handles rapid state changes
    Given violations are occurring at high frequency
    When the circuit state changes multiple times in 1 second:
      | time    | state       | trigger           |
      | 0.0s    | CLOSED      | Initial           |
      | 0.1s    | OPEN        | Threshold         |
      | 30.1s   | HALF_OPEN   | Timeout           |
      | 30.2s   | OPEN        | Test failed       |
      | 60.2s   | HALF_OPEN   | Timeout           |
      | 60.5s   | CLOSED      | Tests passed      |
    Then all state changes should be handled atomically
    And no race conditions should occur
    And all transitions should be logged correctly

  @edge_case @time_window
  Scenario: Violations outside time window don't accumulate
    Given the time window is 60 seconds
    When violations occur at:
      | time_offset | violation_count |
      | 0s          | 2               |
      | 30s         | 2               |
      | 65s         | 2               | (outside window, first 2 expired)
      | 95s         | 2               | (outside window, next 2 expired)
    Then the counter should never exceed 4
    And the circuit should not open
    And old violations should be garbage collected

  # ============================================================================
  # REGRESSION TESTS
  # ============================================================================

  @regression @sc_emr_057
  Scenario Outline: SC-EMR-057 Compliance - Emergency Stop < 5s
    Given the circuit detects a critical violation
    When emergency stop is triggered
    Then all operations should halt within "<max_time>"
    And the circuit should be in "<final_state>"

    Examples:
      | max_time | final_state |
      | 5s       | OPEN        |

  @regression @sc_emr_060
  Scenario Outline: SC-EMR-060 Compliance - Rollback Capability
    Given the circuit is in state "<initial_state>"
    When rollback is triggered
    Then rollback should complete within "<max_time>"
    And the circuit should be in state "<final_state>"

    Examples:
      | initial_state | max_time | final_state |
      | OPEN          | 5s       | CLOSED      |
      | HALF_OPEN     | 3s       | CLOSED      |

  @regression @violation_types
  Scenario Outline: All Violation Types Handled Correctly
    Given the circuit is in CLOSED state
    When a "<violation_type>" violation occurs
    Then the violation should be counted with weight "<weight>"
    And severity should be "<severity>"

    Examples:
      | violation_type    | weight | severity  |
      | SC-TODO-001       | 1      | CRITICAL  |
      | SC-PLAN-001       | 1      | CRITICAL  |
      | SC-FUNC-001       | 2      | INFINITE  |
      | SC-BRIDGE-002     | 1      | HIGH      |
      | Ψ₁ (Regeneration) | 2      | CRITICAL  |
      | Ψ₀ (Existence)    | 5      | INFINITE  |
