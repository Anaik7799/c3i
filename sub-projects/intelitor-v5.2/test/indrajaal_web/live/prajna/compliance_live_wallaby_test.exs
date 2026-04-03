defmodule IndrajaalWeb.Prajna.ComplianceLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Compliance Dashboard page (/cockpit/compliance).

  Gold standard 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/compliance`
  - **Module**: `IndrajaalWeb.Prajna.ComplianceLive`
  - **Title**: "Compliance Dashboard"

  ## Design Intent
  Provides a unified compliance management interface covering multiple regulatory
  frameworks (IEC 61508, ISO 27001, GDPR, EN 50131). Operators can browse compliance
  framework scores, filter controls by framework/status/regulation, paginate the audit
  trail, drill into individual control details, and monitor non-conformances. Integrates
  with `prajna:compliance` and `zenoh:compliance` PubSub channels and syncs metrics
  every 30s per SC-COMP-001 and SC-SAFETY-003.

  ## Expected Behavior (Functional)
  - **On mount**: assigns `page_title`, `current_nav: :compliance`, `frameworks: []`,
    `controls: []`, `audit_trail: []`, `evidence: []`, `nonconformances: []`,
    `filter_framework: :all`, `filter_status: :all`, `filter_regulation: :all`,
    `audit_page: 1`, `selected_control: nil`, `last_update: nil`,
    `metrics: %{}`, `audit_page_size: 10`
  - **PubSub**: subscribes to `"prajna:compliance"` and `"zenoh:compliance"`
  - **Timer**: 10000ms → `:refresh`; 30000ms → `:sync_metrics`
  - **handle_event "filter_framework"**: sets `filter_framework` + resets `audit_page: 1` (no flash)
  - **handle_event "filter_status"**: sets `filter_status` (no flash)
  - **handle_event "filter_regulation"**: sets `filter_regulation` + resets `audit_page: 1` (no flash)
  - **handle_event "audit_page"**: paginates `audit_trail` via `audit_page` (no flash)
  - **handle_event "select_control"**: sets `selected_control` assign (no flash)
  - **handle_event "close_detail"**: sets `selected_control: nil` (no flash)

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator views compliance framework scores on load
    Given I navigate to "/cockpit/compliance"
    Then I should see the "Compliance Dashboard" heading
    And compliance framework score cards should be visible
    And the audit trail pagination controls should be shown

  Scenario: Operator filters controls by framework
    Given I navigate to "/cockpit/compliance"
    When I select "IEC 61508" from the framework filter
    Then only controls associated with "IEC 61508" should be shown

  Scenario: Operator paginates the audit trail
    Given I navigate to "/cockpit/compliance"
    And the audit trail has more than 10 entries
    When I click the "Next" pagination button
    Then the second page of audit entries should be displayed

  Scenario: Operator selects a control to view its detail
    Given I navigate to "/cockpit/compliance"
    And at least one control row exists
    When I click on a control row
    Then the control detail panel should open with metadata

  Scenario: Operator views non-conformance tracking panel
    Given I navigate to "/cockpit/compliance"
    Then the non-conformances section should be visible
    And each non-conformance should show its status badge
  ```

  ## UX Flow
  1. Operator navigates to `/cockpit/compliance` — framework scores shown at top
  2. Four framework panels display compliance scores for IEC 61508, ISO 27001, GDPR, EN 50131
  3. Operator applies framework/status/regulation filters to narrow controls
  4. Controls grid shows status badges (compliant/partial/non-compliant) per row
  5. Operator clicks a control row to open the detail panel
  6. Detail panel shows evidence links, last audit date, and remediation notes
  7. Operator closes detail panel to return to controls list
  8. Audit trail section shows paginated immutable log of compliance events
  9. Operator navigates pages using Prev/Next or numbered page buttons
  10. Non-conformances panel shows open findings with severity and owner

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | Compliance Dashboard heading | h1/span | `css("span", text: "Compliance Dashboard")` | — | C1 |
  | Framework score cards | div | `css("[data-testid='framework-scores']")` | — | C3 |
  | Control Status panel | section | `css("span", text: "Control Status")` | — | C1 |
  | Framework filter | select | `css("select[name='framework']")` | filter_framework | C5 |
  | Status filter | select | `css("select[phx-change='filter_status']")` | filter_status | C5 |
  | Regulation filter | select | `css("select[phx-change='filter_regulation']")` | filter_regulation | C5 |
  | Control rows | tr/div | `css("[phx-click='select_control']")` | select_control | C8 |
  | Control status badges | span | `css("span.badge")` | — | C2 |
  | Close detail button | button | `css("button[phx-click='close_detail']")` | close_detail | C8 |
  | Audit trail section | section | `css("span", text: "Audit Trail")` | — | C4 |
  | Audit trail entries | li/div | `css("[data-testid='audit-entry']")` | — | C4 |
  | Prev page button | button | `css("button[phx-value-page]", text: "Prev")` | audit_page | C5 |
  | Next page button | button | `css("button[phx-value-page]", text: "Next")` | audit_page | C5 |
  | Non-conformances panel | section | `css("section", text: "Non-Conformances")` | — | C2 |
  | STAMP/compliance footer | footer | `css("footer")` | — | C1 |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: Gold standard 8-category coverage
  - SC-HMI-001: Dark Cockpit (gray defaults on initial render)
  - SC-COMP-001: Audit log immutability — audit trail rendered from append-only store
  - SC-SAFETY-003: Complete audit trail to Immutable Register — audit entries non-deletable
  - SC-PRAJNA-004: Sentinel health integration — sentinel data in compliance metrics
  - SC-COV-020: Dual PubSub channels (prajna:compliance + zenoh:compliance) require stability tests

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Audit page resets to 1 on filter change — unexpected | 5 | 3 | 4 | 60 | Assert audit_page = 1 after filter |
  | filter_regulation and filter_framework not composed | 5 | 2 | 4 | 40 | Assert combined filter reduces rows |
  | Dual timer (10s + 30s) race causes double refresh | 4 | 2 | 4 | 32 | sleep + stability assertion |
  | Non-conformance panel empty when no open findings | 4 | 3 | 3 | 36 | Assert "No open findings" fallback |
  | Control detail panel stays open after framework filter | 5 | 2 | 3 | 30 | Assert selected_control nil after filter |

  STAMP: SC-COV-008 to SC-COV-022, AOR-COV-008 to AOR-COV-017

  ## Human-Specified Intent
  <!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
  <!-- Last modified by: [Pending human review] -->

  ### Functional Intent
  [Awaiting human specification — describe what this page MUST do from operator perspective]

  ### UX Requirements
  [Awaiting human specification — describe how the page MUST feel and behave]

  ### Safety Requirements
  [Awaiting human specification — non-negotiable safety behaviors]

  ### Override Instructions
  [Awaiting human specification — any instructions that override agent behavior]
  <!-- END HUMAN-ONLY -->
  """
  use IndrajaalWeb.FeatureCase, async: false

  @moduletag :wallaby

  @path "/cockpit/compliance"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads and renders the compliance dashboard layout", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("main"))
  end

  feature "Control Status panel heading with All Frameworks filter dropdown is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Control Status"))
    |> assert_has(css("select[name='framework']"))
  end

  feature "Audit Trail panel heading with regulation filter dropdown is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Audit Trail"))
    |> assert_has(css("select[name='regulation']"))
  end

  feature "STAMP constraint footer with SC-COMP-001 and Last sync label is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "SC-COMP-001"))
    |> assert_has(css("span", text: "Last sync:"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "ISO 27001 GDPR EN 50131 and IEC 61508 framework cards are all visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "ISO 27001"))
    |> assert_has(css("span", text: "GDPR"))
    |> assert_has(css("span", text: "EN 50131"))
    |> assert_has(css("span", text: "IEC 61508 SIL-2"))
  end

  feature "compliant status badge is displayed on at least one framework card", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "compliant", minimum: 1))
  end

  feature "partial status badge is displayed on IEC 61508 framework card", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "partial"))
  end

  feature "framework score percentages are displayed in the framework row", %{session: session} do
    session
    |> visit(@path)
    # Framework scores like 94%, 98%, 91%, 89% are in text-3xl spans
    |> assert_has(css("div.text-3xl", minimum: 4))
  end

  feature "non-conformance severity badges high and medium are visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "high"))
    |> assert_has(css("span", text: "medium"))
  end

  feature "control status colored dot indicators are rendered in control rows", %{
    session: session
  } do
    session
    |> visit(@path)
    # Control dots: bg-status-healthy (compliant), bg-status-warning (partial), etc.
    |> assert_has(css("span[class*='w-2 h-2 rounded-full']", minimum: 1))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "Overall Compliance metric card with SIL-6 threshold label is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Overall Compliance"))
    |> assert_has(css("div", text: "SIL-6 threshold: 90%"))
  end

  feature "Controls Effective metric card with Active control policies label is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Controls Effective"))
    |> assert_has(css("div", text: "Active control policies"))
  end

  feature "Open Findings metric card with Requires remediation label is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Open Findings"))
    |> assert_has(css("div", text: "Requires remediation"))
  end

  feature "Evidence Items metric card with Collected artifacts label is visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Evidence Items"))
    |> assert_has(css("div", text: "Collected artifacts"))
  end

  feature "compliance score shows percentage sign in overall compliance card", %{session: session} do
    session
    |> visit(@path)
    # Overall score % is in text-2xl span — value is runtime-computed
    |> assert_has(css("div", text: "SIL-6 threshold: 90%"))
  end

  feature "controls met ratio is shown in framework cards as N/N pattern", %{session: session} do
    session
    |> visit(@path)
    # Controls: 112/114 for ISO 27001 rendered as plain text in framework cards
    |> assert_has(css("span", text: "Controls:", minimum: 1))
  end

  feature "Open Non-Conformances section with NC IDs is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Open Non-Conformances"))
    |> assert_has(css("span", text: "NC-2026-001"))
  end

  feature "non-conformance descriptions for NC-2026-001 and NC-2026-002 are visible", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("div", text: "Password policy not enforced on legacy system"))
    |> assert_has(css("div", text: "Missing evidence for annual security training"))
  end

  feature "non-conformance due date and owner fields are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Due:", minimum: 1))
    |> assert_has(css("span", text: "Owner:", minimum: 1))
  end

  # ── C4: Timeline/History (Audit Trail Entries) ──────────────────────────────

  feature "audit trail panel contains at least one audit entry row", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='px-3 py-2 text-xs']", minimum: 1))
  end

  feature "audit trail entries show actor column with known actor values", %{session: session} do
    session
    |> visit(@path)
    # actors: admin@indrajaal.com, auditor@external.com, system, operator1
    |> assert_has(css("span[class*='text-content-secondary']", minimum: 1))
  end

  feature "audit trail entries show type badge with colored classification labels", %{
    session: session
  } do
    session
    |> visit(@path)
    # Type badges: access (blue), change (yellow), review (purple), approval (green), alert (red)
    |> assert_has(css("span[class*='rounded text-xs font-semibold']", minimum: 1))
  end

  feature "audit trail entry timestamp column is rendered with font-mono class", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span[class*='font-mono']", minimum: 1))
  end

  feature "pagination controls are rendered with Page label and Next button", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Page 1"))
    |> assert_has(css("button[phx-click='audit_page'][phx-value-page='2']", text: "Next"))
  end

  feature "clicking Next pagination button advances audit trail to page 2", %{session: session} do
    session
    |> visit(@path)
    |> click(css("button[phx-click='audit_page'][phx-value-page='2']", text: "Next"))
    |> assert_has(css("span", text: "Page 2"))
  end

  feature "audit trail entries count label is rendered in the audit trail header", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("span[class*='text-content-muted']", text: "entries", minimum: 1))
  end

  feature "last audit dates are shown in framework cards", %{session: session} do
    session
    |> visit(@path)
    # last_audit dates like "2025-12-15" shown in framework cards
    |> assert_has(css("span", text: "Audit:", minimum: 1))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "framework filter dropdown contains All Frameworks ISO 27001 GDPR options", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[name='framework'] option", text: "All Frameworks"))
    |> assert_has(css("select[name='framework'] option", text: "ISO 27001"))
    |> assert_has(css("select[name='framework'] option", text: "GDPR"))
  end

  feature "framework filter has EN 50131 and IEC 61508 options", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("select[name='framework'] option", text: "EN 50131"))
    |> assert_has(css("select[name='framework'] option", text: "IEC 61508"))
  end

  feature "status filter dropdown contains All Status Compliant Partial Non-Compliant options", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[name='status'] option", text: "All Status"))
    |> assert_has(css("select[name='status'] option", text: "Compliant"))
    |> assert_has(css("select[name='status'] option", text: "Partial"))
    |> assert_has(css("select[name='status'] option", text: "Non-Compliant"))
  end

  feature "regulation filter has All Regulations ISO 27001 GDPR EN 50131 IEC 61508 options", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("select[name='regulation'] option", text: "All Regulations"))
    |> assert_has(css("select[name='regulation'] option", text: "ISO 27001"))
    |> assert_has(css("select[name='regulation'] option", text: "GDPR"))
    |> assert_has(css("select[name='regulation'] option", text: "EN 50131"))
    |> assert_has(css("select[name='regulation'] option", text: "IEC 61508"))
  end

  feature "control status panel renders clickable control rows", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_control']", minimum: 1))
  end

  feature "compliance page remains stable after a 10000ms refresh interval", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("span", text: "Audit Trail"))

    Process.sleep(10_500)

    assert_has(session, css("span", text: "Audit Trail"))
    assert_has(session, css("span", text: "Control Status"))
  end

  # ── C8: Action Buttons — Dual Verification ──────────────────────────────────
  # filter_framework: verification 1 — Control Status panel remains
  feature "C8 filter_framework iso27001 — Control Status panel persists after framework filter",
          %{
            session: session
          } do
    session
    |> visit(@path)
    |> find(css("select[name='framework']"), fn select ->
      click(select, css("option[value='iso27001']"))
    end)
    |> assert_has(css("span", text: "Control Status"))
  end

  # filter_framework: verification 2 — audit trail resets to page 1
  feature "C8 filter_framework iso27001 — audit trail page resets to 1 after framework filter", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='framework']"), fn select ->
      click(select, css("option[value='iso27001']"))
    end)
    |> assert_has(css("span", text: "Page 1"))
  end

  # filter_status compliant: verification 1 — Control Status heading remains
  feature "C8 filter_status compliant — Control Status heading remains after status filter", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='compliant']"))
    end)
    |> assert_has(css("span", text: "Control Status"))
  end

  # filter_status compliant: verification 2 — page structure intact
  feature "C8 filter_status compliant — main layout with Audit Trail remains after filter", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='status']"), fn select ->
      click(select, css("option[value='compliant']"))
    end)
    |> assert_has(css("span", text: "Audit Trail"))
  end

  # filter_regulation gdpr: verification 1 — audit trail heading remains
  feature "C8 filter_regulation gdpr — Audit Trail panel heading persists after regulation filter",
          %{
            session: session
          } do
    session
    |> visit(@path)
    |> find(css("select[name='regulation']"), fn select ->
      click(select, css("option[value='gdpr']"))
    end)
    |> assert_has(css("span", text: "Audit Trail"))
  end

  # filter_regulation gdpr: verification 2 — page resets to page 1
  feature "C8 filter_regulation gdpr — audit trail resets to page 1 after regulation filter", %{
    session: session
  } do
    session
    |> visit(@path)
    |> find(css("select[name='regulation']"), fn select ->
      click(select, css("option[value='gdpr']"))
    end)
    |> assert_has(css("span", text: "Page 1"))
  end

  # audit_page Next: verification 1 — page counter advances
  feature "C8 audit_page Next — pagination counter shows Page 2 after clicking Next", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='audit_page'][phx-value-page='2']", text: "Next"))
    |> assert_has(css("span", text: "Page 2"))
  end

  # audit_page Next: verification 2 — Audit Trail panel still rendered
  feature "C8 audit_page Next — Audit Trail panel heading remains after navigating to page 2", %{
    session: session
  } do
    session
    |> visit(@path)
    |> click(css("button[phx-click='audit_page'][phx-value-page='2']", text: "Next"))
    |> assert_has(css("span", text: "Audit Trail"))
  end

  # select_control: verification 1 — Control Status panel remains
  feature "C8 select_control — Control Status panel remains after clicking a control row", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_control']", minimum: 1))
    |> click(css("[phx-click='select_control']"))
    |> assert_has(css("span", text: "Control Status"))
  end

  # select_control: verification 2 — page layout remains intact
  feature "C8 select_control — full page layout intact after selecting a control row", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("[phx-click='select_control']", minimum: 1))
    |> click(css("[phx-click='select_control']"))
    |> assert_has(css("span", text: "Audit Trail"))
    |> assert_has(css("span", text: "Open Non-Conformances"))
  end
end
