# Prajna Cockpit User Guide - CEPAF F#

**Version**: 1.0.0 | **Date**: 2025-12-28 | **STAMP**: SC-PRAJNA-001 to SC-PRAJNA-007

## Overview

Prajna (Sanskrit: प्रज्ञा, "wisdom") is a bio-inspired, safety-critical cockpit implementation in F# for the CEPAF framework. It provides intelligent monitoring, threat detection, and system orchestration capabilities using biological metaphors.

### Design Philosophy

Prajna follows the **Dark Cockpit** principle (NASA-STD-3000): the interface remains minimal during normal operations, drawing operator attention only when intervention is required. This reduces cognitive load and improves response to actual emergencies.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRAJNA COCKPIT                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│   │   BIO LAYER   │  │ IMMUNE LAYER  │  │ NEURO LAYER   │       │
│   │   - Holon     │  │ - Threat      │  │ - Spine       │       │
│   │   - Membrane  │  │ - Antibody    │  │ - Routing     │       │
│   │   - Lifecycle │  │ - MARA        │  │ - Priority    │       │
│   └───────────────┘  └───────────────┘  └───────────────┘       │
│                                                                  │
│   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│   │ DARK COCKPIT  │  │CIRCUIT BREAKER│  │ SMART METRICS │       │
│   │   - Modes     │  │ - States      │  │ - Anomaly     │       │
│   │   - Alerts    │  │ - Threshold   │  │ - Z-Score     │       │
│   │   - Ack       │  │ - Recovery    │  │ - Moving Avg  │       │
│   └───────────────┘  └───────────────┘  └───────────────┘       │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                     ORCHESTRATOR                         │   │
│   │    Commands • Two-Key-Turn • Audit Trail                │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Module Reference

### 1. Bio Layer (`Prajna.Bio`)

The Bio layer models system components as living organisms with membranes and lifecycles.

#### Types

```fsharp
// Membrane permeability - controls message flow
type Permeability =
    | Closed      // No messages pass
    | Selective   // Only approved messages
    | Open        // All messages pass
    | Emergency   // Only emergency messages

// Holon lifecycle states
type HolonState =
    | Dormant     // Not yet activated
    | Awakening   // Starting up
    | Active      // Fully operational
    | Stressed    // Under load
    | Healing     // Recovering
    | Apoptotic   // Shutting down (programmed death)
```

#### Functions

```fsharp
// Create a new holon instance
let holon = Bio.createHolon
    (HolonId "agent-001")
    (HolonType.Agent "OODA")
    None  // No parent

// Transition holon state
let activeHolon = Bio.transition holon HolonState.Active

// Check membrane permission
let canPass = Bio.canPass config "status" "agent-001"

// Check holon health
let healthy = Bio.isHealthy holon  // Returns bool
```

#### Example: Creating an Agent Holon

```fsharp
open Cepaf.Cockpit.Prajna

// Create the OODA controller holon
let oodaHolon =
    Bio.createHolon
        (HolonId "ooda-controller")
        (HolonType.Agent "OODA")
        None

// Configure its membrane
let membraneConfig = {
    Permeability = Selective
    AllowedTypes = Set.ofList ["command"; "status"; "alert"]
    BlockedSources = Set.empty
    RateLimit = 50
}

// Activate the holon
let activeOoda = Bio.transition oodaHolon Active
```

---

### 2. Immune Layer (`Prajna.Immune`)

The Immune layer provides threat detection and automated response capabilities.

#### Types

```fsharp
// Threat severity levels
type ThreatLevel =
    | None | Low | Medium | High | Critical

// Types of threats
type ThreatType =
    | ResourceExhaustion
    | UnauthorizedAccess
    | AnomalousBehavior
    | SystemCorruption
    | NetworkIntrusion
    | ConfigurationDrift

// Response actions
type AntibodyAction =
    | Ignore | Log | Alert | Isolate | Terminate | Escalate
```

#### Functions

```fsharp
// Assess threat level from vitals
let threat = Immune.assessThreat vitals  // Returns ThreatLevel

// Get recommended action
let action = Immune.recommendAction High  // Returns Isolate

// Create a threat record
let threat = Immune.createThreat
    ResourceExhaustion
    "worker-01"
    "database"
    "Memory exhaustion detected"

// Create response
let response = Immune.respond threat Isolate "Automated isolation"
```

#### Example: Threat Detection Pipeline

```fsharp
open Cepaf.Cockpit.Prajna.Immune

// Monitor system vitals
let vitals = { HealthIndex = 0.25; StressIndex = 0.85; ... }

// Assess threat
let threatLevel = assessThreat vitals  // Returns High

// Get recommended action
let action = recommendAction threatLevel  // Returns Isolate

// Create threat record
let threat = createThreat
    ResourceExhaustion
    "db-connection-pool"
    "indrajaal-db"
    "Connection pool exhausted (85% stress)"

// Log response
let response = respond threat action "Automated immune response"
```

#### MARA - Modular Adaptive Response Architecture

```fsharp
open Cepaf.Cockpit.Prajna.Immune.MARA

// Analyze threat history
let threats = [threat1; threat2; threat3]
let recommendation = MARA.recommend threats

// recommendation contains:
// - Strategy: Defensive/Offensive/Adaptive/Passive
// - Actions: List of recommended actions
// - Confidence: 0.0 to 1.0
// - Rationale: Human-readable explanation
```

---

### 3. Neuro Layer (`Prajna.Neuro`)

The Neuro layer handles message routing and coordination between components.

#### Types

```fsharp
// Message priority
type Priority =
    | Background | Normal | High | Urgent | Emergency

// Routing decisions
type RoutingDecision =
    | Deliver of string   // Deliver to local node
    | Forward of string   // Forward to remote node
    | Drop of string      // Drop with reason
    | Broadcast           // Send to all nodes
```

#### Functions

```fsharp
// Create a spine message
let msg = Neuro.createMessage
    Urgent
    "cortex-agent"
    "sentinel-guardian"
    """{"action": "health_check"}"""

// Route the message
let localNodes = ["sentinel-guardian"; "ooda-controller"]
let decision = Neuro.route msg localNodes  // Deliver "sentinel-guardian"

// Decrement TTL for forwarding
let forwardedMsg = Neuro.decrementTTL msg

// Check if expired
let expired = Neuro.isExpired msg
```

#### Example: Message Routing

```fsharp
open Cepaf.Cockpit.Prajna.Neuro

// Emergency broadcast to all agents
let emergencyMsg = createMessage
    Emergency
    "alarm-processor"
    "*"  // Broadcast destination
    """{"alert": "critical", "code": "BREACH-001"}"""

// Route message
let decision = route emergencyMsg localNodes
// Returns: Broadcast

// Normal message to specific agent
let statusMsg = createMessage
    Normal
    "dashboard"
    "kpi-agent"
    """{"request": "metrics"}"""

let decision2 = route statusMsg ["kpi-agent"; "cortex-agent"]
// Returns: Deliver "kpi-agent"
```

---

### 4. Dark Cockpit (`Prajna.DarkCockpit`)

The Dark Cockpit module implements attention-based UI that minimizes distraction during normal operations.

#### Types

```fsharp
// Cockpit display modes
type CockpitMode =
    | Dark      // Minimal - only critical alerts
    | Dim       // Low activity display
    | Normal    // Standard operation
    | Bright    // Full visibility
    | Emergency // All alerts prominent

// Alert severity
type AlertSeverity =
    | Info | Warning | Error | Critical
```

#### Functions

```fsharp
// Initialize cockpit
let state = DarkCockpit.initialState()  // Starts in Dark mode

// Add an alert
let alert = {
    Id = Guid.NewGuid()
    Severity = Warning
    Title = "Memory Usage High"
    Message = "System memory at 85%"
    Source = "cortex-sensor"
    Timestamp = DateTimeOffset.UtcNow
    Acknowledged = false
}
let newState = DarkCockpit.addAlert state alert

// Update cockpit based on system health
let updatedState = DarkCockpit.update state
    activeHolons=7
    healthyCount=6
    totalCount=7

// Acknowledge alert
let acked = DarkCockpit.acknowledgeAlert state alertId

// Get unacknowledged critical alerts
let criticals = DarkCockpit.getUnacknowledgedBySeverity state Critical
```

#### Example: Mode Transitions

```fsharp
open Cepaf.Cockpit.Prajna.DarkCockpit

// Start in Dark mode (all systems normal)
let cockpit = initialState()

// System degrades - mode changes automatically
let degraded = update cockpit 7 4 7  // 4 of 7 healthy
// Mode changes to: Normal

// Critical alert arrives
let criticalAlert = {
    Id = Guid.NewGuid()
    Severity = Critical
    Title = "Database Connection Lost"
    Message = "PostgreSQL connection pool exhausted"
    Source = "db-monitor"
    Timestamp = DateTimeOffset.UtcNow
    Acknowledged = false
}
let emergency = addAlert degraded criticalAlert
// Mode changes to: Emergency (automatic)
```

---

### 5. Circuit Breaker (`Prajna.CircuitBreaker`)

Implements the circuit breaker pattern for fault tolerance.

#### Types

```fsharp
type BreakerState =
    | Closed    // Normal operation - requests allowed
    | Open      // Tripped - requests blocked
    | HalfOpen  // Testing recovery - limited requests
```

#### Functions

```fsharp
// Create a circuit breaker
let breaker = CircuitBreaker.create
    "database-pool"
    threshold=5           // Open after 5 failures
    resetTimeout=TimeSpan.FromSeconds(30.0)

// Record outcomes
let afterFailure = CircuitBreaker.recordFailure breaker
let afterSuccess = CircuitBreaker.recordSuccess breaker

// Check if operation allowed
let allowed = CircuitBreaker.isAllowed breaker

// Test if ready for recovery attempt
let shouldReset = CircuitBreaker.shouldAttemptReset breaker
let halfOpen = CircuitBreaker.attemptHalfOpen breaker
```

#### Example: Protecting Database Calls

```fsharp
open Cepaf.Cockpit.Prajna.CircuitBreaker

// Create breaker for database operations
let dbBreaker = create "db-operations" 3 (TimeSpan.FromSeconds(10.0))

// Before making a call
let executeWithBreaker breaker operation =
    if isAllowed breaker then
        try
            let result = operation()
            let updatedBreaker = recordSuccess breaker
            Ok (result, updatedBreaker)
        with ex ->
            let updatedBreaker = recordFailure breaker
            Error (ex.Message, updatedBreaker)
    else
        // Check if should attempt reset
        let maybeHalfOpen = attemptHalfOpen breaker
        if maybeHalfOpen.State = HalfOpen then
            // Try one request
            try
                let result = operation()
                let closed = recordSuccess maybeHalfOpen
                Ok (result, closed)
            with ex ->
                let stillOpen = recordFailure maybeHalfOpen
                Error (ex.Message, stillOpen)
        else
            Error ("Circuit breaker open", breaker)
```

---

### 6. Smart Metrics (`Prajna.SmartMetrics`)

Provides intelligent metric collection and anomaly detection.

#### Types

```fsharp
type MetricType =
    | Counter    // Monotonically increasing
    | Gauge      // Point-in-time value
    | Histogram  // Distribution of values
    | Summary    // Statistical summary
```

#### Functions

```fsharp
// Create a metric
let cpuMetric = SmartMetrics.createMetric
    "cpu_usage"
    Gauge
    75.5
    (Map.ofList [("host", "app-01")])

// Detect anomalies using z-score
let history = [72.0; 74.0; 73.0; 75.0; 74.0]
let current = 95.0  // Spike!
let result = SmartMetrics.detectAnomaly history current 2.0
// result.IsAnomaly = true
// result.ZScore = ~3.5

// Calculate moving average
let avg = SmartMetrics.movingAverage 5 values
```

#### Example: Anomaly Detection Pipeline

```fsharp
open Cepaf.Cockpit.Prajna.SmartMetrics

// Maintain metric history
let mutable cpuHistory = [72.0; 74.0; 73.0; 75.0; 74.0; 73.5; 74.2]

// On new metric
let onNewCpuReading (current: float) =
    let anomaly = detectAnomaly cpuHistory current 2.5

    if anomaly.IsAnomaly then
        // Generate alert
        printfn "ANOMALY: CPU at %.1f%% (z-score: %.2f)"
            current anomaly.ZScore

    // Update history (keep last 100)
    cpuHistory <- (current :: cpuHistory) |> List.take 100

// Example: Normal reading
onNewCpuReading 75.0  // No alert

// Example: Anomalous reading
onNewCpuReading 98.0  // ANOMALY: CPU at 98.0% (z-score: 3.87)
```

---

### 7. Orchestrator (`Prajna.Orchestrator`)

Coordinates commands with safety controls and audit trails.

#### Types

```fsharp
type CommandType =
    | Status
    | Start
    | Stop
    | Restart
    | Scale of int
    | Configure of string

type CommandStatus =
    | Pending
    | Armed
    | Executing
    | Completed
    | Failed of string
```

#### Two-Key-Turn Safety Protocol

Critical operations require two authorized confirmations:

```fsharp
// Commands requiring two-key-turn:
Stop -> true
Restart -> true
Scale _ -> true
Status -> false
Start -> false
Configure _ -> false
```

#### Functions

```fsharp
// Create command
let cmd = Orchestrator.createCommand Stop "admin" "indrajaal-app"

// Arm (first key)
let armed = Orchestrator.arm cmd

// Confirm with second key
let confirmed = Orchestrator.confirm armed (Some "supervisor")

// Complete
let completed = Orchestrator.complete confirmed true "Stopped successfully"

// Generate audit entry
let audit = Orchestrator.audit cmd "STOP_INITIATED" "Emergency shutdown"
```

#### Example: Safe Restart Procedure

```fsharp
open Cepaf.Cockpit.Prajna.Orchestrator

// Initiate restart (critical operation)
let restartCmd = createCommand Restart "operator-01" "indrajaal-app"
// restartCmd.RequiresTwoKey = true

// Step 1: First operator arms the command
let armed = arm restartCmd
let audit1 = audit armed "ARMED" "First key provided by operator-01"

// Step 2: Second operator confirms
let confirmed = confirm armed (Some "supervisor-01")
let audit2 = audit confirmed "CONFIRMED" "Second key provided by supervisor-01"

// Step 3: Execute and complete
let result = // ... perform actual restart
let completed = complete confirmed true "Restart completed in 5.2s"
let audit3 = audit completed "COMPLETED" "Service restored"
```

---

## Integration with Elixir Prajna

The F# Prajna modules complement the Elixir implementation:

| F# Module | Elixir Module | Communication |
|-----------|---------------|---------------|
| `Prajna.Bio` | `Indrajaal.Cockpit.Prajna.Bio.*` | Zenoh bridge |
| `Prajna.Immune` | `Indrajaal.Cockpit.Prajna.Immune.*` | Zenoh bridge |
| `Prajna.DarkCockpit` | `Indrajaal.Cockpit.Prajna.DarkCockpit` | Zenoh bridge |
| `Prajna.Orchestrator` | `Indrajaal.Cockpit.Prajna.Orchestrator` | Zenoh bridge |

### Zenoh Key Expressions

```
indrajaal/prajna/bio/{holon_id}/state      # Holon state updates
indrajaal/prajna/immune/threat/{id}        # Threat notifications
indrajaal/prajna/neuro/spine/{priority}    # Message routing
indrajaal/prajna/cockpit/mode              # Cockpit mode changes
indrajaal/prajna/command/{id}/status       # Command status updates
```

---

## Testing

### Running F# Prajna Tests

```bash
cd lib/cepaf

# Run all tests
dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary

# Run specific Prajna tests
dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- \
    --filter "Prajna"
```

### Test Coverage Requirements

Per SC-PRAJNA-003, all modules require 100% test coverage:

- Bio Layer: Holon creation, state transitions, membrane filtering
- Immune Layer: Threat assessment, MARA recommendations
- Neuro Layer: Message routing, TTL handling
- Dark Cockpit: Mode transitions, alert management
- Circuit Breaker: State machine, recovery attempts
- Smart Metrics: Anomaly detection, moving averages
- Orchestrator: Two-key-turn, audit trail

---

## STAMP Compliance

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-PRAJNA-001 | Dark Cockpit default | `initialState()` returns Dark mode |
| SC-PRAJNA-002 | Two-key-turn for critical ops | `requiresTwoKey` checks command type |
| SC-PRAJNA-003 | Audit trail required | `audit` function on all commands |
| SC-PRAJNA-004 | Bio-inspired architecture | Holon, Membrane, Immune modules |
| SC-PRAJNA-005 | Graceful degradation | Circuit breaker pattern |
| SC-PRAJNA-006 | Anomaly detection | Z-score based detection |
| SC-PRAJNA-007 | Message routing with TTL | Spine message with TTL expiry |

---

## Quick Reference

### Common Operations

```fsharp
open Cepaf.Cockpit.Prajna

// Create holon
let h = Bio.createHolon id type parent

// Check threat
let level = Immune.assessThreat vitals

// Route message
let decision = Neuro.route msg nodes

// Update cockpit
let state = DarkCockpit.update state active healthy total

// Check circuit breaker
let allowed = CircuitBreaker.isAllowed breaker

// Detect anomaly
let result = SmartMetrics.detectAnomaly history current threshold

// Execute command safely
let cmd = Orchestrator.createCommand cmdType user target
let armed = Orchestrator.arm cmd
let confirmed = Orchestrator.confirm armed secondKey
```

### Type Imports

```fsharp
open Cepaf.Cockpit.Prajna
open Cepaf.Cockpit.Prajna.Bio
open Cepaf.Cockpit.Prajna.Immune
open Cepaf.Cockpit.Prajna.Neuro
open Cepaf.Cockpit.Prajna.DarkCockpit
open Cepaf.Cockpit.Prajna.CircuitBreaker
open Cepaf.Cockpit.Prajna.SmartMetrics
open Cepaf.Cockpit.Prajna.Orchestrator
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-28
**Author**: CEPAF F# Team
**STAMP Compliance**: Verified
