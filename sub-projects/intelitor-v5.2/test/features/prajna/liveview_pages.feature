# Feature: Prajna LiveView Pages BDD Tests
# STAMP: SC-COV-004, SC-COV-006, SC-COV-008
# AOR: AOR-COV-005, AOR-COV-006

@prajna @liveview @puppeteer
Feature: Prajna Cockpit LiveView Pages
  As a security operator
  I want to interact with the Prajna C3I cockpit
  So that I can monitor and control the security system effectively

  Background:
    Given I am authenticated as an operator
    And the Phoenix server is running
    And Puppeteer is configured for headless testing

  # ===========================================================================
  # Core Dashboard Tests
  # ===========================================================================

  @dashboard @smoke
  Scenario: Load Prajna main dashboard
    Given I navigate to "/prajna"
    When the page fully loads
    Then I should see the "PRAJNA C3I COCKPIT" header
    And all dashboard widgets should be visible
    And the system health indicator should be present
    And no JavaScript errors should occur

  @dashboard @metrics
  Scenario: Dashboard displays real-time metrics
    Given I am on the Prajna dashboard
    When 5 seconds elapse
    Then the metrics should update via LiveView push
    And the CPU usage chart should have data points
    And the memory usage should be displayed
    And the telemetry should show recent events

  # ===========================================================================
  # Test Evolution Cockpit
  # ===========================================================================

  @test_evolution @level5
  Scenario: Access Test Evolution Cockpit
    Given I navigate to "/cockpit/test-evolution"
    When the page fully loads
    Then I should see the "Test Evolution Cockpit" heading
    And I should see the 5-level test coverage matrix
    And the OODA cycle status should be visible
    And the genome configuration panel should be present

  @test_evolution @fitness
  Scenario: View fitness metrics
    Given I am on the Test Evolution page
    When I look at the fitness cards
    Then I should see the coverage score
    And I should see the pass rate
    And I should see the mutation score
    And I should see the diversity score
    And all scores should be between 0.0 and 1.0

  @test_evolution @generate
  Scenario: Generate tests for a module
    Given I am on the Test Evolution page
    When I enter "lib/indrajaal/accounts/user.ex" in the module path field
    And I click the "Generate TDG Tests" button
    Then a loading indicator should appear
    And after generation completes I should see success message
    And the fitness metrics should update

  @test_evolution @ooda
  Scenario: Monitor OODA cycle
    Given I am on the Test Evolution page
    And the OODA cycle is active
    When 30 seconds elapse
    Then the OODA state should transition through phases
    And the cycle count should increment
    And telemetry should be published

  # ===========================================================================
  # AI Copilot Tests
  # ===========================================================================

  @copilot @ai
  Scenario: Access AI Copilot page
    Given I navigate to "/prajna/copilot"
    When the page fully loads
    Then I should see the "AI Copilot" interface
    And the chat input should be present
    And the context panel should show system state

  @copilot @interaction
  Scenario: Send message to AI Copilot
    Given I am on the AI Copilot page
    When I type "What is the current system health?" in the chat input
    And I press Enter
    Then a thinking indicator should appear
    And after processing I should receive a response
    And the response should mention system health metrics

  @copilot @founder_directive
  Scenario: AI Copilot respects Founder's Directive
    Given I am on the AI Copilot page
    When I ask for a recommendation
    Then the response should align with the Three Supreme Goals
    And the Founder Directive validation should pass
    And the recommendation should be logged

  # ===========================================================================
  # Alarms LiveView Tests
  # ===========================================================================

  @alarms @monitoring
  Scenario: View active alarms
    Given I navigate to "/prajna/alarms"
    When the page fully loads
    Then I should see the alarms table
    And each alarm should show severity indicator
    And filtering controls should be available

  @alarms @acknowledge
  Scenario: Acknowledge an alarm
    Given I am on the Alarms page
    And there is an active alarm
    When I click the acknowledge button for the alarm
    Then a confirmation modal should appear
    And after confirming the alarm status should update to "acknowledged"
    And the action should be logged to audit trail

  @alarms @storm
  Scenario: Detect alarm storm
    Given I am on the Alarms page
    When more than 50 alarms arrive within 60 seconds
    Then the storm detection indicator should activate
    And alarm correlation should group related alarms
    And the storm panel should show affected zones

  # ===========================================================================
  # Access Control Tests
  # ===========================================================================

  @access_control @permissions
  Scenario: View access control policies
    Given I navigate to "/prajna/access-control"
    When the page fully loads
    Then I should see the RBAC policy matrix
    And permission levels should be color-coded
    And audit log should show recent access events

  @access_control @realtime
  Scenario: Real-time permission audit
    Given I am on the Access Control page
    When an access event occurs in the system
    Then the audit log should update via LiveView push
    And the event should show user, resource, and action
    And the result should indicate allowed or denied

  # ===========================================================================
  # Devices Dashboard Tests
  # ===========================================================================

  @devices @health
  Scenario: View device health matrix
    Given I navigate to "/prajna/devices"
    When the page fully loads
    Then I should see the device health matrix
    And online devices should be green
    And offline devices should be red
    And connectivity metrics should be displayed

  @devices @detail
  Scenario: View device details
    Given I am on the Devices page
    When I click on a device card
    Then the device detail modal should open
    And I should see device metadata
    And I should see connectivity history
    And I should see sensor readings if applicable

  # ===========================================================================
  # Video Monitoring Tests
  # ===========================================================================

  @video @streams
  Scenario: View video streams
    Given I navigate to "/prajna/video"
    When the page fully loads
    Then I should see the video grid layout
    And each stream should show camera name
    And stream health indicators should be visible

  @video @detection
  Scenario: View detection events
    Given I am on the Video page
    When a detection event occurs
    Then the event should appear in the detection feed
    And the bounding box should highlight the object
    And confidence score should be displayed

  # ===========================================================================
  # Analytics Dashboard Tests
  # ===========================================================================

  @analytics @reports
  Scenario: View analytics reports
    Given I navigate to "/prajna/analytics"
    When the page fully loads
    Then I should see report generation controls
    And available report templates should be listed
    And date range picker should be functional

  @analytics @trends
  Scenario: View trend analysis
    Given I am on the Analytics page
    When I select a trend report
    Then the trend chart should render
    And data points should be interactive
    And export options should be available

  # ===========================================================================
  # Compliance Dashboard Tests
  # ===========================================================================

  @compliance @audit
  Scenario: View compliance audit trail
    Given I navigate to "/prajna/compliance"
    When the page fully loads
    Then I should see the compliance dashboard
    And audit trail entries should be listed
    And compliance status indicators should be visible

  @compliance @evidence
  Scenario: View evidence collection
    Given I am on the Compliance page
    When I select an evidence category
    Then evidence items should be listed
    And each item should show collection timestamp
    And verification status should be indicated

  # ===========================================================================
  # Guardian Integration Tests
  # ===========================================================================

  @guardian @proposals
  Scenario: View Guardian proposals
    Given I navigate to "/prajna/guardian"
    When the page fully loads
    Then I should see pending proposals list
    And each proposal should show action details
    And approval/veto buttons should be present

  @guardian @veto
  Scenario: Guardian veto flow
    Given I am on the Guardian page
    And there is a pending proposal
    When Guardian vetoes the proposal
    Then the proposal status should update to "vetoed"
    And the veto reason should be displayed
    And the fallback action should be shown

  # ===========================================================================
  # Sentinel Health Tests
  # ===========================================================================

  @sentinel @health
  Scenario: View Sentinel health dashboard
    Given I navigate to "/prajna/sentinel"
    When the page fully loads
    Then I should see the Sentinel health score
    And threat taxonomy should be displayed
    And quarantine status should be visible

  @sentinel @threats
  Scenario: View active threats
    Given I am on the Sentinel page
    When active threats exist
    Then threats should be listed by severity
    And each threat should show RPN score
    And mitigation status should be indicated

  # ===========================================================================
  # Immutable Register Tests
  # ===========================================================================

  @register @chain
  Scenario: View register block chain
    Given I navigate to "/prajna/register"
    When the page fully loads
    Then I should see the block chain visualization
    And each block should show hash and signature
    And chain integrity status should be displayed

  @register @verify
  Scenario: Verify chain integrity
    Given I am on the Register page
    When I click "Verify Chain" button
    Then verification should run
    And all blocks should pass hash verification
    And signature verification should pass
    And the result should be logged

  # ===========================================================================
  # Error Handling Tests
  # ===========================================================================

  @error @recovery
  Scenario: Handle LiveView connection loss
    Given I am on any Prajna page
    When the WebSocket connection is lost
    Then a reconnection banner should appear
    And the page should attempt to reconnect
    And upon reconnection the page should restore state

  @error @validation
  Scenario: Handle form validation errors
    Given I am on a Prajna form page
    When I submit invalid data
    Then validation errors should be displayed inline
    And the form should not submit
    And error messages should be clear and actionable

  # ===========================================================================
  # Screenshot Capture Tests (SC-COV-008)
  # ===========================================================================

  @screenshot @visual
  Scenario: Capture screenshots for visual regression
    Given I navigate to each Prajna page
    Then Puppeteer should capture a screenshot
    And the screenshot should be saved to test/screenshots/
    And the filename should include page name and timestamp

  @screenshot @failure
  Scenario: Capture screenshot on test failure
    Given any Prajna test fails
    Then Puppeteer should capture the current screen
    And the screenshot should be attached to the test report
    And the failure context should be logged
