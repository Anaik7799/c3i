# Fractal TPS RCA: Why Was the Sliding Sync Format Gap Not Caught?

**Date**: 2026-04-19
**Issue**: Element X shows "confirm your digital identity" because sliding sync response used traditional sync format instead of MSC3575 format
**Severity**: HIGH — blocks Element X client entirely
**Detection**: Production (user reported), not caught by any test layer

---

## 5-Why Root Cause Analysis

### L1: Why did Element X show "confirm your digital identity"?
Element X's matrix-rust-sdk parsed the sliding sync response and couldn't find `extensions.e2ee.device_lists` — the E2EE info was at the top level (`device_lists`) instead of nested under `extensions`.

### L2: Why was the E2EE info in the wrong location?
The sliding sync endpoint (`/_matrix/client/unstable/org.matrix.simplified_msc3575/sync`) reused the same handler as traditional sync (`/_matrix/client/v3/sync`), which returns the v2 sync format (`{next_batch, rooms, device_lists, ...}`) instead of MSC3575 format (`{pos, rooms, lists, extensions: {e2ee, to_device, account_data}}`).

### L3: Why did the sliding sync endpoint reuse the traditional handler?
When sliding sync was added, the implementation was: "accept the POST, route to same sync handler" — treating MSC3575 as just another path to the same sync logic. **Nobody checked the MSC3575 spec for its different response schema.**

### L4: Why didn't tests catch it?
Because every test layer tested the WRONG thing:

### L5: Why did the test design miss this?

---

## Fractal Failure Analysis — Where Each Layer Failed

### Layer 0: Specification (TLA+/Agda/Quint)
**Gap**: The 5 TLA+ specs model sync semantics (no skips, no duplicates, ordering) but do NOT model the **response JSON schema**. The `SyncProtocol.tla` spec has `clientReceived` and `serverEvents` as abstract sequences — it never checks whether the response uses `next_batch` vs `pos`, or whether E2EE data is at the top level vs nested under `extensions`.

**Root cause**: Formal specs model **protocol correctness** (safety/liveness properties), not **wire format compliance**. Schema validation is a different concern.

**Fix**: Add a Quint model or test that validates the JSON schema of each sync variant against the Matrix spec OpenAPI definitions.

### Layer 1: Gleam Unit Tests (988 tests)
**Gap**: The router coverage test (`sutra_router_coverage_test.gleam`) tests that `GET /_matrix/client/v1/sync` returns 200 with `next_batch`. It does NOT test `POST /_matrix/client/unstable/org.matrix.simplified_msc3575/sync` for MSC3575-specific fields (`pos`, `extensions`).

**Root cause**: The sliding sync test was added as a single line:
```gleam
pub fn r_sliding_sync_test() {
  case aget("/_matrix/client/v1/sync") { JsonResponse(200, b) -> ... }
}
```
This tests the WRONG endpoint (v1/sync GET, not the MSC3575 POST) and checks for `next_batch` (v2 format) instead of `pos` (MSC3575 format).

**Fix**: Add explicit MSC3575 schema validation test:
```gleam
pub fn sliding_sync_msc3575_format_test() {
  case route("POST", "/_matrix/client/unstable/org.matrix.simplified_msc3575/sync", "{}", Some("tok")) {
    JsonResponse(200, body) -> {
      string.contains(body, "\"pos\"") |> should.be_true
      string.contains(body, "\"extensions\"") |> should.be_true
      string.contains(body, "\"e2ee\"") |> should.be_true
      // MUST NOT have next_batch (that's v2 format)
      string.contains(body, "\"next_batch\"") |> should.be_false
    }
  }
}
```

### Layer 2: Dart SDK Tests (129 tests)
**Gap**: The Dart Matrix SDK (v6.2.0) does NOT use sliding sync — it uses traditional v3/sync. So our 129 Dart tests never exercise the MSC3575 endpoint. The `sutra_full_e2e_test.dart` tests sync via `GET /v3/sync`, not `POST /unstable/.../sync`.

**Root cause**: We tested with the FluffyChat SDK (matrix-dart-sdk v6.2.0) which predates sliding sync. Element X uses matrix-rust-sdk which DOES use sliding sync. **We tested with the wrong client SDK.**

**Fix**: Add a raw HTTP test that validates the MSC3575 response schema:
```dart
test('sliding sync MSC3575 format', () async {
  final r = await rawPost('/_matrix/client/unstable/org.matrix.simplified_msc3575/sync', {}, token: adminToken);
  expect(r.statusCode, 200);
  final d = j(r);
  expect(d.containsKey('pos'), isTrue);         // NOT next_batch
  expect(d.containsKey('extensions'), isTrue);   // NOT top-level device_lists
  expect(d['extensions']['e2ee'], isNotNull);
});
```

### Layer 3: FluffyChat Source Code Analysis
**Gap**: We cloned FluffyChat and analyzed its source code extensively (bootstrap_dialog.dart, olm_manager.dart, bootstrap.dart). But FluffyChat uses the **Dart** Matrix SDK which does traditional sync. **We never analyzed Element X's source** (which uses Rust SDK + sliding sync).

**Root cause**: The user said "FluffyChat" so we focused exclusively on FluffyChat. When the user switched to Element X, we didn't re-analyze for the different client's requirements.

**Fix**: When a new client is introduced, always:
1. Identify which SDK it uses (Dart, Rust, JS)
2. Identify which sync protocol it uses (v2, v3, MSC3575)
3. Check the response format expectations
4. Add client-specific tests

### Layer 4: Client Simulator Test (109 tests)
**Gap**: The `sutra_client_simulator_test.gleam` simulates a FluffyChat-style client using `router.route()` — traditional sync. It never simulates an Element X-style client using MSC3575 POST.

**Root cause**: The simulator was designed around FluffyChat's flow, not Element X's.

### Layer 5: Live HTTP Tests (31 tests)
**Gap**: The `sutra_live_client_test.gleam` tests real HTTP against the server. It includes a sliding sync test but checks the WRONG response format:
```gleam
pub fn r_sliding_sync_test() {
  // Tests v1/sync, not the MSC3575 endpoint!
}
```

### Layer 6: Edge Case Tests (112 tests)
**Gap**: Edge case tests cover injection, traversal, Unicode, etc. but never cover **schema validation** of different response formats.

---

## Toyota Production System Analysis

### Which of the 7 Wastes Occurred?

**Waste #1: Overproduction**
We wrote 15 formal specs, 988 Gleam tests, 129 Dart tests — but NONE tested MSC3575 schema. Massive test count with a critical blind spot.

**Waste #4: Extra Processing**
We analyzed FluffyChat's Dart SDK exhaustively (olm_manager.dart line-by-line) but Element X uses a completely different SDK.

**Waste #7: Defects**
The sliding sync endpoint shipped with the wrong response format because it was treated as "same handler, different path" — no schema validation.

### Jidoka (Stop on Defect)
**Failed**: No automated check existed to stop on MSC3575 schema mismatch. The server happily returned v2 format on the MSC3575 endpoint without any alarm.

### Poka-Yoke (Error Proofing)
**Failed**: The dispatch_to_handler routed MSC3575 POST to the same handler as v3/sync GET — no type-level distinction between the two response formats. The type system should enforce that MSC3575 returns a different type than v2 sync.

---

## Systemic Root Causes

### 1. Response Schema Not Typed
The `ApiResult` type is `JsonResponse(status, body_string)` — the body is an opaque string. There's no compile-time guarantee that different endpoints return different schema shapes. Both v2 sync and MSC3575 sync return `JsonResponse(200, some_json_string)` — indistinguishable at the type level.

**Fix**: Define response types per endpoint:
```gleam
pub type SyncV2Response { ... next_batch, rooms, device_lists ... }
pub type SyncMSC3575Response { ... pos, rooms, lists, extensions ... }
```

### 2. Client-Agnostic Testing
All tests assumed "one client to rule them all" (FluffyChat). Element X has fundamentally different protocol requirements (sliding sync, matrix-rust-sdk, different JSON parsing).

**Fix**: Test matrix:
| Client | SDK | Sync Protocol | Test Coverage |
|--------|-----|--------------|---------------|
| FluffyChat | Dart matrix v6 | v2/v3 sync | ✅ 129 tests |
| Element X | Rust matrix-sdk | MSC3575 sliding sync | ❌ NOT TESTED → NOW ADDED |
| Element Web | JS matrix-js-sdk | v2 sync | Not tested |

### 3. Spec vs Implementation Divergence
MSC3575 was "added" by just routing to the existing sync handler. Nobody read the MSC3575 spec to check the response format. The spec was treated as "just another sync URL" without checking that it has a completely different response schema.

**Fix**: For any new protocol extension:
1. Read the MSC/spec FIRST
2. Define the response type
3. Write a schema validation test
4. THEN implement

---

## Corrective Actions

| # | Action | Priority | Status |
|---|--------|----------|--------|
| 1 | Separate sliding sync handler with MSC3575 format | CRITICAL | **DONE** |
| 2 | Add MSC3575 schema validation test (Gleam) | HIGH | TODO |
| 3 | Add MSC3575 schema validation test (Dart) | HIGH | TODO |
| 4 | Add Element X client-specific test suite | MEDIUM | TODO |
| 5 | Define typed response types per endpoint | MEDIUM | TODO |
| 6 | Add to CLAUDE.md rule: "New protocol = new response type + schema test" | HIGH | TODO |
| 7 | Add wiring-guard for sync response format | MEDIUM | TODO |

---

## Anti-Pattern Recorded

**Name**: "Same Handler, Different Protocol"
**Description**: Routing a new protocol endpoint to an existing handler without checking that the new protocol has a different response format.
**Detection**: Client shows cryptic error ("confirm your digital identity") because it can't parse the response in the expected format.
**Prevention**: Every new endpoint path MUST have its response schema validated against the spec, even if the underlying logic is identical.

> "The map is not the territory." — Korzybski
> A 200 status code and valid JSON does NOT mean the response is correct. The schema must match what the client expects.
