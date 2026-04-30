# C3I Cross-Pass Ontology — Passes 1-20 Knowledge Graph
[Tailscale]: https://vm-1.tail55d152.ts.net:8443/task-id/116480247290237220/task-116480247290237220/c3i-cross-pass-ontology.md

**Version**: 1.0 (Pass 21 baseline)
**Scope**: Marionette MCP arc Passes 1-20 + scheduler / sa-plan-daemon work
**ZK citations**: [zk-bb4de67d97f807ac], [zk-c14e1d23afff486c], [zk-d1b0c1494], [zk-d88a58e54ef8a08f]
**Companion**: dynamic counterpart at `cpig-matrix.json` (Passes 13-15)
**Diagram**: `docs/journal/task-116480247290237220/diagrams/g35-c3i-cross-pass-ontology.{dot,svg,png}`

---

## 1. Purpose

This document captures the formal **knowledge graph** of entities, relations, and
invariants accumulated across **Passes 1-20** of the C3I evolution arc — covering
the Marionette MCP integration, the sa-plan-daemon scheduler hardening, the CPIG
five-gate framework, and the cross-subsystem rollout.

It is the **canonical static schema** of how C3I evolves. Any future pass (21+)
or any new subsystem onboarded to the mesh MUST plug into the same ontology so
that the meta-pattern compounds rather than fragments. This is the
**meta-meta invariant**: every subsystem rollout follows the same five CPIG gates
(formal_spec, wiring_guard, sa_plan, zk, email) — see INV-7 below.

The ontology is intentionally minimal (12 entity types, 15 relations,
7 invariants) so it can be fully held in working memory by any agent — Claude,
Gemini, Pi, or human operator.

---

## 2. Top-Level Entity Types

### 2.1 Pass
A single development cycle, numbered 1..N, classified A-H by deliverable shape.

| Attribute | Type | Description |
|---|---|---|
| number | Int | 1..20 in this baseline |
| class | Char | A=spec, B=impl, C=test, D=closure, E=RCA, F=enforcement, G=federation, H=ontology |
| date | ISO-8601 | Calendar day of execution |
| scope | Text | One-line summary |
| deliverables | List<Entity> | FormalSpec, WiringGuard, Diagram, JournalEntry, EmailClosure refs |
| next_pass_recommendation | Pass-ref | Next-step planted at end of journal |

### 2.2 Subsystem
A coherent module with its own owner, lifecycle, and CPIG attestation.

| Attribute | Type | Description |
|---|---|---|
| id | URN | `urn:c3i:subsystem:<name>` |
| name | Text | Human label |
| criticality | Enum | P0, P1, P2, P3 |
| owner_module | Path | Source-of-truth file or directory |
| cpig_score | Int 0..5 | Sum of 5 gate booleans |
| fractal_layer_set | Set<L0..L7> | Which fractal layers it touches |

### 2.3 FailureMode
A discrete failure scenario from FMEA analysis.

| Attribute | Type | Description |
|---|---|---|
| id | URN | `urn:c3i:fmea:<id>` |
| severity | Int 1..10 | S |
| occurrence | Int 1..10 | O |
| detection | Int 1..10 | D |
| RPN_pre | Int | S × O × D before mitigation |
| RPN_post | Int | S × O × D after mitigation |
| mitigation_pass | Pass-ref | Pass that closed it |

### 2.4 Constraint
A STAMP / AOR control rule with rule-file binding.

| Attribute | Type | Description |
|---|---|---|
| id | Text | `SC-*` or `AOR-*` |
| severity | Enum | INFINITE/CRITICAL/HIGH/MEDIUM/LOW |
| description | Text | One-sentence statement |
| enforced_by_pass | List<Pass-ref> | Passes that brought it to enforced status |
| rule_file | Path | `.claude/rules/*.md` |

### 2.5 FormalSpec
A formal verification artifact (TLA+, Agda, or Allium).

| Attribute | Type | Description |
|---|---|---|
| type | Enum | TLA+ / Agda / Allium |
| file_path | Path | `specs/tla/*.tla`, `specs/agda/*.agda`, `specs/allium/*.allium` |
| theorems | List<Text> | Named theorems |
| invariants | List<Text> | Named invariants |
| TLC_status | Enum | UNCHECKED / CHECKED / FAILED |
| Agda_status | Enum | UNCHECKED / TYPE_CHECKED / FAILED |

### 2.6 WiringGuard
A compile-time / build-time check that proves a Constraint mechanically.

| Attribute | Type | Description |
|---|---|---|
| id | Text | `wg-<name>` |
| file_path | Path | `lib/cepaf_gleam/test/*` or `native/.../tests/*` |
| test_count | Int | Number of test cases |
| pass_count | Int | Currently passing |
| framework | Enum | gleeunit / cargo_test / dotnet |
| STAMP_refs | List<SC-id> | Constraints proven |

### 2.7 Diagram
A visual asset (g1..g35 in this arc).

| Attribute | Type | Description |
|---|---|---|
| id | Text | `g1`..`g35` |
| type | Enum | dataflow / sequence / fractal / heatmap / ontology / etc. |
| file_paths | List<Path> | `.dot`, `.svg`, `.png` |

### 2.8 JournalEntry
A 13- or 14-section markdown record per pass.

| Attribute | Type | Description |
|---|---|---|
| pass | Pass-ref | Owner pass |
| file_path | Path | `docs/journal/task-*/...md` |
| line_count | Int | Body length |
| sections | Int | 13 (standard) or 14 (with addendum) |
| inline_mermaid_count | Int | Inline diagrams |
| ZK_holons_cited | List<zk-id> | Citations |

### 2.9 EmailClosure
A delivered SMTP closure email.

| Attribute | Type | Description |
|---|---|---|
| pass | Pass-ref | Owner pass |
| recipient | Text | Usually `Abhijit.Naik@bountytek.com` |
| subject | Text | Subject line |
| attachments | List<Path> | Journal + spec + matrix |
| delivered_at | ISO-8601 | sa-plan-daemon dispatch time |
| status | Enum | DELIVERED / DEFERRED / FAILED |

### 2.10 SaPlanTask
A row in `Smriti.db` planning store.

| Attribute | Type | Description |
|---|---|---|
| id | Int | sa-plan numeric id |
| urn | URN | `urn:c3i:plan:task:<id>` |
| status | Enum | pending / in_progress / completed / blocked |
| priority | Enum | P0..P3 |
| completed_pass | Pass-ref | Closing pass |

### 2.11 CPIGGate
One of the 5 attestation gates per Subsystem.

| Attribute | Type | Description |
|---|---|---|
| subsystem_id | URN | Owner subsystem |
| gate | Enum | formal_spec / wiring_guard / sa_plan / zk / email |
| score | Int 0\|1 | Boolean attestation |
| evidence_path | Path | File proving the score |

### 2.12 ZKHolon
A node in the Zettelkasten graph cited across passes.

| Attribute | Type | Description |
|---|---|---|
| id | Text | `zk-<16hex>` |
| level | Enum | ecosystem / organism / molecular / atomic |
| tags | List<Text> | Free tags |
| cited_in_passes | List<Pass-ref> | Where referenced |

---

## 3. Top-Level Relations

| # | Source | Verb | Target | Cardinality |
|---|---|---|---|---|
| R1 | Pass | DELIVERS | FormalSpec, WiringGuard, Diagram, JournalEntry, EmailClosure | 1..* |
| R2 | Pass | CLOSES | SaPlanTask | 0..* |
| R3 | Pass | MITIGATES | FailureMode | 0..* |
| R4 | Pass | ENFORCES | Constraint | 0..* |
| R5 | Pass | INGESTS | ZKHolon | 0..* |
| R6 | Subsystem | HAS_GATE | CPIGGate | exactly 5 |
| R7 | FormalSpec | PROVES | Constraint | 0..* |
| R8 | WiringGuard | ENFORCES_AT_BUILD | Constraint | 1..* |
| R9 | JournalEntry | CITES | ZKHolon | 0..* |
| R10 | JournalEntry | REFERENCES | FormalSpec, WiringGuard, Diagram | 0..* |
| R11 | Subsystem | DEPENDS_ON | Subsystem | 0..* (DAG) |
| R12 | FailureMode | OCCURS_IN | Subsystem | 1 |
| R13 | Constraint | APPLIES_TO | Subsystem | 1..* |
| R14 | EmailClosure | ATTACHES | JournalEntry, FormalSpec | 1..* |
| R15 | Pass | RECOMMENDS_NEXT | Pass | 0..1 |

---

## 4. Cross-Pass Invariants (Formal)

Seven named invariants emerge from the arc, six of which are formalizable in
TLA+ and one (INV-7) is a meta-invariant about the rollout pattern itself.

### INV-1 — DispatcherSingularity
> Every oban worker name has **exactly one** match arm in `workers.rs::dispatch`.

- Discovered: Pass 10 (worker name mismatch caused stuck `executing` state)
- Proven: Pass 11 (`specs/tla/WorkerDispatch.tla`)
- Wiring guard: `tests/dispatcher_singularity_test.rs`
- STAMP: `SC-SCHED-WORK-001`

### INV-2 — StateMachineSafety
> No `oban_jobs` row remains in `executing` after CLI exit.

- Discovered: Pass 9 (silent CLI hang on missing PATH)
- Proven: Pass 11 (`specs/tla/JobStateMachine.tla`)
- Wiring guard: `tests/state_machine_safety_test.rs`
- STAMP: `SC-SCHED-TELE-MANDATORY`

### INV-3 — CPIGFiveGateConsistency
> Every Subsystem in `cpig-matrix.json` has **all 5 gates** evaluated (no nulls).

- Discovered: Pass 13 (initial CPIG schema)
- Enforced: Pass 14, 15 (validator + cron)
- Wiring guard: `scripts/cpig-validator.sh` (run hourly)
- STAMP: `SC-CPIG-001..005`

### INV-4 — RuntimeEnforcement
> A `cpig-validator-hourly` cron is registered and emits Zenoh envelopes on
> `indrajaal/l4/cpig/validator/<run_id>`.

- Discovered: Pass 16 (static-only CPIG could drift)
- Enforced: Pass 16 (cron + dead-man's switch at 30 min)
- STAMP: `SC-CPIG-RUNTIME-001`

### INV-5 — URLRoutingMonotonic
> Every URL pattern published in any journal has a **stable redirect path** —
> URLs never break across passes.

- Discovered: Pass 18 (port 4200 → 8443 migration risk)
- Enforced: Pass 18 (server.rs route table + redirects)
- STAMP: `SC-JNL-001`

### INV-6 — FederationQuorum
> Cross-mesh CPIG attestation requires **2-of-3** quorum across federated nodes.

- Discovered: Pass 20 (federation onboarding)
- Proven: Pass 20 (`specs/tla/FederationQuorum.tla`)
- STAMP: `SC-FED-002`, `SC-SIL4-006`

### INV-7 — CrossSubsystemMetaPattern (Meta-Meta-Invariant)
> Every subsystem rollout follows the **same 5 CPIG gates** pattern —
> `formal_spec → wiring_guard → sa_plan → zk → email`.

- This is the invariant **about the invariants**.
- It is the unifying claim of this entire arc and the reason this ontology
  exists: future passes must plug new Subsystem instances into the same
  five-gate template.
- Not TLC-checkable; verified by hand at every CPIG matrix update.

---

## 5. Concrete Instances (Passes 1-20 Population)

### 5.1 Passes (20 instances)

| # | Class | Date | Scope |
|---|---|---|---|
| 1 | A | 2026-04-22 | Marionette MCP rule + 16 tools doc |
| 2 | B | 2026-04-23 | Patrol-Marionette joint workflow |
| 3 | A | 2026-04-23 | dart-flutter-ai-mcp.md rule |
| 4 | C | 2026-04-24 | FluffyChat 200-test CATALOG.md |
| 5 | E | 2026-04-24 | Fractal RCA Marionette adoption |
| 6 | F | 2026-04-25 | marionette-fractal-jidoka health-check |
| 7 | B | 2026-04-25 | sa-plan-daemon scheduler exec.rs |
| 8 | C | 2026-04-25 | Scheduler integration tests |
| 9 | E | 2026-04-26 | Stuck-executing RCA |
| 10 | F | 2026-04-26 | Worker dispatch fix + telemetry |
| 11 | A | 2026-04-26 | TLA+ WorkerDispatch + JobStateMachine |
| 12 | D | 2026-04-26 | Scheduler closure + email + ZK |
| 13 | A | 2026-04-26 | CPIG five-gate framework spec |
| 14 | B | 2026-04-26 | cpig-validator.sh + matrix.json |
| 15 | C | 2026-04-27 | CPIG retroactive cross-subsystem |
| 16 | F | 2026-04-27 | CPIG runtime cron enforcement |
| 17 | C | 2026-04-27 | CPIG mesh-wide audit (12 subsystems) |
| 18 | F | 2026-04-27 | URL routing stability fix |
| 19 | D | 2026-04-28 | Pass-suite closure + 34 diagrams |
| 20 | G | 2026-04-28 | Federation quorum + ontology kickoff |

### 5.2 Subsystems (12 instances, post-arc CPIG scores)

| Subsystem | criticality | owner_module | CPIG | layers |
|---|---|---|---|---|
| sa-plan-daemon | P0 | `sub-projects/c3i/native/planning_daemon/` | 5/5 | L3,L4,L5 |
| Pi runtime | P1 | `lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_*` | 5/5 | L4,L5 |
| Zenoh mesh | P0 | `sub-projects/c3i/native/planning_daemon/src/zenoh_*` | 5/5 | L1,L6 |
| FerrisKey IAM | P0 | `sub-projects/ferriskey/` | 5/5 | L0,L3 |
| F# CEPAF | P1 | `lib/cepaf/` | 5/5 | L4,L5 |
| scripts-gleam | P2 | `sub-projects/scripts-gleam/` | 5/5 | L3,L4 |
| Marionette MCP | P1 | `sub-projects/marionette_mcp/` | 5/5 | L2,L4,L5 |
| Patrol MCP | P1 | (pub.dev) `patrol_mcp` | 5/5 | L5 |
| Dart MCP | P2 | `dart_mcp_server` (bundled) | 5/5 | L1,L4 |
| Gleam UI | P0 | `lib/cepaf_gleam/src/cepaf_gleam/ui/` | 5/5 | L2,L3,L5 |
| Cortex | P0 | `native/planning_daemon/src/cortex.rs` | 5/5 | L5 |
| Fractal Widgets | P1 | `lib/cepaf_gleam/src/cepaf_gleam/fractal/` | 5/5 | L0..L7 |

### 5.3 FailureModes (8 top FMEA instances from Pass-11 RCA)

| id | S | O | D | RPN_pre | RPN_post | mitigation |
|---|---|---|---|---|---|---|
| FM-DISPATCH-MISMATCH | 9 | 8 | 9 | 648 | 24 | Pass 10 |
| FM-SILENT-CLI-HANG | 8 | 7 | 9 | 504 | 16 | Pass 7,10 |
| FM-PATH-DRIFT | 7 | 8 | 8 | 448 | 32 | Pass 7 |
| FM-NO-TIMEOUT-GUARD | 9 | 6 | 8 | 432 | 18 | Pass 7 |
| FM-SELECTOR-GUESS | 9 | 6 | 4 | 216 | 24 | Pass 1 |
| FM-MARIONETTE-RELEASE | 10 | 2 | 7 | 140 | 14 | Pass 1 |
| FM-CPIG-DRIFT | 7 | 5 | 6 | 210 | 21 | Pass 16 |
| FM-URL-BREAKAGE | 6 | 5 | 7 | 210 | 21 | Pass 18 |

### 5.4 Constraints (~30 key SC-* IDs)

`SC-MARIONETTE-001..012`, `SC-MARIONETTE-JIDOKA-001..010`, `SC-PATROL-MCP-001..013`,
`SC-DART-MCP-001..010`, `SC-SCHED-WORK-001`, `SC-SCHED-TELE-MANDATORY`,
`SC-CPIG-001..005`, `SC-CPIG-RUNTIME-001`, `SC-FED-002`, `SC-SIL4-006`,
`SC-JNL-001..006`, `SC-WIRE-001..007`, `SC-ZK-IMP-001..006`, `SC-FRAC-RRF-001..010`,
`SC-FEAT-EVO-001..013`, `SC-NOTIFY-JOURNAL-001..004`, `SC-PI-AUTO-001..008`.

### 5.5 FormalSpecs (15 instances: 13 TLA+ + 2 Agda)

| type | file | invariants |
|---|---|---|
| TLA+ | `specs/tla/WorkerDispatch.tla` | INV-1 |
| TLA+ | `specs/tla/JobStateMachine.tla` | INV-2 |
| TLA+ | `specs/tla/CPIGConsistency.tla` | INV-3 |
| TLA+ | `specs/tla/CPIGRuntime.tla` | INV-4 |
| TLA+ | `specs/tla/UrlRouting.tla` | INV-5 |
| TLA+ | `specs/tla/FederationQuorum.tla` | INV-6 |
| TLA+ | `specs/tla/MarionetteSession.tla` | DiscoveryBeforeDrive |
| TLA+ | `specs/tla/SchedulerLifecycle.tla` | NoOrphanedJob |
| TLA+ | `specs/tla/HealthCheckCron.tla` | DeadMansSwitch |
| TLA+ | `specs/tla/LeaderElection.tla` | NoSplitBrain |
| TLA+ | `specs/tla/PatrolRunner.tla` | TripleParity |
| TLA+ | `specs/tla/ZenohEnvelope.tla` | EnvelopeSchema |
| TLA+ | `specs/tla/ZkCitation.tla` | CiteOrDeclare |
| Agda | `specs/agda/CpigGate.agda` | FiveGateProduct |
| Agda | `specs/agda/FederationQuorum.agda` | TwoOfThree |

### 5.6 WiringGuards (10 instances)

`tests/dispatcher_singularity_test.rs`,
`tests/state_machine_safety_test.rs`,
`tests/cpig_consistency_test.rs`,
`tests/url_routing_test.rs`,
`tests/federation_quorum_test.rs`,
`lib/cepaf_gleam/test/wiring_guard_test.gleam`,
`lib/cepaf_gleam/test/pi_integration_test.gleam`,
`lib/cepaf_gleam/test/marionette_envelope_test.gleam`,
`lib/cepaf_gleam/test/cpig_matrix_test.gleam`,
`scripts/marionette-health-check.sh`.

### 5.7 Diagrams (34 instances g1-g34, this pass adds g35)

g1-g6 (Pass 1-6 Marionette), g7-g12 (Pass 7-12 scheduler), g13-g20 (Pass 13-15 CPIG),
g21-g28 (Pass 16-18 enforcement), g29-g34 (Pass 19-20 closure + federation).
**g35** = this ontology (Pass 21).

### 5.8 JournalEntries (21 — one per pass + master)

`docs/journal/task-116480247290237220/pass{01..20}-*.md` + `master-journal.md`.

### 5.9 EmailClosures (~7 delivered + 1 deferred)

Delivered: Pass 6, 12, 15, 16, 18, 19, 20.  Deferred: Pass 21 (this ontology + g35
will ship in next batched closure).

### 5.10 ZK Holons (5 cross-references)

- `[zk-bb4de67d97f807ac]` — selector-guessing anti-pattern (cited Pass 1, 2, 4, 5)
- `[zk-c14e1d23afff486c]` — scheduler PATH drift (cited Pass 7, 9, 10, 12)
- `[zk-d1b0c1494...]` — CPIG five-gate origin (cited Pass 13, 14, 15)
- `[zk-d88a58e54ef8a08f]` — federation quorum reference (cited Pass 20)
- `[zk-bd82645aedcb5ef4]` — Stub That Lies (cited Pass 4 corpus)

---

## 6. Querying the Ontology

### Q1. Which passes touched the dispatcher?
**A.** Pass 9 (RCA discovered mismatch), Pass 10 (fix), Pass 11 (TLA+ proof).
Pass 18 touched URL routing in `server.rs` but did not modify dispatcher.

### Q2. Which subsystems have the lowest CPIG score?
**A.** All 12 subsystems are 5/5 after Pass 15-20. The lowest pre-Pass-15 score
was scripts-gleam at 2/5 (missing formal_spec and wiring_guard) and
Fractal Widgets at 3/5 (missing email closure and zk citation).

### Q3. What invariant catches the Pass-10 dispatcher mismatch?
**A.** **INV-1 (DispatcherSingularity)**, proven by `WorkerDispatch.tla` and
mechanically enforced by `tests/dispatcher_singularity_test.rs` at build time.

### Q4. Which constraint family has the highest STAMP coverage?
**A.** `SC-CPIG` family (CPIG-001..005 + CPIG-RUNTIME-001 = 6 IDs) tied with
`SC-MARIONETTE-*` (12 IDs) — Marionette is highest by raw ID count.

### Q5. Which pass closed the most P0 tasks?
**A.** **Pass 20** — 5 P0 sa-plan tasks closed (federation quorum, ontology
kickoff, master journal, mesh-wide CPIG attestation, RCA archival).

---

## 7. Schema as JSON-LD

Three illustrative entity instances for machine ingestion:

```json
{
  "@context": {
    "@vocab": "urn:c3i:ontology:v1#",
    "delivers": { "@type": "@id" },
    "proves": { "@type": "@id" }
  },
  "@graph": [
    {
      "@id": "urn:c3i:pass:11",
      "@type": "Pass",
      "number": 11,
      "class": "A",
      "date": "2026-04-26",
      "scope": "TLA+ WorkerDispatch + JobStateMachine specifications",
      "delivers": [
        "urn:c3i:formalspec:WorkerDispatch.tla",
        "urn:c3i:formalspec:JobStateMachine.tla",
        "urn:c3i:journal:pass11"
      ],
      "recommends_next": "urn:c3i:pass:12"
    },
    {
      "@id": "urn:c3i:formalspec:WorkerDispatch.tla",
      "@type": "FormalSpec",
      "specType": "TLA+",
      "file_path": "specs/tla/WorkerDispatch.tla",
      "invariants": ["DispatcherSingularity"],
      "TLC_status": "CHECKED",
      "proves": "urn:c3i:constraint:SC-SCHED-WORK-001"
    },
    {
      "@id": "urn:c3i:subsystem:sa-plan-daemon",
      "@type": "Subsystem",
      "name": "sa-plan-daemon",
      "criticality": "P0",
      "owner_module": "sub-projects/c3i/native/planning_daemon/",
      "cpig_score": 5,
      "fractal_layer_set": ["L3", "L4", "L5"]
    }
  ]
}
```

---

## 8. Versioning + Future Evolution

This ontology is **v1.0** (Pass 21 baseline).

- **Static schema** (this document): entity types, relations, invariants — stable.
- **Dynamic instances** (`cpig-matrix.json`, sa-plan DB, ZK): grow with every pass.

**Pass 22+ rules**:
1. New Subsystem onboarding ⇒ add row to `cpig-matrix.json`, attest 5 gates.
2. New Constraint family ⇒ add to §5.4 + register in `constraint-registry.md`.
3. New Invariant ⇒ formalize in TLA+ if possible, add to §4 with INV-N id.
4. New entity *type* requires ontology revision (v1.1+) and operator approval.
5. The 12 entity types and 15 relations of v1.0 are **closed for additive change
   only** — no removals without a migration plan.

---

## 9. Cross-Reference Index (entity → source-of-truth path)

| Entity | Source-of-truth |
|---|---|
| Pass | `docs/journal/task-116480247290237220/pass*.md` |
| Subsystem | `docs/journal/task-116480247290237220/cpig-matrix.json` |
| FailureMode | `docs/journal/task-116480247290237220/rca-tps.md` (Pass 11) |
| Constraint | `.claude/rules/*.md` + `.claude/rules/constraint-registry.md` |
| FormalSpec | `specs/tla/*.tla`, `specs/agda/*.agda`, `specs/allium/*.allium` |
| WiringGuard | `lib/cepaf_gleam/test/wiring_guard_test.gleam`, `native/.../tests/*` |
| Diagram | `docs/journal/task-116480247290237220/diagrams/g*.{dot,svg,png}` |
| JournalEntry | `docs/journal/task-116480247290237220/pass*.md` |
| EmailClosure | `sa-plan-daemon` audit log + `data/email-audit.log` |
| SaPlanTask | `data/kms/smriti.db::oban_jobs` + `PROJECT_TODOLIST.md` (derived) |
| CPIGGate | `docs/journal/task-116480247290237220/cpig-matrix.json` |
| ZKHolon | `data/kms/smriti.db::holons` (FTS5) |

---

## 10. Closing Note

This ontology is the **lattice** on top of which Passes 21+ compound. It is
intentionally minimal — 12 entities, 15 relations, 7 invariants — so that any
agent (Claude, Gemini, Pi) or human operator can hold the entire shape in
working memory while editing.

The meta-meta-invariant **INV-7** is the most important claim of the entire
20-pass arc: every subsystem rollout follows the same five CPIG gates. If a
future pass discovers a sixth gate is needed, it must update this document
**first** (v1.1), then propagate to `cpig-matrix.json` and `cpig-validator.sh`.

> *निष्कामकर्म* — Action without attachment to fruits. The ontology serves the
> system, not the ego of any single pass. (Gita 3.19)
