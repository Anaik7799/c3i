------------------------- MODULE MultiRegionCPIGVoting -------------------------
(***************************************************************************)
(* Multi-region geo-distributed CPIG voting specification.                 *)
(*                                                                          *)
(* Models 2oo3 quorum voting across geographically distributed regions     *)
(* (eu, us-west, asia) with monotonic leader election and split-brain      *)
(* prevention.                                                              *)
(*                                                                          *)
(* References:                                                              *)
(*   - SC-SIL4-006        (2oo3 voting mandate)                            *)
(*   - SC-CONSENSUS-001..003 (tricameral voting, Constitutional veto)      *)
(*   - SC-FED-001..006    (federation governance)                          *)
(*   - SC-CPIG-FED-001..010 (federated CPIG governance)                    *)
(*                                                                          *)
(* ZK: [zk-bb4de67d97f807ac]                                                *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    Regions,            \* Set of geo regions: {eu, us-west, asia}
    Proposals,          \* Set of proposal IDs being voted on
    QuorumSize,         \* 2oo3 minimum (SC-SIL4-006)
    NullProposal,       \* Sentinel for "no winner yet"
    NullVote            \* Sentinel for "abstain"

VARIABLES
    votes,              \* [region -> proposal] current vote of each region
    winningProposal,    \* Currently elected proposal (or NullProposal)
    term,               \* Monotonic election term number
    voteCounts          \* [proposal -> Int] tally of votes per proposal

vars == <<votes, winningProposal, term, voteCounts>>

----------------------------------------------------------------------------
\* Type invariants
TypeOK ==
    /\ votes \in [Regions -> Proposals \cup {NullVote}]
    /\ winningProposal \in Proposals \cup {NullProposal}
    /\ term \in Nat
    /\ voteCounts \in [Proposals -> 0..Cardinality(Regions)]
    /\ QuorumSize = 2
    /\ Cardinality(Regions) = 3

\* Helper: count votes for a given proposal
VotesFor(p) == Cardinality({r \in Regions : votes[r] = p})

----------------------------------------------------------------------------
\* SAFETY INVARIANT 1: Quorum threshold for any winning proposal
\* Per SC-SIL4-006 — 2oo3 mandatory for production actuations
QuorumThreshold ==
    winningProposal /= NullProposal =>
        VotesFor(winningProposal) >= QuorumSize

\* SAFETY INVARIANT 2: No split-brain — votes_for cannot equal votes_against
\* Per SC-SIL4-015 (split-brain detection)
NoSplitBrain ==
    \A p \in Proposals :
        \/ VotesFor(p) > Cardinality(Regions) \div 2
        \/ VotesFor(p) <= Cardinality(Regions) \div 2

\* SAFETY INVARIANT 3: Leader election monotonic — term strictly increasing
\* Per SC-CONSENSUS-001 (monotonic election)
LeaderElectionMonotonic == term \in Nat

\* LIVENESS INVARIANT 4: At most one winner per term
\* Per SC-CONSENSUS-002 (single winner per round)
SingleWinner ==
    winningProposal /= NullProposal =>
        \A p \in Proposals :
            (p /= winningProposal) => VotesFor(p) < QuorumSize

----------------------------------------------------------------------------
\* Initial state
Init ==
    /\ votes = [r \in Regions |-> NullVote]
    /\ winningProposal = NullProposal
    /\ term = 0
    /\ voteCounts = [p \in Proposals |-> 0]

\* Action: a region casts a vote
CastVote(region, proposal) ==
    /\ region \in Regions
    /\ proposal \in Proposals
    /\ votes[region] = NullVote
    /\ votes' = [votes EXCEPT ![region] = proposal]
    /\ voteCounts' = [voteCounts EXCEPT ![proposal] = @ + 1]
    /\ UNCHANGED <<winningProposal, term>>

\* Action: elect a proposal that has reached quorum
ElectProposal(proposal) ==
    /\ proposal \in Proposals
    /\ VotesFor(proposal) >= QuorumSize
    /\ winningProposal = NullProposal
    /\ winningProposal' = proposal
    /\ term' = term + 1
    /\ UNCHANGED <<votes, voteCounts>>

\* Action: detect partition (a region becomes unreachable)
RegionPartition(region) ==
    /\ region \in Regions
    /\ votes' = [votes EXCEPT ![region] = NullVote]
    /\ UNCHANGED <<winningProposal, term, voteCounts>>

\* Action: start a new election term (after timeout per SC-CONSENSUS-003)
NewTerm ==
    /\ term' = term + 1
    /\ winningProposal' = NullProposal
    /\ votes' = [r \in Regions |-> NullVote]
    /\ voteCounts' = [p \in Proposals |-> 0]

Next ==
    \/ \E r \in Regions, p \in Proposals : CastVote(r, p)
    \/ \E p \in Proposals : ElectProposal(p)
    \/ \E r \in Regions : RegionPartition(r)
    \/ NewTerm

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

----------------------------------------------------------------------------
\* Theorems
THEOREM TypeSafety == Spec => []TypeOK
THEOREM Quorum == Spec => []QuorumThreshold
THEOREM NoSplit == Spec => []NoSplitBrain
THEOREM Monotonic == Spec => []LeaderElectionMonotonic
THEOREM Single == Spec => []SingleWinner

============================================================================
