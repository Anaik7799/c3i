# Wallaby E2E Coverage — Patterns, Insights & Reference Guide

**Date**: 20260328-1815 CEST
**Author**: Claude Opus 4.6
**Purpose**: Permanent reference for future Wallaby test development
**STAMP**: SC-COV-008 to SC-COV-020

---

## 1. Gold Standard Pattern (Canonical)

Every Wallaby E2E test file MUST follow this structure. This is the pattern discovered and validated through the alarm_investigation gold standard (48 features, H=2.89 bits).

```elixir
defmodule IndrajaalWeb.{Namespace}.{Page}LiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for {Page} LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  Coverage: {N} features across {M}/8 categories
  Entropy: H = {X.XX} bits (target ≥ 2.5)
  STAMP: SC-COV-008, SC-COV-009 to SC-COV-016
  """
  use IndrajaalWeb.FeatureCase, async: false
  @moduletag :wallaby
  @path "/route/to/page"

  # ── C1: Page Structure ─────────────────────────────────────────
  # Test: h1 heading, navigation breadcrumbs, section presence
  # Min features: 2-4

  feature "page loads with main heading", %{session: session} do
    session |> visit(@path) |> assert_has(css("h1", text: "Page Title"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────
  # Test: dynamic badges, severity indicators, state labels
  # Min features: 2-4

  feature "status badge shows current state", %{session: session} do
    session |> visit(@path) |> assert_has(css("span.badge", text: "ACTIVE"))
  end

  # ── C3: Data Grid/Summary ──────────────────────────────────────
  # Test: key-value data display, table rows, labels with values
  # Min features: 4-8

  feature "data grid shows key-value pairs", %{session: session} do
    session |> visit(@path)
    |> assert_has(css("dt", text: "Label"))
    |> assert_has(css("dd", text: "Value"))
  end

  # ── C4: Timeline/History ───────────────────────────────────────
  # Test: ordered events, audit trail, chronological entries
  # Min features: 3-6

  feature "timeline shows ordered entries", %{session: session} do
    session |> visit(@path) |> assert_has(css("li", text: "Event"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────
  # Test: forms, textareas, selects, checkboxes with DOM mutation
  # Min features: 3-6

  feature "form submission updates DOM", %{session: session} do
    session |> visit(@path)
    |> fill_in(css("textarea[name='field']"), with: "test value")
    |> click(css("button[type='submit']"))
    |> assert_has(css("span", text: "test value"))
  end

  # ── C6: Media/Rich Content ─────────────────────────────────────
  # Test: video, charts, SVG, external links, downloads
  # Min features: 3-6 (only if page has media)

  feature "chart renders with data", %{session: session} do
    session |> visit(@path) |> assert_has(css("svg.chart"))
  end

  # ── C7: AI/Advisory Panels ─────────────────────────────────────
  # Test: AI recommendations, confidence levels, SC-AI-001 disclaimer
  # Min features: 2-4 (only if page has AI panel)

  feature "AI advisory disclaimer present (SC-AI-001)", %{session: session} do
    session |> visit(@path)
    |> assert_has(css("p", text: "AI suggestions are ADVISORY only"))
  end

  # ── C8: Action Buttons (DUAL verification) ─────────────────────
  # Test: EVERY button TWICE — once for status change, once for flash
  # Min features: 4-16
  # CRITICAL: SC-COV-016 requires both assertions per button

  # Button: "action_name" — Status change
  feature "clicking action changes status badge", %{session: session} do
    session |> visit(@path)
    |> click(css("button[phx-click='action_name']"))
    |> assert_has(css("span.badge", text: "NEW_STATUS"))
  end

  # Button: "action_name" — Flash message
  feature "clicking action triggers flash", %{session: session} do
    session |> visit(@path)
    |> click(css("button[phx-click='action_name']"))
    |> assert_has(css("[role='alert']", text: "Action completed"))
  end
end
```

---

## 2. UI Element Testing Standard (100% Coverage)

### 2.1 Element Coverage Matrix

For EVERY UI element type, test across 4 dimensions:

| Dimension | What to Test | Example Assertion |
|-----------|-------------|-------------------|
| **Structure** | Element exists in DOM | `assert_has(css("button.primary"))` |
| **Content** | Correct text/value | `assert_has(css("span", text: "ACTIVE"))` |
| **State** | Transitions correctly | Click → assert new state |
| **Timeline** | Temporal behavior | Sleep past interval → re-assert |

### 2.2 Per-Element Type Requirements

#### Headings (h1-h6)
```elixir
# Structure: present
assert_has(css("h1"))
# Content: correct text
assert_has(css("h1", text: "Expected Title"))
# State: visible on load (implicit)
# Timeline: stable after PubSub refresh
```

#### Badges/Status Indicators
```elixir
# Structure: badge element with class
assert_has(css("span.badge"))
# Content: correct status text
assert_has(css("span.badge", text: "ACTIVE"))
# State: changes on event
click(css("button[phx-click='change_status']"))
assert_has(css("span.badge", text: "INACTIVE"))
# Timeline: updates on PubSub
Process.sleep(2000); assert_has(css("span.badge"))
```

#### Action Buttons (DUAL VERIFICATION)
```elixir
# Structure: button with phx-click
assert_has(css("button[phx-click='action']"))
# Content: button label correct
assert_has(css("button[phx-click='action']", text: "Do Action"))
# State → STATUS: clicking changes status
click(css("button[phx-click='action']"))
assert_has(css("span.badge", text: "DONE"))
# State → FLASH: clicking shows flash
click(css("button[phx-click='action']"))
assert_has(css("[role='alert']", text: "Action completed"))
# Timeline: button disabled during processing (if applicable)
```

#### Form Inputs
```elixir
# Structure: input element present
assert_has(css("input[name='field']"))
# Content: placeholder/default value
assert_has(css("input[placeholder='Enter value']"))
# State: submission triggers DOM change
fill_in(css("input[name='field']"), with: "test")
click(css("button[type='submit']"))
assert_has(css("span", text: "test"))
# Timeline: validation on blur/submit
fill_in(css("input[name='field']"), with: "")
click(css("button[type='submit']"))
assert_has(css("span.error", text: "required"))
```

#### Tables/Data Grids
```elixir
# Structure: table with headers
assert_has(css("table thead th", text: "Column"))
# Content: rows with data
assert_has(css("table tbody td", text: "Value"))
# State: sort/filter changes order
click(css("th[phx-click='sort']"))
# Timeline: data refreshes on PubSub
Process.sleep(2000); assert_has(css("table tbody tr"))
```

#### Tabs
```elixir
# Structure: tab buttons present
assert_has(css("button[phx-value-tab='tab1']"))
# Content: correct tab label
assert_has(css("button[phx-value-tab='tab1']", text: "Tab 1"))
# State: clicking switches content
click(css("button[phx-value-tab='tab2']"))
assert_has(css("#tab2-content"))
# Timeline: tab state preserved after refresh
```

---

## 3. Mathematical Framework

### 3.1 Coverage Completeness Metric (CCM)

```
CCM = (Σ covered_categories across all files) / (C_max × N_pages) × 100%

Where:
  C_max = 8 (max categories)
  N_pages = 46 (total LiveView pages)
  covered_categories = count of C1-C8 headers per file

Example:
  41 files, avg 6.2 categories = 254 covered
  CCM = 254 / (8 × 46) × 100% = 69%
  Target: CCM ≥ 95%
```

### 3.2 Shannon Coverage Entropy (H)

```
H = -Σ (features_in_Ci / total_features) × log2(features_in_Ci / total_features)

Maximum: H_max = log2(8) = 3.0 bits (perfectly uniform across 8 categories)
Threshold: H ≥ 2.5 bits (83% of maximum)

Interpretation:
  H = 3.0: Perfect balance — each category has exactly 1/8 of features
  H = 2.5: Good balance — most categories represented, slight skew
  H = 2.0: Moderate skew — 2-3 categories dominate
  H = 1.0: Heavy skew — one category has most features
  H = 0.0: Degenerate — all features in one category
```

### 3.3 Risk-Weighted Coverage (RWC)

```
RWC = Σ(coverage_i × rpn_i) / Σ(rpn_i) × 100%

Where:
  coverage_i = features_i / target_i for page i
  rpn_i = Severity × Occurrence × Detection for page i

RPN scoring:
  P0 safety pages: Severity=9, Occurrence=5, Detection=3 → RPN=135
  P1 interactive:  Severity=7, Occurrence=5, Detection=3 → RPN=105
  P2 infrastructure: Severity=5, Occurrence=3, Detection=5 → RPN=75
  P3 admin: Severity=3, Occurrence=3, Detection=3 → RPN=27
```

### 3.4 Fractal Self-Similarity Index (FSSI)

```
FSSI = 1 - σ(coverage_per_category) / μ(coverage_per_category)

Where:
  coverage_per_category = [avg_C1, avg_C2, ..., avg_C8] across all files
  σ = standard deviation
  μ = mean

FSSI = 1.0: All categories have identical coverage (perfect fractal)
FSSI = 0.0: Maximum variance between categories
Target: FSSI ≥ 0.75
```

### 3.5 Fractal Dimension (D_f)

```
D_f = log(N_features) / log(N_categories)

This measures the "roughness" of coverage distribution.
  D_f = 1.0: Linear (features = categories)
  D_f = 1.5-2.5: Good fractal structure
  D_f > 3.0: Over-saturated (too many features per category)
```

### 3.6 Information-Theoretic Completeness

```
Coverage as information: Each tested UI element reduces uncertainty.
  I(test) = log2(1/p_failure) bits

For a page with N elements and K tested:
  Mutual Information I(X;Y) = H(page) - H(page|tests)
  Where H(page) = log2(N) and H(page|tests) = log2(N-K)

  100% coverage: I(X;Y) = H(page), meaning tests capture all information about the page
```

---

## 4. Key Insights & Learnings

### Insight 1: Entropy > Count
A file with 48 features all in C1 (H=0) is WORSE than a file with 25 features across 7 categories (H≈2.7). Feature count is necessary but not sufficient. Entropy measures test diversity — the true indicator of coverage quality.

### Insight 2: Source-First Prevents Brittleness
Reading the LiveView .ex source before writing selectors (AOR-COV-008) eliminates the #1 cause of flaky tests: selectors that don't match the actual DOM. The HEEx template is truth; the test must follow it.

### Insight 3: Dual Verification Catches Silent Failures
Testing only status badge change misses cases where the flash message fails (or vice versa). Dual verification (SC-COV-016) catches bugs where one feedback channel works but another doesn't — a common failure mode in LiveView where handle_event might update assigns but forget put_flash.

### Insight 4: Two-Step Commit is a State Machine
Pages with SC-SAFETY-001 compliance aren't just "click button, check result". They're state machines with 3+ states (idle → armed → executing/cancelled). Testing only the happy path (idle → armed → executing) misses the escape hatch (arm → cancel), which is arguably the most critical safety feature.

### Insight 5: PubSub Refresh is a Timing Bug Amplifier
Pages that auto-refresh via PubSub (`handle_info`) can have timing-dependent bugs that pass in unit tests but fail in E2E. The stability test pattern (visit → assert → sleep past interval → re-assert) catches these by forcing the test through a refresh cycle.

### Insight 6: Category Markers Enable Automation
Without `── C{N}` comment headers, entropy can't be computed automatically. The markers transform test files from opaque code into structured, measurable artifacts. This is the foundation for the `mix wallaby_coverage_audit` task.

### Insight 7: FMEA-Driven Prioritization
Not all pages are equal. FMEA RPN scoring (Severity × Occurrence × Detection) creates a natural execution order: safety-critical pages (P0, RPN=135) get gold standard first, admin dashboards (P3, RPN=27) last. This maximizes risk reduction per development hour.

### Insight 8: Fractal Self-Similarity Enables Scale
When every test file follows the same 8-category structure, adding a new page is a O(1) cognitive task — copy the template, fill in selectors from the LiveView source. Without self-similarity, each new test requires understanding a unique structure, which is O(n) cognitive load.

---

## 5. Common Selector Patterns

### LiveView Button Actions
```elixir
# Standard phx-click
css("button[phx-click='action_name']")

# Button with phx-value
css("button[phx-click='select'][phx-value-id='123']")

# Submit button in form
css("button[type='submit']")

# Button by text content
css("button", text: "Click Me")
```

### LiveView Tab Switching
```elixir
# Tab by value
css("button[phx-value-tab='metrics']")
css("a[phx-click='change_tab'][phx-value-tab='traces']")
```

### Flash Messages
```elixir
# Standard flash container
css("[role='alert']")
css("[role='alert']", text: "Success message")

# Phoenix flash by level
css(".flash-info", text: "Info message")
css(".flash-error", text: "Error message")
```

### Data Display
```elixir
# Key-value pairs
css("dt", text: "Label")
css("dd", text: "Value")

# Table cells
css("td", text: "Cell Value")
css("th", text: "Header")

# Badge/status
css("span.badge", text: "ACTIVE")
css("span", text: "Status: OK")
```

### Forms
```elixir
# Text input
fill_in(css("input[name='field_name']"), with: "value")

# Textarea
fill_in(css("textarea[name='notes']"), with: "some text")

# Select dropdown (Wallaby)
find(session, css("select[name='option']"))
|> click(css("option[value='choice']"))

# Checkbox
click(css("input[type='checkbox'][name='agree']"))
```

---

## 6. Anti-Pattern Catalog

### Anti-Pattern 1: Selector Guessing
```elixir
# BAD: Guessing class names
assert_has(css(".my-custom-button"))  # Might not exist in HEEx

# GOOD: Read source first, use phx-click
assert_has(css("button[phx-click='do_action']"))  # Matches LiveView code
```

### Anti-Pattern 2: Single-Effect Testing
```elixir
# BAD: Only testing one effect of a button
feature "clicking button changes status", %{session: session} do
  session |> visit(@path) |> click(css("button[phx-click='act']"))
  |> assert_has(css("span", text: "DONE"))
end
# Missing: flash message verification

# GOOD: Dual verification
feature "clicking button changes status", %{session: session} do
  session |> visit(@path) |> click(css("button[phx-click='act']"))
  |> assert_has(css("span", text: "DONE"))
end
feature "clicking button shows flash", %{session: session} do
  session |> visit(@path) |> click(css("button[phx-click='act']"))
  |> assert_has(css("[role='alert']", text: "Action completed"))
end
```

### Anti-Pattern 3: Feature Count Inflation
```elixir
# BAD: Trivial tests to inflate count
feature "body exists", %{session: session} do
  session |> visit(@path) |> assert_has(css("body"))
end
feature "html exists", %{session: session} do
  session |> visit(@path) |> assert_has(css("html"))
end

# GOOD: Each feature tests meaningful behavior
feature "alarm severity badge shows critical", %{session: session} do
  session |> visit(@path)
  |> assert_has(css("span.badge-critical", text: "CRITICAL"))
end
```

### Anti-Pattern 4: Ignoring Two-Step
```elixir
# BAD: Testing destructive action as single click
feature "shutdown works", %{session: session} do
  session |> visit(@path) |> click(css("button[phx-click='shutdown']"))
end

# GOOD: Full arm → confirm/cancel state machine
feature "arm then confirm executes shutdown", %{session: session} do
  session |> visit(@path)
  |> click(css("button[phx-click='arm_shutdown']"))
  |> assert_has(css("span", text: "ARMED"))
  |> click(css("button[phx-click='confirm_shutdown']"))
  |> assert_has(css("span", text: "SHUTTING_DOWN"))
end
feature "arm then cancel aborts shutdown", %{session: session} do
  session |> visit(@path)
  |> click(css("button[phx-click='arm_shutdown']"))
  |> assert_has(css("span", text: "ARMED"))
  |> click(css("button[phx-click='cancel_shutdown']"))
  |> assert_has(css("span", text: "IDLE"))
end
```

---

## 7. Priority Classification (FMEA-Based)

| Priority | Pages | Severity | RPN Range | Min Features | Min Categories |
|----------|-------|----------|-----------|--------------|----------------|
| P0 | Commands, Shutdown, Guardian, Alarms, Threat, Cluster, ActiveAlarms, AccessDashboard | 9 | 100-210 | 30 | 6+ |
| P1 | Settings, Diagnostics, TestCockpit, Dispatch, VideoWall, Copilot, Knowledge, Sentinel, Analytics, Compliance | 7 | 75-105 | 20 | 5+ |
| P2 | Containers, Devices, Mesh, Startup, Observability, Register, GitIntelligence, GuardianDashboard, Topology, Prometheus, HealthSparkline, ZenohMeshHealth, Prajna, SystemStatus, ConfigManagement, Knowledge.Developer/Product/SRE | 5 | 40-75 | 15 | 4+ |
| P3 | StampTdgGde, NavigationPortal, MonitoringDashboard, PerformanceDashboard, AccessControlMonitoring, PermissionsManagement | 3 | 10-40 | 10 | 3+ |

---

## 8. Continuous Monitoring

### Automated Audit
```bash
# Run coverage audit
mix wallaby_coverage_audit

# Summary only
mix wallaby_coverage_audit --summary

# Single file audit
mix wallaby_coverage_audit --file commands

# JSON output for CI/CD
mix wallaby_coverage_audit --json

# With correction recommendations
mix wallaby_coverage_audit --fix
```

### CI/CD Integration
```yaml
# In CI pipeline
- name: Wallaby Coverage Audit
  run: |
    mix wallaby_coverage_audit --json > coverage_audit.json
    # Fail if CCM < 90% or any P0 page below threshold
    jq '.ccm < 90 or (.pages[] | select(.priority == "P0" and .features < 30))' coverage_audit.json
```

### Quality Gates (Per PR)
1. `mix wallaby_coverage_audit --summary` shows no regressions
2. New LiveView pages MUST include Wallaby test (AOR-COV-013)
3. Feature count meets priority threshold
4. Coverage entropy H ≥ 2.5 bits
5. C8 dual verification for all new buttons

---

## 9. Reference Links

| Document | Path | Content |
|----------|------|---------|
| Gold standard rules | `.claude/rules/fractal-coverage-gold-standard.md` | 8-category spec, SC-COV-009 to SC-COV-020 |
| Five-level testing | `.claude/rules/five-level-testing.md` | All 6 test levels including Wallaby |
| FMEA analysis | `docs/analysis/20260328-wallaby-gold-standard-fmea-analysis.md` | Findings F-001 to F-007, PubSub map |
| Implementation matrix | `docs/analysis/20260328-wallaby-gold-standard-implementation-matrix.md` | Per-page plan, wave strategy |
| Sprint journal | `docs/journal/20260328-1800-100pct-fractal-wallaby-coverage-sprint.md` | Full 13-section retrospective |
| Master plan | `doc/plans/20260328-1600-gold-standard-wallaby-all-pages.md` | Original plan document |
| Gold standard template | `test/indrajaal_web/live/operations/alarm_investigation_live_wallaby_test.exs` | Reference implementation |
| FeatureCase | `test/support/feature_case.ex` | Wallaby case template |
| Page objects | `test/support/wallaby_page_objects.ex` | 23+ page modules |
