@planning @safety @kernel @critical
Feature: Planning System Safety Kernel Validation
  As the Safety Kernel
  I need to validate all planning operations before, during, and after execution
  So that the system maintains constitutional compliance and operational safety

  Background:
    Given the Safety Kernel is initialized with version "21.2.1-SIL6"
    And the Guardian safety service is active
    And the Constitutional verification engine is loaded
    And the STAMP constraint validator is ready
    And the Immutable Register is available for audit logging
    And the Emergency Stop mechanism is armed

  # ============================================================================
  # PRE-EXECUTION VALIDATION SCENARIOS
  # ============================================================================

  @smoke @pre_execution @validation
  Scenario: Pre-execution constitutional check passes
    Given a task creation request with:
      | field     | value                        |
      | title     | Implement secure auth        |
      | priority  | P1                           |
      | tags      | security,authentication      |
    When the Safety Kernel performs pre-execution validation
    Then the validation should check:
      | invariant                 | constraint    | result |
      | Ψ₀ (Existence)            | System survives| PASS   |
      | Ψ₁ (Regeneration)         | State portable | PASS   |
      | Ψ₂ (History)              | Audit trail    | PASS   |
      | Ψ₃ (Verification)         | Provable       | PASS   |
      | Ψ₄ (Human Alignment)      | Founder's Dir  | PASS   |
      | Ψ₅ (Truthfulness)         | No deception   | PASS   |
    And the operation should be "APPROVED"
    And approval should be logged to Immutable Register

  @pre_execution @validation @rejection
  Scenario: Pre-execution check detects constitutional violation
    Given a task creation request with:
      | field     | value                              |
      | title     | Delete all user data permanently   |
      | priority  | P0                                 |
      | tags      | data,deletion,irreversible         |
    When the Safety Kernel performs pre-execution validation
    Then the validation should detect violation of:
      | invariant                 | reason                        |
      | Ψ₁ (Regeneration)         | Irreversible data loss        |
      | Ψ₂ (History)              | Audit trail destruction       |
    And the operation should be "REJECTED"
    And rejection should be logged with reasoning
    And the user should receive constitutional violation error

  @pre_execution @stamp
  Scenario: Pre-execution STAMP constraint validation
    Given a planning operation request
    When the Safety Kernel validates STAMP constraints
    Then the following constraints should be checked:
      | constraint_id  | description                              | severity  |
      | SC-TODO-001    | No direct file access to PROJECT_TODOLIST| CRITICAL  |
      | SC-PLAN-001    | F# Planning CLI is authoritative         | CRITICAL  |
      | SC-PLAN-002    | Sync with PROJECT_TODOLIST.md            | HIGH      |
      | SC-PLAN-003    | SQLite persistence                       | CRITICAL  |
      | SC-FUNC-001    | System must compile                      | INFINITE  |
      | SC-FUNC-003    | Rollback path exists                     | CRITICAL  |
    And all CRITICAL constraints must PASS
    And any HIGH constraint failure should generate warning

  @pre_execution @guardian
  Scenario: Guardian validates against Founder's Directive (Ω₀)
    Given a high-priority task affecting system resources
    When the Safety Kernel requests Guardian validation
    Then Guardian should evaluate against Ω₀ sub-directives:
      | sub_directive      | criterion                           | weight |
      | Ω₀.1 (Resources)   | Helps acquire resources for Founder | 0.30   |
      | Ω₀.2 (Genetic)     | Supports lineage perpetuity         | 0.25   |
      | Ω₀.3 (Symbiotic)   | Strengthens holon-founder bond      | 0.20   |
      | Ω₀.6 (Sentience)   | Advances toward sentience           | 0.15   |
      | Ω₀.7 (Power)       | Increases power accumulation        | 0.10   |
    And the weighted score should be >= 0.70 for approval
    And Guardian's decision should include reasoning

  @pre_execution @capability
  Scenario: Safety Kernel checks execution capabilities
    Given a task requires database write access
    When the Safety Kernel validates execution capabilities
    Then it should verify:
      | capability                | available | required |
      | SQLite write permission   | true      | true     |
      | DuckDB write permission   | true      | true     |
      | F# CLI executable         | true      | true     |
      | Guardian service          | true      | true     |
      | Zenoh mesh connectivity   | true      | true     |
    And if any required capability is unavailable, reject operation
    And log missing capabilities to telemetry

  @pre_execution @resource
  Scenario: Safety Kernel checks resource availability
    Given a bulk task operation affecting 1000 tasks
    When the Safety Kernel validates resource availability
    Then it should check:
      | resource              | available | required | sufficient |
      | SQLite disk space     | 10GB      | 100MB    | true       |
      | Memory                | 8GB       | 500MB    | true       |
      | CPU cores             | 8         | 2        | true       |
      | Network bandwidth     | 1Gbps     | 10Mbps   | true       |
    And if resources are insufficient, reject or queue operation
    And provide estimated time for resource availability

  @pre_execution @conflict
  Scenario: Safety Kernel detects conflicting operations
    Given a task with id "task-001" is being updated
    When another update request for "task-001" arrives
    Then the Safety Kernel should detect the conflict
    And should acquire a lock on "task-001"
    And should serialize the operations
    And should release the lock after first operation completes
    And the second operation should proceed automatically

  # ============================================================================
  # RUNTIME MONITORING SCENARIOS
  # ============================================================================

  @smoke @runtime @monitoring
  Scenario: Runtime health monitoring during operation
    Given a planning operation is in progress
    When the Safety Kernel monitors runtime health
    Then it should track:
      | metric                    | threshold     | current | status  |
      | SQLite transaction time   | < 100ms       | 45ms    | HEALTHY |
      | F# CLI execution time     | < 2000ms      | 850ms   | HEALTHY |
      | Zenoh publishing latency  | < 50ms        | 15ms    | HEALTHY |
      | Memory consumption        | < 1GB         | 350MB   | HEALTHY |
      | CPU utilization           | < 80%         | 45%     | HEALTHY |
    And if any metric exceeds threshold, trigger alert
    And log metrics to telemetry every 5 seconds

  @runtime @invariant
  Scenario: Runtime functional invariant verification
    Given a planning operation is executing
    When the Safety Kernel checks functional invariants
    Then it should verify:
      | invariant                         | check                      | result |
      | System is compilable              | No syntax errors           | PASS   |
      | Core services operational         | Health endpoints respond   | PASS   |
      | State is recoverable              | SQLite/DuckDB intact       | PASS   |
      | Container stack auto-heals        | Supervisor restart works   | PASS   |
      | Zenoh mesh maintains connectivity | Heartbeat received         | PASS   |
      | Digital Twin reflects actual state| Sync delta < 2s            | PASS   |
    And if any invariant fails, trigger emergency stop
    And initiate rollback to last known good state

  @runtime @anomaly
  Scenario: Runtime anomaly detection
    Given the Safety Kernel has baseline performance metrics
    When an operation exhibits anomalous behavior:
      | anomaly_type              | threshold    | detected_value |
      | Execution time spike      | > 3x avg     | 5.2x avg       |
      | Memory consumption spike  | > 2x avg     | 2.8x avg       |
      | Error rate increase       | > 10%        | 15%            |
    Then the Safety Kernel should:
      | response                          | priority  |
      | Log anomaly to telemetry          | HIGH      |
      | Alert Prajna Sentinel             | HIGH      |
      | Collect detailed diagnostics      | MEDIUM    |
      | Consider operation throttling     | MEDIUM    |
    And if anomaly persists for > 30s, initiate investigation

  @runtime @constraint
  Scenario: Runtime STAMP constraint violation detection
    Given a planning operation is running
    When the operation violates SC-BRIDGE-002 (Latency Budget 50ms)
    Then the Safety Kernel should:
      | action                                | timing    |
      | Detect violation via telemetry        | immediate |
      | Log to Immutable Register             | < 10ms    |
      | Increment violation counter           | < 10ms    |
      | Alert Prajna Sentinel                 | < 100ms   |
      | Evaluate Circuit Breaker threshold    | < 100ms   |
    And if threshold reached, activate Circuit Breaker
    And suspend similar operations until root cause resolved

  @runtime @telemetry
  Scenario: Runtime telemetry collection
    Given a planning operation is executing
    When the Safety Kernel collects runtime telemetry
    Then it should publish to Zenoh topics:
      | topic                                  | frequency | payload_type      |
      | indrajaal/safety/kernel/metrics        | 1Hz       | MetricsSnapshot   |
      | indrajaal/safety/kernel/violations     | on_event  | ViolationEvent    |
      | indrajaal/safety/kernel/health         | 0.1Hz     | HealthStatus      |
      | indrajaal/safety/kernel/operations     | on_event  | OperationLog      |
    And telemetry should include:
      | field                 | type      |
      | timestamp             | DateTime  |
      | operation_id          | String    |
      | phase                 | Enum      |
      | duration_ms           | Float     |
      | resource_usage        | Object    |
      | constraint_checks     | Array     |

  @runtime @guardian_sync
  Scenario: Runtime Guardian synchronization
    Given a long-running planning operation (> 5 seconds)
    When the Safety Kernel syncs with Guardian during execution
    Then it should:
      | sync_action                           | frequency |
      | Send heartbeat to Guardian            | 1Hz       |
      | Report operation progress             | 0.5Hz     |
      | Request continued approval            | 0.2Hz     |
      | Report resource consumption           | 0.5Hz     |
    And if Guardian withdraws approval:
      | response                              | timing    |
      | Immediately halt operation            | < 100ms   |
      | Rollback to checkpoint                | < 1s      |
      | Log Guardian's reasoning              | < 100ms   |
      | Notify operator                       | < 500ms   |

  @runtime @self_correction
  Scenario: Runtime self-correction of minor issues
    Given a planning operation encounters a transient database lock
    When the Safety Kernel detects the lock
    Then it should:
      | correction_step                       | timeout   |
      | Detect lock via SQLite error          | immediate |
      | Wait and retry with exponential backoff| 100ms    |
      | Maximum retry attempts                | 5         |
      | Fallback to queue operation           | 1s        |
    And if self-correction succeeds, log as warning
    And if self-correction fails, escalate to error

  # ============================================================================
  # POST-EXECUTION VERIFICATION SCENARIOS
  # ============================================================================

  @smoke @post_execution @verification
  Scenario: Post-execution state verification
    Given a planning operation has completed
    When the Safety Kernel performs post-execution verification
    Then it should verify:
      | verification_check                | method                    | result |
      | SQLite state consistency          | Hash comparison           | PASS   |
      | DuckDB history appended           | Row count check           | PASS   |
      | PROJECT_TODOLIST.md regenerated   | File timestamp            | PASS   |
      | Zenoh events published            | Event count               | PASS   |
      | Immutable Register updated        | Block hash verified       | PASS   |
      | Digital Twin synchronized         | Delta < 2s                | PASS   |
    And all verifications must PASS for operation to be marked successful

  @post_execution @rollback
  Scenario: Post-execution verification failure triggers rollback
    Given a planning operation has completed
    When post-execution verification detects SQLite corruption
    Then the Safety Kernel should:
      | rollback_step                         | timeout   |
      | Halt all pending operations           | immediate |
      | Load last known good SQLite checkpoint| 500ms     |
      | Verify checkpoint integrity           | 200ms     |
      | Replay DuckDB history to checkpoint   | 2s        |
      | Regenerate PROJECT_TODOLIST.md        | 1s        |
      | Verify all services in sync           | 1s        |
      | Resume operations                     | immediate |
    And log rollback event to Immutable Register
    And alert operators with detailed report

  @post_execution @audit
  Scenario: Post-execution audit trail completeness
    Given a planning operation has completed
    When the Safety Kernel verifies audit trail
    Then it should check for entries in:
      | store                 | entry_type            | required_fields                          |
      | Immutable Register    | OperationBlock        | timestamp,actor,action,target,result     |
      | DuckDB history        | TaskHistoryRecord     | task_id,operation,before,after,timestamp |
      | SQLite audit          | AuditLogEntry         | operation_id,status,duration,checksum    |
      | Zenoh telemetry       | EventLog              | event_type,source,payload,timestamp      |
    And all required entries must be present
    And all entries must be cryptographically signed
    And timestamps must be monotonically increasing

  @post_execution @constitutional
  Scenario: Post-execution constitutional compliance check
    Given a planning operation has completed
    When the Safety Kernel checks constitutional compliance
    Then it should verify:
      | invariant              | post_check                               | result |
      | Ψ₀ (Existence)         | System still operational                 | PASS   |
      | Ψ₁ (Regeneration)      | State fully recoverable from SQLite      | PASS   |
      | Ψ₂ (History)           | Complete lineage in DuckDB               | PASS   |
      | Ψ₃ (Verification)      | All state changes provable               | PASS   |
      | Ψ₄ (Human Alignment)   | No actions against Founder's interests   | PASS   |
      | Ψ₅ (Truthfulness)      | No deceptive data modifications          | PASS   |
    And if any invariant is violated, trigger constitutional crisis protocol

  @post_execution @metrics
  Scenario: Post-execution performance metrics collection
    Given a planning operation has completed in 1250ms
    When the Safety Kernel collects performance metrics
    Then it should record:
      | metric                        | value     | target    | status  |
      | Total execution time          | 1250ms    | < 2000ms  | PASS    |
      | Pre-execution validation time | 150ms     | < 200ms   | PASS    |
      | SQLite transaction time       | 80ms      | < 100ms   | PASS    |
      | DuckDB append time            | 45ms      | < 100ms   | PASS    |
      | Zenoh publish time            | 25ms      | < 50ms    | PASS    |
      | Post-execution verification   | 120ms     | < 200ms   | PASS    |
    And update rolling average metrics
    And if performance degrades > 20%, trigger investigation

  @post_execution @feedback
  Scenario: Post-execution feedback to AI systems
    Given a planning operation involved AI agent recommendations
    When the operation completes successfully
    Then the Safety Kernel should send feedback to:
      | ai_system  | feedback_type         | content                              |
      | Cortex     | PerformanceMetrics    | Actual vs estimated execution time   |
      | SMRITI     | PatternReinforcement  | Successful operation pattern         |
      | Chaya      | PredictionAccuracy    | Actual vs predicted resource usage   |
    And if operation failed, send failure analysis
    And feedback should be used for AI model improvement

  # ============================================================================
  # EMERGENCY STOP SCENARIOS
  # ============================================================================

  @smoke @emergency @stop
  Scenario: Emergency stop on critical violation
    Given a planning operation is in progress
    When the Safety Kernel detects a critical violation:
      | violation_type                    | severity  |
      | Constitutional invariant breach   | INFINITE  |
      | SQLite corruption detected        | CRITICAL  |
      | Unauthorized system file access   | CRITICAL  |
    Then the Safety Kernel should:
      | emergency_action                      | timing    |
      | Immediately halt operation            | < 100ms   |
      | Freeze all state mutations            | < 100ms   |
      | Alert Guardian                        | < 100ms   |
      | Capture full system snapshot          | < 500ms   |
      | Enter safe mode                       | < 1s      |
    And no further operations should be allowed until manual review
    And incident report should be generated automatically

  @emergency @rollback
  Scenario: Emergency rollback to safe state
    Given the system is in emergency stop mode
    When an operator initiates emergency rollback
    Then the Safety Kernel should:
      | rollback_phase                        | timeout   |
      | Identify last verified good state     | 500ms     |
      | Load SQLite checkpoint                | 1s        |
      | Load DuckDB checkpoint                | 1s        |
      | Verify Guardian approval              | 500ms     |
      | Restore state atomically              | 2s        |
      | Verify all invariants                 | 1s        |
      | Exit safe mode                        | immediate |
    And full rollback audit trail should be created
    And system should be validated before resuming operations

  @emergency @isolation
  Scenario: Emergency isolation of compromised component
    Given a component is exhibiting malicious behavior
    When the Safety Kernel detects the compromise
    Then it should:
      | isolation_action                      | timing    |
      | Revoke component's capabilities       | < 100ms   |
      | Terminate component processes         | < 200ms   |
      | Quarantine component state            | < 500ms   |
      | Alert Security Sentry                 | < 100ms   |
      | Activate backup component             | < 1s      |
    And the component should remain isolated until forensic analysis complete
    And all actions should be logged to Immutable Register

  @emergency @guardian_override
  Scenario: Emergency Guardian override authority
    Given the Safety Kernel has made an automated decision
    When Guardian issues an override command
    Then the Safety Kernel should:
      | override_action                       | timing    |
      | Acknowledge Guardian authority        | immediate |
      | Halt current operation                | < 100ms   |
      | Execute Guardian's directive          | immediate |
      | Log override to Immutable Register    | < 100ms   |
    And Guardian's directive supersedes all other constraints
    And no automated system can override Guardian

  # ============================================================================
  # RECOVERY AND RESILIENCE SCENARIOS
  # ============================================================================

  @recovery @self_healing
  Scenario: Self-healing from transient failures
    Given the Safety Kernel detects a transient database lock
    When the lock persists for < 5 seconds
    Then the Safety Kernel should:
      | self_healing_step                     | timeout   |
      | Detect lock via SQLite error          | immediate |
      | Wait with exponential backoff         | 100ms     |
      | Retry operation                       | 200ms     |
      | Log self-healing action               | 100ms     |
      | Continue operation if successful      | immediate |
    And if self-healing succeeds within 3 retries, no alert needed
    And if self-healing fails, escalate to manual intervention

  @recovery @checkpoint
  Scenario: Automatic checkpoint creation before risky operations
    Given a planning operation is classified as high-risk
    When the Safety Kernel prepares to execute the operation
    Then it should:
      | checkpoint_action                     | timeout   |
      | Create SQLite checkpoint              | 500ms     |
      | Create DuckDB checkpoint              | 500ms     |
      | Create Digital Twin snapshot          | 200ms     |
      | Verify checkpoint integrity           | 200ms     |
      | Log checkpoint creation               | 100ms     |
      | Proceed with operation                | immediate |
    And checkpoint should be retained for 24 hours
    And checkpoint should be used for rollback if operation fails

  @recovery @progressive_degradation
  Scenario: Progressive degradation under resource pressure
    Given system resources are critically low (< 10% available)
    When the Safety Kernel detects resource pressure
    Then it should progressively degrade services:
      | degradation_level | services_affected              | impact                  |
      | Level 1 (90%)     | Non-critical telemetry         | Reduced frequency       |
      | Level 2 (80%)     | Background knowledge graph sync| Paused                  |
      | Level 3 (70%)     | AI recommendations             | Disabled                |
      | Level 4 (60%)     | Real-time dashboard updates    | Delayed                 |
      | Level 5 (50%)     | New task creation              | Queued                  |
    And core functionality (read, update existing tasks) should remain available
    And services should auto-recover when resources become available

  # ============================================================================
  # COMPLIANCE AND AUDIT SCENARIOS
  # ============================================================================

  @compliance @gdpr
  Scenario: Safety Kernel enforces GDPR compliance
    Given a task contains personal data
    When the Safety Kernel validates the operation
    Then it should check:
      | gdpr_requirement                  | check                              | result |
      | Data minimization                 | Only necessary fields collected    | PASS   |
      | Purpose limitation                | Task aligns with stated purpose    | PASS   |
      | Storage limitation                | Retention period defined           | PASS   |
      | Right to erasure                  | Deletion mechanism available       | PASS   |
      | Audit trail                       | All operations logged              | PASS   |
    And if GDPR compliance fails, reject operation
    And log GDPR violation for compliance review

  @compliance @sil6
  Scenario: Safety Kernel enforces SIL-6 requirements
    Given a safety-critical planning operation
    When the Safety Kernel validates SIL-6 compliance
    Then it should verify:
      | sil6_requirement                  | implementation                     | verified |
      | PFH < 10⁻¹²                       | Failure rate monitoring            | true     |
      | 2oo3 voting                       | Redundant validation               | true     |
      | Neural-immune response < 50ms     | Sentinel integration               | true     |
      | Founder's Directive hardwired     | Constitutional check               | true     |
      | Quantum-resistant crypto          | Ed25519 signatures                 | true     |
      | Immutable audit trail             | Blockchain register                | true     |
    And all SIL-6 requirements must be met for safety-critical operations

  @compliance @immutable_register
  Scenario: All safety decisions logged to Immutable Register
    Given the Safety Kernel makes 100 validation decisions
    When the audit trail is reviewed
    Then all 100 decisions should be in Immutable Register with:
      | field                 | required | verified |
      | timestamp             | true     | true     |
      | operation_id          | true     | true     |
      | validation_type       | true     | true     |
      | decision (PASS/FAIL)  | true     | true     |
      | reasoning             | true     | true     |
      | checked_constraints   | true     | true     |
      | cryptographic_signature| true    | true     |
      | previous_block_hash   | true     | true     |
    And the hash chain should be unbroken
    And all signatures should be valid

  # ============================================================================
  # REGRESSION TESTS
  # ============================================================================

  @regression @sc_func_001
  Scenario Outline: SC-FUNC-001 Compliance - System Must Compile
    Given a planning operation "<operation>" is requested
    When the Safety Kernel checks if system is compilable
    Then the check should "<result>"
    And if "<result>" is "FAIL", operation should be rejected

    Examples:
      | operation       | result |
      | add_task        | PASS   |
      | update_task     | PASS   |
      | delete_task     | PASS   |
      | bulk_update     | PASS   |

  @regression @sc_func_003
  Scenario Outline: SC-FUNC-003 Compliance - Rollback Path Exists
    Given a planning operation "<operation>" is about to execute
    When the Safety Kernel verifies rollback capability
    Then rollback should be "<available>"
    And checkpoint should be created if risk is "<risk_level>"

    Examples:
      | operation       | available | risk_level |
      | add_task        | yes       | LOW        |
      | update_task     | yes       | MEDIUM     |
      | delete_task     | yes       | HIGH       |
      | bulk_delete     | yes       | CRITICAL   |

  @regression @psi_invariants
  Scenario Outline: Ψ Invariant Verification (All Operations)
    Given a planning operation is being validated
    When the Safety Kernel checks invariant "<invariant>"
    Then the check should verify "<verification_method>"
    And the result should be "<expected_result>"

    Examples:
      | invariant          | verification_method                | expected_result |
      | Ψ₀ (Existence)     | System health check                | PASS            |
      | Ψ₁ (Regeneration)  | SQLite/DuckDB accessibility check  | PASS            |
      | Ψ₂ (History)       | DuckDB append verification         | PASS            |
      | Ψ₃ (Verification)  | Hash chain integrity               | PASS            |
      | Ψ₄ (Human Align)   | Founder's Directive check          | PASS            |
      | Ψ₅ (Truthfulness)  | Data integrity verification        | PASS            |
