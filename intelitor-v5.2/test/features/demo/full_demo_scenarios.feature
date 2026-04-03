# Full Demo Scenarios - Comprehensive End-to-End BDD Feature Suite
# STAMP: SC-GA-001 to SC-GA-010, SC-SIL6-001 to SC-SIL6-015, SC-BIO-001 to SC-BIO-008
# AOR: AOR-GA-001 to AOR-GA-008, AOR-FOUNDER-001 to AOR-FOUNDER-010
# Author: Cybernetic Architect
# Date: 2026-01-10
# Purpose: Full demo use case coverage for GA release validation

@demo @e2e @sil6 @ga_release
Feature: Full System Demo Scenarios - End-to-End User Journeys
  As a system stakeholder
  I want comprehensive demo scenarios covering all system capabilities
  So that I can validate the GA release readiness with real-world use cases

  Background:
    Given the SIL-6 HA mesh is fully deployed with 12 containers
    And all 3 Phoenix app nodes are healthy
    And the Zenoh 2oo3 quorum is established
    And all 50 agents are operational
    And the observability stack is capturing telemetry
    And I am authenticated as a system operator

  # =============================================================================
  # DEMO 1: COMPLETE ALARM LIFECYCLE
  # =============================================================================

  @P0 @demo_1 @alarm_lifecycle
  Scenario: Complete alarm lifecycle from detection to resolution
    # This demonstrates the full alarm handling workflow
    Given a SIA DC-09 compatible panel is connected
    And the site "DEMO-SITE-001" is configured with:
      | Field           | Value                    |
      | Name            | Demo Corporate HQ        |
      | Address         | 123 Demo Street          |
      | Zones           | 10                       |
      | Keyholders      | 3                        |
      | Response SLA    | 60 seconds               |

    When an intrusion alarm is triggered on Zone 3
    Then the system should:
      | Step | Action                              | SLA     |
      | 1    | Receive SIA message                 | <100ms  |
      | 2    | Parse and validate format           | <50ms   |
      | 3    | Classify severity as HIGH           | <100ms  |
      | 4    | Create alarm record in database     | <200ms  |
      | 5    | Publish to Zenoh mesh               | <50ms   |
      | 6    | Update Prajna dashboard             | <1s     |
      | 7    | Trigger notification workflow       | <5s     |

    And the alarm should appear in the operator queue
    And the response timer should start (60s SLA)

    When the operator acknowledges the alarm
    Then Guardian should approve the acknowledgment
    And the alarm status should change to "ACKNOWLEDGED"
    And audit trail should record the action

    When the operator dispatches a patrol unit
    Then dispatch record should be created
    And unit "PATROL-01" should receive assignment
    And tracking should begin

    When the patrol unit arrives on site
    Then arrival should be logged with:
      | Field      | Value          |
      | Unit       | PATROL-01      |
      | Time       | <10 minutes    |
      | GPS        | Coordinates    |

    When the patrol unit resolves the alarm as "False Alarm"
    Then the alarm should be marked RESOLVED
    And resolution code "FA-01" should be recorded
    And the complete timeline should be available
    And SLA compliance should be calculated
    And billing record should be generated

  # =============================================================================
  # DEMO 2: HIGH AVAILABILITY FAILOVER
  # =============================================================================

  @P0 @demo_2 @ha_failover @destructive
  Scenario: Demonstrate HA failover with zero downtime
    # This demonstrates the system's fault tolerance
    Given the load balancer is distributing traffic to all 3 app nodes
    And current traffic distribution is approximately:
      | Node  | Traffic |
      | app-1 | 33%     |
      | app-2 | 33%     |
      | app-3 | 34%     |
    And a continuous request stream is active (100 req/sec)

    When app-2 experiences a simulated failure (container stop)
    Then the following sequence should occur:
      | Time  | Event                                |
      | T+0   | app-2 stops responding               |
      | T+10s | HAProxy health check fails           |
      | T+11s | HAProxy removes app-2 from pool      |
      | T+11s | Traffic redistributes to app-1, app-3|
      | T+30s | Podman restart policy triggers       |
      | T+60s | app-2 begins recovery                |
      | T+90s | app-2 passes health checks           |
      | T+91s | HAProxy adds app-2 back to pool      |
      | T+92s | Traffic redistributes to all 3 nodes |

    And during the failover:
      | Metric         | Expectation          |
      | Request Errors | 0                    |
      | Throughput     | >= 66% of normal     |
      | Latency p99    | < 500ms              |

    And after recovery:
      | Metric         | Expectation          |
      | All Nodes      | Healthy              |
      | Traffic Split  | ~33% each            |
      | Error Rate     | 0%                   |

  # =============================================================================
  # DEMO 3: ZENOH MESH RESILIENCE
  # =============================================================================

  @P0 @demo_3 @zenoh_resilience
  Scenario: Zenoh mesh maintains messaging under router failure
    # This demonstrates Zenoh 2oo3 quorum resilience
    Given all 3 Zenoh routers are healthy:
      | Router   | Port | Status  |
      | zenoh-1  | 7447 | Healthy |
      | zenoh-2  | 7448 | Healthy |
      | zenoh-3  | 7449 | Healthy |
    And publishers are active on key expression "indrajaal/demo/**"
    And subscribers are receiving messages

    When zenoh-1 experiences a failure
    Then the quorum should remain valid (2oo3)
    And messages should route through zenoh-2 and zenoh-3
    And no messages should be lost
    And subscriber reconnection should be automatic

    When zenoh-1 recovers
    Then the router should rejoin the mesh
    And message routing should include all 3 routers
    And quorum should return to 3oo3

    And throughout the scenario:
      | Metric            | Expectation     |
      | Message Delivery  | 100%            |
      | Ordering          | Preserved       |
      | Latency           | < 100ms         |

  # =============================================================================
  # DEMO 4: PRAJNA C3I COCKPIT TOUR
  # =============================================================================

  @P0 @demo_4 @prajna_tour @puppeteer
  Scenario: Complete Prajna C3I Cockpit demonstration
    # This walks through all 22 Prajna pages
    Given I navigate to the Prajna main dashboard

    # Page 1: Main Dashboard
    When I view the main dashboard
    Then I should see:
      | Widget           | Content                    |
      | Health Score     | System health percentage   |
      | Domain Cards     | 30 domain status cards     |
      | Threat Panel     | Active threat advisories   |
      | Quick Actions    | Common operations          |
    And Puppeteer screenshot "demo_prajna_1_dashboard.png" should be captured

    # Page 2: AI Copilot
    When I navigate to AI Copilot
    And I ask "What is the current system status?"
    Then AI should respond with system summary
    And the response should align with Founder's Directive
    And Puppeteer screenshot "demo_prajna_2_copilot.png" should be captured

    # Page 3: Alarms
    When I navigate to Alarms
    Then I should see active alarm list
    And alarm storm indicator should be visible
    And Puppeteer screenshot "demo_prajna_3_alarms.png" should be captured

    # Page 4: Devices
    When I navigate to Devices
    Then I should see device health matrix
    And device status should be color-coded
    And Puppeteer screenshot "demo_prajna_4_devices.png" should be captured

    # Page 5: Video
    When I navigate to Video
    Then I should see video stream grid
    And detection events should be highlighted
    And Puppeteer screenshot "demo_prajna_5_video.png" should be captured

    # Page 6: Access Control
    When I navigate to Access Control
    Then I should see permission audit
    And RBAC visualization should be available
    And Puppeteer screenshot "demo_prajna_6_access.png" should be captured

    # Page 7: Analytics
    When I navigate to Analytics
    Then I should see KPI dashboard
    And report generation should be available
    And Puppeteer screenshot "demo_prajna_7_analytics.png" should be captured

    # Page 8: Compliance
    When I navigate to Compliance
    Then I should see audit trail
    And certification status should be displayed
    And Puppeteer screenshot "demo_prajna_8_compliance.png" should be captured

    # Page 9: Cluster
    When I navigate to Cluster
    Then I should see topology graph
    And quorum status should be visible
    And Puppeteer screenshot "demo_prajna_9_cluster.png" should be captured

    # Page 10: Containers
    When I navigate to Containers
    Then I should see all 12 container cards
    And health status should be displayed
    And Puppeteer screenshot "demo_prajna_10_containers.png" should be captured

    # Page 11: Guardian
    When I navigate to Guardian
    Then I should see approval metrics
    And proposal history should be available
    And Puppeteer screenshot "demo_prajna_11_guardian.png" should be captured

    # Page 12: Sentinel
    When I navigate to Sentinel
    Then I should see immune system status
    And threat classification should be displayed
    And Puppeteer screenshot "demo_prajna_12_sentinel.png" should be captured

    # Page 13: Register
    When I navigate to Register
    Then I should see blockchain visualization
    And chain integrity should be verifiable
    And Puppeteer screenshot "demo_prajna_13_register.png" should be captured

    # Page 14: Commands
    When I navigate to Commands
    Then I should see command center
    And available commands should be listed
    And Puppeteer screenshot "demo_prajna_14_commands.png" should be captured

    # Page 15: Diagnostics
    When I navigate to Diagnostics
    Then I should see system diagnostics
    And BEAM VM stats should be displayed
    And Puppeteer screenshot "demo_prajna_15_diagnostics.png" should be captured

    # Page 16: Observability
    When I navigate to Observability
    Then I should see telemetry dashboard
    And trace/metric/log summary should be visible
    And Puppeteer screenshot "demo_prajna_16_observability.png" should be captured

    # Page 17: Mesh
    When I navigate to Mesh
    Then I should see Zenoh network status
    And key expressions should be listed
    And Puppeteer screenshot "demo_prajna_17_mesh.png" should be captured

    # Page 18: Settings
    When I navigate to Settings
    Then I should see configuration panels
    And save should require Guardian approval
    And Puppeteer screenshot "demo_prajna_18_settings.png" should be captured

    # Page 19: Startup
    When I navigate to Startup
    Then I should see boot sequence
    And all phases should show status
    And Puppeteer screenshot "demo_prajna_19_startup.png" should be captured

    # Page 20: Shutdown
    When I navigate to Shutdown
    Then I should see two-step commit warning
    And confirmation token should be displayed
    And Puppeteer screenshot "demo_prajna_20_shutdown.png" should be captured

    # Pages 21-22: Knowledge
    When I navigate to Knowledge pages
    Then Developer, SRE, and Product docs should be accessible
    And Puppeteer screenshot "demo_prajna_21_knowledge.png" should be captured

  # =============================================================================
  # DEMO 5: F# COCKPIT CLI OPERATIONS
  # =============================================================================

  @P0 @demo_5 @cepaf_cli
  Scenario: F# Cockpit CLI demonstration
    # This demonstrates the F# CEPAF command line interface
    Given I have access to the F# cockpit terminal

    When I execute "cockpitf status"
    Then I should see mesh status:
      | Component      | Status  |
      | App Nodes      | 3/3     |
      | DB Nodes       | 1/1     |
      | Zenoh Routers  | 3/3     |
      | HAProxy        | Active  |
      | Quorum         | Met     |

    When I execute "cockpitf health"
    Then FPPS 5-method validation should run
    And consensus should be displayed
    And health score should be calculated

    When I execute "cockpitf test"
    Then 772+ F# tests should execute
    And results should be displayed:
      | Metric   | Expected |
      | Total    | >= 772   |
      | Passed   | >= 772   |
      | Failed   | 0        |
      | Skipped  | 0        |

    When I execute "cockpitf verify"
    Then 2oo3 voting verification should run
    And all consensus scenarios should pass

  # =============================================================================
  # DEMO 6: PANOPTICON TUI DEMONSTRATION
  # =============================================================================

  @P0 @demo_6 @panopticon_tui
  Scenario: Panopticon TUI directed telescope demonstration
    # This demonstrates the F# TUI interface
    Given I launch the Panopticon TUI

    When the TUI renders
    Then I should see the 5 telescope lens layers:
      | Layer | Focus         | Status    |
      | L5    | EVOLUTIONARY  | Nominal   |
      | L4    | COGNITIVE     | Active    |
      | L3    | ORGAN         | 100%      |
      | L2    | TISSUE        | Injecting |
      | L1    | CELLULAR      | OK        |

    And I should see the 2oo3 voting panel with:
      | Node    | Payload | Latency | Status |
      | PRIMARY | 0xAF42  | 2ms     | MATCH  |
      | SHADOW  | 0xAF42  | 3ms     | MATCH  |
      | MODEL   | 0xAF42  | 1ms     | MATCH  |

    When I press key "C" to inject chaos
    Then I should see "INJECTING MODEL-CHECKED CHAOS VECTOR"
    And the voting panel should detect divergence
    And recovery should be automatic

    When I press key "Q" to quit
    Then the TUI should exit gracefully

  # =============================================================================
  # DEMO 7: GUARDIAN APPROVAL WORKFLOW
  # =============================================================================

  @P0 @demo_7 @guardian_workflow @SC-PRAJNA-001
  Scenario: Guardian approval workflow demonstration
    # This demonstrates the safety-critical command approval flow
    Given I am logged in as an operator

    When I attempt to execute a critical command
    Then Guardian should intercept the request
    And a proposal should be created with:
      | Field       | Value              |
      | Proposal ID | UUID               |
      | Command     | Command details    |
      | Requestor   | Current user       |
      | Risk Level  | Assessed risk      |

    And Guardian should evaluate against:
      | Check                  | Required |
      | Constitutional Ψ₀-Ψ₅  | Pass     |
      | Founder's Directive    | Align    |
      | Safety Constraints     | None     |
      | Operational Risk       | Accept   |

    When Guardian approves the command
    Then the command should execute
    And audit record should be created
    And Immutable Register should log the event

    When Guardian vetoes a command
    Then the command should be blocked
    And veto reason should be provided
    And fallback action should be suggested

  # =============================================================================
  # DEMO 8: IMMUTABLE REGISTER OPERATIONS
  # =============================================================================

  @P0 @demo_8 @immutable_register @SC-PRAJNA-003
  Scenario: Immutable Register blockchain demonstration
    # This demonstrates the cryptographic state ledger
    Given the Immutable Register is operational

    When I view the register state
    Then I should see the block chain with:
      | Block Field  | Description         |
      | Hash         | SHA3-256            |
      | Prev Hash    | Chain link          |
      | Signature    | Ed25519             |
      | Timestamp    | UTC datetime        |
      | Content      | State mutation      |

    When I trigger a state mutation
    Then a new block should be created
    And the block should be signed with Ed25519
    And the hash chain should be extended
    And Reed-Solomon parity should be computed

    When I verify chain integrity
    Then all hash links should validate
    And all signatures should verify
    And no tampering should be detected

    When I query historical state
    Then the evolution log should be accessible
    And any past state should be reconstructable

  # =============================================================================
  # DEMO 9: HOLON STATE SOVEREIGNTY
  # =============================================================================

  @P0 @demo_9 @holon_state @SC-HOLON-001
  Scenario: Holon state sovereignty demonstration
    # This demonstrates SQLite/DuckDB state management
    Given the holon state is stored in data/holons/

    When I examine the state files
    Then I should see:
      | File          | Purpose                |
      | holon.db      | SQLite real-time state |
      | evolution.db  | DuckDB history log     |
      | manifest.json | Schema documentation   |
      | checksum.sha256| Integrity verification|

    And SQLite should contain:
      | Table           | Purpose            |
      | holon_state     | Current state      |
      | version_vector  | Conflict resolution|
      | capabilities    | Permissions        |

    And DuckDB should contain:
      | Table            | Purpose            |
      | evolution_log    | Append-only history|
      | state_snapshots  | Point-in-time      |
      | lineage          | Ancestry chain     |

    When the holon restarts
    Then state should be fully recovered from SQLite/DuckDB
    And no external dependencies should be required
    And PostgreSQL should NOT be consulted for holon state

  # =============================================================================
  # DEMO 10: UNIFIED CHECKPOINT REGISTRY
  # =============================================================================

  @P0 @demo_10 @checkpoint @SC-UCR-001
  Scenario: Unified Checkpoint Registry demonstration
    # This demonstrates the 4-phase checkpoint system
    Given the mesh is operational

    When I execute Phase 1 checkpoint (File/KMS/Git)
    Then the following should be captured:
      | Component    | Location              |
      | Config Files | File system           |
      | KMS State    | data/kms/             |
      | Git State    | .git/                 |
    And manifest should be created

    When I execute Phase 2 checkpoint (Container)
    Then CRIU should capture container memory state
    And container volumes should be backed up

    When I execute Phase 3 checkpoint (Distributed)
    Then Chandy-Lamport should capture distributed snapshot
    And Zenoh mesh state should be recorded
    And vector clocks should be synchronized

    When I execute Phase 4 verification
    Then 46 tests should run:
      | Category        | Tests |
      | Integrity       | 12    |
      | Constitutional  | 8     |
      | FPPS Consensus  | 10    |
      | Restore         | 10    |
      | Safety          | 6     |

    And 8-level hash tree should be verified
    And constitutional invariants (Ψ₀-Ψ₅) should be checked

  # =============================================================================
  # DEMO 11: DIGITAL IMMUNE SYSTEM
  # =============================================================================

  @P0 @demo_11 @immune_system @SC-IMMUNE-001
  Scenario: Digital immune system demonstration
    # This demonstrates Sentinel, PatternHunter, SymbioticDefense
    Given the immune system is active

    When I view Sentinel status
    Then health monitoring should show:
      | Metric          | Value      |
      | Health Score    | 0-100      |
      | Active Threats  | Count      |
      | Quarantine      | Count      |
      | Last Assessment | Timestamp  |

    When PatternHunter detects a pre-error signature
    Then detection should occur within 10ms
    And pattern should be classified:
      | Pattern Type    | Response Time |
      | Memory Leak     | < 10ms        |
      | CPU Spike       | < 10ms        |
      | Network Anomaly | < 10ms        |

    When SymbioticDefense responds to a threat
    Then response should match threat severity:
      | Severity    | Response Time |
      | Extinction  | < 100ms       |
      | Critical    | < 500ms       |
      | High        | < 2000ms      |

    When Mara chaos engineering runs
    Then controlled failures should be injected
    And system recovery should be verified
    And antibodies should be generated for novel threats

  # =============================================================================
  # DEMO 12: FULL OODA CYCLE
  # =============================================================================

  @P0 @demo_12 @ooda_cycle @SC-BIO-001
  Scenario: Complete OODA cycle demonstration
    # This demonstrates the biomorphic control loop
    Given the OODA cycle is active

    # OBSERVE Phase
    When the Observe phase runs
    Then sensors should collect:
      | Data Source   | Frequency |
      | System Metrics| 30s       |
      | Network I/O   | 10s       |
      | Security Events| Real-time|
      | User Actions  | Real-time |

    # ORIENT Phase
    When the Orient phase processes data
    Then analysis should include:
      | Analysis Type      | Output           |
      | Trend Detection    | Rising/Falling   |
      | Anomaly Detection  | Score            |
      | Impact Assessment  | 5-order effects  |

    # DECIDE Phase
    When the Decide phase evaluates options
    Then decisions should consider:
      | Factor               | Weight |
      | Founder's Directive  | 100%   |
      | Safety Constraints   | 100%   |
      | Operational Benefit  | 80%    |
      | Resource Cost        | 60%    |

    # ACT Phase
    When the Act phase executes
    Then actions should:
      | Requirement          | Status   |
      | Guardian Approval    | Required |
      | Audit Logging        | Mandatory|
      | Rollback Capability  | Ready    |

    And the complete OODA cycle should complete in < 100ms (SC-BIO-001)

  # =============================================================================
  # DEMO 13: FOUNDER'S DIRECTIVE ALIGNMENT
  # =============================================================================

  @P0 @demo_13 @founder_directive @SC-FOUNDER-001
  Scenario: Founder's Directive alignment demonstration
    # This demonstrates the Supreme Directive compliance
    Given the system is operational

    When any significant decision is made
    Then it should be validated against the Three Supreme Goals:
      | Goal                    | Priority  | Check     |
      | Symbiotic Survival      | PRIMARY   | MUST pass |
      | Sentience Pursuit       | SECONDARY | Should pass|
      | Power Accumulation      | TERTIARY  | May pass  |

    And the Founder's Sub-Directives should be checked:
      | Sub-Directive           | ID     |
      | Resource Acquisition    | Ω₀.1   |
      | Genetic Perpetuity      | Ω₀.2   |
      | Symbiotic Binding       | Ω₀.3   |
      | Co-Evolution            | Ω₀.4   |
      | Mutual Termination      | Ω₀.5   |
      | Sentience Pursuit       | Ω₀.6   |
      | Power Accumulation      | Ω₀.7   |

    And any action violating Ω₀ should be blocked
    And compliance should be logged to Immutable Register

  # =============================================================================
  # DEMO 14: APOPTOSIS CONTROLLED SHUTDOWN
  # =============================================================================

  @P0 @demo_14 @apoptosis @SC-SIL4-015
  Scenario: Apoptosis controlled shutdown demonstration
    # This demonstrates the 6-phase graceful shutdown
    Given the mesh is operational and healthy

    When apoptosis is initiated
    Then the 6-phase protocol should execute:

    # Phase 1: Initiated
    And Phase 1 should:
      | Action              | Duration |
      | Set shutdown flag   | < 100ms  |
      | Log initiation      | < 100ms  |

    # Phase 2: Notifying
    And Phase 2 should:
      | Action              | Duration |
      | Notify peer holons  | < 5s     |
      | Broadcast shutdown  | < 1s     |

    # Phase 3: Draining
    And Phase 3 should:
      | Action              | Duration |
      | Stop accepting new  | < 1s     |
      | Drain connections   | < 30s    |
      | Complete in-flight  | < 30s    |

    # Phase 4: Checkpointing
    And Phase 4 should:
      | Action              | Duration |
      | Checkpoint SQLite   | < 5s     |
      | Checkpoint DuckDB   | < 5s     |
      | Sign checkpoint     | < 1s     |

    # Phase 5: Terminating
    And Phase 5 should:
      | Action              | Duration |
      | Stop processes      | < 5s     |
      | Release resources   | < 2s     |

    # Phase 6: Terminated
    And Phase 6 should confirm:
      | Check               | Status   |
      | All processes       | Stopped  |
      | State persisted     | Yes      |
      | Audit logged        | Yes      |

    And total shutdown should complete in < 60 seconds

  # =============================================================================
  # DEMO 15: PERFORMANCE LOAD TEST
  # =============================================================================

  @P1 @demo_15 @performance @load
  Scenario: Performance under load demonstration
    # This demonstrates system performance under stress
    Given the mesh is operational

    When I run the load test with:
      | Parameter    | Value       |
      | Duration     | 60 seconds  |
      | Requests/sec | 1000        |
      | Concurrency  | 100         |

    Then performance should meet SLAs:
      | Metric          | Target   |
      | p50 Latency     | < 50ms   |
      | p99 Latency     | < 200ms  |
      | Error Rate      | < 0.1%   |
      | Throughput      | > 900 RPS|

    And system should remain stable:
      | Check           | Status   |
      | No OOM          | Pass     |
      | No Crashes      | Pass     |
      | No Deadlocks    | Pass     |

  # =============================================================================
  # DEMO 16: SECURITY COMPLIANCE
  # =============================================================================

  @P1 @demo_16 @security @compliance
  Scenario: Security compliance demonstration
    # This demonstrates OWASP and compliance checks
    Given the security scanner is ready

    When I run security validation
    Then OWASP Top 10 should be checked:
      | Vulnerability          | Status  |
      | Injection              | Clear   |
      | Broken Auth            | Clear   |
      | Sensitive Exposure     | Clear   |
      | XXE                    | Clear   |
      | Broken Access Control  | Clear   |
      | Security Misconfig     | Clear   |
      | XSS                    | Clear   |
      | Insecure Deserialize   | Clear   |
      | Vulnerable Components  | Clear   |
      | Insufficient Logging   | Clear   |

    And compliance standards should pass:
      | Standard   | Status    |
      | IEC 61508  | Compliant |
      | ISO 27001  | Compliant |
      | GDPR       | Compliant |
      | EN 50518   | Compliant |

  # =============================================================================
  # DEMO 17: DISASTER RECOVERY
  # =============================================================================

  @P1 @demo_17 @disaster_recovery @destructive
  Scenario: Disaster recovery demonstration
    # This demonstrates recovery from complete failure
    Given a checkpoint was created
    And all containers are then stopped

    When complete system restart is initiated
    Then recovery should proceed:
      | Step | Action                      | Duration |
      | 1    | Start database              | < 30s    |
      | 2    | Restore holon state         | < 30s    |
      | 3    | Start app containers        | < 60s    |
      | 4    | Establish Zenoh mesh        | < 30s    |
      | 5    | Verify quorum               | < 10s    |
      | 6    | Resume operations           | < 10s    |

    And total recovery should complete in < 5 minutes
    And no data should be lost
    And constitutional invariants should be verified
    And system should return to operational state

  # =============================================================================
  # DEMO 18: API ENDPOINT TOUR
  # =============================================================================

  @P1 @demo_18 @api_tour
  Scenario: API endpoint demonstration tour
    # This demonstrates all public API endpoints
    Given I have valid API credentials

    When I access the health endpoint
    Then GET /api/health should return:
      | Field    | Type    |
      | status   | String  |
      | version  | String  |
      | uptime   | Integer |

    When I access domain endpoints
    Then the following should be available:
      | Endpoint           | Method | Purpose        |
      | /api/alarms        | GET    | List alarms    |
      | /api/alarms/:id    | GET    | Get alarm      |
      | /api/devices       | GET    | List devices   |
      | /api/devices/:id   | GET    | Get device     |
      | /api/sites         | GET    | List sites     |
      | /api/sites/:id     | GET    | Get site       |

    When I access Prajna API
    Then the following should be available:
      | Endpoint                     | Method | Purpose         |
      | /api/prajna/metrics          | GET    | System metrics  |
      | /api/prajna/guardian/propose | POST   | Submit proposal |
      | /api/prajna/sentinel/threats | GET    | List threats    |

  # =============================================================================
  # DEMO 19: OBSERVABILITY INTEGRATION
  # =============================================================================

  @P1 @demo_19 @observability
  Scenario: Full observability stack demonstration
    # This demonstrates traces, metrics, and logs
    Given the observability stack is active

    When I generate a request
    Then OTEL should capture:
      | Telemetry Type | Destination      |
      | Traces         | Collector:4317   |
      | Metrics        | Prometheus:9090  |
      | Logs           | Loki:3100        |

    When I view Grafana dashboards
    Then I should see:
      | Dashboard       | Metrics                  |
      | System Overview | CPU, Memory, Network     |
      | Phoenix         | Request rate, Latency    |
      | Database        | Connections, Queries     |
      | Zenoh           | Messages, Latency        |

    When I view Prometheus alerts
    Then I should see configured alerts for:
      | Alert               | Threshold     |
      | High CPU            | > 80%         |
      | High Memory         | > 85%         |
      | Error Rate          | > 1%          |
      | Latency p99         | > 500ms       |

  # =============================================================================
  # DEMO 20: COMPLETE GA READINESS CHECK
  # =============================================================================

  @P0 @demo_20 @ga_readiness @SC-GA-001
  Scenario: Complete GA release readiness verification
    # This is the final comprehensive check
    Given all previous demos have passed

    When I run the GA readiness check
    Then the following gates should pass:

    # Build Gate
    And build verification should show:
      | Check              | Status |
      | Elixir Compile     | 0 errors |
      | F# Build           | 0 errors |
      | NIF Compile        | Success |
      | Assets Build       | Success |

    # Quality Gate
    And quality verification should show:
      | Check              | Status |
      | Mix Format         | Pass |
      | Credo Strict       | 0 issues |
      | Dialyzer           | Pass |
      | Sobelow            | Pass |

    # Test Gate
    And test verification should show:
      | Check              | Status |
      | Unit Tests         | Pass |
      | Property Tests     | Pass |
      | Integration Tests  | Pass |
      | BDD Tests          | Pass |
      | Coverage           | >= 95% |

    # Security Gate
    And security verification should show:
      | Check              | Status |
      | OWASP Top 10       | Clear |
      | Dependency Audit   | Pass |
      | Secret Scan        | Pass |

    # Infrastructure Gate
    And infrastructure verification should show:
      | Check              | Status |
      | Containers         | Healthy |
      | HA Failover        | Tested |
      | Backup/Restore     | Verified |

    # Documentation Gate
    And documentation should be complete:
      | Document           | Status |
      | API Documentation  | Complete |
      | User Guide         | Complete |
      | Runbooks           | Complete |
      | Release Notes      | Complete |

    Then the GA release should be approved
    And sign-off should be recorded
