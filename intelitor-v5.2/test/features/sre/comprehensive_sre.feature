@sre @operations @P0
Feature: Comprehensive SRE Operations
  As a Site Reliability Engineer
  I need comprehensive operational capabilities
  So that I can ensure system reliability and availability

  Background:
    Given the system is in production mode
    And I have SRE operator credentials
    And the observability stack is operational

  # =============================================================================
  # OBSERVABILITY & MONITORING
  # =============================================================================

  @observability @metrics @P0 @SC-OBS-069
  Scenario: SRE-OBS-001 - Full observability stack health
    Given I access the observability dashboard
    Then the following components should be healthy:
      | Component    | Port | Status  |
      | OTEL Collector | 4317 | Running |
      | Prometheus   | 9090 | Running |
      | Grafana      | 3000 | Running |
      | Loki         | 3100 | Running |
    And dual logging should be active (Terminal + SigNoz)

  @observability @metrics @P0 @SC-OBS-071
  Scenario: SRE-OBS-002 - 4 OTEL module verification
    Given the observability stack is running
    Then the following OTEL modules should be active:
      | Module          | Purpose                    |
      | TraceExporter   | Distributed tracing        |
      | MetricExporter  | Metrics collection         |
      | LogExporter     | Log aggregation            |
      | BaggageHandler  | Context propagation        |

  @observability @alerting @P0
  Scenario: SRE-OBS-003 - Alert rule verification
    Given I access AlertManager
    Then the following alert rules should be configured:
      | Rule              | Condition          | Severity |
      | HighErrorRate     | error_rate > 5%    | critical |
      | HighLatency       | p95 > 500ms        | warning  |
      | LowAvailability   | availability < 99% | critical |
      | HighCPU           | cpu > 80%          | warning  |
      | HighMemory        | memory > 85%       | warning  |
      | ServiceDown       | up == 0            | critical |

  @observability @dashboards @P1
  Scenario: SRE-OBS-004 - Dashboard panel verification
    Given I access Grafana
    Then the following dashboards should exist:
      | Dashboard         | Panels |
      | Service Overview  | 10     |
      | SLA Compliance    | 8      |
      | Infrastructure    | 12     |
      | Business Metrics  | 6      |

  @observability @zenoh @P0 @SC-BRIDGE-005
  Scenario: SRE-OBS-005 - Zenoh telemetry topics
    Given the Zenoh mesh is operational
    Then the following topics should be active:
      | Topic            | Type    | Frequency |
      | zenoh:kpi/*      | Publish | 30s       |
      | zenoh:metrics/*  | Publish | 10s       |
      | zenoh:agents/*   | Pub/Sub | On-demand |
      | zenoh:health/*   | Publish | 10s       |
      | zenoh:safety/*   | Pub/Sub | On-demand |

  # =============================================================================
  # INCIDENT RESPONSE
  # =============================================================================

  @incident @detection @P0
  Scenario: SRE-INC-001 - Automated incident detection
    Given the monitoring system is operational
    When a service returns 500 errors > 5% for 1 minute
    Then an incident should be automatically created
    And the incident severity should be "P2"
    And notification should be sent to on-call

  @incident @classification @P0
  Scenario: SRE-INC-002 - Incident classification
    Given an incident is detected
    Then it should be classified by severity:
      | Severity | Escalation Time | Response Team     |
      | P1       | 5 minutes       | Emergency team    |
      | P2       | 15 minutes      | SRE team          |
      | P3       | 30 minutes      | Engineering team  |
      | P4       | 4 hours         | On-call engineer  |

  @incident @response @P0
  Scenario: SRE-INC-003 - Incident response workflow
    Given a P2 incident is active
    When the on-call engineer acknowledges the incident
    Then the acknowledgment should be logged
    And the escalation timer should pause
    And the incident status should change to "Investigating"

  @incident @rca @P0
  Scenario: SRE-INC-004 - 5-Level Root Cause Analysis
    Given an incident has been resolved
    When I initiate RCA process
    Then the 5-Why analysis should be performed:
      | Level | Question                      | Finding           |
      | Why 1 | What happened?                | Service timeout   |
      | Why 2 | Why did it happen?            | DB connection pool|
      | Why 3 | Why did that occur?           | Connection leak   |
      | Why 4 | Why wasn't it prevented?      | No pool monitoring|
      | Why 5 | What's the systemic issue?    | Missing alerts    |

  @incident @cast @P1
  Scenario: SRE-INC-005 - CAST analysis for safety incidents
    Given a safety-related incident occurred
    When I perform CAST analysis
    Then the analysis should include:
      | Component          | Assessment                    |
      | Constraint violations | Which constraints were violated |
      | Control actions    | What actions failed/succeeded |
      | Process model      | Was the model adequate?       |
      | Mental model       | Were assumptions correct?     |

  @incident @postmortem @P1
  Scenario: SRE-INC-006 - Incident postmortem
    Given an incident RCA is complete
    When I create a postmortem document
    Then the document should include:
      | Section          | Content                        |
      | Summary          | Incident overview              |
      | Timeline         | Event sequence                 |
      | Impact           | User/business impact           |
      | Root Cause       | 5-Why findings                 |
      | Action Items     | Preventive measures            |
      | Lessons Learned  | Knowledge gained               |

  # =============================================================================
  # CHAOS ENGINEERING
  # =============================================================================

  @chaos @mara @P0 @SC-IMMUNE-003
  Scenario: SRE-CHAOS-001 - Mara chaos agent activation
    Given system health is above 0.8
    And Guardian has approved chaos testing
    When I activate the Mara chaos agent
    Then Mara should be running in controlled mode
    And all chaos actions should be logged
    And automatic recovery should be enabled

  @chaos @scenarios @P0
  Scenario: SRE-CHAOS-002 - Container failure injection
    Given Mara is active
    When I inject "container_crash" failure
    Then the target container should be terminated
    And the supervisor should restart it within 30 seconds
    And the system should return to healthy state

  @chaos @scenarios @P1
  Scenario: SRE-CHAOS-003 - Network partition simulation
    Given Mara is active
    When I inject "network_partition" failure
    Then the mesh should detect the partition
    And quorum should be recalculated
    And affected services should degrade gracefully

  @chaos @scenarios @P1
  Scenario: SRE-CHAOS-004 - Database connection exhaustion
    Given Mara is active
    When I inject "db_pool_exhaustion" failure
    Then database connections should be exhausted
    And circuit breaker should open
    And queued requests should wait or fail gracefully

  @chaos @scenarios @P1
  Scenario: SRE-CHAOS-005 - Memory pressure simulation
    Given Mara is active
    When I inject "memory_pressure" at 90% threshold
    Then memory alerts should fire
    And PatternHunter should detect memory leak pattern
    And automatic cleanup should be triggered

  @chaos @gameday @P2
  Scenario: SRE-CHAOS-006 - Full chaos gameday
    Given the team is prepared for gameday
    When I execute the chaos gameday scenario
    Then multiple failures should be injected sequentially
    And the team should respond to each failure
    And total recovery time should be measured
    And a gameday report should be generated

  # =============================================================================
  # DIGITAL IMMUNE SYSTEM
  # =============================================================================

  @immune @sentinel @P0 @SC-IMMUNE-001
  Scenario: SRE-IMM-001 - Sentinel health monitoring
    Given the Sentinel is running
    Then health should be assessed continuously
    And the health score should consider:
      | Factor          | Weight |
      | Memory pressure | 30%    |
      | CPU utilization | 20%    |
      | Error rate      | 25%    |
      | Process anomalies| 15%   |
      | Quarantine status| 10%   |

  @immune @pattern-hunter @P0 @SC-IMMUNE-004
  Scenario: SRE-IMM-002 - PatternHunter pre-error detection
    Given PatternHunter is active
    When a memory leak pattern is detected
    Then an early warning should be generated
    And the time-to-error estimate should be calculated
    And preventive action recommendations should be provided

  @immune @symbiotic @P0 @SC-IMMUNE-007
  Scenario: SRE-IMM-003 - SymbioticDefense response times
    Given a threat is detected
    Then response should match severity:
      | Threat Level | Response Time |
      | extinction   | <100ms        |
      | critical     | <500ms        |
      | high         | <2000ms       |
      | medium       | <5000ms       |

  @immune @quarantine @P0 @SC-IMMUNE-006
  Scenario: SRE-IMM-004 - Surgical quarantine protocol
    Given a compromised process is detected
    When quarantine is initiated
    Then the process should be suspended with `:sys.suspend/1`
    And NOT terminated with `:erlang.exit/2`
    And the quarantine event should be logged
    And dependent processes should be notified

  # =============================================================================
  # SLA/SLO MANAGEMENT
  # =============================================================================

  @sla @monitoring @P0
  Scenario: SRE-SLA-001 - SLA metrics tracking
    Given SLA monitoring is active
    Then the following SLOs should be tracked:
      | SLO              | Target | Window  |
      | Availability     | 99.9%  | 30-day  |
      | Response Time    | <500ms | Rolling |
      | Error Rate       | <1%    | Rolling |
      | MTTR             | <5min  | Incident|
      | MTBF             | >30d   | Rolling |

  @sla @reporting @P1
  Scenario: SRE-SLA-002 - SLA compliance reporting
    Given the end of month is reached
    When I generate the SLA compliance report
    Then the report should include:
      | Section          | Content              |
      | Executive Summary| Overall compliance   |
      | SLO Performance  | Each SLO vs target   |
      | Incidents        | Impact on SLA        |
      | Error Budget     | Remaining budget     |
      | Trend Analysis   | Month-over-month     |

  @sla @error-budget @P1
  Scenario: SRE-SLA-003 - Error budget tracking
    Given the monthly error budget is 0.1% (43 minutes downtime)
    When I check error budget status
    Then I should see:
      | Metric            | Value   |
      | Total Budget      | 43 min  |
      | Consumed          | 12 min  |
      | Remaining         | 31 min  |
      | Consumption Rate  | 28%     |
      | Projected EOM     | 60%     |

  @sla @alerts @P0
  Scenario: SRE-SLA-004 - Error budget alerts
    Given error budget consumption exceeds 75%
    Then a warning alert should be generated
    And change velocity should be reduced
    And additional review should be required for deployments

  # =============================================================================
  # DEPLOYMENT OPERATIONS
  # =============================================================================

  @deployment @rolling @P0
  Scenario: SRE-DEP-001 - Rolling deployment
    Given a new version is ready for deployment
    When I initiate a rolling deployment
    Then instances should be updated one at a time
    And health checks should pass before proceeding
    And rollback should be available at any point

  @deployment @canary @P1
  Scenario: SRE-DEP-002 - Canary deployment
    Given a new version is ready for deployment
    When I initiate a canary deployment with 10% traffic
    Then 10% of traffic should route to the new version
    And metrics should be compared between versions
    And automatic rollback should trigger on degradation

  @deployment @rollback @P0
  Scenario: SRE-DEP-003 - Automatic rollback
    Given a deployment is in progress
    And error rate exceeds 5%
    When rollback is triggered
    Then the previous version should be restored
    And the rollback should complete within 5 minutes
    And an incident should be created

  @deployment @ucr @P0 @SC-UCR-001
  Scenario: SRE-DEP-004 - Unified Checkpoint Registry
    Given a deployment is planned
    When I create a pre-deployment checkpoint
    Then the 4-phase checkpoint should execute:
      | Phase | Content                        |
      | 1     | File/KMS/Git state             |
      | 2     | Container memory (CRIU)        |
      | 3     | Distributed snapshot (Chandy-Lamport) |
      | 4     | 8-level verification           |

  # =============================================================================
  # CAPACITY MANAGEMENT
  # =============================================================================

  @capacity @planning @P1
  Scenario: SRE-CAP-001 - Capacity utilization monitoring
    Given the capacity dashboard is visible
    Then I should see current utilization:
      | Resource    | Current | Threshold | Status  |
      | CPU         | 67%     | 80%       | Normal  |
      | Memory      | 72%     | 85%       | Normal  |
      | Disk        | 45%     | 90%       | Normal  |
      | Connections | 60%     | 90%       | Normal  |

  @capacity @forecasting @P1
  Scenario: SRE-CAP-002 - Capacity forecasting
    Given 30 days of historical data
    When I run capacity forecast
    Then I should see projected utilization for:
      | Timeframe | CPU  | Memory | Disk |
      | 30 days   | 72%  | 78%    | 50%  |
      | 60 days   | 78%  | 82%    | 55%  |
      | 90 days   | 85%  | 88%    | 60%  |

  @capacity @scaling @P1
  Scenario: SRE-CAP-003 - Auto-scaling triggers
    Given auto-scaling is enabled
    Then scaling should trigger on:
      | Metric      | Scale Up | Scale Down |
      | CPU         | >80%     | <40%       |
      | Memory      | >85%     | <50%       |
      | Request Rate| >1000rps | <200rps    |

  # =============================================================================
  # RUNBOOK AUTOMATION
  # =============================================================================

  @runbook @automation @P1
  Scenario: SRE-RUN-001 - Automated health check runbook
    Given the daily health check runbook is scheduled
    When the scheduled time arrives
    Then the runbook should execute:
      | Step | Action                    | Validation          |
      | 1    | Check container health    | All healthy         |
      | 2    | Run compilation test      | 0 errors/warnings   |
      | 3    | Execute quality gates     | All pass            |
      | 4    | Verify SLA metrics        | Within targets      |
      | 5    | Generate health report    | Report saved        |

  @runbook @remediation @P1
  Scenario: SRE-RUN-002 - Automated remediation
    Given a known failure pattern is detected
    When the remediation runbook is triggered
    Then the remediation steps should execute
    And the outcome should be logged
    And a follow-up ticket should be created if manual action needed

  @runbook @documentation @P2
  Scenario: SRE-RUN-003 - Runbook version control
    Given runbooks are stored in Git
    When a runbook is modified
    Then the change should be reviewed
    And the version should be incremented
    And the changelog should be updated
