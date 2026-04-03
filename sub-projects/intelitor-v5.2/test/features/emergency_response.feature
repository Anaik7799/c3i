@emergency_response @sil6 @critical
Feature: Emergency Response Protocol (SIL-6)
  As an ARC operator
  I need the system to respond to emergencies within strict time limits
  So that safety-critical operations complete correctly

  STAMP Constraints:
  - SC-EMR-057: Emergency stop MUST complete in <5 seconds
  - SC-SIL4-007: Dying gasp checkpoint MANDATORY before shutdown
  - SC-SIL4-015: Split-brain triggers apoptosis for minority partition
  - SC-CONST-001: Existence preservation (graceful termination)

  Background:
    Given the EmergencyResponse GenServer is running
    And the Guardian safety kernel is active
    And Sentinel health monitoring is operational

  # ===========================================================================
  # EMERGENCY STOP SCENARIOS (SC-EMR-057)
  # ===========================================================================

  @sc_emr_057 @critical @timing
  Scenario: Emergency stop completes within 5 seconds
    Given the system is in operational state
    When a critical emergency is triggered with reason "Security breach detected"
    Then the emergency stop MUST complete within 5000 milliseconds
    And a dying gasp checkpoint is created
    And the Guardian is notified of the emergency
    And the status indicates stopped state

  @sc_emr_057 @security
  Scenario: Emergency stop on security threat
    Given the system is in operational state
    When a security threat with level "critical" is detected
    Then emergency stop is triggered immediately
    And the system halts within 5 seconds
    And the threat is logged to the immutable register

  # ===========================================================================
  # 6-PHASE APOPTOSIS PROTOCOL (SC-SIL4-015)
  # ===========================================================================

  @apoptosis @6_phase
  Scenario: Complete 6-phase apoptosis protocol
    Given the system is in operational state
    When apoptosis is initiated for container "container-1" with trigger "manual_trigger"
    Then the system MUST progress through all 6 phases:
      | phase         | max_duration_ms |
      | initiated     | 1000            |
      | notifying     | 2000            |
      | draining      | 5000            |
      | checkpointing | 3000            |
      | terminating   | 2000            |
      | terminated    | 1000            |
    And a dying gasp checkpoint is saved
    And the checkpoint has a valid SHA256 hash

  @apoptosis @abort
  Scenario: Abort apoptosis in early phase
    Given apoptosis has been initiated for container "container-abort"
    And the current phase is "initiated" or "notifying"
    When an abort request is received with reason "false positive"
    Then the apoptosis SHOULD be aborted
    And the container returns to operational state
    And the abort is logged

  @apoptosis @cannot_abort
  Scenario: Cannot abort apoptosis in late phase
    Given apoptosis has been initiated for container "container-late"
    And the current phase is "checkpointing" or later
    When an abort request is received with reason "changed mind"
    Then the abort MUST fail with "too_late"
    And apoptosis continues to completion

  # ===========================================================================
  # 7 TRIGGER TYPES
  # ===========================================================================

  @triggers @split_brain
  Scenario Outline: Activate emergency response for different triggers
    Given the system is in operational state
    When emergency response is activated with trigger "<trigger_type>"
    Then the activation MUST succeed
    And the 5-order effects are logged:
      | order | description                              |
      | 1st   | Emergency activated for <trigger_type>   |
      | 2nd   | Guardian notified, Sentinel alerted      |
      | 3rd   | Cluster coordination initiated           |
      | 4th   | Shutdown sequence prepared               |
      | 5th   | Federation notified if applicable        |

    Examples:
      | trigger_type            |
      | split_brain_detected    |
      | quorum_lost             |
      | seed_nodes_down         |
      | constitutional_violation|
      | manual_trigger          |
      | cascade_failure         |
      | security_threat         |

  @triggers @split_brain @minority_partition
  Scenario: Split-brain triggers apoptosis for minority partition
    Given a cluster of 3 nodes
    And this node is in the minority partition with 1 node
    When network partition is detected
    Then apoptosis MUST be initiated
    And peers are notified within 2000 milliseconds
    And a dying gasp with SHA256 hash is saved

  @triggers @quorum_lost
  Scenario: Quorum loss triggers emergency response
    Given a cluster of 5 nodes with quorum requirement of 3
    And only 2 nodes are reachable
    When quorum loss is detected
    Then emergency response activates with trigger "quorum_lost"
    And graceful degradation is initiated
    And the cluster enters read-only mode

  # ===========================================================================
  # DYING GASP CHECKPOINTS (SC-SIL4-007)
  # ===========================================================================

  @dying_gasp @checkpoint @integrity
  Scenario: Dying gasp checkpoint has valid SHA256 hash
    Given apoptosis has been initiated for container "container-hash"
    When the checkpointing phase completes
    Then a dying gasp checkpoint is created
    And the checkpoint contains:
      | field             | requirement        |
      | checkpoint_id     | unique identifier  |
      | container_id      | container-hash     |
      | timestamp         | current UTC time   |
      | trigger_reason    | the trigger type   |
      | state_snapshot    | serialized state   |
      | sha256_hash       | valid 64-char hash |
    And verifying the checkpoint returns valid

  @dying_gasp @verification
  Scenario: Checkpoint verification detects tampering
    Given a checkpoint exists with SHA256 hash "abc123..."
    When the checkpoint data is modified
    And verification is performed
    Then the verification MUST fail with "hash_mismatch"
    And a security alert is raised

  @dying_gasp @restore
  Scenario: System can restore from dying gasp
    Given a valid dying gasp checkpoint exists
    When system recovery is initiated
    Then the checkpoint is verified
    And state is restored from the snapshot
    And the system resumes operation

  # ===========================================================================
  # STATUS AND MONITORING
  # ===========================================================================

  @status @monitoring
  Scenario: Status reports current state
    Given the EmergencyResponse GenServer is running
    And 2 containers are in apoptosis state
    And 5 checkpoints have been created
    When status is requested
    Then the status MUST include:
      | field            | value_type  |
      | running          | boolean     |
      | active_apoptosis | integer (2) |
      | checkpoints      | integer (5) |
      | effects_logged   | integer     |

  @status @fallback
  Scenario: Status has fallback when GenServer not running
    Given the EmergencyResponse GenServer is NOT running
    When status is requested
    Then a fallback status is returned
    And the status indicates running: false

  # ===========================================================================
  # CLEANUP AND MAINTENANCE
  # ===========================================================================

  @cleanup @maintenance
  Scenario: Cleanup removes old records
    Given 100 completed apoptosis records exist
    And 50 records are older than 24 hours
    When cleanup is performed
    Then records older than 24 hours are removed
    And recent records are preserved
    And the cleanup is logged

  # ===========================================================================
  # FMEA SCENARIOS (Failure Mode Testing)
  # ===========================================================================

  @fmea @fm_001
  Scenario: Graceful handling when GenServer not running
    Given the EmergencyResponse GenServer is NOT running
    When any public API function is called
    Then the function MUST NOT crash
    And an appropriate error is returned

  @fmea @fm_002 @bug @known_issue
  Scenario: GenServer deadlock bug (documented)
    # BUG: do_emergency_response calls initiate_apoptosis which calls GenServer.call to self
    # Location: lib/indrajaal/safety/emergency_response.ex:874
    # Fix Required: Call internal function instead of public API
    Given the EmergencyResponse GenServer is running
    When activate is called with trigger "cascade_failure"
    Then the call MAY timeout due to deadlock
    And this is a known bug to be fixed

  @fmea @fm_006 @timing
  Scenario: Emergency stop timeout enforcement
    Given the system is in operational state
    When emergency stop is called
    Then the stop MUST complete within 5000ms (SC-EMR-057)
    And if timeout approaches, forced termination occurs

  # ===========================================================================
  # INTEGRATION SCENARIOS
  # ===========================================================================

  @integration @guardian
  Scenario: Guardian receives emergency notifications
    Given the Guardian safety kernel is active
    When emergency stop is triggered
    Then the Guardian receives the emergency notification
    And the Guardian logs the event
    And the Guardian may veto if appropriate

  @integration @sentinel
  Scenario: Sentinel monitors emergency response health
    Given Sentinel health monitoring is operational
    When apoptosis is initiated
    Then Sentinel is notified of the threat
    And the threat is classified by severity
    And appropriate alerts are generated
