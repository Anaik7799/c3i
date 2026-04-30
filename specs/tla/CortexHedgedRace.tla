------------------------- MODULE CortexHedgedRace -------------------------
(***************************************************************************)
(* Formalizes the C3I Cortex Tier 1 + Tier 2 hedged-parallel race          *)
(* (tokio::join!) where Gemini Direct (free, ~900ms) and OpenRouter        *)
(* (paid $0.000009, ~1.1s) fire simultaneously and the first success wins. *)
(*                                                                         *)
(* Source: sub-projects/c3i/native/planning_daemon/src/cortex.rs           *)
(*         sub-projects/c3i/native/planning_daemon/src/mcp_inference.rs    *)
(*                                                                         *)
(* References:                                                             *)
(*   - SC-COG-001  (chat processing pipeline)                              *)
(*   - SC-CIRCUIT-001..002  (circuit breaker policy)                       *)
(*   - CLAUDE.md §15.0      (7-tier hedged inference cascade)              *)
(*                                                                         *)
(* ZK: [zk-bb4de67d97f807ac] [zk-c14e1d23afff486c] [zk-5267ae649f8f69e7]   *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    MaxLatency,   \* upper bound on tier latency (ms), e.g. 5000
    MaxCost       \* upper bound on cost units (micro-USD), e.g. 100

VARIABLES
    tier1State,   \* Idle | Pending | Succeeded | Failed
    tier2State,   \* Idle | Pending | Succeeded | Failed
    winner,       \* tier1 | tier2 | neither
    t1Latency,    \* observed latency of tier 1 in ms
    t2Latency,    \* observed latency of tier 2 in ms
    cancelled     \* subset of {tier1, tier2}

vars == <<tier1State, tier2State, winner, t1Latency, t2Latency, cancelled>>

States   == {"Idle", "Pending", "Succeeded", "Failed"}
Tiers    == {"tier1", "tier2"}
WinSet   == Tiers \cup {"neither"}

TypeOK ==
    /\ tier1State \in States
    /\ tier2State \in States
    /\ winner     \in WinSet
    /\ t1Latency  \in 0..MaxLatency
    /\ t2Latency  \in 0..MaxLatency
    /\ cancelled  \subseteq Tiers

Init ==
    /\ tier1State = "Idle"
    /\ tier2State = "Idle"
    /\ winner     = "neither"
    /\ t1Latency  = 0
    /\ t2Latency  = 0
    /\ cancelled  = {}

(* Tier 1 (Gemini Direct, free) starts and is hedged in parallel with Tier 2. *)
StartHedge ==
    /\ tier1State = "Idle" /\ tier2State = "Idle"
    /\ tier1State' = "Pending"
    /\ tier2State' = "Pending"
    /\ UNCHANGED <<winner, t1Latency, t2Latency, cancelled>>

(* Tier 1 succeeds first => declared winner; Tier 2 is cancelled. *)
Tier1Succeeds ==
    /\ tier1State = "Pending"
    /\ winner = "neither"
    /\ \E lat \in 1..MaxLatency:
         /\ t1Latency'  = lat
         /\ tier1State' = "Succeeded"
         /\ winner'     = "tier1"
         /\ cancelled'  = cancelled \cup {"tier2"}
         /\ tier2State' = IF tier2State = "Pending" THEN "Failed" ELSE tier2State
         /\ UNCHANGED <<t2Latency>>

(* Tier 2 succeeds first => declared winner; Tier 1 is cancelled. *)
Tier2Succeeds ==
    /\ tier2State = "Pending"
    /\ winner = "neither"
    /\ \E lat \in 1..MaxLatency:
         /\ t2Latency'  = lat
         /\ tier2State' = "Succeeded"
         /\ winner'     = "tier2"
         /\ cancelled'  = cancelled \cup {"tier1"}
         /\ tier1State' = IF tier1State = "Pending" THEN "Failed" ELSE tier1State
         /\ UNCHANGED <<t1Latency>>

Tier1Fails ==
    /\ tier1State = "Pending"
    /\ tier1State' = "Failed"
    /\ UNCHANGED <<tier2State, winner, t1Latency, t2Latency, cancelled>>

Tier2Fails ==
    /\ tier2State = "Pending"
    /\ tier2State' = "Failed"
    /\ UNCHANGED <<tier1State, winner, t1Latency, t2Latency, cancelled>>

Next ==
    \/ StartHedge
    \/ Tier1Succeeds
    \/ Tier2Succeeds
    \/ Tier1Fails
    \/ Tier2Fails

Spec == Init /\ [][Next]_vars /\ WF_vars(Tier1Succeeds \/ Tier2Succeeds \/ Tier1Fails \/ Tier2Fails)

(*-------------------------- INVARIANTS ----------------------------------*)

(* Race fairness: tier1 wins iff it succeeded and its latency was no worse. *)
RaceFairness ==
    (winner = "tier1") <=>
        (tier1State = "Succeeded" /\ (tier2State # "Succeeded" \/ t1Latency <= t2Latency))

(* Whichever tier loses must be cancelled (resources reclaimed). *)
LosersCancelled ==
    winner # "neither" =>
        cancelled = (Tiers \ {winner})

(* No two simultaneous winners. *)
NoTwoWinners ==
    winner \in WinSet

(* Cost optimality: if the free tier wins, the paid tier must NOT have been billed. *)
PaidNeverWastedIfFreeWins ==
    winner = "tier1" => tier2State # "Succeeded"

(*-------------------------- LIVENESS ------------------------------------*)

(* Eventually, either someone wins or both tiers fail (no infinite stall). *)
EventuallyDecided ==
    <>(winner # "neither" \/ (tier1State = "Failed" /\ tier2State = "Failed"))

(*-------------------------- MODEL CHECKING NOTES ------------------------*)
(* TLC config:                                                            *)
(*   CONSTANTS  MaxLatency = 3   MaxCost = 10                             *)
(*   INVARIANTS TypeOK RaceFairness LosersCancelled                       *)
(*              NoTwoWinners PaidNeverWastedIfFreeWins                    *)
(*   PROPERTY   EventuallyDecided                                         *)
(* State space: ~few thousand states with these bounds.                   *)
=============================================================================
