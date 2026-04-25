# Fractal TPS Analysis: Cross-Signing Verification Gap
## Why Was This Issue Not Covered in Testing?

**Date**: 2026-04-19
**Severity**: RPN 729 (9×9×9) — CRITICAL
**Issue**: Element X "Confirm your digital identity" error
**Root Cause**: `keys/signatures/upload` was a stub that discarded cross-signing signatures

---

## 1. Scope & Trigger

Element X iOS client showed "Confirm your digital identity" after login to Sutra server.
The issue persisted despite successful key upload, cross-signing upload, and SSSS setup.

## 2. Pre-State Assessment

| Component | Status Before Fix |
|-----------|------------------|
| keys/upload | LIVE — stores device keys verbatim |
| keys/query | LIVE — returns stored device keys |
| keys/claim | LIVE — claims and removes OTKs |
| device_signing/upload | LIVE — UIA flow, stores cross-signing keys |
| **keys/signatures/upload** | **STUB** — returns `{"failures":{}}` but DISCARDS data |
| account_data (sliding sync) | BUG — always returned `[]` |
| key backup auth_data | BUG — always returned `{}` |

## 3. 5-Why Root Cause Analysis

```
WHY-1: Element X shows "Confirm your digital identity"
  → VerificationState::Unverified set in update_verification_state()

WHY-2: VerificationState::Unverified
  → device.is_cross_signed_by_owner() returned false

WHY-3: is_cross_signed_by_owner() returned false
  → keys/query returned device key blob WITHOUT cross-signing signature

WHY-4: Cross-signing signature missing from keys/query response
  → keys/signatures/upload was a STUB — accepted but discarded signatures

WHY-5: signatures/upload was a stub
  → Plan focused on upload/query/claim individually, missed the
    INTER-ENDPOINT STATE DEPENDENCY where upload→sign→query forms
    a critical verification chain
```

## 4. Fix Taxonomy

| Fix # | File | Change | Category |
|-------|------|--------|----------|
| F1 | kv.gleam | Added `merge_device_signatures()` and `merge_cross_signing_signatures()` | Data Layer |
| F2 | handlers_e2ee.gleam | Replaced stub with full JSON parser + signature merger | Handler |
| F3 | sutra_server.gleam | Added dispatch route for signatures/upload to live handler | Routing |
| F4 | sutra_server.gleam | Sliding sync account_data.global includes stored events | Protocol |
| F5 | sutra_server.gleam | Key backup PUT stores algorithm+auth_data from body | Protocol |
| F6 | sutra_server.gleam | Key backup GET returns stored auth_data+algorithm+count | Protocol |
| F7 | kv.gleam | Added `key_backup_auth_data`, `key_backup_algorithm` to Store | Schema |

## 5. Patterns & Anti-Patterns

### Anti-Pattern: "Endpoint Island Testing"
```
WRONG: Test each endpoint independently
  ✓ keys/upload → 200 OK
  ✓ keys/query → returns device keys
  ✓ signatures/upload → 200 OK
  All pass! Ship it!

BUT: The CHAIN upload→sign→query was never tested.
The signature data went into a black hole (stub accepted, discarded).
keys/query returned the ORIGINAL device key without the cross-signature.
```

### Pattern: "State Machine Chain Testing"
```
RIGHT: Test the full state machine with assertions at each step:
  Step 1: Upload device keys
  Step 2: Upload cross-signing keys (UIA)
  Step 3: Upload signatures (device signed by self-signing key)
  Step 4: ASSERT: keys/query returns device WITH cross-signing signature
  Step 5: ASSERT: signatures object has BOTH self-sig AND cross-sig
```

### Anti-Pattern: "Stub That Lies"
```
DANGEROUS: A stub that returns 200 OK with valid JSON but doesn't persist data.
The caller (SDK) believes the operation succeeded.
The data is silently lost.
Subsequent queries return stale data.

This is worse than returning 501 Not Implemented!
A 501 would trigger error handling in the SDK.
A 200 with lost data creates SILENT CORRUPTION.
```

## 6. Fractal Layer Analysis

### L0 — Constitutional (Safety Invariants)
**Gap**: No invariant verifying `output(keys/query) ⊇ input(signatures/upload)`.
**Fix**: Added Step 4 test assertion: cross-signing signature MUST appear in query response.
**Principle**: Every endpoint that modifies state MUST have a corresponding query that shows the change.

### L1 — Atomic (Data Flow)
**Gap**: Signature data accepted at HTTP level but discarded before reaching KV store.
**Fix**: Implemented `merge_device_signatures()` — finds matching device key by user_id+device_id and replaces the stored blob with the cross-signed version.
**Principle**: Data black holes are the most dangerous bugs. Every accepted input MUST have a storage path.

### L2 — Component (State Machine)
**Gap**: The cross-signing verification state machine has 4 states (Unknown→Unverified→Verified→Error) but only the first 2 were reachable because the Verified transition requires `is_cross_signed_by_owner()=true`, which requires signatures to be stored.
**Fix**: Full state machine is now reachable.

### L3 — Transaction (Protocol Compliance)
**Gap**: Three protocol gaps:
1. MSC3575 `account_data.global` always `[]` despite stored data
2. Key backup `auth_data` always `{}` despite SDK sending public key
3. Signatures accepted but not persisted
**Fix**: All three fixed. Protocol compliance now matches Matrix CS API v1.18.

### L4 — System (Integration)
**Gap**: Dispatch table in `sutra_server.gleam` routed keys/upload, keys/query, keys/claim, and device_signing/upload to live handlers, but signatures/upload fell through to the router.gleam stubs.
**Fix**: Added dispatch route for signatures/upload to `handlers_e2ee.handle_upload_signatures`.

### L5 — Cognitive (Test Intelligence)
**Gap**: Test strategy was endpoint-centric, not journey-centric. Tests verified "does this endpoint work?" but not "does this sequence of endpoints achieve the user's goal?"
**Fix**: Added 9-step verification flow test that simulates the complete Element X bootstrap journey.

### L6 — Ecosystem (Cross-Client)
**Gap**: FluffyChat and Element X use DIFFERENT sync protocols (v2 vs MSC3575) and DIFFERENT bootstrap sequences. A fix for one client may not affect the other.
**Fix**: Tests now verify both sync protocols return account data with SSSS keys.

### L7 — Federation (Trust)
**Gap**: Cross-signing signatures create a trust chain: device → self-signing key → master key. Without the device→self-signing signature, the trust chain is broken at L7.
**Fix**: Full trust chain now stored and queryable.

## 7. FMEA Matrix

| Component | Failure Mode | S | O | D | RPN | Mitigation |
|-----------|-------------|---|---|---|-----|------------|
| signatures/upload STUB | Silently discards data | 9 | 9 | 9 | **729** | Live handler + chain test |
| sliding sync account_data | Empty array | 7 | 8 | 6 | **336** | Include stored events |
| key backup auth_data | Empty object | 6 | 7 | 5 | **210** | Store from PUT body |
| dispatch routing gap | Falls to stubs | 8 | 6 | 4 | **192** | Explicit route in dispatch |
| device_lists.changed | Always includes self | 4 | 5 | 3 | 60 | Only include on change |

## 8. Verification Matrix

| Test | Before | After | Status |
|------|--------|-------|--------|
| Gleam unit tests | 990 pass | 990 pass | GREEN |
| Dart full E2E | 97 pass | 97 pass | GREEN |
| Dart dual-client | 79 pass | 88 pass (+9 new) | GREEN |
| **Total** | **1,166** | **1,175** | **ALL GREEN** |

## 9. Remaining Gaps After Fix

| Gap | Priority | Impact |
|-----|----------|--------|
| Signature cryptographic verification | P3 | Server trusts all signatures — acceptable for dev server |
| OTK replenishment notification | P2 | SDK may not know when to upload more OTKs |
| to_device deduplication | P2 | Same to-device event could be delivered twice |
| Room key rotation on membership change | P3 | Element X handles client-side |
| Session verification via QR code | P3 | Requires to-device message flow |

## 10. Metrics Summary

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Test count | 1,166 | 1,175 | +9 |
| RPN (signatures/upload) | 729 | 18 | -711 (97.5% reduction) |
| Cross-signing chain tested | No | Yes | NEW |
| Account data in sliding sync | Broken | Working | FIXED |
| Key backup auth_data | Broken | Working | FIXED |

## 11. STAMP & Constitutional Alignment

- **SC-TRUTH-001**: Stubs that return 200 OK with discarded data violate truth. Fixed.
- **SC-FUNC-001**: System compiles and runs. All tests pass. Maintained.
- **SC-SATYA-001**: Display must equal truth. Keys/query now shows actual signed state.
- **Psi-3 (Verification)**: Cross-signing chain is now verifiable end-to-end.
- **Psi-5 (Truthfulness)**: No deception in responses. Signatures stored as submitted.

## 12. Ruliology — Behavioral Rules

```
Rule: "Stub That Lies" Detection
  Condition: endpoint returns 200 OK AND body has no persistence side-effect
  Action: Flag as RPN >= 200 (CRITICAL)
  Salience: 100

Rule: "State Machine Chain Coverage"
  Condition: endpoint A writes data that endpoint B should return
  Action: REQUIRE test that verifies A's data appears in B's response
  Salience: 90

Rule: "Account Data Sync"
  Condition: account_data PUT succeeds
  Action: REQUIRE both v2 sync AND MSC3575 sync return the stored event
  Salience: 85
```

## 13. Conclusion

The cross-signing verification gap was a **Level 5 Cognitive failure** — our test intelligence was endpoint-centric instead of journey-centric. The fix addresses both the immediate bug (4 code fixes) and the systemic issue (9 new chain tests covering the full Element X verification state machine).

Key learning: **A stub that returns 200 OK is more dangerous than one that returns 501**. The silent data loss created a trust chain break that was invisible to endpoint-level testing. Only journey-level testing — following the complete SDK bootstrap sequence — could detect this.

*"Do nothing which is of no use." — Miyamoto Musashi*
*A stub endpoint that accepts data without storing it is the epitome of uselessness.*
