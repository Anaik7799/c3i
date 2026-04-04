---
name: wallaby-coverage
description: allowed-tools: Read, Grep, Glob, Bash(mix:*), Bash(MIX_ENV=test:*), Bash(python3:*), Agent
---
---

# Wallaby Fractal Coverage Engine (SC-COV-008 to SC-COV-022, SC-MATH-COV-001 to SC-MATH-COV-008)

Audit, write, and fix Wallaby E2E browser tests for ALL LiveView pages using the 8-category
gold standard with mathematical quality gates (Shannon entropy, CCM, FMEA RPN, ITQS).

## Mathematical Foundation

**Shannon Coverage Entropy** $H$:
$$H = -\sum_{i=1}^{8} \frac{n_i}{N} \log_2 \frac{n_i}{N}, \quad H_{norm} = \frac{H}{\log_2 8}, \quad H_{norm} \geq 0.83$$

**Coverage Completeness Metric** (weighted):
$$CCM = \frac{\sum w_i \cdot \min(c_i, 1)}{\sum w_i}, \quad w = [1.0, 1.5, 1.0, 1.2, 2.0, 1.0, 1.5, 3.0]$$

**EXPECTED vs AS-IS Divergence**:
$$D_{EA} = \frac{|F_{expected} \setminus F_{implemented}|}{|F_{expected}|} \leq 0.10$$

**Information-Theoretic Quality Score**:
$$ITQS = 0.25 \cdot H_{norm} + 0.35 \cdot CCM + 0.25 \cdot (1 - D_{EA}) + 0.15 \cdot FSI$$

**Fractal Self-Similarity Index**:
$$FSI = 1 - \frac{\sigma_H}{\mu_H}, \quad FSI \geq 0.85$$

## Usage
```
/wallaby-coverage audit                     # Full suite ITQS audit — all 49+ files
/wallaby-coverage audit performance_dashboard  # Single file audit
/wallaby-coverage fix navigation_portal     # Fix entropy/CCM gaps in specific file
/wallaby-coverage write new_page_live       # Write new gold standard test from scratch
/wallaby-coverage status                    # Suite-wide metrics summary
```

## Commands

### audit — Compute ITQS for all/specific Wallaby test files

1. Glob `test/**/*_wallaby_test.exs`
2. For each file, extract:
   - Feature count per category from `# ── C{N}:` section markers
   - Total feature count
   - C8 dual verification count (action buttons with both status + flash tests)
3. Compute per-file: H, H_norm, CCM, D_EA (estimate from @moduledoc)
4. Compute suite-wide: FSI, mean_H, ITQS per file
5. Output ranked table:
```
Rank |   ITQS | Grd |     H |   CCM |  D_EA |  Ft |  C8D | File
```
6. Grade: A≥0.90, B≥0.85, C≥0.75, D<0.75

**ITQS audit mix task**: `lib/mix/tasks/wallaby_coverage_audit.ex`
Run: `MIX_ENV=test mix wallaby.coverage.audit [--json] [--file path]`

### fix — Improve a specific file's entropy/CCM/C8 coverage

Protocol (MANDATORY ORDER per AOR-COV-008):
1. **Read LiveView .ex source** — extract mount assigns, handle_event names, PubSub subs, timers, HEEx template selectors
2. **Read existing Wallaby test file** — count features per C1-C8 category
3. **Compute current metrics** — H, CCM, identify weakest categories
4. **Add missing category features** — prioritize categories with 0 features first, then lowest-weight categories
5. **For C4 (Timeline)**: Add `Process.sleep(5_500)` stability tests if page has timer/PubSub refresh
6. **For C5 (Interactive)**: Add navigation, form interaction, or browser refresh tests
7. **For C6 (Media/Rich)**: Add semantic class assertions (`bg-surface-primary`, `text-content-primary`, `border-border-theme-primary`)
8. **For C7 (AI/Advisory)**: Add contextual reading tests (metric interpretation, multi-dimension breakdowns)
9. **For C8 (Actions)**: For pages WITH buttons: dual verify (status change + flash). For read-only pages: `refute_has` for `button[phx-click]` and `form[phx-submit]`
10. **Verify H ≥ 2.5 bits** after changes (recount per-category)
11. **Preserve Human-Specified Intent section** — NEVER modify (SC-HINT-002)

### write — Create new gold standard test from LiveView source

Source-first protocol (SC-COV-022):
1. Read the LiveView `.ex` module — extract:
   - Route from `router.ex`
   - `mount/3` assigns
   - All `handle_event/3` clauses → interactive elements
   - All `handle_info/2` clauses → timer/PubSub refresh behavior
   - HEEx template → DOM structure, CSS classes, phx-click/submit bindings
2. Derive F_expected set (all testable UI elements)
3. Write @moduledoc with all 9 sections:
   - Page Identity, Design Intent, Expected Behavior, BDD Scenarios
   - UX Flow, UI Elements Inventory, STAMP Constraints, FMEA Risks
   - Human-Specified Intent (empty template — NEVER pre-populate)
4. Write features across all 8 categories (C1-C8)
5. Target: H ≥ 2.5 bits, CCM ≥ 0.90, all applicable categories covered
6. Use `IndrajaalWeb.FeatureCase`, `@moduletag :wallaby`, `async: false`

### status — Suite-wide metrics dashboard

```
╔═══════════════════════════════════════════════════════════════╗
║  WALLABY FRACTAL COVERAGE STATUS              [YYYY-MM-DD]    ║
╠═══════════════════════════════════════════════════════════════╣
║  Files:       {N} test files                                  ║
║  Features:    {N} total ({avg} avg/file)                      ║
║  Entropy:     {pass}/{total} files ≥ 2.5 bits ({pct}%)        ║
║  CCM:         {mean:.1%} mean (target: 90%+)                  ║
║  FSI:         {fsi:.3f} (target: ≥ 0.85)                      ║
║  ITQS:        {mean:.3f} mean, {min:.3f} min                  ║
║  C8 Dual:     {pass}/{total} files ({pct}%)                   ║
║  Grades:      A={a} B={b} C={c} D={d}                         ║
╚═══════════════════════════════════════════════════════════════╝
```

## The 8 Mandatory Categories (C1-C8)

| Cat | Name | Description | Min | Weight | Section Marker |
|-----|------|-------------|-----|--------|----------------|
| C1 | Page Structure | Headings, section presence, footer | 2 | 1.0 | `# ── C1:` |
| C2 | Status/Badge | Dynamic badges, state labels, counts | 2 | 1.5 | `# ── C2:` |
| C3 | Data Grid/Summary | Key-value display, tables, links | 4 | 1.0 | `# ── C3:` |
| C4 | Timeline/History | Refresh stability, temporal data | 3 | 1.2 | `# ── C4:` |
| C5 | Interactive | Forms, navigation, controls | 3 | 2.0 | `# ── C5:` |
| C6 | Media/Rich | Semantic classes, color-coded elements | 3 | 1.0 | `# ── C6:` |
| C7 | AI/Advisory | Contextual interpretation, disclaimers | 2 | 1.5 | `# ── C7:` |
| C8 | Action Buttons | DUAL: status change + flash per button | 4 | 3.0 | `# ── C8:` |

**Applicability**: C1, C2, C3, C8 always apply. C4-C7 where page has relevant content.

## Category Adaptation for Read-Only Pages

Pages with NO handle_event (read-only observability/portal pages):
- **C4**: Use timer refresh stability if timer exists, or page reload stability
- **C5**: Navigation (visit root → visit page), browser refresh maintaining state
- **C6**: Semantic CSS classes (bg-surface-primary, text-content-primary, border-border-theme-primary, color-coded spans)
- **C7**: Contextual reading (multi-dimension analysis, percentage interpretation)
- **C8**: `refute_has(css("button[phx-click]"))` + `refute_has(css("form[phx-submit]"))` — verify absence of unintended mutations

## File Conventions

```elixir
defmodule IndrajaalWeb.{Page}LiveWallabyTest do
  @moduledoc """
  ... 9-section @moduledoc (see gold standard template) ...

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Pending human review] -->
  ...
  <!-- END HUMAN-ONLY -->
  """
  use IndrajaalWeb.FeatureCase, async: false

  @moduletag :wallaby
  @path "/route/to/page"

  # ── C1: Page Structure ─────────────────────────────────────────
  feature "...", %{session: session} do ... end

  # ── C2: Status/Badge Display ───────────────────────────────────
  feature "...", %{session: session} do ... end

  # ... C3 through C8 ...
end
```

## Wallaby E2E Execution

```bash
# Run all Wallaby tests
test-e2e

# Run specific test file
WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_ENV=test mix test test/indrajaal_web/live/path_to_wallaby_test.exs --only wallaby
```

## Quality Gates

| Gate | Threshold | Constraint |
|------|-----------|-----------|
| Shannon entropy | H ≥ 2.5 bits per file | SC-MATH-COV-002, AOR-COV-012 |
| CCM weighted | ≥ 0.95 P0, ≥ 0.90 P1, ≥ 0.80 P2/P3 | SC-MATH-COV-003 |
| FMEA RPN coverage | ≥ 0.95 P0, ≥ 0.90 P1 | SC-MATH-COV-004 |
| D_EA divergence | ≤ 0.10 per file | SC-MATH-COV-006 |
| FSI self-similarity | ≥ 0.85 suite-wide | SC-MATH-COV-005 |
| ITQS overall | ≥ 0.85 system avg, ≥ 0.75 per file | SC-MATH-COV-007 |
| Feature count | P0≥30, P1≥20, P2≥15, P3≥10 | SC-COV-017/018 |
| C8 dual | Every action button: status + flash | SC-COV-016 |
| Source-first | Read .ex before writing selectors | AOR-COV-008, SC-COV-022 |
| Human intent | Section present, never modified | SC-HINT-001 to SC-HINT-008 |

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-COV-008 | Wallaby E2E for all LiveView pages |
| SC-COV-009–016 | 8-category gold standard per file |
| SC-COV-017 | P0 safety pages ≥ 30 features |
| SC-COV-018 | P1 interactive pages ≥ 20 features |
| SC-COV-021 | @moduledoc contains full page spec |
| SC-COV-022 | Page spec derived from .ex source (source-first) |
| SC-MATH-COV-001–008 | Mathematical quality gates |
| SC-HINT-001–008 | Human-Specified Intent protection |

## Reference Files
- Gold standard template: `.claude/rules/fractal-coverage-gold-standard.md`
- Mathematical framework: `.claude/rules/fractal-coverage-mathematical-framework.md`
- ITQS audit task: `lib/mix/tasks/wallaby_coverage_audit.ex`
- FeatureCase template: `test/support/feature_case.ex`
- Gold standard example: `test/indrajaal_web/live/operations/alarm_investigation_live_wallaby_test.exs`
