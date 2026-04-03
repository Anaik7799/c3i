// =============================================================================
// QUINT MODULE: Cluster Quorum and Sentinel Verification
// Purpose: Model check cluster consensus and split-brain prevention
// Context: Stream Beta (Task 30.1.3)
// =============================================================================

module ClusterQuorum {

  // ---------------------------------------------------------------------------
  // Types
  // ---------------------------------------------------------------------------

  type ClusterState = Healthy | Degraded | Partitioned | QuorumLost |
                      Recovering | Failed

  // ---------------------------------------------------------------------------
  // State Variables
  // ---------------------------------------------------------------------------

  var clusterState: ClusterState
  var totalNodes: int
  var activeNodes: int
  var partitionedNodes: Set[int]
  var sentinelActive: bool
  var writesEnabled: bool
  var globalClock: int

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  pure val MIN_CLUSTER_SIZE = 3
  pure val HEALTH_CHECK_INTERVAL = 5000
  pure val PARTITION_TIMEOUT = 10000

  // ---------------------------------------------------------------------------
  // Quorum Calculation
  // ---------------------------------------------------------------------------

  def quorumSize(n: int): int = (n / 2) + 1

  def hasQuorum: bool = activeNodes >= quorumSize(totalNodes)

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  action init = all {
    clusterState' = Healthy,
    totalNodes' = 5,
    activeNodes' = 5,
    partitionedNodes' = Set(),
    sentinelActive' = true,
    writesEnabled' = true,
    globalClock' = 0
  }

  // ---------------------------------------------------------------------------
  // Cluster Events
  // ---------------------------------------------------------------------------

  action nodeJoin = all {
    totalNodes' = totalNodes + 1,
    activeNodes' = activeNodes + 1,
    clusterState' = if (clusterState == Degraded and hasQuorum) Healthy else clusterState,
    partitionedNodes' = partitionedNodes,
    sentinelActive' = sentinelActive,
    writesEnabled' = writesEnabled,
    globalClock' = globalClock + 100
  }

  action nodeFail(nodeId: int): bool = all {
    activeNodes > 0,
    activeNodes' = activeNodes - 1,
    clusterState' = if (activeNodes - 1 < quorumSize(totalNodes)) QuorumLost
                    else if (activeNodes - 1 < totalNodes) Degraded
                    else Healthy,
    writesEnabled' = activeNodes - 1 >= quorumSize(totalNodes),
    partitionedNodes' = partitionedNodes,
    sentinelActive' = sentinelActive,
    totalNodes' = totalNodes,
    globalClock' = globalClock + 10
  }

  action partitionDetected(nodes: Set[int]): bool = all {
    clusterState == Healthy or clusterState == Degraded,
    partitionedNodes' = nodes,
    clusterState' = Partitioned,
    writesEnabled' = activeNodes - size(nodes) >= quorumSize(totalNodes),
    activeNodes' = activeNodes,
    sentinelActive' = sentinelActive,
    totalNodes' = totalNodes,
    globalClock' = globalClock + 50
  }

  action partitionHealed = all {
    clusterState == Partitioned,
    activeNodes' = activeNodes + size(partitionedNodes),
    partitionedNodes' = Set(),
    clusterState' = Recovering,
    sentinelActive' = sentinelActive,
    writesEnabled' = writesEnabled,
    totalNodes' = totalNodes,
    globalClock' = globalClock + 1000
  }

  action recoveryComplete = all {
    clusterState == Recovering,
    clusterState' = Healthy,
    writesEnabled' = true,
    activeNodes' = activeNodes,
    partitionedNodes' = partitionedNodes,
    sentinelActive' = sentinelActive,
    totalNodes' = totalNodes,
    globalClock' = globalClock + 500
  }

  // Intentional leave on quorum loss
  action intentionalLeave = all {
    clusterState == QuorumLost,
    sentinelActive,
    clusterState' = Failed,
    writesEnabled' = false,
    activeNodes' = activeNodes,
    partitionedNodes' = partitionedNodes,
    sentinelActive' = sentinelActive,
    totalNodes' = totalNodes,
    globalClock' = globalClock + 10
  }

  // ---------------------------------------------------------------------------
  // Safety Invariants
  // ---------------------------------------------------------------------------

  // SC-CLU-001: Quorum required for writes
  val quorumForWrites: bool =
    writesEnabled implies hasQuorum

  // SC-CLU-002: Sentinel monitors quorum
  val sentinelMonitors: bool =
    clusterState == QuorumLost implies sentinelActive

  // SC-CLU-003: No writes during partition (without quorum)
  val noWritesDuringPartition: bool =
    clusterState == Partitioned and not(hasQuorum) implies not(writesEnabled)

  // SC-CLU-005: Split-brain prevention
  val splitBrainPrevented: bool =
    clusterState == Partitioned implies (
      writesEnabled == (activeNodes - size(partitionedNodes) >= quorumSize(totalNodes))
    )

  val clusterInvariant: bool =
    quorumForWrites and
    sentinelMonitors and
    noWritesDuringPartition and
    splitBrainPrevented and
    activeNodes <= totalNodes and
    totalNodes >= MIN_CLUSTER_SIZE

  temporal alwaysClusterSafe = always(clusterInvariant)

  // ---------------------------------------------------------------------------
  // Liveness Properties
  // ---------------------------------------------------------------------------

  // Recovery eventually completes
  temporal recoveryCompletes = always(
    clusterState == Recovering implies eventually(clusterState == Healthy)
  )

  // Partition eventually heals or leads to failure
  temporal partitionResolves = always(
    clusterState == Partitioned implies eventually(
      clusterState == Recovering or clusterState == Failed
    )
  )
}
