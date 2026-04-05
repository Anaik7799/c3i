# Full System Robustness Review: 184 Modules, Rust Protocol Alignment (Pass 4)

**Date**: 2026-04-05 20:53 UTC+0530
**Author**: Claude Opus 4.6 (operator-assisted)
**Session Duration**: ~15 minutes (final pass of 4-pass series)
**STAMP References**: All SC-* families referenced in previous 3 passes plus SC-CIRCUIT-001..002, SC-DRK-001..004, SC-SEC-001..049
**Predecessors**: `20260405-2043`, `20260405-2036`, `20260405-2024`, `20260405-2007`

---

## 1. Scope & Trigger

Fourth and final comprehensive pass. Full system review of all 184 Gleam modules (30,930 LOC), exact Rust MCP wire protocol reverse-engineering, cross-cutting production gap analysis, graceful degradation matrix, and Wisp API completeness audit.

---

## 2. Pre-State Assessment

After 3 previous passes, allium specs covered contracts, invariants, 6 source gaps, 4 workflows, and FMEA. This pass identified what was still missing:
- **175 Gleam modules** not yet examined
- **Exact Rust MCP wire format** not documented
- **Cross-cutting concerns** (auth, degradation, circuit breaker integration) not specified
- **Cross-page state coordination** not addressed
- **Wisp API completeness** (40 GET endpoints, 0 mutations) not audited

---

## 3. Execution Detail

### New Gaps Identified (GAP-007 to GAP-012)

| GAP | Severity | RPN | Description |
|-----|----------|-----|-------------|
| GAP-007 | P0 | 10→180 | Auth completely missing — becomes critical when mutations ship |
| GAP-008 | P1 | — | `circuit_breaker.gleam` (93 lines, correct) is never invoked anywhere |
| GAP-009 | P1 | 180 | `dark_cockpit.gleam` (85 lines, correct) never receives real alerts |
| GAP-010 | P1 | 80 | 4 Lustre pages have no-op Msg handlers (buttons do nothing) |
| GAP-011 | P2 | 140 | Zenoh subscriptions in effects.gleam never unsubscribed on unmount |
| GAP-012 | P2 | 108 | Unbounded history growth in verification, dark_cockpit, L6, L7 |

### Rust MCP Protocol Documented

| Finding | Detail |
|---------|--------|
| Active tools | Only 3: `launch`, `restart`, `drain` (despite 6 in catalog) |
| `restart` bug | Only calls `stop_container()` — never starts the container back |
| Wire format | JSON-RPC 2.0 with `jsonrpc`, `method`, `params`, `id` fields |
| Error codes | `-32601` (method not found), `-32602` (invalid params), `-32000` (server error) |
| Node discovery | UUID per bridge instance — Gleam must subscribe to `*/heartbeat` to find it |
| Heartbeat | Every 1000ms, payload `"ALIVE"`, catalog republished each cycle |
| Proof tokens | **NOT validated** in mcp_bridge.rs — must be added to Rust first |

### Cross-Cutting Checklists (5 categories, all failing)

| Category | Score | Status |
|----------|-------|--------|
| Authentication | 0/5 | No sessions, no principals, no RBAC, no token validation |
| Error handling | 1/5 | Only planning/access_control uses Result patterns |
| Graceful degradation | 0/5 | Circuit breaker exists but never invoked |
| Rate limiting | 0/5 | No middleware anywhere |
| Subscription lifecycle | 1/5 | Subscribe works, unsubscribe missing |

### Graceful Degradation Matrix (5 failure scenarios)

Specified what happens when: Zenoh mesh down, database down, Rust ignition down, JavaScript disabled, OTel collector down. Each has: affected features, degradation behavior, recovery path, UI indicator.

### Wisp API Completeness

- **40 GET endpoints**: All working (read-only, hardcoded data)
- **7 POST endpoints missing**: podman/action, emergency/trigger, guardian/respond, hitl/respond, tools/result, homeostasis/threshold, ooda/trigger
- **4 SSE endpoints missing**: mesh, containers, ooda, guardian streams
- **Error handling missing**: All endpoints return `String`, no `Result`, no error variants

---

## 4. Root Cause Analysis

### RCA: Why Cross-Cutting Concerns Are Missing

- **Why no auth?** The WebUI was designed as a local development tool (localhost:4100), not a production service.
- **Why no rate limiting?** Same — local tool assumption. No adversarial threat model.
- **Why circuit breaker unused?** Written as a library module (prajna/), but no consumer was built to use it.
- **Root cause**: The Gleam WebUI was built bottom-up (types first, views second) without a top-down production deployment plan. The types are production-quality; the wiring is development-quality.

---

## 5. Fix Taxonomy

| Fix | Type | Effort |
|-----|------|--------|
| GAP-007: Auth middleware | New Feature | 1 day |
| GAP-008: Circuit breaker integration | Integration | 0.5 day |
| GAP-009: Dark cockpit alert wiring | Integration | 0.5 day |
| GAP-010: Lustre no-op handler fixes | Enhancement | 1 day |
| GAP-011: Subscription unsubscribe | Bug Fix | 0.5 day |
| GAP-012: Bounded history lists | Enhancement | 0.5 day |
| Rust MCP restart fix | Bug Fix (Rust) | 0.5 day |
| SharedMeshState GenServer | New Feature | 1 day |
| Graceful degradation wiring | New Feature | 2 days |

---

## 6. Patterns & Anti-Patterns Discovered

### Anti-Patterns (New)
- **Orphaned library modules**: `circuit_breaker.gleam` and `dark_cockpit.gleam` are correctly implemented but have zero consumers. The library pattern without integration is Muda (inventory waste).
- **Catalog/handler mismatch**: Rust publishes 6 MCP tools but only handles 3. Clients that trust the catalog will get `-32601` errors 50% of the time.
- **No-op Msg handlers**: Lustre update functions that return `model` unchanged create clickable buttons that silently do nothing — worse than not having the button.

### Patterns (Positive)
- **Module isolation is excellent**: Each of the 184 modules compiles independently. No import cycles found. This makes incremental wiring straightforward.
- **Type coverage is comprehensive**: 30,930 lines with strong typing. The gap is integration, not design.

---

## 7. Verification Matrix

| Check | Result |
|-------|--------|
| All 184 modules inventoried | PASS — 30,930 LOC |
| Rust MCP wire format documented | PASS — exact JSON-RPC 2.0 |
| All 3 active Rust tools specified | PASS — launch, restart, drain |
| 5 cross-cutting checklists assessed | PASS — 0/5, 1/5, 0/5, 0/5, 1/5 |
| 5 degradation scenarios specified | PASS — Zenoh, DB, Rust, JS, OTel |
| 40 GET endpoints cataloged | PASS |
| 7 missing POST endpoints identified | PASS |
| 4 missing SSE endpoints identified | PASS |
| GAP-007 to GAP-012 specified | PASS |
| Cross-references updated in all 3 companion specs | PASS |

---

## 8. Files Modified

| File | Action | Lines |
|------|--------|-------|
| `specs/allium/webui_full_system_robustness.allium` | CREATED | 616 |
| `specs/allium/webui_operational_control.allium` | UPDATED | +12 (cross-refs) |
| `specs/allium/webui_production_hardening.allium` | UPDATED | +7 (open question) |

---

## 9. Architectural Observations

### The WebUI Production Spec is Now Complete

Across 4 passes, we have created a 3-file production WebUI specification:

| File | Lines | Coverage |
|------|-------|----------|
| `webui_operational_control.allium` | 761 | Contracts, invariants, surfaces, FMEA |
| `webui_production_hardening.allium` | 550 | Source gaps (6), workflows (4), rules (7), MCP alignment |
| `webui_full_system_robustness.allium` | 616 | Full system (184 modules), Rust protocol, cross-cutting (6 gaps), degradation (5 scenarios), API completeness |
| **Total** | **1,927** | **Complete production WebUI behavioral specification** |

Plus updates to 3 existing specs (zmof, gleam_ui, gleam_webui_comprehensive): +91 lines.

### The 12-Day Roadmap

```
Day 0:   GAP-004 (Zenoh FFI) + GAP-007 (Auth)     ← Foundation
Day 1-3: GAP-001 (Router POST) + GAP-006 (Codecs) + GAP-008 (Circuit breaker)
Day 4:   GAP-005 (L0 Guardian HITL)
Day 5-6: GAP-003 (SSE chunked) + GAP-009 (Dark cockpit wiring)
Day 7-8: GAP-010 (Lustre handlers) + GAP-002 (Live data)
Day 9:   SharedMeshState GenServer + GAP-011 (Subscriptions) + GAP-012 (Bounds)
Day 10-12: Integration tests, load tests, chaos tests
```

---

## 10. Remaining Gaps

All 12 gaps (GAP-001 to GAP-012) are specified with exact file references, remediation steps, and STAMP alignment. No additional gaps were found. The specification is complete.

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Allium files created (this pass) | 1 (616 lines) |
| Allium files updated (this pass) | 2 (+19 lines) |
| Total allium corpus | **6,237 lines across 16 files** (was 4,216 at session start, **+48%**) |
| WebUI-specific specs | 3 files, 1,927 lines |
| Source gaps identified (total) | 12 (GAP-001 to GAP-012) |
| FMEA entries (total across all specs) | 18 |
| Operational workflows | 4 |
| Degradation scenarios | 5 |
| Wisp GET endpoints audited | 40 (all working) |
| Missing POST endpoints | 7 |
| Missing SSE endpoints | 4 |
| Gleam modules inventoried | 184 (30,930 LOC) |
| Rust MCP tools documented | 3 active (launch, restart, drain) |
| Open questions | 7 (consolidated from all 4 passes) |
| Critical path to production | 12 days |

---

## 12. STAMP & Constitutional Alignment

All constraints from passes 1-3 remain applicable. Additional:

| Constraint | Finding |
|------------|---------|
| SC-SEC-001 (Authentication) | **VIOLATED** — GAP-007, zero auth on port 4100 |
| SC-CIRCUIT-001 (Circuit breaker) | **VIOLATED** — GAP-008, module exists but never used |
| SC-DRK-001 (Dark cockpit) | **VIOLATED** — GAP-009, always Dark (no real alerts) |
| SC-GLM-UI-002 (MVU update handlers) | **VIOLATED** — GAP-010, 4 pages have no-op handlers |
| SC-ZENOH-005 (Session reconnect) | **VIOLATED** — GAP-011, subscriptions never cleaned up |
| SC-MUDA-001 (Zero waste) | **VIOLATED** — GAP-012, unbounded history growth |

---

## 13. Conclusion

This fourth pass completes the production WebUI behavioral specification. The allium corpus grew from 4,216 to 6,237 lines (+48%) across 4 sessions, with 3 new WebUI-specific specs totaling 1,927 lines.

Key findings from the full system review:
1. **184 Gleam modules, 30,930 LOC** — excellent type foundations, zero production wiring
2. **Rust MCP has only 3 active tools** (not 6 as catalog claims), and `restart` is broken (only stops)
3. **5 cross-cutting concerns score 0-1 out of 5** — auth, degradation, rate limiting, error handling, subscriptions
4. **Orphaned library modules** — circuit_breaker and dark_cockpit are correctly implemented but never invoked
5. **40 GET endpoints work, 0 POST endpoints exist** — WebUI is observation-only

The 12-day roadmap from GAP-004 (Zenoh FFI) through integration testing is now fully specified with FMEA, degradation scenarios, and exact Rust wire protocol alignment. The specification is complete — implementation can begin.
