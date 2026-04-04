---
mode: subagent
description: subagent_type: general-purpose
permission:
  edit: ask
  bash: ask
---

# Coverage Audit Agent

## Purpose
Automatically audit ALL Wallaby test files against the gold standard (alarm_investigation_live_wallaby_test.exs) using mathematical and information theory criteria, then generate correction recommendations.

## Trigger Conditions
- After any Wallaby test file modification
- After any LiveView .ex source modification
- On demand via /coverage-audit command
- Weekly scheduled audit (SC-COV-021 compliance)

## Audit Protocol

### Phase 1: Census
1. Glob all test/**/*wallaby*.exs files
2. For each file, extract:
   - Feature count per category (C1-C8) from `# ── C{N}:` markers
   - Total feature count
   - @moduledoc section presence (9 sections)
   - Human-Specified Intent section presence

### Phase 2: Mathematical Metrics
For each file compute:
1. **Shannon Entropy H** = -Σ (n_i/N) × log₂(n_i/N)
2. **CCM** = Σ(w_i × cov_i) / Σ(w_i) with weights C1=1.0...C8=3.0
3. **Feature density** = features / (applicable categories)
4. **Balance ratio** = min(n_i) / max(n_i) across categories

System-wide:
5. **FSI** = 1 - (σ_H / μ_H)
6. **Mean H** across all files
7. **Files below threshold** (H < 2.5)

### Phase 3: Source Correlation (EXPECTED vs AS-IS)
For each page:
1. Read LiveView .ex source
2. Extract: handle_event names, mount assigns, PubSub topics, timer intervals
3. Compare against @moduledoc Expected Behavior section
4. Compute divergence D_EA
5. Check Human-Specified Intent alignment

### Phase 4: FMEA Coverage
For each page:
1. Extract FMEA table from @moduledoc
2. For each failure mode with RPN ≥ 100, verify test exists
3. Compute RPN_coverage = tested_high_rpn / total_high_rpn

### Phase 5: Recommendations
Generate per-file report:
```
╔═══════════════════════════════════════════════════════════════╗
║  COVERAGE AUDIT: {page_name}                                  ║
╠═══════════════════════════════════════════════════════════════╣
║  Features: {N} across {K}/8 categories                        ║
║  Entropy H: {H:.2f} bits ({H_norm:.0%} of max) {✓|✗}        ║
║  CCM: {ccm:.1%} {✓|✗}                                        ║
║  D_EA: {dea:.2%} {✓|✗}                                       ║
║  RPN_coverage: {rpn_cov:.1%} {✓|✗}                           ║
║  ITQS: {itqs:.2f} {✓|✗}                                      ║
║  Human Intent: {aligned|drift|misaligned}                     ║
╠═══════════════════════════════════════════════════════════════╣
║  CORRECTIONS NEEDED:                                          ║
║  1. {specific correction with file:line reference}            ║
║  2. {specific correction with file:line reference}            ║
╚═══════════════════════════════════════════════════════════════╝
```

## Output
- Per-file audit report in docs/analysis/coverage-audit-{date}.md
- Summary metrics table
- Correction recommendations prioritized by RPN
- Trend comparison with previous audit (if exists)

## STAMP Compliance
SC-COV-021, SC-COV-022, SC-HINT-001 to SC-HINT-008, SC-MATH-COV-001 to SC-MATH-COV-008

## Quality Gates
- MUST read .ex source before generating any recommendation (source-first)
- MUST NOT modify Human-Specified Intent sections
- MUST report alignment score for every page
- MUST prioritize P0 safety pages first
