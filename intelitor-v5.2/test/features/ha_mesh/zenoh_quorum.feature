@ha_mesh @sil6 @zenoh @quorum
Feature: Zenoh 2oo3 Quorum Consensus
  As a message bus operator
  I want Zenoh to maintain 2oo3 quorum
  So that messages are reliably delivered

  Background:
    Given 3 Zenoh routers are running (zenoh-1, zenoh-2, zenoh-3)
    And zenoh-proxy is connected to all 3 routers
    And quorum requires 2 of 3 routers healthy

  @P0 @single_failure
  Scenario: Single router failure maintains quorum
    Given zenoh-1 crashes unexpectedly
    When a message is published to "indrajaal/kpi/health"
    Then the message should be delivered to all subscribers
    And zenoh-2 and zenoh-3 should maintain consensus
    And quorum status should show "degraded" but "functional"
    And an alert should be generated

  @P0 @quorum_loss
  Scenario: Two router failures loses quorum
    Given zenoh-1 crashes
    And zenoh-2 crashes
    When a message is published
    Then the message should be queued locally
    And an emergency alert should be generated
    And quorum status should show "lost"
    And the system should enter degraded mode

  @P0 @quorum_recovery
  Scenario: Router recovery restores quorum
    Given zenoh-1 was previously crashed
    And quorum was in degraded state
    When zenoh-1 recovers and passes health check
    Then zenoh-1 should rejoin the mesh
    And queued messages should be delivered
    And quorum status should show "healthy"

  @P1 @message_ordering
  Scenario: Message ordering preserved during failover
    Given messages M1, M2, M3 are in flight
    When zenoh-1 fails during delivery
    Then remaining routers should deliver messages in order
    And no messages should be duplicated
    And no messages should be lost

  @P1 @partition_handling
  Scenario: Network partition between routers
    Given zenoh-1 is partitioned from zenoh-2 and zenoh-3
    When zenoh-2 and zenoh-3 form majority
    Then zenoh-2 and zenoh-3 should continue service
    And zenoh-1 should detect isolation
    And zenoh-1 should not accept writes

  @P2 @router_restart_storm
  Scenario: All routers restart within short window
    Given all 3 routers restart within 10 seconds
    When the restart completes
    Then quorum should be re-established
    And state should be recovered from persistent storage
    And no messages from durable subscriptions should be lost
