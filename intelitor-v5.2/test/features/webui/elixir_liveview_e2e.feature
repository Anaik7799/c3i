@webui @liveview @elixir @P0
Feature: Elixir LiveView WebUI End-to-End Workflows
  As a system user
  I need comprehensive LiveView functionality
  So that I can interact with the system through a responsive web interface

  Background:
    Given Phoenix is running on port 4000
    And LiveView is enabled
    And I am authenticated
    And JavaScript is enabled in the browser

  # =============================================================================
  # LIVEVIEW CORE FUNCTIONALITY
  # =============================================================================

  @liveview @connection @P0
  Scenario: LV-CORE-001 - LiveView WebSocket connection
    When I navigate to any LiveView page
    Then a WebSocket connection should be established
    And the "phx-connected" class should be present
    And server pushes should be received in real-time
    And form submissions should not cause page reload

  @liveview @recovery @P0
  Scenario: LV-CORE-002 - LiveView connection recovery
    Given I am on a LiveView page
    When the WebSocket connection is interrupted
    Then the "phx-disconnected" class should appear
    And the page should show a reconnecting indicator
    When the connection is restored
    Then the state should be synchronized
    And no data should be lost

  @liveview @hooks @P1
  Scenario: LV-CORE-003 - LiveView JavaScript hooks
    Given I am on a page with JavaScript hooks
    Then the following hooks should be active:
      | Hook           | Purpose                     |
      | InfiniteScroll | Lazy loading on scroll      |
      | ChartUpdater   | Real-time chart updates     |
      | FormValidator  | Client-side validation      |
      | Notifications  | Toast notification display  |
      | Clipboard      | Copy-to-clipboard function  |

  # =============================================================================
  # FORM HANDLING E2E
  # =============================================================================

  @forms @validation @P0
  Scenario: LV-FORM-001 - Real-time form validation
    Given I am on a form page
    When I type in an email field
    Then validation should happen on each keystroke
    And invalid input should show inline errors
    And the submit button should be disabled when invalid
    And valid input should show success indicators

  @forms @submission @P0
  Scenario: LV-FORM-002 - Form submission workflow
    Given I am on a form page
    When I fill in all required fields
    And I click submit
    Then the form should show loading state
    And the server should process the submission
    And on success, a confirmation message should appear
    And the form should either reset or redirect

  @forms @uploads @P1
  Scenario: LV-FORM-003 - File upload handling
    Given I am on a form with file upload
    When I select a file to upload
    Then the file should be validated (size, type)
    And upload progress should be displayed
    And I should be able to cancel the upload
    When the upload completes
    Then a preview should be shown
    And the file should be associated with the record

  @forms @autosave @P1
  Scenario: LV-FORM-004 - Form autosave
    Given I am on a long form with autosave enabled
    When I fill in fields
    Then changes should be saved periodically
    And a "Saved" indicator should appear
    If I leave and return
    Then my progress should be restored

  # =============================================================================
  # TABLE/LIST COMPONENTS E2E
  # =============================================================================

  @tables @sorting @P0
  Scenario: LV-TABLE-001 - Table sorting
    Given I am viewing a data table
    When I click on a column header
    Then the table should sort by that column (ascending)
    When I click the same header again
    Then the sort should reverse (descending)
    And the sort indicator should update accordingly

  @tables @filtering @P0
  Scenario: LV-TABLE-002 - Table filtering
    Given I am viewing a data table
    When I enter text in the filter input
    Then results should filter in real-time
    And matching text should be highlighted
    And the result count should update
    When I clear the filter
    Then all rows should be displayed again

  @tables @pagination @P0
  Scenario: LV-TABLE-003 - Table pagination
    Given I am viewing a data table with 1000+ rows
    Then the table should show 25 rows per page (default)
    And pagination controls should be visible
    When I click "Next"
    Then the next page should load
    And the URL should update with page parameter
    When I change page size to 100
    Then the table should show 100 rows per page

  @tables @selection @P1
  Scenario: LV-TABLE-004 - Row selection
    Given I am viewing a data table
    When I click on a row
    Then the row should be selected (highlighted)
    When I Ctrl+click another row
    Then both rows should be selected
    When I click "Select All"
    Then all visible rows should be selected
    And bulk action buttons should appear

  @tables @infinite-scroll @P1
  Scenario: LV-TABLE-005 - Infinite scroll loading
    Given I am viewing a list with infinite scroll
    When I scroll to the bottom
    Then more items should load automatically
    And a loading indicator should appear during load
    And scroll position should be maintained
    And previously loaded items should remain

  # =============================================================================
  # MODAL/DIALOG E2E
  # =============================================================================

  @modals @basic @P0
  Scenario: LV-MODAL-001 - Modal open/close
    Given I am on a page with modal triggers
    When I click a button that opens a modal
    Then the modal should appear with animation
    And the background should be dimmed
    And focus should move to the modal
    When I click the close button
    Then the modal should close with animation
    And focus should return to the trigger

  @modals @forms @P0
  Scenario: LV-MODAL-002 - Form in modal
    Given I am on a page with a form modal
    When I click "Add New"
    Then a modal with a form should appear
    When I fill the form and submit
    Then the modal should close
    And the new item should appear in the list
    And a success toast should show

  @modals @confirmation @P0
  Scenario: LV-MODAL-003 - Confirmation dialog
    Given I am on a page with a delete action
    When I click "Delete"
    Then a confirmation modal should appear
    And it should ask "Are you sure?"
    When I click "Cancel"
    Then nothing should be deleted
    When I click "Delete" and then "Confirm"
    Then the item should be deleted

  # =============================================================================
  # NAVIGATION E2E
  # =============================================================================

  @navigation @router @P0
  Scenario: LV-NAV-001 - LiveView navigation
    Given I am on the home page
    When I click a navigation link
    Then the page should change without full reload
    And the URL should update
    And the browser history should be updated
    When I click the browser back button
    Then the previous page should load

  @navigation @params @P0
  Scenario: LV-NAV-002 - URL parameters
    Given I am on a filtered list
    When I apply filters
    Then the URL should include filter parameters
    When I copy and share the URL
    And another user opens it
    Then they should see the same filtered view

  @navigation @breadcrumbs @P1
  Scenario: LV-NAV-003 - Breadcrumb navigation
    Given I am on a nested page (e.g., /sites/1/zones/2)
    Then breadcrumbs should show the full path
    When I click on a breadcrumb
    Then I should navigate to that level
    And child items should be preserved in history

  # =============================================================================
  # NOTIFICATIONS & TOASTS E2E
  # =============================================================================

  @notifications @toast @P0
  Scenario: LV-NOTIF-001 - Toast notifications
    Given I am on any page
    When an action completes successfully
    Then a success toast should appear
    And it should auto-dismiss after 5 seconds
    When an error occurs
    Then an error toast should appear
    And it should require manual dismissal

  @notifications @push @P0 @SC-BRIDGE-005
  Scenario: LV-NOTIF-002 - Server push notifications
    Given I am subscribed to alarm notifications
    When a new alarm arrives via Zenoh
    Then a notification should appear immediately
    And the notification should include:
      | Field      | Content           |
      | Title      | Alarm type        |
      | Body       | Brief description |
      | Action     | "View" button     |
    When I click "View"
    Then I should navigate to the alarm details

  @notifications @badges @P1
  Scenario: LV-NOTIF-003 - Badge counters
    Given I am on the dashboard
    Then I should see badge counters for:
      | Badge          | Updates When              |
      | Unread Alarms  | New alarm arrives         |
      | Pending Tasks  | Task status changes       |
      | Messages       | New message received      |
    When I view the corresponding section
    Then the badge should clear or update

  # =============================================================================
  # SEARCH E2E
  # =============================================================================

  @search @global @P0
  Scenario: LV-SEARCH-001 - Global search
    Given I am on any page
    When I press Cmd/Ctrl+K
    Then the global search modal should open
    When I type a search query
    Then results should appear in real-time
    And results should be grouped by category
    When I select a result
    Then I should navigate to that item

  @search @autocomplete @P1
  Scenario: LV-SEARCH-002 - Search autocomplete
    Given I am typing in a search field
    When I have typed 2+ characters
    Then autocomplete suggestions should appear
    And I can navigate with arrow keys
    When I press Enter
    Then the selected suggestion should be applied

  # =============================================================================
  # DATA VISUALIZATION E2E
  # =============================================================================

  @charts @rendering @P0
  Scenario: LV-CHART-001 - Chart rendering
    Given I am on a page with charts
    Then charts should render correctly
    And legends should be interactive
    When I hover over a data point
    Then a tooltip should show details
    When I click a legend item
    Then that series should toggle visibility

  @charts @realtime @P0
  Scenario: LV-CHART-002 - Real-time chart updates
    Given I am viewing a real-time chart
    When new data arrives via WebSocket
    Then the chart should update smoothly
    And animation should be visible
    And old data should scroll off
    And performance should remain smooth

  @charts @export @P1
  Scenario: LV-CHART-003 - Chart export
    Given I am viewing a chart
    When I click "Export"
    Then export options should appear:
      | Format | Description       |
      | PNG    | Image format      |
      | SVG    | Vector format     |
      | CSV    | Data only         |
    When I select a format
    Then the download should start

  # =============================================================================
  # THEMING E2E
  # =============================================================================

  @theme @dark-mode @P1
  Scenario: LV-THEME-001 - Dark mode toggle
    Given I am on any page
    When I toggle dark mode
    Then the color scheme should change
    And the preference should be saved
    When I reload the page
    Then dark mode should persist

  @theme @aerospace @P1 @SC-HMI-004
  Scenario: LV-THEME-002 - Aerospace theme compliance
    Given aerospace theme is active
    Then the following should apply:
      | Element        | Requirement           |
      | Background     | Dark (#1a1a2e)        |
      | Text Contrast  | 4.5:1 minimum         |
      | Critical Alerts| Red (#ff4444)         |
      | Warnings       | Amber (#ffaa00)       |
      | Normal Status  | Green (#44ff44)       |

  # =============================================================================
  # STATE MANAGEMENT E2E
  # =============================================================================

  @state @persistence @P0
  Scenario: LV-STATE-001 - State persistence across navigation
    Given I have made selections on a page
    When I navigate away and back
    Then my selections should be preserved
    And filters should remain applied
    And scroll position should be restored

  @state @sync @P0
  Scenario: LV-STATE-002 - Multi-tab state sync
    Given I have the app open in two tabs
    When I make a change in tab 1
    Then tab 2 should reflect the change
    And both tabs should show consistent data

  # =============================================================================
  # AUTHENTICATION FLOWS E2E
  # =============================================================================

  @auth @login @P0
  Scenario: LV-AUTH-001 - Login workflow
    Given I am not authenticated
    When I navigate to a protected page
    Then I should be redirected to login
    When I enter valid credentials
    And I click "Login"
    Then I should be authenticated
    And I should be redirected to my original destination

  @auth @session @P0
  Scenario: LV-AUTH-002 - Session management
    Given I am authenticated
    When my session is about to expire (5 min)
    Then a warning should appear
    And I should have option to extend
    When my session expires
    Then I should be logged out gracefully
    And I should see a session expired message

  @auth @logout @P0
  Scenario: LV-AUTH-003 - Logout workflow
    Given I am authenticated
    When I click "Logout"
    Then my session should be terminated
    And I should be redirected to login
    And protected pages should no longer be accessible

  # =============================================================================
  # PRESENCE/COLLABORATION E2E
  # =============================================================================

  @presence @online @P1
  Scenario: LV-PRES-001 - User presence tracking
    Given multiple users are online
    When I view the presence indicator
    Then I should see who is online
    And I should see what they're viewing
    When a user goes offline
    Then they should disappear from the list

  @presence @cursors @P2
  Scenario: LV-PRES-002 - Collaborative cursors
    Given multiple users are editing the same form
    Then I should see other users' cursors
    And each cursor should be labeled with username
    And cursor positions should update in real-time

  # =============================================================================
  # PERFORMANCE E2E
  # =============================================================================

  @performance @lcp @P0
  Scenario: LV-PERF-001 - Core Web Vitals
    Given I measure performance metrics
    Then the following should be met:
      | Metric | Target        |
      | LCP    | < 2.5 seconds |
      | FID    | < 100ms       |
      | CLS    | < 0.1         |

  @performance @memory @P1
  Scenario: LV-PERF-002 - Memory management
    Given I navigate through many pages
    Then memory usage should remain stable
    And there should be no memory leaks
    And garbage collection should run smoothly

  # =============================================================================
  # ERROR BOUNDARIES E2E
  # =============================================================================

  @errors @boundary @P0
  Scenario: LV-ERR-001 - Component error isolation
    Given I am on a page with multiple components
    When one component encounters an error
    Then only that component should show error state
    And other components should continue working
    And the error should be logged

  @errors @reload @P0
  Scenario: LV-ERR-002 - Error recovery
    Given a component is in error state
    When I click "Retry"
    Then the component should attempt to reload
    And on success, it should return to normal state

  # =============================================================================
  # INTERNATIONALIZATION E2E
  # =============================================================================

  @i18n @language @P2
  Scenario: LV-I18N-001 - Language switching
    Given I am viewing the app in English
    When I switch language to Spanish
    Then all UI text should change to Spanish
    And dates/numbers should format according to locale
    And my preference should be saved

  @i18n @rtl @P2
  Scenario: LV-I18N-002 - RTL language support
    Given I switch to an RTL language (Arabic)
    Then the layout should flip to RTL
    And text should align right
    And navigation should adapt accordingly

  # =============================================================================
  # PRINT E2E
  # =============================================================================

  @print @report @P1
  Scenario: LV-PRINT-001 - Print-friendly views
    Given I am viewing a report page
    When I click "Print" or press Ctrl+P
    Then a print-friendly version should be shown
    And navigation should be hidden
    And charts should be print-optimized
    And page breaks should be logical

  # =============================================================================
  # KEYBOARD SHORTCUTS E2E
  # =============================================================================

  @keyboard @shortcuts @P1
  Scenario: LV-KEY-001 - Keyboard shortcuts
    Given I am on any page
    Then the following shortcuts should work:
      | Shortcut  | Action                 |
      | Cmd/Ctrl+K| Open global search     |
      | Escape    | Close modal/dropdown   |
      | ?         | Show keyboard help     |
      | g then h  | Go to home             |
      | g then a  | Go to alarms           |
      | j         | Next item in list      |
      | k         | Previous item in list  |
