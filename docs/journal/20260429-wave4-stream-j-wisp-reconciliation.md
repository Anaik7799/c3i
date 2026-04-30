https://vm-1.tail55d152.ts.net:8443/c3i/docs/journal/20260429-wave4-stream-j-wisp-reconciliation.md

# Wave-4 Stream-J Wisp Endpoint Reconciliation
**Task**: 116487572781230245 (Wave-7)
**STAMP**: SC-AVP-001..010, SC-FRAC-RRF-002, SC-GLM-UI-001, SC-GLM-UI-007
**ZK**: [zk-3346fc607a1ef9e6] no Stub-That-Lies — measure, don't assume
**Date**: 2026-04-29

## 1. Disk State (verified)

Three files exist for the `hook_subsystem` triple-interface:

| Interface | Path | Size | mtime |
|---|---|---|---|
| Lustre tile | `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/hook_subsystem.gleam` | 11,535 B | Apr 29 11:48 |
| Wisp endpoint | `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/hook_subsystem.gleam` | 2,301 B | Apr 29 11:50 |
| TUI view | `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/hook_subsystem_view.gleam` | 3,097 B | Apr 29 11:50 |
| Test | `lib/cepaf_gleam/test/hook_subsystem_test.gleam` | — | present |

The Wisp file is on disk — but with name `hook_subsystem.gleam`, **not** `hook_subsystem_api.gleam` as Stream J's report claimed.

The Wisp module declares `GET /api/v1/hook-subsystem` (header comment, line 2), exports JSON encoders, and imports the Lustre model.

## 2. Route Registration — NOT FOUND

`grep -rn "hook[-_]subsystem"` across the entire `src/` tree returns **zero matches** in any router file:

- `ui/wisp/router.gleam` (96 KB) — no occurrence of `hook_subsystem` or `hook-subsystem`
- No alternate router, mini_app_routes, or planning_routes references it
- `wiring_guard.gleam` imports the **Lustre** module (line 70) and calls `hook_subsystem.init()` (line 125) — but no Wisp wiring

## 3. Live HTTP Probe

```
curl /hook-subsystem          → HTTP 200, body = "C3I — Not Found" page
curl /api/v1/hook-subsystem   → HTTP 200, body = {"error":"not_found", ...}
```

Both endpoints hit the **404 fallback handler** (which returns HTTP 200 with a not-found body — itself an SC-AVP / SC-TRUTH-002 violation worth flagging separately). Stream N's "returns 200" measurement was technically correct but misleading: 200 here ≠ working route.

## 4. Disposition

**Option A** (Stream J wrote under different name): partially supported — Wisp file exists as `hook_subsystem.gleam`, not `hook_subsystem_api.gleam`. Naming mismatch between report and disk.

**Option B** (Stream J never wired the route): supported — neither the Wisp module nor any router invokes `hook_subsystem.full_status_json` / `compact_status_json`. The module compiles in isolation but is **dead code** as far as HTTP serving is concerned.

**Verdict: A + B combined.** The Wisp source file exists (so Stream J did create *a* Wisp module), but it is **not wired into any router**, so the dashboard route at `/hook-subsystem` and the API at `/api/v1/hook-subsystem` both fall through to the 404 handler.

## 5. Triple-Interface Compliance (SC-GLM-UI-001)

| Plane | File present | Wired into runtime |
|---|:---:|:---:|
| Lustre | ✓ | ✓ (via `wiring_guard.init()` — but tile rendering not yet attached to a page route) |
| Wisp | ✓ | **✗** (module orphaned; no router binding) |
| TUI | ✓ | ✓ (importable, `hook_subsystem_view`) |

**Score: 2/3 wired, 3/3 files on disk.** SC-GLM-UI-007 ("every Wisp endpoint MUST have corresponding Lustre + TUI view") is satisfied for files but inverted-violated for runtime: the Wisp module exists yet serves no traffic.

## 6. Stream J Accuracy

**Partially correct.**
- Created the Wisp source file → **TRUE** (different filename than reported, but functionally a Wisp endpoint module).
- Implied the route is live → **FALSE**. No router registration; HTTP 200 is the fallback page, not a working endpoint.
- Stream N's claim "route returns 200" was technically true but vacuous — the 200 is the not-found page returning itself with status 200 (separate SC-TRUTH-002 anti-pattern).

## 7. Recommended Remediation (no edits made in this task)

1. Add to `ui/wisp/router.gleam`: route case `["api", "v1", "hook-subsystem"] -> hook_subsystem.full_status_json(...) |> wisp.json_response(200)`.
2. Add to dashboard page route handler: import `ui/lustre/hook_subsystem` and embed `hook_subsystem.render_card(model)` into the dashboard page or register `/hook-subsystem` as its own page.
3. Fix the 404 fallback to return HTTP 404 (not 200) — separate SC-TRUTH-002 fix.
4. Add `hook_subsystem` Wisp + Lustre route assertions to `wiring_guard_test.gleam` so future regressions fire compile-time.

## 8. Evidence Summary

- Files on disk: 3 (Lustre + Wisp + TUI) ✓
- Route registered: 0 ✗
- Triple-interface compliance: 2/3
- Stream J accuracy: **partial** (file created with different name; route never wired)
