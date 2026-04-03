---
paths: test/**/*wallaby*.exs, test/support/feature_case.ex
---

# Fractal Coverage Gold Standard Rules (SC-COV-009 to SC-COV-020)

## Overview

Every LiveView page's Wallaby E2E test MUST follow the gold standard pattern defined by
`alarm_investigation_live_wallaby_test.exs` (48 features, 8 categories, dual verification).

## The 8 Mandatory Test Categories (C1-C8)

| Cat | Name | Description | Min Features | Weight |
|-----|------|-------------|--------------|--------|
| C1 | Page Structure | Headings, navigation links, section presence | 2-4 | 1.0 |
| C2 | Status/Badge Display | Dynamic badges, severity indicators, state labels | 2-4 | 1.5 |
| C3 | Data Grid/Summary | Key-value data display, labels with values | 4-8 | 1.0 |
| C4 | Timeline/History | Ordered event entries, chronological data | 3-6 | 1.2 |
| C5 | Interactive Elements | Forms, textareas, submission with DOM change | 3-6 | 2.0 |
| C6 | Media/Rich Content | Video, charts, SVG, external links | 3-6 | 1.0 |
| C7 | AI/Advisory Panels | AI recommendations, confidence, disclaimers | 2-4 | 1.5 |
| C8 | Action Buttons | Each button: BOTH status change AND flash | 4-16 | 3.0 |

**Applicability**: C1, C2, C3, C8 apply to ALL pages. C4-C7 apply where the page has the relevant content.

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-COV-009 | C1 (Page Structure) coverage MANDATORY per Wallaby file | HIGH |
| SC-COV-010 | C2 (Status/Badge) coverage MANDATORY per Wallaby file | HIGH |
| SC-COV-011 | C3 (Data Grid) coverage MANDATORY per Wallaby file | HIGH |
| SC-COV-012 | C4 (Timeline/History) coverage MANDATORY where applicable | MEDIUM |
| SC-COV-013 | C5 (Interactive) coverage MANDATORY for form-bearing pages | HIGH |
| SC-COV-014 | C6 (Media) coverage MANDATORY for media-bearing pages | MEDIUM |
| SC-COV-015 | C7 (AI/Advisory) coverage MANDATORY for AI panels (SC-AI-001) | HIGH |
| SC-COV-016 | C8 (Actions) DUAL verification MANDATORY — status AND flash | CRITICAL |
| SC-COV-017 | Safety-critical page (P0) Wallaby file ≥ 30 features | CRITICAL |
| SC-COV-018 | Interactive page (P1) Wallaby file ≥ 20 features | HIGH |
| SC-COV-019 | Two-step commit pages require arm→confirm→cancel sequence | CRITICAL |
| SC-COV-020 | PubSub pages require refresh stability test (sleep + re-assert) | HIGH |
| SC-COV-021 | Wallaby @moduledoc MUST contain page spec (Design Intent, Expected Behavior, BDD, UX, UI Inventory, STAMP, FMEA) | HIGH |
| SC-COV-022 | Page spec MUST be derived from actual LiveView .ex source (source-first) | HIGH |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-COV-008 | Source-first selectors: Read LiveView .ex source BEFORE writing Wallaby selectors |
| AOR-COV-009 | Every action button in C8 MUST be tested twice (status badge + flash message) |
| AOR-COV-010 | Two-step commit flows MUST test all 3 states (idle→armed→executing/cancelled) |
| AOR-COV-011 | Wallaby tests MUST use `@moduletag :wallaby` and `async: false` |
| AOR-COV-012 | Coverage entropy H ≥ 2.5 bits per file (balanced categories, max 3.0) |
| AOR-COV-013 | New LiveView pages MUST include Wallaby test in same PR |
| AOR-COV-014 | FMEA-discovered bugs MUST have regression tests |
| AOR-COV-015 | PubSub topic changes MUST update corresponding Wallaby tests |
| AOR-COV-016 | @moduledoc MUST include: Page Identity, Design Intent, Expected Behavior, BDD Scenarios, UX Flow, UI Elements Inventory, STAMP, FMEA |
| AOR-COV-017 | Page spec sections MUST be extracted from actual .ex source (mount assigns, handle_event names, PubSub subs, timers) |

## Gold Standard Template

```elixir
defmodule IndrajaalWeb.{Namespace}.{Page}LiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for {Page} LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/namespace/page` (or `/namespace/page/:id`)
  - **Module**: `IndrajaalWeb.{Namespace}.{Page}Live`
  - **Title**: "{Page Title}"

  ## Design Intent
  [1-2 sentences: What this page enables the operator to do. What workflow it supports.]

  ## Expected Behavior (Functional)
  - **On mount**: [What mount/3 assigns — list key assigns from .ex source]
  - **handle_event "{event_name}"**: [What each event does + flash message]
  - **handle_info(:refresh)**: [Timer-driven refresh behavior, interval]
  - **PubSub**: [Topics subscribed in mount, e.g. "prajna:metrics"]

  ## BDD Scenarios
  ```gherkin
  Scenario: [Primary user journey]
    Given I navigate to "/namespace/page"
    When I [primary action]
    Then [expected outcome with badge/flash]
  ```

  ## UX Flow
  1. Operator navigates to page via [nav path]
  2. Page loads with [initial state]
  3. [Key interaction steps]
  N. Operator completes [goal]

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | [Name] | button | `button[phx-click='action']` | action | C8 |
  | [Name] | badge | `span.badge` | — | C2 |
  | [Name] | data | `p` with label text | — | C3 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit (gray defaults)
  - [Page-specific SC-* constraints from .ex source]

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | [Mode] | N | N | N | NNN | [Mitigation strategy] |

  STAMP: SC-COV-008 to SC-COV-022, AOR-COV-008 to AOR-COV-017
  """
  use IndrajaalWeb.FeatureCase, async: false
  @moduletag :wallaby
  @path "/route/to/page"

  # ── C1: Page Structure ─────────────────────────────────────────
  feature "page loads with main heading", %{session: session} do
    session |> visit(@path) |> assert_has(css("h1", text: "Heading"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────
  feature "status badge shows current state", %{session: session} do
    session |> visit(@path) |> assert_has(css("span.badge", text: "ACTIVE"))
  end

  # ── C3: Data Grid/Summary ──────────────────────────────────────
  feature "data grid shows key-value pairs", %{session: session} do
    session |> visit(@path) |> assert_has(css("p", text: "value"))
  end

  # ── C4: Timeline/History ───────────────────────────────────────
  feature "timeline shows ordered entries", %{session: session} do
    session |> visit(@path) |> assert_has(css("span", text: "EVENT_TYPE"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────
  feature "form submission updates DOM", %{session: session} do
    session |> visit(@path)
    |> fill_in(css("textarea[name='field']"), with: "test")
    |> click(css("button[type='submit']"))
    |> assert_has(css("span", text: "test"))
  end

  # ── C6: Media/Rich Content ─────────────────────────────────────
  feature "play button starts media", %{session: session} do
    session |> visit(@path) |> click(css("button[phx-click='play']"))
    |> assert_has(css("div", text: "Playing..."))
  end

  # ── C7: AI/Advisory Panels ─────────────────────────────────────
  feature "AI advisory disclaimer present (SC-AI-001)", %{session: session} do
    session |> visit(@path)
    |> assert_has(css("p", text: "AI suggestions are ADVISORY only"))
  end

  # ── C8: Action Buttons (DUAL verification) ─────────────────────
  # Test 1: Status change
  feature "clicking Action changes status badge", %{session: session} do
    session |> visit(@path)
    |> click(css("button[phx-click='action']"))
    |> assert_has(css("span", text: "NEW_STATUS"))
  end

  # Test 2: Flash message
  feature "clicking Action triggers flash", %{session: session} do
    session |> visit(@path)
    |> click(css("button[phx-click='action']"))
    |> assert_has(css("[role='alert']", text: "Action completed"))
  end
end
```

## Quality Gates Per File

1. Read LiveView .ex source first (AOR-COV-008)
2. Cover all applicable categories (C1-C8)
3. Feature count ≥ threshold: P0=30, P1=20, P2=15, P3=10
4. C8 dual verification for EVERY action button (AOR-COV-009)
5. Two-step sequences where applicable (AOR-COV-010)
6. Coverage entropy H ≥ 2.5 bits (AOR-COV-012)
7. Compilation check passes

## Coverage Entropy Formula

```
H = -Σ (features_in_Ci / total_features) × log2(features_in_Ci / total_features)

Maximum: log2(8) = 3.0 bits (perfectly uniform across 8 categories)
Minimum acceptable: 2.5 bits (83% of maximum)

Example — Gold standard (alarm_investigation):
  C1=8, C2=4, C3=8, C4=5, C5=3, C6=6, C7=4, C8=10 → H = 2.89 bits ✓

Example — Anti-pattern (biased file):
  C1=15, C2=5, C3=0, C4=0, C5=0, C6=0, C7=0, C8=0 → H = 0.72 bits ✗
```

## FMEA Findings Registry

| ID | File | RPN | Status |
|----|------|-----|--------|
| F-001 | stamp_tdg_gde_dashboard_live.ex | 192 | Needs connected? guard |
| F-002 | stamp_tdg_gde_dashboard_live.ex | 48 | Remove placeholder stub |
| F-003 | topology_live.ex | 175 | Add refresh timer |
| F-004 | prometheus_live.ex | 210 | Add PubSub subscription |
| F-005 | topology_live.ex | 120 | Fix flash in handle_info |
| F-006 | product_live.ex | 126 | Narrow try/rescue scope |
| F-007 | observability+startup+prajna | 80 | Stagger refresh intervals |

## Criticality-Based Execution Order

| Wave | Priority | Pages | Features | Agent Count |
|------|----------|-------|----------|-------------|
| W1 | P0 (Safety) | 8 | ~320 | 4 (sonnet) |
| W2 | P1 (Interaction) | 10 | ~280 | 4 (haiku) |
| W3 | P2 (Infrastructure) | 8 | ~200 | 2 (haiku) |
| W4 | P2 (Missing) | 10 | ~300 | 1 (haiku) |
| W5 | P3 (Admin) | 4 | ~80 | 1 (haiku) |

## Reference Documents

- Gold standard template: `test/indrajaal_web/live/operations/alarm_investigation_live_wallaby_test.exs`
- Plan: `doc/plans/20260328-1600-gold-standard-wallaby-all-pages.md`
- FMEA analysis: `docs/analysis/20260328-wallaby-gold-standard-fmea-analysis.md`
- Implementation matrix: `docs/analysis/20260328-wallaby-gold-standard-implementation-matrix.md`
- Journal: `docs/journal/20260328-1700-gold-standard-fractal-coverage-analysis.md`
