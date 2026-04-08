--------------------------- MODULE LeaderElection ---------------------------
EXTENDS Naturals, FiniteSets, Sequences

CONSTANTS Nodes, LeaseTTL

VARIABLES active_nodes, current_leader, lease_expiry, db_state

vars == <<active_nodes, current_leader, lease_expiry, db_state>>

Init == 
    /\ active_nodes = {}
    /\ current_leader = "none"
    /\ lease_expiry = 0
    /\ db_state = 0

BecomeLeader(n) ==
    /\ active_nodes' = active_nodes \cup {n}
    /\ current_leader = "none"
    /\ current_leader' = n
    /\ lease_expiry' = LeaseTTL
    /\ UNCHANGED db_state

Heartbeat(n) ==
    /\ current_leader = n
    /\ lease_expiry' = LeaseTTL
    /\ UNCHANGED <<active_nodes, current_leader, db_state>>

ExpireLease ==
    /\ lease_expiry > 0
    /\ lease_expiry' = 0
    /\ current_leader' = "none"
    /\ UNCHANGED <<active_nodes, db_state>>

WriteDB(n) ==
    /\ current_leader = n
    /\ lease_expiry > 0
    /\ db_state' = db_state + 1
    /\ UNCHANGED <<active_nodes, current_leader, lease_expiry>>

Next == 
    \/ \E n \in Nodes : BecomeLeader(n)
    \/ \E n \in Nodes : Heartbeat(n)
    \/ \E n \in Nodes : WriteDB(n)
    \/ ExpireLease

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

MutualExclusion == 
    \/ current_leader = "none"
    \/ current_leader \in Nodes

Liveness == 
    (current_leader = "none") ~> (current_leader \in Nodes)

=============================================================================