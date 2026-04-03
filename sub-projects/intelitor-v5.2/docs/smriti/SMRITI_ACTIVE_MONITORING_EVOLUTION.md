# SMRITI Active Monitoring and Evolution Services

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-11 | **Status**: ACTIVE
**Framework**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6, ISO 27001
**STAMP**: SC-MON-001 to SC-MON-050, SC-AI-001 (AI Context Persistence)
**Evolution**: CONTINUOUS

```
╔══════════════════════════════════════════════════════════════════════╗
║   ACTIVE MONITORING & EVOLUTION CONTROL CENTER                       ║
║   24/7 Health Monitoring • Information Collection • Evolution        ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 1. SYSTEM COMPONENTS REQUIRING ACTIVE MONITORING

### 1.1 Complete Component Inventory

| Component | Category | Criticality | Monitor Interval | Evolution Cycle |
|-----------|----------|-------------|------------------|-----------------|
| SMRITI SQLite Database | Storage | CRITICAL | 30s | Daily |
| SMRITI DuckDB Analytics | Storage | HIGH | 5min | Weekly |
| Edge Network | Graph | CRITICAL | 1min | Continuous |
| Cluster Assignments | Organization | HIGH | 5min | Daily |
| AI Extraction Pipeline | Processing | CRITICAL | Per-request | Continuous |
| OpenRouter API | External | CRITICAL | 1min | N/A |
| Taxonomy Registry | Vocabulary | HIGH | 10min | Weekly |
| Quality Gate System | Validation | CRITICAL | Per-extraction | Daily |
| Hash Chain Registry | Integrity | CRITICAL | 10min | N/A |
| Merkle Tree Root | Integrity | CRITICAL | Per-batch | N/A |
| Replication Targets | Redundancy | HIGH | 1h | Weekly |
| Federation Peers | Distribution | MEDIUM | 1h | Daily |
| Anti-Entropy Cycle | Maintenance | HIGH | 10min | Continuous |
| Zenoh Telemetry Bus | Communication | HIGH | 30s | N/A |
| Captain's Log | Audit | MEDIUM | 1h | N/A |
| System DNA | Recreatability | CRITICAL | Daily | Weekly |

---

## 2. ACTIVE SERVICES MATRIX

### 2.1 Sentinel Services (Always Running)

```fsharp
/// Core sentinel services that run 24/7
module SmritiMonitoringServices

open System
open System.Timers

/// Service definition
type MonitorService = {
    Name: string
    Interval: TimeSpan
    HealthCheck: unit -> Async<HealthStatus>
    Collector: unit -> Async<MetricsBundle>
    Evolver: MetricsBundle -> Async<EvolutionAction list>
}

/// Health status levels
type HealthStatus =
    | Healthy of float          // 0.8-1.0
    | Degraded of float * string // 0.5-0.8 with reason
    | Unhealthy of string       // <0.5 with reason
    | Critical of string        // Immediate action required

/// Active services
let services = [
    // 1. Database Health Monitor
    {
        Name = "smriti-db-health"
        Interval = TimeSpan.FromSeconds 30.0
        HealthCheck = fun () -> async {
            let! dbSize = getDatabaseSize ()
            let! walSize = getWalSize ()
            let! lastWrite = getLastWriteTime ()
            let! integrityCheck = runIntegrityCheck ()

            if not integrityCheck then
                return Critical "Database integrity check failed"
            elif walSize > 100_000_000L then
                return Degraded (0.7, "WAL size exceeds 100MB")
            else
                return Healthy 1.0
        }
        Collector = collectDatabaseMetrics
        Evolver = fun metrics -> async {
            let actions = []
            if metrics.walSize > 50_000_000L then
                return [VacuumDatabase; CheckpointWal]
            return actions
        }
    }

    // 2. Edge Network Monitor
    {
        Name = "smriti-edge-health"
        Interval = TimeSpan.FromMinutes 1.0
        HealthCheck = fun () -> async {
            let! orphanCount = countOrphanHolons ()
            let! avgEdgeDensity = getAverageEdgeDensity ()
            let! brokenEdges = countBrokenEdges ()

            if brokenEdges > 0 then
                return Unhealthy $"Found {brokenEdges} broken edges"
            elif avgEdgeDensity < 3.0 then
                return Degraded (0.6, "Low edge density")
            elif orphanCount > 100 then
                return Degraded (0.7, $"{orphanCount} orphan holons")
            else
                return Healthy (min 1.0 (avgEdgeDensity / 10.0))
        }
        Collector = collectEdgeMetrics
        Evolver = fun metrics -> async {
            let actions = []
            if metrics.orphanCount > 50 then
                return [EnrichOrphans; RegenerateEdges]
            if metrics.avgDensity < 5.0 then
                return [LowerEdgeThreshold 0.15]
            return actions
        }
    }

    // 3. AI Pipeline Monitor
    {
        Name = "smriti-ai-pipeline"
        Interval = TimeSpan.FromMinutes 1.0
        HealthCheck = fun () -> async {
            let! apiAvailable = checkOpenRouterAPI ()
            let! budgetRemaining = getBudgetRemaining ()
            let! avgQuality = getAverageQualityScore ()

            if not apiAvailable then
                return Unhealthy "OpenRouter API unavailable"
            elif budgetRemaining < 0.1 then
                return Critical "AI budget nearly exhausted"
            elif avgQuality < 60.0 then
                return Degraded (0.5, "Quality score below threshold")
            else
                return Healthy (avgQuality / 100.0)
        }
        Collector = collectAIPipelineMetrics
        Evolver = fun metrics -> async {
            if metrics.avgQuality < 70.0 then
                return [UpgradeAIModel; RefinePrompts]
            if metrics.successRate < 0.9 then
                return [AnalyzeFailures; ImproveRetry]
            return []
        }
    }

    // 4. Hash Chain Integrity Monitor
    {
        Name = "smriti-hash-chain"
        Interval = TimeSpan.FromMinutes 10.0
        HealthCheck = fun () -> async {
            let! chainValid = verifyHashChain ()
            let! merkleValid = verifyMerkleRoot ()
            let! lastVerified = getLastVerificationTime ()

            if not chainValid then
                return Critical "Hash chain broken - integrity compromised"
            elif not merkleValid then
                return Unhealthy "Merkle root mismatch"
            else
                return Healthy 1.0
        }
        Collector = collectIntegrityMetrics
        Evolver = fun _ -> async { return [] } // No evolution, just alerting
    }

    // 5. Replication Health Monitor
    {
        Name = "smriti-replication"
        Interval = TimeSpan.FromHours 1.0
        HealthCheck = fun () -> async {
            let! duckdbSync = checkDuckDBSync ()
            let! s3Sync = checkS3Sync ()
            let! ipfsSync = checkIPFSSync ()

            let syncCount = [duckdbSync; s3Sync; ipfsSync] |> List.filter id |> List.length

            if syncCount < 2 then
                return Unhealthy $"Only {syncCount} replicas in sync"
            elif syncCount = 2 then
                return Degraded (0.7, "One replica out of sync")
            else
                return Healthy 1.0
        }
        Collector = collectReplicationMetrics
        Evolver = fun metrics -> async {
            if not metrics.duckdbSync then return [SyncDuckDB]
            if not metrics.s3Sync then return [SyncS3]
            if not metrics.ipfsSync then return [SyncIPFS]
            return []
        }
    }

    // 6. Taxonomy Evolution Monitor
    {
        Name = "smriti-taxonomy"
        Interval = TimeSpan.FromMinutes 10.0
        HealthCheck = fun () -> async {
            let! orphanTags = countOrphanTags ()
            let! duplicateTags = countDuplicateTags ()
            let! tagCoverage = calculateTagCoverage ()

            if orphanTags > 50 then
                return Degraded (0.6, $"{orphanTags} unused tags")
            elif duplicateTags > 10 then
                return Degraded (0.7, $"{duplicateTags} duplicate tags")
            else
                return Healthy (tagCoverage)
        }
        Collector = collectTaxonomyMetrics
        Evolver = fun metrics -> async {
            let actions = []
            if metrics.emergingPatterns > 10 then
                return [ProposeNewTags metrics.emergingPatterns]
            if metrics.orphanTags > 20 then
                return [PruneOrphanTags]
            return actions
        }
    }

    // 7. Anti-Entropy Cycle Monitor
    {
        Name = "smriti-anti-entropy"
        Interval = TimeSpan.FromMinutes 10.0
        HealthCheck = fun () -> async {
            let! lastCycle = getLastAntiEntropyCycle ()
            let! issuesFixed = getIssuesFixedLastHour ()
            let! avgEntropy = getAverageEntropy ()

            let hoursSinceCycle = (DateTime.Now - lastCycle).TotalHours

            if hoursSinceCycle > 1.0 then
                return Unhealthy "Anti-entropy cycle not running"
            elif avgEntropy > 0.7 then
                return Degraded (0.5, "High average entropy")
            else
                return Healthy (1.0 - avgEntropy)
        }
        Collector = collectEntropyMetrics
        Evolver = fun metrics -> async {
            if metrics.avgEntropy > 0.6 then
                return [TriggerMassRefresh; IncreaseRefreshRate]
            return []
        }
    }

    // 8. DNA Integrity Monitor
    {
        Name = "smriti-dna"
        Interval = TimeSpan.FromDays 1.0
        HealthCheck = fun () -> async {
            let! dnaExists = checkDNAExists ()
            let! dnaValid = validateDNAIntegrity ()
            let! dnaAge = getDNAAge ()

            if not dnaExists then
                return Critical "System DNA not found"
            elif not dnaValid then
                return Unhealthy "DNA integrity check failed"
            elif dnaAge.TotalDays > 7.0 then
                return Degraded (0.7, "DNA older than 7 days")
            else
                return Healthy 1.0
        }
        Collector = collectDNAMetrics
        Evolver = fun metrics -> async {
            if metrics.age.TotalDays > 3.0 then
                return [RegenerateDNA]
            return []
        }
    }
]
```

---

## 3. CONTROL MEASURES AND HEALTH CHECKS

### 3.1 Health Check Protocol

```elixir
defmodule SMRITI.HealthCheckProtocol do
  @moduledoc """
  Standardized health check protocol for all SMRITI components.
  Implements FPPS 5-method consensus for critical checks.
  """

  use GenServer
  require Logger

  @check_interval :timer.seconds(30)

  # Component registry
  @components [
    {:database, &check_database_health/0, :critical},
    {:edges, &check_edge_network/0, :critical},
    {:ai_pipeline, &check_ai_pipeline/0, :critical},
    {:hash_chain, &check_hash_chain/0, :critical},
    {:replication, &check_replication/0, :high},
    {:taxonomy, &check_taxonomy/0, :high},
    {:anti_entropy, &check_anti_entropy/0, :high},
    {:federation, &check_federation/0, :medium},
    {:dna, &check_dna/0, :critical}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_check()
    {:ok, %{last_check: nil, status: %{}, history: []}}
  end

  def handle_info(:run_checks, state) do
    new_status = run_all_checks()

    # Publish to Zenoh
    publish_health_status(new_status)

    # Log any degradations
    log_degradations(state.status, new_status)

    # Trigger evolutionary responses
    trigger_evolution(new_status)

    schedule_check()

    {:noreply, %{state |
      last_check: DateTime.utc_now(),
      status: new_status,
      history: [new_status | Enum.take(state.history, 99)]
    }}
  end

  defp run_all_checks do
    @components
    |> Enum.map(fn {name, check_fn, priority} ->
      Task.async(fn ->
        try do
          result = check_fn.()
          {name, result, priority}
        rescue
          e -> {name, {:error, Exception.message(e)}, priority}
        end
      end)
    end)
    |> Task.await_many(5000)
    |> Map.new(fn {name, result, priority} -> {name, %{result: result, priority: priority}} end)
  end

  defp trigger_evolution(status) do
    status
    |> Enum.filter(fn {_name, %{result: result}} ->
      case result do
        {:degraded, _, _} -> true
        {:unhealthy, _} -> true
        {:critical, _} -> true
        _ -> false
      end
    end)
    |> Enum.each(fn {name, %{result: result}} ->
      SMRITI.EvolutionEngine.trigger(name, result)
    end)
  end
end
```

### 3.2 Control Measures Table

| Component | Control Measure | Trigger Condition | Action | Recovery Time |
|-----------|-----------------|-------------------|--------|---------------|
| Database | Auto-vacuum | WAL > 50MB | VACUUM + checkpoint | < 1 min |
| Database | Integrity repair | Check fails | Restore from backup | < 5 min |
| Edges | Orphan enrichment | Orphans > 50 | Deep similarity scan | < 10 min |
| Edges | Edge regeneration | Broken edges > 0 | Full edge rebuild | < 30 min |
| AI Pipeline | Model upgrade | Quality < 70% | Switch to sonnet | Immediate |
| AI Pipeline | Prompt refinement | Failures > 10% | Update prompts | < 1 hour |
| Hash Chain | Chain repair | Verification fails | Reconstruct from source | < 15 min |
| Replication | Force sync | Lag > 1 hour | Immediate sync | < 10 min |
| Replication | Substrate failover | Primary fails | Promote secondary | < 1 min |
| Taxonomy | Tag normalization | Duplicates > 10 | Merge duplicates | < 5 min |
| Taxonomy | Vocabulary expansion | Emerging > 10 | Add new tags | < 1 min |
| Anti-Entropy | Accelerated cycle | Entropy > 0.6 | 2x refresh rate | Immediate |
| DNA | Regeneration | Age > 3 days | Full DNA rebuild | < 30 min |

---

## 4. INFORMATION COLLECTION AND METRICS

### 4.1 Metrics Collection Pipeline

```
╔═══════════════════════════════════════════════════════════════════════╗
║   METRICS COLLECTION PIPELINE                                         ║
╠═══════════════════════════════════════════════════════════════════════╣
║   Sources                                                             ║
║   ├─ SQLite (holons, edges, clusters)                                ║
║   ├─ DuckDB (history, analytics)                                     ║
║   ├─ AI Pipeline (costs, quality, timing)                            ║
║   ├─ Health Checks (status, degradations)                            ║
║   └─ Evolution Actions (proposals, outcomes)                         ║
║                                                                       ║
║   Collection                                                          ║
║   ├─ Poll-based (30s interval for critical)                          ║
║   ├─ Event-driven (on extraction, edge creation)                     ║
║   └─ Batch (hourly aggregations)                                     ║
║                                                                       ║
║   Storage                                                             ║
║   ├─ DuckDB (time-series, analytics-ready)                           ║
║   ├─ SQLite (current state snapshots)                                ║
║   └─ Captain's Log (audit trail)                                     ║
║                                                                       ║
║   Publication                                                         ║
║   ├─ Zenoh (real-time telemetry)                                     ║
║   ├─ Prometheus (metrics export)                                     ║
║   └─ Prajna Dashboard (visualization)                                ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### 4.2 Key Performance Indicators (KPIs)

```fsharp
/// SMRITI Key Performance Indicators
type SmritiKPI = {
    // Volume metrics
    totalHolons: int
    totalEdges: int
    totalClusters: int
    holonsCreatedToday: int
    edgesCreatedToday: int

    // Quality metrics
    avgQualityScore: float      // 0-100
    avgEdgeDensity: float       // edges per holon
    orphanPercentage: float     // % holons with 0 edges
    taxonomyCoverage: float     // % holons with valid tags

    // Health metrics
    databaseHealthScore: float  // 0-1
    chainIntegrity: bool
    replicationStatus: int      // count of synced replicas
    avgEntropy: float           // 0-1 (lower is better)

    // Cost metrics
    aiCostToday: float          // USD
    aiCostThisMonth: float      // USD
    avgCostPerExtraction: float // USD

    // Performance metrics
    avgExtractionTime: float    // seconds
    avgEdgeGenerationTime: float // seconds
    lastBackupAge: TimeSpan

    // Evolution metrics
    evolutionActionsToday: int
    successfulEvolutions: int
    failedEvolutions: int
}

/// Collect all KPIs
let collectKPIs () = async {
    let! holonStats = getHolonStatistics ()
    let! edgeStats = getEdgeStatistics ()
    let! qualityStats = getQualityStatistics ()
    let! healthStats = getHealthStatistics ()
    let! costStats = getCostStatistics ()
    let! evolutionStats = getEvolutionStatistics ()

    return {
        totalHolons = holonStats.total
        totalEdges = edgeStats.total
        totalClusters = holonStats.clusters
        holonsCreatedToday = holonStats.todayCount
        edgesCreatedToday = edgeStats.todayCount
        avgQualityScore = qualityStats.average
        avgEdgeDensity = edgeStats.avgDensity
        orphanPercentage = holonStats.orphanPercent
        taxonomyCoverage = qualityStats.tagCoverage
        databaseHealthScore = healthStats.dbScore
        chainIntegrity = healthStats.chainValid
        replicationStatus = healthStats.syncedReplicas
        avgEntropy = healthStats.avgEntropy
        aiCostToday = costStats.todayCost
        aiCostThisMonth = costStats.monthCost
        avgCostPerExtraction = costStats.avgCost
        avgExtractionTime = healthStats.avgExtractionSec
        avgEdgeGenerationTime = healthStats.avgEdgeSec
        lastBackupAge = healthStats.lastBackup
        evolutionActionsToday = evolutionStats.todayActions
        successfulEvolutions = evolutionStats.successes
        failedEvolutions = evolutionStats.failures
    }
}
```

### 4.3 Metrics Storage Schema

```sql
-- DuckDB schema for metrics time series
CREATE TABLE smriti_metrics (
    timestamp TIMESTAMP NOT NULL,
    metric_name VARCHAR NOT NULL,
    metric_value DOUBLE NOT NULL,
    tags MAP(VARCHAR, VARCHAR),
    PRIMARY KEY (timestamp, metric_name)
);

-- Aggregation table
CREATE TABLE smriti_metrics_hourly (
    hour TIMESTAMP NOT NULL,
    metric_name VARCHAR NOT NULL,
    min_value DOUBLE,
    max_value DOUBLE,
    avg_value DOUBLE,
    count INTEGER,
    PRIMARY KEY (hour, metric_name)
);

-- Evolution history
CREATE TABLE smriti_evolution_log (
    id INTEGER PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    component VARCHAR NOT NULL,
    trigger_condition VARCHAR,
    action_taken VARCHAR,
    outcome VARCHAR,
    metrics_before JSON,
    metrics_after JSON
);
```

---

## 5. EVOLUTIONARY MEASURES

### 5.1 Evolution Engine

```elixir
defmodule SMRITI.EvolutionEngine do
  @moduledoc """
  Autonomous evolution engine for SMRITI improvement.
  Implements OODA-based continuous improvement.
  """

  use GenServer
  require Logger

  # Evolution actions with priorities
  @evolution_actions [
    # Database evolution
    {:database, :vacuum, 0.5, &vacuum_database/0},
    {:database, :reindex, 0.3, &reindex_database/0},

    # Edge evolution
    {:edges, :enrich_orphans, 0.7, &enrich_orphans/0},
    {:edges, :lower_threshold, 0.4, &lower_edge_threshold/0},
    {:edges, :regenerate, 0.2, &regenerate_all_edges/0},

    # AI evolution
    {:ai, :upgrade_model, 0.6, &upgrade_ai_model/0},
    {:ai, :refine_prompts, 0.8, &refine_prompts/0},
    {:ai, :expand_fallback, 0.5, &expand_fallback_chain/0},

    # Taxonomy evolution
    {:taxonomy, :add_tags, 0.7, &add_emerging_tags/0},
    {:taxonomy, :prune_unused, 0.4, &prune_unused_tags/0},
    {:taxonomy, :merge_duplicates, 0.6, &merge_duplicate_tags/0},

    # Quality evolution
    {:quality, :re_extract_low, 0.5, &re_extract_low_quality/0},
    {:quality, :update_gates, 0.3, &update_quality_gates/0},

    # Replication evolution
    {:replication, :add_substrate, 0.2, &add_new_substrate/0},
    {:replication, :optimize_sync, 0.4, &optimize_sync_protocol/0}
  ]

  def trigger(component, condition) do
    GenServer.cast(__MODULE__, {:trigger_evolution, component, condition})
  end

  def handle_cast({:trigger_evolution, component, condition}, state) do
    # OBSERVE: Current state
    current_metrics = collect_metrics(component)

    # ORIENT: Analyze condition
    analysis = analyze_condition(component, condition, current_metrics)

    # DECIDE: Select evolution action
    action = select_evolution_action(component, analysis)

    # ACT: Execute evolution
    result = execute_evolution(action, current_metrics)

    # LEARN: Record outcome
    record_evolution(component, condition, action, result)

    # Publish to Zenoh
    publish_evolution_event(component, action, result)

    {:noreply, update_state(state, component, result)}
  end

  defp select_evolution_action(component, analysis) do
    @evolution_actions
    |> Enum.filter(fn {comp, _name, _priority, _fn} -> comp == component end)
    |> Enum.sort_by(fn {_comp, _name, priority, _fn} -> -priority end)
    |> Enum.find(fn {_comp, _name, _priority, action_fn} ->
      applicable?(action_fn, analysis)
    end)
  end

  defp execute_evolution(nil, _metrics) do
    {:no_action, "No applicable evolution action"}
  end

  defp execute_evolution({_comp, name, _priority, action_fn}, metrics) do
    Logger.info("[Evolution] Executing #{name}")

    before_metrics = metrics
    result = action_fn.()
    after_metrics = collect_metrics_after()

    improvement = calculate_improvement(before_metrics, after_metrics)

    {:ok, %{
      action: name,
      improvement: improvement,
      before: before_metrics,
      after: after_metrics
    }}
  end
end
```

### 5.2 Evolutionary Actions Catalog

| Component | Action | Trigger | Expected Improvement | Frequency |
|-----------|--------|---------|---------------------|-----------|
| Database | Vacuum | WAL > 50MB | -90% WAL size | Daily |
| Database | Reindex | Query time > 100ms | -50% query time | Weekly |
| Edges | Enrich orphans | Orphans > 50 | -80% orphans | Continuous |
| Edges | Lower threshold | Avg density < 5 | +50% edges | Weekly |
| Edges | Regenerate | Broken > 0 | 100% integrity | On demand |
| AI | Upgrade model | Quality < 70% | +15% quality | On demand |
| AI | Refine prompts | Patterns emerge | +10% quality | Weekly |
| Taxonomy | Add tags | Frequency > 10 | +5% coverage | Weekly |
| Taxonomy | Prune unused | Orphans > 20 | -50% orphans | Monthly |
| Quality | Re-extract | Score < 50 | +30% score | Continuous |
| Replication | Add substrate | Replicas < 3 | +1 replica | On demand |

### 5.3 Learning and Feedback Loop

```fsharp
/// Learning from evolution outcomes
module EvolutionLearning

type EvolutionOutcome = {
    action: string
    component: string
    timestamp: DateTime
    success: bool
    improvementScore: float   // -1 to +1
    metricsChange: Map<string, float>
}

/// Store outcomes for learning
let recordOutcome (outcome: EvolutionOutcome) = async {
    // Store in DuckDB
    do! insertEvolutionLog outcome

    // Update action effectiveness scores
    let! currentScore = getActionScore outcome.action
    let newScore =
        currentScore * 0.9 + outcome.improvementScore * 0.1  // Exponential moving average
    do! updateActionScore outcome.action newScore

    // Feed to Training Gym if AI-related
    if outcome.component = "ai" then
        do! sendToTrainingGym outcome
}

/// Analyze patterns in evolution outcomes
let analyzeEvolutionPatterns () = async {
    let! recentOutcomes = getRecentOutcomes (TimeSpan.FromDays 30.0)

    // Find effective actions
    let effectiveActions =
        recentOutcomes
        |> List.groupBy (fun o -> o.action)
        |> List.map (fun (action, outcomes) ->
            let avgImprovement =
                outcomes |> List.averageBy (fun o -> o.improvementScore)
            (action, avgImprovement))
        |> List.sortByDescending snd

    // Find ineffective actions
    let ineffectiveActions =
        effectiveActions
        |> List.filter (fun (_, score) -> score < 0.0)

    // Recommend priority adjustments
    let recommendations =
        effectiveActions
        |> List.take 5
        |> List.map (fun (action, score) ->
            sprintf "Increase priority of '%s' (score: %.2f)" action score)

    return {|
        effective = effectiveActions
        ineffective = ineffectiveActions
        recommendations = recommendations
    |}
}
```

---

## 6. ZENOH TELEMETRY TOPICS

### 6.1 Topic Registry

| Topic Pattern | Purpose | Frequency | Format |
|---------------|---------|-----------|--------|
| `smriti/health/{component}` | Component health status | 30s | JSON |
| `smriti/metrics/{metric_name}` | Individual metrics | 30s | Float |
| `smriti/kpi/summary` | Full KPI bundle | 1min | JSON |
| `smriti/evolution/{component}` | Evolution events | On event | JSON |
| `smriti/alert/{severity}` | Alerts by severity | On alert | JSON |
| `smriti/captain_log` | Captain's log entries | 1h | JSON |

### 6.2 Topic Schemas

```json
// smriti/health/{component}
{
  "component": "database",
  "status": "healthy|degraded|unhealthy|critical",
  "score": 0.95,
  "details": "Optional details string",
  "timestamp": "2026-01-11T12:00:00Z"
}

// smriti/evolution/{component}
{
  "component": "edges",
  "action": "enrich_orphans",
  "trigger": "orphan_count > 50",
  "outcome": "success",
  "improvement": 0.15,
  "metrics_before": {...},
  "metrics_after": {...},
  "timestamp": "2026-01-11T12:05:00Z"
}

// smriti/alert/{severity}
{
  "severity": "critical|high|medium|low",
  "component": "hash_chain",
  "message": "Hash chain integrity verification failed",
  "action_required": "Manual inspection required",
  "timestamp": "2026-01-11T12:10:00Z"
}
```

---

## 7. PRAJNA DASHBOARD INTEGRATION

### 7.1 SMRITI Metrics Panel

```
╔══════════════════════════════════════════════════════════════════════╗
║  SMRITI KNOWLEDGE HEALTH                                   [30s refresh]║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  HOLONS: 2,190  EDGES: 21,947  CLUSTERS: 58   DENSITY: 10.0/holon    ║
║                                                                       ║
║  ┌─ Health Status ─────────────────────────────────────────────────┐ ║
║  │  Database     ████████████████████ 100%  ✓ Healthy              │ ║
║  │  Edges        ██████████████████░░  90%  ⚠ Low density areas    │ ║
║  │  AI Pipeline  ████████████████████ 100%  ✓ Healthy              │ ║
║  │  Hash Chain   ████████████████████ 100%  ✓ Verified             │ ║
║  │  Replication  ██████████████░░░░░░  70%  ⚠ S3 sync delayed      │ ║
║  │  Taxonomy     ██████████████████░░  90%  ✓ Good coverage        │ ║
║  │  Anti-Entropy ████████████████████ 100%  ✓ Cycle active         │ ║
║  │  DNA          ████████████████████ 100%  ✓ Valid                │ ║
║  └──────────────────────────────────────────────────────────────────┘ ║
║                                                                       ║
║  ┌─ Evolution Activity (24h) ──────────────────────────────────────┐ ║
║  │  Actions: 12   Successful: 10   Failed: 2   Improvement: +8%    │ ║
║  └──────────────────────────────────────────────────────────────────┘ ║
║                                                                       ║
║  ┌─ AI Costs (Today) ─────────────────────────────────────────────┐  ║
║  │  Spent: $0.32 / $5.00 budget   Avg: $0.0018/extraction          │ ║
║  └──────────────────────────────────────────────────────────────────┘ ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 8. STAMP CONSTRAINTS (Monitoring)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-MON-001 | Health checks MUST run every 30s for critical components | CRITICAL | Timer verification |
| SC-MON-002 | Metrics MUST be stored for 30 days minimum | HIGH | Retention check |
| SC-MON-003 | Alerts MUST be published within 1s of detection | CRITICAL | Latency check |
| SC-MON-004 | Evolution actions MUST be logged with before/after metrics | HIGH | Log verification |
| SC-MON-005 | Zenoh telemetry MUST be active for monitoring | CRITICAL | Connection check |
| SC-MON-006 | Captain's Log MUST update hourly | MEDIUM | Timestamp check |
| SC-MON-007 | KPIs MUST refresh every 60s | HIGH | Refresh check |
| SC-MON-008 | Failed evolution MUST trigger alert | HIGH | Alert verification |
| SC-MON-009 | Degraded status for > 10 min MUST escalate | HIGH | Escalation check |
| SC-MON-010 | Critical status MUST trigger immediate action | CRITICAL | Response time |

---

## 9. AOR RULES (Monitoring)

| ID | Rule |
|----|------|
| AOR-MON-001 | ALWAYS publish health status to Zenoh |
| AOR-MON-002 | NEVER ignore critical alerts |
| AOR-MON-003 | LOG all monitoring events with timestamps |
| AOR-MON-004 | ESCALATE persistent degradations |
| AOR-MON-005 | RECORD evolution outcomes for learning |
| AOR-MON-006 | VERIFY hash chain before any evolution |
| AOR-MON-007 | BACKUP before risky evolution actions |
| AOR-MON-008 | ROLLBACK failed evolution within 5 minutes |
| AOR-MON-009 | SYNC metrics to DuckDB hourly |
| AOR-MON-010 | REFRESH dashboard every 30 seconds |
| AOR-AI-001 | PERSIST memory/context to SMRITI for AI session continuity |

---

## Related Documents

- [SMRITI Developer Guide](SMRITI_DEVELOPER_GUIDE.md)
- [SMRITI User Guide](SMRITI_USER_GUIDE.md)
- [User Operations Guide](../USER_OPERATIONS_GUIDE.md)
- [SMRITI 8-Level Fractal Evolution Plan](SMRITI_8LEVEL_FRACTAL_EVOLUTION_PLAN.md)
- [SMRITI Intelligence Substrate Analysis](SMRITI_INTELLIGENCE_SUBSTRATE_ANALYSIS.md)
- [SMRITI AI Extraction Rules](SMRITI_AI_EXTRACTION_RULES.md)

---

*"Monitoring is not observation—it is active participation in the system's survival. Every metric collected is information for evolution. Every health check is a step toward immortality."*

**End of Active Monitoring and Evolution Services Document**

*SMRITI Active Monitoring v21.3.0-SIL6 | Indrajaal Project | 2026-01-11*
