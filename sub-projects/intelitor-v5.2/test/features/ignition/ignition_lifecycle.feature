# Indrajaal Ignition Lifecycle — BDD Feature Specification
# SIL-6 Biomorphic Fractal Mesh — 16-Container Swarm Creation Pipeline
# STAMP Compliance: SC-IGNITE-001 to SC-IGNITE-008, SC-SWARM-001 to SC-SWARM-005
# Constitutional Alignment: Psi-0 (Existence), Psi-3 (Verification), Omega-1 (Patient Mode)
# Version: 21.3.2-SIL6 | 50 Scenarios | 7 Categories

Feature: Indrajaal Ignition Lifecycle — SIL-6 Swarm Creation Pipeline
  As an Indrajaal mesh operator
  I want to boot the full 16-container SIL-6 biomorphic swarm
  So that the system achieves constitutional operational state across all fractal layers (L0-L7)

  The ignition daemon manages a 6-wave hierarchical boot sequence:
    Wave 0: Zenoh Control Plane    (zenoh-router-1, zenoh-router-2, zenoh-router-3)
    Wave 1: Quorum Establishment   (zenoh-router health verified, 2-of-3 minimum)
    Wave 2: Infrastructure Layer   (indrajaal-db-prod, indrajaal-obs-prod)
    Wave 3: Cognitive Layer        (cepaf-bridge, indrajaal-cortex)
    Wave 4: Seed Application       (indrajaal-ex-app-1, indrajaal-chaya, indrajaal-ollama)
    Wave 5: HA + ML Expansion      (indrajaal-ex-app-2, indrajaal-ex-app-3,
                                    indrajaal-mojo, indrajaal-ml-runner-1, indrajaal-ml-runner-2)

  Background: Baseline Ignition Prerequisites
    Given the Indrajaal project root is "/home/an/dev/ver/c3i/sub-projects/intelitor-v5.2"
    And rootless Podman 5.4.1 or higher is available
    And the Zenoh router image "eclipse/zenoh:latest" is present in the local registry
    And all required Dockerfiles exist under the project root
    And no host "_build" or "deps" directories are mounted into containers
    And the CPU governor baseline is below 80% utilization
    And the ignition daemon binary is compiled at "native/ignition_daemon/target/release/ignition_daemon"

  # ===========================================================================
  # CATEGORY 1: HAPPY PATH (5 scenarios)
  # Complete successful boot sequences under nominal conditions
  # ===========================================================================

  Scenario: HP-001 Full 6-wave boot reaches operational state in under 120 seconds
    Given all 16 containers have fresh images (age < 168 hours)
    And no port conflicts exist on ports 7447, 5433, 4317, 4000, 4001, 4002
    And disk space exceeds 10GB on the container storage volume
    When the operator runs "ignition_daemon full --env production"
    Then Wave 0 completes: all 3 zenoh-router containers start within 30 seconds
    And Wave 1 completes: 2-of-3 Zenoh router quorum is established
    And Wave 2 completes: indrajaal-db-prod passes pg_isready on port 5433
    And Wave 2 completes: indrajaal-obs-prod OTEL collector is reachable on port 4317
    And Wave 3 completes: cepaf-bridge and indrajaal-cortex pass container inspect health
    And Wave 4 completes: indrajaal-ex-app-1 serves HTTP on port 4000
    And Wave 4 completes: indrajaal-chaya responds on port 4002
    And Wave 4 completes: indrajaal-ollama API is reachable on port 11434
    And Wave 5 completes: all 5 remaining containers pass liveness checks
    And total boot time is under 120 seconds
    And the system exits with status code 0
    And the operational state is recorded in "lib/cepaf/artifacts/build-history.db"

  Scenario: HP-002 Wave 0 Zenoh control plane boots all three routers in parallel
    Given the Zenoh router image exists locally
    When the operator runs "ignition_daemon launch --wave 0"
    Then zenoh-router-1, zenoh-router-2, and zenoh-router-3 are started concurrently via Async.Parallel
    And all three routers are listening on port 7447 within 30 seconds
    And the Zenoh mesh gossip cookie is verified for all routers
    And each router publishes a heartbeat to "indrajaal/health/zenoh-router-{N}"
    And the ignition daemon logs "Wave 0: Zenoh control plane operational"

  Scenario: HP-003 Status command reports accurate per-container health matrix
    Given the full swarm is running (all 16 containers healthy)
    When the operator runs "ignition_daemon status"
    Then the output contains a 16-row health matrix
    And each row shows: container name, status (healthy/degraded/critical), uptime, and port
    And zenoh-router-1, zenoh-router-2, zenoh-router-3 show status "healthy"
    And indrajaal-db-prod shows pg_isready result "accepting connections"
    And the OODA cycle latency is reported as under 100ms
    And the exit code is 0

  Scenario: HP-004 Boot attestation tokens are generated and verified for all containers
    Given the full swarm boot completes successfully
    When the system generates boot attestation tokens
    Then each of the 16 containers receives a unique Ed25519-signed attestation token
    And attestation tokens are valid for 1 hour from generation time
    And token generation is logged to the immutable audit trail
    And the FPPS 5-method consensus validates all 16 attestation tokens
    And tokens are published to "indrajaal/attestation/{container-name}"

  Scenario Outline: HP-005 Individual wave boot succeeds for each wave independently
    Given all prerequisite waves have completed successfully
    When the operator runs "ignition_daemon launch --wave <wave_number>"
    Then the containers in "<containers>" are started
    And all containers in "<containers>" pass their health checks within "<timeout>" seconds
    And the wave completion is logged with timestamp and duration
    And EMA (alpha=0.3) boot time is updated in build-history.db for each container

    Examples:
      | wave_number | containers                                                        | timeout |
      | 0           | zenoh-router-1,zenoh-router-2,zenoh-router-3                      | 30      |
      | 2           | indrajaal-db-prod,indrajaal-obs-prod                              | 60      |
      | 3           | cepaf-bridge,indrajaal-cortex                                     | 60      |
      | 4           | indrajaal-ex-app-1,indrajaal-chaya,indrajaal-ollama               | 60      |
      | 5           | indrajaal-ex-app-2,indrajaal-ex-app-3,indrajaal-mojo,indrajaal-ml-runner-1,indrajaal-ml-runner-2 | 60 |

  # ===========================================================================
  # CATEGORY 2: PRE-FLIGHT FAILURES (8 scenarios)
  # 18-point pre-flight check system validation and error handling
  # ===========================================================================

  Scenario: PF-001 Pre-flight fails when required port 7447 is already bound
    Given port 7447 is already bound by another process (pid 9999)
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "FAIL: Port 7447 conflict — PID 9999 holds the Zenoh router port"
    And the pre-flight summary shows 1 critical failure
    And the system exits with code 1
    And no containers are started
    And the port conflict is logged to the audit trail with process details

  Scenario: PF-002 Pre-flight fails when Dockerfile.sopv51-app is missing
    Given the file "Dockerfile.sopv51-app" does not exist in the project root
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "FAIL: Missing Dockerfile — Dockerfile.sopv51-app not found"
    And affected containers are identified: "indrajaal-ex-app-1, indrajaal-ex-app-2, indrajaal-ex-app-3, indrajaal-chaya"
    And the system exits with code 1
    And no containers are started

  Scenario: PF-003 Pre-flight fails when NIF glibc/musl mismatch is detected (Axiom 0.1)
    Given the host system uses musl libc
    And the Elixir NIF "zenoh_nif.so" was compiled against glibc
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "FAIL: Substrate Integrity Violation — NIF glibc/musl mismatch detected"
    And the remediation advice states "Remove host _build and deps directories; rebuild inside container"
    And the violation is logged as "SC-NIF-001 substrate integrity breach"
    And the system exits with code 2
    And no containers are started

  Scenario: PF-004 Pre-flight fails when host _build directory is mounted into container path
    Given the host directory "_build" exists and is mapped to "/app/_build" in docker-compose
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "FAIL: Axiom 0.1 violation — host _build directory shadowing container build artifacts"
    And the check identifies the volume mount "host:_build → /app/_build" as the violation
    And the system exits with code 2
    And the operator is instructed to remove the volume mount and rebuild

  Scenario: PF-005 Pre-flight fails when available disk space is below 10GB threshold
    Given the container storage volume has only 4GB free space
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "FAIL: Insufficient disk space — 4GB available, 10GB required"
    And the check identifies which containers require the most space
    And the system exits with code 1
    And no containers are started

  Scenario: PF-006 Pre-flight fails when the container network is unavailable
    Given the Podman network "indrajaal-mesh" does not exist
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "FAIL: Container network 'indrajaal-mesh' not found"
    And the remediation advice states "Run: podman network create indrajaal-mesh"
    And the system exits with code 1

  Scenario: PF-007 Pre-flight fails when Podman daemon is not running
    Given the Podman socket at "/run/user/1000/podman/podman.sock" is not accessible
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "FAIL: Podman daemon not running — socket not found"
    And the remediation advice states "Start systemd user service: systemctl --user start podman.socket"
    And the system exits with code 3

  Scenario: PF-008 Pre-flight warns when Podman is not running in rootless mode
    Given Podman is running as root (UID 0)
    When the operator runs "ignition_daemon preflight"
    Then the pre-flight check reports "WARN: Rootless mode required — Podman running as root violates Omega-2"
    And the warning is classified as severity HIGH per SC-SIL4-001
    And the pre-flight summary shows 0 critical failures and 1 warning
    And the operator is prompted to confirm continuation with "--force-rootful" flag
    And the system exits with code 0 when confirmed or code 1 when not confirmed

  # ===========================================================================
  # CATEGORY 3: LAUNCH FAILURES (8 scenarios)
  # Wave-specific boot failures and cascading error handling
  # ===========================================================================

  Scenario: LF-001 Wave 0 failure halts pipeline when all three Zenoh routers fail to bind
    Given the Zenoh router image is present
    And port 7447 becomes unavailable after container creation (race condition)
    When the operator runs "ignition_daemon launch --wave 0"
    Then all 3 Zenoh router containers attempt to start
    And all 3 containers fail to bind port 7447
    And the ignition daemon logs "Wave 0 FAILED: Zenoh control plane could not establish — 0/3 routers healthy"
    And Wave 1 through Wave 5 are NOT started (pipeline halted per SC-IGNITE-002)
    And the system exits with code 10
    And the failure is recorded in build-history.db with action "boot" and success "false"

  Scenario: LF-002 Wave 1 quorum failure halts pipeline when only 1-of-3 routers achieves health
    Given Wave 0 starts all 3 Zenoh routers
    And zenoh-router-2 and zenoh-router-3 fail their TCP health check on port 7447
    When the quorum check executes for Wave 1
    Then the quorum check reports "1/3 routers healthy — minimum 2-of-3 not met"
    And the ignition daemon halts before Wave 2
    And the failure message references SC-SIL4-011 (quorum floor N/2+1)
    And the partial Wave 0 containers are stopped and removed via compensating transaction
    And the system exits with code 11

  Scenario: LF-003 Wave 2 database failure halts pipeline when pg_isready times out
    Given Wave 0 and Wave 1 complete successfully
    And the indrajaal-db-prod container starts but PostgreSQL does not initialize within 60 seconds
    When the Wave 2 health check polls pg_isready on port 5433
    Then the health check reports "TIMEOUT: pg_isready failed after 60s on port 5433"
    And the ignition daemon logs "Wave 2 FAILED: indrajaal-db-prod database not accepting connections"
    And Wave 3 through Wave 5 are NOT started
    And the system initiates recovery up to 3 attempts with exponential backoff (100ms, 200ms, 400ms)
    And after 3 failed attempts the system exits with code 12

  Scenario: LF-004 Wave 3 cognitive layer crash triggers DAG-aware cascading stop
    Given Waves 0 through 2 complete successfully
    And indrajaal-cortex starts but crashes immediately due to missing environment variable "ZENOH_ROUTER_ENDPOINT"
    When Wave 3 executes the cognitive layer boot
    Then cepaf-bridge detects cortex dependency failure via Zenoh pub/sub health topic
    And the ignition daemon logs "Wave 3 FAILED: indrajaal-cortex exited with code 1 — missing env ZENOH_ROUTER_ENDPOINT"
    And the DAG cascading stop removes cepaf-bridge (which depends on cortex) from running state
    And Wave 4 and Wave 5 are NOT started
    And the system exits with code 13

  Scenario: LF-005 GenServer BadMapError during Wave 4 triggers Jidoka halt
    Given Waves 0 through 3 complete successfully
    And indrajaal-ex-app-1 starts but encounters a BadMapError in GenServer init
    When the application layer health check runs
    Then the ignition daemon detects "BadMapError" in the container stdout stream
    And the Jidoka protocol triggers: STOP, SIGNAL, ANALYZE
    And the error is published to Zenoh topic "indrajaal/ignition/error"
    And the ignition daemon logs "JIDOKA HALT: BadMapError detected in indrajaal-ex-app-1 GenServer — AOR-SAF-001"
    And the system exits with code 14

  Scenario: LF-006 Container image pull failure for indrajaal-ollama aborts Wave 4
    Given Waves 0 through 3 complete successfully
    And the registry for "ollama/ollama:latest" is unreachable
    When Wave 4 attempts to pull the Ollama image
    Then the pull fails with "Error: manifest unknown: manifest unknown"
    And the ignition daemon reports "Wave 4 FAILED: Could not pull ollama/ollama:latest — registry unreachable"
    And the operator is instructed to verify network connectivity and registry availability
    And Wave 4 does not start any containers in the wave
    And the system exits with code 15

  Scenario: LF-007 Build failure for indrajaal-ex-app-1 (Dockerfile.sopv51-app compile error)
    Given Waves 0 through 3 complete successfully
    And the Elixir compilation inside Dockerfile.sopv51-app fails with a syntax error
    When Wave 4 triggers genetic re-synthesis for indrajaal-ex-app-1
    Then the build stream monitor captures the compile error from podman build stdout
    And the ignition daemon logs "Build FAILED: indrajaal-ex-app-1 — Elixir compile error in line 42 of mix.exs"
    And the EMA prediction is NOT updated for this container (build unsuccessful)
    And Wave 4 does not proceed to launch indrajaal-chaya or indrajaal-ollama
    And the system exits with code 16

  Scenario: LF-008 Wave 5 timeout exceeded triggers rollback of all Wave 5 containers
    Given Waves 0 through 4 complete successfully
    And indrajaal-ex-app-2, indrajaal-ex-app-3 start successfully
    And indrajaal-mojo fails to serve its inference endpoint within 60 seconds
    When the Wave 5 timeout of 60 seconds expires
    Then the ignition daemon logs "Wave 5 TIMEOUT: indrajaal-mojo did not become healthy within 60s"
    And Wave 5 rollback executes: indrajaal-ex-app-2, indrajaal-ex-app-3, indrajaal-mojo, indrajaal-ml-runner-1, indrajaal-ml-runner-2 are stopped
    And the rollback is logged as a compensating transaction in the audit trail
    And the system exits with code 17

  # ===========================================================================
  # CATEGORY 4: VERIFICATION FAILURES (5 scenarios)
  # FPPS consensus, ProofToken, OODA, health, attestation failures
  # ===========================================================================

  Scenario: VF-001 FPPS 5-method consensus failure halts boot verification
    Given all 16 containers are running
    When the ignition daemon runs "ignition_daemon verify --fpps"
    And 2 of the 5 FPPS verification methods return inconclusive results
    Then the FPPS consensus reports "FAIL: 3/5 methods agree — minimum 4/5 consensus not achieved"
    And the failing methods are identified: static analysis, runtime probe
    And the verification halt is logged per SC-VER-002
    And the system exits with code 20
    And the operator is directed to resolve the inconclusive verification methods before proceeding

  Scenario: VF-002 ProofToken missing on control-plane message blocks verification
    Given all 16 containers are running
    And a control-plane message is received on "indrajaal/control/command" without a ProofToken header
    When the ignition daemon verifies the control-plane message integrity
    Then the verifier reports "FAIL: ProofToken absent — SC-NIF-006 requires signed tokens on all control messages"
    And the message is rejected and quarantined
    And a security alert is published to "indrajaal/sentinel/threats"
    And the incident is logged to the immutable audit trail with the raw message hash
    And the system exits with code 21

  Scenario: VF-003 OODA cycle exceeds 100ms threshold during verification
    Given all 16 containers are running
    And network latency between containers is artificially elevated to 150ms
    When the ignition daemon runs "ignition_daemon verify --ooda"
    Then the OODA cycle measurement returns 165ms
    And the verifier reports "FAIL: OODA cycle 165ms exceeds 100ms threshold — SC-VER-041"
    And the slow subsystem is identified: "Observe phase: 120ms — Zenoh subscription delay"
    And the system exits with code 22

  Scenario: VF-004 Health endpoint unreachable for indrajaal-ex-app-2 during verification
    Given 15 of 16 containers are running and healthy
    And indrajaal-ex-app-2 is running but its HTTP health endpoint on port 4001 is not responding
    When the ignition daemon runs "ignition_daemon verify"
    Then the health check for indrajaal-ex-app-2 fails with "Connection refused on port 4001"
    And the verifier reports "FAIL: indrajaal-ex-app-2 health endpoint unreachable — 1/16 containers degraded"
    And the container is marked as "DEGRADED" in the system state
    And the system exits with code 23

  Scenario: VF-005 Boot attestation token expires before verification completes
    Given the full swarm boot completes successfully
    And the boot took 65 minutes due to slow network conditions
    And attestation tokens were generated at T=0 with 60-minute validity
    When the ignition daemon runs "ignition_daemon verify --attestation"
    Then the attestation verifier reports "FAIL: 16/16 attestation tokens expired — validity window 3600s exceeded"
    And the verifier instructs: "Re-run ignition_daemon full to regenerate fresh attestation tokens"
    And the expired tokens are revoked in the audit log
    And the system exits with code 24

  # ===========================================================================
  # CATEGORY 5: RECOVERY SCENARIOS (8 scenarios)
  # Auto-recovery, DAG cascading restart, rollback, and budget exhaustion
  # ===========================================================================

  Scenario: RC-001 Auto-recovery succeeds within 3-attempt budget when container crashes
    Given all 16 containers are initially running
    And indrajaal-ex-app-3 crashes with exit code 137 (OOM killed) during operation
    When the ignition daemon detects the crash via Zenoh health monitoring
    Then attempt 1 restarts indrajaal-ex-app-3 after 100ms backoff
    And indrajaal-ex-app-3 starts successfully on attempt 1
    And the recovery is logged: "RC-001: indrajaal-ex-app-3 recovered in 1 attempt — within 3-attempt/10-min budget"
    And the system state returns to "fully operational" with all 16 containers healthy
    And the recovery event is recorded in build-history.db

  Scenario: RC-002 Recovery budget exhausted after 3 failed restart attempts
    Given all 16 containers are initially running
    And indrajaal-mojo crashes repeatedly due to a persistent configuration error
    When the ignition daemon attempts auto-recovery
    Then attempt 1 fails after 100ms backoff
    And attempt 2 fails after 200ms backoff
    And attempt 3 fails after 400ms backoff
    And after 3 failed attempts the recovery budget is marked exhausted
    And the ignition daemon logs "RC-002: Recovery budget exhausted for indrajaal-mojo — manual intervention required"
    And a critical alert is published to "indrajaal/ignition/error" with all 3 failure reasons
    And the operator is instructed to inspect logs: "podman logs indrajaal-mojo"
    And the system exits with code 30

  Scenario: RC-003 DAG-aware cascading restart recovers dependent containers in wave order
    Given zenoh-router-1 crashes unexpectedly during operation
    When the ignition daemon detects the crash and determines that quorum is maintained (2-of-3 routers still healthy)
    Then only zenoh-router-1 is restarted (not the full swarm)
    And dependent containers (ex-app-1, ex-app-2, ex-app-3) are NOT restarted as quorum is maintained
    And zenoh-router-1 rejoins the mesh within 30 seconds
    And the recovery is logged as "RC-003: Single router recovery — quorum preserved throughout"

  Scenario: RC-004 Wave rollback executes compensating transactions on Wave 3 failure
    Given Waves 0, 1, and 2 have completed successfully
    And Wave 3 starts cepaf-bridge successfully but indrajaal-cortex fails
    When the Wave 3 rollback is triggered
    Then the compensating transaction stops cepaf-bridge (which was started in the same wave)
    And cepaf-bridge is removed (not just stopped) to return to pre-Wave-3 state
    And the rollback completion is logged: "Compensating transaction complete — Wave 3 state rolled back"
    And Waves 0, 1, and 2 containers remain running (rollback is wave-scoped)
    And the system exits with code 13

  Scenario: RC-005 Partial wave recovery restores degraded containers without full restart
    Given all 16 containers are running
    And indrajaal-ml-runner-2 becomes unhealthy (health check fails) but does not crash
    When the ignition daemon detects the degraded state
    Then it attempts an in-place recovery: restart only indrajaal-ml-runner-2
    And indrajaal-ml-runner-1 continues running without interruption
    And indrajaal-ml-runner-2 recovers and passes health checks within 30 seconds
    And the recovery is classified as "partial wave recovery" (Wave 5, single container)
    And the total system downtime for indrajaal-ml-runner-2 is under 30 seconds

  Scenario: RC-006 Container replacement via image re-pull when runtime corruption is detected
    Given all 16 containers are running
    And the indrajaal-obs-prod container reports file system corruption in its OTEL data directory
    When the ignition daemon detects the corruption via health probe
    Then the ignition daemon stops and removes the corrupted container
    And pulls a fresh image of "Dockerfile.observability" to replace it
    And the fresh container starts and passes OTEL health checks on port 4317
    And the replacement is logged: "RC-006: indrajaal-obs-prod replaced — fresh image pulled, runtime corruption remediated"

  Scenario: RC-007 Recovery succeeds after transient network partition between Wave 2 and Wave 4
    Given Waves 0 through 3 complete successfully
    And a 5-second network partition isolates Wave 4 containers from the Zenoh mesh
    When the network partition resolves after 5 seconds
    Then the Wave 4 containers reconnect to the Zenoh mesh automatically
    And reconnection health is verified by confirming Zenoh subscriptions are restored
    And the ignition daemon logs "RC-007: Network partition recovery — Wave 4 containers rejoined mesh in 8s"
    And no containers are restarted (reconnection is sufficient)

  Scenario: RC-008 Restart policy enforcement prevents infinite restart loops
    Given indrajaal-ollama crashes 10 times within 10 minutes
    When the ignition daemon evaluates the restart policy
    Then the restart policy enforcer detects a restart rate of 60/hour (above threshold of 12/hour)
    And the container is placed in "backoff-quarantine" state
    And no further automatic restarts are attempted for 30 minutes
    And the operator receives a critical alert: "RC-008: indrajaal-ollama restart storm detected — quarantined for 30 minutes"
    And the event is logged to the immutable audit trail per SC-SAFETY-003

  # ===========================================================================
  # CATEGORY 6: TUI SCENARIOS (8 scenarios)
  # Dashboard rendering, keyboard navigation, and real-time display
  # ===========================================================================

  Scenario: TUI-001 Dashboard renders 16-container health grid with ANSI colors
    Given all 16 containers are running with mixed health states (12 healthy, 3 degraded, 1 critical)
    When the operator runs "ignition_daemon dashboard"
    Then the TUI renders a 16-row container status grid
    And healthy containers are displayed with green ANSI color codes (ESC[32m)
    And degraded containers are displayed with yellow ANSI color codes (ESC[33m)
    And the critical container (indrajaal-mojo) is displayed with red ANSI color codes (ESC[31m) and blinking
    And the grid updates every 2 seconds via real-time Zenoh subscription
    And the terminal title shows "Indrajaal Ignition Dashboard — 12 Healthy | 3 Degraded | 1 Critical"

  Scenario: TUI-002 Keyboard navigation allows operator to select individual containers
    Given the dashboard is running and showing the 16-container grid
    When the operator presses the DOWN arrow key 3 times
    Then the cursor moves to row 4 (indrajaal-db-prod)
    And indrajaal-db-prod is highlighted with an inverse video selection indicator
    When the operator presses ENTER
    Then a detail panel opens showing: container ID, status, uptime, port bindings, and last 20 log lines
    When the operator presses ESC
    Then the detail panel closes and the grid view is restored

  Scenario: TUI-003 Wave progress bars show real-time boot progress during launch
    Given the ignition daemon is executing "ignition_daemon full" with TUI enabled
    When Wave 2 is starting (indrajaal-db-prod and indrajaal-obs-prod)
    Then a progress bar is shown for Wave 2: "[==========          ] 50% — 1/2 containers healthy"
    And the EMA-predicted time remaining is displayed: "ETA: ~15s (EMA: 18s)"
    When indrajaal-obs-prod passes its health check
    Then the Wave 2 progress bar shows: "[====================] 100% — Wave 2 complete in 24s"
    And Wave 3 progress bar appears immediately below

  Scenario: TUI-004 Log tail panel streams live container output for selected container
    Given the dashboard is running and indrajaal-ex-app-1 is selected
    When the operator presses "L" to open the log tail panel
    Then the log tail panel opens showing the last 50 lines from "podman logs --follow indrajaal-ex-app-1"
    And new log lines are appended in real time as the container produces output
    And log lines containing "ERROR" are highlighted in red
    And log lines containing "WARNING" are highlighted in yellow
    When the operator presses "Q" to close the log panel
    Then the log streaming stops and the dashboard grid is restored

  Scenario: TUI-005 Container status grid shows port bindings for all 16 containers
    Given all 16 containers are running
    When the operator views the dashboard status grid
    Then the grid displays port bindings in the "Ports" column for each container
    And zenoh-router-1 shows "7447/tcp"
    And indrajaal-db-prod shows "5433/tcp"
    And indrajaal-obs-prod shows "4317/tcp, 9090/tcp, 3000/tcp"
    And indrajaal-ex-app-1 shows "4000/tcp"
    And indrajaal-chaya shows "4002/tcp"
    And indrajaal-ollama shows "11434/tcp"

  Scenario: TUI-006 CPU and memory sparklines update every 5 seconds for each container
    Given the dashboard is running with sparkline view enabled ("V" key)
    When 30 seconds elapse
    Then CPU sparklines show the last 6 data points (30 seconds of history at 5s intervals)
    And memory sparklines show the last 6 data points
    And containers exceeding 80% CPU are highlighted with a warning indicator
    And the CPU governor status is shown in the dashboard header: "CPU Governor: ACTIVE — 75% load, 12 jobs"
    And sparklines are rendered using Unicode block characters (U+2581 to U+2588)

  Scenario: TUI-007 Error panel highlights failed containers with root cause summary
    Given indrajaal-cortex has failed with exit code 1
    When the operator views the dashboard
    Then indrajaal-cortex appears in a distinct "Failed Containers" panel at the bottom
    And the panel shows the last error: "exit code 1 — Process exited: missing env ZENOH_ROUTER_ENDPOINT"
    And the recovery attempt count is shown: "Recovery attempts: 2/3"
    And an action menu offers: [R] Retry Recovery | [I] Inspect Logs | [D] Delete Container | [S] Skip
    When the operator presses "R"
    Then recovery attempt 3 is initiated and the dashboard updates in real time

  Scenario: TUI-008 Dashboard auto-refreshes and recovers from terminal resize
    Given the dashboard is running in an 80x24 terminal
    When the operator resizes the terminal to 120x40
    Then the dashboard detects the SIGWINCH signal
    And the layout reflows to use the new terminal dimensions
    And the 16-container grid expands to show additional columns (memory, CPU, restarts)
    And the dashboard continues updating without requiring a restart
    And the refresh interval remains 2 seconds throughout the resize operation

  # ===========================================================================
  # CATEGORY 7: PERFORMANCE AND SECURITY SCENARIOS (8 scenarios)
  # CPU Governor, EMA prediction, ProofToken latency, audit integrity
  # ===========================================================================

  Scenario: PS-001 CPU Governor throttles parallelism when CPU exceeds 80% threshold
    Given the system CPU utilization is at 85%
    And the CPU governor is enabled (SC-CPU-GOV-001)
    When the operator runs "ignition_daemon launch --wave 5"
    Then the CPU governor detects 85% CPU and reduces scheduler count from 16 to 6
    And the parallelism for Wave 5 is reduced: only 3 containers start simultaneously instead of 5
    And the governor logs "CPU Governor: throttling active — 85% load, reduced to 6 schedulers"
    And when CPU drops below 75%, parallelism is automatically restored to 16 schedulers
    And the CPU governor status is published to Zenoh: "indrajaal/cpu/governor/status"

  Scenario: PS-002 Build Oracle EMA prediction provides accurate boot time estimates
    Given the build-history.db contains 10 previous build records for indrajaal-ex-app-1
    And the EMA (alpha=0.3) for indrajaal-ex-app-1 is 45 seconds
    When the operator runs "ignition_daemon launch --wave 4" with verbose output
    Then the dashboard displays "ETA for indrajaal-ex-app-1: ~45s (EMA-predicted)"
    And after the container boots in 42 seconds, the EMA is updated: "new EMA = 0.3*42 + 0.7*45 = 43.9s"
    And the updated EMA is stored via UPSERT in build-history.db
    And the EMA prediction accuracy for this run is recorded as 93% (within 5% of actual)

  Scenario: PS-003 ProofToken validation completes in under 1ms per message
    Given the ignition daemon is processing control-plane messages with ProofToken enforcement
    When 1000 consecutive control messages arrive on "indrajaal/control/command"
    Then each message is validated for ProofToken presence and Ed25519 signature
    And the 95th percentile validation latency is under 1 millisecond
    And the 99th percentile validation latency is under 2 milliseconds
    And no messages pass through without a valid ProofToken (0 bypass events)
    And the validation throughput exceeds 5000 messages/second

  Scenario: PS-004 Parallel Wave boot achieves minimum 3x speedup over sequential boot
    Given baseline sequential boot time for all 16 containers is 360 seconds (22.5s per container)
    When the ignition daemon boots all waves with Async.Parallel enabled
    Then Wave 0 boots 3 containers in parallel (measured: 30s instead of 67.5s)
    And Wave 5 boots 5 containers in parallel (measured: 60s instead of 112.5s)
    And the total parallel boot time is under 120 seconds
    And the speedup ratio is at least 3x compared to sequential baseline
    And the parallelization efficiency is logged: "Parallel efficiency: 94% (3 wasted slot-seconds)"

  Scenario: PS-005 Memory pressure handling prevents OOM during Wave 5 parallel boot
    Given available system memory is 4GB
    And Wave 5 would require 6GB if all 5 containers start simultaneously
    When the ignition daemon evaluates memory constraints before Wave 5
    Then the memory-aware scheduler starts only 3 containers simultaneously (fitting within 4GB)
    And once the first 3 containers are healthy and memory stabilizes, the remaining 2 start
    And no OOM kills occur during the Wave 5 boot
    And the memory scheduling decision is logged: "Memory-constrained scheduling: 3+2 stagger for Wave 5"

  Scenario Outline: PS-006 Audit log entries maintain cryptographic integrity for all operations
    Given the ignition daemon is performing "<operation>"
    When the operation completes (success or failure)
    Then an audit log entry is written to the immutable register
    And the entry contains: timestamp (ISO 8601), operation, result, actor, container names
    And the entry is signed with a SHA-256 hash of all preceding entries (chain integrity)
    And the hash chain is verified by reading back the last 5 entries
    And tampering with any entry invalidates all subsequent entries (detected in verification)

    Examples:
      | operation                    |
      | preflight check              |
      | Wave 0 Zenoh boot            |
      | attestation token generation |
      | container recovery attempt   |
      | FPPS consensus verification  |
      | ProofToken validation        |

  Scenario: PS-007 Container image signature verification rejects unsigned images
    Given the Indrajaal registry requires Ed25519-signed images (SC-SIL4-024)
    And an unsigned version of "indrajaal-cortex" is present in the local registry
    When the ignition daemon performs genetic re-synthesis for Wave 3
    Then the image verifier checks the Ed25519 signature of the indrajaal-cortex image
    And the verification fails: "FAIL: indrajaal-cortex image is unsigned — SC-SIL4-024 requires Ed25519 signature"
    And the unsigned image is NOT used to start the container
    And the violation is published to "indrajaal/sentinel/threats" with image hash and timestamp
    And the system exits with code 40

  Scenario: PS-008 Boot time SLA compliance verified — full swarm under 120 seconds
    Given all images are fresh and all pre-flight checks pass
    When the ignition daemon executes "ignition_daemon full --env production --sla 120"
    Then the boot timer starts at Wave 0 container creation
    And the timer stops when all 16 containers pass their health checks
    And if total boot time exceeds 120 seconds, an SLA breach alert is raised
    And the SLA result is published: "indrajaal/ignition/sla" with fields: target_seconds, actual_seconds, breach (bool)
    And the EMA predictions are evaluated: containers with EMA > 20s are flagged for optimization
    And the final SLA compliance report is written to "lib/cepaf/artifacts/sla-report-{timestamp}.json"
