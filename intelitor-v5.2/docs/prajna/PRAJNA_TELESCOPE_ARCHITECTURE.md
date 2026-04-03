# PRAJNA Telescope Architecture
**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: ACTIVE
**Paradigm**: Directed Telescope with LLM-Powered Predictive Intelligence

## Executive Summary

The PRAJNA Cockpit implements a **5-Level Directed Telescope Architecture** that enables:
- Progressive disclosure from executive summary (L0) to atomic detail (L4)
- LLM-powered predictive caching for sub-second context loading
- Multi-modal navigation (keyboard, mouse, touchscreen)
- Semantic zooming with intelligent context preservation

---

## Part I: The Five Levels (L0-L4)

### 1.1 Level Definitions

```
L0: EXECUTIVE    │ Single-glance health score, critical alerts only
    │            │ "System OK" or "3 Critical Alarms"
    ▼
L1: SUMMARY      │ Domain-level aggregations, trend indicators
    │            │ "Alarms: 12 active, 3 critical | Nodes: 5/5 healthy"
    ▼
L2: OPERATIONAL  │ Entity lists, actionable items, key metrics
    │            │ "app-03: CPU 45% ↑↑, Memory 68%, 1 alarm"
    ▼
L3: DETAIL       │ Full entity view, history, configuration
    │            │ "app-03 Timeline: [12:30 CPU spike, 12:45 Alert...]"
    ▼
L4: ATOMIC       │ Raw data, logs, traces, code-level inspection
                 │ "Trace ID: abc123, Span: 234ms, Stack: [...]"
```

### 1.2 Level Components Matrix

| Component | L0 | L1 | L2 | L3 | L4 |
|-----------|----|----|----|----|-----|
| **Health Score** | ● 94% | Score breakdown | Per-domain scores | Per-entity scores | Raw metrics |
| **Alarms** | ☢ 3 Critical | By severity | Alarm list | Alarm detail | Raw event data |
| **Nodes** | 5/5 | Status grid | Node cards | Full node view | Logs, traces |
| **Commands** | - | Pending: 1 | Command list | Command detail | Audit trail |
| **AI Copilot** | - | Top insight | Insight list | Full analysis | Model outputs |
| **Metrics** | - | Sparklines | Charts | Time series | Raw telemetry |
| **Containers** | - | Status dots | Container cards | Full status | Runtime logs |

### 1.3 Level-Specific Layouts

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ L0: EXECUTIVE VIEW                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │                                                                   │    │
│     │                          ● 94%                                    │    │
│     │                       HEALTHY                                     │    │
│     │                                                                   │    │
│     │                    ⚠ 2 Cautions                                   │    │
│     │                                                                   │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│     [Press SPACE or TAP to drill down]                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ L1: SUMMARY VIEW                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ HEALTH ───────┐ ┌─ ALARMS ────────┐ ┌─ NODES ─────────┐               │
│  │ ● 94% HEALTHY  │ │ ☢0 ⛔0 ⚠2 ℹ5    │ │ 5/5 Online      │               │
│  │ ↑ 2% (24h)     │ │ Response: 12s   │ │ CPU: 38% avg    │               │
│  └────────────────┘ └─────────────────┘ └─────────────────┘               │
│                                                                             │
│  ┌─ CONTAINERS ───┐ ┌─ COPILOT ───────┐ ┌─ COMMANDS ──────┐               │
│  │ ● APP ● DB ⚠OBS│ │ "Consider load  │ │ Pending: 0      │               │
│  │ Uptime: 25d    │ │  balancing..."  │ │ Last: 2h ago    │               │
│  └────────────────┘ └─────────────────┘ └─────────────────┘               │
│                                                                             │
│  [↑↓←→ Navigate] [ENTER/CLICK to select] [ESC to go back]                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ L2: OPERATIONAL VIEW (Alarms Selected)                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ ACTIVE ALARMS (7) ───────────────────────────────────────────────────┐ │
│  │                                                                        │ │
│  │  ► ⚠ ALM-001 │ app-03 │ CPU trending high (45% ↑↑)        │ 12m   │ │
│  │    ⚠ ALM-002 │ app-01 │ Memory approaching threshold       │ 28m   │ │
│  │    ℹ ALM-003 │ obs    │ SigNoz latency elevated            │ 45m   │ │
│  │    ℹ ALM-004 │ db     │ Connection pool 80% utilized       │ 1h    │ │
│  │    ℹ ALM-005 │ app-02 │ Disk approaching 70%               │ 2h    │ │
│  │                                                                        │ │
│  │  [j/k or ↑↓ scroll] [ENTER/CLICK to view] [a to acknowledge]          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌─ QUICK STATS ─────────┐ ┌─ AI INSIGHT ───────────────────────────────┐ │
│  │ Active: 7 │ Today: 23 │ │ "app-03 CPU spike correlates with         │ │
│  │ MTTR: 12m │ MTBF: 4h  │ │  scheduled batch job at 14:00"            │ │
│  └───────────────────────┘ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ L3: DETAIL VIEW (ALM-001 Selected)                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ ALARM: ALM-001 ──────────────────────────────────────────────────────┐ │
│  │ Severity: ⚠ CAUTION │ Status: ACTIVE │ Age: 12 min                    │ │
│  │ Source: app-03 │ Type: CPU_HIGH │ Threshold: 75%                      │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │ TIMELINE                                                               │ │
│  │ ────────────────────────────────────────────────────────────────────── │ │
│  │ 14:32:45  TRIGGERED    CPU exceeded 75% threshold (current: 78%)      │ │
│  │ 14:33:12  ENRICHED     Node: app-03, Zone: primary, IP: 100.64.1.3   │ │
│  │ 14:35:00  ESCALATED    Auto-escalated after 2 min unacknowledged      │ │
│  │ 14:44:45  [NOW]        Awaiting acknowledgement                       │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │ METRIC HISTORY (1h)                                                   │ │
│  │ ▁▂▃▃▄▄▅▅▆▆▆▇▇▇▇▇████████████                                          │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │ AI ANALYSIS (Confidence: 0.92)                                        │ │
│  │ "This CPU spike aligns with the scheduled ETL batch job that runs    │ │
│  │  daily at 14:00. Historical pattern shows 95% of similar spikes      │ │
│  │  resolve within 30 minutes without intervention."                    │ │
│  │                                                                        │ │
│  │ Recommendation: MONITOR (auto-resolve likely in 18 min)              │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │ [ACK] [SILENCE 1h] [ESCALATE] [VIEW NODE] [VIEW TRACES]              │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ L4: ATOMIC VIEW (Traces Selected)                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─ RAW TELEMETRY: app-03 CPU ───────────────────────────────────────────┐ │
│  │                                                                        │ │
│  │ 14:44:45.123 │ cpu_percent │ 78.2 │ host=app-03 core=all              │ │
│  │ 14:44:44.123 │ cpu_percent │ 77.8 │ host=app-03 core=all              │ │
│  │ 14:44:43.123 │ cpu_percent │ 79.1 │ host=app-03 core=all              │ │
│  │ 14:44:42.123 │ cpu_percent │ 76.5 │ host=app-03 core=all              │ │
│  │ 14:44:41.123 │ cpu_percent │ 75.2 │ host=app-03 core=all              │ │
│  │                                                                        │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │ PROCESS BREAKDOWN                                                     │ │
│  │ ────────────────────────────────────────────────────────────────────── │ │
│  │ PID 1234 │ beam.smp      │ 45.2% │ IndrajaalWeb.Endpoint              │ │
│  │ PID 5678 │ etl_worker    │ 28.1% │ Indrajaal.ETL.BatchProcessor       │ │
│  │ PID 9012 │ postgres      │  3.2% │ PostgreSQL: indrajaal_prod         │ │
│  │                                                                        │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │ RELATED TRACES                                                        │ │
│  │ ────────────────────────────────────────────────────────────────────── │ │
│  │ trace-abc123 │ ETL.process_batch │ 2.3s │ 45 spans                    │ │
│  │   └─ ETL.transform       │ 1.8s │ Processing 50,000 records          │ │
│  │      └─ Repo.insert_all  │ 0.4s │ Bulk insert                        │ │
│  │                                                                        │ │
│  │ [EXPORT JSON] [COPY TRACE ID] [OPEN IN SIGNOZ] [BACK TO L3]          │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part II: Directed Telescope Navigation

### 2.1 Navigation Philosophy

The telescope approach means:
1. **Always start at L0** - Executive summary first
2. **Drill down by selection** - Each selection narrows focus
3. **Context preserved** - Breadcrumb shows path taken
4. **Quick escape** - ESC always returns to parent level
5. **Smart defaults** - System suggests next drill-down target

### 2.2 Navigation State Machine

```
                    ┌─────────────┐
                    │     L0      │
                    │  Executive  │
                    └──────┬──────┘
                           │ SELECT domain
                    ┌──────▼──────┐
                    │     L1      │
                    │   Summary   │
                    └──────┬──────┘
                           │ SELECT entity type
                    ┌──────▼──────┐
                    │     L2      │
                    │ Operational │
                    └──────┬──────┘
                           │ SELECT entity
                    ┌──────▼──────┐
                    │     L3      │
                    │   Detail    │
                    └──────┬──────┘
                           │ SELECT raw data
                    ┌──────▼──────┐
                    │     L4      │
                    │   Atomic    │
                    └─────────────┘

Navigation Commands:
  ESC     → Parent level (L4→L3→L2→L1→L0)
  HOME    → Jump to L0
  END     → Jump to L4 (deepest available)
  [n]     → Jump to Ln directly
  TAB     → Next sibling at same level
  SHIFT+TAB → Previous sibling
```

### 2.3 Multi-Modal Navigation

#### Keyboard Navigation

| Key | Action | Context |
|-----|--------|---------|
| `↑` `↓` | Move selection | Lists, grids |
| `←` `→` | Horizontal nav / collapse-expand | Trees, tabs |
| `ENTER` | Select / drill down | All |
| `SPACE` | Toggle / activate | Checkboxes, buttons |
| `ESC` | Back / cancel | All levels |
| `HOME` | Jump to L0 | All levels |
| `END` | Jump to deepest | All levels |
| `0`-`4` | Jump to level | All levels |
| `TAB` | Next element | Forms, lists |
| `SHIFT+TAB` | Previous element | Forms, lists |
| `/` | Search / filter | Lists, trees |
| `?` | Help overlay | All |
| `g` `g` | Go to top | Long lists |
| `G` | Go to bottom | Long lists |
| `j` | Move down (vim) | Lists |
| `k` | Move up (vim) | Lists |
| `h` | Collapse / left | Trees |
| `l` | Expand / right | Trees |
| `a` | Acknowledge | Alarms |
| `r` | Refresh | All |
| `q` | Quit / close | Modals |

#### Mouse Navigation

| Action | Effect | Context |
|--------|--------|---------|
| Click | Select / drill down | All elements |
| Double-click | Quick action | Lists (view detail) |
| Right-click | Context menu | All elements |
| Scroll | Vertical navigation | Lists, content |
| Shift+Scroll | Horizontal navigation | Tables, timelines |
| Drag | Pan / select range | Charts, maps |
| Hover | Tooltip / preview | Metrics, nodes |
| Middle-click | Open in new panel | Links, entities |

#### Touch Navigation

| Gesture | Action | Context |
|---------|--------|---------|
| Tap | Select / activate | All elements |
| Double-tap | Quick action | Lists |
| Long-press | Context menu | All elements |
| Swipe left | Back / dismiss | Cards, panels |
| Swipe right | Action / expand | Cards, drawers |
| Swipe up/down | Scroll | Lists, content |
| Pinch | Zoom level change | L0-L4 navigation |
| Two-finger pan | Pan view | Charts, maps |
| Pull down | Refresh | All screens |
| Edge swipe | Navigation drawer | Main screens |

### 2.4 Navigation Components

```fsharp
/// Level indicator component
let LevelIndicator currentLevel =
    HBox [
        for level in 0..4 do
            let style = if level = currentLevel then Active else Inactive
            LevelDot level style
            if level < 4 then Connector
    ]

/// Breadcrumb trail showing navigation path
let Breadcrumb path =
    HBox [
        for (i, item) in List.indexed path do
            if i > 0 then Text " > " { fg = Gray }
            Link item.label (NavigateTo item.level item.id)
    ]

/// Navigation hint bar
let NavigationHints (level: int) (mode: InputMode) =
    let hints = match mode with
        | Keyboard -> ["↑↓ Navigate"; "ENTER Select"; "ESC Back"; "? Help"]
        | Mouse -> ["Click Select"; "Right-click Menu"; "Scroll Navigate"]
        | Touch -> ["Tap Select"; "Long-press Menu"; "Pinch Zoom"]
    HBox [
        for hint in hints do
            Chip hint { variant = Outlined }
            Spacer 4
    ]
```

---

## Part III: LLM-Powered Predictive Caching

### 3.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LLM PREDICTIVE CACHING SYSTEM                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │ User Navigation │───▶│ Prediction Engine│───▶│ Pre-fetch Queue │        │
│  │   Events        │    │   (LLM-based)   │    │                 │        │
│  └─────────────────┘    └─────────────────┘    └────────┬────────┘        │
│                                                          │                 │
│                              ┌────────────────────────────┘                │
│                              ▼                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │ Hot Cache (L3)  │◀───│ Warm Cache (L3) │◀───│ Cold Storage    │        │
│  │ <100ms access   │    │ <500ms access   │    │ On-demand fetch │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ CACHE HIERARCHY                                                      │   │
│  │                                                                       │   │
│  │ L0 Cache: System health scores, critical alerts (always hot)        │   │
│  │ L1 Cache: Domain summaries, aggregate metrics (5 min TTL)           │   │
│  │ L2 Cache: Entity lists, recent items (2 min TTL)                    │   │
│  │ L3 Cache: Entity details for predicted navigation (30s TTL)         │   │
│  │ L4 Cache: Raw data snippets, not pre-cached                         │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Prediction Engine

```fsharp
/// Navigation prediction using LLM
module PredictionEngine =

    /// Context for prediction
    type NavigationContext = {
        currentLevel: int
        currentEntity: string option
        navigationHistory: (int * string) list
        timeOfDay: TimeSpan
        userRole: string
        recentAlarms: Alarm list
        systemState: SystemState
    }

    /// Predicted next navigation
    type Prediction = {
        level: int
        entityType: string
        entityId: string option
        confidence: float
        reason: string
    }

    /// Generate predictions using LLM
    let predictNextNavigation (context: NavigationContext) : Prediction list Async = async {
        let prompt = sprintf """
            Given the current navigation context:
            - Current Level: L%d
            - Current Entity: %s
            - Recent History: %A
            - Time: %s
            - Role: %s
            - Active Alarms: %d (%d critical)
            - System Health: %d%%

            Predict the 3 most likely next navigation targets.
            Consider:
            1. Alarm investigation patterns
            2. Time-based workflows (morning checks, end-of-day reports)
            3. Role-specific common paths
            4. Current system state (if unhealthy, predict drill-down)

            Return as JSON: [{level, entityType, entityId, confidence, reason}]
            """
            context.currentLevel
            (context.currentEntity |> Option.defaultValue "none")
            (context.navigationHistory |> List.take 5)
            (context.timeOfDay.ToString("hh\\:mm"))
            context.userRole
            (context.recentAlarms |> List.length)
            (context.recentAlarms |> List.filter (fun a -> a.severity = Critical) |> List.length)
            (context.systemState.healthScore * 100 |> int)

        let! response = OpenRouterClient.chat
            [ { role = "system"; content = "You are a navigation prediction assistant for a security monitoring cockpit." }
              { role = "user"; content = prompt } ]
            { model = "meta-llama/llama-3.1-8b"; maxTokens = 500 }

        return parsePredictions response
    }

    /// Pre-fetch predicted data
    let prefetchPredicted (predictions: Prediction list) = async {
        for pred in predictions |> List.filter (fun p -> p.confidence > 0.7) do
            match pred.entityId with
            | Some id ->
                // Pre-fetch L3 data for high-confidence predictions
                do! DataCache.warmL3 pred.entityType id
            | None ->
                // Pre-fetch L2 list for entity type
                do! DataCache.warmL2 pred.entityType
    }
```

### 3.3 Cache Implementation

```fsharp
module DataCache =

    /// Cache entry with TTL and access tracking
    type CacheEntry<'T> = {
        data: 'T
        cachedAt: DateTime
        ttl: TimeSpan
        accessCount: int
        lastAccess: DateTime
    }

    /// Multi-tier cache
    type CacheStore = {
        l0: ConcurrentDictionary<string, CacheEntry<SystemSummary>>
        l1: ConcurrentDictionary<string, CacheEntry<DomainSummary>>
        l2: ConcurrentDictionary<string, CacheEntry<EntityList>>
        l3: ConcurrentDictionary<string, CacheEntry<EntityDetail>>
    }

    let private store = {
        l0 = ConcurrentDictionary()
        l1 = ConcurrentDictionary()
        l2 = ConcurrentDictionary()
        l3 = ConcurrentDictionary()
    }

    /// TTL by level
    let ttlForLevel = function
        | 0 -> TimeSpan.FromSeconds(10)   // L0: Very fresh
        | 1 -> TimeSpan.FromMinutes(5)    // L1: 5 min
        | 2 -> TimeSpan.FromMinutes(2)    // L2: 2 min
        | 3 -> TimeSpan.FromSeconds(30)   // L3: 30 sec
        | _ -> TimeSpan.FromSeconds(0)    // L4: No cache

    /// Get or fetch with automatic caching
    let getOrFetch<'T> level key (fetch: unit -> 'T Async) : 'T Async = async {
        let cache = match level with
            | 0 -> store.l0 :> IDictionary<_,_>
            | 1 -> store.l1 :> IDictionary<_,_>
            | 2 -> store.l2 :> IDictionary<_,_>
            | 3 -> store.l3 :> IDictionary<_,_>
            | _ -> failwith "L4 not cached"

        match cache.TryGetValue(key) with
        | true, entry when DateTime.UtcNow - entry.cachedAt < entry.ttl ->
            // Cache hit - update access stats
            cache.[key] <- { entry with
                accessCount = entry.accessCount + 1
                lastAccess = DateTime.UtcNow
            }
            return entry.data :?> 'T
        | _ ->
            // Cache miss - fetch and store
            let! data = fetch()
            cache.[key] <- {
                data = data :> obj
                cachedAt = DateTime.UtcNow
                ttl = ttlForLevel level
                accessCount = 1
                lastAccess = DateTime.UtcNow
            }
            return data
    }

    /// Warm cache for predicted navigation
    let warmL3 entityType entityId = async {
        let key = sprintf "%s:%s" entityType entityId
        let! _ = getOrFetch 3 key (fun () -> DataSource.fetchEntityDetail entityType entityId)
        ()
    }

    /// Warm L2 list cache
    let warmL2 entityType = async {
        let! _ = getOrFetch 2 entityType (fun () -> DataSource.fetchEntityList entityType)
        ()
    }

    /// Invalidate cache on data change
    let invalidate level key =
        match level with
        | 0 -> store.l0.TryRemove(key) |> ignore
        | 1 -> store.l1.TryRemove(key) |> ignore
        | 2 -> store.l2.TryRemove(key) |> ignore
        | 3 -> store.l3.TryRemove(key) |> ignore
        | _ -> ()
```

### 3.4 Intelligent Pre-loading

```fsharp
module IntelligentPreloader =

    /// Pre-load strategy based on system state
    type PreloadStrategy =
        | Aggressive  // Pre-load all likely paths
        | Normal      // Pre-load high-confidence only
        | Conservative // Minimal pre-loading
        | Disabled    // No pre-loading

    /// Determine strategy based on conditions
    let determineStrategy (state: SystemState) : PreloadStrategy =
        match state.healthScore, state.networkLatency with
        | health, _ when health < 0.5 -> Aggressive // Unhealthy = expect investigation
        | _, latency when latency > 500 -> Conservative // High latency = save bandwidth
        | health, _ when health > 0.95 -> Conservative // All healthy = less drill-down
        | _ -> Normal

    /// Background pre-loader
    let startPreloader () =
        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop () = async {
                let! context = inbox.Receive()

                let strategy = determineStrategy context.systemState

                match strategy with
                | Disabled -> ()
                | Conservative ->
                    // Only pre-load current level + 1
                    let! predictions = PredictionEngine.predictNextNavigation context
                    let topPrediction = predictions |> List.tryHead
                    match topPrediction with
                    | Some p when p.confidence > 0.9 -> do! PredictionEngine.prefetchPredicted [p]
                    | _ -> ()

                | Normal ->
                    // Pre-load top 3 predictions with confidence > 0.7
                    let! predictions = PredictionEngine.predictNextNavigation context
                    do! PredictionEngine.prefetchPredicted predictions

                | Aggressive ->
                    // Pre-load all paths from critical items
                    let! predictions = PredictionEngine.predictNextNavigation context
                    do! PredictionEngine.prefetchPredicted predictions

                    // Also pre-load all critical alarms to L3
                    for alarm in context.recentAlarms |> List.filter (fun a -> a.severity >= Warning) do
                        do! DataCache.warmL3 "alarm" alarm.id

                return! loop ()
            }
            loop ()
        )
        agent
```

---

## Part IV: LLM Integration Throughout the System

### 4.1 LLM Usage Points

| Feature | Model | Purpose | Latency Target |
|---------|-------|---------|----------------|
| **Navigation Prediction** | Llama 3.1 8B | Predict next drill-down | <200ms |
| **Alarm Explanation** | Claude 3.5 Sonnet | Explain alarm context | <2s |
| **Command Parsing** | GPT-4o | Parse natural language commands | <500ms |
| **Anomaly Description** | Claude 3.5 Sonnet | Describe detected anomalies | <1s |
| **Report Generation** | Claude 3.5 Sonnet | Generate executive reports | <5s |
| **Search Enhancement** | Llama 3.1 8B | Semantic search ranking | <300ms |
| **Layout Optimization** | Llama 3.1 70B | Suggest UI improvements | Async |
| **Correlation Finding** | Claude 3.5 Sonnet | Find event correlations | <3s |

### 4.2 Context-Aware LLM Queries

```fsharp
module ContextualLLM =

    /// Enriched context for LLM queries
    type EnrichedContext = {
        // User context
        userId: string
        role: string
        preferences: UserPreferences
        recentActions: Action list

        // System context
        systemHealth: float
        activeAlarms: Alarm list
        recentEvents: Event list
        currentView: ViewState

        // Navigation context
        currentLevel: int
        selectedEntity: string option
        breadcrumb: string list
    }

    /// Build context from current state
    let buildContext (state: AppState) (user: User) : EnrichedContext =
        {
            userId = user.id
            role = user.role
            preferences = user.preferences
            recentActions = state.actionHistory |> List.take 10

            systemHealth = state.systemHealth
            activeAlarms = state.alarms |> List.filter (fun a -> a.status = Active)
            recentEvents = state.events |> List.take 20
            currentView = state.view

            currentLevel = state.navigationLevel
            selectedEntity = state.selectedEntityId
            breadcrumb = state.breadcrumb
        }

    /// Query LLM with full context
    let queryWithContext (context: EnrichedContext) (query: string) (purpose: QueryPurpose) = async {
        let systemPrompt = sprintf """
            You are an AI assistant for a security monitoring cockpit.

            Current context:
            - User: %s (Role: %s)
            - System Health: %.0f%%
            - Active Alarms: %d (%d critical, %d warning)
            - Current View: L%d - %s
            - Navigation Path: %s

            Recent system events:
            %s

            User preferences:
            - Verbosity: %s
            - Technical Level: %s

            Purpose of this query: %s

            Respond concisely and actionably.
            """
            context.userId
            context.role
            (context.systemHealth * 100.0)
            (context.activeAlarms |> List.length)
            (context.activeAlarms |> List.filter (fun a -> a.severity = Critical) |> List.length)
            (context.activeAlarms |> List.filter (fun a -> a.severity = Warning) |> List.length)
            context.currentLevel
            (context.selectedEntity |> Option.defaultValue "Overview")
            (context.breadcrumb |> String.concat " > ")
            (context.recentEvents |> List.map (fun e -> sprintf "- %s: %s" (e.timestamp.ToString("HH:mm:ss")) e.message) |> String.concat "\n")
            (context.preferences.verbosity.ToString())
            (context.preferences.technicalLevel.ToString())
            (purpose.ToString())

        let model = match purpose with
            | QuickInsight -> "meta-llama/llama-3.1-8b"
            | DetailedAnalysis -> "anthropic/claude-3.5-sonnet"
            | CommandParsing -> "openai/gpt-4o"
            | ReportGeneration -> "anthropic/claude-3.5-sonnet"

        return! OpenRouterClient.chat
            [ { role = "system"; content = systemPrompt }
              { role = "user"; content = query } ]
            { model = model; maxTokens = modelMaxTokens purpose }
    }
```

### 4.3 LLM-Powered Features

```fsharp
/// Natural language command parsing
module NLCommand =

    let parseCommand (context: EnrichedContext) (input: string) = async {
        let! response = ContextualLLM.queryWithContext context input CommandParsing

        // Parse structured command from LLM response
        match parseCommandJson response with
        | Ok cmd -> return Some cmd
        | Error _ -> return None
    }

    // Example inputs and outputs:
    // "acknowledge the cpu alarm on app-03"
    //   → AcknowledgeAlarm { alarmId = "ALM-001"; nodeId = "app-03" }
    //
    // "show me what's wrong with the database"
    //   → Navigate { level = 3; entityType = "container"; entityId = "db" }
    //
    // "restart app-03 when cpu drops below 50%"
    //   → ScheduleCommand { command = Restart; target = "app-03"; condition = CpuBelow 50 }


/// Intelligent alarm explanation
module AlarmExplainer =

    let explainAlarm (context: EnrichedContext) (alarm: Alarm) = async {
        let query = sprintf """
            Explain this alarm for a %s:

            Alarm: %s
            Severity: %A
            Source: %s
            Message: %s
            Duration: %s

            Consider:
            1. What is likely causing this?
            2. Is immediate action required?
            3. What are the recommended next steps?
            4. Are there any correlated events?
            """
            context.role
            alarm.id
            alarm.severity
            alarm.source
            alarm.message
            (DateTime.UtcNow - alarm.timestamp).ToString()

        return! ContextualLLM.queryWithContext context query DetailedAnalysis
    }


/// Semantic search enhancement
module SemanticSearch =

    let enhanceSearch (context: EnrichedContext) (query: string) = async {
        let prompt = sprintf """
            User is searching for: "%s"

            Given the current context (viewing %s at L%d), expand this search to:
            1. Identify the most likely search intent
            2. Suggest related terms
            3. Rank results by relevance to current context

            Return as JSON: { intent, relatedTerms, contextWeight }
            """
            query
            (context.selectedEntity |> Option.defaultValue "system")
            context.currentLevel

        let! response = ContextualLLM.queryWithContext context prompt QuickInsight
        return parseSearchEnhancement response
    }
```

---

## Part V: Component Types for Levels

### 5.1 Level-Aware Components

```fsharp
/// Component that adapts to current level
type LevelAwareComponent<'T> = {
    l0Render: 'T -> Element  // Executive summary
    l1Render: 'T -> Element  // Summary view
    l2Render: 'T -> Element  // Operational list item
    l3Render: 'T -> Element  // Full detail
    l4Render: 'T -> Element  // Atomic/raw data
}

/// Create level-aware alarm component
let alarmComponent : LevelAwareComponent<Alarm list> = {
    l0Render = fun alarms ->
        let criticalCount = alarms |> List.filter (fun a -> a.severity = Critical) |> List.length
        if criticalCount > 0 then
            HBox [
                AlarmIcon Critical
                Text (sprintf "☢ %d CRITICAL" criticalCount) { fg = Red; bold = true }
            ] |> Pulse 500<ms>
        else
            Text "✓ No Critical Alarms" { fg = Green }

    l1Render = fun alarms ->
        let bySeverity = alarms |> List.groupBy (fun a -> a.severity)
        HBox [
            for (sev, items) in bySeverity do
                Badge (sprintf "%d" (List.length items)) (severityColor sev)
                Spacer 4
        ]

    l2Render = fun alarms ->
        VBox [
            for alarm in alarms |> List.take 10 do
                AlarmListItem alarm
        ]

    l3Render = fun alarms ->
        match alarms with
        | [alarm] -> AlarmDetailView alarm
        | _ -> Text "Select an alarm" {}

    l4Render = fun alarms ->
        match alarms with
        | [alarm] -> AlarmRawData alarm
        | _ -> Empty
}

/// Render at appropriate level
let renderAtLevel (level: int) (component: LevelAwareComponent<'T>) (data: 'T) : Element =
    match level with
    | 0 -> component.l0Render data
    | 1 -> component.l1Render data
    | 2 -> component.l2Render data
    | 3 -> component.l3Render data
    | 4 -> component.l4Render data
    | _ -> component.l2Render data // Default to L2
```

### 5.2 Navigation Components

```fsharp
/// Level selector for direct jump
let LevelSelector (currentLevel: int) (onSelect: int -> Msg) =
    HBox [
        for level in 0..4 do
            let style = if level = currentLevel then Selected else Default
            Button
                (sprintf "L%d" level)
                (onSelect level)
                { style = style; tooltip = levelDescription level }
            Spacer 2
    ]

/// Breadcrumb with level indicators
let LevelBreadcrumb (path: BreadcrumbItem list) (currentLevel: int) =
    HBox [
        // Level indicator
        Badge (sprintf "L%d" currentLevel) { variant = Filled; color = levelColor currentLevel }
        Spacer 8

        // Path items
        for (i, item) in List.indexed path do
            if i > 0 then
                Text " › " { fg = Gray }
            Link item.label (NavigateTo item)
    ]

/// Quick level jump shortcuts
let LevelShortcuts =
    KeyboardShortcut [Key.Num0] (JumpToLevel 0) Empty
    |> KeyboardShortcut [Key.Num1] (JumpToLevel 1)
    |> KeyboardShortcut [Key.Num2] (JumpToLevel 2)
    |> KeyboardShortcut [Key.Num3] (JumpToLevel 3)
    |> KeyboardShortcut [Key.Num4] (JumpToLevel 4)
```

---

## Part VI: Input Mode Handling

### 6.1 Multi-Modal Input Manager

```fsharp
module InputManager =

    /// Detected input mode
    type InputMode =
        | Keyboard
        | Mouse
        | Touch
        | Voice  // Future

    /// Current input state
    type InputState = {
        mode: InputMode
        lastKeyPress: DateTime option
        lastMouseMove: DateTime option
        lastTouch: DateTime option
        focusedElement: string option
    }

    /// Detect mode from recent input
    let detectMode (state: InputState) : InputMode =
        let now = DateTime.UtcNow
        let threshold = TimeSpan.FromSeconds(2)

        let recentKey = state.lastKeyPress |> Option.map (fun t -> now - t < threshold) |> Option.defaultValue false
        let recentMouse = state.lastMouseMove |> Option.map (fun t -> now - t < threshold) |> Option.defaultValue false
        let recentTouch = state.lastTouch |> Option.map (fun t -> now - t < threshold) |> Option.defaultValue false

        match recentTouch, recentMouse, recentKey with
        | true, _, _ -> Touch
        | _, true, false -> Mouse
        | _, _, true -> Keyboard
        | _ -> state.mode // Keep previous

    /// Adapt UI based on input mode
    let adaptForMode (mode: InputMode) (element: Element) : Element =
        match mode with
        | Keyboard ->
            element
            |> FocusRing
            |> ArrowNav

        | Mouse ->
            element
            |> Tooltip (getTooltip element)
            |> ContextMenu (getContextMenu element)

        | Touch ->
            element
            |> Padding 4  // Larger touch targets
            |> LongPressMenu (getContextMenu element)

        | Voice ->
            element
            |> VoiceHint (getVoiceCommands element)
```

### 6.2 Input Mode Components

```fsharp
/// Mode-specific button
let AdaptiveButton (label: string) (msg: Msg) (inputMode: InputMode) =
    match inputMode with
    | Keyboard ->
        Button label msg { shortcut = Some (Key.fromLabel label) }
    | Mouse ->
        Button label msg { hoverEffect = true; ripple = true }
    | Touch ->
        Button label msg { size = Large; padding = 16 }
    | Voice ->
        Button label msg { voiceCommand = label }

/// Mode-specific list navigation
let AdaptiveList (items: 'a list) (render: 'a -> Element) (inputMode: InputMode) =
    let baseList = VBox [ for item in items -> render item ]

    match inputMode with
    | Keyboard ->
        baseList |> ArrowNav |> VimNav
    | Mouse ->
        baseList |> HoverHighlight
    | Touch ->
        baseList |> SwipeActions |> PullToRefresh
    | Voice ->
        baseList |> NumberedItems |> VoiceSelect
```

---

## Part VII: STAMP Compliance

### 7.1 Safety Constraints for Telescope Navigation

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-NAV-001 | Level transitions must be audited | Log all level changes |
| SC-NAV-002 | Critical alarms visible at all levels | Always show critical count |
| SC-NAV-003 | Maximum 2 clicks to critical data | L0→L2→L3 path guaranteed |
| SC-NAV-004 | ESC always returns to safer state | ESC → parent level |
| SC-NAV-005 | No dead-ends in navigation | Always provide exit |
| SC-NAV-006 | Cache invalidation on data change | WebSocket push invalidates |
| SC-NAV-007 | Prediction confidence threshold | >0.7 for pre-fetch |
| SC-NAV-008 | LLM timeout handling | Fallback to rule-based |
| SC-NAV-009 | Touch target minimum 44px | Accessibility compliance |
| SC-NAV-010 | Keyboard shortcuts documented | Help overlay available |

### 7.2 TDG Tests for Navigation

```elixir
# test/prajna/navigation/telescope_test.exs
defmodule Prajna.Navigation.TelescopeTest do
  use ExUnit.Case
  use PropCheck
  import StreamData, as: SD

  # TDG-NAV-001: Level transitions
  property "level transitions are bounded 0-4" do
    check all level <- SD.integer(0..4),
              action <- SD.member_of([:up, :down, :jump]) do
      new_level = Navigation.transition(level, action)
      assert new_level >= 0 and new_level <= 4
    end
  end

  # TDG-NAV-002: Critical alarm visibility
  property "critical alarms visible at all levels" do
    check all level <- SD.integer(0..4),
              alarms <- alarm_list_generator() do
      view = Navigation.render_level(level, %{alarms: alarms})
      critical_count = Enum.count(alarms, & &1.severity == :critical)

      if critical_count > 0 do
        assert view =~ ~r/critical|☢/i
      end
    end
  end

  # TDG-NAV-003: Path to critical data
  test "critical alarm reachable in 2 clicks from L0" do
    path = Navigation.path_to_critical()
    assert length(path) <= 3  # L0 → L2 → L3
  end

  # TDG-NAV-004: ESC behavior
  property "ESC always decreases or maintains level" do
    check all level <- SD.integer(0..4) do
      new_level = Navigation.handle_escape(level)
      assert new_level <= level
    end
  end
end
```

---

## Summary

The PRAJNA Telescope Architecture provides:

1. **5-Level Hierarchy (L0-L4)**: Progressive disclosure from executive summary to atomic data
2. **Directed Navigation**: Smart defaults and prediction for efficient drill-down
3. **LLM-Powered Intelligence**: Predictive caching, context-aware queries, natural language commands
4. **Multi-Modal Input**: Keyboard, mouse, and touch with mode-specific optimizations
5. **STAMP Compliance**: Safety constraints verified through TDG tests

This architecture enables sub-second context loading through predictive caching while maintaining the C3I principles of situational awareness and rapid response.

---

*Document Version: 1.0.0*
*STAMP Compliance: SC-NAV-001 through SC-NAV-010*
*Framework: SOPv5.11 + PRAJNA + LLM Integration*
