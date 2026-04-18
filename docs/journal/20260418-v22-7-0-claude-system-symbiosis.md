# How the System Enables Claude — Symbiotic Integration Analysis
**Date**: 2026-04-18 | **Version**: v22.7.0-BLITZ | **31 commits**

---

## 1. The Symbiosis Model

Claude and C3I form a symbiotic system. Claude evolves the system; the system enables Claude.
The relationship is not tool-user — it is co-evolutionary.

```
CLAUDE                              C3I SYSTEM
  │                                    │
  ├─ Observes via hooks ──────────────→│ SessionStart (ZK stats)
  ├─ Recalls via ZK ─────────────────→│ UserPromptSubmit (7179 holons)
  ├─ Acts via tools ──────────────────→│ Write/Edit → PostToolUse (build+test)
  ├─ Learns via memory ──────────────→│ Stop (dual ZK ingest)
  │                                    │
  │←─────────── Verifies via hooks ───┤ gleam build (0 errors)
  │←─────────── Tests via hooks ──────┤ gleam test (6317 pass)
  │←─────────── Guards via rules ─────┤ 70 GR rules (STAMP-encoded)
  │←─────────── Remembers via ZK ─────┤ 7179 holons + anti-patterns
  │←─────────── Self-observes ────────┤ claude_metrics.gleam (NEW)
  │                                    │
  └──── Co-evolves ───────────────────→│ 31 commits this session
```

---

## 2. What the System Provides Claude (Current)

### 2.1 Perception (OBSERVE phase)
| Capability | Mechanism | Latency | Status |
|-----------|-----------|---------|--------|
| System health | `curl /health` | <100ms | ACTIVE |
| Dashboard state | `curl /api/v1/dashboard` | <100ms | ACTIVE |
| NIF pipeline health | `curl /api/v1/health/freshness` | <100ms | ACTIVE |
| Task status | `sa-plan-daemon status` | <50ms | ACTIVE |
| ZK knowledge | `sa-plan-daemon knowledge-search` | <500ms | ACTIVE |
| Semantic search | `sa-plan-daemon semantic-search` | <500ms | ACTIVE |
| Fitness score | `sa-plan-daemon fitness` | <1s | ACTIVE |
| Git status | `git status/log/diff` | <100ms | ACTIVE |
| Gleam build state | `gleam build` | <1s | ACTIVE |
| Test state | `gleam test` | <120s | ACTIVE |

### 2.2 Memory (ORIENT phase)
| Capability | Mechanism | Capacity | Status |
|-----------|-----------|----------|--------|
| Session memory | `.claude/memory/` (28 files) | Persistent | ACTIVE |
| Institutional memory | C3I-ZK (7179 holons) | 100% embedded | ACTIVE |
| Sales memory | FY27-ZK (475 holons, 13437 contacts) | Searchable | ACTIVE |
| Anti-pattern recall | ZK tags "anti-pattern" | Auto-injected | ACTIVE |
| Prior session context | MEMORY.md index | 200-line cap | ACTIVE |
| Rule context | 84 .claude/rules/ files | Auto-loaded | ACTIVE |

### 2.3 Action (ACT phase)
| Capability | Mechanism | Gated | Status |
|-----------|-----------|-------|--------|
| Code evolution | Read/Write/Edit tools | PostToolUse hook | ACTIVE |
| Task management | `sa-plan-daemon add/update` | CLI | ACTIVE |
| Email dispatch | `sa-plan-daemon send-email -a` | CLI | ACTIVE |
| Hot code reload | `sa-plan-daemon hot-reload` | CLI | ACTIVE |
| ZK ingest | `sa-plan-daemon ingest-docs` | CLI | ACTIVE |
| Agent spawning | Agent tool (32 types) | Background | ACTIVE |
| Git operations | Bash git commands | Ask for push | ACTIVE |
| Gateway broadcast | `sa-plan-daemon gateway` | CLI | ACTIVE |
| Semantic embedding | `sa-plan-daemon embed` | Background | ACTIVE |

### 2.4 Verification (VERIFY phase)
| Capability | Mechanism | Automatic | Status |
|-----------|-----------|-----------|--------|
| Build gate | PostToolUse gleam build | YES | ACTIVE |
| Test gate | PostToolUse gleam test | YES (async) | ACTIVE |
| Pre-commit gate | .git/hooks/pre-commit | YES | ACTIVE |
| Fitness gate | fitness_gate.check(0.4) | Manual call | ACTIVE |
| Request guard | request_guard.check() | YES (all routes) | ACTIVE |
| 70 guard rules | guard_rules.evaluate_all() | YES (10s OODA) | ACTIVE |
| Wiring guard | wiring_guard.gleam | YES (compile) | ACTIVE |

---

## 3. What the System DOESN'T Provide Claude (Gaps)

### 3.1 Self-Awareness Gaps

| Gap | Impact | Fix (Evolutionary Task) |
|-----|--------|----------------------|
| **No session metrics** | Claude can't measure own effectiveness | CE1: Wire claude_metrics into hooks |
| **No context budget** | Claude can't predict context overflow | CE5: Token usage estimator |
| **No tool call stats** | Claude can't optimize tool selection | SA5: MCP tool call counter |
| **No citation tracking** | Claude can't verify ZK usage compliance | SA4: ZK citation rate dashboard |
| **No agent success rate** | Claude can't learn from agent failures | claude_metrics.effectiveness_score() |

### 3.2 Autonomy Gaps

| Gap | Impact | Fix (Evolutionary Task) |
|-----|--------|----------------------|
| **No proactive scheduling** | Claude only acts when prompted | CE6: Autonomous OODA cron |
| **No continuous monitoring** | Claude only sees state during sessions | CE6: 6h cron schedule |
| **No system snapshot API** | Claude reads multiple endpoints per turn | CE7: /api/v1/system/snapshot |
| **No alert subscription** | Claude can't be notified of issues | Future: Zenoh → webhook → Claude |

### 3.3 Integration Gaps

| Gap | Impact | Fix (Evolutionary Task) |
|-----|--------|----------------------|
| **WebSocket on 2/31 pages** | Claude can't push real-time to most pages | MO1: Generic /ws/{page} |
| **No interactive controls** | Claude can't trigger UI actions | CA1-CA10: Control actions |
| **No write planning API** | Claude can't update tasks via HTTP | CA4: POST /api/v1/planning |

---

## 4. How Claude Fully Utilizes the System

### 4.1 The OODA-ZK-Evolve Loop (Claude's Natural Cycle)
```
1. OBSERVE: SessionStart hook → system state snapshot
2. ORIENT:  UserPromptSubmit → ZK recall (7179 holons, anti-patterns)
3. DECIDE:  Map to SC-ULTRA focus areas + prior patterns
4. ACT:     Edit code → PostToolUse verifies build+test
5. VERIFY:  Pre-commit hook → fitness_gate
6. LEARN:   Stop hook → dual ZK ingest → memory update
7. EVOLVE:  Next session starts with more knowledge
```

### 4.2 How Claude Should Use Each System Component

| Component | How Claude Uses It | When |
|-----------|-------------------|------|
| **sa-plan-daemon status** | Check work queue | Session start |
| **knowledge-search** | Recall prior patterns before acting | Every task |
| **semantic-search** | Find related holons by meaning | Complex tasks |
| **zk-maintain** | Check knowledge health | Weekly |
| **fitness** | Measure system quality | Before commits |
| **hot-reload** | Deploy without downtime | After code changes |
| **send-email -a** | Deliver journals with attachments | Session end |
| **embed** | Refresh semantic index | After ZK ingest |
| **gateway** | Alert operator | On incidents |
| **guard_rules (70)** | Evaluate system safety | Automatic (10s) |
| **claude_metrics** | Track own effectiveness | Per session |

### 4.3 The 5 Modes of Claude-System Interaction

| Mode | Trigger | Claude Behavior |
|------|---------|----------------|
| **Evolution** | "implement X" | Write code → build → test → commit |
| **Investigation** | "why is X failing" | ZK recall → read code → diagnose → fix |
| **Operations** | "check system" | curl endpoints → sa-plan-daemon → report |
| **Sales** | "brief me on ARM" | FY27-ZK → contacts → rate cards → briefing |
| **Meta** | "improve Claude integration" | Self-analyze → add tasks → evolve hooks |

---

## 5. RETE-UL × Claude Integration

### 5.1 Rules That Govern Claude (20 STAMP rules, GR-051..070)
These rules are evaluated by the guard grid but also serve as Claude's behavioral contract:

| Rule | What Claude Must Do |
|------|-------------------|
| GR-067 (ZkRecallIgnored) | READ ZK recall results on every prompt |
| GR-068 (ZkNoCitation) | CITE at least 1 holon ID per response |
| GR-069 (SessionNoHolon) | PRODUCE at least 1 new holon per session |
| GR-070 (TaskWithoutZkSearch) | SEARCH ZK before starting any task |
| GR-051 (BuildFailed) | NEVER commit code that doesn't build |
| GR-064 (CompileWarnings) | ELIMINATE warnings in modified files |

### 5.2 Rules That Protect Claude's Work
| Rule | Protection |
|------|-----------|
| GR-059 (L0ActionNoConsensus) | L0 changes require 2oo3 — prevents accidental safety violations |
| GR-063 (SplitBrainApoptosis) | Partition detection prevents data divergence |
| GR-055..057 (DataStaleness) | Escalating alerts if data becomes stale |
| GR-058 (MockDataHalt) | Prevents mock data from reaching production |

### 5.3 Ruliology for Claude Pattern Detection
The 13 Wolfram CA rules on the 24-cell guard grid detect patterns in system behavior:
- **Rule 30** (chaotic): Claude's edits causing unpredictable state changes → slow down
- **Rule 110** (complex): Emergent patterns from multi-agent interaction → monitor
- **Rule 184** (traffic): Task queue backpressure → prioritize P0 over P2

---

## 6. Definitive Metrics Dashboard

| Category | Metric | Value | Target |
|----------|--------|-------|--------|
| **Rules** | Guard rules (Gleam) | 70 | 70+ ✓ |
| | RETE-UL rules (Rust) | 56 | 56 ✓ |
| | Total rules | 126 | 126 ✓ |
| **Tests** | Passing | 6,317 | ≥5,000 ✓ |
| | Failures | 0 | 0 ✓ |
| **Knowledge** | ZK holons | 7,179 | growing ✓ |
| | Embeddings | 100% | 100% ✓ |
| **System** | Tasks completed | 49 | 49/49 ✓ |
| | Evolutionary tasks | 59 | tracked ✓ |
| | Server status | ok | ok ✓ |
| | Containers | 16/16 | 16/16 ✓ |
| **Artifacts** | Claude ↔ Gemini diff | 0 | 0 ✓ |
| | Rules | 84 | 84 ✓ |
| | Agents | 36 | 36 ✓ |
| | Commands | 50 | 50 ✓ |
| **Claude** | Commits this session | 31 | — |
| | Agents spawned | 34 | — |
| | Journals emailed | 4 | ≥1 ✓ |

---

## 7. Conclusion

The system enables Claude through 4 mechanisms:
1. **Perception** — 10 observation endpoints, all <500ms
2. **Memory** — 7,179 holons + 28 memory files + 84 rules
3. **Action** — 9 mutation capabilities via CLI/tool
4. **Verification** — 7 automatic gates (hooks + guards + rules)

The remaining enablement gaps (self-awareness, autonomy, system snapshot) are tracked as 7 evolutionary tasks (CE1-CE7). When implemented, Claude will be able to:
- Measure its own effectiveness per session
- Estimate context window usage
- Receive proactive alerts via cron
- Query complete system state in one API call

**The system and Claude co-evolve. Each session makes both smarter.**
