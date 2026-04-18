# OpenClaw × C3I — FMECA, Criticality & Autonomous System Integration Analysis
**Date**: 2026-04-18 | **Source**: [OpenClaw Deep Dive](https://www.youtube.com/watch?v=sxX8BMscce0)
**Paper**: [Defensible Design for OpenClaw](https://arxiv.org/html/2603.13151v1)

---

## 1. OpenClaw Architecture Summary

OpenClaw is a 247K-star open-source autonomous AI agent framework with:
- **3-Layer Architecture**: Channel (messaging adapters) → Brain (agent runtime) → Body (tools)
- **Gateway**: Single long-lived process handling channels, sessions, agent loop, model calls, tools
- **Skills**: Markdown-defined capabilities in SKILL.md files (workspace-first)
- **4 Security Principles**: Least Privilege, Runtime Isolation, Extension Governance, Auditability
- **Multi-Channel**: 25+ platforms (WhatsApp, Telegram, Slack, Discord, GChat, etc.)

---

## 2. C3I Already Implements OpenClaw Patterns (SC-OPENCLAW-001..004)

| OpenClaw Concept | C3I Implementation | Status |
|-----------------|-------------------|--------|
| **Tools (Motor)** | `mcp_sys`, `mcp_file`, `mcp_web` in Rust | ACTIVE |
| **Skills (Cognitive)** | `.agents/skills/**/SKILL.md` + SkillLoader | ACTIVE |
| **Context & Sessions** | Isolated OTP actors, beam_cache ETS | ACTIVE |
| **Secrets** | Symmetrically encrypted in `Smriti.db` | ACTIVE |
| **Approvals (HITL)** | `sa-plan approvals`, Guardian gate | ACTIVE |
| **Multi-Channel** | Telegram + GChat + WhatsApp gateway | ACTIVE |
| **Continuous Voice** | `intelitor-perception` via Gemini Live | ACTIVE |
| **Workspace-first** | CLAUDE.md + .claude/ as source of truth | ACTIVE |

---

## 3. FMECA — Failure Mode, Effects, and Criticality Analysis

### 3.1 Criticality Matrix (MIL-STD-1629A Method)

Criticality Number: `Cm = Σ(β × α × λp × t)`
- β = conditional probability of failure effect (0-1)
- α = failure mode ratio (fraction of total failures)
- λp = part failure rate
- t = operating time

| # | Component | Failure Mode | Effect | Severity | β | α | Criticality | Mitigation |
|---|-----------|-------------|--------|----------|---|---|-------------|-----------|
| **FM-01** | **NIF Bridge** | Stale data (>60s) | Wrong dashboard display → wrong operator decision | CAT I (Catastrophic) | 0.8 | 0.3 | **0.24** HIGH | GR-055..057 escalation, freshness_monitor 10s |
| **FM-02** | **Smriti.db** | Corruption/lock | All tasks lost, ZK inaccessible | CAT I | 0.2 | 0.1 | 0.02 LOW | SQLite WAL, GCS backup/restore |
| **FM-03** | **Guard Grid** | Rule eval failure | Safety rules don't fire → undetected degradation | CAT II (Critical) | 0.5 | 0.2 | **0.10** MED | 70 rules, salience ordering, RETE-UL fallback |
| **FM-04** | **Request Guard** | False negative | Unhealthy system serves requests | CAT II | 0.3 | 0.15 | 0.045 LOW | Threshold 0.3, module_guard backup |
| **FM-05** | **Request Guard** | False positive | Healthy system blocks ALL requests | CAT III (Marginal) | 0.7 | 0.1 | 0.07 MED | Health >0.3 is lenient threshold |
| **FM-06** | **Embedding Pipeline** | Model load failure | No semantic search → degraded ZK recall | CAT III | 0.4 | 0.2 | 0.08 MED | Ollama HTTP fallback |
| **FM-07** | **Agent Swarm** | API mismatch | Generated code doesn't compile | CAT IV (Negligible) | 0.9 | 0.5 | **0.45** HIGH | Source-first protocol, pre-commit hook |
| **FM-08** | **Hot Reload** | Partial load | Some modules old, some new → state inconsistency | CAT II | 0.3 | 0.1 | 0.03 LOW | MD5 verify, soft_purge, atomic batch |
| **FM-09** | **Gateway** | Broadcast failure | Operator not alerted during incident | CAT II | 0.4 | 0.2 | 0.08 MED | Dual channel (TG+GChat), retry x1 |
| **FM-10** | **Claude Context** | Context overflow | Truncated rules/memory → degraded decisions | CAT III | 0.6 | 0.3 | **0.18** HIGH | Dynamic rule loading (Sprint 3.1) |
| **FM-11** | **Session Continuity** | No last session data | Claude repeats work / misses context | CAT IV | 0.8 | 0.4 | **0.32** HIGH | session-save/summary (Sprint 1, DONE) |
| **FM-12** | **CRDT Merge** | Conflict resolution error | Divergent state across nodes | CAT I | 0.1 | 0.05 | 0.005 LOW | LWW tie-break, OR-Set add-wins |

### 3.2 Criticality Rankings

| Rank | Component | Criticality | Category | Action Required |
|------|-----------|-------------|----------|----------------|
| 1 | **Agent Swarm API Mismatch (FM-07)** | 0.45 | CAT IV but HIGH frequency | Source-first test gen ✓ |
| 2 | **Session Continuity (FM-11)** | 0.32 | CAT IV | session-save DONE ✓ |
| 3 | **NIF Data Staleness (FM-01)** | 0.24 | CAT I | freshness_monitor ✓ |
| 4 | **Context Overflow (FM-10)** | 0.18 | CAT III | Dynamic rule loading PLANNED |
| 5 | **Guard Grid Failure (FM-03)** | 0.10 | CAT II | 70 rules, RETE-UL ✓ |

---

## 4. Utility Analysis — Value of Each Component to Claude

| Component | Utility to Claude | Frequency of Use | Utility Score (0-10) |
|-----------|------------------|-------------------|---------------------|
| **ZK Recall** (UserPromptSubmit) | Prevents reinventing patterns | Every prompt | **10** |
| **gleam build** (PostToolUse) | Catches errors instantly | Every edit | **10** |
| **gleam test** (PostToolUse) | Prevents regressions | Every edit | **9** |
| **Pre-commit hook** | Catches broken commits | Every commit | **9** |
| **session-summary** (SessionStart) | Provides continuity | Every session | **8** |
| **recommend** (SessionStart) | Guides task selection | Every session | **8** |
| **sa-plan-daemon status** | Shows work queue | On demand | **7** |
| **semantic-search** | Finds related holons | Complex tasks | **7** |
| **hot-reload** | Zero-downtime deploy | After changes | **6** |
| **gateway** | Alerts operator | Incidents only | **5** |
| **fitness** | Quality scoring | Before commits | **5** |
| **system/snapshot** | Unified state check | On demand | **7** |
| **claude/session** | Self-awareness | On demand | **6** |

---

## 5. OpenClaw Patterns to Incorporate into C3I

### 5.1 Already Implemented (8 patterns)

| Pattern | OpenClaw | C3I |
|---------|----------|-----|
| Least Privilege | Permission scoping | request_guard + module_guard |
| Runtime Isolation | Session boundaries | OTP actor isolation |
| Extension Governance | Skill vetting | .claude/rules/ allowlist |
| Auditability | Execution traces | Zenoh OTel spans + ZK |
| Tool Sandboxing | Chroot, exec limits | NIF sandbox, bash permissions |
| HITL Approvals | Human gate | Guardian 2oo3 consensus |
| Workspace-first | Directory as config | CLAUDE.md + .claude/ |
| Multi-channel | 25+ platforms | Telegram + GChat + WhatsApp |

### 5.2 Should Incorporate (6 new patterns)

| # | OpenClaw Pattern | What It Does | C3I Integration | Priority |
|---|-----------------|-------------|-----------------|----------|
| **OP-1** | **Adaptive Oversight** | Risk-proportional approval: low-risk auto, high-risk HITL | Extend request_guard with risk scoring per endpoint | P1 |
| **OP-2** | **Extension Manifest Signing** | Cryptographic attestation of skill/plugin provenance | Sign .claude/agents/*.md with ed25519 (already have ed25519-dalek) | P2 |
| **OP-3** | **Context Integrity Protection** | Detect poisoned history/cached state | Verify ZK holon integrity via content hash before injection | P2 |
| **OP-4** | **Permission Mediation** | Translate ambiguous intent → bounded actions | Map natural language to sa-plan-daemon subcommands with scope limits | P2 |
| **OP-5** | **Cron Scheduling** | Time-based autonomous task execution | sa-plan-daemon cron subcommand for 6h OODA cycles | P2 |
| **OP-6** | **Command Queue** | Serialized session processing | BEAM mailbox already provides this via OTP actors | DONE ✓ |

### 5.3 Evolutionary Tasks for OpenClaw Integration

```
OP-1: Add risk-adaptive oversight to request_guard — low-risk endpoints auto-proceed,
      high-risk (L0 constitutional, data mutations) require explicit approval
OP-2: Sign agent/skill manifests with ed25519 — verify provenance before loading
OP-3: Add content hash verification to ZK holon injection in UserPromptSubmit hook
OP-4: Create intent→action mapper in cortex.gleam — constrain Claude actions to
      sa-plan-daemon subcommand vocabulary
OP-5: Add sa-plan-daemon cron subcommand — schedule OODA cycles, embedding refresh,
      ZK maintenance, fitness checks on timer
```

---

## 6. Autonomous Operation Design (from OpenClaw Principles)

### 6.1 Current Autonomy Level (SAE-style)

| Level | Description | C3I Status |
|-------|-------------|------------|
| L0 | No automation | — |
| L1 | Assistance (human drives, AI assists) | — |
| L2 | Partial automation (AI handles routine) | **CURRENT** — hooks auto-build/test |
| L3 | Conditional automation (AI acts, human supervises) | **TARGET** — session-save + recommend |
| L4 | High automation (AI acts autonomously in defined scope) | PLANNED — cron OODA |
| L5 | Full automation (AI handles all scenarios) | NOT PLANNED — human always in loop for L0 |

### 6.2 Safety Guarantees for Autonomous Operation

From the Defensible Design paper, autonomous agents need:

1. **Testable** — Can verify behavior before deployment → gleam test (6403 tests) ✓
2. **Bounded** — Actions constrained to defined scope → request_guard + 70 rules ✓
3. **Governable** — Human can override at any time → Guardian 2oo3 + emergency stop ✓
4. **Auditable** — All actions traceable → Zenoh OTel + ZK + session-save ✓

### 6.3 What C3I Needs for L3 Autonomy

| Requirement | Current | Needed |
|-------------|---------|--------|
| Proactive task execution | Manual "continue" | Cron-triggered OODA |
| Self-monitoring | On-demand fitness | Continuous health_derivative |
| Error recovery | Manual rollback | Auto-rollback on fitness regression |
| Learning from failures | Manual ZK ingest | Auto anti-pattern detection |
| Context efficiency | Load all 84 rules | Dynamic rule selection |

---

## 7. STAMP-STPA for Claude as Controller

### 7.1 Claude as STAMP Controller

```
CONTROLLED PROCESS: C3I cepaf_gleam (344 modules)
CONTROLLER: Claude (via hooks + tools)
ACTUATORS: Write/Edit tools, sa-plan-daemon CLI, git
SENSORS: gleam build, gleam test, ZK recall, /health API

UNSAFE CONTROL ACTIONS (UCAs):
  UCA-1: Claude edits L0 module without Guardian approval
  UCA-2: Claude commits code that doesn't build
  UCA-3: Claude ignores ZK anti-pattern warning
  UCA-4: Claude spawns agents that conflict on same files
  UCA-5: Claude pushes to remote without explicit approval
  UCA-6: Claude deletes files without backup

SAFETY CONSTRAINTS:
  SC-1: Pre-commit hook blocks UCA-2
  SC-2: SC-ZK-IMP-003 mandates reading anti-patterns (UCA-3)
  SC-3: AOR-DELETE-001 requires backup before deletion (UCA-6)
  SC-4: Gita protocol: ask for L0/delete/push (UCA-1, UCA-5)
```

### 7.2 Loss Scenarios

| Loss | Cause | Prevention |
|------|-------|-----------|
| **L1: Data loss** | Unintended file deletion | SC-DELETE-001, git stash |
| **L2: Service outage** | Bad code deployed | Pre-commit hook, hot-reload rollback |
| **L3: Knowledge corruption** | Wrong ZK ingest | Content hash verification (OP-3) |
| **L4: Operator confusion** | Stale dashboard data | SC-TRUTH-001, freshness_monitor |
| **L5: Security breach** | Tool injection | Least privilege, sandbox (OP-1) |

---

## 8. Metrics for Autonomous Operation

| Category | Metric | Current | Target | Source |
|----------|--------|---------|--------|--------|
| **Safety** | UCA prevention rate | 100% | 100% | Pre-commit + rules |
| **Reliability** | Test pass rate | 100% | 100% | gleam test |
| **Efficiency** | OODA cycle time | 10s | <30s | guard_grid_actor |
| **Learning** | ZK citation rate | ~50% | >90% | claude_metrics |
| **Autonomy** | Tasks completed per session | ~20 | >10 | session-save |
| **Recovery** | MTTR (mean time to recover) | ~60s | <120s | hot-reload + rollback |
| **Awareness** | Effectiveness score | 0.90 | >0.85 | claude_metrics |

---

## 9. Conclusion

The OpenClaw framework validates C3I's existing architecture — our system already implements 8 of 14 key patterns. The 6 remaining patterns (adaptive oversight, manifest signing, context integrity, permission mediation, cron scheduling, command queue) are mapped to evolutionary tasks.

The FMECA analysis reveals FM-07 (Agent API mismatch, Cm=0.45) as the highest criticality — already mitigated by source-first test generation. FM-10 (Context overflow, Cm=0.18) is the next priority — addressed by Sprint 3.1 dynamic rule loading.

For autonomous operation, C3I is at **Level 2** (partial automation) with clear path to **Level 3** (conditional automation) via cron-triggered OODA, auto-rollback, and dynamic rule selection. Level 5 (full automation) is explicitly NOT targeted — human remains in the loop for L0 constitutional decisions per the Guardian protocol.

Sources:
- [Principles for Autonomous System Design: OpenClaw Deep Dive](https://www.youtube.com/watch?v=sxX8BMscce0)
- [Defensible Design for OpenClaw](https://arxiv.org/html/2603.13151v1)
- [OpenClaw Architecture Guide](https://docs.openclaw.ai/)
- [The OpenClaw Design Patterns](https://kenhuangus.substack.com/p/the-openclaw-design-patternspart)
