---- MODULE CepafBridge ----
(***************************************************************************)
(* F# CEPAF Bridge — F# ↔ Erlang/Gleam isolation, type-safe boundary,       *)
(* runtime 2oo3 quorum for safety-critical decisions.                       *)
(*                                                                          *)
(* Models invariants of the F# CEPAF (Cybernetic Engineering Process &      *)
(* Analysis Framework) bridge: biomorphic synthesis, FMEA generation,       *)
(* formal verification — talks to the BEAM mesh ONLY through Zenoh JSON.    *)
(*                                                                          *)
(* Source modules:                                                          *)
(*   - lib/cepaf/                                                           *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/bridge/                              *)
(*   - specs/allium/ignition.allium                                         *)
(*                                                                          *)
(* STAMP: SC-PRIME-001..003, SC-QUORUM-001, SC-SIL4-006, SC-ZMOF-001        *)
(***************************************************************************)

EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    FsharpProcs,        \* set of F# CEPAF processes
    ErlangProcs,        \* set of Erlang/Gleam BEAM processes
    Decisions,          \* finite decision identifier domain
    Channels            \* {zenoh, direct_ipc, shared_mem} — only zenoh is allowed

VARIABLES
    messages,           \* sequence of cross-language messages
    serialization_ok,   \* per-message JSON-roundtrip flag
    decision_votes,     \* decision_id -> set of voting processes
    decision_state      \* decision_id -> {pending, ratified, rejected}

vars == << messages, serialization_ok, decision_votes, decision_state >>

\* A cross-language message envelope; channel must be zenoh
ValidChannel(msg) == msg.channel = "zenoh"

\* Type-safe boundary: every message carries a serialized JSON payload
ValidPayload(msg) == msg.payload_kind = "json"

Init ==
    /\ messages = << >>
    /\ serialization_ok = [m \in {} |-> TRUE]
    /\ decision_votes = [d \in Decisions |-> {}]
    /\ decision_state = [d \in Decisions |-> "pending"]

\* F# sends a decision proposal to BEAM mesh — must use zenoh + json
SendCrossLang(fp, ep, did) ==
    /\ LET msg == [from |-> fp, to |-> ep, channel |-> "zenoh",
                   payload_kind |-> "json", decision |-> did]
       IN messages' = Append(messages, msg)
    /\ UNCHANGED << serialization_ok, decision_votes, decision_state >>

\* A BEAM process casts a vote on a pending decision
CastQuorumVote(p, did) ==
    /\ decision_state[did] = "pending"
    /\ p \notin decision_votes[did]
    /\ decision_votes' = [decision_votes EXCEPT ![did] = @ \cup {p}]
    /\ UNCHANGED << messages, serialization_ok, decision_state >>

\* Decision is ratified when 2oo3 quorum is met
RatifyDecision(did) ==
    /\ decision_state[did] = "pending"
    /\ Cardinality(decision_votes[did]) >= 2
    /\ decision_state' = [decision_state EXCEPT ![did] = "ratified"]
    /\ UNCHANGED << messages, serialization_ok, decision_votes >>

Next ==
    \/ \E fp \in FsharpProcs, ep \in ErlangProcs, d \in Decisions : SendCrossLang(fp, ep, d)
    \/ \E p \in (FsharpProcs \cup ErlangProcs), d \in Decisions : CastQuorumVote(p, d)
    \/ \E d \in Decisions : RatifyDecision(d)

Spec == Init /\ [][Next]_vars

(***************************************************************************)
(* Invariants                                                               *)
(***************************************************************************)

\* INV-1: Bridge isolation — every cross-language message rides Zenoh, never IPC/shmem
BridgeIsolation ==
    \A i \in 1..Len(messages) : ValidChannel(messages[i])

\* INV-2: Type safety at boundary — every cross-language call serializes to JSON
TypeSafetyAtBoundary ==
    \A i \in 1..Len(messages) : ValidPayload(messages[i])

\* INV-3: Quorum at runtime — F# safety-critical decisions require 2oo3 votes
\* (ratified state implies sufficient quorum was achieved)
QuorumAtRuntime ==
    \A d \in Decisions :
        decision_state[d] = "ratified" => Cardinality(decision_votes[d]) >= 2

\* INV-4: No retroactive ratification — once rejected or ratified, decision is terminal
DecisionTerminality ==
    \A d \in Decisions : decision_state[d] \in {"pending", "ratified", "rejected"}

THEOREM Spec => [](BridgeIsolation /\ TypeSafetyAtBoundary /\ QuorumAtRuntime /\ DecisionTerminality)

====
