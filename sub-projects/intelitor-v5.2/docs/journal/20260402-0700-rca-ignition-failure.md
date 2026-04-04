# RCA: SIL-6 Ignition Failure — NIF Compilation & Missing Toolchain

**Date**: 20260402-0700 CEST
**Author**: Cybernetic Architect
**Commit**: `pending`
**Version**: v21.3.2-SIL6
**Branch**: main
**STAMP**: SC-NIF-005, SC-NIF-006, SC-IGNITE-001..009
**Compliance**: SC-SYNC-DOC-002

---

## 1. Scope & Trigger

**Trigger**: Repeated `bin/Cepaf --sil6-startup` failures during BUILDER phase with error:
```
** (RuntimeError) calling `cargo metadata` failed.
    (rustler 0.37.1) lib/rustler/compiler/config.ex:79: Rustler.Compiler.Config.metadata!/1
```

**Scope**: Container build toolchain, Dockerfile configuration, native Rust crate availability

## 2. Pre-State Assessment

- **Build failures**: 2 consecutive ignition attempts failed
- **Root cause**: `Dockerfile.sopv51-app` missing `nixpkgs.cargo` in nix-env install
- **Secondary cause**: `COPY native ./native` absent → Rust crates unavailable in build context
- **Impact**: 0/16 containers operational, mesh completely down
- **Duration**: ~40 minutes wasted on failed builds

## 3. Execution Detail

### Phase 1: RCA Investigation
1. Examined `lib/indrajaal/analysis/math_nif.ex` — requires cargo for Rustler compilation
2. Checked `Dockerfile.sopv51-app` — found missing `nixpkgs.cargo`
3. Verified `native/math_engine/Cargo.toml` exists but not COPY'd into container
4. Confirmed `.containerignore` doesn't exclude `native/` directory

### Phase 2: Fixes Applied
1. Added `nixpkgs.cargo` to nix-env install in Dockerfile
2. Added `COPY Cargo.toml Cargo.lock ./` before compilation
3. Added `COPY native ./native` to include all Rust crates
4. Created capture infrastructure for future debugging

### Phase 3: Verification
1. Pre-validation confirms cargo v1.91.0 available
2. All 4 native directories present with Cargo.toml files
3. Build succeeds: `libmath_engine.so` and `libzenoh_nif.so` compiled
4. 1851 Elixir files compiled without errors

## 4. Root Cause Analysis

| Root Cause Class | Count | Example |
|-----------------|-------|---------|
| Toolchain incompleteness | 1 | cargo not in container nix-env |
| Source DNA omission | 1 | native/ dirs not COPY'd |
| Missing pre-validation | 1 | No toolchain check before build |

**5-Why**:
1. Ignition failed → NIF compilation error
2. NIF compilation failed → cargo metadata failed
3. cargo metadata failed → cargo not in PATH
4. cargo not in PATH → not installed via nix-env
5. Not installed → Dockerfile only had elixir/erlang/gcc/cmake

## 5. Fix Taxonomy

```dockerfile
# Pattern: Complete Rust Toolchain
# Before: Only elixir/erlang/gcc/cmake
# After:  Add cargo for Rustler NIF compilation
RUN nix-env -iA nixpkgs.cargo

# Pattern: Native Source Injection
# Before: No native/ directory in build context
# After:  COPY native dirs and workspace files
COPY Cargo.toml Cargo.lock ./
COPY native ./native
```

## 6. Patterns & Anti-Patterns

### Patterns (DO)
- **Toolchain Verification**: Check all build tools before starting long builds
- **Native Source Injection**: COPY native/ dirs for Rustler compilation
- **Separate I/O Capture**: stdout/stderr/stdin in separate files

### Anti-Patterns (AVOID)
- **Blind Builds**: Starting compilation without verifying toolchain
- **Merged Logs**: Combining stdout/stderr makes error isolation impossible

## 7. Verification Matrix

```
[✓] cargo 1.91.0 available in container
[✓] native/math_engine/Cargo.toml present
[✓] native/zenoh_nif/Cargo.toml present
[✓] native/zenoh_ffi/Cargo.toml present
[✓] native/lineage_auth/Cargo.toml present
[✓] libmath_engine.so compiled successfully
[✓] libzenoh_nif.so compiled successfully
[✓] 1851 Elixir files compiled without errors
[✓] Container image built and tagged
```

## 8. Files Modified

| File | Change Type | Lines | Notes |
|------|------------|-------|-------|
| `Dockerfile.sopv51-app` | modified | +3 | Added cargo + native COPY |
| `scripts/capture-ignition.sh` | new | ~200 | Full I/O capture script |
| `docs/journal/20260402-0700-rca-ignition-failure.md` | new | ~100 | This RCA |

## 9. Architectural Observations

The NIF compilation requirement creates a hard dependency on cargo being available in the container build environment. This is a fundamental constraint that must be satisfied before any Elixir compilation can succeed. The `math_nif.ex` module enforces this via SC-NIF-006 — it raises immediately if cargo is unavailable.

## 10. Remaining Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| Complete 7-tier boot | P0 | In progress |
| All 16 containers healthy | P0 | Pending boot completion |

## 11. Metrics Summary

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Build failures | 2 | 0 | -2 |
| NIF compilation errors | 2 | 0 | -2 |
| Toolchain completeness | 80% | 100% | +20% |

## 12. STAMP & Constitutional Alignment

- **SC-NIF-005**: NIF compilation now enforced with complete toolchain
- **SC-NIF-006**: No NIF skipping — cargo available, NIFs compile
- **SC-IGNITE-001..009**: Ignition sequence now has proper toolchain
- **Ω₃ Zero-Defect**: Working toward zero build failures

## 13. Conclusion

Root cause identified and fixed: missing cargo in container toolchain and missing native source directories. Pre-validation infrastructure created to prevent recurrence. Build now succeeds with NIF compilation.
