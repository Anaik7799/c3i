# Deep Production Hardening: Source-Level Gap Analysis & Operational Workflows

**Date**: 2026-04-05 20:43 UTC+0530
**Author**: Claude Opus 4.6 (operator-assisted)
**Session Duration**: ~20 minutes (continuation of 20260405-2036 session)
**STAMP References**: SC-ZMOF-001, SC-ARCH-SPLIT-001, SC-GLM-UI-001..010, SC-AGUI-001..017, SC-API-001..010, SC-SEC-001, SC-SIL4-006, SC-SAFETY-001..022, SC-ZENOH-001, SC-NIF-001, SC-CNT-001, SC-EMR-057, SC-LOG-001
**Predecessors**: `20260405-2036`, `20260405-2024`, `20260405-2007`

---

## 1. Scope & Trigger

Deep comprehensive pass on production robustness, reading actual source code to identify exact gaps between allium behavioral specs and current Gleam implementation. Focus on production-grade operational utility for the WebUI.

**Trigger**: Operator requested "one more pass, focus on robustness and webui with production grade operational utility. Think deep and be more comprehensive."

---

## 2. Pre-State Assessment

Previous pass created `webui_operational_control.allium` (749 lines) with contracts and invariants. This pass examines **what the source code actually does** vs what the spec says it should do.

### Source Files Read in Detail

| File | Lines | What It Does | Production Gap |
|------|-------|-------------|----------------|
| `ui/wisp/router.gleam` | 1,022 | 40+ GET endpoints, path string matching, static JSON | **100% read-only, zero mutations** |
| `ui/wisp/podman_api.gleam` | 68 | `containers_json()`, `system_info_json()` | **Read-only serialization only** |
| `ui/wisp/metabolic_api.gleam` | 69 | `status_json()`, `homeostasis_controls_json()` | **Pure encoder, no state** |
| `ui/wisp/verification_api.gleam` | 178 | Swarm report, DAG, graph checks JSON | **Rich encoders, no live data** |
| `agui/sse.gleam` | 134 | `create_sse_stream()` → String concatenation | **Pre-generated, not streamed** |
| `agui/zenoh_bus.gleam` | 59 | `publish_event()`, `broadcast_state()`, `send_to_agent()` | **Calls stubbed FFI** |
| `fractal/l0_constitutional.gleam` | 284 | ApprovalState, ConsensusState, EmergencyState, 2oo3 voting | **Complete types, zero wiring** |
| `fractal/l4_system.gleam` | 202 | RunMonitorState, step tracker, JSON encoder | **AG-UI run tracking, no container ops** |
| `cepaf_gleam_ffi.erl` | 265+ | `os_cmd/1`, `zenoh_put/3` → `{ok, nil}` | **Zenoh FFI is a no-op stub** |
| `ui/domain.gleam` | 166+ | Page, HealthStatus, Action, RenderContext types | **Good foundation, not enough action types** |

---

## 3. Execution Detail

### 6 Source-Level Gaps Identified and Specified

| GAP | File | Severity | RPN | Description |
|-----|------|----------|-----|-------------|
| GAP-001 | router.gleam | P0 | — | Router is 100% GET — zero POST/PUT/DELETE endpoints |
| GAP-002 | router.gleam | P1 | 189 | All API data hardcoded — not from Zenoh or real state |
| GAP-003 | sse.gleam | P1 | 120 | SSE is string concatenation, not Mist chunked streaming |
| GAP-004 | cepaf_gleam_ffi.erl | P0 | **720** | Zenoh FFI stubbed — `zenoh_put` returns `{ok, nil}` silently |
| GAP-005 | l0_constitutional.gleam | P0 | — | Complete type system (284 lines) but zero endpoint wiring |
| GAP-006 | podman_api.gleam | P1 | — | Read-only — no mutation request/response codecs |

**GAP-004 is the critical path blocker** — RPN 720 (Severity 9 x Occurrence 10 x Detection 8). Every Zenoh-dependent feature is silently non-functional because the FFI returns success without doing anything.

### 4 Operational Workflows Specified

| Workflow | Steps | SLA | Error Paths |
|----------|-------|-----|-------------|
| ContainerStart | 9 steps: button → POST → MoZ → Rust → Podman → SSE | < 10s | Timeout, partition, podman failure, concurrent |
| EmergencyStop | 10 steps: button → HITL modal → Guardian 2oo3 → MoZ → apoptosis | < 5s (SC-SAFETY-022) | Rejection, timeout, partial failure |
| DashboardMonitoring | 8 steps: SSR → EventSource → Zenoh subscribe → push → DOM | Continuous | JS disabled, SSE timeout, Zenoh partition |
| OODAVisualization | 5 steps: L5 tab → SSE ooda_cycle_tick → ring animation | Real-time | Degraded OODA latency |

### 7 Production Hardening Rules Specified

Rate limiting (30 RPM), authentication (bearer token for mutations), request body size (64KB), structured errors (STAMP ref in every error), CORS, request timeout (30s), audit trail (OTel + Zenoh).

### MCP Tool Catalog Alignment

Mapped 8 Rust tools from `mcp_bridge.rs` to 8 Gleam client methods with exact JSON-RPC 2.0 format and topic templates.

### Files Created/Updated

| File | Action | Lines |
|------|--------|-------|
| `specs/allium/webui_production_hardening.allium` | CREATED | 543 |
| `specs/allium/gleam_webui_comprehensive.allium` | UPDATED | 1,026 → 1,046 (+20) |

---

## 4. Root Cause Analysis

### RCA: Why Zenoh FFI is Stubbed (GAP-004, RPN 720)

- **Why does `zenoh_put` return `{ok, nil}`?** The FFI was written before `zenoh_nif.so` was available in the Gleam build.
- **Why wasn't it wired later?** The Gleam test suite (2,677 tests) passes with stubs — no test asserts real Zenoh delivery.
- **Why no test asserts real delivery?** `zenoh_test_observer.gleam` exists but uses the same stubbed FFI — it "observes" stubs.
- **Why was this not caught?** The system returns `{ok, nil}` — success. No error, no warning, no log. Silent failure.
- **Root cause**: Stub FFI returns success type, masking total non-functionality. No integration test verifies end-to-end Zenoh delivery from Gleam.

### RCA: Why Router Has Zero Mutations

- **Why no POST endpoints?** The router was built as a read-only dashboard API (Phase 1 of Gleam migration).
- **Why no Phase 2?** The IUFO plan (20260405-1510) is the first to specify mutation capability.
- **Root cause**: Gleam WebUI was designed as observation-only. Container control was delegated to Rust CLI (`sa-up`) and TUI. WebUI mutation is a new architectural capability not yet implemented.

---

## 5. Fix Taxonomy

| Fix | Type | Files | Effort |
|-----|------|-------|--------|
| GAP-004: Wire Zenoh FFI | Integration | `cepaf_gleam_ffi.erl` | 1 day |
| GAP-001: Router mutations | New Feature | `router.gleam` + new `podman_action_handler.gleam` | 2 days |
| GAP-005: L0 Guardian wiring | Integration | `router.gleam` + `l0_constitutional.gleam` | 1 day |
| GAP-003: SSE chunked | Enhancement | `agui/sse_stream.gleam` (new) | 1-2 days |
| GAP-002: Live data | Enhancement | `ui/state.gleam` (new) + router refactor | 2 days |
| GAP-006: Podman codecs | Enhancement | `podman_api.gleam` | 0.5 day |

---

## 6. Patterns & Anti-Patterns Discovered

### Anti-Patterns (Critical)
- **Silent stub success**: Returning `{ok, nil}` from unimplemented FFI is the most dangerous pattern in this codebase. It makes 2,677 tests pass while core functionality is broken. **Fix**: Stubs should return `{error, <<"not_implemented">>}` or be feature-flagged.
- **Hardcoded demo data in production paths**: `planning_json()` returns specific task IDs as if they're real. An operator reading the API would believe these tasks exist. **Fix**: Return `{error, "not_connected"}` or empty arrays when no real data source is available.

### Patterns (Positive)
- **L0 type system is well-designed**: `l0_constitutional.gleam` has exactly the right abstractions — ApprovalRequest/Decision/Severity, ConsensusState with 2oo3 voting, EmergencyState with arm/trigger/reset. The types are correct; only wiring is missing.
- **Verification API is rich**: `verification_api.gleam` (178 lines) has proper type-safe JSON encoding for swarm reports, PROMETHEUS proof tokens, DAG status, graph checks. This is the quality bar for all API modules.

---

## 7. Verification Matrix

| Check | Method | Result |
|-------|--------|--------|
| New allium spec follows TEMPLATE | Visual inspection | PASS |
| SC-ALLIUM-002 header | `-- allium: 3` on line 1 | PASS |
| Gaps reference real file:line | Cross-checked with source reads | PASS |
| FMEA RPNs calculated correctly | S x O x D formula verified | PASS |
| Workflows cover happy + error paths | Each has steps + error_paths | PASS |
| MCP tool catalog matches Rust | Verified against mcp_bridge.rs:51-120 | PASS |
| Production rules have STAMP refs | Each rule references SC-* constraint | PASS |
| Cross-references in comprehensive spec | §27 added with file pointers | PASS |

---

## 8. Files Modified

| File | Action | Lines Changed |
|------|--------|---------------|
| `specs/allium/webui_production_hardening.allium` | CREATED | 543 lines |
| `specs/allium/gleam_webui_comprehensive.allium` | UPDATED | +20 lines (§27 cross-references) |

---

## 9. Architectural Observations

### 9.1 The Zenoh FFI Stub is a System-Wide Defect

GAP-004 (RPN 720) is not just a WebUI problem — it affects everything in the Gleam codebase that uses Zenoh:
- `agui/zenoh_bus.gleam` — all AG-UI event publishing is silently no-op
- `ui/zenoh_otel.gleam` — all OTel span publishing is silently no-op
- Any future MoZ mutation transport — would silently no-op
- Test observer (`zenoh_test_observer.gleam`) — "observes" nothing

Fixing GAP-004 is the single highest-impact change possible. Everything else depends on it.

### 9.2 The Implementation Dependency Graph is Linear

```
GAP-004 (Zenoh FFI) → GAP-002 (Live Data) → GAP-003 (SSE) → Dashboard Monitoring
                    → GAP-001 (Router Mutations) → GAP-006 (Codecs) → GAP-005 (L0 HITL) → Emergency Stop
```

This is good news: it's a linear chain, not a web. Each gap has exactly one predecessor. The critical path is 7-10 days from GAP-004 to full Emergency Stop capability.

### 9.3 The Type System is Ahead of the Wiring

The Gleam type system is well-designed:
- `l0_constitutional.gleam`: 284 lines of correct L0 types
- `l4_system.gleam`: 202 lines of run monitoring types
- `ui/domain.gleam`: 166+ lines of shared domain types
- `agui/events.gleam`: 582 lines of AG-UI 32-event types
- `verification/*.gleam`: 383 lines of verification types

Total: ~1,600+ lines of production-quality type definitions waiting to be wired. The types ARE the spec — they just need endpoints, SSE, and Zenoh.

---

## 10. Remaining Gaps

| Gap | Priority | RPN | Blocks | Effort |
|-----|----------|-----|--------|--------|
| GAP-004: Zenoh FFI wiring | P0 | 720 | Everything | 1 day |
| GAP-001: Router POST endpoints | P0 | — | Container control | 2 days |
| GAP-005: L0 Guardian HITL wiring | P0 | — | Emergency stop | 1 day |
| GAP-002: Live data from Zenoh | P1 | 189 | Accurate dashboard | 2 days |
| GAP-003: SSE chunked streaming | P1 | 120 | Real-time updates | 1-2 days |
| GAP-006: Podman mutation codecs | P1 | — | Clean API contract | 0.5 day |
| Auth for mutations | P1 | 18 | Production deployment | 1 day |
| Rate limiting | P2 | — | DoS protection | 0.5 day |
| Request validation | P2 | — | Input safety | 0.5 day |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Allium files created | 1 (`webui_production_hardening.allium`, 543 lines) |
| Allium files updated | 1 (`gleam_webui_comprehensive.allium`, +20 lines) |
| Total allium corpus | 5,602 lines across 15 files (was 5,039, +563) |
| Source-level gaps identified | 6 (GAP-001 to GAP-006) |
| FMEA entries added | 4 (incl. RPN 720 critical) |
| Operational workflows specified | 4 (ContainerStart, EmergencyStop, Dashboard, OODA) |
| Production hardening rules | 7 (rate limit, auth, body size, errors, CORS, timeout, audit) |
| MCP tools aligned | 8 Rust ↔ 8 Gleam methods |
| Open questions | 3 (ETS vs Actor, proof token, session state) |
| Critical path to production WebUI | 7-10 days (GAP-004 first) |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Finding |
|------------|---------|
| SC-ZMOF-001 (Zenoh sole transport) | **VIOLATED** — Zenoh FFI is stubbed (GAP-004, RPN 720) |
| SC-GLM-UI-001 (Triple interface) | PARTIAL — Lustre SSR + Wisp GET work, mutations missing |
| SC-GLM-ZEN-001 (OTel via Zenoh) | **VIOLATED** — zenoh_put is no-op, spans never publish |
| SC-ARCH-SPLIT-001 (Gleam intent, Rust action) | COMPLIANT in spec, not yet in code |
| SC-SIL4-006 (2oo3 for actuations) | Types exist (l0_constitutional.gleam), not wired to endpoints |
| SC-SAFETY-022 (Emergency stop < 5s) | Type exists (EmergencyState), no endpoint triggers it |
| SC-API-001 (Rate limiting) | Not implemented — specified in production hardening rules |
| SC-SEC-001 (Authentication) | Not implemented — specified in production hardening rules |
| SC-AGUI-002 (SSE streaming) | PARTIAL — SSE format correct but pre-generated, not chunked |

---

## 13. Conclusion

This deep pass revealed that the Gleam WebUI has **excellent type foundations** (~1,600 lines of production-quality types) but is **not production-ready** due to 6 concrete source-level gaps, the most critical being GAP-004 (Zenoh FFI stub, RPN 720) which silently makes all Zenoh-dependent features non-functional.

The allium corpus grew from 5,039 to 5,602 lines with a new 543-line production hardening spec that maps exact source code gaps to remediation steps, operational workflows with error paths, production rules, and MCP tool alignment.

**The single most important action is GAP-004**: wire `zenoh_put` in `cepaf_gleam_ffi.erl` to the real `zenoh_nif.so`. This unblocks everything — mutations, SSE, live data, and Guardian HITL. Estimated 1 day of work that enables 7-10 days of downstream features.

**Allium spec total**: 15 files, 5,602 lines — comprehensive behavioral specification for the full production WebUI control plane.
