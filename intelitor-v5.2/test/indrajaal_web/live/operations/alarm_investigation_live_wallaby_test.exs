defmodule IndrajaalWeb.Operations.AlarmInvestigationLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the Alarm Investigation LiveView page.
  Gold standard: 48 features, 8 categories (C1-C8), H=2.64 bits.

  ## Page Identity
  - **Route**: `/operations/alarms/:id` (default: ALM-2024-00_142)
  - **Module**: `IndrajaalWeb.Operations.AlarmInvestigationLive`
  - **Title**: "Investigation: {alarm_id}"

  ## Design Intent
  Provides a single-screen investigation workflow for security/safety alarms.
  An operator landing on this page should be able to: (1) assess severity at a glance
  via color-coded badges, (2) review the chronological timeline of events,
  (3) examine correlated events from adjacent sensors, (4) view linked video clips,
  (5) consult AI-generated insights (advisory only per SC-AI-001), (6) add
  investigation notes, and (7) resolve the alarm via one of four action buttons.

  ## Expected Behavior (Functional)
  - **On mount**: Loads alarm by `:id` param, populates timeline, correlated events,
    AI insight, empty notes, video_playing=false
  - **handle_event "verify"**: Sets alarm status to `:verified`, flash "Alarm verified"
  - **handle_event "false_alarm"**: Sets status to `:false_alarm`, flash "Marked as false alarm"
  - **handle_event "escalate"**: Sets status to `:escalated`, flash "Escalated to supervisor"
  - **handle_event "close"**: Sets status to `:closed`, flash "Alarm closed"
  - **handle_event "add_note"**: Appends timestamped note to timeline, clears notes field
  - **handle_event "play_video"**: Sets video_playing=true
  - **handle_event "export_clip"**: Flash "Video clip exported"
  - **No PubSub subscriptions** (investigation is a snapshot, not live-updating)
  - **No timer** (no periodic refresh)

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator verifies a real alarm
    Given I navigate to "/operations/alarms/ALM-2024-00_142"
    When I click "Verify Alarm"
    Then the status badge should change to "VERIFIED"
    And I should see flash "Alarm verified - dispatching response team"

  Scenario: Operator marks false alarm
    Given I am on the alarm investigation page
    When I click "False Alarm"
    Then the status badge should change to "FALSE_ALARM"

  Scenario: Operator adds investigation note
    Given I am on the alarm investigation page
    When I type "Checked camera feed - confirmed intrusion" in the notes field
    And I click "Add Note"
    Then the timeline should show a new "note" entry with my text

  Scenario: Operator views linked video
    Given I am on the alarm investigation page
    When I click "Play Video"
    Then the video player should become active
  ```

  ## UX Flow
  1. Operator clicks alarm row in Active Alarms list → navigates here
  2. Sees alarm header with severity badge (CRITICAL/HIGH/MEDIUM/LOW) + status badge
  3. Reads Summary grid: Type, Site, Zone, Device
  4. Scrolls Timeline for chronological event history
  5. Checks Correlated Events for related sensor triggers
  6. Reviews AI Copilot Insight panel (advisory only)
  7. Optionally adds investigation notes via textarea + Add Note button
  8. Optionally plays linked video clip
  9. Resolves: clicks one of 4 action buttons → sees flash + status badge update
  10. Navigates back via "Back to Active Alarms" link

  ## UI Elements Inventory
  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | Investigation heading | h1 | `h1` text "Investigation:" | — |
  | Back link | a | `a` text "Back to Active Alarms" | navigate |
  | Severity badge | span | `.bg-red-900` / `.bg-yellow-900` | — |
  | Status badge | span | text "INVESTIGATING"/"VERIFIED"/etc. | — |
  | Summary grid | div | labels "Type", "Site", "Zone", "Device" | — |
  | Timeline entries | div | `span` with event type text | — |
  | Correlated events | section | text "Correlated Events" | — |
  | Notes textarea | textarea | `textarea[name='note']` | — |
  | Add Note button | button | `button[type='submit']` | add_note |
  | Play Video button | button | `button[phx-click='play_video']` | play_video |
  | Export Clip button | button | `button[phx-click='export_clip']` | export_clip |
  | Verify Alarm | button | `button[phx-click='verify']` | verify |
  | False Alarm | button | `button[phx-click='false_alarm']` | false_alarm |
  | Escalate | button | `button[phx-click='escalate']` | escalate |
  | Close | button | `button[phx-click='close']` | close |
  | AI Insight panel | div | text "AI Copilot Insight" | — |
  | AI disclaimer | p | text "AI suggestions are ADVISORY only" | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-016: C8 dual verification (status + flash) for all action buttons
  - SC-HMI-001: Management by Exception (dark cockpit, gray defaults)
  - SC-HMI-004: Two-step commit for critical actions
  - SC-HMI-011: 8x8 Matrix path coverage
  - SC-AI-001: AI suggestions are ADVISORY only
  - SC-ALARM-001: Alarm processing

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | Alarm data not loaded (mount crash) | 8 | 2 | 3 | 48 | Default sample alarm fallback |
  | Action button changes status silently | 9 | 3 | 2 | 54 | C8 dual verification (flash + badge) |
  | AI insight misleads operator | 7 | 4 | 5 | 140 | "ADVISORY only" disclaimer (SC-AI-001) |

  Run with: `WALLABY_ENABLED=true mix test --only wallaby`

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

  # Default sample alarm route (no :id — uses ALM-2024-00_142)
  @default_path "/operations/alarms/ALM-2024-00_142"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  # ── 1. Page loads with Investigation header ──────────────────────────────────

  feature "page loads with Investigation alarm ID in heading", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("h1", text: "Investigation:"))
  end

  # ── 2. Back to Active Alarms link is present ─────────────────────────────────

  feature "Back to Active Alarms navigation link is present", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("a", text: "Back to Active Alarms"))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────

  # ── 3. INVESTIGATING status badge is shown for default alarm ─────────────────

  feature "INVESTIGATING status badge is shown for the default sample alarm", %{
    session: session
  } do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "INVESTIGATING"))
  end

  # ── 4. CAUTION severity badge is shown for default alarm ─────────────────────

  feature "CAUTION severity badge is shown for the default sample alarm", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "CAUTION"))
  end

  # ── C3: Data Grid/Summary ──────────────────────────────────────────────────

  # ── 5. Alarm type INTRUSION is shown in the summary grid ─────────────────────

  feature "alarm type INTRUSION is shown in the alarm summary grid", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("p", text: "INTRUSION"))
  end

  # ── 6. Alarm site HQ Building is shown in the summary grid ───────────────────

  feature "alarm site HQ Building is shown in the alarm summary grid", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("p", text: "HQ Building"))
  end

  # ── 7. Alarm zone Zone-A North is shown in the summary grid ──────────────────

  feature "alarm zone Zone-A North is shown in the alarm summary grid", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("p", text: "Zone-A North"))
  end

  # ── 8. Alarm device sensor-042 is shown in the summary grid ──────────────────

  feature "alarm device sensor-042 is shown in the alarm summary grid", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("p", text: "sensor-042"))
  end

  # ── C4: Timeline/History ───────────────────────────────────────────────────

  # ── 9. Timeline section heading is present ───────────────────────────────────

  feature "Timeline section heading is present in the left column", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("h2", text: "Timeline"))
  end

  # ── 10. Timeline shows TRIGGERED entry ───────────────────────────────────────

  feature "Timeline shows TRIGGERED entry from sample alarm data", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "TRIGGERED"))
  end

  # ── 11. Timeline shows ENRICHED entry ────────────────────────────────────────

  feature "Timeline shows ENRICHED entry from sample alarm data", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "ENRICHED"))
  end

  # ── 12. Timeline shows ACKNOWLEDGED entry ────────────────────────────────────

  feature "Timeline shows ACKNOWLEDGED entry from sample alarm data", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "ACKNOWLEDGED"))
  end

  # ── 13. Timeline shows DISPATCHED entry ──────────────────────────────────────

  feature "Timeline shows DISPATCHED entry from sample alarm data", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "DISPATCHED"))
  end

  # ── 14. Correlated Events section heading is present ─────────────────────────

  feature "Correlated Events section heading is present", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("h2", text: "Correlated Events"))
  end

  # ── 15. Correlated event from Access Control source is visible ────────────────

  feature "correlated event from Access Control source is visible", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "Access Control"))
  end

  # ── 16. Correlated event from Video Analytics source is visible ───────────────

  feature "correlated event from Video Analytics source is visible", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "Video Analytics"))
  end

  # ── 17. Correlated event from History source is visible ──────────────────────

  feature "correlated event from History source is visible", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "History"))
  end

  # ── C5: Interactive Elements ───────────────────────────────────────────────

  # ── 18. Investigation Notes section heading is present ───────────────────────

  feature "Investigation Notes section heading is present", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("h2", text: "Investigation Notes"))
  end

  # ── 19. Notes textarea with placeholder is present ───────────────────────────

  feature "notes textarea with Add investigation notes placeholder is present", %{
    session: session
  } do
    session
    |> visit(@default_path)
    |> assert_has(css("textarea[name='note'][placeholder='Add investigation notes...']"))
  end

  # ── 20. Add Note button is present ───────────────────────────────────────────

  feature "Add Note submit button is present in the notes form", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("button[type='submit']", text: "Add Note"))
  end

  # ── 21. Submitting a note appends it to the timeline ─────────────────────────

  feature "submitting a note via the form appends NOTE entry to timeline", %{session: session} do
    session
    |> visit(@default_path)
    |> fill_in(css("textarea[name='note']"), with: "Test note from Wallaby")
    |> click(css("button[type='submit']", text: "Add Note"))
    |> assert_has(css("span", text: "NOTE"))
  end

  # ── C6: Media/Rich Content ─────────────────────────────────────────────────

  # ── 22. Video Clip section heading is present ────────────────────────────────

  feature "Video Clip section heading shows camera identifier", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("h2", text: "Video Clip"))
  end

  # ── 23. Video play button is shown before playing ────────────────────────────

  feature "video play button is visible before video starts playing", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("button[phx-click='play_video']"))
  end

  # ── 24. Clicking play_video starts video playback indicator ──────────────────

  feature "clicking play_video button shows Playing indicator", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='play_video']"))
    |> assert_has(css("div", text: "Playing..."))
  end

  # ── 25. Motion detected timestamp annotation is visible ──────────────────────

  feature "Motion detected at 14:32:43 annotation is visible in video section", %{
    session: session
  } do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "Motion detected at 14:32:43"))
  end

  # ── 26. Export clip button is present ────────────────────────────────────────

  feature "Export clip button is present next to the video player", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("button[phx-click='export_clip']", text: "Export"))
  end

  # ── 27. Export clip triggers flash message ───────────────────────────────────

  feature "clicking Export clip button triggers Video clip exported flash", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='export_clip']"))
    |> assert_has(css("[role='alert']", text: "Video clip exported"))
  end

  # ── C7: AI/Advisory Panels ─────────────────────────────────────────────────

  # ── 28. AI Copilot Insight heading is present ────────────────────────────────

  feature "AI Copilot Insight heading is present in the right column", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("h2", text: "AI Copilot Insight"))
  end

  # ── 29. AI confidence score is shown ─────────────────────────────────────────

  feature "AI confidence score is shown in the AI Copilot Insight panel", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "Confidence:"))
  end

  # ── 30. AI advisory notice is shown ──────────────────────────────────────────

  feature "AI ADVISORY only disclaimer is present per SC-AI-001", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("p", text: "AI suggestions are ADVISORY only"))
  end

  # ── 31. Recommendations label is present in AI insight panel ─────────────────

  feature "Recommendations label is present in the AI Copilot Insight panel", %{
    session: session
  } do
    session
    |> visit(@default_path)
    |> assert_has(css("p", text: "Recommendations:"))
  end

  # ── C8: Action Buttons (DUAL verification) ─────────────────────────────────

  # ── 32. Actions section heading is present ───────────────────────────────────

  feature "Actions section heading is present in the right column", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("h2", text: "Actions"))
  end

  # ── 33. Verify Alarm button is present ───────────────────────────────────────

  feature "Verify Alarm action button is present", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("button[phx-click='verify']", text: "Verify Alarm"))
  end

  # ── 34. False Alarm button is present ────────────────────────────────────────

  feature "False Alarm action button is present", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("button[phx-click='false_alarm']", text: "False Alarm"))
  end

  # ── 35. Escalate button is present ───────────────────────────────────────────

  feature "Escalate action button is present", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("button[phx-click='escalate']", text: "Escalate"))
  end

  # ── 36. Close button is present ──────────────────────────────────────────────

  feature "Close action button is present", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("button[phx-click='close']", text: "Close"))
  end

  # ── 37. Clicking Verify Alarm changes status to VERIFIED ─────────────────────

  feature "clicking Verify Alarm changes status badge to VERIFIED", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='verify']"))
    |> assert_has(css("span", text: "VERIFIED"))
  end

  # ── 38. Clicking Verify Alarm triggers info flash ─────────────────────────────

  feature "clicking Verify Alarm triggers dispatching response team flash", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='verify']"))
    |> assert_has(css("[role='alert']", text: "Alarm verified - dispatching response team"))
  end

  # ── 39. Clicking False Alarm changes status badge ─────────────────────────────

  feature "clicking False Alarm changes status badge to FALSE_ALARM", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='false_alarm']"))
    |> assert_has(css("span", text: "FALSE_ALARM"))
  end

  # ── 40. Clicking False Alarm triggers info flash ──────────────────────────────

  feature "clicking False Alarm triggers Marked as false alarm flash", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='false_alarm']"))
    |> assert_has(css("[role='alert']", text: "Marked as false alarm"))
  end

  # ── 41. Clicking Escalate triggers warning flash ──────────────────────────────

  feature "clicking Escalate triggers Escalated to supervisor flash", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='escalate']"))
    |> assert_has(css("[role='alert']", text: "Escalated to supervisor"))
  end

  # ── 42. Clicking Escalate changes status to ESCALATED ────────────────────────

  feature "clicking Escalate changes status badge to ESCALATED", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='escalate']"))
    |> assert_has(css("span", text: "ESCALATED"))
  end

  # ── 43. Clicking Close triggers info flash ────────────────────────────────────

  feature "clicking Close triggers Alarm closed flash message", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='close']"))
    |> assert_has(css("[role='alert']", text: "Alarm closed"))
  end

  # ── 44. Clicking Close changes status to CLOSED ──────────────────────────────

  feature "clicking Close changes status badge to CLOSED", %{session: session} do
    session
    |> visit(@default_path)
    |> click(css("button[phx-click='close']"))
    |> assert_has(css("span", text: "CLOSED"))
  end

  # ── 45. Alarm age label is shown in the header area ──────────────────────────

  feature "alarm age label Age is shown in the header", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span", text: "Age:"))
  end

  # ── 46. Type label is shown in the summary grid ──────────────────────────────

  feature "Type label is present in the alarm summary section", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span.text-content-muted.text-sm", text: "Type"))
  end

  # ── 47. Site label is shown in the summary grid ──────────────────────────────

  feature "Site label is present in the alarm summary section", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span.text-content-muted.text-sm", text: "Site"))
  end

  # ── 48. Device label is shown in the summary grid ────────────────────────────

  feature "Device label is present in the alarm summary section", %{session: session} do
    session
    |> visit(@default_path)
    |> assert_has(css("span.text-content-muted.text-sm", text: "Device"))
  end
end
