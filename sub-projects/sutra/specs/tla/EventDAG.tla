---- MODULE EventDAG ----
(*
 * Matrix Event Directed Acyclic Graph (DAG)
 * Ref: https://spec.matrix.org/v1.13/server-server-api/
 *
 * Every Matrix room is a DAG of PDU events.
 * Properties: acyclicity, unique root, full reachability, monotonic depth.
 *)

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS MaxEvents, MaxDepth

ASSUME MaxEvents >= 1
ASSUME MaxDepth  >= 1

EventIds == 1..MaxEvents

VARIABLES
    nodes, parents, depth, root, nextId

vars == <<nodes, parents, depth, root, nextId>>

TypeOK ==
    /\ nodes   \subseteq EventIds
    /\ parents \in [EventIds -> SUBSET EventIds]
    /\ depth   \in [EventIds -> 0..MaxDepth]
    /\ root    \in EventIds \cup {0}
    /\ nextId  \in 1..MaxEvents+1

RECURSIVE Ancestors(_, _)
Ancestors(e, visited) ==
    IF e \in visited \/ parents[e] = {}
    THEN visited
    ELSE LET newVisited == visited \cup {e}
         IN UNION {Ancestors(p, newVisited) : p \in parents[e]}

AllAncestors(e) == Ancestors(e, {})

RECURSIVE Reachable(_, _, _)
Reachable(e1, e2, visited) ==
    \/ e1 = e2
    \/ /\ e1 \notin visited
       /\ \E p \in parents[e1] : Reachable(p, e2, visited \cup {e1})

Init ==
    /\ nodes   = {}
    /\ parents = [e \in EventIds |-> {}]
    /\ depth   = [e \in EventIds |-> 0]
    /\ root    = 0
    /\ nextId  = 1

InsertRoot ==
    /\ nextId = 1
    /\ root = 0
    /\ nodes'   = {1}
    /\ parents' = [parents EXCEPT ![1] = {}]
    /\ depth'   = [depth   EXCEPT ![1] = 0]
    /\ root'    = 1
    /\ nextId'  = 2

InsertEvent(prevSet) ==
    /\ nextId <= MaxEvents
    /\ root # 0
    /\ prevSet \subseteq nodes
    /\ prevSet # {}
    /\ LET e == nextId
           d == 1 + CHOOSE maxD \in {depth[p] : p \in prevSet} :
                    \A p \in prevSet : depth[p] <= maxD
       IN
       /\ d <= MaxDepth
       /\ nodes'   = nodes \cup {e}
       /\ parents' = [parents EXCEPT ![e] = prevSet]
       /\ depth'   = [depth   EXCEPT ![e] = d]
       /\ nextId'  = nextId + 1
    /\ UNCHANGED <<root>>

Next ==
    \/ InsertRoot
    \/ \E S \in SUBSET nodes : S # {} /\ InsertEvent(S)

Spec == Init /\ [][Next]_vars

\* Acyclicity
Acyclic == \A e \in nodes : e \notin AllAncestors(e)

\* Unique root
UniqueRoot ==
    nodes # {} => Cardinality({e \in nodes : parents[e] = {}}) = 1

\* Root reachable from every event
RootReachable ==
    root # 0 => \A e \in nodes : Reachable(e, root, {})

\* Parents have lesser depth
ParentsHaveLesserDepth ==
    \A e \in nodes : \A p \in parents[e] : depth[p] < depth[e]

\* No dangling parent references
NoDanglingParents ==
    \A e \in nodes : parents[e] \subseteq nodes

INVARIANT TypeOK
INVARIANT Acyclic
INVARIANT UniqueRoot
INVARIANT RootReachable
INVARIANT ParentsHaveLesserDepth
INVARIANT NoDanglingParents

====
