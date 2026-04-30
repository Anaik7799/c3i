-------------------------------- MODULE GleamUiMVU --------------------------------
(***************************************************************************
 C3I CPIG Pass 14 — Lustre/Gleam MVU + Wiring Guard + Triple-Interface

 Subsystem: Gleam UI Model-View-Update closure (Lustre SSR + Wisp REST + TUI)
            with the Wiring Guard test that pins constructor parity at 111
            verified connections.

 Source files:
   - lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/      (24 pages)
   - lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/        (15 endpoints)
   - lib/cepaf_gleam/src/cepaf_gleam/ui/tui/         (23 views)
   - lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam (shared types)
   - lib/cepaf_gleam/src/cepaf_gleam/testing/wiring_guard.gleam
   - lib/cepaf_gleam/test/wiring_guard_test.gleam
   - lib/cepaf_gleam/src/cepaf_gleam/agui/events.gleam (32 AG-UI events)

 STAMP constraints covered:
   SC-GLM-UI-001..010      (triple-interface mandate)
   SC-WIRE-001..007        (wiring guard, init() in tests, Model+Msg closure)
   SC-AGUI-UI-001..015     (agentic UI responsive design)

 Model-checking notes (TLC):
   CONSTANTS  ExpectedConnections = 111,
              Pages               = {"dashboard","planning","cockpit","verification",
                                      "agents","zenoh","knowledge"},
              Interfaces          = {"lustre","wisp","tui"},
              Msgs                = {"RunStarted","TextMessageContent","ToolCallEnd",
                                      "StateSnapshot","Heartbeat"}
   INVARIANT  TypeOK, WiringGuardConsistency, ModelMsgUpdateClosure,
              PageInitTotality, TripleInterfaceParity
   PROPERTY   Spec
 ***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    ExpectedConnections,  \* 111 verified connections (SC-WIRE)
    Pages,                \* set of Lustre page names
    Interfaces,           \* {"lustre","wisp","tui"}
    Msgs                  \* set of AG-UI message variants

VARIABLES
    modelFields,        \* set of Model fields currently declared
    msgVariants,        \* set of message variants currently declared
    updateArms,         \* set of variants the update() function handles
    pages,              \* set of pages with valid init() functions
    connections,        \* Nat: count verified by wiring_guard
    featureSurface      \* function: feature -> subset of Interfaces

vars == <<modelFields, msgVariants, updateArms, pages, connections,
          featureSurface>>

Features == DOMAIN featureSurface

TypeOK ==
    /\ modelFields    \subseteq STRING
    /\ msgVariants    \subseteq Msgs
    /\ updateArms     \subseteq Msgs
    /\ pages          \subseteq Pages
    /\ connections    \in Nat
    /\ featureSurface \in [Features -> SUBSET Interfaces]

----------------------------------------------------------------------------
Init ==
    /\ modelFields    = {}
    /\ msgVariants    = Msgs
    /\ updateArms     = Msgs           \* SC-WIRE-003 — Msg + update co-evolve
    /\ pages          = Pages          \* SC-WIRE-005 — every page has init()
    /\ connections    = ExpectedConnections
    /\ featureSurface = [f \in {"plan","health","trace"} |-> Interfaces]

(* Add a new Model field — SC-WIRE-002 requires wiring_guard to compile;
   modelled here as preserving the connections count. *)
AddModelField(f) ==
    /\ f \notin modelFields
    /\ modelFields' = modelFields \cup {f}
    /\ connections' = ExpectedConnections   \* guard updated in same commit
    /\ UNCHANGED <<msgVariants, updateArms, pages, featureSurface>>

(* Add a new Msg variant — must update update() arms in the same step *)
AddMsgVariant(m) ==
    /\ m \in Msgs
    /\ m \notin msgVariants
    /\ msgVariants' = msgVariants \cup {m}
    /\ updateArms'  = updateArms  \cup {m}    \* SC-WIRE-003
    /\ UNCHANGED <<modelFields, pages, connections, featureSurface>>

(* Register a new page; init() must be wired into wiring_guard *)
RegisterPage(p) ==
    /\ p \in Pages
    /\ p \notin pages
    /\ pages'       = pages \cup {p}
    /\ connections' = ExpectedConnections
    /\ UNCHANGED <<modelFields, msgVariants, updateArms, featureSurface>>

(* Register an actionable feature — SC-GLM-UI-001 mandates all three
   interfaces (Lustre + Wisp + TUI). *)
RegisterFeature(f) ==
    /\ f \notin DOMAIN featureSurface
    /\ featureSurface' = [g \in DOMAIN featureSurface \cup {f} |->
                              IF g = f THEN Interfaces ELSE featureSurface[g]]
    /\ UNCHANGED <<modelFields, msgVariants, updateArms, pages, connections>>

Next ==
    \/ \E f \in {"new_field_a","new_field_b"} : AddModelField(f)
    \/ \E m \in Msgs : AddMsgVariant(m)
    \/ \E p \in Pages : RegisterPage(p)
    \/ \E f \in {"new_feature_x"} : RegisterFeature(f)

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
(* Invariants *)

\* SC-WIRE-001: wiring_guard verifies a fixed number of connections.
WiringGuardConsistency == connections = ExpectedConnections

\* SC-WIRE-003: every Msg variant has a corresponding update() arm.
ModelMsgUpdateClosure ==
    \A m \in msgVariants : m \in updateArms

\* SC-WIRE-005: every registered page has a working init() (totality).
PageInitTotality == Pages \subseteq pages

\* SC-GLM-UI-001: every actionable feature is reachable through all three
\* interfaces — Lustre SSR, Wisp REST, and TUI ANSI.
TripleInterfaceParity ==
    \A f \in DOMAIN featureSurface : featureSurface[f] = Interfaces

THEOREM SpecImpliesInvariants ==
    Spec => [](TypeOK
               /\ WiringGuardConsistency
               /\ ModelMsgUpdateClosure
               /\ PageInitTotality
               /\ TripleInterfaceParity)

============================================================================
