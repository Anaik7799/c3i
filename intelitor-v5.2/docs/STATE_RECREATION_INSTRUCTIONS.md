# System State Recreation Instructions

**Date:** March 24, 2026
**Objective:** Instructions to fully recreate the SIL-6 Homeostasis and Gemini session state after a restart.

## 1. Environment Bootstrapping
Before interacting, Gemini MUST read the following to restore contextual awareness:
- `AGENT_BOOTSTRAP.md`
- `GEMINI.md`
- `docs/STATE_RECREATION_INSTRUCTIONS.md` (this file)

## 2. Infrastructure Startup
To recreate the SIL-6 Biomorphic Fractal Mesh:
```bash
devenv shell
# Start the full 15-container Panopticon mesh
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh up
```

## 3. Autonomous Evolution Engine (AEE) State
Restore the autonomous execution loop by running:
```bash
# Triggers the 5-phase protocol (Discovery -> Claim -> Fix -> Complete -> Merge)
elixir scripts/automation/sil6_autonomous_evolution.exs --resume
```

## 4. Mathematical & Formal Verification State
Run the following to assert mathematical homeostasis (8x8 Fractal Matrix, Warshall's Algorithm, KL Divergence limits):
```bash
# Re-verify all PROMETHEUS proofs
quint verify --invariant=masterInvariant docs/formal_specs/quint_specifications.qnt
agda --safe docs/formal_specs/agda_proofs.agda
mix test test/indrajaal/compliance/sil_compliance_test.exs
```

## 5. Session State
- **Mesh State:** 80% CPU saturation mode active (Continuous Control Law)
- **Active Tasks:** 100+ morphogenic evolution tasks tracked in `Planning.db` via `sa-plan`.
- **Commit Threshold:** Git push executes automatically every 10 commits.