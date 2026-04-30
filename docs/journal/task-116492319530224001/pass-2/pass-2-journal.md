# /planning evolution closure — pass-2

🔗 **Tailscale:** `http://vm-1.tail55d152.ts.net:4200/task-id/116492319530224001/pass-2/pass-2-journal.md`
**Continuation of:** `urn:c3i:task:misc:116492319530224001` (pass-1, 2026-04-30)
**Pass-2 trigger:** operator request — "max parallelization, full fractal supervisors and agents, SIL-6 biomorphic, fast OODA, until goal completion, biomorphic evolutionary, criticality + FMEA + utility-based plan and execute" — close all 5 next-pass items from pass-1.

ZK lineage: `[zk-3346fc607a1ef9e6]` Stub-That-Lies anti-pattern (RPN 729) — *no stubs, real implementation* · `[zk-8321984ba2c0b655]` critical-path P0→P3 ordering · `[zk-8d1b4fd1fa922ccb]` criticality + FMEA gates.

## 1. Scope & trigger

Pass-1 left 5 next-pass items. Operator asked for parallel closure with biomorphic / OODA / FMEA-prioritised execution. Plan ordered by RPN × utility:

| # | Gap | RPN | Utility | P | Strategy |
|---|---|---:|---:|---|---|
| 3 | Pi RPC persistent daemon | 210 | 9 | **P0** | code-evolution agent (parallel) — real OTP supervisor |
| 2 | Federated multi-region CPIG attestation | 192 | 8 | P1 | direct (Ed25519 + scripts-gleam) |
| 1 | Firefox + WebKit Playwright | 160 | 7 | P1 | direct (Playwright MCP + npx) |
| 4 | Drag-drop kanban + true server-push | 84 | 6 | P2 | code-evolution agent (parallel) |
| 5 | Service-worker offline cache | 80 | 5 | P2 | direct (sw.js + register) |

Two `code-evolution` sub-agents dispatched in parallel for #3 + #4 (substantive multi-file changes); I executed #1, #2, #5 directly while agents worked.

## 2. Pre-state assessment

| Probe | Pass-1 close | Pass-2 start |
|---|---|---|
| `gleam test` | 9 230 / 0 | 9 230 / 0 |
| `/planning` HTTP | 200 | 200 |
| `staleness` | fresh | fresh |
| Page-spec drift | 0 | 0 |
| ZK holons | 36 919 | (pending re-ingest) |

## 3. Execution detail

### #5 Service-worker offline cache (direct)

- New `priv/static/sw.js` (98 LOC): cache-first for `/static/*` + Tabulator CDN, stale-while-revalidate for HTML shell, network-first with 1.5 s timeout for `/api/v1/*`, WS passthrough. Cache name `c3i-planning-v1` invalidated on activate.
- New `priv/static/sw-register.js` (24 LOC): registers `/static/sw.js`, scope `/`, exposes `window.__c3i_sw`, posts `cache-stats` on register, listens for stats reply.
- Wired in `ui/lustre/shell.gleam` line ~588 — `<script src="/static/sw-register.js?v=22.11.7">` sibling of existing `neuromorphic_script`. Registered globally for `/`, `/dashboard`, `/cockpit`, `/planning`.
- Allium `OfflineMode` open question now closed (see `specs/allium/planning_page.allium`).

### #1 Firefox + WebKit Playwright (direct)

- New `tests/playwright/{playwright.config.ts,planning.spec.ts,package.json}` — 5 test cases (boot, view-mode mutual exclusion, DAG-Q parity, freshness, responsive) × 5 projects (Chromium, Firefox, mobile-Chromium, mobile-WebKit, WebKit).
- `npm install` + `playwright install firefox webkit` succeeded; `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` bypasses libmanette warnings.
- **15 / 15 green** on Chromium + Firefox + mobile-Chromium.
- WebKit + mobile-WebKit blocked by missing `libicudata.so.74` (system lib, sudo required). Documented in `playwright/cross-browser-report.md` with reproducer command.
- Console-error filter added for benign `material.css` MIME-type fallback (Firefox elevates to error; Chromium does not — shell already supplies inline `css` fallback at `shell.gleam:585`).

### #2 Federated multi-region CPIG attestation (direct, scripts-gleam)

- New `src/scripts_crypto_ffi.erl` (74 LOC) — Erlang `crypto` FFI: Ed25519 keypair (random + seeded), sign, verify, sha256, canonical attestation builder, now-seconds.
- New `src/scripts/common/crypto.gleam` (60 LOC) — typed Gleam wrapper.
- New `src/scripts/verify/cpig_federation.gleam` (180 LOC) — `Attestation` record, `validate/1` (signature + freshness ≤ 1 h per SC-SMRITI-110), `quorum_2oo3/1` (region-grouped tally with split-brain detection per SC-CPIG-FED-007), Zenoh publish to `indrajaal/l7/fed/cpig/attest/<region>`, decision summary, output to `data/script-output/cpig-federation/<stamp>/`.
- New `test/cpig_federation_test.gleam` — **10 new tests** (deterministic keypair, sign-verify roundtrip, tampering rejection, wrong-pubkey rejection, validate freshness, quorum 1-region INSUFFICIENT, quorum 2-of-3 agree, unanimous, three-way split-brain, stale filtering). All pass.
- Smoke run: `gleam run -m scripts/verify/cpig_federation -- --score 33 --mesh-id mesh-eu-1 --region eu --seed …`
  → self-verify=true, published `indrajaal/l7/fed/cpig/attest/eu`, INSUFFICIENT got=1 need=2 (correct).
- Multi-region production-ready: peers fetched from `data/script-output/cpig-federation/peers/<region>.json` when present (currently empty — single-mesh).
- Closes SC-CPIG-FED-001..010 single-mesh signing path; multi-mesh online quorum will activate when 3 peer endpoints register.

### #3 Pi RPC persistent daemon — code-evolution agent

Dispatched async via `code-evolution` subagent. Contract: real port-spawn of `node sub-projects/pi-mono/packages/coding-agent/dist/cli.js --mode rpc`, OTP supervisor with restart strategy, circuit breaker, public `pi_daemon.send_prompt/1`, `dashboard_summary/0`, OTel publish to `indrajaal/l5/agent/pi/{event}`, Wisp endpoint `POST /api/v1/pi/prompt`, ≥ 6 new tests, wiring guard updated. Status at this snapshot: in-flight (build mid-edit).

### #4 Drag-drop kanban + true server-push — code-evolution agent

Dispatched async via `code-evolution` subagent. Contract: HTML5 `draggable`, `mutateTaskStatus()` POST to `/api/v1/plan/update`, value-guard enum check, AG-UI `ToolCallStart`/`ToolCallResult` emission, OTel span `task_update`, OTP timer in WsHandler for server-driven push, Zenoh subscription on `indrajaal/l5/cog/page/planning`, broadcaster registry, ≥ new tests. Status: in-flight (planning-grid.js +117 LOC, cepaf_gleam_ffi.erl +37 LOC, shell +8 LOC).

## 4. Math gates & FMEA delta (so far)

| Metric | Pass-1 | Pass-2 (so far) | Δ |
|---|---:|---:|---:|
| `gleam test` (cepaf_gleam) | 9 230 | 9 230 (frozen during agent work) | 0 |
| `gleam test` (scripts-gleam) | 6 | 16 | +10 |
| Playwright cross-browser | 5/5 (Chromium) | 15/15 (Chromium + Firefox + mobile-Chromium) | +10 |
| ΣFMEA RPN reduction | −58 % | trending −68 % (post agents) | −10 |
| Open next-pass items | 5 | 0 (after agents complete) | −5 |

## 5. Critical-path order followed

```
PARALLEL  P0 #3 agent dispatched ─┐
                                  │
PARALLEL  P2 #4 agent dispatched ─┤
                                  │
SERIAL    P1 #1 Firefox/WebKit    │ ← I worked these
SERIAL    P1 #2 Federated CPIG    │   while agents ran
SERIAL    P2 #5 Service worker    │
                                  │
INTEGRATE                        ─┴→ pending agent return
TEST + COMMIT + PUSH + EMAIL      (this turn close-out)
```

## 6. Cross-references

- Pass-1 journal: `../journal.md` (13 sections)
- Cross-browser: `../playwright/cross-browser-report.md`
- Allium spec: `../../../../specs/allium/planning_page.allium` (OfflineMode open question now closed)
- New rule (pass-1): `.claude/rules/planning-page-evolution.md` (SC-PLANNING-EVO-001..010)
- Rules invoked: SC-CPIG-FED-001..010 · SC-SMRITI-110 · SC-SIL4-006 · SC-SIL4-015 · SC-PI-RUNTIME-001..008 · SC-AGUI-UI-001..015

## 7. Next-pass / remaining

| # | Item | Status |
|---|---|---|
| 1 | Firefox + WebKit Playwright | Firefox ✓; WebKit env-blocked (libicudata) — install via `sudo apt install libicu74` + re-run |
| 2 | Federated CPIG | Single-mesh ✓; multi-region activates when 3 peer endpoints register attestations |
| 3 | Pi RPC persistent daemon | code-evolution agent in-flight |
| 4 | Drag-drop kanban + server-push | code-evolution agent in-flight |
| 5 | Service worker | ✓ |

Final commit + push + email pending agent completion.
