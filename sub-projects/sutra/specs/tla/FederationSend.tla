---- MODULE FederationSend ----
(*
 * Matrix Federation: PUT /_matrix/federation/v1/send/{txnId}
 * Ref: https://spec.matrix.org/v1.13/server-server-api/
 *
 * Models transaction sending, idempotency, auth validation,
 * backfill of missing prev_events, and PDU insertion.
 *)

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS TxnIds, EventIds, MaxPDUsPerTxn, Servers

ASSUME Cardinality(Servers) >= 2
ASSUME MaxPDUsPerTxn >= 1

Sender   == CHOOSE s \in Servers : TRUE
Receiver == CHOOSE s \in Servers : s # Sender

VARIABLES
    processedTxns, knownEvents, roomState, pendingBackfill,
    currentTxn, txnPDUs, pduParents, pduAuthValid, phase

vars == <<processedTxns, knownEvents, roomState, pendingBackfill,
          currentTxn, txnPDUs, pduParents, pduAuthValid, phase>>

TypeOK ==
    /\ processedTxns   \subseteq TxnIds
    /\ knownEvents     \subseteq EventIds
    /\ pendingBackfill \subseteq EventIds
    /\ currentTxn      \in TxnIds \cup {"none"}
    /\ txnPDUs         \in Seq(EventIds)
    /\ phase           \in {"idle", "received", "backfilling", "inserting", "done"}
    /\ Len(txnPDUs)    <= MaxPDUsPerTxn

Parents(pdu) == pduParents[pdu]
MissingParents(pdu) == Parents(pdu) \ knownEvents
CanInsert(pdu) == MissingParents(pdu) = {} /\ pduAuthValid[pdu]

Init ==
    /\ processedTxns   = {}
    /\ knownEvents     = {}
    /\ roomState       = [e \in EventIds |-> FALSE]
    /\ pendingBackfill = {}
    /\ currentTxn      = "none"
    /\ txnPDUs         = <<>>
    /\ pduParents      \in [EventIds -> SUBSET EventIds]
    /\ pduAuthValid    \in [EventIds -> BOOLEAN]
    /\ phase           = "idle"

ReceiveTransaction(txnId, pdus) ==
    /\ phase = "idle"
    /\ txnId \in TxnIds
    /\ Len(pdus) >= 1 /\ Len(pdus) <= MaxPDUsPerTxn
    /\ currentTxn' = txnId /\ txnPDUs' = pdus
    /\ phase' = IF txnId \in processedTxns THEN "done" ELSE "received"
    /\ UNCHANGED <<processedTxns, knownEvents, roomState, pendingBackfill,
                   pduParents, pduAuthValid>>

IdentifyBackfill ==
    /\ phase = "received"
    /\ LET missing == UNION {MissingParents(txnPDUs[i]) : i \in 1..Len(txnPDUs)}
       IN
       /\ pendingBackfill' = missing
       /\ phase' = IF missing = {} THEN "inserting" ELSE "backfilling"
    /\ UNCHANGED <<processedTxns, knownEvents, roomState, currentTxn,
                   txnPDUs, pduParents, pduAuthValid>>

BackfillOne ==
    /\ phase = "backfilling"
    /\ pendingBackfill # {}
    /\ LET e == CHOOSE ev \in pendingBackfill : TRUE
       IN
       /\ knownEvents' = knownEvents \cup {e}
       /\ pendingBackfill' = (pendingBackfill \ {e}) \cup MissingParents(e)
    /\ phase' = IF pendingBackfill' = {} THEN "inserting" ELSE "backfilling"
    /\ UNCHANGED <<processedTxns, roomState, currentTxn, txnPDUs,
                   pduParents, pduAuthValid>>

InsertPDUs ==
    /\ phase = "inserting"
    /\ LET insertable == {txnPDUs[i] : i \in 1..Len(txnPDUs)} \intersect
                         {pdu \in EventIds : CanInsert(pdu)}
       IN
       /\ knownEvents' = knownEvents \cup insertable
       /\ roomState' = [e \in EventIds |->
              IF e \in insertable THEN TRUE ELSE roomState[e]]
    /\ processedTxns' = processedTxns \cup {currentTxn}
    /\ phase' = "done"
    /\ UNCHANGED <<pendingBackfill, currentTxn, txnPDUs, pduParents, pduAuthValid>>

Complete ==
    /\ phase = "done"
    /\ phase' = "idle" /\ currentTxn' = "none" /\ txnPDUs' = <<>>
    /\ UNCHANGED <<processedTxns, knownEvents, roomState, pendingBackfill,
                   pduParents, pduAuthValid>>

Next ==
    \/ \E txnId \in TxnIds, pdus \in Seq(EventIds) :
           ReceiveTransaction(txnId, pdus)
    \/ IdentifyBackfill
    \/ BackfillOne
    \/ InsertPDUs
    \/ Complete

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* Safety: No orphan events (all parents known)
NoOrphanEvents ==
    \A e \in knownEvents : Parents(e) \subseteq knownEvents

\* Safety: Backfill cleared before insert
BackfillClearedBeforeInsert ==
    phase = "inserting" => pendingBackfill = {}

\* Safety: Processed txns only grow
ProcessedTxnsGrow ==
    [][processedTxns \subseteq processedTxns']_processedTxns

\* Liveness: Transactions eventually processed
TransactionEventuallyProcessed ==
    \A txn \in TxnIds :
        (currentTxn = txn) ~> (txn \in processedTxns)

INVARIANT TypeOK
INVARIANT NoOrphanEvents
INVARIANT BackfillClearedBeforeInsert

PROPERTY TransactionEventuallyProcessed

====
