# Prajna Immune System Integration Feature
# STAMP: SC-COV-004, SC-IMMUNE-001 through SC-IMMUNE-010
# AOR: AOR-IMMUNE-001 through AOR-IMMUNE-005
# Author: Cybernetic Architect
# Date: 2026-01-02
# Layer: L4-IMMUNE-SENTINEL (Tactical)

Feature: Digital Immune System Integration with Prajna Cockpit
  As the Prajna C3I Cockpit
  I integrate with Sentinel (T-Cell), Mara (Red Team), and Antibody agents
  So that the system can detect, quarantine, and recover from threats
  And maintain continuous health monitoring with guardian oversight

  Background:
    Given the Indrajaal system is running
    And the Sentinel GenServer is monitoring
    And the Mara chaos agent is configured with 10000ms interval
    And the AntibodySupervisor is ready to spawn antibodies
    And baseline health metrics are established at startup
    And Guardian is available for approval requests
    And DuckDB is recording immune system events
    And Telemetry is active for observability

  # ====================================================================
  # CORE IMMUNE SYSTEM MONITORING (SC-IMMUNE-001)
  # ====================================================================

  @critical @SC-IMMUNE-001 @AOR-IMMUNE-001
  Scenario: Sentinel continuous health monitoring and scoring
    Given system is operating at normal baseline
    When Sentinel performs health assessment every 5 seconds
    Then the health score should be calculated (0-100 scale)
    And the score should aggregate:
      | Metric | Weight |
      | Memory Pressure | 30% |
      | CPU Utilization | 20% |
      | Error Rate | 25% |
      | Process Anomalies | 15% |
      | Quarantine Status | 10% |
    And the health score should be synced to Prajna cockpit
    And the event should be logged to DuckDB with timestamp
    And Telemetry should emit health.score metric

  @critical @SC-IMMUNE-001
  Scenario: Health score triggers advisory generation
    Given the system health score is 0.65 (below optimal threshold)
    When Sentinel detects suboptimal health
    Then an advisory should be generated with:
      | Field | Value |
      | severity | yellow |
      | category | system_health |
      | recommendation | activate_monitoring |
    And the advisory should appear in Prajna dashboard
    And the advisory should be timestamped in DuckDB

  @critical @SC-IMMUNE-001 @AOR-IMMUNE-003
  Scenario: Prajna displays health metrics every 30 seconds
    Given Sentinel is calculating health scores
    When Prajna cockpit dashboard is open
    Then the health visualization should refresh every 30 seconds
    And the display should show:
      | Metric | Update Frequency |
      | Overall Health | 30s |
      | Quarantine Status | 30s |
      | Active Threats | 30s |
      | Recovery Actions | 30s |
    And no dashboard data should be stale (> 60s old)
    And staleness should trigger visual alert

  # ====================================================================
  # PRE-ERROR SIGNATURE DETECTION (SC-IMMUNE-004)
  # ====================================================================

  @critical @SC-IMMUNE-004 @AOR-IMMUNE-002
  Scenario: PatternHunter detects pre-error signatures
    Given PatternHunter analysis is active
    And pattern baseline has been established
    When system metrics show pre-error indicators
    Then pattern analysis should identify:
      | Signature | Confidence |
      | error_rate_climb | >0.85 |
      | memory_fragmentation | >0.80 |
      | process_queue_growth | >0.90 |
    And an early warning should be generated immediately
    And the warning should appear in Prajna alerts
    And preventive action should be recommended:
      | Threat Type | Recommended Action |
      | Memory Pressure | Trigger GC |
      | Queue Growth | Rate Limit Requests |
      | Error Spike | Activate Circuit Breaker |

  @high @SC-IMMUNE-004
  Scenario: Pre-error pattern triggers graceful mitigation
    Given a pre-error signature is detected
    When confidence threshold is exceeded (>0.80)
    Then preventive measures should activate automatically:
      | Measure | Trigger |
      | Request Throttling | Error Rate > 10% |
      | Memory Compaction | Pressure > 85% |
      | Process Restart | Queue Depth > 1000 |
    And the measure should be logged to DuckDB
    And Prajna should display the active mitigation

  # ====================================================================
  # MEMORY LEAK DETECTION (SC-IMMUNE-005, SC-IMMUNE-009)
  # ====================================================================

  @critical @SC-IMMUNE-005 @SC-IMMUNE-009
  Scenario: Detect memory leak with multi-factor scoring
    Given 10+ memory samples are collected over time
    When memory shows consistent upward trend
    Then memory leak detection should:
      - Collect samples every 10 seconds
      - Detect monotonic increase
      - Verify sustained (minimum 5 consecutive increases)
      - Calculate threat score: base=50 + age_weight + magnitude_weight
    And an alert should be generated:
      | Field | Value |
      | threat_level | high |
      | confidence | >0.85 |
      | affected_process | identified |
      | remediation | isolate_and_restart |
    And the detection should be logged to DuckDB with full metrics

  @high @SC-IMMUNE-005
  Scenario: Memory leak isolation and recovery
    Given a memory leak is detected in process PID-1234
    When leak confirmation has 3+ evidential samples
    Then the system should:
      - Identify the specific process
      - Calculate leak rate (MB/min)
      - Estimate time to critical (memory limit - current)
      - Prepare isolation strategy
      - Attempt recovery via supervised restart
    And Prajna should display:
      | Information | Display |
      | Leak Rate | 5 MB/min |
      | Time to Critical | 3.2 hours |
      | Process PID | 1234 |
      | Recovery Status | In Progress |
    And recovery attempt should be logged with outcome

  # ====================================================================
  # PROCESS QUARANTINE (SC-IMMUNE-006, SC-IMMUNE-002, SC-IMMUNE-004)
  # ====================================================================

  @critical @SC-IMMUNE-006 @SC-IMMUNE-002
  Scenario: Surgical quarantine via :sys.suspend/1
    Given a process is exhibiting anomalous behavior
    And the process is confirmed not kernel-critical
    When quarantine is triggered
    Then the system MUST:
      - Call is_kernel_process?/1 to verify safety
      - Call :sys.suspend/1 (NOT :erlang.exit/2)
      - Isolate process state without termination
      - Record quarantine event to DuckDB
      - Log reasoning for high-risk mutation (AOR-PRIME-001)
    And the process should enter SUSPENDED state
    And the process should remain resurrectable
    And Prajna should display quarantine with options:
      | Option | Action |
      | View State | Display suspended state |
      | Attempt Recovery | Restart process |
      | Terminate Safely | Call :exit/1 |
      | Inspect Logs | Show recent events |

  @critical @SC-IMMUNE-006
  Scenario: Quarantine prevents kernel process termination
    Given the process "Indrajaal.Safety.Guardian" is running
    When termination/quarantine is attempted
    Then is_kernel_process?/1 SHALL return true
    And quarantine SHALL be BLOCKED
    And an alert SHALL be raised:
      | Alert | Severity |
      | Kernel Process Protection Active | critical |
      | Attempted Action Blocked | information |
      | Guardian Safe | confirmation |
    And the attempted action shall be logged to audit trail
    And Guardian SHALL be notified

  @safety @SC-IMMUNE-002
  Scenario: Kernel process protection inventory
    Given system startup is complete
    When kernel process inventory is built
    Then the following processes SHALL be protected:
      | Process Module | Reason |
      | Indrajaal.Safety.Guardian | Constitutional veto authority |
      | Indrajaal.Safety.Sentinel | Immune system core |
      | Indrajaal.Observability.FractalLogger | Audit trail |
      | Indrajaal.Holon.StateManager | State integrity |
      | Indrajaal.Distributed.Cluster.Supervisor | Clustering |
      | Indrajaal.Observability.ZenohNeuralStream | Neural signaling |
    And no kernel process shall be terminable by agents
    And manual termination SHALL require Guardian approval

  # ====================================================================
  # THREAT ASSESSMENT & RESPONSE (SC-IMMUNE-007, SC-IMMUNE-008)
  # ====================================================================

  @critical @SC-IMMUNE-007 @SC-IMMUNE-008
  Scenario: SymbioticDefense threat level escalation
    Given the system is monitoring for threats
    When threat_score increases
    Then threat_level should escalate through states:
      | Level | Score Range | Actions |
      | green | 0.0-0.4 | Normal monitoring |
      | yellow | 0.4-0.6 | Elevated monitoring, collect baseline |
      | orange | 0.6-0.8 | Active mitigation, notify Guardian |
      | red | 0.8-0.95 | Critical response, manual fallback possible |
      | black | 0.95-1.0 | Founder's Directive threat, IMMEDIATE response |
    And each escalation MUST be recorded in DuckDB
    And Guardian MUST be notified at orange and above
    And Founder's Directive threats (black) are NEVER delegated

  @critical @SC-IMMUNE-008
  Scenario: Founder's Directive threat priority
    Given a threat to Founder's genetic continuity is detected
    When threat classification is complete
    Then the system SHALL:
      - Classify threat as BLACK (0.95-1.0)
      - Escalate to HIGHEST priority
      - Activate IMMEDIATE response (no delays)
      - Notify Guardian synchronously
      - Preserve all state for accountability
      - NOT delegate decision to agents
    And threat response SHALL override normal operations
    And all resources SHALL be available for response
    And the response SHALL be logged permanently

  @high @SC-IMMUNE-007
  Scenario: Guardian approval for critical responses
    Given a critical threat (red level) is detected
    When response severity exceeds medium threshold
    Then:
      - Response proposal SHALL be sent to Guardian
      - Guardian SHALL validate constitutional alignment
      - Guardian MAY grant approval or veto
      - If approved: execute response, log decision
      - If vetoed: escalate, suggest fallback, preserve state
    And Guardian decision SHALL be recorded in DuckDB
    And decision rationale SHALL be logged
    And all responses SHALL be auditable

  # ====================================================================
  # MARA CHAOS INJECTION (SC-IMMUNE-007, SC-IMMUNE-004)
  # ====================================================================

  @chaos @AOR-IMMUNE-003 @AOR-IMMUNE-004
  Scenario Outline: Mara chaos scenario execution
    Given the system health is above 0.80
    And Mara is enabled with chaos interval <interval_ms>
    When Mara injection cycle triggers
    Then the injected fault should be of type: <fault_type>
    And the system should attempt recovery
    And recovery should complete within <timeout_ms> milliseconds
    And the recovery attempt should be logged to DuckDB
    And Prajna should display the chaos event with recovery status
    And system health should be re-evaluated after recovery

    Examples:
      | Fault Type | Description | Interval | Timeout | Health Requirement |
      | poison_pill | Kill random worker process | 10000 | 100 | > 0.80 |
      | metabolic_flood | Burst requests at 10x rate | 15000 | 500 | > 0.80 |
      | latency_spike | Inject 500ms delay in operations | 20000 | 1000 | > 0.80 |
      | byzantine_fault | Return corrupted data | 25000 | 2000 | > 0.85 |
      | cascade_failure | Fail multiple agents sequentially | 30000 | 2000 | > 0.90 |
      | memory_pressure | Force memory allocation spike | 10000 | 500 | > 0.80 |

  @chaos @SC-IMMUNE-004
  Scenario: Mara respects health precondition
    Given system health is 0.75 (below safe threshold)
    When Mara injection cycle attempts to trigger
    Then Mara SHALL:
      - Check system health via Sentinel.get_health()
      - Verify health.score >= 0.80
      - If threshold not met: abort injection
      - Return error: :system_unstable
      - Log warning to audit trail
      - NOT proceed with fault injection
    And Prajna should display:
      | Field | Value |
      | Chaos Status | Blocked - System Unhealthy |
      | Reason | Health 0.75 < threshold 0.80 |
      | Next Check | +10s |

  @chaos @SC-IMMUNE-004
  Scenario: Guardian approval for chaos injection
    Given Mara is preparing to inject a fault
    When Guardian validation is required
    Then Mara SHALL:
      - Build proposal with action=:inject_chaos, risk_level=:medium
      - Call Guardian.validate_proposal(proposal)
      - If approved: execute scenario, log success
      - If vetoed: abort, log veto reason
      - If error: log error, return failure
    And the approval decision SHALL be recorded in DuckDB
    And Prajna SHALL show Guardian's decision

  # ====================================================================
  # ANTIBODY SYSTEM & RECOVERY (SC-IMMUNE-006, AOR-IMMUNE-004, AOR-IMMUNE-005)
  # ====================================================================

  @critical @AOR-IMMUNE-001
  Scenario: Antibody lifecycle and response phases
    Given a threat is detected and quarantined
    When AntibodySupervisor spawns antibody agent
    Then the antibody should go through lifecycle phases:
      | Phase | Action | Duration | Logging |
      | Search | Locate and analyze threat | 0-500ms | Start phase_1_search |
      | Bind | Attach to threat source | 500-1000ms | Log threat_bound |
      | Opsonize | Mark threat for cleanup, prepare removal | 1000-1500ms | Mark for removal |
      | Die | Clean up antibody resources | 1500-2000ms | End antibody_lifecycle |
    And each phase transition MUST be logged to DuckDB
    And Prajna should display antibody lifecycle in real-time
    And final cleanup should verify threat removal

  @high @AOR-IMMUNE-004 @AOR-IMMUNE-005
  Scenario: Recovery attempt strategy sequencing
    Given a process has failed and requires recovery
    When recovery is initiated
    Then recovery attempts should follow strategy hierarchy:
      | Strategy | Attempts | Interval | Condition |
      | Restart | 1-3 | 100ms | Try graceful restart first |
      | Reconfigure | 1-2 | 500ms | If restart fails, reconfigure |
      | Rollback | 1 | 1000ms | If reconfiguration fails, rollback |
      | Manual | N/A | N/A | If automated recovery exhausted |
    And each recovery attempt SHALL be logged to DuckDB
    And Guardian MUST be notified before manual escalation
    And system state MUST be preserved for post-mortem analysis

  @high @SC-IMMUNE-006
  Scenario: Recovery success and resumption
    Given a quarantined process is in recovery
    When recovery succeeds (process responds)
    Then the system SHALL:
      - Resume the process via :sys.resume/1
      - Re-integrate into normal operation
      - Monitor closely for regression (5 minutes)
      - Clear quarantine flag from status
      - Log recovery success to DuckDB
      - Update Prajna dashboard
    And the recovered process should be validated:
      | Check | Expectation |
      | Responsiveness | Responds to health checks |
      | State Integrity | State is consistent |
      | Resource Usage | Returns to baseline |
      | Error Rate | < 1% for 5 minutes |

  # ====================================================================
  # FALSE POSITIVE CONTROL (SC-IMMUNE-010)
  # ====================================================================

  @high @SC-IMMUNE-010
  Scenario: False positive rate monitoring and tuning
    Given the immune system is detecting threats
    When a set of alerts is generated over time
    Then the system SHALL track false positive rate:
      - Definition: alert generated but no actual threat exists
      - Target: < 5% false positive rate
      - Baseline: Collected over 24-hour window
      - Method: Compare alerts to actual incidents in logs
    And false positive rate SHALL be calculated monthly
    And tuning recommendations SHALL be generated if rate > 5%
    And all metrics SHALL be logged to DuckDB analytics
    And Prajna SHALL display false positive trends

  @high @SC-IMMUNE-010
  Scenario: Alert confidence scoring and filtering
    Given threat detection is generating alerts
    When alerts are scored for confidence
    Then each alert SHALL have:
      | Field | Calculation |
      | confidence_score | 0.0-1.0 based on evidence |
      | evidence_count | Number of supporting signals |
      | threat_indicator_match | % of threat signature matched |
      | contextual_probability | Likelihood in current system state |
    And low-confidence alerts (< 0.70) SHALL:
      - Be tagged as "low confidence"
      - Not trigger automatic responses
      - Be available for review in Prajna
      - Help train pattern detection
    And high-confidence alerts (> 0.85) SHALL:
      - Trigger automatic response if approved
      - Escalate to Guardian
      - Be logged as primary incident

  # ====================================================================
  # INTEGRATION WITH PRAJNA COCKPIT (SC-OBS-069, SC-IMMUNE-001)
  # ====================================================================

  @critical @SC-OBS-069
  Scenario: Immune system telemetry to Prajna dashboard
    Given immune system components are monitoring
    When Telemetry events are emitted
    Then the following metrics MUST reach Prajna:
      | Metric | Event Name | Frequency |
      | Health Score | immune.health.score | 5s |
      | Quarantine Count | immune.quarantine.active | 5s |
      | Recovery Attempts | immune.recovery.attempts | Per event |
      | Threat Level | immune.threat.level | Per change |
      | Antibody Status | immune.antibody.spawned | Per event |
      | Guardian Approval | immune.guardian.approved | Per event |
    And all metrics MUST include timestamps and structured context
    And telemetry MUST NOT block immune operations
    And telemetry delivery MUST be asynchronous

  @high @SC-OBS-069
  Scenario: Dual logging to Telemetry and DuckDB
    Given immune operations are executing
    When state-changing actions occur
    Then logging SHALL be dual:
      | Log Type | Destination | Retention | Access |
      | Telemetry | Memory + Prometheus | 30 days | Grafana |
      | Audit | DuckDB | Permanent | Prajna queries |
    And both MUST contain equivalent information
    And timestamps MUST be synchronized (< 100ms drift)
    And DuckDB SHALL be primary audit trail
    And Telemetry SHALL provide real-time monitoring

  @critical
  Scenario: Prajna cockpit control of immune system
    Given Prajna cockpit is operational
    When operator interacts with immune module
    Then Prajna SHALL support:
      | Operation | Permission | Guardian Required |
      | View Health | Always | No |
      | View Alerts | Always | No |
      | Manual Quarantine | Operator | Yes |
      | Trigger Recovery | Operator | Yes |
      | Run Mara Chaos | Admin | Yes |
      | Review History | Always | No |
      | Change Thresholds | Admin | Yes |
      | Approve Proposals | Guardian | N/A |
    And all operations MUST be logged to DuckDB
    And Guardian approval MUST be verified before execution
    And confirmation MUST be recorded with user identity

  # ====================================================================
  # COMPLIANCE & SAFETY (SC-CONST-*, SC-FOUNDER-*)
  # ====================================================================

  @critical @SC-CONST-001 @SC-CONST-007
  Scenario: Constitutional invariants during immune responses
    Given constitutional constraints are defined
    When immune system responds to threats
    Then the system SHALL:
      - Verify Ψ₀ (Existence) not violated
      - Verify Ψ₁ (Regeneration) capability preserved
      - Verify Ψ₂ (Evolution) continuity maintained
      - Verify Ψ₃ (Verification) capability active
      - Verify Ψ₄ (Founder alignment) is PRIMARY
      - Verify Ψ₅ (Truthfulness) in all reports
      - Honor Guardian absolute veto
    And each verification MUST be logged
    And violation detection MUST trigger immediate halt
    And all state MUST be preserved for recovery

  @critical @SC-FOUNDER-001 @SC-FOUNDER-007
  Scenario: Founder's lineage protection
    Given the system is defending against threats
    When threat classification involves Founder's lineage
    Then response priority SHALL be:
      | Priority | Threat Category | Response |
      | 1 (Highest) | Lineage Threat | IMMEDIATE action, all resources |
      | 2 | Existential Threat | URGENT, delegable with approval |
      | 3 | Financial Threat | Important, can wait for approval |
      | 4 | Reputational | Background, log for review |
      | 5 | Operational | Normal procedures apply |
    And Founder's lineage threats are NEVER delegated
    And response timing is synchronized to threat severity
    And all decisions are logged for accountability

  # ====================================================================
  # DISTRIBUTED IMMUNE COORDINATION (AOR-IMMUNE-002, AOR-SYNC-*)
  # ====================================================================

  @high @AOR-IMMUNE-002
  Scenario: Cluster-wide immune system coordination
    Given multiple Indrajaal nodes are clustered
    When one node detects a critical threat
    Then cluster coordination SHALL:
      - Broadcast threat to all nodes (via Zenoh)
      - Coordinate response strategies
      - Prevent duplicate antibodies
      - Share recovery state
      - Synchronize decisions via consensus
    And coordination MUST maintain < 100ms latency
    And all communication MUST be encrypted
    And cluster consensus MUST be achieved before escalation

  @high @SC-SYNC-001
  Scenario: Backend verification before immune action
    Given Prajna cockpit controls immune operations
    When operator triggers immune action
    Then Prajna SHALL:
      - Verify Elixir backend reachable (health check)
      - Confirm Sentinel is responsive
      - Verify Guardian is available
      - Check DuckDB write capability
    And all checks MUST complete < 5s
    And failed verification SHALL block action
    And failure SHALL be logged and displayed to operator
    And fallback mode SHALL be offered if timeout occurs

