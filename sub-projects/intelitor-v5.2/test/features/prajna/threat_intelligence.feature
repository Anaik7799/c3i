@prajna @l5_bdd @threat_intelligence
Feature: Threat Intelligence
  As a security operator using the Prajna C3I cockpit
  I want to monitor threat indicators, review Sentinel detections, and respond to active threats
  So that I can maintain security posture and protect the biomorphic mesh

  # STAMP: SC-MCP-001, SC-KMS-001, SC-SAFETY-001, SC-HMI-010, SC-HMI-011
  # AOR: AOR-CTX-001, AOR-VER-001, AOR-VER-034
  # Layer: L3 (Domain), L4 (System), L5 (Cluster)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/cockpit/threat"
    And the threat LiveView is connected via WebSocket
    And Guardian service is active
    And Sentinel monitoring is active

  # ----------------------------------------------------------
  # Happy Path: Threat Dashboard Display
  # ----------------------------------------------------------

  @critical @sc_mcp_001 @smoke
  Scenario: Threat dashboard renders with active threat indicators
    Given there are active threats in the system
    When the threat intelligence page loads
    Then I should see the threat summary panel
    And the threat severity distribution chart should be visible
    And each threat row should display a severity badge with color:
      | Severity | Color            |
      | critical | Red (#FF0000)    |
      | high     | Orange (#FF6B00) |
      | medium   | Amber (#FFC107)  |
      | low      | Teal (#00BCD4)   |
    And the total threat count should be visible in the header
    And the page should load within 2000ms

  @critical @sc_kms_001
  Scenario: Sentinel threat feed auto-refreshes with Zenoh telemetry
    Given I am viewing the threat intelligence page
    And Sentinel has detected 3 active threats
    When a new threat event arrives via Zenoh topic "indrajaal/sentinel/threats"
    Then the threat list should update automatically without page reload
    And the new threat should appear at the top of the list
    And the threat count in the header should increment by one
    And the "Last updated" timestamp should advance

  # ----------------------------------------------------------
  # Threat Classification
  # ----------------------------------------------------------

  @high @sc_safety_001
  Scenario Outline: Filter threats by attack vector
    Given there are threats of multiple attack vectors
    When I select attack vector filter "<vector>"
    Then only threats classified as "<vector>" should be displayed
    And the active filter badge should show "<vector>"
    And the threat count should update accordingly

    Examples:
      | vector            |
      | network_intrusion |
      | credential_abuse  |
      | malware           |
      | dos_attack        |

  @high @sc_hmi_010
  Scenario: Threat heatmap displays geographic attack origins
    Given there are threats with source IP metadata
    When I view the threat origin heatmap
    Then each threat origin should be plotted on the heatmap
    And high-density attack regions should render in deep red
    And medium-density regions should render in amber
    And low-density regions should render in teal
    And hovering a region should show attack count and top vectors

  # ----------------------------------------------------------
  # Threat Investigation
  # ----------------------------------------------------------

  @critical @sc_safety_001
  Scenario: Drill into threat details for full forensic context
    Given there is a critical threat with id "THR-001"
    When I click "Investigate" on threat "THR-001"
    Then the threat detail panel should expand
    And I should see the source IP, destination, and timestamp
    And I should see the associated MITRE ATT&CK technique
    And the affected mesh nodes should be highlighted
    And a Zenoh correlation trace link should be available

  @high
  Scenario: Correlate threat with recent alarm events
    Given threat "THR-002" is linked to alarm "ALM-005"
    When I open the threat correlation view for "THR-002"
    Then the correlated alarm "ALM-005" should be visible
    And the timeline showing threat-to-alarm causality should render
    And the correlation confidence score should be displayed as a percentage

  # ----------------------------------------------------------
  # Threat Response Actions
  # ----------------------------------------------------------

  @critical @sc_safety_001 @arm_and_fire
  Scenario: Block a threat source IP via Guardian-gated action
    Given there is an active network intrusion threat from "192.168.99.1"
    When I click "Block Source" on the threat entry
    Then a Guardian approval dialog should appear
    And the dialog should show the IP address and consequence of blocking
    When I confirm the blocking action in the Guardian dialog
    Then the IP "192.168.99.1" should be added to the block list
    And the threat status should change to "mitigated"
    And a Zenoh event "threat_source_blocked" should be published
    And the action should be logged to the Immutable Register

  @critical @sc_safety_001
  Scenario: Escalate a critical threat to incident response
    Given there is a critical threat "THR-CRIT-001" requiring escalation
    When I click "Escalate to IR" on threat "THR-CRIT-001"
    Then an incident response form should appear with threat context pre-filled
    And I can add a priority level and responder note
    When I submit the escalation
    Then Guardian should receive the incident escalation
    And threat "THR-CRIT-001" status should change to "escalated"
    And a Zenoh event "threat_escalated" should be published to "indrajaal/sentinel/threats"

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium
  Scenario: No active threats shows secure system state
    Given there are no active threats in the system
    When I view the threat intelligence page
    Then I should see a "System Secure" indicator with a green badge
    And the threat count should show "0 active threats"
    And the heatmap should show no high-density regions

  @medium
  Scenario: Threat with incomplete metadata renders gracefully
    Given there is a threat with no source_ip field
    When the threat list renders
    Then the threat should appear with "Unknown origin" in the source column
    And no error or crash should occur in the LiveView
    And all other fields should display normally

  @high @sc_hmi_011
  Scenario: Threat MITRE ATT&CK matrix overlay displays technique coverage
    Given there are threats mapped to MITRE ATT&CK techniques
    When I click "MITRE ATT&CK View" in the threat toolbar
    Then the ATT&CK matrix overlay should render
    And techniques with active threats should be highlighted in red
    And techniques with historical detections should be highlighted in amber
    And techniques with no detections should render in the default neutral color
