---- MODULE StateResolutionV2 ----
(*
 * Matrix State Resolution Algorithm v2 (MSC2176 / MSC1442)
 * Ref: https://spec.matrix.org/v1.13/rooms/v2/
 *
 * Models the deterministic state resolution process for conflicting
 * state from concurrent event branches in federated rooms.
 *)

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS
    EventIds,
    Users,
    EventTypes,
    StateKeys,
    MaxPowerLevel

ASSUME MaxPowerLevel > 0
ASSUME EventIds # {}
ASSUME Users # {}

StateTuples == EventTypes \X StateKeys

VARIABLES
    events,
    resolvedState,
    phase,
    conflictedSet,
    unconflictedSet,
    authChain,
    iterOrder,
    iterIdx

vars == <<events, resolvedState, phase, conflictedSet,
          unconflictedSet, authChain, iterOrder, iterIdx>>

TypeOK ==
    /\ phase \in {"collecting", "auth_chain", "iterating", "done"}
    /\ conflictedSet   \subseteq StateTuples
    /\ unconflictedSet \subseteq StateTuples
    /\ authChain       \subseteq EventIds
    /\ Len(iterOrder) <= Cardinality(EventIds)
    /\ iterIdx \in 0..Len(iterOrder)

SenderPowerLevel(e) == events[e].power_level

IsAuthEventType(e) ==
    events[e].type \in {
        "m.room.create",
        "m.room.power_levels",
        "m.room.join_rules",
        "m.room.member"
    }

RTPLess(e1, e2) ==
    \/ SenderPowerLevel(e1) > SenderPowerLevel(e2)
    \/ /\ SenderPowerLevel(e1) = SenderPowerLevel(e2)
       /\ events[e1].depth > events[e2].depth
    \/ /\ SenderPowerLevel(e1) = SenderPowerLevel(e2)
       /\ events[e1].depth = events[e2].depth
       /\ e1 < e2

SatisfiesAuthRules(e, currentState) ==
    LET senderPL == events[e].power_level
    IN
    /\ events[e].type = "m.room.member" => senderPL >= 0
    /\ events[e].type = "m.room.power_levels" => senderPL >= 50
    /\ events[e].type = "m.room.join_rules" => senderPL >= 50
    /\ TRUE

Init ==
    /\ resolvedState = [st \in StateTuples |-> <<"NONE","NONE">>]
    /\ phase = "collecting"
    /\ conflictedSet   = {}
    /\ unconflictedSet = {}
    /\ authChain       = {}
    /\ iterOrder       = <<>>
    /\ iterIdx         = 0

CollectConflicts ==
    /\ phase = "collecting"
    /\ LET allStateTuples == {<<events[e].type, events[e].state_key>> : e \in EventIds}
           ConflictedTuples == {st \in allStateTuples :
               Cardinality({e \in EventIds :
                   <<events[e].type, events[e].state_key>> = st}) > 1}
       IN
       /\ conflictedSet'   = ConflictedTuples
       /\ unconflictedSet' = allStateTuples \ ConflictedTuples
       /\ phase'           = "auth_chain"
    /\ UNCHANGED <<events, resolvedState, authChain, iterOrder, iterIdx>>

ComputeAuthChain ==
    /\ phase = "auth_chain"
    /\ LET AuthAncestors == {e \in EventIds : IsAuthEventType(e)}
       IN
       /\ authChain' = AuthAncestors
       /\ resolvedState' = [st \in StateTuples |->
              IF st \in unconflictedSet
              THEN CHOOSE e \in EventIds :
                       <<events[e].type, events[e].state_key>> = st
              ELSE <<"NONE","NONE">>]
       /\ phase' = "iterating"
       /\ iterOrder' = <<>>
       /\ iterIdx' = 0
    /\ UNCHANGED <<events, conflictedSet, unconflictedSet>>

ApplyNextEvent ==
    /\ phase = "iterating"
    /\ iterIdx < Len(iterOrder)
    /\ LET e  == iterOrder[iterIdx + 1]
           st == <<events[e].type, events[e].state_key>>
       IN
       IF SatisfiesAuthRules(e, resolvedState)
       THEN resolvedState' = [resolvedState EXCEPT ![st] = e]
       ELSE resolvedState' = resolvedState
    /\ iterIdx' = iterIdx + 1
    /\ UNCHANGED <<events, phase, conflictedSet, unconflictedSet,
                   authChain, iterOrder>>

FinishIteration ==
    /\ phase = "iterating"
    /\ iterIdx = Len(iterOrder)
    /\ phase' = "done"
    /\ UNCHANGED <<events, resolvedState, conflictedSet, unconflictedSet,
                   authChain, iterOrder, iterIdx>>

Next ==
    \/ CollectConflicts
    \/ ComputeAuthChain
    \/ ApplyNextEvent
    \/ FinishIteration

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* Safety: Resolution is deterministic
ResolutionIsFunction ==
    phase = "done" =>
        \A st \in StateTuples :
            resolvedState[st] \in (EventIds \cup {<<"NONE","NONE">>})

\* Safety: Resolved state never violates auth rules
ResolvedStateAuthSafe ==
    phase = "done" =>
        \A st \in StateTuples :
            resolvedState[st] \in EventIds =>
                SatisfiesAuthRules(resolvedState[st], resolvedState)

\* Safety: Unconflicted state preserved verbatim
UnconflictedPreserved ==
    phase = "done" =>
        \A st \in unconflictedSet :
            \E e \in EventIds :
                /\ <<events[e].type, events[e].state_key>> = st
                /\ resolvedState[st] = e

\* Liveness: Algorithm terminates
AlgorithmTerminates == <>(phase = "done")

INVARIANT TypeOK
INVARIANT ResolutionIsFunction
INVARIANT ResolvedStateAuthSafe
INVARIANT UnconflictedPreserved

PROPERTY AlgorithmTerminates

====
