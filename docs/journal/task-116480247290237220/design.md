# Marionette MCP — Design Document & ADRs

> Task `116480247290237220`. Captures the architectural decisions of pass 1+2+3, alternatives considered, and rationale.

## 1. High-level design

```
Operator/Agent → MCP stdio → marionette_mcp server → VM Service → MarionetteBinding → Flutter widget tree
                    │                                       ↑
                    │                                       │
                    └──────── PostToolUse hook ─────────────┴──→ Zenoh ──→ rule_engine + dashboard + KPI
```

Three layers of indirection:
1. **MCP transport** — stdio JSON-RPC owned by the agent harness.
2. **VM Service** — Dart's existing introspection protocol, extended by Marionette.
3. **Widget binding** — replaces `WidgetsFlutterBinding`; debug-mode only.

## 2. Architecture Decision Records

### ADR-001 · Vendor upstream rather than depend on pub.dev

- **Status**: Accepted.
- **Context**: We need predictable governance + the ability to patch quickly.
- **Decision**: `git clone --depth 1` into `sub-projects/marionette_mcp/`. Pin Flutter app deps to `^0.5.0` from pub.dev for production; the local clone is for inspection and emergency patches.
- **Consequences**: ~5 MB on disk, periodic `git pull` needed, no fork burden until we change code.

### ADR-002 · Marionette as a *peer* of Patrol, not a sub-mode

- **Status**: Accepted.
- **Context**: Existing `patrol-mcp-zenoh.md` rule listed only 8 Marionette tools. The 0.5.0 release added 8 more.
- **Alternatives considered**:
  - A. Extend `patrol-mcp-zenoh.md` to cover all 16. *Rejected*: 800+ LOC growth, single rule becomes unmanageable.
  - B. Add a Marionette-only rule and keep Patrol rule as-is. **Chosen**: clear separation, cross-references.
  - C. Replace Patrol rule entirely. *Rejected*: high blast-radius, no benefit.
- **Consequences**: Two rules, two agents, two skills — but each is focused (≤ 250 LOC).

### ADR-003 · Discovery-first via stateless hook + flag-file

- **Status**: Accepted.
- **Context**: SC-MARIONETTE-003 must be enforced mechanically; relying on agent self-discipline is insufficient (RPN 216).
- **Alternatives**:
  - A. Database-backed session table. *Rejected*: too heavy, latency in hot path.
  - B. In-memory daemon. *Rejected*: requires a long-running process; couples lifecycle.
  - C. **Per-session flag-file at `/tmp/marionette-discovery-${SESSION}.flag`. Chosen.**
- **Consequences**: Stateless hook command, ~10 ms overhead, survives `hot_reload`, naturally cleared on `disconnect`.

### ADR-004 · Allium as the formal source of truth

- **Status**: Accepted.
- **Context**: Need machine-checkable invariants; existing repo already uses Allium for ignition/voice/UI.
- **Alternatives**:
  - A. TLA+ only. *Rejected*: no semantic match for *contracts* and *surfaces*.
  - B. Allium + TLA+ stub for select invariants. **Chosen**: Allium for completeness, TLA+ for concurrency proofs (A2/A8).
- **Consequences**: Two formal artefacts; `weed` tool detects drift.

### ADR-005 · Reverse Zenoh advisory channel rather than agent polling

- **Status**: Accepted.
- **Context**: RETE-UL rules need to feed back to the agent without polling.
- **Alternatives**:
  - A. Agent polls `rule_engine` HTTP endpoint. *Rejected*: introduces ad-hoc HTTP.
  - B. **Rule engine publishes on `indrajaal/l5/test/marionette/advisory/<rule>`. Chosen.**
- **Consequences**: One-way pub/sub, ≤ 100 ms latency, fits SC-ZMOF-001.

### ADR-006 · `marionette_cli` for CI, not raw VM Service

- **Status**: Accepted (target state — A4).
- **Context**: CI must publish identical envelopes; bypassing the bridge breaks SC-MARIONETTE-008.
- **Decision**: All CI runs go through `marionette_cli mcp` mode or per-command sub-commands; `tool/patrol-zenoh-bridge.sh` wraps every invocation.
- **Consequences**: One vocabulary across local + CI; no parallel telemetry path to maintain.

### ADR-007 · PNG render via chromium-headless rather than rsvg-convert

- **Status**: Accepted.
- **Context**: `rsvg-convert` not installed; `chromium` is available.
- **Decision**: Use chromium-headless `--screenshot` flag for the 6 hand-coded SVGs; use `dot -Tpng` directly for the 4 Graphviz diagrams (DPI 140).
- **Consequences**: 1400×900 fixed viewport for the hand SVGs (acceptable for embedding); Graphviz natively renders PNGs.

### ADR-008 · sa-plan task per gap rather than monolithic backlog file

- **Status**: Accepted.
- **Context**: Operator wanted "tasks and jobs … via sa-plan scheduler".
- **Decision**: Each A-/B-gap becomes a separate `sa-plan add` task with priority. Scheduler `zk_maintain` + `embed_refresh` + `health_check` jobs handle the post-ingest housekeeping.
- **Consequences**: 10 tasks created; integrates with `recommend` command for next-task hinting.

## 3. Component diagram

See `diagrams/01-architecture.png` for the rendered view. Component boundaries:

```
┌─ Operator surface ────────────────────────────────┐
│ - /marionette-explore (skill)                     │
│ - dashboard tile (planned, B1)                    │
└───────────────────────────────────────────────────┘
┌─ Agent surface ───────────────────────────────────┐
│ - marionette-explorer (this pass)                 │
│ - patrol-test-agent (existing, complementary)     │
└───────────────────────────────────────────────────┘
┌─ Governance surface ──────────────────────────────┐
│ - .claude/rules/marionette-mcp-flutter-testing.md │
│ - .claude/agents/marionette-explorer.md           │
│ - .claude/commands/marionette-explore.md          │
│ - specs/allium/marionette_mcp.allium              │
│ - .claude/settings.json hooks                     │
└───────────────────────────────────────────────────┘
┌─ Transport ───────────────────────────────────────┐
│ - marionette_mcp (stdio + SSE)                    │
│ - marionette_cli (shell, CI)                      │
│ - Zenoh router (TCP 7447)                         │
└───────────────────────────────────────────────────┘
┌─ Subject ─────────────────────────────────────────┐
│ - marionette_flutter binding (in app)             │
│ - VM Service extensions (16 tools)                │
└───────────────────────────────────────────────────┘
┌─ Observers ───────────────────────────────────────┐
│ - rule_engine.rs (10 GRL rules — pending dispatch)│
│ - ruliology.rs (4 classifiers)                    │
│ - FMEA aggregator                                 │
│ - smriti.db session_metrics                       │
└───────────────────────────────────────────────────┘
```

## 4. State design

Two state tracks:

1. **Per-session ephemeral**: `MarionetteSession` (Allium §4) — flag-file in `/tmp`, cleared on `disconnect`.
2. **Per-test durable**: `TestRun` — file tree under `docs/cache/marionette/<run_id>/` + Smriti row.

## 5. Failure design

- **Fail-fast** on any rule with severity CRITICAL (release-mode-block, missing evidence on failure, gesture without discovery).
- **Fail-soft** on advisories (selector drift, log-collector missing).
- **Force-capture** branch in control flow (`any → capturing → disconnecting`) ensures Allium `EvidenceForFailure` invariant cannot be violated even if the agent crashes.

## 6. Concurrency model

- One `MarionetteSession` per Flutter process (Allium `SingletonBinding`).
- Multiple `TestRun`s within a session, sequential (no parallel runs against the same VM).
- Multiple agents may attach to *different* Flutter processes simultaneously (e.g. sender + receiver in cross-app tests, see gap-analysis D2).

## 7. Future-proofing

- Allium `weed` (P8.5) keeps spec ↔ code drift = 0.
- `version.g.dart` parity check (SC-MARIONETTE-011) protects against pubspec/generated drift.
- Reverse advisory channel allows RETE-UL rules to be added without modifying the agent.
- `call_custom_extension` allows app-specific test hooks without spec changes.
