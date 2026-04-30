----------------------------- MODULE PiEventBridge -----------------------------
(***************************************************************************)
(* Pi events <-> AG-UI events bridge bijection model.                       *)
(* References: bridge/pi_claude_code.gleam, SC-PI-AUTO-004.                 *)
(* ZK: [zk-bb4de67d97f807ac], [zk-d8929d43344a292d], [zk-c14e1d23afff486c]. *)
(*                                                                          *)
(* Pi-mono emits 29 event kinds; AG-UI defines 32. The bridge is total     *)
(* on Pi (every Pi event maps), partial on AG-UI (3 AG-UI events have no   *)
(* Pi counterpart: Heartbeat, ReasoningEncryptedValue, MetaEvent).         *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS PiEvents,         \* set of 29 Pi event identifiers
          AguiEvents        \* set of 32 AG-UI event identifiers

ASSUME Cardinality(PiEvents) = 29
ASSUME Cardinality(AguiEvents) = 32

VARIABLES bridgeMap,        \* PiEvents -> AguiEvents (total function)
          reverseBridgeMap  \* subset of AguiEvents -> PiEvents (partial)

vars == <<bridgeMap, reverseBridgeMap>>

TypeOK ==
  /\ bridgeMap \in [PiEvents -> AguiEvents]
  /\ DOMAIN reverseBridgeMap \subseteq AguiEvents
  /\ \A a \in DOMAIN reverseBridgeMap : reverseBridgeMap[a] \in PiEvents

Init ==
  /\ bridgeMap \in [PiEvents -> AguiEvents]
  /\ reverseBridgeMap = [a \in {bridgeMap[p] : p \in PiEvents} |->
                          CHOOSE p \in PiEvents : bridgeMap[p] = a]

(* The bridge is fixed at compile time — no Next action mutates it. *)
Next == UNCHANGED vars

Spec == Init /\ [][Next]_vars

(* ===== INVARIANTS ===== *)

(* Total on Pi side: every Pi event maps to some AG-UI event *)
PiToAguiPartial ==
  Cardinality(DOMAIN bridgeMap) = 29

(* Partial on AG-UI side: at most 32 AG-UI events have a Pi counterpart *)
AguiToPiPartial ==
  Cardinality(DOMAIN reverseBridgeMap) <= 32

(* Bridge is injective: round-trip Pi->AG-UI->Pi yields identity *)
BridgeRoundtripIdentity ==
  \A p \in PiEvents :
    /\ bridgeMap[p] \in DOMAIN reverseBridgeMap
    /\ reverseBridgeMap[bridgeMap[p]] = p

(* No two Pi events map to the same AG-UI event *)
NoCollisions ==
  \A p1, p2 \in PiEvents :
    p1 # p2 => bridgeMap[p1] # bridgeMap[p2]

(* Combined: bijection between PiEvents and image(bridgeMap) *)
BijectionOnImage ==
  Cardinality({bridgeMap[p] : p \in PiEvents}) = 29

=============================================================================
