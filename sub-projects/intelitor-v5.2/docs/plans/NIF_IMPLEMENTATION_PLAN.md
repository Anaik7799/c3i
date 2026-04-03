# NIF Implementation Plan: Biomorphic Convergence

**Version**: 1.0.0
**Date**: 2026-01-06
**Status**: ACTIVE
**Target**: SIL-6 Compliance

## Phase 1: Substrate Preparation (The Soil)
- [x] **Toolchain Injection**: `devenv.nix` updated with `rustc`, `cargo`, `libclang`.
- [x] **Container Parity**: `podman-compose` configured to mount `/nix` store.
- [ ] **Dependency Verification**: Ensure `mix.lock` and `Cargo.lock` are synchronized.

## Phase 2: Cellular Alignment (The Code)
- [ ] **LineageAuth NIF**: Verify `native/lineage_auth` compiles cleanly on `musl`.
- [ ] **Zenoh NIF**: Verify `native/zenoh_nif` compiles cleanly.
- [ ] **Wrapper Hardening**: Update Elixir wrappers to implement the **SC-NIF-L3** graceful fallback.

## Phase 3: Metabolic Ignition (The Startup)
- [ ] **Boot Script**: Enhance `sa-up.fsx` to perform explicit NIF pre-checks.
- [ ] **Verbose Compilation**: Enable `RUST_BACKTRACE=1` and `FRACTAL_LOGGING=verbose`.
- [ ] **Telemetry Hook**: Ensure `Indrajaal.Native.Zenoh` connects to the mesh immediately upon load.

## Phase 4: 5-Layer Verification (The Exam)
- [ ] **L1 Unit**: Run `test/fractal/l1_nif_unit_test.exs`.
- [ ] **L2 Integration**: Run `test/fractal/l2_nif_integration_test.exs`.
- [ ] **L3 System**: Run `test/fractal/l3_nif_system_test.exs` inside container.
- [ ] **L4 Stress**: Execute `test/fractal/l4_nif_stress_test.exs`.
- [ ] **L5 Safety**: Execute `test/fractal/l5_nif_safety_test.exs` (Chaos).

## Phase 5: Ecosystem Integration (The Life)
- [ ] **Dashboard**: Verify NIF metrics appear in the "Biomorphic Dashboard".
- [ ] **Self-Healing**: Test restart resilience by killing the NIF process.

---

**Execution Strategy**:
We will proceed with **Phase 3** (Ignition) immediately, using the `sa-up` sequence to trigger the compilation and loading of the NIFs in the live environment.