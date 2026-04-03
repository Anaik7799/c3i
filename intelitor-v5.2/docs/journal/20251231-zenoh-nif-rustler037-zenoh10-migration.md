# TPS 5-Level RCA: Zenoh NIF Migration to Rustler 0.37 + Zenoh 1.7

**Date**: 2025-12-31T14:30:00+01:00
**Category**: P0 Blocker - NIF Compilation Failure
**Status**: RESOLVED
**Root Cause**: Code written for rustler 0.30 + zenoh 0.x, but dependencies are rustler 0.37 + zenoh 1.7

---

## Problem Statement

Zenoh NIF fails to compile with multiple API mismatch errors:

```
error[E0599]: no method named `set_mode` found for struct `Config`
error[E0609]: no field `connect` on type `Config`
error[E0599]: no method named `res` found for struct `OpenBuilder<TryIntoConfig>`
error: cannot find derive macro `Resource` in this scope
```

---

## 5-Level Why Analysis

### Level 1: WHAT are the symptoms?
- 12 Rust compilation errors in zenoh_nif
- `set_mode()`, `connect` field, `.res()` method not found (zenoh API)
- `#[derive(Resource)]` not found (rustler macro)
- `OwnedBinary`, `OwnedEnv` removed from rustler 0.37
- `zenoh_get_timeout`, `zenoh_publish` functions not in scope

### Level 2: WHY these API mismatches?
- **Zenoh 1.0**: Complete API rewrite - no more `.res()` async pattern
- **Rustler 0.37**: Removed derive macros, simplified resource system
- Code written for zenoh 0.x prelude with async `.res()` pattern

### Level 3: WHY was code not updated?
- Cargo.toml specifies `zenoh = "1.0"` but code uses 0.x API
- Rustler 0.37 specified but code uses 0.30 patterns
- Dependencies updated without testing actual compilation

### Level 4: WHY version mismatch persisted?
- No CI enforcement for Rust NIF compilation
- Cross-language NIFs are complex to maintain
- Zenoh 1.0 breaking changes not anticipated

### Level 5: ROOT CAUSE
**Code was written for zenoh 0.x + rustler 0.30, but dependencies are zenoh 1.0 + rustler 0.37 - breaking API changes require complete migration**

---

## Corrective Actions Applied

### 1. Session.rs - Zenoh 1.0 + Rustler 0.37

**Before (zenoh 0.x + rustler 0.30)**:
```rust
use zenoh::prelude::r#async::*;
use rustler::{OwnedBinary, Resource};

#[derive(Resource)]
pub struct ZenohSessionResource { ... }

// Config API
zenoh_config.set_mode(Some(WhatAmI::Client)).unwrap();
zenoh_config.connect.endpoints.extend([endpoint.parse().unwrap()]);

// Async pattern
let session = runtime.block_on(async { zenoh::open(zenoh_config).res().await })?;
```

**After (zenoh 1.0 + rustler 0.37)**:
```rust
use zenoh::Config;
use zenoh::Session;
use rustler::Resource;

// Manual Resource trait implementation
pub struct ZenohSessionResource { ... }
impl Resource for ZenohSessionResource {}

// JSON-based config for zenoh 1.0
let config_json = serde_json::json!({
    "mode": mode_str,
    "connect": { "endpoints": config.connect.clone() },
    "scouting": { "multicast": { "enabled": config.multicast_scouting } }
});
let zenoh_config: Config = serde_json::from_value(config_json)?;

// Direct .await (no .res())
let session = runtime.block_on(async { zenoh::open(zenoh_config).await })?;
```

### 2. Lib.rs - Rustler 0.37 Init

**Before**:
```rust
rustler::init!(
    "Elixir.Indrajaal.Native.Zenoh",
    [session::zenoh_open_session, ...],  // Explicit list - DEPRECATED
    load = load
);
```

**After**:
```rust
// rustler 0.37 auto-discovers NIF functions via #[rustler::nif] attribute
rustler::init!("Elixir.Indrajaal.Native.Zenoh");
```

### 3. Subscriber.rs - Resource Trait

**Before**:
```rust
use rustler::OwnedEnv;

#[derive(Resource)]
pub struct ZenohSubscriptionResource { ... }

// Dynamic resource registration
rustler::resource!(ZenohSubscriptionResource, env);
```

**After**:
```rust
// No more OwnedEnv
use rustler::Resource;

pub struct ZenohSubscriptionResource { ... }
impl Resource for ZenohSubscriptionResource {}
// Resource registered automatically
```

### 4. Publisher.rs - Fixed Recursive Call

**Before**:
```rust
pub fn zenoh_put(...) -> NifResult<Atom> {
    zenoh_publish(session, key, payload)  // ERROR: NIF not callable directly
}
```

**After**:
```rust
pub fn zenoh_put(...) -> NifResult<Atom> {
    match session.publish(&key, payload.as_slice()) {  // Call session method directly
        Ok(_) => Ok(atoms::ok()),
        Err(e) => Err(Error::Term(Box::new(format!("Put failed: {}", e)))),
    }
}
```

---

## Files Modified

| File | Changes |
|------|---------|
| `native/zenoh_nif/src/session.rs` | Zenoh 1.0 config API, `impl Resource`, return types |
| `native/zenoh_nif/src/subscriber.rs` | `impl Resource` instead of `#[derive(Resource)]` |
| `native/zenoh_nif/src/publisher.rs` | Direct session.publish() call, removed recursive NIF call |
| `native/zenoh_nif/src/lib.rs` | Simplified init! macro for rustler 0.37 |
| `native/zenoh_nif/src/types.rs` | Removed unused `Decoder` import |
| `lib/indrajaal/native/zenoh.ex` | Removed SKIP_ZENOH_NIF bypass |

---

## API Migration Summary

### Zenoh 0.x → 1.0
| Old (0.x) | New (1.0) |
|-----------|-----------|
| `zenoh::prelude::r#async::*` | `zenoh::Config`, `zenoh::Session` |
| `config.set_mode()` | JSON config: `{"mode": "client"}` |
| `config.connect.endpoints` | JSON config: `{"connect": {"endpoints": []}}` |
| `.res().await` | Direct `.await` |
| `sample.payload.contiguous()` | `sample.payload().to_bytes()` |
| `sample.key_expr` | `sample.key_expr()` |

### Rustler 0.30 → 0.37
| Old (0.30) | New (0.37) |
|------------|------------|
| `#[derive(Resource)]` | `impl Resource for T {}` |
| `OwnedBinary` | Removed |
| `OwnedEnv` | Removed |
| `rustler::resource!(T, env)` | Automatic via `impl Resource` |
| Explicit NIF list in init! | Auto-discovery via `#[rustler::nif]` |

---

## Verification

```bash
# Rust NIF compilation
$ cd native/zenoh_nif && cargo build
   Compiling zenoh_nif v0.1.0
warning: field `key_expr` is never read (minor)
warning: type alias `NifResult` is never used (minor)
    Finished `dev` profile in 6.54s

# Full Elixir compilation
$ mix compile
Generated indrajaal app
# SUCCESS - No errors
```

---

## New STAMP Constraints Added

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
    - SC-NIF-008: SKIP_ZENOH_NIF only for temporary migration work
```

---

## Lessons Learned

1. **Breaking API changes in dependencies require full code migration**
2. **Zenoh 1.0 is a complete rewrite - not backward compatible**
3. **Rustler 0.37 simplified resources but removed convenience macros**
4. **Cross-language NIFs need explicit version constraints in both ecosystems**
5. **TPS Jidoka: Stop immediately, analyze fully, fix properly - no bypasses**

---

## STAMP Compliance

- SC-NIF-004: ✅ Versions synchronized (0.37)
- SC-NIF-005: ✅ Version check script exists
- SC-NIF-007: ✅ P0 blocker resolved
- SC-NIF-008: ✅ SKIP bypass removed

**OODA Cycle Time**: 45 minutes (Observe → Orient → Decide → Act)
**TPS Jidoka**: ENFORCED - No bypass, proper root cause fix
