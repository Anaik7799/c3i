Feature: PHICS (Physical Interface Control System) Integration
  As a security system operator
  I need reliable physical device control
  So that I can manage doors, alarms, and access control with <50ms latency

  Background:
    Given the Indrajaal system is running
    And the PHICS controller is started
    And Zenoh telemetry is enabled

  # ============================================================================
  # Device Registration and Discovery (SC-PHICS-007)
  # ============================================================================

  Scenario: Register a new door device
    When I register a door device with ID "door-101"
      | field       | value                    |
      | name        | Main Entrance Door       |
      | type        | door                     |
      | location    | Building A - Floor 1     |
      | ip_address  | 192.168.1.101           |
    Then the device "door-101" should be registered
    And the device status should be "online"
    And a "device.registered" event should be published to Zenoh

  Scenario: List all registered devices
    Given the following devices are registered:
      | id        | name                 | type          | location              |
      | door-101  | Main Entrance Door   | door          | Building A - Floor 1  |
      | door-102  | Back Door            | door          | Building A - Floor 1  |
      | alarm-201 | Zone 1 Alarm         | alarm         | Building A - Zone 1   |
      | reader-301| Main Reader          | access_reader | Building A - Entrance |
    When I request the list of all devices
    Then I should receive 4 devices
    And all devices should have status "online"

  Scenario: Attempt to register duplicate device
    Given a device "door-101" is already registered
    When I attempt to register the same device ID "door-101"
    Then the registration should fail with error "already_registered"

  # ============================================================================
  # Door Control Commands (SC-PHICS-001, SC-CNT-002)
  # ============================================================================

  Scenario: Unlock door with valid credential
    Given a door device "door-101" is registered and online
    When I send unlock command to "door-101" with credential "abc123"
    Then the command should succeed within 50ms
    And the door "door-101" should be unlocked
    And the command should be logged to Immutable Register
    And a "command.success" event should be published

  Scenario: Lock door
    Given a door device "door-101" is registered and unlocked
    When I send lock command to "door-101"
    Then the command should succeed within 50ms
    And the door "door-101" should be locked
    And latency should be tracked in statistics

  Scenario: Command to non-existent device
    When I send unlock command to "door-999" with credential "abc123"
    Then the command should fail with error "device_not_found"

  # ============================================================================
  # Alarm Control (SC-PHICS-004)
  # ============================================================================

  Scenario: Arm alarm system
    Given an alarm device "alarm-201" is registered and online
    When I send arm command to "alarm-201" with mode "away"
    Then the command should succeed within 50ms
    And the alarm "alarm-201" should be armed in "away" mode
    And the command should be logged

  Scenario: Disarm alarm system
    Given an alarm device "alarm-201" is armed in "away" mode
    When I send disarm command to "alarm-201" with code "1234"
    Then the command should succeed within 50ms
    And the alarm "alarm-201" should be disarmed
    And access control should be notified

  # ============================================================================
  # Access Control Integration (SC-PHICS-004)
  # ============================================================================

  Scenario: Grant access at reader
    Given an access reader "reader-301" is registered and online
    When I send grant_access command to "reader-301" for user "user-456"
    Then the command should succeed within 50ms
    And access should be granted to user "user-456"
    And the access grant should be logged to audit trail

  Scenario: Deny access at reader
    Given an access reader "reader-301" is registered and online
    When I send deny_access command to "reader-301" for user "user-789" with reason "invalid_credential"
    Then the command should succeed within 50ms
    And access should be denied to user "user-789"
    And the denial reason should be "invalid_credential"

  # ============================================================================
  # Latency Compliance (SC-CNT-002, SC-PHICS-005, SC-PHICS-006)
  # ============================================================================

  Scenario: Verify latency budget compliance
    Given a door device "door-101" is registered
    When I send 100 consecutive unlock commands to "door-101"
    Then all commands should complete within 50ms
    And average latency should be less than 30ms
    And P99 latency should be less than 45ms
    And there should be zero latency violations

  Scenario: Track latency statistics
    Given multiple devices are registered
    When I send commands to various devices:
      | device_id | command | count |
      | door-101  | unlock  | 50    |
      | door-102  | lock    | 50    |
      | alarm-201 | arm     | 50    |
    Then latency statistics should be available
    And statistics should include:
      | metric          | value      |
      | count           | 150        |
      | avg_ms          | < 30       |
      | p50_ms          | < 25       |
      | p95_ms          | < 40       |
      | p99_ms          | < 45       |
      | violations      | 0          |

  Scenario: Alert on latency violation
    Given a door device "door-101" is registered
    When a command to "door-101" takes 75ms to complete
    Then a "latency.violation" event should be published
    And the event should include latency_ms metadata
    And the violation count should be incremented

  # ============================================================================
  # Device Health Monitoring (SC-PHICS-002, AOR-PHICS-009)
  # ============================================================================

  Scenario: Device health check
    Given the following devices are registered:
      | id        | status  |
      | door-101  | online  |
      | door-102  | offline |
      | alarm-201 | online  |
    When I request a health check
    Then the health report should show:
      | metric          | value |
      | total_devices   | 3     |
      | online          | 2     |
      | offline         | 1     |
      | faulted         | 0     |
      | latency_compliant | true |

  Scenario: Detect offline device
    Given a device "door-101" is online with last_contact 15 seconds ago
    When the health check runs
    Then the device "door-101" should be marked as offline
    And a "device.offline" event should be published

  Scenario: Update device status manually
    Given a device "door-101" is online
    When I update device "door-101" status to "maintenance"
    Then the device status should be "maintenance"
    And a "status.changed" event should be published

  # ============================================================================
  # Guardian Integration (SC-PHICS-003)
  # ============================================================================

  Scenario: Emergency unlock all requires Guardian approval
    Given multiple door devices are registered
    When I send emergency_unlock_all command for facility "building-a"
    Then Guardian approval should be requested
    And the command should wait for approval
    When Guardian approves the command
    Then all doors in "building-a" should be unlocked
    And the emergency action should be logged

  Scenario: Emergency lockdown requires Guardian approval
    Given multiple door devices are registered
    When I send emergency_lockdown command for facility "building-a"
    Then Guardian approval should be requested
    When Guardian denies the command
    Then the command should fail with "guardian_denied" error
    And no doors should be affected

  # ============================================================================
  # Zenoh Telemetry (SC-ZENOH-001, AOR-PHICS-003, AOR-PHICS-010)
  # ============================================================================

  Scenario: Publish command events to Zenoh
    Given Zenoh is connected
    And I am subscribed to "indrajaal/phics/event"
    When I send unlock command to "door-101"
    Then a Zenoh event should be published to "indrajaal/phics/event"
    And the event should contain:
      | field       | value           |
      | event_type  | command.success |
      | device_id   | door-101        |
      | severity    | info            |

  Scenario: Publish health telemetry every 30 seconds
    Given the PHICS controller is running
    When 30 seconds have elapsed
    Then health metrics should be published to "indrajaal/phics/telemetry"
    And the metrics should include device counts and latency stats

  Scenario: Event queue preserves FIFO ordering (SC-PHICS-008)
    Given multiple commands are sent rapidly:
      | order | device_id | command |
      | 1     | door-101  | unlock  |
      | 2     | door-102  | lock    |
      | 3     | alarm-201 | arm     |
    Then events should be published in the same order
    And event timestamps should be monotonically increasing

  # ============================================================================
  # Camera and Sensor Integration
  # ============================================================================

  Scenario: Request camera snapshot
    Given a camera device "camera-401" is registered and online
    When I send snapshot command to "camera-401"
    Then the command should succeed within 50ms
    And the response should include base64 image data
    And the snapshot should be logged

  Scenario: Read sensor value
    Given a sensor device "sensor-501" is registered and online
    When I send read command to "sensor-501"
    Then the command should succeed within 50ms
    And the response should include sensor value
    And the value should be numeric

  # ============================================================================
  # Failover and Redundancy
  # ============================================================================

  Scenario: Command retry on timeout
    Given a door device "door-101" is registered but slow to respond
    When I send unlock command with 100ms timeout
    And the device takes 150ms to respond
    Then the command should timeout
    And a retry should be attempted
    And the retry should succeed within latency budget

  Scenario: Fallback to secondary controller
    Given a primary device controller is unreachable
    And a secondary controller is available
    When I send a command to the device
    Then the command should be routed to secondary controller
    And the command should succeed
    And the failover should be logged

  # ============================================================================
  # Audit Trail and Compliance (SC-PHICS-001)
  # ============================================================================

  Scenario: All commands logged to Immutable Register
    Given the Immutable Register is active
    When I send the following commands:
      | device_id | command | credential |
      | door-101  | unlock  | abc123     |
      | door-102  | lock    | -          |
      | alarm-201 | arm     | -          |
    Then all 3 commands should be logged to Immutable Register
    And each log entry should include:
      | field       |
      | device_id   |
      | command     |
      | timestamp   |
      | latency_ms  |
      | success     |

  Scenario: Query command history from register
    Given 100 commands have been executed
    When I query the Immutable Register for device "door-101"
    Then I should receive all commands for that device
    And the commands should be in chronological order
    And the hash chain should be intact

  # ============================================================================
  # Performance and Load Testing
  # ============================================================================

  Scenario: Handle 1000 concurrent commands
    Given 100 devices are registered
    When I send 1000 concurrent commands across all devices
    Then all commands should complete successfully
    And 99% of commands should complete within 50ms
    And no deadlocks should occur
    And the system should remain responsive

  Scenario: Sustained throughput test
    Given 50 devices are registered
    When I send continuous commands for 60 seconds
    Then the system should maintain >500 commands per second
    And average latency should remain under 30ms
    And memory usage should remain stable

  # ============================================================================
  # Error Handling and Recovery
  # ============================================================================

  Scenario: Graceful handling of device fault
    Given a device "door-101" is online
    When the device reports a hardware fault
    Then the device status should change to "faulted"
    And a "device.faulted" event should be published
    And commands to the device should return "device_faulted" error

  Scenario: Automatic recovery from transient error
    Given a device "door-101" temporarily fails
    When I send a command and it fails
    Then the system should retry the command
    And the retry should succeed
    And only the final successful result should be logged

  # ============================================================================
  # Integration with Other Domains
  # ============================================================================

  Scenario: Access Control domain integration
    Given a user attempts access at "reader-301"
    When Access Control domain authorizes the user
    Then PHICS should unlock the associated door
    And the action should complete within 50ms total
    And both Access Control and PHICS should log the event

  Scenario: Alarm domain integration
    Given an alarm "alarm-201" is triggered
    When Alarm domain requests status
    Then PHICS should provide current alarm state
    And the response should include zone information
    And the latency should be under 10ms

  # ============================================================================
  # Firmware Version Tracking (SC-PHICS-010)
  # ============================================================================

  Scenario: Track device firmware versions
    Given devices with various firmware versions:
      | device_id | firmware |
      | door-101  | v2.1.3   |
      | door-102  | v2.1.3   |
      | alarm-201 | v1.5.0   |
    When I query device firmware versions
    Then I should receive accurate firmware data for all devices
    And I should be able to identify devices with outdated firmware

  Scenario: Alert on outdated firmware
    Given a device "door-101" has firmware "v1.0.0"
    And the minimum required firmware is "v2.0.0"
    When the health check runs
    Then an "outdated_firmware" alert should be generated
    And the device should be flagged for upgrade
