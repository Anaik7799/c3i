# Prajna Cockpit - CEPAF F# User Guide

**Version**: 3.0.0-OPERATIONAL | **Tag**: `prajna-cockpit-20251228-1515`
**STAMP**: SC-PRAJNA-001 to SC-PRAJNA-007 | **Status**: 🟢 FULLY OPERATIONAL

## Overview

Prajna Cockpit is a bio-inspired, safety-critical monitoring and control system implemented in F# as part of the CEPAF (Container-Enhanced Platform Architecture Framework) system. It provides intelligent system oversight using biological metaphors for resilience and adaptability.

**Tests**: 90+ tests, 100% pass rate | **File**: `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs`

## Architecture

```
PRAJNA COCKPIT ARCHITECTURE
================================================================

    +-----------------------------------------------------------+
    |                    DARK COCKPIT UI                         |
    |  (Minimal by default - attention only when needed)         |
    +-----------------------------------------------------------+
                              |
         +--------------------+--------------------+
         |                    |                    |
    +----v----+         +-----v-----+        +-----v-----+
    |   BIO   |         |  IMMUNE   |        |   NEURO   |
    |  LAYER  |         |   LAYER   |        |   LAYER   |
    +---------+         +-----------+        +-----------+
    | Holon   |         | Antibody  |        | Spine     |
    | Membrane|         | MARA      |        | Routing   |
    | Vitals  |         | Threats   |        | Priority  |
    +---------+         +-----------+        +-----------+
         |                    |                    |
         +--------------------+--------------------+
                              |
    +-----------------------------------------------------------+
    |                SUPPORT SYSTEMS                             |
    | Circuit Breaker | Smart Metrics | Orchestrator            |
    +-----------------------------------------------------------+
```

## Module Reference

### 1. Bio Layer (`Cepaf.Cockpit.Prajna.Bio`)

The Bio Layer models system components as living holons with membranes and vital signs.

#### Types

```fsharp
// Holon identity
type HolonId = HolonId of string

// Holon classification
type HolonType =
    | Agent of string      // OODA, ACE, Cortex, etc.
    | Worker of string     // FLAME, Oban, Broadway, Batch
    | Service of string    // Database, Cache, API
    | Container of string  // Podman containers

// Membrane permeability
type Permeability =
    | Closed      // Block all messages
    | Selective   // Allow approved message types
    | Open        // Allow all (except blocked sources)
    | Emergency   // Only emergency messages

// Holon lifecycle states
type HolonState =
    | Dormant     // Not activated
    | Awakening   // Starting up
    | Active      // Fully operational
    | Stressed    // Under load
    | Healing     // Recovering
    | Apoptotic   // Shutting down
```

#### Functions

```fsharp
// Create a new holon
let holon = Bio.createHolon (HolonId "agent-ooda") (Agent "OODA") None

// Transition holon state
let activeHolon = Bio.transition holon Bio.Active

// Check health
let healthy = Bio.isHealthy activeHolon  // true if health > 0.5 and stress < 0.8

// Membrane filtering
let config = Bio.defaultMembraneConfig
let canPass = Bio.canPass config "status" "agent-001"  // true for allowed types
```

### 2. Immune Layer (`Cepaf.Cockpit.Prajna.Immune`)

The Immune Layer detects and responds to threats using antibody-based patterns.

#### Types

```fsharp
// Threat severity
type ThreatLevel = None | Low | Medium | High | Critical

// Threat types
type ThreatType =
    | ResourceExhaustion
    | UnauthorizedAccess
    | AnomalousBehavior
    | SystemCorruption
    | NetworkIntrusion
    | ConfigurationDrift

// Response actions
type AntibodyAction =
    | Ignore     // No action
    | Log        // Record only
    | Alert      // Notify operators
    | Isolate    // Quarantine component
    | Terminate  // Stop component
    | Escalate   // Trigger emergency
```

#### Functions

```fsharp
// Assess threat from vital signs
let vitals = { HealthIndex = 0.3; StressIndex = 0.8; LastUpdate = DateTimeOffset.UtcNow }
let threatLevel = Immune.assessThreat vitals  // High

// Get recommended action
let action = Immune.recommendAction threatLevel  // Isolate

// Create threat record
let threat = Immune.createThreat
    Immune.ResourceExhaustion
    "db-pool"
    "database"
    "Connection pool exhausted"

// Create response
let response = Immune.respond threat Immune.Isolate "Automated isolation"
```

#### MARA (Modular Adaptive Response Architecture)

```fsharp
// Get strategic recommendation from threat history
let threats = [threat1; threat2; threat3]
let recommendation = Immune.MARA.recommend threats

// Result:
// { Strategy = Defensive
//   Actions = [Escalate; Isolate; Alert]
//   Confidence = 0.95
//   Rationale = "Critical threats detected: 1" }
```

### 3. Neuro Layer (`Cepaf.Cockpit.Prajna.Neuro`)

The Neuro Layer handles message routing and coordination like a nervous system.

#### Types

```fsharp
// Message priority
type Priority =
    | Background   // Lowest
    | Normal
    | High
    | Urgent
    | Emergency    // Highest

// Routing decisions
type RoutingDecision =
    | Deliver of string    // Deliver to local node
    | Forward of string    // Forward to remote node
    | Drop of string       // Drop (with reason)
    | Broadcast           // Send to all nodes
```

#### Functions

```fsharp
// Create message
let msg = Neuro.createMessage Neuro.Urgent "source" "destination" "payload"

// Route message
let localNodes = ["node-1"; "node-2"; "node-3"]
let decision = Neuro.route msg localNodes

// Handle TTL
let decremented = Neuro.decrementTTL msg
let expired = Neuro.isExpired msg  // true if TTL <= 0 or age > 5 minutes
```

### 4. Dark Cockpit (`Cepaf.Cockpit.Prajna.DarkCockpit`)

The Dark Cockpit implements the "dark cockpit" principle - minimal UI with attention only when needed.

#### Types

```fsharp
// Alert severity
type AlertSeverity = Info | Warning | Error | Critical

// Cockpit modes
type CockpitMode =
    | Dark       // Minimal - system healthy
    | Dim        // Low activity
    | Normal     // Standard operation
    | Bright     // High activity
    | Emergency  // Critical state
```

#### Functions

```fsharp
// Initialize cockpit
let state = DarkCockpit.initialState()  // Starts in Dark mode

// Add alert
let alert = {
    Id = Guid.NewGuid()
    Severity = DarkCockpit.Warning
    Title = "High Memory Usage"
    Message = "Memory usage at 85%"
    Source = "memory-monitor"
    Timestamp = DateTimeOffset.UtcNow
    Acknowledged = false
}
let newState = DarkCockpit.addAlert state alert

// Update based on health
let updated = DarkCockpit.update newState 10 8 10  // 80% healthy -> Dim mode

// Acknowledge alert
let acked = DarkCockpit.acknowledgeAlert updated alert.Id

// Filter alerts
let unackedCritical = DarkCockpit.getUnacknowledgedBySeverity state Critical
```

### 5. Circuit Breaker (`Cepaf.Cockpit.Prajna.CircuitBreaker`)

Provides graceful degradation through circuit breaker patterns.

#### States

```fsharp
type BreakerState =
    | Closed    // Normal operation
    | Open      // Blocking requests
    | HalfOpen  // Testing recovery
```

#### Functions

```fsharp
// Create breaker
let breaker = CircuitBreaker.create "database" 5 (TimeSpan.FromSeconds(30.0))

// Record failure
let updated = CircuitBreaker.recordFailure breaker  // Opens at threshold

// Record success (closes from HalfOpen)
let recovered = CircuitBreaker.recordSuccess breaker

// Check if operation allowed
let allowed = CircuitBreaker.isAllowed breaker

// Attempt recovery
let maybeHalfOpen = CircuitBreaker.attemptHalfOpen openBreaker
```

### 6. Smart Metrics (`Cepaf.Cockpit.Prajna.SmartMetrics`)

Intelligent metrics with anomaly detection.

#### Types

```fsharp
type MetricType = Counter | Gauge | Histogram | Summary
```

#### Functions

```fsharp
// Create metric
let metric = SmartMetrics.createMetric
    "cpu_usage"
    SmartMetrics.Gauge
    75.5
    (Map.ofList [("host", "app-01")])

// Detect anomalies
let history = [70.0; 72.0; 71.0; 73.0; 72.0]
let result = SmartMetrics.detectAnomaly history 95.0 2.0  // z-score threshold
// result.IsAnomaly = true, result.ZScore = high

// Moving average
let avg = SmartMetrics.movingAverage 3 [10.0; 20.0; 30.0; 40.0; 50.0]
// avg = 40.0 (average of last 3)
```

### 7. Orchestrator (`Cepaf.Cockpit.Prajna.Orchestrator`)

Command coordination with two-key-turn safety for critical operations.

#### Command Types

```fsharp
type CommandType =
    | Status            // No two-key required
    | Start             // No two-key required
    | Stop              // Two-key required
    | Restart           // Two-key required
    | Scale of int      // Two-key required
    | Configure of string
```

#### Workflow

```fsharp
// Create command
let cmd = Orchestrator.createCommand Orchestrator.Restart "operator" "indrajaal-app"
// cmd.RequiresTwoKey = true

// Arm (first key)
let armed = Orchestrator.arm cmd

// Confirm (second key required for critical ops)
let confirmed = Orchestrator.confirm armed (Some "supervisor")

// Complete
let completed = Orchestrator.complete confirmed true "Restart successful"

// Audit trail
let entry = Orchestrator.audit cmd "EXECUTED" "Command completed successfully"
```

## STAMP Compliance

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-PRAJNA-001 | Dark Cockpit default | `DarkCockpit.initialState()` starts in Dark mode |
| SC-PRAJNA-002 | Two-key-turn critical ops | `Orchestrator.requiresTwoKey` for Stop/Restart/Scale |
| SC-PRAJNA-003 | Audit trail required | `Orchestrator.audit` creates entries for all commands |
| SC-PRAJNA-005 | Graceful degradation | Circuit Breaker pattern with Open/HalfOpen/Closed |
| SC-PRAJNA-006 | Anomaly detection | `SmartMetrics.detectAnomaly` with z-score analysis |
| SC-PRAJNA-007 | Message routing with TTL | `Neuro.route` drops expired messages |

## Integration Examples

### Bio + Immune Integration

```fsharp
// Create a stressed holon
let vitals = { HealthIndex = 0.2; StressIndex = 0.85; LastUpdate = DateTimeOffset.UtcNow }
let base' = Bio.createHolon (HolonId "sick-001") (HolonType.Agent "Test") None
let holon = { base' with State = Bio.Stressed; Vitals = vitals }

// Immune system assesses threat
let threatLevel = Immune.assessThreat holon.Vitals  // High

// Get recommended action
let action = Immune.recommendAction threatLevel  // Isolate
```

### DarkCockpit + Immune Integration

```fsharp
// Start with healthy cockpit
let state = DarkCockpit.initialState()

// Critical threat detected
let threat = Immune.createThreat Immune.SystemCorruption "db" "core" "Corruption"
let alert : DarkCockpit.Alert = {
    Id = Guid.NewGuid()
    Severity = DarkCockpit.Critical
    Title = threat.Description
    Message = sprintf "Source: %s" threat.Source
    Source = "immune-system"
    Timestamp = DateTimeOffset.UtcNow
    Acknowledged = false
}

// Add to cockpit - triggers Emergency mode
let stateWithAlert = DarkCockpit.addAlert state alert
let updated = DarkCockpit.update stateWithAlert 10 10 10
// updated.Mode = Emergency (due to critical alert)
```

## Running Tests

```bash
cd lib/cepaf
dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary
```

## Test Coverage

- Bio Layer: 21 tests
- Immune Layer: 18 tests
- Neuro Layer: 8 tests
- Dark Cockpit: 12 tests
- Circuit Breaker: 11 tests
- Smart Metrics: 8 tests
- Orchestrator: 17 tests
- Integration: 3 tests
- Property Tests: 4 tests
- STAMP Compliance: 6 tests

**Total: 90+ tests with 100% pass rate**
