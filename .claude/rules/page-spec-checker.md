# Per-Page Spec Conformance Checker (SC-PAGE-SPEC-001..008)

## Mandate

**Every page in the C3I navigation graph MUST register a `PageSpec` and be
checked at runtime by the page_checker against that spec.** The checker emits
sa-plan tasks on drift and Zenoh OTel spans on every check.

ZK lineage: [zk-bb4de67d97f807ac] selector-guessing / consult-the-running-system ·
[zk-a97c474c58e95bd8] pass-9 PageChecker substrate · SC-AGUI-UI-013 (DAG-Q
triple-transport parity).

## Why this rule exists

The audit (task 116489616652108372) flagged that `/planning` had multiple
hidden defects (3 of 4 view modes were `display:none` empty divs; cache-bust
drifted; ZK button mislabelled the fallback). None of these were caught by
existing wiring-guard or compile-time gates because they're **runtime
conformance** issues — the page renders, but it doesn't render *what the spec
says it should render*.

The PageChecker is a fractal extension of SC-WIRE: where SC-WIRE catches Model
+ Msg drift at compile-time, SC-PAGE-SPEC catches **served-HTML drift** at
runtime, every 3 minutes, across all 32 pages.

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-PAGE-SPEC-001 | Every page in `domain.gleam Page` enum MUST have a `PageSpec` entry in the page_checker registry | CRITICAL |
| SC-PAGE-SPEC-002 | PageChecker MUST run at least every 3 minutes across all pages | HIGH |
| SC-PAGE-SPEC-003 | Spec alignment score < 0.7 MUST trigger P1 sa-plan task | HIGH |
| SC-PAGE-SPEC-004 | Page response status code ≥ 500 MUST trigger P0 sa-plan task within 60 s | CRITICAL |
| SC-PAGE-SPEC-005 | PageSpec changes MUST update `wiring_guard.gleam` in the SAME commit (covers spec ↔ Model parity) | HIGH |
| SC-PAGE-SPEC-006 | Per-page violation events MUST publish OTel span on `indrajaal/l5/spec/violation/{page}` | HIGH |
| SC-PAGE-SPEC-007 | Cockpit page-spec grid MUST refresh at most every 30 s | MEDIUM |
| SC-PAGE-SPEC-008 | A new page (Lustre + Wisp + TUI per SC-GLM-UI-001) MUST add a corresponding spec entry in the SAME commit | CRITICAL |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-PAGE-SPEC-001 | NEVER add a route to `domain.gleam Page` without adding a PageSpec entry to the registry |
| AOR-PAGE-SPEC-002 | When changing the served HTML structure (section IDs, weather bar, etc.), update the PageSpec `required_substrings` |
| AOR-PAGE-SPEC-003 | The page_checker cron MUST run via the existing `gleam_run` worker (per SC-DISP-REGISTRY-001..010); do not add a new native worker |
| AOR-PAGE-SPEC-004 | Spec-alignment failures MUST be visible to operator within 5 min (cadence × 1) |

## Reference implementation (pass-9 shipped)

### Registry (inline)

`sub-projects/scripts-gleam/src/scripts/verify/page_checker.gleam`:

```gleam
pub fn registry() -> List(#(String, String, List(String))) {
  [
    #("/", "Root", ["page-title"]),
    #("/planning", "Planning", [
      "all-grid", "blocked-grid", "active-grid",
      "planning-grid.js", "task-detail-panel",
    ]),
    #("/dashboard", "Dashboard", ["page-title", "Indrajaal Swarm Dashboard"]),
    // ... 32 entries total
  ]
}
```

### Verdict computation

```gleam
let cmd = "curl -s -w '\\n__STATUS_%{http_code}' --max-time 5 '" <> url <> "'"
let raw = os_cmd(cmd)
let status = parse_status(raw)
let found = list.fold(expected, 0, fn(acc, sub) {
  case string.contains(raw, sub) {
    True  -> acc + 1
    False -> acc
  }
})
let aligned = found == list.length(expected)
```

### Lyapunov gate

```gleam
case failed_5xx > 0 {
  True  -> JIDOKA P0
  False -> Nil
}
case drift > 5 {
  True  -> P1 task
  False -> Nil
}
```

### Cron

`./sa-plan schedule-add --name page-check-3min --cron "*/3 * * * *" --worker gleam_run --module scripts/verify/page_checker --priority 95 --max-attempts 1`.

Live verdict (pass-9): `pass=32/32 5xx=0 4xx=0 drift=0`.

## RETE-UL rule

`rules/engine.gleam data_quality_rules` includes:

```
rule "PageSpecAlignmentLow" salience 95 {
  when Dq.PageAlignmentLow == true then
    Dq.Decision = "BlockReleaseToProd";
    Dq.Reason   = "SC-PAGE-SPEC-003 alignment below threshold";
}
```

## Future evolution path

Pass-9 ships the **substrate** with inline registry. Future passes may
migrate to:
1. Per-page spec files at `specs/pages/<page>.spec.gleam` (one per page).
2. Compile-time wiring guard test asserting `∀ Page p : ∃! spec ∈ registry()`.
3. OTP actor `ha/page_checker.gleam` analogous to `freshness_monitor.gleam`
   for sub-second escalation.
4. Cockpit dashboard tile rendering 32-cell page-conformance grid.
5. Required `required_endpoints` (referenced fetch URLs) and
   `min_focusable` / `min_aria_labelled` fields for full SC-AGUI-UI-009
   coverage.

## Cross-references
- `sub-projects/scripts-gleam/src/scripts/verify/page_checker.gleam` — substrate (210 LOC)
- `.claude/rules/value-guard.md` — sibling SC-VALUE-GUARD family
- `.claude/rules/wiring-guard.md` — type-domain sibling (SC-WIRE)
- `lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam` — Page enum (32 variants)
- `lib/cepaf_gleam/src/cepaf_gleam/rules/engine.gleam` — RETE-UL `PageSpecAlignmentLow`
- `docs/journal/task-116491660660910166/` — pass-9 journal §3.2

## Governance parity
Mirror at `.gemini/rules/page-spec-checker.md` next sync (SC-SYNC-DOC-007).
