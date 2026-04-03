@smriti @federation @p1
Feature: SMRITI Federation & Replication
  As a Distributed System
  I want to replicate knowledge across nodes
  So that the system is resilient to node failure

  Scenario: Replicating a new Holon
    Given a 3-node SMRITI cluster
    When a new holon is created on Node A
    Then the holon should be queued for replication
    And Node B should receive the new holon
    And Node C should receive the new holon
    And the version vector for the holon should be updated on all nodes

  Scenario: Conflict resolution with concurrent updates
    Given a holon exists on all 3 nodes with version V1
    When Node A updates the holon to V2
    And Node C concurrently updates the holon to V3
    Then the conflict should be detected via version vectors
    And the last-writer-wins strategy should be applied
    And all nodes should converge to the same final state
