# INDRAJAAL 5-LEVEL ROOT CAUSE ANALYSIS FRAMEWORK v20.0
## Autonomous Agent-Based Issue Resolution System

**Document Type**: RCA Framework + Autonomous Agent Protocol
**Version**: 20.0-RCA
**Date**: 2025-12-30T00:45:00+01:00
**Status**: ACTIVE SPECIFICATION
**Goal**: 100% Static + 100% Runtime Coverage via Autonomous Agents

---

# TABLE OF CONTENTS

1. [5-Level RCA Framework](#1-5-level-rca-framework)
2. [Agent Hierarchy (25 Agents + 3 Supervisors)](#2-agent-hierarchy)
3. [OODA-Based Decision Loop](#3-ooda-based-decision-loop)
4. [Criticality-Based Fix Plan](#4-criticality-based-fix-plan)
5. [Hysteresis & Anti-Loop Protection](#5-hysteresis--anti-loop-protection)
6. [Autonomous Execution Protocol](#6-autonomous-execution-protocol)
7. [Dashboard & Progress Tracking](#7-dashboard--progress-tracking)

---

# 1. 5-LEVEL RCA FRAMEWORK

## 1.1 Level Definitions

```
────────────────────────────────────────────────────────────────────────────────
                     5-LEVEL ROOT CAUSE ANALYSIS
────────────────────────────────────────────────────────────────────────────────

LEVEL 1: SYMPTOM IDENTIFICATION
──────────────────────────────────────────────────────────────────────────────
  • What is the observable problem?
  • Where does it manifest?
  • When does it occur?
  • What is the immediate impact?

  TECHNIQUES:
    - Log analysis
    - Error message parsing
    - Test failure inspection
    - Credo/Dialyzer output parsing

  OUTPUT: Symptom List with Location and Frequency

────────────────────────────────────────────────────────────────────────────────

LEVEL 2: PROXIMATE CAUSE ANALYSIS
──────────────────────────────────────────────────────────────────────────────
  • What code directly caused the symptom?
  • What file/function/line is responsible?
  • What was the immediate trigger?

  TECHNIQUES:
    - Stack trace analysis
    - Code diff inspection
    - Git blame investigation
    - Dependency graph traversal

  OUTPUT: Direct Cause with Code Location

────────────────────────────────────────────────────────────────────────────────

LEVEL 3: CONTRIBUTING FACTOR ANALYSIS
──────────────────────────────────────────────────────────────────────────────
  • What conditions enabled the proximate cause?
  • What dependencies are involved?
  • What assumptions were violated?

  TECHNIQUES:
    - Dependency analysis
    - Configuration review
    - API contract verification
    - Type checking

  OUTPUT: Contributing Factors List with Dependency Chain

────────────────────────────────────────────────────────────────────────────────

LEVEL 4: ROOT CAUSE IDENTIFICATION
──────────────────────────────────────────────────────────────────────────────
  • Why did the contributing factors exist?
  • What systemic issue allowed this?
  • What pattern led to this defect?

  TECHNIQUES:
    - Pattern matching across similar issues
    - Architectural review
    - Process gap analysis
    - Historical regression analysis

  OUTPUT: Root Cause with Pattern Classification

────────────────────────────────────────────────────────────────────────────────

LEVEL 5: SYSTEMIC PREVENTION
──────────────────────────────────────────────────────────────────────────────
  • How do we prevent recurrence?
  • What guardrails need to be added?
  • What process improvements are needed?
  • How do we verify the fix?

  TECHNIQUES:
    - STAMP constraint addition
    - TDG test creation
    - AOR rule enforcement
    - Automated prevention mechanisms

  OUTPUT: Prevention Plan with Verification Steps

────────────────────────────────────────────────────────────────────────────────
```

## 1.2 RCA Flow Diagram

```
────────────────────────────────────────────────────────────────────────────────
                     RCA ANALYSIS FLOW
────────────────────────────────────────────────────────────────────────────────

           ┌──────────────────────────────────────────┐
           │          ISSUE DETECTED                  │
           │  (Compile Error, Test Fail, Credo, etc.) │
           └────────────────────┬─────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │  LEVEL 1: SYMPTOM     │
                    │  What? Where? When?   │
                    └───────────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │  LEVEL 2: PROXIMATE   │
                    │  Which code caused it?│
                    └───────────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │  LEVEL 3: CONTRIBUTING│
                    │  What enabled it?     │
                    └───────────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │  LEVEL 4: ROOT CAUSE  │
                    │  Why did this exist?  │
                    └───────────┬───────────┘
                                │
                    ┌───────────▼───────────┐
                    │  LEVEL 5: PREVENTION  │
                    │  How to prevent?      │
                    └───────────┬───────────┘
                                │
           ┌────────────────────▼─────────────────────┐
           │          FIX IMPLEMENTATION              │
           │  (Agent executes fix, tests verify)      │
           └──────────────────────────────────────────┘

────────────────────────────────────────────────────────────────────────────────
```

---

# 2. AGENT HIERARCHY (25 AGENTS + 3 SUPERVISORS)

## 2.1 3-Layer Supervisor Structure

```
────────────────────────────────────────────────────────────────────────────────
                     AUTONOMOUS AGENT HIERARCHY
────────────────────────────────────────────────────────────────────────────────

LAYER 0: EXECUTIVE SUPERVISOR (1)
┌──────────────────────────────────────────────────────────────────────────────┐
│  RCA-EXECUTIVE                                                               │
│  ──────────────────────────────────────────────────────────────────────────  │
│  ROLE: Supreme decision authority                                            │
│  RESPONSIBILITY:                                                             │
│    - Goal tracking (100% coverage)                                           │
│    - Resource allocation                                                     │
│    - Conflict resolution                                                     │
│    - Emergency halt authority                                                │
│  OODA CYCLE: 30 seconds                                                      │
│  HYSTERESIS: 3 cycles before decision change                                 │
└──────────────────────────────────────────────────────────────────────────────┘

LAYER 1: DOMAIN SUPERVISORS (3)
┌──────────────────────────────────────────────────────────────────────────────┐
│  RCA-STATIC-SUPERVISOR                                                       │
│  ──────────────────────────────────────────────────────────────────────────  │
│  ROLE: Static analysis issue resolution                                      │
│  DOMAINS: Compile, Credo, Dialyzer, Format                                   │
│  AGENTS: 8 workers                                                           │
│  OODA CYCLE: 10 seconds                                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│  RCA-RUNTIME-SUPERVISOR                                                      │
│  ──────────────────────────────────────────────────────────────────────────  │
│  ROLE: Runtime test issue resolution                                         │
│  DOMAINS: Unit, Integration, Property, E2E                                   │
│  AGENTS: 8 workers                                                           │
│  OODA CYCLE: 10 seconds                                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│  RCA-COVERAGE-SUPERVISOR                                                     │
│  ──────────────────────────────────────────────────────────────────────────  │
│  ROLE: Coverage gap resolution                                               │
│  DOMAINS: STAMP, TDG, FMEA, Formal Verification                              │
│  AGENTS: 9 workers                                                           │
│  OODA CYCLE: 10 seconds                                                      │
└──────────────────────────────────────────────────────────────────────────────┘

LAYER 2: WORKER AGENTS (25)
┌──────────────────────────────────────────────────────────────────────────────┐
│  STATIC ANALYSIS WORKERS (8)                                                 │
│  ──────────────────────────────────────────────────────────────────────────  │
│  1. COMPILE-ERROR-FIXER     - Fixes compilation errors                       │
│  2. WARNING-ELIMINATOR      - Removes compiler warnings                      │
│  3. CREDO-REFACTOR          - Fixes Credo style issues                       │
│  4. DIALYZER-TYPE-FIXER     - Fixes type specification errors                │
│  5. FORMAT-NORMALIZER       - Applies formatting rules                       │
│  6. UNUSED-CODE-CLEANER     - Removes dead code                              │
│  7. DEPENDENCY-RESOLVER     - Fixes import/alias issues                      │
│  8. SYNTAX-CORRECTOR        - Fixes syntax errors                            │
├──────────────────────────────────────────────────────────────────────────────┤
│  RUNTIME TEST WORKERS (8)                                                    │
│  ──────────────────────────────────────────────────────────────────────────  │
│  1. UNIT-TEST-FIXER         - Fixes failing unit tests                       │
│  2. INTEGRATION-TEST-FIXER  - Fixes integration test failures                │
│  3. PROPERTY-TEST-FIXER     - Fixes property test issues                     │
│  4. FACTORY-FIXER           - Fixes test factory issues                      │
│  5. MOCK-UPDATER            - Updates outdated mocks                         │
│  6. ASSERTION-CORRECTOR     - Fixes incorrect assertions                     │
│  7. SETUP-TEARDOWN-FIXER    - Fixes test setup/teardown                      │
│  8. ASYNC-TEST-FIXER        - Fixes async test timing issues                 │
├──────────────────────────────────────────────────────────────────────────────┤
│  COVERAGE WORKERS (9)                                                        │
│  ──────────────────────────────────────────────────────────────────────────  │
│  1. STAMP-CONSTRAINT-ADDER  - Adds missing STAMP constraints                 │
│  2. TDG-TEST-GENERATOR      - Generates missing tests                        │
│  3. AOR-RULE-ENFORCER       - Enforces agent operating rules                 │
│  4. FMEA-MITIGATOR          - Implements FMEA mitigations                    │
│  5. AGDA-PROOF-WRITER       - Writes Agda proofs                             │
│  6. QUINT-MODEL-WRITER      - Writes Quint models                            │
│  7. COVERAGE-GAP-FILLER     - Fills code coverage gaps                       │
│  8. DOC-GENERATOR           - Generates missing documentation                │
│  9. SPEC-VALIDATOR          - Validates specifications                       │
└──────────────────────────────────────────────────────────────────────────────┘
────────────────────────────────────────────────────────────────────────────────
```

## 2.2 Agent Communication Protocol

```
────────────────────────────────────────────────────────────────────────────────
                     AGENT COMMUNICATION PROTOCOL
────────────────────────────────────────────────────────────────────────────────

MESSAGE TYPES:
  TASK_ASSIGN      : Supervisor → Worker (assign task)
  TASK_PROGRESS    : Worker → Supervisor (progress update)
  TASK_COMPLETE    : Worker → Supervisor (completion report)
  TASK_BLOCKED     : Worker → Supervisor (blocked notification)
  PRIORITY_UPDATE  : Executive → All (priority change)
  EMERGENCY_HALT   : Executive → All (stop all work)
  RESOURCE_REQUEST : Worker → Supervisor (request resources)
  RESOURCE_GRANT   : Supervisor → Worker (grant resources)

MESSAGE FORMAT:
  {
    "id": "uuid",
    "type": "TASK_ASSIGN",
    "from": "RCA-STATIC-SUPERVISOR",
    "to": "COMPILE-ERROR-FIXER",
    "timestamp": "2025-12-30T00:45:00Z",
    "priority": "P0_CRITICAL",
    "payload": {
      "issue_id": "COMPILE-001",
      "file": "lib/indrajaal/accounts/user.ex",
      "line": 42,
      "description": "undefined function",
      "rca_level": 2,
      "estimated_complexity": "LOW"
    }
  }

PRIORITY LANES:
  P0_CRITICAL  : Constitution violations, safety issues
  P1_HIGH      : Compile errors, test failures
  P2_MEDIUM    : Warnings, Credo issues
  P3_LOW       : Coverage gaps, documentation

────────────────────────────────────────────────────────────────────────────────
```

---

# 3. OODA-BASED DECISION LOOP

## 3.1 Fast OODA Cycle

```
────────────────────────────────────────────────────────────────────────────────
                     FAST OODA LOOP (10-30 second cycles)
────────────────────────────────────────────────────────────────────────────────

OBSERVE (2-5 seconds):
  ┌─────────────────────────────────────────────────────────────────────────┐
  │ • Parse compile output for errors/warnings                              │
  │ • Parse Credo output for issues                                         │
  │ • Parse test output for failures                                        │
  │ • Check coverage reports for gaps                                       │
  │ • Monitor agent status and progress                                     │
  └─────────────────────────────────────────────────────────────────────────┘

ORIENT (2-5 seconds):
  ┌─────────────────────────────────────────────────────────────────────────┐
  │ • Classify issues by type and severity                                  │
  │ • Perform 5-level RCA on new issues                                     │
  │ • Identify dependencies between issues                                  │
  │ • Calculate criticality scores                                          │
  │ • Detect patterns and clusters                                          │
  └─────────────────────────────────────────────────────────────────────────┘

DECIDE (2-5 seconds):
  ┌─────────────────────────────────────────────────────────────────────────┐
  │ • Prioritize issues by criticality                                      │
  │ • Assign issues to appropriate agents                                   │
  │ • Allocate resources based on complexity                                │
  │ • Set deadlines and checkpoints                                         │
  │ • Apply hysteresis to prevent oscillation                               │
  └─────────────────────────────────────────────────────────────────────────┘

ACT (4-15 seconds):
  ┌─────────────────────────────────────────────────────────────────────────┐
  │ • Execute fixes via agent workers                                       │
  │ • Run verification tests                                                │
  │ • Update progress tracking                                              │
  │ • Commit successful fixes                                               │
  │ • Report results to supervisor                                          │
  └─────────────────────────────────────────────────────────────────────────┘

CYCLE TIME CONSTRAINTS:
  Executive:   30 seconds (strategic decisions)
  Supervisor:  10 seconds (tactical coordination)
  Worker:      Variable (depends on fix complexity)

────────────────────────────────────────────────────────────────────────────────
```

---

# 4. CRITICALITY-BASED FIX PLAN

## 4.1 Criticality Scoring

```
────────────────────────────────────────────────────────────────────────────────
                     CRITICALITY SCORING MATRIX
────────────────────────────────────────────────────────────────────────────────

CRITICALITY = SEVERITY × IMPACT × URGENCY × (1 / COMPLEXITY)

SEVERITY (1-10):
  10: Blocks all compilation
   8: Blocks specific module compilation
   6: Causes test failures
   4: Causes warnings
   2: Style/format issues
   1: Documentation gaps

IMPACT (1-10):
  10: Affects entire system
   8: Affects multiple domains
   6: Affects single domain
   4: Affects single module
   2: Affects single function
   1: Affects single line

URGENCY (1-10):
  10: Constitution violation
   8: CI/CD pipeline blocked
   6: Feature blocked
   4: Technical debt
   2: Nice to have
   1: Cosmetic

COMPLEXITY (1-10):
  10: Architectural change required
   8: Multi-file refactoring
   6: Single file significant change
   4: Single function change
   2: Few lines change
   1: Single line fix

CRITICALITY THRESHOLDS:
  CRITICAL (>80):  Immediate fix, all resources
  HIGH (60-80):    Priority fix, dedicated agent
  MEDIUM (40-60):  Scheduled fix, normal priority
  LOW (20-40):     Batch fix, low priority
  MINIMAL (<20):   Backlog, when resources available

────────────────────────────────────────────────────────────────────────────────
```

## 4.2 Fix Execution Order

```
────────────────────────────────────────────────────────────────────────────────
                     FIX EXECUTION ORDER
────────────────────────────────────────────────────────────────────────────────

PHASE 1: FOUNDATION FIXES (Blocks everything)
  1. Syntax errors (compilation blockers)
  2. Missing dependencies (import/alias)
  3. Undefined functions/modules
  4. Circular dependencies

PHASE 2: TYPE FIXES (Type safety)
  1. Dialyzer errors
  2. @spec violations
  3. Pattern match failures
  4. Guard clause issues

PHASE 3: LOGIC FIXES (Test failures)
  1. Unit test failures
  2. Integration test failures
  3. Property test failures
  4. Factory issues

PHASE 4: QUALITY FIXES (Code quality)
  1. Credo strict violations
  2. Compiler warnings
  3. Unused variables/functions
  4. Code duplication

PHASE 5: COVERAGE FIXES (100% coverage)
  1. Missing tests for uncovered code
  2. Missing STAMP constraints
  3. Missing documentation
  4. Missing formal specifications

────────────────────────────────────────────────────────────────────────────────
```

---

# 5. HYSTERESIS & ANTI-LOOP PROTECTION

## 5.1 Hysteresis Configuration

```
────────────────────────────────────────────────────────────────────────────────
                     HYSTERESIS PARAMETERS
────────────────────────────────────────────────────────────────────────────────

DECISION HYSTERESIS:
  MARGIN: 10%           -- Must change by >10% to trigger new decision
  HOLD_CYCLES: 3        -- Must persist for 3 cycles
  COOLDOWN: 60 seconds  -- After change, wait before next change

PRIORITY HYSTERESIS:
  PROMOTION_THRESHOLD: +20 criticality points
  DEMOTION_THRESHOLD: -30 criticality points
  MIN_HOLD_TIME: 5 cycles before demotion

RESOURCE HYSTERESIS:
  SCALE_UP_THRESHOLD: 80% utilization for 3 cycles
  SCALE_DOWN_THRESHOLD: 20% utilization for 5 cycles
  MAX_SCALE_RATE: 2 agents per cycle

ANTI-LOOP DETECTION:
  FIX_ATTEMPT_LIMIT: 3 attempts per issue
  ROLLBACK_ON_FAIL: After 2 failed attempts
  ESCALATE_ON_LOOP: After 3 attempts, escalate to supervisor
  BLACKLIST_DURATION: 10 cycles after 3 failures

────────────────────────────────────────────────────────────────────────────────
```

## 5.2 Loop Detection Algorithm

```
────────────────────────────────────────────────────────────────────────────────
                     LOOP DETECTION ALGORITHM
────────────────────────────────────────────────────────────────────────────────

ALGORITHM: DetectLoop(issue_history)
  INPUT: List of (issue_id, fix_attempt, result) tuples
  OUTPUT: Boolean (loop detected)

  1. Group history by issue_id
  2. For each issue:
     a. Count consecutive failures
     b. If failures >= 3:
        - Mark as potential loop
        - Check fix similarity (>80% same = loop)
     c. If same fix applied 2+ times:
        - Definite loop detected
  3. Return true if any loop detected

RECOVERY ACTIONS:
  1. ESCALATE: Send to higher supervisor
  2. ALTERNATE: Try different fix strategy
  3. DEFER: Move to backlog for manual review
  4. BLACKLIST: Temporarily skip issue
  5. EMERGENCY: Halt all work on this area

STATE MACHINE:
  NORMAL → SUSPICIOUS (1 failure)
  SUSPICIOUS → LOOP_RISK (2 failures)
  LOOP_RISK → LOOP_DETECTED (3 failures)
  LOOP_DETECTED → ESCALATED (supervisor notified)
  ESCALATED → RESOLVED | BLACKLISTED

────────────────────────────────────────────────────────────────────────────────
```

---

# 6. AUTONOMOUS EXECUTION PROTOCOL

## 6.1 Full Autonomous Mode

```
────────────────────────────────────────────────────────────────────────────────
                     AUTONOMOUS EXECUTION PROTOCOL
────────────────────────────────────────────────────────────────────────────────

GOAL CRITERIA:
  ☑ 0 compile errors
  ☑ 0 compile warnings
  ☑ 0 test failures
  ☑ 0 Credo strict violations
  ☑ 0 format violations
  ☑ 100% STAMP constraint coverage
  ☑ 100% TDG test coverage
  ☑ 100% code line coverage

AUTONOMOUS RULES:
  1. NO human approval required until goal met
  2. NO stopping for non-critical issues
  3. NO manual intervention unless emergency
  4. ALL fixes committed automatically
  5. ALL tests run automatically

CHECKPOINT PROTOCOL:
  Every 30 seconds:
    - Save current state
    - Update dashboard
    - Check goal progress
    - Adjust priorities

EMERGENCY HALT CONDITIONS:
  - Constitution violation detected
  - Data corruption risk
  - Infinite loop detected (5+ cycles same issue)
  - Resource exhaustion (>95% memory/CPU)
  - Executive manual halt command

────────────────────────────────────────────────────────────────────────────────
```

## 6.2 Agent Execution Flow

```
────────────────────────────────────────────────────────────────────────────────
                     AGENT EXECUTION FLOW
────────────────────────────────────────────────────────────────────────────────

WORKER AGENT LIFECYCLE:

  IDLE ────► ASSIGNED ────► ANALYZING ────► FIXING ────► VERIFYING ────► DONE
    │            │              │              │              │           │
    │            │              │              │              │           │
    │            ▼              ▼              ▼              ▼           │
    │        (receive       (5-level        (apply        (run          │
    │         task)          RCA)           fix)          tests)        │
    │                                                                    │
    └────────────────────────────────────────────────────────────────────┘
                                 (return to IDLE after DONE)

THINKING OUTPUT (Per Agent):
  ┌─────────────────────────────────────────────────────────────────────────┐
  │ [COMPILE-ERROR-FIXER] Cycle 42                                         │
  │ ─────────────────────────────────────────────────────────────────────── │
  │ OBSERVE: Found 3 compile errors in lib/indrajaal/accounts/             │
  │ ORIENT:  L2 RCA - undefined function `create_changeset/2`              │
  │ DECIDE:  Fix by adding missing function or fixing call                 │
  │ ACT:     Adding function stub to user.ex:42                            │
  │ VERIFY:  Recompiling... SUCCESS (2 errors remaining)                   │
  │ STATUS:  FIXING (1/3 complete, ETA 20s)                                │
  └─────────────────────────────────────────────────────────────────────────┘

────────────────────────────────────────────────────────────────────────────────
```

---

# 7. DASHBOARD & PROGRESS TRACKING

## 7.1 Real-Time Dashboard

```
────────────────────────────────────────────────────────────────────────────────
                     AUTONOMOUS RCA DASHBOARD
                     Updated: 2025-12-30 00:45:30 UTC
────────────────────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────────────────────────┐
│                           GOAL PROGRESS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  Static Analysis:    ████████████████████░░░░  85% ▲                       │
│  Runtime Coverage:   ████████████████░░░░░░░░  70% ▲                       │
│  Formal Specs:       ████████████░░░░░░░░░░░░  55% ▲                       │
│  Overall:            ████████████████░░░░░░░░  70% ▲                       │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         ISSUE BREAKDOWN                                      │
├───────────────────────────────┬─────────────────────────────────────────────┤
│  CRITICAL (P0):     0  ✓     │  [================] 100% resolved           │
│  HIGH (P1):         3  ⚠     │  [============....] 80% resolved            │
│  MEDIUM (P2):      12  ⚠     │  [=========.......] 60% resolved            │
│  LOW (P3):         28  ○     │  [======..........] 40% resolved            │
├───────────────────────────────┴─────────────────────────────────────────────┤
│  TOTAL ISSUES: 43 | RESOLVED: 31 | IN PROGRESS: 8 | PENDING: 4             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          AGENT STATUS                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  EXECUTIVE:           ● ACTIVE   Cycle: 142   Efficiency: 98%              │
│  ────────────────────────────────────────────────────────────────────────── │
│  STATIC-SUPERVISOR:   ● ACTIVE   Workers: 8/8  Tasks: 12                   │
│    ├─ COMPILE-ERROR-FIXER      ● FIXING   lib/accounts/user.ex:42         │
│    ├─ WARNING-ELIMINATOR       ● IDLE     Waiting for task                 │
│    ├─ CREDO-REFACTOR           ● FIXING   lib/alarms/event.ex:88          │
│    ├─ DIALYZER-TYPE-FIXER      ● VERIFYING lib/auth/jwt.ex:15             │
│    ├─ FORMAT-NORMALIZER        ○ IDLE     Waiting for task                 │
│    ├─ UNUSED-CODE-CLEANER      ● ANALYZING lib/video/processor.ex         │
│    ├─ DEPENDENCY-RESOLVER      ● FIXING   lib/integration/sync.ex:22      │
│    └─ SYNTAX-CORRECTOR         ○ IDLE     Waiting for task                 │
│  ────────────────────────────────────────────────────────────────────────── │
│  RUNTIME-SUPERVISOR:  ● ACTIVE   Workers: 8/8  Tasks: 8                    │
│    ├─ UNIT-TEST-FIXER          ● FIXING   test/accounts/user_test.exs:55  │
│    ├─ INTEGRATION-TEST-FIXER   ● VERIFYING test/dispatch/coord_test.exs   │
│    ├─ PROPERTY-TEST-FIXER      ● ANALYZING test/alarms/prop_test.exs      │
│    └─ ... (5 more)                                                          │
│  ────────────────────────────────────────────────────────────────────────── │
│  COVERAGE-SUPERVISOR: ● ACTIVE   Workers: 9/9  Tasks: 15                   │
│    ├─ STAMP-CONSTRAINT-ADDER   ● FIXING   Adding SC-VID-001               │
│    ├─ TDG-TEST-GENERATOR       ● GENERATING test/video/stream_test.exs    │
│    └─ ... (7 more)                                                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         OODA METRICS                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  Cycle Time:       8.2s avg (target: <10s)  ✓                              │
│  Decision Rate:    12/min                                                   │
│  Fix Success Rate: 94%                                                      │
│  Loop Incidents:   0 in last 100 cycles  ✓                                 │
│  Hysteresis Active: 2 issues held                                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         RECENT ACTIVITY                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  00:45:28  COMPILE-ERROR-FIXER  Fixed undefined function in user.ex        │
│  00:45:25  CREDO-REFACTOR       Refactored complex function in event.ex    │
│  00:45:22  UNIT-TEST-FIXER      Fixed assertion in user_test.exs           │
│  00:45:18  STAMP-ADDER          Added SC-ACC-015 constraint                │
│  00:45:15  TDG-GENERATOR        Generated video/stream_test.exs            │
└─────────────────────────────────────────────────────────────────────────────┘

────────────────────────────────────────────────────────────────────────────────
  ETA to 100%: ~15 minutes | Next refresh: 30 seconds | [AUTONOMOUS MODE]
────────────────────────────────────────────────────────────────────────────────
```

## 7.2 Progress Persistence

```
────────────────────────────────────────────────────────────────────────────────
                     PROGRESS PERSISTENCE
────────────────────────────────────────────────────────────────────────────────

STORAGE FORMAT: JSON in data/tmp/rca_progress.json

{
  "session_id": "rca-20251230-004500",
  "started_at": "2025-12-30T00:45:00Z",
  "last_update": "2025-12-30T00:45:30Z",
  "goal": {
    "static_coverage": 100,
    "runtime_coverage": 100,
    "formal_coverage": 100
  },
  "current": {
    "static_coverage": 85,
    "runtime_coverage": 70,
    "formal_coverage": 55
  },
  "issues": {
    "total": 43,
    "resolved": 31,
    "in_progress": 8,
    "pending": 4
  },
  "agents": [
    {
      "id": "COMPILE-ERROR-FIXER",
      "status": "FIXING",
      "current_task": {
        "issue_id": "COMPILE-001",
        "file": "lib/indrajaal/accounts/user.ex",
        "line": 42
      },
      "stats": {
        "tasks_completed": 12,
        "tasks_failed": 0,
        "efficiency": 100
      }
    }
  ],
  "checkpoints": [
    {
      "cycle": 142,
      "timestamp": "2025-12-30T00:45:30Z",
      "issues_resolved": 31,
      "issues_remaining": 12
    }
  ]
}

SYNC WITH TODO LIST:
  mix todo.sync --from rca_progress.json

────────────────────────────────────────────────────────────────────────────────
```

---

# EXECUTION COMMANDS

```bash
# Start autonomous RCA system
mix rca.start --autonomous --goal "100% coverage" --agents 25 --supervisors 3

# Monitor dashboard
mix rca.dashboard --refresh 30

# Check progress
mix rca.status

# Sync with todo list
mix todo.sync --from rca

# Emergency halt
mix rca.halt --reason "manual intervention"

# Resume from checkpoint
mix rca.resume --checkpoint latest
```

---

# END OF 5-LEVEL RCA FRAMEWORK
