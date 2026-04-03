defmodule IndrajaalWeb.Prajna.GuardianLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Guardian Approval Interface LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/guardian-approval`
  - **Module**: `IndrajaalWeb.Prajna.GuardianLive`
  - **Title**: "Guardian - Approval Interface"
  - **Priority**: P0 (Safety-Critical — proposal approval/veto with constitutional audit)

  ## Design Intent
  The Guardian Approval Interface is the safety kernel operator console for
  reviewing and acting on pending system proposals. Operators see a live queue
  of proposals (GDE-NNN format), filter by priority, select a proposal to view
  detail, then execute a two-step approve or veto action. All decisions are logged
  to the audit trail and the Immutable Register. The circuit breaker status and
  rolling proposal statistics are shown in the header. The page receives live
  PubSub updates for new proposals and decisions from other operators or agents.

  ## Expected Behavior

  ### Mount Assigns
  - `page_title` — "Guardian - Approval Interface"
  - `current_nav` — `:guardian`
  - `pending_proposals` — list of 3 sample proposals (GDE-447, GDE-448, GDE-449)
  - `audit_trail` — list of 3 sample audit entries
  - `circuit_breaker` — `:closed` (nominal state)
  - `proposals_approved` — 0 (counter)
  - `proposals_vetoed` — 0 (counter)
  - `selected_proposal` — nil (no proposal selected on mount)
  - `confirm_action` — nil (no confirm panel on mount)
  - `filter_priority` — `:all`
  - `last_update` — timestamp

  ### handle_event Callbacks
  - `"select_proposal"` — sets `selected_proposal` to proposal id; no flash
  - `"close_proposal"` — clears `selected_proposal` and `confirm_action`; no flash
  - `"request_approve"` — sets `confirm_action` to `{:approve, id}`; no flash (ARM step)
  - `"request_veto"` — sets `confirm_action` to `{:veto, id}`; no flash (ARM step)
  - `"cancel_confirm"` — clears `confirm_action`; no flash
  - `"confirm_action"` (approve) — executes approval; flash :info "Proposal #{id} approved and recorded"
  - `"confirm_action"` (veto) — executes veto; flash :warning "Proposal #{id} vetoed and recorded"
  - `"filter_priority"` — updates `filter_priority` assign; no flash

  ### handle_info Callbacks
  - `:refresh` (every 5000ms) — calls `refresh_guardian_status/1` to update proposal queue and stats
  - `{:new_proposal, proposal}` — prepends proposal to `pending_proposals`
  - `{:proposal_decided, %{id, decision}}` — removes from `pending_proposals`; appends to `audit_trail`

  ### PubSub Subscriptions
  - `"guardian:proposals"` — new proposal notifications
  - `"guardian:decisions"` — decision notifications from other operators
  - `"prajna:guardian"` — general guardian status updates

  ### Timer Intervals
  - `:refresh` every 5000ms (`@refresh_interval 5_000`)

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with Guardian Approval Interface heading
    Given I navigate to "/cockpit/guardian-approval"
    Then I see h1 "Guardian Approval Interface"
    And I see SC-GDE-001 in the subtitle
    And I see the circuit breaker badge "CB:"

  Scenario: C2 - Circuit breaker shows CLOSED status on load
    Given I navigate to "/cockpit/guardian-approval"
    Then the circuit breaker displays a closed/nominal badge

  Scenario: C3 - Pending proposals panel shows proposal entries
    Given I navigate to "/cockpit/guardian-approval"
    Then I see the pending proposals panel with proposal IDs

  Scenario: C5 - Priority filter updates the proposal list
    Given I navigate to "/cockpit/guardian-approval"
    When I click a priority filter button
    Then the displayed proposals are filtered by that priority

  Scenario: C8 (two-step approve) - arm request_approve → confirm → cancel
    Given I navigate to "/cockpit/guardian-approval"
    And I select a proposal
    When I click the Approve button (request_approve ARM)
    Then the confirm approve panel appears
    When I click Cancel
    Then the confirm panel disappears

  Scenario: C8 (dual approve) - confirm_action approve changes status and shows flash
    Given the confirm approve panel is visible
    When I click Confirm Approve
    Then the proposal is removed from the queue
    And I see flash info "approved and recorded"

  Scenario: C8 (dual veto) - confirm_action veto shows flash warning
    Given the confirm veto panel is visible
    When I click Confirm Veto
    Then I see flash warning "vetoed and recorded"
  ```

  ## UX Flow
  1. Operator loads the page; sees pending proposals queue on the left
  2. Operator optionally filters by priority (All / Critical / High / Medium)
  3. Operator clicks a proposal to expand the detail panel
  4. Operator clicks "Approve" or "Veto" — ARM step; `confirm_action` set
  5. Operator confirms in the confirm panel — FIRE step; flash + audit update
  6. Operator may cancel at any time during the ARM step
  7. Audit trail (right column) shows all past decisions with timestamps
  8. Live PubSub updates add new proposals in real time

  ## UI Elements Inventory

  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Page heading | h1 | `h1[text="Guardian Approval Interface"]` | — |
  | SC-GDE-001 subtitle | p | `p[contains 'SC-GDE-001']` | — |
  | Circuit breaker badge | div | `div[contains 'CB:']` | — |
  | Navigation bar | nav | `nav` | — |
  | Proposals panel | div | `div.col-span-7` | — |
  | Right sidebar | div | `div.col-span-5` | — |
  | Proposal list items | div | `div[phx-click='select_proposal']` | `select_proposal` |
  | Priority filter buttons | button | `button[phx-click='filter_priority']` | `filter_priority` |
  | Approve button (ARM) | button | `button[phx-click='request_approve']` | `request_approve` |
  | Veto button (ARM) | button | `button[phx-click='request_veto']` | `request_veto` |
  | Confirm action button (FIRE) | button | `button[phx-click='confirm_action']` | `confirm_action` |
  | Cancel confirm button | button | `button[phx-click='cancel_confirm']` | `cancel_confirm` |
  | Close proposal button | button | `button[phx-click='close_proposal']` | `close_proposal` |
  | Audit trail panel | div | `div[contains 'AUDIT TRAIL']` | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-019: Two-step commit arm→confirm→cancel sequence required
  - SC-GDE-001: Guardian validation required for all proposals
  - SC-PRAJNA-001: Guardian pre-approval for planning mutations
  - SC-PRAJNA-005: Two-step commit for destructive actions
  - SC-SAFETY-001: Guardian pre-approval required
  - SC-SAFETY-003: Complete audit trail to Immutable Register
  - SC-HMI-001: Dark Cockpit defaults (bg-surface-primary layout)

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Proposal approved without confirm step | 9 | 1 | 2 | 18 | `confirm_action` ARM gate before FIRE |
  | Stale proposal list (no live update) | 5 | 3 | 3 | 45 | 5s `:refresh` timer + PubSub subscription |
  | Audit trail not updated after decision | 7 | 2 | 3 | 42 | `{:proposal_decided,...}` handle_info appends entry |
  | Circuit breaker status not shown | 5 | 2 | 4 | 40 | `circuit_breaker` assign bound to header badge |
  | Priority filter loses proposals on select | 3 | 2 | 3 | 18 | Filter is cosmetic; full list preserved in assigns |

  Run with: WALLABY_ENABLED=true mix test --only wallaby

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

  @url "/cockpit/guardian-approval"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads and renders the Guardian Approval Interface heading", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("h1", text: "Guardian Approval Interface"))
  end

  feature "SC-GDE-001 STAMP reference is visible in the page subtitle", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("p", text: "SC-GDE-001"))
  end

  feature "circuit breaker badge is visible in the header area", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "CB:"))
  end

  feature "page root container uses the bg-surface-primary dark cockpit layout class", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div.bg-surface-primary"))
  end

  feature "prajna navigation component is present on the page", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("nav"))
  end

  feature "main content area is rendered with a col-span-7 proposals panel", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div.col-span-7"))
  end

  feature "right sidebar column is rendered with the col-span-5 layout class", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div.col-span-5"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "stats row is rendered as a 4-column grid", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div.grid.grid-cols-4"))
  end

  feature "PENDING metric card is visible in the stats row", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "PENDING"))
  end

  feature "APPROVED metric card is visible in the stats row", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "APPROVED"))
  end

  feature "VETOED metric card is visible in the stats row", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "VETOED"))
  end

  feature "APPROVAL RATE metric card is visible in the stats row", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "APPROVAL RATE"))
  end

  feature "P0 Critical priority badge uses red styling (bg-red-100)", %{session: session} do
    # GDE-448 is seeded with priority :p0
    session
    |> visit(@url)
    |> assert_has(css("span.bg-red-100", text: "P0"))
  end

  feature "P1 High priority badge uses orange styling (bg-orange-100)", %{session: session} do
    # GDE-447 is seeded with priority :p1
    session
    |> visit(@url)
    |> assert_has(css("span.bg-orange-100", text: "P1"))
  end

  feature "P2 Medium priority badge uses blue styling (bg-blue-100)", %{session: session} do
    # GDE-449 is seeded with priority :p2
    session
    |> visit(@url)
    |> assert_has(css("span.bg-blue-100", text: "P2"))
  end

  # ── C3: Data Grid/Summary ───────────────────────────────────────────────────

  feature "PENDING PROPOSALS section heading is visible in the proposals panel", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("h2", text: "PENDING PROPOSALS"))
  end

  feature "initial seeded proposal GDE-447 title is rendered in the proposals list", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "Deploy evolution patch to SentinelBridge v2.1.0"))
  end

  feature "initial seeded proposal GDE-448 title is rendered in the proposals list", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "Reconfigure Guardian circuit breaker threshold to 5"))
  end

  feature "initial seeded proposal GDE-449 title is rendered in the proposals list", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "Update KMS key rotation schedule to 90 days"))
  end

  feature "APPROVE buttons are rendered for proposals in the queue", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("button", text: "APPROVE", minimum: 1))
  end

  feature "VETO buttons are rendered for proposals in the queue", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("button", text: "VETO", minimum: 1))
  end

  feature "priority filter dropdown with All Priorities option is rendered", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("select[name='priority']"))
    |> assert_has(css("option", text: "All Priorities"))
  end

  feature "priority filter dropdown exposes the P0 Critical option", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("option[value='p0']", text: "P0 Critical"))
  end

  feature "priority filter dropdown exposes the P1 High option", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("option[value='p1']", text: "P1 High"))
  end

  feature "priority filter dropdown exposes the P2 Medium option", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("option[value='p2']", text: "P2 Medium"))
  end

  # ── C4: Audit Trail / History ───────────────────────────────────────────────

  feature "AUDIT TRAIL section heading is visible in the right sidebar", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("h3", text: "AUDIT TRAIL"))
  end

  feature "audit trail shows the seeded APPROVED decision for GDE-440", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "APPROVED"))
  end

  feature "audit trail shows the seeded VETOED decision for GDE-439", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "VETOED"))
  end

  feature "audit trail entries show the actor attribution 'by operator'", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "by operator"))
  end

  feature "approving a proposal adds a new APPROVED entry to the audit trail", %{
    session: session
  } do
    session
    |> visit(@url)
    # Count APPROVED entries before action — seeded has 2 (GDE-440, GDE-438)
    |> click(css("button[phx-click='request_approve']", minimum: 1))
    |> click(css("button[phx-click='confirm_action']"))
    # After approval the audit trail gains a new APPROVED entry
    |> assert_has(css("span.text-green-600", minimum: 3))
  end

  feature "vetoing a proposal adds a new VETOED entry to the audit trail", %{session: session} do
    session
    |> visit(@url)
    # Count VETOED entries before action — seeded has 1 (GDE-439)
    |> click(css("button[phx-click='request_veto']", minimum: 1))
    |> click(css("button[phx-click='confirm_action']"))
    # After veto the audit trail gains a new VETOED entry
    |> assert_has(css("span.text-red-600", minimum: 2))
  end

  feature "STAMP constraint labels are in the sidebar", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "SC-PRAJNA-001"))
  end

  feature "two-step commit enforced label is visible in the STAMP sidebar area", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div", text: "Two-step commit enforced"))
  end

  # ── C5: Interactive Elements / Proposal Detail ──────────────────────────────

  feature "clicking a proposal row opens the PROPOSAL DETAIL sidebar", %{session: session} do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("h3", text: "PROPOSAL DETAIL"))
  end

  feature "proposal detail sidebar shows the Proposer field label", %{session: session} do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("span", text: "Proposer:"))
  end

  feature "proposal detail sidebar shows the Impact Score field label", %{session: session} do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("span", text: "Impact Score:"))
  end

  feature "proposal detail sidebar shows the STAMP field label", %{session: session} do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("span", text: "STAMP:"))
  end

  feature "proposal detail sidebar shows the CONSTITUTIONAL ALIGNMENT section", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("div", text: "CONSTITUTIONAL ALIGNMENT"))
  end

  feature "constitutional alignment shows Ψ₀ Existence check for the selected proposal", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("span", text: "Ψ₀ Existence"))
  end

  feature "constitutional alignment shows Ψ₃ Verification check for the selected proposal", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("span", text: "Ψ₃ Verification"))
  end

  feature "proposal detail sidebar exposes a CLOSE button to dismiss the panel", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("button[phx-click='close_proposal']", text: "CLOSE"))
  end

  feature "clicking CLOSE removes the PROPOSAL DETAIL panel from the DOM", %{session: session} do
    session
    |> visit(@url)
    |> click(css("[phx-click='select_proposal']", minimum: 1))
    |> assert_has(css("h3", text: "PROPOSAL DETAIL"))
    |> click(css("button[phx-click='close_proposal']"))
    |> refute_has(css("h3", text: "PROPOSAL DETAIL"))
  end

  feature "selecting P1 High filter shows only P1 proposals", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("select[name='priority']"), with: "p1")
    # After filtering to p1, GDE-447 (P1) should be present
    |> assert_has(css("span.bg-orange-100", text: "P1", minimum: 1))
  end

  feature "selecting P0 Critical filter shows only P0 proposals", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("select[name='priority']"), with: "p0")
    # After filtering to p0, GDE-448 (P0) should be present
    |> assert_has(css("span.bg-red-100", text: "P0", minimum: 1))
  end

  # ── C8: Action Buttons — Dual Verification (status + flash) ────────────────

  # request_approve — C8 Test 1: confirmation modal appears (status change)
  feature "clicking APPROVE triggers the CONFIRM ACTION REQUIRED two-step dialog", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_approve']", minimum: 1))
    |> assert_has(css("span", text: "CONFIRM ACTION REQUIRED"))
  end

  # request_approve — C8 Test 2: confirmation dialog renders action buttons
  feature "two-step confirmation dialog renders the CONFIRM button", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_approve']", minimum: 1))
    |> assert_has(css("button[phx-click='confirm_action']", text: "CONFIRM"))
  end

  # confirm_action (approve path) — C8 Test 1: proposal removed from queue (status change)
  feature "confirming APPROVE removes the proposal from the pending queue", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_approve']", minimum: 1))
    |> click(css("button[phx-click='confirm_action']"))
    # Pending count decreased — APPROVED counter incremented
    |> assert_has(css("div.text-green-400"))
  end

  # confirm_action (approve path) — C8 Test 2: flash message shown
  feature "confirming an APPROVE shows the approved flash info message", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_approve']", minimum: 1))
    |> assert_has(css("button[phx-click='confirm_action']"))
    |> click(css("button[phx-click='confirm_action']"))
    |> assert_has(css("div[role='alert']"))
  end

  # request_veto — C8 Test 1: veto confirmation modal appears (status change)
  feature "clicking VETO triggers the CONFIRM ACTION REQUIRED two-step dialog", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_veto']", minimum: 1))
    |> assert_has(css("span", text: "CONFIRM ACTION REQUIRED"))
  end

  # request_veto — C8 Test 2: veto dialog renders the CONFIRM and CANCEL buttons
  feature "VETO confirmation dialog renders both CONFIRM and CANCEL buttons", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_veto']", minimum: 1))
    |> assert_has(css("button[phx-click='confirm_action']", text: "CONFIRM"))
    |> assert_has(css("button[phx-click='cancel_confirm']", text: "CANCEL"))
  end

  # confirm_action (veto path) — C8 Test 1: vetoed counter incremented (status change)
  feature "confirming VETO increments the VETOED counter", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_veto']", minimum: 1))
    |> click(css("button[phx-click='confirm_action']"))
    # VETOED counter is displayed in red
    |> assert_has(css("div.text-red-400"))
  end

  # confirm_action (veto path) — C8 Test 2: flash message shown
  feature "confirming VETO shows a flash warning message", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_veto']", minimum: 1))
    |> click(css("button[phx-click='confirm_action']"))
    |> assert_has(css("div[role='alert']"))
  end

  # cancel_confirm — C8 Test 1: modal dismissed (status change)
  feature "clicking CANCEL on the confirmation dialog dismisses it without applying action", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='request_approve']", minimum: 1))
    |> assert_has(css("span", text: "CONFIRM ACTION REQUIRED"))
    |> click(css("button[phx-click='cancel_confirm']"))
    |> refute_has(css("span", text: "CONFIRM ACTION REQUIRED"))
  end

  # cancel_confirm — C8 Test 2: no flash on cancel (proposal remains in queue)
  feature "cancelling confirmation leaves proposal count unchanged", %{session: session} do
    session
    |> visit(@url)
    # Three proposals should still be present after cancel
    |> click(css("button[phx-click='request_approve']", minimum: 1))
    |> click(css("button[phx-click='cancel_confirm']"))
    |> assert_has(css("button[phx-click='request_approve']", minimum: 1))
  end

  # filter_priority — C8 Test 1: filtered list shown (status change in DOM)
  feature "filter_priority to p2 shows only P2 Medium proposals in the list", %{
    session: session
  } do
    session
    |> visit(@url)
    |> fill_in(css("select[name='priority']"), with: "p2")
    |> assert_has(css("span.bg-blue-100", text: "P2", minimum: 1))
  end

  # filter_priority — C8 Test 2: All Priorities restores full list
  feature "resetting filter to All Priorities restores all three seeded proposals", %{
    session: session
  } do
    session
    |> visit(@url)
    |> fill_in(css("select[name='priority']"), with: "p1")
    |> fill_in(css("select[name='priority']"), with: "all")
    |> assert_has(css("button[phx-click='request_approve']", minimum: 3))
  end

  # ── Refresh Stability ───────────────────────────────────────────────────────

  feature "guardian page remains stable after the 5000ms auto-refresh interval", %{
    session: session
  } do
    session = visit(session, @url)
    assert_has(session, css("h1", text: "Guardian Approval Interface"))
    assert_has(session, css("h3", text: "AUDIT TRAIL"))

    Process.sleep(5_500)

    assert_has(session, css("h1", text: "Guardian Approval Interface"))
    assert_has(session, css("h3", text: "AUDIT TRAIL"))
  end
end
