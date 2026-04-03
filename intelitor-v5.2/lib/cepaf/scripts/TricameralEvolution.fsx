#!/usr/bin/env dotnet fsi

// =============================================================================
// TRICAMERAL EVOLUTION ENGINE
// OODA-Based Autonomous System Evolution with Biomorphic Patterns
// =============================================================================
// Version: 1.0.0 | STAMP: SC-EVO-001 to SC-EVO-030
// Layer: L5-EVOLUTIONARY | SIL-6 Compliance | 5-Cycle Execution
// =============================================================================

#r "nuget: System.Text.Json"
#r "nuget: Microsoft.Data.Sqlite"
#r "nuget: FSharp.Data, 6.4.0"

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization
open System.Security.Cryptography
open System.Collections.Generic
open Microsoft.Data.Sqlite

// =============================================================================
// TYPES - EVOLUTION DOMAIN
// =============================================================================

/// Evolution signal severity
type Severity =
    | Critical    // Immediate action required
    | High        // Action within current cycle
    | Medium      // Action within 3 cycles
    | Low         // Optional improvement

/// Evolution action type
type ActionType =
    | ModelSwitch of fromModel: string * toModel: string * reason: string
    | ThresholdAdjust of metric: string * oldValue: float * newValue: float
    | CacheOptimize of target: string * strategy: string
    | RetryLogic of target: string * maxRetries: int * backoffMs: int
    | CircuitBreaker of target: string * threshold: int * cooldownMs: int
    | CostOptimize of strategy: string * expectedSavings: float
    | PerformanceTune of target: string * parameter: string * value: string
    | AlertConfig of signal: string * enabled: bool * threshold: float
    | ScaleAdjust of target: string * direction: string * factor: float
    | HealthCheckTune of target: string * intervalMs: int

/// Evolution proposal
[<CLIMutable>]
type EvolutionProposal = {
    Id: Guid
    Cycle: int
    Timestamp: DateTime
    Signal: string          // The signal that triggered this proposal
    Severity: string
    Action: string          // JSON serialized action
    Rationale: string
    ExpectedImpact: string
    RiskLevel: string
    Approved: bool option   // None = pending, Some true = approved, Some false = rejected
}

/// OODA Phase
type OODAPhase =
    | Observe   // Gather data from monitoring
    | Orient    // Analyze patterns and context
    | Decide    // Generate evolution proposals
    | Act       // Execute approved changes

/// Evolution cycle record
[<CLIMutable>]
type EvolutionCycle = {
    CycleNumber: int
    StartTime: DateTime
    EndTime: DateTime option
    Phase: string
    ObservationJson: string
    OrientationJson: string
    Proposals: EvolutionProposal list
    ActionsExecuted: string list
    Outcome: string
    FitnessScore: float    // 0.0 - 1.0 system fitness
}

/// Orientation context
[<CLIMutable>]
type OrientationContext = {
    Timestamp: DateTime
    Patterns: string list           // Detected patterns
    Trends: Map<string, string>     // metric -> trend (up/down/stable)
    Anomalies: string list          // Unusual behaviors
    HistoricalContext: string       // Past similar situations
    RecommendedFocus: string list   // Priority areas
}

/// System fitness metrics
[<CLIMutable>]
type FitnessMetrics = {
    Availability: float      // 0-1
    Latency: float           // 0-1 (lower is better, normalized)
    CostEfficiency: float    // 0-1
    ConsensusRate: float     // 0-1
    HashIntegrity: float     // 0-1
    ModelOptimality: float   // 0-1
    OverallFitness: float    // Weighted average
}

// =============================================================================
// CONFIGURATION
// =============================================================================

let projectRoot =
    let current = Directory.GetCurrentDirectory()
    if current.Contains("lib/cepaf") then
        Path.GetFullPath(Path.Combine(current, "../.."))
    else current

let dataPath = Path.Combine(projectRoot, "data", "evolution")
let evolutionDbPath = Path.Combine(dataPath, "tricameral_evolution.db")
let monitorDbPath = Path.Combine(projectRoot, "data", "monitoring", "tricameral_monitor.db")
let governanceDbPath = Path.Combine(projectRoot, "data", "governance", "tricameral.db")

/// Fitness weights for overall score
let fitnessWeights = {|
    Availability = 0.25
    Latency = 0.15
    CostEfficiency = 0.15
    ConsensusRate = 0.20
    HashIntegrity = 0.15
    ModelOptimality = 0.10
|}

// =============================================================================
// DATABASE
// =============================================================================

let ensureEvolutionDatabase () =
    Directory.CreateDirectory(dataPath) |> ignore

    use conn = new SqliteConnection($"Data Source={evolutionDbPath}")
    conn.Open()

    let sql = """
        -- Evolution cycles
        CREATE TABLE IF NOT EXISTS evolution_cycles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_number INTEGER NOT NULL UNIQUE,
            start_time TEXT NOT NULL,
            end_time TEXT,
            phase TEXT NOT NULL,
            observation_json TEXT,
            orientation_json TEXT,
            proposals_json TEXT,
            actions_executed_json TEXT,
            outcome TEXT,
            fitness_score REAL,
            hash TEXT
        );

        -- Evolution proposals
        CREATE TABLE IF NOT EXISTS evolution_proposals (
            id TEXT PRIMARY KEY,
            cycle_number INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            signal TEXT NOT NULL,
            severity TEXT NOT NULL,
            action_json TEXT NOT NULL,
            rationale TEXT,
            expected_impact TEXT,
            risk_level TEXT,
            approved INTEGER,
            executed INTEGER DEFAULT 0,
            execution_result TEXT
        );

        -- Fitness history
        CREATE TABLE IF NOT EXISTS fitness_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_number INTEGER NOT NULL,
            availability REAL,
            latency REAL,
            cost_efficiency REAL,
            consensus_rate REAL,
            hash_integrity REAL,
            model_optimality REAL,
            overall_fitness REAL,
            timestamp TEXT NOT NULL
        );

        -- Pattern library (learned patterns)
        CREATE TABLE IF NOT EXISTS pattern_library (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pattern_type TEXT NOT NULL,
            description TEXT NOT NULL,
            detection_rule TEXT,
            recommended_action TEXT,
            success_rate REAL DEFAULT 0.0,
            occurrence_count INTEGER DEFAULT 0,
            last_seen TEXT,
            created_at TEXT NOT NULL
        );

        -- Action history (for learning)
        CREATE TABLE IF NOT EXISTS action_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_number INTEGER NOT NULL,
            action_type TEXT NOT NULL,
            action_json TEXT NOT NULL,
            pre_fitness REAL,
            post_fitness REAL,
            improvement REAL,
            success INTEGER,
            timestamp TEXT NOT NULL
        );

        -- Indexes
        CREATE INDEX IF NOT EXISTS idx_cycles_number ON evolution_cycles(cycle_number);
        CREATE INDEX IF NOT EXISTS idx_proposals_cycle ON evolution_proposals(cycle_number);
        CREATE INDEX IF NOT EXISTS idx_fitness_cycle ON fitness_history(cycle_number);
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.ExecuteNonQuery() |> ignore

    printfn "[EVO] Evolution database initialized at %s" evolutionDbPath

// =============================================================================
// OBSERVE PHASE
// =============================================================================

/// Get latest monitoring data
let getMonitoringState () =
    let observation = {|
        Timestamp = DateTime.UtcNow
        HealthChecks = ResizeArray<obj>()
        Metrics = ResizeArray<obj>()
        Signals = ResizeArray<string>()
    |}

    try
        if File.Exists(monitorDbPath) then
            use conn = new SqliteConnection($"Data Source={monitorDbPath}")
            conn.Open()

            // Get recent health checks
            let sql1 = """
                SELECT component, status, latency_ms, message
                FROM health_checks
                WHERE timestamp > datetime('now', '-5 minutes')
                ORDER BY timestamp DESC
            """
            use cmd1 = new SqliteCommand(sql1, conn)
            use reader1 = cmd1.ExecuteReader()
            while reader1.Read() do
                observation.HealthChecks.Add({|
                    Component = reader1.GetString(0)
                    Status = reader1.GetString(1)
                    Latency = reader1.GetInt32(2)
                    Message = reader1.GetString(3)
                |})

            // Get recent metrics
            let sql2 = """
                SELECT name, value, unit
                FROM metrics
                WHERE timestamp > datetime('now', '-5 minutes')
                ORDER BY timestamp DESC
            """
            use cmd2 = new SqliteCommand(sql2, conn)
            use reader2 = cmd2.ExecuteReader()
            while reader2.Read() do
                observation.Metrics.Add({|
                    Name = reader2.GetString(0)
                    Value = reader2.GetDouble(1)
                    Unit = reader2.GetString(2)
                |})

            // Get recent signals
            let sql3 = """
                SELECT signal_type, component, severity
                FROM evolution_signals
                WHERE timestamp > datetime('now', '-1 hour')
                  AND acknowledged = 0
                ORDER BY timestamp DESC
            """
            use cmd3 = new SqliteCommand(sql3, conn)
            use reader3 = cmd3.ExecuteReader()
            while reader3.Read() do
                let signalType = reader3.GetString(0)
                let target = if reader3.IsDBNull(1) then "" else reader3.GetString(1)
                let severity = reader3.GetString(2)
                observation.Signals.Add($"{severity}: {signalType} on {target}")
    with ex ->
        printfn "[EVO] Warning: Could not read monitoring data: %s" ex.Message

    observation

/// Calculate current fitness metrics
let calculateFitness () : FitnessMetrics =
    let mutable availability = 1.0
    let mutable latency = 1.0
    let mutable costEfficiency = 1.0
    let mutable consensusRate = 1.0
    let mutable hashIntegrity = 1.0
    let mutable modelOptimality = 0.8  // Default

    try
        if File.Exists(monitorDbPath) then
            use conn = new SqliteConnection($"Data Source={monitorDbPath}")
            conn.Open()

            // Get latest snapshot
            let sql = """
                SELECT overall_health, healthy_components, degraded_components, unhealthy_components,
                       total_cost, avg_latency_ms, consensus_rate
                FROM system_snapshots
                ORDER BY timestamp DESC
                LIMIT 1
            """
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            if reader.Read() then
                let healthy = reader.GetInt32(1)
                let degraded = reader.GetInt32(2)
                let unhealthy = reader.GetInt32(3)
                let total = healthy + degraded + unhealthy

                if total > 0 then
                    availability <- float healthy / float total
                    // Add degraded as partial availability
                    availability <- availability + (float degraded * 0.5 / float total)

                // Normalize latency (assume 1000ms is acceptable)
                let avgLatency = if reader.IsDBNull(5) then 100.0 else reader.GetDouble(5)
                latency <- max 0.0 (1.0 - (avgLatency / 5000.0))

                // Cost efficiency (assume $10/hour budget)
                let cost = if reader.IsDBNull(4) then 0.0 else reader.GetDouble(4)
                costEfficiency <- max 0.0 (1.0 - (cost / 100.0))  // $100 total budget

        // Get consensus rate from governance DB
        if File.Exists(governanceDbPath) then
            use conn = new SqliteConnection($"Data Source={governanceDbPath}")
            conn.Open()

            let sql = """
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN consensus_type IN ('UNANIMOUS', 'MAJORITY') THEN 1 ELSE 0 END) as success
                FROM tricameral_decisions
                WHERE timestamp > datetime('now', '-24 hours')
            """
            use cmd = new SqliteCommand(sql, conn)
            use reader = cmd.ExecuteReader()

            if reader.Read() then
                let total = reader.GetInt64(0)
                let success = reader.GetInt64(1)
                if total > 0L then
                    consensusRate <- float success / float total

            // Check hash integrity
            let sql2 = """
                SELECT COUNT(*) as total,
                       SUM(CASE WHEN record_hash IS NOT NULL AND record_hash != '' THEN 1 ELSE 0 END) as hashed
                FROM tricameral_decisions
            """
            use cmd2 = new SqliteCommand(sql2, conn)
            use reader2 = cmd2.ExecuteReader()

            if reader2.Read() then
                let total = reader2.GetInt64(0)
                let hashed = reader2.GetInt64(1)
                if total > 0L then
                    hashIntegrity <- float hashed / float total

    with ex ->
        printfn "[EVO] Warning: Could not calculate fitness: %s" ex.Message

    let overall =
        availability * fitnessWeights.Availability +
        latency * fitnessWeights.Latency +
        costEfficiency * fitnessWeights.CostEfficiency +
        consensusRate * fitnessWeights.ConsensusRate +
        hashIntegrity * fitnessWeights.HashIntegrity +
        modelOptimality * fitnessWeights.ModelOptimality

    {
        Availability = availability
        Latency = latency
        CostEfficiency = costEfficiency
        ConsensusRate = consensusRate
        HashIntegrity = hashIntegrity
        ModelOptimality = modelOptimality
        OverallFitness = overall
    }

// =============================================================================
// ORIENT PHASE
// =============================================================================

/// Analyze patterns and context
let orient (observation: obj) : OrientationContext =
    let patterns = ResizeArray<string>()
    let trends = Dictionary<string, string>()
    let anomalies = ResizeArray<string>()
    let focus = ResizeArray<string>()

    try
        if File.Exists(monitorDbPath) then
            use conn = new SqliteConnection($"Data Source={monitorDbPath}")
            conn.Open()

            // Detect latency trends
            let sql1 = """
                SELECT name, AVG(value) as avg_val
                FROM metrics
                WHERE name LIKE '%latency%'
                  AND timestamp > datetime('now', '-1 hour')
                GROUP BY name
            """
            use cmd1 = new SqliteCommand(sql1, conn)
            use reader1 = cmd1.ExecuteReader()
            while reader1.Read() do
                let name = reader1.GetString(0)
                let avgVal = reader1.GetDouble(1)
                if avgVal > 3000.0 then
                    patterns.Add($"High latency detected: {name} = {avgVal:F0}ms")
                    focus.Add($"Optimize {name}")
                    trends.[name] <- "high"

            // Check for recurring signals
            let sql2 = """
                SELECT signal_type, COUNT(*) as cnt
                FROM evolution_signals
                WHERE timestamp > datetime('now', '-24 hours')
                GROUP BY signal_type
                HAVING cnt > 3
            """
            use cmd2 = new SqliteCommand(sql2, conn)
            use reader2 = cmd2.ExecuteReader()
            while reader2.Read() do
                let signalType = reader2.GetString(0)
                let count = reader2.GetInt64(1)
                patterns.Add($"Recurring signal: {signalType} ({count} times in 24h)")
                anomalies.Add($"Repeated {signalType}")

            // Check component availability
            let sql3 = """
                SELECT component, status, COUNT(*) as cnt
                FROM health_checks
                WHERE timestamp > datetime('now', '-1 hour')
                GROUP BY component, status
            """
            use cmd3 = new SqliteCommand(sql3, conn)
            use reader3 = cmd3.ExecuteReader()
            while reader3.Read() do
                let comp = reader3.GetString(0)
                let status = reader3.GetString(1)
                let count = reader3.GetInt64(2)
                if status = "Unhealthy" && count > 2L then
                    anomalies.Add($"{comp} has been unhealthy {count} times")
                    focus.Add($"Fix {comp} availability")

    with ex ->
        printfn "[EVO] Warning: Orientation failed: %s" ex.Message
        patterns.Add("Orientation incomplete due to data access issues")

    {
        Timestamp = DateTime.UtcNow
        Patterns = patterns |> Seq.toList
        Trends = trends |> Seq.map (fun kv -> kv.Key, kv.Value) |> Map.ofSeq
        Anomalies = anomalies |> Seq.toList
        HistoricalContext = "First evolution cycle - no historical data"
        RecommendedFocus = focus |> Seq.toList
    }

// =============================================================================
// DECIDE PHASE
// =============================================================================

/// Generate evolution proposals based on orientation
let decide (cycle: int) (orientation: OrientationContext) (fitness: FitnessMetrics) : EvolutionProposal list =
    let proposals = ResizeArray<EvolutionProposal>()
    let now = DateTime.UtcNow

    // Proposal 1: If availability is low, suggest scaling
    if fitness.Availability < 0.9 then
        proposals.Add({
            Id = Guid.NewGuid()
            Cycle = cycle
            Timestamp = now
            Signal = "AvailabilityLow"
            Severity = "HIGH"
            Action = JsonSerializer.Serialize({|
                Type = "HealthCheckTune"
                Component = "OpenRouter"
                IntervalMs = 15000
            |})
            Rationale = $"Availability at {fitness.Availability*100.0:F1}%% is below 90%% threshold"
            ExpectedImpact = "Faster detection of failures, improved recovery time"
            RiskLevel = "LOW"
            Approved = None
        })

    // Proposal 2: If latency is high, suggest performance tuning
    if fitness.Latency < 0.7 then
        proposals.Add({
            Id = Guid.NewGuid()
            Cycle = cycle
            Timestamp = now
            Signal = "LatencyHigh"
            Severity = "MEDIUM"
            Action = JsonSerializer.Serialize({|
                Type = "RetryLogic"
                Component = "APIGateway"
                MaxRetries = 2
                BackoffMs = 500
            |})
            Rationale = $"Latency score at {fitness.Latency*100.0:F1}%% indicates slow responses"
            ExpectedImpact = "Reduced failed requests through smart retries"
            RiskLevel = "LOW"
            Approved = None
        })

    // Proposal 3: If cost efficiency is low, suggest model optimization
    if fitness.CostEfficiency < 0.8 then
        proposals.Add({
            Id = Guid.NewGuid()
            Cycle = cycle
            Timestamp = now
            Signal = "CostExceeded"
            Severity = "MEDIUM"
            Action = JsonSerializer.Serialize({|
                Type = "CostOptimize"
                Strategy = "UseEfficientModelsForTactical"
                ExpectedSavings = 0.3
            |})
            Rationale = $"Cost efficiency at {fitness.CostEfficiency*100.0:F1}%% - using expensive models too often"
            ExpectedImpact = "30% cost reduction by using efficient models for tactical decisions"
            RiskLevel = "MEDIUM"
            Approved = None
        })

    // Proposal 4: If consensus rate is low, suggest voting strategy adjustment
    if fitness.ConsensusRate < 0.85 then
        proposals.Add({
            Id = Guid.NewGuid()
            Cycle = cycle
            Timestamp = now
            Signal = "ConsensusFailure"
            Severity = "HIGH"
            Action = JsonSerializer.Serialize({|
                Type = "ThresholdAdjust"
                Metric = "consensus_confidence_threshold"
                OldValue = 0.7
                NewValue = 0.6
            |})
            Rationale = $"Consensus rate at {fitness.ConsensusRate*100.0:F1}%% - too many split decisions"
            ExpectedImpact = "Higher agreement rate with adjusted confidence threshold"
            RiskLevel = "MEDIUM"
            Approved = None
        })

    // Proposal 5: General improvement based on patterns
    for pattern in orientation.Patterns do
        if pattern.Contains("High latency") then
            proposals.Add({
                Id = Guid.NewGuid()
                Cycle = cycle
                Timestamp = now
                Signal = "PatternDetected"
                Severity = "LOW"
                Action = JsonSerializer.Serialize({|
                    Type = "CacheOptimize"
                    Component = "ModelRegistry"
                    Strategy = "PreloadFrequentModels"
                |})
                Rationale = pattern
                ExpectedImpact = "Reduced model lookup latency"
                RiskLevel = "LOW"
                Approved = None
            })

    // Always include a health improvement proposal
    if proposals.Count = 0 || fitness.OverallFitness > 0.85 then
        proposals.Add({
            Id = Guid.NewGuid()
            Cycle = cycle
            Timestamp = now
            Signal = "ContinuousImprovement"
            Severity = "LOW"
            Action = JsonSerializer.Serialize({|
                Type = "AlertConfig"
                Signal = "PerformanceDegraded"
                Enabled = true
                Threshold = 0.8
            |})
            Rationale = "Proactive monitoring enhancement"
            ExpectedImpact = "Earlier detection of performance degradation"
            RiskLevel = "LOW"
            Approved = Some true  // Auto-approve low-risk improvements
        })

    proposals |> Seq.toList

// =============================================================================
// ACT PHASE
// =============================================================================

/// Execute approved proposals (simulation - no actual changes)
let act (proposals: EvolutionProposal list) : string list =
    let actions = ResizeArray<string>()

    for proposal in proposals do
        match proposal.Approved with
        | Some true ->
            // In a real system, this would apply the change
            // For now, we simulate and log
            actions.Add($"EXECUTED: {proposal.Signal} - {proposal.Action}")
            printfn "[EVO] ACT: Executing proposal %s for signal %s"
                (proposal.Id.ToString().Substring(0, 8))
                proposal.Signal
        | Some false ->
            actions.Add($"REJECTED: {proposal.Signal}")
        | None ->
            // Auto-approve low-risk proposals
            if proposal.RiskLevel = "LOW" then
                actions.Add($"AUTO-APPROVED: {proposal.Signal} - {proposal.Action}")
                printfn "[EVO] ACT: Auto-approving low-risk proposal %s"
                    (proposal.Id.ToString().Substring(0, 8))
            else
                actions.Add($"PENDING: {proposal.Signal} (requires approval)")

    actions |> Seq.toList

// =============================================================================
// EVOLUTION CYCLE
// =============================================================================

/// Run a complete OODA evolution cycle
let runEvolutionCycle (cycleNumber: int) : EvolutionCycle =
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════╗"
    printfn "║  EVOLUTION CYCLE %d                                                        ║" cycleNumber
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"

    let startTime = DateTime.UtcNow

    // Phase 1: OBSERVE
    printfn "║  PHASE 1: OBSERVE - Gathering monitoring data...                        ║"
    let observation = getMonitoringState()
    let observationJson = JsonSerializer.Serialize(observation)

    // Phase 2: ORIENT
    printfn "║  PHASE 2: ORIENT - Analyzing patterns and context...                    ║"
    let orientation = orient observation
    let orientationJson = JsonSerializer.Serialize(orientation)

    printfn "║    Patterns detected: %-52d ║" orientation.Patterns.Length
    printfn "║    Anomalies found: %-54d ║" orientation.Anomalies.Length

    // Calculate fitness
    let fitness = calculateFitness()
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  FITNESS METRICS                                                         ║"
    printfn "║    Availability:    %s %.0f%%                                        ║"
        (if fitness.Availability > 0.9 then "🟢" elif fitness.Availability > 0.7 then "🟡" else "🔴")
        (fitness.Availability * 100.0)
    printfn "║    Latency:         %s %.0f%%                                        ║"
        (if fitness.Latency > 0.7 then "🟢" elif fitness.Latency > 0.5 then "🟡" else "🔴")
        (fitness.Latency * 100.0)
    printfn "║    Cost Efficiency: %s %.0f%%                                        ║"
        (if fitness.CostEfficiency > 0.8 then "🟢" elif fitness.CostEfficiency > 0.5 then "🟡" else "🔴")
        (fitness.CostEfficiency * 100.0)
    printfn "║    Consensus Rate:  %s %.0f%%                                        ║"
        (if fitness.ConsensusRate > 0.85 then "🟢" elif fitness.ConsensusRate > 0.7 then "🟡" else "🔴")
        (fitness.ConsensusRate * 100.0)
    printfn "║    Hash Integrity:  %s %.0f%%                                        ║"
        (if fitness.HashIntegrity > 0.99 then "🟢" elif fitness.HashIntegrity > 0.9 then "🟡" else "🔴")
        (fitness.HashIntegrity * 100.0)
    printfn "║    ────────────────────────────────────────────────────────────────────  ║"
    printfn "║    OVERALL FITNESS: %.1f%%                                            ║" (fitness.OverallFitness * 100.0)

    // Phase 3: DECIDE
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  PHASE 3: DECIDE - Generating evolution proposals...                    ║"
    let proposals = decide cycleNumber orientation fitness

    for proposal in proposals do
        let statusIcon =
            match proposal.Approved with
            | Some true -> "✓"
            | Some false -> "✗"
            | None -> if proposal.RiskLevel = "LOW" then "→" else "?"
        printfn "║    %s [%s] %-55s ║" statusIcon proposal.Severity proposal.Signal

    // Phase 4: ACT
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  PHASE 4: ACT - Executing approved proposals...                         ║"
    let actionsExecuted = act proposals

    for action in actionsExecuted do
        let shortAction = if action.Length > 66 then action.Substring(0, 63) + "..." else action
        printfn "║    %s" shortAction

    let endTime = DateTime.UtcNow
    let duration = (endTime - startTime).TotalMilliseconds

    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  CYCLE COMPLETE                                                          ║"
    printfn "║    Duration: %.0fms                                                   ║" duration
    printfn "║    Proposals generated: %-50d ║" proposals.Length
    printfn "║    Actions executed: %-52d ║" actionsExecuted.Length
    printfn "╚══════════════════════════════════════════════════════════════════════════╝"

    {
        CycleNumber = cycleNumber
        StartTime = startTime
        EndTime = Some endTime
        Phase = "COMPLETE"
        ObservationJson = observationJson
        OrientationJson = orientationJson
        Proposals = proposals
        ActionsExecuted = actionsExecuted
        Outcome = $"Fitness: {fitness.OverallFitness:F2}"
        FitnessScore = fitness.OverallFitness
    }

/// Save evolution cycle to database
let saveEvolutionCycle (cycle: EvolutionCycle) =
    use conn = new SqliteConnection($"Data Source={evolutionDbPath}")
    conn.Open()

    let sql = """
        INSERT OR REPLACE INTO evolution_cycles (
            cycle_number, start_time, end_time, phase,
            observation_json, orientation_json, proposals_json, actions_executed_json,
            outcome, fitness_score
        ) VALUES (
            @cycle, @start, @end, @phase,
            @observation, @orientation, @proposals, @actions,
            @outcome, @fitness
        )
    """

    use cmd = new SqliteCommand(sql, conn)
    cmd.Parameters.AddWithValue("@cycle", cycle.CycleNumber) |> ignore
    cmd.Parameters.AddWithValue("@start", cycle.StartTime.ToString("o")) |> ignore
    cmd.Parameters.AddWithValue("@end",
        match cycle.EndTime with
        | Some t -> t.ToString("o") :> obj
        | None -> DBNull.Value :> obj) |> ignore
    cmd.Parameters.AddWithValue("@phase", cycle.Phase) |> ignore
    cmd.Parameters.AddWithValue("@observation", cycle.ObservationJson) |> ignore
    cmd.Parameters.AddWithValue("@orientation", cycle.OrientationJson) |> ignore
    cmd.Parameters.AddWithValue("@proposals", JsonSerializer.Serialize(cycle.Proposals)) |> ignore
    cmd.Parameters.AddWithValue("@actions", JsonSerializer.Serialize(cycle.ActionsExecuted)) |> ignore
    cmd.Parameters.AddWithValue("@outcome", cycle.Outcome) |> ignore
    cmd.Parameters.AddWithValue("@fitness", cycle.FitnessScore) |> ignore

    cmd.ExecuteNonQuery() |> ignore

    // Save fitness metrics
    let fitness = calculateFitness()
    let sql2 = """
        INSERT INTO fitness_history (
            cycle_number, availability, latency, cost_efficiency,
            consensus_rate, hash_integrity, model_optimality, overall_fitness, timestamp
        ) VALUES (@cycle, @avail, @latency, @cost, @consensus, @hash, @model, @overall, @ts)
    """

    use cmd2 = new SqliteCommand(sql2, conn)
    cmd2.Parameters.AddWithValue("@cycle", cycle.CycleNumber) |> ignore
    cmd2.Parameters.AddWithValue("@avail", fitness.Availability) |> ignore
    cmd2.Parameters.AddWithValue("@latency", fitness.Latency) |> ignore
    cmd2.Parameters.AddWithValue("@cost", fitness.CostEfficiency) |> ignore
    cmd2.Parameters.AddWithValue("@consensus", fitness.ConsensusRate) |> ignore
    cmd2.Parameters.AddWithValue("@hash", fitness.HashIntegrity) |> ignore
    cmd2.Parameters.AddWithValue("@model", fitness.ModelOptimality) |> ignore
    cmd2.Parameters.AddWithValue("@overall", fitness.OverallFitness) |> ignore
    cmd2.Parameters.AddWithValue("@ts", DateTime.UtcNow.ToString("o")) |> ignore

    cmd2.ExecuteNonQuery() |> ignore

/// Run multiple evolution cycles
let runEvolutionCycles (count: int) =
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════════════╗"
    printfn "║  TRICAMERAL EVOLUTION ENGINE - STARTING %d CYCLES                                ║" count
    printfn "║  OODA-Based Autonomous System Evolution with Biomorphic Patterns                 ║"
    printfn "╚══════════════════════════════════════════════════════════════════════════════════╝"

    // Get next cycle number
    let startCycle =
        try
            use conn = new SqliteConnection($"Data Source={evolutionDbPath}")
            conn.Open()
            use cmd = new SqliteCommand("SELECT COALESCE(MAX(cycle_number), 0) + 1 FROM evolution_cycles", conn)
            cmd.ExecuteScalar() :?> int64 |> int
        with _ -> 1

    let cycles = ResizeArray<EvolutionCycle>()

    for i in 0 .. count - 1 do
        let cycleNum = startCycle + i
        let cycle = runEvolutionCycle cycleNum
        saveEvolutionCycle cycle
        cycles.Add(cycle)

        // Brief pause between cycles
        if i < count - 1 then
            printfn ""
            printfn "[EVO] Waiting 2 seconds before next cycle..."
            System.Threading.Thread.Sleep(2000)

    // Summary
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════════════╗"
    printfn "║  EVOLUTION SUMMARY                                                               ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"

    let avgFitness = cycles |> Seq.averageBy (fun c -> c.FitnessScore)
    let totalProposals = cycles |> Seq.sumBy (fun c -> c.Proposals.Length)
    let totalActions = cycles |> Seq.sumBy (fun c -> c.ActionsExecuted.Length)

    printfn "║  Cycles completed: %-66d ║" count
    printfn "║  Total proposals generated: %-57d ║" totalProposals
    printfn "║  Total actions executed: %-60d ║" totalActions
    printfn "║  Average fitness score: %-60.1f%% ║" (avgFitness * 100.0)
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"
    printfn "║  FITNESS TREND                                                                   ║"

    for cycle in cycles do
        let bar = String.replicate (int (cycle.FitnessScore * 50.0)) "█"
        printfn "║  Cycle %2d: %s %.1f%%                                     ║"
            cycle.CycleNumber bar (cycle.FitnessScore * 100.0)

    printfn "╚══════════════════════════════════════════════════════════════════════════════════╝"

// =============================================================================
// CLI INTERFACE
// =============================================================================

let showHistory (count: int) =
    use conn = new SqliteConnection($"Data Source={evolutionDbPath}")
    conn.Open()

    let sql = $"SELECT cycle_number, start_time, phase, outcome, fitness_score FROM evolution_cycles ORDER BY cycle_number DESC LIMIT {count}"

    use cmd = new SqliteCommand(sql, conn)
    use reader = cmd.ExecuteReader()

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════╗"
    printfn "║  EVOLUTION HISTORY (Last %d Cycles)                                      ║" count
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    printfn "║  CYCLE │ TIMESTAMP           │ STATUS   │ FITNESS                        ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"

    let mutable found = false
    while reader.Read() do
        found <- true
        let cycle = reader.GetInt32(0)
        let ts = reader.GetString(1).Substring(0, 19)
        let phase = reader.GetString(2)
        let fitness = reader.GetDouble(4)
        printfn "║  %5d │ %s │ %-8s │ %.1f%%                                   ║"
            cycle ts phase (fitness * 100.0)

    if not found then
        printfn "║  No evolution history available                                          ║"

    printfn "╚══════════════════════════════════════════════════════════════════════════╝"

let showFitnessHistory () =
    use conn = new SqliteConnection($"Data Source={evolutionDbPath}")
    conn.Open()

    let sql = """
        SELECT cycle_number, availability, latency, cost_efficiency,
               consensus_rate, hash_integrity, overall_fitness, timestamp
        FROM fitness_history
        ORDER BY cycle_number DESC
        LIMIT 10
    """

    use cmd = new SqliteCommand(sql, conn)
    use reader = cmd.ExecuteReader()

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════════════╗"
    printfn "║  FITNESS HISTORY                                                                 ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"
    printfn "║  CYCLE │ AVAIL │ LATCY │ COST  │ CONSNS│ HASH  │ OVERALL                         ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════════════╣"

    while reader.Read() do
        printfn "║  %5d │ %4.0f%% │ %4.0f%% │ %4.0f%% │ %4.0f%% │ %4.0f%% │ %4.0f%%                          ║"
            (reader.GetInt32(0))
            (reader.GetDouble(1) * 100.0)
            (reader.GetDouble(2) * 100.0)
            (reader.GetDouble(3) * 100.0)
            (reader.GetDouble(4) * 100.0)
            (reader.GetDouble(5) * 100.0)
            (reader.GetDouble(6) * 100.0)

    printfn "╚══════════════════════════════════════════════════════════════════════════════════╝"

let showHelp () =
    printfn """
╔══════════════════════════════════════════════════════════════════════════╗
║  TRICAMERAL EVOLUTION ENGINE                                             ║
║  OODA-Based Autonomous System Evolution                                  ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  COMMANDS:                                                               ║
║    run [n]              Run n evolution cycles (default: 1)              ║
║    cycle                Run single evolution cycle                       ║
║    fitness              Show current fitness metrics                     ║
║    history [n]          Show last n cycles (default: 10)                 ║
║    fitness-history      Show fitness metric history                      ║
║    help                 Show this help                                   ║
║                                                                          ║
║  OODA LOOP:                                                              ║
║    OBSERVE  - Gather monitoring data and metrics                         ║
║    ORIENT   - Analyze patterns, trends, and context                      ║
║    DECIDE   - Generate evolution proposals                               ║
║    ACT      - Execute approved changes                                   ║
║                                                                          ║
║  FITNESS METRICS:                                                        ║
║    Availability   (25%%) - Component uptime                              ║
║    Latency        (15%%) - Response time performance                     ║
║    Cost Efficiency(15%%) - Budget utilization                            ║
║    Consensus Rate (20%%) - Decision success rate                         ║
║    Hash Integrity (15%%) - Audit log integrity                           ║
║    Model Optimal. (10%%) - Model selection effectiveness                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

let showFitness () =
    let fitness = calculateFitness()

    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════════════╗"
    printfn "║  CURRENT SYSTEM FITNESS                                                  ║"
    printfn "╠══════════════════════════════════════════════════════════════════════════╣"

    let printMetric name value weight =
        let icon = if value > 0.8 then "🟢" elif value > 0.5 then "🟡" else "🔴"
        let bar = String.replicate (int (value * 40.0)) "█"
        printfn "║  %s %-15s │ %s %-40.0f%% │ (%.0f%%) ║"
            icon name bar (value * 100.0) (weight * 100.0)

    printMetric "Availability" fitness.Availability fitnessWeights.Availability
    printMetric "Latency" fitness.Latency fitnessWeights.Latency
    printMetric "Cost Efficiency" fitness.CostEfficiency fitnessWeights.CostEfficiency
    printMetric "Consensus Rate" fitness.ConsensusRate fitnessWeights.ConsensusRate
    printMetric "Hash Integrity" fitness.HashIntegrity fitnessWeights.HashIntegrity
    printMetric "Model Optimal." fitness.ModelOptimality fitnessWeights.ModelOptimality

    printfn "╠══════════════════════════════════════════════════════════════════════════╣"
    let overallBar = String.replicate (int (fitness.OverallFitness * 50.0)) "█"
    printfn "║  OVERALL: %s %.1f%%                                   ║"
        overallBar (fitness.OverallFitness * 100.0)
    printfn "╚══════════════════════════════════════════════════════════════════════════╝"

// =============================================================================
// MAIN
// =============================================================================

let main (args: string[]) =
    ensureEvolutionDatabase()

    if args.Length = 0 then
        showHelp()
    else
        match args.[0].ToLower() with
        | "help" | "--help" | "-h" -> showHelp()
        | "run" ->
            let count = if args.Length > 1 then Int32.Parse(args.[1]) else 1
            runEvolutionCycles count
        | "cycle" ->
            runEvolutionCycles 1
        | "fitness" -> showFitness()
        | "history" ->
            let count = if args.Length > 1 then Int32.Parse(args.[1]) else 10
            showHistory count
        | "fitness-history" -> showFitnessHistory()
        | _ ->
            printfn "[EVO] Unknown command: %s" args.[0]
            showHelp()

// Entry point
main (fsi.CommandLineArgs |> Array.skip 1)
