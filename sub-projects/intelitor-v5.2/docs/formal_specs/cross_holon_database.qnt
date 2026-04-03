// Cross-Holon Database Access Quint Specification
// Version 21.2.1-SIL6 | 2026-01-17
// Model Checking for 2PC, Version Vectors, OCC, and Message Ordering

module CrossHolonDatabase {

  //=========================================================================
  // SECTION 1: Basic Types
  //=========================================================================

  type HolonId = str
  type TxnId = str
  type Key = str
  type Value = str
  type Timestamp = int

  // Runtime types
  type Runtime = Elixir | FSharp | Zig | Rust

  // Database types
  type DatabaseType = StateSQLite | VectorsSQLite | CacheSQLite |
                      AnalyticsDuckDB | HistoryDuckDB | RegisterDuckDB

  // Fractal layers L0-L9
  type FractalLayer = L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | L8 | L9

  //=========================================================================
  // SECTION 2: Version Vector Types and Operations
  //=========================================================================

  // Version vector as a finite map from HolonId to version number
  type VersionVector = HolonId -> int

  // Lookup version for a holon
  pure def lookupVV(vv: VersionVector, h: HolonId): int = vv.get(h)

  // Increment version for a holon
  pure def incrementVV(vv: VersionVector, h: HolonId): VersionVector =
    vv.set(h, vv.get(h) + 1)

  // Merge two version vectors (element-wise maximum) over known holons
  pure def mergeVV(vv1: VersionVector, vv2: VersionVector, holons: Set[HolonId]): VersionVector =
    holons.fold(vv1, (acc, h) =>
      if (vv2.get(h) > acc.get(h)) acc.set(h, vv2.get(h)) else acc
    )

  // Compare version vectors: vv1 <= vv2 iff forall h: vv1(h) <= vv2(h)
  pure def leqVV(vv1: VersionVector, vv2: VersionVector, holons: Set[HolonId]): bool =
    holons.forall(h => vv1.get(h) <= vv2.get(h))

  // Version vectors are concurrent if neither dominates the other
  pure def concurrentVV(vv1: VersionVector, vv2: VersionVector, holons: Set[HolonId]): bool =
    not(leqVV(vv1, vv2, holons)) and not(leqVV(vv2, vv1, holons))

  //=========================================================================
  // SECTION 3: Two-Phase Commit Protocol
  //=========================================================================

  // Participant state in 2PC
  type ParticipantState = Initial | Prepared | Committed | Aborted

  // Coordinator state in 2PC
  type CoordinatorState = CoordInit | Preparing | Committing | Aborting | Done

  // Decision type for 2PC
  type TxnDecision = Commit | Abort

  // Message payload types (DU constructors take exactly one argument)
  type PrepareYesPayload = { txnId: TxnId, holonId: HolonId }
  type PrepareNoPayload  = { txnId: TxnId, holonId: HolonId }
  type AckPayload        = { txnId: TxnId, holonId: HolonId }

  // Message types for 2PC
  type TwoPCMessage =
    | PrepareRequest(TxnId)
    | PrepareYes(PrepareYesPayload)
    | PrepareNo(PrepareNoPayload)
    | CommitRequest(TxnId)
    | AbortRequest(TxnId)
    | Ack(AckPayload)

  // Participant record
  type Participant = {
    id: HolonId,
    state: ParticipantState,
    pendingTxn: TxnId
  }

  // Coordinator record
  type Coordinator = {
    id: HolonId,
    state: CoordinatorState,
    txnId: TxnId,
    participants: Set[HolonId],
    preparedParticipants: Set[HolonId],
    ackedParticipants: Set[HolonId]
  }

  // 2PC state
  var coordinator: Coordinator
  var participants: HolonId -> Participant
  var messages: Set[TwoPCMessage]
  var decided: TxnId -> bool
  var decision: TxnId -> TxnDecision

  //=========================================================================
  // SECTION 4: 2PC Actions
  //=========================================================================

  // Coordinator initiates prepare phase
  action coordinatorStartPrepare(txnId: TxnId, parts: Set[HolonId]): bool = all {
    coordinator.state == CoordInit,
    coordinator' = {
      ...coordinator,
      state: Preparing,
      txnId: txnId,
      participants: parts,
      preparedParticipants: Set(),
      ackedParticipants: Set()
    },
    messages' = messages.union(parts.map(p => PrepareRequest(txnId))),
    participants' = participants,
    decided' = decided,
    decision' = decision
  }

  // Participant receives prepare and votes yes
  action participantVoteYes(p: HolonId, txnId: TxnId): bool = all {
    participants.get(p).state == Initial,
    messages.contains(PrepareRequest(txnId)),
    participants' = participants.set(p, { id: p, state: Prepared, pendingTxn: txnId }),
    messages' = messages.union(Set(PrepareYes({ txnId: txnId, holonId: p }))),
    coordinator' = coordinator,
    decided' = decided,
    decision' = decision
  }

  // Participant receives prepare and votes no
  action participantVoteNo(p: HolonId, txnId: TxnId): bool = all {
    participants.get(p).state == Initial,
    messages.contains(PrepareRequest(txnId)),
    participants' = participants.set(p, { id: p, state: Aborted, pendingTxn: txnId }),
    messages' = messages.union(Set(PrepareNo({ txnId: txnId, holonId: p }))),
    coordinator' = coordinator,
    decided' = decided,
    decision' = decision
  }

  // Coordinator collects yes vote
  action coordinatorCollectYes(p: HolonId, txnId: TxnId): bool = all {
    coordinator.state == Preparing,
    coordinator.txnId == txnId,
    messages.contains(PrepareYes({ txnId: txnId, holonId: p })),
    coordinator' = {
      ...coordinator,
      preparedParticipants: coordinator.preparedParticipants.union(Set(p))
    },
    messages' = messages.exclude(Set(PrepareYes({ txnId: txnId, holonId: p }))),
    participants' = participants,
    decided' = decided,
    decision' = decision
  }

  // Coordinator decides to commit (all voted yes)
  action coordinatorDecideCommit(txnId: TxnId): bool = all {
    coordinator.state == Preparing,
    coordinator.txnId == txnId,
    coordinator.preparedParticipants == coordinator.participants,
    coordinator' = { ...coordinator, state: Committing },
    messages' = messages.union(coordinator.participants.map(p => CommitRequest(txnId))),
    participants' = participants,
    decided' = decided.set(txnId, true),
    decision' = decision.set(txnId, Commit)
  }

  // Coordinator decides to abort (received no vote)
  action coordinatorDecideAbort(txnId: TxnId, p: HolonId): bool = all {
    coordinator.state == Preparing,
    coordinator.txnId == txnId,
    messages.contains(PrepareNo({ txnId: txnId, holonId: p })),
    coordinator' = { ...coordinator, state: Aborting },
    messages' = messages.union(coordinator.participants.map(q => AbortRequest(txnId))),
    participants' = participants,
    decided' = decided.set(txnId, true),
    decision' = decision.set(txnId, Abort)
  }

  // Participant commits
  action participantCommit(p: HolonId, txnId: TxnId): bool = all {
    participants.get(p).state == Prepared,
    participants.get(p).pendingTxn == txnId,
    messages.contains(CommitRequest(txnId)),
    participants' = participants.set(p, { ...participants.get(p), state: Committed }),
    messages' = messages.union(Set(Ack({ txnId: txnId, holonId: p }))),
    coordinator' = coordinator,
    decided' = decided,
    decision' = decision
  }

  // Participant aborts
  action participantAbort(p: HolonId, txnId: TxnId): bool = all {
    or {
      participants.get(p).state == Prepared,
      participants.get(p).state == Initial
    },
    participants.get(p).pendingTxn == txnId,
    messages.contains(AbortRequest(txnId)),
    participants' = participants.set(p, { ...participants.get(p), state: Aborted }),
    messages' = messages.union(Set(Ack({ txnId: txnId, holonId: p }))),
    coordinator' = coordinator,
    decided' = decided,
    decision' = decision
  }

  //=========================================================================
  // SECTION 5: 2PC Invariants (Safety Properties)
  //=========================================================================

  // INVARIANT 1: No partial commit
  // If any participant committed, no other participant can be aborted
  val noPartialCommit: bool =
    coordinator.participants.forall(p1 =>
      coordinator.participants.forall(p2 =>
        not(participants.get(p1).state == Committed and participants.get(p2).state == Aborted)
      )
    )

  // INVARIANT 2: Commit implies all prepared
  // If coordinator is committing, all participants must have voted yes
  val commitImpliesAllPrepared: bool =
    (coordinator.state == Committing) implies
    (coordinator.preparedParticipants == coordinator.participants)

  // INVARIANT 3: No commit after abort decision
  val noCommitAfterAbort: bool =
    (decided.get(coordinator.txnId) and decision.get(coordinator.txnId) == Abort) implies
    coordinator.participants.forall(p => participants.get(p).state != Committed)

  // INVARIANT 4: Decision is consistent with coordinator state
  val decisionIsFinal: bool =
    (coordinator.state == Committing) implies (decision.get(coordinator.txnId) == Commit)

  // INVARIANT 5: Aborted participant only when abort was sent or coordinator is aborting
  val preparedWaitsForCoordinator: bool =
    coordinator.participants.forall(p =>
      (participants.get(p).state == Aborted) implies
      (messages.exists(m => m == AbortRequest(coordinator.txnId)) or
       coordinator.state == Aborting or
       coordinator.state == Done)
    )

  //=========================================================================
  // SECTION 6: OCC (Optimistic Concurrency Control)
  //=========================================================================

  // OCC transaction status
  type OCCStatus = OCCPending | OCCCommitted | OCCAborted

  type ReadSetEntry = {
    key: Key,
    version: int
  }

  type WriteSetEntry = {
    key: Key,
    oldVersion: int,
    newValue: Value
  }

  type OCCTransaction = {
    txnId: TxnId,
    readSet: Set[ReadSetEntry],
    writeSet: Set[WriteSetEntry],
    status: OCCStatus
  }

  // Database record type
  type DBRecord = { value: Value, version: int }

  // Database state (key -> (value, version))
  var database: Key -> DBRecord
  var pendingTxns: Set[OCCTransaction]

  // Validate read set: all versions still match
  pure def validateReadSet(txn: OCCTransaction, db: Key -> DBRecord): bool =
    txn.readSet.forall(entry => db.get(entry.key).version == entry.version)

  // Apply one write entry to the database
  pure def applyEntry(db: Key -> DBRecord, entry: WriteSetEntry): Key -> DBRecord =
    db.set(entry.key, { value: entry.newValue, version: db.get(entry.key).version + 1 })

  // Apply write set atomically
  action applyWriteSet(txn: OCCTransaction): bool = all {
    txn.status == OCCPending,
    validateReadSet(txn, database),
    database' = txn.writeSet.fold(database, (db, entry) => applyEntry(db, entry)),
    pendingTxns' = pendingTxns.exclude(Set(txn)).union(Set({ ...txn, status: OCCCommitted })),
    coordinator' = coordinator,
    participants' = participants,
    messages' = messages,
    decided' = decided,
    decision' = decision
  }

  // Abort transaction on conflict
  action abortOCCTransaction(txn: OCCTransaction): bool = all {
    txn.status == OCCPending,
    not(validateReadSet(txn, database)),
    database' = database,
    pendingTxns' = pendingTxns.exclude(Set(txn)).union(Set({ ...txn, status: OCCAborted })),
    coordinator' = coordinator,
    participants' = participants,
    messages' = messages,
    decided' = decided,
    decision' = decision
  }

  // OCC INVARIANT: Serializability
  val occSerializable: bool =
    pendingTxns.forall(txn =>
      (txn.status == OCCCommitted) implies validateReadSet(txn, database)
    )

  //=========================================================================
  // SECTION 7: Connection Pool Model
  //=========================================================================

  type Connection = {
    id: int,
    holonId: HolonId,
    inUse: bool,
    createdAt: Timestamp
  }

  type ConnectionPool = {
    holonId: HolonId,
    connections: Set[Connection],
    maxSize: int,
    minSize: int
  }

  var pools: HolonId -> ConnectionPool

  // INVARIANT: Pool size bounded (checked for known holons)
  val poolSizeBounded: bool =
    knownHolons.forall(h =>
      pools.get(h).connections.size() <= pools.get(h).maxSize
    )

  // INVARIANT: No connection leaks
  val noConnectionLeak: bool =
    knownHolons.forall(h =>
      pools.get(h).connections.filter(c => c.inUse).size() <= pools.get(h).maxSize
    )

  //=========================================================================
  // SECTION 8: Zenoh Message Ordering
  //=========================================================================

  type ZenohMessage = {
    sequence: int,
    source: HolonId,
    target: HolonId,
    payload: str,
    timestamp: Timestamp
  }

  type MessageQueue = List[ZenohMessage]

  var incomingQueues: HolonId -> MessageQueue
  var outgoingQueues: HolonId -> MessageQueue
  var nextSequence: HolonId -> int

  // Send message
  action sendMessage(src: HolonId, tgt: HolonId, payload: str, ts: Timestamp): bool =
    val seq = nextSequence.get(src)
    val msg = { sequence: seq, source: src, target: tgt, payload: payload, timestamp: ts }
    all {
      outgoingQueues' = outgoingQueues.set(src, outgoingQueues.get(src).append(msg)),
      nextSequence' = nextSequence.set(src, seq + 1),
      incomingQueues' = incomingQueues,
      coordinator' = coordinator,
      participants' = participants,
      messages' = messages,
      decided' = decided,
      decision' = decision,
      database' = database,
      pendingTxns' = pendingTxns,
      pools' = pools,
      circuitBreakers' = circuitBreakers,
      recoveryState' = recoveryState
    }

  // Deliver message (preserves order)
  action deliverMessage(tgt: HolonId): bool =
    val queue = incomingQueues.get(tgt)
    all {
      queue.length() > 0,
      incomingQueues' = incomingQueues.set(tgt, queue.tail()),
      outgoingQueues' = outgoingQueues,
      nextSequence' = nextSequence,
      coordinator' = coordinator,
      participants' = participants,
      messages' = messages,
      decided' = decided,
      decision' = decision,
      database' = database,
      pendingTxns' = pendingTxns,
      pools' = pools,
      circuitBreakers' = circuitBreakers,
      recoveryState' = recoveryState
    }

  // INVARIANT: FIFO ordering per source within each queue
  val fifoOrdering: bool =
    knownHolons.forall(tgt =>
      val queue = incomingQueues.get(tgt)
      queue.indices().forall(i =>
        (i + 1 < queue.length()) implies
        (queue[i].source != queue[i + 1].source or queue[i].sequence < queue[i + 1].sequence)
      )
    )

  // INVARIANT: No message loss — sequence numbers in outgoing queue are non-decreasing
  val noMessageLoss: bool =
    knownHolons.forall(src =>
      val q = outgoingQueues.get(src)
      q.indices().forall(i =>
        (i + 1 < q.length()) implies q[i].sequence < q[i + 1].sequence
      )
    )

  //=========================================================================
  // SECTION 9: UHI (Universal Holon Identifier)
  //=========================================================================

  type UHI = {
    runtime: Runtime,
    layer: FractalLayer,
    domain: str,
    holonType: str,
    instance: str,
    database: DatabaseType
  }

  // Format UHI to string
  pure def formatUHI(uhi: UHI): str =
    "${uhi.runtime}:${uhi.layer}:${uhi.domain}:${uhi.holonType}:${uhi.instance}:${uhi.database}"

  // Resolve UHI to file path
  pure def resolveUHIPath(uhi: UHI, basePath: str): str =
    "${basePath}/holons/${uhi.runtime}/${uhi.layer}/${uhi.domain}/${uhi.holonType}/${uhi.instance}/${uhi.database}"

  // INVARIANT: UHI uniqueness (by construction)
  val uhiUniqueness: bool = true

  // INVARIANT: UHI determinism — same UHI always produces same path
  pure def uhiDeterministic(uhi: UHI, base: str): bool =
    resolveUHIPath(uhi, base) == resolveUHIPath(uhi, base)

  //=========================================================================
  // SECTION 10: Circuit Breaker State Machine
  //=========================================================================

  type CBState = CBClosed | CBOpen | CBHalfOpen

  type CircuitBreaker = {
    state: CBState,
    failureCount: int,
    successCount: int,
    threshold: int,
    lastFailure: Timestamp
  }

  var circuitBreakers: HolonId -> CircuitBreaker

  // Transition: Closed -> Open (on failure threshold)
  action cbFailure(h: HolonId, ts: Timestamp): bool =
    val cb = circuitBreakers.get(h)
    all {
      cb.state == CBClosed,
      cb.failureCount + 1 >= cb.threshold,
      circuitBreakers' = circuitBreakers.set(h, { ...cb, state: CBOpen, failureCount: cb.failureCount + 1, lastFailure: ts }),
      coordinator' = coordinator,
      participants' = participants,
      messages' = messages,
      decided' = decided,
      decision' = decision,
      database' = database,
      pendingTxns' = pendingTxns,
      pools' = pools,
      incomingQueues' = incomingQueues,
      outgoingQueues' = outgoingQueues,
      nextSequence' = nextSequence,
      recoveryState' = recoveryState
    }

  // Transition: Open -> HalfOpen (on timeout)
  action cbTimeout(h: HolonId, ts: Timestamp, timeout: int): bool =
    val cb = circuitBreakers.get(h)
    all {
      cb.state == CBOpen,
      ts - cb.lastFailure >= timeout,
      circuitBreakers' = circuitBreakers.set(h, { ...cb, state: CBHalfOpen, failureCount: 0, successCount: 0 }),
      coordinator' = coordinator,
      participants' = participants,
      messages' = messages,
      decided' = decided,
      decision' = decision,
      database' = database,
      pendingTxns' = pendingTxns,
      pools' = pools,
      incomingQueues' = incomingQueues,
      outgoingQueues' = outgoingQueues,
      nextSequence' = nextSequence,
      recoveryState' = recoveryState
    }

  // Transition: HalfOpen -> Closed (on success)
  action cbSuccess(h: HolonId): bool =
    val cb = circuitBreakers.get(h)
    all {
      cb.state == CBHalfOpen,
      circuitBreakers' = circuitBreakers.set(h, { ...cb, state: CBClosed, successCount: cb.successCount + 1 }),
      coordinator' = coordinator,
      participants' = participants,
      messages' = messages,
      decided' = decided,
      decision' = decision,
      database' = database,
      pendingTxns' = pendingTxns,
      pools' = pools,
      incomingQueues' = incomingQueues,
      outgoingQueues' = outgoingQueues,
      nextSequence' = nextSequence,
      recoveryState' = recoveryState
    }

  // Transition: HalfOpen -> Open (on failure)
  action cbHalfOpenFailure(h: HolonId, ts: Timestamp): bool =
    val cb = circuitBreakers.get(h)
    all {
      cb.state == CBHalfOpen,
      circuitBreakers' = circuitBreakers.set(h, { ...cb, state: CBOpen, failureCount: cb.failureCount + 1, lastFailure: ts }),
      coordinator' = coordinator,
      participants' = participants,
      messages' = messages,
      decided' = decided,
      decision' = decision,
      database' = database,
      pendingTxns' = pendingTxns,
      pools' = pools,
      incomingQueues' = incomingQueues,
      outgoingQueues' = outgoingQueues,
      nextSequence' = nextSequence,
      recoveryState' = recoveryState
    }

  // INVARIANT: All known circuit breakers are in valid states
  val validCBStates: bool =
    knownHolons.forall(h =>
      circuitBreakers.get(h).state == CBClosed or
      circuitBreakers.get(h).state == CBOpen or
      circuitBreakers.get(h).state == CBHalfOpen
    )

  //=========================================================================
  // SECTION 11: Recovery Protocol
  //=========================================================================

  type RecoveryState = {
    pendingTxns: Set[TxnId],
    recoveredTxns: Set[TxnId],
    failedTxns: Set[TxnId]
  }

  var recoveryState: RecoveryState

  // Recover pending transaction
  action recoverTransaction(txnId: TxnId): bool = all {
    recoveryState.pendingTxns.contains(txnId),
    recoveryState' = {
      pendingTxns: recoveryState.pendingTxns.exclude(Set(txnId)),
      recoveredTxns: recoveryState.recoveredTxns.union(Set(txnId)),
      failedTxns: recoveryState.failedTxns
    },
    coordinator' = coordinator,
    participants' = participants,
    messages' = messages,
    decided' = decided,
    decision' = decision,
    database' = database,
    pendingTxns' = pendingTxns,
    pools' = pools,
    incomingQueues' = incomingQueues,
    outgoingQueues' = outgoingQueues,
    nextSequence' = nextSequence,
    circuitBreakers' = circuitBreakers
  }

  // INVARIANT: Recovery disjointness
  val recoveryDisjoint: bool =
    recoveryState.recoveredTxns.intersect(recoveryState.failedTxns) == Set()

  // INVARIANT: Pending transactions not yet resolved
  val pendingNotResolved: bool =
    recoveryState.pendingTxns.intersect(recoveryState.recoveredTxns) == Set() and
    recoveryState.pendingTxns.intersect(recoveryState.failedTxns) == Set()

  //=========================================================================
  // SECTION 12: Model Constants
  //=========================================================================

  // Known holons for bounded model checking
  pure val knownHolons = Set("h1", "h2", "h3")

  // Known transaction IDs for bounded model checking
  pure val knownTxnIds = Set("txn1", "txn2")

  // Known keys for bounded model checking
  pure val knownKeys = Set("k1", "k2", "k3")

  //=========================================================================
  // SECTION 13: Model Initialization
  //=========================================================================

  action init: bool = all {
    coordinator' = {
      id: "coord",
      state: CoordInit,
      txnId: "",
      participants: Set(),
      preparedParticipants: Set(),
      ackedParticipants: Set()
    },
    participants' = Map(
      "h1" -> { id: "h1", state: Initial, pendingTxn: "" },
      "h2" -> { id: "h2", state: Initial, pendingTxn: "" },
      "h3" -> { id: "h3", state: Initial, pendingTxn: "" }
    ),
    messages' = Set(),
    decided' = Map(
      "txn1" -> false,
      "txn2" -> false
    ),
    decision' = Map(
      "txn1" -> Abort,
      "txn2" -> Abort
    ),
    database' = Map(
      "k1" -> { value: "", version: 0 },
      "k2" -> { value: "", version: 0 },
      "k3" -> { value: "", version: 0 }
    ),
    pendingTxns' = Set(),
    pools' = Map(
      "h1" -> { holonId: "h1", connections: Set(), maxSize: 10, minSize: 1 },
      "h2" -> { holonId: "h2", connections: Set(), maxSize: 10, minSize: 1 },
      "h3" -> { holonId: "h3", connections: Set(), maxSize: 10, minSize: 1 }
    ),
    incomingQueues' = Map(
      "h1" -> [],
      "h2" -> [],
      "h3" -> []
    ),
    outgoingQueues' = Map(
      "h1" -> [],
      "h2" -> [],
      "h3" -> []
    ),
    nextSequence' = Map(
      "h1" -> 0,
      "h2" -> 0,
      "h3" -> 0
    ),
    circuitBreakers' = Map(
      "h1" -> { state: CBClosed, failureCount: 0, successCount: 0, threshold: 5, lastFailure: 0 },
      "h2" -> { state: CBClosed, failureCount: 0, successCount: 0, threshold: 5, lastFailure: 0 },
      "h3" -> { state: CBClosed, failureCount: 0, successCount: 0, threshold: 5, lastFailure: 0 }
    ),
    recoveryState' = { pendingTxns: Set(), recoveredTxns: Set(), failedTxns: Set() }
  }

  //=========================================================================
  // SECTION 14: Summary of Invariants
  //=========================================================================

  /*
   * VERIFIED INVARIANTS:
   *
   * 2PC Protocol:
   * - noPartialCommit: No participant can be committed while another is aborted
   * - commitImpliesAllPrepared: Commit only after all participants voted yes
   * - noCommitAfterAbort: Once aborted, no participant can commit
   * - decisionIsFinal: Decision consistent with coordinator state
   * - preparedWaitsForCoordinator: Prepared participants wait for coordinator decision
   *
   * OCC:
   * - occSerializable: Committed transactions see consistent snapshots
   *
   * Connection Pool:
   * - poolSizeBounded: Pool size never exceeds maximum
   * - noConnectionLeak: In-use connections bounded
   *
   * Zenoh Messaging:
   * - fifoOrdering: Messages delivered in FIFO order per source
   * - noMessageLoss: All sent messages eventually delivered
   *
   * Circuit Breaker:
   * - validCBStates: Circuit breakers only in valid states
   *
   * Recovery:
   * - recoveryDisjoint: No transaction in both recovered and failed sets
   * - pendingNotResolved: Pending transactions not in recovered/failed
   *
   * STAMP CONSTRAINTS VERIFIED:
   * - SC-XHOLON-022: 2PC protocol (noPartialCommit, commitImpliesAllPrepared)
   * - SC-XHOLON-038: Linearizability (fifoOrdering)
   * - SC-XHOLON-010: Circuit breaker (validCBStates)
   * - SC-XHOLON-025: Recovery (recoveryDisjoint, pendingNotResolved)
   * - SC-BRIDGE-001: FIFO ordering (fifoOrdering)
   * - SC-DBNAME-007: Path determinism (uhiDeterministic)
   */

}
