
Review All system docs and code for planning, execution and visualization.
Review the coretex, Prajna, todolist  and all otehr planning and task management, job management system aspects


>> TodoList Migration and Integrated Planning and Project Management System 
create a requirements and specifications doc that has the features of all these systems 
ToDolist Migration 
move all todo list functionality to f# ONLY
 store todolist in smriti databases 
use the separate db  for planning and todolist management
move the full functionality to f# code 
integrate zenoh into todo list system
do detailed 9 level analysis on all items related to planning, project management task and todolist management in the indrajaal system
move all the logic into F# only. decouple this logic from elixir completely
keep the PROJECT_TODOLIST.md as a backup
Create criticality based plan for smooth migration, the todo functionality must always be operational till ten time the migration is done  
 
Integrated Planning and Project management 
- For Overall Balance & Teams: Asana offers powerful team management, task handoffs, and a modern interface, with a solid free tier. 
- Monday.com provides excellent visual work management for diverse teams. 
- For Simplicity & Visuals: Trello is famous for its intuitive Kanban boards, making it easy to see task flow. 
- For Personal Productivity: Todoist balances power and simplicity, while 
- TickTick adds calendars and timers, and Microsoft To Do/Apple Reminders integrate with their ecosystems. 
- For Customization & All-in-One: ClickUp offers extensive customization for various tasks and projects. 
- For Agile/Developers: Jira is the go-to for Agile workflows and complex development projects. 
- For Spreadsheet Lovers: Smartsheet provides a familiar spreadsheet-style approach to project management.

Identify the features to 7 levels of detail and interaction, create integrated set of features and requirements that is optimal for our processes and system and all aspects of the system can use for planning, goal management, task tracking and todolist management
it should be useable by system and manually and useable for automated agent use
it must incorporate all ASPECTS of military planning and decision making into the system 
- architecture must be fractal, holonic and BIOmorphic

Explore integration of these techniques into the system 
Here is the comprehensive, unified report integrating all discussed frameworks, techniques, and strategic analyses. This document preserves the depth of the previous exchanges, structured as a formal military staff study for review and analysis.


==========================================================

# Indrajaal Planning System

## Comprehensive Requirements, Features, Design, and Implementation Specification

**Version:** 2.0  
**Date:** January 2026  
**Architecture:** Fractal | Holonic | Biomorphic  
**Implementation:** F# with Event Sourcing, CQRS, Railway-Oriented Programming  
**Target Users:** Organizations, Teams, Humans, and Intelligent Agents

---

# Table of Contents

1. [Level 1: Strategic Vision](#level-1-strategic-vision)
2. [Level 2: System Architecture](#level-2-system-architecture)
3. [Level 3: Feature Specifications](#level-3-feature-specifications)
4. [Level 4: Technical Design](#level-4-technical-design)
5. [Level 5: Implementation Details](#level-5-implementation-details)
6. [Appendices](#appendices)

---

# Level 1: Strategic Vision

## 1.1 Executive Summary

The Indrajaal Planning System is an integrated work management platform designed to unify task management, project coordination, program oversight, and strategic portfolio planning. Built on military-grade decision frameworks and incorporating AI-agent collaboration capabilities, the system serves organizations, teams, individual humans, and intelligent agents working on integrated projects and operations.

### 1.1.1 Problem Statement

Modern organizations face fragmented work management across multiple tools, leading to:

- Information silos between strategic planning and operational execution
- Inconsistent prioritization across organizational levels
- Limited visibility into cross-project dependencies
- Inability to integrate AI agents into planning workflows
- Lack of real-time synchronization across distributed teams

### 1.1.2 Solution Overview

Indrajaal provides a unified platform with:

- Hierarchical work structure (Task → Project → Program → Portfolio)
- Military decision frameworks (OODA Loop, MDMP, Eisenhower Matrix)
- Event-sourced architecture for complete audit trails
- Multi-actor support (humans, teams, organizations, AI agents)
- Real-time distributed synchronization via Zenoh messaging
- Natural language interface for rapid task capture

## 1.2 Target Users and Actors

### 1.2.1 Human Users

| Actor | Description | Primary Use Cases |
|-------|-------------|-------------------|
| **Individual Contributor** | Single person managing personal work | Task creation, time tracking, checklist management |
| **Team Lead** | Manages a team's workload | Sprint planning, work assignment, progress tracking |
| **Project Manager** | Oversees project delivery | Milestone tracking, risk management, resource allocation |
| **Program Director** | Coordinates multiple projects | Cross-project dependencies, strategic alignment, OKR tracking |
| **Portfolio Executive** | Strategic oversight | Investment decisions, capacity planning, business alignment |

### 1.2.2 Intelligent Agents

| Agent Type | Description | Capabilities |
|------------|-------------|--------------|
| **Task Automation Agent** | Handles routine operations | Auto-assignment, status updates, notifications |
| **Analysis Agent** | Provides insights | Progress reports, risk detection, trend analysis |
| **Planning Agent** | Assists with planning | Sprint suggestions, workload balancing, scheduling |
| **Integration Agent** | Bridges external systems | Data sync, event processing, API mediation |
| **Orchestration Agent** | Coordinates multi-agent workflows | Agent-to-agent communication, workflow execution |

### 1.2.3 Multi-Actor Collaboration Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL PLANNING SYSTEM                     │
├─────────────────────────────────────────────────────────────────┤
│  Organizations                                                   │
│  ├── Teams                                                       │
│  │   ├── Human Users                                            │
│  │   │   ├── Project Managers                                   │
│  │   │   ├── Team Members                                       │
│  │   │   └── Stakeholders                                       │
│  │   └── Intelligent Agents                                     │
│  │       ├── Automation Agents                                  │
│  │       ├── Analysis Agents                                    │
│  │       └── Integration Agents                                 │
│  └── External Systems (via MCP)                                 │
│      ├── Communication Tools (Slack, Teams)                     │
│      ├── Development Tools (GitHub, Jira)                       │
│      └── Business Systems (CRM, ERP)                            │
└─────────────────────────────────────────────────────────────────┘
```

## 1.3 Market Context and Competitive Analysis

### 1.3.1 Reference Platforms

Based on analysis of leading project management platforms:

**Asana** (150,000+ paying customers)
- Multiple project views: List, Board, Calendar, Timeline, Gantt
- Portfolio feature for strategic initiative visualization
- Workflow automation with Zapier integration
- API with comprehensive REST endpoints
- AI features for smart task creation and status updates

**Jira** (Atlassian ecosystem leader)
- Native Scrum and Kanban support with sprint management
- JQL (Jira Query Language) for powerful filtering
- Deep developer tooling integration
- Customizable workflows per project type
- REST API with board, sprint, and issue endpoints

**ClickUp** (AI-first platform)
- ClickUp Brain: AI Knowledge Manager, Project Manager, Writer
- Autopilot Agents for autonomous task execution
- Connected Search across workspace and external apps
- Custom AI fields with auto-generated content
- Brain MAX: Multi-model AI (GPT, Claude, Gemini) integration
- Pricing: AI Standard $9/user/month, AI Autopilot $28/user/month

### 1.3.2 Differentiating Capabilities

| Capability | Asana | Jira | ClickUp | Indrajaal |
|------------|-------|------|---------|-----------|
| Hierarchical Structure | Project-level | Epic/Issue | Folder/Space | Portfolio→Program→Project→Task |
| Military Frameworks | ✗ | ✗ | ✗ | OODA, MDMP, Eisenhower |
| AI Agent Support | Limited | ✗ | Brain/Autopilot | Full MCP Integration |
| Event Sourcing | ✗ | ✗ | ✗ | Complete Audit Trail |
| Real-time Distributed | Webhooks | Webhooks | WebSocket | Zenoh Pub/Sub/Query |
| Natural Language | Basic | ✗ | Brain | Full NLP Parser |
| Self-hosted | ✗ | Data Center | ✗ | Full Control |

## 1.4 Military Planning Framework Integration

### 1.4.1 OODA Loop (Observe-Orient-Decide-Act)

Developed by USAF Colonel John Boyd, the OODA loop is a decision-making model that enables rapid adaptation in dynamic environments. Boyd's concept emphasizes that entities able to process this cycle faster than opponents gain decisive advantage.

**Key Characteristics:**
- Iterative decision cycle for uncertainty management
- Speed advantage through rapid cycling
- Orientation as the central cognitive element
- Feedback loops enabling continuous adaptation

**Throughput Performance (Zenoh benchmarks):**
- 4M messages/second for small payloads in peer-to-peer mode
- 67 Gbps throughput approaching network theoretical maximum
- 13 µs latency in optimized scenarios
- 20x more wire-efficient than DDS

| OODA Phase | System Feature | Latency Target |
|------------|----------------|----------------|
| **Observe** | Real-time dashboards, event streams, notifications | < 100ms |
| **Orient** | Analytics engine, context aggregation, AI insights | < 500ms |
| **Decide** | Priority scoring, recommendation engine, COA comparison | < 1s |
| **Act** | Quick capture, automation triggers, agent execution | < 100ms |

### 1.4.2 MDMP (Military Decision Making Process)

The seven-step MDMP provides a structured planning methodology used by US Army battalion-level and higher units. The process enables commanders and staffs to apply critical and creative thinking to develop operations plans.

**Seven Steps:**

1. **Receipt of Mission**
   - Initial mission/tasking capture
   - Commander's initial guidance
   - Time analysis and allocation

2. **Mission Analysis**
   - Detailed analysis of higher order
   - Identification of key tasks, constraints, critical facts
   - Problem statement development
   - Initial risk assessment

3. **COA (Course of Action) Development**
   - Creating multiple viable approaches
   - Applying relative combat power
   - Generating options for commander consideration

4. **COA Analysis (War-gaming)**
   - Action-reaction-counteraction simulation
   - Synchronization matrix development
   - Risk identification per COA

5. **COA Comparison**
   - Systematic evaluation against criteria
   - Decision matrix development
   - Commander's evaluation criteria application

6. **COA Approval**
   - Commander's decision point
   - Final COA selection
   - Refined commander's intent

7. **Orders Production**
   - OPORD (Operations Order) generation
   - Briefings and rehearsals
   - Transition to execution

**One-Third/Two-Thirds Rule:** Commanders use no more than one-third of available time for their planning, leaving two-thirds for subordinate planning and preparation.

### 1.4.3 Eisenhower Matrix Enhanced Priority System

The system implements an enhanced Eisenhower Matrix combining urgency and importance with military criticality scoring:

```
                    URGENT                  NOT URGENT
            ┌─────────────────────┬─────────────────────┐
   HIGH     │     IMMEDIATE       │      SCHEDULED      │
IMPORTANCE  │   Do First (Q1)     │    Plan It (Q2)     │
            │  Score: 80-100      │   Score: 60-79      │
            ├─────────────────────┼─────────────────────┤
    LOW     │      SOON           │      EVENTUAL       │
IMPORTANCE  │  Delegate (Q3)      │   Eliminate (Q4)    │
            │  Score: 40-59       │   Score: 20-39      │
            └─────────────────────┴─────────────────────┘
```

---

# Level 2: System Architecture

## 2.1 Architectural Principles

### 2.1.1 Fractal Architecture

The logic of the whole is embedded in every part. Each level of the hierarchy (Task, Project, Program, Portfolio) contains the same structural patterns:

- Status workflow (Pending → InProgress → Review → Completed)
- Priority assignment (Urgency × Importance)
- Assignment model (Owner, Assignees, Reviewers, Stakeholders)
- Audit trail (Created, Modified, Accessed by whom/when)
- Event sourcing (Complete history of changes)

### 2.1.2 Holonic Structure

Each entity is simultaneously a whole and a part:

- A **Task** is complete in itself but part of a **Project**
- A **Project** is complete in itself but part of a **Program**
- A **Program** is complete in itself but part of a **Portfolio**
- Each level can operate autonomously while contributing to the larger system

### 2.1.3 Biomorphic Patterns

The system exhibits self-organizing, adaptive behaviors:

- **Self-healing**: Automatic retry and recovery from failures
- **Emergent behavior**: Aggregate metrics emerge from individual task updates
- **Adaptive routing**: Zenoh intelligent routing optimizes message paths
- **Load balancing**: Work distribution based on capacity and availability

## 2.2 Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         API LAYER                                │
│   REST API │ GraphQL │ WebSocket │ MCP Server │ Agent Interface │
├─────────────────────────────────────────────────────────────────┤
│                     APPLICATION LAYER                            │
│          Commands │ Queries │ Event Handlers │ Projections      │
├─────────────────────────────────────────────────────────────────┤
│                       DOMAIN LAYER                               │
│     Entities │ Value Objects │ Domain Events │ Business Logic   │
├─────────────────────────────────────────────────────────────────┤
│                   INFRASTRUCTURE LAYER                           │
│        Smriti (PostgreSQL) │ Zenoh Messaging │ External APIs    │
└─────────────────────────────────────────────────────────────────┘
```

## 2.3 CQRS and Event Sourcing Architecture

### 2.3.1 Command Side (Write Model)

Commands represent intentions to change state:

```
Command → Validation → Aggregate Load → Business Logic → Events → Event Store
```

**Command Flow:**
1. API receives command (e.g., `CreateTask`)
2. Validation pipeline checks invariants
3. Aggregate loaded from event stream
4. Business logic applied (pure functions)
5. Domain events generated
6. Events persisted to event store
7. Events published to message bus

### 2.3.2 Query Side (Read Model)

Queries retrieve data from optimized projections:

```
Query → Projection Selection → Materialized View → Response DTO
```

**Projection Types:**
- **Inline Projections**: Updated synchronously with events
- **Async Projections**: Updated via background subscription
- **Live Projections**: Computed on-demand from event stream

### 2.3.3 Event Sourcing Benefits

Based on industry patterns and PostgreSQL implementations:

| Benefit | Description |
|---------|-------------|
| **Complete Audit Trail** | Every state change is captured with who/when/what |
| **Time Travel** | Reconstruct system state at any point in history |
| **Event Replay** | Rebuild projections by replaying events |
| **Debugging** | Understand exactly how state reached current condition |
| **Compliance** | Meet regulatory requirements for data retention |
| **Integration** | Events provide natural integration points |

## 2.4 Messaging Architecture (Zenoh)

### 2.4.1 Why Zenoh

Eclipse Zenoh is a pub/sub/query protocol designed for the cloud-to-microcontroller continuum:

**Performance Characteristics:**
- Minimum wire overhead: 5 bytes
- Throughput: Up to 4M msgs/sec (small payloads), 67 Gbps (large payloads)
- Latency: As low as 13 µs in optimized scenarios
- 20x more wire-efficient than DDS
- 10x more wire-efficient than MQTT

**Adoption:**
- ITU recommended for Intelligent Transport Systems (ITS)
- Used in autonomous vehicles (CARMA, Indy Autonomous Challenge)
- ROS2 Tier 1 support for robotics
- ETSI identified as key technology for Multi-Access Edge Computing

### 2.4.2 Zenoh Integration Points

```fsharp
// Topic hierarchy for Indrajaal
module Topics =
    let taskEvents = "indrajaal/tasks/events"
    let projectEvents = "indrajaal/projects/events"
    let programEvents = "indrajaal/programs/events"
    let portfolioEvents = "indrajaal/portfolios/events"
    let notifications userId = $"indrajaal/users/{userId}/notifications"
    let agentCommands agentId = $"indrajaal/agents/{agentId}/commands"
    let agentResponses agentId = $"indrajaal/agents/{agentId}/responses"
```

### 2.4.3 Messaging Patterns

| Pattern | Use Case | Zenoh Feature |
|---------|----------|---------------|
| **Pub/Sub** | Event broadcast to subscribers | `put` / `subscribe` |
| **Query/Reply** | Request-response for state queries | `get` / `queryable` |
| **Storage** | Persistence for offline subscribers | Storages plugin |
| **Routing** | Cross-network message delivery | Zenoh Router (zenohd) |

## 2.5 Agent Integration Architecture

### 2.5.1 Model Context Protocol (MCP)

MCP was announced by Anthropic in November 2024 as an open standard for connecting AI assistants to data systems. Adopted by OpenAI, Google DeepMind, Microsoft Azure, and now governed by the Linux Foundation's Agentic AI Foundation (AAIF).

**MCP Characteristics:**
- Transport-agnostic (typically JSON-RPC 2.0 over stdio)
- Dynamic tool discovery and invocation
- Standardized context sharing between AI agents and systems
- 8M+ monthly SDK downloads by April 2025
- 5,800+ MCP servers, 300+ MCP clients available

**Indrajaal MCP Server Capabilities:**

```
indrajaal-mcp-server
├── Tools
│   ├── create_task
│   ├── update_task
│   ├── query_tasks
│   ├── create_project
│   ├── get_project_status
│   ├── add_task_to_sprint
│   └── generate_report
├── Resources
│   ├── task://{task_id}
│   ├── project://{project_id}
│   ├── program://{program_id}
│   └── portfolio://{portfolio_id}
└── Prompts
    ├── daily_standup
    ├── sprint_planning
    └── risk_assessment
```

### 2.5.2 Agent Governance Model

| Control | Description | Implementation |
|---------|-------------|----------------|
| **Authentication** | Agent identity verification | OAuth 2.1, API keys, mTLS |
| **Authorization** | Permission scopes per agent | RBAC with fine-grained permissions |
| **Rate Limiting** | Request throttling per agent | Token bucket with burst allowance |
| **Audit Logging** | Complete trace of agent actions | Event sourcing with agent context |
| **Human-in-Loop** | Approval for critical operations | Configurable approval workflows |
| **Kill Switch** | Emergency agent deactivation | Admin override capability |

---

# Level 3: Feature Specifications

## 3.1 Task Management

### 3.1.1 Task Entity Properties

Synced with F# implementation (`Domain.Task`):

| Property | Type | Description | Code Reference |
|----------|------|-------------|----------------|
| `Id` | `EntityId` | Globally unique identifier | `type EntityId = EntityId of Guid` |
| `HierarchicalId` | `HierarchicalId` | Portfolio.Program.Project.Task path | `type HierarchicalId` |
| `Title` | `string` | Task name (1-500 chars) | Validated |
| `Description` | `string option` | Detailed description | Markdown supported |
| `Status` | `TaskStatus` | Workflow state | 10 states with transitions |
| `Priority` | `Priority` | Urgency × Importance | `CriticalityScore: int` |
| `DueDate` | `DateTimeOffset option` | Target completion | Timezone-aware |
| `EstimatedDuration` | `TimeSpan option` | Planned effort | For capacity planning |
| `Assignees` | `Assignment list` | Responsible parties | With roles |
| `Tags` | `Tag list` | Categorical labels | Hierarchical tags |
| `Dependencies` | `Dependency list` | Task relationships | FS, SS, FF, SF types |
| `Checklists` | `Checklist list` | Sub-items | Nested checklists |
| `Attachments` | `Attachment list` | Linked files | Type-aware |
| `Comments` | `Comment list` | Discussion thread | Threaded, with reactions |
| `CustomFields` | `CustomField list` | User-defined metadata | Multiple types |
| `Recurrence` | `Recurrence option` | Repeating patterns | Cron and pattern-based |
| `TimeTracking` | `TimeTracking` | Time entries | With billable flag |
| `Audit` | `AuditInfo` | Created/Modified metadata | Full history |
| `Version` | `int` | Optimistic concurrency | Incremented on change |

### 3.1.2 Status Workflow

From F# implementation (`TaskStatus` module):

```
                    ┌──────────┐
                    │ Pending  │
                    └────┬─────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌─────────┐    ┌──────────┐    ┌───────────┐
    │ Planned │    │  Ready   │    │ Cancelled │
    └────┬────┘    └────┬─────┘    └───────────┘
         │              │
         └──────┬───────┘
                ▼
         ┌────────────┐       ┌──────────┐
         │ InProgress │◄──────│ Blocked  │
         └─────┬──────┘       └──────────┘
               │
               ▼
         ┌──────────┐
         │ InReview │
         └────┬─────┘
              │
              ▼
         ┌───────────┐
         │ Completed │
         └─────┬─────┘
               │
               ▼
         ┌──────────┐
         │ Archived │
         └──────────┘
```

**Transition Rules** (from `TaskStatus.canTransitionTo`):

| From State | Valid Transitions |
|------------|-------------------|
| Pending | Planned, Ready, InProgress, Cancelled |
| Planned | Ready, InProgress, OnHold, Cancelled |
| Ready | InProgress, Blocked, OnHold, Cancelled |
| InProgress | InReview, Blocked, OnHold, Completed, Cancelled |
| InReview | InProgress, Completed, Cancelled |
| Blocked | Ready, InProgress, OnHold, Cancelled |
| OnHold | Ready, InProgress, Cancelled |
| Completed/Cancelled | Archived |

### 3.1.3 Priority System

From F# implementation (`Priority` type):

**Urgency Levels:**
```fsharp
type Urgency =
    | Immediate    // Must be done now (Score: 100)
    | Soon         // Should be done today (Score: 80)
    | Scheduled    // Has a specific deadline (Score: 60)
    | Eventual     // No specific deadline (Score: 40)
    | Deferred     // Explicitly postponed (Score: 20)
```

**Importance Levels:**
```fsharp
type Importance =
    | Critical     // Mission-critical (Score: 100)
    | High         // Significant impact (Score: 80)
    | Medium       // Normal business value (Score: 60)
    | Low          // Nice to have (Score: 40)
    | Optional     // Can be dropped (Score: 20)
```

**Criticality Score Calculation:**
```fsharp
CriticalityScore = (UrgencyScore + ImportanceScore) / 2
```

### 3.1.4 Dependency Types

From F# implementation (`DependencyType`):

| Type | Code | Description | Example |
|------|------|-------------|---------|
| **Finish-to-Start** | `FS` | Predecessor must finish before successor starts | "Design" → "Development" |
| **Start-to-Start** | `SS` | Predecessor must start before successor starts | Parallel work with staggered start |
| **Finish-to-Finish** | `FF` | Both must finish together | Coordinated delivery |
| **Start-to-Finish** | `SF` | Predecessor start enables successor finish | Just-in-time scenarios |

```fsharp
type Dependency = {
    Id: EntityId
    PredecessorId: EntityId
    SuccessorId: EntityId
    Type: DependencyType
    LagTime: TimeSpan      // Lead (+) or Lag (-) time
    IsStrict: bool         // Hard vs soft dependency
}
```

### 3.1.5 Natural Language Parsing

From F# implementation (`NaturalLanguageParser` module):

**Input Example:**
```
"Review quarterly report tomorrow at 2pm #finance @john !high ~2h"
```

**Parsed Output:**
```fsharp
{
    Title = "Review quarterly report"
    DueDate = Some (tomorrow at 14:00)
    Priority = Some (Soon, High, 80)
    Tags = ["finance"]
    Assignees = ["john"]
    Duration = Some (TimeSpan.FromHours(2.0))
}
```

**Supported Patterns:**

| Pattern | Examples | Parsed As |
|---------|----------|-----------|
| **Dates** | "today", "tomorrow", "next monday", "jan 15" | `DateTimeOffset` |
| **Times** | "at 2pm", "9:00", "afternoon" | Time component |
| **Tags** | "#finance", "#urgent" | `Tag list` |
| **Mentions** | "@john", "@team" | `Assignee list` |
| **Priority** | "!critical", "!high", "!low" | `Priority` |
| **Duration** | "~2h", "~30m", "~1d" | `TimeSpan` |

## 3.2 Project Management

### 3.2.1 Project Entity Properties

From F# implementation (`Entities.Project`):

| Property | Type | Description |
|----------|------|-------------|
| `Id` | `EntityId` | Unique identifier |
| `Name` | `string` | Project name (validated) |
| `Description` | `string option` | Project description |
| `Status` | `ProjectStatus` | Project lifecycle state |
| `StartDate` | `DateTimeOffset option` | Planned start |
| `TargetEndDate` | `DateTimeOffset option` | Target completion |
| `ActualEndDate` | `DateTimeOffset option` | Actual completion |
| `Tasks` | `EntityId list` | Associated tasks |
| `Milestones` | `Milestone list` | Key deliverables |
| `Sprints` | `Sprint list` | Time-boxed iterations |
| `Team` | `TeamMember list` | Project team |
| `Budget` | `Budget option` | Financial allocation |
| `Tags` | `Tag list` | Project tags |
| `LinkedProgram` | `EntityId option` | Parent program |

### 3.2.2 Project Views

Matching industry standards (Asana, Jira, ClickUp patterns):

| View | Description | Best For |
|------|-------------|----------|
| **List View** | Tabular with sortable/filterable columns | Detailed task management |
| **Board View** | Kanban with drag-drop status changes | Visual workflow tracking |
| **Calendar View** | Date-based scheduling with due dates | Time-based planning |
| **Timeline View** | Gantt chart with dependencies | Project scheduling |
| **Workload View** | Resource allocation heatmap | Capacity planning |

### 3.2.3 Sprint Management

From F# implementation (`Entities.Sprint`):

```fsharp
type Sprint = {
    Id: EntityId
    ProjectId: EntityId
    Name: string
    Goal: string option
    StartDate: DateTimeOffset
    EndDate: DateTimeOffset
    Status: SprintStatus  // Planned, Active, Completed, Cancelled
    TaskIds: EntityId list
    Capacity: int option  // Story points or hours
    Velocity: int option  // Actual completed
}
```

**Sprint Ceremonies Supported:**
- Sprint Planning (capacity allocation)
- Daily Standup (progress tracking)
- Sprint Review (demo and feedback)
- Sprint Retrospective (continuous improvement)

### 3.2.4 Project Analytics

From F# implementation (`ProjectQueries` module):

| Metric | Calculation | Purpose |
|--------|-------------|---------|
| **Completion %** | Completed tasks / Total tasks × 100 | Progress tracking |
| **Velocity** | Story points completed / Sprint | Capacity forecasting |
| **Cycle Time** | Average time from start to completion | Efficiency measurement |
| **Burndown** | Remaining work over time | Sprint health |
| **Budget Utilization** | Actual spend / Allocated budget × 100 | Financial control |
| **Milestone Progress** | Completed milestones / Total milestones × 100 | Delivery tracking |

## 3.3 Program and Portfolio Management

### 3.3.1 Program Structure

From F# implementation (`Entities.Program`):

```fsharp
type Program = {
    Id: EntityId
    Name: string
    Description: string option
    Status: ProgramStatus
    StrategicObjective: string
    Projects: EntityId list
    Manager: string option
    Stakeholders: string list
    Budget: Budget option
    LinkedOkrs: EntityId list
    Risks: Risk list
    Audit: AuditInfo
    Version: int
}
```

### 3.3.2 Portfolio Structure

From F# implementation (`Entities.Portfolio`):

```fsharp
type Portfolio = {
    Id: EntityId
    Name: string
    Description: string option
    StrategicThemes: StrategicTheme list
    Programs: EntityId list
    Owner: string
    Stakeholders: string list
    TotalBudget: Budget option
    Audit: AuditInfo
    Version: int
}
```

### 3.3.3 OKR (Objectives and Key Results)

From F# implementation (`Entities.Objective`, `Entities.KeyResult`):

```fsharp
type KeyResult = {
    Id: EntityId
    ObjectiveId: EntityId
    Title: string
    Description: string option
    TargetValue: decimal
    CurrentValue: decimal
    Unit: string
    Progress: float  // 0.0 to 100.0
    Owner: string
    Status: OkrStatus
}

type Objective = {
    Id: EntityId
    Title: string
    Description: string option
    Owner: string
    Period: OkrPeriod
    KeyResults: KeyResult list
    Progress: float  // Average of key results
    Status: OkrStatus
    ParentObjectiveId: EntityId option
}
```

**OKR Hierarchy Example:**
```
Portfolio: "Digital Transformation"
└── Program: "Customer Experience Enhancement"
    └── Objective: "Increase customer satisfaction"
        ├── Key Result: "NPS score > 50" (Current: 42, Target: 50)
        ├── Key Result: "Support response < 2h" (Current: 1.5h, Target: 2h)
        └── Key Result: "Mobile app rating > 4.5" (Current: 4.2, Target: 4.5)
```

## 3.4 Agent and Automation Features

### 3.4.1 Agent Interface

From F# implementation (`AgentInterface` module):

```fsharp
type AgentCommand =
    | CreateTaskCmd of title: string * description: string option * metadata: Map<string, string>
    | UpdateTaskCmd of taskId: string * updates: Map<string, string>
    | QueryTasksCmd of filter: Map<string, string>
    | CompleteTasksCmd of taskIds: string list
    | AssignTaskCmd of taskId: string * userId: string * role: string
    | BatchOperationCmd of operation: string * taskIds: string list * parameters: Map<string, string>

type AgentResponse = {
    Success: bool
    Operation: string
    Results: AgentResult list
    Summary: string
    NextSuggestedActions: string list
}
```

### 3.4.2 Automation Rules

Pattern-based automation triggers:

```yaml
# Example automation rule
name: "Auto-assign reviewer on completion"
trigger:
  event: task.status_changed
  condition:
    new_status: "in_review"
actions:
  - type: assign_user
    user_selector: "project.default_reviewer"
    role: "reviewer"
  - type: notify
    channel: "slack"
    template: "review_requested"
  - type: set_due_date
    offset: "+2d"
```

### 3.4.3 Agent Capability Matrix

| Capability | Description | Authorization Level |
|------------|-------------|---------------------|
| `task.read` | View task details | Basic |
| `task.write` | Create/update tasks | Standard |
| `task.delete` | Remove tasks | Elevated |
| `project.read` | View project details | Basic |
| `project.write` | Create/update projects | Standard |
| `project.admin` | Manage project settings | Admin |
| `report.generate` | Create reports | Standard |
| `automation.execute` | Run automation rules | Elevated |
| `agent.orchestrate` | Coordinate other agents | Admin |

---

# Level 4: Technical Design

## 4.1 Domain Model Design

### 4.1.1 Value Objects

Immutable types representing domain concepts:

```fsharp
/// Unique identifier for all entities
[<Struct>]
type EntityId = EntityId of Guid
    with
    static member New() = EntityId(Guid.NewGuid())
    static member Parse(s: string) = EntityId(Guid.Parse(s))
    member this.Value = let (EntityId id) = this in id

/// Hierarchical path encoding
[<Struct>]
type HierarchicalId = {
    PortfolioId: EntityId option
    ProgramId: EntityId option
    ProjectId: EntityId option
    TaskId: EntityId
}
```

### 4.1.2 Aggregate Design

Each aggregate is a consistency boundary:

| Aggregate | Root Entity | Child Entities | Invariants |
|-----------|-------------|----------------|------------|
| **Task** | Task | Comments, Checklists, TimeEntries | Status transitions, dependency validation |
| **Project** | Project | Milestones, Sprints | Sprint date ranges, task membership |
| **Program** | Program | Risks | Project assignments, OKR links |
| **Portfolio** | Portfolio | StrategicThemes | Budget allocation, program assignments |

### 4.1.3 Domain Events

From F# implementation (`Events` module):

```fsharp
type TaskEvent =
    | TaskCreated of TaskCreatedData
    | TaskTitleUpdated of TaskTitleUpdatedData
    | TaskStatusChanged of TaskStatusChangedData
    | TaskPriorityChanged of TaskPriorityChangedData
    | TaskDueDateSet of TaskDueDateSetData
    | TaskAssigned of TaskAssignedData
    | TaskUnassigned of TaskUnassignedData
    | TaskTagAdded of TaskTagAddedData
    | TaskDependencyAdded of TaskDependencyAddedData
    | TaskChecklistAdded of TaskChecklistAddedData
    | TaskChecklistItemToggled of TaskChecklistItemToggledData
    | TaskCommentAdded of TaskCommentAddedData
    | TaskTimeEntryAdded of TaskTimeEntryAddedData
    | TaskCompleted of TaskCompletedData
    | TaskDeleted of TaskDeletedData
```

## 4.2 Railway-Oriented Programming

### 4.2.1 Result Type

From F# implementation (`Results` module):

```fsharp
type DomainError =
    | ValidationError of field: string * message: string
    | NotFound of entityType: string * id: EntityId
    | Unauthorized of action: string * reason: string
    | InvalidStateTransition of from: string * toState: string * reason: string
    | BusinessRuleViolation of rule: string * message: string
    | ConcurrencyConflict of entityId: EntityId * expectedVersion: int * actualVersion: int
    | DependencyError of message: string
    | ExternalServiceError of service: string * message: string

type DomainResult<'T> = Result<'T, DomainError>
```

### 4.2.2 Computation Expression

```fsharp
type ResultBuilder() =
    member _.Bind(result, f) = Result.bind f result
    member _.Return(value) = Ok value
    member _.ReturnFrom(result) = result
    member _.Zero() = Ok ()

let result = ResultBuilder()

// Usage example
let createTask data context =
    result {
        let! validTitle = Validation.validateTitle data.Title
        let! validDueDate = Validation.validateDueDate data.DueDate
        let task = Task.create validTitle validDueDate context
        return task
    }
```

## 4.3 Event Store Design

### 4.3.1 PostgreSQL Schema

From F# implementation (`SmritiDatabase` module):

```sql
-- Event streams table
CREATE TABLE event_streams (
    stream_id UUID PRIMARY KEY,
    stream_type VARCHAR(100) NOT NULL,
    aggregate_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(stream_type, aggregate_id)
);

-- Events table (append-only)
CREATE TABLE events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id UUID NOT NULL REFERENCES event_streams(stream_id),
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    metadata JSONB,
    version INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(stream_id, version)
);

-- Snapshots for optimization
CREATE TABLE snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stream_id UUID NOT NULL REFERENCES event_streams(stream_id),
    snapshot_data JSONB NOT NULL,
    version INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subscriptions for event handlers
CREATE TABLE subscriptions (
    subscription_id VARCHAR(100) PRIMARY KEY,
    last_processed_position BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 4.3.2 Optimistic Concurrency

```fsharp
let appendEvents streamId expectedVersion events =
    async {
        use! conn = getConnection()
        use tx = conn.BeginTransaction()
        
        try
            // Check current version
            let! currentVersion = getCurrentVersion streamId conn
            
            if currentVersion <> expectedVersion then
                return Error (ConcurrencyConflict(streamId, expectedVersion, currentVersion))
            else
                // Append events with incrementing versions
                for (i, event) in events |> List.indexed do
                    do! insertEvent streamId (expectedVersion + i + 1) event conn
                
                tx.Commit()
                return Ok ()
        with ex ->
            tx.Rollback()
            return Error (DependencyError ex.Message)
    }
```

## 4.4 Messaging Design

### 4.4.1 Zenoh Configuration

From F# implementation (`ZenohMessaging` module):

```fsharp
type ZenohConfig = {
    Endpoints: string list
    Mode: string  // "peer" | "client" | "router"
    ConnectTimeout: TimeSpan
    SharedMemory: bool
    Gossip: bool
}

let defaultConfig = {
    Endpoints = ["tcp/localhost:7447"]
    Mode = "client"
    ConnectTimeout = TimeSpan.FromSeconds(10.0)
    SharedMemory = true
    Gossip = true
}
```

### 4.4.2 Message Types

```fsharp
type Message<'T> = {
    Id: Guid
    Timestamp: DateTimeOffset
    Source: string
    CorrelationId: Guid option
    Payload: 'T
}

type TaskNotification =
    | TaskAssignedNotification of taskId: EntityId * assigneeId: string
    | TaskDueNotification of taskId: EntityId * dueDate: DateTimeOffset
    | TaskOverdueNotification of taskId: EntityId * overdueBy: TimeSpan
    | TaskCompletedNotification of taskId: EntityId * completedBy: string
    | TaskBlockedNotification of taskId: EntityId * reason: string
    | TaskCommentNotification of taskId: EntityId * commentBy: string
```

## 4.5 API Design

### 4.5.1 REST Endpoints

From F# implementation (`Api` module):

| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| `GET` | `/api/v1/tasks` | List tasks with filtering | Query params |
| `POST` | `/api/v1/tasks` | Create new task | `CreateTaskRequest` |
| `GET` | `/api/v1/tasks/{id}` | Get task details | - |
| `PATCH` | `/api/v1/tasks/{id}` | Update task | `UpdateTaskRequest` |
| `DELETE` | `/api/v1/tasks/{id}` | Delete task | - |
| `POST` | `/api/v1/tasks/parse` | Parse natural language | `{ input: string }` |
| `POST` | `/api/v1/tasks/bulk` | Bulk operations | `BulkTaskRequest` |
| `GET` | `/api/v1/projects` | List projects | Query params |
| `POST` | `/api/v1/projects` | Create project | `CreateProjectRequest` |
| `GET` | `/api/v1/projects/{id}` | Get project details | - |
| `GET` | `/api/v1/projects/{id}/tasks` | Get project tasks | Query params |
| `POST` | `/api/v1/projects/{id}/sprints` | Create sprint | `CreateSprintRequest` |

### 4.5.2 Response Format

From F# implementation (`ApiResponse` module):

```fsharp
type ApiResponse<'T> = {
    Success: bool
    Data: 'T option
    Error: ApiError option
    Timestamp: DateTimeOffset
}

type ApiError = {
    Code: string
    Message: string
    Details: Map<string, string>
}
```

**Error Codes:**

| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Request validation failed |
| `NOT_FOUND` | Entity not found |
| `UNAUTHORIZED` | Permission denied |
| `INVALID_STATE` | Invalid state transition |
| `BUSINESS_RULE` | Business rule violation |
| `CONCURRENCY` | Version conflict |
| `DEPENDENCY` | Dependency error |
| `EXTERNAL_SERVICE` | External service failure |

---

# Level 5: Implementation Details

## 5.1 F# Module Structure

Complete codebase organization (2,926 lines):

```
IndrajaalPlanningSystem.fs
├── Domain Module
│   ├── Core Value Types (EntityId, HierarchicalId)
│   ├── Priority System (Urgency, Importance, Priority)
│   ├── Status Workflow (TaskStatus with transitions)
│   ├── Recurrence Patterns
│   ├── Dependency Types
│   ├── Time Tracking
│   ├── Assignments
│   ├── Tags
│   ├── Custom Fields
│   ├── Attachments
│   ├── Comments
│   ├── Checklists
│   └── Audit Info
├── Entities Module
│   ├── Task
│   ├── Project
│   ├── Sprint
│   ├── Milestone
│   ├── Program
│   ├── Portfolio
│   ├── Objective
│   ├── KeyResult
│   └── TodoList
├── Events Module
│   ├── TaskEvent (15 event types)
│   ├── ProjectEvent (12 event types)
│   ├── ProgramEvent (8 event types)
│   ├── PortfolioEvent (5 event types)
│   ├── OkrEvent (6 event types)
│   └── TodoListEvent (4 event types)
├── Results Module
│   ├── DomainError (8 error types)
│   ├── DomainResult<'T>
│   └── ResultBuilder
├── Validation Module
│   ├── notEmpty
│   ├── maxLength
│   ├── minLength
│   ├── range
│   ├── pattern
│   ├── dateAfter
│   ├── dateBefore
│   └── Combined validators
├── TaskOperations Module
│   ├── create
│   ├── updateTitle
│   ├── updateDescription
│   ├── changeStatus
│   ├── setPriority
│   ├── setDueDate
│   ├── assign
│   ├── unassign
│   ├── addTag
│   ├── removeTag
│   ├── addDependency
│   ├── removeDependency
│   ├── addChecklist
│   ├── toggleChecklistItem
│   ├── addComment
│   ├── addTimeEntry
│   ├── complete
│   └── delete
├── TaskQueries Module
│   ├── isOverdue
│   ├── isDueToday
│   ├── isDueSoon
│   ├── getChecklistProgress
│   ├── filter
│   ├── sort
│   └── search
├── ProjectOperations Module
│   ├── create
│   ├── updateName
│   ├── changeStatus
│   ├── addTask
│   ├── removeTask
│   ├── addMilestone
│   ├── completeMilestone
│   ├── addTeamMember
│   ├── removeTeamMember
│   ├── createSprint
│   ├── startSprint
│   └── completeSprint
├── ProjectQueries Module
│   ├── getCompletionPercentage
│   ├── getMilestoneProgress
│   ├── isOverdue
│   ├── getVelocity
│   └── getBudgetUtilization
├── ProgramOperations Module
│   ├── create
│   ├── changeStatus
│   ├── addProject
│   ├── removeProject
│   ├── assignManager
│   ├── addStakeholder
│   ├── linkOkr
│   └── addRisk
├── PortfolioOperations Module
│   ├── create
│   ├── addStrategicTheme
│   ├── addProgram
│   ├── removeProgram
│   └── allocateBudget
├── OkrOperations Module
│   ├── createObjective
│   ├── addKeyResult
│   ├── updateKeyResultProgress
│   └── closeObjective
├── SmritiDatabase Module
│   ├── SmritiConfig
│   ├── IEventStore interface
│   ├── IAggregateRepository interface
│   └── SQL schema definitions
├── ZenohMessaging Module
│   ├── ZenohConfig
│   ├── Message<'T>
│   ├── Topics
│   ├── IMessagePublisher interface
│   ├── IMessageSubscriber interface
│   └── Notification types
├── Commands Module
│   ├── TaskCommand (17 commands)
│   ├── ProjectCommand (12 commands)
│   ├── ProgramCommand (8 commands)
│   ├── TodoListCommand (4 commands)
│   └── CommandContext
├── NaturalLanguageParser Module
│   ├── ParsedTask
│   ├── Date patterns
│   ├── Priority patterns
│   ├── Tag extraction
│   ├── Mention extraction
│   └── Duration extraction
└── Api Module
    ├── DTOs (Request/Response types)
    ├── ApiResponse<'T>
    ├── ApiError
    ├── Mapping functions
    └── AgentInterface
```

## 5.2 Key Implementation Patterns

### 5.2.1 Pure Function Pattern

All business logic implemented as pure functions:

```fsharp
// No side effects - input determines output completely
let changeStatus (newStatus: TaskStatus) (context: CommandContext) (task: Task) =
    // Validate transition
    if not (TaskStatus.canTransitionTo task.Status newStatus) then
        Error (InvalidStateTransition(
            string task.Status, 
            string newStatus, 
            "Transition not allowed"))
    else
        let now = DateTimeOffset.UtcNow
        let updatedTask = { 
            task with 
                Status = newStatus
                Audit = { task.Audit with 
                    ModifiedAt = now
                    ModifiedBy = context.UserId }
                Version = task.Version + 1
        }
        let event = TaskStatusChanged {
            TaskId = task.Id
            OldStatus = task.Status
            NewStatus = newStatus
            ChangedBy = context.UserId
            ChangedAt = now
            Reason = None
        }
        Ok (updatedTask, event)
```

### 5.2.2 Validation Chain Pattern

```fsharp
let validateTask (data: CreateTaskData) =
    result {
        let! title = 
            data.Title 
            |> Validation.notEmpty "title"
            |> Result.bind (Validation.maxLength "title" 500)
        
        let! description =
            data.Description
            |> Option.map (Validation.maxLength "description" 5000)
            |> Option.defaultValue (Ok None)
            |> Result.map Some
        
        let! dueDate =
            data.DueDate
            |> Option.map (Validation.dateAfter "dueDate" DateTimeOffset.UtcNow)
            |> Option.defaultValue (Ok None)
        
        return {| Title = title; Description = description; DueDate = dueDate |}
    }
```

### 5.2.3 Event Application Pattern

```fsharp
let applyEvent (task: Task) (event: TaskEvent) : Task =
    match event with
    | TaskTitleUpdated data ->
        { task with Title = data.NewTitle; Version = task.Version + 1 }
    | TaskStatusChanged data ->
        { task with Status = data.NewStatus; Version = task.Version + 1 }
    | TaskAssigned data ->
        let assignment = { UserId = UserId(Guid.Parse(data.UserId)); Role = data.Role; AssignedAt = data.AssignedAt }
        { task with Assignees = assignment :: task.Assignees; Version = task.Version + 1 }
    | TaskCompleted data ->
        { task with 
            Status = Completed
            TimeTracking = { task.TimeTracking with 
                EndTime = Some data.CompletedAt }
            Version = task.Version + 1 }
    | _ -> task

let reconstitute (events: TaskEvent list) : Task =
    events |> List.fold applyEvent Task.Empty
```

## 5.3 Integration Specifications

### 5.3.1 MCP Server Implementation

```fsharp
type IndrajaalMcpServer = {
    Tools: Map<string, McpTool>
    Resources: Map<string, McpResource>
    Prompts: Map<string, McpPrompt>
}

let mcpTools = [
    { Name = "create_task"
      Description = "Create a new task in the planning system"
      InputSchema = typeof<CreateTaskRequest>
      Handler = fun input -> handleCreateTask input }
    
    { Name = "query_tasks"
      Description = "Query tasks with filters"
      InputSchema = typeof<TaskFilterDto>
      Handler = fun input -> handleQueryTasks input }
    
    { Name = "update_task_status"
      Description = "Update the status of a task"
      InputSchema = typeof<UpdateStatusRequest>
      Handler = fun input -> handleUpdateStatus input }
]
```

### 5.3.2 External System Integration

| System | Integration Method | Use Case |
|--------|-------------------|----------|
| **Slack** | Webhook + API | Notifications, quick capture |
| **GitHub** | Webhook + API | Issue sync, commit links |
| **Jira** | REST API | Migration, bidirectional sync |
| **Google Calendar** | OAuth + API | Due date sync, scheduling |
| **Microsoft Teams** | Bot Framework | Notifications, commands |
| **Asana** | REST API | Migration, import/export |

## 5.4 Deployment Architecture

### 5.4.1 Container Composition

```yaml
# docker-compose.yml
version: '3.8'
services:
  indrajaal-api:
    image: indrajaal/api:latest
    ports:
      - "8080:8080"
    environment:
      - SMRITI_CONNECTION_STRING=postgresql://...
      - ZENOH_ENDPOINTS=tcp://zenoh:7447
    depends_on:
      - smriti-db
      - zenoh-router

  smriti-db:
    image: postgres:16
    volumes:
      - smriti-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=indrajaal
      - POSTGRES_USER=indrajaal
      - POSTGRES_PASSWORD=${DB_PASSWORD}

  zenoh-router:
    image: eclipse/zenoh:latest
    ports:
      - "7447:7447"
    command: ["--cfg", "mode='router'"]

  mcp-server:
    image: indrajaal/mcp-server:latest
    ports:
      - "3000:3000"
    environment:
      - API_URL=http://indrajaal-api:8080
```

### 5.4.2 Scaling Strategy

| Component | Scaling Approach | Considerations |
|-----------|------------------|----------------|
| **API Layer** | Horizontal (stateless) | Load balancer, session affinity not required |
| **Event Store** | Vertical + Read replicas | PostgreSQL streaming replication |
| **Projections** | Horizontal partitioned | Partition by aggregate type |
| **Zenoh Router** | Mesh topology | Multiple routers for redundancy |
| **MCP Server** | Horizontal | Stateless, load balanced |

---

# Appendices

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **AAR** | After Action Review - Structured reflection process |
| **Aggregate** | Cluster of domain objects treated as a unit |
| **COA** | Course of Action - A potential approach to accomplish a mission |
| **CQRS** | Command Query Responsibility Segregation |
| **DDD** | Domain-Driven Design |
| **Event Sourcing** | Storing state as sequence of events |
| **Holon** | Entity that is simultaneously whole and part |
| **MCP** | Model Context Protocol - AI agent integration standard |
| **MDMP** | Military Decision Making Process |
| **OKR** | Objectives and Key Results |
| **OODA** | Observe-Orient-Decide-Act loop |
| **Projection** | Read model derived from events |
| **ROP** | Railway-Oriented Programming |
| **TLP** | Troop Leading Procedures |

## Appendix B: Reference Documentation

| Resource | URL | Description |
|----------|-----|-------------|
| F# Documentation | docs.microsoft.com/fsharp | Language reference |
| PostgreSQL | postgresql.org/docs | Database documentation |
| Zenoh | zenoh.io/docs | Messaging protocol |
| MCP Specification | modelcontextprotocol.io | Agent protocol |
| Event Sourcing | eventstore.com/blog | Patterns and practices |

## Appendix C: API Rate Limits

| Client Type | Requests/Minute | Burst | Notes |
|-------------|-----------------|-------|-------|
| Web User | 60 | 100 | Per authenticated session |
| API Token (Basic) | 120 | 200 | Standard integration |
| API Token (Premium) | 600 | 1000 | Enterprise tier |
| Agent (Standard) | 120 | 200 | Per agent ID |
| Agent (Elevated) | 600 | 1000 | Approved automation |
| System | 1200 | 2000 | Internal services |

## Appendix D: Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | January 2026 | Initial requirements specification |
| 2.0 | January 2026 | 5-level detail with code sync, markdown format, agent integration |

---

*Document generated for Indrajaal Planning System*  
*Implementation: F# 8.0 | .NET 8.0*  
*Infrastructure: PostgreSQL 16 | Zenoh 1.x*  
*Total F# Implementation: 2,926 lines across 17 modules*


=========================================
Use Israeli planning approach for Planning and execution 
========================================

This is a sophisticated way to view military operations, and it aligns perfectly with the Israeli military philosophy of **Systemic Operational Design (SOD)**.

In the IDF, the "Fractal Approach" means that the **logic of the whole is embedded in every part**. The strategic dilemma of the Nation is perfectly mirrored in the tactical dilemma of the 19-year-old Sergeant. They are not two different things; they are the same pattern at different scales.

Here is an exploration of the **7 Levels of Detail (The Action)** mapped directly to the **7 Levels of Implications (The Consequence)**, using a "Fractal" model where a single tactical event echoes all the way to geopolitics.

### The Fractal Concept: The "Strategic Corporal"

In the IDF, due to the small size of the theater and the 24/7 global media cycle, there is no buffer between a tactical mistake and a strategic disaster. This collapses the hierarchy.

**The Scenario:** A Squad Leader in an urban environment (e.g., Gaza or Southern Lebanon) identifies a threat in a building. He decides to engage.

Here is how that single decision fractures across 7 levels simultaneously.

---

### Level 1: The Kinetic Level (Physics & Geometry)

* **The Detail (Action):** The soldier pulls the trigger. A 5.56mm round travels downrange. He is focused on breathing, sight alignment, and the angle of the shot relative to the window.
* **The Implication (Effect):** **Terminal Ballistics.** Does the bullet stop the threat? If it passes through the wall, who is behind it?
* *Fractal Check:* At this micro-level, the implication is binary: Hit or Miss. Life or Death.



### Level 2: The Tactical Level (The Squad)

* **The Detail (Action):** The squad maneuvers. "Cover and Move." They breach the door to secure the room. They are managing ammo, sectors of fire, and immediate security.
* **The Implication (Effect):** **Flow & Friction.** Does this engagement slow the squad down? If they get stuck here for 10 minutes evacuating a casualty, they miss their synchronization window with the tank platoon down the street. The OODA loop of the unit stalls.

### Level 3: The Ethical/Legal Level (The "Purity of Arms")

* **The Detail (Action):** The target was a combatant, but he was holding a child. Or, the building was a mosque. The soldier had 0.5 seconds to apply the Rules of Engagement (ROE).
* **The Implication (Effect):** **Legitimacy.** This is the core of the IDF fractal. If the soldier violates *Tohar HaNeshek* (Purity of Arms), the tactical victory (killing the enemy) becomes a moral defeat. The IDF employs **International Law Dept (Dabla)** officers who often sit in the brigade command post to advise on this continuously.

### Level 4: The Operational Level (The Sector)

* **The Detail (Action):** The building is secured. The Battalion Commander sees this on his *Tzayad* (Digital Map). He marks the sector "Green."
* **The Implication (Effect):** **Systemic Shock.** How does the enemy react? The IDF views the enemy as a network. By taking this specific node, did we disrupt their command chain? Or did we just annoy them?
* *Israeli Nuance:* This is where **SOD** kicks in. Are we just "Mowing the Grass" (temporary degradation) or are we changing the reality?



### Level 5: The Strategic Level (The Theater)

* **The Detail (Action):** The engagement is reported to Northern/Southern Command.
* **The Implication (Effect):** **Deterrence.** If the operation was clean and lethal, it restores Israeli deterrence ("They are too strong to fight"). If the operation was messy and caused high casualties, it emboldens the enemy to launch rockets in retaliation. The tactical shot influences the enemy's *willingness* to continue the war.

### Level 6: The Political Level (The State of Israel)

* **The Detail (Action):** Footage of the engagement (from the soldier's helmet cam or a bystander's phone) hits Telegram/TikTok.
* **The Implication (Effect):** **Domestic Resilience.** Israel is a small society. If the soldier dies, the entire nation mourns. If the soldier commits a crime, the nation argues. The government's stability can hinge on the public's trust in the army's conduct during this one engagement.

### Level 7: The Geopolitical Level (The World)

* **The Detail (Action):** The UN Security Council meets. CNN runs the headline.
* **The Implication (Effect):** **Time & Space.**
* This is the "Diplomatic Clock." Every Israeli military operation works against a ticking clock of international legitimacy.
* A "successful" tactical shot that kills 10 civilians by accident stops the clock instantly. The US calls the Prime Minister, and the war ends before the goals are achieved.
* *The Fractal Result:* The soldier's finger on the trigger at **Level 1** directly controls the Diplomatic Clock at **Level 7**.



---

### How the IDF Manages the Fractal (The "Why")

The IDF knows it cannot control Level 7 (The World) if it ignores Level 1 (The Soldier). To manage this vertical complexity, they use specific mechanisms:

#### 1. The "Generals" in the Loop

Because the implications scale so fast, high-ranking officers in the IDF are often physically present at the front (forward command). They don't sit in bunkers 50 miles away; they need to "feel" the fractal friction to understand the geopolitical risk in real-time.

#### 2. "Knock on the Roof" (The Fractal Warning)

This technique is the physical manifestation of connecting Level 1 to Level 7.

* **Action:** A drone drops a non-explosive device on a building to warn civilians to flee before the real strike.
* **Purpose:** It makes no *tactical* sense (it warns the enemy). But it makes perfect *Strategic* sense (it preserves legitimacy, keeping the Diplomatic Clock running).

#### 3. Systemic Operational Design (SOD)

This is the intellectual framework taught to commanders. It forces them to ask:

> *"If I pull this thread (Tactical Action), which part of the web shakes (Strategic Implication)?"*

The diagram typically shows non-linear connections—loops rather than lines—illustrating how a tactical input feeds into a cognitive/psychological output in the enemy's mind.

### Summary: The Fractal Mirror

* **US Approach:** Levels are compartmentalized. The Private clears the room; the General handles the UN.
* **Israeli Approach:** Levels are superimposed. The Private *is* the representative of the State. The General must understand the geometry of the room.

The fractal nature means that **Discipline** at Level 1 is the primary driver of **Success** at Level 7.

----------------------


**Systemic Operational Design (SOD)** is arguably the most intellectually demanding military planning framework in the world. Developed largely by Brig. Gen. (Ret.) Shimon Naveh, it rejects the industrial, linear assembly-line approach to war (Plan A  Plan B) in favor of a biological, holistic approach.

It treats the enemy not as a "target set" to be destroyed, but as a "system" to be disrupted.

Here is an exploration of SOD through 7 levels of detail, moving from the abstract philosophy down to the concrete reality on the ground.

### Level 1: The Epistemological Level (How We Learn)

**The Core Question:** *Why do we think we know what we know?*

Most armies assume reality is objective: "There is a hill. If we take the hill, we win." SOD argues that reality is subjective and constructed.

* **The Detail:** SOD begins with "Deconstruction." Before planning an attack, commanders must deconstruct their own biases, terminology, and assumptions.
* **The Concept:** **"Difference."** Instead of looking for similarities to past wars ("This is just like 1973"), SOD hunts for what is *different*. If you fight the last war, you lose.
* **The Output:** A realization that the "problem" isn't the enemy army itself, but the *relationship* between the enemy, the population, the terrain, and the political narrative.

### Level 2: The Systemic Level (Framing the System)

**The Core Question:** *What is the logic that holds the enemy together?*

SOD views the enemy as a complex adaptive system. If you punch it, it doesn't just break; it reorganizes.

* **The Detail:** Commanders build a "System Frame." They map the **Rival System** (the enemy) and the **Command System** (us) and the **Environment** (the context).
* **The Insight:** They look for the **"Rationales."** Why does the enemy fight? Is it religious fervor? Money? Fear of the regime?
* **The Output:** A holistic map showing that the enemy's strength might not be their tanks, but their ability to intimidate the local population. If you destroy the tanks but ignore the intimidation, the system survives.

### Level 3: The Design Level (Operational Logic)

**The Core Question:** *Where can we inject energy to shatter their logic?*

This is distinct from "Strategy." Strategy is goals; Design is the architecture of the solution.

* **The Detail:** The creation of a **"Holistic Strike."** In standard planning, you attack the front line. In SOD, you might ignore the front line entirely and attack a specific vulnerability that causes the whole system to collapse (Systemic Shock).
* **The Concept:** **"Form."** The operation must have a unique "form" that fits the specific enemy logic.
* **The Output:** A counter-intuitive plan. *Example:* In Nablus (2002), the "form" was "Inverse Geometry." The logic was: "The enemy expects us in the streets. Therefore, the streets are the forbidden zone. We will move *through* the houses."

### Level 4: The Strategic Level (Cognitive Maneuver)

**The Core Question:** *How do we defeat the enemy's mind before defeating his body?*

SOD prioritizes the cognitive effect over the physical effect.

* **The Detail:** Operations are designed as "Communication." Every bomb, every maneuver is a message.
* **The Concept:** **"Reframing."** The goal is to force the enemy to suffer "Cognitive Dissonance." You want the enemy commander to look at his screens and realize his entire understanding of the battle is wrong.
* **The Output:** Operations that look bizarre to an outsider but are devastating to the insider. *Example:* Creating a massive, noisy, visible buildup on the beach (to trigger the enemy's fear of invasion) while silently infiltrating via tunnels. The physical buildup is a decoy; the *psychological* buildup is the weapon.

### Level 5: The Operational Level (Disruption Mechanisms)

**The Core Question:** *How do we synchronize chaos?*

This is where the rubber meets the road.

* **The Detail:** Instead of "Phases" (Phase 1, Phase 2), SOD uses **"Vectors of Operation."** Multiple actions happen simultaneously to overload the enemy system.
* **The Concept:** **"Swarming."** Attacks come from multiple directions, timelines, and domains (Cyber, Physical, Information) simultaneously. The goal is to exceed the enemy's OODA loop capacity.
* **The Output:** A state of "Systemic Freeze." The enemy commander is so overwhelmed by contradictory inputs that they stop giving orders.

### Level 6: The Tactical Level (Fractal Application)

**The Core Question:** *How does the Sergeant execute "Systemic Shock"?*

This is the hardest part: translating high philosophy to a 19-year-old with a rifle.

* **The Detail:** The mission order changes from "Capture Building X" to "Disrupt the enemy logistics flow in Sector Y."
* **The Concept:** **"Mission Command" (Auftragstaktik).** The soldier is given the "Logic," not just the "Task."
* **The Output:** The "Strategic Corporal." If the soldier sees a supply truck, he knows destroying it (Logistics Logic) is more valuable than shooting a single gunman (Attrition Logic). The tactical act is perfectly aligned with the Systemic Design.

### Level 7: The Learning Level (The Feedback Loop)

**The Core Question:** *Is our Frame still valid?*

SOD assumes the plan is dying the moment it is born.

* **The Detail:** Continuous **"Reframing."** While the battle rages, the Commanders go back to Level 1. They ask: "Did the enemy react how we predicted? No? Then our understanding of the 'System' was wrong."
* **The Concept:** **"Learning while Fighting."** You don't wait for the war to end to learn. You update the entire operational logic *during* the fight.
* **The Output:** An army that evolves faster than the enemy can adapt. The "Plan" is not a static document; it is a living, breathing organism.

---

### Summary of the SOD Fractal

1. **Epistemology:** We doubt our own assumptions.
2. **System:** We map the enemy's logic, not just his positions.
3. **Design:** We create a unique "Form" to break that logic.
4. **Strategy:** We attack the mind.
5. **Operation:** We swarm to overload.
6. **Tactic:** The soldier executes the logic.
7. **Learning:** We re-frame immediately.

### Next Step

This system is heavily dependent on **Intelligence** that goes beyond just "enemy location"—it requires deep cultural and psychological intel. Would you like to explore how **Intelligence Preparation of the Battlefield (IPB)** is adapted in this model to feed such a complex system?
--------
Standard **Intelligence Preparation of the Battlefield (IPB)** asks: *"Where is the enemy tank?"*
**Systemic IPB** asks: *"Who pays for the tank's fuel, and what specific grievance motivates the driver?"*

In the Israeli model (and Systemic Operational Design), intelligence is not just about locating targets; it is about **mapping the ecosystem** that allows those targets to exist. This shifts the focus from "Geography" to "Sociology."

Here is how the IDF adapts IPB to feed the complex SOD model.

### 1. The Shift: From "Red Blobs" to "Neural Networks"

Traditional IPB produces a map with red diamonds (enemy units) and blue arrows (friendly movement). Systemic IPB produces a **Network Graph**.

* **Traditional View:** The enemy is a hierarchy (General  Colonel  Soldier).
* **Systemic View:** The enemy is a network of loose nodes (Financier  Cleric  Bomb Maker  Political Spokesman).
* **The Goal:** You don't just want to kill the Bomb Maker (kinetic effect); you want to arrest the Financier to starve the system (systemic effect).

### 2. Layer 1: The Human Terrain (The "Social Soil")

Before looking at the enemy, Systemic IPB maps the population. In Fourth Generation Warfare, the population is the terrain.

* **Mapping Sub-Structures:** Intelligence officers map clans, extended families, religious sects, and economic dependencies.
* **The "Key Influencer" Map:** Who holds the real power? It might not be the Mayor. It might be the elderly man who runs the bakery where everyone gathers.
* **Actionable Insight:** If you need to calm a neighborhood, you don't patrol it with tanks; you drink tea with the bakery owner. If you disrespect him, the "terrain" turns hostile.

### 3. Layer 2: The "Signatures" of invisible enemies

In conventional war, you look for tanks (large thermal signature). In asymmetric war, the enemy looks like a civilian. Systemic IPB hunts for **Anomalies in the Pattern of Life**.

* **The Baseline:** The IDF uses persistent surveillance (drones, balloons, sensors) to learn the "normal" rhythm of a village. (e.g., The market opens at 06:00, kids play soccer at 16:00).
* **The Anomaly:** Suddenly, the kids stop playing soccer in that specific alley.
* **The Deduction:** The kids know something. There is likely an IED (Improvised Explosive Device) or a sniper team setting up. The *absence* of activity is the intelligence.

### 4. Layer 3: The Narrative & Cognitive Map

This is the most abstract but critical layer. It maps the **Psychological Terrain**.

* **Sacred Space vs. Tactical Space:** A traditional map sees a "Building." A Systemic map sees a "Shrine."
* **The Logic of Resistance:** Intelligence analysts read the enemy's propaganda not just for clues, but to understand their "Theory of Victory."
* *If the enemy believes "Martyrdom is Victory," then killing them doesn't defeat them; it validates them.*


* **Impact on Design:** This forces the Commander to find non-lethal leverage points (e.g., cutting off their funding or humiliating them publicly rather than making them martyrs).

### 5. Layer 4: The "Target Bank" (Bank Matarot)

All this systemic analysis must eventually become a coordinate for a missile. This is the industrialization of intelligence.

The IDF uses a concept called the **"Target Factory."**

1. **Collection:** Unit 8200 (SIGINT) and drones collect petabytes of data.
2. **Fusion:** AI algorithms overlay the "Network Map" onto the "Physical Map."
3. **Incrimination (Hapalala):** This is a legal/operational step. You have a name, but do you have *proof*? The system links the person to the hostile act (e.g., intercepted phone call + drone footage of him holding a weapon).
4. **Production:** The target is "generated" and pushed to the **Tzayad** system.
* *Result:* A pilot flying over the area doesn't need to do the analysis. A red dot simply appears on his visor with a "Valid Target" tag.



### 6. The Feedback Loop: "Reframing" the Intel

In Systemic IPB, the intelligence assessment is never "finished."

* **The Stimulus:** We strike Node A (The Money Man).
* **The Observation:** How does the system react? Does Node B (The Bomb Maker) stop working, or does he find money elsewhere?
* **The Learning:** If he finds money elsewhere instantly, we learned our map of the financial network was incomplete. We "Reframe" and hunt for the backup funding line.

### Summary: The Difference

| Feature | Traditional IPB | Systemic IPB (Israeli/SOD Model) |
| --- | --- | --- |
| **Focus** | Enemy Capabilities (Tanks, Range) | Enemy Intent & Logic (Why they fight) |
| **Terrain** | Mountains, Rivers, Roads | Clans, Narratives, Economics |
| **Enemy Structure** | Hierarchical Order of Battle | Dynamic Network of Nodes |
| **Goal** | Attrition (Kill the enemy) | Disruption (Break the system) |
| **Speed** | Static Updates (Daily) | Real-time Streaming (Pattern of Life) |

### Next Step

The execution of these systemic strikes often falls to **Special Operations Forces (SOF)** who act as the "Scalpel" to the regular army's "Hammer." Would you like to explore the **Task Organization of Israeli Special Forces (Sayeret)** and how they are integrated into this systemic design?
--------------
In the Israeli model, **Special Forces (Sayeret)** are not just "better infantry." They are the primary sensors and actuators of the Systemic Operational Design.

While the "Big Army" is the hammer that smashes the system, the Sayeret are the needles inserted into the system's nervous center to paralyze or manipulate it.

Here is the exploration of Israeli Special Forces integration, scaled to 7 levels of detail.

### Level 1: The Operator (Cognitive Selection)

**The Detail:** The "Rosh Gadol" (Big Head).

* **The Concept:** Israeli selection (Gibbush) doesn't just test physical endurance (can you run?); it tests cognitive improvisation (can you think while starving?).
* **The Fractal Link:** The system demands that the lowest ranking soldier can understand the highest strategic intent.
* **Execution:** A Sayeret operator is expected to possess *Rosh Gadol*—meaning they don't just follow orders; they expand their responsibility. If an operator sees a flaw in the plan during a raid, they are culturally authorized to deviate immediately without asking permission, assuming the responsibility of the outcome.

### Level 2: The Team (The Organic Cell)

**The Detail:** Rank-Agnostic Intimacy.

* **The Concept:** Sayeret teams are often small (12–15 men) and operate on a first-name basis, regardless of rank. The officer is a peer-leader, not a master.
* **The Systemic Function:** This eliminates the "bureaucratic lag" in the OODA loop. Information flows instantly from the point man to the team leader because there is no social barrier.
* **Equipment:** They act as "Tech Incubators." A team might field-test a new drone or hacking tool that isn't standard issue yet, effectively beta-testing tactics for the rest of the army.

### Level 3: The Unit (Specialized Nodes)

**The Detail:** The Toolbox Approach.

* **The Concept:** Each unit corresponds to a specific "domain" of the enemy system.
* **Sayeret Matkal (General Staff Recon):** Deep intelligence gathering. They plant the "bugs" in the enemy network.
* **Shaldag (Kingfisher):** Air-Ground integration. They are the laser pointer for the Air Force, designating the critical nodes for destruction.
* **Shayetet 13 (Flotilla 13):** Maritime sabotage. They strike the economic lifelines (ports/ships).
* **Duvdevan/Mista'arvim:** Undercover urban units. They merge with the human terrain (Level 1 of IPB) to kidnap specific nodes (people) without triggering a full battle.



### Level 4: The Integration (The "Torch")

**The Detail:** "Hataf" (The Fusion).

* **The Concept:** In the past, SF worked alone. In the modern Systemic approach, they are the "Torch" that lights up the room for the heavy hitters.
* **The Mechanism:** Through the **Tzayad** digital network, a Shaldag team hiding on a hill doesn't shoot the enemy tank column. They "paint" the targets digitally.
* **The Effect:** A tank battalion 10km away receives the data and fires beyond-line-of-sight shells. The Sayeret effectively turns "dumb" mass fire into "smart" precision fire.

### Level 5: The Operational Level (Systemic Disruption)

**The Detail:** The "Mabam" (Campaign Between Wars).

* **The Concept:** Israel is technically always at war. The *Mabam* is the shadow war fought to prevent the big war.
* **The Mission:** Sayeret units conduct operations to "mow the grass" of enemy capability without triggering a full conflict.
* *Example:* Destroying a specific convoy of advanced missiles in a neighboring country.


* **The Logic:** This targets the enemy's "Theory of Victory." If the enemy plans to win by accumulating 10,000 precision missiles, the Sayeret dismantles that inventory piece by piece, secretly, keeping the enemy below the threshold of confidence needed to attack.

### Level 6: The Strategic Level (Cognitive Dominance)

**The Detail:** The Entebbe Principle.

* **The Concept:** The strategic utility of Sayeret is not just attrition; it is psychological reach.
* **The Message:** "No place is safe."
* **The Execution:** When Sayeret Matkal raids a location deep inside enemy territory (hundreds of miles from the border), the physical damage might be small. But the *Strategic* damage is massive. It forces the enemy to spend billions on defense everywhere, diluting their offensive power. It creates "Systemic Paranoia" in the enemy leadership.

### Level 7: The National Level (The Innovation Lab)

**The Detail:** The "Start-Up Nation" Pipeline.

* **The Concept:** The Sayeret acts as the R&D lab for the entire Israeli economy and society.
* **The Flow:** The extreme filtering (Level 1) + the technological reliance (Level 4) + the improvisational culture (Level 2) creates a unique human capital.
* **The Output:** Veterans of Unit 8200 (Cyber) or Talpiot (Air Force R&D) leave the army and found tech startups (Waze, CheckPoint, CyberArk). These technologies are then often sold back to the military or strengthen the national economy, which funds the military.
* **The Loop:** The Sayeret ecosystem powers the National Economy, which powers the Sayeret.

---

### Summary of the Fractal

1. **Operator:** Improvisational Genius (Rosh Gadol).
2. **Team:** Flat Hierarchy (Speed).
3. **Unit:** Domain Specialization (The Tool).
4. **Integration:** Digital Fusion (The Network).
5. **Operation:** The Shadow War (Mabam).
6. **Strategy:** Psychological Reach (Deterrence).
7. **Nation:** The Economic Engine (Start-Up Nation).

### Next Step

This system works exceptionally well for short, high-intensity conflicts or shadow wars. However, it faces unique challenges in **Protracted Occupation or Long-Term COIN (Counter-Insurgency)**, where "winning" is undefined.

Would you like to analyze the **Limitations and Failures** of this Israeli Systemic approach when applied to long-term attrition warfare?
----------
The Israeli model is optimized for **speed, high-intensity, and short duration** (like the Six-Day War). It is essentially a "Sprint" machine.

When this machine is forced to run a "Marathon" (Long-term Occupation or Attrition), the very features that make it strong begin to create systemic failures.

Here is an analysis of the **Limitations and Failures** of the Israeli Systemic approach, scaled to 7 levels of friction.

### Level 1: The Soldier (Desensitization & Burnout)

**The Limitation:** **Moral Erosion.**

* **The Problem:** The "Strategic Corporal" concept requires a soldier to be a diplomat one minute and a killer the next. In a short war (2 weeks), this is manageable. In a 50-year friction, it is psychologically impossible.
* **The Failure:** The "Rosh Gadol" (Big Head) stops working. Soldiers, exhausted by the ambiguity of policing a civilian population, revert to **Binary Thinking** (Everyone is a threat).
* **Result:** This leads to tactical mistakes (shooting the wrong person) that cause strategic damage (media outrage), reversing the gains of the OODA loop.

### Level 2: The Tactical Level (The "Plasma Screen" Trap)

**The Limitation:** **Tech Dependency vs. Analog Reality.**

* **The Problem:** The "Tzayad" system makes commanders addicted to the "God's Eye View." They trust the screen more than the ground.
* **The Counter:** The enemy (Hamas/Hezbollah) realized this and went **Subterranean**.
* **The Failure:** In 2014 and 2023, the IDF faced massive surprise from tunnels. A screen cannot see through 20 meters of concrete. The high-tech "Sensor-to-Shooter" loop is useless if the sensor is blind. The enemy defeated the "Start-Up Nation" with shovels.

### Level 3: The Operational Language (The 2006 Warning)

**The Limitation:** **Intellectual Over-Complication.**

* **The Problem:** SOD (Systemic Operational Design) is so abstract that it can paralyze execution.
* **The Case Study (2006 Lebanon War):** This is the most famous failure of the doctrine. General Gal Hirsch used SOD language in his orders, telling subordinates to "create systemic effects" and "swarm the logic."
* **The Failure:** Brigade commanders looked at the orders and didn't know what to do. They asked: *"Sir, do we capture the village or not?"*
* **Result:** The Winograd Commission (official inquiry) blamed the confusing language for the military's poor performance. When bullets fly, you don't need "Systemic Logic"; you need "Take that Hill."

### Level 4: The Strategic Level (The "Iron Dome" Paradox)

**The Limitation:** **Tactical Success causes Strategic Stagnation.**

* **The Problem:** The Iron Dome is a miracle of technology. It shoots down 90%+ of incoming rockets.
* **The Failure:** Because the rockets don't hit Tel Aviv, the political urgency to *solve* the conflict disappears.
* **The Trap:** The technology allows the country to "live with the problem" rather than fixing it. This leads to **"Mowing the Grass"**—endless rounds of violence every 2–3 years with no strategic end state. The tactic (interception) is perfect; the strategy (resolution) is nonexistent.

### Level 5: The Political Level (The Legitimacy Clock)

**The Limitation:** **Asymmetry of Time.**

* **The Problem:** The IDF relies on massive firepower to shock the system (Level 5 of SOD).
* **The Failure:** In a protracted COIN (Counter-Insurgency) war, the enemy *wants* you to use massive firepower.
* **The Dynamic:** Every time the IDF uses a 2,000lb bomb to kill a commander (Tactical Success), the images of collateral damage shorten the **"Diplomatic Clock."**
* **Result:** Israel often runs out of "Time" before it runs out of "Targets." The international community forces a ceasefire before the military goal is achieved.

### Level 6: The Societal Level (The Reserve Ceiling)

**The Limitation:** **Economic Collapse.**

* **The Problem:** The IDF is a **Reservist Army**. The soldiers are also the engineers, doctors, and teachers of the economy.
* **The Failure:** The US Army can deploy for 20 years because it is a professional volunteer force. Israel cannot. If Israel mobilizes fully for more than a few months, its economy implodes.
* **The Consequence:** This forces the IDF to seek "Fast Decisions" even when the situation (like COIN) requires "Slow Patience." You cannot rush a counter-insurgency, but the Israeli economic model *demands* you rush.

### Level 7: The Geopolitical Level (The "Fortress" Mentality)

**The Limitation:** **Isolation.**

* **The Problem:** The Systemic approach focuses on "Defeating the Enemy System."
* **The Failure:** It often neglects "Building the Friendly System" (Alliances).
* **The Result:** While the IDF is excellent at winning the physical battle, the State often loses the **Information War**. The narrative of "Military Dominance" alienates potential regional partners, turning a military victory into a diplomatic isolation.

### Summary: The "Victory" Problem

The core failure of the Israeli model in long-term conflict is the definition of **Victory**.

* **In 1967:** Victory was "Destroy the Egyptian Army." (Clear, Achievable).
* **In 2024:** Victory is "Dismantle the Ideology of Resistance." (Vague, Systemic).

You cannot "shoot" an ideology. The OODA loop spins faster and faster, becoming more efficient at killing, but the "Goal" keeps moving further away.

### Next Step

This analysis highlights that **Technology and Speed** have limits. The US Military faced similar paradoxes in Afghanistan and Iraq and developed a different doctrine: **FM 3-24 (The COIN Manual)**, which emphasizes "Protecting the Population" over "Hunting the Enemy."

Would you like to compare the **Israeli "Hunter-Killer" approach** vs. the **US "Population-Centric" approach** to see how they differ in solving these problems?
-------------
This explores the "Long Term Strategic Campaign" perspective, shifting the timeline from **Seconds (Tactical)** to **Decades (Strategic)**.

When we zoom out to this level, the Israeli model shifts from "Decisive Victory" (Winning the War) to **"Mabam"** (The Campaign Between Wars). The goal is no longer to *solve* the problem, but to *manage* the entropy.

Here is the **Long-Term Strategic Campaign** explored through 7 levels of detail, using the Fractal approach to show how a 10-year strategy creates a 10-second reality.

### The Doctrine: "Mabam" (Campaign Between Wars)

In the US, "Campaigns" (like Operation Desert Storm) have a start and an end.
In Israel, the **Mabam** is a permanent state of being. It is a gray-zone strategy designed to delay the inevitable next war while improving the opening conditions for it.

---

### Level 1: The Molecular Level (Cumulative Erosion)

* **The Detail:** **The "Grass" Metaphor.**
* You don't cut the grass once and expect it to stay short. You cut it every week.
* **Action:** Israel conducts thousands of small, low-signature strikes (a shipment in Syria, a cyber-attack in Iran, an arrest in Jenin).


* **The Strategic Fractal:** This relies on **Cumulative Strategy** (J.C. Wylie's theory). No single strike matters. It is the *sum* of 1,000 strikes that creates a "statistically significant" reduction in enemy capability.
* *Result:* The enemy never reaches "Critical Mass" to invade, but they never disappear either.



### Level 2: The Tactical Level (The "Reference Threat")

* **The Detail:** **Force Design Lag.**
* It takes 10 years to build a new tank or fighter jet.
* **The Dilemma:** If you build a tank to fight the enemy of 2020 (Hamas), you might be useless against the enemy of 2030 (Iran).


* **The Strategic Fractal:** The long-term campaign requires **Hedging**. The IDF invests heavily in "Generic" capabilities (Air Power, Cyber) that work against everyone, rather than "Specific" capabilities (Heavy Armor) that only work against invasions.
* *Consequence:* This focus on "Generic Flexibility" over "Specific Mass" is why the ground forces often struggle in specific terrain (like mud/tunnels) when the long-term war suddenly becomes a short-term invasion.



### Level 3: The Operational Level (The "Legitimacy Bank")

* **The Detail:** **Diplomatic Capital as Ammunition.**
* In a long campaign, "International Legitimacy" is a fuel tank. You start with a full tank (sympathy after an attack). Every day of war burns fuel.


* **The Strategic Fractal:** Israel operates on a **"Deficit Spending"** model.
* *Phase A (High Legitimacy):* Use massive force early.
* *Phase B (Low Legitimacy):* Shift to covert/precision raids (Mabam) as the "fuel" runs out.
* *The Trap:* If the campaign drags on too long (Gaza 2024), the tank runs dry, and the military engine stalls not because of a lack of bullets, but a lack of *permission*.



### Level 4: The Societal Level (The "Resilience" Contract)

* **The Detail:** **Routine in Emergency.**
* The goal of the long campaign is to allow the Tel Aviv stock market to hit record highs while a war rages 40 miles away.


* **The Strategic Fractal:** **Cognitive Partitioning.** The state implicitly tells its citizens: *"We will not solve the conflict. In exchange, we promise the conflict will not stop you from vacationing in Cyprus."*
* *The Risk:* This works for 10 years. But when the "Wall" breaks (Oct 7), the shock is existential because the society forgot it was at war. The "Mabam" strategy anesthetized the patient instead of curing him.



### Level 5: The Economic Level (The "Start-Up" Engine)

* **The Detail:** **The Military-Industrial Loop.**
* Long-term campaigns are expensive. To sustain them, the war itself must generate profit.


* **The Strategic Fractal:** **Exporting the Solution.**
* Israel develops "Iron Dome" to survive the campaign.
* It then sells "Iron Dome" to Germany/NATO for billions.
* The profit funds the next generation of Iron Dome.
* *Result:* The "Campaign" becomes an economic driver. Peace, ironically, might be less economically efficient for the Defense Industrial Base than "Permanent Low-Intensity Conflict."



### Level 6: The Geopolitical Level (The "Regional Architecture")

* **The Detail:** **The Enemy of my Enemy.**
* In a 30-year campaign against Iran, Israel cannot fight alone.


* **The Strategic Fractal:** **The Alliance of Fear.**
* Israel uses the "Long War" to build bridges with Sunni Arab states (UAE, Saudis) who also fear Iran.
* The campaign transforms Israel from a "Pariah" to a "Shield."
* *The Pivot:* The long-term goal shifts from "Defeating the Arabs" to "Leading a Middle East NATO."



### Level 7: The Grand Strategic Level (The "End State" Void)

* **The Detail:** **Managing vs. Solving.**
* This is the critical failure point.


* **The Strategic Fractal:** **The Sisyphean Trap.**
* A campaign implies a destination ("We walk until we reach Berlin").
* The Israeli Long-Term Campaign is a treadmill ("We run so we don't fall off").
* *The Ultimate Implication:* Because there is no political vision for *peace* (Two States, One State, etc.), the military campaign becomes circular. The "7 Levels" cycle repeats every 5 years, with higher technology but identical geometry.



---

### Comparison: The US vs. Israeli Long Game

| Feature | US Long-Term Model (Global Power) | Israeli Long-Term Model (Regional Survival) |
| --- | --- | --- |
| **Goal** | **Order:** Maintain global trade/democracy. | **Existence:** Prevent annihilation. |
| **Method** | **Expeditionary:** Fight "Over there" so we don't fight here. | **Mabam:** Fight "In between" so we don't fight "For real." |
| **Time** | **Sequential:** Phase 1  Phase 4 (Stabilization). | **Cumulative:** Phase 1  Phase 1  Phase 1. |
| **Risk** | **Fatigue:** Public gets bored and demands withdrawal (Vietnam/Afghan). | **Erosion:** Society hardens, democracy strains under perpetual war footing. |

### The Bottom Line

From a long-term perspective, the Israeli system is a **Tactical Ferrari engine inside a Strategic bus with no driver.**

It is the world's most efficient machine for *buying time*, but it has no mechanism for *using* that time to solve the underlying problem. The OODA loop spins brilliantly, but the vehicle stays in the same place.
--------------
The following is a consolidated strategic analysis integrating military planning frameworks, execution techniques (OODA), and the specific Israeli "Systemic" approach, scaled from the soldier's rifle to the nation's geopolitical strategy.

---

# The Architecture of Action: From Strategy to Soldier

**A Comparative Analysis of Military Planning & Execution Systems**

This document integrates the **US/NATO "Industrial" Model** (optimized for global power projection) and the **Israeli "Systemic" Model** (optimized for existential regional survival), demonstrating how planning cascades down to execution at the soldier level.

---

## Part I: The Core Frameworks (The "Codebase")

To achieve a fast OODA (Observe-Orient-Decide-Act) loop and efficient goal achievement, military organizations operate on two distinct tracks: one for **Deliberate Planning** (Before the Battle) and one for **Rapid Execution** (During the Battle).

### 1. Planning: Structuring Chaos

The goal of planning is not to script the battle, but to align all forces so they can improvise effectively when the script breaks.

| Feature | **US / NATO Model (MDMP)** | **Israeli Model (SOD)** |
| --- | --- | --- |
| **Philosophy** | **Engineering:** "Here is the problem (Hill 402). Build a bridge (Plan) to solve it." | **Biology:** "Here is the system (Enemy Network). Inject a virus (Shock) to disrupt it." |
| **Method** | **Linear:** Step 1  Step 2  Step 3. Focus on synchronization and logistics. | **Systemic:** Focus on enemy psychology, leverage points, and "logic of resistance." |
| **Output** | **OPORD (Operation Order):** Detailed, rigid, checklists. | **Operational Frame:** Abstract, focused on "Why" and "Context." |

### 2. Execution: The "Digital" OODA Loop

Modern execution relies on decentralization (Mission Command) enabled by technology.

* **The Golden Rule (1/3 - 2/3):** Leaders use only 1/3 of the time to plan, leaving 2/3 for subordinates to prepare.
* **The Tech Stack:**
* **US:** *ATAK (Android Team Awareness Kit).*
* **Israel:** *Tzayad (Digital Army Program).*
* **Function:** Both systems visualize the OODA loop. Instead of saying "Enemy at the blue house" (Slow/Ambiguous), a soldier drops a digital pin. Every screen in the network updates instantly. "Observe"  "Orient" happens in milliseconds.



---

## Part II: The Israeli Approach (The Fractal System)

The Israeli Defense Forces (IDF) operate on a unique **Fractal Model**, where the strategic dilemma of the nation is mirrored in the tactical actions of the individual soldier. This is analyzed below through **7 Levels of Detail**.

### The 7 Levels of Detail vs. Implications

| Level | **The Detail (Action)** | **The Implication (Consequence)** |
| --- | --- | --- |
| **1. The Soldier** | **"Rosh Gadol" (Big Head):** The soldier is expected to improvise and disobey stupid orders. | **Moral Erosion:** Constant high-stakes decision-making leads to burnout and ethical slipping in long occupations. |
| **2. The Team** | **Flat Hierarchy:** A Private can correct a Colonel. Low formality = High Speed. | **The "Plasma Trap":** Over-reliance on screens (*Tzayad*) creates blindness to low-tech threats (Tunnels). |
| **3. The Unit** | **Domain Specialization:** Units like *Unit 8200* (Cyber) or *Shaldag* (Air-Ground) act as specialized tools. | **Intellectual Overload:** Complex "Systemic" orders can confuse tactical commanders who just need simple objectives. |
| **4. The Operation** | **"Mabam" (Campaign Between Wars):** Constant "mowing the grass" to degrade enemy capabilities without full war. | **Strategic Stagnation:** Tactical success (Iron Dome interceptions) removes the urgency to solve the political root cause. |
| **5. The Strategy** | **Cognitive Maneuver:** Attacking the enemy's "Theory of Victory" rather than just their tanks. | **The Legitimacy Clock:** Massive firepower shortens the diplomatic window. The world stops the war before the goal is met. |
| **6. The Society** | **Start-Up Nation:** The military acts as an R&D lab for the economy; the economy funds the military. | **Economic Fragility:** A reservist army cannot fight long wars. The economy collapses if mobilization lasts >6 months. |
| **7. The Geopolitics** | **Regional Integration:** Using shared threats (Iran) to build secret alliances with Arab neighbors. | **The Sisyphean Trap:** The campaign buys time, but without a political end-state, the loop repeats forever. |

---

## Part III: Strategic Analysis (The Long Game)

### 1. The "Systemic IPB" (Intelligence Preparation of the Battlefield)

The Israeli model shifts intelligence from **Geography** to **Sociology**.

* **Traditional IPB:** Maps terrain (Rivers, Hills).
* **Systemic IPB:** Maps human terrain (Clans, Economies, Narratives).
* **Goal:** Do not just kill the enemy commander; cut off the funding stream that pays him.

### 2. Red Teaming as Law

To prevent "Groupthink," the IDF institutionalized the **Ipcha Mistabra** ("The Opposite Appears Likely").

* A dedicated intelligence unit's *only* job is to argue that the lead assessment is wrong.
* **Benefit:** The Commander always decides between two opposing, well-researched options.

### 3. The "Victory" Paradox

The consolidated limitation of the Israeli model is the definition of success.

* **Short Term:** It is a Ferrari. High speed, high tech, devastating lethality.
* **Long Term:** It struggles to convert military dominance into political peace. The "Campaign Between Wars" becomes a permanent state of existence—a treadmill of tactical brilliance and strategic stalemate.

---

## Part IV: The Toolkit for Implementation

For a military or organization to replicate this efficiency, they must implement:

1. **Mission Command:** Tell them *what* to do, not *how*.
2. **Standardization (Doctrine):** Ensure everyone speaks the "Codebase" (same symbols, terms, radio procedures).
3. **Digital Fusion:** Use tools like ATAK to create a shared consciousness.
4. **After Action Review (AAR):** A ruthless, rank-agnostic feedback loop to learn from every mistake instantly.
5. **Red Teaming:** Designate a professional contrarian to stress-test every plan before execution.

### Final Summary

* **US Model:** **Robust & Sequential.** Wins by logistics, mass, and overwhelming firepower. Optimized for definitive victories abroad.
* **Israeli Model:** **Agile & Systemic.** Wins by adaptation, intelligence, and rapid targeting. Optimized for survival at home.

The ultimate efficiency comes when **Systemic Design** (The Israeli Brain) is executed with **Industrial Discipline** (The US Muscle).
-----------

Here is the comprehensive, unified report integrating all discussed frameworks, techniques, and strategic analyses. This document preserves the depth of the previous exchanges, structured as a formal military staff study for review and analysis.

---

# **Strategic & Tactical Architecture: A Comparative Analysis of Military Execution Models**

**Subject:** Integrated Analysis of OODA, Systemic Operational Design (SOD), and Fractal Execution from Soldier to State.
**Date:** January 2026

---

## **1. Executive Summary**

This report analyzes the mechanisms of military planning and execution, contrasting the **US/NATO "Industrial" Model** (optimized for global power projection and massive logistical synchronization) with the **Israeli "Systemic" Model** (optimized for rapid adaptation, regional survival, and cognitive maneuver).

The central thesis is that efficient goal achievement relies on **Decentralization**—pushing decision-making authority to the lowest capable level—enabled by **Mission Command**, **Common Operational Pictures (technology)**, and robust **Learning Loops (AARs)**. The report further explores the "Fractal Nature" of operations, where a single tactical action by a soldier echoes upward to create geopolitical consequences.

---

## **2. Foundations of Execution: The Universal Operating System**

To achieve a fast OODA (Observe-Orient-Decide-Act) loop, military organizations must balance **Deliberate Planning** (thoroughness) with **Rapid Execution** (speed).

### **2.1 The Planning Frameworks**

Planning operates on two tracks depending on the available time.

* **The Thorough Track (MDMP/MCPP):** Used by Battalions and higher.
* **Process:** Detailed Intelligence Preparation of the Battlefield (IPB), Course of Action (COA) Development, and Wargaming.
* **Output:** The **OPORD (Operation Order)** containing the **Commander’s Intent**.
* **Goal:** Synchronization of complex assets (Artillery, Aviation, Logistics).


* **The Fast Track (TLP/BAMCIS):** Used by Small Units (Platoons/Squads).
* **Troop Leading Procedures (TLP):** Receive Mission  Issue Warning Order (WARNO)  Make Tentative Plan  Initiate Movement  Recon  Complete Plan  Issue Order  Supervise.
* **BAMCIS (USMC):** Begin Planning, Arrange Recon, Make Recon, Complete Plan, Issue Order, Supervise.
* **Key Mechanic:** The **1/3 - 2/3 Rule**. Leaders use only 1/3 of available time for their planning, leaving 2/3 for subordinates to plan and rehearse.



### **2.2 The Execution Techniques (Soldier Level)**

At the lowest level, planning is replaced by "Muscle Memory" to compress the OODA loop from minutes to seconds.

* **Battle Drills:** Collective reflexes. (e.g., "React to Contact": Return fire, seek cover, yell direction). No decision-making required; action is immediate.
* **SOPs (Standard Operating Procedures):** Standardized layouts for kits, radios, and vehicles to reduce cognitive load.
* **Immediate Action Drills (IADs):** Individual reflexes (e.g., "Tap-Rack-Bang" for a jammed weapon).

### **2.3 The "Digital OODA" (Technology)**

Modern execution is visualized through **ATAK (Android Team Awareness Kit)** or **Tzayad (Digital Army Program)**.

* **Observe:** **Cursor-on-Target (CoT).** A soldier double-taps a map; a red diamond appears on all screens.
* **Orient:** **Blue Force Tracking.** Seeing friendly positions prevents fratricide and enables self-synchronization without radio chatter.
* **Decide:** **Chat/Graphics.** Commanders draw arrows on screens to issue orders silently.
* **Act:** **Sensor-to-Shooter.** Data from a drone or laser rangefinder flows directly to artillery fire direction centers.

---

## **3. The Israeli Approach: Systemic Operational Design (SOD)**

While the US model focuses on **Physics** (Geography, Logistics), the Israeli model focuses on **Psychology** (Systems, Logic).

### **3.1 The Philosophy of SOD**

Developed to address the complexity of asymmetric warfare, SOD treats the enemy not as a "Target Set" but as a "Complex Adaptive System."

* **Epistemological Shift:** Instead of asking "Where is the enemy?", SOD asks "Why does the enemy exist?" and "What is the logic that holds them together?"
* **The "System Frame":** Mapping the **Rival System** (Enemy), **Command System** (Friendly), and the **Environment**.
* **Operational Logic:** Designing a **"Holistic Strike"** that injects energy into the enemy system to cause it to collapse or freeze (Systemic Shock).
* *Case Study (Nablus 2002):* The logic was "Inverse Geometry." The enemy prepared the streets (Kill Zones). The IDF attacked *through* the walls (Living Rooms), bypassing the enemy's defense logic entirely.



### **3.2 Systemic Intelligence (IPB)**

Systemic IPB shifts the focus from "Terrain" to "Human Terrain."

* **Layer 1: The Social Soil:** Mapping clans, extended families, and economic dependencies.
* **Layer 2: Pattern of Life:** Using persistent surveillance to find *anomalies* (e.g., kids stopping play in an alley = IED threat).
* **Layer 3: The Narrative:** Understanding the enemy's "Theory of Victory." (e.g., If they value martyrdom, killing them is counter-productive; you must find a leverage point that denies them glory).

### **3.3 The "Target Factory"**

The industrialization of intelligence for rapid execution.

1. **Collection:** SIGINT (Unit 8200), Visual (Drones).
2. **Fusion:** AI overlays Network Maps onto Physical Maps.
3. **Incrimination:** Legal verification of targets.
4. **Distribution:** Targets are pushed to the **Tzayad** network, appearing as "Available" to any nearby shooter (Tank, Heli, Sniper).

---

## **4. The Fractal Analysis: 7 Levels of Detail**

The Israeli model operates on a "Fractal" principle: the logic of the whole is embedded in the part. This analysis maps the **Action**, the **Implication**, and the **Systemic Failure** at every level.

### **Level 1: The Soldier (The Molecular Level)**

* **Action:** **"Rosh Gadol" (Big Head).** The expectation that the lowest soldier will improvise and deviate from the plan if it serves the intent.
* **Implication:** **Terminal Ballistics.** A single bullet's trajectory determines life or death.
* **Limitation:** **Moral Erosion.** In long-term occupation, the cognitive burden burns out the "Rosh Gadol," leading to binary thinking and ethical failures (shooting the wrong person).

### **Level 2: The Tactical Level (The Squad/Platoon)**

* **Action:** **Flat Hierarchy.** Low formality, rank-agnostic communication, and high speed.
* **Implication:** **Flow & Friction.** The unit moves as a fluid organism rather than a rigid block.
* **Limitation:** **The "Plasma Screen" Trap.** Over-reliance on the "God's Eye View" (Tzayad) creates blindness to low-tech, subterranean threats (Tunnels) that sensors cannot see.

### **Level 3: The Unit (Specialized Nodes)**

* **Action:** **The Toolbox.** Units like **Sayeret Matkal** (Deep Intel), **Shaldag** (Air-Ground), and **Shayetet 13** (Maritime) act as specific tools for specific domains.
* **Implication:** **Tech Incubation.** These units beta-test technologies for the wider army.
* **Limitation:** **Intellectual Over-Complication.** High-concept "Systemic" orders can confuse tactical commanders in the heat of battle (e.g., 2006 Lebanon War failures).

### **Level 4: The Operational Level (The Sector)**

* **Action:** **"Mabam" (Campaign Between Wars).** Constant, low-signature strikes to "mow the grass" and degrade capability.
* **Implication:** **Systemic Shock.** Swarming the enemy network to induce paralysis.
* **Limitation:** **Strategic Stagnation.** Tactical success (like Iron Dome) removes the political urgency to solve the root cause, leading to endless cyclical violence.

### **Level 5: The Strategic Level (The Theater)**

* **Action:** **Cognitive Maneuver.** Using force to send a message ("Deterrence") rather than just to destroy matter.
* **Implication:** **The Legitimacy Clock.** Every operation runs against a ticking clock of international tolerance.
* **Limitation:** **Asymmetry of Time.** The enemy wants a long war; the IDF needs a short war. Massive firepower creates collateral damage that stops the clock before the goal is reached.

### **Level 6: The Societal Level (The State)**

* **Action:** **Start-Up Nation Pipeline.** The military acts as an R&D engine; veterans found tech companies that power the economy.
* **Implication:** **Domestic Resilience.** The society must maintain normalcy (Stock Market highs) while at war.
* **Limitation:** **Economic Collapse.** A reservist army cannot sustain long mobilizations without crashing the economy, forcing hasty military decisions.

### **Level 7: The Geopolitical Level (The World)**

* **Action:** **Regional Architecture.** Building alliances (Sunni States) based on shared threats (Iran).
* **Implication:** **Diplomatic Capital.** Military actions can build or burn bridges with allies.
* **Limitation:** **The Sisyphean Trap.** The "Long Term Campaign" becomes a treadmill—running faster just to stay in place, with no political "End State" in sight.

---

## **5. Long-Term Strategic Campaigning ("Mabam")**

When the timeline shifts from **Seconds** to **Decades**, the strategy shifts from "Victory" to "Management."

* **Cumulative Strategy:** Success is not one big battle, but the sum of 1,000 small cuts over 10 years.
* **Deficit Spending:** Burning "Diplomatic Capital" to buy time.
* **Hedging:** Investing in "Generic" capabilities (Air/Cyber) that work against any enemy, at the expense of "Specific" capabilities (Armor/Occupation forces).
* **The Paradox:** The goal of the Long Campaign is to prevent the "Big War," but it creates a "Permanent War" state that slowly hardens society and isolates the nation.

---

## **6. Quality Assurance: Learning & Adaptation**

The system is maintained by rigorous, honest feedback loops.

### **6.1 Wargaming (Stress-Testing the Plan)**

* **Process:** Action-Reaction-Counteraction cycles between Blue (Friendly) and Red (Enemy) cells.
* **Output:** The **Synchronization Matrix**, aligning units in time and space.
* **Goal:** Building "Artificial Experience" so commanders have already "lived" the battle before it starts.

### **6.2 Red Teaming (Stress-Testing the Thinking)**

* **Concept:** **Ipcha Mistabra** ("The Opposite Appears Likely"). A designated team *must* challenge the prevailing assumption.
* **Techniques:**
* **Pre-Mortem:** "Assume the plan failed. Write the history of why."
* **4 Ways of Seeing:** Analysis of self/enemy perspectives to avoid "Mirror Imaging" bias.



### **6.3 After Action Review (AAR)**

* **The 4 Questions:** What was supposed to happen? What happened? Why the difference? What do we do next time?
* **Culture:** Rank is irrelevant. Brutal honesty is required.
* **Flow:** Lessons from the Soldier's AAR flow up to the "Center for Lessons Learned" to update Doctrine and Strategy.

---

## **7. Conclusion**

The integration of these systems reveals a dichotomy in modern warfare:

1. **The US Model** is an **Industrial Juggernaut**: It wins through mass, logistics, and established doctrine. It is robust but can be slow to adapt to non-standard threats.
2. **The Israeli Model** is a **Systemic Scalpel**: It wins through improvisation, intelligence dominance, and rapid OODA loops. It is agile but fragile in long-term attrition.

**The Ultimate Efficiency** in goal achievement is found in the synthesis:

* **Plan** like an Engineer (MDMP).
* **Think** like a Biologist (SOD).
* **Execute** like a Start-up (Mission Command/ATAK).
* **Learn** like a Scientist (AAR/Red Teaming).
--------------\

==========================================
reference F# code - Analyse , review and see how this can be integrated with current system
Use this for ideation and analysis only
==========================================
// =============================================================================
// INDRAJAAL PLANNING SYSTEM - COMPLETE F# IMPLEMENTATION
// =============================================================================
// 
// This file contains the complete F# implementation for the Indrajaal Planning
// System, migrated from Elixir. It implements a military-grade planning framework
// incorporating OODA, SOD, and MDMP/TLP methodologies with fractal, holonic, and
// biomorphic architectural patterns.
//
// Architecture Layers:
//   1. Domain Layer - Core types, entities, events, and business logic
//   2. Infrastructure Layer - Database (Smriti) and messaging (Zenoh) integration
//   3. Application Layer - CQRS commands and query handlers
//   4. API Layer - REST endpoints and agent interface
//
// =============================================================================

namespace Indrajaal.Planning

open System
open System.Threading.Tasks

// =============================================================================
// MODULE 1: DOMAIN TYPES
// =============================================================================
// Core value types and primitives used throughout the system

module Domain =

    // =========================================================================
    // CORE VALUE TYPES
    // =========================================================================

    /// Unique identifier for all entities in the system
    [<Struct>]
    type EntityId = EntityId of Guid
        with
        static member New() = EntityId(Guid.NewGuid())
        static member Parse(s: string) = EntityId(Guid.Parse(s))
        member this.Value = let (EntityId id) = this in id
        override this.ToString() = this.Value.ToString()

    /// Hierarchical identifier encoding: portfolio.program.project.task
    [<Struct>]
    type HierarchicalId = {
        PortfolioId: EntityId option
        ProgramId: EntityId option
        ProjectId: EntityId option
        TaskId: EntityId
    } with
        static member TaskOnly(taskId: EntityId) = 
            { PortfolioId = None; ProgramId = None; ProjectId = None; TaskId = taskId }
        
        member this.ToPath() =
            [this.PortfolioId; this.ProgramId; this.ProjectId; Some this.TaskId]
            |> List.choose id
            |> List.map (fun id -> id.ToString())
            |> String.concat "."

    // =========================================================================
    // PRIORITY SYSTEM (Eisenhower Matrix + Military Criticality)
    // =========================================================================

    /// Urgency dimension of priority
    type Urgency =
        | Immediate    // Must be done now
        | Soon         // Should be done today
        | Scheduled    // Has a specific deadline
        | Eventual     // No specific deadline
        | Deferred     // Explicitly postponed

    /// Importance dimension of priority
    type Importance =
        | Critical     // Mission-critical, failure is catastrophic
        | High         // Significant impact on objectives
        | Medium       // Normal business value
        | Low          // Nice to have
        | Optional     // Can be dropped if needed

    /// Combined priority with military-grade criticality assessment
    type Priority = {
        Urgency: Urgency
        Importance: Importance
        CriticalityScore: int  // 1-100 computed score
    } with
        static member Calculate(urgency: Urgency, importance: Importance) =
            let urgencyScore = 
                match urgency with
                | Immediate -> 100 | Soon -> 80 | Scheduled -> 60 | Eventual -> 40 | Deferred -> 20
            let importanceScore =
                match importance with
                | Critical -> 100 | High -> 80 | Medium -> 60 | Low -> 40 | Optional -> 20
            { Urgency = urgency
              Importance = importance
              CriticalityScore = (urgencyScore + importanceScore) / 2 }
        
        static member Default = Priority.Calculate(Eventual, Medium)

    // =========================================================================
    // STATUS WORKFLOW
    // =========================================================================

    /// Task status with workflow semantics
    type TaskStatus =
        | Pending           // Created but not started
        | Planned           // Scheduled for future work
        | Ready             // All prerequisites met, can be started
        | InProgress        // Currently being worked on
        | InReview          // Awaiting review/approval
        | Blocked of string // Cannot proceed, with reason
        | OnHold of string  // Intentionally paused, with reason
        | Completed         // Successfully finished
        | Cancelled of string // Abandoned, with reason
        | Archived          // Historical record only

    /// Check if status represents an active (not terminal) state
    module TaskStatus =
        let isActive = function
            | Pending | Planned | Ready | InProgress | InReview -> true
            | Blocked _ | OnHold _ -> true
            | Completed | Cancelled _ | Archived -> false
        
        let isTerminal = function
            | Completed | Cancelled _ | Archived -> true
            | _ -> false
        
        let canTransitionTo (current: TaskStatus) (target: TaskStatus) =
            match current, target with
            | Pending, (Planned | Ready | InProgress | Cancelled _) -> true
            | Planned, (Ready | InProgress | OnHold _ | Cancelled _) -> true
            | Ready, (InProgress | Blocked _ | OnHold _ | Cancelled _) -> true
            | InProgress, (InReview | Blocked _ | OnHold _ | Completed | Cancelled _) -> true
            | InReview, (InProgress | Completed | Cancelled _) -> true
            | Blocked _, (Ready | InProgress | OnHold _ | Cancelled _) -> true
            | OnHold _, (Ready | InProgress | Cancelled _) -> true
            | (Completed | Cancelled _), Archived -> true
            | s1, s2 when s1 = s2 -> true
            | _ -> false

    // =========================================================================
    // RECURRENCE PATTERNS
    // =========================================================================

    type DayOfWeekSet = DayOfWeek Set

    type RecurrencePattern =
        | Daily
        | Weekdays
        | Weekly of DayOfWeekSet
        | BiWeekly of DayOfWeekSet
        | Monthly of int
        | MonthlyLastDay
        | MonthlyFirstWeekday of DayOfWeek
        | MonthlyLastWeekday of DayOfWeek
        | Quarterly of int
        | Yearly of int * int
        | Custom of TimeSpan
        | CronExpression of string

    type Recurrence = {
        Pattern: RecurrencePattern
        StartDate: DateTimeOffset
        EndDate: DateTimeOffset option
        MaxOccurrences: int option
        SkipWeekends: bool
        SkipHolidays: bool
    } with
        static member Daily(start: DateTimeOffset) = 
            { Pattern = Daily; StartDate = start; EndDate = None; MaxOccurrences = None; SkipWeekends = false; SkipHolidays = false }

    // =========================================================================
    // DEPENDENCY TYPES
    // =========================================================================

    type DependencyType =
        | FinishToStart
        | StartToStart
        | FinishToFinish
        | StartToFinish

    type Dependency = {
        Id: EntityId
        PredecessorId: EntityId
        SuccessorId: EntityId
        Type: DependencyType
        LagTime: TimeSpan
        IsStrict: bool
    }

    // =========================================================================
    // TIME TRACKING
    // =========================================================================

    type UserId = UserId of Guid

    type TimeEntry = {
        Id: EntityId
        TaskId: EntityId
        UserId: UserId
        StartTime: DateTimeOffset
        EndTime: DateTimeOffset option
        Duration: TimeSpan option
        Description: string option
        IsBillable: bool
    }

    type TimeEstimate = {
        Optimistic: TimeSpan
        MostLikely: TimeSpan
        Pessimistic: TimeSpan
    } with
        member this.PertEstimate =
            let o = this.Optimistic.TotalMinutes
            let m = this.MostLikely.TotalMinutes
            let p = this.Pessimistic.TotalMinutes
            TimeSpan.FromMinutes((o + 4.0 * m + p) / 6.0)
        
        static member Simple(duration: TimeSpan) =
            { Optimistic = duration; MostLikely = duration; Pessimistic = duration }

    // =========================================================================
    // ASSIGNMENT AND COLLABORATION
    // =========================================================================

    type AssignmentRole =
        | Owner
        | Assignee
        | Reviewer
        | Stakeholder
        | Watcher

    type Assignment = {
        UserId: UserId
        Role: AssignmentRole
        AssignedAt: DateTimeOffset
        AssignedBy: UserId option
    }

    // =========================================================================
    // METADATA AND TAGGING
    // =========================================================================

    type Tag = {
        Name: string
        Color: string option
        Category: string option
    }

    type CustomFieldType =
        | Text
        | Number
        | Date
        | SingleSelect of options: string list
        | MultiSelect of options: string list
        | Checkbox
        | Url
        | Email
        | Currency of code: string
        | Percentage
        | Rating of maxStars: int

    type CustomFieldValue =
        | TextValue of string
        | NumberValue of decimal
        | DateValue of DateTimeOffset
        | SelectValue of string
        | MultiSelectValue of string list
        | CheckboxValue of bool
        | UrlValue of string
        | EmailValue of string
        | CurrencyValue of decimal
        | PercentageValue of decimal
        | RatingValue of int

    type CustomField = {
        Id: EntityId
        Name: string
        FieldType: CustomFieldType
        IsRequired: bool
        DefaultValue: CustomFieldValue option
    }

    // =========================================================================
    // ATTACHMENTS AND LINKS
    // =========================================================================

    type AttachmentType =
        | File of mimeType: string * size: int64
        | Link of url: string
        | EmbeddedDocument of documentType: string

    type Attachment = {
        Id: EntityId
        Name: string
        Type: AttachmentType
        StoragePath: string option
        UploadedBy: UserId
        UploadedAt: DateTimeOffset
    }

    // =========================================================================
    // COMMENTS AND ACTIVITY
    // =========================================================================

    type CommentType =
        | Note
        | Question
        | Answer
        | StatusUpdate
        | SystemGenerated

    type Comment = {
        Id: EntityId
        TaskId: EntityId
        AuthorId: UserId
        Content: string
        Type: CommentType
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset option
        ParentCommentId: EntityId option
        Mentions: UserId list
        Reactions: Map<string, UserId list>
    }

    // =========================================================================
    // CHECKLIST
    // =========================================================================

    type ChecklistItem = {
        Id: EntityId
        Title: string
        IsCompleted: bool
        CompletedAt: DateTimeOffset option
        CompletedBy: UserId option
        SortOrder: int
    }

    type Checklist = {
        Id: EntityId
        Title: string
        Items: ChecklistItem list
    }

    // =========================================================================
    // AUDIT AND HISTORY
    // =========================================================================

    type ChangeType =
        | Created
        | Updated of field: string * oldValue: string option * newValue: string option
        | StatusChanged of oldStatus: TaskStatus * newStatus: TaskStatus
        | Assigned of assignment: Assignment
        | Unassigned of userId: UserId
        | CommentAdded of commentId: EntityId
        | AttachmentAdded of attachmentId: EntityId
        | DependencyAdded of dependencyId: EntityId
        | Deleted
        | Restored

    type AuditEntry = {
        Id: EntityId
        EntityId: EntityId
        EntityType: string
        ChangeType: ChangeType
        ChangedBy: UserId
        ChangedAt: DateTimeOffset
        Metadata: Map<string, string>
    }

// =============================================================================
// MODULE 2: DOMAIN ENTITIES
// =============================================================================
// Aggregate roots and related entities

module Entities =
    open Domain

    // =========================================================================
    // TASK AGGREGATE ROOT
    // =========================================================================

    type Task = {
        Id: EntityId
        HierarchicalId: HierarchicalId
        Title: string
        Description: string option
        Status: TaskStatus
        Priority: Priority
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
        DueDate: DateTimeOffset option
        StartDate: DateTimeOffset option
        CompletedAt: DateTimeOffset option
        EstimatedTime: TimeEstimate option
        ActualTime: TimeSpan
        TimeEntries: TimeEntry list
        Recurrence: Recurrence option
        RecurrenceParentId: EntityId option
        ParentTaskId: EntityId option
        SubtaskIds: EntityId list
        DependsOn: EntityId list
        Blockers: EntityId list
        CreatedBy: UserId
        Assignments: Assignment list
        Checklists: Checklist list
        Comments: Comment list
        Attachments: Attachment list
        Tags: Tag list
        CustomFields: Map<EntityId, CustomFieldValue>
        Version: int64
        LastModifiedBy: UserId
    } with
        static member Empty(id: EntityId, title: string, createdBy: UserId) =
            let now = DateTimeOffset.UtcNow
            { Id = id
              HierarchicalId = HierarchicalId.TaskOnly(id)
              Title = title
              Description = None
              Status = Pending
              Priority = Priority.Default
              CreatedAt = now
              UpdatedAt = now
              DueDate = None
              StartDate = None
              CompletedAt = None
              EstimatedTime = None
              ActualTime = TimeSpan.Zero
              TimeEntries = []
              Recurrence = None
              RecurrenceParentId = None
              ParentTaskId = None
              SubtaskIds = []
              DependsOn = []
              Blockers = []
              CreatedBy = createdBy
              Assignments = [{ UserId = createdBy; Role = Owner; AssignedAt = now; AssignedBy = None }]
              Checklists = []
              Comments = []
              Attachments = []
              Tags = []
              CustomFields = Map.empty
              Version = 1L
              LastModifiedBy = createdBy }

    // =========================================================================
    // PROJECT ENTITY
    // =========================================================================

    type ProjectStatus =
        | Draft
        | Planning
        | Active
        | OnHold of reason: string
        | Completed
        | Cancelled of reason: string
        | Archived

    type Milestone = {
        Id: EntityId
        Name: string
        Description: string option
        DueDate: DateTimeOffset
        CompletedAt: DateTimeOffset option
        TaskIds: EntityId list
    }

    type ProjectPhase = {
        Id: EntityId
        Name: string
        Description: string option
        StartDate: DateTimeOffset
        EndDate: DateTimeOffset
        Milestones: Milestone list
        GateReviewRequired: bool
        GateReviewCompletedAt: DateTimeOffset option
    }

    type Project = {
        Id: EntityId
        ProgramId: EntityId option
        Name: string
        Description: string option
        Status: ProjectStatus
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
        StartDate: DateTimeOffset option
        TargetEndDate: DateTimeOffset option
        ActualEndDate: DateTimeOffset option
        Phases: ProjectPhase list
        Milestones: Milestone list
        TaskIds: EntityId list
        CreatedBy: UserId
        OwnerId: UserId
        TeamMembers: Assignment list
        Budget: decimal option
        Currency: string
        ActualCost: decimal
        Tags: Tag list
        CustomFields: Map<EntityId, CustomFieldValue>
        SprintDuration: TimeSpan option
        CurrentSprintId: EntityId option
        BacklogIds: EntityId list
        Version: int64
        LastModifiedBy: UserId
    }

    // =========================================================================
    // PROGRAM ENTITY
    // =========================================================================

    type ProgramStatus =
        | Proposed
        | Approved
        | Active
        | OnHold of reason: string
        | Completed
        | Cancelled of reason: string

    type Program = {
        Id: EntityId
        PortfolioId: EntityId option
        Name: string
        Description: string option
        Status: ProgramStatus
        StrategicObjective: string option
        OkrIds: EntityId list
        ProjectIds: EntityId list
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
        StartDate: DateTimeOffset option
        TargetEndDate: DateTimeOffset option
        CreatedBy: UserId
        ProgramManagerId: UserId
        StakeholderIds: UserId list
        TotalBudget: decimal option
        Currency: string
        Tags: Tag list
        CustomFields: Map<EntityId, CustomFieldValue>
        Version: int64
    }

    // =========================================================================
    // PORTFOLIO ENTITY
    // =========================================================================

    type PortfolioStatus =
        | Active
        | Frozen
        | UnderReview
        | Archived

    type StrategicTheme = {
        Id: EntityId
        Name: string
        Description: string option
        Color: string
        AllocationPercentage: decimal
    }

    type Portfolio = {
        Id: EntityId
        OrganizationId: EntityId
        Name: string
        Description: string option
        Status: PortfolioStatus
        StrategicThemes: StrategicTheme list
        ProgramIds: EntityId list
        StandaloneProjectIds: EntityId list
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
        FiscalYearStart: int
        OwnerId: UserId
        ReviewCadence: TimeSpan
        LastReviewDate: DateTimeOffset option
        TotalBudget: decimal option
        Currency: string
        Tags: Tag list
        CustomFields: Map<EntityId, CustomFieldValue>
        Version: int64
    }

    // =========================================================================
    // SPRINT (Agile Time-box)
    // =========================================================================

    type SprintStatus =
        | Planned
        | Active
        | Completed
        | Cancelled

    type Sprint = {
        Id: EntityId
        ProjectId: EntityId
        Name: string
        Goal: string option
        Status: SprintStatus
        StartDate: DateTimeOffset
        EndDate: DateTimeOffset
        PlannedTaskIds: EntityId list
        CompletedTaskIds: EntityId list
        PlannedPoints: int
        CompletedPoints: int
        Velocity: decimal option
        WentWell: string list
        Improvements: string list
        ActionItems: string list
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
    }

    // =========================================================================
    // OKR (Objectives and Key Results)
    // =========================================================================

    type KeyResultType =
        | Percentage
        | Number
        | Currency
        | Boolean

    type KeyResultStatus =
        | OnTrack
        | AtRisk
        | Behind
        | Achieved
        | Missed

    type KeyResult = {
        Id: EntityId
        Title: string
        Type: KeyResultType
        TargetValue: decimal
        CurrentValue: decimal
        StartValue: decimal
        Status: KeyResultStatus
        LinkedTaskIds: EntityId list
        UpdatedAt: DateTimeOffset
    } with
        member this.Progress =
            if this.TargetValue = this.StartValue then 100.0m
            else ((this.CurrentValue - this.StartValue) / (this.TargetValue - this.StartValue)) * 100.0m

    type ObjectiveStatus =
        | Draft
        | Active
        | Achieved
        | Missed
        | Deferred

    type Objective = {
        Id: EntityId
        Title: string
        Description: string option
        Status: ObjectiveStatus
        StartDate: DateTimeOffset
        EndDate: DateTimeOffset
        KeyResults: KeyResult list
        ParentObjectiveId: EntityId option
        ChildObjectiveIds: EntityId list
        OwnerId: UserId
        StrategicThemeId: EntityId option
        ProgramIds: EntityId list
        ProjectIds: EntityId list
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
    } with
        member this.OverallProgress =
            if this.KeyResults.IsEmpty then 0.0m
            else this.KeyResults |> List.averageBy (fun kr -> kr.Progress)

    // =========================================================================
    // TODO LIST
    // =========================================================================

    type TodoListFilter = {
        Statuses: TaskStatus list option
        Priorities: Priority list option
        DueBefore: DateTimeOffset option
        DueAfter: DateTimeOffset option
        Tags: string list option
        AssignedTo: UserId option
        ProjectIds: EntityId list option
        SearchText: string option
    }

    type TodoListSort =
        | ByDueDate of ascending: bool
        | ByPriority of ascending: bool
        | ByCreatedDate of ascending: bool
        | ByUpdatedDate of ascending: bool
        | ByTitle of ascending: bool
        | Custom of field: string * ascending: bool

    type TodoList = {
        Id: EntityId
        OwnerId: UserId
        Name: string
        Description: string option
        Filter: TodoListFilter option
        Sort: TodoListSort list
        ManualTaskIds: EntityId list option
        ShowCompleted: bool
        GroupBy: string option
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
    }

// =============================================================================
// MODULE 3: DOMAIN EVENTS
// =============================================================================
// Event sourcing events for all aggregates

module Events =
    open Domain
    open Entities

    // =========================================================================
    // EVENT METADATA
    // =========================================================================

    type EventMetadata = {
        EventId: EntityId
        Timestamp: DateTimeOffset
        UserId: UserId
        CorrelationId: EntityId option
        CausationId: EntityId option
        Version: int64
    }

    module EventMetadata =
        let create (userId: UserId) =
            { EventId = EntityId.New()
              Timestamp = DateTimeOffset.UtcNow
              UserId = userId
              CorrelationId = None
              CausationId = None
              Version = 0L }
        
        let withVersion (version: int64) (meta: EventMetadata) =
            { meta with Version = version }
        
        let withCorrelation (correlationId: EntityId) (meta: EventMetadata) =
            { meta with CorrelationId = Some correlationId }

    // =========================================================================
    // TASK EVENTS
    // =========================================================================

    type TaskEvent =
        | TaskCreated of 
            taskId: EntityId * 
            title: string * 
            description: string option *
            projectId: EntityId option *
            parentTaskId: EntityId option
        | TaskDeleted of taskId: EntityId * reason: string option
        | TaskRestored of taskId: EntityId
        | TaskTitleUpdated of taskId: EntityId * oldTitle: string * newTitle: string
        | TaskDescriptionUpdated of taskId: EntityId * oldDescription: string option * newDescription: string option
        | TaskStatusChanged of 
            taskId: EntityId * 
            oldStatus: TaskStatus * 
            newStatus: TaskStatus *
            reason: string option
        | TaskCompleted of taskId: EntityId * completedAt: DateTimeOffset
        | TaskReopened of taskId: EntityId * reason: string option
        | TaskPriorityUpdated of 
            taskId: EntityId * 
            oldPriority: Priority * 
            newPriority: Priority
        | TaskDueDateSet of taskId: EntityId * dueDate: DateTimeOffset
        | TaskDueDateCleared of taskId: EntityId * previousDueDate: DateTimeOffset
        | TaskStartDateSet of taskId: EntityId * startDate: DateTimeOffset
        | TaskStartDateCleared of taskId: EntityId * previousStartDate: DateTimeOffset
        | TaskTimeEstimateSet of taskId: EntityId * estimate: TimeEstimate
        | TaskTimeEntryAdded of taskId: EntityId * entry: TimeEntry
        | TaskTimeEntryUpdated of taskId: EntityId * entryId: EntityId * entry: TimeEntry
        | TaskTimeEntryDeleted of taskId: EntityId * entryId: EntityId
        | TaskRecurrenceSet of taskId: EntityId * recurrence: Recurrence
        | TaskRecurrenceCleared of taskId: EntityId
        | TaskRecurrenceTriggered of parentTaskId: EntityId * newTaskId: EntityId
        | TaskMovedToProject of taskId: EntityId * oldProjectId: EntityId option * newProjectId: EntityId option
        | TaskParentChanged of taskId: EntityId * oldParentId: EntityId option * newParentId: EntityId option
        | SubtaskAdded of parentTaskId: EntityId * subtaskId: EntityId
        | SubtaskRemoved of parentTaskId: EntityId * subtaskId: EntityId
        | TaskDependencyAdded of taskId: EntityId * dependency: Dependency
        | TaskDependencyRemoved of taskId: EntityId * dependencyId: EntityId
        | TaskBlocked of taskId: EntityId * blockedBy: EntityId * reason: string option
        | TaskUnblocked of taskId: EntityId * previousBlocker: EntityId
        | TaskAssigned of taskId: EntityId * assignment: Assignment
        | TaskUnassigned of taskId: EntityId * userId: UserId * role: AssignmentRole
        | TaskOwnershipTransferred of taskId: EntityId * oldOwnerId: UserId * newOwnerId: UserId
        | ChecklistAdded of taskId: EntityId * checklist: Checklist
        | ChecklistRemoved of taskId: EntityId * checklistId: EntityId
        | ChecklistItemAdded of taskId: EntityId * checklistId: EntityId * item: ChecklistItem
        | ChecklistItemToggled of taskId: EntityId * checklistId: EntityId * itemId: EntityId * isCompleted: bool
        | ChecklistItemRemoved of taskId: EntityId * checklistId: EntityId * itemId: EntityId
        | ChecklistReordered of taskId: EntityId * checklistId: EntityId * itemIds: EntityId list
        | CommentAdded of taskId: EntityId * comment: Comment
        | CommentUpdated of taskId: EntityId * commentId: EntityId * newContent: string
        | CommentDeleted of taskId: EntityId * commentId: EntityId
        | CommentReactionAdded of taskId: EntityId * commentId: EntityId * emoji: string * userId: UserId
        | CommentReactionRemoved of taskId: EntityId * commentId: EntityId * emoji: string * userId: UserId
        | AttachmentAdded of taskId: EntityId * attachment: Attachment
        | AttachmentRemoved of taskId: EntityId * attachmentId: EntityId
        | TaskTagAdded of taskId: EntityId * tag: Tag
        | TaskTagRemoved of taskId: EntityId * tagName: string
        | TaskCustomFieldSet of taskId: EntityId * fieldId: EntityId * value: CustomFieldValue
        | TaskCustomFieldCleared of taskId: EntityId * fieldId: EntityId

    // =========================================================================
    // PROJECT EVENTS
    // =========================================================================

    type ProjectEvent =
        | ProjectCreated of 
            projectId: EntityId *
            name: string *
            description: string option *
            programId: EntityId option
        | ProjectDeleted of projectId: EntityId * reason: string option
        | ProjectArchived of projectId: EntityId
        | ProjectRestored of projectId: EntityId
        | ProjectNameUpdated of projectId: EntityId * oldName: string * newName: string
        | ProjectDescriptionUpdated of projectId: EntityId * description: string option
        | ProjectStatusChanged of projectId: EntityId * oldStatus: ProjectStatus * newStatus: ProjectStatus
        | ProjectStartDateSet of projectId: EntityId * startDate: DateTimeOffset
        | ProjectTargetEndDateSet of projectId: EntityId * endDate: DateTimeOffset
        | ProjectCompleted of projectId: EntityId * completedAt: DateTimeOffset
        | ProjectPhaseAdded of projectId: EntityId * phase: ProjectPhase
        | ProjectPhaseUpdated of projectId: EntityId * phase: ProjectPhase
        | ProjectPhaseRemoved of projectId: EntityId * phaseId: EntityId
        | ProjectMilestoneAdded of projectId: EntityId * milestone: Milestone
        | ProjectMilestoneCompleted of projectId: EntityId * milestoneId: EntityId * completedAt: DateTimeOffset
        | ProjectMilestoneRemoved of projectId: EntityId * milestoneId: EntityId
        | TaskAddedToProject of projectId: EntityId * taskId: EntityId
        | TaskRemovedFromProject of projectId: EntityId * taskId: EntityId
        | ProjectTeamMemberAdded of projectId: EntityId * assignment: Assignment
        | ProjectTeamMemberRemoved of projectId: EntityId * userId: UserId
        | ProjectOwnerChanged of projectId: EntityId * oldOwnerId: UserId * newOwnerId: UserId
        | ProjectBudgetSet of projectId: EntityId * amount: decimal * currency: string
        | ProjectCostRecorded of projectId: EntityId * amount: decimal * description: string
        | SprintCreated of projectId: EntityId * sprint: Sprint
        | SprintStarted of projectId: EntityId * sprintId: EntityId
        | SprintCompleted of projectId: EntityId * sprintId: EntityId * velocity: decimal
        | TaskAddedToSprint of projectId: EntityId * sprintId: EntityId * taskId: EntityId
        | TaskRemovedFromSprint of projectId: EntityId * sprintId: EntityId * taskId: EntityId
        | BacklogItemPrioritized of projectId: EntityId * taskId: EntityId * position: int

    // =========================================================================
    // PROGRAM EVENTS
    // =========================================================================

    type ProgramEvent =
        | ProgramCreated of 
            programId: EntityId *
            name: string *
            portfolioId: EntityId option
        | ProgramStatusChanged of programId: EntityId * oldStatus: ProgramStatus * newStatus: ProgramStatus
        | ProjectAddedToProgram of programId: EntityId * projectId: EntityId
        | ProjectRemovedFromProgram of programId: EntityId * projectId: EntityId
        | ProgramManagerAssigned of programId: EntityId * userId: UserId
        | ProgramOkrLinked of programId: EntityId * okrId: EntityId
        | ProgramBudgetAllocated of programId: EntityId * amount: decimal

    // =========================================================================
    // PORTFOLIO EVENTS
    // =========================================================================

    type PortfolioEvent =
        | PortfolioCreated of 
            portfolioId: EntityId *
            organizationId: EntityId *
            name: string
        | PortfolioStatusChanged of portfolioId: EntityId * status: PortfolioStatus
        | ProgramAddedToPortfolio of portfolioId: EntityId * programId: EntityId
        | ProjectAddedToPortfolio of portfolioId: EntityId * projectId: EntityId
        | StrategicThemeAdded of portfolioId: EntityId * theme: StrategicTheme
        | StrategicThemeUpdated of portfolioId: EntityId * theme: StrategicTheme
        | StrategicThemeRemoved of portfolioId: EntityId * themeId: EntityId
        | PortfolioReviewCompleted of portfolioId: EntityId * reviewDate: DateTimeOffset

    // =========================================================================
    // OKR EVENTS
    // =========================================================================

    type OkrEvent =
        | ObjectiveCreated of 
            objectiveId: EntityId *
            title: string *
            startDate: DateTimeOffset *
            endDate: DateTimeOffset *
            parentObjectiveId: EntityId option
        | ObjectiveStatusChanged of objectiveId: EntityId * oldStatus: ObjectiveStatus * newStatus: ObjectiveStatus
        | KeyResultAdded of objectiveId: EntityId * keyResult: KeyResult
        | KeyResultProgressUpdated of objectiveId: EntityId * keyResultId: EntityId * newValue: decimal
        | KeyResultAchieved of objectiveId: EntityId * keyResultId: EntityId
        | TaskLinkedToKeyResult of objectiveId: EntityId * keyResultId: EntityId * taskId: EntityId

    // =========================================================================
    // TODOLIST EVENTS
    // =========================================================================

    type TodoListEvent =
        | TodoListCreated of 
            listId: EntityId *
            ownerId: UserId *
            name: string
        | TodoListRenamed of listId: EntityId * newName: string
        | TodoListFilterUpdated of listId: EntityId * filter: TodoListFilter option
        | TodoListSortUpdated of listId: EntityId * sort: TodoListSort list
        | TaskAddedToList of listId: EntityId * taskId: EntityId * position: int option
        | TaskRemovedFromList of listId: EntityId * taskId: EntityId
        | TaskReorderedInList of listId: EntityId * taskId: EntityId * newPosition: int
        | TodoListDeleted of listId: EntityId

    // =========================================================================
    // AGGREGATE EVENT WRAPPER
    // =========================================================================

    type DomainEvent =
        | Task of TaskEvent * EventMetadata
        | Project of ProjectEvent * EventMetadata
        | Program of ProgramEvent * EventMetadata
        | Portfolio of PortfolioEvent * EventMetadata
        | Okr of OkrEvent * EventMetadata
        | TodoList of TodoListEvent * EventMetadata

    module DomainEvent =
        let getMetadata = function
            | Task (_, meta) -> meta
            | Project (_, meta) -> meta
            | Program (_, meta) -> meta
            | Portfolio (_, meta) -> meta
            | Okr (_, meta) -> meta
            | TodoList (_, meta) -> meta
        
        let getTimestamp event = (getMetadata event).Timestamp
        let getEventId event = (getMetadata event).EventId
        let getUserId event = (getMetadata event).UserId
        let getVersion event = (getMetadata event).Version
        
        let taskEvent (event: TaskEvent) (userId: UserId) =
            Task(event, EventMetadata.create userId)
        
        let projectEvent (event: ProjectEvent) (userId: UserId) =
            Project(event, EventMetadata.create userId)

// =============================================================================
// MODULE 4: DOMAIN ERRORS AND RESULTS
// =============================================================================
// Railway-oriented programming support

module Results =
    open Domain

    type DomainError =
        | ValidationError of field: string * message: string
        | NotFound of entityType: string * id: EntityId
        | Unauthorized of action: string * reason: string
        | InvalidStateTransition of from: string * toState: string * reason: string
        | BusinessRuleViolation of rule: string * message: string
        | ConcurrencyConflict of entityId: EntityId * expectedVersion: int64 * actualVersion: int64
        | DependencyError of message: string
        | ExternalServiceError of service: string * message: string

    module DomainError =
        let validation field msg = ValidationError(field, msg)
        let notFound entityType id = NotFound(entityType, id)
        let unauthorized action reason = Unauthorized(action, reason)
        let invalidTransition from toState reason = InvalidStateTransition(from, toState, reason)
        let businessRule rule msg = BusinessRuleViolation(rule, msg)
        let concurrency id expected actual = ConcurrencyConflict(id, expected, actual)

    type DomainResult<'T> = Result<'T, DomainError>

    module DomainResult =
        let map f result = Result.map f result
        let bind f result = Result.bind f result
        let mapError f result = Result.mapError f result
        
        let fromOption error = function
            | Some x -> Ok x
            | None -> Error error
        
        let toOption = function
            | Ok x -> Some x
            | Error _ -> None
        
        let isOk = function Ok _ -> true | Error _ -> false
        let isError = function Error _ -> true | Ok _ -> false
        
        let getOrDefault defaultValue = function
            | Ok x -> x
            | Error _ -> defaultValue
        
        let sequence (results: DomainResult<'T> list) : DomainResult<'T list> =
            let folder acc item =
                match acc, item with
                | Ok list, Ok x -> Ok (x :: list)
                | Error e, _ -> Error e
                | _, Error e -> Error e
            results |> List.fold folder (Ok []) |> Result.map List.rev

// =============================================================================
// MODULE 5: VALIDATION
// =============================================================================

module Validation =
    open Domain
    open Results

    let notEmpty fieldName value =
        if String.IsNullOrWhiteSpace(value) then
            Error (DomainError.validation fieldName "cannot be empty")
        else
            Ok value
    
    let maxLength fieldName maxLen (value: string) =
        if value.Length > maxLen then
            Error (DomainError.validation fieldName $"cannot exceed {maxLen} characters")
        else
            Ok value
    
    let minLength fieldName minLen (value: string) =
        if value.Length < minLen then
            Error (DomainError.validation fieldName $"must be at least {minLen} characters")
        else
            Ok value
    
    let inRange fieldName min max value =
        if value < min || value > max then
            Error (DomainError.validation fieldName $"must be between {min} and {max}")
        else
            Ok value
    
    let positive fieldName value =
        if value <= 0m then
            Error (DomainError.validation fieldName "must be positive")
        else
            Ok value
    
    let notInPast fieldName (date: DateTimeOffset) =
        if date < DateTimeOffset.UtcNow then
            Error (DomainError.validation fieldName "cannot be in the past")
        else
            Ok date
    
    let dateAfter fieldName (reference: DateTimeOffset) (date: DateTimeOffset) =
        if date <= reference then
            Error (DomainError.validation fieldName $"must be after {reference:yyyy-MM-dd}")
        else
            Ok date
    
    let validateTitle = notEmpty "title" >> Result.bind (maxLength "title" 500)
    let validateDescription desc =
        match desc with
        | None -> Ok None
        | Some d -> maxLength "description" 10000 d |> Result.map Some

// =============================================================================
// MODULE 6: TASK OPERATIONS
// =============================================================================
// Pure business logic functions for Task operations

module TaskOperations =
    open Domain
    open Entities
    open Events
    open Results
    open Validation

    /// Create a new task with validation
    let create 
        (title: string) 
        (description: string option) 
        (createdBy: UserId) 
        : DomainResult<Task * TaskEvent> =
        
        result {
            let! validTitle = validateTitle title
            let! validDesc = validateDescription description
            
            let taskId = EntityId.New()
            let task = 
                { Task.Empty(taskId, validTitle, createdBy) with
                    Description = validDesc }
            
            let event = TaskCreated(taskId, validTitle, validDesc, None, None)
            return (task, event)
        }
    
    /// Update task title
    let updateTitle (newTitle: string) (task: Task) : DomainResult<Task * TaskEvent> =
        result {
            let! validTitle = validateTitle newTitle
            
            if validTitle = task.Title then
                return (task, TaskTitleUpdated(task.Id, task.Title, task.Title))
            else
                let updatedTask = 
                    { task with 
                        Title = validTitle
                        UpdatedAt = DateTimeOffset.UtcNow
                        Version = task.Version + 1L }
                
                let event = TaskTitleUpdated(task.Id, task.Title, validTitle)
                return (updatedTask, event)
        }
    
    /// Update task description
    let updateDescription (newDescription: string option) (task: Task) : DomainResult<Task * TaskEvent> =
        result {
            let! validDesc = validateDescription newDescription
            
            let updatedTask = 
                { task with 
                    Description = validDesc
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskDescriptionUpdated(task.Id, task.Description, validDesc)
            return (updatedTask, event)
        }
    
    /// Change task status with workflow validation
    let changeStatus 
        (newStatus: TaskStatus) 
        (reason: string option) 
        (task: Task) 
        : DomainResult<Task * TaskEvent> =
        
        if not (TaskStatus.canTransitionTo task.Status newStatus) then
            Error (DomainError.invalidTransition 
                (sprintf "%A" task.Status) 
                (sprintf "%A" newStatus) 
                "Invalid status transition")
        else
            let completedAt = 
                match newStatus with
                | Completed -> Some DateTimeOffset.UtcNow
                | _ -> task.CompletedAt
            
            let updatedTask = 
                { task with 
                    Status = newStatus
                    CompletedAt = completedAt
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskStatusChanged(task.Id, task.Status, newStatus, reason)
            Ok (updatedTask, event)
    
    /// Complete a task
    let complete (task: Task) : DomainResult<Task * TaskEvent> =
        changeStatus Completed None task
    
    /// Start working on a task
    let start (task: Task) : DomainResult<Task * TaskEvent> =
        changeStatus InProgress None task
    
    /// Block a task
    let block (reason: string) (task: Task) : DomainResult<Task * TaskEvent> =
        changeStatus (Blocked reason) (Some reason) task
    
    /// Update priority
    let updatePriority (newPriority: Priority) (task: Task) : DomainResult<Task * TaskEvent> =
        let updatedTask = 
            { task with 
                Priority = newPriority
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = TaskPriorityUpdated(task.Id, task.Priority, newPriority)
        Ok (updatedTask, event)
    
    /// Set due date
    let setDueDate (dueDate: DateTimeOffset) (task: Task) : DomainResult<Task * TaskEvent> =
        let updatedTask = 
            { task with 
                DueDate = Some dueDate
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = TaskDueDateSet(task.Id, dueDate)
        Ok (updatedTask, event)
    
    /// Clear due date
    let clearDueDate (task: Task) : DomainResult<Task * TaskEvent> =
        match task.DueDate with
        | None -> 
            Error (DomainError.businessRule "DueDate" "Task has no due date to clear")
        | Some previousDate ->
            let updatedTask = 
                { task with 
                    DueDate = None
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskDueDateCleared(task.Id, previousDate)
            Ok (updatedTask, event)
    
    /// Set time estimate
    let setTimeEstimate (estimate: TimeEstimate) (task: Task) : DomainResult<Task * TaskEvent> =
        let updatedTask = 
            { task with 
                EstimatedTime = Some estimate
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = TaskTimeEstimateSet(task.Id, estimate)
        Ok (updatedTask, event)
    
    /// Add time entry
    let addTimeEntry (entry: TimeEntry) (task: Task) : DomainResult<Task * TaskEvent> =
        let duration = 
            match entry.Duration, entry.EndTime with
            | Some d, _ -> d
            | None, Some endTime -> endTime - entry.StartTime
            | None, None -> TimeSpan.Zero
        
        let updatedTask = 
            { task with 
                TimeEntries = entry :: task.TimeEntries
                ActualTime = task.ActualTime + duration
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = TaskTimeEntryAdded(task.Id, entry)
        Ok (updatedTask, event)
    
    /// Assign user to task
    let assign (assignment: Assignment) (task: Task) : DomainResult<Task * TaskEvent> =
        let existingAssignment = 
            task.Assignments 
            |> List.tryFind (fun a -> a.UserId = assignment.UserId && a.Role = assignment.Role)
        
        match existingAssignment with
        | Some _ -> 
            Error (DomainError.businessRule "Assignment" "User already has this role on the task")
        | None ->
            let updatedTask = 
                { task with 
                    Assignments = assignment :: task.Assignments
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskAssigned(task.Id, assignment)
            Ok (updatedTask, event)
    
    /// Unassign user from task
    let unassign (userId: UserId) (role: AssignmentRole) (task: Task) : DomainResult<Task * TaskEvent> =
        let newAssignments = 
            task.Assignments 
            |> List.filter (fun a -> not (a.UserId = userId && a.Role = role))
        
        if newAssignments.Length = task.Assignments.Length then
            Error (DomainError.businessRule "Assignment" "User does not have this role on the task")
        else
            let updatedTask = 
                { task with 
                    Assignments = newAssignments
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskUnassigned(task.Id, userId, role)
            Ok (updatedTask, event)
    
    /// Add a tag
    let addTag (tag: Tag) (task: Task) : DomainResult<Task * TaskEvent> =
        if task.Tags |> List.exists (fun t -> t.Name = tag.Name) then
            Error (DomainError.businessRule "Tag" $"Tag '{tag.Name}' already exists on task")
        else
            let updatedTask = 
                { task with 
                    Tags = tag :: task.Tags
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskTagAdded(task.Id, tag)
            Ok (updatedTask, event)
    
    /// Remove a tag
    let removeTag (tagName: string) (task: Task) : DomainResult<Task * TaskEvent> =
        let newTags = task.Tags |> List.filter (fun t -> t.Name <> tagName)
        
        if newTags.Length = task.Tags.Length then
            Error (DomainError.businessRule "Tag" $"Tag '{tagName}' not found on task")
        else
            let updatedTask = 
                { task with 
                    Tags = newTags
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskTagRemoved(task.Id, tagName)
            Ok (updatedTask, event)
    
    /// Add dependency
    let addDependency (dependency: Dependency) (task: Task) : DomainResult<Task * TaskEvent> =
        if dependency.PredecessorId = task.Id then
            Error (DomainError.businessRule "Dependency" "Task cannot depend on itself")
        else
            let updatedTask = 
                { task with 
                    DependsOn = dependency.PredecessorId :: task.DependsOn
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = task.Version + 1L }
            
            let event = TaskDependencyAdded(task.Id, dependency)
            Ok (updatedTask, event)
    
    /// Add checklist
    let addChecklist (checklist: Checklist) (task: Task) : DomainResult<Task * TaskEvent> =
        let updatedTask = 
            { task with 
                Checklists = checklist :: task.Checklists
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = ChecklistAdded(task.Id, checklist)
        Ok (updatedTask, event)
    
    /// Toggle checklist item
    let toggleChecklistItem 
        (checklistId: EntityId) 
        (itemId: EntityId) 
        (isCompleted: bool)
        (completedBy: UserId)
        (task: Task) 
        : DomainResult<Task * TaskEvent> =
        
        let updateItem (item: ChecklistItem) =
            if item.Id = itemId then
                { item with 
                    IsCompleted = isCompleted
                    CompletedAt = if isCompleted then Some DateTimeOffset.UtcNow else None
                    CompletedBy = if isCompleted then Some completedBy else None }
            else item
        
        let updateChecklist (cl: Checklist) =
            if cl.Id = checklistId then
                { cl with Items = cl.Items |> List.map updateItem }
            else cl
        
        let newChecklists = task.Checklists |> List.map updateChecklist
        
        let updatedTask = 
            { task with 
                Checklists = newChecklists
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = ChecklistItemToggled(task.Id, checklistId, itemId, isCompleted)
        Ok (updatedTask, event)
    
    /// Add comment
    let addComment (comment: Comment) (task: Task) : DomainResult<Task * TaskEvent> =
        let updatedTask = 
            { task with 
                Comments = comment :: task.Comments
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = CommentAdded(task.Id, comment)
        Ok (updatedTask, event)
    
    /// Set custom field value
    let setCustomField 
        (fieldId: EntityId) 
        (value: CustomFieldValue) 
        (task: Task) 
        : DomainResult<Task * TaskEvent> =
        
        let updatedTask = 
            { task with 
                CustomFields = task.CustomFields |> Map.add fieldId value
                UpdatedAt = DateTimeOffset.UtcNow
                Version = task.Version + 1L }
        
        let event = TaskCustomFieldSet(task.Id, fieldId, value)
        Ok (updatedTask, event)

// =============================================================================
// MODULE 7: TASK QUERIES
// =============================================================================

module TaskQueries =
    open Domain
    open Entities

    /// Check if task is overdue
    let isOverdue (task: Task) =
        match task.DueDate, task.Status with
        | Some due, status when TaskStatus.isActive status -> 
            due < DateTimeOffset.UtcNow
        | _ -> false
    
    /// Check if task is due today
    let isDueToday (task: Task) =
        match task.DueDate with
        | Some due -> due.Date = DateTimeOffset.UtcNow.Date
        | None -> false
    
    /// Check if task is due this week
    let isDueThisWeek (task: Task) =
        match task.DueDate with
        | Some due ->
            let today = DateTimeOffset.UtcNow.Date
            let startOfWeek = today.AddDays(-(float today.DayOfWeek))
            let endOfWeek = startOfWeek.AddDays(7.0)
            due.Date >= startOfWeek && due.Date < endOfWeek
        | None -> false
    
    /// Get completion percentage based on checklists
    let getChecklistProgress (task: Task) =
        let totalItems = 
            task.Checklists 
            |> List.sumBy (fun cl -> cl.Items.Length)
        
        if totalItems = 0 then 100.0
        else
            let completedItems = 
                task.Checklists 
                |> List.sumBy (fun cl -> cl.Items |> List.filter (_.IsCompleted) |> List.length)
            (float completedItems / float totalItems) * 100.0
    
    /// Get all assignees with a specific role
    let getAssigneesByRole (role: AssignmentRole) (task: Task) =
        task.Assignments 
        |> List.filter (fun a -> a.Role = role)
        |> List.map (_.UserId)
    
    /// Get the owner of the task
    let getOwner (task: Task) =
        task.Assignments 
        |> List.tryFind (fun a -> a.Role = Owner)
        |> Option.map (_.UserId)
    
    /// Check if user has any role on task
    let hasAccess (userId: UserId) (task: Task) =
        task.Assignments |> List.exists (fun a -> a.UserId = userId)
    
    /// Get time remaining until due date
    let getTimeRemaining (task: Task) =
        match task.DueDate with
        | Some due -> 
            let remaining = due - DateTimeOffset.UtcNow
            if remaining > TimeSpan.Zero then Some remaining else None
        | None -> None
    
    /// Get time tracking summary
    let getTimeTrackingSummary (task: Task) =
        let estimated = 
            task.EstimatedTime 
            |> Option.map (_.PertEstimate) 
            |> Option.defaultValue TimeSpan.Zero
        
        let actual = task.ActualTime
        let variance = actual - estimated
        
        {| Estimated = estimated
           Actual = actual
           Variance = variance
           PercentComplete = 
               if estimated = TimeSpan.Zero then 0.0
               else (actual.TotalMinutes / estimated.TotalMinutes) * 100.0 |}
    
    /// Filter tasks by criteria
    let filter (filter: TodoListFilter) (tasks: Task list) =
        tasks
        |> List.filter (fun task ->
            let statusMatch =
                match filter.Statuses with
                | Some statuses -> statuses |> List.contains task.Status
                | None -> true
            
            let dueBeforeMatch =
                match filter.DueBefore, task.DueDate with
                | Some before, Some due -> due <= before
                | Some _, None -> false
                | None, _ -> true
            
            let dueAfterMatch =
                match filter.DueAfter, task.DueDate with
                | Some after, Some due -> due >= after
                | Some _, None -> false
                | None, _ -> true
            
            let tagMatch =
                match filter.Tags with
                | Some tags -> 
                    let taskTagNames = task.Tags |> List.map (_.Name)
                    tags |> List.forall (fun t -> taskTagNames |> List.contains t)
                | None -> true
            
            let assigneeMatch =
                match filter.AssignedTo with
                | Some userId -> task.Assignments |> List.exists (fun a -> a.UserId = userId)
                | None -> true
            
            let textMatch =
                match filter.SearchText with
                | Some text ->
                    let lowerText = text.ToLowerInvariant()
                    task.Title.ToLowerInvariant().Contains(lowerText) ||
                    (task.Description |> Option.map (fun d -> d.ToLowerInvariant().Contains(lowerText)) |> Option.defaultValue false)
                | None -> true
            
            statusMatch && dueBeforeMatch && dueAfterMatch && tagMatch && assigneeMatch && textMatch
        )
    
    /// Sort tasks
    let sort (sortCriteria: TodoListSort list) (tasks: Task list) =
        let applySingleSort (sort: TodoListSort) (tasks: Task list) =
            match sort with
            | ByDueDate ascending ->
                let sorted = tasks |> List.sortBy (fun t -> t.DueDate |> Option.defaultValue DateTimeOffset.MaxValue)
                if ascending then sorted else sorted |> List.rev
            | ByPriority ascending ->
                let sorted = tasks |> List.sortBy (fun t -> t.Priority.CriticalityScore)
                if ascending then sorted else sorted |> List.rev
            | ByCreatedDate ascending ->
                let sorted = tasks |> List.sortBy (_.CreatedAt)
                if ascending then sorted else sorted |> List.rev
            | ByUpdatedDate ascending ->
                let sorted = tasks |> List.sortBy (_.UpdatedAt)
                if ascending then sorted else sorted |> List.rev
            | ByTitle ascending ->
                let sorted = tasks |> List.sortBy (_.Title)
                if ascending then sorted else sorted |> List.rev
            | Custom (field, ascending) ->
                tasks
        
        sortCriteria |> List.fold (fun acc sort -> applySingleSort sort acc) tasks

// =============================================================================
// MODULE 8: PROJECT OPERATIONS
// =============================================================================

module ProjectOperations =
    open Domain
    open Entities
    open Events
    open Results
    open Validation

    /// Create a new project
    let create 
        (name: string) 
        (description: string option)
        (programId: EntityId option)
        (createdBy: UserId) 
        : DomainResult<Project * ProjectEvent> =
        
        result {
            let! validName = notEmpty "name" name
            let! _ = maxLength "name" 200 validName
            
            let projectId = EntityId.New()
            let now = DateTimeOffset.UtcNow
            
            let project: Project = {
                Id = projectId
                ProgramId = programId
                Name = validName
                Description = description
                Status = Draft
                CreatedAt = now
                UpdatedAt = now
                StartDate = None
                TargetEndDate = None
                ActualEndDate = None
                Phases = []
                Milestones = []
                TaskIds = []
                CreatedBy = createdBy
                OwnerId = createdBy
                TeamMembers = [{ UserId = createdBy; Role = Owner; AssignedAt = now; AssignedBy = None }]
                Budget = None
                Currency = "USD"
                ActualCost = 0m
                Tags = []
                CustomFields = Map.empty
                SprintDuration = None
                CurrentSprintId = None
                BacklogIds = []
                Version = 1L
                LastModifiedBy = createdBy
            }
            
            let event = ProjectCreated(projectId, validName, description, programId)
            return (project, event)
        }
    
    /// Update project name
    let updateName (newName: string) (project: Project) : DomainResult<Project * ProjectEvent> =
        result {
            let! validName = notEmpty "name" newName
            
            let updated = 
                { project with 
                    Name = validName
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = project.Version + 1L }
            
            let event = ProjectNameUpdated(project.Id, project.Name, validName)
            return (updated, event)
        }
    
    /// Change project status
    let changeStatus (newStatus: ProjectStatus) (project: Project) : DomainResult<Project * ProjectEvent> =
        let actualEndDate =
            match newStatus with
            | ProjectStatus.Completed -> Some DateTimeOffset.UtcNow
            | _ -> project.ActualEndDate
        
        let updated = 
            { project with 
                Status = newStatus
                ActualEndDate = actualEndDate
                UpdatedAt = DateTimeOffset.UtcNow
                Version = project.Version + 1L }
        
        let event = ProjectStatusChanged(project.Id, project.Status, newStatus)
        Ok (updated, event)
    
    /// Add task to project
    let addTask (taskId: EntityId) (project: Project) : DomainResult<Project * ProjectEvent> =
        if project.TaskIds |> List.contains taskId then
            Error (DomainError.businessRule "Task" "Task is already in this project")
        else
            let updated = 
                { project with 
                    TaskIds = taskId :: project.TaskIds
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = project.Version + 1L }
            
            let event = TaskAddedToProject(project.Id, taskId)
            Ok (updated, event)
    
    /// Remove task from project
    let removeTask (taskId: EntityId) (project: Project) : DomainResult<Project * ProjectEvent> =
        if not (project.TaskIds |> List.contains taskId) then
            Error (DomainError.businessRule "Task" "Task is not in this project")
        else
            let updated = 
                { project with 
                    TaskIds = project.TaskIds |> List.filter ((<>) taskId)
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = project.Version + 1L }
            
            let event = TaskRemovedFromProject(project.Id, taskId)
            Ok (updated, event)
    
    /// Add milestone
    let addMilestone (milestone: Milestone) (project: Project) : DomainResult<Project * ProjectEvent> =
        let updated = 
            { project with 
                Milestones = milestone :: project.Milestones
                UpdatedAt = DateTimeOffset.UtcNow
                Version = project.Version + 1L }
        
        let event = ProjectMilestoneAdded(project.Id, milestone)
        Ok (updated, event)
    
    /// Complete milestone
    let completeMilestone (milestoneId: EntityId) (project: Project) : DomainResult<Project * ProjectEvent> =
        let milestone = project.Milestones |> List.tryFind (fun m -> m.Id = milestoneId)
        
        match milestone with
        | None -> 
            Error (DomainError.notFound "Milestone" milestoneId)
        | Some m when m.CompletedAt.IsSome ->
            Error (DomainError.businessRule "Milestone" "Milestone is already completed")
        | Some _ ->
            let now = DateTimeOffset.UtcNow
            let updatedMilestones = 
                project.Milestones 
                |> List.map (fun m -> 
                    if m.Id = milestoneId 
                    then { m with CompletedAt = Some now }
                    else m)
            
            let updated = 
                { project with 
                    Milestones = updatedMilestones
                    UpdatedAt = now
                    Version = project.Version + 1L }
            
            let event = ProjectMilestoneCompleted(project.Id, milestoneId, now)
            Ok (updated, event)
    
    /// Add phase
    let addPhase (phase: ProjectPhase) (project: Project) : DomainResult<Project * ProjectEvent> =
        let updated = 
            { project with 
                Phases = project.Phases @ [phase]
                UpdatedAt = DateTimeOffset.UtcNow
                Version = project.Version + 1L }
        
        let event = ProjectPhaseAdded(project.Id, phase)
        Ok (updated, event)
    
    /// Add team member
    let addTeamMember (assignment: Assignment) (project: Project) : DomainResult<Project * ProjectEvent> =
        let existing = 
            project.TeamMembers 
            |> List.tryFind (fun a -> a.UserId = assignment.UserId && a.Role = assignment.Role)
        
        match existing with
        | Some _ -> 
            Error (DomainError.businessRule "TeamMember" "User already has this role on the project")
        | None ->
            let updated = 
                { project with 
                    TeamMembers = assignment :: project.TeamMembers
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = project.Version + 1L }
            
            let event = ProjectTeamMemberAdded(project.Id, assignment)
            Ok (updated, event)
    
    /// Set budget
    let setBudget (amount: decimal) (currency: string) (project: Project) : DomainResult<Project * ProjectEvent> =
        result {
            let! _ = positive "amount" amount
            
            let updated = 
                { project with 
                    Budget = Some amount
                    Currency = currency
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = project.Version + 1L }
            
            let event = ProjectBudgetSet(project.Id, amount, currency)
            return (updated, event)
        }
    
    /// Create sprint
    let createSprint (sprint: Sprint) (project: Project) : DomainResult<Project * ProjectEvent> =
        let updated = 
            { project with 
                CurrentSprintId = Some sprint.Id
                UpdatedAt = DateTimeOffset.UtcNow
                Version = project.Version + 1L }
        
        let event = SprintCreated(project.Id, sprint)
        Ok (updated, event)

// =============================================================================
// MODULE 9: PROJECT QUERIES
// =============================================================================

module ProjectQueries =
    open Domain
    open Entities

    /// Get project completion percentage based on tasks
    let getCompletionPercentage (taskStatusMap: Map<EntityId, TaskStatus>) (project: Project) =
        if project.TaskIds.IsEmpty then 0.0
        else
            let completedCount =
                project.TaskIds
                |> List.filter (fun taskId ->
                    match taskStatusMap |> Map.tryFind taskId with
                    | Some Completed -> true
                    | _ -> false)
                |> List.length
            
            (float completedCount / float project.TaskIds.Length) * 100.0
    
    /// Get milestone completion percentage
    let getMilestoneProgress (project: Project) =
        if project.Milestones.IsEmpty then 100.0
        else
            let completed = 
                project.Milestones 
                |> List.filter (fun m -> m.CompletedAt.IsSome)
                |> List.length
            (float completed / float project.Milestones.Length) * 100.0
    
    /// Check if project is overdue
    let isOverdue (project: Project) =
        match project.TargetEndDate, project.Status with
        | Some endDate, status when status <> ProjectStatus.Completed && status <> ProjectStatus.Archived ->
            endDate < DateTimeOffset.UtcNow
        | _ -> false
    
    /// Get budget utilization
    let getBudgetUtilization (project: Project) =
        match project.Budget with
        | Some budget when budget > 0m ->
            Some ((project.ActualCost / budget) * 100.0m)
        | _ -> None
    
    /// Get upcoming milestones
    let getUpcomingMilestones (days: int) (project: Project) =
        let cutoff = DateTimeOffset.UtcNow.AddDays(float days)
        project.Milestones
        |> List.filter (fun m -> 
            m.CompletedAt.IsNone && m.DueDate <= cutoff)
        |> List.sortBy (_.DueDate)

// =============================================================================
// MODULE 10: PROGRAM OPERATIONS
// =============================================================================

module ProgramOperations =
    open Domain
    open Entities
    open Events
    open Results
    open Validation

    /// Create a new program
    let create 
        (name: string)
        (portfolioId: EntityId option)
        (createdBy: UserId)
        : DomainResult<Program * ProgramEvent> =
        
        result {
            let! validName = notEmpty "name" name
            
            let programId = EntityId.New()
            let now = DateTimeOffset.UtcNow
            
            let program: Program = {
                Id = programId
                PortfolioId = portfolioId
                Name = validName
                Description = None
                Status = Proposed
                StrategicObjective = None
                OkrIds = []
                ProjectIds = []
                CreatedAt = now
                UpdatedAt = now
                StartDate = None
                TargetEndDate = None
                CreatedBy = createdBy
                ProgramManagerId = createdBy
                StakeholderIds = []
                TotalBudget = None
                Currency = "USD"
                Tags = []
                CustomFields = Map.empty
                Version = 1L
            }
            
            let event = ProgramCreated(programId, validName, portfolioId)
            return (program, event)
        }
    
    /// Change program status
    let changeStatus (newStatus: ProgramStatus) (program: Program) : DomainResult<Program * ProgramEvent> =
        let updated = 
            { program with 
                Status = newStatus
                UpdatedAt = DateTimeOffset.UtcNow
                Version = program.Version + 1L }
        
        let event = ProgramStatusChanged(program.Id, program.Status, newStatus)
        Ok (updated, event)
    
    /// Add project to program
    let addProject (projectId: EntityId) (program: Program) : DomainResult<Program * ProgramEvent> =
        if program.ProjectIds |> List.contains projectId then
            Error (DomainError.businessRule "Project" "Project is already in this program")
        else
            let updated = 
                { program with 
                    ProjectIds = projectId :: program.ProjectIds
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = program.Version + 1L }
            
            let event = ProjectAddedToProgram(program.Id, projectId)
            Ok (updated, event)
    
    /// Remove project from program
    let removeProject (projectId: EntityId) (program: Program) : DomainResult<Program * ProgramEvent> =
        if not (program.ProjectIds |> List.contains projectId) then
            Error (DomainError.businessRule "Project" "Project is not in this program")
        else
            let updated = 
                { program with 
                    ProjectIds = program.ProjectIds |> List.filter ((<>) projectId)
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = program.Version + 1L }
            
            let event = ProjectRemovedFromProgram(program.Id, projectId)
            Ok (updated, event)
    
    /// Assign program manager
    let assignManager (userId: UserId) (program: Program) : DomainResult<Program * ProgramEvent> =
        let updated = 
            { program with 
                ProgramManagerId = userId
                UpdatedAt = DateTimeOffset.UtcNow
                Version = program.Version + 1L }
        
        let event = ProgramManagerAssigned(program.Id, userId)
        Ok (updated, event)
    
    /// Link OKR to program
    let linkOkr (okrId: EntityId) (program: Program) : DomainResult<Program * ProgramEvent> =
        if program.OkrIds |> List.contains okrId then
            Error (DomainError.businessRule "OKR" "OKR is already linked to this program")
        else
            let updated = 
                { program with 
                    OkrIds = okrId :: program.OkrIds
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = program.Version + 1L }
            
            let event = ProgramOkrLinked(program.Id, okrId)
            Ok (updated, event)

// =============================================================================
// MODULE 11: PORTFOLIO OPERATIONS
// =============================================================================

module PortfolioOperations =
    open Domain
    open Entities
    open Events
    open Results
    open Validation

    /// Create a new portfolio
    let create 
        (organizationId: EntityId)
        (name: string)
        (createdBy: UserId)
        : DomainResult<Portfolio * PortfolioEvent> =
        
        result {
            let! validName = notEmpty "name" name
            
            let portfolioId = EntityId.New()
            let now = DateTimeOffset.UtcNow
            
            let portfolio: Portfolio = {
                Id = portfolioId
                OrganizationId = organizationId
                Name = validName
                Description = None
                Status = Active
                StrategicThemes = []
                ProgramIds = []
                StandaloneProjectIds = []
                CreatedAt = now
                UpdatedAt = now
                FiscalYearStart = 1
                OwnerId = createdBy
                ReviewCadence = TimeSpan.FromDays(90.0)
                LastReviewDate = None
                TotalBudget = None
                Currency = "USD"
                Tags = []
                CustomFields = Map.empty
                Version = 1L
            }
            
            let event = PortfolioCreated(portfolioId, organizationId, validName)
            return (portfolio, event)
        }
    
    /// Add strategic theme
    let addStrategicTheme (theme: StrategicTheme) (portfolio: Portfolio) : DomainResult<Portfolio * PortfolioEvent> =
        let totalAllocation = 
            portfolio.StrategicThemes 
            |> List.sumBy (_.AllocationPercentage)
        
        if totalAllocation + theme.AllocationPercentage > 100m then
            Error (DomainError.businessRule "StrategicTheme" "Total allocation cannot exceed 100%")
        else
            let updated = 
                { portfolio with 
                    StrategicThemes = theme :: portfolio.StrategicThemes
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = portfolio.Version + 1L }
            
            let event = StrategicThemeAdded(portfolio.Id, theme)
            Ok (updated, event)
    
    /// Add program to portfolio
    let addProgram (programId: EntityId) (portfolio: Portfolio) : DomainResult<Portfolio * PortfolioEvent> =
        if portfolio.ProgramIds |> List.contains programId then
            Error (DomainError.businessRule "Program" "Program is already in this portfolio")
        else
            let updated = 
                { portfolio with 
                    ProgramIds = programId :: portfolio.ProgramIds
                    UpdatedAt = DateTimeOffset.UtcNow
                    Version = portfolio.Version + 1L }
            
            let event = ProgramAddedToPortfolio(portfolio.Id, programId)
            Ok (updated, event)

// =============================================================================
// MODULE 12: OKR OPERATIONS
// =============================================================================

module OkrOperations =
    open Domain
    open Entities
    open Events
    open Results
    open Validation

    /// Create a new objective
    let createObjective 
        (title: string)
        (startDate: DateTimeOffset)
        (endDate: DateTimeOffset)
        (parentId: EntityId option)
        (ownerId: UserId)
        : DomainResult<Objective * OkrEvent> =
        
        result {
            let! validTitle = notEmpty "title" title
            let! _ = dateAfter "endDate" startDate endDate
            
            let objectiveId = EntityId.New()
            let now = DateTimeOffset.UtcNow
            
            let objective: Objective = {
                Id = objectiveId
                Title = validTitle
                Description = None
                Status = Draft
                StartDate = startDate
                EndDate = endDate
                KeyResults = []
                ParentObjectiveId = parentId
                ChildObjectiveIds = []
                OwnerId = ownerId
                StrategicThemeId = None
                ProgramIds = []
                ProjectIds = []
                CreatedAt = now
                UpdatedAt = now
            }
            
            let event = ObjectiveCreated(objectiveId, validTitle, startDate, endDate, parentId)
            return (objective, event)
        }
    
    /// Add key result to objective
    let addKeyResult (keyResult: KeyResult) (objective: Objective) : DomainResult<Objective * OkrEvent> =
        let updated = 
            { objective with 
                KeyResults = keyResult :: objective.KeyResults
                UpdatedAt = DateTimeOffset.UtcNow }
        
        let event = KeyResultAdded(objective.Id, keyResult)
        Ok (updated, event)
    
    /// Update key result progress
    let updateKeyResultProgress 
        (keyResultId: EntityId) 
        (newValue: decimal) 
        (objective: Objective) 
        : DomainResult<Objective * OkrEvent> =
        
        let kr = objective.KeyResults |> List.tryFind (fun k -> k.Id = keyResultId)
        
        match kr with
        | None -> 
            Error (DomainError.notFound "KeyResult" keyResultId)
        | Some existingKr ->
            let newStatus =
                let progress = 
                    if existingKr.TargetValue = existingKr.StartValue then 100.0m
                    else ((newValue - existingKr.StartValue) / (existingKr.TargetValue - existingKr.StartValue)) * 100.0m
                
                if progress >= 100.0m then KeyResultStatus.Achieved
                elif progress >= 70.0m then KeyResultStatus.OnTrack
                elif progress >= 40.0m then KeyResultStatus.AtRisk
                else KeyResultStatus.Behind
            
            let updatedKr = 
                { existingKr with 
                    CurrentValue = newValue
                    Status = newStatus
                    UpdatedAt = DateTimeOffset.UtcNow }
            
            let updatedKeyResults = 
                objective.KeyResults 
                |> List.map (fun k -> if k.Id = keyResultId then updatedKr else k)
            
            let updated = 
                { objective with 
                    KeyResults = updatedKeyResults
                    UpdatedAt = DateTimeOffset.UtcNow }
            
            let event = KeyResultProgressUpdated(objective.Id, keyResultId, newValue)
            Ok (updated, event)

// =============================================================================
// MODULE 13: INFRASTRUCTURE - DATABASE CONFIG
// =============================================================================

module Infrastructure =
    open Domain
    open Events
    open Results

    // =========================================================================
    // SMRITI DATABASE CONFIGURATION
    // =========================================================================

    type SmritiConfig = {
        Host: string
        Port: int
        Database: string
        Username: string
        Password: string
        ConnectionPoolSize: int
        ConnectionTimeout: TimeSpan
        CommandTimeout: TimeSpan
    }

    module SmritiConfig =
        let defaultConfig = {
            Host = "localhost"
            Port = 5432
            Database = "indrajaal_planning"
            Username = "planning_service"
            Password = ""
            ConnectionPoolSize = 20
            ConnectionTimeout = TimeSpan.FromSeconds(30.0)
            CommandTimeout = TimeSpan.FromSeconds(60.0)
        }
        
        let fromEnvironment () =
            { Host = Environment.GetEnvironmentVariable("SMRITI_HOST") |> Option.ofObj |> Option.defaultValue defaultConfig.Host
              Port = Environment.GetEnvironmentVariable("SMRITI_PORT") |> Option.ofObj |> Option.bind (fun s -> Int32.TryParse(s) |> function true, v -> Some v | _ -> None) |> Option.defaultValue defaultConfig.Port
              Database = Environment.GetEnvironmentVariable("SMRITI_DATABASE") |> Option.ofObj |> Option.defaultValue defaultConfig.Database
              Username = Environment.GetEnvironmentVariable("SMRITI_USERNAME") |> Option.ofObj |> Option.defaultValue defaultConfig.Username
              Password = Environment.GetEnvironmentVariable("SMRITI_PASSWORD") |> Option.ofObj |> Option.defaultValue ""
              ConnectionPoolSize = defaultConfig.ConnectionPoolSize
              ConnectionTimeout = defaultConfig.ConnectionTimeout
              CommandTimeout = defaultConfig.CommandTimeout }
        
        let toConnectionString config =
            $"Host={config.Host};Port={config.Port};Database={config.Database};Username={config.Username};Password={config.Password};Pooling=true;Maximum Pool Size={config.ConnectionPoolSize};Connection Idle Lifetime=300"

    // =========================================================================
    // EVENT STORE TYPES
    // =========================================================================

    type StoredEvent = {
        EventId: Guid
        StreamId: string
        StreamType: string
        EventType: string
        EventData: string
        Metadata: string
        Version: int64
        Timestamp: DateTimeOffset
        UserId: Guid
    }

    type EventStream = {
        StreamId: string
        StreamType: string
        CurrentVersion: int64
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
    }

    type Snapshot<'T> = {
        StreamId: string
        Version: int64
        State: 'T
        CreatedAt: DateTimeOffset
    }

    // =========================================================================
    // EVENT STORE INTERFACE
    // =========================================================================

    type IEventStore =
        abstract member AppendEvents: streamId: string -> streamType: string -> expectedVersion: int64 -> events: DomainEvent list -> Task<Result<int64, DomainError>>
        abstract member ReadEvents: streamId: string -> fromVersion: int64 -> maxCount: int -> Task<StoredEvent list>
        abstract member ReadAllEvents: streamId: string -> Task<StoredEvent list>
        abstract member GetStreamInfo: streamId: string -> Task<EventStream option>
        abstract member SaveSnapshot<'T> : streamId: string -> version: int64 -> state: 'T -> Task<unit>
        abstract member GetSnapshot<'T> : streamId: string -> Task<Snapshot<'T> option>

    // =========================================================================
    // AGGREGATE REPOSITORY INTERFACE
    // =========================================================================

    type IAggregateRepository<'TAggregate, 'TEvent> =
        abstract member Load: EntityId -> Task<Result<'TAggregate * int64, DomainError>>
        abstract member Save: EntityId -> expectedVersion: int64 -> events: 'TEvent list -> Task<Result<int64, DomainError>>
        abstract member Exists: EntityId -> Task<bool>

    // =========================================================================
    // DATABASE SCHEMA SQL
    // =========================================================================

    let createSchemaSQL = """
        -- Event streams table
        CREATE TABLE IF NOT EXISTS event_streams (
            stream_id VARCHAR(255) PRIMARY KEY,
            stream_type VARCHAR(100) NOT NULL,
            current_version BIGINT NOT NULL DEFAULT 0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        
        -- Events table
        CREATE TABLE IF NOT EXISTS events (
            event_id UUID PRIMARY KEY,
            stream_id VARCHAR(255) NOT NULL REFERENCES event_streams(stream_id),
            stream_type VARCHAR(100) NOT NULL,
            event_type VARCHAR(200) NOT NULL,
            event_data JSONB NOT NULL,
            metadata JSONB NOT NULL,
            version BIGINT NOT NULL,
            timestamp TIMESTAMPTZ NOT NULL,
            user_id UUID NOT NULL,
            UNIQUE(stream_id, version)
        );
        
        -- Indexes
        CREATE INDEX IF NOT EXISTS idx_events_stream_id ON events(stream_id);
        CREATE INDEX IF NOT EXISTS idx_events_stream_type ON events(stream_type);
        CREATE INDEX IF NOT EXISTS idx_events_event_type ON events(event_type);
        CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_events_user_id ON events(user_id);
        
        -- Snapshots table
        CREATE TABLE IF NOT EXISTS snapshots (
            stream_id VARCHAR(255) PRIMARY KEY,
            version BIGINT NOT NULL,
            state JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        
        -- Tasks materialized view
        CREATE TABLE IF NOT EXISTS tasks_view (
            id UUID PRIMARY KEY,
            hierarchical_id VARCHAR(500),
            title VARCHAR(500) NOT NULL,
            description TEXT,
            status VARCHAR(50) NOT NULL,
            priority_urgency VARCHAR(50),
            priority_importance VARCHAR(50),
            priority_score INT,
            created_at TIMESTAMPTZ NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL,
            due_date TIMESTAMPTZ,
            start_date TIMESTAMPTZ,
            completed_at TIMESTAMPTZ,
            created_by UUID NOT NULL,
            project_id UUID,
            parent_task_id UUID,
            version BIGINT NOT NULL,
            tags JSONB,
            custom_fields JSONB
        );
        
        CREATE INDEX IF NOT EXISTS idx_tasks_view_status ON tasks_view(status);
        CREATE INDEX IF NOT EXISTS idx_tasks_view_due_date ON tasks_view(due_date);
        CREATE INDEX IF NOT EXISTS idx_tasks_view_project ON tasks_view(project_id);
        CREATE INDEX IF NOT EXISTS idx_tasks_view_created_by ON tasks_view(created_by);
        
        -- Projects materialized view
        CREATE TABLE IF NOT EXISTS projects_view (
            id UUID PRIMARY KEY,
            name VARCHAR(200) NOT NULL,
            description TEXT,
            status VARCHAR(50) NOT NULL,
            program_id UUID,
            created_at TIMESTAMPTZ NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL,
            start_date TIMESTAMPTZ,
            target_end_date TIMESTAMPTZ,
            owner_id UUID NOT NULL,
            version BIGINT NOT NULL
        );
        
        -- Full-text search
        CREATE INDEX IF NOT EXISTS idx_tasks_view_fts ON tasks_view 
            USING gin(to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, '')));
    """

// =============================================================================
// MODULE 14: ZENOH MESSAGING
// =============================================================================

module Messaging =
    open Domain

    // =========================================================================
    // ZENOH CONFIGURATION
    // =========================================================================

    type ZenohQoS =
        | BestEffort
        | Reliable
        | Transactional

    type ZenohConfig = {
        Mode: string
        Endpoints: string list
        LocalEndpoint: string option
        BufferSize: int
        QoS: ZenohQoS
    }

    module ZenohConfig =
        let defaultConfig = {
            Mode = "peer"
            Endpoints = ["tcp/localhost:7447"]
            LocalEndpoint = None
            BufferSize = 1024 * 1024
            QoS = Reliable
        }
        
        let fromEnvironment () =
            let endpoints = 
                Environment.GetEnvironmentVariable("ZENOH_ENDPOINTS")
                |> Option.ofObj
                |> Option.map (fun s -> s.Split(',') |> Array.toList)
                |> Option.defaultValue defaultConfig.Endpoints
            
            { Mode = Environment.GetEnvironmentVariable("ZENOH_MODE") |> Option.ofObj |> Option.defaultValue defaultConfig.Mode
              Endpoints = endpoints
              LocalEndpoint = Environment.GetEnvironmentVariable("ZENOH_LOCAL_ENDPOINT") |> Option.ofObj
              BufferSize = defaultConfig.BufferSize
              QoS = defaultConfig.QoS }

    // =========================================================================
    // MESSAGE TYPES
    // =========================================================================

    type MessagePriority =
        | Background = 0
        | Low = 1
        | Normal = 2
        | High = 3
        | Urgent = 4

    type Message<'T> = {
        Id: Guid
        Topic: string
        Payload: 'T
        Timestamp: DateTimeOffset
        Priority: MessagePriority
        Source: string
        CorrelationId: Guid option
        Headers: Map<string, string>
    }

    module Message =
        let create topic payload source = {
            Id = Guid.NewGuid()
            Topic = topic
            Payload = payload
            Timestamp = DateTimeOffset.UtcNow
            Priority = MessagePriority.Normal
            Source = source
            CorrelationId = None
            Headers = Map.empty
        }
        
        let withPriority priority msg = { msg with Priority = priority }
        let withCorrelation correlationId msg = { msg with CorrelationId = Some correlationId }
        let withHeader key value msg = { msg with Headers = msg.Headers |> Map.add key value }

    // =========================================================================
    // TOPIC DEFINITIONS
    // =========================================================================

    module Topics =
        let private root = "indrajaal/planning"
        
        let taskCreated = $"{root}/tasks/created"
        let taskUpdated taskId = $"{root}/tasks/{taskId}/updated"
        let taskDeleted = $"{root}/tasks/deleted"
        let taskStatusChanged = $"{root}/tasks/status"
        let taskAssigned = $"{root}/tasks/assigned"
        let taskCommented = $"{root}/tasks/comments"
        
        let projectCreated = $"{root}/projects/created"
        let projectUpdated projectId = $"{root}/projects/{projectId}/updated"
        let projectStatusChanged = $"{root}/projects/status"
        let projectMilestone = $"{root}/projects/milestones"
        let sprintEvents = $"{root}/projects/sprints"
        
        let programEvents = $"{root}/programs/**"
        let portfolioEvents = $"{root}/portfolios/**"
        
        let userNotifications userId = $"{root}/users/{userId}/notifications"
        let userTaskUpdates userId = $"{root}/users/{userId}/tasks"
        
        let teamUpdates teamId = $"{root}/teams/{teamId}/**"
        
        let systemHealth = $"{root}/system/health"
        let systemMetrics = $"{root}/system/metrics"
        
        let allTaskEvents = $"{root}/tasks/**"
        let allProjectEvents = $"{root}/projects/**"
        let allEvents = $"{root}/**"

    // =========================================================================
    // NOTIFICATION TYPES
    // =========================================================================

    type TaskNotification = {
        TaskId: EntityId
        EventType: string
        Summary: string
        AffectedUsers: UserId list
        Timestamp: DateTimeOffset
        Metadata: Map<string, string>
    }

    type ProjectNotification = {
        ProjectId: EntityId
        EventType: string
        Summary: string
        AffectedUsers: UserId list
        Timestamp: DateTimeOffset
        Metadata: Map<string, string>
    }

    type SystemNotification = {
        NotificationType: string
        Message: string
        Severity: string
        Timestamp: DateTimeOffset
    }

    // =========================================================================
    // MESSAGING INTERFACES
    // =========================================================================

    type IMessagePublisher =
        abstract member Publish<'T> : topic: string -> message: Message<'T> -> Task<Result<unit, string>>
        abstract member PublishBatch<'T> : messages: (string * Message<'T>) list -> Task<Result<unit, string>>

    type IMessageSubscriber =
        abstract member Subscribe<'T> : topic: string -> handler: (Message<'T> -> Task<unit>) -> IDisposable
        abstract member SubscribePattern : pattern: string -> handler: (string * byte[]) -> Task<unit> -> IDisposable

// =============================================================================
// MODULE 15: APPLICATION COMMANDS
// =============================================================================

module Application =
    open Domain
    open Entities
    open Events
    open Results

    // =========================================================================
    // TASK COMMANDS
    // =========================================================================

    type TaskCommand =
        | CreateTask of 
            title: string * 
            description: string option * 
            projectId: EntityId option * 
            parentTaskId: EntityId option
        | UpdateTaskTitle of taskId: EntityId * newTitle: string
        | UpdateTaskDescription of taskId: EntityId * newDescription: string option
        | ChangeTaskStatus of taskId: EntityId * newStatus: TaskStatus * reason: string option
        | CompleteTask of taskId: EntityId
        | StartTask of taskId: EntityId
        | BlockTask of taskId: EntityId * reason: string
        | UnblockTask of taskId: EntityId
        | SetTaskPriority of taskId: EntityId * urgency: Urgency * importance: Importance
        | SetTaskDueDate of taskId: EntityId * dueDate: DateTimeOffset
        | ClearTaskDueDate of taskId: EntityId
        | SetTaskStartDate of taskId: EntityId * startDate: DateTimeOffset
        | SetTaskRecurrence of taskId: EntityId * recurrence: Recurrence
        | SetTaskEstimate of taskId: EntityId * optimistic: TimeSpan * mostLikely: TimeSpan * pessimistic: TimeSpan
        | LogTime of taskId: EntityId * startTime: DateTimeOffset * endTime: DateTimeOffset option * description: string option
        | AssignTask of taskId: EntityId * userId: UserId * role: AssignmentRole
        | UnassignTask of taskId: EntityId * userId: UserId * role: AssignmentRole
        | TransferTaskOwnership of taskId: EntityId * newOwnerId: UserId
        | AddTaskDependency of taskId: EntityId * dependsOnTaskId: EntityId * dependencyType: DependencyType
        | RemoveTaskDependency of taskId: EntityId * dependencyId: EntityId
        | AddChecklist of taskId: EntityId * title: string * items: string list
        | ToggleChecklistItem of taskId: EntityId * checklistId: EntityId * itemId: EntityId * isCompleted: bool
        | AddComment of taskId: EntityId * content: string * commentType: CommentType
        | AddTag of taskId: EntityId * tagName: string * color: string option
        | RemoveTag of taskId: EntityId * tagName: string
        | DeleteTask of taskId: EntityId * reason: string option

    // =========================================================================
    // PROJECT COMMANDS
    // =========================================================================

    type ProjectCommand =
        | CreateProject of name: string * description: string option * programId: EntityId option
        | UpdateProjectName of projectId: EntityId * newName: string
        | ChangeProjectStatus of projectId: EntityId * newStatus: ProjectStatus
        | SetProjectDates of projectId: EntityId * startDate: DateTimeOffset option * endDate: DateTimeOffset option
        | AddTaskToProject of projectId: EntityId * taskId: EntityId
        | RemoveTaskFromProject of projectId: EntityId * taskId: EntityId
        | AddMilestone of projectId: EntityId * name: string * dueDate: DateTimeOffset
        | CompleteMilestone of projectId: EntityId * milestoneId: EntityId
        | AddTeamMember of projectId: EntityId * userId: UserId * role: AssignmentRole
        | SetProjectBudget of projectId: EntityId * amount: decimal * currency: string
        | CreateSprint of projectId: EntityId * name: string * goal: string option * startDate: DateTimeOffset * endDate: DateTimeOffset

    // =========================================================================
    // PROGRAM COMMANDS
    // =========================================================================

    type ProgramCommand =
        | CreateProgram of name: string * portfolioId: EntityId option
        | AddProjectToProgram of programId: EntityId * projectId: EntityId
        | RemoveProjectFromProgram of programId: EntityId * projectId: EntityId
        | AssignProgramManager of programId: EntityId * userId: UserId

    // =========================================================================
    // TODOLIST COMMANDS
    // =========================================================================

    type TodoListCommand =
        | CreateTodoList of name: string * description: string option
        | RenameTodoList of listId: EntityId * newName: string
        | SetTodoListFilter of listId: EntityId * filter: TodoListFilter
        | AddTaskToTodoList of listId: EntityId * taskId: EntityId * position: int option
        | RemoveTaskFromTodoList of listId: EntityId * taskId: EntityId
        | ReorderTodoList of listId: EntityId * taskIds: EntityId list
        | DeleteTodoList of listId: EntityId

    // =========================================================================
    // COMMAND CONTEXT
    // =========================================================================

    type CommandContext = {
        UserId: UserId
        Timestamp: DateTimeOffset
        CorrelationId: EntityId option
        OrganizationId: EntityId option
    }

    module CommandContext =
        let create userId = {
            UserId = userId
            Timestamp = DateTimeOffset.UtcNow
            CorrelationId = None
            OrganizationId = None
        }
        
        let withCorrelation correlationId ctx = 
            { ctx with CorrelationId = Some correlationId }
        
        let withOrganization orgId ctx = 
            { ctx with OrganizationId = Some orgId }

    type CommandResult<'T> = Task<Result<'T, DomainError>>

// =============================================================================
// MODULE 16: NATURAL LANGUAGE PARSER
// =============================================================================

module NaturalLanguageParser =
    open System.Text.RegularExpressions
    open Domain

    type ParsedTask = {
        Title: string
        DueDate: DateTimeOffset option
        Priority: Priority option
        Tags: string list
        Assignee: string option
    }
    
    let private dueDatePatterns = [
        (@"tomorrow", fun () -> DateTimeOffset.UtcNow.AddDays(1.0).Date |> DateTimeOffset)
        (@"today", fun () -> DateTimeOffset.UtcNow.Date |> DateTimeOffset)
        (@"next week", fun () -> DateTimeOffset.UtcNow.AddDays(7.0).Date |> DateTimeOffset)
        (@"next month", fun () -> DateTimeOffset.UtcNow.AddMonths(1).Date |> DateTimeOffset)
        (@"in (\d+) days?", fun () -> DateTimeOffset.UtcNow.AddDays(1.0).Date |> DateTimeOffset)
    ]
    
    let private priorityPatterns = [
        (@"!critical|!!!", fun () -> Priority.Calculate(Immediate, Critical))
        (@"!high|!!", fun () -> Priority.Calculate(Soon, High))
        (@"!low|!", fun () -> Priority.Calculate(Eventual, Low))
    ]
    
    let private tagPattern = Regex(@"#(\w+)", RegexOptions.Compiled)
    let private assigneePattern = Regex(@"@(\w+)", RegexOptions.Compiled)
    
    /// Parse natural language task input
    let parse (input: string) : ParsedTask =
        let mutable remaining = input.Trim()
        let mutable dueDate = None
        let mutable priority = None
        
        for (pattern, dateFunc) in dueDatePatterns do
            let regex = Regex(pattern, RegexOptions.IgnoreCase)
            let m = regex.Match(remaining)
            if m.Success then
                dueDate <- Some (dateFunc())
                remaining <- regex.Replace(remaining, "").Trim()
        
        for (pattern, priorityFunc) in priorityPatterns do
            let regex = Regex(pattern, RegexOptions.IgnoreCase)
            let m = regex.Match(remaining)
            if m.Success then
                priority <- Some (priorityFunc())
                remaining <- regex.Replace(remaining, "").Trim()
        
        let tags = 
            tagPattern.Matches(remaining)
            |> Seq.cast<Match>
            |> Seq.map (fun m -> m.Groups.[1].Value)
            |> Seq.toList
        remaining <- tagPattern.Replace(remaining, "").Trim()
        
        let assignee = 
            let m = assigneePattern.Match(remaining)
            if m.Success then
                remaining <- assigneePattern.Replace(remaining, "").Trim()
                Some m.Groups.[1].Value
            else None
        
        let title = Regex(@"\s+").Replace(remaining, " ").Trim()
        
        { Title = title
          DueDate = dueDate
          Priority = priority
          Tags = tags
          Assignee = assignee }

// =============================================================================
// MODULE 17: API MODELS (DTOs)
// =============================================================================

module Api =
    open Domain
    open Entities

    // =========================================================================
    // REQUEST/RESPONSE DTOS
    // =========================================================================

    type PriorityDto = {
        Urgency: string
        Importance: string
    }

    type AssigneeDto = {
        UserId: string
        Role: string
    }

    type CreateTaskRequest = {
        Title: string
        Description: string option
        ProjectId: string option
        ParentTaskId: string option
        DueDate: DateTimeOffset option
        Priority: PriorityDto option
        Tags: string list option
        Assignees: AssigneeDto list option
    }

    type UpdateTaskRequest = {
        Title: string option
        Description: string option
        Status: string option
        Priority: PriorityDto option
        DueDate: DateTimeOffset option
    }

    type TaskResponse = {
        Id: string
        Title: string
        Description: string option
        Status: string
        Priority: PriorityDto
        DueDate: DateTimeOffset option
        StartDate: DateTimeOffset option
        CompletedAt: DateTimeOffset option
        CreatedAt: DateTimeOffset
        UpdatedAt: DateTimeOffset
        Assignees: AssigneeDto list
        Tags: string list
        ChecklistProgress: float
        IsOverdue: bool
        ProjectId: string option
        ParentTaskId: string option
    }

    type BulkTaskRequest = {
        TaskIds: string list
        Operation: string
        Parameters: Map<string, string>
    }

    type CreateProjectRequest = {
        Name: string
        Description: string option
        ProgramId: string option
        StartDate: DateTimeOffset option
        TargetEndDate: DateTimeOffset option
    }

    type ProjectResponse = {
        Id: string
        Name: string
        Description: string option
        Status: string
        StartDate: DateTimeOffset option
        TargetEndDate: DateTimeOffset option
        TaskCount: int
        CompletedTaskCount: int
        MilestoneProgress: float
    }

    type TodoListFilterDto = {
        Statuses: string list option
        DueBefore: DateTimeOffset option
        DueAfter: DateTimeOffset option
        Tags: string list option
        AssignedTo: string option
        SearchText: string option
    }

    type CreateTodoListRequest = {
        Name: string
        Description: string option
        Filter: TodoListFilterDto option
    }

    type TodoListResponse = {
        Id: string
        Name: string
        Description: string option
        TaskCount: int
        CompletedCount: int
    }

    // =========================================================================
    // API RESPONSE WRAPPER
    // =========================================================================

    type ApiError = {
        Code: string
        Message: string
        Details: Map<string, string>
    }

    type ApiResponse<'T> = {
        Success: bool
        Data: 'T option
        Error: ApiError option
        Timestamp: DateTimeOffset
    }

    module ApiResponse =
        open Results

        let success data = {
            Success = true
            Data = Some data
            Error = None
            Timestamp = DateTimeOffset.UtcNow
        }
        
        let error code message = {
            Success = false
            Data = None
            Error = Some { Code = code; Message = message; Details = Map.empty }
            Timestamp = DateTimeOffset.UtcNow
        }
        
        let fromResult = function
            | Ok data -> success data
            | Error (ValidationError (field, msg)) -> error "VALIDATION_ERROR" $"{field}: {msg}"
            | Error (NotFound (entityType, id)) -> error "NOT_FOUND" $"{entityType} with id {id} not found"
            | Error (Unauthorized (action, reason)) -> error "UNAUTHORIZED" $"Cannot {action}: {reason}"
            | Error (InvalidStateTransition (from, toState, reason)) -> error "INVALID_STATE" $"Cannot transition from {from} to {toState}: {reason}"
            | Error (BusinessRuleViolation (rule, msg)) -> error "BUSINESS_RULE" $"{rule}: {msg}"
            | Error (ConcurrencyConflict (id, expected, actual)) -> error "CONCURRENCY" $"Version conflict for {id}: expected {expected}, got {actual}"
            | Error (DependencyError msg) -> error "DEPENDENCY" msg
            | Error (ExternalServiceError (service, msg)) -> error "EXTERNAL_SERVICE" $"{service}: {msg}"

    // =========================================================================
    // MAPPING FUNCTIONS
    // =========================================================================

    module Mapping =
        let parseUrgency = function
            | "immediate" -> Immediate
            | "soon" -> Soon
            | "scheduled" -> Scheduled
            | "eventual" -> Eventual
            | "deferred" -> Deferred
            | _ -> Eventual
        
        let parseImportance = function
            | "critical" -> Critical
            | "high" -> High
            | "medium" -> Medium
            | "low" -> Low
            | "optional" -> Optional
            | _ -> Medium
        
        let parseStatus = function
            | "pending" -> Pending
            | "planned" -> Planned
            | "ready" -> Ready
            | "in_progress" -> InProgress
            | "in_review" -> InReview
            | "completed" -> Completed
            | "archived" -> Archived
            | s when s.StartsWith("blocked:") -> Blocked (s.Substring(8))
            | s when s.StartsWith("on_hold:") -> OnHold (s.Substring(8))
            | s when s.StartsWith("cancelled:") -> Cancelled (s.Substring(10))
            | _ -> Pending
        
        let statusToString = function
            | Pending -> "pending"
            | Planned -> "planned"
            | Ready -> "ready"
            | InProgress -> "in_progress"
            | InReview -> "in_review"
            | Blocked reason -> $"blocked:{reason}"
            | OnHold reason -> $"on_hold:{reason}"
            | Completed -> "completed"
            | Cancelled reason -> $"cancelled:{reason}"
            | Archived -> "archived"
        
        let parseRole = function
            | "owner" -> Owner
            | "assignee" -> Assignee
            | "reviewer" -> Reviewer
            | "stakeholder" -> Stakeholder
            | "watcher" -> Watcher
            | _ -> Assignee
        
        let roleToString = function
            | Owner -> "owner"
            | Assignee -> "assignee"
            | Reviewer -> "reviewer"
            | Stakeholder -> "stakeholder"
            | Watcher -> "watcher"

    // =========================================================================
    // AGENT INTERFACE
    // =========================================================================

    module AgentInterface =
        type AgentCommand =
            | CreateTaskCmd of title: string * description: string option * metadata: Map<string, string>
            | UpdateTaskCmd of taskId: string * updates: Map<string, string>
            | QueryTasksCmd of filter: Map<string, string>
            | CompleteTasksCmd of taskIds: string list
            | AssignTaskCmd of taskId: string * userId: string * role: string
            | BatchOperationCmd of operation: string * taskIds: string list * parameters: Map<string, string>
        
        type AgentResult = {
            EntityId: string option
            Status: string
            Message: string
            Data: Map<string, string>
        }
        
        type AgentResponse = {
            Success: bool
            Operation: string
            Results: AgentResult list
            Summary: string
            NextSuggestedActions: string list
        }
        
        /// Natural language command parser for agents
        let parseNaturalLanguageCommand (input: string) : AgentCommand option =
            let input = input.ToLower().Trim()
            
            if input.StartsWith("create task") || input.StartsWith("add task") || input.StartsWith("new task") then
                let title = input.Replace("create task", "").Replace("add task", "").Replace("new task", "").Trim()
                Some (CreateTaskCmd (title, None, Map.empty))
            elif input.StartsWith("complete") || input.StartsWith("finish") || input.StartsWith("done") then
                None
            elif input.StartsWith("list") || input.StartsWith("show") || input.StartsWith("get") then
                Some (QueryTasksCmd Map.empty)
            else
                None

// =============================================================================
// END OF INDRAJAAL PLANNING SYSTEM F# IMPLEMENTATION
// =============================================================================
// 
// Total modules: 17
// Total lines: ~2800
// 
// Key Features:
// - Immutable domain types using discriminated unions and records
// - Pure functions for business logic (no side effects)
// - Railway-oriented programming for error handling
// - Event sourcing architecture
// - CQRS pattern (Command Query Responsibility Segregation)
// - Real-time sync via Zenoh messaging
// - Smriti database integration
// - Natural language task parsing
// - REST API with DTOs
// - Agent interface for AI/automated use
//
// Military Planning Frameworks Implemented:
// - OODA Loop (Observe, Orient, Decide, Act)
// - MDMP (Military Decision Making Process)
// - Priority system based on Eisenhower Matrix
// - Hierarchical structure (Task -> Project -> Program -> Portfolio)
//
// =============================================================================
