@prajna @l5_bdd @cluster
Feature: Cluster Management
  As an operator of the Prajna C3I cockpit
  I want to view cluster topology, manage nodes, trigger elections, and scale FLAME pools
  So that I can maintain distributed system health and capacity

  # STAMP: SC-CLU-001 to SC-CLU-008, SC-FLAME-001 to SC-FLAME-011, SC-SIL4-011
  # STAMP: SC-DIST-001 to SC-DIST-010, SC-HMI-010
  # AOR: AOR-VER-022, AOR-XHOLON-010
  # Layer: L4 (System), L5 (Cluster)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/prajna/cluster"
    And the cluster LiveView is connected via WebSocket
    And the Erlang cluster has at least 3 nodes connected

  # ----------------------------------------------------------
  # Topology View
  # ----------------------------------------------------------

  @critical @sc_clu_001 @smoke
  Scenario: Cluster topology renders all connected nodes
    When the cluster management page loads
    Then I should see a topology graph with all connected nodes
    And each node should show:
      | Field          |
      | Node name (FQUN)  |
      | Role (seed/worker)|
      | Status (health)   |
      | Uptime            |
      | CPU %             |
      | Memory %          |
    And healthy nodes should be displayed in teal/green
    And degraded nodes should be displayed in amber
    And offline nodes should be displayed in dark gray with an X icon
    And the page should load within 2000ms

  @high @sc_clu_002
  Scenario: Node count summary is accurate
    Given the cluster has 4 nodes: 1 seed and 3 workers
    When I view the cluster summary header
    Then I should see "4 nodes connected"
    And I should see "1 seed, 3 workers"
    And quorum status should show "Quorum: Met (3/4)"

  # ----------------------------------------------------------
  # Node Selection and Detail
  # ----------------------------------------------------------

  @high @sc_clu_003
  Scenario: Select a node to view its details
    Given the cluster topology is visible
    When I click on node "indrajaal@worker-1"
    Then a detail panel should slide in
    And the panel should show:
      | Detail              |
      | Full node name      |
      | Erlang version      |
      | OTP release         |
      | Running processes   |
      | Memory breakdown    |
      | Port count          |
      | ETS table count     |
      | Connected peers     |
    And a "Force Dequeue" button should be visible for the selected node

  @high @sc_clu_004
  Scenario: View FLAME pool workers assigned to a node
    Given node "indrajaal@worker-2" has FLAME pool workers
    When I click on "indrajaal@worker-2" and expand "FLAME Workers"
    Then I should see the list of active FLAME pool processes
    And each worker should show job ID, duration, and status

  # ----------------------------------------------------------
  # Force Election
  # ----------------------------------------------------------

  @critical @sc_clu_005 @sc_safety_001 @election
  Scenario: Force leader election with Guardian approval
    Given the current cluster leader is "indrajaal@seed-1"
    When I click "Force Election"
    Then a confirmation dialog should appear: "Trigger new leader election?"
    And the dialog should show the current leader name
    When I confirm the election request
    Then Guardian approval should be requested
    When Guardian approves
    Then the election should be initiated
    And a "Election in progress" banner should appear
    And a Zenoh event "cluster_election_triggered" should be published
    And within 30 seconds a new leader should be elected
    And the topology graph should update to show the new leader with a crown icon

  @high @sc_clu_006 @election
  Scenario: Election is blocked when quorum is not met
    Given the cluster has lost quorum (only 1 of 3 nodes active)
    When I click "Force Election"
    Then the confirmation dialog should show a quorum warning
    And a message should appear: "Warning: Cluster quorum not met"
    And the "Confirm" button should be disabled until I acknowledge the risk
    When I check the "I understand the risk" checkbox
    Then the "Confirm" button should become active

  # ----------------------------------------------------------
  # FLAME Pool Scaling
  # ----------------------------------------------------------

  @critical @sc_flame_001 @flame
  Scenario: View current FLAME pool capacity
    When I click the "FLAME Pools" tab
    Then I should see the pool summary with:
      | Field             |
      | Pool name         |
      | Min workers       |
      | Max workers       |
      | Active workers    |
      | Queued jobs       |
      | Idle workers      |
    And pools near capacity should show an amber utilization bar
    And pools at maximum should show a red full indicator

  @critical @sc_flame_002 @flame @sc_safety_001
  Scenario: Manually scale up a FLAME pool
    Given the "compute" FLAME pool has 3 active workers and max 10
    When I click "Scale Up" on the "compute" pool
    And I set the target worker count to 6
    And I click "Apply Scale"
    Then Guardian should be requested for approval
    When Guardian approves
    Then FLAME should begin spawning workers up to 6
    And the worker count should update in real time
    And a Zenoh event "flame_pool_scaled" should be published

  @high @sc_flame_003 @flame
  Scenario: Scale down a FLAME pool gracefully
    Given the "compute" FLAME pool has 8 active workers
    When I click "Scale Down" and set target to 4
    And I confirm the scale-down
    Then idle workers should be terminated first
    And busy workers should complete their current job before termination
    And the pool count should decrease to 4 over the next 60 seconds

  # ----------------------------------------------------------
  # Autoscale Toggle
  # ----------------------------------------------------------

  @high @sc_flame_004 @flame @autoscale
  Scenario: Enable autoscale on a FLAME pool
    Given the "background" FLAME pool has autoscale disabled
    When I click the "Autoscale" toggle for the "background" pool
    Then a configuration panel should appear
    And I should be able to set:
      | Parameter            | Default |
      | Scale-up threshold   | 80%     |
      | Scale-down threshold | 30%     |
      | Cooldown period      | 120s    |
      | Max scale step       | 2       |
    When I click "Enable Autoscale"
    Then the autoscale toggle should show "ON" in teal
    And a Zenoh event "flame_autoscale_enabled" should be published

  @high @sc_flame_005 @flame @autoscale
  Scenario: Disable autoscale returns pool to manual mode
    Given the "background" FLAME pool has autoscale enabled
    When I toggle autoscale off
    Then a confirmation dialog should appear: "Disable autoscale?"
    When I confirm
    Then the toggle should show "OFF" in gray
    And the pool should return to its last manually set worker count
    And a Zenoh event "flame_autoscale_disabled" should be published

  # ----------------------------------------------------------
  # Crash Recovery (SC-FLAME-006)
  # ----------------------------------------------------------

  @critical @sc_flame_006 @flame @crash_recovery
  Scenario: FLAME worker crash triggers automatic replacement
    Given the "compute" pool has 5 active workers
    When a FLAME worker crashes unexpectedly
    Then the crash should be detected within 5 seconds
    And the pool should automatically spawn a replacement worker
    And the incident should be logged in the cluster event feed
    And a Zenoh alert "flame_worker_crashed" should be published
    And the replacement worker should reach "ready" state within 30 seconds

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium @sc_clu_007
  Scenario: Node detail panel shows warning when node is isolated
    Given a cluster node has lost contact with all peers for 60 seconds
    When I view that node in the topology
    Then the node card should show "Isolated" with a warning icon
    And the detail panel should show "No peers connected"
    And a suggestion to check network connectivity should be displayed

  @medium @sc_sil4_011
  Scenario: Cluster page warns when quorum drops below minimum
    Given the cluster requires a quorum of 3 nodes
    When a second node goes offline (leaving 2 active)
    Then a "Quorum Warning" banner should appear at the top of the cluster page
    And the banner should say "Quorum at risk: 2/3 nodes active"
    And it should turn red if another node goes offline
