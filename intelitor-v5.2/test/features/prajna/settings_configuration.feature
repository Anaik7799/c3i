@prajna @l5_bdd @settings
Feature: Settings and Configuration
  As an operator of the Prajna C3I cockpit
  I want to configure display settings, thresholds, AI models, and system envelopes
  So that I can tune the cockpit to my operational requirements

  # STAMP: SC-THEME-001 to SC-THEME-006, SC-HMI-010, SC-HMI-011
  # STAMP: SC-CONFIG-001 to SC-CONFIG-006, SC-MODEL-001 to SC-MODEL-020
  # STAMP: SC-GUARD-001
  # AOR: AOR-CONFIG-001, AOR-MATH-018
  # Layer: L2 (Module), L3 (Domain)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/settings"
    And the settings LiveView is connected via WebSocket

  # ----------------------------------------------------------
  # Display Settings
  # ----------------------------------------------------------

  @high @sc_theme_001 @smoke
  Scenario: Settings page loads with current configuration
    When the settings page loads
    Then I should see settings panels for:
      | Panel Name          |
      | Display & Theme     |
      | Alert Thresholds    |
      | AI Model Config     |
      | Envelopes           |
      | Notifications       |
    And all current values should be pre-populated from the active configuration
    And the page should load within 2000ms

  @high @sc_theme_002 @display
  Scenario: Toggle between dark and light cockpit themes
    Given the settings page is open
    When I click the "Dark Mode" toggle
    Then the cockpit should switch to light theme
    And all UI elements should re-render with light palette
    When I click the toggle again
    Then the cockpit should return to dark mode
    And the preference should be persisted to the holon SQLite store

  @high @sc_theme_003 @sc_hmi_010 @display
  Scenario Outline: Change dashboard refresh interval
    Given I am on the Display settings panel
    When I set the refresh interval to "<interval>"
    And I click "Apply"
    Then the dashboard should begin refreshing every "<seconds>" seconds
    And a confirmation toast should appear: "Refresh interval set to <interval>"

    Examples:
      | interval  | seconds |
      | 5 seconds | 5       |
      | 10 seconds| 10      |
      | 30 seconds| 30      |
      | 60 seconds| 60      |

  @medium @sc_hmi_010 @display
  Scenario: Toggle color-rich chromatic feedback mode
    Given I am on the Display settings panel
    When I enable the "Color Rich Mode" toggle (SC-HMI-010)
    Then the cockpit should activate high-saturation chromatic feedback
    And metric cards should use vibrant gradient palettes
    And the setting should be saved to configuration

  # ----------------------------------------------------------
  # Alert Thresholds
  # ----------------------------------------------------------

  @critical @sc_alarm_020 @thresholds
  Scenario: View and edit CPU threshold
    Given I am on the "Alert Thresholds" panel
    Then I should see the current CPU threshold values:
      | Level   | Default |
      | Warning | 80%     |
      | Critical| 95%     |
    When I change the Warning threshold to 75%
    And I click "Save Thresholds"
    Then the threshold should be updated
    And a toast should confirm "CPU warning threshold set to 75%"
    And the change should be logged to the Immutable Register

  @critical @sc_alarm_021 @thresholds
  Scenario Outline: Edit multiple system thresholds
    Given I am on the "Alert Thresholds" panel
    When I set the "<metric>" warning threshold to "<warning_value>"
    And I set the "<metric>" critical threshold to "<critical_value>"
    And I click "Save Thresholds"
    Then the thresholds should be persisted
    And alarms should use the new thresholds from the next evaluation cycle

    Examples:
      | metric       | warning_value | critical_value |
      | CPU          | 75%           | 90%            |
      | Memory       | 70%           | 90%            |
      | OODA latency | 80ms          | 150ms          |
      | Error rate   | 1%            | 5%             |

  @high @sc_alarm_022 @thresholds
  Scenario: Threshold validation prevents invalid configuration
    Given I am on the "Alert Thresholds" panel
    When I set the Warning CPU threshold to 95% and Critical to 80%
    Then a validation error should appear: "Warning must be less than Critical"
    And the "Save Thresholds" button should remain disabled
    And the invalid fields should be highlighted in red

  # ----------------------------------------------------------
  # AI Model Configuration
  # ----------------------------------------------------------

  @high @sc_model_001 @ai_config
  Scenario: View current AI model assignments
    Given I am on the "AI Model Config" panel
    Then I should see current model assignments for:
      | Agent Role      | Current Model           |
      | Executive       | claude-opus-4           |
      | Domain Supervisor| claude-sonnet-4-6      |
      | Worker          | claude-haiku-3-5        |
      | Cortex Inference| openrouter/default      |
    And each assignment should show model name, provider, and cost tier

  @high @sc_model_002 @ai_config
  Scenario: Change model assignment for a worker agent role
    Given I am on the "AI Model Config" panel
    When I click "Edit" on the "Worker" row
    And I select "claude-haiku-3-5" from the model dropdown
    And I click "Save"
    Then the worker model should update to "claude-haiku-3-5"
    And a confirmation toast should appear
    And the change should take effect for newly spawned worker agents

  @medium @sc_model_003 @ai_config
  Scenario: AI config shows estimated cost per 1000 calls
    Given I am on the "AI Model Config" panel
    Then each model row should show an estimated cost per 1000 API calls
    And the total estimated hourly cost should be shown in the panel footer
    And a cost comparison chart should be available when clicking "Cost Analysis"

  # ----------------------------------------------------------
  # Envelope Editing (SC-GUARD-001)
  # ----------------------------------------------------------

  @critical @sc_guard_001 @envelopes
  Scenario: View Guardian envelope values
    Given I am on the "Envelopes" panel
    Then I should see all current Guardian envelope parameters
    And each envelope should show:
      | Field           |
      | Envelope name   |
      | Current value   |
      | Min bound       |
      | Max bound       |
      | Last modified   |
    And envelopes at boundary limits should show a warning indicator

  @critical @sc_guard_001 @sc_safety_001 @envelopes @arm_and_fire
  Scenario: Edit a Guardian envelope requires Arm & Fire approval
    Given I am on the "Envelopes" panel
    When I click "Edit" on the "max_cpu_threshold" envelope
    And I change the value from 95 to 98
    And I click "Propose Change"
    Then a Guardian approval request should be raised
    And a "Pending Guardian Approval" status should show on the envelope row
    When Guardian approves the change
    Then the envelope value should update to 98
    And the change should be logged to the Immutable Register
    And a Zenoh event "envelope_updated" should be published

  @high @sc_guard_001 @envelopes
  Scenario: Envelope value outside bounds is rejected immediately
    Given I am on the "Envelopes" panel
    When I edit "max_cpu_threshold" and enter a value of 105 (above max bound 100)
    Then a validation error should appear immediately: "Value exceeds maximum bound: 100"
    And the "Propose Change" button should be disabled

  # ----------------------------------------------------------
  # Save and Reset
  # ----------------------------------------------------------

  @high @sc_config_001 @save_reset
  Scenario: Save all settings persists to SQLite
    Given I have modified display, threshold, and notification settings
    When I click "Save All Settings"
    Then a confirmation dialog should appear listing all changes
    When I confirm
    Then all changes should be persisted to the holon SQLite store (Ω₇)
    And a success toast should appear: "Settings saved successfully"
    And the settings should survive a page refresh

  @high @sc_config_002 @save_reset
  Scenario: Reset to defaults restores original configuration
    Given I have modified several settings
    When I click "Reset to Defaults"
    Then a warning dialog should appear: "This will revert all settings to system defaults"
    When I confirm the reset
    Then all settings fields should repopulate with default values
    And the previous custom values should be discarded
    And a toast should confirm "Settings reset to defaults"

  @medium @sc_config_003 @save_reset
  Scenario: Unsaved changes prompt before navigation
    Given I have modified a threshold setting without saving
    When I attempt to navigate to a different cockpit page
    Then a "Unsaved Changes" dialog should appear
    And it should offer "Save and Leave", "Discard and Leave", and "Cancel"
    When I choose "Discard and Leave"
    Then the navigation should proceed without saving the change

  # ----------------------------------------------------------
  # Notifications
  # ----------------------------------------------------------

  @medium @sc_config_004 @notifications
  Scenario: Configure alarm notification channels
    Given I am on the "Notifications" panel
    Then I should see toggles for:
      | Channel           |
      | In-app banner     |
      | Zenoh event       |
      | Email (if configured) |
    When I enable the "Email" notification channel for "critical" alarms
    Then the email channel toggle should show "ON"
    And test notification should be sendable from the same panel

  @medium @sc_config_005 @notifications
  Scenario: Test notification sends a sample alert
    Given the "In-app banner" notification channel is enabled
    When I click "Send Test Notification"
    Then a sample alarm banner should appear in the cockpit for 5 seconds
    And a toast should confirm "Test notification sent"
