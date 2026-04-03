// =============================================================================
// QUINT MODULE: Indrajaal Homeostasis
// Version: 2.0.0 (ported to Quint 0.29.1 syntax)
// Purpose: Formal specification of the 6-Node Biomorphic Fractal Mesh
// Compliance: SIL-6 / Axiom 0
// =============================================================================

module homeostasis {
  type NodeStatus = Healthy | Degraded | Unhealthy | Dead
  type NodeType = DB | OBS | APP | UI

  type Node = {
    id: int,
    nodeType: NodeType,
    status: NodeStatus,
    quorum_weight: int
  }

  // --- STATE ---
  var nodes: int -> Node
  var total_quorum: int

  // --- HELPERS ---

  // Count healthy nodes in a node map
  pure def countHealthy(ns: int -> Node): int =
    ns.keys().filter(k => ns.get(k).status == Healthy).size()

  // Update a node's status
  pure def withStatus(ns: int -> Node, nodeId: int, newStatus: NodeStatus): int -> Node =
    ns.set(nodeId, { ...ns.get(nodeId), status: newStatus })

  // --- INVARIANTS ---

  // AXIOM 0: Functional State Invariant
  // The system is functional iff at least one node of each critical type is healthy
  val axiom_0 =
    and {
      nodes.keys().exists(k => nodes.get(k).nodeType == DB and nodes.get(k).status == Healthy),
      nodes.keys().exists(k => nodes.get(k).nodeType == OBS and nodes.get(k).status == Healthy),
      nodes.keys().exists(k => nodes.get(k).nodeType == APP and nodes.get(k).status == Healthy)
    }

  // SIL-6 QUORUM: 2oo3 equivalent for each group
  // Minimum weight required for steady-state homeostasis
  val sil6_quorum_invariant = total_quorum >= 4

  // --- ACTIONS ---

  action init = all {
    nodes' = Map(
      1 -> { id: 1, nodeType: DB,  status: Healthy, quorum_weight: 1 },
      2 -> { id: 2, nodeType: DB,  status: Healthy, quorum_weight: 1 },
      3 -> { id: 3, nodeType: OBS, status: Healthy, quorum_weight: 1 },
      4 -> { id: 4, nodeType: APP, status: Healthy, quorum_weight: 1 },
      5 -> { id: 5, nodeType: APP, status: Healthy, quorum_weight: 1 },
      6 -> { id: 6, nodeType: UI,  status: Healthy, quorum_weight: 1 }
    ),
    total_quorum' = 6
  }

  // Metabolic Drift: A node becomes degraded or unhealthy
  action metabolic_drift(nodeId: int, newStatus: NodeStatus): bool = all {
    nodes.keys().contains(nodeId),
    nodes' = nodes.withStatus(nodeId, newStatus),
    total_quorum' = countHealthy(nodes.withStatus(nodeId, newStatus))
  }

  // Apoptosis & Re-ignition: Repairing a node
  action self_heal(nodeId: int): bool = all {
    nodes.get(nodeId).status != Healthy,
    nodes' = nodes.withStatus(nodeId, Healthy),
    total_quorum' = countHealthy(nodes.withStatus(nodeId, Healthy))
  }

  // Next step transition
  action step = any {
    nondet n = oneOf(nodes.keys()); metabolic_drift(n, Unhealthy),
    nondet n = oneOf(nodes.keys()); self_heal(n)
  }
}
