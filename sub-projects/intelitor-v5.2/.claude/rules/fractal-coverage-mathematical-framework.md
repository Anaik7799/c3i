---
paths: test/**/*wallaby*.exs
---

# Fractal Coverage Mathematical Framework (SC-MATH-COV)

## Overview

This rule establishes the formal mathematical foundations for fractal UI coverage
verification. All metrics defined here are computable from source files and test files
alone, with no external tooling required. Every formula maps directly to the 8-category
gold standard defined in `fractal-coverage-gold-standard.md`.

---

## 1. Fractal Coverage Tensor

The coverage tensor models every test obligation as a 3D binary space.

```
C[layer][depth][element] ∈ {0, 1}

Dimensions:
  layer   ∈ { L1-Structure, L2-Data, L3-Timeline, L4-Forms,
               L5-Media, L6-Actions, L7-AI/Advisory }
  depth   ∈ { state, structure, actions, timeline }
  element = each distinct UI component on the page

Coverage Completeness:
  CC = Σ C[l][d][e] / (|layers| × |depths| × |elements|) × 100%
```

Layer-to-category mapping (ties fractal tensor to gold-standard categories):

| Tensor Layer | Gold Standard Category | Weight |
|:-------------|:-----------------------|-------:|
| L1-Structure | C1 Page Structure      |    1.0 |
| L2-Data      | C2 Status/Badge + C3 Data Grid | 1.5 / 1.0 |
| L3-Timeline  | C4 Timeline/History    |    1.2 |
| L4-Forms     | C5 Interactive Elements |   2.0 |
| L5-Media     | C6 Media/Rich Content  |    1.0 |
| L6-Actions   | C8 Action Buttons      |    3.0 |
| L7-AI/Advisory | C7 AI/Advisory Panels |   1.5 |

### Depth axis semantics

| Depth Index | Meaning |
|:------------|:--------|
| state       | Assert visible state (badge text, assign value) |
| structure   | Assert DOM presence (element exists with selector) |
| actions     | Assert post-click state change |
| timeline    | Assert ordered-event or history-entry rendering |

A cell C[l][d][e] = 1 iff there exists at least one `feature` block in the Wallaby
test file that satisfies that obligation.

---

## 2. Shannon Coverage Entropy

Entropy measures whether test effort is balanced across all 8 categories.

```
H = -Σ (n_i / N) × log₂(n_i / N)    for i ∈ {C1, C2, …, C8}

Where:
  n_i = number of `feature` blocks assigned to category C_i
  N   = total `feature` blocks in the file
  (categories with n_i = 0 contribute 0 to the sum)

Bounds:
  H_max  = log₂(8) = 3.0 bits   (perfectly uniform across 8 categories)
  H_min  = 0 bits               (all features in one category)

Normalization:
  H_norm = H / H_max            (dimensionless ratio, 0.0–1.0)

Acceptance gate:
  H_norm ≥ 0.83  ↔  H ≥ 2.5 bits   (AOR-COV-012)
```

### Worked examples

```
Gold standard (alarm_investigation, 48 features):
  C1=8, C2=4, C3=8, C4=5, C5=3, C6=6, C7=4, C8=10
  p = [8,4,8,5,3,6,4,10]/48 = [0.167,0.083,0.167,0.104,0.063,0.125,0.083,0.208]
  H = 2.89 bits   H_norm = 0.96   PASS

Anti-pattern (C8-only bias):
  C1=0, C2=0, C3=0, C4=0, C5=0, C6=0, C7=0, C8=20
  H = 0 bits   H_norm = 0.00   FAIL
```

---

## 3. Coverage Completeness Metric (CCM)

CCM produces a single weighted score that accounts for the relative safety importance
of each category.

```
CCM = (Σ w_i × coverage_i) / (Σ w_i)    for i ∈ {C1, …, C8}

Where:
  w_i        = category weight (see table below)
  coverage_i = (features_in_Ci / expected_min_in_Ci)   clamped to [0, 1]

Category weights (gold standard):
  C1 = 1.0   C2 = 1.5   C3 = 1.0   C4 = 1.2
  C5 = 2.0   C6 = 1.0   C7 = 1.5   C8 = 3.0

Expected minimums per category (P0 page):
  C1 ≥ 2     C2 ≥ 2     C3 ≥ 4     C4 ≥ 3
  C5 ≥ 3     C6 ≥ 3     C7 ≥ 2     C8 ≥ 4

Acceptance gates:
  CCM ≥ 0.95  for P0 (safety-critical) pages     (SC-MATH-COV-003)
  CCM ≥ 0.90  for P1 (interactive) pages          (SC-MATH-COV-003)
  CCM ≥ 0.80  for P2/P3 (infrastructure/admin)
```

### Σ w_i denominator

The denominator is computed only over categories that apply to the target page
(C4, C5, C6, C7 are excluded from the denominator if the page has no applicable
content, per SC-COV-012 to SC-COV-015 applicability rules).

---

## 4. FMEA-Based Criticality Coverage (RPN_coverage)

Tests must be allocated proportionally to Risk Priority Number so the highest-risk
failure modes receive verification first.

```
FMEA RPN formula (standard):
  RPN_i = S_i × O_i × D_i

Where:
  S_i ∈ [1,10]  Severity of failure mode i
  O_i ∈ [1,10]  Likelihood of occurrence
  D_i ∈ [1,10]  Difficulty of detection (10 = undetectable)

Criticality coverage score:
  RPN_coverage = Σ (RPN_i × has_test_i) / Σ RPN_i

Where:
  has_test_i ∈ {0, 1}  — 1 iff at least one feature tests failure mode i

Acceptance gates (SC-MATH-COV-004):
  RPN_coverage ≥ 0.95  for P0 safety pages
  RPN_coverage ≥ 0.90  for P1 interactive pages

Prioritization rule:
  Sort failure modes descending by RPN_i.
  Write tests for the top-k modes such that cumulative RPN reaches threshold.
  This is the minimum-test-count path to compliance.
```

### Severity mapping (aligned with SC-FMEA-003)

| Priority | Severity band | S value |
|:---------|:--------------|--------:|
| P0-SAFETY | Critical      | 9–10    |
| P1-CORE   | High          | 7–8     |
| P2-DOMAIN | Medium        | 4–6     |
| P3-STYLE  | Low           | 1–3     |

---

## 5. Fractal Self-Similarity Index (FSI)

A healthy test suite has similar entropy distributions across all pages. Pages
should not diverge significantly in coverage pattern.

```
FSI = 1 - (σ_H / μ_H)

Where:
  σ_H = standard deviation of H across all Wallaby test files in the suite
  μ_H = mean entropy across all Wallaby test files in the suite
  (files with fewer than 10 features are excluded from the FSI calculation)

FSI ∈ (-∞, 1.0]   (values above 0 indicate positive similarity)

Acceptance gate:
  FSI ≥ 0.85  (files should have coherent, similar coverage patterns)
              (SC-MATH-COV-005)

Interpretation:
  FSI = 1.0   Perfect self-similarity — all files have identical entropy
  FSI = 0.85  ≤15% coefficient of variation in entropy — acceptable
  FSI < 0.70  High structural divergence — audit required
  FSI < 0.50  Critical disorder — suite-wide remediation required
```

---

## 6. EXPECTED vs AS-IS Divergence (D_EA)

Before writing Wallaby tests, the agent MUST derive the expected UI element set from
the LiveView .ex source (AOR-COV-008, SC-COV-022). This metric measures how closely
the test file matches that source-derived intent.

```
D_EA = |F_expected \ F_implemented| / |F_expected|

Where:
  F_expected     = set of UI elements / interactions derived from .ex source
                   (mount assigns, handle_event names, PubSub subs, timers, buttons)
  F_implemented  = set of elements/interactions verified in the Wallaby test file
  F_expected \ F_implemented = elements in expected set but NOT tested (gap set)

D_EA ∈ [0.0, 1.0]
  D_EA = 0.0  Perfect — every expected element is tested
  D_EA = 0.1  10% gap — maximum acceptable divergence (SC-MATH-COV-006)
  D_EA > 0.1  FAIL — missing coverage requires additional `feature` blocks

Acceptance gate:
  D_EA ≤ 0.10   (SC-MATH-COV-006)
```

### Source-derivation protocol (how to compute F_expected)

1. Read the LiveView module's `mount/3` — collect all `assign` keys as data elements.
2. Read all `handle_event` clauses — each event name becomes an action element.
3. Read `handle_info` clauses for timer-driven refresh events.
4. Read PubSub `subscribe` calls — each topic is a dynamic-data element.
5. Read the HEEx template — every `phx-click`, `phx-submit`, `phx-change` binding
   is an interactive element; every status badge class is a state element.
6. |F_expected| = count of distinct elements from steps 1-5.

---

## 7. Information-Theoretic Quality Score (ITQS)

ITQS aggregates all five metrics into a single file-level and suite-level quality
signal.

```
ITQS = α × H_norm + β × CCM + γ × (1 - D_EA) + δ × FSI

Coefficients (sum to 1.0):
  α = 0.25   (Shannon entropy — balance)
  β = 0.35   (CCM — weighted completeness, highest weight)
  γ = 0.25   (1 - D_EA — source alignment)
  δ = 0.15   (FSI — self-similarity)

ITQS ∈ [0.0, 1.0]

Acceptance gate:
  ITQS ≥ 0.85  system-wide (averaged over all Wallaby files)  (SC-MATH-COV-007)

Per-file minimum:
  ITQS ≥ 0.75  per individual file before it is considered complete

Grade mapping:
  A: ITQS ≥ 0.90   Gold standard
  B: ITQS ≥ 0.85   Compliant
  C: ITQS ≥ 0.75   Needs improvement
  D: ITQS < 0.75   Non-compliant — blocked from merge
```

### Worked example (alarm_investigation_live_wallaby_test.exs)

```
H_norm  = 0.96   CCM = 0.98   D_EA = 0.03   FSI = 0.92 (suite value)

ITQS = 0.25×0.96 + 0.35×0.98 + 0.25×(1-0.03) + 0.15×0.92
     = 0.240 + 0.343 + 0.243 + 0.138
     = 0.964   Grade A
```

---

## 8. Metric Computation Order

When auditing a Wallaby test file, compute metrics in this sequence:

```
Step 1 → Derive F_expected from .ex source        (AOR-COV-008)
Step 2 → Categorize each `feature` block → C1-C8  (AOR-COV-012)
Step 3 → Compute H and H_norm                     (SC-MATH-COV-002)
Step 4 → Compute CCM                              (SC-MATH-COV-003)
Step 5 → Compute RPN_coverage from FMEA registry  (SC-MATH-COV-004)
Step 6 → Compute D_EA = gap / |F_expected|         (SC-MATH-COV-006)
Step 7 → Compute FSI across suite                  (SC-MATH-COV-005)
Step 8 → Compute ITQS                             (SC-MATH-COV-007)
Step 9 → Accept if all gates pass; else add tests
```

---

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-MATH-COV-001 | Coverage tensor C[l][d][e] MUST be computed for every page | HIGH |
| SC-MATH-COV-002 | Shannon entropy H ≥ 2.5 bits (H_norm ≥ 0.83) per test file | HIGH |
| SC-MATH-COV-003 | CCM ≥ 0.95 for P0 pages, ≥ 0.90 for P1 pages | HIGH |
| SC-MATH-COV-004 | FMEA RPN_coverage ≥ 0.95 for safety-critical pages | CRITICAL |
| SC-MATH-COV-005 | Fractal Self-Similarity Index FSI ≥ 0.85 suite-wide | MEDIUM |
| SC-MATH-COV-006 | EXPECTED vs AS-IS divergence D_EA ≤ 0.10 per file | HIGH |
| SC-MATH-COV-007 | ITQS ≥ 0.85 system-wide (averaged over all Wallaby files) | HIGH |
| SC-MATH-COV-008 | All metrics MUST be recomputable from source + test files alone | HIGH |

---

## AOR Rules

| ID | Rule |
|----|------|
| AOR-MATH-COV-001 | Compute coverage tensor on every new page audit before writing tests |
| AOR-MATH-COV-002 | Verify entropy H ≥ 2.5 bits after every test file modification |
| AOR-MATH-COV-003 | Use FMEA RPN ranking to prioritize test writing order for new pages |
| AOR-MATH-COV-004 | Run D_EA divergence check before marking any page complete |
| AOR-MATH-COV-005 | If ITQS < 0.75, add features to lowest-scoring category first |
| AOR-MATH-COV-006 | FSI computation MUST exclude files with fewer than 10 features |
| AOR-MATH-COV-007 | CCM denominator MUST exclude non-applicable categories (C4-C7) |
| AOR-MATH-COV-008 | Publish ITQS per-file score in test file @moduledoc FMEA section |

---

## Relationship to Existing Rules

| This document | Related rule | Relationship |
|:--------------|:-------------|:-------------|
| H / H_norm | AOR-COV-012 (fractal-coverage-gold-standard.md) | Formalizes the H ≥ 2.5 gate |
| CCM weights | C1-C8 table (fractal-coverage-gold-standard.md) | Same weights, scalar form |
| RPN_coverage | FMEA Findings Registry (fractal-coverage-gold-standard.md) | Quantifies registry |
| D_EA | AOR-COV-008, SC-COV-022 | Formalizes source-first mandate |
| ITQS | SC-COV-006 (Ω₃ Zero-Defect gate) | Overall quality gate |
| FSI | SC-HMI-011 (8×8 matrix coverage) | Self-similarity across 8 layers |

---

## Reference Documents

- Gold standard: `.claude/rules/fractal-coverage-gold-standard.md`
- COV constraints: CLAUDE.md §5.0 SC-COV-001 to SC-COV-022
- FMEA methodology: `.claude/rules/reconciled-p2-domain-critical.md`
- Mathematical disciplines: SC-MATH-001 to SC-MATH-004 (CLAUDE.md)
- Information theory baseline: constraint-sync-mandatory.md §8.0 (KL, H, MI reference)
