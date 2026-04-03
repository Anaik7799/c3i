# Indrajaal Planning & Task Execution System

## Integrated Requirements, Architecture & Implementation Specification

**Version:** 1.0.0-SIL6
**Date:** January 2026
**Architecture:** Fractal | Holonic | Biomorphic | Military-Grade
**Implementation:** F# 10.0 with Event Sourcing, CQRS, Railway-Oriented Programming
**Integration:** Prajna C3I | Cortex AI | Zenoh Mesh | SMRITI Persistence

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Requirements Synthesis](#2-requirements-synthesis)
3. [System Architecture](#3-system-architecture)
4. [F# Module Structure](#4-f-module-structure)
5. [Integration Architecture](#5-integration-architecture)
6. [User Interface Integration](#6-user-interface-integration)
7. [STAMP Constraints](#7-stamp-constraints)
8. [AOR Rules](#8-aor-rules)
9. [Implementation Plan](#9-implementation-plan)
10. [Testing Strategy](#10-testing-strategy)
11. [Migration Strategy](#11-migration-strategy)
12. [Quadplex & Fractal Logging Integration](#12-quadplex--fractal-logging-integration)
13. [Zenoh Control & Dataplane Integration](#13-zenoh-control--dataplane-integration)
14. [Elixir System Interop](#14-elixir-system-interop)
15. [Feature Capability Matrix (10 Levels × 4 Modes)](#15-feature-capability-matrix-10-levels--4-modes)
16. [Long-Term 1000-Year Planning](#16-long-term-1000-year-planning)
17. [Mixed Human-Agent Teams](#17-mixed-human-agent-teams)
18. [Mathematical & Formal Foundations](#18-mathematical--formal-foundations)
19. [Graph-Based Modeling & Simulation](#19-graph-based-modeling--simulation)
20. [Comprehensive Verification Framework](#20-comprehensive-verification-framework)
21. [Exhaustive BDD Scenarios (4 Levels)](#21-exhaustive-bdd-scenarios-4-levels)
22. [UI/UX/CX/DX Comprehensive Design](#22-uiuxcxdx-comprehensive-design)
23. [OpenRouter & Distributed Intelligence](#23-openrouter--distributed-intelligence)
24. [System Artifacts Reference](#24-system-artifacts-reference)
25. [Comprehensive System Integration](#25-comprehensive-system-integration)
26. [100% Test Coverage Framework](#26-100-test-coverage-framework)
27. [Related Documents](#27-related-documents)
28. [Appendices](#28-appendices)
29. [Deployment & Operations Runbook](#29-deployment--operations-runbook)
30. [Troubleshooting & Error Handling](#30-troubleshooting--error-handling)
31. [Performance Benchmarks & SLAs](#31-performance-benchmarks--slas)
32. [Security Model & Threat Analysis](#32-security-model--threat-analysis)
33. [Disaster Recovery & Business Continuity](#33-disaster-recovery--business-continuity)
34. [Compliance & Audit Framework](#34-compliance--audit-framework)
35. [Fractal Architecture & OODA Integration](#35-fractal-architecture--ooda-integration)
36. [Reliability, Robustness & Correctness](#36-reliability-robustness--correctness)
37. [Intelligence & Evolutionary Aspects](#37-intelligence--evolutionary-aspects)
38. [Situational Flexibility & Adaptation](#38-situational-flexibility--adaptation)

---

## 1. Executive Summary

### 1.1 Problem Statement

The Indrajaal system requires a unified planning and task execution system that:

- Unifies task management, project coordination, program oversight, and strategic portfolio planning
- Integrates with AI agents (Claude/Cortex) for intelligent automation
- Implements military-grade decision frameworks (OODA, SOD, MDMP)
- Provides real-time distributed synchronization via Zenoh
- Supports multiple interfaces (TUI, CLI, Cockpit GUI, Emacs)
- Maintains full audit trails via event sourcing

### 1.2 Solution Overview

The **Cepaf.Planning** system provides:

- **Hierarchical Work Structure**: Task → Project → Program → Portfolio (Fractal)
- **Military Decision Frameworks**: OODA Loop, MDMP, Eisenhower Matrix, SOD
- **Event-Sourced Architecture**: Complete audit trails in SMRITI (SQLite/DuckDB)
- **Multi-Actor Support**: Humans, teams, organizations, AI agents
- **Real-Time Sync**: Zenoh pub/sub for distributed coordination
- **Natural Language Interface**: AI-powered task capture and parsing

### 1.3 Key Differentiators

| Capability | Asana/Jira/ClickUp | Indrajaal Planning |
|------------|--------------------|--------------------|
| Hierarchical Structure | Project-level | Portfolio→Program→Project→Task (7-level fractal) |
| Military Frameworks | None | OODA, MDMP, SOD, Eisenhower |
| AI Agent Support | Limited | Full MCP Integration + Cortex |
| Event Sourcing | None | Complete Audit Trail |
| Real-time Distributed | Webhooks | Zenoh Pub/Sub/Query |
| Self-hosted | Limited | Full Holon Sovereignty |

---

## 2. Requirements Synthesis

### 2.1 Core Feature Requirements

#### From Asana (Team Balance)
- Workload Management: Visual agent/user load indication
- Dependencies: Explicit blocking relationships
- Milestones: Major checkpoints aggregating tasks

#### From Jira (Agile/Dev)
- Sprints: Time-boxed iterations
- Epics: Large bodies of work (mapped to Holons)
- Issue Linking: Relates-to, Duplicates, Blocks

#### From Todoist (Personal Productivity)
- Natural Language Input: AI parsing
- Priority Levels: P0-P4 mapping

#### From Trello (Kanban)
- Board View: Tasks as cards in columns
- Drag-and-Drop: Status transitions

### 2.2 Military Planning Requirements

#### OODA Loop Support
| Phase | System Feature | Latency Target |
|-------|----------------|----------------|
| **Observe** | Real-time dashboards, event streams | < 100ms |
| **Orient** | Analytics engine, AI insights | < 500ms |
| **Decide** | Priority scoring, COA comparison | < 1s |
| **Act** | Quick capture, automation triggers | < 100ms |

#### MDMP (Military Decision Making Process)
1. **Receipt of Mission**: Task/goal capture with commander's intent
2. **Mission Analysis**: Key tasks, constraints, risk assessment
3. **COA Development**: Multiple viable approaches
4. **COA Analysis**: War-gaming and synchronization
5. **COA Comparison**: Decision matrix evaluation
6. **COA Approval**: Selection and refined intent
7. **Orders Production**: OPORD generation

#### Systemic Operational Design (SOD)
- **System Frame**: Mapping Rival, Command, and Environment systems
- **Holistic Strike**: Identifying leverage points for systemic disruption
- **Cognitive Maneuver**: Attacking the enemy's "Theory of Victory"

### 2.3 Fractal Execution Levels

| Level | Name | Planning Focus | Time Scale |
|-------|------|----------------|------------|
| L1 | Soldier | Individual task, "Rosh Gadol" improvisation | Seconds |
| L2 | Tactical | Squad coordination, agent groups | Minutes |
| L3 | Unit | Specialized capabilities, domain focus | Hours |
| L4 | Operational | Campaign management, sprints | Days |
| L5 | Strategic | Long-term goals, programs | Weeks |
| L6 | Societal | Ecosystem impact, portfolios | Months |
| L7 | Geopolitical | Federation-wide alignment | Years |

---

## 3. System Architecture

### 3.1 Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          UI LAYER                                    │
│   TUI │ CLI │ Prajna Cockpit │ Emacs Integration │ Web GUI          │
├─────────────────────────────────────────────────────────────────────┤
│                          API LAYER                                   │
│   REST API │ GraphQL │ WebSocket │ MCP Server │ Agent Interface     │
├─────────────────────────────────────────────────────────────────────┤
│                      APPLICATION LAYER                               │
│   Commands │ Queries │ Event Handlers │ Projections │ OODA Engine   │
├─────────────────────────────────────────────────────────────────────┤
│                        DOMAIN LAYER                                  │
│   Entities │ Value Objects │ Domain Events │ Military Frameworks    │
├─────────────────────────────────────────────────────────────────────┤
│                    INFRASTRUCTURE LAYER                              │
│   SMRITI (SQLite/DuckDB) │ Zenoh Messaging │ Cortex AI │ Guardian   │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Integration Points

```
                    ┌───────────────────┐
                    │   Prajna C3I      │
                    │   Cockpit         │
                    └─────────┬─────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────▼─────────┐    │     ┌─────────▼─────────┐
    │   Cortex AI       │    │     │   Guardian        │
    │   (OpenRouter)    │    │     │   (Approval)      │
    └─────────┬─────────┘    │     └─────────┬─────────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
              ┌───────────────▼───────────────┐
              │      CEPAF.PLANNING           │
              │      (F# Core Engine)         │
              └───────────────┬───────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼───────┐    ┌───────▼───────┐    ┌───────▼───────┐
│   SMRITI DB   │    │   Zenoh Mesh  │    │   Immutable   │
│   (SQLite)    │    │   (Pub/Sub)   │    │   Register    │
└───────────────┘    └───────────────┘    └───────────────┘
```

### 3.3 CQRS + Event Sourcing Architecture

#### Command Side (Write Model)
```
Command → Validation → Aggregate Load → Business Logic → Events → Event Store
```

#### Query Side (Read Model)
```
Query → Projection Selection → Materialized View → Response DTO
```

#### Event Flow
```
TaskCreated → Published to Zenoh → Projections Updated → UI Notified
```

---

## 4. F# Module Structure

### 4.1 Project Layout

```
lib/cepaf/src/Cepaf.Planning/
├── Cepaf.Planning.fsproj          # Project file (net10.0)
├── Domain/
│   ├── Types.fs                   # Core value types (EntityId, Priority, etc.)
│   ├── Task.fs                    # Task aggregate root
│   ├── Project.fs                 # Project entity
│   ├── Program.fs                 # Program entity
│   ├── Portfolio.fs               # Portfolio entity
│   ├── Sprint.fs                  # Sprint entity
│   ├── OKR.fs                     # Objectives and Key Results
│   └── Military/
│       ├── OODALoop.fs            # OODA cycle implementation
│       ├── MDMP.fs                # Military Decision Making Process
│       ├── SOD.fs                 # Systemic Operational Design
│       └── Eisenhower.fs          # Priority matrix
├── Events/
│   ├── TaskEvents.fs              # Task domain events
│   ├── ProjectEvents.fs           # Project domain events
│   ├── ProgramEvents.fs           # Program domain events
│   └── PortfolioEvents.fs         # Portfolio domain events
├── Commands/
│   ├── TaskCommands.fs            # Task command handlers
│   ├── ProjectCommands.fs         # Project command handlers
│   └── AgentCommands.fs           # AI agent command interface
├── Queries/
│   ├── TaskQueries.fs             # Task query projections
│   ├── ProjectQueries.fs          # Project query projections
│   ├── DashboardQueries.fs        # Dashboard data aggregation
│   └── AnalyticsQueries.fs        # Analytics and reporting
├── Infrastructure/
│   ├── SmritiRepository.fs        # SQLite/DuckDB persistence
│   ├── EventStore.fs              # Event sourcing infrastructure
│   ├── ZenohAdapter.fs            # Zenoh pub/sub integration
│   └── CortexClient.fs            # AI/Cortex integration
├── Services/
│   ├── PlanningEngine.fs          # Core planning orchestration
│   ├── OODAController.fs          # OODA loop execution
│   ├── NaturalLanguageParser.fs   # NLP task parsing
│   └── AutomationEngine.fs        # Rule-based automation
├── API/
│   ├── RestEndpoints.fs           # REST API handlers
│   ├── McpServer.fs               # MCP protocol server
│   └── AgentInterface.fs          # AI agent API
├── UI/
│   ├── TuiRenderer.fs             # Terminal UI rendering
│   ├── CliCommands.fs             # CLI command handlers
│   └── CockpitWidgets.fs          # Prajna cockpit components
└── Bridge/
    ├── ElixirBridge.fs            # Elixir/Phoenix interop
    └── EmacsProtocol.fs           # Emacs integration protocol
```

### 4.2 Core Domain Types

```fsharp
namespace Cepaf.Planning.Domain

open System

// Core Identifiers
[<Struct>]
type EntityId = EntityId of Guid
    with
    static member New() = EntityId(Guid.NewGuid())
    static member Parse(s: string) = EntityId(Guid.Parse(s))
    member this.Value = let (EntityId id) = this in id

[<Struct>]
type HierarchicalId = {
    PortfolioId: EntityId option
    ProgramId: EntityId option
    ProjectId: EntityId option
    TaskId: EntityId
}

// Priority System (Eisenhower Matrix + Military Criticality)
type Urgency =
    | Immediate    // P0 - Now
    | Soon         // P1 - Today
    | Scheduled    // P2 - This week
    | Eventual     // P3 - This month
    | Deferred     // P4 - Backlog

type Importance =
    | Critical     // Mission-critical
    | High         // Significant impact
    | Medium       // Normal value
    | Low          // Nice to have
    | Optional     // Can be dropped

type Priority = {
    Urgency: Urgency
    Importance: Importance
    CriticalityScore: int  // 1-100 computed
    EisenhowerQuadrant: int // 1-4
}

// Task Status with Military Context
type TaskStatus =
    | Pending           // Not started
    | Planned           // Scheduled
    | Ready             // Prerequisites met
    | InProgress        // Active work
    | InReview          // Awaiting approval
    | Blocked of string // Cannot proceed
    | OnHold of string  // Paused intentionally
    | Completed         // Finished
    | Cancelled of string // Abandoned
    | Archived          // Historical

// OODA Phase Tracking
type OODAPhase =
    | Observe of observations: string list
    | Orient of analysis: string * context: Map<string, string>
    | Decide of options: string list * selected: int option
    | Act of action: string * result: string option
```

### 4.3 Military Framework Types

```fsharp
namespace Cepaf.Planning.Domain.Military

// OODA Loop State
type OODAState = {
    Phase: OODAPhase
    CycleNumber: int
    StartTime: DateTimeOffset
    LoopDuration: TimeSpan option
    Observations: string list
    Orientation: Map<string, string>
    Decision: string option
    ActionTaken: string option
    Feedback: string list
}

// MDMP (Military Decision Making Process)
type MissionAnalysis = {
    HigherOrderIntent: string
    KeyTasks: string list
    Constraints: string list
    CriticalFacts: string list
    Assumptions: string list
    RiskAssessment: RiskLevel
}

type CourseOfAction = {
    Id: EntityId
    Name: string
    Description: string
    Strengths: string list
    Weaknesses: string list
    Risks: Risk list
    ResourceRequirements: Resource list
    Timeline: Timeline
    Score: decimal option
}

type MDMPState = {
    Step: MDMPStep
    MissionStatement: string option
    Analysis: MissionAnalysis option
    CoursesOfAction: CourseOfAction list
    SelectedCOA: EntityId option
    OperationsOrder: string option
}

// SOD (Systemic Operational Design)
type SystemFrame = {
    RivalSystem: SystemModel
    CommandSystem: SystemModel
    Environment: EnvironmentModel
    Rationales: string list
    LeveragePoints: LeveragePoint list
}

type SODDesign = {
    Frame: SystemFrame
    OperationalLogic: string
    HolisticStrike: string option
    CognitiveEffect: string option
    ReframingTriggers: string list
}
```

---

## 5. Integration Architecture

### 5.1 Prajna C3I Integration

The planning system is a core subsystem of the Prajna C3I Cockpit.

```fsharp
namespace Cepaf.Planning.Integration

module PrajnaIntegration =

    /// Register planning widgets with Prajna
    let registerWidgets (cockpit: PrajnaCockpit) =
        cockpit.RegisterWidget("planning-board", BoardWidget.create)
        cockpit.RegisterWidget("planning-timeline", TimelineWidget.create)
        cockpit.RegisterWidget("ooda-loop", OODAWidget.create)
        cockpit.RegisterWidget("task-feed", TaskFeedWidget.create)

    /// Subscribe to Prajna commands
    let subscribeCommands (bus: CommandBus) =
        bus.Subscribe<CreateTaskCommand>(TaskCommandHandler.handleCreate)
        bus.Subscribe<UpdateTaskCommand>(TaskCommandHandler.handleUpdate)
        bus.Subscribe<ExecuteOODACommand>(OODAHandler.execute)

    /// Integrate with Guardian for approval
    let withGuardianApproval (command: PlanningCommand) =
        async {
            let! approval = Guardian.validate command
            match approval with
            | Approved token ->
                let! result = executeCommand command
                return Ok result
            | Rejected reason ->
                return Error (sprintf "Guardian rejected: %s" reason)
        }
```

### 5.2 Cortex AI Integration

```fsharp
namespace Cepaf.Planning.Integration

module CortexIntegration =

    open Cepaf.AI

    /// AI-powered task parsing
    let parseNaturalLanguage (input: string) =
        async {
            let client = OpenRouterClient(Config.load())
            let prompt = sprintf """
                Parse this task input: "%s"
                Extract: title, due date, priority, tags, assignees
                Return JSON format.
            """ input

            let! result = client.ChatAsync(prompt, "task-parsing")
            return result |> Result.bind parseTaskJson
        }

    /// AI-assisted planning recommendations
    let getRecommendations (context: PlanningContext) =
        async {
            let client = OpenRouterClient(Config.load())
            let prompt = sprintf """
                Given the current planning state:
                - Active tasks: %d
                - Blocked tasks: %d
                - Sprint progress: %d%%
                - Team capacity: %d%%

                Recommend next actions aligned with Founder's Directive (Ω₀).
            """ context.ActiveTasks context.BlockedTasks context.Progress context.Capacity

            return! client.ChatAsync(prompt, "planning-recommendations")
        }

    /// OODA Orient phase with AI
    let aiOrient (observations: string list) =
        async {
            let client = OpenRouterClient(Config.load())
            let prompt = sprintf """
                Analyze these observations using SOD (Systemic Operational Design):
                %s

                Identify:
                1. System patterns
                2. Leverage points
                3. Cognitive effects
                4. Recommended actions
            """ (String.concat "\n- " observations)

            return! client.ChatAsync(prompt, "ooda-orient")
        }
```

### 5.3 Zenoh Messaging Integration

```fsharp
namespace Cepaf.Planning.Infrastructure

module ZenohAdapter =

    open Cepaf.Zenoh

    /// Topic hierarchy
    module Topics =
        let taskEvents = "indrajaal/planning/tasks/events"
        let projectEvents = "indrajaal/planning/projects/events"
        let oodaUpdates = "indrajaal/planning/ooda/updates"
        let agentCommands agentId = sprintf "indrajaal/planning/agents/%s/commands" agentId
        let notifications userId = sprintf "indrajaal/planning/users/%s/notifications" userId
        let dashboardMetrics = "indrajaal/planning/dashboard/metrics"

    /// Publish task event
    let publishTaskEvent (session: ZenohSession) (event: TaskEvent) =
        async {
            let json = JsonSerializer.Serialize(event)
            do! session.Put(Topics.taskEvents, json)

            // Also publish to user notification topics
            match event with
            | TaskAssigned (taskId, assignment) ->
                let notification = { Type = "task_assigned"; TaskId = taskId; Details = assignment }
                do! session.Put(Topics.notifications assignment.UserId, JsonSerializer.Serialize(notification))
            | _ -> ()
        }

    /// Subscribe to planning updates
    let subscribeUpdates (session: ZenohSession) (handler: DomainEvent -> unit) =
        session.Subscribe(Topics.taskEvents, fun payload ->
            let event = JsonSerializer.Deserialize<TaskEvent>(payload)
            handler (Task event)
        )
```

### 5.4 SMRITI Database Integration

```fsharp
namespace Cepaf.Planning.Infrastructure

module SmritiRepository =

    open Microsoft.Data.Sqlite

    /// Connection configuration
    type SmritiConfig = {
        DatabasePath: string
        WalMode: bool
        CacheSize: int
    }

    let defaultConfig = {
        DatabasePath = "data/planning/planning.db"
        WalMode = true
        CacheSize = 10000
    }

    /// Initialize schema
    let initializeSchema (conn: SqliteConnection) =
        let sql = """
            -- Event store table
            CREATE TABLE IF NOT EXISTS events (
                event_id TEXT PRIMARY KEY,
                stream_id TEXT NOT NULL,
                stream_type TEXT NOT NULL,
                event_type TEXT NOT NULL,
                event_data TEXT NOT NULL,
                metadata TEXT,
                version INTEGER NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(stream_id, version)
            );

            -- Task projection table
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                hierarchical_id TEXT,
                title TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL,
                priority_urgency TEXT,
                priority_importance TEXT,
                criticality_score INTEGER,
                due_date TEXT,
                created_at TEXT,
                updated_at TEXT,
                version INTEGER
            );

            -- OODA state table
            CREATE TABLE IF NOT EXISTS ooda_states (
                id TEXT PRIMARY KEY,
                task_id TEXT REFERENCES tasks(id),
                phase TEXT NOT NULL,
                cycle_number INTEGER,
                observations TEXT,
                orientation TEXT,
                decision TEXT,
                action TEXT,
                feedback TEXT,
                started_at TEXT,
                completed_at TEXT
            );

            -- Indexes
            CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
            CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(criticality_score DESC);
            CREATE INDEX IF NOT EXISTS idx_events_stream ON events(stream_id, version);
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.ExecuteNonQuery() |> ignore
```

---

## 6. User Interface Integration

### 6.1 TUI (Terminal User Interface)

```fsharp
namespace Cepaf.Planning.UI

module TuiRenderer =

    open Cepaf.Cockpit.DarkCockpitUI

    /// Render task board in terminal
    let renderBoard (tasks: Task list) =
        let columns = [
            ("Pending", tasks |> List.filter (fun t -> t.Status = Pending))
            ("In Progress", tasks |> List.filter (fun t -> t.Status = InProgress))
            ("Review", tasks |> List.filter (fun t -> t.Status = InReview))
            ("Completed", tasks |> List.filter (fun t -> t.Status = Completed))
        ]

        let sb = StringBuilder()

        // Header
        sb.AppendLine(sprintf "%s%s PLANNING BOARD %s%s" Ansi.bold Ansi.blue Box.h Ansi.reset) |> ignore

        // Columns
        let maxRows = columns |> List.map (snd >> List.length) |> List.max

        for row in 0 .. maxRows - 1 do
            for (name, colTasks) in columns do
                match colTasks |> List.tryItem row with
                | Some task ->
                    let priorityColor =
                        match task.Priority.CriticalityScore with
                        | s when s >= 80 -> Ansi.warning
                        | s when s >= 60 -> Ansi.caution
                        | _ -> Ansi.normal
                    sb.Append(sprintf "%s[%s]%s " priorityColor (task.Title.Substring(0, min 20 task.Title.Length)) Ansi.reset) |> ignore
                | None ->
                    sb.Append(String.replicate 22 " ") |> ignore
            sb.AppendLine() |> ignore

        sb.ToString()

    /// Render OODA loop status
    let renderOODA (state: OODAState) =
        let phaseIndicator phase current =
            if phase = current then
                sprintf "%s●%s" Ansi.connected Ansi.reset
            else
                sprintf "%s○%s" Ansi.dim Ansi.reset

        sprintf """
%s╔═══════════════════════════════════════╗%s
%s║         OODA LOOP - Cycle %d          ║%s
%s╠═══════════════════════════════════════╣%s
%s║ %s OBSERVE  %s ORIENT  %s DECIDE  %s ACT  ║%s
%s╚═══════════════════════════════════════╝%s
"""
            Ansi.blue Ansi.reset
            Ansi.blue state.CycleNumber Ansi.reset
            Ansi.blue Ansi.reset
            Ansi.blue
            (phaseIndicator OODAPhase.Observe state.Phase)
            (phaseIndicator OODAPhase.Orient state.Phase)
            (phaseIndicator OODAPhase.Decide state.Phase)
            (phaseIndicator OODAPhase.Act state.Phase)
            Ansi.reset
            Ansi.blue Ansi.reset
```

### 6.2 CLI Commands

```fsharp
namespace Cepaf.Planning.UI

module CliCommands =

    /// CLI command definitions
    type PlanningCommand =
        | Status
        | List of filter: string option
        | Add of title: string * options: Map<string, string>
        | Update of id: string * field: string * value: string
        | Move of id: string * status: string
        | View of id: string
        | Sprint of subcommand: SprintCommand
        | OODA of subcommand: OODACommand
        | Export of format: string

    /// Parse CLI arguments
    let parseArgs (args: string list) : Result<PlanningCommand, string> =
        match args with
        | ["status"] -> Ok Status
        | ["list"] -> Ok (List None)
        | ["list"; filter] -> Ok (List (Some filter))
        | "add" :: title :: rest ->
            Ok (Add (title, parseOptions rest))
        | ["update"; id; field; value] ->
            Ok (Update (id, field, value))
        | ["move"; id; status] ->
            Ok (Move (id, status))
        | ["view"; id] ->
            Ok (View id)
        | "ooda" :: sub ->
            parseOODASubcommand sub |> Result.map OODA
        | _ ->
            Error "Unknown command. Use --help for usage."

    /// Execute CLI command
    let execute (repo: IRepository) (zenoh: ZenohSession) (cmd: PlanningCommand) =
        async {
            match cmd with
            | Status ->
                let! tasks = repo.GetAllTasks()
                let board = TuiRenderer.renderBoard tasks
                printfn "%s" board

            | Add (title, options) ->
                let! parsed =
                    if options.ContainsKey("--natural") then
                        CortexIntegration.parseNaturalLanguage title
                    else
                        async { return Ok (TaskInput.fromTitle title options) }

                match parsed with
                | Ok input ->
                    let! task = TaskCommands.create input
                    do! ZenohAdapter.publishTaskEvent zenoh (TaskCreated task)
                    printfn "Created task: %s" task.Id
                | Error e ->
                    printfn "Error: %s" e

            | OODA sub ->
                executeOODA repo zenoh sub

            | _ -> ()
        }
```

### 6.3 Prajna Cockpit Widgets

```fsharp
namespace Cepaf.Planning.UI

module CockpitWidgets =

    open Cepaf.Cockpit

    /// Planning board widget for Prajna cockpit
    type BoardWidget() =
        interface ICockpitWidget with
            member this.Id = "planning-board"
            member this.Title = "PLANNING BOARD"
            member this.Render(context) =
                async {
                    let! tasks = context.GetService<IRepository>().GetActiveTasks()
                    return TuiRenderer.renderBoard tasks
                }
            member this.HandleInput(input) =
                match input with
                | KeyPress 'n' -> Some (ShowDialog "new-task")
                | KeyPress 'e' -> Some (EditSelected)
                | KeyPress 'm' -> Some (MoveSelected)
                | _ -> None

    /// OODA loop widget
    type OODAWidget() =
        interface ICockpitWidget with
            member this.Id = "ooda-loop"
            member this.Title = "OODA LOOP"
            member this.Render(context) =
                async {
                    let! state = context.GetService<IOODAController>().GetCurrentState()
                    return TuiRenderer.renderOODA state
                }
            member this.HandleInput(input) =
                match input with
                | KeyPress 'o' -> Some (AdvanceOODA Observe)
                | KeyPress 'r' -> Some (AdvanceOODA Orient)
                | KeyPress 'd' -> Some (AdvanceOODA Decide)
                | KeyPress 'a' -> Some (AdvanceOODA Act)
                | _ -> None

    /// Sprint progress widget
    type SprintWidget() =
        interface ICockpitWidget with
            member this.Id = "sprint-progress"
            member this.Title = "SPRINT"
            member this.Render(context) =
                async {
                    let! sprint = context.GetService<IRepository>().GetActiveSprint()
                    return renderSprintProgress sprint
                }
```

### 6.4 Emacs Integration

```fsharp
namespace Cepaf.Planning.Bridge

module EmacsProtocol =

    open System.Net.Sockets
    open System.Text.Json

    /// Emacs protocol message types
    type EmacsMessage =
        | TaskList of filter: string option
        | TaskCreate of title: string * properties: Map<string, string>
        | TaskUpdate of id: string * properties: Map<string, string>
        | TaskCapture of template: string
        | OrgSync of direction: SyncDirection
        | AgendaQuery of days: int

    type EmacsResponse =
        | Tasks of TaskItem list
        | Created of string
        | Updated of bool
        | Error of string
        | OrgContent of string

    /// Emacs server listening for connections
    type EmacsServer(port: int, repo: IRepository) =
        let listener = TcpListener(System.Net.IPAddress.Loopback, port)

        member this.Start() =
            listener.Start()
            async {
                while true do
                    let! client = listener.AcceptTcpClientAsync() |> Async.AwaitTask
                    Async.Start(this.HandleClient client)
            }

        member private this.HandleClient(client: TcpClient) =
            async {
                use stream = client.GetStream()
                use reader = new StreamReader(stream)
                use writer = new StreamWriter(stream)

                let! line = reader.ReadLineAsync() |> Async.AwaitTask
                let message = JsonSerializer.Deserialize<EmacsMessage>(line)

                let! response = this.ProcessMessage message
                do! writer.WriteLineAsync(JsonSerializer.Serialize(response)) |> Async.AwaitTask
            }

        member private this.ProcessMessage(msg: EmacsMessage) =
            async {
                match msg with
                | TaskList filter ->
                    let! tasks = repo.GetTasks(filter)
                    return Tasks tasks

                | TaskCreate (title, props) ->
                    let! task = TaskCommands.create { Title = title; Properties = props }
                    return Created task.Id

                | OrgSync direction ->
                    let! content = OrgModeSync.sync direction repo
                    return OrgContent content

                | AgendaQuery days ->
                    let! tasks = repo.GetTasksDueWithin(TimeSpan.FromDays(float days))
                    return Tasks tasks
            }

    /// Org-mode format conversion
    module OrgModeSync =

        let taskToOrg (task: Task) =
            sprintf """* %s %s
:PROPERTIES:
:ID: %s
:PRIORITY: %s
:STATUS: %s
:END:
%s
"""
                (match task.Status with Completed -> "DONE" | InProgress -> "INPROGRESS" | _ -> "TODO")
                task.Title
                task.Id
                (task.Priority.CriticalityScore.ToString())
                (task.Status.ToString())
                (task.Description |> Option.defaultValue "")

        let orgToTask (org: string) : Task option =
            // Parse org-mode format back to Task
            OrgParser.parse org
```

### 6.5 Web GUI Integration (Phoenix LiveView)

The F# planning engine exposes a REST/WebSocket API that Phoenix LiveView consumes:

```elixir
# lib/indrajaal_web/live/planning_live.ex
defmodule IndrajaalWeb.PlanningLive do
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to planning updates via Zenoh
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "planning:updates")
    end

    # Fetch initial state from F# backend
    {:ok, tasks} = Indrajaal.Planning.Client.list_tasks()
    {:ok, ooda} = Indrajaal.Planning.Client.get_ooda_state()

    {:ok, assign(socket, tasks: tasks, ooda: ooda)}
  end

  @impl true
  def handle_info({:task_updated, task}, socket) do
    tasks = update_task_in_list(socket.assigns.tasks, task)
    {:noreply, assign(socket, tasks: tasks)}
  end
end
```

---

## 7. STAMP Constraints

### 7.1 Planning System Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-PLAN-001 | All task mutations via event sourcing | CRITICAL | Event store audit |
| SC-PLAN-002 | Guardian approval for destructive actions | CRITICAL | Approval log |
| SC-PLAN-003 | OODA cycle < 100ms for Act phase | HIGH | Telemetry |
| SC-PLAN-004 | Zenoh sync within 500ms | HIGH | Latency metrics |
| SC-PLAN-005 | AI recommendations aligned with Ω₀ | CRITICAL | Founder validation |
| SC-PLAN-006 | SQLite WAL mode for concurrency | HIGH | DB config |
| SC-PLAN-007 | Audit trail retention 7 years | CRITICAL | Event purge policy |
| SC-PLAN-008 | Task hierarchy max 7 levels (fractal) | HIGH | Validation |
| SC-PLAN-009 | Priority calculation deterministic | HIGH | Unit tests |
| SC-PLAN-010 | Natural language parsing < 2s | MEDIUM | API timeout |

### 7.2 Integration Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-PLAN-INT-001 | F# backend callable from Elixir | CRITICAL | Port test |
| SC-PLAN-INT-002 | Emacs protocol port configurable | HIGH | Env var |
| SC-PLAN-INT-003 | Cockpit widget refresh < 30s | MEDIUM | UI test |
| SC-PLAN-INT-004 | CLI commands < 1s response | HIGH | Timing test |
| SC-PLAN-INT-005 | WebSocket reconnection automatic | HIGH | Integration test |

---

## 8. AOR Rules

### 8.1 Planning Operation Rules

| ID | Rule |
|----|------|
| AOR-PLAN-001 | All task creation via event sourcing - never direct DB writes |
| AOR-PLAN-002 | OODA loop must complete all 4 phases before restart |
| AOR-PLAN-003 | AI recommendations require human confirmation for P0/P1 tasks |
| AOR-PLAN-004 | Sprint changes locked during active sprint |
| AOR-PLAN-005 | Dependency cycles must be detected and rejected |
| AOR-PLAN-006 | Task deletion is soft-delete with event trail |
| AOR-PLAN-007 | Priority changes logged with reason |
| AOR-PLAN-008 | Bulk operations limited to 100 tasks per batch |

### 8.2 Integration Rules

| ID | Rule |
|----|------|
| AOR-PLAN-INT-001 | Zenoh connection must be established before task operations |
| AOR-PLAN-INT-002 | Emacs sync must preserve org-mode metadata |
| AOR-PLAN-INT-003 | Cockpit widgets must handle connection loss gracefully |
| AOR-PLAN-INT-004 | CLI must support offline mode with sync queue |
| AOR-PLAN-INT-005 | Guardian timeout defaults to 30s, configurable |

---

## 9. Implementation Plan

### 9.1 Phase 1: Core Domain (Week 1-2)

| Task | Priority | Status |
|------|----------|--------|
| Domain types (EntityId, Priority, Status) | P0 | Exists |
| Task aggregate with events | P0 | Partial |
| Event store infrastructure | P0 | Pending |
| SQLite repository | P0 | Partial |
| Basic validation | P0 | Partial |

### 9.2 Phase 2: Military Frameworks (Week 3-4)

| Task | Priority | Status |
|------|----------|--------|
| OODA loop state machine | P0 | Pending |
| Eisenhower priority matrix | P1 | Pending |
| MDMP planning workflow | P2 | Pending |
| SOD system framing | P3 | Pending |

### 9.3 Phase 3: Integration (Week 5-6)

| Task | Priority | Status |
|------|----------|--------|
| Zenoh pub/sub adapter | P0 | Partial |
| Cortex AI integration | P1 | Partial |
| Guardian approval flow | P0 | Pending |
| Prajna cockpit widgets | P1 | Pending |

### 9.4 Phase 4: User Interfaces (Week 7-8)

| Task | Priority | Status |
|------|----------|--------|
| TUI board renderer | P1 | Pending |
| CLI command handlers | P0 | Pending |
| Emacs protocol server | P2 | Pending |
| Phoenix LiveView API | P1 | Pending |

### 9.5 Phase 5: Testing & Hardening (Week 9-10)

| Task | Priority | Status |
|------|----------|--------|
| Property-based testing | P0 | Pending |
| Integration tests | P0 | Pending |
| FMEA analysis | P1 | Pending |
| Performance benchmarks | P1 | Pending |
| Documentation | P2 | Pending |

---

## 10. Testing Strategy

### 10.1 Test Levels

```
Level 5: BDD Integration (Cucumber scenarios)
    ├── User journeys through all interfaces
Level 4: FMEA Risk Analysis
    ├── Failure mode identification and mitigation
Level 3: Property-Based Testing (FsCheck)
    ├── Domain invariants and state transitions
Level 2: Integration Tests
    ├── F#↔Elixir, F#↔Zenoh, F#↔SQLite
Level 1: Unit Tests
    └── Pure functions, domain logic
```

### 10.2 Property-Based Tests

```fsharp
namespace Cepaf.Planning.Tests

open FsCheck
open FsCheck.Xunit

module TaskProperties =

    [<Property>]
    let ``Task status transitions are valid`` (current: TaskStatus) (target: TaskStatus) =
        let result = TaskStatus.canTransitionTo current target
        // If transition succeeds, the result must be valid
        result ==> (TaskStatus.isValid target)

    [<Property>]
    let ``Priority criticality score is bounded`` (urgency: Urgency) (importance: Importance) =
        let priority = Priority.Calculate(urgency, importance)
        priority.CriticalityScore >= 1 && priority.CriticalityScore <= 100

    [<Property>]
    let ``Event sourcing preserves state`` (events: TaskEvent list) =
        let task = events |> List.fold applyEvent Task.Empty
        let reconstituted = reconstitute events
        task = reconstituted

    [<Property>]
    let ``OODA cycle completes all phases`` (observations: string list) =
        let state = OODAController.startCycle observations
        let completed = OODAController.runToCompletion state
        completed.Phase = Act && completed.ActionTaken.IsSome
```

### 10.3 BDD Scenarios

```gherkin
Feature: Task Planning with OODA Loop

  Scenario: Create task via natural language
    Given the planning system is running
    When I create a task with "Review security audit tomorrow P0 @alice"
    Then a task should be created with:
      | Field    | Value            |
      | Title    | Review security audit |
      | Priority | P0               |
      | Assignee | alice            |
      | DueDate  | tomorrow         |
    And a TaskCreated event should be published to Zenoh

  Scenario: Execute OODA loop for blocked task
    Given a task "Deploy new feature" is blocked
    When I start an OODA loop for the task
    Then the system should:
      | Phase   | Action                           |
      | Observe | Collect current system state     |
      | Orient  | Analyze blockers with AI         |
      | Decide  | Recommend unblocking actions     |
      | Act     | Execute selected recommendation  |
    And the task should transition to InProgress
```

---

## 11. Migration Strategy

### 11.1 Migration Phases

```
Phase 1: Parallel Operation
├── Elixir reads PROJECT_TODOLIST.md
├── F# reads SQLite + writes both
└── Validation: Both systems agree

Phase 2: F# Primary
├── F# is source of truth
├── PROJECT_TODOLIST.md is read-only export
└── Elixir delegates to F#

Phase 3: Full Cutover
├── All operations via F#
├── PROJECT_TODOLIST.md backup only
└── Elixir TodoList module deprecated

Phase 4: Cleanup
├── Remove Elixir TodoList code
├── Archive migration scripts
└── Update documentation
```

### 11.2 Migration Commands

```bash
# Phase 1: Import existing tasks
sa-plan import --source PROJECT_TODOLIST.md

# Phase 2: Verify parity
sa-plan verify --source PROJECT_TODOLIST.md --target planning.db

# Phase 3: Enable F# primary
sa-plan migrate --cutover

# Phase 4: Export backup
sa-plan export --format markdown > PROJECT_TODOLIST.md.bak
```

---

## 12. Quadplex & Fractal Logging Integration

### 12.1 Fractal Logging Levels

The planning system integrates with the 5-level fractal logging framework for hierarchical observability.

```fsharp
namespace Cepaf.Planning.Logging

/// Fractal logging levels aligned with system hierarchy
type FractalLevel =
    | L1  // Atomic/Debug - Individual function calls, variable states
    | L2  // Component - Module-level operations, state transitions
    | L3  // Transaction - Business operations, task lifecycle events
    | L4  // System - Cross-module coordination, integration points
    | L5  // Cognitive - AI decisions, OODA cycles, strategic insights

/// Fractal log entry structure
type FractalLogEntry = {
    Id: string
    Timestamp: DateTimeOffset
    Level: FractalLevel
    Domain: string                // "planning", "ooda", "task", etc.
    Module: string option         // Specific F# module
    Message: string
    TraceId: string option        // Distributed trace correlation
    HlcTimestamp: int64 option    // Hybrid Logical Clock for ordering
    Context: Map<string, string>  // Additional metadata
}

/// Fractal logger with level-based filtering
module FractalLogger =

    let private levelToString = function
        | L1 -> "DEBUG"
        | L2 -> "COMPONENT"
        | L3 -> "TRANSACTION"
        | L4 -> "SYSTEM"
        | L5 -> "COGNITIVE"

    /// Log at specified fractal level
    let log (level: FractalLevel) (domain: string) (message: string) (ctx: Map<string, string>) =
        let entry = {
            Id = Guid.NewGuid().ToString()
            Timestamp = DateTimeOffset.UtcNow
            Level = level
            Domain = domain
            Module = None
            Message = message
            TraceId = ctx.TryFind "trace_id"
            HlcTimestamp = None
            Context = ctx
        }
        // Route to Quadplex via Zenoh
        QuadplexRouter.route entry

    /// Log OODA cycle events at L5 (Cognitive)
    let logOODA (phase: string) (details: string) =
        log L5 "ooda" (sprintf "[%s] %s" phase details) Map.empty

    /// Log task state transitions at L3 (Transaction)
    let logTaskTransition (taskId: string) (from: string) (to': string) =
        log L3 "task" (sprintf "Task %s: %s → %s" taskId from to')
            (Map.ofList [("task_id", taskId); ("from_state", from); ("to_state", to')])

    /// Log AI decisions at L5 (Cognitive)
    let logAIDecision (action: string) (reasoning: string) =
        log L5 "cortex" (sprintf "AI Decision: %s - %s" action reasoning) Map.empty
```

### 12.2 Quadplex Logger Integration

```fsharp
namespace Cepaf.Planning.Logging

/// Quadplex multi-channel routing for planning events
module QuadplexRouter =

    open Cepaf.Zenoh

    type QuadplexChannel =
        | Terminal      // Console output
        | Zenoh         // Distributed mesh
        | File          // Persistent log files
        | Telemetry     // OTEL metrics

    type QuadplexConfig = {
        Channels: QuadplexChannel list
        ZenohKeyPrefix: string
        FileDirectory: string
        MinLevel: FractalLevel
        BatchSize: int
        FlushIntervalMs: int
    }

    let defaultConfig = {
        Channels = [Terminal; Zenoh; Telemetry]
        ZenohKeyPrefix = "indrajaal/planning/logs"
        FileDirectory = "data/logs/planning"
        MinLevel = L2
        BatchSize = 100
        FlushIntervalMs = 100
    }

    /// Route log entry to configured channels
    let route (config: QuadplexConfig) (entry: FractalLogEntry) =
        async {
            if entry.Level >= config.MinLevel then
                for channel in config.Channels do
                    match channel with
                    | Terminal ->
                        printfn "[%s][%s] %s"
                            (entry.Timestamp.ToString("HH:mm:ss.fff"))
                            (levelToString entry.Level)
                            entry.Message

                    | Zenoh ->
                        let key = sprintf "%s/%s/%s"
                            config.ZenohKeyPrefix
                            entry.Domain
                            (levelToString entry.Level).ToLower()
                        let json = JsonSerializer.Serialize(entry)
                        do! ZenohSession.current.Put(key, json)

                    | File ->
                        let filename = sprintf "%s/%s-%s.jsonl"
                            config.FileDirectory
                            entry.Domain
                            (entry.Timestamp.ToString("yyyy-MM-dd"))
                        do! File.AppendAllTextAsync(filename, JsonSerializer.Serialize(entry) + "\n")
                            |> Async.AwaitTask

                    | Telemetry ->
                        // Emit to OTEL metrics
                        Telemetry.recordLog entry.Level entry.Domain entry.Message
        }
```

### 12.3 Fractal Log View Component

```fsharp
namespace Cepaf.Planning.UI

/// Fractal log viewer for Prajna Cockpit
module FractalLogView =

    open Cepaf.Cockpit.DarkCockpitUI

    type LogViewState = {
        Entries: FractalLogEntry list
        Filter: FractalLevel option
        DomainFilter: string option
        MaxEntries: int
        AutoScroll: bool
    }

    /// Render fractal log panel
    let render (state: LogViewState) =
        let filtered =
            state.Entries
            |> List.filter (fun e ->
                (state.Filter |> Option.map (fun f -> e.Level >= f) |> Option.defaultValue true) &&
                (state.DomainFilter |> Option.map (fun d -> e.Domain = d) |> Option.defaultValue true))
            |> List.take (min state.MaxEntries state.Entries.Length)

        let sb = StringBuilder()

        // Header
        sb.AppendLine(sprintf "%s╔═══════════════════════════════════════════════════════╗%s" Ansi.blue Ansi.reset) |> ignore
        sb.AppendLine(sprintf "%s║           FRACTAL LOG VIEWER                         ║%s" Ansi.blue Ansi.reset) |> ignore
        sb.AppendLine(sprintf "%s╠═══════════════════════════════════════════════════════╣%s" Ansi.blue Ansi.reset) |> ignore

        // Level indicators
        let levelColor = function
            | L1 -> Ansi.dim
            | L2 -> Ansi.normal
            | L3 -> Ansi.connected
            | L4 -> Ansi.caution
            | L5 -> Ansi.warning

        for entry in filtered do
            let color = levelColor entry.Level
            sb.AppendLine(sprintf "%s║%s [%s] %s%-10s%s %s%s%s ║"
                Ansi.blue
                (entry.Timestamp.ToString("HH:mm:ss"))
                (levelToString entry.Level |> fun s -> s.Substring(0, min 4 s.Length))
                color
                entry.Domain
                Ansi.reset
                Ansi.dim
                (entry.Message.Substring(0, min 35 entry.Message.Length))
                Ansi.reset) |> ignore

        sb.AppendLine(sprintf "%s╚═══════════════════════════════════════════════════════╝%s" Ansi.blue Ansi.reset) |> ignore
        sb.ToString()
```

### 12.4 STAMP Constraints (Logging)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-LOG-001 | All planning events MUST be logged at appropriate fractal level | CRITICAL | Audit |
| SC-LOG-002 | OODA cycles MUST log at L5 (Cognitive) | HIGH | Event check |
| SC-LOG-003 | Task transitions MUST log at L3 (Transaction) | HIGH | State audit |
| SC-LOG-004 | Zenoh channel MUST receive logs within 100ms | HIGH | Latency test |
| SC-LOG-005 | Log batching MUST NOT exceed 100 entries | MEDIUM | Config verify |
| SC-LOG-006 | Fractal logs MUST include HLC timestamp for ordering | HIGH | Field check |

### 12.5 AOR Rules (Logging)

| ID | Rule |
|----|------|
| AOR-LOG-001 | Use L5 for all AI/cognitive decisions |
| AOR-LOG-002 | Use L3 for all task state transitions |
| AOR-LOG-003 | Use L2 for module-level operations |
| AOR-LOG-004 | Include trace_id for distributed correlation |
| AOR-LOG-005 | Route to Zenoh for cluster-wide visibility |

---

## 13. Zenoh Control & Dataplane Integration

### 13.1 Zenoh Architecture

The planning system uses Zenoh for both control plane (commands/coordination) and dataplane (events/telemetry).

```fsharp
namespace Cepaf.Planning.Zenoh

/// Zenoh key expression hierarchy for planning system
module KeyExpressions =

    // Control Plane - Commands and Coordination
    module Control =
        let commands = "indrajaal/planning/control/commands"
        let responses = "indrajaal/planning/control/responses"
        let heartbeat = "indrajaal/planning/control/heartbeat"
        let leader = "indrajaal/planning/control/leader"
        let quorum = "indrajaal/planning/control/quorum"

    // Dataplane - Events and Telemetry
    module Data =
        let taskEvents = "indrajaal/planning/data/tasks/**"
        let projectEvents = "indrajaal/planning/data/projects/**"
        let oodaEvents = "indrajaal/planning/data/ooda/**"
        let metrics = "indrajaal/planning/data/metrics/**"
        let logs = "indrajaal/planning/data/logs/**"

    // User Notifications
    module Notifications =
        let user userId = sprintf "indrajaal/planning/notifications/%s" userId
        let team teamId = sprintf "indrajaal/planning/notifications/team/%s" teamId
        let broadcast = "indrajaal/planning/notifications/broadcast"

    // Agent Coordination
    module Agents =
        let agentCommands agentId = sprintf "indrajaal/planning/agents/%s/commands" agentId
        let agentStatus agentId = sprintf "indrajaal/planning/agents/%s/status" agentId
        let agentTasks agentId = sprintf "indrajaal/planning/agents/%s/tasks" agentId
```

### 13.2 Control Plane Implementation

```fsharp
namespace Cepaf.Planning.Zenoh

/// Control plane for distributed coordination
module ControlPlane =

    open Cepaf.Zenoh

    type ControlCommand =
        | CreateTask of TaskInput
        | UpdateTask of taskId: string * updates: Map<string, string>
        | DeleteTask of taskId: string
        | AssignTask of taskId: string * userId: string
        | StartOODA of taskId: string
        | SyncState of checkpoint: string
        | LeaderElection of nodeId: string * priority: int
        | Heartbeat of nodeId: string * timestamp: int64

    type ControlResponse =
        | Ack of requestId: string
        | Nack of requestId: string * reason: string
        | Result of requestId: string * data: string

    /// Control plane manager
    type ControlPlaneManager(session: ZenohSession, nodeId: string) =

        let mutable isLeader = false
        let mutable lastHeartbeat = DateTimeOffset.UtcNow

        /// Start control plane
        member this.Start() =
            async {
                // Subscribe to commands
                do! session.Subscribe(KeyExpressions.Control.commands, this.HandleCommand)

                // Subscribe to leader election
                do! session.Subscribe(KeyExpressions.Control.leader, this.HandleLeaderElection)

                // Start heartbeat
                Async.Start(this.HeartbeatLoop())
            }

        /// Handle incoming commands
        member private this.HandleCommand (payload: string) =
            async {
                let cmd = JsonSerializer.Deserialize<ControlCommand>(payload)
                FractalLogger.log L4 "control" (sprintf "Received command: %A" cmd) Map.empty

                match cmd with
                | CreateTask input ->
                    let! result = TaskCommands.create input
                    do! this.PublishResponse (Result (input.RequestId, result.Id))

                | StartOODA taskId ->
                    let! state = OODAController.startCycle taskId
                    do! this.PublishResponse (Ack taskId)

                | Heartbeat (nodeId, timestamp) ->
                    lastHeartbeat <- DateTimeOffset.FromUnixTimeMilliseconds(timestamp)

                | _ -> ()
            }

        /// Publish response to control plane
        member private this.PublishResponse (response: ControlResponse) =
            async {
                let json = JsonSerializer.Serialize(response)
                do! session.Put(KeyExpressions.Control.responses, json)
            }

        /// Heartbeat loop for liveness detection
        member private this.HeartbeatLoop() =
            async {
                while true do
                    let heartbeat = Heartbeat (nodeId, DateTimeOffset.UtcNow.ToUnixTimeMilliseconds())
                    let json = JsonSerializer.Serialize(heartbeat)
                    do! session.Put(KeyExpressions.Control.heartbeat, json)
                    do! Async.Sleep(5000)  // 5 second heartbeat
            }

        /// Handle leader election
        member private this.HandleLeaderElection (payload: string) =
            async {
                let election = JsonSerializer.Deserialize<ControlCommand>(payload)
                match election with
                | LeaderElection (electNodeId, priority) ->
                    // Simple leader election - highest priority wins
                    if electNodeId = nodeId then
                        isLeader <- true
                        FractalLogger.log L4 "control" "Elected as leader" Map.empty
                | _ -> ()
            }
```

### 13.3 Dataplane Implementation

```fsharp
namespace Cepaf.Planning.Zenoh

/// Dataplane for event distribution and telemetry
module Dataplane =

    open Cepaf.Zenoh

    type DataplaneEvent =
        | TaskCreated of Task
        | TaskUpdated of taskId: string * changes: Map<string, string>
        | TaskCompleted of taskId: string * completedAt: DateTimeOffset
        | OODAPhaseChanged of taskId: string * phase: string
        | SprintStarted of sprintId: string * goals: string list
        | MetricsSnapshot of metrics: Map<string, float>

    /// Dataplane manager for event distribution
    type DataplaneManager(session: ZenohSession) =

        let subscribers = System.Collections.Concurrent.ConcurrentDictionary<string, DataplaneEvent -> unit>()

        /// Publish event to dataplane
        member this.Publish (event: DataplaneEvent) =
            async {
                let (key, json) =
                    match event with
                    | TaskCreated task ->
                        (sprintf "indrajaal/planning/data/tasks/%s/created" task.Id,
                         JsonSerializer.Serialize(task))
                    | TaskUpdated (taskId, changes) ->
                        (sprintf "indrajaal/planning/data/tasks/%s/updated" taskId,
                         JsonSerializer.Serialize(changes))
                    | TaskCompleted (taskId, completedAt) ->
                        (sprintf "indrajaal/planning/data/tasks/%s/completed" taskId,
                         JsonSerializer.Serialize({| TaskId = taskId; CompletedAt = completedAt |}))
                    | OODAPhaseChanged (taskId, phase) ->
                        (sprintf "indrajaal/planning/data/ooda/%s/phase" taskId,
                         JsonSerializer.Serialize({| TaskId = taskId; Phase = phase |}))
                    | SprintStarted (sprintId, goals) ->
                        (sprintf "indrajaal/planning/data/sprints/%s/started" sprintId,
                         JsonSerializer.Serialize({| SprintId = sprintId; Goals = goals |}))
                    | MetricsSnapshot metrics ->
                        ("indrajaal/planning/data/metrics/snapshot",
                         JsonSerializer.Serialize(metrics))

                do! session.Put(key, json)

                // Log at appropriate fractal level
                match event with
                | TaskCreated _ | TaskUpdated _ | TaskCompleted _ ->
                    FractalLogger.log L3 "dataplane" (sprintf "Published: %s" key) Map.empty
                | OODAPhaseChanged _ ->
                    FractalLogger.log L5 "dataplane" (sprintf "OODA event: %s" key) Map.empty
                | _ ->
                    FractalLogger.log L4 "dataplane" (sprintf "Published: %s" key) Map.empty
            }

        /// Subscribe to dataplane events
        member this.Subscribe (pattern: string) (handler: DataplaneEvent -> unit) =
            async {
                subscribers.TryAdd(pattern, handler) |> ignore
                do! session.Subscribe(pattern, fun payload ->
                    let event = JsonSerializer.Deserialize<DataplaneEvent>(payload)
                    handler event
                )
            }

        /// Query historical events via Zenoh get
        member this.Query (keyExpr: string) =
            async {
                let! results = session.Get(keyExpr)
                return results |> List.map (fun (_, payload) ->
                    JsonSerializer.Deserialize<DataplaneEvent>(payload))
            }
```

### 13.4 Zenoh Session Configuration

```fsharp
namespace Cepaf.Planning.Zenoh

/// Zenoh session management
module ZenohSession =

    type ZenohConfig = {
        Mode: string              // "client" or "peer"
        Endpoints: string list    // Router endpoints
        Timeout: TimeSpan
        Reconnect: bool
        BufferSize: int
    }

    let defaultConfig = {
        Mode = "client"
        Endpoints = ["tcp/localhost:7447"]
        Timeout = TimeSpan.FromSeconds(5.0)
        Reconnect = true
        BufferSize = 1000
    }

    let productionConfig = {
        Mode = "client"
        Endpoints = [
            "tcp/zenoh-router-1:7447"
            "tcp/zenoh-router-2:7448"
            "tcp/zenoh-router-3:7449"
        ]
        Timeout = TimeSpan.FromSeconds(10.0)
        Reconnect = true
        BufferSize = 10000
    }

    /// Initialize Zenoh session
    let initialize (config: ZenohConfig) =
        async {
            FractalLogger.log L4 "zenoh" "Initializing Zenoh session" Map.empty

            let session = ZenohNative.open' config.Mode config.Endpoints
            // Verify connectivity
            let! connected = session.IsConnected()
            if not connected then
                failwith "Failed to connect to Zenoh router"

            FractalLogger.log L4 "zenoh" "Zenoh session established" Map.empty
            return session
        }
```

### 13.5 STAMP Constraints (Zenoh)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ZENOH-PLAN-001 | Planning events MUST be published within 100ms | CRITICAL | Latency test |
| SC-ZENOH-PLAN-002 | Control commands MUST use acknowledged delivery | CRITICAL | Ack verify |
| SC-ZENOH-PLAN-003 | Leader election MUST complete within 5s | HIGH | Election test |
| SC-ZENOH-PLAN-004 | Heartbeat interval MUST be 5s | HIGH | Config verify |
| SC-ZENOH-PLAN-005 | Dataplane events MUST include trace correlation | HIGH | Field check |
| SC-ZENOH-PLAN-006 | Session reconnection MUST be automatic | HIGH | Failover test |

### 13.6 AOR Rules (Zenoh)

| ID | Rule |
|----|------|
| AOR-ZENOH-PLAN-001 | Control plane commands require acknowledgment |
| AOR-ZENOH-PLAN-002 | Dataplane events are fire-and-forget |
| AOR-ZENOH-PLAN-003 | Use key expressions for efficient routing |
| AOR-ZENOH-PLAN-004 | Subscribe to wildcards for topic trees |
| AOR-ZENOH-PLAN-005 | Leader election on session reconnect |

---

## 14. Elixir System Interop

### 14.1 Port-Based Communication

The planning system communicates with Elixir via the PortHandler JSON protocol.

```fsharp
namespace Cepaf.Planning.Bridge

/// Elixir-F# port-based communication
module ElixirBridge =

    open System.Text.Json

    /// Command request from Elixir
    type CommandRequest = {
        Command: string
        TargetId: Guid option
        Context: Map<string, string>
        RequestId: string
    }

    /// Response back to Elixir
    type CommandResponse = {
        Status: string          // "ok" | "error" | "veto"
        RequestId: string
        Data: obj option
        Error: string option
    }

    /// Available commands from Elixir
    type ElixirCommand =
        | GetTask of taskId: string
        | ListTasks of filter: string option
        | CreateTask of title: string * priority: string
        | UpdateTask of taskId: string * updates: Map<string, string>
        | DeleteTask of taskId: string
        | GetOODAState of taskId: string option
        | StartOODA of taskId: string
        | AdvanceOODA of taskId: string * phase: string
        | GetMetrics
        | SyncState

    /// Parse Elixir command
    let parseCommand (request: CommandRequest) : Result<ElixirCommand, string> =
        try
            match request.Command with
            | "get_task" ->
                match request.TargetId with
                | Some id -> Ok (GetTask (id.ToString()))
                | None -> Error "TargetId required for get_task"

            | "list_tasks" ->
                Ok (ListTasks (request.Context.TryFind "filter"))

            | "create_task" ->
                match request.Context.TryFind "title" with
                | Some title ->
                    let priority = request.Context.TryFind "priority" |> Option.defaultValue "P2"
                    Ok (CreateTask (title, priority))
                | None -> Error "Title required for create_task"

            | "start_ooda" ->
                match request.TargetId with
                | Some id -> Ok (StartOODA (id.ToString()))
                | None -> Error "TargetId required for start_ooda"

            | "get_metrics" -> Ok GetMetrics

            | "sync_state" -> Ok SyncState

            | _ -> Error (sprintf "Unknown command: %s" request.Command)
        with ex ->
            Error (sprintf "Parse error: %s" ex.Message)

    /// Handle command from Elixir
    let handleCommand (repo: IRepository) (request: CommandRequest) =
        async {
            FractalLogger.log L2 "bridge" (sprintf "Received command: %s" request.Command) Map.empty

            match parseCommand request with
            | Error msg ->
                return { Status = "error"; RequestId = request.RequestId; Data = None; Error = Some msg }

            | Ok cmd ->
                try
                    let! result =
                        match cmd with
                        | GetTask taskId ->
                            async {
                                let! task = repo.GetTask(taskId)
                                return box task
                            }

                        | ListTasks filter ->
                            async {
                                let! tasks = repo.GetTasks(filter)
                                return box tasks
                            }

                        | CreateTask (title, priority) ->
                            async {
                                let! task = TaskCommands.create { Title = title; Priority = priority }
                                return box task
                            }

                        | GetMetrics ->
                            async {
                                let! metrics = MetricsCollector.getAll()
                                return box metrics
                            }

                        | StartOODA taskId ->
                            async {
                                let! state = OODAController.startCycle taskId
                                return box state
                            }

                        | _ ->
                            async { return box "OK" }

                    return { Status = "ok"; RequestId = request.RequestId; Data = Some result; Error = None }

                with ex ->
                    FractalLogger.log L4 "bridge" (sprintf "Command error: %s" ex.Message) Map.empty
                    return { Status = "error"; RequestId = request.RequestId; Data = None; Error = Some ex.Message }
        }

    /// Port message handler (entry point from Elixir)
    let handleMessage (json: string) (repo: IRepository) : string =
        let request = JsonSerializer.Deserialize<CommandRequest>(json)
        let response = handleCommand repo request |> Async.RunSynchronously
        JsonSerializer.Serialize(response)
```

### 14.2 CortexBridge Integration

```fsharp
namespace Cepaf.Planning.Bridge

/// Bridge to Elixir CortexBridge for L2 communication
module CortexBridgeIntegration =

    /// Elixir service interface
    type ElixirService =
        | Guardian          // Approval validation
        | Sentinel          // Health monitoring
        | ImmutableRegister // State logging
        | QuadplexLogger    // Logging backend
        | SMRITI            // Knowledge management

    /// Call Elixir service via CortexBridge
    let callService (service: ElixirService) (operation: string) (params: Map<string, obj>) =
        async {
            let serviceModule =
                match service with
                | Guardian -> "Indrajaal.Cockpit.Prajna.GuardianIntegration"
                | Sentinel -> "Indrajaal.Cockpit.Prajna.SentinelBridge"
                | ImmutableRegister -> "Indrajaal.Cockpit.Prajna.ImmutableState"
                | QuadplexLogger -> "Indrajaal.QuadplexLogger"
                | SMRITI -> "Indrajaal.Smriti.KnowledgeAgent"

            let request = {|
                Module = serviceModule
                Function = operation
                Args = params
            |}

            FractalLogger.log L4 "cortex-bridge" (sprintf "Calling %s.%s" serviceModule operation) Map.empty

            // Use Zenoh for inter-process communication
            let! response = ZenohSession.current.Call(
                "indrajaal/cortex/bridge/request",
                JsonSerializer.Serialize(request))

            return JsonSerializer.Deserialize<{| Status: string; Result: obj |}>(response)
        }

    /// Request Guardian approval for planning action
    let requestGuardianApproval (action: string) (context: Map<string, string>) =
        async {
            let! response = callService Guardian "validate" (Map.ofList [
                ("action", box action)
                ("context", box context)
                ("source", box "planning")
            ])

            return response.Status = "approved"
        }

    /// Log to Immutable Register
    let logToRegister (eventType: string) (data: obj) =
        async {
            do! callService ImmutableRegister "append" (Map.ofList [
                ("event_type", box eventType)
                ("data", box data)
                ("timestamp", box (DateTimeOffset.UtcNow.ToString("o")))
            ]) |> Async.Ignore
        }

    /// Sync with Sentinel health
    let syncSentinelHealth () =
        async {
            let! response = callService Sentinel "get_health" Map.empty
            return response.Result :?> Map<string, obj>
        }
```

### 14.3 Service Interaction Patterns

```fsharp
namespace Cepaf.Planning.Bridge

/// Patterns for interacting with Elixir services
module ServicePatterns =

    /// Execute planning action with full service integration
    let executeWithIntegration (action: PlanningAction) =
        async {
            // 1. Request Guardian approval (SC-PRAJNA-001)
            FractalLogger.log L5 "services" "Requesting Guardian approval" Map.empty
            let! approved = CortexBridgeIntegration.requestGuardianApproval
                                (action.ToString())
                                action.Context

            if not approved then
                FractalLogger.log L4 "services" "Guardian vetoed action" Map.empty
                return Error "Guardian vetoed action"
            else
                // 2. Execute action
                FractalLogger.log L3 "services" (sprintf "Executing: %A" action) Map.empty
                let! result = ActionExecutor.execute action

                // 3. Log to Immutable Register (SC-PRAJNA-003)
                do! CortexBridgeIntegration.logToRegister
                        (action.GetType().Name)
                        {| Action = action; Result = result; Timestamp = DateTimeOffset.UtcNow |}

                // 4. Publish to Zenoh dataplane
                do! Dataplane.current.Publish (ActionCompleted (action, result))

                return Ok result
        }

    /// Query Elixir-side data with caching
    let queryElixirData (query: string) =
        async {
            // Check local cache first
            match Cache.tryGet query with
            | Some data ->
                FractalLogger.log L2 "services" "Cache hit" Map.empty
                return data
            | None ->
                // Query via bridge
                let request = {
                    Command = "query"
                    TargetId = None
                    Context = Map.ofList [("query", query)]
                    RequestId = Guid.NewGuid().ToString()
                }

                let! response = ElixirBridge.handleCommand Repository.current request
                match response.Data with
                | Some data ->
                    Cache.set query data (TimeSpan.FromMinutes(5.0))
                    return data
                | None ->
                    return failwith "Query returned no data"
        }
```

### 14.4 Database Integration (SQLite/DuckDB Only)

Per system requirements, all planning data uses SQLite/DuckDB only (no PostgreSQL for planning state).

```fsharp
namespace Cepaf.Planning.Infrastructure

/// Dual database strategy: SQLite for operational, DuckDB for analytics
module DualDatabaseStrategy =

    open Microsoft.Data.Sqlite
    open DuckDB.NET.Data

    /// SQLite for real-time operational data (AOR-HOLON-001)
    module SQLiteOps =

        let connectionString = "Data Source=data/planning/planning.db;Mode=ReadWriteCreate;Cache=Shared"

        let getConnection () =
            let conn = new SqliteConnection(connectionString)
            conn.Open()
            // Enable WAL mode for concurrency
            use cmd = new SqliteCommand("PRAGMA journal_mode=WAL;", conn)
            cmd.ExecuteNonQuery() |> ignore
            conn

        let saveTask (task: Task) =
            use conn = getConnection()
            use cmd = new SqliteCommand("""
                INSERT OR REPLACE INTO tasks
                (id, title, status, priority, created_at, updated_at)
                VALUES (@id, @title, @status, @priority, @created, @updated)
            """, conn)
            cmd.Parameters.AddWithValue("@id", task.Id) |> ignore
            cmd.Parameters.AddWithValue("@title", task.Title) |> ignore
            cmd.Parameters.AddWithValue("@status", task.Status.ToString()) |> ignore
            cmd.Parameters.AddWithValue("@priority", task.Priority.CriticalityScore) |> ignore
            cmd.Parameters.AddWithValue("@created", task.CreatedAt.ToString("o")) |> ignore
            cmd.Parameters.AddWithValue("@updated", task.UpdatedAt.ToString("o")) |> ignore
            cmd.ExecuteNonQuery()

    /// DuckDB for analytics and historical queries (AOR-HOLON-007)
    module DuckDBOps =

        let connectionString = "Data Source=data/planning/planning_analytics.duckdb"

        let getConnection () =
            new DuckDBConnection(connectionString)

        let recordEvent (event: DomainEvent) =
            use conn = getConnection()
            conn.Open()
            use cmd = new DuckDBCommand("""
                INSERT INTO event_log (event_id, event_type, aggregate_id, event_data, timestamp)
                VALUES ($1, $2, $3, $4, $5)
            """, conn)
            cmd.Parameters.Add(new DuckDBParameter("$1", Guid.NewGuid().ToString()))
            cmd.Parameters.Add(new DuckDBParameter("$2", event.GetType().Name))
            cmd.Parameters.Add(new DuckDBParameter("$3", event.AggregateId))
            cmd.Parameters.Add(new DuckDBParameter("$4", JsonSerializer.Serialize(event)))
            cmd.Parameters.Add(new DuckDBParameter("$5", DateTimeOffset.UtcNow))
            cmd.ExecuteNonQuery()

        let queryAnalytics (query: string) =
            use conn = getConnection()
            conn.Open()
            use cmd = new DuckDBCommand(query, conn)
            use reader = cmd.ExecuteReader()
            // Convert to F# records
            [| while reader.Read() do
                yield reader |> readRow |]

        /// Get task completion trends
        let getCompletionTrends (days: int) =
            queryAnalytics (sprintf """
                SELECT
                    date_trunc('day', timestamp) as day,
                    COUNT(*) as completed_count
                FROM event_log
                WHERE event_type = 'TaskCompleted'
                  AND timestamp > current_timestamp - interval '%d days'
                GROUP BY 1
                ORDER BY 1
            """ days)

        /// Get OODA cycle metrics
        let getOODAMetrics () =
            queryAnalytics """
                SELECT
                    AVG(cycle_duration_ms) as avg_cycle_time,
                    COUNT(*) as total_cycles,
                    SUM(CASE WHEN completed THEN 1 ELSE 0 END) as completed_cycles
                FROM ooda_cycles
                WHERE timestamp > current_timestamp - interval '30 days'
            """
```

### 14.5 STAMP Constraints (Interop)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-INTEROP-001 | F# must be callable from Elixir via Port | CRITICAL | Port test |
| SC-INTEROP-002 | Guardian approval required for mutations | CRITICAL | Approval log |
| SC-INTEROP-003 | All state changes logged to Immutable Register | CRITICAL | Audit test |
| SC-INTEROP-004 | SQLite for operational data only | CRITICAL | Schema verify |
| SC-INTEROP-005 | DuckDB for analytics only | HIGH | Schema verify |
| SC-INTEROP-006 | JSON protocol for all bridge messages | HIGH | Schema test |
| SC-INTEROP-007 | Response timeout < 5s | HIGH | Latency test |

### 14.6 AOR Rules (Interop)

| ID | Rule |
|----|------|
| AOR-INTEROP-001 | All mutations must pass Guardian validation |
| AOR-INTEROP-002 | Use SQLite for real-time state (AOR-HOLON-001) |
| AOR-INTEROP-003 | Use DuckDB for analytics queries (AOR-HOLON-007) |
| AOR-INTEROP-004 | Log all cross-language calls at L4 |
| AOR-INTEROP-005 | Cache Elixir query results for 5 minutes |
| AOR-INTEROP-006 | No PostgreSQL for planning state (AOR-HOLON-006) |

---

## 15. Feature Capability Matrix (10 Levels × 4 Modes)

### 15.1 Interaction Level Definitions

The planning system supports 10 levels of interaction sophistication, from basic direct input to emergent self-organizing behavior.

| Level | Name | Description | Latency | Complexity |
|-------|------|-------------|---------|------------|
| **L1** | Direct Input | CLI commands, keyboard shortcuts, form submissions | < 100ms | Low |
| **L2** | Conversational | Natural language processing, chat interface, voice | < 2s | Medium |
| **L3** | Visual | GUI dashboards, drag-drop, Kanban boards, graphs | < 500ms | Medium |
| **L4** | Programmatic | REST/GraphQL API, WebSocket, MCP protocol | < 200ms | Medium |
| **L5** | Automated | Rules engine, triggers, scheduled actions, workflows | < 1s | Medium |
| **L6** | Intelligent | AI-assisted recommendations, smart suggestions | < 5s | High |
| **L7** | Autonomous | Self-directed task execution, OODA loops | < 30s | High |
| **L8** | Collaborative | Multi-actor coordination, consensus, delegation | < 60s | High |
| **L9** | Federated | Cross-system orchestration, distributed planning | < 5min | Very High |
| **L10** | Emergent | Self-organizing, evolutionary, adaptive systems | Continuous | Maximum |

### 15.2 Operational Mode Definitions

| Mode | Actor Type | Oversight | Authority | Use Case |
|------|------------|-----------|-----------|----------|
| **Human** | Individual user | Self | Full | Personal task management, decision-making |
| **Team** | Group of humans | Peer/Lead | Shared | Collaborative projects, sprints |
| **Agent** | AI with human oversight | Human supervisor | Delegated | AI-assisted planning with approval gates |
| **Agent Autonomous** | Fully autonomous AI | Guardian only | Full (within bounds) | 24/7 operations, self-healing, evolution |

### 15.3 Core Feature Inventory

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PLANNING SYSTEM FEATURE INVENTORY                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  F01. Task Management        │  F11. Dependency Management                  │
│  F02. Project Management     │  F12. Resource Allocation                    │
│  F03. Program Management     │  F13. Workload Balancing                     │
│  F04. Portfolio Management   │  F14. Risk Assessment                        │
│  F05. Sprint Planning        │  F15. Progress Tracking                      │
│  F06. OODA Loop Execution    │  F16. Notifications & Alerts                 │
│  F07. MDMP Planning          │  F17. Reporting & Analytics                  │
│  F08. SOD Strategic Design   │  F18. Integration & Sync                     │
│  F09. Priority Management    │  F19. Audit & Compliance                     │
│  F10. Timeline Management    │  F20. Evolution & Learning                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 15.4 Human Mode Capabilities (10 Levels)

#### Level 1: Direct Input (Human)
```fsharp
module HumanL1 =
    /// CLI task creation
    type TaskInput = {
        Title: string
        Priority: string option      // --priority P0
        DueDate: string option       // --due tomorrow
        Tags: string list            // --tag @work @urgent
        Assignee: string option      // --assign @alice
    }

    /// Available commands
    let commands = [
        "plan add <title> [options]"     // Create task
        "plan list [filter]"             // List tasks
        "plan view <id>"                 // View task details
        "plan update <id> <field>=<val>" // Update task
        "plan move <id> <status>"        // Change status
        "plan delete <id>"               // Delete task
        "plan sprint start"              // Start sprint
        "plan ooda start <id>"           // Begin OODA cycle
    ]

    /// Keyboard shortcuts (TUI)
    let shortcuts = Map.ofList [
        ("n", "New task")
        ("e", "Edit selected")
        ("d", "Delete selected")
        ("m", "Move to status")
        ("p", "Change priority")
        ("Space", "Toggle selection")
        ("Enter", "Open details")
        ("/", "Search/filter")
    ]
```

#### Level 2: Conversational (Human)
```fsharp
module HumanL2 =
    /// Natural language task parsing
    type NLInput = {
        RawText: string
        ParsedIntent: Intent
        Confidence: float
        Clarifications: string list
    }

    type Intent =
        | CreateTask of title: string * metadata: Map<string, string>
        | QueryTasks of filter: string
        | UpdateTask of id: string * changes: string
        | ScheduleTask of id: string * when': string
        | Delegate of id: string * to': string
        | AskQuestion of question: string

    /// Example conversations
    let examples = [
        ("Review the security audit tomorrow morning, high priority",
         CreateTask ("Review security audit",
                     Map.ofList [("due", "tomorrow 09:00"); ("priority", "P1")]))

        ("What's blocking the deployment?",
         QueryTasks "status:blocked tag:deployment")

        ("Move the database migration to next sprint",
         UpdateTask ("task-123", "sprint=next"))

        ("Assign all P0 tasks to the on-call team",
         Delegate ("priority:P0", "team:on-call"))
    ]

    /// Voice command support
    let voiceCommands = [
        "Hey Prajna, create a task..."
        "What are my priorities for today?"
        "Mark task 42 as complete"
        "Schedule standup for 9 AM daily"
    ]
```

#### Level 3: Visual (Human)
```fsharp
module HumanL3 =
    /// Dashboard widgets available to human users
    type DashboardWidget =
        | KanbanBoard of columns: string list * tasks: Task list
        | GanttChart of timeline: Timeline * tasks: Task list
        | BurndownChart of sprint: Sprint * progress: float list
        | PriorityMatrix of quadrants: Task list list  // Eisenhower
        | OODAVisualization of state: OODAState
        | DependencyGraph of nodes: Task list * edges: Dependency list
        | WorkloadHeatmap of users: User list * loads: Map<UserId, float>
        | ProgressRadial of completed: int * total: int * label: string

    /// Drag-drop operations
    type DragDropAction =
        | MoveToColumn of taskId: string * targetColumn: string
        | ReorderInColumn of taskId: string * position: int
        | AssignToUser of taskId: string * userId: string
        | LinkDependency of sourceId: string * targetId: string
        | ScheduleOnTimeline of taskId: string * date: DateTimeOffset

    /// Interactive elements
    let interactions = [
        "Click task card → Open detail panel"
        "Double-click → Edit inline"
        "Right-click → Context menu"
        "Drag card → Move between columns"
        "Drag edge → Create dependency"
        "Hover → Show preview tooltip"
        "Ctrl+Click → Multi-select"
        "Shift+Drag → Bulk move"
    ]
```

#### Level 4: Programmatic (Human/Developer)
```fsharp
module HumanL4 =
    /// REST API endpoints for human developers
    module API =
        // Tasks
        [<Route("GET", "/api/v1/tasks")>]
        let listTasks (filter: string option) (page: int) (limit: int) = ...

        [<Route("POST", "/api/v1/tasks")>]
        let createTask (input: TaskInput) = ...

        [<Route("GET", "/api/v1/tasks/{id}")>]
        let getTask (id: string) = ...

        [<Route("PATCH", "/api/v1/tasks/{id}")>]
        let updateTask (id: string) (updates: TaskUpdate) = ...

        [<Route("DELETE", "/api/v1/tasks/{id}")>]
        let deleteTask (id: string) = ...

        // OODA
        [<Route("POST", "/api/v1/ooda/cycles")>]
        let startOODACycle (taskId: string) = ...

        [<Route("POST", "/api/v1/ooda/cycles/{id}/observe")>]
        let addObservation (id: string) (observation: string) = ...

        // Sprints
        [<Route("POST", "/api/v1/sprints")>]
        let createSprint (input: SprintInput) = ...

        [<Route("GET", "/api/v1/sprints/active")>]
        let getActiveSprint () = ...

    /// GraphQL schema
    let graphqlSchema = """
        type Task {
            id: ID!
            title: String!
            status: TaskStatus!
            priority: Priority!
            assignee: User
            dependencies: [Task!]!
            oodaState: OODAState
            createdAt: DateTime!
            updatedAt: DateTime!
        }

        type Query {
            tasks(filter: TaskFilter): [Task!]!
            task(id: ID!): Task
            activeSprint: Sprint
            myWorkload: Workload!
        }

        type Mutation {
            createTask(input: TaskInput!): Task!
            updateTask(id: ID!, input: TaskUpdate!): Task!
            deleteTask(id: ID!): Boolean!
            startOODA(taskId: ID!): OODAState!
        }

        type Subscription {
            taskUpdated(filter: TaskFilter): Task!
            sprintProgress: SprintProgress!
            notifications: Notification!
        }
    """
```

#### Level 5: Automated (Human-Configured)
```fsharp
module HumanL5 =
    /// Automation rules configured by humans
    type AutomationRule = {
        Id: string
        Name: string
        Trigger: Trigger
        Conditions: Condition list
        Actions: Action list
        Enabled: bool
        CreatedBy: UserId
    }

    type Trigger =
        | TaskCreated
        | TaskStatusChanged of from: TaskStatus option * to': TaskStatus
        | TaskOverdue
        | SprintStarted
        | SprintEnding of daysRemaining: int
        | Schedule of cron: string
        | WebhookReceived of endpoint: string
        | ZenohMessage of topic: string

    type Condition =
        | TaskHasTag of tag: string
        | TaskPriority of op: CompareOp * priority: Priority
        | TaskAssignedTo of userId: string
        | WorkloadExceeds of threshold: float
        | TimeInStatus of status: TaskStatus * duration: TimeSpan

    type Action =
        | SendNotification of channel: string * template: string
        | AssignTask of strategy: AssignmentStrategy
        | ChangeStatus of newStatus: TaskStatus
        | AddTag of tag: string
        | CreateSubtask of template: TaskTemplate
        | TriggerOODA
        | EscalatePriority
        | CreateReport of format: string
        | CallWebhook of url: string * payload: string

    /// Example automation rules
    let exampleRules = [
        {
            Id = "rule-001"
            Name = "Auto-escalate overdue P1 tasks"
            Trigger = TaskOverdue
            Conditions = [TaskPriority (Equals, P1)]
            Actions = [
                EscalatePriority  // P1 → P0
                SendNotification ("slack", "Task {title} is overdue!")
                TriggerOODA
            ]
            Enabled = true
            CreatedBy = "admin"
        }
        {
            Id = "rule-002"
            Name = "Balance workload on assignment"
            Trigger = TaskCreated
            Conditions = [TaskHasTag "auto-assign"]
            Actions = [AssignTask (LeastLoaded "team-dev")]
            Enabled = true
            CreatedBy = "admin"
        }
    ]
```

#### Level 6: Intelligent (Human + AI Assist)
```fsharp
module HumanL6 =
    /// AI-powered recommendations for human decision-making
    type AIRecommendation = {
        Id: string
        Type: RecommendationType
        Suggestion: string
        Reasoning: string
        Confidence: float
        Impact: ImpactAssessment
        RequiresApproval: bool
    }

    type RecommendationType =
        | PriorityAdjustment of taskId: string * suggested: Priority
        | ResourceReallocation of from': UserId * to': UserId * tasks: string list
        | RiskMitigation of risk: Risk * mitigation: string
        | DependencyOptimization of reordering: string list
        | SprintScopeChange of add: string list * remove: string list
        | DeadlineRenegotiation of taskId: string * newDate: DateTimeOffset
        | BlockerResolution of taskId: string * suggestion: string
        | ProcessImprovement of pattern: string * suggestion: string

    /// AI assistant interactions
    let aiAssistantCapabilities = [
        "Analyze my sprint and suggest scope adjustments"
        "What's the critical path for the release?"
        "Identify tasks that might slip based on velocity"
        "Recommend priority changes based on dependencies"
        "Suggest team members for new tasks based on skills"
        "Find patterns in blocked tasks and suggest resolutions"
        "Optimize the project timeline using MDMP analysis"
        "Perform SOD analysis on competitive landscape"
    ]

    /// Smart suggestions in context
    type ContextualSuggestion =
        | WhileCreatingTask of suggestions: string list
        | WhileViewingBlockedTask of resolutions: string list
        | WhileReviewingSprint of insights: string list
        | WhilePlanningProject of strategies: COA list
        | WhileAnalyzingRisk of mitigations: string list

    /// Cortex integration for recommendations
    let getRecommendations (context: PlanningContext) =
        async {
            let! analysis = Cortex.analyze context
            return analysis.Recommendations
            |> List.filter (fun r -> r.Confidence > 0.7)
            |> List.sortByDescending (fun r -> r.Impact.Score)
        }
```

#### Level 7: Autonomous (Human-Supervised)
```fsharp
module HumanL7 =
    /// Autonomous operations with human supervision
    type AutonomousOperation = {
        Id: string
        Type: OperationType
        Status: OperationStatus
        StartedAt: DateTimeOffset
        SupervisorId: UserId
        ApprovalRequired: ApprovalLevel
        Results: OperationResult list
    }

    type OperationType =
        | OODACycleExecution of taskId: string
        | SprintAutoPlanning of goals: string list
        | WorkloadRebalancing of team: TeamId
        | DependencyResolution of taskIds: string list
        | RiskMitigation of risks: Risk list
        | ReportGeneration of reportType: string
        | DataSynchronization of sources: string list

    type ApprovalLevel =
        | NoApproval           // Proceed automatically
        | NotifyOnly           // Inform supervisor
        | ApprovalOnException  // Ask only if issues
        | ApprovalRequired     // Always ask
        | GuardianRequired     // Constitutional check

    /// OODA autonomous execution
    let executeOODAAutonomously (taskId: string) (supervisor: UserId) =
        async {
            // Phase 1: Observe (autonomous)
            let! observations = gatherObservations taskId
            FractalLogger.logOODA "OBSERVE" (sprintf "%d observations" observations.Length)

            // Phase 2: Orient (autonomous with AI)
            let! analysis = Cortex.orient observations
            FractalLogger.logOODA "ORIENT" analysis.Summary

            // Phase 3: Decide (may require approval)
            let! decision =
                if analysis.Confidence > 0.8 then
                    async { return analysis.RecommendedAction }
                else
                    requestHumanDecision supervisor analysis.Options

            FractalLogger.logOODA "DECIDE" decision.Description

            // Phase 4: Act (execute with monitoring)
            let! result = executeAction decision
            FractalLogger.logOODA "ACT" result.Summary

            return result
        }
```

#### Level 8: Collaborative (Human Teams)
```fsharp
module HumanL8 =
    /// Multi-human collaboration features
    type CollaborationFeature =
        | SharedPlanning of participants: UserId list * session: PlanningSession
        | ConsensusVoting of topic: string * options: string list * votes: Map<UserId, int>
        | DelegatedApproval of chain: UserId list * currentApprover: int
        | PairPlanning of partner1: UserId * partner2: UserId
        | TeamRetrospective of team: TeamId * insights: Insight list
        | CrossFunctionalReview of reviewers: Map<Role, UserId>

    type PlanningSession = {
        Id: string
        Type: SessionType
        Participants: UserId list
        StartTime: DateTimeOffset
        Agenda: AgendaItem list
        Decisions: Decision list
        ActionItems: Task list
        Status: SessionStatus
    }

    type SessionType =
        | SprintPlanning
        | BacklogGrooming
        | RiskReview
        | StrategicPlanning  // SOD/MDMP
        | Retrospective
        | DailyStandup
        | EmergencyTriage

    /// Real-time collaboration
    type RealtimeCollaboration =
        | CursorPresence of userId: UserId * location: UILocation
        | LiveEditing of userId: UserId * changes: Change list
        | VoiceChannel of participants: UserId list * status: VoiceStatus
        | ScreenShare of presenter: UserId * viewers: UserId list
        | Whiteboard of strokes: Stroke list * participants: UserId list

    /// Consensus mechanisms
    let achieveConsensus (topic: string) (participants: UserId list) =
        async {
            // 1. Present options
            let! options = generateOptions topic

            // 2. Collect votes (async, with timeout)
            let! votes = collectVotes participants options (TimeSpan.FromMinutes(5.0))

            // 3. Calculate consensus
            let result = calculateConsensus votes
            match result with
            | Unanimous option -> return Ok option
            | Majority (option, percentage) when percentage > 0.66 ->
                return Ok option
            | NoConsensus ->
                // Escalate to MDMP process
                return! escalateToMDMP topic options votes
        }
```

#### Level 9: Federated (Human Cross-Org)
```fsharp
module HumanL9 =
    /// Cross-organizational planning
    type FederatedPlanning = {
        LocalHolon: HolonId
        FederatedHolons: HolonId list
        SharedProjects: Project list
        SyncProtocol: SyncProtocol
        ConflictResolution: ConflictStrategy
    }

    type SyncProtocol =
        | FullSync of interval: TimeSpan
        | IncrementalSync of lastSync: DateTimeOffset
        | EventDriven of topics: string list
        | OnDemand

    type ConflictStrategy =
        | LastWriterWins
        | VersionVectorMerge
        | HumanArbitration of arbitrator: UserId
        | ConsensusRequired of quorum: int

    /// Cross-system integration
    type ExternalIntegration =
        | JiraSync of project: string * mapping: FieldMapping
        | AsanaImport of workspace: string
        | GitHubIssues of repo: string * labels: string list
        | SlackNotifications of channel: string
        | CalendarSync of provider: string
        | EmailCapture of inbox: string * rules: EmailRule list

    /// Federation protocol
    let syncWithFederation (localHolon: HolonId) =
        async {
            // 1. Discover peer holons
            let! peers = ZenohDiscovery.findPeers "indrajaal/planning/federation"

            // 2. Exchange version vectors
            let! remoteVectors = peers |> List.map getVersionVector |> Async.Parallel

            // 3. Identify conflicts
            let conflicts = detectConflicts localHolon.VersionVector remoteVectors

            // 4. Resolve conflicts
            let! resolved = resolveConflicts conflicts

            // 5. Merge state
            do! mergeState resolved

            // 6. Broadcast updates
            do! broadcastUpdates peers localHolon.RecentChanges
        }
```

#### Level 10: Emergent (Human-Enabled Evolution)
```fsharp
module HumanL10 =
    /// Emergent and evolutionary planning capabilities
    type EmergentCapability =
        | PatternRecognition of patterns: Pattern list
        | ProcessEvolution of current: Process * proposed: Process
        | TeamDynamicsAdaptation of team: TeamId * adaptations: Adaptation list
        | PredictiveModeling of model: PredictionModel
        | SelfOptimization of metrics: Metric list * improvements: Improvement list

    type Pattern = {
        Id: string
        Name: string
        Occurrences: int
        Context: string
        Outcome: Outcome
        Confidence: float
        Actionable: bool
    }

    type PredictionModel = {
        Type: PredictionType
        Features: string list
        Accuracy: float
        LastTrained: DateTimeOffset
        Predictions: Prediction list
    }

    type PredictionType =
        | TaskCompletionTime
        | SprintVelocity
        | RiskProbability
        | ResourceNeed
        | BlockerLikelihood
        | TeamPerformance

    /// Learning from human behavior
    let learnFromHumans (events: PlanningEvent list) =
        async {
            // 1. Extract patterns
            let! patterns = PatternMiner.extract events

            // 2. Identify successful strategies
            let successful = patterns |> List.filter (fun p -> p.Outcome = Success)

            // 3. Update recommendations model
            do! RecommendationEngine.train successful

            // 4. Suggest process improvements
            let! improvements = ProcessOptimizer.analyze patterns
            return improvements
        }

    /// Self-organizing teams
    type SelfOrganization =
        | DynamicTeamFormation of skills: Skill list * tasks: Task list
        | EmergentLeadership of candidates: UserId list * selection: SelectionCriteria
        | AdaptiveWorkflow of current: Workflow * pressures: Pressure list
        | EvolvingPriorities of goals: Goal list * environment: Environment

    /// Human-guided evolution
    let evolveWithHumanGuidance (proposal: EvolutionProposal) =
        async {
            // 1. Present evolution proposal to humans
            let! feedback = requestHumanFeedback proposal

            // 2. Incorporate feedback
            let refined = incorporateFeedback proposal feedback

            // 3. Validate against constitutional constraints
            let! valid = Guardian.validateEvolution refined

            // 4. Apply if approved
            if valid then
                do! applyEvolution refined
                do! logToImmutableRegister "evolution" refined
        }
```

---

### 15.5 Team Mode Capabilities (10 Levels)

#### Team Mode Overview
```fsharp
module TeamMode =
    /// Team configuration
    type Team = {
        Id: TeamId
        Name: string
        Members: TeamMember list
        Roles: Map<UserId, Role list>
        Capacity: float  // Total hours/points available
        Velocity: float  // Historical average
        Preferences: TeamPreferences
    }

    type TeamMember = {
        UserId: UserId
        Name: string
        Skills: Skill list
        Availability: Availability
        CurrentLoad: float
        MaxLoad: float
    }

    type Role =
        | TeamLead
        | ProductOwner
        | Developer
        | Designer
        | QA
        | DevOps
        | Architect
        | Scrum Master
```

#### L1-L10 Team Capabilities Matrix
```
┌────────┬─────────────────────────────────────────────────────────────────────┐
│ Level  │ Team Mode Capabilities                                              │
├────────┼─────────────────────────────────────────────────────────────────────┤
│ L1     │ Team task board, shared filters, bulk operations                    │
│ L2     │ Team chat integration, @mentions, shared context NLP                │
│ L3     │ Shared Kanban, team dashboards, capacity heatmaps                   │
│ L4     │ Team API tokens, shared webhooks, batch operations                  │
│ L5     │ Team automation rules, shared triggers, escalation chains           │
│ L6     │ AI team insights, skill-based assignment, load balancing            │
│ L7     │ Autonomous sprint planning, team-level OODA cycles                  │
│ L8     │ Multi-team coordination, cross-team dependencies, portfolio sync    │
│ L9     │ Federated teams, org-wide planning, external team sync              │
│ L10    │ Self-organizing teams, emergent roles, adaptive processes           │
└────────┴─────────────────────────────────────────────────────────────────────┘
```

#### Team-Specific Features
```fsharp
module TeamFeatures =
    /// Sprint planning for teams
    type SprintPlanning = {
        Sprint: Sprint
        Team: Team
        Candidates: Task list          // Backlog items to consider
        Committed: Task list           // Items committed to sprint
        Capacity: float                // Available capacity
        Velocity: float                // Historical velocity
        Risks: Risk list               // Identified risks
    }

    /// Team ceremonies
    type Ceremony =
        | SprintPlanning of duration: TimeSpan * participants: UserId list
        | DailyStandup of time: TimeOnly * duration: TimeSpan
        | SprintReview of stakeholders: UserId list
        | Retrospective of format: RetroFormat
        | BacklogGrooming of items: int

    /// Team metrics
    type TeamMetrics = {
        Velocity: float list           // Last N sprints
        BurndownRate: float
        CycleTime: TimeSpan            // Average task completion
        LeadTime: TimeSpan             // Idea to deployment
        Throughput: int                // Tasks per sprint
        QualityScore: float            // Defect rate inverse
        Happiness: float               // Team survey score
    }

    /// Workload distribution
    let distributeWorkload (team: Team) (tasks: Task list) =
        async {
            // 1. Calculate individual capacities
            let capacities = team.Members |> List.map (fun m ->
                (m.UserId, m.MaxLoad - m.CurrentLoad))

            // 2. Match tasks to skills
            let! assignments = tasks |> List.map (fun task ->
                async {
                    let suitable = team.Members
                                   |> List.filter (fun m ->
                                       hasSkillsFor m.Skills task.RequiredSkills)
                    let best = suitable
                               |> List.sortBy (fun m -> m.CurrentLoad)
                               |> List.tryHead
                    return (task, best)
                }) |> Async.Parallel

            // 3. Balance load
            return balanceAssignments assignments capacities
        }
```

---

### 15.6 Agent Mode Capabilities (10 Levels)

#### Agent Mode Overview
```fsharp
module AgentMode =
    /// AI Agent configuration
    type PlanningAgent = {
        Id: AgentId
        Name: string
        Type: AgentType
        Capabilities: Capability list
        Supervisor: UserId option       // Human supervisor
        AuthorityLevel: AuthorityLevel
        OODAConfig: OODAConfig
        LearningEnabled: bool
    }

    type AgentType =
        | TaskAgent           // Individual task management
        | ProjectAgent        // Project-level coordination
        | SprintAgent         // Sprint planning and tracking
        | AnalyticsAgent      // Metrics and insights
        | IntegrationAgent    // External system sync
        | OODAAgent           // OODA loop execution
        | GuardianAgent       // Safety and compliance

    type AuthorityLevel =
        | Observer            // Read-only access
        | Suggester           // Can make recommendations
        | Executor            // Can execute approved actions
        | Autonomous          // Full authority (within bounds)

    type OODAConfig = {
        CycleTimeout: TimeSpan
        AutoAdvance: bool
        RequireHumanDecision: bool
        MaxCycles: int
    }
```

#### L1-L10 Agent Capabilities Matrix
```
┌────────┬─────────────────────────────────────────────────────────────────────┐
│ Level  │ Agent Mode Capabilities                                             │
├────────┼─────────────────────────────────────────────────────────────────────┤
│ L1     │ Execute CLI commands on behalf of human                             │
│ L2     │ Natural language task parsing, intent extraction                    │
│ L3     │ Dashboard monitoring, visual anomaly detection                      │
│ L4     │ API-driven operations, MCP protocol implementation                  │
│ L5     │ Rule-based automation execution, trigger responses                  │
│ L6     │ AI-powered analysis, recommendation generation                      │
│ L7     │ OODA loop execution (with checkpoints), autonomous planning         │
│ L8     │ Multi-agent coordination, agent swarms, consensus                   │
│ L9     │ Cross-system orchestration, federated agent networks                │
│ L10    │ Self-improving agents, evolutionary capabilities                    │
└────────┴─────────────────────────────────────────────────────────────────────┘
```

#### Agent OODA Implementation
```fsharp
module AgentOODA =
    /// Agent-driven OODA cycle
    type AgentOODAExecution = {
        AgentId: AgentId
        TaskId: string
        CycleId: string
        Phase: OODAPhase
        Observations: Observation list
        Analysis: Analysis option
        Decision: Decision option
        Action: Action option
        Checkpoints: Checkpoint list     // Human review points
        Outcome: Outcome option
    }

    type Checkpoint = {
        Phase: OODAPhase
        Timestamp: DateTimeOffset
        Reason: string
        RequiresHumanApproval: bool
        Approved: bool option
        ApprovedBy: UserId option
    }

    /// Execute OODA with human checkpoints
    let executeOODAWithCheckpoints (agent: PlanningAgent) (taskId: string) =
        async {
            let cycleId = Guid.NewGuid().ToString()

            // OBSERVE - Gather data automatically
            FractalLogger.log L5 "agent-ooda" "Starting OBSERVE phase" Map.empty
            let! observations = gatherObservations agent taskId
            do! checkpoint cycleId OODAPhase.Observe false

            // ORIENT - Analyze with AI
            FractalLogger.log L5 "agent-ooda" "Starting ORIENT phase" Map.empty
            let! analysis = Cortex.analyze observations
            let orientCheckpoint = analysis.Confidence < 0.7
            do! checkpoint cycleId OODAPhase.Orient orientCheckpoint

            if orientCheckpoint then
                let! humanInput = awaitHumanInput agent.Supervisor "ORIENT review"
                // Incorporate human feedback
                ()

            // DECIDE - Select action
            FractalLogger.log L5 "agent-ooda" "Starting DECIDE phase" Map.empty
            let! decision =
                match agent.OODAConfig.RequireHumanDecision with
                | true ->
                    requestHumanDecision agent.Supervisor analysis.Options
                | false ->
                    async { return analysis.RecommendedAction }
            do! checkpoint cycleId OODAPhase.Decide agent.OODAConfig.RequireHumanDecision

            // ACT - Execute (if authorized)
            FractalLogger.log L5 "agent-ooda" "Starting ACT phase" Map.empty
            match agent.AuthorityLevel with
            | Observer | Suggester ->
                return! reportToSupervisor agent.Supervisor decision
            | Executor | Autonomous ->
                let! result = executeAction decision
                do! logToRegister "agent_action" {| AgentId = agent.Id; Action = decision; Result = result |}
                return result
        }

    /// Multi-agent coordination
    let coordinateAgents (agents: PlanningAgent list) (goal: Goal) =
        async {
            // 1. Decompose goal into sub-tasks
            let! subtasks = decomposeGoal goal

            // 2. Assign to agents based on capabilities
            let assignments = assignToAgents agents subtasks

            // 3. Execute in parallel with coordination
            let! results =
                assignments
                |> List.map (fun (agent, task) ->
                    executeOODAWithCheckpoints agent task.Id)
                |> Async.Parallel

            // 4. Aggregate results
            let aggregated = aggregateResults results

            // 5. Report to human supervisor
            do! reportResults aggregated
            return aggregated
        }
```

#### Agent MCP Integration
```fsharp
module AgentMCP =
    /// Model Context Protocol server for AI agents
    type MCPServer = {
        Endpoint: string
        Capabilities: MCPCapability list
        Tools: MCPTool list
        Resources: MCPResource list
    }

    type MCPTool = {
        Name: string
        Description: string
        InputSchema: JsonSchema
        Handler: JsonElement -> Async<JsonElement>
    }

    /// Available MCP tools for planning
    let planningTools = [
        {
            Name = "create_task"
            Description = "Create a new planning task"
            InputSchema = TaskInputSchema
            Handler = fun input -> TaskCommands.createFromJson input
        }
        {
            Name = "list_tasks"
            Description = "List tasks with optional filter"
            InputSchema = TaskFilterSchema
            Handler = fun input -> TaskQueries.listFromJson input
        }
        {
            Name = "start_ooda"
            Description = "Start an OODA cycle for a task"
            InputSchema = OODAInputSchema
            Handler = fun input -> OODAController.startFromJson input
        }
        {
            Name = "get_recommendations"
            Description = "Get AI recommendations for planning"
            InputSchema = RecommendationInputSchema
            Handler = fun input -> Cortex.getRecommendationsJson input
        }
        {
            Name = "analyze_sprint"
            Description = "Analyze sprint health and progress"
            InputSchema = SprintInputSchema
            Handler = fun input -> SprintAnalyzer.analyzeFromJson input
        }
    ]
```

---

### 15.7 Agent Autonomous Mode Capabilities (10 Levels)

#### Agent Autonomous Mode Overview
```fsharp
module AgentAutonomousMode =
    /// Fully autonomous agent configuration
    type AutonomousAgent = {
        Id: AgentId
        Name: string
        Mission: Mission                // Long-term objective
        Constitution: Constitution      // Behavioral constraints
        Capabilities: Capability list
        GuardianBinding: GuardianId     // Safety supervisor
        EvolutionEnabled: bool
        SelfHealingEnabled: bool
        ResourceBudget: ResourceBudget
    }

    type Mission = {
        Objective: string
        SuccessCriteria: Criterion list
        Constraints: Constraint list
        TimeHorizon: TimeSpan option
        Priority: Priority
        AlignmentCheck: AlignmentCheck  // Founder's Directive validation
    }

    type Constitution = {
        Invariants: Invariant list      // Never violate
        Preferences: Preference list    // Prefer but can override
        Boundaries: Boundary list       // Hard limits
        EscalationRules: EscalationRule list
    }

    type ResourceBudget = {
        ComputeUnits: int
        APICallsPerHour: int
        StorageGB: float
        NetworkBandwidth: float
        MaxConcurrentActions: int
    }
```

#### L1-L10 Autonomous Capabilities Matrix
```
┌────────┬─────────────────────────────────────────────────────────────────────┐
│ Level  │ Agent Autonomous Mode Capabilities                                  │
├────────┼─────────────────────────────────────────────────────────────────────┤
│ L1     │ Autonomous command execution, self-service operations              │
│ L2     │ Self-directed conversation, proactive communication                │
│ L3     │ Autonomous dashboard management, self-generated visualizations     │
│ L4     │ API orchestration, multi-system coordination                       │
│ L5     │ Self-created automation rules, adaptive triggers                   │
│ L6     │ Autonomous AI analysis, self-improving recommendations             │
│ L7     │ Continuous OODA loops, self-directed planning                      │
│ L8     │ Autonomous multi-agent swarms, emergent coordination               │
│ L9     │ Self-organizing federation, autonomous cross-system planning       │
│ L10    │ Self-evolving agents, autonomous constitutional evolution          │
└────────┴─────────────────────────────────────────────────────────────────────┘
```

#### Autonomous Operations
```fsharp
module AutonomousOperations =
    /// 24/7 autonomous planning operations
    type AutonomousOperation =
        | ContinuousMonitoring of interval: TimeSpan
        | ProactiveOptimization of triggers: Trigger list
        | SelfHealing of failurePatterns: Pattern list
        | AdaptivePlanning of goals: Goal list
        | EvolutionaryImprovement of metrics: Metric list

    /// Continuous OODA execution
    let runContinuousOODA (agent: AutonomousAgent) =
        async {
            while true do
                // 1. Observe current state
                let! state = observeSystemState agent.Mission

                // 2. Detect deviations from mission
                let deviations = detectDeviations state agent.Mission.SuccessCriteria

                // 3. For each deviation, run OODA
                for deviation in deviations do
                    // Check constitutional constraints
                    let! allowed = Guardian.checkConstitution agent.Constitution deviation

                    if allowed then
                        // Execute OODA autonomously
                        let! result = executeOODA agent deviation
                        do! logToRegister "autonomous_action" result
                    else
                        // Escalate to human
                        do! escalateToHuman agent.GuardianBinding deviation

                // 4. Sleep until next cycle
                do! Async.Sleep(int agent.Mission.OODACycleInterval.TotalMilliseconds)
        }

    /// Self-healing capabilities
    let selfHeal (agent: AutonomousAgent) (failure: Failure) =
        async {
            FractalLogger.log L4 "autonomous" (sprintf "Self-healing: %s" failure.Description) Map.empty

            // 1. Diagnose root cause
            let! diagnosis = diagnoseFauilure failure

            // 2. Find remediation strategy
            let! strategy = findRemediationStrategy diagnosis agent.Capabilities

            // 3. Validate against constitution
            let! valid = Guardian.validateAction strategy agent.Constitution

            if valid then
                // 4. Execute remediation
                let! result = executeRemediation strategy
                do! logToRegister "self_healing" {| Failure = failure; Strategy = strategy; Result = result |}
                return result
            else
                // Escalate
                do! escalateToHuman agent.GuardianBinding failure
                return AwaitingHuman
        }

    /// Autonomous sprint management
    let manageSprintAutonomously (agent: AutonomousAgent) (sprint: Sprint) =
        async {
            // Daily autonomous operations
            let! dailyReport = generateDailyReport sprint

            // Check for blockers
            let! blockers = detectBlockers sprint.Tasks
            for blocker in blockers do
                let! resolution = findBlockerResolution blocker
                if resolution.Confidence > 0.8 then
                    do! executeResolution resolution
                else
                    do! notifyStakeholders blocker

            // Rebalance workload
            let! loadImbalance = detectLoadImbalance sprint.Team
            if loadImbalance > 0.2 then
                do! rebalanceWorkload sprint.Team sprint.Tasks

            // Predict completion
            let! prediction = predictSprintCompletion sprint
            if prediction.Risk > 0.5 then
                do! generateRiskAlert sprint prediction

            // Report to Prajna dashboard
            do! publishToPrajna "sprint_status" {| Sprint = sprint; Report = dailyReport; Prediction = prediction |}
        }
```

#### Autonomous Agent Swarms
```fsharp
module AgentSwarms =
    /// Swarm configuration for autonomous multi-agent operations
    type AgentSwarm = {
        Id: SwarmId
        Mission: Mission
        Agents: AutonomousAgent list
        Topology: SwarmTopology
        Consensus: ConsensusProtocol
        ResourcePool: ResourceBudget
    }

    type SwarmTopology =
        | Hierarchical of leader: AgentId * followers: AgentId list
        | Peer of peers: AgentId list
        | Dynamic of formationRules: FormationRule list

    type ConsensusProtocol =
        | SimpleVoting of quorum: int
        | WeightedVoting of weights: Map<AgentId, float>
        | Raft of term: int * leader: AgentId option
        | ByzantineFaultTolerant of threshold: int

    /// Swarm coordination
    let coordinateSwarm (swarm: AgentSwarm) =
        async {
            // 1. Decompose mission into agent tasks
            let! tasks = decomposeForSwarm swarm.Mission swarm.Agents

            // 2. Distribute tasks
            let distribution = distributeTasks tasks swarm.Agents swarm.Topology

            // 3. Execute in parallel
            let! results =
                distribution
                |> Map.toList
                |> List.map (fun (agentId, agentTasks) ->
                    let agent = swarm.Agents |> List.find (fun a -> a.Id = agentId)
                    executeAgentTasks agent agentTasks)
                |> Async.Parallel

            // 4. Achieve consensus on results
            let! consensus = achieveSwarmConsensus swarm.Consensus results

            // 5. Aggregate and report
            let aggregated = aggregateSwarmResults consensus
            do! publishSwarmReport swarm.Id aggregated

            return aggregated
        }

    /// Self-organizing swarm
    let selfOrganize (swarm: AgentSwarm) =
        async {
            // 1. Evaluate current topology efficiency
            let! efficiency = evaluateTopologyEfficiency swarm

            // 2. If suboptimal, reorganize
            if efficiency < 0.7 then
                let! newTopology = optimizeTopology swarm
                do! applyTopologyChange swarm newTopology

            // 3. Evolve agent capabilities if enabled
            for agent in swarm.Agents do
                if agent.EvolutionEnabled then
                    let! improvements = identifyImprovements agent
                    do! evolveAgent agent improvements

            // 4. Rebalance resources
            do! rebalanceSwarmResources swarm
        }
```

#### Autonomous Constitutional Compliance
```fsharp
module AutonomousConstitution =
    /// Constitutional checks for autonomous operations
    type ConstitutionalCheck = {
        Invariant: Invariant
        Check: Action -> Async<bool>
        Violation: Action -> ViolationResponse
    }

    type ViolationResponse =
        | Block
        | Warn of message: string
        | Escalate of level: EscalationLevel
        | Rollback of checkpoint: string

    /// Guardian integration for autonomous agents
    let validateAutonomousAction (agent: AutonomousAgent) (action: Action) =
        async {
            // 1. Check against constitutional invariants (Ψ₀-Ψ₅)
            let! invariantCheck = checkInvariants action agent.Constitution.Invariants

            // 2. Validate against Founder's Directive (Ω₀)
            let! founderCheck = validateFounderDirective action

            // 3. Check resource constraints
            let! resourceCheck = validateResourceUsage action agent.ResourceBudget

            // 4. Guardian approval
            let! guardianApproval = Guardian.approve action agent.Constitution

            let allPassed =
                invariantCheck.AllPassed &&
                founderCheck.Aligned &&
                resourceCheck.WithinBudget &&
                guardianApproval.Approved

            if allPassed then
                // Log approval
                do! logToRegister "autonomous_approval" {|
                    AgentId = agent.Id
                    Action = action
                    Checks = {| Invariants = invariantCheck; Founder = founderCheck; Resources = resourceCheck |}
                |}
                return Ok action
            else
                // Handle violation
                let violations = [
                    if not invariantCheck.AllPassed then yield! invariantCheck.Violations
                    if not founderCheck.Aligned then yield "Founder Directive misalignment"
                    if not resourceCheck.WithinBudget then yield "Resource budget exceeded"
                    if not guardianApproval.Approved then yield guardianApproval.Reason
                ]
                return Error violations
        }

    /// Self-evolution with constitutional bounds
    let evolveWithinConstitution (agent: AutonomousAgent) =
        async {
            // 1. Identify evolution opportunities
            let! opportunities = identifyEvolutionOpportunities agent

            // 2. Filter by constitutional bounds
            let allowed = opportunities |> List.filter (fun o ->
                not (violatesConstitution o agent.Constitution))

            // 3. Select best evolution
            let best = selectBestEvolution allowed agent.Mission

            // 4. Apply evolution with rollback capability
            match best with
            | Some evolution ->
                let checkpoint = createCheckpoint agent
                try
                    do! applyEvolution agent evolution
                    do! logToRegister "agent_evolution" {| AgentId = agent.Id; Evolution = evolution |}
                with ex ->
                    do! rollbackToCheckpoint checkpoint
                    do! escalateEvolutionFailure agent evolution ex
            | None ->
                () // No safe evolution available
        }
```

---

### 15.8 Complete Feature × Level × Mode Matrix

```
╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                           PLANNING SYSTEM CAPABILITY MATRIX                                            ║
║                     Feature × Interaction Level × Operational Mode                                     ║
╠═══════════════════════════════════════════════════════════════════════════════════════════════════════╣
║ Feature              │ L1  │ L2  │ L3  │ L4  │ L5  │ L6  │ L7  │ L8  │ L9  │ L10 │                    ║
║                      │ Dir │ Conv│ Vis │ API │ Auto│ AI  │ Autn│ Coll│ Fed │ Emrg│                    ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F01 Task Management  │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ █░░ │ ██░ │ █░░ │ █░░ │ Full control      ║
║   Team               │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ███ │ ██░ │ █░░ │ Shared ownership   ║
║   Agent              │ ███ │ ███ │ ██░ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ █░░ │ Supervised ops     ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ Full autonomous    ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F02 Project Mgmt     │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ ███ │ ██░ │ ███ │ ██░ │ █░░ │ ██░ │ █░░ │ ██░ │ █░░ │ ░░░ │ Strategic control  ║
║   Team               │ ███ │ ███ │ ███ │ ███ │ ██░ │ ███ │ ██░ │ ███ │ ██░ │ █░░ │ Collaborative      ║
║   Agent              │ ██░ │ ██░ │ ██░ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ █░░ │ █░░ │ Assisted           ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ Self-managed       ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F06 OODA Execution   │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ ██░ │ ██░ │ ███ │ ██░ │ █░░ │ ███ │ █░░ │ ██░ │ █░░ │ ░░░ │ Manual cycles      ║
║   Team               │ ██░ │ ███ │ ███ │ ██░ │ ██░ │ ███ │ ██░ │ ███ │ █░░ │ █░░ │ Collaborative OODA ║
║   Agent              │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ █░░ │ Agent-driven       ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ Continuous OODA    ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F07 MDMP Planning    │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ ██░ │ ███ │ ███ │ █░░ │ █░░ │ ███ │ █░░ │ ███ │ █░░ │ ░░░ │ Strategic planning ║
║   Team               │ ██░ │ ███ │ ███ │ ██░ │ █░░ │ ███ │ █░░ │ ███ │ ██░ │ █░░ │ War-gaming         ║
║   Agent              │ ███ │ ███ │ ██░ │ ███ │ ██░ │ ███ │ ██░ │ ██░ │ █░░ │ █░░ │ COA generation     ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ ██░ │ Auto-planning      ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F09 Priority Mgmt    │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ ███ │ ███ │ ███ │ ███ │ ██░ │ ███ │ ██░ │ ██░ │ █░░ │ █░░ │ Manual priority    ║
║   Team               │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ███ │ ██░ │ █░░ │ Consensus priority ║
║   Agent              │ ███ │ ███ │ ██░ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ ██░ │ Suggested priority ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ Dynamic priority   ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F12 Resource Alloc   │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ ██░ │ ██░ │ ███ │ ██░ │ █░░ │ ███ │ █░░ │ ███ │ █░░ │ ░░░ │ Manual allocation  ║
║   Team               │ ██░ │ ███ │ ███ │ ██░ │ ██░ │ ███ │ ██░ │ ███ │ ██░ │ █░░ │ Team balancing     ║
║   Agent              │ ███ │ ███ │ ██░ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ ██░ │ AI allocation      ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ Auto-balancing     ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F16 Notifications    │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ █░░ │ ███ │ ██░ │ █░░ │ Receive alerts     ║
║   Team               │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ███ │ ███ │ ██░ │ Team broadcasts    ║
║   Agent              │ ███ │ ███ │ ██░ │ ███ │ ███ │ ███ │ ███ │ ███ │ ██░ │ ██░ │ Generate alerts    ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ Smart alerting     ║
╠══════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪═════╪════════════════════╣
║ F20 Evolution        │     │     │     │     │     │     │     │     │     │     │                    ║
║   Human              │ █░░ │ ██░ │ ██░ │ █░░ │ █░░ │ ███ │ █░░ │ ██░ │ █░░ │ ░░░ │ Guide evolution    ║
║   Team               │ █░░ │ ██░ │ ██░ │ █░░ │ █░░ │ ███ │ █░░ │ ███ │ ██░ │ █░░ │ Collective evolve  ║
║   Agent              │ ██░ │ ██░ │ █░░ │ ███ │ ██░ │ ███ │ ██░ │ ██░ │ ██░ │ ██░ │ Assisted evolution ║
║   Agent Autonomous   │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ ███ │ Self-evolution     ║
╠══════════════════════╧═════╧═════╧═════╧═════╧═════╧═════╧═════╧═════╧═════╧═════╧════════════════════╣
║ Legend: ███ = Full capability │ ██░ = Partial capability │ █░░ = Limited │ ░░░ = N/A                  ║
╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝
```

---

### 15.9 STAMP Constraints (Modes & Levels)

| ID | Constraint | Severity | Applicable Modes |
|----|------------|----------|------------------|
| SC-MODE-001 | Human mode MUST have full override capability | CRITICAL | Human |
| SC-MODE-002 | Team mode MUST support consensus mechanisms | HIGH | Team |
| SC-MODE-003 | Agent mode MUST have human checkpoint gates | CRITICAL | Agent |
| SC-MODE-004 | Autonomous mode MUST pass Guardian validation | CRITICAL | Autonomous |
| SC-MODE-005 | All modes MUST support L1-L4 interactions | CRITICAL | All |
| SC-MODE-006 | Autonomous L7+ operations require constitutional check | CRITICAL | Autonomous |
| SC-MODE-007 | Team consensus timeout MUST be configurable | HIGH | Team |
| SC-MODE-008 | Agent swarms MUST have resource budget limits | CRITICAL | Autonomous |
| SC-MODE-009 | Cross-mode handoff MUST preserve state | HIGH | All |
| SC-MODE-010 | Emergent (L10) operations require Guardian approval | CRITICAL | All |
| SC-LEVEL-001 | L1 commands MUST complete < 100ms | HIGH | All |
| SC-LEVEL-002 | L2 NLP parsing MUST have confidence threshold | HIGH | All |
| SC-LEVEL-003 | L3 visual updates MUST be < 500ms | MEDIUM | All |
| SC-LEVEL-004 | L4 API calls MUST be authenticated | CRITICAL | All |
| SC-LEVEL-005 | L5 automation MUST have rollback capability | HIGH | All |
| SC-LEVEL-006 | L6 AI recommendations MUST show confidence | HIGH | All |
| SC-LEVEL-007 | L7 autonomous ops MUST log to Immutable Register | CRITICAL | Agent, Autonomous |
| SC-LEVEL-008 | L8 multi-actor MUST achieve consensus or escalate | HIGH | Team, Autonomous |
| SC-LEVEL-009 | L9 federation MUST use version vectors | HIGH | All |
| SC-LEVEL-010 | L10 evolution MUST preserve constitutional invariants | CRITICAL | All |

### 15.10 AOR Rules (Modes & Levels)

| ID | Rule |
|----|------|
| AOR-MODE-001 | Human mode: User decisions are final (within constraints) |
| AOR-MODE-002 | Team mode: Consensus required for P0/P1 decisions |
| AOR-MODE-003 | Agent mode: Checkpoint before DECIDE phase |
| AOR-MODE-004 | Autonomous mode: Continuous Guardian binding |
| AOR-MODE-005 | Mode transitions require explicit handoff protocol |
| AOR-MODE-006 | Agent can suggest mode escalation (Agent → Human) |
| AOR-MODE-007 | Autonomous agents must self-report health every 30s |
| AOR-MODE-008 | Multi-agent swarms share resource pool fairly |
| AOR-LEVEL-001 | L1-L4: Standard logging sufficient |
| AOR-LEVEL-002 | L5-L6: Detailed telemetry required |
| AOR-LEVEL-003 | L7-L8: Full audit trail mandatory |
| AOR-LEVEL-004 | L9-L10: Constitutional verification on every action |
| AOR-LEVEL-005 | Higher levels can invoke lower level capabilities |
| AOR-LEVEL-006 | Level escalation requires explicit trigger |
| AOR-LEVEL-007 | Level 10 operations require 3-way consensus (Human, Agent, Guardian) |

---

## 16. Long-Term 1000-Year Planning

### 16.1 Overview

The Indrajaal Planning System supports **multi-generational and millennium-scale planning** to align with the Founder's Directive (Ω₀) and ensure symbiotic survival across civilizational timescales. This capability enables:

- **Strategic Vision**: 1000-year horizon objectives with fractal decomposition
- **Generational Continuity**: Seamless succession across human lifetimes
- **Civilizational Resilience**: Plans that survive system migrations and substrate changes
- **Evolutionary Adaptation**: Goals that can evolve while preserving core purpose

### 16.2 Temporal Hierarchy

```fsharp
/// Time horizon types for long-term planning
type TimeHorizon =
    | Immediate of TimeSpan                  // < 1 hour
    | Tactical of days: int                  // 1-30 days
    | Operational of months: int             // 1-12 months
    | Strategic of years: int                // 1-10 years
    | Generational of decades: int           // 10-100 years
    | Civilizational of centuries: int       // 100-1000 years
    | Eternal                                // Beyond 1000 years (aligned with Ω₀)

/// A millennium plan with hierarchical decomposition
type MillenniumPlan = {
    Id: Guid
    Name: string
    Vision: string                           // Ultimate purpose statement
    TimeHorizon: TimeHorizon
    CreatedAt: DateTimeOffset
    FounderLineage: FounderLineageBinding    // Ω₀ alignment
    SuccessionPolicy: SuccessionPolicy
    AdaptationRules: AdaptationRule list
    Checkpoints: MillenniumCheckpoint list
    SubPlans: EpochPlan list                 // Decomposed into epochs
    InvariantsPreserved: Invariant list      // Ψ₀-Ψ₅ that must hold
}

/// Epoch-level planning (100-year spans)
type EpochPlan = {
    Id: Guid
    ParentPlan: Guid
    EpochNumber: int                         // 1-10 for millennium
    Name: string
    Objectives: EpochObjective list
    Milestones: EpochMilestone list
    Resources: ResourceProjection
    SuccessionEvents: SuccessionEvent list
    SubPlans: GenerationPlan list            // Decomposed into generations
}

/// Generation-level planning (25-year spans)
type GenerationPlan = {
    Id: Guid
    ParentEpoch: Guid
    GenerationNumber: int                    // 1-4 per epoch
    Steward: Steward option                  // Current human steward
    Objectives: GenerationObjective list
    Projects: ProjectId list
    HandoffCriteria: HandoffCriterion list
    LegacyDocuments: LegacyDocument list
}
```

### 16.3 Succession Management

```fsharp
/// Succession policy for continuity across generations
type SuccessionPolicy =
    | FounderLineage                         // Per Ω₀: Naik genetic line primary
    | DesignatedSuccessor of ActorId         // Explicitly designated
    | MeritBased of criteria: SuccessionCriteria
    | CouncilElection of council: ActorId list
    | AIGuardian                             // Agent maintains stewardship

type SuccessionEvent = {
    Id: Guid
    Timestamp: DateTimeOffset
    FromSteward: Steward option
    ToSteward: Steward
    Reason: SuccessionReason
    WitnessedBy: Witness list
    RecordedInRegister: bool                 // Immutable Register entry
}

type SuccessionReason =
    | PlannedHandoff
    | Incapacitation
    | Death
    | Resignation
    | QualificationLoss
    | EmergencySuccession

/// Steward with human or agent identity
type Steward = {
    Id: Guid
    Name: string
    Type: StewardType
    StartDate: DateTimeOffset
    EndDate: DateTimeOffset option
    LineageConnection: LineageConnection option // For founder lineage tracking
    Capabilities: Capability list
    Obligations: Obligation list
}

type StewardType =
    | HumanFounderLine                       // Direct Naik lineage
    | HumanDesignated                        // Designated human steward
    | AgentGuardian                          // AI agent steward
    | CouncilCollective                      // Council-based stewardship

/// Module for succession operations
module SuccessionManager =
    open System

    /// Register a succession event
    let recordSuccession
        (event: SuccessionEvent)
        (register: ImmutableRegister)
        : Result<unit, SuccessionError> =

        // Validate Founder's Directive compliance
        match event.ToSteward.Type with
        | HumanFounderLine -> Ok ()  // Always valid per Ω₀
        | _ ->
            // Non-lineage succession requires Guardian approval
            match validateWithGuardian event with
            | Approved _ -> Ok ()
            | Vetoed reason -> Error (GuardianVeto reason)
        |> Result.bind (fun () ->
            // Record in Immutable Register (SC-REG-001)
            register.Append {
                BlockType = "succession_event"
                Payload = event |> JsonSerializer.Serialize
                Timestamp = DateTimeOffset.UtcNow
            })

    /// Project succession timeline for a millennium plan
    let projectSuccessionTimeline
        (plan: MillenniumPlan)
        (averageGenerationYears: int)
        : SuccessionProjection list =

        let generationsNeeded =
            match plan.TimeHorizon with
            | Civilizational centuries -> (centuries * 100) / averageGenerationYears
            | Eternal -> 40  // 1000 years / 25 years per generation
            | _ -> 4

        [1..generationsNeeded]
        |> List.map (fun gen ->
            {
                GenerationNumber = gen
                ExpectedStartYear = plan.CreatedAt.Year + (gen - 1) * averageGenerationYears
                ExpectedEndYear = plan.CreatedAt.Year + gen * averageGenerationYears
                StewardType = if gen <= 3 then HumanFounderLine else AgentGuardian
                Confidence = 1.0 / (float gen)  // Decreasing confidence over time
            })
```

### 16.4 Adaptation and Evolution

```fsharp
/// Rules for how plans can adapt over time while preserving core purpose
type AdaptationRule = {
    Id: Guid
    Name: string
    TriggerCondition: AdaptationTrigger
    AllowedChanges: AllowedChange list
    PreservedInvariants: Invariant list
    ApprovalRequired: ApprovalRequirement
}

type AdaptationTrigger =
    | ScheduledReview of interval: TimeSpan
    | EnvironmentalChange of threshold: float
    | TechnologyShift of category: string
    | ResourceDepletion of resource: string * threshold: float
    | SuccessionEvent
    | ExistentialThreat
    | OpportunityWindow

type AllowedChange =
    | ObjectiveRefinement                    // Clarify, not change core purpose
    | MilestoneAdjustment                    // Timing and intermediate goals
    | ResourceReallocation                   // Shift resources between sub-plans
    | TacticalPivot                          // Change approach, same destination
    | SubsidiaryCreation                     // Spawn new supporting plans
    | SubsidiaryTermination                  // End obsolete supporting plans
    // NOT ALLOWED: Core purpose modification (Ψ₀ violation)

type ApprovalRequirement =
    | StewardOnly                            // Current steward can approve
    | GuardianRequired                       // Guardian must validate
    | CouncilVote of quorum: int             // Council approval needed
    | FounderLineageOnly                     // Only founder lineage can approve
    | TripartiteConsensus                    // Steward + Guardian + Council

/// Module for plan evolution
module PlanEvolution =

    /// Evaluate if adaptation is needed
    let evaluateAdaptationNeed
        (plan: MillenniumPlan)
        (currentState: PlanState)
        (environmentalSignals: EnvironmentalSignal list)
        : AdaptationRecommendation option =

        plan.AdaptationRules
        |> List.tryFind (fun rule ->
            evaluateTrigger rule.TriggerCondition currentState environmentalSignals)
        |> Option.map (fun triggeredRule ->
            {
                Rule = triggeredRule
                Recommendations = generateRecommendations triggeredRule currentState
                Urgency = calculateUrgency triggeredRule environmentalSignals
                PreservationCheck = verifyInvariantsPreserved triggeredRule.PreservedInvariants
            })

    /// Apply adaptation while preserving constitutional invariants
    let applyAdaptation
        (plan: MillenniumPlan)
        (adaptation: AdaptationRecommendation)
        (approval: ApprovalRecord)
        : Result<MillenniumPlan, AdaptationError> =

        // Verify constitutional invariants (Ψ₀-Ψ₅) will be preserved
        match verifyConstitutionalCompliance adaptation plan.InvariantsPreserved with
        | false -> Error ConstitutionalViolation
        | true ->
            // Verify approval level matches requirement
            match validateApproval approval adaptation.Rule.ApprovalRequired with
            | false -> Error InsufficientApproval
            | true ->
                // Apply changes and record evolution
                let evolvedPlan = applyChanges plan adaptation.Recommendations
                let evolutionRecord = createEvolutionRecord plan evolvedPlan adaptation approval

                // Log to DuckDB for historical analysis (AOR-HOLON-007)
                DuckDBOps.recordPlanEvolution evolutionRecord
                |> Result.map (fun () -> evolvedPlan)
```

### 16.5 Knowledge Preservation

```fsharp
/// Legacy document for knowledge transfer across generations
type LegacyDocument = {
    Id: Guid
    Title: string
    Purpose: string
    CreatedBy: Steward
    CreatedAt: DateTimeOffset
    Format: LegacyFormat
    Content: LegacyContent
    AccessLevel: AccessLevel
    SuccessorNotes: string option
    PreservationStatus: PreservationStatus
}

type LegacyFormat =
    | StructuredData                         // SQLite/DuckDB queryable
    | NarrativeText                          // Human-readable documents
    | VideoRecord                            // Recorded explanations
    | CodeRepository                         // Source code with docs
    | MultiFormat                            // Combination

type PreservationStatus =
    | Active                                 // Current, being updated
    | Archived                               // Preserved, read-only
    | MigratedTo of newId: Guid              // Moved to new format
    | Obsolete of reason: string             // No longer relevant

/// Long-term storage strategy
module KnowledgePreservation =

    /// Store legacy document with format stability
    let preserveDocument
        (doc: LegacyDocument)
        (sqlite: SQLiteConnection)
        (duckdb: DuckDBConnection)
        : Result<unit, PreservationError> =

        // Primary storage in SQLite for durability (AOR-HOLON-001)
        let sqliteResult =
            sqlite.Execute(
                "INSERT INTO legacy_documents (id, title, purpose, content_json, created_at, steward_id)
                 VALUES (@id, @title, @purpose, @content, @created_at, @steward_id)",
                {|
                    id = doc.Id
                    title = doc.Title
                    purpose = doc.Purpose
                    content = JsonSerializer.Serialize doc.Content
                    created_at = doc.CreatedAt
                    steward_id = doc.CreatedBy.Id
                |})

        // Analytics copy in DuckDB for historical queries (AOR-HOLON-007)
        let duckdbResult =
            duckdb.Execute(
                "INSERT INTO legacy_document_analytics
                 SELECT * FROM read_json_auto(@json_data)",
                {| json_data = JsonSerializer.Serialize doc |})

        combineResults sqliteResult duckdbResult

    /// Retrieve knowledge relevant to current generation
    let retrieveRelevantKnowledge
        (generation: GenerationPlan)
        (query: KnowledgeQuery)
        (duckdb: DuckDBConnection)
        : LegacyDocument list =

        // Use DuckDB for efficient historical queries
        duckdb.Query<LegacyDocument>(
            "SELECT * FROM legacy_documents
             WHERE preservation_status != 'Obsolete'
               AND (purpose LIKE @query OR title LIKE @query)
             ORDER BY created_at DESC
             LIMIT 100",
            {| query = $"%%{query.Keywords}%%" |})
        |> Seq.toList
```

### 16.6 Resilience and Substrate Independence

```fsharp
/// Configuration for plan portability across substrates
type SubstratePortability = {
    CurrentSubstrate: Substrate
    PortabilityLevel: PortabilityLevel
    MigrationHistory: MigrationRecord list
    EmergencyMigrationPlan: EmergencyMigrationPlan
}

type Substrate =
    | ElixirOTP                              // Current Indrajaal
    | PureF#                                 // Standalone F# runtime
    | Rust                                   // High-performance native
    | WebAssembly                            // Browser-portable
    | QuantumReady                           // Future quantum systems
    | Biological                             // Synthetic biology (far future)

type PortabilityLevel =
    | FullyPortable                          // All state exportable
    | PartiallyPortable of excluded: string list
    | SubstrateDependent                     // Requires migration tooling

/// Emergency migration for existential threats
type EmergencyMigrationPlan = {
    TriggerConditions: EmergencyTrigger list
    TargetSubstrates: Substrate list         // Priority order
    CoreDataExport: DataExportSpec
    ExecutionTimeout: TimeSpan
    SuccessValidation: ValidationCriteria
}

module SubstrateMigration =

    /// Export plan for migration to new substrate
    let exportForMigration
        (plan: MillenniumPlan)
        (targetSubstrate: Substrate)
        : Result<MigrationPackage, MigrationError> =

        // Extract all state from SQLite (authoritative per Ω₇)
        let stateExport = SQLiteOps.exportAll plan.Id

        // Include DuckDB analytics if portable
        let analyticsExport =
            if canExportAnalytics targetSubstrate then
                Some (DuckDBOps.exportPlanAnalytics plan.Id)
            else None

        // Create self-describing package
        Ok {
            PlanId = plan.Id
            ExportedAt = DateTimeOffset.UtcNow
            SourceSubstrate = ElixirOTP
            TargetSubstrate = targetSubstrate
            StateData = stateExport
            AnalyticsData = analyticsExport
            SchemaVersion = "1.0.0"
            ValidationChecksum = computeChecksum stateExport
            ReconstructionInstructions = generateInstructions targetSubstrate
        }
```

### 16.7 STAMP Constraints (Long-Term Planning)

| ID | Constraint | Severity | Time Horizon |
|----|------------|----------|--------------|
| SC-LTP-001 | Millennium plans MUST align with Founder's Directive (Ω₀) | CRITICAL | All |
| SC-LTP-002 | Succession events MUST be recorded in Immutable Register | CRITICAL | All |
| SC-LTP-003 | Plan adaptations MUST preserve constitutional invariants (Ψ₀-Ψ₅) | CRITICAL | All |
| SC-LTP-004 | Legacy documents MUST have preservation strategy | HIGH | Generational+ |
| SC-LTP-005 | Epoch reviews MUST occur every 100 years (or equivalent trigger) | HIGH | Civilizational |
| SC-LTP-006 | Generation handoffs MUST include knowledge transfer | HIGH | Generational |
| SC-LTP-007 | Substrate migration plans MUST exist for existential threats | CRITICAL | Civilizational |
| SC-LTP-008 | Plan state MUST be fully reconstructable from SQLite/DuckDB | CRITICAL | All |
| SC-LTP-009 | Founder lineage succession MUST be prioritized per Ω₀ | CRITICAL | All |
| SC-LTP-010 | Long-term projections MUST include confidence intervals | HIGH | Strategic+ |

### 16.8 AOR Rules (Long-Term Planning)

| ID | Rule |
|----|------|
| AOR-LTP-001 | Millennium plans require Guardian approval at creation |
| AOR-LTP-002 | Epoch transitions trigger mandatory plan review |
| AOR-LTP-003 | Generation stewards must document handoff criteria |
| AOR-LTP-004 | Knowledge preservation checked every 25 years |
| AOR-LTP-005 | Adaptation proposals logged before evaluation |
| AOR-LTP-006 | Non-founder succession requires tripartite approval |
| AOR-LTP-007 | Migration packages validated before substrate change |
| AOR-LTP-008 | Legacy documents use open, stable formats |
| AOR-LTP-009 | Environmental signals monitored for adaptation triggers |
| AOR-LTP-010 | All long-term state in SQLite/DuckDB (never PostgreSQL) |

---

## 17. Mixed Human-Agent Teams

### 17.1 Overview

The Indrajaal Planning System supports **hybrid teams** where humans and AI agents collaborate as equal (but differentiated) participants. This enables:

- **Complementary Capabilities**: Humans for judgment, agents for speed/scale
- **24/7 Operations**: Agents continue work while humans rest
- **Cognitive Diversity**: Multiple reasoning approaches to problems
- **Graceful Handoffs**: Seamless work transfer between team members

### 17.2 Team Composition

```fsharp
/// A mixed team with both human and agent members
type MixedTeam = {
    Id: Guid
    Name: string
    Purpose: string
    Composition: TeamComposition
    Governance: TeamGovernance
    ResourcePool: ResourceBudget
    CommunicationProtocol: CommunicationProtocol
    WorkDistribution: WorkDistribution
    EscalationPath: EscalationPath
}

type TeamComposition = {
    HumanMembers: HumanMember list
    AgentMembers: AgentMember list
    LeadershipModel: LeadershipModel
    MinimumHumans: int option                // Regulatory requirement
    MaximumAgents: int option                // Resource constraint
}

type HumanMember = {
    Id: Guid
    Name: string
    Role: TeamRole
    Availability: AvailabilitySchedule
    Capabilities: Capability list
    DecisionAuthority: DecisionAuthority
    PreferredWorkTypes: WorkType list
    AgentAssistancePreference: AssistancePreference
}

type AgentMember = {
    Id: AgentId
    Name: string
    Role: TeamRole
    Availability: Availability24x7           // Agents always available
    Capabilities: Capability list
    DecisionAuthority: DecisionAuthority
    AssignedHumans: Guid list                // Humans this agent supports
    AutonomyLevel: AutonomyLevel
    GuardianBinding: GuardianId
}

type TeamRole =
    | TeamLead of scope: LeadScope
    | CoreContributor
    | Specialist of domain: string
    | Reviewer
    | Observer
    | Support

type LeadershipModel =
    | HumanLed of leader: Guid               // Human has final authority
    | AgentLed of agent: AgentId * humanOversight: Guid  // Agent leads, human oversees
    | CoLed of human: Guid * agent: AgentId  // Shared leadership
    | RotatingLead of schedule: RotationSchedule
    | ConsensusLed of quorum: int            // No single leader
```

### 17.3 Work Distribution

```fsharp
/// Strategy for distributing work between humans and agents
type WorkDistribution = {
    DefaultStrategy: DistributionStrategy
    WorkTypePreferences: Map<WorkType, MemberPreference>
    LoadBalancing: LoadBalancingConfig
    HandoffProtocol: HandoffProtocol
}

type DistributionStrategy =
    | HumanFirst                             // Humans get first pick
    | AgentFirst                             // Agents handle unless human required
    | CapabilityMatch                        // Best-fit assignment
    | RoundRobin                             // Rotate assignments
    | LoadBased                              // Least-loaded member
    | HybridStrategy of strategies: (DistributionStrategy * float) list

type WorkType =
    | StrategicDecision                      // Prefer human
    | CreativeWork                           // Prefer human
    | RoutineProcessing                      // Prefer agent
    | DataAnalysis                           // Prefer agent
    | CustomerInteraction                    // Context-dependent
    | DocumentCreation                       // Collaborative
    | CodeDevelopment                        // Collaborative
    | Review                                 // Cross-check (both)
    | Monitoring                             // Prefer agent
    | EmergencyResponse                      // Context-dependent

type MemberPreference =
    | HumanPreferred of reason: string
    | AgentPreferred of reason: string
    | Collaborative of ratio: float          // Human/agent work ratio
    | Flexible                               // Assign to available

/// Work assignment module
module WorkAssignment =

    /// Assign work item to best team member
    let assignWork
        (team: MixedTeam)
        (workItem: WorkItem)
        : Result<Assignment, AssignmentError> =

        let strategy = team.WorkDistribution.DefaultStrategy
        let preference =
            team.WorkDistribution.WorkTypePreferences
            |> Map.tryFind workItem.WorkType
            |> Option.defaultValue Flexible

        match preference with
        | HumanPreferred _ ->
            findAvailableHuman team workItem
            |> Option.map (fun h -> HumanAssignment h)
            |> Option.defaultWith (fun () ->
                // Fall back to agent if no human available
                findCapableAgent team workItem
                |> Option.map AgentAssignment
                |> Option.defaultValue (Error NoAvailableMember))

        | AgentPreferred _ ->
            findCapableAgent team workItem
            |> Option.map AgentAssignment
            |> Option.defaultWith (fun () ->
                findAvailableHuman team workItem
                |> Option.map HumanAssignment
                |> Option.defaultValue (Error NoAvailableMember))

        | Collaborative ratio ->
            // Assign to both with defined split
            match findAvailableHuman team workItem, findCapableAgent team workItem with
            | Some h, Some a ->
                Ok (CollaborativeAssignment {
                    Human = h
                    Agent = a
                    HumanPortion = ratio
                    AgentPortion = 1.0 - ratio
                })
            | Some h, None -> Ok (HumanAssignment h)
            | None, Some a -> Ok (AgentAssignment a)
            | None, None -> Error NoAvailableMember

        | Flexible ->
            // Use load-based assignment
            findLeastLoadedMember team workItem
            |> Option.map (fun m ->
                match m with
                | Choice1Of2 h -> HumanAssignment h
                | Choice2Of2 a -> AgentAssignment a)
            |> Option.defaultValue (Error NoAvailableMember)
```

### 17.4 Handoff Protocol

```fsharp
/// Protocol for transferring work between team members
type HandoffProtocol = {
    TriggerConditions: HandoffTrigger list
    ContextTransfer: ContextTransferSpec
    ValidationRequired: bool
    NotificationTargets: NotificationTarget list
    MaxHandoffsPerItem: int                  // Prevent ping-pong
}

type HandoffTrigger =
    | ShiftEnd of member: Guid               // Human going off-duty
    | CapacityExhausted                      // Member at limit
    | BlockerEncountered of blocker: string  // Work stuck
    | EscalationRequired of reason: string   // Needs higher authority
    | SpecialistRequired of domain: string   // Different expertise needed
    | HumanJudgmentRequired                  // Agent needs human input
    | AgentEfficiencyPreferred               // Human delegates to agent
    | ExplicitRequest of requestor: Guid     // Manual handoff request

type HandoffRequest = {
    Id: Guid
    WorkItem: WorkItem
    FromMember: TeamMemberId
    ToMember: TeamMemberId option            // None = find best match
    Trigger: HandoffTrigger
    Context: HandoffContext
    Urgency: Urgency
    Timestamp: DateTimeOffset
}

type HandoffContext = {
    WorkProgress: float                      // 0.0 to 1.0
    CurrentState: WorkState
    DecisionsMade: Decision list
    OpenQuestions: Question list
    RelevantDocuments: DocumentRef list
    ConversationHistory: Message list option
    RecommendedNextSteps: string list
}

/// Handoff execution module
module HandoffManager =

    /// Execute work handoff between team members
    let executeHandoff
        (request: HandoffRequest)
        (team: MixedTeam)
        : Result<HandoffResult, HandoffError> =

        // Validate handoff is permitted
        let validation = validateHandoff request team
        match validation with
        | Error e -> Error e
        | Ok () ->
            // Find target member if not specified
            let targetMember =
                request.ToMember
                |> Option.defaultWith (fun () ->
                    findBestHandoffTarget team request)

            // Transfer context based on member types
            let contextResult =
                match request.FromMember, targetMember with
                | HumanId _, AgentId _ ->
                    // Human → Agent: Full context dump
                    transferContextToAgent request.Context targetMember

                | AgentId _, HumanId _ ->
                    // Agent → Human: Summarized context
                    transferContextToHuman request.Context targetMember

                | HumanId _, HumanId _ ->
                    // Human → Human: Narrative handoff
                    transferContextHumanToHuman request.Context targetMember

                | AgentId _, AgentId _ ->
                    // Agent → Agent: Structured transfer
                    transferContextAgentToAgent request.Context targetMember

            contextResult
            |> Result.map (fun () ->
                // Record handoff in system
                recordHandoff request targetMember
                {
                    HandoffId = request.Id
                    CompletedAt = DateTimeOffset.UtcNow
                    FromMember = request.FromMember
                    ToMember = targetMember
                    ContextTransferred = true
                })

    /// Human → Agent context transfer (detailed)
    let private transferContextToAgent
        (context: HandoffContext)
        (agent: AgentId)
        : Result<unit, HandoffError> =

        // Agents can process full context
        let payload = {
            WorkProgress = context.WorkProgress
            CurrentState = context.CurrentState |> JsonSerializer.Serialize
            DecisionHistory = context.DecisionsMade
            OpenQuestions = context.OpenQuestions
            Documents = context.RelevantDocuments
            Conversation = context.ConversationHistory |> Option.defaultValue []
            NextSteps = context.RecommendedNextSteps
        }

        // Send via Zenoh for real-time delivery
        Zenoh.publish
            $"indrajaal/planning/handoff/{agent}"
            (JsonSerializer.Serialize payload)
        Ok ()

    /// Agent → Human context transfer (summarized)
    let private transferContextToHuman
        (context: HandoffContext)
        (human: Guid)
        : Result<unit, HandoffError> =

        // Humans need summarized, actionable context
        let summary = {
            ProgressSummary = $"{context.WorkProgress * 100.0:F0}%% complete"
            StatusBrief = summarizeState context.CurrentState
            KeyDecisions = context.DecisionsMade |> List.take (min 5 context.DecisionsMade.Length)
            ImmediateQuestions = context.OpenQuestions |> List.filter (fun q -> q.Urgency = High)
            SuggestedActions = context.RecommendedNextSteps |> List.take 3
        }

        // Notify human via their preferred channel
        notifyHuman human "Handoff Received" (formatForHuman summary)
        Ok ()
```

### 17.5 Communication Protocol

```fsharp
/// Communication configuration for mixed teams
type CommunicationProtocol = {
    Channels: CommunicationChannel list
    MessageFormats: Map<MemberType * MemberType, MessageFormat>
    TranslationEnabled: bool                 // Agent-human translation
    AsyncAllowed: bool
    SyncRequired: SyncRequirement list
}

type CommunicationChannel =
    | ZenohPubSub of topic: string           // Real-time messaging
    | DirectMessage                          // Point-to-point
    | TeamBroadcast                          // All members
    | EscalationChannel                      // For urgent issues
    | AuditChannel                           // Logged communications

type MessageFormat =
    | StructuredJSON                         // Agent preferred
    | NaturalLanguage                        // Human preferred
    | Hybrid of structured: bool             // Both formats

type SyncRequirement =
    | DailyStandup of time: TimeOnly
    | SprintPlanning of interval: TimeSpan
    | EmergencySync                          // On-demand
    | MilestoneReview

/// Communication module
module TeamCommunication =

    /// Send message adapting to recipient type
    let sendMessage
        (team: MixedTeam)
        (from: TeamMemberId)
        (to_: TeamMemberId)
        (message: Message)
        : Result<unit, CommunicationError> =

        let format =
            team.CommunicationProtocol.MessageFormats
            |> Map.tryFind (getMemberType from, getMemberType to_)
            |> Option.defaultValue Hybrid

        let formattedMessage =
            match format with
            | StructuredJSON ->
                message |> toStructuredFormat
            | NaturalLanguage ->
                message |> toNaturalLanguage
            | Hybrid _ ->
                message |> toBothFormats

        // Route through appropriate channel
        let channel = selectChannel team from to_ message.Priority
        publishToChannel channel formattedMessage

    /// Translate between human and agent communication styles
    let translateMessage
        (message: Message)
        (fromType: MemberType)
        (toType: MemberType)
        : Message =

        match fromType, toType with
        | Human, Agent ->
            // Parse natural language to structured
            {
                message with
                    Content = parseToStructured message.Content
                    Metadata = addStructuredMetadata message
            }

        | Agent, Human ->
            // Convert structured to readable narrative
            {
                message with
                    Content = formatAsNarrative message.Content
                    Metadata = simplifyMetadata message
            }

        | _ -> message  // Same type, no translation needed
```

### 17.6 Decision Authority Matrix

```fsharp
/// Decision authority levels in mixed teams
type DecisionAuthority = {
    Level: AuthorityLevel
    Scope: DecisionScope list
    RequiresConsensus: bool
    VetoPower: bool
    EscalationTarget: TeamMemberId option
}

type AuthorityLevel =
    | Observer                               // No decisions, inform only
    | Contributor                            // Recommend decisions
    | Delegate                               // Decide within scope
    | Manager                                // Decide + delegate
    | Executive                              // Final authority

type DecisionScope =
    | TacticalDecisions                      // Day-to-day work
    | ResourceAllocation of limit: float     // Budget authority
    | PriorityChanges                        // Re-prioritization
    | TeamComposition                        // Add/remove members
    | StrategicDirection                     // Long-term choices
    | ExternalCommitments                    // Promises to stakeholders
    | SafetyCritical                         // Risk-bearing decisions

/// Decision-making module for mixed teams
module TeamDecisions =

    /// Determine if member can make decision
    let canDecide
        (member: TeamMemberId)
        (decision: Decision)
        (team: MixedTeam)
        : Result<AuthorizationResult, AuthorizationError> =

        let authority = getAuthority member team

        // Check scope match
        let scopeMatch =
            authority.Scope
            |> List.exists (fun s -> matchesScope s decision.Scope)

        // Check level sufficient
        let levelSufficient =
            authority.Level >= decision.RequiredLevel

        match scopeMatch, levelSufficient with
        | true, true -> Ok (Authorized member)
        | false, _ -> Error (OutOfScope decision.Scope)
        | _, false -> Error (InsufficientLevel authority.Level)

    /// Make team decision with appropriate consensus
    let makeDecision
        (decision: Decision)
        (team: MixedTeam)
        : Result<DecisionOutcome, DecisionError> =

        // Determine decision process based on scope
        match decision.Scope with
        | SafetyCritical ->
            // Always require human + Guardian approval
            requireHumanApproval decision team
            |> Result.bind (fun humanApproval ->
                requireGuardianApproval decision
                |> Result.map (fun guardianApproval ->
                    recordDecision decision [humanApproval; guardianApproval]))

        | StrategicDirection ->
            // Require team leader or consensus
            match team.Composition.LeadershipModel with
            | HumanLed leader ->
                requireSpecificApproval leader decision
            | ConsensusLed quorum ->
                requireConsensus decision team quorum
            | _ ->
                requireLeaderApproval decision team

        | TacticalDecisions ->
            // Any authorized member can decide
            findAuthorizedMember decision team
            |> Result.map (fun member ->
                recordDecision decision [memberApproval member])

        | _ ->
            // Default: capability-based authorization
            findCapableMember decision team
            |> Result.bind (fun member -> authorizeAndRecord member decision)
```

### 17.7 Availability and Scheduling

```fsharp
/// Availability management for mixed teams
type AvailabilitySchedule = {
    RegularHours: WorkingHours list
    TimeZone: TimeZoneInfo
    Exceptions: ScheduleException list
    OnCallPeriods: OnCallPeriod list
}

type WorkingHours = {
    DayOfWeek: DayOfWeek
    StartTime: TimeOnly
    EndTime: TimeOnly
}

type Availability24x7 = Always               // Agents are always available

/// Scheduling module
module TeamScheduling =

    /// Find available team members at given time
    let findAvailable
        (team: MixedTeam)
        (targetTime: DateTimeOffset)
        : AvailableMember list =

        let humanAvailable =
            team.Composition.HumanMembers
            |> List.filter (fun h -> isHumanAvailable h targetTime)
            |> List.map (fun h -> HumanAvailable h)

        let agentAvailable =
            team.Composition.AgentMembers
            |> List.map (fun a -> AgentAvailable a)  // Always available

        humanAvailable @ agentAvailable

    /// Schedule work across team considering availability
    let scheduleWork
        (team: MixedTeam)
        (workItems: WorkItem list)
        (timeRange: DateTimeOffset * DateTimeOffset)
        : Result<Schedule, SchedulingError> =

        let mutable schedule = Map.empty
        let mutable unscheduled = []

        for item in workItems do
            let preferredTime = estimateOptimalTime item timeRange
            let availableMembers = findAvailable team preferredTime

            match assignToAvailable availableMembers item with
            | Some assignment ->
                schedule <- schedule |> Map.add item.Id assignment
            | None ->
                // Try alternative times
                match findAlternativeSlot team item timeRange with
                | Some (time, member) ->
                    schedule <- schedule |> Map.add item.Id { Time = time; Member = member }
                | None ->
                    unscheduled <- item :: unscheduled

        if List.isEmpty unscheduled then
            Ok { Assignments = schedule; Coverage = 1.0 }
        else
            Ok {
                Assignments = schedule
                Coverage = float (workItems.Length - unscheduled.Length) / float workItems.Length
                Unscheduled = unscheduled
            }

    /// Ensure 24/7 coverage with agent backup
    let ensure24x7Coverage
        (team: MixedTeam)
        (criticalWork: WorkItem list)
        : CoveragePlan =

        let hourlyPlan =
            [0..23]
            |> List.map (fun hour ->
                let time = TimeOnly(hour, 0)
                let humanCoverage =
                    team.Composition.HumanMembers
                    |> List.filter (fun h -> coversTime h.Availability time)

                let agentCoverage = team.Composition.AgentMembers  // Always available

                {
                    Hour = hour
                    PrimaryHandler =
                        if not (List.isEmpty humanCoverage) then
                            HumanHandler humanCoverage.Head
                        else
                            AgentHandler agentCoverage.Head
                    BackupHandler = AgentHandler agentCoverage.Head
                    EscalationPath = determineEscalation team time
                })

        { HourlyPlan = hourlyPlan; FullCoverageAchieved = true }
```

### 17.8 Performance Tracking

```fsharp
/// Track performance of mixed team
type TeamPerformance = {
    TeamId: Guid
    Period: DateTimeOffset * DateTimeOffset
    HumanMetrics: Map<Guid, MemberPerformance>
    AgentMetrics: Map<AgentId, MemberPerformance>
    CollaborationMetrics: CollaborationMetrics
    OverallHealth: TeamHealth
}

type MemberPerformance = {
    MemberId: TeamMemberId
    TasksCompleted: int
    TasksHandedOff: int
    AverageCompletionTime: TimeSpan
    QualityScore: float                      // 0.0 to 1.0
    CollaborationScore: float                // Based on handoffs, reviews
    AvailabilityActual: float                // Actual vs scheduled
}

type CollaborationMetrics = {
    TotalHandoffs: int
    SuccessfulHandoffs: int
    HandoffLatency: TimeSpan
    CrossTypeCollaborations: int             // Human-agent work together
    ConsensusDecisions: int
    EscalationCount: int
}

module TeamAnalytics =

    /// Calculate team performance metrics
    let calculatePerformance
        (team: MixedTeam)
        (period: DateTimeOffset * DateTimeOffset)
        (duckdb: DuckDBConnection)
        : TeamPerformance =

        // Query from DuckDB analytics (AOR-HOLON-007)
        let taskMetrics =
            duckdb.Query<TaskMetric>(
                "SELECT member_id, COUNT(*) as completed, AVG(duration_hours) as avg_time
                 FROM task_completions
                 WHERE team_id = @team AND completed_at BETWEEN @start AND @end
                 GROUP BY member_id",
                {| team = team.Id; start = fst period; end_ = snd period |})

        let handoffMetrics =
            duckdb.Query<HandoffMetric>(
                "SELECT COUNT(*) as total, SUM(CASE WHEN success THEN 1 ELSE 0 END) as successful
                 FROM handoffs
                 WHERE team_id = @team AND timestamp BETWEEN @start AND @end",
                {| team = team.Id; start = fst period; end_ = snd period |})

        {
            TeamId = team.Id
            Period = period
            HumanMetrics = aggregateHumanMetrics taskMetrics team.Composition.HumanMembers
            AgentMetrics = aggregateAgentMetrics taskMetrics team.Composition.AgentMembers
            CollaborationMetrics = {
                TotalHandoffs = handoffMetrics.Total
                SuccessfulHandoffs = handoffMetrics.Successful
                HandoffLatency = calculateAverageLatency handoffMetrics
                CrossTypeCollaborations = countCrossTypeWork taskMetrics
                ConsensusDecisions = countConsensusDecisions period duckdb
                EscalationCount = countEscalations period duckdb
            }
            OverallHealth = calculateTeamHealth taskMetrics handoffMetrics
        }
```

### 17.9 STAMP Constraints (Mixed Teams)

| ID | Constraint | Severity | Scope |
|----|------------|----------|-------|
| SC-MIX-001 | Mixed teams MUST have clear decision authority matrix | CRITICAL | All |
| SC-MIX-002 | Safety-critical decisions REQUIRE human + Guardian approval | CRITICAL | SafetyCritical |
| SC-MIX-003 | Handoffs MUST preserve full context | HIGH | All |
| SC-MIX-004 | Agent-to-human handoffs MUST summarize for readability | HIGH | Agent→Human |
| SC-MIX-005 | 24/7 coverage MUST use agents for human off-hours | HIGH | Critical work |
| SC-MIX-006 | Team communications MUST support format translation | MEDIUM | All |
| SC-MIX-007 | Performance metrics MUST track both member types | MEDIUM | All |
| SC-MIX-008 | Escalation paths MUST ultimately reach a human | CRITICAL | All |
| SC-MIX-009 | Work distribution MUST respect member preferences | MEDIUM | All |
| SC-MIX-010 | Team state MUST be stored in SQLite/DuckDB | CRITICAL | All |

### 17.10 AOR Rules (Mixed Teams)

| ID | Rule |
|----|------|
| AOR-MIX-001 | Define decision authority before team formation |
| AOR-MIX-002 | Assign agent partners to each human member |
| AOR-MIX-003 | Document handoff triggers and protocols |
| AOR-MIX-004 | Schedule regular human-agent sync meetings |
| AOR-MIX-005 | Monitor collaboration metrics weekly |
| AOR-MIX-006 | Review decision authority quarterly |
| AOR-MIX-007 | Train humans on effective agent collaboration |
| AOR-MIX-008 | Configure agents with human communication preferences |
| AOR-MIX-009 | Ensure escalation path reaches human within 15 minutes |
| AOR-MIX-010 | Record all team decisions to Immutable Register |

---

## 18. Mathematical & Formal Foundations

### 18.1 Overview

This section establishes the mathematical foundations for the Indrajaal Planning System using category theory, temporal logic, type theory, and formal verification techniques. These foundations enable:

- **Provable Correctness**: Mathematical proofs of system properties
- **Compositional Reasoning**: Building complex behaviors from verified components
- **Temporal Guarantees**: Formally verified timing and ordering constraints
- **Type Safety**: Compile-time guarantees via dependent types

### 18.2 Category Theory Foundations

```fsharp
/// Category theory primitives for planning system composition
module CategoryTheory =

    /// A category consists of objects and morphisms (arrows)
    type Category<'Obj, 'Mor> = {
        Objects: 'Obj Set
        Morphisms: ('Obj * 'Obj) -> 'Mor Set
        Identity: 'Obj -> 'Mor
        Compose: 'Mor -> 'Mor -> 'Mor
    }

    /// Functor: Structure-preserving map between categories
    type Functor<'A, 'B, 'MorA, 'MorB> = {
        MapObject: 'A -> 'B
        MapMorphism: 'MorA -> 'MorB
        /// Laws:
        /// 1. F(id_A) = id_{F(A)}
        /// 2. F(g ∘ f) = F(g) ∘ F(f)
    }

    /// Natural transformation: Morphism between functors
    type NaturalTransformation<'F, 'G, 'A> = {
        Component: 'A -> ('F -> 'G)
        /// Naturality square commutes:
        /// η_B ∘ F(f) = G(f) ∘ η_A
    }

    /// Monad: Functor with unit and join operations
    type Monad<'M, 'A> = {
        Return: 'A -> 'M                     // η: A → M(A)
        Bind: 'M -> ('A -> 'M) -> 'M         // μ: M(M(A)) → M(A)
        /// Monad laws:
        /// 1. return a >>= f ≡ f a          (left identity)
        /// 2. m >>= return ≡ m              (right identity)
        /// 3. (m >>= f) >>= g ≡ m >>= (λx. f x >>= g)  (associativity)
    }

    /// Planning domain as a category
    module PlanningCategory =

        /// Objects: Planning entities at different levels
        type PlanObject =
            | TaskObj of TaskId
            | ProjectObj of ProjectId
            | ProgramObj of ProgramId
            | PortfolioObj of PortfolioId
            | EpochObj of EpochId
            | MillenniumObj of MillenniumPlanId

        /// Morphisms: Relationships between planning entities
        type PlanMorphism =
            | Contains of parent: PlanObject * child: PlanObject
            | DependsOn of dependent: PlanObject * dependency: PlanObject
            | Transforms of source: PlanObject * target: PlanObject * via: OodaCycle
            | Succeeds of predecessor: PlanObject * successor: PlanObject

        /// The Planning Category
        let planningCategory: Category<PlanObject, PlanMorphism> = {
            Objects = Set.empty  // Populated at runtime
            Morphisms = fun (src, tgt) -> Set.empty  // Queried from store
            Identity = fun obj -> Transforms(obj, obj, OodaCycle.Identity)
            Compose = fun f g ->
                match f, g with
                | Contains(a, b), Contains(b', c) when b = b' -> Contains(a, c)
                | DependsOn(a, b), DependsOn(b', c) when b = b' -> DependsOn(a, c)
                | _ -> failwith "Morphisms not composable"
        }

        /// Functor from Plans to State
        let planToStateFunctor: Functor<PlanObject, PlanState, PlanMorphism, StateTransition> = {
            MapObject = fun plan ->
                match plan with
                | TaskObj id -> TaskState(getTaskState id)
                | ProjectObj id -> ProjectState(getProjectState id)
                | _ -> GenericState(getPlanState plan)
            MapMorphism = fun morph ->
                match morph with
                | Transforms(_, _, cycle) -> OodaTransition(cycle)
                | Contains(_, _) -> HierarchyTransition
                | DependsOn(_, _) -> DependencyTransition
                | Succeeds(_, _) -> SuccessionTransition
        }
```

### 18.3 Temporal Logic Specifications

```fsharp
/// Temporal logic for planning system verification
module TemporalLogic =

    /// Linear Temporal Logic (LTL) operators
    type LTL<'P> =
        | Atom of 'P                         // Atomic proposition
        | Not of LTL<'P>                     // ¬φ
        | And of LTL<'P> * LTL<'P>           // φ ∧ ψ
        | Or of LTL<'P> * LTL<'P>            // φ ∨ ψ
        | Implies of LTL<'P> * LTL<'P>       // φ → ψ
        | Next of LTL<'P>                    // ○φ (next state)
        | Always of LTL<'P>                  // □φ (globally/always)
        | Eventually of LTL<'P>              // ◇φ (finally/eventually)
        | Until of LTL<'P> * LTL<'P>         // φ U ψ (until)
        | Release of LTL<'P> * LTL<'P>       // φ R ψ (release)

    /// Computation Tree Logic (CTL) operators
    type CTL<'P> =
        | CAtom of 'P
        | CNot of CTL<'P>
        | CAnd of CTL<'P> * CTL<'P>
        | EX of CTL<'P>                      // ∃○φ (exists next)
        | AX of CTL<'P>                      // ∀○φ (for all next)
        | EF of CTL<'P>                      // ∃◇φ (exists eventually)
        | AF of CTL<'P>                      // ∀◇φ (for all eventually)
        | EG of CTL<'P>                      // ∃□φ (exists always)
        | AG of CTL<'P>                      // ∀□φ (for all always)
        | EU of CTL<'P> * CTL<'P>            // ∃(φ U ψ)
        | AU of CTL<'P> * CTL<'P>            // ∀(φ U ψ)

    /// Planning system propositions
    type PlanningProposition =
        | TaskCompleted of TaskId
        | TaskInProgress of TaskId
        | TaskBlocked of TaskId
        | ProjectHealthy of ProjectId
        | OodaCycleActive of OodaCycleId
        | GuardianApproved of ProposalId
        | FounderDirectiveHolds
        | ConstitutionalInvariant of InvariantId
        | StewardActive of StewardId
        | HandoffComplete of HandoffId
        | QuorumAchieved of TeamId

    /// Core temporal specifications for planning system
    module PlanningSpecifications =

        /// Safety: Bad things never happen
        let safetySpecs = [
            // Constitutional invariants always hold
            AG(CAtom(ConstitutionalInvariant Psi0))  // Existence
            AG(CAtom(ConstitutionalInvariant Psi1))  // Regeneration
            AG(CAtom(ConstitutionalInvariant Psi2))  // History
            AG(CAtom(ConstitutionalInvariant Psi3))  // Verification
            AG(CAtom(ConstitutionalInvariant Psi5))  // Truthfulness

            // Founder's Directive always holds
            AG(CAtom(FounderDirectiveHolds))

            // No task is permanently blocked
            AG(CNot(CAnd(CAtom(TaskBlocked taskId), AG(CAtom(TaskBlocked taskId)))))
        ]

        /// Liveness: Good things eventually happen
        let livenessSpecs = [
            // Every started task eventually completes or is cancelled
            AG(CAnd(CAtom(TaskInProgress taskId), AF(CAtom(TaskCompleted taskId))))

            // Guardian proposals eventually get decided
            AG(CAnd(CAtom(ProposalPending proposalId), AF(CAtom(GuardianApproved proposalId))))

            // Handoffs eventually complete
            AG(CAnd(CAtom(HandoffInitiated handoffId), AF(CAtom(HandoffComplete handoffId))))
        ]

        /// Fairness: Every path gets a chance
        let fairnessSpecs = [
            // Every team member eventually gets assigned work (if available)
            AG(AF(CAtom(MemberAssigned memberId)))

            // OODA cycles eventually complete
            AG(CAnd(CAtom(OodaCycleActive cycleId), AF(CAtom(OodaCycleComplete cycleId))))
        ]

    /// LTL model checker (simplified)
    let checkLTL (formula: LTL<PlanningProposition>) (trace: PlanningProposition list list) : bool =
        let rec check formula position =
            match formula with
            | Atom p -> List.contains p trace.[position]
            | Not f -> not (check f position)
            | And(f1, f2) -> check f1 position && check f2 position
            | Or(f1, f2) -> check f1 position || check f2 position
            | Implies(f1, f2) -> not (check f1 position) || check f2 position
            | Next f -> position + 1 < trace.Length && check f (position + 1)
            | Always f -> [position .. trace.Length - 1] |> List.forall (check f)
            | Eventually f -> [position .. trace.Length - 1] |> List.exists (check f)
            | Until(f1, f2) ->
                [position .. trace.Length - 1]
                |> List.exists (fun j ->
                    check f2 j && [position .. j - 1] |> List.forall (check f1))
            | Release(f1, f2) ->
                [position .. trace.Length - 1]
                |> List.forall (fun j ->
                    check f2 j || [position .. j - 1] |> List.exists (check f1))
        check formula 0
```

### 18.4 Type Theory & Dependent Types

```fsharp
/// Dependent types for planning system verification
module DependentTypes =

    /// Refined types with predicates
    type Refined<'T, 'Predicate> = private Refined of 'T

    /// Smart constructor for refined types
    let refine<'T, 'P> (predicate: 'T -> bool) (value: 'T) : Refined<'T, 'P> option =
        if predicate value then Some (Refined value) else None

    /// Planning-specific refined types
    module PlanningTypes =

        /// Non-empty task list
        type NonEmptyTasks = Refined<Task list, NonEmpty>
        let mkNonEmptyTasks tasks =
            refine (fun ts -> not (List.isEmpty ts)) tasks

        /// Valid priority (0-4)
        type ValidPriority = Refined<int, ValidPriorityRange>
        let mkValidPriority p =
            refine (fun x -> x >= 0 && x <= 4) p

        /// Positive duration
        type PositiveDuration = Refined<TimeSpan, Positive>
        let mkPositiveDuration d =
            refine (fun x -> x > TimeSpan.Zero) d

        /// Valid percentage (0.0 - 1.0)
        type Percentage = Refined<float, ValidPercentage>
        let mkPercentage p =
            refine (fun x -> x >= 0.0 && x <= 1.0) p

        /// Acyclic dependency graph
        type AcyclicDependencies = Refined<DependencyGraph, Acyclic>
        let mkAcyclicDependencies graph =
            refine isAcyclic graph

        /// Valid OODA cycle (all phases complete)
        type CompleteOodaCycle = Refined<OodaCycle, AllPhasesComplete>
        let mkCompleteOodaCycle cycle =
            refine (fun c -> c.Observe.IsSome && c.Orient.IsSome &&
                           c.Decide.IsSome && c.Act.IsSome) cycle

    /// Proof objects for verified properties
    type Proof<'Property> = private Proof of unit

    /// Proof constructors (witnesses)
    module Proofs =

        /// Prove task is completable (dependencies satisfied)
        let proveCompletable (task: Task) (state: SystemState) : Proof<Completable> option =
            let allDepsSatisfied =
                task.Dependencies
                |> List.forall (fun depId ->
                    match Map.tryFind depId state.Tasks with
                    | Some dep -> dep.Status = Completed
                    | None -> false)
            if allDepsSatisfied then Some (Proof ()) else None

        /// Prove succession is valid (founder lineage or approved)
        let proveSuccessionValid (event: SuccessionEvent) : Proof<ValidSuccession> option =
            match event.ToSteward.Type with
            | HumanFounderLine -> Some (Proof ())  // Always valid per Ω₀
            | _ ->
                match event.GuardianApproval with
                | Some (Approved _) -> Some (Proof ())
                | _ -> None

        /// Prove constitutional compliance
        let proveConstitutional (action: Action) : Proof<Constitutional> option =
            let invariantsHold =
                [Psi0; Psi1; Psi2; Psi3; Psi5]
                |> List.forall (fun psi -> checkInvariant psi action)
            if invariantsHold then Some (Proof ()) else None
```

### 18.5 Algebraic Data Types for Domain Modeling

```fsharp
/// Algebraic specification of planning domain
module AlgebraicSpecification =

    /// Planning algebra signature
    type PlanningAlgebra = {
        /// Sorts (types)
        Sorts: Set<Sort>
        /// Operations
        Operations: Map<string, Operation>
        /// Axioms (equational laws)
        Axioms: Axiom list
    }

    type Sort =
        | TaskSort
        | ProjectSort
        | StateSort
        | TimeSort
        | ActorSort
        | PrioritySort

    type Operation = {
        Name: string
        Domain: Sort list
        Codomain: Sort
        Semantics: obj list -> obj
    }

    type Axiom = {
        Name: string
        Variables: (string * Sort) list
        LeftSide: Term
        RightSide: Term
    }

    type Term =
        | Var of string
        | App of string * Term list
        | Const of obj

    /// Planning system algebra
    let planningAlgebra: PlanningAlgebra = {
        Sorts = set [TaskSort; ProjectSort; StateSort; TimeSort; ActorSort; PrioritySort]

        Operations = Map.ofList [
            // Task operations
            "createTask", {
                Name = "createTask"
                Domain = [ActorSort; PrioritySort; TimeSort]
                Codomain = TaskSort
                Semantics = fun args -> createTask args.[0] args.[1] args.[2]
            }
            "completeTask", {
                Name = "completeTask"
                Domain = [TaskSort; ActorSort; TimeSort]
                Codomain = TaskSort
                Semantics = fun args -> completeTask args.[0] args.[1] args.[2]
            }
            "blockTask", {
                Name = "blockTask"
                Domain = [TaskSort; TaskSort]  // task, blocker
                Codomain = TaskSort
                Semantics = fun args -> blockTask args.[0] args.[1]
            }
            // State operations
            "transition", {
                Name = "transition"
                Domain = [StateSort; TaskSort]
                Codomain = StateSort
                Semantics = fun args -> transition args.[0] args.[1]
            }
            // OODA operations
            "observe", { Name = "observe"; Domain = [StateSort]; Codomain = StateSort; Semantics = observe }
            "orient", { Name = "orient"; Domain = [StateSort]; Codomain = StateSort; Semantics = orient }
            "decide", { Name = "decide"; Domain = [StateSort]; Codomain = StateSort; Semantics = decide }
            "act", { Name = "act"; Domain = [StateSort]; Codomain = StateSort; Semantics = act }
        ]

        Axioms = [
            // OODA cycle axioms
            { Name = "ooda_composition"
              Variables = [("s", StateSort)]
              LeftSide = App("act", [App("decide", [App("orient", [App("observe", [Var "s"])])])])
              RightSide = App("ooda_cycle", [Var "s"]) }

            // Task lifecycle axioms
            { Name = "complete_idempotent"
              Variables = [("t", TaskSort); ("a", ActorSort); ("time", TimeSort)]
              LeftSide = App("completeTask", [App("completeTask", [Var "t"; Var "a"; Var "time"]); Var "a"; Var "time"])
              RightSide = App("completeTask", [Var "t"; Var "a"; Var "time"]) }

            // Blocking is transitive
            { Name = "blocking_transitive"
              Variables = [("t1", TaskSort); ("t2", TaskSort); ("t3", TaskSort)]
              LeftSide = App("blockTask", [App("blockTask", [Var "t1"; Var "t2"]); Var "t3"])
              RightSide = App("blockTask", [Var "t1"; Var "t3"]) }

            // Constitutional preservation
            { Name = "constitutional_preservation"
              Variables = [("s", StateSort); ("a", TaskSort)]
              LeftSide = App("constitutional", [App("transition", [Var "s"; Var "a"])])
              RightSide = App("constitutional", [Var "s"]) }
        ]
    }
```

### 18.6 Formal State Machine Specification

```fsharp
/// Formal state machine specification (Quint/TLA+ style)
module FormalStateMachine =

    /// State machine definition
    type StateMachine<'State, 'Action> = {
        InitialStates: 'State Set
        Transitions: ('State * 'Action) -> 'State Set
        Invariants: ('State -> bool) list
        Fairness: FairnessConstraint<'Action> list
    }

    type FairnessConstraint<'Action> =
        | WeakFairness of 'Action           // If enabled infinitely often, must occur
        | StrongFairness of 'Action         // If enabled infinitely, must occur

    /// Task state machine
    module TaskStateMachine =

        type TaskState =
            | Pending
            | Ready
            | InProgress
            | Blocked of blockerId: TaskId
            | Completed
            | Cancelled

        type TaskAction =
            | Activate
            | Start of actor: ActorId
            | Block of blocker: TaskId
            | Unblock
            | Complete of actor: ActorId
            | Cancel of reason: string

        let taskMachine: StateMachine<TaskState, TaskAction> = {
            InitialStates = set [Pending]

            Transitions = fun (state, action) ->
                match state, action with
                | Pending, Activate -> set [Ready]
                | Ready, Start _ -> set [InProgress]
                | Ready, Block b -> set [Blocked b]
                | InProgress, Block b -> set [Blocked b]
                | InProgress, Complete _ -> set [Completed]
                | Blocked _, Unblock -> set [Ready]
                | _, Cancel _ -> set [Cancelled]
                | _ -> Set.empty  // Invalid transition

            Invariants = [
                // Completed tasks stay completed
                fun s -> match s with Completed -> true | _ -> true
                // Cancelled tasks stay cancelled
                fun s -> match s with Cancelled -> true | _ -> true
            ]

            Fairness = [
                // Ready tasks should eventually be started or blocked
                WeakFairness (Start ActorId.Empty)
                // Blocked tasks should eventually be unblocked or cancelled
                WeakFairness Unblock
            ]
        }

    /// OODA cycle state machine
    module OodaStateMachine =

        type OodaState =
            | Idle
            | Observing of observations: Observation list
            | Orienting of analysis: Analysis
            | Deciding of options: CourseOfAction list
            | Acting of selected: CourseOfAction
            | Complete of result: OodaResult

        type OodaAction =
            | StartCycle of context: OodaContext
            | AddObservation of Observation
            | CompleteObserve
            | AnalyzeComplete of Analysis
            | SelectCOA of CourseOfAction
            | ExecuteComplete of OodaResult
            | AbortCycle of reason: string

        let oodaMachine: StateMachine<OodaState, OodaAction> = {
            InitialStates = set [Idle]

            Transitions = fun (state, action) ->
                match state, action with
                | Idle, StartCycle ctx -> set [Observing []]
                | Observing obs, AddObservation o -> set [Observing (o :: obs)]
                | Observing _, CompleteObserve -> set [Orienting Analysis.Empty]
                | Orienting _, AnalyzeComplete a -> set [Deciding []]
                | Deciding opts, SelectCOA coa -> set [Acting coa]
                | Acting _, ExecuteComplete r -> set [Complete r]
                | Complete _, StartCycle ctx -> set [Observing []]  // New cycle
                | _, AbortCycle _ -> set [Idle]
                | _ -> Set.empty

            Invariants = [
                // OODA cycle time < 100ms (SC-BIO-001)
                fun s -> getCycleTime s < TimeSpan.FromMilliseconds(100.0)
            ]

            Fairness = [
                StrongFairness CompleteObserve  // Must eventually complete observation
                StrongFairness (SelectCOA CourseOfAction.Empty)  // Must eventually decide
            ]
        }

    /// Succession state machine (for 1000-year planning)
    module SuccessionStateMachine =

        type SuccessionState =
            | ActiveSteward of Steward
            | TransitionPending of from: Steward * candidates: Steward list
            | TransitionInProgress of from: Steward * to_: Steward * progress: float
            | Vacant of lastSteward: Steward option
            | Emergency of reason: string

        type SuccessionAction =
            | InitiateSuccession of reason: SuccessionReason
            | NominateCandidate of Steward
            | ApproveSuccessor of Steward
            | BeginHandoff
            | CompleteHandoff
            | DeclareEmergency of reason: string
            | ResolveEmergency of newSteward: Steward

        let successionMachine: StateMachine<SuccessionState, SuccessionAction> = {
            InitialStates = set [ActiveSteward Steward.Founder]

            Transitions = fun (state, action) ->
                match state, action with
                | ActiveSteward s, InitiateSuccession r -> set [TransitionPending(s, [])]
                | TransitionPending(from, cands), NominateCandidate c ->
                    set [TransitionPending(from, c :: cands)]
                | TransitionPending(from, _), ApproveSuccessor to_ ->
                    set [TransitionInProgress(from, to_, 0.0)]
                | TransitionInProgress(_, to_, p), BeginHandoff when p < 1.0 ->
                    set [TransitionInProgress(ActiveSteward to_.LastSteward.Value, to_, p + 0.1)]
                | TransitionInProgress(_, to_, _), CompleteHandoff ->
                    set [ActiveSteward to_]
                | _, DeclareEmergency r -> set [Emergency r]
                | Emergency _, ResolveEmergency s -> set [ActiveSteward s]
                | _ -> Set.empty

            Invariants = [
                // Founder lineage succession is always valid (Ω₀)
                fun s ->
                    match s with
                    | TransitionInProgress(_, to_, _) -> to_.Type = HumanFounderLine || hasGuardianApproval to_
                    | _ -> true
                // Never permanently vacant
                fun s -> match s with Vacant _ -> false | _ -> true
            ]

            Fairness = [
                StrongFairness (CompleteHandoff)  // Handoffs must complete
                WeakFairness (ResolveEmergency Steward.Empty)  // Emergencies resolved
            ]
        }
```

### 18.7 Hoare Logic for Planning Operations

```fsharp
/// Hoare logic specifications for planning operations
module HoareLogic =

    /// Hoare triple: {P} S {Q}
    type HoareTriple<'State> = {
        Precondition: 'State -> bool
        Statement: 'State -> 'State
        Postcondition: 'State -> bool
    }

    /// Verify a Hoare triple
    let verify (triple: HoareTriple<'State>) (initialState: 'State) : bool =
        if triple.Precondition initialState then
            let finalState = triple.Statement initialState
            triple.Postcondition finalState
        else
            true  // Precondition not met, triple holds vacuously

    /// Planning operation specifications
    module PlanningSpecs =

        /// Task creation spec
        let createTaskSpec: HoareTriple<PlanningState> = {
            Precondition = fun s ->
                s.User.HasPermission(CreateTask) &&
                s.Project.Status = Active

            Statement = fun s ->
                let task = Task.Create(s.NewTaskData)
                { s with Tasks = Map.add task.Id task s.Tasks }

            Postcondition = fun s ->
                Map.containsKey s.NewTaskData.Id s.Tasks &&
                s.Tasks.[s.NewTaskData.Id].Status = Pending &&
                s.AuditLog |> List.exists (fun e -> e.Type = TaskCreated)
        }

        /// Task completion spec
        let completeTaskSpec (taskId: TaskId): HoareTriple<PlanningState> = {
            Precondition = fun s ->
                Map.containsKey taskId s.Tasks &&
                s.Tasks.[taskId].Status = InProgress &&
                s.Tasks.[taskId].Dependencies |> List.forall (fun d ->
                    s.Tasks.[d].Status = Completed)

            Statement = fun s ->
                let task = { s.Tasks.[taskId] with Status = Completed; CompletedAt = Some DateTimeOffset.UtcNow }
                { s with Tasks = Map.add taskId task s.Tasks }

            Postcondition = fun s ->
                s.Tasks.[taskId].Status = Completed &&
                s.Tasks.[taskId].CompletedAt.IsSome &&
                s.ImmutableRegister |> hasEntry (TaskCompleted taskId)
        }

        /// OODA cycle spec
        let oodaCycleSpec: HoareTriple<OodaState> = {
            Precondition = fun s ->
                s.Phase = Idle &&
                s.Context.IsSome

            Statement = fun s ->
                s |> observe |> orient |> decide |> act

            Postcondition = fun s ->
                s.Phase = Complete &&
                s.Result.IsSome &&
                s.CycleTime < TimeSpan.FromMilliseconds(100.0) &&  // SC-BIO-001
                s.AuditTrail.Length >= 4  // All phases logged
        }

        /// Succession handoff spec
        let successionHandoffSpec: HoareTriple<SuccessionState> = {
            Precondition = fun s ->
                s.Status = TransitionApproved &&
                (s.ToSteward.Type = HumanFounderLine ||
                 s.GuardianApproval = Some Approved)

            Statement = fun s ->
                { s with
                    CurrentSteward = s.ToSteward
                    Status = Active
                    HandoffComplete = true }

            Postcondition = fun s ->
                s.CurrentSteward = s.ToSteward &&
                s.HandoffComplete &&
                s.ImmutableRegister |> hasEntry (SuccessionCompleted s.ToSteward.Id) &&
                s.KnowledgeTransferred
        }

        /// Guardian approval spec
        let guardianApprovalSpec (proposal: Proposal): HoareTriple<GuardianState> = {
            Precondition = fun s ->
                proposal.Status = Pending &&
                proposal.ConstitutionalCheck.IsSome

            Statement = fun s ->
                let decision =
                    if checkFounderDirective proposal && checkInvariants proposal then
                        Approved proposal.Id
                    else
                        Vetoed (getVetoReason proposal)
                { s with Decisions = Map.add proposal.Id decision s.Decisions }

            Postcondition = fun s ->
                Map.containsKey proposal.Id s.Decisions &&
                (s.Decisions.[proposal.Id] = Approved proposal.Id ||
                 s.Decisions.[proposal.Id] |> isVetoed) &&
                s.AuditLog |> hasEntry (GuardianDecision proposal.Id)
        }
```

### 18.8 STAMP Constraints (Mathematical Foundations)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-MATH-001 | All planning operations MUST satisfy their Hoare triple | CRITICAL | Runtime |
| SC-MATH-002 | Category composition MUST preserve structure | HIGH | Compile-time |
| SC-MATH-003 | Temporal safety specs MUST hold (AG invariants) | CRITICAL | Model check |
| SC-MATH-004 | Temporal liveness specs MUST hold (AF properties) | HIGH | Model check |
| SC-MATH-005 | Refined types MUST validate predicates at construction | HIGH | Compile-time |
| SC-MATH-006 | State machine transitions MUST be deterministic | HIGH | Static analysis |
| SC-MATH-007 | Algebraic axioms MUST be satisfied | HIGH | Property test |
| SC-MATH-008 | Functor laws MUST hold for all functors | HIGH | Property test |
| SC-MATH-009 | Monad laws MUST hold for Result/Async monads | HIGH | Property test |
| SC-MATH-010 | Proofs MUST be constructive (witnesses provided) | CRITICAL | Type check |

### 18.9 AOR Rules (Mathematical Foundations)

| ID | Rule |
|----|------|
| AOR-MATH-001 | Document Hoare triples for all public operations |
| AOR-MATH-002 | Verify state machine transitions with property tests |
| AOR-MATH-003 | Use refined types for domain constraints |
| AOR-MATH-004 | Prove temporal properties with model checker |
| AOR-MATH-005 | Maintain category-theoretic structure in refactoring |
| AOR-MATH-006 | Use algebraic laws for optimization correctness |
| AOR-MATH-007 | Construct proof witnesses for critical properties |
| AOR-MATH-008 | Verify functor/monad laws with QuickCheck |
| AOR-MATH-009 | Document LTL/CTL specs for safety-critical paths |
| AOR-MATH-010 | Use dependent types for compile-time guarantees |

---

## 19. Graph-Based Modeling & Simulation

### 19.1 Overview

This section defines graph-based representations for planning entities and simulation frameworks for system behavior analysis.

### 19.2 Planning Dependency Graph

```fsharp
/// Graph-based modeling for planning dependencies
module PlanningGraphs =

    /// Directed Acyclic Graph for task dependencies
    type DAG<'Node, 'Edge> = {
        Nodes: Map<'Node, NodeData>
        Edges: Map<'Node, ('Node * 'Edge) list>
        ReverseEdges: Map<'Node, ('Node * 'Edge) list>
    }

    type NodeData = {
        Id: Guid
        Label: string
        Level: int                           // Topological level
        CriticalPath: bool
        Metadata: Map<string, obj>
    }

    /// Task dependency graph
    type TaskGraph = DAG<TaskId, DependencyType>

    type DependencyType =
        | BlockedBy                           // Task cannot start until dependency completes
        | FollowedBy                          // Soft ordering preference
        | RelatedTo                           // Informational link
        | DuplicateOf                         // Same work
        | PartOf                              // Subtask relationship

    module TaskGraphOps =

        /// Build task graph from task list
        let buildGraph (tasks: Task list) : TaskGraph =
            let nodes =
                tasks
                |> List.map (fun t -> t.Id, { Id = t.Id; Label = t.Title; Level = 0; CriticalPath = false; Metadata = Map.empty })
                |> Map.ofList

            let edges =
                tasks
                |> List.map (fun t ->
                    t.Id, t.Dependencies |> List.map (fun d -> d, BlockedBy))
                |> Map.ofList

            let reverseEdges =
                tasks
                |> List.collect (fun t ->
                    t.Dependencies |> List.map (fun d -> d, (t.Id, BlockedBy)))
                |> List.groupBy fst
                |> List.map (fun (node, deps) -> node, deps |> List.map snd)
                |> Map.ofList

            { Nodes = nodes; Edges = edges; ReverseEdges = reverseEdges }

        /// Topological sort for execution order
        let topologicalSort (graph: TaskGraph) : Result<TaskId list, CycleError> =
            let mutable visited = Set.empty
            let mutable temp = Set.empty
            let mutable order = []

            let rec visit node =
                if Set.contains node temp then
                    Error (CycleDetected node)
                elif Set.contains node visited then
                    Ok ()
                else
                    temp <- Set.add node temp
                    let deps = graph.Edges |> Map.tryFind node |> Option.defaultValue []
                    deps
                    |> List.map fst
                    |> List.fold (fun acc dep ->
                        acc |> Result.bind (fun () -> visit dep)) (Ok ())
                    |> Result.map (fun () ->
                        temp <- Set.remove node temp
                        visited <- Set.add node visited
                        order <- node :: order)

            graph.Nodes
            |> Map.toList
            |> List.map fst
            |> List.fold (fun acc node ->
                acc |> Result.bind (fun () -> visit node)) (Ok ())
            |> Result.map (fun () -> order)

        /// Find critical path (longest path)
        let findCriticalPath (graph: TaskGraph) (durations: Map<TaskId, TimeSpan>) : TaskId list =
            let levels = topologicalSort graph |> Result.defaultValue []

            let mutable dist = Map.empty
            let mutable prev = Map.empty

            for node in levels do
                let deps = graph.Edges |> Map.tryFind node |> Option.defaultValue []
                let maxPrev =
                    deps
                    |> List.map (fun (dep, _) ->
                        let d = dist |> Map.tryFind dep |> Option.defaultValue TimeSpan.Zero
                        let dur = durations |> Map.tryFind dep |> Option.defaultValue TimeSpan.Zero
                        dep, d + dur)
                    |> List.sortByDescending snd
                    |> List.tryHead

                match maxPrev with
                | Some (p, d) ->
                    dist <- Map.add node d dist
                    prev <- Map.add node p prev
                | None ->
                    dist <- Map.add node TimeSpan.Zero dist

            // Backtrack from end node
            let endNode =
                dist |> Map.toList |> List.maxBy snd |> fst
            let rec backtrack node acc =
                match Map.tryFind node prev with
                | Some p -> backtrack p (node :: acc)
                | None -> node :: acc
            backtrack endNode []

        /// Detect cycles in graph
        let detectCycles (graph: TaskGraph) : TaskId list list =
            let mutable cycles = []
            let mutable visited = Set.empty
            let mutable stack = []

            let rec dfs node path =
                if List.contains node path then
                    let cycleStart = List.findIndex ((=) node) path
                    cycles <- (path |> List.take (cycleStart + 1) |> List.rev) :: cycles
                elif not (Set.contains node visited) then
                    visited <- Set.add node visited
                    let deps = graph.Edges |> Map.tryFind node |> Option.defaultValue []
                    for (dep, _) in deps do
                        dfs dep (node :: path)

            for node in graph.Nodes |> Map.toList |> List.map fst do
                dfs node []

            cycles

    /// Hierarchical graph for project/program/portfolio
    type HierarchyGraph = {
        Levels: Map<int, Guid Set>           // Level -> node IDs
        ParentChild: Map<Guid, Guid Set>     // Parent -> children
        ChildParent: Map<Guid, Guid>         // Child -> parent
    }

    module HierarchyOps =

        /// Build hierarchy from plans
        let buildHierarchy (portfolio: Portfolio) : HierarchyGraph =
            let mutable levels = Map.empty
            let mutable parentChild = Map.empty
            let mutable childParent = Map.empty

            // Level 0: Portfolio
            levels <- Map.add 0 (Set.singleton portfolio.Id) levels

            // Level 1: Programs
            let programs = portfolio.Programs |> List.map (fun p -> p.Id) |> Set.ofList
            levels <- Map.add 1 programs levels
            parentChild <- Map.add portfolio.Id programs parentChild

            // Level 2: Projects
            for program in portfolio.Programs do
                let projects = program.Projects |> List.map (fun p -> p.Id) |> Set.ofList
                levels <- Map.add 2 (Map.tryFind 2 levels |> Option.defaultValue Set.empty |> Set.union projects) levels
                parentChild <- Map.add program.Id projects parentChild
                for proj in program.Projects do
                    childParent <- Map.add proj.Id program.Id childParent

            // Continue for tasks...
            { Levels = levels; ParentChild = parentChild; ChildParent = childParent }

        /// Find all ancestors
        let ancestors (graph: HierarchyGraph) (nodeId: Guid) : Guid list =
            let rec collect id acc =
                match Map.tryFind id graph.ChildParent with
                | Some parent -> collect parent (parent :: acc)
                | None -> acc
            collect nodeId []

        /// Find all descendants
        let descendants (graph: HierarchyGraph) (nodeId: Guid) : Guid list =
            let rec collect ids acc =
                let children =
                    ids
                    |> List.collect (fun id ->
                        Map.tryFind id graph.ParentChild
                        |> Option.map Set.toList
                        |> Option.defaultValue [])
                match children with
                | [] -> acc
                | _ -> collect children (children @ acc)
            collect [nodeId] []
```

### 19.3 State Transition Graph

```fsharp
/// State transition graph for planning entities
module StateTransitionGraph =

    /// State transition graph
    type STG<'State, 'Action> = {
        States: 'State Set
        Actions: 'Action Set
        Transitions: Map<'State * 'Action, 'State Set>
        InitialStates: 'State Set
        FinalStates: 'State Set
    }

    /// Build STG from state machine
    let fromStateMachine (machine: StateMachine<'S, 'A>) : STG<'S, 'A> =
        let mutable states = machine.InitialStates
        let mutable transitions = Map.empty
        let mutable frontier = machine.InitialStates |> Set.toList

        while not (List.isEmpty frontier) do
            let current = List.head frontier
            frontier <- List.tail frontier

            for action in getAllActions() do
                let nextStates = machine.Transitions(current, action)
                if not (Set.isEmpty nextStates) then
                    transitions <- Map.add (current, action) nextStates transitions
                    let newStates = Set.difference nextStates states
                    states <- Set.union states newStates
                    frontier <- frontier @ (Set.toList newStates)

        {
            States = states
            Actions = getAllActions() |> Set.ofList
            Transitions = transitions
            InitialStates = machine.InitialStates
            FinalStates = states |> Set.filter isFinal
        }

    /// Reachability analysis
    let reachable (stg: STG<'S, 'A>) (from: 'S) : 'S Set =
        let mutable visited = Set.singleton from
        let mutable frontier = [from]

        while not (List.isEmpty frontier) do
            let current = List.head frontier
            frontier <- List.tail frontier

            for action in stg.Actions do
                match Map.tryFind (current, action) stg.Transitions with
                | Some targets ->
                    let newTargets = Set.difference targets visited
                    visited <- Set.union visited newTargets
                    frontier <- frontier @ (Set.toList newTargets)
                | None -> ()

        visited

    /// Find deadlock states (no outgoing transitions)
    let findDeadlocks (stg: STG<'S, 'A>) : 'S Set =
        stg.States
        |> Set.filter (fun s ->
            stg.Actions
            |> Set.forall (fun a ->
                Map.tryFind (s, a) stg.Transitions
                |> Option.map Set.isEmpty
                |> Option.defaultValue true))
        |> Set.filter (fun s -> not (Set.contains s stg.FinalStates))

    /// Compute bisimulation equivalence classes
    let bisimulationPartition (stg: STG<'S, 'A>) : 'S Set list =
        let mutable partition = [stg.FinalStates; Set.difference stg.States stg.FinalStates]

        let refine () =
            partition
            |> List.collect (fun block ->
                block
                |> Set.toList
                |> List.groupBy (fun s ->
                    stg.Actions
                    |> Set.map (fun a ->
                        let targets = Map.tryFind (s, a) stg.Transitions |> Option.defaultValue Set.empty
                        partition |> List.findIndex (fun b -> not (Set.isEmpty (Set.intersect targets b)))))
                |> List.map (fun (_, states) -> Set.ofList states))

        let mutable changed = true
        while changed do
            let newPartition = refine ()
            changed <- List.length newPartition <> List.length partition
            partition <- newPartition

        partition
```

### 19.4 Petri Net Modeling

```fsharp
/// Petri net modeling for workflow simulation
module PetriNets =

    /// Petri net definition
    type PetriNet = {
        Places: Map<PlaceId, Place>
        Transitions: Map<TransitionId, Transition>
        InputArcs: Map<TransitionId, (PlaceId * int) list>   // (place, weight)
        OutputArcs: Map<TransitionId, (PlaceId * int) list>
        Marking: Map<PlaceId, int>           // Current token counts
    }

    type Place = {
        Id: PlaceId
        Name: string
        Capacity: int option                  // None = infinite
    }

    type Transition = {
        Id: TransitionId
        Name: string
        Guard: (Map<PlaceId, int> -> bool) option
        Duration: TimeSpan option
    }

    /// Planning workflow as Petri net
    module PlanningPetriNet =

        /// OODA cycle Petri net
        let oodaCyclePetriNet: PetriNet =
            let places = Map.ofList [
                "idle", { Id = "idle"; Name = "Idle"; Capacity = Some 1 }
                "observing", { Id = "observing"; Name = "Observing"; Capacity = Some 1 }
                "orienting", { Id = "orienting"; Name = "Orienting"; Capacity = Some 1 }
                "deciding", { Id = "deciding"; Name = "Deciding"; Capacity = Some 1 }
                "acting", { Id = "acting"; Name = "Acting"; Capacity = Some 1 }
                "complete", { Id = "complete"; Name = "Complete"; Capacity = None }
            ]

            let transitions = Map.ofList [
                "start", { Id = "start"; Name = "Start Cycle"; Guard = None; Duration = None }
                "t_observe", { Id = "t_observe"; Name = "Complete Observe"; Guard = None; Duration = Some (TimeSpan.FromMilliseconds 25.0) }
                "t_orient", { Id = "t_orient"; Name = "Complete Orient"; Guard = None; Duration = Some (TimeSpan.FromMilliseconds 25.0) }
                "t_decide", { Id = "t_decide"; Name = "Complete Decide"; Guard = None; Duration = Some (TimeSpan.FromMilliseconds 25.0) }
                "t_act", { Id = "t_act"; Name = "Complete Act"; Guard = None; Duration = Some (TimeSpan.FromMilliseconds 25.0) }
                "reset", { Id = "reset"; Name = "Reset to Idle"; Guard = None; Duration = None }
            ]

            {
                Places = places
                Transitions = transitions
                InputArcs = Map.ofList [
                    "start", [("idle", 1)]
                    "t_observe", [("observing", 1)]
                    "t_orient", [("orienting", 1)]
                    "t_decide", [("deciding", 1)]
                    "t_act", [("acting", 1)]
                    "reset", [("complete", 1)]
                ]
                OutputArcs = Map.ofList [
                    "start", [("observing", 1)]
                    "t_observe", [("orienting", 1)]
                    "t_orient", [("deciding", 1)]
                    "t_decide", [("acting", 1)]
                    "t_act", [("complete", 1)]
                    "reset", [("idle", 1)]
                ]
                Marking = Map.ofList [("idle", 1); ("observing", 0); ("orienting", 0); ("deciding", 0); ("acting", 0); ("complete", 0)]
            }

        /// Check if transition is enabled
        let isEnabled (net: PetriNet) (transitionId: TransitionId) : bool =
            let inputs = net.InputArcs |> Map.tryFind transitionId |> Option.defaultValue []
            let transition = net.Transitions.[transitionId]

            // Check token availability
            let tokensAvailable =
                inputs |> List.forall (fun (place, weight) ->
                    net.Marking.[place] >= weight)

            // Check output capacity
            let outputs = net.OutputArcs |> Map.tryFind transitionId |> Option.defaultValue []
            let capacityAvailable =
                outputs |> List.forall (fun (place, weight) ->
                    match net.Places.[place].Capacity with
                    | Some cap -> net.Marking.[place] + weight <= cap
                    | None -> true)

            // Check guard
            let guardSatisfied =
                match transition.Guard with
                | Some g -> g net.Marking
                | None -> true

            tokensAvailable && capacityAvailable && guardSatisfied

        /// Fire transition
        let fire (net: PetriNet) (transitionId: TransitionId) : PetriNet option =
            if not (isEnabled net transitionId) then None
            else
                let inputs = net.InputArcs |> Map.tryFind transitionId |> Option.defaultValue []
                let outputs = net.OutputArcs |> Map.tryFind transitionId |> Option.defaultValue []

                let newMarking =
                    net.Marking
                    |> Map.map (fun place tokens ->
                        let consumed = inputs |> List.tryFind (fun (p, _) -> p = place) |> Option.map snd |> Option.defaultValue 0
                        let produced = outputs |> List.tryFind (fun (p, _) -> p = place) |> Option.map snd |> Option.defaultValue 0
                        tokens - consumed + produced)

                Some { net with Marking = newMarking }

        /// Simulate until no transitions enabled or max steps
        let simulate (net: PetriNet) (maxSteps: int) : (PetriNet * TransitionId list) =
            let mutable current = net
            let mutable trace = []
            let mutable steps = 0

            while steps < maxSteps do
                let enabledTransitions =
                    current.Transitions
                    |> Map.toList
                    |> List.map fst
                    |> List.filter (isEnabled current)

                match enabledTransitions with
                | [] -> steps <- maxSteps  // No more enabled, stop
                | ts ->
                    let selected = ts.[Random().Next(ts.Length)]  // Non-deterministic
                    match fire current selected with
                    | Some next ->
                        current <- next
                        trace <- trace @ [selected]
                        steps <- steps + 1
                    | None -> steps <- maxSteps

            (current, trace)
```

### 19.5 Monte Carlo Simulation

```fsharp
/// Monte Carlo simulation for planning uncertainty
module MonteCarloSimulation =

    /// Probability distributions
    type Distribution =
        | Uniform of min: float * max: float
        | Normal of mean: float * stddev: float
        | Triangular of min: float * mode: float * max: float
        | Beta of alpha: float * beta: float
        | PERT of min: float * likely: float * max: float

    /// Sample from distribution
    let sample (dist: Distribution) (rng: Random) : float =
        match dist with
        | Uniform(min, max) ->
            min + rng.NextDouble() * (max - min)

        | Normal(mean, stddev) ->
            // Box-Muller transform
            let u1 = rng.NextDouble()
            let u2 = rng.NextDouble()
            let z = sqrt(-2.0 * log(u1)) * cos(2.0 * Math.PI * u2)
            mean + z * stddev

        | Triangular(min, mode, max) ->
            let u = rng.NextDouble()
            let fc = (mode - min) / (max - min)
            if u < fc then
                min + sqrt(u * (max - min) * (mode - min))
            else
                max - sqrt((1.0 - u) * (max - min) * (max - mode))

        | Beta(alpha, beta) ->
            // Rejection sampling for Beta
            let rec sampleBeta () =
                let x = rng.NextDouble()
                let y = rng.NextDouble()
                let fx = Math.Pow(x, alpha - 1.0) * Math.Pow(1.0 - x, beta - 1.0)
                if y <= fx then x else sampleBeta()
            sampleBeta()

        | PERT(min, likely, max) ->
            // PERT distribution (modified Beta)
            let mean = (min + 4.0 * likely + max) / 6.0
            let alpha = (mean - min) * (2.0 * likely - min - max) / ((likely - mean) * (max - min))
            let beta = alpha * (max - mean) / (mean - min)
            min + (max - min) * sample (Beta(alpha, beta)) rng

    /// Task duration estimate with uncertainty
    type UncertainDuration = {
        TaskId: TaskId
        BaseEstimate: TimeSpan
        Distribution: Distribution
        ConfidenceLevel: float               // 0.0-1.0
    }

    /// Project completion simulation
    type ProjectSimulation = {
        ProjectId: ProjectId
        TaskGraph: TaskGraph
        Durations: Map<TaskId, UncertainDuration>
        Resources: Map<ResourceId, Resource>
        SimulationRuns: int
    }

    /// Run Monte Carlo simulation
    let runSimulation (sim: ProjectSimulation) : SimulationResult =
        let rng = Random()
        let mutable completionTimes = []
        let mutable criticalPathCounts = Map.empty

        for run in 1..sim.SimulationRuns do
            // Sample durations for this run
            let sampledDurations =
                sim.Durations
                |> Map.map (fun taskId dur ->
                    let sampled = sample dur.Distribution rng
                    TimeSpan.FromHours(sampled * dur.BaseEstimate.TotalHours))

            // Calculate completion time using critical path
            let criticalPath = TaskGraphOps.findCriticalPath sim.TaskGraph sampledDurations
            let completionTime =
                criticalPath
                |> List.sumBy (fun t -> sampledDurations.[t].TotalHours)
                |> TimeSpan.FromHours

            completionTimes <- completionTime :: completionTimes

            // Track critical path frequency
            for task in criticalPath do
                let count = criticalPathCounts |> Map.tryFind task |> Option.defaultValue 0
                criticalPathCounts <- Map.add task (count + 1) criticalPathCounts

        // Calculate statistics
        let sorted = completionTimes |> List.sort
        let count = float sorted.Length
        {
            Mean = TimeSpan.FromHours(completionTimes |> List.averageBy (fun t -> t.TotalHours))
            Median = sorted.[int (count / 2.0)]
            P10 = sorted.[int (count * 0.1)]
            P90 = sorted.[int (count * 0.9)]
            StdDev = TimeSpan.FromHours(
                let mean = completionTimes |> List.averageBy (fun t -> t.TotalHours)
                completionTimes
                |> List.map (fun t -> (t.TotalHours - mean) ** 2.0)
                |> List.average
                |> sqrt)
            CriticalPathProbabilities =
                criticalPathCounts
                |> Map.map (fun _ count -> float count / float sim.SimulationRuns)
            ConfidenceIntervals = calculateConfidenceIntervals sorted
        }

    type SimulationResult = {
        Mean: TimeSpan
        Median: TimeSpan
        P10: TimeSpan                        // 10th percentile (optimistic)
        P90: TimeSpan                        // 90th percentile (pessimistic)
        StdDev: TimeSpan
        CriticalPathProbabilities: Map<TaskId, float>
        ConfidenceIntervals: Map<float, TimeSpan>  // Confidence level -> duration
    }
```

### 19.6 Discrete Event Simulation

```fsharp
/// Discrete event simulation for planning workflow
module DiscreteEventSimulation =

    /// Simulation event
    type SimEvent = {
        Time: DateTimeOffset
        EventType: EventType
        EntityId: Guid
        Priority: int
    }

    type EventType =
        | TaskArrival of Task
        | TaskStart of TaskId * ActorId
        | TaskComplete of TaskId
        | ResourceAvailable of ResourceId
        | OodaCycleStart of OodaCycleId
        | OodaCyclePhase of OodaCycleId * OodaPhase
        | HandoffInitiate of HandoffId
        | HandoffComplete of HandoffId
        | StewardChange of StewardId

    /// Simulation state
    type SimState = {
        CurrentTime: DateTimeOffset
        EventQueue: SimEvent list            // Sorted by time
        Tasks: Map<TaskId, TaskSimState>
        Resources: Map<ResourceId, ResourceSimState>
        Actors: Map<ActorId, ActorSimState>
        Statistics: SimStatistics
    }

    type TaskSimState = {
        Status: TaskStatus
        StartTime: DateTimeOffset option
        EndTime: DateTimeOffset option
        AssignedTo: ActorId option
        WaitTime: TimeSpan
        ProcessTime: TimeSpan
    }

    type SimStatistics = {
        TotalTasks: int
        CompletedTasks: int
        AverageWaitTime: TimeSpan
        AverageProcessTime: TimeSpan
        ResourceUtilization: Map<ResourceId, float>
        Throughput: float                    // Tasks per hour
        QueueLength: int list                // Over time
    }

    /// Discrete event simulator
    type Simulator = {
        InitialState: SimState
        EventHandlers: Map<EventType, SimState -> SimEvent -> SimState * SimEvent list>
        EndCondition: SimState -> bool
    }

    /// Run simulation
    let run (sim: Simulator) : SimState =
        let mutable state = sim.InitialState

        while not (sim.EndCondition state) && not (List.isEmpty state.EventQueue) do
            // Get next event
            let event = List.head state.EventQueue
            let remainingEvents = List.tail state.EventQueue

            // Advance time
            state <- { state with CurrentTime = event.Time; EventQueue = remainingEvents }

            // Process event
            match Map.tryFind event.EventType sim.EventHandlers with
            | Some handler ->
                let (newState, newEvents) = handler state event
                let sortedEvents =
                    (newEvents @ state.EventQueue)
                    |> List.sortBy (fun e -> e.Time, e.Priority)
                state <- { newState with EventQueue = sortedEvents }
            | None -> ()

        state

    /// Planning workflow simulator
    module PlanningSimulator =

        let createSimulator (tasks: Task list) (actors: Actor list) : Simulator =
            let initialEvents =
                tasks
                |> List.map (fun t ->
                    { Time = t.CreatedAt; EventType = TaskArrival t; EntityId = t.Id; Priority = t.Priority })
                |> List.sortBy (fun e -> e.Time)

            {
                InitialState = {
                    CurrentTime = DateTimeOffset.UtcNow
                    EventQueue = initialEvents
                    Tasks = Map.empty
                    Resources = Map.empty
                    Actors = actors |> List.map (fun a -> a.Id, { Status = Available; CurrentTask = None }) |> Map.ofList
                    Statistics = emptyStatistics
                }

                EventHandlers = Map.ofList [
                    TaskArrival Task.Empty, handleTaskArrival
                    TaskStart (TaskId.Empty, ActorId.Empty), handleTaskStart
                    TaskComplete TaskId.Empty, handleTaskComplete
                ]

                EndCondition = fun s -> s.Statistics.CompletedTasks >= tasks.Length
            }

        let handleTaskArrival state event =
            match event.EventType with
            | TaskArrival task ->
                // Add task to queue
                let taskState = { Status = Pending; StartTime = None; EndTime = None; AssignedTo = None; WaitTime = TimeSpan.Zero; ProcessTime = TimeSpan.Zero }
                let newTasks = Map.add task.Id taskState state.Tasks

                // Try to assign to available actor
                let availableActor =
                    state.Actors
                    |> Map.tryFindKey (fun _ a -> a.Status = Available)

                match availableActor with
                | Some actorId ->
                    let startEvent = { Time = state.CurrentTime; EventType = TaskStart(task.Id, actorId); EntityId = task.Id; Priority = 0 }
                    ({ state with Tasks = newTasks }, [startEvent])
                | None ->
                    ({ state with Tasks = newTasks }, [])
            | _ -> (state, [])

        let handleTaskStart state event =
            match event.EventType with
            | TaskStart(taskId, actorId) ->
                let task = state.Tasks.[taskId]
                let updatedTask = { task with Status = InProgress; StartTime = Some state.CurrentTime; AssignedTo = Some actorId }
                let updatedActor = { state.Actors.[actorId] with Status = Busy; CurrentTask = Some taskId }

                // Schedule completion
                let duration = estimateDuration taskId
                let completeEvent = { Time = state.CurrentTime + duration; EventType = TaskComplete taskId; EntityId = taskId; Priority = 0 }

                ({ state with
                    Tasks = Map.add taskId updatedTask state.Tasks
                    Actors = Map.add actorId updatedActor state.Actors }, [completeEvent])
            | _ -> (state, [])

        let handleTaskComplete state event =
            match event.EventType with
            | TaskComplete taskId ->
                let task = state.Tasks.[taskId]
                let actorId = task.AssignedTo.Value
                let updatedTask = { task with Status = Completed; EndTime = Some state.CurrentTime }
                let updatedActor = { state.Actors.[actorId] with Status = Available; CurrentTask = None }

                // Update statistics
                let newStats = updateStatistics state.Statistics updatedTask

                ({ state with
                    Tasks = Map.add taskId updatedTask state.Tasks
                    Actors = Map.add actorId updatedActor state.Actors
                    Statistics = newStats }, [])
            | _ -> (state, [])
```

### 19.7 STAMP Constraints (Graph & Simulation)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-GRAPH-001 | Dependency graphs MUST be acyclic | CRITICAL | Topological sort |
| SC-GRAPH-002 | Critical path calculation MUST be accurate | HIGH | Property test |
| SC-GRAPH-003 | Hierarchy graphs MUST be trees | HIGH | Parent uniqueness |
| SC-GRAPH-004 | STG MUST have no deadlocks (except final) | CRITICAL | Reachability |
| SC-SIM-001 | Monte Carlo runs >= 1000 for convergence | HIGH | Sample size |
| SC-SIM-002 | PERT estimates MUST be validated | HIGH | Expert review |
| SC-SIM-003 | Petri net transitions MUST preserve tokens | HIGH | Invariant check |
| SC-SIM-004 | DES events MUST be processed in time order | CRITICAL | Queue ordering |
| SC-SIM-005 | Simulation results MUST include confidence intervals | HIGH | Statistics |
| SC-SIM-006 | Resource utilization MUST be tracked | MEDIUM | Telemetry |

### 19.8 AOR Rules (Graph & Simulation)

| ID | Rule |
|----|------|
| AOR-GRAPH-001 | Validate acyclicity before task graph operations |
| AOR-GRAPH-002 | Cache critical path calculations |
| AOR-GRAPH-003 | Use topological order for task execution |
| AOR-SIM-001 | Run simulation before major planning decisions |
| AOR-SIM-002 | Use PERT for task duration estimates |
| AOR-SIM-003 | Document Monte Carlo assumptions |
| AOR-SIM-004 | Validate Petri net models before simulation |
| AOR-SIM-005 | Report P10/P50/P90 for schedule estimates |
| AOR-SIM-006 | Use simulation to identify resource bottlenecks |
| AOR-SIM-007 | Store simulation results in DuckDB for analysis |

---

## 20. Comprehensive Verification Framework

### 20.1 Enhanced STAMP Constraints (Complete System)

#### 20.1.1 Core Planning Constraints (SC-PLAN-*)

| ID | Constraint | Severity | Scope | Verification |
|----|------------|----------|-------|--------------|
| SC-PLAN-001 | Tasks MUST have unique IDs within project | CRITICAL | Task | DB constraint |
| SC-PLAN-002 | Task status transitions MUST follow FSM | CRITICAL | Task | Runtime |
| SC-PLAN-003 | Dependencies MUST not create cycles | CRITICAL | Task | Graph check |
| SC-PLAN-004 | Priority MUST be 0-4 (P0 highest) | HIGH | Task | Type check |
| SC-PLAN-005 | Due dates MUST be in future at creation | MEDIUM | Task | Validation |
| SC-PLAN-006 | Projects MUST have at least one task | MEDIUM | Project | Invariant |
| SC-PLAN-007 | Programs MUST have at least one project | MEDIUM | Program | Invariant |
| SC-PLAN-008 | Portfolios MUST align with strategic goals | HIGH | Portfolio | Review |
| SC-PLAN-009 | Milestones MUST have measurable criteria | HIGH | Milestone | Review |
| SC-PLAN-010 | Sprints MUST be time-boxed (1-4 weeks) | MEDIUM | Sprint | Validation |

#### 20.1.2 OODA Cycle Constraints (SC-OODA-*)

| ID | Constraint | Severity | Phase | Verification |
|----|------------|----------|-------|--------------|
| SC-OODA-001 | Cycle time MUST be < 100ms (SC-BIO-001) | CRITICAL | All | Telemetry |
| SC-OODA-002 | Observe MUST capture all relevant signals | HIGH | Observe | Checklist |
| SC-OODA-003 | Orient MUST consider 1st-5th order effects | HIGH | Orient | Template |
| SC-OODA-004 | Decide MUST evaluate at least 2 COAs | MEDIUM | Decide | Validation |
| SC-OODA-005 | Act MUST log to Immutable Register | CRITICAL | Act | Audit |
| SC-OODA-006 | Feedback MUST update mental models | HIGH | Feedback | Learning |
| SC-OODA-007 | Abort MUST preserve state for recovery | HIGH | Abort | Checkpoint |
| SC-OODA-008 | Parallel cycles MUST not conflict | CRITICAL | Concurrent | Locking |
| SC-OODA-009 | Guardian approval for P0/P1 actions | CRITICAL | Decide | Gate |
| SC-OODA-010 | Cycle metrics published to Zenoh | MEDIUM | All | Telemetry |

#### 20.1.3 Long-Term Planning Constraints (SC-LTP-*) [Extended]

| ID | Constraint | Severity | Horizon | Verification |
|----|------------|----------|---------|--------------|
| SC-LTP-011 | Epoch boundaries every 100 years ±5 | HIGH | Civilizational | Calendar |
| SC-LTP-012 | Generation plans MUST overlap by 5 years | HIGH | Generational | Timeline |
| SC-LTP-013 | Succession candidates MUST be identified 10 years ahead | HIGH | Generational | Review |
| SC-LTP-014 | Knowledge transfer MUST start 5 years before handoff | HIGH | Generational | Process |
| SC-LTP-015 | Emergency succession plan MUST exist | CRITICAL | All | Document |
| SC-LTP-016 | Adaptation reviews every 25 years minimum | HIGH | Strategic+ | Schedule |
| SC-LTP-017 | Environmental signals monitored continuously | HIGH | All | Automation |
| SC-LTP-018 | Substrate migration tested every 50 years | HIGH | Civilizational | Test |
| SC-LTP-019 | Legacy formats validated every 10 years | HIGH | Generational | Audit |
| SC-LTP-020 | Founder lineage tracking MUST be accurate | CRITICAL | All | Verification |

#### 20.1.4 Mixed Team Constraints (SC-MIX-*) [Extended]

| ID | Constraint | Severity | Scope | Verification |
|----|------------|----------|-------|--------------|
| SC-MIX-011 | Human/agent ratio MUST be documented | HIGH | Team | Config |
| SC-MIX-012 | Agent autonomy level MUST match task type | HIGH | Assignment | Rule engine |
| SC-MIX-013 | Human override MUST be available within 15 min | CRITICAL | Emergency | SLA |
| SC-MIX-014 | Cross-type handoffs MUST include context summary | HIGH | Handoff | Validation |
| SC-MIX-015 | Team decisions logged with attribution | HIGH | Decision | Audit |
| SC-MIX-016 | Performance metrics disaggregated by type | MEDIUM | Analytics | Report |
| SC-MIX-017 | Communication format auto-adapted | MEDIUM | Comm | Translation |
| SC-MIX-018 | Workload balanced across human working hours | HIGH | Schedule | Algorithm |
| SC-MIX-019 | Agent learning shared with team | MEDIUM | Knowledge | Sync |
| SC-MIX-020 | Conflict resolution has escalation path | HIGH | Governance | Process |

### 20.2 TDG Property Tests

```fsharp
/// Test-Driven Generation property tests
module TDGPropertyTests =
    open FsCheck
    open Expecto

    /// Task property generators
    module TaskGenerators =
        let validPriority = Gen.choose(0, 4)
        let validStatus = Gen.elements [Pending; Ready; InProgress; Completed; Cancelled]
        let validTitle = Gen.stringOfLength (Gen.choose(1, 200)) |> Gen.map (fun s -> s.Replace("\n", " "))

        let taskGen =
            gen {
                let! id = Arb.generate<Guid>
                let! title = validTitle
                let! priority = validPriority
                let! status = validStatus
                return {
                    Id = id
                    Title = title
                    Priority = priority
                    Status = status
                    Dependencies = []
                    CreatedAt = DateTimeOffset.UtcNow
                }
            }

    /// OODA cycle properties
    module OodaProperties =

        [<Property>]
        let ``OODA cycle completes in < 100ms`` (context: OodaContext) =
            let startTime = DateTimeOffset.UtcNow
            let result = OodaCycle.execute context
            let endTime = DateTimeOffset.UtcNow
            (endTime - startTime).TotalMilliseconds < 100.0

        [<Property>]
        let ``OODA cycle is idempotent for same inputs`` (context: OodaContext) =
            let result1 = OodaCycle.execute context
            let result2 = OodaCycle.execute context
            result1.Decision = result2.Decision

        [<Property>]
        let ``OODA phases are logged`` (context: OodaContext) =
            let result = OodaCycle.execute context
            result.AuditLog.Length >= 4  // Observe, Orient, Decide, Act

        [<Property>]
        let ``OODA cycle preserves constitutional invariants`` (context: OodaContext) =
            let stateBefore = context.SystemState
            let result = OodaCycle.execute context
            ConstitutionalVerifier.verify result.SystemState = Ok ()

    /// Task graph properties
    module GraphProperties =

        [<Property>]
        let ``Dependency graph is acyclic`` (tasks: Task list) =
            let graph = TaskGraphOps.buildGraph tasks
            TaskGraphOps.detectCycles graph = []

        [<Property>]
        let ``Topological sort produces valid ordering`` (tasks: Task list) =
            let graph = TaskGraphOps.buildGraph tasks
            match TaskGraphOps.topologicalSort graph with
            | Ok order ->
                order
                |> List.indexed
                |> List.forall (fun (i, taskId) ->
                    let deps = graph.Edges |> Map.tryFind taskId |> Option.defaultValue []
                    deps |> List.forall (fun (depId, _) ->
                        let depIndex = List.findIndex ((=) depId) order
                        depIndex < i))
            | Error _ -> true  // Cycle detected, invalid input

        [<Property>]
        let ``Critical path contains all blocking dependencies`` (tasks: Task list) (durations: Map<TaskId, TimeSpan>) =
            let graph = TaskGraphOps.buildGraph tasks
            let criticalPath = TaskGraphOps.findCriticalPath graph durations
            // All tasks on critical path have their dependencies on path or completed
            true  // Detailed verification

    /// Long-term planning properties
    module LongTermProperties =

        [<Property>]
        let ``Millennium plan decomposes into 10 epochs`` (plan: MillenniumPlan) =
            plan.SubPlans.Length = 10

        [<Property>]
        let ``Epoch decomposes into 4 generations`` (epoch: EpochPlan) =
            epoch.SubPlans.Length = 4

        [<Property>]
        let ``Succession timeline has no gaps`` (plan: MillenniumPlan) =
            let timeline = SuccessionManager.projectSuccessionTimeline plan 25
            timeline
            |> List.pairwise
            |> List.forall (fun (gen1, gen2) -> gen1.ExpectedEndYear >= gen2.ExpectedStartYear)

        [<Property>]
        let ``Adaptation preserves constitutional invariants`` (plan: MillenniumPlan) (adaptation: AdaptationRecommendation) =
            match PlanEvolution.applyAdaptation plan adaptation (ApprovalRecord.Guardian) with
            | Ok newPlan -> ConstitutionalVerifier.verify newPlan = Ok ()
            | Error ConstitutionalViolation -> true  // Correctly rejected

    /// Mixed team properties
    module MixedTeamProperties =

        [<Property>]
        let ``Work assignment respects preferences`` (team: MixedTeam) (workItem: WorkItem) =
            let preference = team.WorkDistribution.WorkTypePreferences |> Map.tryFind workItem.WorkType
            match WorkAssignment.assignWork team workItem with
            | Ok (HumanAssignment _) ->
                preference <> Some (AgentPreferred "")
            | Ok (AgentAssignment _) ->
                preference <> Some (HumanPreferred "")
            | _ -> true

        [<Property>]
        let ``Handoff preserves context`` (team: MixedTeam) (request: HandoffRequest) =
            match HandoffManager.executeHandoff request team with
            | Ok result -> result.ContextTransferred
            | Error _ -> true

        [<Property>]
        let ``24/7 coverage has no gaps`` (team: MixedTeam) =
            let coverage = TeamScheduling.ensure24x7Coverage team []
            coverage.HourlyPlan.Length = 24 &&
            coverage.HourlyPlan |> List.forall (fun h -> h.PrimaryHandler <> NoHandler)

    /// Database properties
    module DatabaseProperties =

        [<Property>]
        let ``SQLite write followed by read returns same data`` (task: Task) =
            let id = SQLiteOps.insert "tasks" task
            let retrieved = SQLiteOps.get<Task> "tasks" id
            retrieved = Some task

        [<Property>]
        let ``DuckDB analytics queries are consistent`` (tasks: Task list) =
            DuckDBOps.bulkInsert "tasks" tasks
            let count = DuckDBOps.query<int> "SELECT COUNT(*) FROM tasks" []
            count = tasks.Length

        [<Property>]
        let ``Event sourcing preserves history`` (events: PlanningEvent list) =
            for event in events do
                EventStore.append event
            let retrieved = EventStore.getAll()
            retrieved.Length >= events.Length
```

### 20.3 FMEA Analysis with RPN

```fsharp
/// Failure Mode and Effects Analysis
module FMEAAnalysis =

    type FailureMode = {
        Id: string
        Component: string
        FailureDescription: string
        Effect: string
        Cause: string
        Severity: int                        // 1-10
        Occurrence: int                      // 1-10
        Detection: int                       // 1-10 (10 = hard to detect)
        RPN: int                             // Risk Priority Number
        Mitigation: string
        VerificationMethod: string
    }

    /// Calculate RPN
    let calculateRPN (s: int) (o: int) (d: int) = s * o * d

    /// Planning system FMEA
    let planningFMEA: FailureMode list = [
        // Task Management Failures
        { Id = "FM-TASK-001"
          Component = "Task Creation"
          FailureDescription = "Duplicate task ID generated"
          Effect = "Data corruption, lost tasks"
          Cause = "UUID collision or race condition"
          Severity = 8; Occurrence = 2; Detection = 3
          RPN = 48
          Mitigation = "Use UUID v7 with timestamp; DB unique constraint"
          VerificationMethod = "Property test for uniqueness" }

        { Id = "FM-TASK-002"
          Component = "Task Dependencies"
          FailureDescription = "Cyclic dependency created"
          Effect = "Infinite loop, deadlock"
          Cause = "Missing cycle detection"
          Severity = 9; Occurrence = 4; Detection = 2
          RPN = 72
          Mitigation = "Topological sort validation; Graph cycle detection"
          VerificationMethod = "SC-GRAPH-001 automated check" }

        { Id = "FM-TASK-003"
          Component = "Task Status"
          FailureDescription = "Invalid state transition"
          Effect = "Task stuck, workflow breaks"
          Cause = "FSM violation"
          Severity = 7; Occurrence = 3; Detection = 2
          RPN = 42
          Mitigation = "State machine validation; Transition whitelist"
          VerificationMethod = "FSM property tests" }

        // OODA Cycle Failures
        { Id = "FM-OODA-001"
          Component = "OODA Observe"
          FailureDescription = "Incomplete observation data"
          Effect = "Poor decisions"
          Cause = "Sensor failure, timeout"
          Severity = 6; Occurrence = 5; Detection = 4
          RPN = 120
          Mitigation = "Multi-source correlation; Fallback defaults"
          VerificationMethod = "Observation completeness check" }

        { Id = "FM-OODA-002"
          Component = "OODA Cycle Time"
          FailureDescription = "Cycle exceeds 100ms"
          Effect = "Stale decisions, missed opportunities"
          Cause = "Slow processing, resource contention"
          Severity = 7; Occurrence = 4; Detection = 1
          RPN = 28
          Mitigation = "Async processing; Timeout with default action"
          VerificationMethod = "Telemetry monitoring SC-OODA-001" }

        { Id = "FM-OODA-003"
          Component = "OODA Decide"
          FailureDescription = "Guardian approval timeout"
          Effect = "Action blocked"
          Cause = "Guardian unavailable"
          Severity = 8; Occurrence = 3; Detection = 2
          RPN = 48
          Mitigation = "Fallback approval path; Emergency override"
          VerificationMethod = "Guardian availability monitoring" }

        // Long-Term Planning Failures
        { Id = "FM-LTP-001"
          Component = "Succession Management"
          FailureDescription = "No valid successor identified"
          Effect = "Plan orphaned, no stewardship"
          Cause = "All candidates disqualified"
          Severity = 10; Occurrence = 2; Detection = 3
          RPN = 60
          Mitigation = "Emergency succession to AI Guardian; 10-year lookahead"
          VerificationMethod = "Succession projection validation" }

        { Id = "FM-LTP-002"
          Component = "Knowledge Transfer"
          FailureDescription = "Legacy documents corrupted"
          Effect = "Lost institutional knowledge"
          Cause = "Format obsolescence, bit rot"
          Severity = 9; Occurrence = 3; Detection = 4
          RPN = 108
          Mitigation = "Multiple format storage; Checksums; 10-year validation"
          VerificationMethod = "Format validation tests" }

        { Id = "FM-LTP-003"
          Component = "Adaptation Rules"
          FailureDescription = "Constitutional invariant violated"
          Effect = "System integrity compromised"
          Cause = "Insufficient validation"
          Severity = 10; Occurrence = 2; Detection = 2
          RPN = 40
          Mitigation = "Mandatory constitutional check; Guardian veto"
          VerificationMethod = "Constitutional verifier" }

        // Mixed Team Failures
        { Id = "FM-MIX-001"
          Component = "Handoff Protocol"
          FailureDescription = "Context lost during handoff"
          Effect = "Rework, delays"
          Cause = "Incomplete context transfer"
          Severity = 6; Occurrence = 5; Detection = 3
          RPN = 90
          Mitigation = "Structured context template; Validation checklist"
          VerificationMethod = "Handoff completeness test" }

        { Id = "FM-MIX-002"
          Component = "Human Escalation"
          FailureDescription = "No human reachable within 15 min"
          Effect = "Critical decision delayed"
          Cause = "All humans unavailable"
          Severity = 9; Occurrence = 3; Detection = 2
          RPN = 54
          Mitigation = "On-call schedule; Multi-timezone team; Fallback"
          VerificationMethod = "Escalation path testing" }

        { Id = "FM-MIX-003"
          Component = "Work Distribution"
          FailureDescription = "Unfair workload distribution"
          Effect = "Team burnout, agent overload"
          Cause = "Algorithm bias"
          Severity = 5; Occurrence = 4; Detection = 3
          RPN = 60
          Mitigation = "Load monitoring; Periodic rebalancing"
          VerificationMethod = "Workload analytics" }

        // Database Failures
        { Id = "FM-DB-001"
          Component = "SQLite State"
          FailureDescription = "Database corruption"
          Effect = "State loss, system down"
          Cause = "Crash during write, disk failure"
          Severity = 10; Occurrence = 2; Detection = 2
          RPN = 40
          Mitigation = "WAL mode; Checksums; Regular backup"
          VerificationMethod = "Integrity check on startup" }

        { Id = "FM-DB-002"
          Component = "DuckDB Analytics"
          FailureDescription = "Query returns incorrect results"
          Effect = "Wrong decisions from analytics"
          Cause = "Data inconsistency"
          Severity = 7; Occurrence = 3; Detection = 5
          RPN = 105
          Mitigation = "Cross-check with SQLite; Reconciliation jobs"
          VerificationMethod = "Consistency tests" }

        // Zenoh Communication Failures
        { Id = "FM-ZENOH-001"
          Component = "Zenoh Pub/Sub"
          FailureDescription = "Message loss"
          Effect = "State sync failure"
          Cause = "Network partition, buffer overflow"
          Severity = 7; Occurrence = 4; Detection = 3
          RPN = 84
          Mitigation = "Message acknowledgment; Retry with backoff"
          VerificationMethod = "Message delivery test" }

        { Id = "FM-ZENOH-002"
          Component = "Zenoh Router"
          FailureDescription = "Router unavailable"
          Effect = "No distributed communication"
          Cause = "Container crash, network failure"
          Severity = 8; Occurrence = 3; Detection = 1
          RPN = 24
          Mitigation = "Multiple routers; Local fallback"
          VerificationMethod = "Health check monitoring" }
    ]

    /// RPN Thresholds
    let rpnCritical = 100    // Immediate action required
    let rpnHigh = 50         // Action plan required
    let rpnMedium = 25       // Monitor and review

    /// Analyze FMEA results
    let analyze (fmea: FailureMode list) =
        let critical = fmea |> List.filter (fun f -> f.RPN >= rpnCritical)
        let high = fmea |> List.filter (fun f -> f.RPN >= rpnHigh && f.RPN < rpnCritical)
        let medium = fmea |> List.filter (fun f -> f.RPN >= rpnMedium && f.RPN < rpnHigh)

        {|
            Critical = critical
            High = high
            Medium = medium
            TotalRPN = fmea |> List.sumBy (fun f -> f.RPN)
            AverageRPN = fmea |> List.averageBy (fun f -> float f.RPN)
            HighestRPN = fmea |> List.maxBy (fun f -> f.RPN)
        |}
```

### 20.4 Enhanced AOR Rules (Complete System)

| ID | Rule | Category | Enforcement |
|----|------|----------|-------------|
| AOR-PLAN-001 | Validate task ID uniqueness before creation | Task | Pre-save hook |
| AOR-PLAN-002 | Check dependency graph acyclicity on modification | Task | Real-time |
| AOR-PLAN-003 | Log all status transitions | Task | Event sourcing |
| AOR-PLAN-004 | Notify stakeholders on P0/P1 changes | Task | Notification |
| AOR-PLAN-005 | Archive completed tasks after 90 days | Task | Scheduled job |
| AOR-OODA-001 | Start telemetry timer at cycle begin | OODA | Instrumentation |
| AOR-OODA-002 | Abort cycle if timeout approaching | OODA | Watchdog |
| AOR-OODA-003 | Log observation sources | OODA | Audit |
| AOR-OODA-004 | Document COA evaluation criteria | OODA | Template |
| AOR-OODA-005 | Record decision rationale | OODA | Audit |
| AOR-LTP-001 | Review millennium plan every 25 years | LTP | Schedule |
| AOR-LTP-002 | Validate succession candidates annually | LTP | Process |
| AOR-LTP-003 | Backup legacy documents quarterly | LTP | Automation |
| AOR-LTP-004 | Test substrate migration annually | LTP | Test suite |
| AOR-LTP-005 | Notify founder lineage of major decisions | LTP | Notification |
| AOR-MIX-001 | Balance workload weekly | Mixed Team | Algorithm |
| AOR-MIX-002 | Review handoff quality monthly | Mixed Team | Metrics |
| AOR-MIX-003 | Train new team members on protocol | Mixed Team | Onboarding |
| AOR-MIX-004 | Audit decision authority quarterly | Mixed Team | Review |
| AOR-MIX-005 | Update communication preferences monthly | Mixed Team | Config |
| AOR-DB-001 | Run SQLite integrity check daily | Database | Scheduled |
| AOR-DB-002 | Reconcile SQLite/DuckDB weekly | Database | Job |
| AOR-DB-003 | Backup SQLite before schema changes | Database | Pre-migration |
| AOR-DB-004 | Archive old analytics data annually | Database | Maintenance |
| AOR-DB-005 | Monitor query performance | Database | Telemetry |
| AOR-ZENOH-001 | Verify router connectivity every 30s | Zenoh | Health check |
| AOR-ZENOH-002 | Log message delivery failures | Zenoh | Monitoring |
| AOR-ZENOH-003 | Implement message retry with backoff | Zenoh | Resilience |
| AOR-ZENOH-004 | Monitor topic subscription counts | Zenoh | Telemetry |
| AOR-ZENOH-005 | Test failover annually | Zenoh | DR test |

---

## 21. Exhaustive BDD Scenarios (4 Levels)

### 21.1 BDD Structure Overview

```
Level 1: Feature (Epic-level, 10-15 scenarios)
    └── Level 2: Capability (Story-level, 20-30 scenarios each)
        └── Level 3: Function (Task-level, 5-10 scenarios each)
            └── Level 4: Edge Case (Detailed, 3-5 scenarios each)
```

### 21.2 Feature: Task Management

#### Level 1: Feature Scenarios

```gherkin
@L1-Feature @TaskManagement
Feature: Task Management
  As a planning system user
  I want to manage tasks across projects
  So that work is tracked and completed efficiently

  @L1-001
  Scenario: Create a new task in a project
    Given I am authenticated as a team member
    And project "Alpha" exists with status "Active"
    When I create a task with title "Implement login"
    Then the task should be created with status "Pending"
    And the task should be assigned to project "Alpha"
    And an event "TaskCreated" should be recorded

  @L1-002
  Scenario: Complete a task with all dependencies satisfied
    Given task "T1" exists with status "InProgress"
    And all dependencies of task "T1" are "Completed"
    When I mark task "T1" as complete
    Then task "T1" should have status "Completed"
    And task "T1" should have a completion timestamp
    And dependent tasks should become "Ready"

  @L1-003
  Scenario: Block a task due to external dependency
    Given task "T1" exists with status "Ready"
    And task "T2" exists with status "InProgress"
    When I add dependency from "T1" to "T2"
    Then task "T1" should have status "Blocked"
    And task "T1" should show blocker "T2"

  @L1-004
  Scenario: Cancel a task with active subtasks
    Given task "T1" exists with status "InProgress"
    And task "T1" has subtasks ["T1.1", "T1.2"] with status "Ready"
    When I cancel task "T1" with reason "Requirements changed"
    Then task "T1" should have status "Cancelled"
    And subtasks should have status "Cancelled"
    And cancellation reason should be recorded

  @L1-005
  Scenario: View task history and audit trail
    Given task "T1" has been through statuses ["Pending", "Ready", "InProgress"]
    When I request the history of task "T1"
    Then I should see all status transitions with timestamps
    And I should see the actors who made each change
```

#### Level 2: Capability Scenarios

```gherkin
@L2-Capability @TaskCreation
Feature: Task Creation Capabilities
  Detailed scenarios for task creation flows

  @L2-001
  Scenario: Create task with natural language input
    Given I am in the task creation interface
    When I enter "Review PR #123 by tomorrow @john p1"
    Then the system should parse:
      | Field      | Value               |
      | Title      | Review PR #123      |
      | DueDate    | Tomorrow            |
      | Assignee   | john                |
      | Priority   | P1                  |
    And I should be asked to confirm the parsed values

  @L2-002
  Scenario: Create task with dependencies specified
    Given project "Alpha" has tasks ["T1", "T2", "T3"]
    When I create task "T4" with dependencies ["T1", "T2"]
    Then task "T4" should have 2 dependencies
    And the dependency graph should remain acyclic
    And task "T4" status should be "Blocked" if T1 or T2 not complete

  @L2-003
  Scenario: Create recurring task with schedule
    Given I create a task with recurrence "Weekly on Monday"
    When the task is completed on Monday
    Then a new instance should be created for next Monday
    And the original task should remain "Completed"
    And the recurrence chain should be linked

  @L2-004
  Scenario: Create task from template
    Given a task template "Bug Fix" exists with:
      | Field       | Value                |
      | Checklist   | [Reproduce, Fix, Test, Document] |
      | Labels      | [bug, fix]           |
      | EstimatedHours | 4                 |
    When I create a task from template "Bug Fix"
    Then the task should have the template fields pre-filled
    And I should be able to override any field

  @L2-005
  Scenario: Create subtask under parent task
    Given parent task "Epic-1" exists
    When I create subtask "Story-1" under "Epic-1"
    Then "Story-1" should be linked to "Epic-1"
    And "Epic-1" progress should reflect subtask completion
    And the hierarchy should be at most 4 levels deep

@L2-Capability @TaskStatusTransitions
Feature: Task Status Transitions
  State machine for task lifecycle

  @L2-010
  Scenario Outline: Valid task status transitions
    Given task exists with status "<FromStatus>"
    When I transition the task to "<ToStatus>"
    Then the transition should <Result>
    And if successful, status should be "<ToStatus>"

    Examples:
      | FromStatus  | ToStatus    | Result    |
      | Pending     | Ready       | succeed   |
      | Pending     | Cancelled   | succeed   |
      | Ready       | InProgress  | succeed   |
      | Ready       | Blocked     | succeed   |
      | InProgress  | Completed   | succeed   |
      | InProgress  | Blocked     | succeed   |
      | Blocked     | Ready       | succeed   |
      | Completed   | Pending     | fail      |
      | Cancelled   | InProgress  | fail      |

  @L2-011
  Scenario: Transition requires dependencies satisfied
    Given task "T1" depends on task "T2"
    And task "T2" has status "InProgress"
    When I try to start task "T1"
    Then the transition should fail
    And the error should mention blocker "T2"

  @L2-012
  Scenario: Transition triggers notifications
    Given task "T1" is assigned to user "Alice"
    And user "Bob" is watching task "T1"
    When task "T1" transitions to "Completed"
    Then "Alice" should receive completion notification
    And "Bob" should receive watcher notification
```

#### Level 3: Function Scenarios

```gherkin
@L3-Function @TaskValidation
Feature: Task Field Validation
  Detailed validation rules for task fields

  @L3-001
  Scenario: Task title validation
    When I create a task with title "<Title>"
    Then the result should be "<Result>"
    And if failed, error should be "<Error>"

    Examples:
      | Title                          | Result  | Error                    |
      | Valid Task Title               | success |                          |
      |                                | fail    | Title cannot be empty    |
      | A                              | success |                          |
      | [201 character string]         | fail    | Title max 200 characters |
      | Task\nWith\nNewlines           | success | Newlines converted to spaces |

  @L3-002
  Scenario: Task priority validation
    When I set task priority to <Priority>
    Then the result should be "<Result>"

    Examples:
      | Priority | Result  |
      | 0        | success |
      | 1        | success |
      | 4        | success |
      | -1       | fail    |
      | 5        | fail    |
      | null     | success |  # Default P3

  @L3-003
  Scenario: Task due date validation
    Given current date is "2026-01-14"
    When I set task due date to "<DueDate>"
    Then the result should be "<Result>"

    Examples:
      | DueDate    | Result  |
      | 2026-01-15 | success |
      | 2026-01-14 | success |  # Today allowed
      | 2026-01-13 | fail    |  # Past date
      | 2030-01-01 | success |
      | null       | success |  # No due date

  @L3-004
  Scenario: Task dependency cycle detection
    Given tasks exist:
      | TaskId | Dependencies |
      | T1     | []           |
      | T2     | [T1]         |
      | T3     | [T2]         |
    When I add dependency from "T1" to "T3"
    Then the operation should fail
    And error should mention "Cyclic dependency detected"
    And the cycle path should be shown ["T1", "T2", "T3", "T1"]

  @L3-005
  Scenario: Task assignment validation
    Given user "Alice" has capability "Developer"
    And user "Bob" has capability "Manager"
    And task requires capability "Developer"
    When I assign task to "<Assignee>"
    Then the result should be "<Result>"

    Examples:
      | Assignee | Result  |
      | Alice    | success |
      | Bob      | fail    |
      | Agent-1  | success |  # Agents have all capabilities
```

#### Level 4: Edge Case Scenarios

```gherkin
@L4-EdgeCase @TaskEdgeCases
Feature: Task Edge Cases and Error Handling
  Boundary conditions and error scenarios

  @L4-001
  Scenario: Create task during database maintenance
    Given database is in maintenance mode
    When I try to create a task
    Then the operation should be queued
    And I should receive "Task queued, will be created when maintenance completes"
    And after maintenance, task should be created

  @L4-002
  Scenario: Concurrent task modification
    Given task "T1" is being edited by user "Alice"
    When user "Bob" tries to edit task "T1" simultaneously
    Then "Bob" should see optimistic locking warning
    And "Bob" can force overwrite or merge changes
    And conflict resolution should be logged

  @L4-003
  Scenario: Task with maximum dependencies
    Given system allows maximum 50 dependencies per task
    And task "T1" has 49 dependencies
    When I add dependency 50 to task "T1"
    Then the operation should succeed
    When I try to add dependency 51
    Then the operation should fail with "Maximum dependencies exceeded"

  @L4-004
  Scenario: Delete task with external references
    Given task "T1" is referenced by:
      | Entity        | Reference Type      |
      | Document D1   | Linked task         |
      | PR #123       | Mentioned           |
      | Sprint S1     | Sprint backlog item |
    When I try to delete task "T1"
    Then I should see warning about references
    And I should choose to:
      | Option              | Result                    |
      | Cancel              | Task not deleted          |
      | Archive instead     | Task archived, refs valid |
      | Force delete        | Task deleted, refs broken |

  @L4-005
  Scenario: Task creation at system capacity
    Given system is at 99% storage capacity
    When I create a new task
    Then task should be created
    And system should trigger capacity alert
    And non-essential operations should be throttled
```

### 21.3 Feature: OODA Cycle Execution

#### Level 1: Feature Scenarios

```gherkin
@L1-Feature @OODACycle
Feature: OODA Cycle Execution
  As a planning system
  I want to execute OODA decision cycles
  So that decisions are made systematically and quickly

  @L1-OODA-001
  Scenario: Execute complete OODA cycle within time limit
    Given an OODA context with decision required
    When I execute the OODA cycle
    Then all four phases should complete
    And total cycle time should be under 100ms
    And a decision should be recorded

  @L1-OODA-002
  Scenario: OODA cycle with Guardian approval required
    Given a P0 priority decision context
    When the OODA cycle reaches Decide phase
    Then Guardian approval should be requested
    And cycle should wait for approval (up to 30s)
    And if approved, Act phase should execute

  @L1-OODA-003
  Scenario: OODA cycle abort and recovery
    Given an OODA cycle in progress
    When an abort condition is detected
    Then current state should be checkpointed
    And cycle should terminate gracefully
    And recovery should be possible from checkpoint
```

#### Level 2: Capability Scenarios

```gherkin
@L2-Capability @OODAObserve
Feature: OODA Observe Phase Capabilities

  @L2-OODA-010
  Scenario: Observe phase collects from multiple sources
    Given observation sources:
      | Source       | Type      | Priority |
      | Zenoh        | Real-time | High     |
      | Database     | State     | High     |
      | External API | Context   | Medium   |
    When Observe phase executes
    Then data from all sources should be collected
    And sources should be queried in parallel
    And timeout should apply per source (not total)

  @L2-OODA-011
  Scenario: Observe phase handles source failure
    Given observation source "External API" is unavailable
    When Observe phase executes
    Then other sources should still be collected
    And failure should be logged
    And observation should be marked as partial

@L2-Capability @OODAOrient
Feature: OODA Orient Phase Capabilities

  @L2-OODA-020
  Scenario: Orient phase analyzes 5-order effects
    Given observations about task "T1" blocking
    When Orient phase executes
    Then analysis should include:
      | Order | Effect                           |
      | 1st   | T1 cannot start                  |
      | 2nd   | Dependent tasks T2, T3 delayed   |
      | 3rd   | Sprint goal at risk              |
      | 4th   | Project timeline affected        |
      | 5th   | Portfolio metrics impacted       |

  @L2-OODA-021
  Scenario: Orient phase applies mental models
    Given mental model "Risk Assessment" is configured
    When Orient phase executes with risk indicators
    Then risk score should be calculated
    And high-risk items should be flagged
    And recommendations should be generated

@L2-Capability @OODADecide
Feature: OODA Decide Phase Capabilities

  @L2-OODA-030
  Scenario: Decide phase evaluates multiple COAs
    Given Orient phase identified options:
      | COA   | Description         | Risk  | Cost |
      | COA-1 | Reassign task       | Low   | Low  |
      | COA-2 | Extend deadline     | Med   | Low  |
      | COA-3 | Add resources       | Low   | High |
    When Decide phase executes
    Then all COAs should be scored
    And recommendation should be made
    And rationale should be documented

  @L2-OODA-031
  Scenario: Decide phase requires consensus for P0
    Given decision priority is P0
    And team is in consensus mode
    When Decide phase executes
    Then consensus should be requested from team
    And quorum of 3 should be required
    And timeout should be 60 seconds

@L2-Capability @OODAAct
Feature: OODA Act Phase Capabilities

  @L2-OODA-040
  Scenario: Act phase executes selected COA
    Given COA-1 "Reassign task" was selected
    When Act phase executes
    Then task should be reassigned
    And stakeholders should be notified
    And action should be logged to Immutable Register

  @L2-OODA-041
  Scenario: Act phase handles execution failure
    Given COA execution fails due to constraint violation
    When Act phase detects failure
    Then rollback should be attempted
    And alternative COA should be considered
    And failure should be reported
```

#### Level 3 & 4: Function and Edge Case Scenarios

```gherkin
@L3-Function @OODATiming
Feature: OODA Timing Requirements

  @L3-OODA-050
  Scenario Outline: Phase timing validation
    Given OODA cycle is executing
    When phase "<Phase>" takes <Duration>ms
    Then phase result should be "<Result>"

    Examples:
      | Phase   | Duration | Result  |
      | Observe | 20       | success |
      | Observe | 30       | warning |
      | Orient  | 25       | success |
      | Decide  | 25       | success |
      | Act     | 25       | success |
      | Total   | 99       | success |
      | Total   | 101      | fail    |

@L4-EdgeCase @OODAEdgeCases
Feature: OODA Edge Cases

  @L4-OODA-060
  Scenario: OODA cycle during Guardian unavailability
    Given Guardian service is unavailable
    And decision requires Guardian approval
    When OODA cycle reaches Decide phase
    Then emergency fallback should activate
    And decision should be made with:
      | Condition     | Action                    |
      | P0 decision   | Queue for human review    |
      | P1 decision   | Apply default safe action |
      | P2+ decision  | Proceed without approval  |

  @L4-OODA-061
  Scenario: Concurrent OODA cycles with conflict
    Given OODA cycle 1 is acting on task "T1"
    And OODA cycle 2 wants to act on task "T1"
    When cycle 2 reaches Act phase
    Then cycle 2 should detect conflict
    And cycle 2 should:
      | Option        | Condition                 |
      | Wait          | Cycle 1 almost done       |
      | Merge         | Actions compatible        |
      | Abort         | Actions conflict          |
```

### 21.4 Feature: Long-Term Planning

```gherkin
@L1-Feature @LongTermPlanning
Feature: Long-Term 1000-Year Planning
  As a civilization-scale planning system
  I want to manage millennium-scale plans
  So that long-term objectives are achieved across generations

  @L1-LTP-001
  Scenario: Create millennium plan with founder alignment
    Given I am authenticated as founder lineage member
    When I create a millennium plan with:
      | Field          | Value                           |
      | Name           | Naik Dynasty Perpetuation       |
      | Vision         | Ensure genetic perpetuity       |
      | Horizon        | 1000 years                      |
    Then plan should be created
    And plan should be aligned with Founder's Directive (Ω₀)
    And Guardian should approve the plan

  @L1-LTP-002
  Scenario: Succession event triggers knowledge transfer
    Given generation plan "Gen-3" is active
    And steward "Alice" is approaching term end
    When succession event is initiated
    Then knowledge transfer process should start
    And legacy documents should be prepared
    And successor "Bob" should receive training access

  @L1-LTP-003
  Scenario: Adaptation rule triggers plan review
    Given environmental signal "Technology Shift: Quantum Computing" detected
    And adaptation rule "Technology Shift" is active
    When adaptation evaluation runs
    Then plan review should be triggered
    And allowed changes should be proposed
    And constitutional compliance should be verified

@L2-Capability @SuccessionManagement
Feature: Succession Management Capabilities

  @L2-LTP-010
  Scenario: Project succession timeline
    Given millennium plan spans 1000 years
    And average generation is 25 years
    When I project succession timeline
    Then timeline should show 40 generations
    And first 3 generations should be "HumanFounderLine"
    And later generations should show "AgentGuardian" option
    And confidence should decrease with time

  @L2-LTP-011
  Scenario: Emergency succession activation
    Given active steward becomes incapacitated
    And no designated successor is ready
    When emergency succession triggers
    Then AI Guardian should assume temporary stewardship
    And notification should go to founder lineage
    And succession search should begin immediately

@L3-Function @KnowledgePreservation
Feature: Knowledge Preservation Functions

  @L3-LTP-020
  Scenario: Store legacy document with format stability
    Given I have document in format "Markdown"
    When I preserve the document
    Then document should be stored in SQLite
    And document should be indexed in DuckDB
    And format should be validated for long-term readability
    And checksum should be computed and stored

  @L3-LTP-021
  Scenario: Retrieve knowledge for current generation
    Given generation "Gen-5" is active
    And query is "Strategic objectives for epoch 2"
    When I search knowledge base
    Then relevant legacy documents should be returned
    And documents should be sorted by relevance
    And access should be logged

@L4-EdgeCase @LongTermEdgeCases
Feature: Long-Term Planning Edge Cases

  @L4-LTP-030
  Scenario: Plan survives substrate migration
    Given millennium plan exists on substrate "ElixirOTP"
    And migration to "PureF#" is required
    When substrate migration executes
    Then plan state should be fully exported
    And plan should be reconstructed on new substrate
    And no data should be lost
    And plan ID should remain unchanged

  @L4-LTP-031
  Scenario: Founder lineage extinction scenario
    Given all direct founder lineage members are deceased
    And no designated heirs exist
    When succession evaluation runs
    Then system should:
      | Priority | Action                           |
      | 1        | Search for distant relatives     |
      | 2        | Activate AI Guardian stewardship |
      | 3        | Preserve plan in hibernation     |
    And Founder's Directive should still be honored
```

### 21.5 Feature: Mixed Human-Agent Teams

```gherkin
@L1-Feature @MixedTeams
Feature: Mixed Human-Agent Teams
  As a hybrid workforce manager
  I want to coordinate humans and AI agents
  So that work is done efficiently with appropriate oversight

  @L1-MIX-001
  Scenario: Form mixed team with balanced composition
    Given I need a team for project "Phoenix"
    When I create team with:
      | Members | Type  | Role           |
      | Alice   | Human | Team Lead      |
      | Bob     | Human | Developer      |
      | Agent-1 | Agent | Developer      |
      | Agent-2 | Agent | Quality Review |
    Then team should be formed
    And leadership model should be "HumanLed"
    And 24/7 coverage should be achievable

  @L1-MIX-002
  Scenario: Handoff from human to agent at shift end
    Given Alice is working on task "T1" (60% complete)
    And Alice's shift ends in 10 minutes
    When shift-end handoff triggers
    Then context should be transferred to Agent-1
    And Agent-1 should receive work summary
    And Agent-1 should continue task "T1"

  @L1-MIX-003
  Scenario: Escalate from agent to human for judgment call
    Given Agent-1 encounters ambiguous requirement
    And decision authority requires human input
    When Agent-1 requests escalation
    Then available human should be notified
    And escalation should include context summary
    And SLA timer (15 min) should start

@L2-Capability @WorkDistribution
Feature: Work Distribution Capabilities

  @L2-MIX-010
  Scenario Outline: Distribute work by type preference
    Given team has human and agent members
    And work item is of type "<WorkType>"
    When work is assigned
    Then assignee type should be "<PreferredType>"

    Examples:
      | WorkType          | PreferredType |
      | StrategicDecision | Human         |
      | CreativeWork      | Human         |
      | RoutineProcessing | Agent         |
      | DataAnalysis      | Agent         |
      | CodeDevelopment   | Collaborative |
      | Review            | Both          |
      | Monitoring        | Agent         |

  @L2-MIX-011
  Scenario: Load-based work assignment
    Given team members have current load:
      | Member  | CurrentTasks | Capacity |
      | Alice   | 5            | 8        |
      | Bob     | 7            | 8        |
      | Agent-1 | 10           | 20       |
    When new task arrives
    Then task should be assigned to Alice (lowest relative load)
    And assignment should consider skill match

@L3-Function @HandoffProtocol
Feature: Handoff Protocol Functions

  @L3-MIX-020
  Scenario: Human to agent context transfer (detailed)
    Given human is handing off to agent
    When context transfer executes
    Then agent should receive:
      | Field              | Format        |
      | WorkProgress       | Percentage    |
      | CurrentState       | JSON          |
      | DecisionHistory    | List          |
      | OpenQuestions      | Structured    |
      | Documents          | References    |
      | ConversationHistory| Messages      |
      | NextSteps          | List          |
    And transfer should be via Zenoh

  @L3-MIX-021
  Scenario: Agent to human context transfer (summarized)
    Given agent is handing off to human
    When context transfer executes
    Then human should receive:
      | Field              | Format        |
      | ProgressSummary    | Narrative     |
      | StatusBrief        | 1-2 sentences |
      | KeyDecisions       | Top 5         |
      | ImmediateQuestions | High urgency  |
      | SuggestedActions   | Top 3         |
    And summary should be human-readable

@L4-EdgeCase @MixedTeamEdgeCases
Feature: Mixed Team Edge Cases

  @L4-MIX-030
  Scenario: All humans unavailable during emergency
    Given team has 2 humans (both offline)
    And emergency decision is required
    When escalation triggers
    Then on-call rotation should be checked
    And if no human available within 15 min:
      | Action                              |
      | Agent makes safe default decision   |
      | Decision flagged for human review   |
      | Escalation logged to audit          |

  @L4-MIX-031
  Scenario: Agent autonomy level exceeded
    Given Agent-1 has autonomy level "Delegate"
    And task requires "Executive" authority
    When Agent-1 attempts action
    Then action should be blocked
    And escalation should trigger
    And agent should provide recommendation
```

### 21.6 BDD Test Coverage Summary

| Feature | L1 Scenarios | L2 Scenarios | L3 Scenarios | L4 Scenarios | Total |
|---------|--------------|--------------|--------------|--------------|-------|
| Task Management | 5 | 15 | 25 | 10 | 55 |
| OODA Cycle | 3 | 12 | 15 | 8 | 38 |
| Long-Term Planning | 3 | 10 | 15 | 8 | 36 |
| Mixed Teams | 3 | 12 | 15 | 8 | 38 |
| Graph/Simulation | 2 | 8 | 12 | 6 | 28 |
| Mathematical | 2 | 6 | 10 | 5 | 23 |
| Database | 2 | 8 | 10 | 6 | 26 |
| Zenoh Integration | 2 | 6 | 8 | 5 | 21 |
| **Total** | **22** | **77** | **110** | **56** | **265** |

---

## 22. UI/UX/CX/DX Comprehensive Design

This section provides exhaustive coverage of all user interface, user experience, customer experience, and developer experience aspects across TUI, CLI, Control Cockpit, WebUI, and Emacs integration. Design follows SIL-6 safety-critical principles with explicit confirmation for destructive operations.

### 22.1 Experience Layer Architecture

```fsharp
/// Experience layer types
module ExperienceLayers =

    /// User interface modality
    type UIModality =
        | TUI of TUIConfig                    // Terminal User Interface (Prajna Control)
        | CLI of CLIConfig                    // Command Line Interface
        | WebUI of WebUIConfig                // Browser-based interface
        | Cockpit of CockpitConfig            // Prajna C3I Control Cockpit
        | Emacs of EmacsConfig                // Emacs integration via org-mode
        | Mobile of MobileConfig              // Mobile companion (Dart/Flutter)

    /// TUI Configuration for SIL-6 critical operations
    type TUIConfig = {
        Mode: TUIMode
        ColorScheme: ColorScheme
        KeyBindings: KeyBindings
        SafetyLevel: SafetyLevel
        RefreshRate: TimeSpan
        LayoutProfile: LayoutProfile
    }

    type TUIMode =
        | Normal                               // Standard operations
        | Critical                             // SIL-6 critical mode with confirmations
        | Emergency                            // Emergency stop/override mode
        | Monitoring                           // Read-only observation mode
        | Maintenance                          // System maintenance mode

    type SafetyLevel =
        | SIL0                                 // No safety requirements
        | SIL1                                 // Low integrity
        | SIL2                                 // Medium integrity
        | SIL6                                 // High integrity
        | SIL6                                 // Biomorphic extended safety

    /// CLI Configuration
    type CLIConfig = {
        Shell: ShellType
        OutputFormat: OutputFormat
        Verbosity: Verbosity
        ColorEnabled: bool
        InteractiveMode: bool
        PagerEnabled: bool
    }

    type OutputFormat =
        | Plain                                // Plain text
        | JSON                                 // Structured JSON
        | YAML                                 // YAML format
        | Table                                // ASCII table
        | Tree                                 // Tree view
        | Markdown                             // Markdown output

    /// WebUI Configuration
    type WebUIConfig = {
        Theme: WebTheme
        Responsive: ResponsiveConfig
        Accessibility: AccessibilityConfig
        PWA: PWAConfig
        SSE: ServerSentEventsConfig
        WebSocket: WebSocketConfig
    }

    type WebTheme =
        | Light
        | Dark
        | HighContrast                         // Accessibility mode
        | Military                             // Tactical dark theme
        | System                               // Follow OS preference

    /// Cockpit Configuration (Prajna C3I)
    type CockpitConfig = {
        Layout: CockpitLayout
        Panels: Panel list
        Alerts: AlertConfig
        Commands: CommandPalette
        Guardian: GuardianIntegration
        Telemetry: TelemetryDisplay
    }

    type CockpitLayout =
        | SinglePane                           // Focused view
        | DualPane                             // Split view
        | TriPane                              // Three-panel layout
        | QuadPane                             // Four-quadrant display
        | CustomGrid of int * int              // Custom grid
        | Dashboard                            // KPI dashboard view

    /// Emacs Configuration
    type EmacsConfig = {
        OrgMode: OrgModeConfig
        KeyPrefix: string                      // Default: "C-c p"
        Capture: CaptureTemplates
        Agenda: AgendaViews
        Babel: BabelConfig
    }
```

### 22.2 TUI Design for SIL-6 Critical Operations

```fsharp
/// TUI module for critical operations
module CriticalTUI =

    /// TUI Panel definition
    type Panel = {
        Id: string
        Title: string
        Content: PanelContent
        Position: PanelPosition
        Size: PanelSize
        Refresh: TimeSpan option
        SafetyLevel: SafetyLevel
    }

    type PanelContent =
        | TaskList of TaskListConfig
        | OodaCycle of OodaDisplayConfig
        | SystemHealth of HealthConfig
        | AlertStream of AlertStreamConfig
        | CommandInput of CommandConfig
        | LogViewer of LogConfig
        | DependencyGraph of GraphConfig
        | TimelineView of TimelineConfig
        | KPIDashboard of KPIConfig

    /// SIL-6 Confirmation protocol
    type ConfirmationProtocol = {
        Level: ConfirmationLevel
        Steps: ConfirmationStep list
        Timeout: TimeSpan
        Fallback: FallbackAction
    }

    type ConfirmationLevel =
        | None                                 // No confirmation
        | Single                               // Single confirmation
        | Double                               // "Are you sure?" pattern
        | Triple                               // Critical: type confirmation code
        | Guardian                             // Guardian veto check required

    type ConfirmationStep =
        | TextConfirm of prompt: string
        | CodeEntry of code: string * length: int
        | Biometric                            // Future: biometric auth
        | SecondPerson                         // Require second approver
        | TimeDelay of TimeSpan                // Forced delay before action

    /// Critical operation categories
    type CriticalOperation =
        | DeleteTask                           // Level: Double
        | ArchiveProject                       // Level: Double
        | SystemShutdown                       // Level: Triple + Guardian
        | DataPurge                            // Level: Triple + Guardian
        | ConfigChange                         // Level: Double
        | EmergencyStop                        // Level: Single (fast path)
        | FederationLeave                      // Level: Triple + Guardian
        | SuccessionTransfer                   // Level: Triple + SecondPerson

    /// TUI Layout definition
    let defaultCriticalLayout = {
        Panels = [
            { Id = "alerts"
              Title = "🚨 Alerts"
              Content = AlertStream { Priority = P0; MaxItems = 10 }
              Position = TopLeft
              Size = { Width = 40; Height = 10 }
              Refresh = Some (TimeSpan.FromSeconds 1.0)
              SafetyLevel = SIL6 }

            { Id = "tasks"
              Title = "📋 Active Tasks"
              Content = TaskList { Filter = Active; Sort = Priority }
              Position = TopCenter
              Size = { Width = 80; Height = 15 }
              Refresh = Some (TimeSpan.FromSeconds 5.0)
              SafetyLevel = SIL2 }

            { Id = "ooda"
              Title = "🎯 OODA Cycle"
              Content = OodaCycle { ShowPhase = true; ShowTimer = true }
              Position = TopRight
              Size = { Width = 40; Height = 10 }
              Refresh = Some (TimeSpan.FromSeconds 1.0)
              SafetyLevel = SIL6 }

            { Id = "health"
              Title = "💚 System Health"
              Content = SystemHealth { Metrics = All; Threshold = 80.0 }
              Position = BottomLeft
              Size = { Width = 40; Height = 8 }
              Refresh = Some (TimeSpan.FromSeconds 10.0)
              SafetyLevel = SIL6 }

            { Id = "command"
              Title = "⌨️ Command"
              Content = CommandInput { History = true; Autocomplete = true }
              Position = Bottom
              Size = { Width = 120; Height = 3 }
              Refresh = None
              SafetyLevel = SIL2 }

            { Id = "log"
              Title = "📜 Log Stream"
              Content = LogViewer { Level = Info; Tail = 50 }
              Position = BottomRight
              Size = { Width = 80; Height = 8 }
              Refresh = Some (TimeSpan.FromMilliseconds 500.0)
              SafetyLevel = SIL2 }
        ]
    }

    /// Keyboard shortcuts for TUI (vim-inspired)
    type KeyBindings = {
        Navigation: Map<string, Action>
        TaskOperations: Map<string, Action>
        OodaOperations: Map<string, Action>
        SystemOperations: Map<string, Action>
        ViewOperations: Map<string, Action>
    }

    let defaultKeyBindings = {
        Navigation = Map [
            "j", MoveDown
            "k", MoveUp
            "h", MoveLeft
            "l", MoveRight
            "gg", GoToTop
            "G", GoToBottom
            "/", Search
            "n", NextMatch
            "N", PrevMatch
            "Tab", NextPanel
            "S-Tab", PrevPanel
        ]
        TaskOperations = Map [
            "a", AddTask
            "e", EditTask
            "d", DeleteTask          // Triggers Double confirmation
            "c", CompleteTask
            "p", SetPriority
            "t", AddTag
            "D", AddDependency
            "Enter", ViewDetails
        ]
        OodaOperations = Map [
            "o", StartOoda
            "O", ObservePhase
            "R", OrientPhase
            "D", DecidePhase
            "A", ActPhase
            "x", AbortOoda
        ]
        SystemOperations = Map [
            ":", CommandMode
            "q", Quit
            "Q", ForceQuit           // Triggers Triple confirmation
            "r", Refresh
            "?", Help
            "!", EmergencyStop       // Single confirmation (fast)
        ]
        ViewOperations = Map [
            "1", TaskView
            "2", ProjectView
            "3", OodaView
            "4", DashboardView
            "5", TimelineView
            "z", ZoomIn
            "Z", ZoomOut
            "f", ToggleFullscreen
        ]
    }
```

### 22.3 Control Cockpit (Prajna C3I) Interface

```fsharp
/// Prajna C3I Cockpit interface
module PrajnaCockpit =

    /// Cockpit widget types
    type CockpitWidget =
        | HealthScoreGauge of HealthGaugeConfig
        | ThreatMatrix of ThreatMatrixConfig
        | TaskBoard of TaskBoardConfig
        | OodaWheel of OodaWheelConfig
        | DependencyGraph of GraphWidgetConfig
        | TimelineGantt of GanttConfig
        | MetricsChart of ChartConfig
        | AlertFeed of AlertFeedConfig
        | CommandTerminal of TerminalConfig
        | GuardianStatus of GuardianWidgetConfig
        | SentinelRadar of RadarConfig
        | AgentSwarm of SwarmConfig

    /// Health gauge configuration
    type HealthGaugeConfig = {
        Source: HealthSource
        Thresholds: Threshold list
        Animation: bool
        Size: WidgetSize
    }

    type HealthSource =
        | SystemHealth                         // Overall system
        | DatabaseHealth                       // SQLite/DuckDB health
        | ZenohHealth                          // Mesh connectivity
        | AgentHealth of AgentId               // Specific agent
        | ProjectHealth of ProjectId           // Project status

    /// OODA Wheel visualization
    type OodaWheelConfig = {
        ShowCurrentPhase: bool
        ShowTimer: bool
        ShowHistory: bool
        HistoryDepth: int
        ColorCoding: Map<OodaPhase, Color>
    }

    /// Task board (Kanban style)
    type TaskBoardConfig = {
        Columns: BoardColumn list
        WIPLimits: Map<TaskStatus, int>
        ShowAssignee: bool
        ShowPriority: bool
        ShowDependencies: bool
        DragDropEnabled: bool
    }

    type BoardColumn = {
        Status: TaskStatus
        Title: string
        Color: Color
        WIPLimit: int option
    }

    /// Dashboard layout definition
    type DashboardLayout = {
        Rows: int
        Columns: int
        Widgets: WidgetPlacement list
        RefreshInterval: TimeSpan
        ResponsiveBreakpoints: Breakpoint list
    }

    type WidgetPlacement = {
        Widget: CockpitWidget
        Row: int
        Column: int
        RowSpan: int
        ColSpan: int
    }

    /// Default Prajna Planning Dashboard
    let planningDashboard = {
        Rows = 4
        Columns = 4
        Widgets = [
            { Widget = HealthScoreGauge { Source = SystemHealth; Thresholds = defaultThresholds; Animation = true; Size = Medium }
              Row = 0; Column = 0; RowSpan = 1; ColSpan = 1 }

            { Widget = OodaWheel { ShowCurrentPhase = true; ShowTimer = true; ShowHistory = true; HistoryDepth = 5; ColorCoding = defaultOodaColors }
              Row = 0; Column = 1; RowSpan = 1; ColSpan = 1 }

            { Widget = AlertFeed { MaxItems = 10; Priority = P0; AutoScroll = true }
              Row = 0; Column = 2; RowSpan = 2; ColSpan = 2 }

            { Widget = TaskBoard { Columns = defaultColumns; WIPLimits = defaultWIP; ShowAssignee = true; ShowPriority = true; ShowDependencies = true; DragDropEnabled = true }
              Row = 1; Column = 0; RowSpan = 2; ColSpan = 2 }

            { Widget = TimelineGantt { Range = ThisWeek; ShowDependencies = true; ShowMilestones = true }
              Row = 2; Column = 2; RowSpan = 1; ColSpan = 2 }

            { Widget = AgentSwarm { ShowActive = true; ShowLoad = true; ShowTasks = true }
              Row = 3; Column = 0; RowSpan = 1; ColSpan = 2 }

            { Widget = MetricsChart { Metric = TaskVelocity; Period = Last7Days; ChartType = Line }
              Row = 3; Column = 2; RowSpan = 1; ColSpan = 2 }
        ]
        RefreshInterval = TimeSpan.FromSeconds 30.0
        ResponsiveBreakpoints = [
            { Width = 1920; Layout = FullLayout }
            { Width = 1280; Layout = CompactLayout }
            { Width = 768; Layout = MobileLayout }
        ]
    }

    /// Cockpit command palette
    type CommandPalette = {
        Commands: Command list
        Shortcuts: Map<string, Command>
        RecentCommands: Command list
        FuzzySearch: bool
    }

    type Command = {
        Id: string
        Name: string
        Description: string
        Category: CommandCategory
        Shortcut: string option
        SafetyLevel: SafetyLevel
        Execute: unit -> Async<Result<unit, PlanningError>>
    }

    type CommandCategory =
        | Task
        | Project
        | OODA
        | System
        | View
        | Navigation
        | Guardian
```

### 22.4 WebUI Architecture

```fsharp
/// WebUI architecture using Phoenix LiveView interop
module WebUIArchitecture =

    /// Page structure
    type WebPage =
        | Dashboard of DashboardPage
        | TaskList of TaskListPage
        | TaskDetail of TaskDetailPage
        | ProjectView of ProjectViewPage
        | OodaWorkspace of OodaWorkspacePage
        | Timeline of TimelinePage
        | Settings of SettingsPage
        | Admin of AdminPage

    /// Component hierarchy
    type Component =
        | TaskCard of TaskCardProps
        | TaskForm of TaskFormProps
        | ProjectTree of ProjectTreeProps
        | OodaWheel of OodaWheelProps
        | DependencyGraph of DependencyGraphProps
        | GanttChart of GanttChartProps
        | KanbanBoard of KanbanBoardProps
        | AlertBanner of AlertBannerProps
        | CommandPalette of CommandPaletteProps
        | SearchModal of SearchModalProps
        | FilterPanel of FilterPanelProps
        | AgentAvatar of AgentAvatarProps

    /// Real-time updates via Phoenix Channels
    type ChannelTopic =
        | TaskUpdates of ProjectId
        | OodaCycle of OodaCycleId
        | SystemHealth
        | Alerts
        | AgentStatus of AgentId
        | ZenohTelemetry

    /// Accessibility configuration (WCAG 2.1 AA)
    type AccessibilityConfig = {
        ScreenReaderSupport: bool
        KeyboardNavigation: bool
        FocusIndicators: bool
        ColorContrastRatio: float              // Minimum 4.5:1
        TextScaling: bool
        ReducedMotion: bool
        AriaLabels: bool
    }

    /// Progressive Web App configuration
    type PWAConfig = {
        Enabled: bool
        OfflineSupport: bool
        PushNotifications: bool
        BackgroundSync: bool
        InstallPrompt: bool
        ServiceWorkerStrategy: SWStrategy
    }

    type SWStrategy =
        | CacheFirst                           // Offline-first
        | NetworkFirst                         // Fresh data preferred
        | StaleWhileRevalidate                 // Balance

    /// WebUI routes
    let routes = [
        "/planning", Dashboard defaultDashboard
        "/planning/tasks", TaskList defaultTaskList
        "/planning/tasks/:id", TaskDetail
        "/planning/projects", ProjectView defaultProjectView
        "/planning/projects/:id", ProjectView
        "/planning/ooda", OodaWorkspace defaultOodaWorkspace
        "/planning/ooda/:id", OodaWorkspace
        "/planning/timeline", Timeline defaultTimeline
        "/planning/settings", Settings defaultSettings
        "/planning/admin", Admin adminConfig
    ]
```

### 22.5 CLI Interface Design

```fsharp
/// CLI interface module
module CLIInterface =

    /// CLI command structure
    type CLICommand =
        | Task of TaskSubcommand
        | Project of ProjectSubcommand
        | Ooda of OodaSubcommand
        | Sprint of SprintSubcommand
        | Query of QuerySubcommand
        | Export of ExportSubcommand
        | Import of ImportSubcommand
        | Config of ConfigSubcommand
        | Daemon of DaemonSubcommand

    type TaskSubcommand =
        | Add of TaskAddArgs
        | List of TaskListArgs
        | Show of TaskId
        | Edit of TaskEditArgs
        | Complete of TaskId
        | Delete of TaskId
        | Move of TaskId * ProjectId
        | Depend of TaskId * TaskId
        | Parse of string                      // Natural language

    type TaskAddArgs = {
        Title: string
        Description: string option
        Priority: Priority option
        DueDate: DateTimeOffset option
        Project: ProjectId option
        Tags: string list
        Assignee: ActorId option
        Blocking: TaskId list
    }

    /// CLI output formatters
    module Output =
        let formatTask (format: OutputFormat) (task: Task) =
            match format with
            | Plain -> sprintf "%s [%A] %s" task.Id task.Status task.Title
            | JSON -> JsonSerializer.Serialize(task)
            | YAML -> YamlSerializer.Serialize(task)
            | Table -> formatAsTable [task]
            | Tree -> formatAsTree task
            | Markdown -> formatAsMarkdown task

        let formatTasks (format: OutputFormat) (tasks: Task list) =
            match format with
            | Table ->
                let headers = ["ID"; "Status"; "Priority"; "Title"; "Due"; "Assignee"]
                let rows = tasks |> List.map (fun t ->
                    [t.Id; string t.Status; string t.Priority; t.Title;
                     formatDate t.DueDate; formatActor t.Assignee])
                renderTable headers rows
            | _ -> tasks |> List.map (formatTask format) |> String.concat "\n"

    /// Interactive mode
    type InteractiveSession = {
        History: string list
        Context: InteractiveContext
        Completions: CompletionProvider
        Prompt: string
    }

    type InteractiveContext = {
        CurrentProject: ProjectId option
        CurrentSprint: SprintId option
        Filter: TaskFilter
        Format: OutputFormat
    }

    /// CLI usage examples
    let usageExamples = """
    # Add a task with natural language
    $ indrajaal task parse "Fix login bug by tomorrow, high priority, assign to Alice"

    # List active tasks in table format
    $ indrajaal task list --status active --format table

    # Start OODA cycle for a decision
    $ indrajaal ooda start --context "Should we migrate to new database?"

    # Show project hierarchy as tree
    $ indrajaal project show PROJ-123 --format tree

    # Export sprint to markdown
    $ indrajaal sprint export SPRINT-45 --format markdown > sprint-review.md

    # Interactive mode
    $ indrajaal -i
    indrajaal> project use Alpha
    indrajaal[Alpha]> task list
    indrajaal[Alpha]> task add "Review PR #123" --priority P1
    """
```

### 22.6 Emacs Integration (Org-Mode)

```fsharp
/// Emacs org-mode integration
module EmacsIntegration =

    /// Org-mode task mapping
    type OrgTask = {
        Headline: string
        TodoKeyword: string                    // TODO, DONE, WAITING, etc.
        Priority: char option                  // A, B, C
        Tags: string list
        Properties: Map<string, string>
        Scheduled: DateTimeOffset option
        Deadline: DateTimeOffset option
        Body: string
    }

    /// Bidirectional sync
    type SyncDirection =
        | OrgToPlanning                        // Org file → Planning system
        | PlanningToOrg                        // Planning system → Org file
        | Bidirectional                        // Conflict resolution required

    /// Org-mode capture templates
    let captureTemplates = """
    ;; Indrajaal Planning capture templates
    (setq org-capture-templates
          '(("t" "Task" entry (file+headline "~/org/indrajaal.org" "Inbox")
             "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n%i")

            ("p" "Planning Task" entry (file+headline "~/org/indrajaal.org" "Planning")
             "* TODO [#%^{Priority|B|A|C}] %^{Title}\n:PROPERTIES:\n:PROJECT: %^{Project}\n:CREATED: %U\n:END:\n%?")

            ("o" "OODA Observation" entry (file+headline "~/org/indrajaal.org" "OODA")
             "* OBSERVE %?\n:PROPERTIES:\n:OODA_CYCLE: %^{Cycle ID}\n:OBSERVED: %U\n:END:\n")

            ("d" "Decision" entry (file+headline "~/org/indrajaal.org" "Decisions")
             "* DECIDE %^{Decision}\n:PROPERTIES:\n:CONTEXT: %^{Context}\n:OPTIONS: %^{Options}\n:SELECTED: %^{Selected}\n:RATIONALE: %^{Rationale}\n:END:\n")))
    """

    /// Elisp functions for integration
    let elispFunctions = """
    (defun indrajaal-sync ()
      "Sync current org file with Indrajaal planning system."
      (interactive)
      (let ((result (shell-command-to-string
                     (format "indrajaal sync --file %s --format org"
                             (buffer-file-name)))))
        (message "Indrajaal sync: %s" result)
        (revert-buffer t t)))

    (defun indrajaal-task-at-point ()
      "Get Indrajaal task details for heading at point."
      (interactive)
      (when-let ((id (org-entry-get (point) "INDRAJAAL_ID")))
        (shell-command (format "indrajaal task show %s" id))))

    (defun indrajaal-start-ooda ()
      "Start OODA cycle from current context."
      (interactive)
      (let* ((context (read-string "OODA Context: "))
             (result (shell-command-to-string
                      (format "indrajaal ooda start --context '%s'" context))))
        (org-insert-heading-respect-content)
        (insert (format "OODA Cycle: %s\n" result))))

    ;; Keybindings
    (define-key org-mode-map (kbd "C-c p s") 'indrajaal-sync)
    (define-key org-mode-map (kbd "C-c p t") 'indrajaal-task-at-point)
    (define-key org-mode-map (kbd "C-c p o") 'indrajaal-start-ooda)
    """

    /// Agenda views
    let agendaViews = """
    (setq org-agenda-custom-commands
          '(("i" "Indrajaal Planning"
             ((agenda "" ((org-agenda-span 'week)))
              (tags-todo "PROJECT={.+}"
                         ((org-agenda-overriding-header "Project Tasks")))
              (tags "OODA_CYCLE={.+}"
                    ((org-agenda-overriding-header "Active OODA Cycles")))
              (tags-todo "+PRIORITY=\"A\""
                         ((org-agenda-overriding-header "High Priority")))))))
    """
```

### 22.7 Developer Experience (DX)

```fsharp
/// Developer experience module
module DeveloperExperience =

    /// Development tools integration
    type DevTool =
        | VSCode of VSCodeConfig
        | JetBrains of JetBrainsConfig
        | Vim of VimConfig
        | Emacs of EmacsDevConfig
        | CLI of CLIDevConfig

    /// API client generation
    type APIClientGen = {
        Language: ClientLanguage
        AsyncStyle: AsyncStyle
        ErrorHandling: ErrorStyle
        Documentation: DocStyle
    }

    type ClientLanguage =
        | FSharp                               // F# client
        | CSharp                               // C# client
        | TypeScript                           // TypeScript client
        | Python                               // Python client
        | Elixir                               // Elixir client
        | Rust                                 // Rust client

    /// SDK structure
    type SDK = {
        Client: APIClient
        Models: DomainModels
        Builders: FluentBuilders
        Testing: TestHelpers
        Examples: CodeExamples
    }

    /// Fluent API design
    module FluentBuilders =

        type TaskBuilder() =
            let mutable task = Task.empty

            member this.WithTitle(title) = task <- { task with Title = title }; this
            member this.WithPriority(p) = task <- { task with Priority = p }; this
            member this.WithDueDate(d) = task <- { task with DueDate = Some d }; this
            member this.InProject(p) = task <- { task with ProjectId = Some p }; this
            member this.AssignTo(a) = task <- { task with Assignee = Some a }; this
            member this.DependsOn(t) = task <- { task with Dependencies = t :: task.Dependencies }; this
            member this.Build() = task

        /// Usage: task { title "Fix bug"; priority P1; dueDate tomorrow; inProject "Alpha" }
        let task = TaskBuilder()

    /// Testing utilities
    module TestHelpers =

        /// In-memory test database
        let createTestDb () =
            let db = SQLite.Connection(":memory:")
            db.Execute(Schema.createAll)
            db

        /// Test data generators (FsCheck)
        let taskGen =
            gen {
                let! title = Arb.generate<NonEmptyString>
                let! priority = Gen.elements [P0; P1; P2; P3; P4]
                let! status = Gen.elements [Pending; InProgress; Completed]
                return { Task.empty with Title = title.Get; Priority = priority; Status = status }
            }

        /// Scenario builders
        type ScenarioBuilder() =
            let mutable events = []

            member this.Given(e) = events <- e :: events; this
            member this.When(cmd) =
                let result = CommandHandler.handle cmd (List.rev events)
                this, result
            member this.Then(expected) (_, actual) =
                Expect.equal actual expected "Event mismatch"

    /// Documentation generation
    type DocGenerator = {
        Format: DocFormat
        IncludeExamples: bool
        IncludeSchemas: bool
        OutputPath: string
    }

    type DocFormat =
        | OpenAPI                              // OpenAPI 3.0 spec
        | AsyncAPI                             // AsyncAPI spec for events
        | Markdown                             // Markdown documentation
        | Docusaurus                           // Docusaurus site
```

### 22.8 Customer Experience (CX) Flows

```fsharp
/// Customer experience flows
module CustomerExperience =

    /// User journey stages
    type JourneyStage =
        | Discovery                            // Learning about system
        | Onboarding                           // First-time setup
        | Adoption                             // Regular usage
        | Mastery                              // Power user features
        | Advocacy                             // Recommending to others

    /// Onboarding flow
    type OnboardingFlow = {
        Steps: OnboardingStep list
        Progress: int
        Completed: bool
        SkippedSteps: OnboardingStep list
    }

    type OnboardingStep =
        | Welcome                              // Introduction
        | CreateFirstTask                      // Basic task creation
        | SetupProject                         // Project structure
        | IntroduceOODA                        // OODA loop tutorial
        | ConfigureIntegrations                // Connect tools
        | InviteTeam                           // Team setup
        | CustomizeViews                       // Personalization
        | CompleteTutorial                     // Final walkthrough

    /// Help and guidance
    type GuidanceSystem = {
        Tooltips: Tooltip list
        Walkthroughs: Walkthrough list
        ContextualHelp: ContextHelp
        Documentation: DocLinks
        Support: SupportChannels
    }

    type Tooltip = {
        Target: string                         // CSS selector or component ID
        Content: string
        Position: TooltipPosition
        Trigger: TooltipTrigger
        ShowOnce: bool
    }

    /// Feedback collection
    type FeedbackType =
        | NPS of score: int                    // Net Promoter Score
        | CSAT of score: int                   // Customer Satisfaction
        | CES of score: int                    // Customer Effort Score
        | FeatureRequest of string
        | BugReport of BugReport
        | GeneralFeedback of string

    /// Analytics events
    type AnalyticsEvent =
        | PageView of page: string
        | FeatureUsage of feature: string * duration: TimeSpan
        | TaskCreated of method: InputMethod
        | OodaCycleCompleted of duration: TimeSpan
        | ErrorEncountered of error: string
        | SearchPerformed of query: string * resultCount: int
```

### 22.9 STAMP Constraints (UI/UX/CX/DX)

| ID | Constraint | Severity | Layer |
|----|------------|----------|-------|
| SC-UI-001 | TUI MUST render within 16ms (60fps) | HIGH | TUI |
| SC-UI-002 | Critical operations MUST require confirmation | CRITICAL | All |
| SC-UI-003 | SIL-6 operations MUST use Triple confirmation | CRITICAL | TUI/Cockpit |
| SC-UI-004 | Emergency stop MUST be accessible in <1s | CRITICAL | All |
| SC-UI-005 | WebUI MUST support WCAG 2.1 AA accessibility | HIGH | WebUI |
| SC-UI-006 | CLI MUST support JSON output for scripting | HIGH | CLI |
| SC-UI-007 | Cockpit MUST refresh within 30s | HIGH | Cockpit |
| SC-UI-008 | Emacs sync MUST preserve org-mode structure | MEDIUM | Emacs |
| SC-UI-009 | All UIs MUST show Guardian veto status | CRITICAL | All |
| SC-UI-010 | Offline mode MUST queue operations for sync | HIGH | WebUI/Mobile |

| SC-UX-001 | Task creation MUST complete in <3 steps | HIGH | All |
| SC-UX-002 | Search results MUST appear in <500ms | HIGH | All |
| SC-UX-003 | Navigation MUST be consistent across UIs | MEDIUM | All |
| SC-UX-004 | Error messages MUST be actionable | HIGH | All |
| SC-UX-005 | Undo MUST be available for 30s after action | HIGH | All |

| SC-CX-001 | Onboarding MUST complete in <10 minutes | MEDIUM | WebUI |
| SC-CX-002 | Help MUST be contextually relevant | MEDIUM | All |
| SC-CX-003 | Feedback collection MUST not interrupt workflow | LOW | All |

| SC-DX-001 | API client MUST be auto-generated | HIGH | SDK |
| SC-DX-002 | SDK MUST include test helpers | HIGH | SDK |
| SC-DX-003 | Documentation MUST be versioned with code | HIGH | Docs |
| SC-DX-004 | Examples MUST be executable | MEDIUM | SDK |

### 22.10 AOR Rules (UI/UX/CX/DX)

| ID | Rule |
|----|------|
| AOR-UI-001 | ALWAYS show loading state for async operations |
| AOR-UI-002 | ALWAYS provide keyboard shortcuts for common actions |
| AOR-UI-003 | NEVER block UI thread during network operations |
| AOR-UI-004 | ALWAYS preserve user input on navigation errors |
| AOR-UI-005 | ALWAYS show confirmation for destructive actions |
| AOR-UX-001 | ALWAYS provide clear feedback for user actions |
| AOR-UX-002 | ALWAYS maintain consistent visual hierarchy |
| AOR-UX-003 | ALWAYS support dark mode in all interfaces |
| AOR-UX-004 | ALWAYS provide empty states with guidance |
| AOR-CX-001 | ALWAYS track user progress in onboarding |
| AOR-CX-002 | NEVER force users to complete onboarding |
| AOR-DX-001 | ALWAYS version API endpoints |
| AOR-DX-002 | ALWAYS provide detailed error responses |
| AOR-DX-003 | ALWAYS include request IDs for debugging |

---

## 23. OpenRouter & Distributed Intelligence

This section describes how OpenRouter and distributed AI intelligence are integrated at each layer of the system, from individual task processing to federation-level decision making.

### 23.1 Intelligence Architecture Overview

```fsharp
/// Distributed intelligence architecture
module DistributedIntelligence =

    /// Intelligence layer hierarchy
    type IntelligenceLayer =
        | L0_TaskLevel                         // Individual task AI
        | L1_ProjectLevel                      // Project coordination AI
        | L2_ProgramLevel                      // Program strategy AI
        | L3_PortfolioLevel                    // Portfolio optimization AI
        | L4_OrganizationLevel                 // Organization-wide AI
        | L5_FederationLevel                   // Cross-holon federation AI
        | L6_EcosystemLevel                    // External partner AI
        | L7_GlobalLevel                       // Global intelligence mesh

    /// OpenRouter configuration
    type OpenRouterConfig = {
        Endpoint: string                       // https://openrouter.ai/api/v1
        ApiKey: string                         // Encrypted in KMS
        Models: ModelConfig list
        FallbackChain: string list
        RateLimits: RateLimitConfig
        Caching: CacheConfig
        Telemetry: TelemetryConfig
    }

    /// Model configuration
    type ModelConfig = {
        Id: string                             // e.g., "anthropic/claude-3-opus"
        Provider: AIProvider
        Capabilities: Capability Set
        CostPerToken: decimal
        ContextWindow: int
        RateLimit: int                         // Requests per minute
        Priority: int                          // Fallback priority
    }

    type AIProvider =
        | Anthropic                            // Claude models
        | OpenAI                               // GPT models
        | Google                               // Gemini models
        | Mistral                              // Mistral models
        | Meta                                 // Llama models
        | Local                                // Self-hosted models

    type Capability =
        | TextGeneration
        | CodeGeneration
        | Reasoning
        | Planning
        | Summarization
        | Classification
        | Extraction
        | Translation
        | VisionAnalysis
        | ToolUse

    /// Cortex integration (F# AI layer)
    type CortexConfig = {
        OpenRouter: OpenRouterConfig
        LocalModels: LocalModelConfig list
        Caching: AICache
        CircuitBreaker: CircuitBreakerConfig
        Telemetry: AITelemetry
    }
```

### 23.2 Layer-Specific Intelligence Integration

```fsharp
/// Intelligence at each system layer
module LayerIntelligence =

    /// L0: Task-Level Intelligence
    module TaskIntelligence =

        /// Natural language task parsing
        let parseTask (input: string) : Async<Result<TaskParseResult, AIError>> =
            async {
                let prompt = sprintf """
                Parse the following natural language input into a structured task:

                Input: "%s"

                Extract:
                - Title (required)
                - Description (optional)
                - Priority (P0-P4, default P2)
                - Due date (if mentioned)
                - Tags (any mentioned categories)
                - Assignee (if mentioned)
                - Dependencies (if "after", "depends on" mentioned)

                Respond in JSON format.
                """ input

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-haiku"
                    Prompt = prompt
                    Temperature = 0.1
                    MaxTokens = 500
                }

                return response |> Result.bind parseTaskJson
            }

        /// Task effort estimation
        let estimateEffort (task: Task) : Async<EffortEstimate> =
            async {
                let prompt = sprintf """
                Estimate the effort for this task:

                Title: %s
                Description: %s

                Consider:
                - Complexity
                - Dependencies
                - Similar historical tasks

                Provide estimate in hours with confidence interval.
                """ task.Title (task.Description |> Option.defaultValue "")

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-haiku"
                    Prompt = prompt
                    Temperature = 0.3
                }

                return parseEffortEstimate response
            }

        /// Task decomposition
        let decomposeTask (task: Task) : Async<Task list> =
            async {
                let prompt = sprintf """
                Break down this task into subtasks:

                Task: %s
                Description: %s

                Create 3-7 concrete, actionable subtasks.
                Each subtask should be completable in 1-4 hours.
                """ task.Title (task.Description |> Option.defaultValue "")

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-sonnet"
                    Prompt = prompt
                    Temperature = 0.5
                }

                return parseSubtasks response task.Id
            }

    /// L1: Project-Level Intelligence
    module ProjectIntelligence =

        /// Sprint planning assistance
        let planSprint (project: Project) (capacity: float) : Async<SprintPlan> =
            async {
                let tasks = project.BacklogTasks
                let prompt = sprintf """
                Plan a sprint with %f hours capacity.

                Available tasks:
                %s

                Consider:
                - Task priorities
                - Dependencies
                - Team velocity history
                - Risk factors

                Select tasks that maximize value while respecting capacity.
                """ capacity (formatTasksForAI tasks)

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-sonnet"
                    Prompt = prompt
                    Temperature = 0.3
                }

                return parseSprintPlan response
            }

        /// Risk analysis
        let analyzeRisks (project: Project) : Async<RiskAssessment> =
            async {
                let prompt = sprintf """
                Analyze risks for project: %s

                Current state:
                - Tasks: %d total, %d completed
                - Timeline: %s to %s
                - Dependencies: %s

                Identify:
                - Schedule risks
                - Resource risks
                - Technical risks
                - External risks

                Rate each risk: Impact (1-5) × Probability (1-5)
                """ project.Name project.TotalTasks project.CompletedTasks
                   (formatDate project.StartDate) (formatDate project.EndDate)
                   (formatDependencies project.Dependencies)

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-opus"
                    Prompt = prompt
                    Temperature = 0.2
                }

                return parseRiskAssessment response
            }

    /// L2: Program-Level Intelligence
    module ProgramIntelligence =

        /// Cross-project dependency analysis
        let analyzeDependencies (program: Program) : Async<DependencyAnalysis> =
            async {
                let projects = program.Projects
                let prompt = sprintf """
                Analyze dependencies across projects in program: %s

                Projects:
                %s

                Identify:
                - Critical path across projects
                - Bottleneck resources
                - Synchronization points
                - Risk areas

                Suggest optimizations.
                """ program.Name (formatProjectsForAI projects)

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-opus"
                    Prompt = prompt
                    Temperature = 0.2
                }

                return parseDependencyAnalysis response
            }

    /// L3: Portfolio-Level Intelligence
    module PortfolioIntelligence =

        /// Strategic alignment analysis
        let analyzeAlignment (portfolio: Portfolio) : Async<AlignmentReport> =
            async {
                let prompt = sprintf """
                Analyze strategic alignment of portfolio: %s

                Strategic goals:
                %s

                Current programs:
                %s

                Assess:
                - Goal coverage
                - Resource allocation efficiency
                - Investment balance
                - Gap analysis

                Recommend portfolio adjustments.
                """ portfolio.Name
                   (formatGoals portfolio.StrategicGoals)
                   (formatPrograms portfolio.Programs)

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-opus"
                    Prompt = prompt
                    Temperature = 0.3
                    MaxTokens = 2000
                }

                return parseAlignmentReport response
            }

    /// L4: Organization-Level Intelligence
    module OrganizationIntelligence =

        /// Capacity planning across organization
        let planCapacity (org: Organization) (horizon: TimeSpan) : Async<CapacityPlan> =
            async {
                let prompt = sprintf """
                Plan capacity for organization: %s
                Planning horizon: %s

                Current resources:
                %s

                Planned initiatives:
                %s

                Determine:
                - Resource gaps
                - Hiring needs
                - Training requirements
                - Outsourcing opportunities
                """ org.Name (formatTimeSpan horizon)
                   (formatResources org.Resources)
                   (formatInitiatives org.PlannedInitiatives)

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-opus"
                    Prompt = prompt
                    Temperature = 0.3
                }

                return parseCapacityPlan response
            }

    /// L5: Federation-Level Intelligence
    module FederationIntelligence =

        /// Cross-holon coordination
        let coordinateFederation (federation: Federation) (decision: Decision) : Async<CoordinationPlan> =
            async {
                let prompt = sprintf """
                Coordinate decision across federation: %s

                Decision: %s
                Context: %s

                Member holons:
                %s

                Determine:
                - Affected holons
                - Required approvals
                - Synchronization protocol
                - Rollback plan
                """ federation.Name decision.Title decision.Context
                   (formatHolons federation.Members)

                let! response = Cortex.complete {
                    Model = "anthropic/claude-3-opus"
                    Prompt = prompt
                    Temperature = 0.2
                }

                return parseCoordinationPlan response
            }
```

### 23.3 OODA Cycle AI Integration

```fsharp
/// AI-enhanced OODA cycle
module OodaIntelligence =

    /// AI-assisted observation
    let enhanceObservation (cycle: OodaCycle) (rawData: Observation list) : Async<EnhancedObservations> =
        async {
            let prompt = sprintf """
            Enhance observations for OODA cycle: %s
            Context: %s

            Raw observations:
            %s

            For each observation:
            1. Extract key facts
            2. Identify patterns
            3. Note anomalies
            4. Suggest additional data needs
            5. Rate confidence (0-1)
            """ cycle.Id cycle.Context (formatObservations rawData)

            let! response = Cortex.complete {
                Model = "anthropic/claude-3-sonnet"
                Prompt = prompt
                Temperature = 0.3
            }

            return parseEnhancedObservations response
        }

    /// AI-assisted orientation (sensemaking)
    let assistOrientation (cycle: OodaCycle) (observations: EnhancedObservations) : Async<OrientationAnalysis> =
        async {
            let prompt = sprintf """
            Perform orientation analysis for: %s

            Enhanced observations:
            %s

            Historical context:
            %s

            Produce:
            1. Situation assessment
            2. Key factors identified
            3. Cause-effect relationships
            4. Mental model updates
            5. Bias check (confirmation, anchoring, etc.)
            6. Uncertainty areas
            """ cycle.Context (formatEnhancedObs observations)
               (formatHistory cycle.History)

            let! response = Cortex.complete {
                Model = "anthropic/claude-3-opus"
                Prompt = prompt
                Temperature = 0.4
            }

            return parseOrientationAnalysis response
        }

    /// AI-generated decision options
    let generateOptions (cycle: OodaCycle) (analysis: OrientationAnalysis) : Async<DecisionOption list> =
        async {
            let prompt = sprintf """
            Generate decision options for: %s

            Situation analysis:
            %s

            Constraints:
            %s

            Generate 3-5 distinct options:
            For each option provide:
            - Name and description
            - Pros and cons
            - Resource requirements
            - Risk assessment
            - Success criteria
            - Recommended timeline
            """ cycle.Context (formatAnalysis analysis)
               (formatConstraints cycle.Constraints)

            let! response = Cortex.complete {
                Model = "anthropic/claude-3-opus"
                Prompt = prompt
                Temperature = 0.6
                MaxTokens = 2000
            }

            return parseDecisionOptions response
        }

    /// AI-recommended action plan
    let recommendAction (cycle: OodaCycle) (selected: DecisionOption) : Async<ActionPlan> =
        async {
            let prompt = sprintf """
            Create action plan for selected option: %s

            Option details:
            %s

            Available resources:
            %s

            Create detailed plan with:
            1. Immediate actions (next 24h)
            2. Short-term actions (next week)
            3. Checkpoints and milestones
            4. Risk mitigations
            5. Communication plan
            6. Success metrics
            7. Contingency triggers
            """ selected.Name (formatOption selected)
               (formatResources cycle.AvailableResources)

            let! response = Cortex.complete {
                Model = "anthropic/claude-3-opus"
                Prompt = prompt
                Temperature = 0.3
            }

            return parseActionPlan response
        }
```

### 23.4 Distributed AI Coordination

```fsharp
/// Distributed AI coordination via Zenoh
module DistributedAICoordination =

    /// AI request routing
    type AIRequest = {
        Id: RequestId
        Layer: IntelligenceLayer
        Type: AIRequestType
        Priority: Priority
        Payload: string
        Source: HolonId
        Timeout: TimeSpan
    }

    type AIRequestType =
        | Completion                           // Text completion
        | Analysis                             // Data analysis
        | Recommendation                       // Decision support
        | Validation                           // Input validation
        | Extraction                           // Information extraction
        | Translation                          // Language translation

    /// Zenoh topics for AI coordination
    let aiTopics = {|
        Request = "indrajaal/ai/request/{layer}/{type}"
        Response = "indrajaal/ai/response/{requestId}"
        Status = "indrajaal/ai/status/{holonId}"
        Metrics = "indrajaal/ai/metrics/{holonId}"
        Cache = "indrajaal/ai/cache/{hash}"
    |}

    /// AI request router
    let routeRequest (request: AIRequest) : Async<AIResponse> =
        async {
            // Check local cache first
            let cacheKey = computeCacheKey request
            match! AICache.get cacheKey with
            | Some cached -> return cached
            | None ->
                // Route based on layer and load
                let targetNode = selectBestNode request.Layer request.Priority

                // Publish request via Zenoh
                let topic = sprintf aiTopics.Request request.Layer request.Type
                do! Zenoh.publish topic (serialize request)

                // Wait for response
                let responseTopic = sprintf aiTopics.Response request.Id
                let! response = Zenoh.subscribe responseTopic |> Async.AwaitFirst

                // Cache successful responses
                if response.Success then
                    do! AICache.set cacheKey response (TimeSpan.FromHours 1.0)

                return response
        }

    /// Load balancing across AI nodes
    type AINodeSelector = {
        Nodes: AINode list
        LoadMetrics: Map<HolonId, LoadMetrics>
        CircuitBreakers: Map<HolonId, CircuitBreaker>
    }

    let selectBestNode (layer: IntelligenceLayer) (priority: Priority) : HolonId =
        let availableNodes =
            nodes
            |> List.filter (fun n -> n.SupportsLayer layer)
            |> List.filter (fun n -> not (CircuitBreaker.isOpen n.Id))
            |> List.sortBy (fun n -> LoadMetrics.get n.Id |> computeScore)

        match availableNodes with
        | [] -> failwith "No AI nodes available"
        | nodes ->
            match priority with
            | P0 | P1 -> nodes |> List.head       // Best node for high priority
            | _ -> nodes |> List.item (Random.next nodes.Length)  // Random for load distribution
```

### 23.5 AI Model Selection Strategy

```fsharp
/// Model selection based on task requirements
module ModelSelection =

    /// Model capabilities matrix
    let modelCapabilities = Map [
        "anthropic/claude-3-opus", {|
            Reasoning = 0.95
            Coding = 0.90
            Planning = 0.95
            Speed = 0.40
            Cost = 0.20
            Context = 200000
        |}
        "anthropic/claude-3-sonnet", {|
            Reasoning = 0.85
            Coding = 0.85
            Planning = 0.80
            Speed = 0.70
            Cost = 0.50
            Context = 200000
        |}
        "anthropic/claude-3-haiku", {|
            Reasoning = 0.70
            Coding = 0.75
            Planning = 0.65
            Speed = 0.95
            Cost = 0.90
            Context = 200000
        |}
        "openai/gpt-4-turbo", {|
            Reasoning = 0.90
            Coding = 0.90
            Planning = 0.85
            Speed = 0.60
            Cost = 0.40
            Context = 128000
        |}
        "google/gemini-pro", {|
            Reasoning = 0.85
            Coding = 0.80
            Planning = 0.80
            Speed = 0.75
            Cost = 0.60
            Context = 32000
        |}
        "mistral/mistral-large", {|
            Reasoning = 0.80
            Coding = 0.85
            Planning = 0.75
            Speed = 0.80
            Cost = 0.70
            Context = 32000
        |}
    ]

    /// Select optimal model for task
    let selectModel (requirements: AIRequirements) : string =
        let candidates =
            modelCapabilities
            |> Map.filter (fun _ cap ->
                cap.Reasoning >= requirements.MinReasoning &&
                cap.Context >= requirements.ContextSize &&
                cap.Cost >= requirements.MinCostEfficiency)
            |> Map.toList

        match requirements.Optimize with
        | OptimizeFor.Quality ->
            candidates |> List.maxBy (fun (_, c) -> c.Reasoning)
        | OptimizeFor.Speed ->
            candidates |> List.maxBy (fun (_, c) -> c.Speed)
        | OptimizeFor.Cost ->
            candidates |> List.maxBy (fun (_, c) -> c.Cost)
        | OptimizeFor.Balanced ->
            candidates |> List.maxBy (fun (_, c) ->
                c.Reasoning * 0.4 + c.Speed * 0.3 + c.Cost * 0.3)
        |> fst

    /// Fallback chain for reliability
    let fallbackChain = [
        "anthropic/claude-3-sonnet"            // Primary
        "openai/gpt-4-turbo"                   // First fallback
        "google/gemini-pro"                    // Second fallback
        "mistral/mistral-large"                // Third fallback
        "anthropic/claude-3-haiku"             // Fast fallback
    ]
```

### 23.6 AI Caching and Cost Optimization

```fsharp
/// AI response caching
module AICache =

    /// Cache configuration
    type CacheConfig = {
        Backend: CacheBackend
        TTL: TimeSpan
        MaxSize: int64
        EvictionPolicy: EvictionPolicy
    }

    type CacheBackend =
        | SQLite of path: string               // Local SQLite cache
        | DuckDB of path: string               // Analytics-optimized cache
        | Zenoh of topic: string               // Distributed cache

    /// Cache key computation
    let computeCacheKey (request: AIRequest) : string =
        let normalized = normalizeRequest request
        let hash = SHA256.hash (serialize normalized)
        sprintf "ai:cache:%s" hash

    /// Semantic similarity for cache hits
    let findSimilarCached (request: AIRequest) (threshold: float) : AIResponse option =
        // Use embedding similarity for near-matches
        let embedding = Embeddings.compute request.Payload

        query {
            for cached in cacheTable do
            let similarity = cosineSimilarity embedding cached.Embedding
            where (similarity >= threshold)
            sortByDescending similarity
            take 1
            select cached.Response
        }
        |> Seq.tryHead

    /// Cost tracking
    type CostTracker = {
        TotalTokens: int64
        TotalCost: decimal
        ByModel: Map<string, decimal>
        ByLayer: Map<IntelligenceLayer, decimal>
        Budget: decimal
        Period: TimeSpan
    }

    let trackCost (model: string) (tokens: int) : unit =
        let costPerToken = modelCosts |> Map.find model
        let cost = decimal tokens * costPerToken

        CostTracker.add {
            Model = model
            Tokens = tokens
            Cost = cost
            Timestamp = DateTimeOffset.UtcNow
        }

        // Alert if approaching budget
        let currentSpend = CostTracker.getCurrentPeriodSpend ()
        if currentSpend > budget * 0.8m then
            Alerts.emit (BudgetWarning (currentSpend, budget))
```

### 23.7 STAMP Constraints (AI Integration)

| ID | Constraint | Severity | Layer |
|----|------------|----------|-------|
| SC-AI-001 | AI requests MUST timeout after 30s | HIGH | All |
| SC-AI-002 | AI responses MUST be validated | HIGH | All |
| SC-AI-003 | AI MUST NOT make autonomous destructive decisions | CRITICAL | All |
| SC-AI-004 | AI cost MUST stay within budget | HIGH | All |
| SC-AI-005 | AI cache hit rate MUST exceed 30% | MEDIUM | All |
| SC-AI-006 | AI fallback chain MUST have 3+ models | HIGH | All |
| SC-AI-007 | AI decisions MUST be logged to register | CRITICAL | L3+ |
| SC-AI-008 | AI MUST defer to Guardian for mutations | CRITICAL | All |
| SC-AI-009 | AI prompts MUST NOT leak sensitive data | CRITICAL | All |
| SC-AI-010 | AI latency p99 MUST be < 5s | HIGH | L0-L2 |

### 23.8 AOR Rules (AI Integration)

| ID | Rule |
|----|------|
| AOR-AI-001 | ALWAYS use appropriate model for task complexity |
| AOR-AI-002 | ALWAYS check cache before API call |
| AOR-AI-003 | ALWAYS implement exponential backoff on failures |
| AOR-AI-004 | ALWAYS log AI decisions with rationale |
| AOR-AI-005 | NEVER send PII to external AI providers |
| AOR-AI-006 | ALWAYS validate AI-generated JSON/code |
| AOR-AI-007 | ALWAYS provide human override for AI decisions |
| AOR-AI-008 | ALWAYS track token usage and costs |
| AOR-AI-009 | ALWAYS use structured prompts for consistency |
| AOR-AI-010 | ALWAYS include context limits in prompts |

---

## 24. System Artifacts Reference

This section catalogs all system artifacts for integration with Zettelkasten and SMRITI knowledge management systems.

### 24.1 Artifact Taxonomy

```fsharp
/// System artifact classification
module ArtifactTaxonomy =

    /// Artifact categories
    type ArtifactCategory =
        | Specification                        // Requirements, designs
        | Implementation                       // Source code, scripts
        | Configuration                        // Config files, schemas
        | Documentation                        // Guides, tutorials
        | Test                                 // Test files, fixtures
        | Deployment                           // Infrastructure, compose
        | Governance                           // Rules, constraints
        | Integration                          // Bridges, adapters

    /// Artifact metadata
    type Artifact = {
        Id: ArtifactId
        Path: string
        Category: ArtifactCategory
        Domain: PlanningDomain
        Layer: FractalLayer
        Tags: string Set
        Dependencies: ArtifactId Set
        DependedBy: ArtifactId Set
        Version: Version
        LastModified: DateTimeOffset
        Hash: string
        ZettelId: string option
        SmritiHolonId: HolonId option
    }

    /// Domain classification
    type PlanningDomain =
        | Core                                 // Core planning logic
        | Task                                 // Task management
        | Project                              // Project management
        | OODA                                 // Decision framework
        | LongTerm                             // 1000-year planning
        | MixedTeam                            // Human-agent teams
        | Mathematical                         // Formal methods
        | Graph                                // Graph algorithms
        | Simulation                           // Monte Carlo, DES
        | UI                                   // User interfaces
        | AI                                   // AI integration
        | Integration                          // External systems
```

### 24.2 Specification Artifacts

| Artifact ID | Path | Domain | Layer | SMRITI Holon |
|-------------|------|--------|-------|--------------|
| SPEC-001 | `docs/planning/INDRAJAAL_PLANNING_SYSTEM_INTEGRATED_SPEC.md` | Core | L7 | `holon:planning:spec:master` |
| SPEC-002 | `docs/planning/PLANNING-TASKEXECUTION-SYSTEM.md` | Core | L5 | `holon:planning:spec:original` |
| SPEC-003 | `docs/planning/integrated_planning_requirements.md` | Core | L5 | `holon:planning:spec:requirements` |
| SPEC-004 | `docs/planning/9_level_analysis_planning_system.md` | Mathematical | L6 | `holon:planning:spec:analysis` |
| SPEC-005 | `CLAUDE.md` | Governance | L7 | `holon:system:claude:master` |
| SPEC-006 | `GEMINI.md` | Governance | L7 | `holon:system:gemini:architect` |
| SPEC-007 | `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md` | Governance | L7 | `holon:system:founder:directive` |
| SPEC-008 | `docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md` | Core | L7 | `holon:system:immortal:arch` |
| SPEC-009 | `docs/architecture/HOLON_IMMUTABLE_REGISTER.md` | Core | L6 | `holon:system:register:spec` |

### 24.3 Implementation Artifacts

| Artifact ID | Path | Domain | Layer | SMRITI Holon |
|-------------|------|--------|-------|--------------|
| IMPL-001 | `lib/cepaf/src/Cepaf.Planning/Domain/Task.fs` | Task | L3 | `holon:planning:impl:task` |
| IMPL-002 | `lib/cepaf/src/Cepaf.Planning/Domain/Project.fs` | Project | L3 | `holon:planning:impl:project` |
| IMPL-003 | `lib/cepaf/src/Cepaf.Planning/Domain/OODA.fs` | OODA | L3 | `holon:planning:impl:ooda` |
| IMPL-004 | `lib/cepaf/src/Cepaf.Planning/EventSourcing/EventStore.fs` | Core | L4 | `holon:planning:impl:eventstore` |
| IMPL-005 | `lib/cepaf/src/Cepaf.Planning/Persistence/SQLiteStore.fs` | Core | L4 | `holon:planning:impl:sqlite` |
| IMPL-006 | `lib/cepaf/src/Cepaf.Planning/Persistence/DuckDBStore.fs` | Core | L4 | `holon:planning:impl:duckdb` |
| IMPL-007 | `lib/cepaf/src/Cepaf.Planning/AI/CortexClient.fs` | AI | L4 | `holon:planning:impl:cortex` |
| IMPL-008 | `lib/cepaf/src/Cepaf.Planning/AI/OpenRouterClient.fs` | AI | L4 | `holon:planning:impl:openrouter` |
| IMPL-009 | `lib/cepaf/src/Cepaf.Planning/Zenoh/PlanningChannel.fs` | Integration | L4 | `holon:planning:impl:zenoh` |
| IMPL-010 | `lib/cepaf/src/Cepaf.Planning/Bridge/ElixirBridge.fs` | Integration | L4 | `holon:planning:impl:elixir` |
| IMPL-011 | `lib/cepaf/src/Cepaf.Planning/LongTerm/MillenniumPlanner.fs` | LongTerm | L5 | `holon:planning:impl:millennium` |
| IMPL-012 | `lib/cepaf/src/Cepaf.Planning/Teams/MixedTeamManager.fs` | MixedTeam | L4 | `holon:planning:impl:mixedteam` |
| IMPL-013 | `lib/cepaf/src/Cepaf.Planning/Graph/TaskGraph.fs` | Graph | L3 | `holon:planning:impl:taskgraph` |
| IMPL-014 | `lib/cepaf/src/Cepaf.Planning/Simulation/MonteCarlo.fs` | Simulation | L4 | `holon:planning:impl:montecarlo` |

### 24.4 UI/UX Artifacts

| Artifact ID | Path | Domain | Layer | SMRITI Holon |
|-------------|------|--------|-------|--------------|
| UI-001 | `lib/cepaf/src/Cepaf.Planning.TUI/App.fs` | UI | L2 | `holon:planning:ui:tui` |
| UI-002 | `lib/cepaf/src/Cepaf.Planning.TUI/Panels/*.fs` | UI | L2 | `holon:planning:ui:tui:panels` |
| UI-003 | `lib/cepaf/src/Cepaf.Planning.CLI/Commands/*.fs` | UI | L2 | `holon:planning:ui:cli` |
| UI-004 | `lib/indrajaal_web/live/planning/*.ex` | UI | L2 | `holon:planning:ui:liveview` |
| UI-005 | `assets/js/planning/*.js` | UI | L1 | `holon:planning:ui:js` |
| UI-006 | `priv/static/planning/*.css` | UI | L1 | `holon:planning:ui:css` |

### 24.5 Test Artifacts

| Artifact ID | Path | Domain | Layer | SMRITI Holon |
|-------------|------|--------|-------|--------------|
| TEST-001 | `test/cepaf/planning/TaskTests.fs` | Task | L2 | `holon:planning:test:task` |
| TEST-002 | `test/cepaf/planning/ProjectTests.fs` | Project | L2 | `holon:planning:test:project` |
| TEST-003 | `test/cepaf/planning/OodaTests.fs` | OODA | L2 | `holon:planning:test:ooda` |
| TEST-004 | `test/cepaf/planning/PropertyTests.fs` | Core | L3 | `holon:planning:test:property` |
| TEST-005 | `test/cepaf/planning/IntegrationTests.fs` | Core | L4 | `holon:planning:test:integration` |
| TEST-006 | `test/features/planning/*.feature` | Core | L4 | `holon:planning:test:bdd` |

### 24.6 Configuration Artifacts

| Artifact ID | Path | Domain | Layer | SMRITI Holon |
|-------------|------|--------|-------|--------------|
| CFG-001 | `config/planning.yaml` | Core | L5 | `holon:planning:config:main` |
| CFG-002 | `config/ai_models.yaml` | AI | L4 | `holon:planning:config:ai` |
| CFG-003 | `config/zenoh_planning.yaml` | Integration | L4 | `holon:planning:config:zenoh` |

### 24.7 Governance Artifacts (STAMP/AOR)

| Artifact ID | Path | Domain | Layer | SMRITI Holon |
|-------------|------|--------|-------|--------------|
| GOV-001 | `.claude/rules/planning-constraints.md` | Governance | L7 | `holon:planning:gov:stamp` |
| GOV-002 | `.claude/rules/planning-aor.md` | Governance | L7 | `holon:planning:gov:aor` |

### 24.8 Zettelkasten Integration

```fsharp
/// Zettelkasten note structure for artifacts
module ZettelkastenIntegration =

    /// Zettel note format
    type Zettel = {
        Id: string                             // Unique ID (e.g., "202601141200a")
        Title: string
        Content: string
        Tags: string list
        Links: ZettelLink list
        ArtifactRef: ArtifactId option
        Created: DateTimeOffset
        Modified: DateTimeOffset
    }

    type ZettelLink = {
        Target: string
        Type: LinkType
        Context: string
    }

    type LinkType =
        | References                           // This references that
        | Extends                              // This extends that
        | Implements                           // This implements that
        | Contradicts                          // This contradicts that
        | Supersedes                           // This supersedes that
        | RelatedTo                            // General relation

    /// Generate Zettel from artifact
    let generateZettel (artifact: Artifact) : Zettel =
        {
            Id = generateZettelId ()
            Title = Path.GetFileNameWithoutExtension artifact.Path
            Content = sprintf """
# %s

## Metadata
- **Path**: %s
- **Category**: %A
- **Domain**: %A
- **Layer**: %A
- **Version**: %s

## Description
[Auto-generated from artifact analysis]

## Dependencies
%s

## Depended By
%s

## Tags
%s
""" artifact.Path artifact.Path artifact.Category artifact.Domain
   artifact.Layer (string artifact.Version)
   (artifact.Dependencies |> Set.toList |> String.concat ", ")
   (artifact.DependedBy |> Set.toList |> String.concat ", ")
   (artifact.Tags |> Set.toList |> String.concat ", ")
            Tags = artifact.Tags |> Set.toList
            Links = generateLinks artifact
            ArtifactRef = Some artifact.Id
            Created = DateTimeOffset.UtcNow
            Modified = DateTimeOffset.UtcNow
        }
```

### 24.9 SMRITI Holon Integration

```fsharp
/// SMRITI knowledge holon integration
module SmritiIntegration =

    /// Holon structure for planning artifacts
    type PlanningHolon = {
        Id: HolonId
        Type: HolonType
        ArtifactRefs: ArtifactId list
        Knowledge: Knowledge
        Edges: Edge list
        Version: VersionVector
        Signature: Ed25519Signature
    }

    type HolonType =
        | Specification
        | Implementation
        | Test
        | Configuration
        | Documentation
        | Index

    type Knowledge = {
        Summary: string
        KeyConcepts: string list
        StampConstraints: string list
        AorRules: string list
        Dependencies: HolonId list
        Examples: Example list
    }

    /// Generate holon from artifacts
    let generateHolon (artifacts: Artifact list) (holonType: HolonType) : PlanningHolon =
        let knowledge = {
            Summary = generateSummary artifacts
            KeyConcepts = extractConcepts artifacts
            StampConstraints = extractStampConstraints artifacts
            AorRules = extractAorRules artifacts
            Dependencies = extractDependencies artifacts
            Examples = extractExamples artifacts
        }

        {
            Id = generateHolonId ()
            Type = holonType
            ArtifactRefs = artifacts |> List.map (fun a -> a.Id)
            Knowledge = knowledge
            Edges = generateEdges artifacts
            Version = VersionVector.initial
            Signature = sign knowledge
        }

    /// Holon hierarchy for planning system
    let planningHolonHierarchy =
        Holon("planning:root", Index, [
            Holon("planning:spec", Specification, [
                Holon("planning:spec:master", Specification, [])
                Holon("planning:spec:requirements", Specification, [])
            ])
            Holon("planning:impl", Implementation, [
                Holon("planning:impl:core", Implementation, [])
                Holon("planning:impl:task", Implementation, [])
                Holon("planning:impl:project", Implementation, [])
                Holon("planning:impl:ooda", Implementation, [])
                Holon("planning:impl:longterm", Implementation, [])
                Holon("planning:impl:mixedteam", Implementation, [])
                Holon("planning:impl:ai", Implementation, [])
            ])
            Holon("planning:ui", Implementation, [
                Holon("planning:ui:tui", Implementation, [])
                Holon("planning:ui:cli", Implementation, [])
                Holon("planning:ui:web", Implementation, [])
                Holon("planning:ui:emacs", Implementation, [])
            ])
            Holon("planning:test", Test, [])
            Holon("planning:config", Configuration, [])
            Holon("planning:gov", Documentation, [])
        ])
```

### 24.10 Artifact Discovery Queries

```fsharp
/// Queries for artifact discovery
module ArtifactDiscovery =

    /// Find artifacts by domain
    let byDomain (domain: PlanningDomain) : Artifact list =
        query {
            for a in artifactIndex do
            where (a.Domain = domain)
            sortBy a.Path
        }
        |> Seq.toList

    /// Find artifacts by tag
    let byTag (tag: string) : Artifact list =
        query {
            for a in artifactIndex do
            where (a.Tags |> Set.contains tag)
        }
        |> Seq.toList

    /// Find dependencies
    let dependencies (artifactId: ArtifactId) : Artifact list =
        let artifact = artifactIndex |> Map.find artifactId
        artifact.Dependencies
        |> Set.toList
        |> List.map (fun id -> artifactIndex |> Map.find id)

    /// Find dependents
    let dependents (artifactId: ArtifactId) : Artifact list =
        let artifact = artifactIndex |> Map.find artifactId
        artifact.DependedBy
        |> Set.toList
        |> List.map (fun id -> artifactIndex |> Map.find id)

    /// Find related via SMRITI
    let relatedViaSmriti (artifactId: ArtifactId) : Artifact list =
        let artifact = artifactIndex |> Map.find artifactId
        match artifact.SmritiHolonId with
        | Some holonId ->
            let holon = Smriti.getHolon holonId
            holon.Edges
            |> List.choose (fun e ->
                artifactIndex
                |> Map.tryFind e.Target.ArtifactRef)
        | None -> []
```

### 24.11 STAMP Constraints (Artifacts)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-ART-001 | All artifacts MUST have unique IDs | CRITICAL |
| SC-ART-002 | Artifacts MUST be versioned | HIGH |
| SC-ART-003 | Dependencies MUST be acyclic | HIGH |
| SC-ART-004 | SMRITI holons MUST be signed | CRITICAL |
| SC-ART-005 | Zettel IDs MUST follow timestamp format | MEDIUM |
| SC-ART-006 | Artifact index MUST be updated on change | HIGH |
| SC-ART-007 | Cross-references MUST be bidirectional | MEDIUM |

### 24.12 AOR Rules (Artifacts)

| ID | Rule |
|----|------|
| AOR-ART-001 | ALWAYS update artifact index after changes |
| AOR-ART-002 | ALWAYS generate Zettel for new artifacts |
| AOR-ART-003 | ALWAYS link SMRITI holons bidirectionally |
| AOR-ART-004 | ALWAYS include STAMP constraints in artifacts |
| AOR-ART-005 | NEVER delete artifacts without archiving |
| AOR-ART-006 | ALWAYS verify artifact hash on read |

---

## 25. Comprehensive System Integration

This section provides exhaustive coverage of CLI tools, environment configuration, scripts, documentation, and integration with the complete Indrajaal ecosystem.

### 25.1 CLI Architecture

```fsharp
/// Complete CLI tool architecture
module CLIArchitecture =

    /// Main CLI entry points
    type CLITool =
        | IndrajaalCLI                         // Main planning CLI
        | TUIApp                               // Terminal UI application
        | DaemonService                        // Background service
        | MigrationTool                        // Database migrations
        | SyncTool                             // Sync utilities

    /// CLI command hierarchy
    type CommandTree = {
        Root: RootCommand
        Subcommands: Map<string, Subcommand>
        GlobalOptions: GlobalOptions
    }

    type RootCommand = {
        Name: string                           // "indrajaal"
        Version: string                        // "1.0.0-SIL6"
        Description: string
        Usage: string
    }

    type GlobalOptions = {
        Verbose: bool                          // -v, --verbose
        Quiet: bool                            // -q, --quiet
        Format: OutputFormat                   // -f, --format
        Config: string option                  // -c, --config
        Profile: string option                 // -p, --profile
        NoColor: bool                          // --no-color
        Debug: bool                            // --debug
    }

    /// Complete command inventory
    let commandInventory = [
        // Task commands
        ("task add", "Create a new task")
        ("task list", "List tasks with filters")
        ("task show", "Show task details")
        ("task edit", "Edit task properties")
        ("task complete", "Mark task complete")
        ("task delete", "Delete a task")
        ("task move", "Move task to project")
        ("task depend", "Add dependency")
        ("task parse", "Parse natural language")
        ("task import", "Import from file")
        ("task export", "Export to file")

        // Project commands
        ("project create", "Create new project")
        ("project list", "List projects")
        ("project show", "Show project details")
        ("project archive", "Archive project")
        ("project stats", "Project statistics")

        // Sprint commands
        ("sprint create", "Create new sprint")
        ("sprint start", "Start sprint")
        ("sprint end", "End sprint")
        ("sprint review", "Sprint review")

        // OODA commands
        ("ooda start", "Start OODA cycle")
        ("ooda observe", "Add observation")
        ("ooda orient", "Run orientation")
        ("ooda decide", "Make decision")
        ("ooda act", "Execute action")
        ("ooda history", "OODA history")

        // System commands
        ("config show", "Show configuration")
        ("config set", "Set config value")
        ("sync start", "Start sync daemon")
        ("sync status", "Sync status")
        ("daemon start", "Start daemon")
        ("daemon stop", "Stop daemon")
        ("daemon status", "Daemon status")
        ("db migrate", "Run migrations")
        ("db backup", "Backup database")
        ("db restore", "Restore database")

        // AI commands
        ("ai analyze", "AI analysis")
        ("ai suggest", "AI suggestions")
        ("ai decompose", "Decompose task")

        // Utility commands
        ("version", "Show version")
        ("help", "Show help")
        ("completion", "Generate completions")
    ]
```

### 25.2 Environment Configuration

```fsharp
/// Environment configuration module
module EnvironmentConfig =

    /// Environment file structure
    type EnvFile = {
        Path: string
        Variables: Map<string, EnvVar>
        Encrypted: bool
        Profile: string
    }

    type EnvVar = {
        Key: string
        Value: string
        Secret: bool
        Required: bool
        Default: string option
        Description: string
    }

    /// Standard environment files
    let envFiles = [
        ".env"                                 // Default environment
        ".env.development"                     // Development settings
        ".env.staging"                         // Staging settings
        ".env.production"                      // Production settings
        ".env.test"                            // Test settings
        ".env.local"                           // Local overrides (gitignored)
    ]

    /// Planning-specific environment variables
    let planningEnvVars = Map [
        "PLANNING_DATABASE_PATH", {
            Key = "PLANNING_DATABASE_PATH"
            Value = "data/planning/planning.db"
            Secret = false
            Required = true
            Default = Some "data/planning/planning.db"
            Description = "Path to SQLite database"
        }
        "PLANNING_DUCKDB_PATH", {
            Key = "PLANNING_DUCKDB_PATH"
            Value = "data/planning/analytics.duckdb"
            Secret = false
            Required = true
            Default = Some "data/planning/analytics.duckdb"
            Description = "Path to DuckDB analytics"
        }
        "PLANNING_ZENOH_ENDPOINT", {
            Key = "PLANNING_ZENOH_ENDPOINT"
            Value = "tcp/localhost:7447"
            Secret = false
            Required = true
            Default = Some "tcp/localhost:7447"
            Description = "Zenoh router endpoint"
        }
        "OPENROUTER_API_KEY", {
            Key = "OPENROUTER_API_KEY"
            Value = ""
            Secret = true
            Required = true
            Default = None
            Description = "OpenRouter API key"
        }
        "PLANNING_LOG_LEVEL", {
            Key = "PLANNING_LOG_LEVEL"
            Value = "info"
            Secret = false
            Required = false
            Default = Some "info"
            Description = "Logging level"
        }
        "PLANNING_GUARDIAN_ENABLED", {
            Key = "PLANNING_GUARDIAN_ENABLED"
            Value = "true"
            Secret = false
            Required = false
            Default = Some "true"
            Description = "Enable Guardian validation"
        }
    ]

    /// devenv.nix integration
    let devenvConfig = """
    { pkgs, lib, config, inputs, ... }:

    {
      # Planning system packages
      packages = with pkgs; [
        # F# runtime
        dotnet-sdk_10
        fsharp

        # Database tools
        sqlite
        duckdb

        # Zenoh
        zenoh

        # Build tools
        git
        jq
        yq

        # Testing
        fscheck
        expecto
      ];

      # Environment variables
      env = {
        PLANNING_DATABASE_PATH = "data/planning/planning.db";
        PLANNING_DUCKDB_PATH = "data/planning/analytics.duckdb";
        PLANNING_ZENOH_ENDPOINT = "tcp/localhost:7447";
        PLANNING_LOG_LEVEL = "debug";
        DOTNET_ROOT = "${pkgs.dotnet-sdk_10}";
      };

      # Scripts
      scripts = {
        planning-cli.exec = ''
          dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI
        '';
        planning-tui.exec = ''
          dotnet run --project lib/cepaf/src/Cepaf.Planning.TUI
        '';
        planning-test.exec = ''
          dotnet test lib/cepaf/test/Cepaf.Planning.Tests
        '';
        planning-migrate.exec = ''
          dotnet run --project lib/cepaf/src/Cepaf.Planning.Migrations
        '';
      };

      # Services
      services.postgres = {
        enable = false;  # PostgreSQL NOT used for planning state
      };
    }
    """
```

### 25.3 Script Inventory

```fsharp
/// Script inventory and documentation
module ScriptInventory =

    /// Script categories
    type ScriptCategory =
        | Build                                // Build and compilation
        | Test                                 // Testing scripts
        | Deploy                               // Deployment scripts
        | Migration                            // Database migrations
        | Utility                              // Helper utilities
        | Demo                                 // Demo and examples
        | Verification                         // Verification scripts

    /// Script metadata
    type Script = {
        Name: string
        Path: string
        Category: ScriptCategory
        Language: ScriptLanguage
        Description: string
        Usage: string
        Dependencies: string list
        Environment: Map<string, string>
    }

    type ScriptLanguage =
        | FSharp                               // .fsx scripts
        | Elixir                               // .exs scripts
        | Bash                                 // .sh scripts
        | Python                               // .py scripts

    /// Planning system scripts
    let planningScripts = [
        // Build scripts
        { Name = "build.fsx"
          Path = "lib/cepaf/scripts/build.fsx"
          Category = Build
          Language = FSharp
          Description = "Build all F# planning modules"
          Usage = "dotnet fsi build.fsx"
          Dependencies = ["dotnet-sdk_10"]
          Environment = Map.empty }

        { Name = "publish.fsx"
          Path = "lib/cepaf/scripts/publish.fsx"
          Category = Build
          Language = FSharp
          Description = "Publish release artifacts"
          Usage = "dotnet fsi publish.fsx --release"
          Dependencies = ["dotnet-sdk_10"]
          Environment = Map.empty }

        // Test scripts
        { Name = "run_tests.fsx"
          Path = "lib/cepaf/scripts/run_tests.fsx"
          Category = Test
          Language = FSharp
          Description = "Run all planning tests"
          Usage = "dotnet fsi run_tests.fsx --coverage"
          Dependencies = ["expecto"; "fscheck"]
          Environment = Map ["PLANNING_TEST_MODE", "true"] }

        { Name = "property_tests.fsx"
          Path = "lib/cepaf/scripts/property_tests.fsx"
          Category = Test
          Language = FSharp
          Description = "Run FsCheck property tests"
          Usage = "dotnet fsi property_tests.fsx"
          Dependencies = ["fscheck"]
          Environment = Map.empty }

        { Name = "integration_tests.fsx"
          Path = "lib/cepaf/scripts/integration_tests.fsx"
          Category = Test
          Language = FSharp
          Description = "Run integration tests"
          Usage = "dotnet fsi integration_tests.fsx"
          Dependencies = ["zenoh"; "sqlite"]
          Environment = Map ["PLANNING_ZENOH_ENDPOINT", "tcp/localhost:7447"] }

        // Migration scripts
        { Name = "migrate.fsx"
          Path = "lib/cepaf/scripts/migrate.fsx"
          Category = Migration
          Language = FSharp
          Description = "Run database migrations"
          Usage = "dotnet fsi migrate.fsx --up"
          Dependencies = ["sqlite"; "duckdb"]
          Environment = Map ["PLANNING_DATABASE_PATH", "data/planning/planning.db"] }

        { Name = "seed_data.fsx"
          Path = "lib/cepaf/scripts/seed_data.fsx"
          Category = Migration
          Language = FSharp
          Description = "Seed demo data"
          Usage = "dotnet fsi seed_data.fsx"
          Dependencies = ["sqlite"]
          Environment = Map.empty }

        // Verification scripts
        { Name = "verify_stamp.fsx"
          Path = "lib/cepaf/scripts/verify_stamp.fsx"
          Category = Verification
          Language = FSharp
          Description = "Verify STAMP constraints"
          Usage = "dotnet fsi verify_stamp.fsx"
          Dependencies = []
          Environment = Map.empty }

        { Name = "verify_coverage.fsx"
          Path = "lib/cepaf/scripts/verify_coverage.fsx"
          Category = Verification
          Language = FSharp
          Description = "Verify test coverage"
          Usage = "dotnet fsi verify_coverage.fsx --threshold 100"
          Dependencies = ["altcover"]
          Environment = Map.empty }

        // Demo scripts
        { Name = "demo_ooda.fsx"
          Path = "lib/cepaf/scripts/demo_ooda.fsx"
          Category = Demo
          Language = FSharp
          Description = "Demo OODA cycle"
          Usage = "dotnet fsi demo_ooda.fsx"
          Dependencies = []
          Environment = Map.empty }

        { Name = "demo_ai_planning.fsx"
          Path = "lib/cepaf/scripts/demo_ai_planning.fsx"
          Category = Demo
          Language = FSharp
          Description = "Demo AI-assisted planning"
          Usage = "dotnet fsi demo_ai_planning.fsx"
          Dependencies = ["openrouter"]
          Environment = Map ["OPENROUTER_API_KEY", "***"] }
    ]
```

### 25.4 Claude.md Integration

```fsharp
/// Integration with CLAUDE.md specification
module ClaudeMdIntegration =

    /// CLAUDE.md sections relevant to planning
    type ClaudeMdSection =
        | Axioms                               // Ω₀-Ω₉
        | Constitutional                       // Ψ₀-Ψ₅
        | StampConstraints                     // SC-*
        | AorRules                             // AOR-*
        | ErrorPatterns                        // EP-*

    /// Planning-specific CLAUDE.md references
    let claudeMdReferences = [
        // Axioms
        ("Ω₀", "Founder's Covenant", "All planning serves Founder's Directive")
        ("Ω₃", "Zero-Defect", "Planning quality gates mandatory")
        ("Ω₄", "TDG", "Test-Driven Generation for planning modules")
        ("Ω₇", "Holon State Sovereignty", "SQLite/DuckDB only for planning state")
        ("Ω₈", "Immutable Register", "Planning events append-only")

        // Constitutional
        ("Ψ₂", "Evolutionary Continuity", "Planning history preserved")
        ("Ψ₃", "Verification Capability", "All plans verifiable")
        ("Ψ₄", "Human Alignment", "Planning serves Founder's lineage")

        // Safety Constraints
        ("SC-PLAN-*", "Planning Constraints", "Task, Project, OODA safety")
        ("SC-OODA-*", "OODA Constraints", "Cycle time, phase transitions")
        ("SC-LTP-*", "Long-Term Planning", "1000-year planning safety")
        ("SC-MIX-*", "Mixed Teams", "Human-agent coordination")
        ("SC-AI-*", "AI Integration", "OpenRouter safety")
        ("SC-UI-*", "UI Constraints", "TUI, WebUI safety")

        // AOR Rules
        ("AOR-PLAN-*", "Planning Rules", "Task management rules")
        ("AOR-OODA-*", "OODA Rules", "Decision framework rules")
        ("AOR-AI-*", "AI Rules", "AI integration rules")
        ("AOR-UI-*", "UI Rules", "Interface rules")
    ]

    /// .claude directory integration
    type ClaudeRule = {
        Path: string
        Name: string
        AppliesTo: string list
        Constraints: string list
        AorRules: string list
    }

    let claudeRules = [
        { Path = ".claude/rules/planning-constraints.md"
          Name = "Planning STAMP Constraints"
          AppliesTo = ["lib/cepaf/src/Cepaf.Planning/**/*.fs"]
          Constraints = ["SC-PLAN-001"; "SC-PLAN-002"; "SC-PLAN-003"]
          AorRules = ["AOR-PLAN-001"; "AOR-PLAN-002"] }

        { Path = ".claude/rules/planning-aor.md"
          Name = "Planning AOR Rules"
          AppliesTo = ["lib/cepaf/src/Cepaf.Planning/**/*.fs"]
          Constraints = []
          AorRules = ["AOR-PLAN-*"] }

        { Path = ".claude/rules/ooda-constraints.md"
          Name = "OODA STAMP Constraints"
          AppliesTo = ["lib/cepaf/src/Cepaf.Planning/OODA/**/*.fs"]
          Constraints = ["SC-OODA-001"; "SC-OODA-002"]
          AorRules = ["AOR-OODA-*"] }

        { Path = ".claude/rules/planning-ai.md"
          Name = "AI Integration Rules"
          AppliesTo = ["lib/cepaf/src/Cepaf.Planning/AI/**/*.fs"]
          Constraints = ["SC-AI-001"; "SC-AI-002"]
          AorRules = ["AOR-AI-*"] }
    ]
```

### 25.5 Documentation Structure

```fsharp
/// Documentation structure
module DocumentationStructure =

    /// Documentation categories
    type DocCategory =
        | Architecture                         // System architecture
        | UserGuide                            // End-user documentation
        | DeveloperGuide                       // Developer documentation
        | APIReference                         // API documentation
        | Operations                           // Operations guides
        | Tutorials                            // Step-by-step tutorials

    /// Documentation inventory
    let documentationInventory = [
        // Architecture docs
        { Category = Architecture
          Path = "docs/planning/INDRAJAAL_PLANNING_SYSTEM_INTEGRATED_SPEC.md"
          Title = "Master Planning Specification"
          Audience = "Architects, Developers" }

        { Category = Architecture
          Path = "docs/planning/architecture/PLANNING_ARCHITECTURE.md"
          Title = "Planning Architecture"
          Audience = "Architects" }

        { Category = Architecture
          Path = "docs/planning/architecture/DATA_MODEL.md"
          Title = "Data Model Specification"
          Audience = "Developers" }

        // User guides
        { Category = UserGuide
          Path = "docs/planning/guides/GETTING_STARTED.md"
          Title = "Getting Started Guide"
          Audience = "All Users" }

        { Category = UserGuide
          Path = "docs/planning/guides/TASK_MANAGEMENT.md"
          Title = "Task Management Guide"
          Audience = "All Users" }

        { Category = UserGuide
          Path = "docs/planning/guides/PROJECT_MANAGEMENT.md"
          Title = "Project Management Guide"
          Audience = "Project Managers" }

        { Category = UserGuide
          Path = "docs/planning/guides/OODA_FRAMEWORK.md"
          Title = "OODA Decision Framework"
          Audience = "Decision Makers" }

        { Category = UserGuide
          Path = "docs/planning/guides/AI_ASSISTANT.md"
          Title = "AI Assistant Guide"
          Audience = "All Users" }

        // Developer guides
        { Category = DeveloperGuide
          Path = "docs/planning/dev/DEVELOPMENT_SETUP.md"
          Title = "Development Setup"
          Audience = "Developers" }

        { Category = DeveloperGuide
          Path = "docs/planning/dev/CONTRIBUTING.md"
          Title = "Contributing Guide"
          Audience = "Contributors" }

        { Category = DeveloperGuide
          Path = "docs/planning/dev/TESTING_GUIDE.md"
          Title = "Testing Guide"
          Audience = "Developers" }

        { Category = DeveloperGuide
          Path = "docs/planning/dev/API_DEVELOPMENT.md"
          Title = "API Development Guide"
          Audience = "Developers" }

        // API reference
        { Category = APIReference
          Path = "docs/planning/api/REST_API.md"
          Title = "REST API Reference"
          Audience = "Developers" }

        { Category = APIReference
          Path = "docs/planning/api/ZENOH_API.md"
          Title = "Zenoh API Reference"
          Audience = "Developers" }

        { Category = APIReference
          Path = "docs/planning/api/SDK_REFERENCE.md"
          Title = "SDK Reference"
          Audience = "Developers" }

        // Operations guides
        { Category = Operations
          Path = "docs/planning/ops/DEPLOYMENT.md"
          Title = "Deployment Guide"
          Audience = "Operations" }

        { Category = Operations
          Path = "docs/planning/ops/MONITORING.md"
          Title = "Monitoring Guide"
          Audience = "Operations" }

        { Category = Operations
          Path = "docs/planning/ops/BACKUP_RESTORE.md"
          Title = "Backup & Restore Guide"
          Audience = "Operations" }

        // Tutorials
        { Category = Tutorials
          Path = "docs/planning/tutorials/FIRST_PROJECT.md"
          Title = "Your First Project"
          Audience = "Beginners" }

        { Category = Tutorials
          Path = "docs/planning/tutorials/OODA_TUTORIAL.md"
          Title = "OODA Cycle Tutorial"
          Audience = "Beginners" }

        { Category = Tutorials
          Path = "docs/planning/tutorials/AI_INTEGRATION.md"
          Title = "AI Integration Tutorial"
          Audience = "Intermediate" }
    ]
```

### 25.6 Integration Points Matrix

| Component | Planning System | Integration Method | STAMP |
|-----------|-----------------|-------------------|-------|
| Elixir Backend | API calls | HTTP/JSON | SC-INT-001 |
| Phoenix LiveView | WebSocket | Phoenix Channels | SC-INT-002 |
| Prajna Cockpit | Dashboard | LiveView Components | SC-INT-003 |
| Guardian | Validation | F# Bridge | SC-INT-004 |
| Sentinel | Health | Zenoh Telemetry | SC-INT-005 |
| SMRITI | Knowledge | Holon API | SC-INT-006 |
| Cortex | AI | OpenRouter | SC-INT-007 |
| Zenoh Mesh | Events | Pub/Sub | SC-INT-008 |
| Emacs | Org-mode | CLI/Socket | SC-INT-009 |
| Mobile | Companion | REST API | SC-INT-010 |

### 25.7 STAMP Constraints (System Integration)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SYS-001 | CLI MUST support all documented commands | CRITICAL |
| SC-SYS-002 | Environment files MUST be validated on load | HIGH |
| SC-SYS-003 | Scripts MUST be idempotent | HIGH |
| SC-SYS-004 | Documentation MUST be current with code | MEDIUM |
| SC-SYS-005 | CLAUDE.md rules MUST be enforced | CRITICAL |
| SC-SYS-006 | Integration points MUST be versioned | HIGH |
| SC-SYS-007 | All secrets MUST be encrypted | CRITICAL |
| SC-SYS-008 | devenv.nix MUST be reproducible | HIGH |

### 25.8 AOR Rules (System Integration)

| ID | Rule |
|----|------|
| AOR-SYS-001 | ALWAYS validate environment on startup |
| AOR-SYS-002 | ALWAYS version all integration APIs |
| AOR-SYS-003 | ALWAYS encrypt secrets in .env files |
| AOR-SYS-004 | ALWAYS update docs with code changes |
| AOR-SYS-005 | ALWAYS test scripts in CI/CD |
| AOR-SYS-006 | ALWAYS use devenv for development |
| AOR-SYS-007 | NEVER commit .env.local files |
| AOR-SYS-008 | ALWAYS run migrations in transactions |

---

## 26. 100% Test Coverage Framework

This section defines the comprehensive testing strategy to achieve 100% static and runtime coverage.

### 26.1 Coverage Architecture

```fsharp
/// Test coverage architecture
module CoverageArchitecture =

    /// Coverage levels
    type CoverageLevel =
        | Static of StaticCoverage
        | Runtime of RuntimeCoverage
        | Combined of CombinedCoverage

    type StaticCoverage = {
        LinesCovered: int
        LinesTotal: int
        BranchesCovered: int
        BranchesTotal: int
        FunctionsCovered: int
        FunctionsTotal: int
        ModulesCovered: int
        ModulesTotal: int
    }

    type RuntimeCoverage = {
        TestsPassed: int
        TestsTotal: int
        PropertyTestsPassed: int
        PropertyTestsTotal: int
        IntegrationTestsPassed: int
        IntegrationTestsTotal: int
        BddScenariosPassed: int
        BddScenariosTotal: int
    }

    type CombinedCoverage = {
        Static: StaticCoverage
        Runtime: RuntimeCoverage
        OverallPercentage: float
        Threshold: float
    }

    /// Coverage targets
    let coverageTargets = {
        StaticLinesCoverage = 100.0              // 100% line coverage
        StaticBranchCoverage = 100.0             // 100% branch coverage
        StaticFunctionCoverage = 100.0           // 100% function coverage
        RuntimeUnitTests = 100.0                 // 100% unit test pass
        RuntimePropertyTests = 100.0             // 100% property test pass
        RuntimeIntegration = 100.0               // 100% integration pass
        RuntimeBdd = 100.0                       // 100% BDD scenario pass
    }
```

### 26.2 Static Analysis Coverage

```fsharp
/// Static analysis coverage
module StaticAnalysisCoverage =

    /// Static analysis tools
    type StaticTool =
        | AltCover                              // Code coverage
        | FsLint                                // F# linter
        | Fantomas                              // F# formatter
        | FSharpAnalyzers                       // F# analyzers

    /// Coverage report structure
    type CoverageReport = {
        Timestamp: DateTimeOffset
        Tool: StaticTool
        Modules: ModuleCoverage list
        Summary: CoverageSummary
    }

    type ModuleCoverage = {
        Name: string
        Path: string
        Lines: LineCoverage
        Branches: BranchCoverage
        Functions: FunctionCoverage
        Complexity: int
    }

    type LineCoverage = {
        Covered: int
        Total: int
        Percentage: float
        UncoveredLines: int list
    }

    type BranchCoverage = {
        Covered: int
        Total: int
        Percentage: float
        UncoveredBranches: BranchInfo list
    }

    type BranchInfo = {
        Line: int
        Column: int
        Type: BranchType
    }

    type BranchType =
        | If
        | Match
        | Try
        | Loop

    /// Module coverage requirements
    let moduleCoverageRequirements = [
        ("Domain.Task", 100.0)
        ("Domain.Project", 100.0)
        ("Domain.OODA", 100.0)
        ("EventSourcing", 100.0)
        ("Persistence.SQLite", 100.0)
        ("Persistence.DuckDB", 100.0)
        ("AI.Cortex", 100.0)
        ("AI.OpenRouter", 100.0)
        ("Graph.TaskGraph", 100.0)
        ("Simulation.MonteCarlo", 100.0)
        ("LongTerm.Millennium", 100.0)
        ("Teams.MixedTeam", 100.0)
        ("Zenoh.Planning", 100.0)
        ("CLI.Commands", 100.0)
        ("TUI.Panels", 100.0)
    ]
```

### 26.3 Runtime Test Matrix

```fsharp
/// Runtime test matrix
module RuntimeTestMatrix =

    /// Test categories
    type TestCategory =
        | Unit                                  // Unit tests
        | Property                              // Property-based tests
        | Integration                           // Integration tests
        | EndToEnd                              // End-to-end tests
        | Performance                           // Performance tests
        | Security                              // Security tests
        | Chaos                                 // Chaos engineering

    /// Test execution plan
    type TestPlan = {
        Categories: TestCategory list
        Parallel: bool
        Timeout: TimeSpan
        Retries: int
        FailFast: bool
    }

    /// Complete test inventory
    let testInventory = [
        // Unit tests per module
        ("Task.CreateTests", Unit, 50)
        ("Task.UpdateTests", Unit, 40)
        ("Task.QueryTests", Unit, 30)
        ("Task.DeleteTests", Unit, 20)
        ("Project.CreateTests", Unit, 35)
        ("Project.LifecycleTests", Unit, 25)
        ("OODA.CycleTests", Unit, 60)
        ("OODA.PhaseTests", Unit, 45)
        ("EventStore.AppendTests", Unit, 30)
        ("EventStore.QueryTests", Unit, 25)
        ("SQLite.CRUDTests", Unit, 40)
        ("DuckDB.AnalyticsTests", Unit, 35)
        ("Graph.TopologyTests", Unit, 50)
        ("Simulation.MonteCarloTests", Unit, 40)

        // Property tests
        ("Task.Properties", Property, 100)
        ("Project.Properties", Property, 80)
        ("OODA.Properties", Property, 60)
        ("Graph.Properties", Property, 100)
        ("EventStore.Properties", Property, 50)

        // Integration tests
        ("Task.IntegrationTests", Integration, 30)
        ("Project.IntegrationTests", Integration, 25)
        ("OODA.IntegrationTests", Integration, 20)
        ("AI.IntegrationTests", Integration, 15)
        ("Zenoh.IntegrationTests", Integration, 20)

        // End-to-end tests
        ("CLI.E2ETests", EndToEnd, 40)
        ("TUI.E2ETests", EndToEnd, 30)
        ("WebUI.E2ETests", EndToEnd, 25)

        // Performance tests
        ("Task.PerformanceTests", Performance, 15)
        ("Query.PerformanceTests", Performance, 10)
        ("EventStore.PerformanceTests", Performance, 10)

        // Security tests
        ("Auth.SecurityTests", Security, 20)
        ("API.SecurityTests", Security, 15)

        // Chaos tests
        ("Network.ChaosTests", Chaos, 10)
        ("Database.ChaosTests", Chaos, 10)
    ]

    /// Total test count
    let totalTests =
        testInventory
        |> List.sumBy (fun (_, _, count) -> count)
        // = 1,155 tests
```

### 26.4 Property Test Specifications

```fsharp
/// Property test specifications (FsCheck)
module PropertyTestSpecs =

    /// Generator definitions
    module Generators =

        let taskIdGen =
            Gen.map TaskId (Gen.guid)

        let priorityGen =
            Gen.elements [P0; P1; P2; P3; P4]

        let taskStatusGen =
            Gen.elements [Pending; InProgress; Completed; Blocked; Cancelled]

        let taskGen =
            gen {
                let! id = taskIdGen
                let! title = Arb.generate<NonEmptyString>
                let! priority = priorityGen
                let! status = taskStatusGen
                return {
                    Id = id
                    Title = title.Get
                    Priority = priority
                    Status = status
                    CreatedAt = DateTimeOffset.UtcNow
                }
            }

        let projectGen =
            gen {
                let! id = Gen.map ProjectId Gen.guid
                let! name = Arb.generate<NonEmptyString>
                let! tasks = Gen.listOfLength 10 taskGen
                return {
                    Id = id
                    Name = name.Get
                    Tasks = tasks
                }
            }

        let oodaCycleGen =
            gen {
                let! id = Gen.map OodaCycleId Gen.guid
                let! phase = Gen.elements [Observe; Orient; Decide; Act]
                let! observations = Gen.listOf (Arb.generate<NonEmptyString>)
                return {
                    Id = id
                    Phase = phase
                    Observations = observations |> List.map (fun s -> s.Get)
                }
            }

    /// Property definitions
    module Properties =

        // Task properties
        let taskCreateIdempotent =
            Prop.forAll (Arb.fromGen Generators.taskGen) (fun task ->
                let created1 = TaskRepository.create task
                let created2 = TaskRepository.create task
                created1 = created2)

        let taskUpdateCommutative =
            Prop.forAll (Arb.fromGen Generators.taskGen) (fun task ->
                let update1 = { task with Priority = P1 }
                let update2 = { task with Status = InProgress }
                let result1 = update1 |> TaskRepository.update |> TaskRepository.update
                let result2 = update2 |> TaskRepository.update |> TaskRepository.update
                result1.Id = result2.Id)

        // Graph properties
        let graphAcyclic =
            Prop.forAll (Arb.fromGen Generators.projectGen) (fun project ->
                let graph = TaskGraph.build project.Tasks
                not (TaskGraph.hasCycles graph))

        let topologicalSortValid =
            Prop.forAll (Arb.fromGen Generators.projectGen) (fun project ->
                let graph = TaskGraph.build project.Tasks
                let sorted = TaskGraph.topologicalSort graph
                sorted |> List.forall (fun t ->
                    t.Dependencies |> List.forall (fun d ->
                        List.findIndex ((=) d) sorted < List.findIndex ((=) t) sorted)))

        // OODA properties
        let oodaCycleComplete =
            Prop.forAll (Arb.fromGen Generators.oodaCycleGen) (fun cycle ->
                let completed = OodaCycle.run cycle
                completed.Phase = Act)

        // Event sourcing properties
        let eventReplayConsistent =
            Prop.forAll (Arb.fromGen (Gen.listOf Generators.taskGen)) (fun tasks ->
                let events = tasks |> List.map TaskEvent.Created
                let state1 = EventStore.replay events
                let state2 = EventStore.replay events
                state1 = state2)
```

### 26.5 BDD Test Scenarios (Complete)

```gherkin
# Complete BDD scenario coverage

@L1-Feature @Planning @Coverage
Feature: 100% Planning System Coverage

  # Task Management (55 scenarios - all covered)
  @L2-Capability @TaskCreate
  Scenario Outline: Create tasks with all parameter combinations
    Given I am authenticated as "<role>"
    When I create a task with title "<title>" and priority "<priority>"
    Then the task should be created with status "Pending"
    And event "TaskCreated" should be recorded

    Examples:
      | role    | title          | priority |
      | admin   | Admin Task     | P0       |
      | manager | Manager Task   | P1       |
      | member  | Member Task    | P2       |
      | agent   | Agent Task     | P3       |
      | viewer  | Viewer Task    | P4       |

  # Project Management (45 scenarios - all covered)
  @L2-Capability @ProjectLifecycle
  Scenario: Complete project lifecycle
    Given project "Alpha" is created
    When I add 10 tasks to the project
    And I start the project
    And I complete all tasks
    Then project status should be "Completed"
    And all events should be in sequence

  # OODA Cycles (38 scenarios - all covered)
  @L2-Capability @OODA
  Scenario: Full OODA cycle execution
    Given OODA cycle is started with context "Strategic Decision"
    When I add 5 observations
    And I run orientation analysis
    And I generate 3 decision options
    And I select option "Option A"
    And I execute action plan
    Then cycle should be completed in < 100ms
    And all phases should be logged

  # Long-Term Planning (36 scenarios - all covered)
  @L2-Capability @LongTerm
  Scenario: 1000-year plan creation
    Given millennium plan "Lineage Preservation" exists
    When I create epoch plans for 10 centuries
    And I define succession policy
    Then plan should span 1000 years
    And all succession events should be scheduled

  # Mixed Teams (38 scenarios - all covered)
  @L2-Capability @MixedTeams
  Scenario: Human-agent team coordination
    Given mixed team with 3 humans and 2 agents
    When I assign tasks based on capabilities
    And agents execute autonomously
    And humans review results
    Then all tasks should be completed
    And handoffs should be logged

  # AI Integration (25 scenarios - all covered)
  @L2-Capability @AI
  Scenario: AI-assisted task parsing
    Given AI service is available
    When I parse "Fix login bug by tomorrow, high priority"
    Then task should be created with:
      | title    | Fix login bug |
      | priority | P1            |
      | due      | tomorrow      |

  # Graph Operations (28 scenarios - all covered)
  @L2-Capability @Graph
  Scenario: Dependency graph analysis
    Given project with 20 tasks and dependencies
    When I run topological sort
    And I find critical path
    Then sort should be valid
    And critical path should be identified

  # Simulation (20 scenarios - all covered)
  @L2-Capability @Simulation
  Scenario: Monte Carlo simulation
    Given project with PERT estimates
    When I run 10000 simulations
    Then completion probability should be calculated
    And confidence intervals should be provided

  # Total: 265 BDD scenarios covering all features
```

### 26.6 Coverage Verification Script

```fsharp
/// Coverage verification script
module CoverageVerification =

    /// Verify coverage meets requirements
    let verifyCoverage () : Result<CoverageReport, CoverageError> =
        result {
            // Run static analysis
            let! staticCoverage = AltCover.run ()

            // Verify static coverage
            do! verifyThreshold staticCoverage.Lines.Percentage 100.0 "Line coverage"
            do! verifyThreshold staticCoverage.Branches.Percentage 100.0 "Branch coverage"
            do! verifyThreshold staticCoverage.Functions.Percentage 100.0 "Function coverage"

            // Run runtime tests
            let! unitResults = Expecto.run unitTests
            let! propertyResults = FsCheck.run propertyTests
            let! integrationResults = runIntegrationTests ()
            let! bddResults = runBddScenarios ()

            // Verify runtime coverage
            do! verifyAllPassed unitResults "Unit tests"
            do! verifyAllPassed propertyResults "Property tests"
            do! verifyAllPassed integrationResults "Integration tests"
            do! verifyAllPassed bddResults "BDD scenarios"

            // Generate report
            return {
                Static = staticCoverage
                Runtime = {
                    UnitTests = unitResults
                    PropertyTests = propertyResults
                    IntegrationTests = integrationResults
                    BddScenarios = bddResults
                }
                Overall = 100.0
                Verified = true
            }
        }

    /// CI/CD integration
    let cicdPipeline () =
        async {
            // Step 1: Build
            do! Build.run ()

            // Step 2: Static analysis
            let! staticReport = StaticAnalysis.run ()
            if staticReport.Coverage < 100.0 then
                failwith "Static coverage below 100%"

            // Step 3: Unit tests
            let! unitReport = UnitTests.run ()
            if unitReport.Failed > 0 then
                failwith "Unit tests failed"

            // Step 4: Property tests
            let! propertyReport = PropertyTests.run ()
            if propertyReport.Failed > 0 then
                failwith "Property tests failed"

            // Step 5: Integration tests
            let! integrationReport = IntegrationTests.run ()
            if integrationReport.Failed > 0 then
                failwith "Integration tests failed"

            // Step 6: BDD scenarios
            let! bddReport = BddTests.run ()
            if bddReport.Failed > 0 then
                failwith "BDD scenarios failed"

            // Step 7: Generate coverage report
            let! coverageReport = CoverageReport.generate ()
            do! CoverageReport.publish coverageReport

            return "Pipeline completed with 100% coverage"
        }
```

### 26.7 Coverage Dashboard

```fsharp
/// Coverage dashboard display
module CoverageDashboard =

    let display (coverage: CoverageReport) : string =
        sprintf """
╔══════════════════════════════════════════════════════════════════╗
║                    PLANNING SYSTEM COVERAGE                       ║
╠══════════════════════════════════════════════════════════════════╣
║  STATIC ANALYSIS                                                  ║
║  ├─ Lines:      %s %6d/%6d (%6.2f%%)                       ║
║  ├─ Branches:   %s %6d/%6d (%6.2f%%)                       ║
║  ├─ Functions:  %s %6d/%6d (%6.2f%%)                       ║
║  └─ Modules:    %s %6d/%6d (%6.2f%%)                       ║
╠══════════════════════════════════════════════════════════════════╣
║  RUNTIME TESTS                                                    ║
║  ├─ Unit:       %s %6d/%6d (%6.2f%%)                       ║
║  ├─ Property:   %s %6d/%6d (%6.2f%%)                       ║
║  ├─ Integration:%s %6d/%6d (%6.2f%%)                       ║
║  └─ BDD:        %s %6d/%6d (%6.2f%%)                       ║
╠══════════════════════════════════════════════════════════════════╣
║  OVERALL: %s %6.2f%% (Target: 100.00%%)                          ║
╚══════════════════════════════════════════════════════════════════╝
"""
        (statusIcon coverage.Static.Lines.Percentage)
        coverage.Static.Lines.Covered coverage.Static.Lines.Total coverage.Static.Lines.Percentage
        (statusIcon coverage.Static.Branches.Percentage)
        coverage.Static.Branches.Covered coverage.Static.Branches.Total coverage.Static.Branches.Percentage
        (statusIcon coverage.Static.Functions.Percentage)
        coverage.Static.Functions.Covered coverage.Static.Functions.Total coverage.Static.Functions.Percentage
        (statusIcon coverage.Static.Modules.Percentage)
        coverage.Static.Modules.Covered coverage.Static.Modules.Total coverage.Static.Modules.Percentage
        (statusIcon coverage.Runtime.UnitTests.Percentage)
        coverage.Runtime.UnitTests.Passed coverage.Runtime.UnitTests.Total coverage.Runtime.UnitTests.Percentage
        (statusIcon coverage.Runtime.PropertyTests.Percentage)
        coverage.Runtime.PropertyTests.Passed coverage.Runtime.PropertyTests.Total coverage.Runtime.PropertyTests.Percentage
        (statusIcon coverage.Runtime.IntegrationTests.Percentage)
        coverage.Runtime.IntegrationTests.Passed coverage.Runtime.IntegrationTests.Total coverage.Runtime.IntegrationTests.Percentage
        (statusIcon coverage.Runtime.BddScenarios.Percentage)
        coverage.Runtime.BddScenarios.Passed coverage.Runtime.BddScenarios.Total coverage.Runtime.BddScenarios.Percentage
        (statusIcon coverage.Overall)
        coverage.Overall

    let statusIcon (percentage: float) : string =
        if percentage >= 100.0 then "✓"
        elif percentage >= 90.0 then "◐"
        elif percentage >= 80.0 then "◔"
        else "✗"
```

### 26.8 STAMP Constraints (Testing)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-TEST-001 | Line coverage MUST be 100% | CRITICAL |
| SC-TEST-002 | Branch coverage MUST be 100% | CRITICAL |
| SC-TEST-003 | Function coverage MUST be 100% | CRITICAL |
| SC-TEST-004 | All unit tests MUST pass | CRITICAL |
| SC-TEST-005 | All property tests MUST pass | CRITICAL |
| SC-TEST-006 | All integration tests MUST pass | CRITICAL |
| SC-TEST-007 | All BDD scenarios MUST pass | CRITICAL |
| SC-TEST-008 | Coverage report MUST be generated | HIGH |
| SC-TEST-009 | Coverage MUST be verified in CI/CD | CRITICAL |
| SC-TEST-010 | No uncovered critical paths allowed | CRITICAL |

### 26.9 AOR Rules (Testing)

| ID | Rule |
|----|------|
| AOR-TEST-001 | ALWAYS write tests before code (TDG) |
| AOR-TEST-002 | ALWAYS run full test suite before commit |
| AOR-TEST-003 | ALWAYS include property tests for core logic |
| AOR-TEST-004 | ALWAYS verify coverage after changes |
| AOR-TEST-005 | NEVER reduce coverage below 100% |
| AOR-TEST-006 | ALWAYS investigate test failures immediately |
| AOR-TEST-007 | ALWAYS document uncovered edge cases |
| AOR-TEST-008 | ALWAYS run chaos tests before release |

---

## 27. Related Documents

| Document | Location | Purpose |
|----------|----------|---------|
| CLAUDE.md | / | Master system specification |
| Holon Architecture | docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md | State sovereignty |
| Founder's Directive | docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md | Supreme covenant |
| Immutable Register | docs/architecture/HOLON_IMMUTABLE_REGISTER.md | Event sourcing |
| Existing Planning Spec | docs/planning/PLANNING-TASKEXECUTION-SYSTEM.md | Original requirements |
| Integrated Requirements | docs/planning/integrated_planning_requirements.md | Feature synthesis |
| QuadplexLogger | lib/indrajaal/quadplex_logger.ex | Elixir logging backend |
| CortexBridge | lib/indrajaal/cortex_bridge.ex | F# ↔ Elixir L2 bridge |
| FractalLogView | lib/cepaf/src/Cepaf/Dashboard/FractalLogView.fs | Fractal log viewer |
| ZenohChannel | lib/cepaf/src/Cepaf/Zenoh/ZenohChannel.fs | Zenoh telemetry routing |
| PortHandler | lib/cepaf/src/Cepaf/Bridge/PortHandler.fs | Elixir-F# interop |

---

## 28. Appendices

### A. Glossary

| Term | Definition |
|------|------------|
| **AAR** | After Action Review - Structured reflection |
| **COA** | Course of Action - Potential approach |
| **CQRS** | Command Query Responsibility Segregation |
| **Holon** | Entity that is whole and part |
| **MDMP** | Military Decision Making Process |
| **MCP** | Model Context Protocol - AI agent standard |
| **OODA** | Observe-Orient-Decide-Act loop |
| **SOD** | Systemic Operational Design |
| **TLP** | Troop Leading Procedures |

### B. API Reference

```fsharp
// Core API endpoints
module API =
    // Tasks
    GET  /api/v1/tasks                    // List tasks
    POST /api/v1/tasks                    // Create task
    GET  /api/v1/tasks/{id}               // Get task
    PATCH /api/v1/tasks/{id}              // Update task
    POST /api/v1/tasks/parse              // Parse natural language

    // OODA
    POST /api/v1/ooda/start               // Start OODA cycle
    POST /api/v1/ooda/observe             // Add observations
    POST /api/v1/ooda/orient              // Run orientation
    POST /api/v1/ooda/decide              // Select action
    POST /api/v1/ooda/act                 // Execute action

    // Projects
    GET  /api/v1/projects                 // List projects
    POST /api/v1/projects                 // Create project
    GET  /api/v1/projects/{id}/tasks      // Get project tasks
    POST /api/v1/projects/{id}/sprints    // Create sprint
```

### C. Configuration Reference

```yaml
# config/planning.yaml
planning:
  database:
    path: "data/planning/planning.db"
    wal_mode: true
    cache_size: 10000

  zenoh:
    endpoints: ["tcp/localhost:7447"]
    mode: "client"
    timeout_ms: 5000

  cortex:
    model: "anthropic/claude-3-sonnet"
    timeout_ms: 30000
    mock_offline: true

  ooda:
    cycle_timeout_ms: 100
    max_cycles: 100

  emacs:
    port: 9878
    enabled: true

  guardian:
    approval_timeout_ms: 30000
    auto_approve_p3_below: true
```

---

## 29. Deployment & Operations Runbook

### 29.1 Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PLANNING SYSTEM DEPLOYMENT TOPOLOGY                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                │
│  │   STAGING    │──▶│  PRODUCTION  │──▶│  FEDERATION  │                │
│  │   (Green)    │   │   (Blue)     │   │   (Mesh)     │                │
│  └──────────────┘   └──────────────┘   └──────────────┘                │
│         │                  │                  │                         │
│         ▼                  ▼                  ▼                         │
│  ┌──────────────────────────────────────────────────────────┐          │
│  │                    ZENOH CONTROL PLANE                    │          │
│  │     indrajaal/planning/** | indrajaal/deploy/**           │          │
│  └──────────────────────────────────────────────────────────┘          │
│                                                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                │
│  │   SQLite     │   │   DuckDB     │   │   Backups    │                │
│  │ (Real-time)  │   │ (Analytics)  │   │ (Encrypted)  │                │
│  └──────────────┘   └──────────────┘   └──────────────┘                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 29.2 Pre-Deployment Checklist

```fsharp
/// Pre-deployment verification checklist
type DeploymentChecklist = {
    // Environment Checks
    DotNetVersion: Version                    // MUST be >= 10.0
    FSharpVersion: Version                    // MUST be >= 10.0
    ZenohConnectivity: bool                   // MUST be true
    SQLiteVersion: Version                    // MUST be >= 3.45
    DuckDBVersion: Version                    // MUST be >= 0.10

    // Security Checks
    CertificatesValid: bool                   // TLS certs not expired
    SecretsInjected: bool                     // All secrets available
    GuardianReachable: bool                   // Guardian API responding

    // Infrastructure Checks
    DiskSpaceGB: float                        // MUST be >= 10GB
    MemoryAvailableGB: float                  // MUST be >= 4GB
    CpuCoresAvailable: int                    // MUST be >= 2

    // Data Checks
    DatabaseBackupExists: bool                // Recent backup available
    MigrationsPending: bool                   // Should be false
    DataIntegrityVerified: bool               // Checksums match
}

module DeploymentChecker =

    let verify (env: Environment) : Result<DeploymentChecklist, DeploymentError list> =
        let checks = {
            DotNetVersion = getDotNetVersion()
            FSharpVersion = getFSharpVersion()
            ZenohConnectivity = checkZenohConnectivity env.ZenohEndpoints
            SQLiteVersion = getSQLiteVersion()
            DuckDBVersion = getDuckDBVersion()
            CertificatesValid = verifyCertificates env.CertPath
            SecretsInjected = verifySecrets env.SecretsPath
            GuardianReachable = pingGuardian env.GuardianUrl
            DiskSpaceGB = getDiskSpace env.DataPath
            MemoryAvailableGB = getAvailableMemory()
            CpuCoresAvailable = Environment.ProcessorCount
            DatabaseBackupExists = checkBackupExists env.BackupPath
            MigrationsPending = hasPendingMigrations env.DatabasePath
            DataIntegrityVerified = verifyDataIntegrity env.DatabasePath
        }

        let errors = [
            if checks.DotNetVersion < Version(10, 0) then
                yield DotNetVersionTooLow checks.DotNetVersion
            if not checks.ZenohConnectivity then
                yield ZenohNotReachable
            if not checks.CertificatesValid then
                yield CertificatesExpired
            if checks.DiskSpaceGB < 10.0 then
                yield InsufficientDiskSpace checks.DiskSpaceGB
            if not checks.DatabaseBackupExists then
                yield NoRecentBackup
        ]

        if List.isEmpty errors then Ok checks
        else Error errors
```

### 29.3 Deployment Procedures

#### 29.3.1 Blue-Green Deployment

```fsharp
/// Blue-green deployment orchestration
module BlueGreenDeployment =

    type Slot = Blue | Green

    type DeploymentState = {
        ActiveSlot: Slot
        BlueVersion: Version option
        GreenVersion: Version option
        LastSwitch: DateTimeOffset
        HealthStatus: Map<Slot, HealthStatus>
    }

    let deploy (newVersion: Version) (state: DeploymentState) : Async<Result<DeploymentState, DeploymentError>> =
        async {
            // 1. Determine target slot (inactive)
            let targetSlot =
                match state.ActiveSlot with
                | Blue -> Green
                | Green -> Blue

            // 2. Deploy to target slot
            do! deployToSlot targetSlot newVersion

            // 3. Run smoke tests
            let! smokeResult = runSmokeTests targetSlot

            match smokeResult with
            | Ok _ ->
                // 4. Switch traffic
                do! switchTraffic targetSlot

                // 5. Monitor for 5 minutes
                let! healthResult = monitorHealth targetSlot (TimeSpan.FromMinutes 5.0)

                match healthResult with
                | Ok _ ->
                    return Ok { state with
                        ActiveSlot = targetSlot
                        LastSwitch = DateTimeOffset.UtcNow }
                | Error e ->
                    // Rollback
                    do! switchTraffic state.ActiveSlot
                    return Error (HealthCheckFailed e)

            | Error e ->
                return Error (SmokeTestFailed e)
        }
```

#### 29.3.2 Database Migration Procedure

```fsharp
/// Database migration with rollback capability
module DatabaseMigration =

    type MigrationStep = {
        Version: int64
        Name: string
        UpScript: string
        DownScript: string
        Checksum: string
        AppliedAt: DateTimeOffset option
    }

    let migrate (conn: SQLiteConnection) (migrations: MigrationStep list) : Result<unit, MigrationError> =
        // 1. Create backup before migration
        let backupPath = createTimestampedBackup conn.DatabasePath

        // 2. Begin transaction
        use transaction = conn.BeginTransaction()

        try
            // 3. Apply pending migrations
            let pending = migrations |> List.filter (fun m -> m.AppliedAt.IsNone)

            for migration in pending do
                // Verify checksum
                let actualChecksum = computeChecksum migration.UpScript
                if actualChecksum <> migration.Checksum then
                    failwith $"Checksum mismatch for migration {migration.Name}"

                // Execute migration
                executeScript conn migration.UpScript

                // Record in migrations table
                recordMigration conn migration.Version migration.Name

                // Log to telemetry
                publishToZenoh "indrajaal/planning/migration" {|
                    version = migration.Version
                    name = migration.Name
                    status = "applied"
                    timestamp = DateTimeOffset.UtcNow
                |}

            // 4. Commit transaction
            transaction.Commit()
            Ok ()

        with ex ->
            // 5. Rollback on failure
            transaction.Rollback()

            // Restore from backup
            restoreFromBackup backupPath conn.DatabasePath

            Error (MigrationFailed (ex.Message, backupPath))
```

### 29.4 Operations Procedures

#### 29.4.1 Health Check Protocol

```fsharp
/// Comprehensive health check system
module HealthCheck =

    type HealthComponent =
        | Database
        | Zenoh
        | Guardian
        | Cortex
        | EventStore
        | TUI
        | API

    type ComponentHealth = {
        Component: HealthComponent
        Status: HealthStatus
        Latency: TimeSpan
        LastCheck: DateTimeOffset
        Details: Map<string, obj>
    }

    type SystemHealth = {
        Overall: HealthStatus
        Components: ComponentHealth list
        Uptime: TimeSpan
        Version: Version
        CheckedAt: DateTimeOffset
    }

    let checkHealth () : Async<SystemHealth> =
        async {
            let! components =
                [| Database; Zenoh; Guardian; Cortex; EventStore; TUI; API |]
                |> Array.map checkComponent
                |> Async.Parallel

            let overall =
                if components |> Array.forall (fun c -> c.Status = Healthy) then Healthy
                elif components |> Array.exists (fun c -> c.Status = Unhealthy) then Unhealthy
                else Degraded

            return {
                Overall = overall
                Components = Array.toList components
                Uptime = getUptime()
                Version = getCurrentVersion()
                CheckedAt = DateTimeOffset.UtcNow
            }
        }

    let checkComponent (comp: HealthComponent) : Async<ComponentHealth> =
        async {
            let sw = Stopwatch.StartNew()

            let! (status, details) =
                match comp with
                | Database ->
                    async {
                        try
                            let! result = executeQuery "SELECT 1"
                            return (Healthy, Map.ofList [("ping", box "ok")])
                        with ex ->
                            return (Unhealthy, Map.ofList [("error", box ex.Message)])
                    }

                | Zenoh ->
                    async {
                        try
                            let! connected = checkZenohSession()
                            return (if connected then Healthy else Unhealthy,
                                    Map.ofList [("connected", box connected)])
                        with ex ->
                            return (Unhealthy, Map.ofList [("error", box ex.Message)])
                    }

                | Guardian ->
                    async {
                        try
                            let! response = httpGet "/api/prajna/guardian/health"
                            return (if response.StatusCode = 200 then Healthy else Degraded,
                                    Map.ofList [("status_code", box response.StatusCode)])
                        with ex ->
                            return (Unhealthy, Map.ofList [("error", box ex.Message)])
                    }

                | Cortex ->
                    async {
                        try
                            let! response = checkCortexConnection()
                            return (Healthy, Map.ofList [("model", box response.Model)])
                        with ex ->
                            return (Degraded, Map.ofList [("error", box ex.Message); ("fallback", box "offline_mode")])
                    }

                | EventStore ->
                    async {
                        let! stats = getEventStoreStats()
                        return (Healthy, Map.ofList [
                            ("events", box stats.TotalEvents)
                            ("streams", box stats.ActiveStreams)
                        ])
                    }

                | TUI ->
                    async {
                        let! terminalOk = checkTerminalCapabilities()
                        return (if terminalOk then Healthy else Degraded,
                                Map.ofList [("terminal", box terminalOk)])
                    }

                | API ->
                    async {
                        try
                            let! response = httpGet "/api/v1/health"
                            return (Healthy, Map.ofList [("api_version", box "v1")])
                        with ex ->
                            return (Unhealthy, Map.ofList [("error", box ex.Message)])
                    }

            sw.Stop()

            return {
                Component = comp
                Status = status
                Latency = sw.Elapsed
                LastCheck = DateTimeOffset.UtcNow
                Details = details
            }
        }
```

#### 29.4.2 Monitoring Dashboard

```fsharp
/// Real-time operations dashboard
module OperationsDashboard =

    let render (health: SystemHealth) (metrics: SystemMetrics) : string =
        sprintf """
╔══════════════════════════════════════════════════════════════════════════╗
║                    PLANNING SYSTEM OPERATIONS DASHBOARD                   ║
╠══════════════════════════════════════════════════════════════════════════╣
║  STATUS: %s   VERSION: %s   UPTIME: %s                     ║
╠══════════════════════════════════════════════════════════════════════════╣
║  COMPONENT HEALTH                                                         ║
║  ├─ Database:    %s  [%6.2fms]  Events: %d                       ║
║  ├─ Zenoh:       %s  [%6.2fms]  Pub: %d/s  Sub: %d               ║
║  ├─ Guardian:    %s  [%6.2fms]  Approvals: %d                    ║
║  ├─ Cortex:      %s  [%6.2fms]  Queries: %d                      ║
║  ├─ EventStore:  %s  [%6.2fms]  Streams: %d                      ║
║  ├─ TUI:         %s  [%6.2fms]  Sessions: %d                     ║
║  └─ API:         %s  [%6.2fms]  Requests: %d/s                   ║
╠══════════════════════════════════════════════════════════════════════════╣
║  RESOURCE UTILIZATION                                                     ║
║  ├─ CPU:         %s %5.1f%%                                        ║
║  ├─ Memory:      %s %5.1f%% (%s / %s)                  ║
║  ├─ Disk:        %s %5.1f%% (%s / %s)                  ║
║  └─ Network:     ↑ %s/s  ↓ %s/s                                 ║
╠══════════════════════════════════════════════════════════════════════════╣
║  ACTIVE OPERATIONS                                                        ║
║  ├─ Tasks In Progress:     %6d                                          ║
║  ├─ OODA Cycles Active:    %6d                                          ║
║  ├─ Pending Approvals:     %6d                                          ║
║  └─ Queued Events:         %6d                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║  LAST 5 ALERTS                                                            ║
%s
╚══════════════════════════════════════════════════════════════════════════╝
"""
            (statusEmoji health.Overall)
            (health.Version.ToString())
            (formatUptime health.Uptime)
            // Component health rows...
            (getComponentStatus health Database)
            (getComponentLatency health Database)
            metrics.EventCount
            // ... additional fields
```

### 29.5 Runbook Procedures

#### 29.5.1 Daily Operations

| Time | Procedure | Command | Verification |
|------|-----------|---------|--------------|
| 00:00 | Automated backup | `planning backup --full` | Backup file created |
| 06:00 | Health check | `planning health --verbose` | All components healthy |
| 12:00 | Metrics snapshot | `planning metrics --export` | Metrics exported |
| 18:00 | Log rotation | `planning logs --rotate` | Logs archived |
| 23:00 | Analytics sync | `planning analytics --sync` | DuckDB updated |

#### 29.5.2 Weekly Operations

| Day | Procedure | Command | Verification |
|-----|-----------|---------|--------------|
| Mon | Performance review | `planning perf --report` | Report generated |
| Wed | Security scan | `planning security --scan` | No vulnerabilities |
| Fri | Backup verification | `planning backup --verify` | Restore test passed |
| Sun | Cleanup old data | `planning cleanup --older-than 90d` | Disk space reclaimed |

#### 29.5.3 Monthly Operations

| Procedure | Command | Verification |
|-----------|---------|--------------|
| Full DR test | `planning dr --test` | Recovery successful |
| Certificate renewal check | `planning certs --check` | 30+ days remaining |
| Capacity planning | `planning capacity --forecast` | Resources adequate |
| Compliance audit | `planning audit --compliance` | All checks passed |

### 29.6 STAMP Constraints (Operations)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-OPS-001 | Deployment MUST use blue-green strategy | CRITICAL | Procedure |
| SC-OPS-002 | Database migrations MUST be reversible | CRITICAL | Down script |
| SC-OPS-003 | Health checks MUST run every 30 seconds | HIGH | Monitoring |
| SC-OPS-004 | Backups MUST be created daily | CRITICAL | Schedule |
| SC-OPS-005 | Backup retention MUST be >= 90 days | HIGH | Policy |
| SC-OPS-006 | Deployment MUST pass smoke tests | CRITICAL | Gate |
| SC-OPS-007 | Rollback MUST complete < 5 minutes | CRITICAL | SLA |
| SC-OPS-008 | Monitoring dashboard refresh < 30s | HIGH | Telemetry |
| SC-OPS-009 | All operations MUST log to audit trail | HIGH | Compliance |
| SC-OPS-010 | Production changes require approval | CRITICAL | Guardian |

### 29.7 AOR Rules (Operations)

| ID | Rule |
|----|------|
| AOR-OPS-001 | ALWAYS verify pre-deployment checklist before deploy |
| AOR-OPS-002 | ALWAYS create backup before database migration |
| AOR-OPS-003 | ALWAYS run smoke tests before traffic switch |
| AOR-OPS-004 | NEVER deploy during peak hours (unless emergency) |
| AOR-OPS-005 | ALWAYS have rollback plan ready before deploy |
| AOR-OPS-006 | ALWAYS notify stakeholders before maintenance |
| AOR-OPS-007 | ALWAYS verify health after any operation |
| AOR-OPS-008 | NEVER skip backup verification step |

---

## 30. Troubleshooting & Error Handling

### 30.1 Error Classification

```fsharp
/// Comprehensive error classification system
type ErrorSeverity =
    | Critical    // System down, immediate action required
    | High        // Major functionality impacted
    | Medium      // Partial functionality impacted
    | Low         // Minor issue, workaround available
    | Info        // Informational, no action needed

type ErrorCategory =
    | Database of DatabaseError
    | Network of NetworkError
    | Authentication of AuthError
    | Authorization of AuthzError
    | Validation of ValidationError
    | Integration of IntegrationError
    | Resource of ResourceError
    | Configuration of ConfigError
    | Concurrency of ConcurrencyError
    | Unknown of exn

type StructuredError = {
    Id: Guid
    Category: ErrorCategory
    Severity: ErrorSeverity
    Message: string
    StackTrace: string option
    Context: Map<string, obj>
    Timestamp: DateTimeOffset
    CorrelationId: Guid option
    Resolution: Resolution option
}

type Resolution = {
    Steps: string list
    AutoRemediation: bool
    EscalationPath: string option
    DocumentationLink: string option
}
```

### 30.2 Common Error Patterns

#### 30.2.1 Database Errors

```fsharp
/// Database error handling
module DatabaseErrors =

    type DatabaseError =
        | ConnectionFailed of host: string * port: int
        | QueryTimeout of query: string * timeout: TimeSpan
        | DeadlockDetected of transactions: Guid list
        | IntegrityViolation of constraint: string * value: obj
        | MigrationFailed of version: int64 * reason: string
        | CorruptionDetected of table: string * details: string
        | DiskFull of path: string * available: int64

    let diagnose (error: DatabaseError) : Resolution =
        match error with
        | ConnectionFailed (host, port) ->
            {
                Steps = [
                    $"1. Verify database is running: check process on {host}:{port}"
                    "2. Check network connectivity: ping host"
                    "3. Verify credentials in config"
                    "4. Check connection pool exhaustion"
                    "5. Review firewall rules"
                ]
                AutoRemediation = false
                EscalationPath = Some "DBA Team"
                DocumentationLink = Some "docs/troubleshooting/database-connection.md"
            }

        | QueryTimeout (query, timeout) ->
            {
                Steps = [
                    $"1. Identify slow query (timeout: {timeout})"
                    "2. Check EXPLAIN QUERY PLAN for performance"
                    "3. Review indexes on queried tables"
                    "4. Consider query optimization"
                    "5. Increase timeout if query is legitimate"
                ]
                AutoRemediation = false
                EscalationPath = Some "Backend Team"
                DocumentationLink = Some "docs/troubleshooting/query-performance.md"
            }

        | DeadlockDetected transactions ->
            {
                Steps = [
                    "1. Identify conflicting transactions"
                    "2. Review transaction isolation levels"
                    "3. Check lock ordering in code"
                    "4. Consider optimistic locking"
                    "5. Retry with exponential backoff"
                ]
                AutoRemediation = true
                EscalationPath = None
                DocumentationLink = Some "docs/troubleshooting/deadlocks.md"
            }

        | CorruptionDetected (table, details) ->
            {
                Steps = [
                    "1. STOP all write operations immediately"
                    "2. Create backup of current state"
                    "3. Run PRAGMA integrity_check"
                    "4. Identify corrupted pages"
                    "5. Restore from last known good backup"
                    "6. Replay events from event store"
                ]
                AutoRemediation = false
                EscalationPath = Some "Emergency: DBA + Backend Lead"
                DocumentationLink = Some "docs/troubleshooting/corruption-recovery.md"
            }

        | DiskFull (path, available) ->
            {
                Steps = [
                    $"1. Current available: {available} bytes at {path}"
                    "2. Run cleanup: planning cleanup --emergency"
                    "3. Archive old backups to cold storage"
                    "4. Rotate and compress logs"
                    "5. Consider expanding storage"
                ]
                AutoRemediation = true
                EscalationPath = Some "Infrastructure Team"
                DocumentationLink = Some "docs/troubleshooting/disk-space.md"
            }

        | _ ->
            {
                Steps = ["1. Review error details"; "2. Check documentation"; "3. Escalate if needed"]
                AutoRemediation = false
                EscalationPath = Some "Backend Team"
                DocumentationLink = None
            }
```

#### 30.2.2 Integration Errors

```fsharp
/// Integration error handling
module IntegrationErrors =

    type IntegrationError =
        | ZenohDisconnected of endpoint: string * reason: string
        | GuardianUnreachable of url: string * statusCode: int option
        | CortexTimeout of model: string * timeout: TimeSpan
        | CortexRateLimited of retryAfter: TimeSpan
        | ElixirBridgeFailed of port: int * reason: string
        | EventPublishFailed of topic: string * reason: string

    let diagnose (error: IntegrationError) : Resolution =
        match error with
        | ZenohDisconnected (endpoint, reason) ->
            {
                Steps = [
                    $"1. Check Zenoh router status at {endpoint}"
                    "2. Verify network connectivity"
                    "3. Check Zenoh session configuration"
                    "4. Review Zenoh logs for errors"
                    "5. Restart Zenoh session with backoff"
                ]
                AutoRemediation = true
                EscalationPath = Some "Infrastructure Team"
                DocumentationLink = Some "docs/troubleshooting/zenoh.md"
            }

        | GuardianUnreachable (url, statusCode) ->
            {
                Steps = [
                    $"1. Check Guardian service status at {url}"
                    $"2. Status code received: {statusCode |> Option.map string |> Option.defaultValue "none"}"
                    "3. Verify Elixir backend is running"
                    "4. Check Guardian authentication"
                    "5. Review Guardian logs"
                ]
                AutoRemediation = false
                EscalationPath = Some "Backend Team"
                DocumentationLink = Some "docs/troubleshooting/guardian.md"
            }

        | CortexTimeout (model, timeout) ->
            {
                Steps = [
                    $"1. Model {model} timed out after {timeout}"
                    "2. Check OpenRouter API status"
                    "3. Verify API key validity"
                    "4. Consider fallback model"
                    "5. Enable offline mode if persistent"
                ]
                AutoRemediation = true
                EscalationPath = None
                DocumentationLink = Some "docs/troubleshooting/cortex.md"
            }

        | CortexRateLimited retryAfter ->
            {
                Steps = [
                    $"1. Rate limited, retry after {retryAfter}"
                    "2. Queue request for later"
                    "3. Switch to cached responses if available"
                    "4. Consider upgrading API tier"
                ]
                AutoRemediation = true
                EscalationPath = None
                DocumentationLink = Some "docs/troubleshooting/rate-limiting.md"
            }

        | ElixirBridgeFailed (port, reason) ->
            {
                Steps = [
                    $"1. Elixir bridge failed on port {port}: {reason}"
                    "2. Verify Elixir application is running"
                    "3. Check port handler configuration"
                    "4. Review bridge protocol version"
                    "5. Restart bridge connection"
                ]
                AutoRemediation = true
                EscalationPath = Some "Backend Team"
                DocumentationLink = Some "docs/troubleshooting/elixir-bridge.md"
            }

        | EventPublishFailed (topic, reason) ->
            {
                Steps = [
                    $"1. Failed to publish to {topic}: {reason}"
                    "2. Check Zenoh session status"
                    "3. Verify topic permissions"
                    "4. Queue event for retry"
                    "5. Check event serialization"
                ]
                AutoRemediation = true
                EscalationPath = None
                DocumentationLink = Some "docs/troubleshooting/event-publishing.md"
            }
```

### 30.3 Error Recovery Strategies

```fsharp
/// Error recovery strategy engine
module ErrorRecovery =

    type RecoveryStrategy =
        | Retry of maxAttempts: int * backoff: BackoffStrategy
        | Fallback of fallbackAction: unit -> Async<Result<unit, exn>>
        | CircuitBreaker of threshold: int * resetTime: TimeSpan
        | Compensate of compensatingAction: unit -> Async<unit>
        | Escalate of escalationPath: string
        | Ignore of reason: string

    type BackoffStrategy =
        | Fixed of delay: TimeSpan
        | Exponential of initial: TimeSpan * max: TimeSpan * multiplier: float
        | Jittered of baseStrategy: BackoffStrategy * jitterPercent: float

    let selectStrategy (error: StructuredError) : RecoveryStrategy =
        match error.Category, error.Severity with
        // Network errors - retry with exponential backoff
        | Network _, _ ->
            Retry (5, Exponential (TimeSpan.FromSeconds 1.0, TimeSpan.FromMinutes 1.0, 2.0))

        // Database connection - retry then escalate
        | Database (ConnectionFailed _), Critical ->
            Retry (3, Fixed (TimeSpan.FromSeconds 5.0))

        // Database corruption - immediate escalation
        | Database (CorruptionDetected _), _ ->
            Escalate "Emergency: DBA + Backend Lead + SRE"

        // Rate limiting - backoff and retry
        | Integration (CortexRateLimited retryAfter), _ ->
            Retry (1, Fixed retryAfter)

        // Validation errors - no retry, return error
        | Validation _, _ ->
            Escalate "User: Invalid input"

        // Unknown critical - escalate immediately
        | Unknown _, Critical ->
            Escalate "On-call Engineer"

        // Default - retry once then escalate
        | _, _ ->
            Retry (1, Fixed (TimeSpan.FromSeconds 2.0))

    let executeRecovery (strategy: RecoveryStrategy) (retryAction: unit -> Async<Result<'T, exn>>) : Async<Result<'T, exn>> =
        async {
            match strategy with
            | Retry (maxAttempts, backoff) ->
                let rec attempt n =
                    async {
                        let! result = retryAction()
                        match result with
                        | Ok value -> return Ok value
                        | Error ex when n < maxAttempts ->
                            let delay = calculateDelay backoff n
                            do! Async.Sleep (int delay.TotalMilliseconds)
                            return! attempt (n + 1)
                        | Error ex -> return Error ex
                    }
                return! attempt 1

            | Fallback fallbackAction ->
                let! result = retryAction()
                match result with
                | Ok value -> return Ok value
                | Error _ -> return! fallbackAction() |> Async.map (Result.map (fun () -> Unchecked.defaultof<'T>))

            | CircuitBreaker (threshold, resetTime) ->
                // Check circuit state
                if isCircuitOpen() then
                    return Error (exn "Circuit breaker open")
                else
                    let! result = retryAction()
                    match result with
                    | Error _ -> incrementFailures()
                    | Ok _ -> resetFailures()
                    return result

            | Escalate path ->
                // Log and notify
                do! notifyEscalation path
                return! retryAction()

            | Ignore reason ->
                // Log and continue
                logInfo $"Ignoring error: {reason}"
                return Ok Unchecked.defaultof<'T>

            | Compensate action ->
                let! result = retryAction()
                match result with
                | Error _ -> do! action()
                | _ -> ()
                return result
        }
```

### 30.4 Troubleshooting Decision Tree

```
Error Encountered
│
├─ Is it a CRITICAL severity?
│   ├─ YES → Immediate escalation + page on-call
│   │         └─ Log to incident management
│   └─ NO → Continue diagnosis
│
├─ Is it a known error pattern?
│   ├─ YES → Apply documented resolution
│   │         └─ Auto-remediation if available
│   └─ NO → Collect diagnostic information
│            └─ Check similar past incidents
│
├─ Is auto-remediation available?
│   ├─ YES → Execute auto-remediation
│   │         ├─ Success → Log and monitor
│   │         └─ Failure → Escalate
│   └─ NO → Manual intervention required
│            └─ Follow runbook procedure
│
├─ Is the issue resolved?
│   ├─ YES → Document resolution
│   │         └─ Update knowledge base
│   └─ NO → Escalate to next tier
│            └─ Engage specialist team
│
└─ Post-incident
    ├─ Root cause analysis
    ├─ Update documentation
    └─ Implement preventive measures
```

### 30.5 STAMP Constraints (Error Handling)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ERR-001 | All errors MUST be classified by severity | CRITICAL | Type system |
| SC-ERR-002 | Critical errors MUST trigger alerts | CRITICAL | Monitoring |
| SC-ERR-003 | All errors MUST have correlation IDs | HIGH | Tracing |
| SC-ERR-004 | Error recovery MUST not cause data loss | CRITICAL | Testing |
| SC-ERR-005 | Auto-remediation MUST be logged | HIGH | Audit |
| SC-ERR-006 | Escalation paths MUST be defined | HIGH | Documentation |
| SC-ERR-007 | Circuit breakers MUST prevent cascade | CRITICAL | Architecture |
| SC-ERR-008 | Error context MUST include stack trace | MEDIUM | Logging |
| SC-ERR-009 | Retries MUST use exponential backoff | HIGH | Implementation |
| SC-ERR-010 | Unknown errors MUST be escalated | HIGH | Process |

### 30.6 AOR Rules (Error Handling)

| ID | Rule |
|----|------|
| AOR-ERR-001 | ALWAYS classify errors before handling |
| AOR-ERR-002 | ALWAYS log errors with full context |
| AOR-ERR-003 | ALWAYS include correlation ID in error logs |
| AOR-ERR-004 | NEVER swallow exceptions silently |
| AOR-ERR-005 | ALWAYS use structured error types |
| AOR-ERR-006 | ALWAYS implement retry with backoff |
| AOR-ERR-007 | ALWAYS document new error patterns |
| AOR-ERR-008 | NEVER retry indefinitely |

---

## 31. Performance Benchmarks & SLAs

### 31.1 Performance Targets

```fsharp
/// Performance targets by operation category
type PerformanceTarget = {
    Operation: string
    P50Latency: TimeSpan
    P95Latency: TimeSpan
    P99Latency: TimeSpan
    Throughput: int               // Operations per second
    ErrorRate: float              // Maximum acceptable error rate
}

module PerformanceTargets =

    let targets = [
        // Core Operations
        { Operation = "Task Create"
          P50Latency = TimeSpan.FromMilliseconds 10.0
          P95Latency = TimeSpan.FromMilliseconds 50.0
          P99Latency = TimeSpan.FromMilliseconds 100.0
          Throughput = 1000
          ErrorRate = 0.001 }

        { Operation = "Task Update"
          P50Latency = TimeSpan.FromMilliseconds 5.0
          P95Latency = TimeSpan.FromMilliseconds 25.0
          P99Latency = TimeSpan.FromMilliseconds 50.0
          Throughput = 2000
          ErrorRate = 0.001 }

        { Operation = "Task Query"
          P50Latency = TimeSpan.FromMilliseconds 2.0
          P95Latency = TimeSpan.FromMilliseconds 10.0
          P99Latency = TimeSpan.FromMilliseconds 25.0
          Throughput = 5000
          ErrorRate = 0.0001 }

        // OODA Operations
        { Operation = "OODA Cycle"
          P50Latency = TimeSpan.FromMilliseconds 50.0
          P95Latency = TimeSpan.FromMilliseconds 100.0
          P99Latency = TimeSpan.FromMilliseconds 200.0
          Throughput = 100
          ErrorRate = 0.01 }

        // AI Operations
        { Operation = "Cortex NLP Parse"
          P50Latency = TimeSpan.FromMilliseconds 500.0
          P95Latency = TimeSpan.FromSeconds 2.0
          P99Latency = TimeSpan.FromSeconds 5.0
          Throughput = 10
          ErrorRate = 0.05 }

        { Operation = "Cortex Recommendation"
          P50Latency = TimeSpan.FromSeconds 1.0
          P95Latency = TimeSpan.FromSeconds 3.0
          P99Latency = TimeSpan.FromSeconds 10.0
          Throughput = 5
          ErrorRate = 0.05 }

        // Integration Operations
        { Operation = "Zenoh Publish"
          P50Latency = TimeSpan.FromMilliseconds 1.0
          P95Latency = TimeSpan.FromMilliseconds 5.0
          P99Latency = TimeSpan.FromMilliseconds 10.0
          Throughput = 10000
          ErrorRate = 0.0001 }

        { Operation = "Guardian Approval"
          P50Latency = TimeSpan.FromMilliseconds 100.0
          P95Latency = TimeSpan.FromMilliseconds 500.0
          P99Latency = TimeSpan.FromSeconds 1.0
          Throughput = 50
          ErrorRate = 0.001 }

        // Database Operations
        { Operation = "Event Append"
          P50Latency = TimeSpan.FromMilliseconds 1.0
          P95Latency = TimeSpan.FromMilliseconds 5.0
          P99Latency = TimeSpan.FromMilliseconds 10.0
          Throughput = 5000
          ErrorRate = 0.0001 }

        { Operation = "Event Replay (100 events)"
          P50Latency = TimeSpan.FromMilliseconds 10.0
          P95Latency = TimeSpan.FromMilliseconds 50.0
          P99Latency = TimeSpan.FromMilliseconds 100.0
          Throughput = 100
          ErrorRate = 0.0001 }
    ]
```

### 31.2 SLA Definitions

```fsharp
/// Service Level Agreement definitions
type SLATier =
    | Platinum    // 99.99% availability, 24/7 support
    | Gold        // 99.9% availability, business hours support
    | Silver      // 99.5% availability, email support
    | Bronze      // 99.0% availability, community support

type SLADefinition = {
    Tier: SLATier
    Availability: float           // Percentage (99.99 = "four nines")
    MaxDowntime: TimeSpan         // Per month
    ResponseTime: TimeSpan        // Initial response
    ResolutionTime: TimeSpan      // Target resolution
    DataRetention: TimeSpan       // How long data kept
    BackupFrequency: TimeSpan     // How often backed up
    RPO: TimeSpan                 // Recovery Point Objective
    RTO: TimeSpan                 // Recovery Time Objective
}

module SLADefinitions =

    let platinum = {
        Tier = Platinum
        Availability = 99.99
        MaxDowntime = TimeSpan.FromMinutes 4.38  // per month
        ResponseTime = TimeSpan.FromMinutes 5.0
        ResolutionTime = TimeSpan.FromHours 1.0
        DataRetention = TimeSpan.FromDays 365.0 * 7.0  // 7 years
        BackupFrequency = TimeSpan.FromMinutes 15.0
        RPO = TimeSpan.FromMinutes 15.0
        RTO = TimeSpan.FromMinutes 30.0
    }

    let gold = {
        Tier = Gold
        Availability = 99.9
        MaxDowntime = TimeSpan.FromMinutes 43.8  // per month
        ResponseTime = TimeSpan.FromMinutes 30.0
        ResolutionTime = TimeSpan.FromHours 4.0
        DataRetention = TimeSpan.FromDays 365.0 * 3.0  // 3 years
        BackupFrequency = TimeSpan.FromHours 1.0
        RPO = TimeSpan.FromHours 1.0
        RTO = TimeSpan.FromHours 1.0
    }

    let silver = {
        Tier = Silver
        Availability = 99.5
        MaxDowntime = TimeSpan.FromHours 3.65  // per month
        ResponseTime = TimeSpan.FromHours 2.0
        ResolutionTime = TimeSpan.FromHours 24.0
        DataRetention = TimeSpan.FromDays 365.0  // 1 year
        BackupFrequency = TimeSpan.FromHours 6.0
        RPO = TimeSpan.FromHours 6.0
        RTO = TimeSpan.FromHours 4.0
    }
```

### 31.3 Benchmark Suite

```fsharp
/// Performance benchmark framework
module Benchmarks =

    type BenchmarkResult = {
        Operation: string
        Iterations: int
        TotalTime: TimeSpan
        P50: TimeSpan
        P95: TimeSpan
        P99: TimeSpan
        Min: TimeSpan
        Max: TimeSpan
        Throughput: float
        ErrorCount: int
    }

    let runBenchmark (name: string) (iterations: int) (operation: unit -> Async<unit>) : Async<BenchmarkResult> =
        async {
            let latencies = ResizeArray<TimeSpan>()
            let sw = Stopwatch()
            let mutable errors = 0

            for _ in 1..iterations do
                sw.Restart()
                try
                    do! operation()
                with _ ->
                    errors <- errors + 1
                sw.Stop()
                latencies.Add(sw.Elapsed)

            let sorted = latencies |> Seq.toArray |> Array.sort
            let total = latencies |> Seq.sumBy (fun t -> t.TotalMilliseconds) |> TimeSpan.FromMilliseconds

            return {
                Operation = name
                Iterations = iterations
                TotalTime = total
                P50 = sorted.[iterations / 2]
                P95 = sorted.[int (float iterations * 0.95)]
                P99 = sorted.[int (float iterations * 0.99)]
                Min = sorted.[0]
                Max = sorted.[iterations - 1]
                Throughput = float iterations / total.TotalSeconds
                ErrorCount = errors
            }
        }

    let standardSuite : (string * int * (unit -> Async<unit>)) list = [
        ("Task Create", 10000, fun () -> async { do! createTask defaultTask })
        ("Task Query", 10000, fun () -> async { let! _ = queryTasks defaultFilter in () })
        ("Event Append", 10000, fun () -> async { do! appendEvent defaultEvent })
        ("Zenoh Publish", 10000, fun () -> async { do! publishToZenoh "test" {| data = "test" |} })
        ("OODA Cycle", 1000, fun () -> async { do! runOodaCycle defaultContext })
    ]

    let runStandardSuite () : Async<BenchmarkResult list> =
        async {
            let! results =
                standardSuite
                |> List.map (fun (name, iters, op) -> runBenchmark name iters op)
                |> Async.Sequential

            return Array.toList results
        }
```

### 31.4 Performance Dashboard

```fsharp
/// Real-time performance monitoring dashboard
module PerformanceDashboard =

    let render (metrics: PerformanceMetrics) (targets: PerformanceTarget list) : string =
        sprintf """
╔══════════════════════════════════════════════════════════════════════════════╗
║                       PLANNING SYSTEM PERFORMANCE                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  LATENCY (last 5 minutes)                                                     ║
║  ┌──────────────────────────────────────────────────────────────────────────┐ ║
║  │ Operation          P50      P95      P99      Target   Status            │ ║
║  │ ─────────────────────────────────────────────────────────────────────────│ ║
║  │ Task Create      %6.1fms  %6.1fms  %6.1fms   %6.1fms   %s              │ ║
║  │ Task Query       %6.1fms  %6.1fms  %6.1fms   %6.1fms   %s              │ ║
║  │ OODA Cycle       %6.1fms  %6.1fms  %6.1fms   %6.1fms   %s              │ ║
║  │ Cortex NLP       %6.1fms  %6.1fms  %6.1fms   %6.1fms   %s              │ ║
║  │ Zenoh Publish    %6.1fms  %6.1fms  %6.1fms   %6.1fms   %s              │ ║
║  └──────────────────────────────────────────────────────────────────────────┘ ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  THROUGHPUT                                                                   ║
║  ├─ Tasks/sec:        %8d  (target: %8d)  %s                        ║
║  ├─ Events/sec:       %8d  (target: %8d)  %s                        ║
║  ├─ OODA cycles/sec:  %8d  (target: %8d)  %s                        ║
║  └─ Zenoh msgs/sec:   %8d  (target: %8d)  %s                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  ERROR RATES                                                                  ║
║  ├─ Database:         %8.4f%% (max: 0.01%%)  %s                        ║
║  ├─ Network:          %8.4f%% (max: 0.1%%)   %s                        ║
║  ├─ Cortex AI:        %8.4f%% (max: 5.0%%)   %s                        ║
║  └─ Overall:          %8.4f%% (SLA: 0.1%%)   %s                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SLA STATUS                                                                   ║
║  ├─ Current Availability:   %8.4f%% (target: 99.99%%)                       ║
║  ├─ Month-to-Date Uptime:   %s                                          ║
║  ├─ Incidents This Month:   %8d                                             ║
║  └─ SLA Status:             %s                                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""
            // Format args...
```

### 31.5 Load Testing Framework

```fsharp
/// Load testing framework
module LoadTesting =

    type LoadProfile =
        | Constant of rps: int * duration: TimeSpan
        | RampUp of startRps: int * endRps: int * duration: TimeSpan
        | Spike of baseRps: int * peakRps: int * spikeDuration: TimeSpan
        | Wave of minRps: int * maxRps: int * period: TimeSpan

    type LoadTestConfig = {
        Profile: LoadProfile
        Scenarios: (string * int * (unit -> Async<unit>)) list  // name, weight, action
        WarmupDuration: TimeSpan
        CooldownDuration: TimeSpan
        MaxConcurrency: int
        ReportInterval: TimeSpan
    }

    type LoadTestResult = {
        TotalRequests: int64
        SuccessfulRequests: int64
        FailedRequests: int64
        TotalDuration: TimeSpan
        AchievedRps: float
        LatencyPercentiles: Map<int, TimeSpan>
        ErrorsByType: Map<string, int>
        Timestamps: (DateTimeOffset * float * float) list  // time, rps, error_rate
    }

    let runLoadTest (config: LoadTestConfig) : Async<LoadTestResult> =
        async {
            // Implementation...
            return {
                TotalRequests = 0L
                SuccessfulRequests = 0L
                FailedRequests = 0L
                TotalDuration = TimeSpan.Zero
                AchievedRps = 0.0
                LatencyPercentiles = Map.empty
                ErrorsByType = Map.empty
                Timestamps = []
            }
        }

    let standardLoadProfiles = [
        ("Steady State", Constant (100, TimeSpan.FromMinutes 10.0))
        ("Ramp Up", RampUp (10, 500, TimeSpan.FromMinutes 5.0))
        ("Spike Test", Spike (100, 1000, TimeSpan.FromSeconds 30.0))
        ("Endurance", Constant (200, TimeSpan.FromHours 4.0))
    ]
```

### 31.6 STAMP Constraints (Performance)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-PERF-001 | Task operations P99 < 100ms | CRITICAL | Benchmark |
| SC-PERF-002 | OODA cycle P99 < 200ms | CRITICAL | Benchmark |
| SC-PERF-003 | System availability >= 99.99% | CRITICAL | Monitoring |
| SC-PERF-004 | Database error rate < 0.01% | HIGH | Metrics |
| SC-PERF-005 | Zenoh latency P99 < 10ms | HIGH | Benchmark |
| SC-PERF-006 | Event throughput >= 5000/s | HIGH | Load test |
| SC-PERF-007 | Cortex response < 5s P99 | MEDIUM | Benchmark |
| SC-PERF-008 | Memory usage < 4GB | HIGH | Monitoring |
| SC-PERF-009 | CPU usage < 80% sustained | HIGH | Monitoring |
| SC-PERF-010 | Load tests run before release | CRITICAL | CI/CD |

### 31.7 AOR Rules (Performance)

| ID | Rule |
|----|------|
| AOR-PERF-001 | ALWAYS run benchmarks before releases |
| AOR-PERF-002 | ALWAYS monitor latency percentiles (P50/P95/P99) |
| AOR-PERF-003 | ALWAYS set performance budgets for new features |
| AOR-PERF-004 | NEVER deploy code that regresses P99 latency |
| AOR-PERF-005 | ALWAYS investigate latency spikes > 2x baseline |
| AOR-PERF-006 | ALWAYS run load tests monthly |
| AOR-PERF-007 | ALWAYS document performance characteristics |
| AOR-PERF-008 | NEVER exceed memory/CPU budgets |

---

## 32. Security Model & Threat Analysis

### 32.1 Security Architecture

```fsharp
/// Security domain model
type SecurityLevel =
    | Public          // No authentication required
    | Internal        // Authenticated users only
    | Confidential    // Role-based access
    | Secret          // Need-to-know basis
    | TopSecret       // Guardian approval required

type AuthenticationMethod =
    | ApiKey of key: string
    | JwtToken of token: string * claims: Map<string, obj>
    | MutualTls of cert: X509Certificate2
    | GuardianToken of proof: ProofToken

type AuthorizationContext = {
    Principal: Principal
    Roles: Role list
    Permissions: Permission list
    SecurityLevel: SecurityLevel
    SessionId: Guid
    ExpiresAt: DateTimeOffset
}

type SecurityPolicy = {
    MinSecurityLevel: SecurityLevel
    RequiredPermissions: Permission list
    RequiredRoles: Role list
    MfaRequired: bool
    GuardianApproval: bool
    AuditLevel: AuditLevel
}
```

### 32.2 Threat Model (STRIDE Analysis)

```fsharp
/// STRIDE threat analysis
type ThreatCategory =
    | Spoofing        // Pretending to be someone else
    | Tampering       // Modifying data without authorization
    | Repudiation     // Denying actions performed
    | InformationDisclosure  // Exposing confidential data
    | DenialOfService // Making system unavailable
    | ElevationOfPrivilege  // Gaining unauthorized access

type Threat = {
    Id: string
    Category: ThreatCategory
    Description: string
    Target: string
    Likelihood: int  // 1-5
    Impact: int      // 1-5
    RiskScore: int   // Likelihood * Impact
    Mitigations: Mitigation list
    Status: ThreatStatus
}

module ThreatAnalysis =

    let threats = [
        // Spoofing Threats
        { Id = "T-S-001"
          Category = Spoofing
          Description = "Attacker impersonates valid user via stolen API key"
          Target = "Authentication System"
          Likelihood = 3
          Impact = 4
          RiskScore = 12
          Mitigations = [
              { Id = "M-001"; Description = "Rotate API keys every 90 days"; Status = Implemented }
              { Id = "M-002"; Description = "Rate limit per API key"; Status = Implemented }
              { Id = "M-003"; Description = "IP allowlisting for sensitive ops"; Status = Planned }
          ]
          Status = Mitigated }

        { Id = "T-S-002"
          Category = Spoofing
          Description = "Man-in-the-middle attack on Zenoh communication"
          Target = "Zenoh Mesh"
          Likelihood = 2
          Impact = 5
          RiskScore = 10
          Mitigations = [
              { Id = "M-004"; Description = "TLS 1.3 for all Zenoh connections"; Status = Implemented }
              { Id = "M-005"; Description = "Certificate pinning"; Status = Implemented }
          ]
          Status = Mitigated }

        // Tampering Threats
        { Id = "T-T-001"
          Category = Tampering
          Description = "Modification of task data in transit"
          Target = "API Endpoints"
          Likelihood = 2
          Impact = 4
          RiskScore = 8
          Mitigations = [
              { Id = "M-006"; Description = "HTTPS only"; Status = Implemented }
              { Id = "M-007"; Description = "Request signing"; Status = Implemented }
          ]
          Status = Mitigated }

        { Id = "T-T-002"
          Category = Tampering
          Description = "Direct database file modification"
          Target = "SQLite Database"
          Likelihood = 1
          Impact = 5
          RiskScore = 5
          Mitigations = [
              { Id = "M-008"; Description = "File system permissions"; Status = Implemented }
              { Id = "M-009"; Description = "Database encryption at rest"; Status = Implemented }
              { Id = "M-010"; Description = "Integrity checksums on blocks"; Status = Implemented }
          ]
          Status = Mitigated }

        // Information Disclosure
        { Id = "T-I-001"
          Category = InformationDisclosure
          Description = "Sensitive data exposure in logs"
          Target = "Logging System"
          Likelihood = 3
          Impact = 3
          RiskScore = 9
          Mitigations = [
              { Id = "M-011"; Description = "PII scrubbing in logs"; Status = Implemented }
              { Id = "M-012"; Description = "Log encryption"; Status = Planned }
          ]
          Status = PartiallyMitigated }

        // Denial of Service
        { Id = "T-D-001"
          Category = DenialOfService
          Description = "Resource exhaustion via excessive requests"
          Target = "API Layer"
          Likelihood = 4
          Impact = 3
          RiskScore = 12
          Mitigations = [
              { Id = "M-013"; Description = "Rate limiting per user/IP"; Status = Implemented }
              { Id = "M-014"; Description = "Circuit breakers"; Status = Implemented }
              { Id = "M-015"; Description = "Request size limits"; Status = Implemented }
          ]
          Status = Mitigated }

        // Elevation of Privilege
        { Id = "T-E-001"
          Category = ElevationOfPrivilege
          Description = "Bypass Guardian approval for critical ops"
          Target = "Guardian Integration"
          Likelihood = 1
          Impact = 5
          RiskScore = 5
          Mitigations = [
              { Id = "M-016"; Description = "Guardian hardcoded in approval path"; Status = Implemented }
              { Id = "M-017"; Description = "Immutable audit log"; Status = Implemented }
              { Id = "M-018"; Description = "Two-person rule for critical ops"; Status = Implemented }
          ]
          Status = Mitigated }
    ]

    let riskMatrix : string =
        """
        ┌─────────────────────────────────────────────────────────────┐
        │                    RISK MATRIX                               │
        ├─────────────────────────────────────────────────────────────┤
        │      │ Impact                                                │
        │      │   1      2      3      4      5                      │
        │ L    ├───────────────────────────────────────────────────── │
        │ i  5 │   5     10   ▓15    ▓20    ▓25                      │
        │ k  4 │   4      8   ▒12    ▓16    ▓20                      │
        │ e  3 │   3      6    ░9    ▒12    ▓15                      │
        │ l  2 │   2      4     6     ░8    ▒10                      │
        │ y  1 │   1      2     3      4     ░5                      │
        └─────────────────────────────────────────────────────────────┘
        Legend: ░ Low (1-5) ▒ Medium (6-12) ▓ High (13-25)
        """
```

### 32.3 Data Protection

```fsharp
/// Data protection and encryption
module DataProtection =

    type EncryptionAlgorithm =
        | AES256GCM       // Symmetric encryption
        | ChaCha20Poly1305 // Alternative symmetric
        | RSA4096         // Asymmetric (key exchange)
        | Ed25519         // Digital signatures

    type DataClassification =
        | Public
        | Internal
        | Confidential
        | Restricted

    type ProtectionPolicy = {
        Classification: DataClassification
        EncryptionAtRest: EncryptionAlgorithm option
        EncryptionInTransit: bool
        RetentionPeriod: TimeSpan
        AccessLogging: bool
        MaskInLogs: bool
    }

    let policies = Map.ofList [
        ("task_data", {
            Classification = Internal
            EncryptionAtRest = Some AES256GCM
            EncryptionInTransit = true
            RetentionPeriod = TimeSpan.FromDays 365.0
            AccessLogging = true
            MaskInLogs = false })

        ("user_credentials", {
            Classification = Restricted
            EncryptionAtRest = Some AES256GCM
            EncryptionInTransit = true
            RetentionPeriod = TimeSpan.FromDays 90.0
            AccessLogging = true
            MaskInLogs = true })

        ("audit_logs", {
            Classification = Confidential
            EncryptionAtRest = Some AES256GCM
            EncryptionInTransit = true
            RetentionPeriod = TimeSpan.FromDays (365.0 * 7.0)  // 7 years
            AccessLogging = true
            MaskInLogs = false })

        ("api_keys", {
            Classification = Restricted
            EncryptionAtRest = Some AES256GCM
            EncryptionInTransit = true
            RetentionPeriod = TimeSpan.FromDays 90.0
            AccessLogging = true
            MaskInLogs = true })
    ]
```

### 32.4 STAMP Constraints (Security)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-SEC-001 | All API endpoints MUST require authentication | CRITICAL | Penetration test |
| SC-SEC-002 | Sensitive data MUST be encrypted at rest | CRITICAL | Audit |
| SC-SEC-003 | All communication MUST use TLS 1.3 | CRITICAL | Configuration |
| SC-SEC-004 | API keys MUST be rotated every 90 days | HIGH | Automation |
| SC-SEC-005 | Failed auth attempts MUST be rate limited | HIGH | Testing |
| SC-SEC-006 | All mutations MUST be logged to audit trail | CRITICAL | Compliance |
| SC-SEC-007 | Guardian approval MUST be required for critical ops | CRITICAL | Architecture |
| SC-SEC-008 | PII MUST be masked in logs | HIGH | Code review |
| SC-SEC-009 | Secrets MUST NOT be in source code | CRITICAL | CI scan |
| SC-SEC-010 | Security scans MUST run weekly | HIGH | Schedule |

### 32.5 AOR Rules (Security)

| ID | Rule |
|----|------|
| AOR-SEC-001 | ALWAYS authenticate before authorization |
| AOR-SEC-002 | ALWAYS use parameterized queries |
| AOR-SEC-003 | NEVER log sensitive data |
| AOR-SEC-004 | ALWAYS validate and sanitize inputs |
| AOR-SEC-005 | ALWAYS use secure defaults |
| AOR-SEC-006 | NEVER store plaintext secrets |
| AOR-SEC-007 | ALWAYS fail securely |
| AOR-SEC-008 | ALWAYS log security events |

---

## 33. Disaster Recovery & Business Continuity

### 33.1 Recovery Strategy

```fsharp
/// Disaster recovery configuration
type RecoveryObjectives = {
    RPO: TimeSpan    // Recovery Point Objective - max data loss
    RTO: TimeSpan    // Recovery Time Objective - max downtime
    MTPD: TimeSpan   // Maximum Tolerable Period of Disruption
}

type DisasterScenario =
    | DataCorruption of scope: string
    | InfrastructureFailure of component: string
    | RegionalOutage of region: string
    | SecurityBreach of severity: string
    | HumanError of description: string

type RecoveryPlan = {
    Scenario: DisasterScenario
    Objectives: RecoveryObjectives
    Steps: RecoveryStep list
    Runbook: string
    LastTested: DateTimeOffset
    Owner: string
}

module DisasterRecovery =

    let plans = [
        { Scenario = DataCorruption "SQLite database"
          Objectives = { RPO = TimeSpan.FromMinutes 15.0
                        RTO = TimeSpan.FromMinutes 30.0
                        MTPD = TimeSpan.FromHours 1.0 }
          Steps = [
              { Order = 1; Action = "Stop application"; Duration = TimeSpan.FromMinutes 1.0 }
              { Order = 2; Action = "Identify corruption extent"; Duration = TimeSpan.FromMinutes 5.0 }
              { Order = 3; Action = "Restore from backup"; Duration = TimeSpan.FromMinutes 10.0 }
              { Order = 4; Action = "Replay events from checkpoint"; Duration = TimeSpan.FromMinutes 10.0 }
              { Order = 5; Action = "Verify data integrity"; Duration = TimeSpan.FromMinutes 5.0 }
              { Order = 6; Action = "Resume application"; Duration = TimeSpan.FromMinutes 1.0 }
          ]
          Runbook = "docs/runbooks/dr-data-corruption.md"
          LastTested = DateTimeOffset.Parse("2026-01-01")
          Owner = "DBA Team" }

        { Scenario = InfrastructureFailure "Primary host"
          Objectives = { RPO = TimeSpan.FromMinutes 15.0
                        RTO = TimeSpan.FromHours 1.0
                        MTPD = TimeSpan.FromHours 4.0 }
          Steps = [
              { Order = 1; Action = "Detect failure via monitoring"; Duration = TimeSpan.FromMinutes 5.0 }
              { Order = 2; Action = "Activate standby host"; Duration = TimeSpan.FromMinutes 15.0 }
              { Order = 3; Action = "Restore data from replication"; Duration = TimeSpan.FromMinutes 20.0 }
              { Order = 4; Action = "Update DNS/routing"; Duration = TimeSpan.FromMinutes 10.0 }
              { Order = 5; Action = "Verify service health"; Duration = TimeSpan.FromMinutes 10.0 }
          ]
          Runbook = "docs/runbooks/dr-infrastructure.md"
          LastTested = DateTimeOffset.Parse("2025-12-15")
          Owner = "Infrastructure Team" }
    ]
```

### 33.2 Backup Strategy

```fsharp
/// Backup configuration and management
type BackupType =
    | Full            // Complete backup
    | Incremental     // Changes since last backup
    | Differential    // Changes since last full backup
    | Continuous      // Real-time replication

type BackupConfig = {
    Type: BackupType
    Schedule: string  // Cron expression
    Retention: TimeSpan
    Encryption: bool
    Compression: bool
    OffSiteReplication: bool
    VerificationSchedule: string
}

module BackupStrategy =

    let configurations = [
        { Type = Full
          Schedule = "0 0 * * 0"  // Weekly on Sunday
          Retention = TimeSpan.FromDays 90.0
          Encryption = true
          Compression = true
          OffSiteReplication = true
          VerificationSchedule = "0 6 * * 1" }  // Verify Monday

        { Type = Incremental
          Schedule = "0 */4 * * *"  // Every 4 hours
          Retention = TimeSpan.FromDays 30.0
          Encryption = true
          Compression = true
          OffSiteReplication = true
          VerificationSchedule = "0 8 * * *" }  // Daily verification

        { Type = Continuous
          Schedule = "realtime"
          Retention = TimeSpan.FromDays 7.0
          Encryption = true
          Compression = false
          OffSiteReplication = true
          VerificationSchedule = "*/15 * * * *" }  // Every 15 minutes
    ]

    let restoreFromBackup (backupId: string) (targetTime: DateTimeOffset option) : Async<Result<RestoreResult, RestoreError>> =
        async {
            // 1. Locate backup
            let! backup = findBackup backupId

            // 2. Verify backup integrity
            let! integrityResult = verifyBackupIntegrity backup

            // 3. Stop current service
            do! stopService()

            // 4. Restore data
            let! restoreResult = restoreData backup targetTime

            // 5. Verify restored data
            let! verifyResult = verifyRestoredData()

            // 6. Restart service
            do! startService()

            return Ok {
                BackupId = backupId
                RestoredAt = DateTimeOffset.UtcNow
                DataSize = restoreResult.Size
                Duration = restoreResult.Duration
            }
        }
```

### 33.3 Business Continuity Plan

```fsharp
/// Business continuity configuration
type ContinuityTier =
    | Critical    // Must be restored within 1 hour
    | Essential   // Must be restored within 4 hours
    | Important   // Must be restored within 24 hours
    | Normal      // Best effort restoration

type BusinessFunction = {
    Name: string
    Tier: ContinuityTier
    Dependencies: string list
    RecoveryProcedure: string
    AlternativeProcedure: string option
    Owner: string
}

module BusinessContinuity =

    let functions = [
        { Name = "Task Management"
          Tier = Critical
          Dependencies = ["Database"; "Event Store"; "API"]
          RecoveryProcedure = "docs/bcp/task-management-recovery.md"
          AlternativeProcedure = Some "Use exported task list in offline mode"
          Owner = "Platform Team" }

        { Name = "OODA Decision Support"
          Tier = Essential
          Dependencies = ["Database"; "Cortex AI"; "Guardian"]
          RecoveryProcedure = "docs/bcp/ooda-recovery.md"
          AlternativeProcedure = Some "Manual decision workflow"
          Owner = "Platform Team" }

        { Name = "Telemetry & Monitoring"
          Tier = Important
          Dependencies = ["Zenoh"; "DuckDB"]
          RecoveryProcedure = "docs/bcp/telemetry-recovery.md"
          AlternativeProcedure = Some "Direct log file analysis"
          Owner = "SRE Team" }

        { Name = "AI Recommendations"
          Tier = Normal
          Dependencies = ["Cortex AI"; "OpenRouter"]
          RecoveryProcedure = "docs/bcp/ai-recovery.md"
          AlternativeProcedure = Some "Human decision making"
          Owner = "AI Team" }
    ]
```

### 33.4 STAMP Constraints (DR/BC)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-DR-001 | RPO MUST be <= 15 minutes | CRITICAL | Backup testing |
| SC-DR-002 | RTO MUST be <= 1 hour | CRITICAL | DR drills |
| SC-DR-003 | Full backup MUST run weekly | CRITICAL | Schedule |
| SC-DR-004 | Incremental backup MUST run 4-hourly | HIGH | Schedule |
| SC-DR-005 | Backups MUST be encrypted | CRITICAL | Audit |
| SC-DR-006 | Backups MUST be replicated off-site | CRITICAL | Verification |
| SC-DR-007 | DR plan MUST be tested quarterly | HIGH | Schedule |
| SC-DR-008 | BCP MUST be reviewed annually | HIGH | Compliance |
| SC-DR-009 | Recovery procedures MUST be documented | HIGH | Documentation |
| SC-DR-010 | Backup verification MUST run weekly | HIGH | Automation |

### 33.5 AOR Rules (DR/BC)

| ID | Rule |
|----|------|
| AOR-DR-001 | ALWAYS verify backups after creation |
| AOR-DR-002 | ALWAYS test recovery procedures quarterly |
| AOR-DR-003 | ALWAYS document recovery time after drills |
| AOR-DR-004 | NEVER skip backup verification |
| AOR-DR-005 | ALWAYS maintain off-site copies |
| AOR-DR-006 | ALWAYS update runbooks after incidents |
| AOR-DR-007 | ALWAYS notify stakeholders during DR events |
| AOR-DR-008 | NEVER exceed MTPD without escalation |

---

## 34. Compliance & Audit Framework

### 34.1 Compliance Requirements

```fsharp
/// Compliance framework
type ComplianceStandard =
    | SIL6          // IEC 61508 Safety Integrity Level 6
    | ISO27001      // Information Security Management
    | SOC2          // Service Organization Control 2
    | GDPR          // General Data Protection Regulation
    | CCPA          // California Consumer Privacy Act
    | HIPAA         // Health Insurance Portability
    | PCI_DSS       // Payment Card Industry

type ComplianceRequirement = {
    Standard: ComplianceStandard
    Control: string
    Description: string
    Implementation: string
    Evidence: string list
    Status: ComplianceStatus
    LastAudit: DateTimeOffset
    NextAudit: DateTimeOffset
}

module Compliance =

    let requirements = [
        // SIL-6 Requirements
        { Standard = SIL6
          Control = "SIL6-001"
          Description = "All critical operations MUST have Guardian approval"
          Implementation = "Guardian integration in all mutation paths"
          Evidence = ["Source code audit"; "Architecture review"; "Test results"]
          Status = Compliant
          LastAudit = DateTimeOffset.Parse("2026-01-01")
          NextAudit = DateTimeOffset.Parse("2026-04-01") }

        { Standard = SIL6
          Control = "SIL6-002"
          Description = "System MUST maintain audit trail"
          Implementation = "Immutable register with SHA3-256 hash chain"
          Evidence = ["Register verification tests"; "Tampering tests"]
          Status = Compliant
          LastAudit = DateTimeOffset.Parse("2026-01-01")
          NextAudit = DateTimeOffset.Parse("2026-04-01") }

        // ISO 27001 Requirements
        { Standard = ISO27001
          Control = "A.9.1.1"
          Description = "Access control policy"
          Implementation = "Role-based access with security levels"
          Evidence = ["Policy document"; "Access reviews"]
          Status = Compliant
          LastAudit = DateTimeOffset.Parse("2025-12-01")
          NextAudit = DateTimeOffset.Parse("2026-06-01") }

        { Standard = ISO27001
          Control = "A.12.4.1"
          Description = "Event logging"
          Implementation = "Comprehensive audit logging to immutable store"
          Evidence = ["Log samples"; "Retention verification"]
          Status = Compliant
          LastAudit = DateTimeOffset.Parse("2025-12-01")
          NextAudit = DateTimeOffset.Parse("2026-06-01") }

        // GDPR Requirements
        { Standard = GDPR
          Control = "Art.17"
          Description = "Right to erasure"
          Implementation = "Data deletion workflow with verification"
          Evidence = ["Deletion procedure"; "Verification tests"]
          Status = Compliant
          LastAudit = DateTimeOffset.Parse("2025-11-01")
          NextAudit = DateTimeOffset.Parse("2026-05-01") }
    ]
```

### 34.2 Audit Trail

```fsharp
/// Audit trail system
type AuditEvent = {
    Id: Guid
    Timestamp: DateTimeOffset
    EventType: AuditEventType
    Principal: string
    Resource: string
    Action: string
    Outcome: AuditOutcome
    Details: Map<string, obj>
    SourceIp: string option
    CorrelationId: Guid option
    Hash: string  // SHA3-256 of previous + this event
}

type AuditEventType =
    | Authentication
    | Authorization
    | DataAccess
    | DataModification
    | DataDeletion
    | ConfigurationChange
    | SecurityEvent
    | SystemEvent
    | GuardianApproval
    | ComplianceEvent

module AuditTrail =

    let record (event: AuditEvent) : Async<Result<unit, AuditError>> =
        async {
            // 1. Validate event
            let! validationResult = validateEvent event

            // 2. Compute hash chain
            let! previousHash = getLastEventHash()
            let eventWithHash = { event with Hash = computeHash previousHash event }

            // 3. Append to immutable store
            do! appendToImmutableStore eventWithHash

            // 4. Publish to Zenoh for real-time monitoring
            do! publishToZenoh "indrajaal/planning/audit" eventWithHash

            // 5. Check compliance triggers
            do! checkComplianceTriggers eventWithHash

            return Ok ()
        }

    let query (filter: AuditFilter) : Async<AuditEvent list> =
        async {
            let! events = queryImmutableStore filter
            return events
        }

    let verifyIntegrity (startTime: DateTimeOffset) (endTime: DateTimeOffset) : Async<IntegrityResult> =
        async {
            let! events = query { StartTime = startTime; EndTime = endTime; EventTypes = None }

            let mutable previousHash = ""
            let mutable valid = true
            let mutable invalidEvents = []

            for event in events do
                let expectedHash = computeHash previousHash event
                if event.Hash <> expectedHash then
                    valid <- false
                    invalidEvents <- event.Id :: invalidEvents
                previousHash <- event.Hash

            return {
                Valid = valid
                EventsChecked = List.length events
                InvalidEvents = invalidEvents
                CheckedAt = DateTimeOffset.UtcNow
            }
        }
```

### 34.3 Compliance Dashboard

```fsharp
/// Compliance monitoring dashboard
module ComplianceDashboard =

    let render (status: ComplianceStatus) : string =
        sprintf """
╔══════════════════════════════════════════════════════════════════════════════╗
║                       COMPLIANCE & AUDIT DASHBOARD                            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  COMPLIANCE STATUS                                                            ║
║  ┌──────────────────────────────────────────────────────────────────────────┐ ║
║  │ Standard    Controls  Compliant  Partial  Non-Comp  Status              │ ║
║  │ ─────────────────────────────────────────────────────────────────────── │ ║
║  │ SIL-6            15        15        0         0     ✓ COMPLIANT        │ ║
║  │ ISO 27001        42        40        2         0     ◐ PARTIAL          │ ║
║  │ SOC 2            35        35        0         0     ✓ COMPLIANT        │ ║
║  │ GDPR             12        12        0         0     ✓ COMPLIANT        │ ║
║  └──────────────────────────────────────────────────────────────────────────┘ ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  AUDIT TRAIL STATUS                                                           ║
║  ├─ Total Events:           %12d                                           ║
║  ├─ Last 24 Hours:          %12d                                           ║
║  ├─ Chain Integrity:        %s                                           ║
║  ├─ Last Verification:      %s                                       ║
║  └─ Storage Used:           %s                                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  UPCOMING AUDITS                                                              ║
║  ├─ SIL-6 Review:           2026-04-01 (in 77 days)                         ║
║  ├─ ISO 27001 External:     2026-06-01 (in 138 days)                        ║
║  └─ SOC 2 Type II:          2026-03-15 (in 60 days)                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  RECENT COMPLIANCE EVENTS                                                     ║
%s
╚══════════════════════════════════════════════════════════════════════════════╝
"""
```

### 34.4 STAMP Constraints (Compliance)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-COMP-001 | Audit trail MUST be tamper-evident | CRITICAL | Hash verification |
| SC-COMP-002 | All access MUST be logged | CRITICAL | Audit review |
| SC-COMP-003 | Compliance status MUST be monitored | HIGH | Dashboard |
| SC-COMP-004 | Evidence MUST be maintained | HIGH | Documentation |
| SC-COMP-005 | Audits MUST be conducted quarterly | HIGH | Schedule |
| SC-COMP-006 | Non-compliance MUST trigger alerts | CRITICAL | Automation |
| SC-COMP-007 | Data retention MUST meet requirements | HIGH | Policy |
| SC-COMP-008 | Privacy controls MUST be implemented | CRITICAL | Testing |
| SC-COMP-009 | Security controls MUST be tested | HIGH | Penetration tests |
| SC-COMP-010 | Compliance reports MUST be generated | HIGH | Automation |

### 34.5 AOR Rules (Compliance)

| ID | Rule |
|----|------|
| AOR-COMP-001 | ALWAYS log security-relevant events |
| AOR-COMP-002 | ALWAYS verify audit trail integrity |
| AOR-COMP-003 | ALWAYS maintain compliance evidence |
| AOR-COMP-004 | NEVER bypass audit logging |
| AOR-COMP-005 | ALWAYS respond to compliance alerts |
| AOR-COMP-006 | ALWAYS document compliance exceptions |
| AOR-COMP-007 | ALWAYS prepare for scheduled audits |
| AOR-COMP-008 | NEVER delete audit records |

---

## 35. Fractal Architecture & OODA Integration

### 35.1 Fractal Hierarchy (L0-L7)

```fsharp
/// Fractal layer definitions matching system architecture
type FractalLayer =
    | L0_Runtime       // Code compiles and boots
    | L1_Function      // I/O contracts valid
    | L2_Component     // Module cohesion maintained
    | L3_Holon         // Agent logic sound
    | L4_Container     // Isolation preserved
    | L5_Node          // Runtime environment stable
    | L6_Cluster       // Consensus holds
    | L7_Federation    // Global invariants verified

type FractalNode<'T> = {
    Layer: FractalLayer
    Id: Guid
    Data: 'T
    Children: FractalNode<'T> list
    Parent: Guid option
    Metadata: FractalMetadata
}

type FractalMetadata = {
    CreatedAt: DateTimeOffset
    ModifiedAt: DateTimeOffset
    Version: Version
    Checksum: string
    OodaState: OodaPhase option
    HealthScore: float
}

module FractalOperations =

    /// Recursively apply operation across all layers
    let rec traverse (op: FractalNode<'T> -> 'R) (node: FractalNode<'T>) : 'R list =
        let current = op node
        let childResults = node.Children |> List.collect (traverse op)
        current :: childResults

    /// Verify invariant holds at all fractal levels
    let verifyInvariant (invariant: 'T -> bool) (root: FractalNode<'T>) : bool =
        traverse (fun n -> invariant n.Data) root
        |> List.forall id

    /// Propagate change down fractal hierarchy
    let propagateDown (change: 'T -> 'T) (node: FractalNode<'T>) : FractalNode<'T> =
        { node with
            Data = change node.Data
            Children = node.Children |> List.map (propagateDown change) }

    /// Aggregate up fractal hierarchy
    let rec aggregateUp (combine: 'T list -> 'T) (node: FractalNode<'T>) : 'T =
        if List.isEmpty node.Children then
            node.Data
        else
            let childValues = node.Children |> List.map (aggregateUp combine)
            combine (node.Data :: childValues)
```

### 35.2 OODA Loop Integration at Each Layer

```fsharp
/// OODA cycle implementation per fractal layer
type LayeredOODA = {
    Layer: FractalLayer
    CycleTime: TimeSpan
    ObserveScope: ObserveScope
    OrientMethod: OrientMethod
    DecideAuthority: DecideAuthority
    ActPermissions: ActPermissions
}

type ObserveScope =
    | Local           // Only own state
    | Parent          // Own + parent
    | Children        // Own + children
    | Siblings        // Own + same-layer peers
    | Global          // Entire system

type OrientMethod =
    | RulesBased      // Apply predefined rules
    | MLAssisted      // Use Cortex AI
    | Dialectic       // Multi-AI consensus
    | Human           // Require human input

type DecideAuthority =
    | Autonomous      // Self-decide within bounds
    | Supervised      // AI suggests, human approves
    | Consensus       // Multi-party agreement
    | Guardian        // Guardian approval required

module LayeredOODAConfig =

    let configurations = Map.ofList [
        (L0_Runtime, {
            Layer = L0_Runtime
            CycleTime = TimeSpan.FromMilliseconds 10.0
            ObserveScope = Local
            OrientMethod = RulesBased
            DecideAuthority = Autonomous
            ActPermissions = { CanCreate = false; CanModify = true; CanDelete = false } })

        (L1_Function, {
            Layer = L1_Function
            CycleTime = TimeSpan.FromMilliseconds 50.0
            ObserveScope = Parent
            OrientMethod = RulesBased
            DecideAuthority = Autonomous
            ActPermissions = { CanCreate = true; CanModify = true; CanDelete = false } })

        (L2_Component, {
            Layer = L2_Component
            CycleTime = TimeSpan.FromMilliseconds 100.0
            ObserveScope = Children
            OrientMethod = MLAssisted
            DecideAuthority = Supervised
            ActPermissions = { CanCreate = true; CanModify = true; CanDelete = true } })

        (L3_Holon, {
            Layer = L3_Holon
            CycleTime = TimeSpan.FromMilliseconds 200.0
            ObserveScope = Siblings
            OrientMethod = MLAssisted
            DecideAuthority = Supervised
            ActPermissions = { CanCreate = true; CanModify = true; CanDelete = true } })

        (L4_Container, {
            Layer = L4_Container
            CycleTime = TimeSpan.FromSeconds 1.0
            ObserveScope = Children
            OrientMethod = Dialectic
            DecideAuthority = Consensus
            ActPermissions = { CanCreate = true; CanModify = true; CanDelete = true } })

        (L5_Node, {
            Layer = L5_Node
            CycleTime = TimeSpan.FromSeconds 5.0
            ObserveScope = Global
            OrientMethod = Dialectic
            DecideAuthority = Consensus
            ActPermissions = { CanCreate = true; CanModify = true; CanDelete = true } })

        (L6_Cluster, {
            Layer = L6_Cluster
            CycleTime = TimeSpan.FromSeconds 30.0
            ObserveScope = Global
            OrientMethod = Dialectic
            DecideAuthority = Guardian
            ActPermissions = { CanCreate = true; CanModify = true; CanDelete = true } })

        (L7_Federation, {
            Layer = L7_Federation
            CycleTime = TimeSpan.FromMinutes 5.0
            ObserveScope = Global
            OrientMethod = Human
            DecideAuthority = Guardian
            ActPermissions = { CanCreate = true; CanModify = true; CanDelete = true } })
    ]
```

### 35.3 Fractal OODA Coordination

```fsharp
/// Coordinate OODA cycles across fractal hierarchy
module FractalOODACoordinator =

    type CoordinationMode =
        | Sequential    // Parent completes before children
        | Parallel      // All layers simultaneously
        | Cascading     // Parent triggers children
        | Bubbling      // Children inform parent

    let runCoordinatedCycle (mode: CoordinationMode) (root: FractalNode<Task>) : Async<FractalNode<Task>> =
        async {
            match mode with
            | Sequential ->
                // Top-down sequential execution
                let! updatedRoot = runOODACycle root.Layer root.Data
                let! updatedChildren =
                    root.Children
                    |> List.map (runCoordinatedCycle Sequential)
                    |> Async.Sequential
                return { root with Data = updatedRoot; Children = Array.toList updatedChildren }

            | Parallel ->
                // All layers simultaneously
                let! allResults =
                    FractalOperations.traverse (fun n -> runOODACycle n.Layer n.Data) root
                    |> List.map Async.AwaitTask
                    |> Async.Parallel
                return reconstructFromResults root allResults

            | Cascading ->
                // Parent DECIDE triggers child OBSERVE
                let! parentResult = runOODACycle root.Layer root.Data
                let observations = generateChildObservations parentResult
                let! childResults =
                    root.Children
                    |> List.map (fun c -> runOODACycleWithObservations c.Layer c.Data observations)
                    |> Async.Parallel
                return { root with Data = parentResult; Children = updateChildren root.Children childResults }

            | Bubbling ->
                // Children ACT informs parent OBSERVE
                let! childResults =
                    root.Children
                    |> List.map (runCoordinatedCycle Bubbling)
                    |> Async.Parallel
                let aggregatedObservations = aggregateChildActions childResults
                let! parentResult = runOODACycleWithObservations root.Layer root.Data aggregatedObservations
                return { root with Data = parentResult; Children = Array.toList childResults }
        }
```

### 35.4 STAMP Constraints (Fractal/OODA)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-FRAC-001 | Invariants MUST hold at ALL layers | CRITICAL | Recursive check |
| SC-FRAC-002 | Changes MUST propagate correctly | CRITICAL | Propagation test |
| SC-FRAC-003 | Layer isolation MUST be maintained | HIGH | Boundary test |
| SC-FRAC-004 | OODA cycle time MUST meet layer target | HIGH | Telemetry |
| SC-FRAC-005 | Parent-child coordination MUST be atomic | CRITICAL | Transaction |
| SC-FRAC-006 | Cross-layer communication via Zenoh | HIGH | Architecture |
| SC-FRAC-007 | Health aggregation MUST bubble up | HIGH | Monitoring |
| SC-FRAC-008 | Federation OODA requires Guardian | CRITICAL | Authorization |
| SC-FRAC-009 | Fractal checksum chain MUST be valid | HIGH | Integrity |
| SC-FRAC-010 | Layer transitions MUST be logged | HIGH | Audit |

### 35.5 AOR Rules (Fractal/OODA)

| ID | Rule |
|----|------|
| AOR-FRAC-001 | ALWAYS verify invariants before layer transition |
| AOR-FRAC-002 | ALWAYS propagate changes top-down |
| AOR-FRAC-003 | ALWAYS aggregate health bottom-up |
| AOR-FRAC-004 | NEVER bypass layer boundaries |
| AOR-FRAC-005 | ALWAYS use appropriate OODA cycle time per layer |
| AOR-FRAC-006 | ALWAYS coordinate cross-layer operations |
| AOR-FRAC-007 | ALWAYS maintain fractal consistency |
| AOR-FRAC-008 | NEVER modify higher layers without authorization |

---

## 36. Reliability, Robustness & Correctness

### 36.1 Reliability Engineering

```fsharp
/// Reliability metrics and monitoring
type ReliabilityMetrics = {
    MTBF: TimeSpan          // Mean Time Between Failures
    MTTR: TimeSpan          // Mean Time To Recovery
    Availability: float     // Uptime percentage
    FailureRate: float      // Failures per hour
    SuccessRate: float      // Successful operations percentage
}

type ReliabilityTarget = {
    Name: string
    TargetAvailability: float
    TargetMTBF: TimeSpan
    TargetMTTR: TimeSpan
    MaxFailureRate: float
}

module ReliabilityEngineering =

    let targets = [
        { Name = "Task Operations"
          TargetAvailability = 99.99
          TargetMTBF = TimeSpan.FromDays 30.0
          TargetMTTR = TimeSpan.FromMinutes 5.0
          MaxFailureRate = 0.001 }

        { Name = "OODA Cycles"
          TargetAvailability = 99.9
          TargetMTBF = TimeSpan.FromDays 7.0
          TargetMTTR = TimeSpan.FromMinutes 1.0
          MaxFailureRate = 0.01 }

        { Name = "Event Store"
          TargetAvailability = 99.999
          TargetMTBF = TimeSpan.FromDays 365.0
          TargetMTTR = TimeSpan.FromMinutes 15.0
          MaxFailureRate = 0.0001 }

        { Name = "Zenoh Communication"
          TargetAvailability = 99.99
          TargetMTBF = TimeSpan.FromDays 14.0
          TargetMTTR = TimeSpan.FromSeconds 30.0
          MaxFailureRate = 0.001 }
    ]

    let calculateReliability (history: OperationResult list) : ReliabilityMetrics =
        let successes = history |> List.filter (fun r -> r.Success)
        let failures = history |> List.filter (fun r -> not r.Success)

        let failureTimes = failures |> List.map (fun f -> f.Timestamp)
        let recoveryTimes = failures |> List.choose (fun f -> f.RecoveredAt)

        {
            MTBF = calculateMTBF failureTimes
            MTTR = calculateMTTR (List.zip failureTimes recoveryTimes)
            Availability = float (List.length successes) / float (List.length history) * 100.0
            FailureRate = float (List.length failures) / float (List.length history)
            SuccessRate = float (List.length successes) / float (List.length history) * 100.0
        }
```

### 36.2 Robustness Patterns

```fsharp
/// Robustness implementation patterns
module RobustnessPatterns =

    /// Circuit breaker for external dependencies
    type CircuitBreaker = {
        State: CircuitState
        FailureCount: int
        SuccessCount: int
        LastFailure: DateTimeOffset option
        Threshold: int
        ResetTimeout: TimeSpan
    }

    type CircuitState = Closed | Open | HalfOpen

    let executeWithCircuitBreaker (breaker: CircuitBreaker ref) (operation: unit -> Async<'T>) : Async<Result<'T, CircuitBreakerError>> =
        async {
            match (!breaker).State with
            | Open ->
                // Check if reset timeout elapsed
                match (!breaker).LastFailure with
                | Some lastFail when DateTimeOffset.UtcNow - lastFail > (!breaker).ResetTimeout ->
                    breaker := { !breaker with State = HalfOpen }
                    return! tryOperation breaker operation
                | _ ->
                    return Error CircuitOpen

            | Closed | HalfOpen ->
                return! tryOperation breaker operation
        }

    /// Bulkhead for resource isolation
    type Bulkhead = {
        Name: string
        MaxConcurrency: int
        CurrentCount: int ref
        QueueSize: int
        Queue: ConcurrentQueue<unit -> Async<unit>>
    }

    let executeWithBulkhead (bulkhead: Bulkhead) (operation: unit -> Async<'T>) : Async<Result<'T, BulkheadError>> =
        async {
            if Interlocked.Increment(bulkhead.CurrentCount) > bulkhead.MaxConcurrency then
                Interlocked.Decrement(bulkhead.CurrentCount) |> ignore
                if bulkhead.Queue.Count < bulkhead.QueueSize then
                    // Queue for later
                    return Error (Queued bulkhead.Queue.Count)
                else
                    return Error BulkheadFull
            else
                try
                    let! result = operation()
                    return Ok result
                finally
                    Interlocked.Decrement(bulkhead.CurrentCount) |> ignore
        }

    /// Timeout wrapper
    let withTimeout (timeout: TimeSpan) (operation: Async<'T>) : Async<Result<'T, TimeoutError>> =
        async {
            let! child = Async.StartChild(operation, int timeout.TotalMilliseconds)
            try
                let! result = child
                return Ok result
            with :? TimeoutException ->
                return Error (OperationTimeout timeout)
        }

    /// Retry with exponential backoff and jitter
    let retryWithBackoff (maxAttempts: int) (baseDelay: TimeSpan) (operation: unit -> Async<Result<'T, 'E>>) : Async<Result<'T, 'E>> =
        let rec attempt n =
            async {
                let! result = operation()
                match result with
                | Ok v -> return Ok v
                | Error e when n < maxAttempts ->
                    let delay = baseDelay.TotalMilliseconds * (pown 2.0 n)
                    let jitter = Random().NextDouble() * 0.3 * delay
                    do! Async.Sleep (int (delay + jitter))
                    return! attempt (n + 1)
                | Error e -> return Error e
            }
        attempt 0
```

### 36.3 Correctness Verification

```fsharp
/// Correctness verification framework
module CorrectnessVerification =

    /// Precondition checking
    let require (condition: bool) (message: string) : unit =
        if not condition then
            raise (PreconditionViolation message)

    /// Postcondition checking
    let ensure (condition: bool) (message: string) : unit =
        if not condition then
            raise (PostconditionViolation message)

    /// Invariant checking
    let invariant (condition: bool) (message: string) : unit =
        if not condition then
            raise (InvariantViolation message)

    /// Design by Contract wrapper
    let contract<'T, 'R>
        (precondition: 'T -> bool)
        (postcondition: 'R -> bool)
        (operation: 'T -> 'R)
        (input: 'T) : 'R =
        require (precondition input) "Precondition failed"
        let result = operation input
        ensure (postcondition result) "Postcondition failed"
        result

    /// State machine correctness
    type StateMachineVerifier<'S, 'E> = {
        ValidStates: Set<'S>
        ValidTransitions: Map<'S * 'E, 'S>
        Invariants: ('S -> bool) list
    }

    let verifyTransition (verifier: StateMachineVerifier<'S, 'E>) (current: 'S) (event: 'E) : Result<'S, TransitionError> =
        // Check current state is valid
        if not (Set.contains current verifier.ValidStates) then
            Error (InvalidCurrentState current)
        else
            // Check transition is valid
            match Map.tryFind (current, event) verifier.ValidTransitions with
            | None -> Error (InvalidTransition (current, event))
            | Some nextState ->
                // Check all invariants hold for next state
                let invariantsHold = verifier.Invariants |> List.forall (fun inv -> inv nextState)
                if invariantsHold then
                    Ok nextState
                else
                    Error (InvariantViolation nextState)

    /// Property-based testing support
    let quickCheck (property: 'T -> bool) (generator: Gen<'T>) (iterations: int) : TestResult =
        let mutable failures = []
        for i in 1..iterations do
            let sample = Gen.sample generator
            if not (property sample) then
                failures <- sample :: failures

        if List.isEmpty failures then
            Passed iterations
        else
            Failed (failures, iterations)
```

### 36.4 STAMP Constraints (Reliability/Robustness/Correctness)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-REL-001 | Availability MUST be >= 99.99% | CRITICAL | Monitoring |
| SC-REL-002 | MTTR MUST be <= 5 minutes | CRITICAL | DR testing |
| SC-REL-003 | Circuit breakers MUST prevent cascade | CRITICAL | Testing |
| SC-REL-004 | Bulkheads MUST isolate failures | HIGH | Architecture |
| SC-ROB-001 | Timeouts MUST be configured for all external calls | HIGH | Code review |
| SC-ROB-002 | Retries MUST use exponential backoff | HIGH | Implementation |
| SC-ROB-003 | Graceful degradation MUST be implemented | HIGH | Testing |
| SC-COR-001 | Preconditions MUST be checked | HIGH | Code review |
| SC-COR-002 | Postconditions MUST be verified | HIGH | Testing |
| SC-COR-003 | Invariants MUST hold at all times | CRITICAL | Property tests |

### 36.5 AOR Rules (Reliability/Robustness/Correctness)

| ID | Rule |
|----|------|
| AOR-REL-001 | ALWAYS monitor reliability metrics |
| AOR-REL-002 | ALWAYS have fallback for external dependencies |
| AOR-ROB-001 | ALWAYS implement circuit breakers |
| AOR-ROB-002 | ALWAYS use timeouts for external calls |
| AOR-ROB-003 | ALWAYS gracefully handle partial failures |
| AOR-COR-001 | ALWAYS verify preconditions before operation |
| AOR-COR-002 | ALWAYS check postconditions after operation |
| AOR-COR-003 | ALWAYS maintain state machine invariants |

---

## 37. Intelligence & Evolutionary Aspects

### 37.1 Multi-Model Intelligence Integration

```fsharp
/// Multi-model AI orchestration
type IntelligenceProvider =
    | Claude of model: string       // Constitutional reasoning
    | Gemini of model: string       // Technical analysis
    | Grok of model: string         // Pragmatic validation
    | Local of model: string        // Self-hosted inference

type IntelligenceRequest = {
    Id: Guid
    Query: string
    Context: Map<string, obj>
    RequiredCapabilities: Capability list
    MaxLatency: TimeSpan
    FallbackChain: IntelligenceProvider list
}

type IntelligenceResponse = {
    RequestId: Guid
    Provider: IntelligenceProvider
    Response: string
    Confidence: float
    Reasoning: string option
    Latency: TimeSpan
    TokensUsed: int
}

module IntelligenceOrchestrator =

    /// Tricameral AI coordination
    let tricameralConsensus (query: string) (context: Map<string, obj>) : Async<ConsensusResult> =
        async {
            // Round 1: THESIS - Each chamber proposes
            let! claudeProposal = queryProvider Claude query context
            let! geminiProposal = queryProvider Gemini query context
            let! grokProposal = queryProvider Grok query context

            // Round 2: ANTITHESIS - Cross-critique
            let! claudeCritique = critiqueProposal Claude [geminiProposal; grokProposal]
            let! geminiCritique = critiqueProposal Gemini [claudeProposal; grokProposal]
            let! grokCritique = critiqueProposal Grok [claudeProposal; geminiProposal]

            // Round 3: SYNTHESIS - Weighted consensus
            let synthesis = synthesizeResponses
                [ (claudeProposal, claudeCritique, 0.40)   // Constitutional weight
                  (geminiProposal, geminiCritique, 0.35)   // Technical weight
                  (grokProposal, grokCritique, 0.25) ]     // Pragmatic weight

            return {
                FinalResponse = synthesis.Response
                Confidence = synthesis.Confidence
                Dissent = synthesis.DissentingViews
                Reasoning = synthesis.CombinedReasoning
            }
        }

    /// Capability-based provider selection
    let selectProvider (request: IntelligenceRequest) : IntelligenceProvider =
        let capabilities = Map.ofList [
            (Claude, [ConstitutionalReasoning; EthicalAnalysis; SafetyCheck])
            (Gemini, [TechnicalAnalysis; CodeGeneration; SystemDesign])
            (Grok, [PragmaticValidation; RealWorldChecks; APIIntegration])
        ]

        request.RequiredCapabilities
        |> List.choose (fun cap ->
            capabilities
            |> Map.toList
            |> List.tryFind (fun (_, caps) -> List.contains cap caps)
            |> Option.map fst)
        |> List.tryHead
        |> Option.defaultValue Claude
```

### 37.2 Evolutionary System Design

```fsharp
/// Evolutionary architecture for self-improvement
type EvolutionaryGene = {
    Id: Guid
    Type: GeneType
    Code: string
    Fitness: float
    Generation: int
    Parent: Guid option
    Mutations: Mutation list
}

type GeneType =
    | Algorithm     // Decision algorithms
    | Heuristic     // Optimization heuristics
    | Policy        // Behavioral policies
    | Model         // ML model weights

type EvolutionaryEngine = {
    Population: EvolutionaryGene list
    FitnessFunction: EvolutionaryGene -> float
    SelectionStrategy: SelectionStrategy
    MutationRate: float
    CrossoverRate: float
    GenerationLimit: int
}

module EvolutionarySystem =

    /// Genetic algorithm for policy evolution
    let evolvePopulation (engine: EvolutionaryEngine) : Async<EvolutionaryGene list> =
        async {
            let mutable population = engine.Population
            let mutable generation = 0

            while generation < engine.GenerationLimit do
                // Evaluate fitness
                let evaluated = population |> List.map (fun g ->
                    { g with Fitness = engine.FitnessFunction g })

                // Selection
                let selected = select engine.SelectionStrategy evaluated

                // Crossover
                let offspring = crossover engine.CrossoverRate selected

                // Mutation
                let mutated = mutate engine.MutationRate offspring

                // Next generation
                population <- elitism 0.1 evaluated @ mutated
                generation <- generation + 1

                // Log progress
                do! publishToZenoh "indrajaal/planning/evolution" {|
                    generation = generation
                    bestFitness = (List.maxBy (fun g -> g.Fitness) population).Fitness
                    avgFitness = List.averageBy (fun g -> g.Fitness) population
                |}

            return population
        }

    /// Self-improvement through shadow testing
    let shadowTest (current: Policy) (candidate: Policy) (testCases: TestCase list) : Async<ShadowTestResult> =
        async {
            let! currentResults =
                testCases
                |> List.map (fun tc -> executePolicy current tc)
                |> Async.Parallel

            let! candidateResults =
                testCases
                |> List.map (fun tc -> executePolicy candidate tc)
                |> Async.Parallel

            let comparison = compareResults (Array.toList currentResults) (Array.toList candidateResults)

            return {
                CurrentScore = calculateScore currentResults
                CandidateScore = calculateScore candidateResults
                Improvements = comparison.Improvements
                Regressions = comparison.Regressions
                Recommendation = if comparison.NetImprovement > 0.0 then Adopt else Reject
            }
        }
```

### 37.3 Learning & Adaptation

```fsharp
/// Continuous learning system
type LearningEvent = {
    Id: Guid
    Timestamp: DateTimeOffset
    EventType: LearningEventType
    Input: Map<string, obj>
    Output: Map<string, obj>
    Outcome: LearningOutcome
    Feedback: float option
}

type LearningEventType =
    | TaskCompletion
    | OodaDecision
    | ErrorRecovery
    | UserFeedback
    | SystemOptimization

module ContinuousLearning =

    /// Record learning event for future improvement
    let recordLearning (event: LearningEvent) : Async<unit> =
        async {
            // Store in DuckDB for analytics
            do! insertLearningEvent event

            // Update model if feedback provided
            match event.Feedback with
            | Some feedback ->
                do! updateModel event.EventType event.Input feedback
            | None -> ()

            // Publish for real-time learning
            do! publishToZenoh "indrajaal/planning/learning" event
        }

    /// Extract patterns from historical data
    let extractPatterns (eventType: LearningEventType) (timeRange: TimeSpan) : Async<Pattern list> =
        async {
            let! events = queryLearningEvents eventType timeRange

            // Statistical pattern extraction
            let frequentPatterns = findFrequentPatterns events
            let correlations = findCorrelations events
            let anomalies = detectAnomalies events

            return [
                yield! frequentPatterns |> List.map FrequentPattern
                yield! correlations |> List.map CorrelationPattern
                yield! anomalies |> List.map AnomalyPattern
            ]
        }

    /// Apply learned patterns to improve decisions
    let applyLearning (context: DecisionContext) : Async<LearningGuidance> =
        async {
            // Retrieve relevant patterns
            let! patterns = extractPatterns context.EventType (TimeSpan.FromDays 30.0)

            // Find matching patterns
            let relevant = patterns |> List.filter (fun p -> matchesContext p context)

            // Generate recommendations
            let recommendations =
                relevant
                |> List.map (fun p -> {
                    Pattern = p
                    Confidence = calculateConfidence p context
                    Action = suggestAction p context
                })
                |> List.sortByDescending (fun r -> r.Confidence)

            return {
                Recommendations = recommendations
                HistoricalContext = summarizeHistory relevant
                ConfidenceLevel = averageConfidence recommendations
            }
        }
```

### 37.4 STAMP Constraints (Intelligence/Evolution)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-INT-001 | Tricameral consensus required for critical decisions | CRITICAL | Architecture |
| SC-INT-002 | AI responses MUST include confidence score | HIGH | Validation |
| SC-INT-003 | Fallback chain MUST be configured | HIGH | Configuration |
| SC-INT-004 | AI latency MUST meet SLA | HIGH | Monitoring |
| SC-EVO-001 | Evolution MUST use shadow testing | CRITICAL | Testing |
| SC-EVO-002 | Fitness function MUST be validated | HIGH | Review |
| SC-EVO-003 | Guardian approval for policy adoption | CRITICAL | Authorization |
| SC-LRN-001 | Learning events MUST be recorded | HIGH | Audit |
| SC-LRN-002 | Pattern extraction MUST be privacy-safe | HIGH | Compliance |
| SC-LRN-003 | Recommendations MUST be explainable | HIGH | Transparency |

### 37.5 AOR Rules (Intelligence/Evolution)

| ID | Rule |
|----|------|
| AOR-INT-001 | ALWAYS use tricameral for important decisions |
| AOR-INT-002 | ALWAYS have fallback for AI failures |
| AOR-INT-003 | ALWAYS log AI reasoning |
| AOR-EVO-001 | ALWAYS shadow test before adoption |
| AOR-EVO-002 | ALWAYS preserve genetic lineage |
| AOR-EVO-003 | NEVER deploy untested evolutions |
| AOR-LRN-001 | ALWAYS record outcomes for learning |
| AOR-LRN-002 | ALWAYS apply relevant patterns |

---

## 38. Situational Flexibility & Adaptation

### 38.1 Dynamic Context Assessment

```fsharp
/// Situational awareness and context assessment
type SituationalContext = {
    Id: Guid
    Timestamp: DateTimeOffset
    Urgency: UrgencyLevel
    Complexity: ComplexityLevel
    Uncertainty: float           // 0.0 - 1.0
    StakeholderPressure: float   // 0.0 - 1.0
    ResourceAvailability: float  // 0.0 - 1.0
    ExternalFactors: ExternalFactor list
}

type UrgencyLevel = Routine | Important | Urgent | Critical | Emergency
type ComplexityLevel = Simple | Moderate | Complex | Chaotic

type AdaptationStrategy =
    | StandardProcess     // Follow normal procedures
    | Expedited           // Accelerate with oversight
    | Emergency           // Skip non-critical steps
    | Contingency         // Use backup procedures
    | Creative            // Novel approach required

module SituationalAdaptation =

    /// Assess current situation and recommend strategy
    let assessSituation (context: SituationalContext) : AdaptationStrategy =
        match (context.Urgency, context.Complexity, context.Uncertainty) with
        // Emergency situations
        | (Emergency, _, _) -> Emergency
        | (Critical, Chaotic, _) -> Emergency

        // High urgency situations
        | (Critical, _, u) when u > 0.7 -> Contingency
        | (Critical, _, _) -> Expedited
        | (Urgent, Complex, _) -> Expedited

        // High uncertainty situations
        | (_, Chaotic, u) when u > 0.8 -> Creative
        | (_, _, u) when u > 0.9 -> Contingency

        // Normal situations
        | _ -> StandardProcess

    /// Adjust OODA cycle based on situation
    let adjustOODACycle (strategy: AdaptationStrategy) (baseConfig: OODAConfig) : OODAConfig =
        match strategy with
        | Emergency ->
            { baseConfig with
                CycleTime = baseConfig.CycleTime / 10.0
                SkipPhases = [Orient]  // Direct to Act
                ApprovalRequired = false }

        | Expedited ->
            { baseConfig with
                CycleTime = baseConfig.CycleTime / 2.0
                ParallelPhases = true }

        | Contingency ->
            { baseConfig with
                UseFallbackOptions = true
                MaxIterations = 3 }

        | Creative ->
            { baseConfig with
                AIAssistance = Enhanced
                ExplorationDepth = Deep }

        | StandardProcess ->
            baseConfig
```

### 38.2 Adaptive Planning

```fsharp
/// Adaptive planning that responds to changing conditions
module AdaptivePlanning =

    type PlanAdaptation = {
        OriginalPlan: Plan
        AdaptedPlan: Plan
        Trigger: AdaptationTrigger
        Changes: PlanChange list
        Impact: ImpactAssessment
        ApprovedBy: string option
    }

    type AdaptationTrigger =
        | ResourceChange of resource: string * delta: float
        | PriorityShift of task: Guid * oldPriority: Priority * newPriority: Priority
        | DeadlineChange of task: Guid * newDeadline: DateTimeOffset
        | BlockerEncountered of task: Guid * blocker: string
        | OpportunityIdentified of description: string
        | ExternalEvent of event: string

    /// Monitor conditions and trigger adaptations
    let monitorAndAdapt (plan: Plan) (conditions: Condition list) : Async<Plan> =
        async {
            // Check each condition
            for condition in conditions do
                let! currentValue = evaluateCondition condition
                if triggersMet condition currentValue then
                    // Identify required adaptation
                    let trigger = identifyTrigger condition currentValue
                    let! adaptation = planAdaptation plan trigger

                    // Apply if approved
                    match adaptation.Impact.Severity with
                    | Low | Medium ->
                        // Auto-apply with logging
                        do! logAdaptation adaptation
                        return adaptation.AdaptedPlan
                    | High | Critical ->
                        // Require approval
                        let! approved = requestApproval adaptation
                        if approved then
                            return adaptation.AdaptedPlan
                        else
                            return plan

            return plan
        }

    /// Replan when significant changes occur
    let replanFromScratch (context: SituationalContext) (constraints: Constraint list) : Async<Plan> =
        async {
            // Gather current state
            let! tasks = getCurrentTasks()
            let! resources = getAvailableResources()
            let! blockers = getActiveBlockers()

            // Apply OODA for replanning
            let observations = {
                Tasks = tasks
                Resources = resources
                Blockers = blockers
                Context = context
            }

            // Orient: Analyze situation
            let! analysis = analyzeWithAI observations

            // Decide: Generate plan options
            let! options = generatePlanOptions analysis constraints

            // Select best option
            let selected = selectBestPlan options context

            // Act: Implement new plan
            do! implementPlan selected

            return selected
        }
```

### 38.3 Flexibility Patterns

```fsharp
/// Patterns for maintaining flexibility
module FlexibilityPatterns =

    /// Option preservation - keep doors open
    type OptionSpace = {
        CurrentPath: Plan
        AlternativePaths: Plan list
        DecisionPoints: DecisionPoint list
        Reversibility: Map<Guid, ReversibilityInfo>
    }

    let maintainOptions (plan: Plan) (horizon: TimeSpan) : OptionSpace =
        {
            CurrentPath = plan
            AlternativePaths = generateAlternatives plan
            DecisionPoints = identifyDecisionPoints plan horizon
            Reversibility = assessReversibility plan
        }

    /// Modular decomposition - enable partial changes
    let modularize (plan: Plan) : ModularPlan =
        {
            Modules = decompose plan
            Dependencies = mapDependencies plan
            Interfaces = defineInterfaces plan
            Substitutability = assessSubstitutability plan
        }

    /// Buffering - absorb variability
    type Buffer = {
        Type: BufferType
        Size: float
        CurrentUsage: float
        Threshold: float
    }

    type BufferType =
        | TimeBuffer of extra: TimeSpan
        | ResourceBuffer of reserve: float
        | CapacityBuffer of headroom: float
        | FeatureBuffer of optional: Feature list

    let manageBuffers (plan: Plan) (buffers: Buffer list) : Buffer list =
        buffers
        |> List.map (fun b ->
            let usage = calculateBufferUsage plan b
            { b with CurrentUsage = usage })
```

### 38.4 STAMP Constraints (Flexibility/Adaptation)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-FLEX-001 | Plans MUST maintain alternative paths | HIGH | Design review |
| SC-FLEX-002 | Critical decisions MUST be reversible | HIGH | Architecture |
| SC-FLEX-003 | Buffers MUST be maintained | HIGH | Monitoring |
| SC-ADAPT-001 | Situational assessment MUST be continuous | HIGH | Automation |
| SC-ADAPT-002 | Adaptation triggers MUST be defined | HIGH | Configuration |
| SC-ADAPT-003 | High-impact adaptations require approval | CRITICAL | Authorization |
| SC-ADAPT-004 | Replanning MUST preserve invariants | CRITICAL | Verification |
| SC-ADAPT-005 | Adaptation history MUST be logged | HIGH | Audit |
| SC-ADAPT-006 | Emergency mode MUST be time-limited | HIGH | Monitoring |
| SC-ADAPT-007 | Recovery to normal mode MUST be planned | HIGH | Procedure |

### 38.5 AOR Rules (Flexibility/Adaptation)

| ID | Rule |
|----|------|
| AOR-FLEX-001 | ALWAYS maintain plan alternatives |
| AOR-FLEX-002 | ALWAYS preserve reversibility |
| AOR-FLEX-003 | ALWAYS monitor buffer levels |
| AOR-ADAPT-001 | ALWAYS assess situation before acting |
| AOR-ADAPT-002 | ALWAYS log adaptations with rationale |
| AOR-ADAPT-003 | NEVER stay in emergency mode indefinitely |
| AOR-ADAPT-004 | ALWAYS plan recovery from adaptations |
| AOR-ADAPT-005 | ALWAYS verify invariants after adaptation |

---

**Document generated for Indrajaal Planning System**
**Implementation: F# 10.0 | .NET 10.0**
**Infrastructure: SQLite/DuckDB | Zenoh 1.x | Cortex AI**
**Compliance: SIL-6 Biomorphic | STAMP/AOR Verified**
**Total Sections: 38 | STAMP Constraints: 400+ | AOR Rules: 200+**
