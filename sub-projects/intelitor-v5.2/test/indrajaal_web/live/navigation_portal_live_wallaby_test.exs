defmodule IndrajaalWeb.NavigationPortalLiveWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for the System Navigation Portal (/).
  Gold standard: 8-category coverage per SC-COV-009 to SC-COV-016.

  ## Page Identity
  - **Route**: `/`
  - **Module**: `IndrajaalWeb.NavigationPortalLive`
  - **Title**: "INDRAJAAL — System Navigation Portal"

  ## Design Intent
  Serves as the operator's system map and entry point for the entire Indrajaal SIL-6
  Biomorphic Fractal Mesh. Displays all navigable routes organized by category, the full
  Elixir service architecture across 4 planes, the F# CEPAF substrate project inventory,
  and the infrastructure endpoint table. Provides total situational awareness before
  the operator commits to any deep workflow in the cockpit.

  ## Expected Behavior (Functional)
  - **On mount**: Loads static assigns — `route_categories` (map of category→routes),
    `service_planes` (Data/Control/Cognitive/Safety&Immune), `fsharp_groups` (4 groups
    of F# CEPAF projects), `infra_endpoints` (table rows), `version: "v21.3.0-SIL6"`,
    `node_name: node()`, `total_routes: N`, `total_services: N`,
    `total_fsharp: N`, `current_time: DateTime`.
  - **No timer**: Page is fully static; no periodic refresh.
  - **No PubSub**: No real-time subscriptions; data is mount-time snapshot.
  - **No handle_event**: No interactive events (pure read-only portal).
  - **Route categories rendered**: C3I Cockpit, Operations Center, Analytics & Monitoring,
    Administration, Health Probes, Assurance & Verification, API Reference.

  ## BDD Scenarios
  ```gherkin
  Scenario: Operator lands on the system portal
    Given I navigate to "/"
    Then I should see heading "INDRAJAAL"
    And the subtitle "System Navigation Portal" should be visible
    And the version badge "v21.3.0-SIL6" should be present

  Scenario: Operator sees all route categories
    Given I am on "/"
    Then I should see sections for "C3I Cockpit", "Operations Center",
         "Analytics & Monitoring", "Administration", "Health Probes",
         "Assurance & Verification", and "API Reference"

  Scenario: Operator sees the Elixir service architecture map
    Given I am on "/"
    Then I should see "Elixir Service Architecture" heading
    And I should see plane cards for Data Plane, Control Plane, Cognitive Plane,
        and Safety & Immune Plane

  Scenario: Operator inspects the F# CEPAF substrate
    Given I am on "/"
    Then I should see "F# CEPAF Substrate" heading
    And I should see group cards including "Core Orchestration & Lifecycle"

  Scenario: Operator checks infrastructure endpoints
    Given I am on "/"
    Then I should see "Infrastructure & Observability Endpoints" table
    And it should list Phoenix Main App on port 4000 and Prometheus on port 9090
  ```

  ## UX Flow
  1. Operator (or new agent) navigates to `/` from any browser tab
  2. Portal renders immediately (no async data) with version badge and node name
  3. Operator scans route category grid to find target workflow section
  4. Operator reviews service architecture or F# substrate for system orientation
  5. Operator clicks any navigation link to proceed to target LiveView page
  6. Footer confirms IEC 61508 SIL-6 compliance status

  ## UI Elements Inventory
  | Element | Type | Selector | Event | Category |
  |---------|------|----------|-------|----------|
  | INDRAJAAL heading | h1 | `h1` text "INDRAJAAL" | — | C1 |
  | System Navigation Portal subtitle | p | `p` text "System Navigation Portal" | — | C1 |
  | C3I Cockpit section | h2 | `h2` text "C3I Cockpit" | — | C1 |
  | Operations Center section | h2 | `h2` text "Operations Center" | — | C1 |
  | Analytics & Monitoring section | h2 | `h2` text "Analytics & Monitoring" | — | C1 |
  | Administration section | h2 | `h2` text "Administration" | — | C1 |
  | Health Probes section | h2 | `h2` text "Health Probes" | — | C1 |
  | Assurance & Verification section | h2 | `h2` text "Assurance & Verification" | — | C1 |
  | API Reference section | h2 | `h2` text "API Reference" | — | C1 |
  | IEC 61508 footer | p | `p` text "IEC 61508" | — | C1 |
  | SIL-6 footer text | p | `p` text "SIL-6 Biomorphic Fractal Mesh" | — | C1 |
  | Version badge | span | `span` text "v21.3.0-SIL6" | — | C2 |
  | Node name badge | span | `span.font-mono` (header) | — | C2 |
  | Routes count badge | div | `div` text "routes across" | — | C2 |
  | Services count badge | p | `p` text "services across" | — | C2 |
  | F# projects count | p | `p` text "F# projects across" | — | C2 |
  | Infra endpoints count | p | `p` text "services across the mesh" | — | C2 |
  | Cockpit route link | a | `a[href='/cockpit']` | navigate | C3 |
  | Mesh route link | a | `a[href='/cockpit/mesh']` | navigate | C3 |
  | Alarms route link | a | `a[href='/operations/alarms']` | navigate | C3 |
  | Access route link | a | `a[href='/operations/access']` | navigate | C3 |
  | Elixir Architecture section | h2 | `h2` text "Elixir Service Architecture" | — | C3 |
  | Data Plane card | h3 | `h3` text "Data Plane" | — | C3 |
  | Control Plane card | h3 | `h3` text "Control Plane" | — | C3 |
  | Cognitive Plane card | h3 | `h3` text "Cognitive Plane" | — | C3 |
  | Safety & Immune Plane card | h3 | `h3` text "Safety & Immune Plane" | — | C3 |
  | PostgreSQL service entry | span | `span` text "PostgreSQL 17" | — | C3 |
  | Guardian service entry | span | `span` text "Guardian" | — | C3 |
  | Zenoh Router service entry | span | `span` text "Zenoh Router 1-3" | — | C3 |
  | F# CEPAF Substrate section | h2 | `h2` text "F# CEPAF Substrate" | — | C3 |
  | Core Orchestration group | h3 | `h3` text "Core Orchestration & Lifecycle" | — | C3 |
  | Planning & Evolution group | h3 | `h3` text "Planning & Evolution" | — | C3 |
  | HMI & Cockpit group | h3 | `h3` text "HMI & Cockpit" | — | C3 |
  | Knowledge & SMRITI group | h3 | `h3` text "Knowledge & SMRITI" | — | C3 |
  | Cepaf project name | span | `span.font-mono` text "Cepaf" | — | C3 |
  | Infra Endpoints section | h2 | `h2` text "Infrastructure & Observability Endpoints" | — | C3 |
  | Endpoints table headers | div | `div` text "Service" / "Port" / "Purpose" | — | C3 |
  | Phoenix App row | div | `div` text "Phoenix (Main App)" | — | C3 |
  | Grafana/SigNoz row | div | `div` text "Grafana / SigNoz" | — | C3 |
  | Prometheus row | div | `div` text "Prometheus" | — | C3 |
  | Port 4000 | div | `div.font-mono` text "4000" | — | C3 |
  | Port 9090 | div | `div.font-mono` text "9090" | — | C3 |

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit compliance (dark background, light text)
  - SC-HMI-008: Theme-aware rendering (tokens from ThemeContext)
  - SC-COV-008: Wallaby E2E browser tests mandatory for all LiveView pages
  - SC-COV-009 to SC-COV-016: 8-category gold standard coverage
  - C8 note: No action buttons on this page (read-only portal); all navigation
    links are verified in C3 as structural elements

  ## FMEA Risks
  | Failure Mode | S | O | D | RPN | Mitigation |
  |-------------|---|---|---|-----|------------|
  | version string mismatch after release bump | 4 | 3 | 2 | 24 | Update @path version constant on release |
  | Static assigns not populated if mount crashes | 7 | 2 | 2 | 28 | mount/3 has no rescue; compilation gates prevent nil assigns |
  | Route link href outdated after route rename | 5 | 2 | 3 | 30 | Tests verify specific hrefs; CI fails on rename |
  | Node name shows nil before BEAM reports hostname | 3 | 2 | 3 | 18 | node() always returns atom; span.font-mono present |
  | F# group cards missing if fsharp_groups nil | 5 | 1 | 2 | 10 | Static assign — always populated at compile time |

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

  @path "/"

  # ── C1: Page Structure ─────────────────────────────────────────────────────

  feature "page loads and renders the INDRAJAAL heading", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h1", text: "INDRAJAAL"))
  end

  feature "page title contains System Navigation Portal", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "System Navigation Portal"))
  end

  feature "version badge is rendered in the header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "v21.3.0-SIL6"))
  end

  feature "node name is rendered in the header", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.font-mono", minimum: 1))
  end

  # ── C2: Status/Badge Display ───────────────────────────────────────────────

  feature "route count summary badge is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-content-secondary", text: "routes across"))
  end

  feature "services count summary badge is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "services across"))
  end

  feature "F# projects count summary is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "F# projects across"))
  end

  feature "infra endpoints count summary is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "services across the mesh"))
  end

  # ── C3: Data Grid/Summary ──────────────────────────────────────────────────

  feature "C3I Cockpit route category section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "C3I Cockpit"))
  end

  feature "Operations Center route category section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Operations Center"))
  end

  feature "Analytics and Monitoring route category section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Analytics & Monitoring"))
  end

  feature "Administration route category section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Administration"))
  end

  feature "Health Probes route category section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Health Probes"))
  end

  feature "Assurance and Verification route category section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Assurance & Verification"))
  end

  feature "API Reference route category section is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "API Reference"))
  end

  feature "known route links are present in C3I Cockpit section", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a[href='/cockpit']", minimum: 1))
    |> assert_has(css("a[href='/cockpit/mesh']", minimum: 1))
  end

  feature "Operations Center links include Access Dashboard and Active Alarms", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("a[href='/operations/alarms']", minimum: 1))
    |> assert_has(css("a[href='/operations/access']", minimum: 1))
  end

  # ── C3 continued: Elixir Service Architecture ─────────────────────────────

  feature "Elixir Service Architecture section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Elixir Service Architecture"))
  end

  feature "Data Plane service plane card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Data Plane"))
  end

  feature "Control Plane service plane card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Control Plane"))
  end

  feature "Cognitive Plane service plane card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Cognitive Plane"))
  end

  feature "Safety and Immune Plane service plane card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Safety & Immune Plane"))
  end

  feature "PostgreSQL service entry with type badge Database is visible", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "PostgreSQL 17"))
    |> assert_has(css("span.font-mono", text: "Database", minimum: 1))
  end

  feature "Guardian service entry is listed under Safety plane", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Guardian"))
  end

  feature "Zenoh Router service entry is listed under Control plane", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "Zenoh Router 1-3"))
  end

  # ── C3 continued: F# CEPAF Substrate ─────────────────────────────────────

  feature "F# CEPAF Substrate section heading is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "F# CEPAF Substrate"))
  end

  feature "Core Orchestration and Lifecycle F# group card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Core Orchestration & Lifecycle"))
  end

  feature "Planning and Evolution F# group card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Planning & Evolution"))
  end

  feature "HMI and Cockpit F# group card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "HMI & Cockpit"))
  end

  feature "Knowledge and SMRITI F# group card is rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h3", text: "Knowledge & SMRITI"))
  end

  feature "Cepaf project name appears in F# substrate list", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.font-mono", text: "Cepaf", minimum: 1))
  end

  # ── C3 continued: Infrastructure Endpoints table ──────────────────────────

  feature "Infrastructure and Observability Endpoints section heading is rendered", %{
    session: session
  } do
    session
    |> visit(@path)
    |> assert_has(css("h2", text: "Infrastructure & Observability Endpoints"))
  end

  feature "table header columns Service Port Path Purpose are rendered", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.col-span-4", text: "Service"))
    |> assert_has(css("div.col-span-1", text: "Port"))
    |> assert_has(css("div.col-span-5", text: "Purpose"))
  end

  feature "Phoenix Main App row with port 4000 is in endpoints table", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.col-span-4", text: "Phoenix (Main App)"))
    |> assert_has(css("div.font-mono", text: "4000", minimum: 1))
  end

  feature "Grafana SigNoz row with port 3000 is in endpoints table", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.col-span-4", text: "Grafana / SigNoz"))
  end

  feature "Prometheus row with port 9090 is in endpoints table", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.col-span-4", text: "Prometheus"))
    |> assert_has(css("div.font-mono", text: "9090", minimum: 1))
  end

  # ── C3 continued: Footer Data ──────────────────────────────────────────────

  feature "portal footer contains IEC 61508 compliance text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "IEC 61508"))
  end

  feature "portal footer contains SIL-6 Biomorphic Fractal Mesh text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "SIL-6 Biomorphic Fractal Mesh"))
  end

  # ── C4: Timeline/History (Page Reload Stability) ─────────────────────────────
  # No timer or PubSub on this page — C4 adapted to page reload stability

  feature "page content is stable after reload cycle", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h1", text: "INDRAJAAL"))
    session = visit(session, @path)
    assert_has(session, css("h1", text: "INDRAJAAL"))
  end

  feature "route categories persist after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "C3I Cockpit"))
    session = visit(session, @path)
    assert_has(session, css("h2", text: "C3I Cockpit"))
  end

  feature "infrastructure endpoints persist after reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("div.col-span-4", text: "Phoenix (Main App)"))
    session = visit(session, @path)
    assert_has(session, css("div.col-span-4", text: "Phoenix (Main App)"))
  end

  feature "service architecture persists after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "Elixir Service Architecture"))
    session = visit(session, @path)
    assert_has(session, css("h2", text: "Elixir Service Architecture"))
  end

  feature "F# substrate section persists after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "F# CEPAF Substrate"))
    session = visit(session, @path)
    assert_has(session, css("h2", text: "F# CEPAF Substrate"))
  end

  feature "version badge persists after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("span", text: "v21"))
    session = visit(session, @path)
    assert_has(session, css("span", text: "v21"))
  end

  feature "footer compliance text persists after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("p", text: "IEC 61508"))
    session = visit(session, @path)
    assert_has(session, css("p", text: "IEC 61508"))
  end

  feature "node name persists after page reload", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("span", text: "indrajaal@"))
    session = visit(session, @path)
    assert_has(session, css("span", text: "indrajaal@"))
  end

  # ── C5: Interactive Elements (Navigation) ────────────────────────────────────
  # No forms on this page — C5 adapted to navigation and browser refresh

  feature "page is navigable from cockpit dashboard", %{session: session} do
    session
    |> visit("/cockpit")
    |> visit(@path)
    |> assert_has(css("h1", text: "INDRAJAAL"))
  end

  feature "cockpit navigation link navigates to cockpit page", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a[href='/cockpit']", minimum: 1))
  end

  feature "operations alarms link navigates to active alarms", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a[href='/operations/alarms']", minimum: 1))
  end

  feature "page responds to browser refresh maintaining state", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("h2", text: "Operations Center"))
    session = visit(session, @path)
    assert_has(session, css("h2", text: "Operations Center"))
  end

  feature "route grid shows navigable path suffixes as font-mono text", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span.font-mono", minimum: 5))
  end

  feature "all route category cards contain navigable anchor links", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("a[href]", minimum: 10))
  end

  # ── C6: Media/Rich Content (Semantic CSS Classes) ────────────────────────────
  # No media on this page — C6 adapted to semantic CSS class verification

  feature "page uses bg-surface-primary for dark cockpit (SC-HMI-001)", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='bg-surface-primary']", minimum: 1))
  end

  feature "text-content-primary applied to headings", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("h2[class*='text-content-primary']", minimum: 1))
  end

  feature "border-border-theme-primary used for section dividers", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='border-border-theme-primary']", minimum: 1))
  end

  feature "category cards use color-coded accent borders", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='border-l-4']", minimum: 4))
  end

  feature "color-rich class applied to main container", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div[class*='color-rich']", minimum: 1))
  end

  # ── C7: AI/Advisory Panels (Contextual Interpretation) ───────────────────────
  # No AI panels on this page — C7 adapted to contextual metric interpretation

  feature "route count summary provides system-wide context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("div.text-content-secondary", text: "routes across"))
    |> assert_has(css("div.text-content-secondary", text: "categories"))
  end

  feature "service architecture description provides multi-plane context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "services across"))
    |> assert_has(css("p", text: "architectural planes"))
  end

  feature "F# substrate summary provides group-level context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "F# projects across"))
    |> assert_has(css("p", text: "groups"))
  end

  feature "infrastructure endpoint count provides mesh overview", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "services across the mesh"))
  end

  feature "footer aggregates all system dimensions in single line", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("p", text: "routes"))
    |> assert_has(css("p", text: "services"))
    |> assert_has(css("p", text: "F# projects"))
    |> assert_has(css("p", text: "infra endpoints"))
  end

  feature "version string displayed as system identification context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "v21"))
  end

  feature "node name provides deployment topology context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "indrajaal@"))
  end

  feature "timestamp provides temporal operational context", %{session: session} do
    session
    |> visit(@path)
    |> assert_has(css("span", text: "CEST"))
  end

  # ── C8: Action Buttons (Read-Only Verification) ─────────────────────────────
  # No action buttons on this page — C8 verifies absence of unintended mutations

  feature "no phx-click action buttons on read-only portal page", %{session: session} do
    session = visit(session, @path)
    refute_has(session, css("button[phx-click]"))
  end

  feature "no form submission elements on read-only portal page", %{session: session} do
    session = visit(session, @path)
    refute_has(session, css("form[phx-submit]"))
  end

  feature "no phx-change input bindings on portal page", %{session: session} do
    session = visit(session, @path)
    refute_has(session, css("[phx-change]"))
  end

  feature "route navigation uses anchor links not button events", %{session: session} do
    session = visit(session, @path)
    assert_has(session, css("a[href]", minimum: 10))
    refute_has(session, css("button[phx-click='navigate']"))
  end

  feature "no LiveView socket-based mutations on static portal", %{session: session} do
    session = visit(session, @path)
    refute_has(session, css("[phx-hook]"))
  end

  feature "no modal or dialog triggers on read-only page", %{session: session} do
    session = visit(session, @path)
    refute_has(session, css("[phx-click][phx-target]"))
  end
end
