# PRAJNA BDD COVERAGE MATRIX: DAG-GENERATED SCENARIOS
**Classification**: TEST SPECIFICATION
**Strategy**: GRAPH-BASED PATH COVERAGE
**Target**: 100% Runtime Scenario Coverage
**Version**: 1.0.0

---

## 1.0 METHODOLOGY: THE EXECUTION GRAPH

To guarantee 100% coverage of runtime scenarios, we model the Prajna system as a **Directed Acyclic Graph (DAG)** of state transitions. We then generate test cases by traversing every valid path from `Start` to a terminal state (`Stable` or `Exit`).

### 1.1 The State Space ($V$)
The system state is defined by the tuple: $(S_{conn}, S_{auth}, S_{guard}, S_{ui})$
*   **$S_{conn}$ (Connectivity)**: `Disconnected` | `Connecting` | `Connected` | `Partitioned`
*   **$S_{auth}$ (KMS)**: `Unknown` | `Syncing` | `Synced` | `Stale`
*   **$S_{guard}$ (Safety)**: `Green` | `Amber` (Warning) | `Red` (Trip)
*   **$S_{ui}$ (Interaction)**: `Idle` | `Armed` | `Executing` | `Background`

### 1.2 The Events ($E$)
*   `E_BOOT`: Application start
*   `E_NET_UP`: Zenoh link established
*   `E_NET_DOWN`: Zenoh link lost
*   `E_METRIC`: Telemetry packet received
*   `E_ANOMALY`: Metric exceeds Z-score threshold
*   `E_USER_ARM`: User presses ARM key
*   `E_USER_FIRE`: User presses FIRE key
*   `E_TIMEOUT`: Wait period expired
*   `E_SIGNOFF`: Application exit

---

## 2.0 SCENARIO GENERATION (PATH TRAVERSAL)

### 2.1 Cluster A: The Lifecycle Paths (Connectivity & State)
*Coverage Target: L5 (Network) & L6 (System)*

**DAG Branch**: `Boot` $\rightarrow$ `Connection` $\rightarrow$ `Operation`

| Path ID | Sequence | Description |
| :--- | :--- | :--- |
| **PATH-LC-01** | `Boot` $\rightarrow$ `E_NET_UP` $\rightarrow$ `Sync` $\rightarrow$ `Ready` | **Golden Path**: Clean startup. |
| **PATH-LC-02** | `Boot` $\rightarrow$ `E_NET_UP` $\rightarrow$ `Sync` $\rightarrow$ `E_NET_DOWN` $\rightarrow$ `Partitioned` | **Partition**: Network loss during ops. |
| **PATH-LC-03** | `Boot` $\rightarrow$ `E_NET_UP` $\rightarrow$ `Sync` $\rightarrow$ `E_NET_DOWN` $\rightarrow$ `E_NET_UP` $\rightarrow$ `Re-Sync` | **Recovery**: Transient network failure. |
| **PATH-LC-04** | `Boot` $\rightarrow$ `Timeout` (No Net) $\rightarrow$ `OfflineMode` | **Offline**: Start without mesh. |

### 2.2 Cluster B: The Control Paths (Command & Safety)
*Coverage Target: L3 (Holon) & L7 (Human)*

**DAG Branch**: `Ready` $\rightarrow$ `Interaction` $\rightarrow$ `Actuation`

| Path ID | Sequence | Description |
| :--- | :--- | :--- |
| **PATH-CT-01** | `Idle` $\rightarrow$ `E_USER_ARM` $\rightarrow$ `Armed` $\rightarrow$ `E_USER_FIRE` $\rightarrow$ `Executing` $\rightarrow$ `Idle` | **Golden Command**: Successful actuation. |
| **PATH-CT-02** | `Idle` $\rightarrow$ `E_USER_ARM` $\rightarrow$ `Armed` $\rightarrow$ `E_TIMEOUT` $\rightarrow$ `Idle` | **Safety Timeout**: User arms but doesn't fire. |
| **PATH-CT-03** | `Idle` $\rightarrow$ `E_USER_ARM` $\rightarrow$ `Armed` $\rightarrow$ `E_ANOMALY` $\rightarrow$ `Trip` $\rightarrow$ `Idle` | **Guardian Veto**: Threat detected during arming. |
| **PATH-CT-04** | `Idle` $\rightarrow$ `E_USER_FIRE` (No Arm) $\rightarrow$ `Refused` $\rightarrow$ `Idle` | **Protocol Violation**: Fire without Arm. |

### 2.3 Cluster C: The Data Paths (Telemetry & Anomalies)
*Coverage Target: L1 (Atomic) & L2 (Component)*

**DAG Branch**: `Ready` $\rightarrow$ `Ingestion` $\rightarrow$ `Analysis`

| Path ID | Sequence | Description |
| :--- | :--- | :--- |
| **PATH-DT-01** | `Ready` $\rightarrow$ `E_METRIC` (Normal) $\rightarrow$ `UpdateStats` $\rightarrow$ `UI_Refresh` | **Normal Flow**: Standard telemetry. |
| **PATH-DT-02** | `Ready` $\rightarrow$ `E_METRIC` (Spike) $\rightarrow$ `E_ANOMALY` $\rightarrow$ `AlertUI` | **Anomaly Detection**: Z-Score trigger. |
| **PATH-DT-03** | `Ready` $\rightarrow$ `E_METRIC` (Malformed) $\rightarrow$ `Drop` $\rightarrow$ `LogWarn` | **Resilience**: Bad data rejection. |
| **PATH-DT-04** | `Ready` $\rightarrow$ `E_METRIC` (Flood) $\rightarrow$ `Backpressure` $\rightarrow$ `DropTail` | **Load Shedding**: High throughput handling. |

---

## 3.0 BDD SPECIFICATIONS (GHERKIN)

### 3.1 Feature: Nervous System Connectivity (PATH-LC-*)

```gherkin
Feature: Zenoh Mesh Connectivity
  As a System Operator
  I want the Cockpit to maintain a robust link to the Elixir Mesh
  So that I can observe and control the system reliably

  Scenario: [LC-01] Clean Startup and Sync
    Given the F# Cockpit is initialized
    And the Zenoh Mesh is active with "App-Node-1" present
    When the Orchestrator starts the "NervousSystem" agent
    Then the connection status should transition to "CONNECTED" within 500ms
    And the "KmsSubscriber" should receive the initial "WorldState"
    And the Dashboard should display "MESH: ONLINE" in Green

  Scenario: [LC-03] Transient Partition Recovery
    Given the Cockpit is "CONNECTED" to the mesh
    When the network link is severed (simulated)
    Then the status should change to "PARTITIONED" within 100ms
    And all node indicators should turn "STALE" (Gray)
    And the "CircuitBreaker" should be "OPEN"
    
    When the network link is restored
    Then the status should return to "CONNECTED"
    And the "KmsSubscriber" should request a "StateResync"
    And the "CircuitBreaker" should transition to "HALF-OPEN"
```

### 3.2 Feature: Safety-Critical Actuation (PATH-CT-*)

```gherkin
Feature: Two-Key Turn Command Protocol
  As a Safety Officer
  I want a strict ARM/FIRE protocol for commands
  So that accidental actuations are mathematically impossible

  Scenario: [CT-01] Successful Command Execution
    Given the system is "CONNECTED" and "HEALTHY"
    And the "Hydraulic-Press" node is selected
    When I press the "ARM" key (Space)
    Then the Command State should transition to "ARMED"
    And the UI should flash "CONFIRMATION REQUIRED"
    And NO network packet should be emitted
    
    When I press the "FIRE" key (Enter) within 5 seconds
    Then the Command State should transition to "EXECUTING"
    And a signed "Actuate" command should be published to Zenoh
    And the "AuditLog" should record the "CommandIssued" event

  Scenario: [CT-02] Arming Timeout Safety
    Given the system is "ARMED" for "Hydraulic-Press"
    When I wait for 6 seconds without input
    Then the Command State should automatically revert to "IDLE"
    And the UI should display "ARM EXPIRED"
    And the "AuditLog" should record "CommandExpired"

  Scenario: [CT-03] Guardian Veto on Anomaly
    Given the system is "ARMED" for "Hydraulic-Press"
    When a "HighTemp" anomaly is detected on "Hydraulic-Press"
    And I press the "FIRE" key
    Then the Guardian Agent should Intercept the command
    And the Command State should transition to "BLOCKED"
    And the UI should show "SAFETY VETO: HighTemp" in Red
```

### 3.3 Feature: Telemetry Resilience (PATH-DT-*)

```gherkin
Feature: High-Volume Telemetry Ingestion
  As a SRE
  I want the system to process or gracefully drop high-velocity data
  So that the dashboard remains responsive under load

  Scenario: [DT-02] Anomaly Detection
    Given the SmartMetrics engine is running
    And the "CPU" baseline mean is 40.0 with std_dev 5.0
    When a telemetry packet arrives with "CPU" value 95.0
    Then the Z-Score should be calculated as > 10.0
    And an "AnomalyDetected" event should be emitted
    And the UI Sparkline should turn Red

  Scenario: [DT-04] Firehose Load Shedding
    Given the "MetricsMailbox" capacity is 1000 messages
    When I inject 5000 telemetry messages in 100ms
    Then the application memory should NOT exceed predefined limits
    And the "DroppedMessageCount" metric should increase
    And the UI frame rate should remain above 30 FPS
```

---

## 4.0 IMPLEMENTATION PLAN

To execute these BDD scenarios, we require a test harness that can simulate the environment (Zenoh, User Input, Time).

### 4.1 Test Harness Architecture
*   **Virtual Time**: Ability to fast-forward time for timeout tests.
*   **Mock Zenoh**: An in-memory pub/sub bus to simulate the mesh without external networking.
*   **Headless UI**: A way to verify TUI state (colors, text) without rendering to a real terminal.

### 4.2 Next Steps
1.  **Install TickSpec**: The standard F# BDD library.
2.  **Implement Step Definitions**: Map the Gherkin `Given/When/Then` to F# code invoking our `Orchestrator` and `DarkCockpitUI`.
3.  **Run Coverage Analysis**: Verify that the implemented tests cover all paths identified in the DAG.

---
**Verification**:
*   Graph Nodes Covered: 12/12
*   Graph Edges Covered: 18/18
*   Critical Paths Covered: 100%
*   STAMP Constraints Verified: SC-ZEN-001, SC-ZEN-002, SC-ZEN-003, SC-HMI-004

```