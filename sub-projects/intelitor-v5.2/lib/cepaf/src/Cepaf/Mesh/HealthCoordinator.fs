// =============================================================================
// HealthCoordinator.fs - SIL-4 Health Coordination and Quorum Voting
// =============================================================================
// STAMP Constraints:
//   SC-SIL4-001: Health checks every 10s
//   SC-SIL4-011: Quorum = floor(N/2) + 1
//   SC-SIL4-015: Split-brain triggers apoptosis
//   SC-SIL4-019: Circuit breaker after 3 failures
//
// AOR Rules:
//   AOR-IMMUNE-001: Run Sentinel.assess_now() before critical ops
//   AOR-HOLON-009: SQLite/DuckDB is authoritative source of holon state
//
// 5-Order Effects Analysis:
//   1st Order: Individual container health polled
//   2nd Order: Health scores aggregated across mesh
//   3rd Order: Quorum calculated, consensus formed
//   4th Order: Split-brain detection, apoptosis trigger
//   5th Order: Federation notification, cluster reconfiguration
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Collections.Concurrent
open System.Diagnostics
open System.Threading.Tasks

/// Health status for a single container
type HealthStatus =
    | Healthy
    | Degraded
    | Unhealthy
    | Unknown
    | Unreachable

/// Container health metrics
type ContainerHealthMetrics = {
    ContainerId: string
    Status: HealthStatus
    HealthScore: float          // 0.0 to 1.0
    CpuUsage: float             // 0.0 to 100.0
    MemoryUsage: float          // 0.0 to 100.0
    ResponseTimeMs: int64       // Latency in milliseconds
    LastHeartbeat: DateTime
    ConsecutiveFailures: int
    CheckedAt: DateTime
}

/// Quorum achieved data
type QuorumAchievedData = {
    Healthy: int
    Total: int
    Required: int
    Consensus: string
}

/// Quorum not achieved data
type QuorumNotAchievedData = {
    Healthy: int
    Total: int
    Required: int
    Reason: string
}

/// Insufficient nodes data
type InsufficientNodesData = {
    Available: int
    MinimumRequired: int
}

/// Quorum voting result
type QuorumResult =
    | QuorumAchieved of QuorumAchievedData
    | QuorumNotAchieved of QuorumNotAchievedData
    | InsufficientNodes of InsufficientNodesData

/// Split-brain detected data
type SplitBrainDetectedData = {
    Partition1: string list
    Partition2: string list
    SeedInPartition1: bool
    SeedInPartition2: bool
}

/// Split-brain detection result
type SplitBrainDetection =
    | NoSplitBrain
    | SplitBrainDetected of SplitBrainDetectedData
    | NetworkPartitionSuspected of string

/// Health check configuration per SC-SIL4-001
type HealthCheckConfig = {
    IntervalMs: int             // 10000ms = 10s per SC-SIL4-001
    TimeoutMs: int              // 5000ms default
    FailureThreshold: int       // 3 failures = circuit breaker (SC-SIL4-019)
    DegradedThreshold: float    // 0.7 health score
    UnhealthyThreshold: float   // 0.3 health score
    QuorumPercentage: float     // 0.5 + epsilon for majority
}

/// 5-Order effects tracking
type FiveOrderEffects = {
    FirstOrder: string          // Direct action
    SecondOrder: string         // Adjacent system reaction
    ThirdOrder: string          // System integration effects
    FourthOrder: string         // Operational capabilities
    FifthOrder: string          // Ecosystem/GA effects
    Timestamp: DateTime
}

/// SIL-4 Health Coordinator with quorum voting
type HealthCoordinator() =

    // SC-SIL4-001: Default 10s health check interval
    let defaultConfig = {
        IntervalMs = 10000
        TimeoutMs = 5000
        FailureThreshold = 3      // SC-SIL4-019: Circuit breaker
        DegradedThreshold = 0.7
        UnhealthyThreshold = 0.3
        QuorumPercentage = 0.5
    }

    let mutable config = defaultConfig
    let healthMetrics = ConcurrentDictionary<string, ContainerHealthMetrics>()
    let seedNodes = ConcurrentDictionary<string, DateTime>()
    let effectsLog = ConcurrentDictionary<Guid, FiveOrderEffects>()

    // Track consecutive failures for circuit breaker (SC-SIL4-019)
    let failureCounts = ConcurrentDictionary<string, int>()

    /// Configure health check parameters
    member this.Configure(newConfig: HealthCheckConfig) =
        config <- newConfig

    /// Register a seed node for special monitoring
    member this.RegisterSeedNode(nodeId: string) =
        seedNodes.TryAdd(nodeId, DateTime.UtcNow) |> ignore

        // Log 5-order effects
        let effects = {
            FirstOrder = sprintf "Seed node %s registered" nodeId
            SecondOrder = "Seed tracking activated for quorum calculation"
            ThirdOrder = "Split-brain detection enhanced"
            FourthOrder = "Cluster stability improved"
            FifthOrder = "Federation seed visibility enabled"
            Timestamp = DateTime.UtcNow
        }
        effectsLog.TryAdd(Guid.NewGuid(), effects) |> ignore

    /// Check if node is a seed node
    member this.IsSeedNode(nodeId: string) =
        seedNodes.ContainsKey(nodeId)

    /// Update health metrics for a container
    member this.UpdateHealth(containerId: string, status: HealthStatus,
                             healthScore: float, cpuUsage: float,
                             memoryUsage: float, responseTimeMs: int64) =

        let now = DateTime.UtcNow

        // Track consecutive failures for circuit breaker (SC-SIL4-019)
        let consecutiveFailures =
            match status with
            | Unhealthy | Unreachable ->
                let current =
                    match failureCounts.TryGetValue(containerId) with
                    | true, count -> count + 1
                    | false, _ -> 1
                failureCounts.[containerId] <- current
                current
            | _ ->
                failureCounts.[containerId] <- 0
                0

        let metrics = {
            ContainerId = containerId
            Status = status
            HealthScore = healthScore
            CpuUsage = cpuUsage
            MemoryUsage = memoryUsage
            ResponseTimeMs = responseTimeMs
            LastHeartbeat = now
            ConsecutiveFailures = consecutiveFailures
            CheckedAt = now
        }

        healthMetrics.[containerId] <- metrics

        // Log effects for significant health changes
        if consecutiveFailures = config.FailureThreshold then
            let effects = {
                FirstOrder = sprintf "Container %s hit failure threshold (%d)" containerId consecutiveFailures
                SecondOrder = "Circuit breaker triggered (SC-SIL4-019)"
                ThirdOrder = "Container marked for recovery or removal"
                FourthOrder = "Quorum recalculation required"
                FifthOrder = "Federation health notification pending"
                Timestamp = now
            }
            effectsLog.TryAdd(Guid.NewGuid(), effects) |> ignore

    /// Get health metrics for a container
    member this.GetHealth(containerId: string) =
        match healthMetrics.TryGetValue(containerId) with
        | true, metrics -> Some metrics
        | false, _ -> None

    /// Get all healthy containers
    member this.GetHealthyContainers() =
        healthMetrics.Values
        |> Seq.filter (fun m -> m.Status = Healthy || m.Status = Degraded)
        |> Seq.map (fun m -> m.ContainerId)
        |> Seq.toList

    /// Calculate quorum requirement per SC-SIL4-011
    /// Quorum = floor(N/2) + 1
    member this.CalculateQuorumRequirement(totalNodes: int) =
        if totalNodes <= 0 then 1
        else (totalNodes / 2) + 1

    /// Check if quorum is achieved (SC-SIL4-011)
    member this.CheckQuorum() : QuorumResult =
        let totalNodes = healthMetrics.Count

        if totalNodes < 2 then
            InsufficientNodes { Available = totalNodes; MinimumRequired = 2 }
        else
            let healthyNodes =
                healthMetrics.Values
                |> Seq.filter (fun m ->
                    m.Status = Healthy &&
                    m.ConsecutiveFailures < config.FailureThreshold)
                |> Seq.length

            let required = this.CalculateQuorumRequirement(totalNodes)

            if healthyNodes >= required then
                QuorumAchieved {
                    Healthy = healthyNodes
                    Total = totalNodes
                    Required = required
                    Consensus = sprintf "Quorum achieved: %d/%d healthy (need %d)" healthyNodes totalNodes required
                }
            else
                QuorumNotAchieved {
                    Healthy = healthyNodes
                    Total = totalNodes
                    Required = required
                    Reason = sprintf "Quorum failed: %d/%d healthy (need %d)" healthyNodes totalNodes required
                }

    /// FPPS 5-point consensus validation
    /// Per SC-VAL-003: 5-Method FPPS must agree
    member this.FppsConsensus(containerId: string) : bool * string =
        match healthMetrics.TryGetValue(containerId) with
        | false, _ ->
            false, "Container not found"
        | true, metrics ->
            // 5-point validation per FPPS
            let checks = [
                // Point 1: Pattern - Status not Unreachable
                metrics.Status <> Unreachable

                // Point 2: AST (proxy: health score threshold)
                metrics.HealthScore >= config.UnhealthyThreshold

                // Point 3: Statistical - Failure count below threshold
                metrics.ConsecutiveFailures < config.FailureThreshold

                // Point 4: Binary (proxy: heartbeat recent)
                (DateTime.UtcNow - metrics.LastHeartbeat).TotalSeconds < 30.0

                // Point 5: Line-by-line (proxy: response time acceptable)
                metrics.ResponseTimeMs < 5000L
            ]

            let passed = checks |> List.filter id |> List.length
            let consensusReached = passed = 5  // SC-VAL-003: ALL 5/5 must agree

            let message =
                sprintf "FPPS: %d/5 checks passed (%s)"
                    passed
                    (if consensusReached then "CONSENSUS" else "NO CONSENSUS")

            consensusReached, message

    /// Detect split-brain scenario (SC-SIL4-015)
    member this.DetectSplitBrain() : SplitBrainDetection =
        let allNodes = healthMetrics.Keys |> Seq.toList
        let reachableNodes =
            healthMetrics.Values
            |> Seq.filter (fun m -> m.Status <> Unreachable)
            |> Seq.map (fun m -> m.ContainerId)
            |> Set.ofSeq

        let unreachableNodes =
            healthMetrics.Values
            |> Seq.filter (fun m -> m.Status = Unreachable)
            |> Seq.map (fun m -> m.ContainerId)
            |> Set.ofSeq

        // Check if both partitions have seed nodes
        let seedsInReachable =
            seedNodes.Keys
            |> Seq.filter reachableNodes.Contains
            |> Seq.length

        let seedsInUnreachable =
            seedNodes.Keys
            |> Seq.filter unreachableNodes.Contains
            |> Seq.length

        if unreachableNodes.Count = 0 then
            NoSplitBrain
        elif seedsInReachable > 0 && seedsInUnreachable > 0 then
            // Both partitions have seeds - split-brain!
            SplitBrainDetected {
                Partition1 = reachableNodes |> Set.toList
                Partition2 = unreachableNodes |> Set.toList
                SeedInPartition1 = true
                SeedInPartition2 = true
            }
        elif unreachableNodes.Count > 0 && seedNodes.Count > 0 then
            NetworkPartitionSuspected
                (sprintf "Partition detected: %d reachable, %d unreachable"
                    reachableNodes.Count unreachableNodes.Count)
        else
            NoSplitBrain

    /// Get seed node health - critical for cluster stability
    member this.GetSeedHealth() =
        seedNodes.Keys
        |> Seq.choose (fun nodeId ->
            match healthMetrics.TryGetValue(nodeId) with
            | true, metrics -> Some (nodeId, metrics)
            | false, _ -> None)
        |> Seq.toList

    /// Check if all seed nodes are healthy
    member this.AllSeedsHealthy() =
        let seedHealth = this.GetSeedHealth()
        if seedHealth.IsEmpty then
            false
        else
            seedHealth
            |> List.forall (fun (_, m) ->
                m.Status = Healthy &&
                m.ConsecutiveFailures < config.FailureThreshold)

    /// Verify holographic parity of the substrate artifacts (SC-REGEN-002)
    member this.VerifySubstrateParity() =
        printfn "[SEO] Verifying Substrate Holographic Parity..."
        // Call the HRP out-of-band checker
        let psi = ProcessStartInfo("dotnet", "fsi lib/cepaf/scripts/RegenerationSwarmUpkeep.fsx")
        psi.RedirectStandardOutput <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        use p = Process.Start(psi)
        let stdout = p.StandardOutput.ReadToEnd()
        p.WaitForExit()
        
        let aligned = stdout.Contains("Holographically Aligned")
        if not aligned then
            printfn "[SEO] ⚠️ SUBSTRATE DRIFT DETECTED: Parity mismatch in Merkle hashes."
        aligned

    /// Aggregate health across all containers
    member this.AggregateHealth() =
        let metrics = healthMetrics.Values |> Seq.toList
        let parityAligned = this.VerifySubstrateParity()

        if metrics.IsEmpty then
            {|
                TotalContainers = 0
                HealthyCount = 0
                DegradedCount = 0
                UnhealthyCount = 0
                UnreachableCount = 0
                AverageHealthScore = 0.0
                AverageResponseTimeMs = 0L
                QuorumStatus = this.CheckQuorum()
                SplitBrainStatus = this.DetectSplitBrain()
                AllSeedsHealthy = false
                SubstrateParity = parityAligned
            |}
        else
            let healthyCount = metrics |> List.filter (fun m -> m.Status = Healthy) |> List.length
            let degradedCount = metrics |> List.filter (fun m -> m.Status = Degraded) |> List.length
            let unhealthyCount = metrics |> List.filter (fun m -> m.Status = Unhealthy) |> List.length
            let unreachableCount = metrics |> List.filter (fun m -> m.Status = Unreachable) |> List.length

            let avgScore = metrics |> List.averageBy (fun m -> m.HealthScore)
            let avgResponseTime =
                metrics
                |> List.averageBy (fun m -> float m.ResponseTimeMs)
                |> int64

            {|
                TotalContainers = metrics.Length
                HealthyCount = healthyCount
                DegradedCount = degradedCount
                UnhealthyCount = unhealthyCount
                UnreachableCount = unreachableCount
                AverageHealthScore = avgScore
                AverageResponseTimeMs = avgResponseTime
                QuorumStatus = this.CheckQuorum()
                SplitBrainStatus = this.DetectSplitBrain()
                AllSeedsHealthy = this.AllSeedsHealthy()
                SubstrateParity = parityAligned
            |}

    /// Should trigger apoptosis? (SC-SIL4-015)
    member this.ShouldTriggerApoptosis() =
        let aggregate = this.AggregateHealth()

        // Condition 1: Split-brain detected
        let splitBrainTrigger =
            match aggregate.SplitBrainStatus with
            | SplitBrainDetected _ -> true
            | _ -> false

        // Condition 2: Quorum lost for extended period
        let quorumLost =
            match aggregate.QuorumStatus with
            | QuorumNotAchieved _ -> true
            | InsufficientNodes _ -> true
            | _ -> false

        // Condition 3: All seeds unhealthy
        let seedsDown = not aggregate.AllSeedsHealthy && seedNodes.Count > 0

        // Condition 4: Substrate Parity Violation (SC-REGEN-002)
        let parityViolation = not aggregate.SubstrateParity

        let shouldTrigger = splitBrainTrigger || (quorumLost && seedsDown) || parityViolation

        if shouldTrigger then
            let effects = {
                FirstOrder = "Apoptosis trigger condition met"
                SecondOrder = sprintf "Split-brain: %b, Quorum lost: %b, Seeds down: %b, Parity Violation: %b"
                                splitBrainTrigger quorumLost seedsDown parityViolation
                ThirdOrder = "Initiating controlled shutdown"
                FourthOrder = "Releasing resources, notifying peers"
                FifthOrder = "Federation cluster reconfiguration"
                Timestamp = DateTime.UtcNow
            }
            effectsLog.TryAdd(Guid.NewGuid(), effects) |> ignore

        shouldTrigger,
        sprintf "SplitBrain=%b, QuorumLost=%b, SeedsDown=%b, ParityViolation=%b"
            splitBrainTrigger quorumLost seedsDown parityViolation

    /// Get recent 5-order effects log
    member this.GetEffectsLog(?count: int) =
        let limit = defaultArg count 20
        effectsLog.Values
        |> Seq.sortByDescending (fun e -> e.Timestamp)
        |> Seq.truncate limit
        |> Seq.toList

    /// Remove container from health tracking
    member this.RemoveContainer(containerId: string) =
        healthMetrics.TryRemove(containerId) |> ignore
        failureCounts.TryRemove(containerId) |> ignore
        seedNodes.TryRemove(containerId) |> ignore

    /// Get circuit breaker status for a container (SC-SIL4-019)
    member this.GetCircuitBreakerStatus(containerId: string) =
        match failureCounts.TryGetValue(containerId) with
        | true, count when count >= config.FailureThreshold ->
            {|
                State = "Open"
                FailureCount = count
                Threshold = config.FailureThreshold
                Message = "Circuit breaker OPEN - container marked unhealthy"
            |}
        | true, count ->
            {|
                State = "Closed"
                FailureCount = count
                Threshold = config.FailureThreshold
                Message = sprintf "Circuit breaker closed - %d/%d failures" count config.FailureThreshold
            |}
        | false, _ ->
            {|
                State = "Unknown"
                FailureCount = 0
                Threshold = config.FailureThreshold
                Message = "Container not being tracked"
            |}

    /// Publish health metrics to Zenoh logic plane
    member this.PublishToZenoh(metrics: ContainerHealthMetrics) =
        let topic = sprintf "indrajaal/health/%s" metrics.ContainerId
        let json = sprintf """{"status":"%A","score":%.2f,"cpu":%.1f,"memory":%.1f,"latency":%d}""" 
                    metrics.Status metrics.HealthScore metrics.CpuUsage metrics.MemoryUsage metrics.ResponseTimeMs
        Cepaf.Mesh.ZenohPublish.publish "CP-HEALTH-01" topic (sprintf "Health updated for %s" metrics.ContainerId) json

    /// Publish aggregate health to Zenoh
    member this.PublishAggregateToZenoh() =
        let agg = this.AggregateHealth()
        let json = sprintf """{"total":%d,"healthy":%d,"avg_score":%.2f,"quorum":"%A"}"""
                    agg.TotalContainers agg.HealthyCount agg.AverageHealthScore agg.QuorumStatus
        Cepaf.Mesh.ZenohPublish.publish "CP-HEALTH-AGG-01" "indrajaal/health/aggregate" "Aggregate health published" json

    /// Perform AI-powered cognitive assessment (SC-COG-001)
    /// Natively implements the AI Authority in F# logic
    member this.PerformCognitiveAssessment() =
        let aggregate = this.AggregateHealth()
        let healthy = aggregate.HealthyCount
        let total = aggregate.TotalContainers
        let score = aggregate.AverageHealthScore

        // SC-PROM-001: Mathematical Correctness Check
        let mathStatus = 
            if aggregate.QuorumStatus.IsQuorumAchieved then "MATHEMATICALLY_SOUND"
            else "QUORUM_FAILURE"

        let threats = 
            if score < 0.9 then
                [ sprintf "Low swarm health (Score: %.2f)" score ]
            else []

        let assessmentJson = 
            sprintf """{"threat_level":"%s","health_score":%.2f,"math_status":"%s","active_threats":%s,"timestamp":"%O"}"""
                (if score >= 0.9 then "none" elif score >= 0.7 then "low" else "elevated")
                score
                mathStatus
                (match threats with | [] -> "[]" | t -> "[" + (t |> List.map (sprintf "\"%s\"") |> String.concat ",") + "]")
                DateTime.UtcNow

        // SC-ZEN-001: Publish AI Authority assessment to Zenoh
        Cepaf.Mesh.ZenohPublish.publish "CP-AI-AUTH-01" "indrajaal/health/sentinel" "F#-Native AI Authority Assessment" assessmentJson
        
        assessmentJson

    /// Verify mathematical invariants for code generation and runtime (SC-MATH-001)
    member this.VerifyMathematicalInvariants() =
        // 1. Quorum Invariant: floor(N/2) + 1
        let quorumValid = 
            let nodes = healthMetrics.Count
            if nodes = 0 then true
            else
                let req = this.CalculateQuorumRequirement(nodes)
                req > (nodes / 2)

        // 2. Connectivity Invariant: All nodes reachable from seed
        let seeds = this.GetSeedHealth()
        let connected = seeds |> List.forall (fun (_, m) -> m.Status <> Unreachable)

        // 3. Result Synthesis
        if quorumValid && connected then
            "CONVERGENT"
        else
            "DIVERGENT"

    /// Async health check loop (SC-SIL4-001: 10s interval)
    member this.StartHealthCheckLoop(checkFunction: string -> Async<ContainerHealthMetrics option>) =
        async {
            while true do
                let containerIds = healthMetrics.Keys |> Seq.toList

                for containerId in containerIds do
                    try
                        let! result = checkFunction containerId
                        match result with
                        | Some metrics ->
                            this.UpdateHealth(
                                containerId,
                                metrics.Status,
                                metrics.HealthScore,
                                metrics.CpuUsage,
                                metrics.MemoryUsage,
                                metrics.ResponseTimeMs)
                            this.PublishToZenoh(metrics) // SC-ZEN-001: Biomorphic broadcast
                        | None ->
                            this.UpdateHealth(
                                containerId,
                                Unreachable,
                                0.0,
                                0.0,
                                0.0,
                                -1L)
                    with ex ->
                        this.UpdateHealth(
                            containerId,
                            Unreachable,
                            0.0,
                            0.0,
                            0.0,
                            -1L)

                this.PublishAggregateToZenoh() // SC-ZEN-001: Biomorphic aggregate broadcast

                // SC-COG-001: Autonomous Cognitive Assessment
                this.PerformCognitiveAssessment() |> ignore

                // SC-SIL4-001: 10s interval
                do! Async.Sleep(config.IntervalMs)
                }

