@prajna @l5_bdd @mesh_topology
Feature: Mesh Topology Visualization
  As a mesh operator using the Prajna C3I cockpit
  I want to visualize, inspect, and interact with the Zenoh mesh topology
  So that I can understand connectivity, detect partitions, and diagnose network issues

  # STAMP: SC-ZENOH-001, SC-ZENOH-002, SC-DIST-001, SC-HA-003, SC-HMI-010, SC-HMI-011
  # AOR: AOR-CTX-001, AOR-ZENOH-001, AOR-VER-017
  # Layer: L4 (System), L5 (Cluster)

  Background:
    Given I am on the Prajna cockpit
    And the system is in normal operation
    And I navigate to "/cockpit/topology"
    And the mesh topology LiveView is connected via WebSocket
    And Zenoh router is reachable

  # ----------------------------------------------------------
  # Happy Path: Topology Graph Display
  # ----------------------------------------------------------

  @critical @sc_zenoh_001 @smoke
  Scenario: Mesh topology graph renders all nodes and links
    Given the Zenoh mesh has 4 active nodes
    When the topology page loads
    Then I should see 4 node circles on the topology graph
    And each node should be labeled with its FQUN
    And active Zenoh links between nodes should be rendered as edges
    And the page should load within 2000ms

  @critical @sc_zenoh_002
  Scenario: Node health status reflected with chromatic indicators
    Given the Zenoh mesh has nodes with varying health states
    When the topology graph renders
    Then healthy nodes should render with a green fill
    And degraded nodes should render with an amber fill
    And unreachable nodes should render with a red fill
    And each node tooltip should show latency in milliseconds

  @critical @sc_zenoh_001
  Scenario: Topology updates in real-time when a node joins
    Given I am viewing the mesh topology graph
    And there are currently 3 active mesh nodes
    When a new node "indrajaal-ex-app-2" joins the mesh via Zenoh
    Then the new node should appear on the topology graph automatically
    And a new edge should appear connecting the node to the router
    And the node count in the summary should increment to 4
    And the new node should be highlighted with a "New" animation for 3 seconds

  # ----------------------------------------------------------
  # Node Inspection
  # ----------------------------------------------------------

  @high @sc_dist_001
  Scenario: Inspect node details on click
    Given the topology graph has node "indrajaal-ex-app-1"
    When I click on node "indrajaal-ex-app-1"
    Then a node detail panel should appear on the right side
    And I should see the node's FQUN, container name, and IP address
    And I should see active Zenoh subscriptions count
    And I should see current uptime and last heartbeat timestamp
    And I should see inbound and outbound message rates

  @high @sc_dist_001
  Scenario: Inspect link details between two nodes
    Given there is an active Zenoh link between "indrajaal-ex-app-1" and "zenoh-router"
    When I click on the edge between those nodes
    Then a link detail panel should appear
    And I should see the link latency in milliseconds
    And I should see message throughput (msgs/sec) in both directions
    And I should see the Zenoh key expression prefixes active on the link

  # ----------------------------------------------------------
  # Layout and Filtering
  # ----------------------------------------------------------

  @high @sc_hmi_011
  Scenario Outline: Filter topology view by layer
    Given the mesh topology shows nodes from multiple fractal layers
    When I apply the layer filter "<layer>"
    Then only nodes belonging to fractal layer "<layer>" should be visible
    And inter-layer links involving hidden nodes should be dimmed
    And the filter label should show "<layer>" as active

    Examples:
      | layer |
      | L3    |
      | L4    |
      | L5    |

  @medium
  Scenario: Switch between force-directed and hierarchical layout
    Given I am viewing the mesh topology in force-directed layout
    When I click "Hierarchical Layout" in the view controls
    Then the nodes should rearrange into a tree-based hierarchical layout
    And the root node should appear at the top
    And child nodes should be arranged by depth level below their parents

  # ----------------------------------------------------------
  # Partition and Failure Detection
  # ----------------------------------------------------------

  @critical @sc_ha_003
  Scenario: Network partition is detected and highlighted
    Given the mesh currently has full connectivity
    When node "indrajaal-ex-app-2" becomes unreachable
    Then the edge connecting "indrajaal-ex-app-2" should turn red
    And a "Partition Detected" warning banner should appear
    And the partitioned node should pulsate to draw attention
    And a Zenoh event "mesh_partition_detected" should be published

  @critical @sc_ha_003
  Scenario: Quorum loss warning fires below minimum threshold
    Given the mesh requires 3 nodes for quorum
    And currently 3 nodes are connected
    When one node fails and drops connectivity to 2 nodes
    Then a "Quorum Lost" critical banner should appear at the top of the page
    And the banner should display "2 of 3 minimum nodes active"
    And all edges should render in an alert state
    And a Zenoh event "mesh_quorum_lost" should be published

  # ----------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------

  @medium
  Scenario: Single-node topology renders without edges
    Given the Zenoh mesh has only 1 node running
    When the topology page loads
    Then I should see 1 node circle on the graph
    And no edges should be present
    And an informational message should note "Single-node mesh — no redundancy"

  @medium
  Scenario: Topology renders gracefully when Zenoh metrics are unavailable
    Given node "indrajaal-ex-app-1" is reachable but has no latency metrics
    When the topology graph renders
    Then the node should still appear on the graph
    And the latency tooltip should show "Metrics unavailable"
    And no crash or error should occur in the LiveView
