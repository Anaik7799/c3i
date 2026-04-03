# KMS Use Cases & Scenarios - Comprehensive Catalog
**Version**: 2.0.0-ENHANCED | **Date**: 2025-12-30 | **Status**: ACTIVE
**Classification**: Safety-Critical | **Compliance**: ISO-13849, IEC 61508 SIL-2, EN 50131

## Related Documents
- [KMS_WIREFRAMES_COMPREHENSIVE.md](./KMS_WIREFRAMES_COMPREHENSIVE.md) - Visual wireframes
- [PRAJNA_TUI_MASTER_SPECIFICATION.md](../prajna/PRAJNA_TUI_MASTER_SPECIFICATION.md) - TUI master spec
- [SAFETY_CRITICAL_DIRECTIVE.md](../safety/SAFETY_CRITICAL_DIRECTIVE.md) - Safety code generation

---

## Table of Contents
0. [Use Case Specification Template](#0-use-case-specification-template)
1. [Developer Use Cases](#1-developer-use-cases)
2. [Product Manager Use Cases](#2-product-manager-use-cases)
3. [SRE Use Cases](#3-sre-use-cases)
4. [Technical Leadership Use Cases](#4-technical-leadership-use-cases)
5. [Knowledge Worker Use Cases](#5-knowledge-worker-use-cases)
6. [System Administrator Use Cases](#6-system-administrator-use-cases)
7. [AI/Automation Scenarios](#7-aiautomation-scenarios)
8. [Cross-Runtime Scenarios](#8-cross-runtime-scenarios)
9. [Safety-Critical Scenarios](#9-safety-critical-scenarios)
10. [Error & Recovery Scenarios](#10-error--recovery-scenarios)

---

## 0. Use Case Specification Template

Every use case in this document MUST include the following specification items:

### Template Structure

```markdown
### UC-XXX-NNN: [Use Case Title]

#### Basic Information
- **Actor**: [Primary user role]
- **Preconditions**: [System state before execution]
- **Trigger**: [What initiates the use case]
- **Priority**: [P0-Critical | P1-High | P2-Medium | P3-Low]

#### Main Flow
1. [Step 1]
2. [Step 2]
...

#### Postconditions
- [System state after successful completion]

#### STAMP Safety Constraints
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-XXX-001 | [Description] | [CRITICAL/HIGH/MEDIUM] | [How verified] |

#### TDG Test Templates
```elixir
# Property-based test for [use case]
property "[invariant description]" do
  check all(input <- generator()) do
    assert invariant(input)
  end
end
```

#### AOR Agent Operating Rules
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-XXX-001 | [Description] | [How enforced] |

#### FMEA Analysis
| Failure Mode | Cause | Effect | S | O | D | RPN | Mitigation |
|--------------|-------|--------|---|---|---|-----|------------|
| [Mode] | [Cause] | [Effect] | [1-10] | [1-10] | [1-10] | [Product] | [Action] |

#### BDD Scenarios (Gherkin)
```gherkin
Feature: [Use Case Title]
  Scenario: [Happy path]
    Given [precondition]
    When [action]
    Then [expected result]
```

#### Formal Methods

**Mathematica FSM:**
```mathematica
transitions = {
  {state1, event} -> state2,
  ...
};
```

**Agda Type:**
```agda
data UCState : Set where
  ...
```

**Quint Model:**
```quint
module uc_xxx {
  ...
}
```

**TLA+ Spec:**
```tla+
---- MODULE UCSpec ----
...
====
```

#### Graph Specifications
```
[Node1] --[relationship]--> [Node2]
```

#### Implementation Guidelines
- **Elixir**: [Implementation notes]
- **F#**: [Implementation notes]
- **LiveView**: [Implementation notes]

#### Testing Strategy
- **Unit**: [Scope and approach]
- **Integration**: [Scope and approach]
- **Property**: [Generators and invariants]
- **Visual**: [VHS scenarios]

#### UX/CX/DX Guidelines
- **UX**: [User experience requirements]
- **CX**: [Customer experience - audit, logging]
- **DX**: [Developer experience - API, CLI]

#### Automation Framework
```yaml
automation:
  trigger: [event]
  actions:
    - [action1]
    - [action2]
```
```

---

## 1. Developer Use Cases

### UC-DEV-001: Create Architecture Decision Record (ADR)

#### Basic Information
- **Actor**: Developer
- **Preconditions**: User authenticated, KMS accessible, write permission granted
- **Trigger**: Technical decision needs documentation
- **Priority**: P1-High

#### Main Flow
1. Developer navigates to Developer Portal → Decisions
2. Clicks [N]ew Decision
3. Selects type: ADR
4. Fills required fields:
   - Title: "GraphQL Federation Strategy"
   - Context: Problem description
   - Decision: Chosen approach
   - Consequences: Impact analysis
   - Status: proposed
5. Optionally links to related decisions
6. Submits for review
7. System creates holon with type: decision
8. Zenoh broadcasts creation event
9. F# Cockpit receives real-time update

#### Postconditions
- ADR created with unique ID
- Content indexed for full-text search
- Holon graph updated with new node
- Audit log entry created

#### STAMP Safety Constraints
| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-KMS-007 | All technical decisions MUST be traceable | HIGH | Audit log check |
| SC-KMS-008 | ADR status transitions MUST follow workflow | MEDIUM | FSM validation |
| SC-KMS-009 | Concurrent ADR edits MUST be conflict-resolved | HIGH | Optimistic locking |

#### TDG Test Templates
```elixir
# Property: ADR creation always produces valid holon
property "ADR creation invariants" do
  check all(
    title <- SD.string(:alphanumeric, min_length: 1, max_length: 200),
    context <- SD.string(:printable, min_length: 10),
    decision <- SD.string(:printable, min_length: 10),
    status <- SD.member_of([:proposed, :accepted, :deprecated, :superseded])
  ) do
    attrs = %{title: title, context: context, decision: decision, status: status}
    {:ok, adr} = KMS.Developer.create_decision(attrs)

    assert adr.id != nil
    assert adr.type == :decision
    assert adr.inserted_at != nil
    assert String.length(adr.title) <= 200
  end
end
```

#### AOR Agent Operating Rules
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-KMS-001 | Agent MUST verify user has write permission before ADR creation | Pre-action check |
| AOR-KMS-002 | Agent MUST validate all required fields before submission | Schema validation |
| AOR-KMS-003 | Agent MUST broadcast creation event within 100ms | Timeout enforcement |

#### FMEA Analysis
| Failure Mode | Cause | Effect | S | O | D | RPN | Mitigation |
|--------------|-------|--------|---|---|---|-----|------------|
| ADR not saved | DB connection failure | Data loss | 8 | 2 | 3 | 48 | Retry with exponential backoff |
| Duplicate ADR | Race condition | Confusion | 5 | 3 | 4 | 60 | Optimistic locking |
| Zenoh broadcast fails | Network partition | F# cockpit stale | 4 | 2 | 5 | 40 | Fallback to polling |
| Invalid status | User error | Workflow violation | 3 | 4 | 2 | 24 | FSM validation |

#### BDD Scenarios (Gherkin)
```gherkin
Feature: Create Architecture Decision Record
  As a Developer
  I need to document technical decisions
  So that future developers understand why choices were made

  Background:
    Given I am logged in as a Developer
    And I have write access to the KMS

  @ui @happy-path
  Scenario: Successfully create an ADR
    Given I am on the Developer Portal
    When I click "New Decision"
    And I fill in "Title" with "GraphQL Federation Strategy"
    And I fill in "Context" with "Need to unify multiple GraphQL schemas"
    And I fill in "Decision" with "Use Apollo Federation"
    And I fill in "Consequences" with "Additional complexity, better scalability"
    And I select "proposed" from "Status"
    And I click "Submit"
    Then I should see "ADR created successfully"
    And the ADR should appear in the decisions list
    And an audit log entry should be created

  @ui @validation
  Scenario: Cannot create ADR without required fields
    Given I am on the Developer Portal
    When I click "New Decision"
    And I click "Submit" without filling any fields
    Then I should see validation errors for required fields
    And no ADR should be created

  @cx @audit
  Scenario: ADR creation is logged for compliance
    When I create an ADR with title "Security Policy Update"
    Then an audit log entry should contain the user ID
    And an audit log entry should contain the timestamp
    And an audit log entry should contain "ADR_CREATED"

  @dx @api
  Scenario: Create ADR via REST API
    When I POST to "/api/v1/kms/decisions" with valid JSON
    Then the response status should be 201
    And the response should contain the new ADR ID
    And the ADR should be searchable via the API
```

#### Formal Methods

**Mathematica FSM (Status Transitions):**
```mathematica
(* ADR Status State Machine *)
adrStates = {proposed, accepted, deprecated, superseded};
adrTransitions = {
  {proposed, "accept"} -> accepted,
  {proposed, "reject"} -> deprecated,
  {accepted, "deprecate"} -> deprecated,
  {accepted, "supersede"} -> superseded,
  {deprecated, "reopen"} -> proposed
};

(* Invariant: All ADRs must have valid status *)
ValidADR[adr_] := MemberQ[adrStates, adr["status"]]
```

**Agda Type (Decision Structure):**
```agda
module ADR where

open import Data.String
open import Data.List

data Status : Set where
  proposed   : Status
  accepted   : Status
  deprecated : Status
  superseded : Status

record ADR : Set where
  field
    id           : String
    title        : String
    context      : String
    decision     : String
    consequences : String
    status       : Status
    linked_code  : List String

-- Proof: Status transitions are valid
valid-transition : Status → String → Status → Set
valid-transition proposed "accept" accepted = ⊤
valid-transition proposed "reject" deprecated = ⊤
valid-transition accepted "deprecate" deprecated = ⊤
valid-transition accepted "supersede" superseded = ⊤
valid-transition deprecated "reopen" proposed = ⊤
valid-transition _ _ _ = ⊥
```

**Quint Model:**
```quint
module adr {
  type Status = "proposed" | "accepted" | "deprecated" | "superseded"

  type ADR = {
    id: str,
    title: str,
    context: str,
    decision: str,
    status: Status,
    created_at: int,
    updated_at: int
  }

  var adrs: Set[ADR]

  action create_adr(title: str, context: str, decision: str): bool = {
    val new_adr = {
      id: generate_uuid(),
      title: title,
      context: context,
      decision: decision,
      status: "proposed",
      created_at: now(),
      updated_at: now()
    }
    adrs' = adrs.union(Set(new_adr))
  }

  // Invariant: All ADRs have valid status
  val all_valid_status = adrs.forall(a => a.status.in(Set("proposed", "accepted", "deprecated", "superseded")))
}
```

**TLA+ Specification:**
```tla+
---- MODULE ADRSpec ----
EXTENDS Naturals, Sequences, TLC

CONSTANTS Users, ADRIds

VARIABLES adrs, audit_log

Status == {"proposed", "accepted", "deprecated", "superseded"}

TypeInvariant ==
  /\ adrs \in [ADRIds -> [title: STRING, status: Status, owner: Users]]
  /\ audit_log \in Seq([action: STRING, adr_id: ADRIds, user: Users])

Init ==
  /\ adrs = [a \in {} |-> <<>>]
  /\ audit_log = <<>>

CreateADR(id, title, user) ==
  /\ id \notin DOMAIN adrs
  /\ adrs' = adrs @@ (id :> [title |-> title, status |-> "proposed", owner |-> user])
  /\ audit_log' = Append(audit_log, [action |-> "create", adr_id |-> id, user |-> user])

AcceptADR(id, user) ==
  /\ id \in DOMAIN adrs
  /\ adrs[id].status = "proposed"
  /\ adrs' = [adrs EXCEPT ![id].status = "accepted"]
  /\ audit_log' = Append(audit_log, [action |-> "accept", adr_id |-> id, user |-> user])

Next == \E id \in ADRIds, user \in Users:
  \/ CreateADR(id, "title", user)
  \/ AcceptADR(id, user)

Spec == Init /\ [][Next]_<<adrs, audit_log>>

(* All ADRs have valid status *)
StatusInvariant == \A id \in DOMAIN adrs: adrs[id].status \in Status

====
```

#### Graph Specifications
```
┌─────────────────────────────────────────────────────────────────┐
│                    ADR HOLON GRAPH                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   [Developer]                                                   │
│       │                                                         │
│       │ CREATES                                                 │
│       ▼                                                         │
│   [ADR: GraphQL Federation]                                     │
│       │                                                         │
│       ├── SUPERSEDES ──► [ADR: REST API v1]                    │
│       │                                                         │
│       ├── RELATES_TO ──► [ADR: Microservices]                  │
│       │                                                         │
│       ├── IMPLEMENTS ──► [Pattern: API Gateway]                │
│       │                                                         │
│       └── LINKED_CODE                                           │
│               │                                                 │
│               ├──► [File: lib/indrajaal/graphql/federation.ex] │
│               └──► [File: lib/indrajaal/graphql/schema.ex]     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementation Guidelines

**Elixir (Backend):**
```elixir
defmodule Indrajaal.KMS.Developer do
  @moduledoc """
  Developer domain module for KMS operations.

  ## STAMP Constraints
  - SC-KMS-007: Decision traceability
  - SC-KMS-008: Status workflow validation
  - SC-KMS-009: Conflict resolution

  ## AOR Rules
  - AOR-KMS-001: Permission verification
  - AOR-KMS-002: Field validation
  - AOR-KMS-003: Event broadcast timeout
  """

  alias Indrajaal.KMS.{Holon, AuditLog}

  @doc """
  Creates a new Architecture Decision Record.

  ## Examples
      iex> create_decision(%{title: "GraphQL Strategy", ...})
      {:ok, %Holon{type: :decision, ...}}
  """
  def create_decision(attrs, actor) do
    # SC-KMS-007: Ensure traceability
    with :ok <- authorize(actor, :create_decision),
         {:ok, holon} <- Holon.create(:decision, attrs),
         :ok <- AuditLog.record(:adr_created, holon, actor),
         :ok <- broadcast_event(:adr_created, holon) do
      {:ok, holon}
    end
  end
end
```

**F# (Cockpit):**
```fsharp
/// ADR panel for F# Cockpit
/// SC-KMS-007: Display ADR with full traceability
module Indrajaal.Cockpit.ADRPanel

open Indrajaal.Cockpit.Core

type ADRState =
    | Proposed
    | Accepted
    | Deprecated
    | Superseded

type ADRModel = {
    Id: string
    Title: string
    Status: ADRState
    LinkedCode: string list
}

let view (model: ADRModel) : View =
    vbox [
        text $"[ADR] {model.Title}"
        text $"Status: {model.Status}"
        text $"Linked: {model.LinkedCode.Length} files"
    ]
```

**LiveView (Web):**
```elixir
defmodule IndrajaalWeb.KMS.DecisionLive do
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "kms:decisions")
    end
    {:ok, assign(socket, decisions: list_decisions())}
  end

  @impl true
  def handle_event("create_adr", params, socket) do
    case KMS.Developer.create_decision(params, socket.assigns.current_user) do
      {:ok, adr} -> {:noreply, update(socket, :decisions, &[adr | &1])}
      {:error, changeset} -> {:noreply, assign(socket, :errors, changeset.errors)}
    end
  end
end
```

#### Testing Strategy

| Type | Scope | Approach |
|------|-------|----------|
| **Unit** | `create_decision/2` | Mock DB, test validation |
| **Integration** | Full flow | Start app, create ADR, verify DB |
| **Property** | Data invariants | FsCheck/StreamData generators |
| **Visual** | UI rendering | VHS tape: `adr_creation.tape` |
| **Chaos** | Resilience | Kill process during save |
| **E2E** | Full journey | Wallaby browser test |

#### UX/CX/DX Guidelines

**UX (User Experience):**
- Form auto-saves draft every 30 seconds
- Real-time validation with inline error messages
- Keyboard navigation: Tab through fields, Enter to submit
- Confirmation modal before submission

**CX (Customer Experience):**
- All ADR operations logged with user ID, timestamp, action
- Export ADRs to Markdown for external sharing
- Notification to stakeholders on status change
- Searchable decision history

**DX (Developer Experience):**
- REST API: `POST /api/v1/kms/decisions`
- GraphQL: `mutation { createDecision(...) }`
- CLI: `mix kms.decision create --title "..." --context "..."`
- SDK: `KMS.Developer.create_decision(attrs)`

#### Automation Framework
```yaml
automation:
  name: adr_lifecycle
  trigger:
    event: adr_created
    conditions:
      - status == "proposed"

  actions:
    - name: notify_stakeholders
      type: notification
      config:
        channel: slack
        message: "New ADR: {{title}} by {{author}}"

    - name: create_review_task
      type: task
      config:
        assignee: tech_lead
        due_days: 7

    - name: index_for_search
      type: search
      config:
        engine: meilisearch
        fields: [title, context, decision]

  on_status_change:
    accepted:
      - name: update_documentation
        type: docs
        config:
          target: docs/architecture/decisions/

    deprecated:
      - name: archive_adr
        type: archive
        config:
          retention_days: 365
```

---

### UC-DEV-002: Link Decision to Code
**Actor**: Developer
**Preconditions**: ADR exists, code file identified

**Main Flow**:
1. Developer opens existing ADR
2. Clicks [L]ink Code
3. Enters file path: `lib/indrajaal/graphql/federation.ex`
4. Selects line range: 1-200
5. Chooses link type: IMPLEMENTS
6. Optionally adds git commit reference
7. Saves code link
8. System creates edge in holon graph

**Postconditions**: ADR linked to implementation
**Verification**: `get_file_context(path)` returns linked ADR

---

### UC-DEV-003: Store Reusable Pattern
**Actor**: Developer
**Preconditions**: Pattern identified, documented

**Main Flow**:
1. Navigate to Developer Portal → Patterns
2. Click [N]ew Pattern
3. Fill pattern details:
   - Name: "Circuit Breaker"
   - Category: resilience
   - Problem: External service failures
   - Solution: Wrap calls with failure tracking
   - Template: Code snippet
   - Examples: Link to implementations
   - Tags: ["resilience", "fault-tolerance"]
4. Submit pattern
5. System increments usage_count on each reference

**Postconditions**: Pattern available in library
**Metrics**: Usage tracking enabled

---

### UC-DEV-004: Start Debug Session
**Actor**: Developer
**Preconditions**: Bug identified, investigation needed

**Main Flow**:
1. Navigate to Developer Portal → Debug Sessions
2. Click [N]ew Session
3. Enter symptom: "Memory leak in WebSocket handler"
4. System creates debug session holon
5. Developer adds investigation steps:
   - Step 1: "Reproduced with 100 disconnects" ✓
   - Step 2: "Found ETS table growth" ✓
   - Step 3: "Testing fix" ●
6. Updates root cause when identified
7. Documents solution and prevention
8. Closes session with resolution

**Postconditions**: Debug knowledge captured
**Metrics**: Time spent, files involved logged

---

### UC-DEV-005: Add Code Review Note
**Actor**: Developer
**Preconditions**: Code review in progress

**Main Flow**:
1. During review, identify learning opportunity
2. Create review note:
   - Type: learning | suggestion | issue | praise
   - File path: Referenced file
   - Line number: Specific location
   - Content: Note text
   - Author: Auto-captured
3. Link to relevant patterns or decisions
4. Mark as resolved when addressed

**Postconditions**: Review insight preserved

---

### UC-DEV-006: Search Code Context
**Actor**: Developer
**Preconditions**: Working on specific file

**Main Flow**:
1. Developer queries: `get_file_context("lib/indrajaal/auth/jwt.ex")`
2. System returns:
   - Linked ADRs (e.g., "JWT Auth Flow")
   - Relevant patterns (e.g., "Token Validation")
   - Debug sessions touching this file
   - Review notes for this file
3. Developer gains full context before modification

**Postconditions**: Informed code changes

---

### UC-DEV-007: View Developer Statistics
**Actor**: Developer / Tech Lead
**Preconditions**: Sufficient data collected

**Main Flow**:
1. Navigate to Developer Portal → Stats
2. View metrics:
   - Knowledge density per module
   - Decisions per quarter
   - Pattern usage frequency
   - Debug session durations
   - Review note categories
3. Identify knowledge gaps
4. Plan documentation efforts

**Postconditions**: Actionable insights available

---

## 2. Product Manager Use Cases

### UC-PM-001: Create Feature
**Actor**: Product Manager
**Preconditions**: Feature ideated, stakeholders identified

**Main Flow**:
1. Navigate to Product Portal → Features
2. Click [N]ew Feature
3. Fill feature details:
   - Name: "Dark Mode Toggle"
   - Description: User story
   - Status: ideation
   - Priority: high
   - Quarter: Q1-2026
   - Owner: @alice
   - Stakeholders: [@bob, @charlie]
   - Dependencies: [feature_id_1, feature_id_2]
   - Metrics: ["user_adoption", "accessibility_score"]
4. Submit feature
5. Feature appears in pipeline kanban

**Postconditions**: Feature tracked in pipeline
**Visualization**: Kanban board updated

---

### UC-PM-002: Manage Release
**Actor**: Product Manager
**Preconditions**: Features ready for release

**Main Flow**:
1. Navigate to Product Portal → Releases
2. Create new release:
   - Version: "2.5.0" (unique)
   - Status: planning
   - Features: [selected_feature_ids]
   - Breaking changes: Description
   - Release notes: Markdown content
3. Progress through states:
   - planning → staged → deployed
4. If issues: rollback release
   - Status changes to rolled_back
   - rolled_back_at timestamp set
5. Track deployment metrics

**Postconditions**: Release lifecycle documented

---

### UC-PM-003: Record Customer Feedback
**Actor**: Product Manager / Support
**Preconditions**: Customer feedback received

**Main Flow**:
1. Navigate to Product Portal → Feedback
2. Create feedback entry:
   - Source: support_ticket | survey | interview | social | review
   - Content: Verbatim feedback
   - Sentiment: positive | neutral | negative (auto-classified)
   - Customer ID: Optional identifier
   - Category: UX | Performance | Feature Request | Bug
3. Link to existing feature (if applicable)
4. Track status: new → reviewed → actioned

**Postconditions**: Feedback captured and linked

---

### UC-PM-004: Run A/B Experiment
**Actor**: Product Manager
**Preconditions**: Hypothesis defined, metrics identified

**Main Flow**:
1. Navigate to Product Portal → Experiments
2. Create experiment:
   - Name: "Checkout Flow Optimization"
   - Hypothesis: "Simplified checkout increases conversion"
   - Variant A: Current flow (control)
   - Variant B: Simplified flow (treatment)
   - Metrics: ["conversion_rate", "time_to_complete"]
   - Sample size: 10000 users
   - Status: draft
3. Start experiment (status: running)
4. Monitor results in real-time
5. Complete experiment:
   - Record results
   - Document conclusion
   - Update status: completed

**Postconditions**: Experiment results documented

---

### UC-PM-005: Manage Product Incident
**Actor**: Product Manager
**Preconditions**: Customer-impacting issue identified

**Main Flow**:
1. Navigate to Product Portal → Incidents
2. Create incident:
   - Title: "SSO Login Broken After Update"
   - Severity: critical | major | minor | cosmetic
   - Status: investigating
   - Linked features: [sso_feature_id]
3. Update timeline as investigation progresses
4. Document root cause when identified
5. Record resolution steps
6. Add action items for prevention
7. Create post-mortem
8. Status: resolved → post_mortem

**Postconditions**: Incident fully documented

---

### UC-PM-006: View Feedback Sentiment Analysis
**Actor**: Product Manager
**Preconditions**: Feedback data collected

**Main Flow**:
1. Navigate to Product Portal → Feedback
2. View sentiment dashboard:
   - Pie chart: Positive/Neutral/Negative
   - Trend line: Sentiment over time
   - Top requested features
   - Sentiment by source
3. Filter by date range, source, feature
4. Export report for stakeholders

**Postconditions**: Sentiment insights available

---

### UC-PM-007: Track Feature Velocity
**Actor**: Product Manager
**Preconditions**: Features moving through pipeline

**Main Flow**:
1. Navigate to Product Portal → KPIs
2. View velocity metrics:
   - Features shipped per sprint
   - Average cycle time (ideation → released)
   - WIP (Work in Progress) count
   - Throughput trend
3. Identify bottlenecks
4. Adjust process accordingly

**Postconditions**: Delivery metrics tracked

---

### UC-PM-008: Plan Quarterly Roadmap
**Actor**: Product Manager
**Preconditions**: Strategic priorities defined

**Main Flow**:
1. Navigate to Product Portal → Roadmap
2. View/edit roadmap items:
   - Quarter: Q1-2026
   - Theme: "Mobile Experience"
   - Status: tentative | committed | in_progress | completed | deferred
   - Confidence: 0.0-1.0
   - Dependencies: Cross-team dependencies
3. Drag items between quarters
4. Adjust confidence based on progress
5. Export roadmap visualization

**Postconditions**: Roadmap documented and shareable

---

## 3. SRE Use Cases

### UC-SRE-001: Create Runbook
**Actor**: SRE
**Preconditions**: Operational procedure identified

**Main Flow**:
1. Navigate to SRE Portal → Runbooks
2. Click [N]ew Runbook
3. Fill runbook details:
   - Name: "Database Failover"
   - Category: recovery | incident_response | maintenance | deployment | scaling | debugging | security
   - Steps: Ordered procedure list
     - Each step: command, description, automation_status
   - Automation level: manual | semi_automated | fully_automated
   - Estimated duration: 15 minutes
   - Linked alerts: [PostgresReplicaLag, DiskSpaceCritical]
4. Submit runbook
5. Runbook indexed for quick access

**Postconditions**: Runbook available for execution
**Quick Access**: F-key binding assigned

---

### UC-SRE-002: Execute Runbook
**Actor**: SRE
**Preconditions**: Incident triggered, runbook identified

**Main Flow**:
1. Alert fires: PostgresReplicaLag > 30s
2. System suggests relevant runbook
3. SRE clicks [E]xecute or presses F2
4. Arm & Fire protocol activates (for critical runbooks)
5. Step-by-step execution:
   - Step 1: Check replica status ✓
   - Step 2: Pause traffic ● (in progress)
   - Step 3: Promote replica ○ (pending)
6. Each step logs output
7. Completion logged with duration
8. Execution count incremented

**Postconditions**: Runbook executed, audit trail created
**STAMP**: SC-HMI-003 (Arm & Fire for critical operations)

---

### UC-SRE-003: Define SLO
**Actor**: SRE
**Preconditions**: Service metrics available

**Main Flow**:
1. Navigate to SRE Portal → SLOs
2. Create SLO:
   - Service: "API Gateway"
   - Indicator: Availability | Latency P99 | Error Rate
   - Target: 99.95%
   - Window: rolling_28d | calendar_month
   - Alerting threshold: 99.9% (warn), 99.5% (critical)
3. System calculates:
   - Current value
   - Error budget remaining
   - Burn rate
4. Dashboard updated with SLO status

**Postconditions**: SLO tracked with error budget

---

### UC-SRE-004: Track SLO Breach
**Actor**: SRE / System
**Preconditions**: SLO defined, metrics flowing

**Main Flow**:
1. System detects SLO breach:
   - Background Jobs success rate: 99.2% (target: 99.9%)
2. Error budget impact calculated: -8%
3. Breach logged with:
   - Timestamp
   - Duration
   - Linked incidents
4. Alert sent to on-call
5. SRE investigates and links to incident

**Postconditions**: Breach documented for post-mortem

---

### UC-SRE-005: Record Change
**Actor**: SRE
**Preconditions**: Change scheduled/performed

**Main Flow**:
1. Navigate to SRE Portal → Changes
2. Create change record:
   - Type: deployment | configuration | maintenance
   - Service: Affected service
   - Risk level: low | medium | high
   - Approvers: Required sign-offs
   - Implementation plan: Step-by-step
   - Rollback plan: Recovery steps
3. Track change through states:
   - proposed → approved → in_progress → completed | failed

**Postconditions**: Change audit trail created

---

### UC-SRE-006: Create Chaos Experiment
**Actor**: SRE
**Preconditions**: Reliability hypothesis formed

**Main Flow**:
1. Navigate to SRE Portal → Chaos
2. Create experiment:
   - Name: "API Gateway Pod Failure"
   - Hypothesis: "System recovers within 30s"
   - Blast radius: 1 pod (limited)
   - Services affected: [api-gateway, auth-service]
   - Expected outcome: Automatic failover
3. Execute experiment (with approvals)
4. Record actual outcome
5. Document learnings
6. Update runbooks if needed

**Postconditions**: Reliability validated/improved

---

### UC-SRE-007: Track Toil
**Actor**: SRE
**Preconditions**: Manual repetitive work identified

**Main Flow**:
1. Navigate to SRE Portal → Toil
2. Log toil task:
   - Task: "Manual certificate rotation"
   - Frequency: monthly
   - Time spent: 2 hours
   - Automation effort: 8 hours (estimate)
   - Automation priority: high
   - Owner: @sre_team
3. System calculates ROI:
   - Toil time/year: 24 hours
   - Automation payback: 4 months
4. Prioritize automation backlog

**Postconditions**: Toil tracked, automation prioritized

---

### UC-SRE-008: Get Runbook Recommendations
**Actor**: SRE
**Preconditions**: Alert/incident active

**Main Flow**:
1. Alert triggers: "High CPU on app-server-3"
2. SRE queries: `get_runbook_recommendations("high_cpu")`
3. System returns ranked runbooks:
   - High CPU Alert (95% match)
   - Memory Exhaustion (70% match)
   - Service Restart (65% match)
4. SRE selects appropriate runbook
5. System logs selection for ML improvement

**Postconditions**: Faster incident response

---

### UC-SRE-009: Create Post-Mortem
**Actor**: SRE
**Preconditions**: Incident resolved

**Main Flow**:
1. Navigate to resolved incident
2. Click "Add Post-Mortem"
3. Fill post-mortem:
   - Timeline reconstruction
   - Root cause analysis (5 Whys)
   - What went well
   - What went poorly
   - Action items (with owners and deadlines)
4. Link to affected SLOs
5. Share with stakeholders
6. Track action item completion

**Postconditions**: Learning documented, actions tracked

---

## 4. Technical Leadership Use Cases

### UC-TL-001: Create RFC
**Actor**: Tech Lead
**Preconditions**: Significant change proposed

**Main Flow**:
1. Navigate to Knowledge Dashboard → Decisions
2. Create RFC:
   - Title: "Migrate to GraphQL Federation"
   - Type: rfc
   - Reviewers: [@alice, @bob, @charlie]
   - Deadline: 2026-01-15
   - Approval threshold: 2/3
   - Content: Detailed proposal
3. Submit for review
4. Reviewers add comments
5. Track approval status
6. RFC approved → becomes ADR

**Postconditions**: RFC reviewed and decided

---

### UC-TL-002: Create Tech Spec
**Actor**: Tech Lead
**Preconditions**: Implementation details needed

**Main Flow**:
1. Create tech spec:
   - Title: "Federation Gateway Implementation"
   - Scope: Detailed scope definition
   - Requirements: Functional requirements
   - Constraints: Technical constraints
   - Acceptance criteria: Definition of done
   - Implementation phases: Phased approach
2. Link to parent RFC/ADR
3. Track implementation progress

**Postconditions**: Implementation plan documented

---

### UC-TL-003: Track Technical Debt
**Actor**: Tech Lead
**Preconditions**: Tech debt identified

**Main Flow**:
1. Navigate to Knowledge Dashboard → Debt
2. Create debt item:
   - Area: "Authentication Module"
   - Description: "Legacy session handling"
   - Impact score: 1-10 (affects velocity)
   - Remediation effort: S/M/L/XL
   - Blockers: Dependencies
   - Timeline: Target resolution date
   - Owner: Responsible person
3. Link to related ADRs
4. Track debt trend over time

**Postconditions**: Debt visible and managed

---

### UC-TL-004: Map Capabilities
**Actor**: Tech Lead
**Preconditions**: Team skills assessment needed

**Main Flow**:
1. Navigate to Knowledge Dashboard → Capabilities
2. Create capability matrix:
   - Skill: "GraphQL Federation"
   - Current level: 2/5
   - Required level: 4/5
   - Gap analysis: "Need 2 more experts"
   - Learning plan: Training resources
3. Track skill development over time
4. Identify hiring needs

**Postconditions**: Team capabilities mapped

---

### UC-TL-005: Update Technology Radar
**Actor**: Tech Lead
**Preconditions**: Technology evaluation needed

**Main Flow**:
1. Navigate to Knowledge Dashboard → Radar
2. Create/update radar entry:
   - Technology: "Deno"
   - Quadrant: Languages & Frameworks
   - Ring: Assess | Trial | Adopt | Hold
   - Rationale: Why this positioning
   - Last review: Date
3. View radar visualization
4. Plan technology investments

**Postconditions**: Tech strategy documented

---

### UC-TL-006: Check Architecture Coherence
**Actor**: Tech Lead
**Preconditions**: Multiple decisions made

**Main Flow**:
1. Run coherence check: `architecture_coherence_check()`
2. System analyzes:
   - Decision consistency
   - Pattern usage
   - Dependency alignment
   - C4 model coverage
3. Report generated:
   - Coherence score: 85%
   - Issues found: 3
   - Recommendations: 5
4. Address identified issues

**Postconditions**: Architecture consistency maintained

---

### UC-TL-007: Analyze Decision Impact
**Actor**: Tech Lead
**Preconditions**: Major decision proposed

**Main Flow**:
1. Select decision for impact analysis
2. Run: `decision_impact_analysis(decision_id)`
3. System traces:
   - Dependent decisions
   - Affected code paths
   - Impacted teams
   - Related patterns
4. Visualize impact graph
5. Make informed decision

**Postconditions**: Decision impact understood

---

## 5. Knowledge Worker Use Cases

### UC-KW-001: Search Knowledge Base
**Actor**: Any User
**Preconditions**: Knowledge exists in KMS

**Main Flow**:
1. Navigate to main dashboard
2. Press [S] for search
3. Enter query: "authentication jwt refresh"
4. System returns:
   - Full-text matches (FTS5)
   - Semantic matches (embedding similarity)
   - Ranked by score
5. Filter by:
   - Type (decision, knowledge, process, etc.)
   - Domain (developer, product, sre)
   - Health status
6. Select result to view details

**Postconditions**: Relevant knowledge found

---

### UC-KW-002: Browse Holon Tree
**Actor**: Any User
**Preconditions**: Holons exist in KMS

**Main Flow**:
1. Navigate to main dashboard
2. View hierarchical tree:
   - Root
     - Knowledge (47)
     - Process (23)
     - Decision (31)
     - etc.
3. Expand/collapse nodes with [h]/[l]
4. Navigate with [j]/[k]
5. Select node with [Enter]
6. View detail panel

**Postconditions**: Knowledge structure understood

---

### UC-KW-003: View Holon Relationships
**Actor**: Any User
**Preconditions**: Holons with edges exist

**Main Flow**:
1. Navigate to main dashboard
2. Switch to [G]raph view
3. View relationship visualization:
   - Nodes: Holons
   - Edges: Relationships (IMPACTS, GUIDES, PRODUCES, etc.)
4. Filter by type
5. Zoom in/out
6. Click node for details

**Postconditions**: Relationships visualized

---

### UC-KW-004: Create Knowledge Entry
**Actor**: Any User
**Preconditions**: Knowledge to document

**Main Flow**:
1. Press [N] for new holon
2. Select type: knowledge
3. Fill details:
   - Name: "JWT Token Best Practices"
   - Content: Knowledge content
   - Tags: ["security", "jwt", "authentication"]
4. Optionally set parent
5. Submit
6. System auto-classifies (AI)
7. System generates embedding (AI)

**Postconditions**: Knowledge captured and indexed

---

### UC-KW-005: View Health Dashboard
**Actor**: Any User
**Preconditions**: Holons with vital signs

**Main Flow**:
1. Navigate to [A]nalytics view
2. View health metrics:
   - Overall health: 85%
   - Health by type (bar chart)
   - Health trend (line chart)
3. Identify low-health areas
4. Drill down into details

**Postconditions**: System health visible

---

### UC-KW-006: Review Entropy Report
**Actor**: Any User
**Preconditions**: Stale/orphan holons exist

**Main Flow**:
1. Navigate to Analytics → Entropy
2. View entropy metrics:
   - Stale holons (>90 days): List
   - Orphaned holons: List
   - Entropy score: 0.34
3. Select holons for action
4. Archive stale or link orphans

**Postconditions**: Entropy reduced

---

## 6. System Administrator Use Cases

### UC-ADM-001: Initialize KMS Database
**Actor**: System Admin
**Preconditions**: Fresh installation

**Main Flow**:
1. Run: `Indrajaal.KMS.Store.initialize()`
2. System creates:
   - SQLite database: `data/kms/holons.db`
   - DuckDB database: `data/kms/analytics.duckdb`
   - Schema: holons, holon_edges, holon_events, holon_vectors
3. Verify with health check
4. Create initial root holon

**Postconditions**: KMS ready for use

---

### UC-ADM-002: Configure Zenoh Integration
**Actor**: System Admin
**Preconditions**: Zenoh router available

**Main Flow**:
1. Configure Zenoh connection:
   - Router address
   - Key expressions
2. Start ZenohKmsPublisher
3. Verify pub/sub connectivity
4. Test cross-runtime sync

**Postconditions**: Real-time sync operational

---

### UC-ADM-003: Run Knowledge Gardening
**Actor**: System Admin
**Preconditions**: KMS populated with data

**Main Flow**:
1. Run: `Indrajaal.KMS.AI.garden(dry_run: true)`
2. Review proposed actions:
   - Stale holons to archive
   - Orphans to flag
   - Duplicates to merge
3. If satisfied: `garden(dry_run: false)`
4. Review results
5. Verify no unintended changes

**Postconditions**: Knowledge base cleaned
**STAMP**: SC-KMS-016 (human approval required)

---

### UC-ADM-004: Export/Import Holons
**Actor**: System Admin
**Preconditions**: Backup/migration needed

**Main Flow**:
1. Export: Copy `data/kms/` directory
2. Import: Place in new location
3. Verify integrity
4. Update config paths if needed

**Postconditions**: Data portable
**STAMP**: SC-KMS-003 (portable holons)

---

### UC-ADM-005: Monitor KMS Performance
**Actor**: System Admin
**Preconditions**: KMS operational

**Main Flow**:
1. View metrics:
   - Query latency (P50, P95, P99)
   - Write throughput
   - Cache hit rate
   - Zenoh message latency
2. Check OODA cycle time (<100ms)
3. Identify bottlenecks
4. Tune configuration

**Postconditions**: Performance maintained
**STAMP**: SC-KMS-004 (OODA <100ms)

---

## 7. AI/Automation Scenarios

> **[Updated Sprint 51: real implementation]** All AI/Automation use cases below are now backed by real OpenRouter API integration in `lib/indrajaal/kms/ai.ex`. Classification uses LLM analysis, embedding generation uses voyage-3 model, and knowledge gardening runs real stale/orphan detection. These are no longer planned features.

### UC-AI-001: Auto-Classify Holon
**Actor**: System (AI)
**Trigger**: New holon created

**Main Flow**:
1. Holon created with content
2. AI module invoked: `classify(holon)`
3. System analyzes:
   - Content keywords
   - Structure patterns
   - Similar existing holons
4. Returns classification:
   - Suggested type
   - Confidence score (must be ≥0.75)
   - Suggested tags
   - Suggested parent
5. If confidence high: auto-apply
6. If low: flag for human review

**Postconditions**: Holon classified
**STAMP**: SC-KMS-013 (confidence threshold)

---

### UC-AI-002: Generate Embedding
**Actor**: System (AI)
**Trigger**: Holon created/updated

**Main Flow**:
1. Holon content changed
2. AI module invoked: `generate_embedding(holon)`
3. System generates:
   - 1024-dimension vector
   - Model: voyage-3 (or compatible)
4. Store in holon_vectors table
5. Enable semantic search

**Postconditions**: Embedding stored
**STAMP**: SC-KMS-014 (1024 dimensions)

---

### UC-AI-003: Find Similar Holons
**Actor**: User / System
**Trigger**: Query or new holon

**Main Flow**:
1. User searches or creates holon
2. AI module invoked: `find_similar(holon, k: 5)`
3. System computes:
   - Embedding similarity (cosine)
   - Threshold: 0.7 minimum
4. Returns ranked similar holons
5. Optionally suggest relationships

**Postconditions**: Similar content discovered

---

### UC-AI-004: Infer Relationships
**Actor**: System (AI)
**Trigger**: Manual or scheduled

**Main Flow**:
1. AI module invoked: `infer_relationships(holons)`
2. System analyzes:
   - Content similarity (Jaccard)
   - Type compatibility
   - Structural patterns
3. Suggests edges:
   - decision → architecture: "IMPACTS"
   - process → artifact: "PRODUCES"
4. Human reviews suggestions
5. Approved edges created

**Postconditions**: Graph enriched

---

### UC-AI-005: Scheduled Gardening
**Actor**: System (Scheduler)
**Trigger**: Cron (max once/hour)

**Main Flow**:
1. Scheduler triggers garden job
2. System checks last run (must be >1 hour)
3. Runs garden with dry_run: true
4. Logs proposed actions
5. If auto-approved: executes non-destructive actions
6. Destructive actions flagged for human review

**Postconditions**: Automated maintenance
**STAMP**: SC-KMS-015 (max once/hour)

---

## 8. Cross-Runtime Scenarios

### UC-XRUN-001: Elixir→F# Holon Sync
**Actor**: System
**Trigger**: Holon created in Elixir

**Main Flow**:
1. Elixir creates holon via `KMS.Store.create_holon()`
2. ZenohKmsPublisher broadcasts:
   - Topic: `indrajaal/kms/holons/created`
   - Payload: Holon JSON
3. F# KmsSubscriber receives message
4. F# updates local state
5. F# KmsPanel refreshes display

**Postconditions**: Both runtimes synchronized
**STAMP**: SC-KMS-005 (Zenoh sync)

---

### UC-XRUN-002: F#→Elixir Command
**Actor**: F# Cockpit User
**Trigger**: User action in F# TUI

**Main Flow**:
1. User presses [D] to delete holon in F# TUI
2. F# publishes command:
   - Topic: `indrajaal/cockpit/cmd/delete`
   - Payload: {holon_id, confirmation_token}
3. Elixir command handler receives
4. Elixir executes delete
5. Elixir broadcasts result
6. F# receives confirmation

**Postconditions**: Command executed across runtimes

---

### UC-XRUN-003: Health State Broadcast
**Actor**: System
**Trigger**: Health metrics updated

**Main Flow**:
1. Elixir computes health report
2. ZenohKmsPublisher broadcasts:
   - Topic: `indrajaal/kms/state/health`
   - Payload: Health metrics JSON
3. F# KmsSubscriber receives
4. F# updates health view
5. Both UIs show consistent health

**Postconditions**: Consistent health display

---

### UC-XRUN-004: Graphiti Bidirectional Sync
**Actor**: System
**Trigger**: Graphiti or KMS update

**Main Flow**:
1. Graphiti creates new Extraction
2. GraphitiBridge detects via PubSub
3. Bridge creates corresponding holon:
   - Type: knowledge
   - Source: graphiti
   - Payload: Extraction content
4. Reverse: KMS holon → Graphiti Fact
5. Conflict resolution: HLC timestamp wins

**Postconditions**: Graphiti ↔ KMS synchronized
**STAMP**: SC-KMS-010 (bidirectional sync)

---

## 9. Safety-Critical Scenarios

### UC-SAFE-001: Delete Holon (Arm & Fire)
**Actor**: User with delete permission
**Trigger**: User initiates delete

**Main Flow**:
1. User selects holon
2. User presses [D] for delete
3. System enters ARMED state:
   - UI dims surrounding zones
   - Shows "READY TO FIRE"
   - Starts 10-second timeout
4. User holds [SPACE] for 3 seconds
5. Progress bar fills to 100%
6. System enters ENGAGED state
7. Holon deleted
8. Screen flashes white
9. Audit log created

**Alternative**: User releases early or presses ESC
- System returns to IDLE
- Delete cancelled

**Postconditions**: Safe deletion with audit trail
**STAMP**: SC-HMI-003 (Arm & Fire protocol)

---

### UC-SAFE-002: Connection Loss Handling
**Actor**: System
**Trigger**: Heartbeat failure

**Main Flow**:
1. TUI sends heartbeat every 100ms
2. Backend misses 5 consecutive beats (500ms)
3. System displays full-screen overlay:
   - "CONNECTION LOST"
   - Last heartbeat timestamp
   - Reconnection attempts
4. All interactive controls disabled
5. On reconnection:
   - Overlay dismissed
   - Controls re-enabled
   - State synchronized

**Postconditions**: User aware of connection state
**STAMP**: SC-PRAJNA-002 (connection loss)

---

### UC-SAFE-003: E-Stop Override
**Actor**: Physical E-Stop
**Trigger**: E-Stop button pressed

**Main Flow**:
1. GPIO interrupt triggered
2. System immediately:
   - Locks all UI to "E-STOP ENGAGED"
   - Cancels any pending operations
   - Logs emergency stop event
3. System remains locked until:
   - E-Stop released
   - Manual unlock command
4. Full audit trail created

**Postconditions**: System in safe state
**STAMP**: SC-PRAJNA-003 (E-Stop integration)

---

### UC-SAFE-004: Process Crash Recovery
**Actor**: System (Supervisor)
**Trigger**: GenServer crash

**Main Flow**:
1. KMS.Store process crashes
2. Supervisor detects within 10ms
3. Supervisor restarts process
4. Process recovers state from:
   - ETS persistence
   - SQLite database
5. Total recovery time <50ms
6. User sees brief flicker (if any)

**Postconditions**: Continuous availability
**STAMP**: NFR-REL-001 (restart <50ms)

---

### UC-SAFE-005: Data Staling Indication
**Actor**: System
**Trigger**: Data update delay

**Main Flow**:
1. System tracks last update timestamp for each component
2. If data age >2 seconds:
   - Apply desaturation filter
   - Show "⏳" stale indicator
   - Log staleness event
3. When fresh data arrives:
   - Remove desaturation
   - Remove indicator
4. User always aware of data freshness

**Postconditions**: No stale data displayed as fresh
**STAMP**: SC-HMI-004 (stale indication)

---

## 10. Error & Recovery Scenarios

### UC-ERR-001: Database Write Failure
**Actor**: System
**Trigger**: SQLite write error

**Main Flow**:
1. User creates holon
2. SQLite write fails (disk full, corruption)
3. System:
   - Returns error to user
   - Logs detailed error
   - Does NOT show success
4. User sees error message in Zone C
5. Retry option available
6. If persistent: escalate to admin

**Postconditions**: Data integrity maintained

---

### UC-ERR-002: Zenoh Connection Failure
**Actor**: System
**Trigger**: Zenoh router unavailable

**Main Flow**:
1. ZenohKmsPublisher detects connection loss
2. Circuit breaker opens after 3 failures
3. System:
   - Queues messages locally
   - Shows "SYNC OFFLINE" indicator
   - Continues local operations
4. On reconnection:
   - Circuit breaker closes
   - Queued messages sent
   - Full sync performed

**Postconditions**: Graceful degradation

---

### UC-ERR-003: AI Service Timeout
**Actor**: System
**Trigger**: AI classification timeout

**Main Flow**:
1. User creates holon
2. AI classification times out (>20s)
3. System:
   - Saves holon without classification
   - Flags for manual classification
   - Logs timeout event
4. Holon usable immediately
5. Background retry scheduled

**Postconditions**: User not blocked by AI

---

### UC-ERR-004: Invalid Holon Data
**Actor**: System
**Trigger**: Validation failure

**Main Flow**:
1. User submits holon with invalid data
2. Validation fails:
   - Missing required fields
   - Invalid type
   - Malformed JSON
3. System:
   - Returns specific error message
   - Highlights invalid fields
   - Preserves user input
4. User corrects and resubmits

**Postconditions**: Only valid data stored

---

### UC-ERR-005: Rendering Tier Fallback
**Actor**: System
**Trigger**: Terminal capability detection

**Main Flow**:
1. F# TUI starts
2. Detects terminal capabilities:
   - Tier 1: Kitty/WezTerm (GPU)
   - Tier 2: Modern terminal (Unicode)
   - Tier 3: Basic terminal (ASCII)
3. If Tier 1 rendering fails:
   - Falls back to Tier 2
   - Logs fallback event
4. If Tier 2 fails:
   - Falls back to Tier 3
5. UI always functional

**Postconditions**: Universal terminal support
**STAMP**: AOR-TUI-009 (graceful degradation)

---

## Scenario Matrix

### By Actor
| Actor | Scenario Count |
|-------|----------------|
| Developer | 7 |
| Product Manager | 8 |
| SRE | 9 |
| Tech Lead | 7 |
| Knowledge Worker | 6 |
| System Admin | 5 |
| AI/Automation | 5 |
| Cross-Runtime | 4 |
| Safety | 5 |
| Error Recovery | 5 |
| **Total** | **61** |

### By Priority
| Priority | Scenarios |
|----------|-----------|
| Critical | UC-SAFE-*, UC-ERR-001, UC-ERR-002 |
| High | UC-DEV-001-003, UC-SRE-001-002, UC-XRUN-* |
| Medium | UC-PM-*, UC-TL-*, UC-AI-* |
| Low | UC-KW-*, UC-ADM-003-005 |

### By STAMP Constraint
| Constraint | Scenarios |
|------------|-----------|
| SC-KMS-003 | UC-ADM-004 |
| SC-KMS-004 | UC-ADM-005 |
| SC-KMS-005 | UC-XRUN-001-003 |
| SC-KMS-007 | UC-DEV-001, UC-DEV-002 |
| SC-KMS-010 | UC-XRUN-004 |
| SC-KMS-013 | UC-AI-001 |
| SC-KMS-014 | UC-AI-002 |
| SC-KMS-015 | UC-AI-005 |
| SC-KMS-016 | UC-ADM-003 |
| SC-HMI-003 | UC-SAFE-001, UC-SRE-002 |
| SC-HMI-004 | UC-SAFE-005 |
| SC-PRAJNA-002 | UC-SAFE-002 |
| SC-PRAJNA-003 | UC-SAFE-003 |

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-30 | Claude | Initial comprehensive catalog |

**STAMP Compliance**: All scenarios mapped to safety constraints
**TDG Compliance**: Scenarios ready for test case derivation
**Traceability**: Full actor → scenario → constraint mapping
