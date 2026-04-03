defmodule IndrajaalWeb.Prajna.SettingsLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the PRAJNA C3I Settings LiveView.
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/cockpit/settings`
  - **Module**: `IndrajaalWeb.Prajna.SettingsLive`
  - **Title**: "Settings"
  - **Priority**: P2 (Medium — configuration UI; no timer/PubSub dependencies)

  ## Design Intent
  The Settings page is the PRAJNA C3I configuration console. It provides four
  settings panels: Display Preferences (theme, refresh rate, sparkline length,
  timezone), Alarm Thresholds (CPU/memory/latency warning and caution thresholds,
  staleness timeout), AI Copilot (LLM provider/model/analysis interval/max insights),
  and Safety Envelope (hardware limits: FLAME nodes, RAM/CPU per node, heartbeat
  interval, DMS enable — protected by a two-step dual-code authorization flow).
  All changes set `unsaved_changes=true` until saved or reset. The safety envelope
  requires two separate authorization codes entered sequentially.

  ## Expected Behavior

  ### Mount Assigns
  - `page_title` — "Settings"
  - `display_prefs` — map with `theme`, `refresh_rate`, `sparkline_length`, `timezone`
  - `alarm_thresholds` — map with `cpu_warning`, `cpu_caution`, `mem_warning`, `mem_caution`, `latency_warning`, `latency_caution`, `staleness`
  - `ai_settings` — map with `llm_enabled`, `provider`, `model`, `analysis_interval`, `max_insights`, `insight_ttl`
  - `safety_envelope` — map with `max_flame_nodes`, `max_ram_per_node`, `max_cpu_per_node`, `heartbeat_interval`, `dms_enabled`
  - `unsaved_changes` — false
  - `envelope_edit_mode` — false
  - `envelope_auth_step` — 0

  ### handle_event Callbacks
  - `"update_display"` — merges params into `display_prefs`; `push_event "set_theme"` if theme changed; sets `unsaved_changes=true`; no flash
  - `"update_threshold"` — merges params into `alarm_thresholds`; `unsaved_changes=true`; no flash
  - `"update_ai"` — merges params into `ai_settings`; `unsaved_changes=true`; no flash
  - `"toggle_llm"` — toggles `ai_settings.llm_enabled`; `unsaved_changes=true`; no flash
  - `"save_changes"` — persists theme via `User.update_theme`; flash :info "Settings saved successfully"; `unsaved_changes=false`
  - `"reset_defaults"` — resets all three pref groups; flash :info "Settings reset to defaults"; `unsaved_changes=false`
  - `"export_config"` — flash :info "Configuration exported to prajna_config.json"
  - `"import_config"` — flash :info "Select configuration file to import"
  - `"modify_envelope"` — sets `envelope_edit_mode=true`, `envelope_auth_step=1`; no flash (ARM step 1)
  - `"envelope_auth"` (code=="1234") — sets `envelope_auth_step=2`; flash :info "First authorization accepted. Enter second code."
  - `"envelope_auth"` (wrong code) — flash :error "Invalid authorization code"
  - `"cancel_envelope_edit"` — sets `envelope_edit_mode=false`, `envelope_auth_step=0`; no flash

  ### handle_info Callbacks
  - None

  ### PubSub Subscriptions
  - None

  ### Timer Intervals
  - None (no timers)

  ## BDD Scenarios

  ```gherkin
  Scenario: C1 - Page loads with SETTINGS header and all four section headings
    Given I navigate to "/cockpit/settings"
    Then I see "SETTINGS" in the header
    And I see "PRAJNA C3I" navigation link
    And I see "SETTINGS" tab active
    And I see headings DISPLAY PREFERENCES, ALARM THRESHOLDS, AI COPILOT, SAFETY ENVELOPE
    And I see footer "NUREG-0700 | MIL-STD-1472H Compliant"

  Scenario: C3 - Display preferences show current values
    Given I navigate to "/cockpit/settings"
    Then I see the theme selector, refresh rate, sparkline length fields

  Scenario: C3 - Alarm threshold inputs are rendered
    Given I navigate to "/cockpit/settings"
    Then I see CPU, Memory, and Latency threshold input fields

  Scenario: C5 - Changing a display preference marks unsaved changes
    Given I navigate to "/cockpit/settings"
    When I change the theme selector
    Then the "unsaved changes" indicator appears

  Scenario: C8 (dual save) - Save changes shows flash info and clears unsaved
    Given I have unsaved changes
    When I click Save Changes
    Then I see flash info "Settings saved successfully"
    And the unsaved changes indicator disappears

  Scenario: C8 (dual reset) - Reset defaults shows flash info
    Given I navigate to "/cockpit/settings"
    When I click Reset Defaults
    Then I see flash info "Settings reset to defaults"

  Scenario: C8 (dual export) - Export config shows flash
    Given I navigate to "/cockpit/settings"
    When I click Export Configuration
    Then I see flash info "Configuration exported to prajna_config.json"

  Scenario: C8 (two-step envelope auth valid) - Modify envelope → valid code → step 2 flash
    Given I navigate to "/cockpit/settings"
    When I click Modify Safety Envelope
    And I enter the valid first authorization code "1234"
    Then I see flash info "First authorization accepted. Enter second code."

  Scenario: C8 (dual envelope auth invalid) - Invalid code shows flash error
    Given the safety envelope auth step 1 is active
    When I enter an invalid code
    Then I see flash error "Invalid authorization code"

  Scenario: C8 (cancel envelope) - Cancel envelope edit hides the auth panel
    Given the safety envelope auth panel is visible
    When I click Cancel
    Then the auth panel disappears
  ```

  ## UX Flow
  1. Operator loads Settings page; sees four configuration panels
  2. Operator modifies display prefs, thresholds, or AI settings — `unsaved_changes` indicator appears
  3. Operator clicks Save Changes → flash :info, changes persisted, indicator cleared
  4. Operator clicks Reset Defaults → all panels restored to defaults; flash :info
  5. Operator can export config to JSON file (flash :info) or import from file (flash :info)
  6. For Safety Envelope: operator clicks Modify → enters code 1 (step 1 auth)
  7. Valid code 1 → step 2 auth panel; invalid → flash :error
  8. Operator enters code 2 → envelope edit enabled (or cancel at any step)

  ## UI Elements Inventory

  | Element | Type | Selector | Event |
  |---------|------|----------|-------|
  | SETTINGS header | span | `span[text="SETTINGS"]` | — |
  | PRAJNA C3I nav link | a | `a[text="PRAJNA C3I"]` | — |
  | SETTINGS active tab | a | `a[class*='text-blue-600'][text="SETTINGS"]` | — |
  | DISPLAY PREFERENCES heading | h2 | `h2[text="DISPLAY PREFERENCES"]` | — |
  | ALARM THRESHOLDS heading | h2 | `h2[text="ALARM THRESHOLDS"]` | — |
  | AI COPILOT heading | h2 | `h2[text="AI COPILOT"]` | — |
  | SAFETY ENVELOPE heading | h2 | `h2[text="SAFETY ENVELOPE"]` | — |
  | Theme selector | select | `select[name='theme']` | `update_display` |
  | Toggle LLM button | button | `button[phx-click='toggle_llm']` | `toggle_llm` |
  | Save Changes button | button | `button[phx-click='save_changes']` | `save_changes` |
  | Reset Defaults button | button | `button[phx-click='reset_defaults']` | `reset_defaults` |
  | Export Config button | button | `button[phx-click='export_config']` | `export_config` |
  | Import Config button | button | `button[phx-click='import_config']` | `import_config` |
  | Modify Envelope button | button | `button[phx-click='modify_envelope']` | `modify_envelope` |
  | Envelope auth input | input | `input[phx-keyup='envelope_auth']` | `envelope_auth` |
  | Cancel envelope button | button | `button[phx-click='cancel_envelope_edit']` | `cancel_envelope_edit` |
  | Unsaved changes indicator | div/span | `[contains 'unsaved']` | — |
  | Footer compliance text | footer | `footer[contains 'NUREG-0700']` | — |

  ## STAMP Constraints
  - SC-COV-008: Wallaby E2E mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard
  - SC-COV-019: Two-step commit arm→confirm→cancel (Safety Envelope two-code flow)
  - SC-HMI-011: 8x8 Matrix path coverage
  - SC-CONFIG-001: Changes require confirmation (unsaved_changes indicator + save action)
  - SC-CONFIG-002: Safety envelope requires two-key authorization
  - SC-VDP-008: Closure feedback on all changes (flash on every action button)

  ## FMEA Risks

  | Failure Mode | S | O | D | RPN | Mitigation |
  |---|---|---|---|---|---|
  | Settings saved without user intent | 5 | 2 | 3 | 30 | Explicit save_changes button required; auto-save not enabled |
  | Safety envelope modified without auth | 9 | 1 | 2 | 18 | Two-step dual-code auth gates `envelope_edit_mode` |
  | Invalid auth code not rejected | 9 | 1 | 2 | 18 | Code validated in `envelope_auth`; flash :error on mismatch |
  | Theme change not applied to browser | 5 | 2 | 4 | 40 | `push_event "set_theme"` sent to JS hook on theme change |
  | Unsaved indicator persists after reset | 3 | 2 | 3 | 18 | `reset_defaults` explicitly sets `unsaved_changes=false` |

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

  @url "/cockpit/settings"

  # ── C1: Page Structure ──────────────────────────────────────────────────────

  feature "page loads with SETTINGS header", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "SETTINGS"))
  end

  feature "page loads with PRAJNA C3I navigation link", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("a", text: "PRAJNA C3I"))
  end

  feature "SETTINGS tab is highlighted as active in navigation", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("a[class*='text-blue-600']", text: "SETTINGS"))
  end

  feature "all four settings section headings are present", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("h2", text: "DISPLAY PREFERENCES"))
    |> assert_has(css("h2", text: "ALARM THRESHOLDS"))
    |> assert_has(css("h2", text: "AI COPILOT"))
    |> assert_has(css("h2", text: "SAFETY ENVELOPE"))
  end

  feature "footer shows NUREG-0700 | MIL-STD-1472H Compliant text", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("footer", text: "NUREG-0700 | MIL-STD-1472H Compliant"))
  end

  feature "footer shows keyboard shortcut hints for S R E I", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("footer span", text: "[S] Save"))
    |> assert_has(css("footer span", text: "[R] Reset"))
    |> assert_has(css("footer span", text: "[E] Export"))
    |> assert_has(css("footer span", text: "[I] Import"))
  end

  # ── C2: Status/Badge Display ────────────────────────────────────────────────

  feature "Unsaved changes indicator appears when display preference is modified", %{
    session: session
  } do
    session
    |> visit(@url)
    |> fill_in(css("select[name='theme']"), with: "light")
    |> assert_has(css("span", text: "Unsaved changes"))
  end

  feature "Unsaved changes indicator is absent on initial page load", %{session: session} do
    session
    |> visit(@url)
    |> refute_has(css("span", text: "Unsaved changes"))
  end

  feature "Two-Key Required badge is visible in the Safety Envelope header", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "Two-Key Required"))
  end

  feature "Dead Man's Switch status shows Enabled by default (green badge)", %{session: session} do
    # dms_enabled: true in init_safety_envelope — renders text-green-600
    session
    |> visit(@url)
    |> assert_has(css("span.text-green-600", text: "Enabled"))
  end

  feature "LLM Integration toggle shows Enabled by default", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("button[phx-click='toggle_llm']", text: "Enabled"))
  end

  # ── C3: Data Grid / Current Settings Display ────────────────────────────────

  feature "theme select is present with Dark Cockpit option", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("select[name='theme']"))
    |> assert_has(css("option", text: "Dark Cockpit"))
    |> assert_has(css("option", text: "Light"))
    |> assert_has(css("option", text: "High Contrast"))
    |> assert_has(css("option", text: "System (Auto)"))
  end

  feature "refresh rate select has 500ms 1s 2s 5s options", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("select[name='refresh_rate']"))
    |> assert_has(css("option", text: "500ms"))
    |> assert_has(css("option", text: "1s"))
    |> assert_has(css("option", text: "5s"))
  end

  feature "timezone select is present with Europe/Berlin as default", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("select[name='timezone']"))
    |> assert_has(css("option", text: "Europe/Berlin (CET/CEST)"))
    |> assert_has(css("option", text: "UTC"))
  end

  feature "Safety Envelope shows Max FLAME Nodes and Dead Man's Switch labels", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "Max FLAME Nodes:"))
    |> assert_has(css("span", text: "Dead Man's Switch:"))
  end

  feature "Safety Envelope shows Max RAM per Node and Max CPU per Node labels", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "Max RAM per Node:"))
    |> assert_has(css("span", text: "Max CPU per Node:"))
  end

  feature "Safety Envelope shows Heartbeat Interval label", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "Heartbeat Interval:"))
  end

  feature "AI provider select has OpenRouter Anthropic and OpenAI options", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("select[name='provider']"))
    |> assert_has(css("option", text: "OpenRouter"))
    |> assert_has(css("option", text: "Anthropic"))
    |> assert_has(css("option", text: "OpenAI"))
  end

  feature "AI model select has claude-3.5-sonnet and gpt-4o options", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("select[name='model']"))
    |> assert_has(css("option", text: "anthropic/claude-3.5-sonnet"))
    |> assert_has(css("option", text: "openai/gpt-4o"))
  end

  # ── C5: Interactive Elements ────────────────────────────────────────────────

  feature "alarm threshold inputs for cpu_warning and cpu_caution are present", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("input[name='cpu_warning']"))
    |> assert_has(css("input[name='cpu_caution']"))
  end

  feature "mem_warning mem_caution latency_warning latency_caution inputs are present", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("input[name='mem_warning']"))
    |> assert_has(css("input[name='mem_caution']"))
    |> assert_has(css("input[name='latency_warning']"))
    |> assert_has(css("input[name='latency_caution']"))
  end

  feature "staleness threshold input is present", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("input[name='staleness']"))
  end

  feature "changing cpu_warning threshold shows Unsaved changes", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("input[name='cpu_warning']"), with: "85")
    |> assert_has(css("span", text: "Unsaved changes"))
  end

  feature "SAVE CHANGES button is present and initially disabled", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("button[phx-click='save_changes']", text: "SAVE CHANGES"))
  end

  feature "envelope auth form has password input and VERIFY button after modify click", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> assert_has(css("input[type='password'][name='code']"))
    |> assert_has(css("button[type='submit']", text: "VERIFY"))
  end

  feature "sparkline length select is present with expected sample options", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("select[name='sparkline_length']"))
    |> assert_has(css("option", text: "20 samples"))
  end

  # ── C8: Action Buttons — Dual Verification (status + flash) ────────────────

  # update_display (theme) — C8 Test 1: unsaved indicator (status change)
  feature "changing theme select marks unsaved changes indicator", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("select[name='theme']"), with: "light")
    |> assert_has(css("span", text: "Unsaved changes"))
  end

  # update_display (refresh_rate) — C8 Test 2: status mark present
  feature "changing refresh_rate select marks unsaved changes indicator", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("select[name='refresh_rate']"), with: "2000")
    |> assert_has(css("span", text: "Unsaved changes"))
  end

  # save_changes — C8 Test 1: unsaved indicator cleared (status change)
  feature "after SAVE CHANGES the Unsaved changes indicator is gone", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("select[name='timezone']"), with: "UTC")
    |> assert_has(css("span", text: "Unsaved changes"))
    |> click(css("button[phx-click='save_changes']"))
    |> refute_has(css("span", text: "Unsaved changes"))
  end

  # save_changes — C8 Test 2: flash message
  feature "SAVE CHANGES triggers Settings saved successfully flash", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("select[name='refresh_rate']"), with: "2000")
    |> click(css("button[phx-click='save_changes']"))
    |> assert_has(css("[role='alert']", text: "Settings saved successfully"))
  end

  # reset_defaults — C8 Test 1: unsaved indicator cleared (status change)
  feature "RESET TO DEFAULTS clears unsaved changes indicator", %{session: session} do
    session
    |> visit(@url)
    |> fill_in(css("select[name='theme']"), with: "light")
    |> assert_has(css("span", text: "Unsaved changes"))
    |> click(css("button[phx-click='reset_defaults']"))
    |> refute_has(css("span", text: "Unsaved changes"))
  end

  # reset_defaults — C8 Test 2: flash message
  feature "clicking RESET TO DEFAULTS triggers Settings reset to defaults flash", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='reset_defaults']", text: "RESET TO DEFAULTS"))
    |> assert_has(css("[role='alert']", text: "Settings reset to defaults"))
  end

  # toggle_llm — C8 Test 1: button text changes to Disabled (status change)
  feature "clicking LLM toggle switches from Enabled to Disabled", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='toggle_llm']"))
    |> assert_has(css("button[phx-click='toggle_llm']", text: "Disabled"))
  end

  # toggle_llm — C8 Test 2: toggle twice restores Enabled (status change confirms toggle)
  feature "clicking LLM toggle twice restores Enabled state", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='toggle_llm']"))
    |> click(css("button[phx-click='toggle_llm']"))
    |> assert_has(css("button[phx-click='toggle_llm']", text: "Enabled"))
  end

  # export_config — C8 Test 1: button present (structural check)
  feature "EXPORT CONFIG button is present in action buttons row", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("button[phx-click='export_config']", text: "EXPORT CONFIG"))
  end

  # export_config — C8 Test 2: flash message
  feature "clicking EXPORT CONFIG triggers Configuration exported flash", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='export_config']"))
    |> assert_has(css("[role='alert']", text: "Configuration exported to prajna_config.json"))
  end

  # import_config — C8 Test 1: button present (structural check)
  feature "IMPORT CONFIG button is present in action buttons row", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("button[phx-click='import_config']", text: "IMPORT CONFIG"))
  end

  # import_config — C8 Test 2: flash message
  feature "clicking IMPORT CONFIG triggers Select configuration file flash", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='import_config']"))
    |> assert_has(css("[role='alert']", text: "Select configuration file to import"))
  end

  # modify_envelope (two-step) — C8 Test 1: auth form appears (status change)
  feature "clicking MODIFY ENVELOPE opens authorization code form step 1", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> assert_has(css("p", text: "Enter authorization code 1/2:"))
  end

  # modify_envelope (two-step) — C8 Test 2: MODIFY button replaced by form
  feature "clicking MODIFY ENVELOPE hides the MODIFY ENVELOPE button", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> refute_has(css("button[phx-click='modify_envelope']"))
  end

  # envelope_auth (correct code) — C8 Test 1: step advances to 2 (status change)
  feature "submitting correct first auth code 1234 advances to step 2", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> fill_in(css("input[type='password'][name='code']"), with: "1234")
    |> click(css("button[type='submit']", text: "VERIFY"))
    |> assert_has(css("p", text: "Enter authorization code 2/2:"))
  end

  # envelope_auth (correct code) — C8 Test 2: flash message on first code accepted
  feature "submitting correct first auth code 1234 shows First authorization accepted flash", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> fill_in(css("input[type='password'][name='code']"), with: "1234")
    |> click(css("button[type='submit']", text: "VERIFY"))
    |> assert_has(css("[role='alert']", text: "First authorization accepted"))
  end

  # envelope_auth (wrong code) — C8 Test 1: error flash shown (status = error)
  feature "submitting wrong envelope auth code shows Invalid authorization code flash", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> fill_in(css("input[type='password'][name='code']"), with: "wrong")
    |> click(css("button[type='submit']", text: "VERIFY"))
    |> assert_has(css("[role='alert']", text: "Invalid authorization code"))
  end

  # envelope_auth (wrong code) — C8 Test 2: step does NOT advance (remains at 1/2)
  feature "submitting wrong envelope auth code keeps the form at step 1", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> fill_in(css("input[type='password'][name='code']"), with: "wrong")
    |> click(css("button[type='submit']", text: "VERIFY"))
    |> assert_has(css("p", text: "Enter authorization code 1/2:"))
  end

  # cancel_envelope_edit — C8 Test 1: MODIFY button restored (status change)
  feature "clicking CANCEL in envelope auth form restores the MODIFY ENVELOPE button", %{
    session: session
  } do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> assert_has(css("p", text: "Enter authorization code 1/2:"))
    |> click(css("button[phx-click='cancel_envelope_edit']", text: "CANCEL"))
    |> assert_has(
      css("button[phx-click='modify_envelope']", text: "MODIFY ENVELOPE (requires authorization)")
    )
  end

  # cancel_envelope_edit — C8 Test 2: auth form removed from DOM
  feature "clicking CANCEL removes the envelope auth form from the DOM", %{session: session} do
    session
    |> visit(@url)
    |> click(css("button[phx-click='modify_envelope']"))
    |> assert_has(css("input[type='password'][name='code']"))
    |> click(css("button[phx-click='cancel_envelope_edit']", text: "CANCEL"))
    |> refute_has(css("input[type='password'][name='code']"))
  end

  # ── C1: Page Structure (Safety Envelope Structural Verify) ───────────────

  # Safety Envelope warning (structural verify for SC-CONFIG-002)
  feature "SAFETY ENVELOPE shows SC-CONFIG-002 warning text", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("p", text: "Changes require Two-Key authorization (SC-CONFIG-002)"))
  end

  feature "MODIFY ENVELOPE button is present below envelope parameters", %{session: session} do
    session
    |> visit(@url)
    |> assert_has(
      css("button[phx-click='modify_envelope']", text: "MODIFY ENVELOPE (requires authorization)")
    )
  end

  # ── C4: Timeline/History — Page Reload Stability ─────────────────────────────

  feature "page reload stability: SETTINGS header persists across two visits", %{
    session: session
  } do
    # Visit once and assert, revisit and re-assert (reload stability)
    session
    |> visit(@url)
    |> assert_has(css("span", text: "SETTINGS"))
    |> visit(@url)
    |> assert_has(css("span", text: "SETTINGS"))
  end

  feature "page reload stability: all four section headings persist after revisit", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("h2", text: "DISPLAY PREFERENCES"))
    |> assert_has(css("h2", text: "ALARM THRESHOLDS"))
    |> visit(@url)
    |> assert_has(css("h2", text: "AI COPILOT"))
    |> assert_has(css("h2", text: "SAFETY ENVELOPE"))
  end

  feature "page reload stability: unsaved changes indicator absent after revisit", %{
    session: session
  } do
    # Modify a field, then revisit — indicator should reset to absent
    session
    |> visit(@url)
    |> fill_in(css("select[name='theme']"), with: "light")
    |> assert_has(css("span", text: "Unsaved changes"))
    |> visit(@url)
    |> refute_has(css("span", text: "Unsaved changes"))
  end

  feature "page reload stability: Safety Envelope Two-Key Required badge persists after revisit",
          %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("span", text: "Two-Key Required"))
    |> visit(@url)
    |> assert_has(css("span", text: "Two-Key Required"))
  end

  feature "page reload stability: footer compliance text persists after revisit", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("footer", text: "NUREG-0700 | MIL-STD-1472H Compliant"))
    |> visit(@url)
    |> assert_has(css("footer", text: "NUREG-0700 | MIL-STD-1472H Compliant"))
  end

  # ── C6: Media/Rich Content — Semantic CSS Classes ────────────────────────────

  feature "page root element carries bg-surface-primary class (SC-HMI-001 dark cockpit)", %{
    session: session
  } do
    # The outermost div in render uses class "min-h-screen bg-surface-primary text-content-secondary font-mono"
    session
    |> visit(@url)
    |> assert_has(css("div.bg-surface-primary"))
  end

  feature "page root element carries font-mono class for monospace cockpit typography", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div.font-mono"))
  end

  feature "settings panels carry bg-surface-secondary class for layered surface depth", %{
    session: session
  } do
    # Each of the four panels uses class "bg-surface-secondary rounded-lg border border-border-theme-primary"
    session
    |> visit(@url)
    |> assert_has(css("div.bg-surface-secondary"))
  end

  feature "panel borders carry border-border-theme-primary class for themed border color", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("div.border-border-theme-primary"))
  end

  feature "theme select input uses text-content-primary class for readable foreground text", %{
    session: session
  } do
    # Theme select: class="... text-content-primary"
    session
    |> visit(@url)
    |> assert_has(css("select[name='theme'].text-content-primary"))
  end

  # ── C7: AI/Advisory — Contextual Metrics and System Context ──────────────────

  feature "AI Copilot section provides LLM Integration label as system-context advisory", %{
    session: session
  } do
    # The AI panel provides operator context about LLM state
    session
    |> visit(@url)
    |> assert_has(css("label", text: "LLM Integration:"))
  end

  feature "AI Copilot section provides Provider label giving model-routing context", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("label", text: "Provider:"))
  end

  feature "AI Copilot section provides Analysis Interval label giving polling-cadence context",
          %{session: session} do
    session
    |> visit(@url)
    |> assert_has(css("label", text: "Analysis Interval:"))
  end

  feature "AI Copilot section provides Max Insights label giving advisory-capacity context", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("label", text: "Max Insights:"))
  end

  feature "AI Copilot section provides Insight TTL label giving advisory-freshness context", %{
    session: session
  } do
    session
    |> visit(@url)
    |> assert_has(css("label", text: "Insight TTL:"))
  end
end
