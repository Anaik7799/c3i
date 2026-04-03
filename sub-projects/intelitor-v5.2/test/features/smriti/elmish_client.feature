# SMRITI Elmish Client (WS3) - GUI Acceptance Tests
# Comprehensive BDD Feature File for F# Elmish/Fable GUI
# SC-BDD-001 to SC-BDD-012 Compliance
# SC-COV-005: BDD specs for all user journeys

@smriti @elmish @gui @ws3 @sil4
Feature: SMRITI Elmish Client GUI
  As a knowledge engineer
  I want an interactive visual interface for exploring knowledge graphs
  So that I can intuitively navigate interconnected Zettels with real-time insights

  Background:
    Given the SMRITI API backend is running at "http://localhost:8080"
    And the Elmish client is loaded in the browser
    And the viewport size is 1920x1080 pixels
    And WebSocket connections are established
    And Cytoscape.js library is loaded

  # ============================================================================
  # SCENARIO 1: Graph Visualization with Cytoscape.js
  # ============================================================================

  @graph @visualization @cytoscape
  Scenario: Graph renders knowledge network with Cytoscape.js
    Given the API returns the following holons:
      | uuid                                 | title                | cluster     | entropy |
      | 550e8400-e29b-41d4-a716-446655440001 | System Architecture  | architecture| 0.2     |
      | 550e8400-e29b-41d4-a716-446655440002 | Testing Strategy     | testing     | 0.5     |
      | 550e8400-e29b-41d4-a716-446655440003 | Deployment Pipeline  | operations  | 0.7     |
    And edges exist:
      | source                               | target                               | edge_type |
      | 550e8400-e29b-41d4-a716-446655440001 | 550e8400-e29b-41d4-a716-446655440002 | references|
      | 550e8400-e29b-41d4-a716-446655440002 | 550e8400-e29b-41d4-a716-446655440003 | depends_on|
    When the graph page loads
    Then I should see a Cytoscape canvas element with id "cy-graph"
    And the graph should contain exactly 3 nodes
    And the graph should contain exactly 2 edges
    And node "550e8400-e29b-41d4-a716-446655440001" should have label "System Architecture"
    And node "550e8400-e29b-41d4-a716-446655440001" should have cluster badge "architecture"
    And the layout algorithm should be "cose" (force-directed)
    And all nodes should be interactive (hoverable/clickable)

  @graph @visualization @entropy-color
  Scenario: Graph nodes display entropy-based color coding
    Given nodes have varying entropy values:
      | uuid                                 | title      | entropy | expected_color |
      | 550e8400-e29b-41d4-a716-446655440001 | Fresh      | 0.1     | #22c55e (green)|
      | 550e8400-e29b-41d4-a716-446655440002 | Moderate   | 0.5     | #eab308 (yellow)|
      | 550e8400-e29b-41d4-a716-446655440003 | Stale      | 0.8     | #ef4444 (red)  |
    When the graph renders
    Then node "550e8400-e29b-41d4-a716-446655440001" should have background color "#22c55e"
    And node "550e8400-e29b-41d4-a716-446655440002" should have background color "#eab308"
    And node "550e8400-e29b-41d4-a716-446655440003" should have background color "#ef4444"
    And the color legend should display:
      | Range       | Color   | Label    |
      | 0.0 - 0.3   | Green   | Fresh    |
      | 0.3 - 0.7   | Yellow  | Moderate |
      | 0.7 - 1.0   | Red     | Stale    |

  # ============================================================================
  # SCENARIO 2: Node Selection and Detail View
  # ============================================================================

  @interaction @node-selection @detail-view
  Scenario: Clicking a node displays detailed information panel
    Given the graph contains node "550e8400-e29b-41d4-a716-446655440001" with:
      | field         | value                                |
      | title         | System Architecture Patterns         |
      | content       | Comprehensive guide to patterns...   |
      | cluster       | architecture                         |
      | entropy       | 0.25                                 |
      | created_at    | 2025-12-01T10:00:00Z                |
      | last_modified | 2025-12-10T14:30:00Z                |
      | word_count    | 1543                                 |
      | level         | molecular                            |
    When I click on node "550e8400-e29b-41d4-a716-446655440001"
    Then the detail panel should slide in from the right
    And the detail panel should be visible within 300ms
    And the panel should display title "System Architecture Patterns"
    And the panel should show entropy badge "0.25" with green background
    And the panel should show cluster badge "architecture"
    And the panel should show level badge "molecular"
    And the panel should display creation date "Dec 1, 2025"
    And the panel should display last modified "Dec 10, 2025"
    And the panel should show word count "1,543 words"
    And the panel should render content as markdown
    And the selected node should have a highlight ring/border

  @interaction @node-selection @keyboard
  Scenario: Keyboard navigation for node selection
    Given the graph contains 5 nodes
    And no node is currently selected
    When I press Tab key
    Then the first node should receive focus
    And the focus indicator should be visible
    When I press Tab key again
    Then the second node should receive focus
    When I press Enter key
    Then the detail panel for the focused node should open
    When I press Escape key
    Then the detail panel should close
    And focus should return to the graph

  # ============================================================================
  # SCENARIO 3: Search Bar with Live Results
  # ============================================================================

  @search @live-search @typeahead
  Scenario: Live search filters holons as user types
    Given the knowledge base contains:
      | title                     | content                          | cluster |
      | Alarm Processing Guide    | How to process security alarms   | alarms  |
      | Device Configuration      | Setting up IoT devices           | devices |
      | Alarm Correlation Engine  | Correlating multiple alarms      | alarms  |
      | Alarm Severity Levels     | Understanding alarm priorities   | alarms  |
    And the search bar is visible at the top of the page
    When I type "alar" into the search bar
    Then I should see a dropdown with live results
    And the dropdown should appear within 200ms
    And the results should contain "Alarm Processing Guide"
    And the results should contain "Alarm Correlation Engine"
    And the results should contain "Alarm Severity Levels"
    And the results should NOT contain "Device Configuration"
    And matching text "alar" should be highlighted in yellow
    And result count should be displayed as "3 results"

  @search @live-search @debounce
  Scenario: Search input is debounced to avoid excessive API calls
    Given the search bar is focused
    When I rapidly type "architecture" (10 characters in 500ms)
    Then the API should be called at most 2 times
    And the first API call should be debounced by 300ms
    And the search spinner should be visible during API calls
    And the spinner should disappear when results arrive

  @search @live-search @keyboard-navigation
  Scenario: Keyboard navigation through search results
    Given search results are displayed with 5 items
    When I press ArrowDown key
    Then the first result should be highlighted
    When I press ArrowDown key 2 more times
    Then the third result should be highlighted
    When I press Enter key
    Then the highlighted holon should be selected
    And the graph should center on the selected node
    And the detail panel should open for that node

  # ============================================================================
  # SCENARIO 4: Entropy Badge Visualization
  # ============================================================================

  @entropy @badge @color-coding
  Scenario: Entropy badges display with color-coded backgrounds
    Given a holon detail panel is open
    And the holon has entropy value 0.65
    When the entropy badge renders
    Then the badge should display "0.65"
    And the badge background should be "#eab308" (yellow)
    And the badge should have a pulsing animation
    And the badge should show tooltip "Moderate: Last updated 45 days ago"
    And the tooltip should appear on hover within 100ms

  @entropy @badge @threshold-alerts
  Scenario: High entropy badges show warning indicators
    Given holons with critical entropy levels:
      | uuid                                 | title        | entropy |
      | 550e8400-e29b-41d4-a716-446655440001 | Critical Doc | 0.92    |
    When the graph renders
    Then node "550e8400-e29b-41d4-a716-446655440001" should have a warning icon
    And the warning icon should be a red exclamation mark
    And the node should have a pulsing red outline
    And hovering should show tooltip "Urgent: Update required (92% decay)"

  @entropy @badge @batch-update
  Scenario: Entropy recalculation updates all badges in real-time
    Given 10 holons are visible on the graph
    And all have entropy values from API
    When the "Recalculate Entropy" button is clicked
    Then a loading spinner should appear on the button
    And the API should be called with "POST /entropy/recalculate"
    When the API responds with updated entropy values
    Then all node colors should update with smooth transitions (300ms)
    And entropy badges in detail panels should update
    And a toast notification should show "Entropy recalculated for 10 holons"

  # ============================================================================
  # SCENARIO 5: Route Navigation (Home, Zettel, Cluster, Search)
  # ============================================================================

  @routing @navigation @spa
  Scenario: Navigation bar switches between routes
    Given the Elmish app is on the Home route "/"
    When I click the "Zettel Graph" navigation link
    Then the URL should change to "/zettel"
    And the graph view should be displayed
    And the navigation link "Zettel Graph" should have "active" CSS class
    When I click the "Clusters" navigation link
    Then the URL should change to "/clusters"
    And the cluster overview should be displayed
    And the navigation link "Clusters" should have "active" CSS class
    When I click the "Search" navigation link
    Then the URL should change to "/search"
    And the search page should be displayed
    And the search input should auto-focus

  @routing @navigation @browser-history
  Scenario: Browser back/forward buttons work correctly
    Given I navigate through the following routes:
      | route      | action           |
      | /          | Initial load     |
      | /zettel    | Click "Zettel"   |
      | /clusters  | Click "Clusters" |
      | /search    | Click "Search"   |
    When I click the browser back button
    Then the URL should be "/clusters"
    And the cluster view should be displayed
    When I click the browser back button again
    Then the URL should be "/zettel"
    And the graph view should be displayed
    When I click the browser forward button
    Then the URL should be "/clusters"

  @routing @navigation @deep-links
  Scenario: Deep links to specific holons work on page load
    Given the knowledge base contains holon "550e8400-e29b-41d4-a716-446655440001"
    When I navigate directly to "/zettel/550e8400-e29b-41d4-a716-446655440001"
    Then the graph should load
    And node "550e8400-e29b-41d4-a716-446655440001" should be auto-selected
    And the detail panel should be open for that holon
    And the graph should be centered on that node

  # ============================================================================
  # SCENARIO 6: API Data Loading and Display
  # ============================================================================

  @api @loading @state-management
  Scenario: Initial page load fetches and displays holons from API
    Given the API endpoint "GET /api/holons" returns:
      """json
      {
        "holons": [
          {
            "uuid": "550e8400-e29b-41d4-a716-446655440001",
            "title": "First Zettel",
            "cluster": "test",
            "entropy": 0.3
          }
        ],
        "edges": []
      }
      """
    When the Elmish app initializes
    Then the loading spinner should be displayed
    And the spinner text should say "Loading knowledge graph..."
    When the API responds successfully
    Then the loading spinner should disappear
    And the graph should render within 500ms
    And exactly 1 node should be visible

  @api @loading @pagination
  Scenario: Large datasets load with pagination
    Given the API supports pagination with query params
    And the knowledge base contains 500 holons
    When the graph page loads
    Then the initial request should be "GET /api/holons?limit=100&offset=0"
    And 100 nodes should be rendered
    When I scroll to the bottom of the page
    Then the next request should be "GET /api/holons?limit=100&offset=100"
    And an additional 100 nodes should be appended to the graph
    And a "Loading more..." indicator should appear during fetch

  @api @loading @retry-logic
  Scenario: Failed API requests trigger retry with exponential backoff
    Given the API endpoint is temporarily unavailable
    When the Elmish app attempts to fetch holons
    Then the first retry should occur after 1 second
    And the second retry should occur after 2 seconds
    And the third retry should occur after 4 seconds
    And a toast notification should show "Retrying... (Attempt 3 of 5)"
    When the API becomes available on the 4th attempt
    Then the data should load successfully
    And the toast should show "Connected successfully"

  # ============================================================================
  # SCENARIO 7: Error State Handling in UI
  # ============================================================================

  @error @error-handling @user-feedback
  Scenario: Network errors display user-friendly error messages
    Given the API is unreachable
    When the app attempts to load holons
    Then an error message should be displayed in the main content area
    And the error message should say "Unable to connect to SMRITI backend"
    And a "Retry" button should be visible
    And a "View Offline Cache" button should be visible
    When I click the "Retry" button
    Then the API request should be retried immediately

  @error @error-handling @validation
  Scenario: Invalid holon data shows validation errors
    Given the API returns malformed JSON:
      """json
      {
        "holons": [
          {
            "uuid": "invalid-uuid",
            "title": null,
            "entropy": 1.5
          }
        ]
      }
      """
    When the app attempts to parse the data
    Then a validation error banner should appear
    And the error should say "Invalid data received from API"
    And the error details should be logged to browser console
    And the graph should remain in its previous state (no partial render)

  @error @error-handling @fallback
  Scenario: Missing API data gracefully degrades to defaults
    Given the API returns holon without optional fields:
      """json
      {
        "uuid": "550e8400-e29b-41d4-a716-446655440001",
        "title": "Minimal Zettel"
      }
      """
    When the holon is rendered
    Then the entropy should default to 0.0
    And the cluster should default to "uncategorized"
    And the node color should be green (default for 0.0 entropy)
    And no errors should be logged

  # ============================================================================
  # SCENARIO 8: Responsive Layout Behavior
  # ============================================================================

  @responsive @mobile @layout
  Scenario: Mobile viewport shows hamburger menu and stacked layout
    Given the viewport is resized to 375x667 pixels (iPhone SE)
    When the page loads
    Then the navigation bar should collapse to a hamburger menu icon
    And the graph should occupy full viewport width
    And the detail panel should slide up from bottom (not from right)
    When I click a node
    Then the detail panel should cover 60% of viewport height
    And I should be able to drag the panel to full height

  @responsive @tablet @layout
  Scenario: Tablet viewport shows split view
    Given the viewport is resized to 768x1024 pixels (iPad)
    When the page loads
    Then the navigation bar should be fully visible
    And the graph should occupy 60% of viewport width
    And the detail panel area should occupy 40% of viewport width
    When I select a node
    Then the detail panel should populate the right 40% (no slide animation)

  @responsive @desktop @layout
  Scenario: Desktop viewport shows full multi-column layout
    Given the viewport is 1920x1080 pixels
    When the page loads
    Then the navigation bar should be horizontal at the top
    And the graph should occupy 70% of viewport width
    And the detail panel should be a collapsible sidebar (30% width)
    And a minimap should be visible in the bottom-right corner
    And zoom controls should be visible in the top-right of the graph

  @responsive @zoom @accessibility
  Scenario: Graph supports zoom and pan operations
    Given the graph is displayed
    When I scroll the mouse wheel upward
    Then the graph should zoom in by 10%
    And the zoom level indicator should update to "110%"
    When I scroll the mouse wheel downward
    Then the graph should zoom out by 10%
    When I drag the graph canvas
    Then the graph should pan in the drag direction
    And the minimap should show the current viewport position

  # ============================================================================
  # SCENARIO 9: End-to-End User Journey
  # ============================================================================

  @e2e @user-journey @complete-workflow
  Scenario: Complete user journey from search to exploration
    # ACT 1: Landing and Search
    Given I am a new user visiting the SMRITI Elmish Client
    And the knowledge base contains 100 holons across 5 clusters
    When I land on the home page "/"
    Then I should see a welcome message "Explore Your Knowledge Graph"
    And I should see a prominent search bar
    And I should see cluster statistics cards:
      | cluster      | count |
      | architecture | 25    |
      | testing      | 20    |
      | operations   | 18    |
      | security     | 22    |
      | docs         | 15    |

    # ACT 2: Search and Discovery
    When I type "security patterns" into the search bar
    Then live search results should appear
    And I should see 8 matching holons
    When I click on "Authentication Patterns" from the results
    Then I should be navigated to "/zettel/[uuid]"
    And the graph should load with "Authentication Patterns" node centered
    And the detail panel should open automatically

    # ACT 3: Graph Exploration
    When I examine the detail panel
    Then I should see:
      | field         | value                        |
      | Title         | Authentication Patterns      |
      | Cluster       | security                     |
      | Entropy       | 0.4 (yellow badge)          |
      | Word Count    | 2,345 words                 |
      | Last Modified | 35 days ago                 |
    And I should see a list of connected holons (edges)
    When I click on a connected holon "OAuth2 Implementation"
    Then the graph should animate to center on that node
    And the detail panel should update within 200ms
    And the browser history should update to the new UUID

    # ACT 4: Cluster Navigation
    When I click the "Clusters" navigation link
    Then I should be navigated to "/clusters"
    And I should see a cluster visualization (treemap or sunburst)
    When I click on the "security" cluster
    Then I should be navigated to "/zettel?cluster=security"
    And the graph should filter to show only security holons
    And the node count should be 22

    # ACT 5: Entropy Analysis
    When I click the "Show High Entropy" filter toggle
    Then the graph should filter to holons with entropy > 0.7
    And nodes should be sorted by entropy (highest first)
    And I should see a warning message "5 holons require urgent review"
    When I click on the highest entropy node
    Then I should see a red "STALE" badge
    And I should see a "Mark as Reviewed" button
    When I click "Mark as Reviewed"
    Then a modal should ask for confirmation
    When I confirm
    Then the API should be called "POST /api/holons/[uuid]/review"
    And the entropy should recalculate
    And the node color should update to yellow
    And a success toast should appear "Holon marked as reviewed"

    # ACT 6: Responsive Behavior
    When I resize the viewport to 375x667 (mobile)
    Then the layout should adapt seamlessly
    And the detail panel should slide up from bottom
    And the hamburger menu should be accessible
    When I restore to desktop viewport 1920x1080
    Then the layout should return to multi-column
    And no data should be lost
    And the graph state should be preserved

    # ACT 7: Session Persistence
    When I navigate to another website
    And I return to the SMRITI client after 5 minutes
    Then the graph state should be restored from localStorage
    And the last selected holon should still be selected
    And the zoom level should be preserved
    And the filter settings should be preserved

  # ============================================================================
  # PROPERTY-BASED SCENARIOS (PropCheck/FsCheck)
  # ============================================================================

  @property @fscheck @rendering
  Scenario: Graph rendering is deterministic (Property)
    Given any set of holons from the API
    When I render the graph multiple times
    Then the node positions should be identical (given same random seed)
    And the edge connections should be identical
    And the color mappings should be identical

  @property @fscheck @performance
  Scenario: Graph performance scales linearly (Property)
    Given graphs with varying node counts:
      | nodes | max_render_time_ms |
      | 10    | 100                |
      | 100   | 500                |
      | 1000  | 2000               |
    When I measure render time
    Then the render time should be less than or equal to max_render_time_ms
    And memory usage should not exceed 100MB per 1000 nodes

  # ============================================================================
  # FMEA SCENARIOS (Failure Mode Analysis)
  # ============================================================================

  @fmea @failure-mode
  Scenario: WebSocket disconnection handling (RPN 72)
    Given the WebSocket connection is established
    When the WebSocket connection drops unexpectedly
    Then a reconnection attempt should start within 2 seconds
    And a "Connection lost" toast should appear
    And the UI should remain interactive (using cached data)
    When the WebSocket reconnects
    Then a "Connected" toast should appear
    And any pending updates should be synced

  @fmea @failure-mode
  Scenario: Browser memory exhaustion with large graphs (RPN 64)
    Given the graph contains 5000+ nodes
    When the user attempts to render all nodes at once
    Then the app should enable "virtualization mode"
    And only nodes in the visible viewport should render
    And off-screen nodes should be rendered on-demand
    And a warning should appear "Large graph detected - using optimized rendering"

  @fmea @failure-mode
  Scenario: Cytoscape.js library load failure (RPN 80)
    Given the Cytoscape.js CDN is unavailable
    When the app attempts to initialize the graph
    Then a critical error should be displayed
    And the error should say "Required graph library failed to load"
    And a "Reload Page" button should be provided
    And the app should not crash (graceful degradation)

  # ============================================================================
  # 5-ORDER EFFECTS SCENARIOS
  # ============================================================================

  @5-order-effects
  Scenario: Node selection 5-order effects
    When I click a node on the graph
    Then 1st order: Node selected event fires
    And 2nd order: Detail panel opens with slide animation
    And 3rd order: API request fetches full holon content
    And 4th order: URL updates with holon UUID
    And 5th order: Browser history entry created, shareable link generated

  @5-order-effects
  Scenario: Search query 5-order effects
    When I type a search query
    Then 1st order: Input debounce timer starts
    And 2nd order: API request sent after 300ms
    And 3rd order: Results rendered in dropdown
    And 4th order: Graph filters to matching nodes (optional)
    And 5th order: Analytics event logged for search patterns

  # ============================================================================
  # ACCESSIBILITY SCENARIOS
  # ============================================================================

  @a11y @wcag @accessibility
  Scenario: Keyboard-only navigation is fully functional
    Given I am navigating with keyboard only
    When I press Tab to navigate through the interface
    Then all interactive elements should be focusable
    And focus indicators should be clearly visible
    And Tab order should be logical (top to bottom, left to right)
    When I press Shift+Tab
    Then focus should move backward
    When I press Enter on a focused node
    Then the node should be selected (same as click)

  @a11y @wcag @accessibility
  Scenario: Screen reader support provides context
    Given I am using a screen reader
    When the graph loads
    Then the screen reader should announce "Graph loaded with [N] nodes"
    When I focus on a node
    Then the screen reader should announce:
      """
      Node: [Title]
      Cluster: [Cluster Name]
      Entropy: [Value] (High/Medium/Low)
      [N] connections
      Press Enter to view details
      """
    When I open the detail panel
    Then the screen reader should announce "Detail panel opened for [Title]"

  @a11y @wcag @accessibility
  Scenario: Color contrast meets WCAG AA standards
    Given all UI elements are rendered
    Then all text should have a contrast ratio >= 4.5:1 against backgrounds
    And interactive elements should have a contrast ratio >= 3:1
    And focus indicators should have a contrast ratio >= 3:1
    And entropy color badges should have text contrast >= 4.5:1

  # ============================================================================
  # TELEMETRY & MONITORING SCENARIOS
  # ============================================================================

  @telemetry @monitoring @observability
  Scenario: User interactions are logged to telemetry
    Given telemetry is enabled
    When I perform the following actions:
      | action          | target                |
      | click_node      | [uuid]                |
      | search          | "security patterns"   |
      | navigate        | /clusters             |
      | zoom            | 150%                  |
    Then telemetry events should be sent to the backend
    And events should include:
      | field       | value                     |
      | event_type  | user_interaction          |
      | session_id  | [unique session UUID]     |
      | timestamp   | ISO8601 format            |
      | user_agent  | [browser info]            |

  @telemetry @monitoring @performance
  Scenario: Performance metrics are captured and reported
    Given performance monitoring is active
    When the graph renders
    Then the following metrics should be captured:
      | metric                  | threshold   |
      | time_to_first_paint     | < 500ms     |
      | time_to_interactive     | < 1500ms    |
      | graph_render_duration   | < 1000ms    |
      | api_response_time       | < 300ms     |
    And metrics should be sent to the observability backend
    And metrics should be queryable in Grafana dashboards

  # ============================================================================
  # STATE MANAGEMENT SCENARIOS (Elmish MVU)
  # ============================================================================

  @state @elmish @mvu
  Scenario: Elmish MVU pattern maintains predictable state
    Given the Elmish app is initialized
    When the following messages are dispatched:
      | message_type       | payload                              |
      | GraphLoaded        | { holons: [...], edges: [...] }      |
      | NodeSelected       | { uuid: "550e...001" }               |
      | DetailPanelOpened  | { uuid: "550e...001" }               |
    Then the model should update in the expected sequence
    And each state transition should be logged
    And the view should re-render only when model changes
    And view rendering should use React-style virtual DOM diffing

  @state @elmish @time-travel
  Scenario: Undo/Redo support for user actions (Time-Travel Debugging)
    Given time-travel debugging is enabled in dev mode
    When I perform 5 graph manipulations:
      | action         |
      | Select node A  |
      | Zoom to 150%   |
      | Pan left       |
      | Select node B  |
      | Open filter    |
    Then I should be able to press Ctrl+Z to undo
    And the state should revert to "Select node B"
    When I press Ctrl+Z again
    Then the state should revert to "Pan left"
    When I press Ctrl+Shift+Z
    Then the state should redo to "Select node B"
