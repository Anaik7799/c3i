---- MODULE FractalWidgets ----
(***************************************************************************)
(* Fractal Widgets L0-L7                                                    *)
(*                                                                          *)
(* Models the structural invariants of the C3I fractal widget architecture, *)
(* ensuring that every layer has at least one widget, L0 widgets are        *)
(* Guardian-gated (HITL mandatory), and the widget tree exhibits fractal    *)
(* self-similarity (every widget either contains a sub-fractal or grounds   *)
(* at L0).                                                                  *)
(*                                                                          *)
(* Source modules:                                                          *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l0_constitutional.gleam      *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l1_atomic_debug.gleam        *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l2_component.gleam           *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l3_transaction.gleam         *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l4_system.gleam              *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l5_cognitive.gleam           *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l6_ecosystem.gleam           *)
(*   - lib/cepaf_gleam/src/cepaf_gleam/fractal/l7_federation.gleam          *)
(*                                                                          *)
(* STAMP: SC-FRACTAL-001..008, SC-SAFETY-001, SC-SIL4-006 (2oo3 for L0)     *)
(***************************************************************************)

EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
    Widgets,            \* set of widget identifiers
    Layers              \* {L0, L1, L2, L3, L4, L5, L6, L7}

VARIABLES
    layer_of,           \* widget -> layer
    children,           \* widget -> set of child widgets (sub-fractal)
    hitl_approved,      \* set of L0 widgets with active Guardian approval
    quorum_votes        \* L0 widget -> number of 2oo3 votes received

vars == << layer_of, children, hitl_approved, quorum_votes >>

\* Layer ordering for fractal self-similarity check
LayerIndex(l) ==
    CASE l = "L0" -> 0
      [] l = "L1" -> 1
      [] l = "L2" -> 2
      [] l = "L3" -> 3
      [] l = "L4" -> 4
      [] l = "L5" -> 5
      [] l = "L6" -> 6
      [] l = "L7" -> 7

Init ==
    /\ layer_of \in [Widgets -> Layers]
    /\ children \in [Widgets -> SUBSET Widgets]
    /\ hitl_approved = {}
    /\ quorum_votes = [w \in Widgets |-> 0]

\* Action: Guardian approves an L0 widget after 2oo3 quorum
GuardianApprove(w) ==
    /\ layer_of[w] = "L0"
    /\ quorum_votes[w] >= 2
    /\ hitl_approved' = hitl_approved \cup {w}
    /\ UNCHANGED << layer_of, children, quorum_votes >>

CastVote(w) ==
    /\ layer_of[w] = "L0"
    /\ quorum_votes[w] < 3
    /\ quorum_votes' = [quorum_votes EXCEPT ![w] = @ + 1]
    /\ UNCHANGED << layer_of, children, hitl_approved >>

Next ==
    \/ \E w \in Widgets : CastVote(w)
    \/ \E w \in Widgets : GuardianApprove(w)

Spec == Init /\ [][Next]_vars

(***************************************************************************)
(* Invariants                                                               *)
(***************************************************************************)

\* INV-1: Layer-widget parity — every L0..L7 layer is populated by at least one widget
LayerWidgetParity ==
    \A l \in Layers : \E w \in Widgets : layer_of[w] = l

\* INV-2: HITL gate for L0 — every L0 widget that is "active" (has children fired)
\* must be in hitl_approved set
HITLGateForL0 ==
    \A w \in Widgets :
        (layer_of[w] = "L0" /\ children[w] # {}) => w \in hitl_approved

\* INV-3: Fractal self-similarity — for every widget at layer Lk (k > 0),
\* either it has children OR it grounds (terminates) at L0 via a chain
\* (encoded as: widget either has children, or its layer is L0)
FractalSelfSimilarity ==
    \A w \in Widgets :
        \/ children[w] # {}
        \/ layer_of[w] = "L0"

\* INV-4: 2oo3 prerequisite — Guardian approval implies sufficient quorum
QuorumPrerequisite ==
    \A w \in hitl_approved : quorum_votes[w] >= 2

THEOREM Spec => [](LayerWidgetParity /\ HITLGateForL0 /\ FractalSelfSimilarity /\ QuorumPrerequisite)

====
