@planning @orchestration @coordination @integration
Feature: Planning System Orchestration and Service Coordination
  As the Planning System Orchestrator
  I need to coordinate with Cortex, Prajna, Smriti, and Chaya services
  So that planning operations are integrated across the entire biomorphic organism

  Background:
    Given the Planning System is operational
    And the F# Planning Runtime is initialized
    And the Guardian Safety Kernel is active
    And the Zenoh telemetry mesh is connected
    And all services are health-checked

  # ============================================================================
  # CORTEX INTEGRATION SCENARIOS (F# Cognitive Plane)
  # ============================================================================

  @smoke @cortex @integration
  Scenario: Cortex receives planning task creation event
    Given the Cortex service is subscribed to "indrajaal/planning/events"
    When a new task is created via F# CLI:
      """
      dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- plan add "AI-driven feature" --priority P1
      """
    Then Cortex should receive a task creation event within 100ms
    And the event payload should contain:
      | field       | type     |
      | task_id     | String   |
      | title       | String   |
      | priority    | String   |
      | timestamp   | DateTime |
      | created_by  | String   |
    And Cortex should acknowledge the event

  @cortex @analysis
  Scenario: Cortex analyzes task complexity
    Given a task with id "task-cortex-001" is created
    When Cortex receives the task creation event
    Then Cortex should analyze task complexity using AI models
    And Cortex should publish complexity metrics to "indrajaal/cortex/analysis"
    And the metrics should include:
      | metric                | unit      |
      | estimated_hours       | Float     |
      | complexity_score      | Integer   |
      | required_skills       | Array     |
      | risk_factors          | Array     |

  @cortex @recommendation
  Scenario: Cortex recommends task prioritization
    Given 20 tasks exist across all priority levels
    When Cortex performs periodic task analysis
    Then Cortex should publish prioritization recommendations
    And recommendations should include suggested priority changes
    And recommendations should include reasoning based on:
      | factor                |
      | business_value        |
      | technical_dependencies|
      | resource_availability |
      | deadline_proximity    |

  @cortex @failure_recovery
  Scenario: Planning System operates when Cortex is unavailable
    Given the Cortex service is down
    When a task is created via F# CLI
    Then the task creation should succeed
    And the event should be queued for Cortex
    And when Cortex recovers, the queued events should be delivered
    And no events should be lost

  @cortex @telemetry
  Scenario: Cortex publishes planning telemetry to Zenoh
    Given Cortex is monitoring planning operations
    When planning activities occur over 5 minutes
    Then Cortex should publish telemetry to "indrajaal/cortex/planning/metrics"
    And telemetry should include:
      | metric                    | frequency |
      | tasks_created_per_minute  | 1/min     |
      | tasks_completed_per_hour  | 1/min     |
      | average_task_duration     | 1/min     |
      | priority_distribution     | 1/min     |

  # ============================================================================
  # PRAJNA INTEGRATION SCENARIOS (C3I Cockpit)
  # ============================================================================

  @smoke @prajna @integration
  Scenario: Prajna Cockpit displays planning dashboard
    Given Prajna Cockpit is running at "http://localhost:4000/prajna"
    When a user navigates to "/prajna/planning"
    Then the planning dashboard should display:
      | widget                | data_source          |
      | Task Overview         | SQLite               |
      | Priority Distribution | DuckDB               |
      | Completion Trends     | DuckDB               |
      | Team Velocity         | DuckDB               |
      | Upcoming Deadlines    | SQLite               |

  @prajna @realtime
  Scenario: Prajna receives real-time task updates via Zenoh
    Given Prajna is subscribed to "indrajaal/planning/updates"
    And a user has the planning dashboard open
    When a task status changes from "TODO" to "IN_PROGRESS"
    Then Prajna should receive the update within 50ms
    And the dashboard should update without page refresh
    And the status change should be animated for user feedback

  @prajna @guardian
  Scenario: Prajna routes task creation through Guardian
    Given a user submits a new task via Prajna UI
    When the task requires Guardian approval (priority P0)
    Then Prajna should call Guardian validation API
    And Guardian should validate against Founder's Directive
    And if approved, the task should be created via F# API
    And if rejected, the user should receive Guardian's reasoning

  @prajna @ai_copilot
  Scenario: Prajna AI Copilot suggests task breakdowns
    Given a user creates a complex task "Implement distributed cache"
    When Prajna AI Copilot analyzes the task
    Then the Copilot should suggest breaking it into subtasks:
      | subtask                          | priority |
      | Research cache solutions         | P1       |
      | Design cache architecture        | P1       |
      | Implement cache layer            | P1       |
      | Write cache integration tests    | P2       |
      | Deploy to staging                | P2       |
    And the user should be able to accept/reject suggestions

  @prajna @sentinel
  Scenario: Prajna Sentinel monitors planning system health
    Given Prajna Sentinel is monitoring system health
    When the Planning System experiences degraded performance
    Then Sentinel should detect the degradation within 30 seconds
    And Sentinel should publish an alert to "indrajaal/sentinel/alerts"
    And the alert should appear in Prajna dashboard
    And an incident should be created automatically

  # ============================================================================
  # SMRITI INTEGRATION SCENARIOS (Knowledge Graph & Memory)
  # ============================================================================

  @smoke @smriti @integration
  Scenario: SMRITI persists task metadata to knowledge graph
    Given SMRITI is initialized with knowledge graph
    When a task is created with tags "ai,machine-learning,nlp"
    Then SMRITI should create a holon node for the task
    And the holon should have edges to:
      | edge_type     | target_node       |
      | has_tag       | ai                |
      | has_tag       | machine-learning  |
      | has_tag       | nlp               |
      | created_by    | user-001          |
      | belongs_to    | project-alpha     |

  @smriti @context
  Scenario: SMRITI provides context for AI agents
    Given an AI agent needs to understand project context
    When the agent queries SMRITI for tasks related to "authentication"
    Then SMRITI should return relevant tasks from knowledge graph
    And the results should include:
      | field                 | included |
      | task_history          | true     |
      | related_tasks         | true     |
      | domain_knowledge      | true     |
      | previous_discussions  | true     |

  @smriti @learning
  Scenario: SMRITI learns from task completion patterns
    Given 100 tasks have been completed over the past month
    When SMRITI analyzes completion patterns
    Then SMRITI should identify:
      | pattern                           | confidence |
      | Average completion time by priority| high       |
      | Common blockers                   | medium     |
      | Frequent task dependencies        | high       |
      | Team velocity trends              | high       |
    And these patterns should be stored as knowledge holons

  @smriti @federation
  Scenario: SMRITI synchronizes planning knowledge across federation
    Given multiple holon instances in a federation
    When a task is created in holon "indrajaal-alpha"
    Then SMRITI should replicate task metadata to peer holons
    And replication should use vector clocks for conflict resolution
    And all holons should converge to consistent state within 5 seconds

  @smriti @recovery
  Scenario: SMRITI recovers from knowledge graph corruption
    Given the SMRITI knowledge graph becomes corrupted
    When SMRITI detects the corruption via hash verification
    Then SMRITI should trigger self-repair protocol
    And SMRITI should rebuild the graph from DuckDB history
    And integrity should be verified via Merkle tree proofs
    And planning operations should continue with minimal disruption

  # ============================================================================
  # CHAYA INTEGRATION SCENARIOS (Digital Twin)
  # ============================================================================

  @smoke @chaya @integration
  Scenario: Chaya mirrors planning state in Digital Twin
    Given Chaya Digital Twin is initialized
    When tasks are created and updated in Planning System
    Then Chaya should maintain a synchronized copy of:
      | state_component       | sync_delay |
      | Active tasks          | < 1s       |
      | Task relationships    | < 2s       |
      | Priority distribution | < 1s       |
      | Team assignments      | < 1s       |
      | Progress metrics      | < 5s       |

  @chaya @ooda
  Scenario: Chaya runs OODA cycle on planning metrics
    Given Chaya is monitoring planning system performance
    When Chaya executes OODA cycle (< 100ms per SC-OODA-001)
    Then Chaya should:
      | phase    | action                                    |
      | Observe  | Collect metrics from SQLite, DuckDB       |
      | Orient   | Analyze trends, detect anomalies          |
      | Decide   | Recommend optimizations                   |
      | Act      | Publish recommendations to control plane  |

  @chaya @autonomous
  Scenario: Chaya autonomously manages task distribution
    Given Chaya is in autonomous mode
    And 50 new tasks are created in bulk
    When Chaya analyzes team capacity and task complexity
    Then Chaya should propose task assignments based on:
      | factor                    | weight |
      | Team member expertise     | 0.40   |
      | Current workload          | 0.30   |
      | Task complexity           | 0.20   |
      | Historical performance    | 0.10   |
    And proposals should be sent to Guardian for approval

  @chaya @mesh
  Scenario: Chaya distributes tasks across mesh nodes
    Given Chaya is aware of 3 mesh nodes
    When planning operations require distributed processing
    Then Chaya should distribute tasks to nodes based on:
      | criterion             | optimization_goal |
      | Node CPU utilization  | Load balancing    |
      | Network latency       | Minimize delay    |
      | Data locality         | Reduce transfers  |
    And task results should be aggregated within 500ms

  @chaya @sync
  Scenario: Chaya syncs with PROJECT_TODOLIST.md (SC-CHAYA-003)
    Given Chaya maintains its own task state
    When PROJECT_TODOLIST.md is regenerated by F# runtime
    Then Chaya should sync its state within 2 seconds
    And Chaya should verify consistency via hash comparison
    And any discrepancies should trigger a reconciliation event
    And the reconciliation should be logged to audit trail

  # ============================================================================
  # MULTI-SERVICE COORDINATION SCENARIOS
  # ============================================================================

  @smoke @coordination @full_stack
  Scenario: Full-stack task lifecycle with all services
    Given all services (Cortex, Prajna, SMRITI, Chaya) are operational
    When a user creates a critical task via Prajna UI:
      """
      Title: Implement end-to-end encryption
      Priority: P0
      Tags: security, encryption, compliance
      """
    Then the following sequence should occur:
      | step | service  | action                                      | max_time |
      | 1    | Prajna   | Route to Guardian for approval              | 100ms    |
      | 2    | Guardian | Validate against security policies          | 200ms    |
      | 3    | F# CLI   | Create task in SQLite                       | 100ms    |
      | 4    | F# CLI   | Regenerate PROJECT_TODOLIST.md              | 500ms    |
      | 5    | SMRITI   | Create knowledge graph node                 | 200ms    |
      | 6    | Cortex   | Analyze complexity and estimate effort      | 1s       |
      | 7    | Chaya    | Update Digital Twin state                   | 100ms    |
      | 8    | Prajna   | Display confirmation to user                | 100ms    |
    And total end-to-end latency should be < 3 seconds

  @coordination @event_chain
  Scenario: Event propagation across service mesh
    Given all services are subscribed to relevant Zenoh topics
    When a task status changes from "IN_PROGRESS" to "COMPLETED"
    Then events should propagate in this order:
      | order | service  | topic                              | action                    |
      | 1     | F# CLI   | indrajaal/planning/updates         | Publish status change     |
      | 2     | Prajna   | indrajaal/planning/updates         | Update dashboard          |
      | 3     | SMRITI   | indrajaal/planning/updates         | Update knowledge graph    |
      | 4     | Cortex   | indrajaal/planning/updates         | Update analytics          |
      | 5     | Chaya    | indrajaal/planning/updates         | Sync Digital Twin         |
    And all services should acknowledge receipt within 500ms

  @coordination @failure_cascade
  Scenario: System handles cascading service failures gracefully
    Given all services are initially healthy
    When SMRITI becomes unavailable
    Then the Planning System should:
      | response                                      | priority |
      | Continue accepting task operations            | CRITICAL |
      | Queue knowledge graph updates                 | HIGH     |
      | Alert Prajna Sentinel                         | HIGH     |
      | Maintain core functionality                   | CRITICAL |
    And when SMRITI recovers:
      | recovery_step                                 | timeout  |
      | Replay queued events                          | 10s      |
      | Verify knowledge graph consistency            | 30s      |
      | Resume normal operations                      | 5s       |

  @coordination @consensus
  Scenario: Services reach consensus on task priority
    Given Cortex analyzes a task and suggests priority P0
    And a human user suggests priority P2
    When the conflict is detected
    Then the system should:
      | step | action                                        |
      | 1    | Trigger tricameral consensus protocol         |
      | 2    | Claude (Constitutional) evaluates urgency     |
      | 3    | Gemini (Technical) evaluates complexity       |
      | 4    | Grok (Pragmatic) evaluates business value     |
      | 5    | Guardian synthesizes recommendations          |
      | 6    | Final decision presented to human for approval|
    And the decision process should be logged to Immutable Register

  @coordination @telemetry
  Scenario: Unified telemetry collection across services
    Given all services publish telemetry to Zenoh
    When planning operations occur over 10 minutes
    Then unified telemetry should be collected:
      | metric_category       | source_services              | aggregation  |
      | Task throughput       | F# CLI, Chaya                | Sum          |
      | Processing latency    | All services                 | p95          |
      | Error rate            | All services                 | Rate/min     |
      | Knowledge graph growth| SMRITI                       | Delta        |
      | AI model inference    | Cortex                       | Count        |
    And telemetry should be visualized in Prajna dashboard

  # ============================================================================
  # SAFETY AND COMPLIANCE SCENARIOS
  # ============================================================================

  @safety @guardian @approval
  Scenario: Guardian requires approval for high-risk tasks
    Given a task with priority P0 and tags containing "production,database"
    When the task is submitted for creation
    Then Guardian should classify it as high-risk
    And Guardian should require explicit approval
    And Guardian should evaluate against:
      | constraint                    | severity  |
      | Founder's Directive           | CRITICAL  |
      | Constitutional invariants     | CRITICAL  |
      | Security policies             | HIGH      |
      | Compliance requirements       | HIGH      |
    And approval decision should be logged to Immutable Register

  @safety @circuit_breaker
  Scenario: Circuit breaker activates on repeated failures
    Given planning operations are failing due to database lock
    When 5 consecutive operations fail within 10 seconds
    Then the Circuit Breaker should activate
    And all new operations should be queued
    And the system should enter degraded mode
    And Prajna should display circuit breaker status
    And after 30 seconds, the circuit should half-open and retry

  @compliance @audit_trail
  Scenario: Complete audit trail for planning operations
    Given planning operations occur throughout the day
    When an auditor requests the audit trail
    Then the trail should include entries for:
      | operation_type    | required_fields                               |
      | task_created      | timestamp, actor, task_id, title, priority    |
      | task_updated      | timestamp, actor, task_id, field, old, new    |
      | task_deleted      | timestamp, actor, task_id, reason             |
      | access_denied     | timestamp, actor, action, target, reason      |
      | guardian_approval | timestamp, task_id, decision, reasoning       |
    And all entries should be cryptographically signed
    And the audit trail should be stored in DuckDB and Immutable Register

  # ============================================================================
  # PERFORMANCE AND SCALABILITY SCENARIOS
  # ============================================================================

  @performance @latency
  Scenario: End-to-end operation latency budget
    Given performance monitoring is active
    When a task is created via Prajna UI
    Then the operation should meet these latency budgets:
      | component              | budget    | p99      |
      | Prajna UI to F# API    | 50ms      | 100ms    |
      | F# API to SQLite       | 20ms      | 50ms     |
      | SQLite to Zenoh event  | 10ms      | 20ms     |
      | Zenoh to SMRITI        | 50ms      | 100ms    |
      | Zenoh to Cortex        | 100ms     | 200ms    |
      | Total end-to-end       | 500ms     | 1000ms   |

  @performance @throughput
  Scenario: System handles high task creation throughput
    Given the system is under load
    When 1000 tasks are created concurrently via F# API
    Then the system should:
      | metric                        | target     | actual     |
      | Task creation rate            | > 100/s    | measured   |
      | SQLite transaction rate       | > 100/s    | measured   |
      | Zenoh event publishing rate   | > 500/s    | measured   |
      | No task loss                  | 0%         | verified   |
      | No event loss                 | 0%         | verified   |

  @scalability @federation
  Scenario: Planning System scales across federation
    Given 5 holon instances in a federation
    When each holon has 1000 tasks
    Then the federation should:
      | capability                    | requirement   |
      | Total tasks                   | 5000          |
      | Cross-holon task queries      | < 200ms       |
      | Federated knowledge graph     | consistent    |
      | Conflict resolution           | automatic     |
      | Global task visibility        | available     |

  # ============================================================================
  # ERROR HANDLING AND RECOVERY SCENARIOS
  # ============================================================================

  @error_handling @database
  Scenario: Graceful handling of database connection loss
    Given planning operations are in progress
    When the SQLite database connection is lost
    Then the system should:
      | response                          | timeout   |
      | Detect connection loss            | 1s        |
      | Queue pending operations          | immediate |
      | Attempt reconnection              | 5s        |
      | Retry with exponential backoff    | 30s       |
      | Alert Prajna Sentinel             | 10s       |
    And when the connection is restored:
      | recovery_action                   | timeout   |
      | Replay queued operations          | 10s       |
      | Verify database integrity         | 5s        |
      | Resume normal operations          | immediate |

  @error_handling @network
  Scenario: Graceful handling of Zenoh mesh partition
    Given all services are connected via Zenoh
    When a network partition occurs
    Then services should:
      | action                                | timeout   |
      | Detect partition via heartbeat loss   | 5s        |
      | Switch to local operation mode        | immediate |
      | Buffer events for partition recovery  | ongoing   |
      | Alert operators                       | 10s       |
    And when the partition heals:
      | recovery_action                       | timeout   |
      | Merge buffered events                 | 30s       |
      | Resolve conflicts via vector clocks   | 10s       |
      | Verify global consistency             | 20s       |

  # ============================================================================
  # REGRESSION TESTS
  # ============================================================================

  @regression @sc_ooda_001
  Scenario Outline: SC-OODA-001 Compliance - OODA Cycle Timing
    Given Chaya is executing OODA cycles
    When Chaya performs "<phase>" phase
    Then the phase should complete within "<max_time>"

    Examples:
      | phase     | max_time |
      | Observe   | 20ms     |
      | Orient    | 30ms     |
      | Decide    | 30ms     |
      | Act       | 20ms     |

  @regression @sc_bridge_005
  Scenario Outline: SC-BRIDGE-005 Compliance - PubSub Topic Patterns
    Given service "<service>" publishes to topic "<topic>"
    When a planning event occurs
    Then the message should follow the schema:
      | field         | type      | required |
      | event_type    | String    | true     |
      | timestamp     | DateTime  | true     |
      | source        | String    | true     |
      | payload       | Object    | true     |

    Examples:
      | service  | topic                           |
      | F# CLI   | indrajaal/planning/events       |
      | SMRITI   | indrajaal/smriti/knowledge      |
      | Cortex   | indrajaal/cortex/analysis       |
      | Chaya    | indrajaal/chaya/twin            |
