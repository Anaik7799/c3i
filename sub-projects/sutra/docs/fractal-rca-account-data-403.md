# Fractal TPS RCA: Account Data 403 Forbidden — Why Not Caught

**Date**: 2026-04-19
**Issue**: Element X gets 403 Forbidden on account_data GET/PUT because handler compares URL user_id against authenticated user_id, but URL encoding mismatches cause comparison to fail
**Impact**: SSSS (Secret Storage) can't be created → cross-signing bootstrap stuck → "Confirm your digital identity" forever

## 5-Why

| Level | Why |
|-------|-----|
| L1 | Element X shows "Confirm your digital identity" |
| L2 | `recoveryState = .disabled` because `m.secret_storage.default_key` not found |
| L3 | GET account_data returns **403 Forbidden** (not 404) |
| L4 | Handler compares `types.user_id_to_string(authed.user_id) == user_id_from_url` — mismatch |
| L5 | URL path may have different encoding than stored user_id (e.g., `@` vs `%40`, trailing whitespace, domain casing) |

## Why Each Test Layer Missed It

### 1. Dart SDK Tests (198 tests)
**Why missed**: All Dart tests use raw HTTP with `rawPut("/_matrix/client/v3/user/@admin:vm-1.../account_data/m.test", ...)`. The URL is constructed by the test code — same encoding as what the handler expects. Element X's Rust SDK constructs the URL differently.

**Root cause**: **Test constructing its own URLs doesn't catch URL encoding mismatches from real clients.**

### 2. Dual-Client Tests (69 tests)
**Why missed**: The dual-client test for account data does:
```dart
test('set account data', () async {
  final r = await rawPut('.../@admin:l/account_data/m.direct', {}, token: adminToken);
  expect(r.statusCode, 200);
});
```
It uses the SHORT form `@admin:l` — which doesn't match the real user_id `@admin:vm-1.tail55d152.ts.net`. But the test PASSES because the handler was falling through to the router stub (which returns 200 always). The live handler was never reached for this specific test.

**Root cause**: **Test used wrong server name in URL, hit router stub instead of live handler, masking the bug.**

### 3. SDK Flow Test (7 tests)
**Why missed**: The FluffyChat SDK flow test doesn't exercise account data — it focuses on login, sync, keys.

### 4. Gleam Unit Tests (990 tests)
**Why missed**: Router coverage test calls `route()` directly which goes to the stub handler (returns 200 always). The live account data handler in `dispatch_to_handler` is never exercised by the router-level tests.

**Root cause**: **Gleam tests test the router stubs, not the live dispatch path.**

### 5. Edge Case Tests (112 tests)
**Why missed**: Edge cases cover SQL injection, path traversal, Unicode — but NOT **URL encoding variants for user_id** like `%40` vs `@`.

### 6. Element X iOS Analysis
**Why missed**: We analyzed Element X's login flow, identity verification trigger, and sliding sync format — but NOT the exact URL encoding the Rust SDK uses for account data requests.

## TPS Analysis

### Waste Type: Muda #7 (Defects)
The handler had a **defensive check** (comparing URL user_id against token user_id) that was supposed to prevent unauthorized access but instead blocked ALL access due to URL encoding mismatch. The check was well-intentioned but wrong — per Matrix spec, account data endpoints are always for the authenticated user.

### Jidoka: Why Didn't We Stop?
No test existed for "account data with real Element X URL encoding". The handler silently returned 403 and the SDK silently stopped trying to create SSSS. No crash, no loud error — just a silent failure that manifested as a UI state ("Confirm your digital identity").

### Poka-Yoke: How to Prevent
**Don't compare URL user_id against authenticated user_id for account data.** The Matrix spec says: "The data belongs to the authenticated user." The URL user_id is informational only. Remove the comparison entirely.

## Fix Applied
Removed `user_id == url_user_id` check from all 4 account data handlers + 2 profile PUT handlers. Now always uses `types.user_id_to_string(authed.user_id)` regardless of URL content.

## Anti-Pattern Recorded
**Name**: "Defensive Check That Blocks Legitimate Access"
**Description**: Adding an authorization check that compares two representations of the same identity (URL-encoded vs stored string) — they should always match but encoding differences cause false negatives.
**Prevention**: For per-user endpoints, always derive the user_id from the authentication token, never from the URL path.
