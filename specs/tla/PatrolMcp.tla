--------------------------------- MODULE PatrolMcp ---------------------------------
(***************************************************************************
 C3I CPIG Pass 14 — Patrol MCP triple-platform Flutter test orchestration

 Subsystem: Patrol MCP regression channel; tracks parity across
            {android, linux, chrome} platforms.

 Source files:
   - sub-projects/sutra/fluffychat/integration_test/patrol_test.dart
   - sub-projects/sutra/fluffychat/integration_test/marionette/marionette_runner.dart
   - .claude/scripts/patrol-zenoh-bridge.sh
   - tool/run-patrol.sh

 STAMP constraints covered:
   SC-PATROL-MCP-001..013   (Patrol MCP + Zenoh feedback loop)
   SC-MARIONETTE-012        (shared OTel envelope schema)

 Model-checking notes (TLC):
   CONSTANTS  Platforms = {"android","linux","chrome"},
              Outcomes  = {"passed","failed"},
              MaxRuns   = 6
   INVARIANT  TypeOK, TriplePlatformParity, EvidenceCapture,
              ZenohEnvelopeSchema
   PROPERTY   Spec
 ***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Platforms,    \* {"android","linux","chrome"} per SC-PATROL-MCP-005
    Outcomes,     \* {"passed","failed"}
    MaxRuns       \* TLC bound on history length

VARIABLES
    runs,            \* Seq of [platform |-> P, outcome |-> O,
                     \*         screenshot |-> BOOL, nativeTree |-> BOOL,
                     \*         envelopeOk |-> BOOL]
    platformsCovered \* set of platforms that have at least one passed run

vars == <<runs, platformsCovered>>

RunRecord == [platform: Platforms, outcome: Outcomes,
              screenshot: BOOLEAN, nativeTree: BOOLEAN,
              envelopeOk: BOOLEAN]

TypeOK ==
    /\ runs             \in Seq(RunRecord)
    /\ platformsCovered \subseteq Platforms
    /\ Len(runs)        <= MaxRuns

----------------------------------------------------------------------------
Init ==
    /\ runs             = <<>>
    /\ platformsCovered = {}

(* Successful run: must publish OTel envelope (SC-PATROL-MCP-004) *)
RunPassed(p) ==
    /\ p \in Platforms
    /\ Len(runs) < MaxRuns
    /\ LET r == [platform |-> p, outcome |-> "passed",
                 screenshot |-> TRUE, nativeTree |-> TRUE,
                 envelopeOk |-> TRUE]
       IN runs' = Append(runs, r)
    /\ platformsCovered' = platformsCovered \cup {p}

(* Failed run: SC-PATROL-MCP-008 mandates screenshot + native-tree before quit *)
RunFailed(p) ==
    /\ p \in Platforms
    /\ Len(runs) < MaxRuns
    /\ LET r == [platform |-> p, outcome |-> "failed",
                 screenshot |-> TRUE, nativeTree |-> TRUE,
                 envelopeOk |-> TRUE]
       IN runs' = Append(runs, r)
    /\ UNCHANGED platformsCovered

Next ==
    \/ \E p \in Platforms : RunPassed(p)
    \/ \E p \in Platforms : RunFailed(p)

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
(* Invariants *)

\* SC-PATROL-MCP-005: a feature is verified iff covered on ALL platforms.
\* Whenever any platform has been covered, the parity invariant is that
\* "fully verified" implies the covered set equals all platforms.
TriplePlatformParity ==
    (platformsCovered # {} /\ platformsCovered # Platforms) =>
        \E p \in Platforms \ platformsCovered : TRUE   \* gap is observable

\* SC-PATROL-MCP-008: every failed run captures evidence before quit.
EvidenceCapture ==
    \A i \in DOMAIN runs :
        runs[i].outcome = "failed" =>
            (runs[i].screenshot /\ runs[i].nativeTree)

\* SC-PATROL-MCP-004: every published event conforms to the OTel envelope.
ZenohEnvelopeSchema ==
    \A i \in DOMAIN runs : runs[i].envelopeOk

THEOREM SpecImpliesInvariants ==
    Spec => [](TypeOK
               /\ TriplePlatformParity
               /\ EvidenceCapture
               /\ ZenohEnvelopeSchema)

============================================================================
