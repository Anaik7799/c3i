# SMRITI Rebranding Plan (10x10 Matrix)

**Objective**: Complete rebranding of "ZKMS" to "SMRITI" across the entire codebase to unify nomenclature and align with the "Recall" architectural vision.
**Constraints**: Zero downtime, backward compatibility where possible (deprecated aliases), atomic commits.

| ID | Dimension | Current State (ZKMS) | Target State (SMRITI) | Criticality | Verification |
|----|-----------|----------------------|-----------------------|-------------|--------------|
| 1 | **File Naming** | `zkms_integration.ex`, `zkms_*.fsx` | `smriti_integration.ex`, `smriti_*.fsx` | HIGH | `ls` check |
| 2 | **Elixir Modules** | `Indrajaal.KMS.ZkmsIntegration` | `Indrajaal.KMS.SmritiIntegration` | CRITICAL | `mix compile` |
| 3 | **F# Namespaces** | `Cepaf.Zkms.*` | `Cepaf.Smriti.*` | CRITICAL | `dotnet build` |
| 4 | **Database Config** | `:zkms_db_path` | `:smriti_db_path` | HIGH | `runtime.exs` |
| 5 | **CLI Commands** | `zkms-cli`, `mix zkms.ingest` | `smriti-cli`, `mix smriti.ingest` | MEDIUM | `mix help` |
| 6 | **Docker/Podman** | `Dockerfile.zkms-api` | `Dockerfile.smriti-api` | HIGH | `podman images` |
| 7 | **Documentation** | `docs/zkms/` | `docs/smriti/` | MEDIUM | Link checks |
| 8 | **Telemetry** | `[:zkms, :health]` | `[:smriti, :health]` | HIGH | SigNoz |
| 9 | **Test Suites** | `zkms_test.exs` | `smriti_test.exs` | CRITICAL | `mix test` |
| 10 | **Artifacts** | `zkms.db` | `smriti.db` | HIGH | File existence |

## Execution Phases

### Phase 1: Preparation (Safe)
- [ ] create `smriti` aliases for all `zkms` configs.
- [ ] Copy `docs/zkms` to `docs/smriti`.
- [ ] Create empty `Smriti` namespaces in F#.

### Phase 2: Elixir Migration (Atomic)
- [ ] Rename `zkms_integration.ex` -> `smriti_integration.ex`.
- [ ] Update `Indrajaal.KMS.SmritiIntegration` module (already partially named Smriti, verify full consistency).
- [ ] Update `lib/indrajaal/application.ex` supervision tree.

### Phase 3: F# Migration (Atomic)
- [ ] Rename `Cepaf.Zkms` solution/projects to `Cepaf.Smriti`.
- [ ] Update `sa-*.fsx` scripts to reference new DLLs.

### Phase 4: Container & Data (Hard)
- [ ] Rename `Dockerfile.zkms` -> `Dockerfile.smriti`.
- [ ] Migration script to move `data/kms/zkms.db` -> `data/kms/smriti.db`.

### Phase 5: Cleanup
- [ ] Remove `zkms` aliases.
- [ ] Delete `docs/zkms`.
- [ ] Grep codebase for residual "zkms" strings.
