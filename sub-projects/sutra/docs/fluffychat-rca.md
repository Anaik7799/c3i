# FluffyChat "Upload Key Failed" — Fractal RCA

**Date**: 2026-04-18
**Client**: FluffyChat v2.5.1 (iOS/iPad)
**SDK**: matrix-dart-sdk v6.2.0
**Server**: Sutra v0.1.0 (Gleam)

## Root Cause Chain (5-Why Fractal)

### L1: Why does FluffyChat show "upload key failed"?
The Bootstrap dialog reaches `BootstrapState.error` (line 502 of bootstrap.dart in the Matrix SDK).

### L2: Why does the bootstrap error?
At line 453-460, `client.uploadCrossSigningKeys()` is called with UIA (`uiaRequestBackground`). This calls `POST /keys/device_signing/upload`. If the server doesn't support UIA (always returns 200), the SDK's UIA flow breaks.

### L3: Why doesn't UIA work?
Sutra's `handle_device_signing_upload()` returned `200 {}` unconditionally — no UIA challenge (401 with session/flows) on the first call.

**FIX APPLIED**: Added UIA support — returns 401 with `m.login.password` flow when no `auth` field present, 200 when auth is provided.

### L4: Why does the bootstrap retry loop?
After `uploadCrossSigningKeys` succeeds, the SDK calls `client.oneShotSync()` (line 468) and waits for the master key to appear in `client.userDeviceKeys`. Since Sutra doesn't actually store cross-signing keys in the sync response, this check fails → the bootstrap throws `BootstrapBadStateException`.

**FIX NEEDED**: Store uploaded cross-signing keys and include them in the `/sync` response under `device_lists.changed`.

### L5: Why does FluffyChat retry the entire login?
When `BootstrapState.error` is reached, FluffyChat shows the error icon. The user (or auto-retry) restarts the login flow, which triggers the same bootstrap → same error → infinite loop.

## Sequence Diagram

```
FluffyChat                    Matrix SDK                    Sutra Server
────────                      ──────────                    ────────────
Login ──────────────────────────────────────POST /login──────▶ 200 ✓
                              Store token ◀─────────────────── access_token
                              
POST /keys/upload ──────────────────────────────────────────▶ 200 ✓
                              one_time_key_counts OK

GET /sync ─────────────────────────────────────────────────▶ 200 ✓
                              prevBatch set, sync complete

Bootstrap starts ◀────────── client.encryption.bootstrap()
                              
Check SSSS ──────────────── No SSSS keys → askNewSsss
User creates recovery key ─ newSsssKey created

askSetupCrossSigning(all=true) ──────────────────────────────
  uploadCrossSigningKeys ──POST /keys/device_signing/upload──▶
    WITHOUT auth           ◀──── 401 {session, flows} ←── UIA challenge (FIXED)
    WITH auth              ◀──── 200 {} ←── Success (FIXED)
                              
  oneShotSync() ───────────GET /sync────────────────────────▶ 200
                              Check: masterKey in userDeviceKeys?
                              ✗ NOT FOUND ← Server doesn't return
                                            cross-signing keys in sync
                              
  THROW BootstrapBadStateException ←─── "New master key does not match up!"
  state = BootstrapState.error
                              
FluffyChat shows ⛔ error icon
```

## Fixes Applied

| # | Fix | File | Status |
|---|-----|------|--------|
| 1 | UIA for device_signing/upload | router.gleam | **DONE** |
| 2 | Unique device_id per login | router.gleam | **DONE** |
| 3 | OTK counts in sync response | sync_engine.gleam | **DONE** |
| 4 | Admin password mismatch | sutra_server.gleam | **DONE** |

## Fixes Still Needed

| # | Fix | Impact | Effort |
|---|-----|--------|--------|
| 5 | Store cross-signing keys in server state | Bootstrap completes | Medium |
| 6 | Include cross-signing keys in /sync device_lists | masterKey verification passes | Medium |
| 7 | Include user_device_keys in /sync response | SDK populates device key cache | Medium |
| 8 | Support /keys/query returning stored device keys | Cross-device verification | Low |

## Verification

- Dart Matrix SDK tests: **31/31 passed** (against live server)
- Gleam tests: **986 passed, 0 failures**
- UIA flow: Verified via curl (401 → 200)
- Server: Running on port 6167, PID 4143058
