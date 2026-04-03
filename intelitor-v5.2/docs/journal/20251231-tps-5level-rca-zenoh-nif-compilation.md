# TPS 5-Level RCA: Zenoh NIF Compilation Failure

**Date**: 2025-12-31T14:00:00+01:00
**Category**: P0 Blocker - Compilation Failure
**Status**: RESOLVED
**Root Cause**: Missing SC-NIF version synchronization constraint

---

## Problem Statement

Zenoh NIF fails to compile with Rust type mismatch error:

```
error[E0308]: mismatched types
  --> rustler-0.30.0/src/term.rs:127:67
      expected `usize`, found `&usize`
```

---

## 5-Level Why Analysis

### Level 1: WHAT is the symptom?
- Rustler 0.30.0 API incompatible with current Erlang NIF interface
- Compilation blocked for entire project

### Level 2: WHY API mismatch?
```
# Cargo.toml (Rust) - BEFORE
rustler = "0.30"

# mix.exs (Elixir)
{:rustler, "~> 0.30"}  # Resolves to 0.37.1 in mix.lock!
```

### Level 3: WHY version drift?
- Elixir `~> 0.30` permits any 0.x version
- Hex resolved to 0.37.1 (latest compatible)
- Rust Cargo.toml was NOT updated
- No CI enforcement of version coupling

### Level 4: WHY no enforcement?
- NIF added after core STAMP framework
- Cross-language deps not in original spec
- No automated sync between mix.exs ↔ Cargo.toml

### Level 5: ROOT CAUSE
**Missing STAMP constraint for Rust/Elixir NIF version synchronization**

---

## Corrective Actions

### Immediate Fix (Applied)

```toml
# native/zenoh_nif/Cargo.toml
rustler = "0.37"  # Updated to match mix.lock
```

```elixir
# mix.exs - Made explicit
{:rustler, "~> 0.37"}  # Was "~> 0.30"
```

### Permanent Fix - New STAMP Constraints

Added to CLAUDE.md Section 5.0:

```markdown
*   **SC-NIF (Native Interface Functions)**:
    - SC-NIF-001: NIF functions MUST NOT block BEAM scheduler
    - SC-NIF-002: Resource cleanup on process exit
    - SC-NIF-003: Error propagation to Elixir
    - SC-NIF-004: Rustler Rust crate version MUST match Elixir hex version
    - SC-NIF-005: CI MUST verify Cargo.toml rustler = mix.exs rustler
    - SC-NIF-006: Version bump requires synchronized update
    - SC-NIF-007: NIF compilation failure = P0 blocker
```

### Prevention Script

Created `scripts/validation/check_rustler_versions.exs`:
- Extracts rustler version from mix.exs
- Extracts rustler version from all Cargo.toml files
- Validates major.minor match
- Exits with code 1 on mismatch

### CI Integration

Add to `.github/workflows/ci.yml`:
```yaml
- name: SC-NIF-005 Rustler Version Check
  run: elixir scripts/validation/check_rustler_versions.exs
```

---

## Verification

```bash
$ elixir scripts/validation/check_rustler_versions.exs
============================================================
SC-NIF-004/005: Rustler Version Synchronization Check
============================================================

[Elixir] mix.exs rustler version: 0.37
[Rust] native/zenoh_nif/Cargo.toml: 0.37

------------------------------------------------------------
✅ SC-NIF-004 PASS: All Rustler versions are synchronized
```

---

## Files Modified

| File | Change |
|------|--------|
| `mix.exs` | `{:rustler, "~> 0.37"}` + SC-NIF-004 comment |
| `native/zenoh_nif/Cargo.toml` | `rustler = "0.37"` |
| `CLAUDE.md` | Added SC-NIF-001 to SC-NIF-007 |
| `scripts/validation/check_rustler_versions.exs` | NEW - Version sync check |

---

## Lessons Learned

1. **Cross-language dependencies need explicit coupling constraints**
2. **Semantic versioning ~> can cause unexpected upgrades**
3. **CI must validate all polyglot version dependencies**
4. **TPS Jidoka: Stop immediately on compile failure, fix root cause**

---

## STAMP Compliance

- SC-NIF-004: ✅ Versions now match (0.37)
- SC-NIF-005: ✅ Script created for CI validation
- SC-NIF-007: ✅ P0 blocker resolved

**OODA Cycle Time**: 15 minutes (Observe → Orient → Decide → Act)

---

## Follow-Up: Complete API Migration

After version synchronization, additional API errors emerged requiring full migration.
See: [20251231-zenoh-nif-rustler037-zenoh10-migration.md](20251231-zenoh-nif-rustler037-zenoh10-migration.md)

**Total Resolution Time**: 60 minutes (Version Sync + API Migration)
