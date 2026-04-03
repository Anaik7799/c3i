# Human Intent Protection Protocol (SC-HINT)

<!-- applies-to: test/**/*wallaby*.exs, docs/specs/pages/*.md -->

## SUPREME MANDATE

**Human-Specified Intent sections in page specifications are INVIOLABLE.**

Every page spec MUST contain a `## Human-Specified Intent` section marked with the
`<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->` sentinel. Agents are ABSOLUTELY FORBIDDEN
from creating, editing, or deleting content inside this section. The section represents
the operator's authoritative statement of what the page must do — it overrides every
other spec section, every STAMP constraint, and every agent-generated annotation.

---

## STAMP/AOR Reference
> SC-HINT-001 to SC-HINT-008, AOR-HINT-001 to AOR-HINT-005 — defined in this file and
> referenced from CLAUDE.md §5.0 (SC-HMI, SC-COV)
> Key: Human-Specified Intent is read-only for agents. Correlation score MUST be reported
> on every page audit. Misalignment > 30% triggers P1 alert and blocks agent modifications.

---

## 1.0 Core Principle

Every page spec that describes a LiveView page, a Wallaby test module, or a standalone
docs/specs/pages/ document MUST contain a `## Human-Specified Intent` section. This
section:

- **Can ONLY be modified by humans manually.**
- **Agent MUST NEVER modify, delete, override, or reformat content in this section.**
- **Agent MUST flag any misalignment** between observed code behavior and human intent.
- **Human intent instructions OVERRIDE** all agent-generated sections, auto-derived
  selectors, BDD scenarios, FMEA tables, and STAMP annotations.
- **The section persists across all evolution cycles** — it is never regenerated.

---

## 2.0 STAMP Constraints (Human Intent)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-HINT-001 | Every page spec MUST contain `## Human-Specified Intent` section | CRITICAL |
| SC-HINT-002 | Agent MUST NEVER modify Human-Specified Intent section | CRITICAL |
| SC-HINT-003 | Agent MUST detect misalignment between code behavior and human intent | HIGH |
| SC-HINT-004 | Human intent instructions OVERRIDE all agent-generated sections | CRITICAL |
| SC-HINT-005 | Agent MUST report correlation score between code and human intent | HIGH |
| SC-HINT-006 | Misalignment > 30% MUST trigger P1 alert with detailed diff | HIGH |
| SC-HINT-007 | Human-Specified Intent section MUST have `<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->` marker | CRITICAL |
| SC-HINT-008 | Agent MUST preserve human intent across all evolution cycles | CRITICAL |

---

## 3.0 AOR Rules (Human Intent)

| ID | Rule |
|----|------|
| AOR-HINT-001 | Before modifying any page spec, check for Human-Specified Intent section |
| AOR-HINT-002 | After any page modification, verify human intent section is byte-for-byte unchanged |
| AOR-HINT-003 | Report alignment score in every page audit output |
| AOR-HINT-004 | Flag divergence between EXPECTED behavior and AS-IS behavior |
| AOR-HINT-005 | Human intent changes require git blame verification of human authorship |

---

## 4.0 Section Format (Canonical Template)

When creating a new page spec for which no Human-Specified Intent exists yet, the agent
MUST insert this empty template and leave all content lines blank. The agent MUST NOT
pre-populate any content inside the `<!-- HUMAN-ONLY -->` block.

```markdown
## Human-Specified Intent
<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
<!-- Last modified by: [Human Name] on [YYYY-MM-DD] -->

### Functional Intent
[What this page MUST do from the human operator's perspective]

### UX Requirements
[How the page MUST feel and behave for the operator]

### Safety Requirements
[Non-negotiable safety behaviors]

### Override Instructions
[Any instructions that override agent-generated behavior]
<!-- END HUMAN-ONLY -->
```

**Placement**: The `## Human-Specified Intent` section MUST appear as the first second-level
heading inside a `@moduledoc` or spec document — before Design Intent, BDD scenarios,
FMEA tables, or any other agent-derived section.

---

## 5.0 Correlation Check Protocol

### 5.1 Alignment Score Formula

```
Alignment Score = |EXPECTED ∩ AS-IS| / |EXPECTED ∪ AS-IS|

Where:
  EXPECTED = behaviors specified in Human-Specified Intent
  AS-IS    = behaviors observed in the LiveView .ex source code

Thresholds:
  ≥ 0.9  : ALIGNED      (green)  — no action required
  0.7–0.9: DRIFT        (yellow) — flag for human review
  < 0.7  : MISALIGNED   (red)    — P1 alert, block agent modifications
```

### 5.2 Computation Steps

1. **Parse EXPECTED**: Extract every imperative statement from the Human-Specified Intent
   section (lines beginning with verbs or containing MUST/SHALL/SHOULD).
2. **Parse AS-IS**: Read the LiveView `.ex` source for the page. Extract:
   - `handle_event/3` clauses (interactive behaviors)
   - `render/1` or HEEx template patterns (UI elements)
   - PubSub subscriptions (real-time behaviors)
   - Guardian/auth guards (safety behaviors)
3. **Compute intersection**: For each EXPECTED statement, score 1.0 if a matching
   AS-IS behavior exists, 0.0 otherwise (partial matches scored 0.5).
4. **Report**: Emit alignment score with per-statement breakdown.

### 5.3 Misalignment Response

When Alignment Score < 0.7:

1. **BLOCK** agent from modifying any spec section for this page.
2. **EMIT** P1 alert:
   ```
   [SC-HINT-006] MISALIGNMENT DETECTED
   Page:  <module or file path>
   Score: <N> (threshold: 0.70)
   Diff:
     EXPECTED but NOT in code: <list of missing behaviors>
     In code but NOT in EXPECTED: <list of undeclared behaviors>
   Action required: human review before agent may proceed.
   ```
3. **LOG** to Immutable Register via ImmutableState.append/1.
4. **PUBLISH** to Zenoh topic `indrajaal/hint/misalignment`.

---

## 6.0 Forbidden Actions ($\mathbb{F}_{HINT}$)

The following actions are STRICTLY FORBIDDEN for agents:

```
# FORBIDDEN — Writing inside the human-only block
Edit(file, old: "<anything inside <!-- HUMAN-ONLY -->", ...)   # VIOLATION SC-HINT-002

# FORBIDDEN — Deleting the section
Edit(file, old: "## Human-Specified Intent\n<!-- HUMAN-ONLY ...", new: "")  # VIOLATION SC-HINT-002

# FORBIDDEN — Regenerating the section from source
"Updating Human-Specified Intent based on latest LiveView source"           # VIOLATION SC-HINT-004

# FORBIDDEN — Moving or renaming the section heading
Edit(file, old: "## Human-Specified Intent", new: "## Operator Intent")     # VIOLATION SC-HINT-007

# FORBIDDEN — Silently proceeding when the section is absent
# (must report SC-HINT-001 violation and create empty template)             # VIOLATION SC-HINT-001
```

---

## 7.0 Integration with Wallaby Tests (AOR-COV-008)

Per AOR-COV-008, agents MUST read the LiveView `.ex` source before writing Wallaby
selectors. When SC-HINT is active, the read sequence is:

1. Read `## Human-Specified Intent` section — extract operator-level behavioral contract.
2. Read LiveView `.ex` source — extract AS-IS selectors and behaviors.
3. Compute Alignment Score between step 1 and step 2.
4. If score < 0.7: HALT, emit P1 alert, do not generate Wallaby test.
5. If score >= 0.7: generate Wallaby test such that C1–C8 coverage satisfies human intent.

The `@moduledoc` of every Wallaby test file MUST include an `Alignment Score` field:

```elixir
@moduledoc """
## Human-Specified Intent
<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
...
<!-- END HUMAN-ONLY -->

## Alignment Score
Score: 0.94 (ALIGNED) — checked 2026-03-28
"""
```

---

## 8.0 Constitutional Alignment

This rule enforces:

- **Ψ₂ (Evolutionary Continuity)**: Human-authored intent is part of the holon's
  evolutionary history and MUST be preserved through all morphogenic cycles.
- **Ψ₃ (Verification Capability)**: Alignment score provides a verifiable, numeric
  measure of fidelity between operator intent and system behavior.
- **Ω₄ (Test-Driven Gen)**: Human intent is the primary specification from which
  TDG-compliant tests are derived — not the other way around.
- **SC-COV-021**: Wallaby `@moduledoc` MUST contain page spec including Design Intent.
  Human-Specified Intent is a required sub-section of that spec.
- **SC-HMI-010**: Vibrant, correct feedback depends on the cockpit behaving as operators
  expect — which is only enforceable if human intent is captured and verified.

---

## 9.0 Enforcement

This rule is:

- **CRITICAL**: Violations of SC-HINT-001, SC-HINT-002, SC-HINT-004, SC-HINT-007,
  SC-HINT-008 MUST halt the current agent operation immediately (AOR-SAF-001: < 1s).
- **AUDITED**: Every alignment score computation and every HINT violation is recorded
  in the Immutable Register.
- **GATED**: An agent MAY NOT mark a page-spec task `completed` via `sa-plan` if the
  Human-Specified Intent section is absent or if the alignment score is below 0.7.
- **REVERSIBLE**: If an agent accidentally modifies the section, `git revert` is the
  mandatory remediation (SC-FUNC-003 rollback path).

---

## 10.0 Related Documents

- CLAUDE.md §5.0 — SC-HMI, SC-COV-021, SC-COV-022
- `.claude/rules/functional-invariant.md` — SC-FUNC-003 (rollback path)
- `.claude/rules/change-management.md` — 4-layer impact, reversal protocol
- `.claude/rules/concurrent-bug-fix-protocol.md` — sa-plan completion gate
- `docs/specs/pages/` — canonical page spec location
