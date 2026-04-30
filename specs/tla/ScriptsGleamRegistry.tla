---------------------------- MODULE ScriptsGleamRegistry ----------------------------
(***************************************************************************
 C3I CPIG Pass 14 — scripts-gleam userspace registry & isolation

 Subsystem: Gleam-only scripting subproject (SC-SCRIPT-GLEAM-001).

 Source files:
   - sub-projects/scripts-gleam/gleam.toml
   - sub-projects/scripts-gleam/src/scripts/
   - sub-projects/scripts-gleam/src/scripts/common/{artifact,journal,
       html_doc,html_deck,diagrams,delivery,zenoh,paths,fsx,logx}.gleam
   - sub-projects/scripts-gleam/src/scripts/verify/feature_evolution.gleam
   - sub-projects/scripts-gleam/src/scripts/tools/list.gleam (registry)

 STAMP constraints covered:
   SC-SCRIPT-GLEAM-001        (Gleam-only scripting mandate; isolation)
   SC-FEAT-EVO-LIB-001..008  (reusable common library tier)

 Model-checking notes (TLC):
   CONSTANTS  Scripts          = {"probe/public_interface","verify/feature_evolution",
                                  "registry/saplan_smoke","build/auto","ingest/zk"}
              ForbiddenImports = {"lib/cepaf_gleam","sub-projects/pi-mono",
                                  "sub-projects/ferriskey","sub-projects/openclaw"}
              OutputRoot       = "data/script-output/"
   INVARIANT  TypeOK, ManifestParity, IsolationInvariant, OutputDirInvariant
   PROPERTY   Spec
 ***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Scripts,            \* set of all runnable script module paths
    ForbiddenImports,   \* sub-projects scripts MUST NOT import from
    OutputRoot          \* canonical output prefix, e.g. "data/script-output/"

VARIABLES
    scripts,        \* registered runnable scripts (subset of Scripts)
    manifest,       \* function: scripts -> path
    runHistory,     \* sequence of run records [script |-> ..., outputPath |-> ...]
    imports         \* function: scripts -> set of imported modules

vars == <<scripts, manifest, runHistory, imports>>

\* String prefix relation kept abstract for TLC: pre-condition over OutputRoot.
StartsWith(s, prefix) == s = prefix \o "rest"   \* abstract; TLC overrides

TypeOK ==
    /\ scripts    \subseteq Scripts
    /\ manifest   \in [scripts -> Scripts]
    /\ runHistory \in Seq([script: scripts, outputPath: STRING])
    /\ imports    \in [scripts -> SUBSET (Scripts \cup ForbiddenImports)]

----------------------------------------------------------------------------
(* Initial state: empty registry, no runs, no imports *)
Init ==
    /\ scripts    = {}
    /\ manifest   = [s \in {} |-> s]
    /\ runHistory = <<>>
    /\ imports    = [s \in {} |-> {}]

(* Register a new runnable script.  By SC-SCRIPT-GLEAM-001 every entry
   in `scripts` must have a manifest row pointing back to itself. *)
RegisterScript(s) ==
    /\ s \in Scripts
    /\ s \notin scripts
    /\ scripts'  = scripts \cup {s}
    /\ manifest' = [t \in scripts' |->
                       IF t = s THEN s ELSE manifest[t]]
    /\ imports'  = [t \in scripts' |->
                       IF t = s THEN {} ELSE imports[t]]
    /\ UNCHANGED runHistory

(* Add an allowed import.  Forbidden imports are blocked at this transition. *)
AddImport(s, m) ==
    /\ s \in scripts
    /\ m \notin ForbiddenImports     \* hard isolation per SC-SCRIPT-GLEAM-001
    /\ imports' = [imports EXCEPT ![s] = imports[s] \cup {m}]
    /\ UNCHANGED <<scripts, manifest, runHistory>>

(* Execute a script — it MUST land outputs under data/script-output/ *)
RunScript(s, outPath) ==
    /\ s \in scripts
    /\ StartsWith(outPath, OutputRoot)
    /\ runHistory' = Append(runHistory, [script |-> s, outputPath |-> outPath])
    /\ UNCHANGED <<scripts, manifest, imports>>

Next ==
    \/ \E s \in Scripts: RegisterScript(s)
    \/ \E s \in scripts, m \in Scripts: AddImport(s, m)
    \/ \E s \in scripts, p \in {OutputRoot \o "x"}: RunScript(s, p)

Spec == Init /\ [][Next]_vars

----------------------------------------------------------------------------
(* Invariants *)

\* SC-SCRIPT-GLEAM-001: every registered script is reachable through manifest.
ManifestParity ==
    \A s \in scripts : manifest[s] = s

\* SC-SCRIPT-GLEAM-001: hard isolation — no script imports a forbidden module.
IsolationInvariant ==
    \A s \in scripts : imports[s] \cap ForbiddenImports = {}

\* SC-FEAT-EVO-LIB-003: artefacts only land under canonical output root.
OutputDirInvariant ==
    \A i \in DOMAIN runHistory :
        StartsWith(runHistory[i].outputPath, OutputRoot)

THEOREM SpecImpliesInvariants ==
    Spec => [](TypeOK
               /\ ManifestParity
               /\ IsolationInvariant
               /\ OutputDirInvariant)

============================================================================
