@operations @comprehensive @e2e @sil6
Feature: Comprehensive Operational Scenarios - Full Coverage
  As an operator, administrator, or engineer
  I need comprehensive coverage of all operational scenarios
  So that the SIL-6 Biomorphic Fractal Mesh operates reliably in production

  STAMP Constraints:
    - SC-EMR-057: Emergency stop < 5 seconds
    - SC-EMR-060: Rollback capability required
    - SC-OBS-069: Dual logging (Terminal + SigNoz)
    - SC-VAL-001: Patient Mode for compilation
    - SC-CNT-009: NixOS/Podman only
    - SC-SIL6-001: PFH < 10^-12

  AOR Rules:
    - AOR-MESH-001: Use sa-up for all mesh operations
    - AOR-MESH-002: Checkpoint state before shutdown
    - AOR-MESH-003: Verify 2oo3 consensus in production
    - AOR-FUNC-001: Verify compilation before ANY code commit

  Background:
    Given I am authenticated as the appropriate role
    And the system is in a known initial state
    And the Immutable Register is active

  # ===========================================================================
  # SECTION 1: DAILY OPERATIONS
  # ===========================================================================

  @P0 @daily @startup
  Scenario: System Startup - Normal Boot Sequence
    Given the system is in STOPPED state
    When I execute "sa-up" command
    Then the boot sequence should progress through 5 stages:
      | Stage        | Duration | Verification                    |
      | Preflight    | < 10s    | Dependencies verified           |
      | Ignition     | < 30s    | Containers started              |
      | Lens         | < 20s    | Instrumentation configured      |
      | Convergence  | < 30s    | Zenoh quorum achieved           |
      | Ready        | < 5s     | OODA loop active                |
    And all 12 containers should be healthy
    And Phoenix should respond on port 4000
    And the startup should be logged to Immutable Register

  @P0 @daily @shutdown
  Scenario: System Shutdown - Graceful Apoptosis
    Given the system is running with all containers healthy
    When I execute "sa-down" command
    Then the Apoptosis protocol should execute:
      | Phase         | Duration | Actions                         |
      | Initiated     | < 2s     | Shutdown signal sent            |
      | Notifying     | < 5s     | Clients notified                |
      | Draining      | < 30s    | Active requests completed       |
      | Checkpointing | < 60s    | State saved to SQLite/DuckDB    |
      | Terminating   | < 10s    | Containers stopped              |
      | Terminated    | < 2s     | Cleanup complete                |
    And no data should be lost
    And the shutdown should be logged to Immutable Register

  @P0 @daily @health_check
  Scenario: Health Check - Continuous Monitoring
    Given the system is running
    When I execute "sa-status" command
    Then I should see health status for all containers:
      | Container            | Expected Status |
      | haproxy              | HEALTHY         |
      | indrajaal-app-1      | HEALTHY         |
      | indrajaal-app-2      | HEALTHY         |
      | indrajaal-app-3      | HEALTHY         |
      | indrajaal-db-prod    | HEALTHY         |
      | indrajaal-obs-prod   | HEALTHY         |
      | zenoh-router-1       | HEALTHY         |
      | zenoh-router-2       | HEALTHY         |
      | zenoh-router-3       | HEALTHY         |
    And the health check should complete in < 5 seconds

  @P0 @daily @alarm_handling
  Scenario: Alarm Handling - Standard Operating Procedure
    Given I am logged into Prajna as an operator
    When a new alarm "INTRUSION_ZONE_A" is received
    Then I should:
      | Step | Action                          | SLA      |
      | 1    | See alarm in active list        | < 2s     |
      | 2    | Hear audible alert              | < 2s     |
      | 3    | Read alarm details              | < 30s    |
      | 4    | Attempt subscriber verification | < 60s    |
      | 5    | Acknowledge alarm               | < 180s   |
      | 6    | Dispatch if verified            | < 300s   |
    And all actions should be logged to audit trail

  @P0 @daily @shift_handover
  Scenario: Shift Handover - Operator Transition
    Given operator A is ending their shift
    And operator B is starting their shift
    When operator A initiates shift handover
    Then the system should:
      | Action                 | Verification                    |
      | Generate shift report  | Active alarms, pending tasks    |
      | Transfer active calls  | No dropped connections          |
      | Update session         | Operator B now primary          |
      | Archive shift log      | Immutable Register entry        |
    And operator B should acknowledge the handover
    And the handover should complete in < 5 minutes

  @P1 @daily @report_generation
  Scenario: Report Generation - Daily Operations Report
    Given it is 06:00 UTC (scheduled report time)
    When the daily report job executes
    Then the system should generate:
      | Report                 | Content                         |
      | Alarm Summary          | Total, by type, by severity     |
      | Response Metrics       | Average, P95, SLA compliance    |
      | Operator Performance   | Handling times, accuracy        |
      | System Health          | Uptime, errors, warnings        |
    And the report should be emailed to distribution list
    And the report should be archived

  @P1 @daily @log_review
  Scenario: Log Review - Security Log Analysis
    Given I am a security analyst
    When I review the security logs for the past 24 hours
    Then I should see:
      | Log Category           | Expected Entries                |
      | Authentication         | All login attempts              |
      | Authorization          | All permission checks           |
      | Data Access            | All sensitive data access       |
      | Configuration Changes  | All config modifications        |
    And I should be able to filter by severity and time

  # ===========================================================================
  # SECTION 2: MAINTENANCE OPERATIONS
  # ===========================================================================

  @P0 @maintenance @deployment
  Scenario: Deployment - Rolling Update
    Given the system is running version 21.2.0
    And version 21.3.0 is ready for deployment
    When I initiate a rolling update
    Then the update should proceed:
      | Step | Action                          | Verification              |
      | 1    | Guardian approval requested     | Approval received         |
      | 2    | Checkpoint created              | UCR Phase 1-4 complete    |
      | 3    | Node 1 updated                  | Health check passes       |
      | 4    | Node 2 updated                  | Health check passes       |
      | 5    | Node 3 updated                  | Health check passes       |
      | 6    | HAProxy updated                 | Traffic flowing           |
    And zero downtime should occur
    And rollback capability should remain for 24 hours

  @P0 @maintenance @database
  Scenario: Database Maintenance - Backup and Vacuum
    Given the database has been running for 7 days
    When I initiate database maintenance
    Then the following should occur:
      | Task                   | Verification                    |
      | Full backup            | Backup file created             |
      | Vacuum analyze         | Table statistics updated        |
      | Reindex                | Indexes optimized               |
      | Timescale compress     | Old chunks compressed           |
    And the maintenance window should not exceed 30 minutes
    And the backup should be verified

  @P0 @maintenance @certificate
  Scenario: Certificate Rotation - TLS Certificate Update
    Given TLS certificates will expire in 30 days
    When I initiate certificate rotation
    Then the system should:
      | Step | Action                          | Verification              |
      | 1    | Generate new certificates       | Valid for 1 year          |
      | 2    | Update HAProxy                  | No connection drops       |
      | 3    | Update app nodes                | TLS handshake successful  |
      | 4    | Archive old certificates        | Retained for 90 days      |
    And all connections should remain secure
    And no service interruption should occur

  @P1 @maintenance @cleanup
  Scenario: Cleanup - Log and Artifact Removal
    Given logs older than 90 days exist
    When I execute scheduled cleanup
    Then the system should:
      | Action                 | Retention Policy                |
      | Compress old logs      | Logs > 30 days compressed       |
      | Archive to cold storage| Logs 30-90 days to archive      |
      | Delete expired logs    | Logs > 90 days removed          |
      | Clean temp files       | Temp files > 24h removed        |
      | Prune containers       | Unused images removed           |
    And disk space should be reclaimed
    And audit trail should be preserved indefinitely

  @P1 @maintenance @patching
  Scenario: Security Patching - OS and Dependency Updates
    Given security patches are available
    When I initiate patching during maintenance window
    Then the system should:
      | Step | Action                          | Verification              |
      | 1    | Create checkpoint               | UCR complete              |
      | 2    | Apply patches to node 1         | Reboot if needed          |
      | 3    | Verify node 1 health            | All services up           |
      | 4    | Repeat for nodes 2 and 3        | Rolling update            |
    And vulnerability scans should show no critical issues
    And the patch window should not exceed 2 hours

  @P1 @maintenance @capacity
  Scenario: Capacity Planning - Resource Scaling
    Given CPU utilization averages > 70% for 7 days
    When I analyze capacity requirements
    Then the system should provide:
      | Metric                 | Current    | Projected (30d)  |
      | CPU Utilization        | 70%        | 85%              |
      | Memory Usage           | 65%        | 75%              |
      | Disk Usage             | 40%        | 50%              |
      | Network Throughput     | 50%        | 60%              |
    And I should receive scaling recommendations
    And auto-scaling rules should be configurable

  # ===========================================================================
  # SECTION 3: TROUBLESHOOTING OPERATIONS
  # ===========================================================================

  @P0 @troubleshooting @connectivity
  Scenario: Connectivity Issues - Network Troubleshooting
    Given an operator reports slow dashboard performance
    When I run network diagnostics
    Then I should check:
      | Check                  | Tool/Command                    |
      | DNS resolution         | dig, nslookup                   |
      | Port connectivity      | nc, telnet                      |
      | Latency                | ping, mtr                       |
      | Packet loss            | ping statistics                 |
      | SSL/TLS                | openssl s_client                |
      | WebSocket              | wscat                           |
    And results should identify the root cause
    And I should document findings in incident log

  @P0 @troubleshooting @performance
  Scenario: Performance Degradation - 5-Why Root Cause Analysis
    Given response times have increased from 50ms to 500ms
    When I apply 5-Why RCA methodology
    Then I should investigate:
      | Why Level | Question                        | Investigation Area        |
      | Why 1     | Why are responses slow?         | Check application logs    |
      | Why 2     | Why is the DB slow?             | Check query performance   |
      | Why 3     | Why is the query slow?          | Check missing indexes     |
      | Why 4     | Why is the index missing?       | Check migration history   |
      | Why 5     | Why wasn't it caught?           | Check CI/CD pipeline      |
    And the root cause should be documented
    And preventive measures should be identified

  @P0 @troubleshooting @container
  Scenario: Container Failure - Container Recovery
    Given container "indrajaal-app-1" has crashed
    When I investigate the failure
    Then I should:
      | Step | Action                          | Expected Result           |
      | 1    | Check container logs            | Error message identified  |
      | 2    | Check resource limits           | OOM or CPU throttling     |
      | 3    | Check disk space                | Volume not full           |
      | 4    | Check network                   | Ports accessible          |
      | 5    | Restart container               | Container healthy         |
    And the failure should be logged to incident management
    And alerts should have been generated

  @P1 @troubleshooting @memory
  Scenario: Memory Leak Investigation - BEAM Diagnostics
    Given memory usage is continuously increasing
    When I run BEAM memory diagnostics
    Then I should check:
      | Diagnostic             | Tool                            |
      | Process memory         | :recon.proc_count(:memory, 10)  |
      | ETS table sizes        | :ets.info(table, :memory)       |
      | Binary memory          | :recon.bin_leak(5)              |
      | Mailbox sizes          | :recon.proc_count(:message_queue_len, 10) |
    And the memory leak source should be identified
    And a fix should be implemented and verified

  @P1 @troubleshooting @database
  Scenario: Database Performance - Query Optimization
    Given some queries are taking > 1 second
    When I analyze database performance
    Then I should:
      | Step | Action                          | Tool                      |
      | 1    | Identify slow queries           | pg_stat_statements        |
      | 2    | Analyze query plans             | EXPLAIN ANALYZE           |
      | 3    | Check index usage               | pg_stat_user_indexes      |
      | 4    | Check lock contention           | pg_locks                  |
      | 5    | Check connection pool           | Ecto telemetry            |
    And optimizations should be implemented
    And query times should improve

  @P1 @troubleshooting @integration
  Scenario: Integration Failure - External API Issues
    Given integration with Genesys Cloud is failing
    When I troubleshoot the integration
    Then I should check:
      | Check                  | Expected Result                 |
      | API endpoint health    | HTTP 200                        |
      | Authentication         | OAuth token valid               |
      | Rate limits            | Under quota                     |
      | Request/Response logs  | Valid payloads                  |
      | Network path           | No firewall blocks              |
    And the issue should be resolved or escalated
    And fallback procedures should be documented

  # ===========================================================================
  # SECTION 4: EMERGENCY OPERATIONS
  # ===========================================================================

  @P0 @emergency @stop
  Scenario: Emergency Stop - Immediate System Halt
    Given a critical security breach is detected
    When I execute "sa-emergency" command
    Then the system should halt within 5 seconds (SC-EMR-057)
    And the emergency should be logged immediately
    And all active sessions should be terminated
    And network connections should be severed
    And incident response should be triggered

  @P0 @emergency @failover
  Scenario: Emergency Failover - Node Failure
    Given the primary node "indrajaal-app-1" has failed catastrophically
    When automatic failover is triggered
    Then the system should:
      | Step | Action                          | SLA               |
      | 1    | Detect failure                  | < 5 seconds       |
      | 2    | Remove from load balancer       | < 2 seconds       |
      | 3    | Elect new leader                | < 10 seconds      |
      | 4    | Redistribute traffic            | < 5 seconds       |
    And zero data loss should occur
    And operators should be notified immediately
    And the incident should be logged

  @P0 @emergency @rollback
  Scenario: Emergency Rollback - Critical Bug in Production
    Given a critical bug is discovered in production version 21.3.0
    When I initiate emergency rollback
    Then the system should:
      | Step | Action                          | Verification              |
      | 1    | Halt new transactions           | No new data accepted      |
      | 2    | Identify rollback point         | Checkpoint 21.2.0         |
      | 3    | Restore from checkpoint         | State verified            |
      | 4    | Verify data integrity           | Checksums match           |
      | 5    | Resume operations               | All services healthy      |
    And rollback should complete in < 15 minutes
    And all stakeholders should be notified

  @P0 @emergency @security
  Scenario: Security Incident Response - Breach Containment
    Given a security breach has been detected
    When I execute security incident response
    Then the following should occur:
      | Phase         | Actions                         |
      | Contain       | Isolate affected systems        |
      | Eradicate     | Remove threat                   |
      | Recover       | Restore from clean backup       |
      | Document      | Full incident report            |
    And the breach should be contained in < 30 minutes
    And forensic evidence should be preserved
    And regulatory notification should be prepared

  @P1 @emergency @disaster
  Scenario: Disaster Recovery - Full Site Failover
    Given the primary data center is unavailable
    When disaster recovery is activated
    Then the DR site should:
      | Step | Action                          | RTO               |
      | 1    | Activate DR site                | < 5 minutes       |
      | 2    | Restore from replication        | < 10 minutes      |
      | 3    | Update DNS                      | < 5 minutes       |
      | 4    | Verify all services             | < 10 minutes      |
    And RPO should be < 1 minute (continuous replication)
    And full service should resume in < 30 minutes

  @P1 @emergency @communication
  Scenario: Emergency Communication - Mass Notification
    Given a critical emergency affecting all sites
    When I trigger emergency broadcast
    Then the following should occur:
      | Channel                | Recipients        | SLA               |
      | SMS                    | All operators     | < 30 seconds      |
      | Email                  | All stakeholders  | < 1 minute        |
      | Push notification      | Mobile app users  | < 30 seconds      |
      | System banner          | All web users     | < 5 seconds       |
    And delivery confirmation should be tracked
    And escalation should occur for non-acknowledgment

  # ===========================================================================
  # SECTION 5: VERIFICATION OPERATIONS
  # ===========================================================================

  @P0 @verification @2oo3
  Scenario: 2oo3 Voting Verification - Consensus Check
    Given the 2oo3 voting system is active
    When I execute "sa-verify" command
    Then the verification should check:
      | Node           | Payload    | Latency | Status    |
      | PRIMARY        | 0xAF42     | 2ms     | MATCH     |
      | SHADOW         | 0xAF42     | 3ms     | MATCH     |
      | MODEL          | 0xAF42     | 1ms     | MATCH     |
    And consensus should be UNANIMOUS
    And the verification should be logged

  @P0 @verification @fpps
  Scenario: FPPS 5-Method Consensus - Validation Check
    Given FPPS validation is required
    When I execute validation
    Then all 5 methods should agree:
      | Method         | Result     | Confidence |
      | Pattern        | VALID      | 99.5%      |
      | AST            | VALID      | 100%       |
      | Statistical    | VALID      | 98.7%      |
      | Binary         | VALID      | 100%       |
      | LineByLine     | VALID      | 100%       |
    And disagreement should trigger emergency halt
    And results should be logged to Immutable Register

  @P0 @verification @constitutional
  Scenario: Constitutional Check - Invariant Verification
    Given a major system change is proposed
    When I verify constitutional invariants
    Then all invariants should be checked:
      | Invariant | Description              | Status      |
      | Ψ₀        | Existence preservation   | COMPLIANT   |
      | Ψ₁        | Regenerative completeness| COMPLIANT   |
      | Ψ₂        | Evolutionary continuity  | COMPLIANT   |
      | Ψ₃        | Verification capability  | COMPLIANT   |
      | Ψ₄        | Human alignment          | COMPLIANT   |
      | Ψ₅        | Truthfulness             | COMPLIANT   |
    And any violation should block the change
    And verification should be logged

  @P1 @verification @checkpoint
  Scenario: Checkpoint Verification - UCR Validation
    Given a checkpoint has been created
    When I verify the checkpoint
    Then the verification should pass:
      | Phase         | Components                | Status      |
      | Phase 1       | File/KMS/Git              | VERIFIED    |
      | Phase 2       | CRIU container state      | VERIFIED    |
      | Phase 3       | Chandy-Lamport distributed| VERIFIED    |
      | Phase 4       | 8-level hash tree         | VERIFIED    |
    And all 46 verification tests should pass
    And the checkpoint should be marked as restorable

  @P1 @verification @compliance
  Scenario: Compliance Verification - Regulatory Check
    Given compliance audit is due
    When I run compliance verification
    Then the following should be checked:
      | Standard       | Requirements              | Status      |
      | EN 50518       | Alarm response < 60s      | COMPLIANT   |
      | ISO 27001      | Access control            | COMPLIANT   |
      | GDPR           | Data protection           | COMPLIANT   |
      | IEC 61508      | Functional safety         | COMPLIANT   |
    And compliance report should be generated
    And evidence should be collected automatically

  # ===========================================================================
  # SECTION 6: DEVELOPMENT OPERATIONS
  # ===========================================================================

  @P0 @devops @compilation
  Scenario: Compilation - Patient Mode Build
    Given I have made code changes
    When I execute "compile" command
    Then compilation should occur in Patient Mode:
      | Setting                | Value                     |
      | NO_TIMEOUT             | true                      |
      | PATIENT_MODE           | enabled                   |
      | INFINITE_PATIENCE      | true                      |
      | Schedulers             | 16:16                     |
      | Partition Count        | 8                         |
    And compilation should produce 0 errors and 0 warnings
    And output should be logged to ./data/tmp/1-compile.log

  @P0 @devops @testing
  Scenario: Testing - Full Test Suite
    Given the codebase is compiled
    When I execute "test" command
    Then testing should:
      | Check                  | Requirement               |
      | SKIP_ZENOH_NIF         | Must be 0 (NIF active)    |
      | Coverage               | > 95%                     |
      | Failures               | 0                         |
      | Property tests         | PropCheck + ExUnitProperties |
    And test results should be reported
    And coverage report should be generated

  @P0 @devops @quality
  Scenario: Quality Gate - Full Pipeline
    Given I am preparing for a release
    When I execute "quality-full" command
    Then the following gates should pass:
      | Gate           | Tool                      | Status      |
      | Format         | mix format                | PASS        |
      | Credo          | mix credo --strict        | PASS        |
      | Dialyzer       | mix dialyzer              | PASS        |
      | Sobelow        | mix sobelow --exit        | PASS        |
    And 0 issues should be found
    And the code should be release-ready

  @P1 @devops @cepaf
  Scenario: CEPAF Build - F# Compilation
    Given F# code changes are ready
    When I execute "cepaf-build" command
    Then F# build should:
      | Check                  | Requirement               |
      | Target Framework       | net10.0                   |
      | Errors                 | 0                         |
      | Warnings               | 0 (warnings as errors)    |
      | Test Count             | 772+                      |
    And all F# projects should compile
    And tests should pass

  @P1 @devops @database
  Scenario: Database Operations - Migration
    Given there are pending database migrations
    When I execute "db-migrate" command
    Then migrations should:
      | Step                   | Verification              |
      | Backup before          | Backup created            |
      | Apply migrations       | All applied               |
      | Verify schema          | Schema matches            |
      | Update version         | Version recorded          |
    And the database should be in sync with code
    And rollback should be possible

  # ===========================================================================
  # SECTION 7: MONITORING OPERATIONS
  # ===========================================================================

  @P0 @monitoring @dashboard
  Scenario: Dashboard Monitoring - Real-Time Observability
    Given I am monitoring the system
    When I view the monitoring dashboard
    Then I should see real-time metrics:
      | Metric Category        | Refresh Rate              |
      | System Health          | 10 seconds                |
      | Container Status       | 10 seconds                |
      | Request Latency        | 5 seconds                 |
      | Error Rate             | 5 seconds                 |
      | Active Alarms          | Real-time                 |
    And alerts should appear within 2 seconds of threshold breach
    And historical trends should be available

  @P0 @monitoring @alerts
  Scenario: Alert Management - Threshold Alerts
    Given alert thresholds are configured
    When a metric exceeds its threshold
    Then the alert lifecycle should be:
      | Phase          | Timing           | Actions                  |
      | Detection      | < 5 seconds      | Threshold breached       |
      | Notification   | < 10 seconds     | Operators notified       |
      | Acknowledgment | < 5 minutes      | Alert acknowledged       |
      | Resolution     | Per SLA          | Issue resolved           |
      | Closure        | Automatic        | Alert closed             |
    And escalation should occur if not acknowledged
    And all alerts should be logged

  @P1 @monitoring @logs
  Scenario: Log Monitoring - Log Aggregation
    Given logs are flowing from all services
    When I search the aggregated logs
    Then I should be able to:
      | Action                 | Result                    |
      | Full-text search       | Matching log entries      |
      | Filter by service      | Service-specific logs     |
      | Filter by level        | ERROR, WARN, INFO, DEBUG  |
      | Filter by time         | Custom time range         |
      | Correlate traces       | Related trace IDs         |
    And log search should complete in < 5 seconds
    And logs should be retained per policy

  @P1 @monitoring @traces
  Scenario: Distributed Tracing - Request Tracing
    Given distributed tracing is enabled
    When I investigate a slow request
    Then I should see the full trace:
      | Span                   | Duration         | Service            |
      | HTTP Request           | 450ms            | HAProxy            |
      | Phoenix Controller     | 400ms            | App Node 1         |
      | Ecto Query             | 350ms            | PostgreSQL         |
      | Cache Lookup           | 5ms              | Redis              |
    And I should identify the bottleneck
    And I should be able to compare with baseline

  @P1 @monitoring @capacity
  Scenario: Capacity Monitoring - Resource Forecasting
    Given I am monitoring resource utilization
    When I view capacity forecasts
    Then I should see predictions:
      | Resource               | Current   | 30-Day Forecast   |
      | CPU Utilization        | 45%       | 55%               |
      | Memory Usage           | 60%       | 65%               |
      | Disk Usage             | 40%       | 48%               |
      | Database Size          | 100 GB    | 120 GB            |
    And I should receive alerts for projected capacity issues
    And recommendations should be provided

  # ===========================================================================
  # SECTION 8: SECURITY OPERATIONS
  # ===========================================================================

  @P0 @security @access_review
  Scenario: Access Review - Periodic Access Audit
    Given 90 days have passed since last access review
    When I conduct an access review
    Then I should verify:
      | Check                  | Action                    |
      | Active users           | Confirm still employed    |
      | Permission levels      | Least privilege applied   |
      | Inactive accounts      | Disable if > 30 days      |
      | Service accounts       | Rotate credentials        |
      | API keys               | Verify usage              |
    And findings should be documented
    And remediation should be tracked

  @P0 @security @vulnerability
  Scenario: Vulnerability Scan - Security Assessment
    Given a security scan is scheduled
    When the vulnerability scan runs
    Then I should receive:
      | Finding Type           | Expected Count            |
      | Critical               | 0                         |
      | High                   | 0                         |
      | Medium                 | < 5                       |
      | Low                    | < 20                      |
    And critical/high findings should trigger immediate action
    And remediation timeline should be established

  @P1 @security @penetration
  Scenario: Penetration Testing - Security Validation
    Given penetration testing is authorized
    When the pen test is conducted
    Then the following should be tested:
      | Test Category          | Coverage                  |
      | Authentication         | Login, 2FA, SSO           |
      | Authorization          | RBAC, privilege escalation|
      | Input validation       | SQL injection, XSS        |
      | API security           | Rate limiting, auth       |
      | Network security       | TLS, firewall rules       |
    And findings should be reported and prioritized
    And remediation should be verified

  @P1 @security @incident
  Scenario: Security Incident - Forensic Investigation
    Given a security incident has occurred
    When I conduct forensic investigation
    Then I should:
      | Step                   | Action                    |
      | Preserve evidence      | Lock affected systems     |
      | Collect logs           | All relevant log sources  |
      | Identify IOCs          | Indicators of compromise  |
      | Timeline reconstruction| Attack sequence           |
      | Impact assessment      | Data affected             |
    And findings should support incident report
    And lessons learned should be documented

  # ===========================================================================
  # SECTION 9: BUSINESS CONTINUITY OPERATIONS
  # ===========================================================================

  @P0 @bcp @failover_drill
  Scenario: Failover Drill - Planned Failover Test
    Given a failover drill is scheduled
    When I execute the failover drill
    Then the drill should verify:
      | Capability             | Target                    |
      | Failover time          | < 5 minutes               |
      | Data consistency       | 100%                      |
      | Service availability   | > 99.9%                   |
      | Failback time          | < 10 minutes              |
    And the drill should be documented
    And gaps should be identified and remediated

  @P0 @bcp @backup_restore
  Scenario: Backup Restore - Recovery Test
    Given backups exist from the past 7 days
    When I perform a restore test
    Then the restore should:
      | Step                   | Verification              |
      | Identify backup        | Valid backup selected     |
      | Restore to test env    | Data restored             |
      | Verify integrity       | Checksums match           |
      | Verify functionality   | Application works         |
    And restore time should meet RTO
    And data integrity should be confirmed

  @P1 @bcp @communication
  Scenario: Crisis Communication - Stakeholder Notification
    Given a major incident is in progress
    When I initiate crisis communication
    Then the following should be notified:
      | Stakeholder            | Method           | Timing            |
      | Operations team        | SMS + Call       | Immediate         |
      | Management             | Email + Call     | < 5 minutes       |
      | Customers (if affected)| Email            | < 30 minutes      |
      | Regulators (if required)| Formal letter   | Per regulation    |
    And communication should be tracked
    And updates should be provided per SLA

  # ===========================================================================
  # SECTION 10: PERFORMANCE OPERATIONS
  # ===========================================================================

  @P0 @performance @load_test
  Scenario: Load Testing - Performance Validation
    Given the system is in a test environment
    When I run a load test with 1000 concurrent users
    Then performance should meet targets:
      | Metric                 | Target           | Tolerance         |
      | Response Time (P50)    | < 50ms           | 10%               |
      | Response Time (P99)    | < 200ms          | 10%               |
      | Throughput             | > 1000 rps       | 5%                |
      | Error Rate             | < 0.1%           | 0%                |
      | CPU Utilization        | < 80%            | 5%                |
    And results should be compared to baseline
    And regression should be flagged

  @P1 @performance @optimization
  Scenario: Performance Optimization - Bottleneck Resolution
    Given performance analysis identifies a bottleneck
    When I implement optimization
    Then the following process should occur:
      | Step                   | Action                    |
      | Baseline measurement   | Current metrics captured  |
      | Root cause analysis    | Bottleneck identified     |
      | Implement fix          | Optimization applied      |
      | Validate improvement   | Metrics improved          |
      | Document change        | Knowledge base updated    |
    And improvement should be measurable
    And no regressions should occur

  @P1 @performance @scaling
  Scenario: Auto-Scaling - Dynamic Resource Adjustment
    Given auto-scaling is enabled
    When load increases beyond threshold
    Then the system should:
      | Action                 | Trigger          | Result            |
      | Scale up               | CPU > 70%        | Add node          |
      | Rebalance              | New node healthy | Traffic distributed|
      | Scale down             | CPU < 30%        | Remove node       |
    And scaling should be transparent to users
    And costs should be optimized

  # ===========================================================================
  # SECTION 11: AUDIT OPERATIONS
  # ===========================================================================

  @P0 @audit @compliance
  Scenario: Compliance Audit - Regulatory Preparation
    Given a compliance audit is scheduled
    When I prepare for the audit
    Then I should have:
      | Evidence Type          | Availability              |
      | Access control logs    | Last 12 months            |
      | Configuration changes  | Last 12 months            |
      | Security incidents     | Last 12 months            |
      | Training records       | Current certifications    |
      | Policy documents       | Current versions          |
    And evidence should be exportable
    And gaps should be remediated before audit

  @P0 @audit @internal
  Scenario: Internal Audit - Self-Assessment
    Given quarterly internal audit is due
    When I conduct internal audit
    Then I should verify:
      | Control Area           | Verification Method       |
      | Access management      | Sample user permissions   |
      | Change management      | Review change records     |
      | Incident management    | Review incident logs      |
      | Backup/recovery        | Restore test results      |
    And findings should be documented
    And remediation should be tracked

  @P1 @audit @trail
  Scenario: Audit Trail - Complete Activity Log
    Given an investigation requires historical data
    When I query the audit trail
    Then I should retrieve:
      | Data Type              | Retention                 |
      | User actions           | Indefinite                |
      | System events          | 7 years                   |
      | Configuration changes  | Indefinite                |
      | Security events        | 7 years                   |
    And queries should complete in < 30 seconds
    And data integrity should be cryptographically verified

  # ===========================================================================
  # SECTION 12: TRAINING OPERATIONS
  # ===========================================================================

  @P1 @training @onboarding
  Scenario: Operator Onboarding - New Hire Training
    Given a new operator has joined
    When I initiate onboarding
    Then the training should include:
      | Module                 | Duration         | Assessment        |
      | System Overview        | 2 hours          | Quiz              |
      | Alarm Handling         | 4 hours          | Simulation        |
      | Emergency Procedures   | 2 hours          | Practical         |
      | Compliance             | 1 hour           | Quiz              |
      | Certification          | 1 hour           | Final exam        |
    And progress should be tracked
    And certification should be recorded

  @P1 @training @drill
  Scenario: Emergency Drill - Procedure Validation
    Given quarterly emergency drill is due
    When I conduct emergency drill
    Then the following scenarios should be tested:
      | Scenario               | Participants     | Objective         |
      | Mass alarm event       | All operators    | Storm handling    |
      | System failover        | Senior operators | Failover procedure|
      | Security breach        | Security team    | Incident response |
    And performance should be measured
    And improvements should be identified

  @P1 @training @continuous
  Scenario: Continuous Training - Skill Development
    Given ongoing training is required
    When I review training requirements
    Then the following should be tracked:
      | Requirement            | Frequency        | Status            |
      | Product updates        | Per release      | CURRENT           |
      | Security awareness     | Quarterly        | CURRENT           |
      | Compliance refresher   | Annual           | DUE               |
      | New feature training   | As needed        | COMPLETED         |
    And training compliance should be > 95%
    And gaps should be addressed promptly
