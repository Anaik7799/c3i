# Split-Brain Resolution (FM-006)

## Overview

The SplitBrainResolver provides external witness-based arbitration for network partition resolution in the Zenoh cluster. This implements FM-006 requirements for split-brain detection and recovery.

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-CONS-003 | External witness arbitration required for partition resolution | CRITICAL |
| SC-CONS-005 | Majority vs minority partition determination mandatory | HIGH |
| SC-CONS-006 | Automatic freeze/recovery protocol for minority partition | CRITICAL |

## Architecture

```
┌─────────────────┐
│  Partition A    │──┐
│  (Node 1, 2)    │  │
└─────────────────┘  │     ┌──────────────────┐
                      ├────▶│ External Witness │
┌─────────────────┐  │     │  (HTTP API)      │
│  Partition B    │──┘     └──────────────────┘
│  (Node 3)       │              │
└─────────────────┘              │
         │                       │
         └──Decision: Majority/Minority
```

### Components

1. **WitnessConfig**: External witness configuration
2. **PartitionResolution**: Arbitration decision (Majority/Minority/Unreachable/TieBreaker)
3. **ArbitrationRequest/Response**: JSON protocol for witness communication
4. **SplitBrainResolver**: Main resolver class with HTTP client
5. **ConsensusIntegration**: Integration module for RaftNode

## Usage

### 1. Basic Setup

```fsharp
open Cepaf.Zenoh.Cluster

// Configure witness
let witnessConfig =
    WitnessConfig.defaultConfig()
    |> WitnessConfig.forEndpoint "http://witness-node:8080"

// Create resolver
let resolver = new SplitBrainResolver("node-1", witnessConfig)

// Start health checking
resolver.Start()
```

### 2. Detect and Resolve Split-Brain

```fsharp
// Detect partition
let visibleNodes = ["node-1"; "node-2"]
let totalClusterSize = 5

if resolver.DetectSplitBrain(visibleNodes, totalClusterSize) then
    // Request arbitration from witness
    let! resolution =
        resolver.RequestArbitrationAsync(
            term = 42L,
            partitionNodes = visibleNodes,
            totalClusterSize = totalClusterSize,
            currentLeader = Some "node-1"
        )

    // Execute recovery action
    let action = resolver.ExecuteRecovery(resolution)

    match action with
    | RecoveryAction.ContinueOperations ->
        printfn "We are in majority - continue operations"
    | RecoveryAction.FreezeWrites ->
        printfn "We are in minority - freezing writes"
    | RecoveryAction.EnterSafeMode ->
        printfn "Witness unreachable - entering safe mode"
    | RecoveryAction.StepDownLeader ->
        printfn "Tie-breaker: stepping down from leadership"
    | RecoveryAction.ManualIntervention reason ->
        printfn "Manual intervention required: %s" reason
```

### 3. Integration with Raft Consensus

```fsharp
open Cepaf.Zenoh.Cluster.ConsensusIntegration

// Create Raft node
let raftNode = new RaftNode<string>(
    nodeId = "node-1",
    clusterNodes = ["node-1"; "node-2"; "node-3"]
)

// Create resolver
let resolver = new SplitBrainResolver("node-1", witnessConfig)

// Attach resolver to Raft node
attachResolver raftNode resolver

// Start both
raftNode.Start()
resolver.Start()

// Check if safe for writes
if isSafeForWrites resolver then
    // Accept write operations
    let! result = raftNode.ProposeAsync("command-1")
    ()
```

### 4. Monitor Partition State

```fsharp
// Get current metrics
let metrics = resolver.GetMetrics()

printfn "Partition Status:"
printfn "  Is Partitioned: %b" metrics.IsPartitioned
printfn "  Operations Frozen: %b" metrics.OperationsFrozen
printfn "  Arbitration Attempts: %d" metrics.ArbitrationAttempts
printfn "  Witness Healthy: %b" metrics.WitnessHealthy
printfn "  Consecutive Failures: %d" metrics.ConsecutiveFailures

// Check if frozen
if resolver.AreOperationsFrozen then
    printfn "Operations are currently frozen - minority partition"
```

### 5. Heal Partition (Manual Recovery)

```fsharp
// When network partition is resolved
resolver.HealPartition()

printfn "Partition healed - operations unfrozen"
```

## Witness Server Implementation

The external witness must implement the following HTTP API:

### Health Check Endpoint

```http
GET /health
```

**Response:**
- `200 OK` - Witness is healthy
- `503 Service Unavailable` - Witness is unhealthy

### Arbitration Endpoint

```http
POST /arbitrate
Content-Type: application/json
```

**Request Body:**
```json
{
  "requestingNodeId": "node-1",
  "term": 42,
  "partitionNodes": ["node-1", "node-2"],
  "totalClusterSize": 5,
  "currentLeader": "node-1",
  "detectedAt": "2026-01-15T10:30:00Z",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response Body:**
```json
{
  "success": true,
  "isMajority": true,
  "requestingPartitionSize": 2,
  "otherPartitionSize": 3,
  "witnessTotalNodes": 5,
  "reason": "Partition has 2 nodes, quorum requires 3",
  "arbitratedAt": "2026-01-15T10:30:05Z",
  "requestId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Example Witness Server (Python/Flask)

```python
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

# Track known partitions
partitions = {}

@app.route('/health', methods=['GET'])
def health():
    return '', 200

@app.route('/arbitrate', methods=['POST'])
def arbitrate():
    req = request.get_json()

    node_id = req['requestingNodeId']
    partition_nodes = req['partitionNodes']
    total_size = req['totalClusterSize']
    request_id = req['requestId']

    # Store partition info
    partitions[node_id] = {
        'nodes': partition_nodes,
        'size': len(partition_nodes),
        'timestamp': datetime.utcnow()
    }

    # Calculate quorum
    quorum = (total_size // 2) + 1
    partition_size = len(partition_nodes)

    # Determine majority
    is_majority = partition_size >= quorum

    # Calculate other partition size (approximate)
    other_size = total_size - partition_size

    response = {
        'success': True,
        'isMajority': is_majority,
        'requestingPartitionSize': partition_size,
        'otherPartitionSize': other_size,
        'witnessTotalNodes': total_size,
        'reason': f'Partition has {partition_size} nodes, quorum requires {quorum}',
        'arbitratedAt': datetime.utcnow().isoformat() + 'Z',
        'requestId': request_id
    }

    return jsonify(response), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

## Configuration Options

```fsharp
type WitnessConfig = {
    Endpoint: string                  // Default: "http://witness:8080"
    TimeoutMs: int                    // Default: 5000ms (SC-CONS-003)
    RetryCount: int                   // Default: 3
    RetryDelayMs: int                 // Default: 1000ms
    HealthCheckIntervalMs: int        // Default: 10000ms
    EnableTls: bool                   // Default: false
    ApiKey: string option             // Default: None
}
```

### With TLS and Authentication

```fsharp
let secureConfig =
    WitnessConfig.defaultConfig()
    |> WitnessConfig.forEndpoint "https://witness-node:8443"
    |> WitnessConfig.withTls "my-secret-api-key"

let resolver = new SplitBrainResolver("node-1", secureConfig)
```

## Recovery Actions

| Action | Description | Use Case |
|--------|-------------|----------|
| `ContinueOperations` | Continue normal operations | Majority partition |
| `FreezeWrites` | Freeze all write operations | Minority partition |
| `EnterSafeMode` | Conservative mode (no writes) | Witness unreachable |
| `StepDownLeader` | Step down from leadership | Tie-breaker decision |
| `ManualIntervention` | Requires operator action | Critical failure |

## Error Handling

```fsharp
// Witness unreachable - enters safe mode automatically
if resolver.IsWitnessHealthy then
    // Witness is healthy - can request arbitration
    let! resolution = resolver.RequestArbitrationAsync(...)
    ()
else
    // Witness is unhealthy - enter safe mode
    resolver.FreezeOperations("Witness unreachable")
```

## Integration Points

### ZenohConsensus.fs

The resolver integrates with `RaftNode<'T>` via event subscription:

```fsharp
raftNode.OnEvent(fun event ->
    match event with
    | ConsensusEvent.BecameFollower (term, leader) when leader.IsNone ->
        // Lost leader - check for partition
        if resolver.DetectSplitBrain(...) then
            // Request arbitration
            ()
    | _ -> ()
)
```

### ZenohQuorum.fs

Quorum voting works in conjunction with split-brain resolution:

```fsharp
// Standard quorum voting
let quorumResult = QuorumCalculator.calculate votes totalNodes

// If quorum fails, check for split-brain
if not quorumResult.IsDecided then
    let visibleNodes = votes |> List.map (fun v -> v.NodeId)
    if resolver.DetectSplitBrain(visibleNodes, totalNodes) then
        // Request arbitration
        ()
```

## Telemetry

All partition events are logged with telemetry:

```fsharp
// Metrics published to Zenoh
let metrics = resolver.GetMetrics()

:telemetry.execute([:zenoh, :partition, :detected], %{
  is_partitioned: metrics.IsPartitioned,
  operations_frozen: metrics.OperationsFrozen,
  arbitration_attempts: metrics.ArbitrationAttempts,
  witness_healthy: metrics.WitnessHealthy
}, %{node_id: nodeId})
```

## Testing

### Unit Tests (FsCheck)

```fsharp
open FsCheck
open Expecto

[<Tests>]
let tests =
    testList "SplitBrainResolver" [
        testProperty "DetectSplitBrain: visible < quorum => true" <| fun (PositiveInt total) ->
            let resolver = new SplitBrainResolver("test", WitnessConfig.defaultConfig())
            let quorum = (total / 2) + 1
            let visible = quorum - 1
            let visibleNodes = List.init visible (sprintf "node-%d")

            resolver.DetectSplitBrain(visibleNodes, total) = true

        testProperty "DetectSplitBrain: visible >= quorum => false" <| fun (PositiveInt total) ->
            let resolver = new SplitBrainResolver("test", WitnessConfig.defaultConfig())
            let quorum = (total / 2) + 1
            let visible = quorum
            let visibleNodes = List.init visible (sprintf "node-%d")

            resolver.DetectSplitBrain(visibleNodes, total) = false
    ]
```

### Integration Tests

See `scripts/testing/zenoh_splitbrain_test.exs` for Elixir integration tests.

## 5-Order Effects

| Order | Effect | Time Scale |
|-------|--------|------------|
| 1st | Split-brain detected, arbitration requested | Immediate |
| 2nd | Witness responds, partition classified | 1-5 seconds |
| 3rd | Recovery action executed (freeze/continue) | Seconds |
| 4th | Cluster state stabilized, operations resume | Minutes |
| 5th | Partition healed, normal operations restored | Minutes-Hours |

## Related Documents

- ZenohConsensus.fs - Raft-lite consensus implementation
- ZenohQuorum.fs - Quorum voting and 2oo3 consensus
- CLAUDE.md - System specification (SC-CONS-* constraints)
- docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md - Cluster architecture

## Change History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0.0 | 2026-01-15 | Claude Opus 4.5 | Initial implementation (FM-006) |
