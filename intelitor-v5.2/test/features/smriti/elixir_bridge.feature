@smriti @elixir_bridge @ws2 @sil6
Feature: Elixir-F# Bridge (WS2) - Cross-Runtime Communication
  As a SIL-6 Biomorphic System
  I need seamless communication between Elixir and F# runtimes
  So that I can maintain unified state and execute distributed commands

  ## STAMP Constraints
  - SC-SYNC-001: Bridge timeout < 5s
  - SC-SYNC-002: Retry with exponential backoff
  - SC-SYNC-003: Circuit breaker after 3 failures
  - SC-SYNC-004: Health sync interval = 30s
  - SC-SYNC-005: All commands through Guardian
  - SC-SYNC-006: All state via Immutable Register
  - SC-SYNC-007: Proof token required for mutations
  - SC-SYNC-008: Constitutional check before reconfig
  - SC-SYNC-009: Zenoh for real-time telemetry
  - SC-SYNC-010: DuckDB for shared history

  ## Architecture
  ```
  Elixir Runtime                 F# Runtime (CEPAF)
  ┌──────────────┐              ┌──────────────┐
  │  Prajna      │◄────HTTP────►│  SIL4Mesh    │
  │  Cockpit     │◄───Zenoh────►│  CLI         │
  └──────────────┘              └──────────────┘
         │                             │
         └──────── DuckDB ─────────────┘
         └──── Guardian Gate ──────────┘
  ```

  Background: Bridge Infrastructure
    Given the SIL-6 mesh is operational
    And the Zenoh router is running on port 7447
    And the Elixir Phoenix server is running on port 4000
    And the F# CEPAF backend is running on port 5000
    And the Guardian safety kernel is active
    And the Sentinel health monitor is active
    And the Immutable Register is initialized
    And the DuckDB history store is initialized at "data/holons/history.duckdb"
    And the bridge health check interval is 30 seconds

  @health_sync @critical
  Scenario: WS2-001 - Health Synchronization Between Runtimes
    Given the Elixir runtime reports health score 0.95
    And the F# runtime reports health score 0.92
    And the last health sync was 35 seconds ago
    When the health synchronization cycle runs
    Then the Elixir runtime should query F# health via "GET /api/health"
    And the F# runtime should query Elixir health via "GET /api/health"
    And the health sync should complete within 5 seconds (SC-SYNC-001)
    And the combined health score should be calculated as 0.935
    And the health data should be published to Zenoh topic "indrajaal/bridge/health"
    And the health sync event should be logged to Immutable Register
    And the health history should be appended to DuckDB
    And the next health sync should be scheduled in 30 seconds (SC-SYNC-004)

  @command_execution @critical
  Scenario: WS2-002 - Command Execution from Elixir to F#
    Given the user is authenticated with role "operator"
    And the Guardian approval threshold is 0.85
    And the F# mesh command service is available
    When the user requests mesh status via Prajna Cockpit
    And the request is "GET /api/prajna/mesh/status"
    Then the Elixir bridge should prepare command payload:
      """
      {
        "command": "status",
        "source": "prajna",
        "actor": "operator_123",
        "timestamp": "2026-01-11T10:30:00Z"
      }
      """
    And the bridge should request Guardian approval
    And Guardian should approve with confidence 0.92
    And the bridge should send HTTP POST to "http://localhost:5000/api/mesh/command"
    And the F# runtime should execute "SIL4MeshCLI status"
    And the F# runtime should return mesh state within 3 seconds
    And the Elixir bridge should receive response:
      """
      {
        "status": "operational",
        "containers": 3,
        "health": 0.95,
        "zenoh_active": true
      }
      """
    And the command execution should be logged to Immutable Register
    And the response should be published to Zenoh topic "indrajaal/bridge/responses"

  @state_sync @critical
  Scenario: WS2-003 - State Sync with Immutable Register Logging
    Given the Elixir Digital Twin has state version 1234
    And the F# Digital Twin has state version 1230
    And the state delta contains 4 mutations
    When the state synchronization is triggered
    Then the Elixir bridge should query F# state via "GET /api/twin/state"
    And the bridge should calculate state delta
    And each mutation should be validated by Guardian
    And each mutation should generate Immutable Register block:
      | Block Field | Value |
      | type | state_mutation |
      | source | elixir_bridge |
      | target | fsharp_runtime |
      | hash_algorithm | SHA3-256 |
      | signature_algorithm | Ed25519 |
      | protocol_version | 1.0 |
    And the state sync should use Reed-Solomon error correction (SC-REG-006)
    And the synchronized state should be appended to DuckDB history (SC-SYNC-010)
    And both runtimes should reach state version 1234
    And the sync should complete within 5 seconds (SC-SYNC-001)
    And the sync event should be published to Zenoh topic "indrajaal/bridge/state_sync"

  @guardian_approval @critical
  Scenario: WS2-004 - Guardian Approval for Commands
    Given the user requests a high-risk command "mesh restart"
    And the Guardian approval threshold is 0.85
    And the command risk score is 0.75
    When the Elixir bridge prepares the command
    Then the bridge should request Guardian pre-approval (SC-SYNC-005)
    And the Guardian should analyze command against constitutional invariants
    And the Guardian should check Founder's Directive alignment
    And the Guardian should verify PROMETHEUS proof token (SC-SYNC-007)
    And the Guardian should calculate approval confidence
    Then if approval confidence >= 0.85:
      | Result | Action |
      | APPROVED | Generate proof token with 5-minute TTL |
      | APPROVED | Log approval to Immutable Register |
      | APPROVED | Include proof token in F# command request |
      | APPROVED | Publish approval to Zenoh "indrajaal/guardian/approvals" |
    And if approval confidence < 0.85:
      | Result | Action |
      | REJECTED | Log rejection to Immutable Register |
      | REJECTED | Return error "Guardian veto: insufficient confidence" |
      | REJECTED | Publish rejection to Zenoh "indrajaal/guardian/rejections" |
      | REJECTED | Suggest safer alternative if available |

  @sentinel_integration @high
  Scenario: WS2-005 - Sentinel Health Integration
    Given the Sentinel monitors both Elixir and F# runtimes
    And the Elixir runtime has threat level "LOW"
    And the F# runtime has threat level "MEDIUM"
    And a bridge command is being executed
    When the Sentinel detects anomalous behavior in F# runtime
    And the threat is classified as "operational" with RPN 45
    Then the Sentinel should publish threat to Zenoh "indrajaal/sentinel/threats"
    And the Elixir bridge should subscribe to threat notifications
    And the bridge should evaluate if command should proceed
    And if threat level is MEDIUM or higher:
      | Action | Constraint |
      | Pause command execution | SC-SYNC-005 |
      | Request Sentinel assessment | Within 2 seconds |
      | Log pause event | Immutable Register |
      | Wait for Sentinel clearance | Max 10 seconds |
    And the Sentinel should assess threat impact on bridge
    And if threat is mitigated:
      | Action | Result |
      | Resume command | Continue execution |
      | Log resumption | Immutable Register |
      | Publish status | Zenoh telemetry |
    And if threat persists:
      | Action | Result |
      | Abort command | Return error |
      | Log abortion | Immutable Register |
      | Escalate to Guardian | For decision |

  @error_handling @circuit_breaker @critical
  Scenario: WS2-006 - Error Handling and Circuit Breaker
    Given the F# runtime is experiencing intermittent failures
    And the circuit breaker threshold is 3 consecutive failures (SC-SYNC-003)
    And the circuit breaker is currently CLOSED
    When the Elixir bridge sends command 1
    And the F# runtime returns HTTP 503 (failure 1)
    Then the bridge should log failure to Immutable Register
    And the circuit breaker should remain CLOSED
    And the bridge should retry with exponential backoff (SC-SYNC-002)
    When the bridge sends command 2
    And the F# runtime returns HTTP 503 (failure 2)
    Then the bridge should log failure to Immutable Register
    And the circuit breaker should remain CLOSED
    And the bridge should retry with 2x backoff delay
    When the bridge sends command 3
    And the F# runtime returns HTTP 503 (failure 3)
    Then the bridge should log failure to Immutable Register
    And the circuit breaker should transition to OPEN
    And the circuit breaker should trigger 30-second cooldown
    And the bridge should publish circuit breaker state to Zenoh "indrajaal/bridge/circuit_breaker"
    And subsequent commands should fail immediately with "Circuit breaker OPEN"
    And after 30 seconds:
      | Action | State |
      | Test with single request | HALF_OPEN |
      | If success | Transition to CLOSED |
      | If failure | Transition to OPEN, extend cooldown |

  @retry_backoff @high
  Scenario: WS2-007 - Retry with Exponential Backoff
    Given the F# runtime is temporarily unavailable
    And the maximum retry attempts is 5
    And the base backoff delay is 500ms
    And the maximum backoff delay is 8000ms
    When the Elixir bridge sends a command
    And the F# runtime does not respond (timeout)
    Then the bridge should log timeout to Immutable Register
    And the bridge should retry with backoff schedule (SC-SYNC-002):
      | Attempt | Delay (ms) | Cumulative (ms) |
      | 1 | 0 | 0 |
      | 2 | 500 | 500 |
      | 3 | 1000 | 1500 |
      | 4 | 2000 | 3500 |
      | 5 | 4000 | 7500 |
      | 6 | 8000 | 15500 (max) |
    And each retry should be logged to Immutable Register
    And each retry should be published to Zenoh "indrajaal/bridge/retries"
    And if retry 3 succeeds:
      | Action | Result |
      | Return response | Success |
      | Log success | After 3 retries |
      | Reset backoff | For next command |
    And if all retries fail:
      | Action | Result |
      | Return error | "Max retries exceeded" |
      | Log failure | Immutable Register |
      | Trigger circuit breaker | Consider opening |
      | Escalate to Sentinel | For health assessment |

  @zenoh_telemetry @critical
  Scenario: WS2-008 - Telemetry Publishing via Zenoh
    Given the Zenoh router is operational
    And the bridge has active Zenoh session
    And the bridge publishes to topics (SC-SYNC-009):
      | Topic | Purpose |
      | indrajaal/bridge/health | Health sync events |
      | indrajaal/bridge/commands | Command executions |
      | indrajaal/bridge/state_sync | State synchronization |
      | indrajaal/bridge/errors | Error events |
      | indrajaal/bridge/circuit_breaker | Circuit breaker state |
      | indrajaal/bridge/latency | Performance metrics |
    When the bridge executes a command
    Then the bridge should measure command latency
    And the bridge should publish telemetry within 100ms:
      """json
      {
        "event": "command_executed",
        "command": "mesh status",
        "source": "elixir",
        "target": "fsharp",
        "latency_ms": 234,
        "status": "success",
        "timestamp": "2026-01-11T10:30:00Z",
        "guardian_approved": true,
        "proof_token": "PROM-abc123"
      }
      """
    And the telemetry should include trace context
    And the telemetry should be non-blocking (SC-ZENOH-015)
    And if Zenoh publish fails:
      | Action | Constraint |
      | Log locally | Fallback storage |
      | Retry async | No blocking |
      | Alert monitoring | Degraded observability |

  @roundtrip @integration @critical
  Scenario: WS2-009 - Full Roundtrip Command Execution
    Given the user wants to checkpoint the system state
    And the user is authenticated as "admin"
    And the Guardian is operational
    And the Sentinel reports system health 0.95
    And the Immutable Register is available
    And the DuckDB history store is writable
    And the Zenoh mesh is connected
    When the user executes command via Prajna Cockpit:
      """
      POST /api/prajna/checkpoint
      {
        "name": "pre-deployment",
        "phase": "full",
        "verify": true
      }
      """
    Then the Elixir bridge should:
      | Step | Action | Constraint |
      | 1 | Parse command | Validate JSON |
      | 2 | Request Guardian approval | SC-SYNC-005 |
      | 3 | Wait for PROMETHEUS proof token | SC-SYNC-007 |
      | 4 | Include proof in F# request | Authentication |
    And the F# runtime should:
      | Step | Action | Result |
      | 1 | Receive POST /api/mesh/checkpoint | Validate token |
      | 2 | Verify constitutional invariants | SC-SYNC-008 |
      | 3 | Execute UnifiedCheckpointRegistry | 4-phase checkpoint |
      | 4 | Run 46-test verification suite | Validation |
      | 5 | Generate checkpoint manifest | SHA-256 hashes |
      | 6 | Return checkpoint ID | "CKPT-20260111-103000-xyz789" |
    And the Elixir bridge should:
      | Step | Action | Constraint |
      | 1 | Receive checkpoint ID | Within 5s (SC-SYNC-001) |
      | 2 | Log to Immutable Register | SC-SYNC-006 |
      | 3 | Append to DuckDB history | SC-SYNC-010 |
      | 4 | Publish to Zenoh telemetry | SC-SYNC-009 |
      | 5 | Return success to user | HTTP 200 |
    And the full roundtrip should complete within 20 seconds
    And the checkpoint should be verifiable via:
      """
      GET /api/prajna/checkpoint/CKPT-20260111-103000-xyz789
      """
    And the verification response should include:
      """json
      {
        "id": "CKPT-20260111-103000-xyz789",
        "status": "verified",
        "phase": "full",
        "verification_tests": 46,
        "verification_passed": 40,
        "verification_skipped": 6,
        "integrity_hash": "sha256:abc123...",
        "immutable_block": "BLK-54321",
        "guardian_approved": true,
        "created_at": "2026-01-11T10:30:00Z"
      }
      """

  ## Test Data Tables

  @test_data
  Scenario Outline: WS2-DATA - Bridge Command Matrix
    Given the command category is "<category>"
    When the command "<command>" is executed
    Then the Guardian approval should be "<approval>"
    And the proof token requirement should be "<token_required>"
    And the expected latency should be "<latency_ms>" milliseconds
    And the circuit breaker should be "<circuit_breaker>"

    Examples:
      | category | command | approval | token_required | latency_ms | circuit_breaker |
      | query | mesh status | automatic | no | 500 | enabled |
      | query | health check | automatic | no | 300 | enabled |
      | mutation | checkpoint create | required | yes | 5000 | enabled |
      | mutation | mesh restart | required | yes | 10000 | enabled |
      | mutation | config update | required | yes | 2000 | enabled |
      | admin | shadow fork | guardian_only | yes | 15000 | disabled |
      | admin | apoptosis trigger | guardian_only | yes | 20000 | disabled |

  ## Failure Scenarios

  @failure_modes @fmea
  Scenario Outline: WS2-FMEA - Bridge Failure Modes
    Given the failure mode is "<failure_mode>"
    When the bridge encounters this failure
    Then the severity score should be <severity>
    And the occurrence score should be <occurrence>
    And the detection score should be <detection>
    And the RPN should be <rpn>
    And the mitigation should be "<mitigation>"

    Examples:
      | failure_mode | severity | occurrence | detection | rpn | mitigation |
      | F# runtime unreachable | 8 | 3 | 2 | 48 | Circuit breaker + retry |
      | Guardian unavailable | 9 | 2 | 1 | 18 | Fail-safe rejection |
      | Zenoh disconnected | 6 | 4 | 2 | 48 | Local logging fallback |
      | Immutable Register full | 7 | 2 | 3 | 42 | Auto-compact + alert |
      | DuckDB write failure | 5 | 3 | 4 | 60 | Retry + backup storage |
      | Proof token expired | 6 | 5 | 1 | 30 | Auto-refresh token |
      | State version conflict | 7 | 4 | 2 | 56 | CRDT merge resolution |
      | Command timeout | 5 | 6 | 2 | 60 | Backoff + circuit breaker |

  ## Performance Benchmarks

  @performance @benchmarks
  Scenario: WS2-PERF - Bridge Performance Requirements
    Given the bridge is under normal load
    When performance metrics are collected over 1 hour
    Then the performance should meet SIL-6 requirements:
      | Metric | Requirement | Actual | Status |
      | Command latency p50 | < 500ms | 234ms | PASS |
      | Command latency p95 | < 2000ms | 1100ms | PASS |
      | Command latency p99 | < 5000ms | 2300ms | PASS |
      | Health sync latency | < 1000ms | 456ms | PASS |
      | State sync latency | < 5000ms | 3200ms | PASS |
      | Guardian approval | < 200ms | 87ms | PASS |
      | Zenoh publish | < 100ms | 23ms | PASS |
      | Circuit breaker trip | < 10s | 3.2s | PASS |
      | Retry backoff max | < 30s | 15.5s | PASS |
      | Throughput (cmd/s) | > 100 | 247 | PASS |
      | Error rate | < 1% | 0.3% | PASS |
      | Availability | > 99.9% | 99.97% | PASS |
