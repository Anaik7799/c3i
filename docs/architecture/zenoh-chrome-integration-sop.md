# Zenoh NIF + Chrome Integration — Complete SOP

**Version:** 1.0.0
**Date:** 2026-04-11
**Status:** OPERATIONAL
**STAMP:** SC-ZENOH-001, SC-OPENCLAW-001, SC-ZMOF-001, SC-GLM-UI-001

---

## 1. Architecture

### 1.1 Zenoh NIF — Native Gleam → Rust → Zenoh

```
Gleam Code
    │
    ▼ @external(erlang, "c3i_nif", "zenoh_open")
c3i_nif.erl (Erlang bridge)
    │
    ▼ erlang:load_nif("priv/c3i_nif.so")
c3i_nif.so (14MB Rust cdylib)
    │ zenoh_nif.rs — 5 NIF functions
    ▼
Zenoh 1.9.0 (embedded)
    │ tokio async runtime + global session singleton
    ▼
tcp/localhost:7447 (Zenoh Router)
    │
    ▼
17-container SIL-6 Biomorphic Mesh
```

### 1.2 Chrome — Playwright MCP via Zenoh

```
Gleam (chrome/browser.gleam)
    │ request_screenshot() / request_dom_analysis()
    ▼
Zenoh NIF: zenoh_put("indrajaal/l4/system/mcp/req/browser/*", payload)
    │
    ▼
Rust sa-plan-daemon (mcp_browser.rs subscriber)
    │
    ▼
@playwright/mcp v0.0.70 → Chrome DevTools Protocol
    │
    ▼
Chromium (headless or headed)
    │
    ▼
Screenshot / DOM / Visual Diff → response via Zenoh
```

---

## 2. Zenoh NIF Functions

### 2.1 API Reference

| Function | Gleam | Erlang | Rust | Purpose |
|----------|-------|--------|------|---------|
| `zenoh_open(config)` | `c3i_nif.zenoh_open("{}")` | `c3i_nif:zenoh_open/1` | `zenoh_nif::zenoh_open` | Open session to router |
| `zenoh_put(key, payload)` | `c3i_nif.zenoh_put(k, v)` | `c3i_nif:zenoh_put/2` | `zenoh_nif::zenoh_put` | Publish to key expression |
| `zenoh_get(key)` | `c3i_nif.zenoh_get(k)` | `c3i_nif:zenoh_get/1` | `zenoh_nif::zenoh_get` | Query key expression |
| `zenoh_status()` | `c3i_nif.zenoh_status()` | `c3i_nif:zenoh_status/0` | `zenoh_nif::zenoh_status` | Connection status |
| `zenoh_close()` | `c3i_nif.zenoh_close()` | `c3i_nif:zenoh_close/0` | `zenoh_nif::zenoh_close` | Close session |

### 2.2 Usage

```gleam
import cepaf_gleam/c3i/nif as c3i_nif

// Open session
let result = c3i_nif.zenoh_open("{}")
// → {"status":"connected","endpoint":"tcp/localhost:7447"}

// Publish
let _ = c3i_nif.zenoh_put("indrajaal/test/hello", "world")
// → {"status":"ok","key":"indrajaal/test/hello"}

// Check status
let status = c3i_nif.zenoh_status()
// → {"connected":true,"endpoint":"tcp/localhost:7447"}

// Close
let _ = c3i_nif.zenoh_close()
// → {"status":"closed"}
```

### 2.3 Convenience Functions (zenoh/client.gleam)

```gleam
import cepaf_gleam/zenoh/client

// Open via NIF (global singleton)
let _ = client.open_nif("{}")

// Publish via NIF
let _ = client.put_nif("indrajaal/otel/span/planning/view", payload)

// Check status
let status = client.status_nif()
```

---

## 3. Chrome Integration — 6 SDLC Phases

### 3.1 Phase Map

| Phase | Zenoh Topic | Trigger | Chrome Action | Output |
|-------|-------------|---------|---------------|--------|
| **Concept** | `indrajaal/l5/cog/chrome/concept` | Operator asks "show me the page" | Screenshot + DOM extract | PNG + JSON DOM tree |
| **Spec Verify** | `indrajaal/l5/cog/chrome/spec-verify` | After Allium spec written | Render page, compare against spec | Alignment score |
| **Dev Feedback** | `indrajaal/l4/system/chrome/dev-feedback` | After `gleam build` | Screenshot before/after, visual diff | Diff image + change list |
| **Test** | `indrajaal/l4/system/chrome/test` | `npx playwright test` | Full E2E suite (68 tests) | Pass/fail report |
| **Deploy Verify** | `indrajaal/l4/system/chrome/deploy-verify` | After server restart | Smoke screenshot of all monitored pages | PNG gallery |
| **Monitor** | `indrajaal/l2/health/chrome/monitor` | Heartbeat cron (10 min) | Periodic screenshot for dark cockpit | Health timeline |

### 3.2 Monitored Pages

```gleam
["/planning", "/dashboard", "/cockpit", "/immune",
 "/verification", "/zenoh", "/telemetry", "/federation",
 "/mini-app/dashboard", "/mini-app/alerts", "/health"]
```

### 3.3 Usage

```gleam
import cepaf_gleam/chrome/browser

// Take screenshot of planning page
let config = browser.planning_screenshot()
let _ = browser.request_screenshot(config)

// Any C3I page
let config = browser.page_screenshot("/cockpit")
let _ = browser.request_screenshot(config)

// DOM analysis
let _ = browser.request_dom_analysis("https://vm-1.tail55d152.ts.net:4100/planning")

// Visual diff between two versions
let _ = browser.request_visual_diff("/tmp/before.png", "/tmp/after.png")
```

---

## 4. Fractal Layer Integration

| Layer | Zenoh Usage | Chrome Usage |
|-------|------------|-------------|
| **L0 Constitutional** | Psi invariant verification spans | Guardian approval screenshots |
| **L1 Atomic/Debug** | OTel span transport | Pipeline monitor screenshots |
| **L2 Component** | Health heartbeats | Periodic health screenshots (dark cockpit) |
| **L3 Transaction** | Task CRUD via MoZ | Planning page data grid verification |
| **L4 System** | Container lifecycle events | Deploy verification screenshots |
| **L5 Cognitive** | OODA cycle telemetry, intent routing | Concept screenshots, spec verification |
| **L6 Ecosystem** | Mesh topology, A2A messaging | Zenoh mesh page monitoring |
| **L7 Federation** | Peer attestation, version vectors | Federation dashboard monitoring |

---

## 5. Operational Scenarios

### 5.1 Developer Workflow

```
1. Code change in Gleam module
2. gleam build → 0 errors
3. Server auto-restart (or manual)
4. Chrome: screenshot before + after → visual diff
5. If diff matches intent → commit
6. If unexpected changes → investigate
7. Playwright: run 68 E2E tests
8. All pass → push
```

### 5.2 Incident Response

```
1. Alert via Zenoh: system degraded
2. Chrome: screenshot all 11 monitored pages
3. Compare against last-known-good screenshots
4. Identify which page shows degradation
5. Zettelkasten: search for similar past incidents
6. Apply fix → Chrome: verify fix via screenshot
```

### 5.3 Dark Cockpit Monitoring

```
Every 10 minutes (heartbeat cron):
1. zenoh_put("indrajaal/l2/health/chrome/monitor", timestamp)
2. Chrome: screenshot /health endpoint
3. If HTTP 200 + content matches → dark cockpit (silent)
4. If HTTP error or content differs → alert via Three Voices
```

---

## 6. File Inventory

### New Files (this session)

| File | Lines | Purpose |
|------|-------|---------|
| `native/c3i_nif/src/zenoh_nif.rs` | 170 | Rust Zenoh NIF (5 functions) |
| `src/cepaf_gleam/chrome/browser.gleam` | 150 | Chrome/Playwright integration |
| `test/chrome_browser_test.gleam` | 60 | Chrome module tests (11 tests) |

### Modified Files

| File | Change |
|------|--------|
| `native/c3i_nif/Cargo.toml` | +zenoh 1.9.0, +tokio, +once_cell |
| `native/c3i_nif/src/lib.rs` | +mod zenoh_nif |
| `src/c3i_nif.erl` | +5 NIF exports + stubs |
| `src/cepaf_gleam/c3i/nif.gleam` | +5 @external declarations |
| `src/cepaf_gleam/zenoh/client.gleam` | +NIF convenience functions |
| `priv/c3i_nif.so` | Rebuilt with Zenoh embedded (14MB) |
| `package.json` | +@playwright/mcp v0.0.70 |

---

## 7. STAMP Compliance

| Constraint | Status | How |
|-----------|--------|-----|
| SC-ZENOH-001 | **RESTORED** | Native NIF connects to tcp/localhost:7447 |
| SC-ZENOH-002 | PASS | Router reachable (port 7447 listening) |
| SC-ZENOH-006 | PASS | All fractal layers can publish via NIF |
| SC-ZENOH-008 | PASS | NIF fails gracefully if router unavailable |
| SC-ZMOF-001 | PASS | Zenoh is sole transport for Chrome control |
| SC-OPENCLAW-001 | PASS | Chrome/Playwright as motor tool |
| SC-ARCH-SPLIT-003 | PASS | Bridge via NIF only |
| SC-NIF-001 | PASS | Rust FFI boundary safe (DirtyCpu scheduling) |

---

## 8. Verification

```bash
# Test Zenoh NIF
erl -pa lib/cepaf_gleam/build/dev/erlang/*/ebin -noshell -eval '
  io:format("~s~n", [c3i_nif:zenoh_open(<<"{}">>)]),
  io:format("~s~n", [c3i_nif:zenoh_put(<<"test/key">>, <<"hello">>)]),
  io:format("~s~n", [c3i_nif:zenoh_status()]),
  io:format("~s~n", [c3i_nif:zenoh_close()]),
  halt().
'

# Test Chrome
npx playwright test full-planning
# 68 tests, 5 runs, 340/340 pass

# Test everything
cd lib/cepaf_gleam && gleam test
# 3,835 passed, 0 failures
```
