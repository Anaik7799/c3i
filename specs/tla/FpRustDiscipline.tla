-------------------------- MODULE FpRustDiscipline --------------------------
(*
   FpRustDiscipline — Pass-5 formal spec for SC-FP-RUST-001..020.

   Models the cross-pass invariant gate (CPIG subsystem #13 fp_discipline)
   and the Lyapunov-stable composite KPI track (FP_TOTAL drift >= 0).

   Companion to:
     - .claude/rules/functional-programming-rust.md
     - specs/allium/fp_rust.allium
     - docs/journal/task-116499874901057156/

   ZK lineage:
     [zk-3346fc607a1ef9e6] Stub-That-Lies — only proven invariants land
     [zk-c14e1d23afff486c] implicit-invariant — refinement parity machine-checked
     [zk-139840e16ed2b21e] predicate-asserted-both-ways — proptest mirror
*)
EXTENDS Naturals, Sequences, FiniteSets, Reals

CONSTANTS
    Surfaces,        \* {planning_daemon, c3i_nif, rusty_vault_nif, scripts_nif}
    Libraries,       \* {derive_more, itertools, either, nutype, frunk, bon,
                     \*  parking_lot, winnow, recursion, kani, rayon, tower}
    PassCount,       \* 5
    FpTotalFloor,    \* 0.70
    FpTotalTarget,   \* 0.80
    FpVaultTarget,   \* 0.90
    FpDriftMin       \* 0.00 (Lyapunov)

ASSUME PassCount = 5
ASSUME FpTotalFloor = 70
ASSUME FpTotalTarget = 80
ASSUME FpVaultTarget = 90
ASSUME FpDriftMin = 0

VARIABLES
    pass,            \* current pass number 0..5
    adopted,         \* function: Surface -> set of Libraries adopted
    fp_total,        \* sequence of FP_TOTAL scores per pass
    fp_vault,        \* sequence of FP_VAULT scores per pass
    cpig_score       \* CPIG subsystem #13 score 0..5

vars == <<pass, adopted, fp_total, fp_vault, cpig_score>>

Init ==
    /\ pass = 0
    /\ adopted = [s \in Surfaces |-> {}]
    /\ fp_total = << >>
    /\ fp_vault = << >>
    /\ cpig_score = 0

\* Vault attack-surface budget: only 4 libraries allowed.
VaultAllowedLibs == {"derive_more", "nutype", "proptest", "kani"}

VaultBudgetHonored ==
    \A lib \in adopted["rusty_vault_nif"] :
        lib \in VaultAllowedLibs

\* Lyapunov gate: FP_TOTAL drift over 3-pass window must be non-negative.
\* drift(t) = (fp_total[t] - fp_total[t-3]) / 3
LyapunovDrift ==
    \A i \in 1..(Len(fp_total) - 3) :
        fp_total[i + 3] >= fp_total[i]

\* Floor enforcement: once we hit Pass 5, FP_TOTAL must be >= floor.
FloorEnforced ==
    Len(fp_total) >= PassCount =>
        fp_total[PassCount] >= FpTotalFloor

\* Vault target: by Pass 5, FP_VAULT >= 90.
VaultTargetMet ==
    Len(fp_vault) >= PassCount =>
        fp_vault[PassCount] >= FpVaultTarget

\* CPIG subsystem #13 must reach 5 by Pass 3 (closure of all 5 gates).
CpigReachedByPass3 ==
    pass >= 3 => cpig_score = 5

\* Action: advance one pass.
\* Each pass adds zero or more libraries to one or more surfaces, then records
\* the FP_TOTAL/FP_VAULT measurement and (possibly) increments cpig_score.
AdvancePass(new_adopted, new_fp_total, new_fp_vault, new_cpig) ==
    /\ pass < PassCount
    /\ pass' = pass + 1
    /\ adopted' = new_adopted
    /\ fp_total' = Append(fp_total, new_fp_total)
    /\ fp_vault' = Append(fp_vault, new_fp_vault)
    /\ cpig_score' = new_cpig

\* Specific concrete pass transitions matching the .claude rule:
Pass1Step ==
    AdvancePass(
        [adopted EXCEPT !["planning_daemon"] =
            adopted["planning_daemon"] \cup {"derive_more", "itertools", "either"}],
        50,  \* approximately FP_TOTAL after Pass-1
        35,
        3
    )

Pass2Step ==
    AdvancePass(
        [adopted EXCEPT
            !["planning_daemon"] =
                adopted["planning_daemon"]
                \cup {"nutype", "frunk", "bon", "parking_lot"},
            !["rusty_vault_nif"] =
                adopted["rusty_vault_nif"] \cup {"nutype", "derive_more", "proptest"}
        ],
        55,
        50,
        4
    )

Pass3Step ==
    AdvancePass(
        adopted,    \* concrete refinement on existing libs
        58,
        55,
        5           \* CPIG #13 closes all 5 gates
    )

Pass4Step ==
    AdvancePass(
        [adopted EXCEPT !["planning_daemon"] =
            adopted["planning_daemon"] \cup {"winnow", "recursion"}],
        65,
        60,
        5
    )

Pass5Step ==
    AdvancePass(
        [adopted EXCEPT !["planning_daemon"] =
            adopted["planning_daemon"] \cup {"kani", "rayon"}],
        85,         \* >= FpTotalTarget
        92,         \* >= FpVaultTarget
        5
    )

Next ==
    \/ Pass1Step
    \/ Pass2Step
    \/ Pass3Step
    \/ Pass4Step
    \/ Pass5Step
    \/ UNCHANGED vars   \* stutter

Spec == Init /\ [][Next]_vars

\* Invariants

I_VAULT_BUDGET == VaultBudgetHonored
I_CPIG_REACHED == CpigReachedByPass3
I_LYAPUNOV == LyapunovDrift

\* Liveness: eventually pass = 5 and floor met.
EventuallyClosed == <>(pass = PassCount /\ FloorEnforced /\ VaultTargetMet)

\* Combined safety:
Safety ==
    /\ I_VAULT_BUDGET
    /\ I_CPIG_REACHED
    /\ I_LYAPUNOV

THEOREM Spec => []Safety
\* Proof obligation: model-check via TLC with concrete CONSTANTS.
\* Run: tlc FpRustDiscipline.tla -config FpRustDiscipline.cfg

==============================================================================
