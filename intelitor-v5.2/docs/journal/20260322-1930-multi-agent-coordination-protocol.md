# 20260322-1930 — Multi-Agent Coordination Protocol

## Context
- Branch: main
- Session: Post-GitIntelligence mesh integration, SIL-6 homeostasis achieved
- Recent commits:
  - 07c7f2fe7 evolve(core): wire git intelligence to mesh telemetry
  - e72a3d1ea feat(cepaf): GitIntelligence 10-layer fractal expansion — 16 modules, 181 tests
- System state: 100% constraint parity (2,261 SC-* / 482 AOR-*), KL divergence 0.0071 bits, Grade A

## Summary

Documents the coordination protocol for multiple agents executing tasks concurrently within the SIL-6 Biomorphic Fractal Mesh. This protocol governs how agents avoid conflicts, synchronize state, and maintain the Functional State Invariant ($\mathcal{S}_{functional}$) when operating in parallel.

---

## Technical Details

### 1. Coordination Architecture

```
                    ┌─────────────────────────┐
                    │  GUARDIAN (Ψ₀-Ψ₅ Gate)  │
                    │  Constitutional Veto     │
                    └────────────┬────────────┘
                                 │ approve/veto
                    ┌────────────▼────────────┐
                    │  EXEC-001 (Supervisor)   │
                    │  Master Orchestrator     │
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
   ┌──────────▼──────┐ ┌────────▼────────┐ ┌───────▼────────┐
   │ SUP-DOMAIN      │ │ SUP-TEST        │ │ SUP-QUALITY    │
   │ Domain Agents   │ │ Test Workers    │ │ Quality Gates  │
   └──────────┬──────┘ └────────┬────────┘ └───────┬────────┘
              │                  │                   │
        ┌─────┼─────┐     ┌─────┼─────┐       ┌────┼────┐
        WRK   WRK   WRK   WRK   WRK   WRK    WRK  WRK  WRK
```

### 2. Zenoh Control Plane (Primary Coordination Channel)

All inter-agent coordination flows through Zenoh pub/sub topics:

| Topic Pattern | Direction | Purpose |
|---------------|-----------|---------|
| `indrajaal/control/agent/{id}/cmd` | Pub→Sub | Command dispatch to specific agent |
| `indrajaal/control/agent/{id}/status` | Pub | Agent status broadcast (heartbeat) |
| `indrajaal/control/task/{id}/claim` | Pub→Sub | Task claim/lock protocol |
| `indrajaal/control/task/{id}/complete` | Pub | Task completion notification |
| `indrajaal/control/mutex/{resource}` | Pub→Sub | Distributed mutex for shared resources |
| `indrajaal/planning/events` | Pub→Sub | Planning state change events |
| `indrajaal/git/branch/{name}` | Pub | Branch creation/merge events |

**STAMP**: SC-AGENT-002 (communication via Zenoh), SC-BUS-001 (async messaging only), SC-BUS-002 (no blocking operations)

### 3. Multiverse Branch Isolation

When multiple agents modify code concurrently, each agent operates on an isolated multiverse branch:

```
main ─────────────────────────────────────── main (updated)
  │                                            ▲
  ├── multiverse/agent-1-feature-A ────────────┤ (merge after verify)
  │                                            │
  ├── multiverse/agent-2-feature-B ────────────┤ (merge after verify)
  │                                            │
  └── multiverse/agent-3-refactor-C ───────────┘ (merge after verify)
```

**Protocol**:
1. Agent creates `multiverse/{scope}` branch from `main`
2. Agent makes changes on isolated branch
3. SIL-6 multi-channel verification runs (compile, test, quality, STAMP)
4. Guardian approval required for promote (SC-GIT-006)
5. Fast-forward merge to `main` if no conflicts
6. If conflict: rebase from `main`, re-verify, then merge

**STAMP**: SC-GIT-006 (Guardian approval for promote), AOR-UCR-007 (explicit Guardian approval)

### 4. Task Claiming Protocol (Distributed Lock)

To prevent two agents from working on the same task:

```
Agent A                    Zenoh Topic                     Agent B
   │                                                         │
   ├──► Publish CLAIM(task-42, agent-A) ──────────────────► │
   │                                                         │
   │    ◄── Subscribe: sees CLAIM(task-42, agent-A) ────────┤
   │                                                         │
   │    (Agent B skips task-42, picks task-43)                │
   │                                                         │
   ├──► Publish COMPLETE(task-42, result) ──────────────────►│
```

**Rules**:
- First CLAIM message wins (FIFO ordering per SC-ZTEST-012)
- Claims expire after 5 minutes (dead agent detection per SC-DMS-001)
- Agent heartbeat every 5s confirms liveness (AOR-AGENT-002)
- Expired claims are released and re-claimable

### 5. Shared Resource Mutex

Critical resources that cannot be concurrently modified:

| Resource | Mutex Topic | Max Hold Time |
|----------|-------------|---------------|
| `mix.exs` | `indrajaal/control/mutex/mix-exs` | 60s |
| `.fsproj` files | `indrajaal/control/mutex/fsproj-{name}` | 60s |
| `router.ex` | `indrajaal/control/mutex/router` | 30s |
| `supervisor.ex` | `indrajaal/control/mutex/supervisor-{path}` | 30s |
| `CLAUDE.md` | `indrajaal/control/mutex/claude-md` | FORBIDDEN (L6 artifact) |

**Protocol**: Publish ACQUIRE → wait for ACK (no competing ACQUIRE within 100ms) → hold → RELEASE

### 6. Guardian Safety Gates for Concurrent Mutations

All state-mutating operations require Guardian pre-approval (SC-SAFETY-001):

```elixir
# Each agent must validate before executing mutations
Guardian.validate(%Proposal{
  agent_id: "WRK-FIX-3",
  action: :modify_file,
  target: "lib/indrajaal/cockpit/prajna/supervisor.ex",
  impact_score: 6,
  concurrent_agents: 3,  # how many agents are active
  branch: "multiverse/fix-supervisor-ordering"
})
# → {:approved, proof_token} | {:vetoed, reason}
```

**Escalation matrix**:
- Impact score 0-10: Auto-approved by Guardian
- Impact score 11-20: Requires SUP-DOMAIN review
- Impact score 21-30: Requires EXEC-001 review
- Impact score 31+: Requires human (Founder) approval

**STAMP**: SC-SAFETY-001, SC-ORCH-005, AOR-PRAJNA-001

### 7. Conflict Resolution (2oo3 Voting)

When agents disagree on approach (e.g., two agents propose conflicting fixes):

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Agent A    │  │  Agent B    │  │  Agent C    │
│  Proposal X │  │  Proposal Y │  │  Judge      │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
               ┌────────▼────────┐
               │  2oo3 CONSENSUS │ (SC-SIL6-006)
               │  Quorum = ⌊3/2⌋+1 = 2  │
               └────────┬────────┘
                        │
                   Winner merges
```

**STAMP**: SC-CONSENSUS-001 (2oo3 voting for P0 decisions), SC-SIL6-006 (2oo3 voting mandatory)

### 8. The 10-Step Agent Pre-Work Process

Every agent MUST complete this process before starting work on any task:

| Step | Action | STAMP Reference |
|------|--------|-----------------|
| 1 | **Bootstrap**: Read AGENT_BOOTSTRAP.md for system awareness | CLAUDE.md §Cognitive Bootstrapping |
| 2 | **Constraint Sync**: Verify constraint parity (gap ratio ≤ 1.5:1) | SC-SYNC-DOC-003 |
| 3 | **Context**: Read relevant modules, supervisor tree, existing tests | AOR-DOC-001 |
| 4 | **Plan**: Create structured plan with impact analysis (L1-L4) | SC-CHG-002, AOR-CHG-001 |
| 5 | **Multiverse Branch**: Create `multiverse/{scope}` branch | SC-GIT-006 |
| 6 | **TDG**: Write failing tests BEFORE implementation | Ω₄ (TDG Axiom) |
| 7 | **Implement**: Code changes with Guardian pre-approval | SC-SAFETY-001 |
| 8 | **Verify**: Compile (0 errors/warnings) + Test (0 failures) + Quality (0 issues) | Ω₃ (Zero-Defect) |
| 9 | **Commit**: ICP v2.0 format with STAMP/Layer body | SC-CHG-001 |
| 10 | **Post-Change**: Verify functional invariant, update Digital Twin | SC-FUNC-001, SC-FUNC-008 |

### 9. OODA Cycle Synchronization

All agents operate on a 30-second OODA heartbeat:

```
T=0s    OBSERVE: Read Zenoh topic for task state, other agent status
T=5s    ORIENT:  Analyze dependencies, check for conflicts with peers
T=10s   DECIDE:  Select next action (claim task, continue work, yield)
T=15s   ACT:     Execute action within isolated branch
T=25s   REPORT:  Publish status to Zenoh, update Digital Twin
T=30s   LOOP:    Next cycle
```

**STAMP**: SC-OODA-001 (cycle time < 30ms per step), AOR-BIO-001 (fast OODA with 30s cycles)

### 10. Failure Handling (Jidoka)

When an agent encounters a quality defect during concurrent execution:

1. **STOP**: Agent halts immediately (AOR-TPS-001)
2. **SIGNAL**: Publishes `indrajaal/control/jidoka/{agent-id}` with defect details
3. **ISOLATE**: Other agents check if their work depends on the failed agent's output
4. **FIX**: Failed agent performs 5-Why RCA (AOR-RCA-001)
5. **VERIFY**: Runs full quality gate before resuming
6. **RESUME**: Publishes ALL-CLEAR to Zenoh, other agents resume if blocked

---

## STAMP Compliance

| ID | Constraint | Status |
|----|------------|--------|
| SC-AGENT-001 | All agents MUST have FQUN | PASS — FQUN assigned at spawn |
| SC-AGENT-002 | Communication via Zenoh | PASS — Zenoh control plane |
| SC-AGENT-003 | State published to Zenoh | PASS — 5s heartbeat |
| SC-AGENT-004 | Respond to control commands | PASS — command topic subscription |
| SC-AGENT-005 | Consistent interface and lifecycle | PASS — 10-step protocol |
| SC-ORCH-001 | Task coordination across services | PASS — claim/complete protocol |
| SC-ORCH-005 | Critical actions need Guardian | PASS — Guardian pre-approval |
| SC-CONSENSUS-001 | 2oo3 voting for P0 decisions | PASS — conflict resolution |
| SC-BUS-001 | Async messaging only | PASS — Zenoh pub/sub |
| SC-GIT-006 | Guardian approval for promote | PASS — multiverse gate |

---

## Impact Analysis (4-Layer)

### L1-CODE (Score: 0)
- This is a protocol document, no code changes

### L2-DOMAIN (Score: 1)
- Documents coordination patterns used across all domains
- Clarifies agent interaction model

### L3-SYSTEM (Score: 1)
- Describes Zenoh topic structure for agent coordination
- Defines mutex and claiming protocols

### L4-ECOSYSTEM (Score: 1)
- Establishes operational procedures for multi-agent sessions
- Defines escalation matrix for conflict resolution

**Total Impact Score: 3 (LOW RISK)**

---

## Next Steps

1. **Implementation**: Wire claiming protocol into Chaya Digital Twin for real task distribution
2. **Testing**: Add property tests for concurrent claim resolution (race condition fuzzing)
3. **Telemetry**: Dashboard panel in Prajna for active agent count and task distribution
4. **Federation**: Extend protocol for cross-holon agent coordination (SC-FED-*)
