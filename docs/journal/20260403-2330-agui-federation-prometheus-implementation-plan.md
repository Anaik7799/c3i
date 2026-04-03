# Journal: AG-UI SSE + L7 Federation + PROMETHEUS Proof Implementation Plan

**Date**: 2026-04-03 23:30 CEST
**Author**: Claude Opus 4.6
**Version**: v21.5.0-GLM
**Scope**: Three critical UI gaps — AG-UI transport, L7 Federation, PROMETHEUS proof integration

---

## 1. Scope & Trigger

**Trigger**: Fractal analysis from v21.5.0-GLM identified three critical gaps:
1. AG-UI SSE transport at 29% SC-AGUI compliance
2. L7 Federation triple-interface at 0/3 coverage
3. PROMETHEUS proof UI at 14% SC-PROM compliance

**Scope**: 14 files (6 modify, 5 create, 3 test files), ~1,220 lines across 5 implementation batches.

**Constraint References**: SC-AGUI-001..017, SC-GLM-UI-001..010, SC-FED-001..006, SC-PROM-001..007, SC-FRACTAL-001..008

---

## 2. Pre-State Assessment

| Area | Current State | Target |
|------|--------------|--------|
| AG-UI SSE | 32 events defined, router returns raw Strings, no HTTP headers, no query parsing, missing HITL/tool POST endpoints | Full Wisp HTTP handler with SSE headers, query parsing, all POST endpoints |
| L7 Federation | Types in `fractal/l7_federation.gleam`, no Page enum variant, no Lustre/Wisp/TUI | Full triple-interface: Lustre MVU + Wisp JSON + TUI ANSI + router registration |
| PROMETHEUS | ProofToken/GraphCheck/VerificationDag exist but not surfaced to UI, swarm covers 3/8 layers | Extended verification UI with proof display, DAG stats, graph checks, all 8 layers |

---

## 3. Execution Detail — Implementation Plan

### Batch 0: Foundation (must come first)

#### 0.1 Add `Federation` to Page enum
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam`
- Add `Federation` variant to `Page` type
- Add `Federation -> "/federation"` to `page_to_path()`
- Add `Federation -> "Federation (L7)"` to `page_to_label()`
- Gleam compiler enforces exhaustive matching — will flag every incomplete case in codebase

#### 0.2 Extend SwarmReport to all 8 layers
**File**: `lib/cepaf_gleam/src/cepaf_gleam/verification/swarm.gleam`
- Extend `generate_report()` from 3 layers (L0, L1, L4) to all 8 (L0-L7)

---

### Batch 1: AG-UI SSE Wiring (Work Stream 1)

#### 1.1 Add Wisp HTTP handler to router
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam` (~200 lines added)
- `pub fn handle_request(req: wisp.Request) -> wisp.Response` — main Wisp handler
- Dispatch on `wisp.path_segments(req)` + `req.method` (Get/Post)
- `parse_run_config(req)` extracts `agent`, `thread_id` from `wisp.get_query(req)`
- `sse_response(body)` sets `content-type: text/event-stream`, `cache-control: no-cache`, `connection: keep-alive`
- New endpoints:
  - `GET /ag-ui/events` → SSE stream with proper headers
  - `POST /ag-ui/run` → start run, return run_id JSON
  - `POST /ag-ui/hitl/respond` → process HITL approval/rejection
  - `GET /ag-ui/hitl/pending` → list pending approval IDs
  - `POST /ag-ui/tools/result` → submit tool result
  - `GET /ag-ui/state` → SharedState snapshot

#### 1.2 Add agent-aware SSE stream
**File**: `lib/cepaf_gleam/src/cepaf_gleam/agui/sse.gleam` (~80 lines added)
- `create_sse_stream_for_agent(agent, thread_id, run_id, query)` → SSE with Custom event for agent metadata
- `create_run_response(agent, thread_id, run_id)` → JSON for POST /ag-ui/run

#### 1.3 Add HITL listing and JSON serialization
**File**: `lib/cepaf_gleam/src/cepaf_gleam/agui/tools.gleam` (~30 lines added)
- `pending_call_ids(registry)` → List(String)
- `call_state_to_json(call)` → json.Json
- `pending_calls_to_json(registry)` → json.Json array

---

### Batch 2: L7 Federation Triple-Interface (Work Stream 2)

#### 2.1 Create Lustre Federation page
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/federation.gleam` (~90 lines, NEW)
- `FederationModel` = `{ state: Option(FederationState), loading: Bool, error: Option(String) }`
- `FederationMsg` = StateReceived | PeerAdded | PeerRemoved | VersionIncremented | RefreshFederation | ErrorReceived
- `init()`, `update()`, `connected_count()`, `all_attested()`

#### 2.2 Create Wisp Federation API
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/federation_api.gleam` (~75 lines, NEW)
- `federation_status_json(state)` → JSON with local_id, peer_count, connected_count, all_attested, version_vector, peers
- `peer_list_json(peers)` → JSON array

#### 2.3 Create TUI Federation view
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/federation_view.gleam` (~85 lines, NEW)
- `render(model)` → ANSI string with header, peer table, version vector, attestation status
- Color coding: Connected=green, Disconnected=red, Suspected=yellow

#### 2.4 Register Federation routes
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam` (+15 lines)
- Add `/api/v1/federation` route + `federation_json()` handler

---

### Batch 3: PROMETHEUS Proof UI Connection (Work Stream 3)

#### 3.1 Extend Verification Lustre model
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/verification.gleam` (+60 lines)
- Extend `VerificationModel` with: `latest_proof`, `graph_checks`, `dag_node_count`, `dag_edge_count`, `proof_history`
- Add `VerificationMsg` variants: ProofGenerated, GraphChecksCompleted, DagUpdated
- Add helpers: `all_checks_passed()`, `latest_proof_verified()`

#### 3.2 Extend Verification Wisp API
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/verification_api.gleam` (+80 lines)
- `proof_token_json()`, `dag_status_json()`, `graph_checks_json()`
- Fix `compliance_percent` dead code bug

#### 3.3 Extend Verification TUI view
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/verification_view.gleam` (+60 lines)
- `render_proof()`, `render_graph_checks()`, `render_dag_stats()`

#### 3.4 Add verification sub-routes
**File**: `lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam` (+15 lines)
- `/api/v1/verification/proofs`, `/api/v1/verification/dag`, `/api/v1/verification/checks`

---

### Batch 4: Tests

| Test File | Lines | Coverage |
|-----------|-------|----------|
| `test/agui_router_test.gleam` | ~120 | SSE headers, query parsing, HITL, 404s, tool serialization |
| `test/federation_triple_test.gleam` | ~140 | Lustre MVU, Wisp JSON, TUI ANSI, domain, router |
| `test/verification_wiring_test.gleam` | ~130 | Extended model, proof/DAG/check JSON, TUI rendering, 8-layer swarm |

---

## 4. Root Cause Analysis

### Why these gaps exist:
1. **AG-UI SSE**: Protocol layer (events, state, tools) was built first as pure functions returning Strings. HTTP transport integration was deferred — the router was designed as a String-returning dispatch table, not a Wisp handler.
2. **L7 Federation**: Fractal layer types were implemented bottom-up (l0→l7) but UI modules were built for the most-used layers first (immune, zenoh, planning). Federation was lowest priority.
3. **PROMETHEUS**: Verification engine was built as standalone proof system. UI integration was partial — swarm report was connected but ProofToken and GraphCheck were not surfaced.

---

## 5. Fix Taxonomy

| Change | Type | Impact |
|--------|------|--------|
| Batch 0 | Foundation | L1-CODE — enables all downstream work |
| Batch 1 | Transport integration | L2-DOMAIN — connects protocol to HTTP |
| Batch 2 | New feature | L2-DOMAIN — completes triple-interface for last layer |
| Batch 3 | Wiring + bug fix | L2-DOMAIN — connects existing proof system to UI |
| Batch 4 | Tests | L1-CODE — validates all changes |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns to Follow
- Immune module is canonical triple-interface pattern (import domain types, Model/Msg/init/update, json.object() pipeline, visuals.with_color())
- Router uses case-match dispatch on path strings — simple to extend
- All modules have C3I-SIL6-MSTS headers with STAMP constraint references

### Anti-Patterns Found
- Router returns String not wisp.Response — breaks HTTP semantics
- `compliance_percent` dead code bug in verification_api.gleam (computed value discarded, always returns 0.0)
- SSE stream hardcodes event sequence, ignores query params

---

## 7. Verification Matrix

| Batch | Verification | Gate |
|-------|-------------|------|
| 0 | `gleam build` — compiler enforces exhaustive match | 0 errors |
| 1 | `gleam test` — agui_router_test.gleam | 15 tests pass |
| 2 | `gleam test` — federation_triple_test.gleam | 19 tests pass |
| 3 | `gleam test` — verification_wiring_test.gleam | 22 tests pass |
| ALL | `gleam build && gleam test` | 0 errors, 0 failures |

---

## 8. Files Modified

| # | File | Action | WS | Est. Lines |
|---|------|--------|-----|-----------|
| 1 | `ui/domain.gleam` | Modify | 2 | +10 |
| 2 | `verification/swarm.gleam` | Modify | 3 | +30 |
| 3 | `ui/wisp/router.gleam` | Modify | 1+2+3 | +230 |
| 4 | `agui/sse.gleam` | Modify | 1 | +80 |
| 5 | `agui/tools.gleam` | Modify | 1 | +30 |
| 6 | `ui/lustre/federation.gleam` | Create | 2 | ~90 |
| 7 | `ui/wisp/federation_api.gleam` | Create | 2 | ~75 |
| 8 | `ui/tui/federation_view.gleam` | Create | 2 | ~85 |
| 9 | `ui/lustre/verification.gleam` | Modify | 3 | +60 |
| 10 | `ui/wisp/verification_api.gleam` | Modify | 3 | +80 |
| 11 | `ui/tui/verification_view.gleam` | Modify | 3 | +60 |
| 12 | `test/agui_router_test.gleam` | Create | 1 | ~120 |
| 13 | `test/federation_triple_test.gleam` | Create | 2 | ~140 |
| 14 | `test/verification_wiring_test.gleam` | Create | 3 | ~130 |
| | **TOTAL** | | | **~1,220** |

---

## 9. Architectural Observations

- **Router is the convergence point**: All 3 work streams modify `router.gleam`. Careful sequencing needed.
- **Gleam exhaustive matching is a safety net**: Adding `Federation` to `Page` will trigger compiler errors everywhere the Page type is matched without handling it. This ensures no missed cases.
- **Pure function architecture**: All AG-UI, fractal, verification modules are pure functions. State is managed by the caller (Lustre model or Elixir GenServer). This makes testing straightforward.
- **Wisp 2.2.2 provides all needed HTTP primitives**: `wisp.json_response()`, `wisp.get_query()`, `wisp.path_segments()`, `wisp.require_method()`, `wisp.read_body_to_bitstring()`.

---

## 10. Remaining Gaps

After this plan completes, the following will remain:
1. **AG-UI streaming**: SSE returns complete string, not true streaming. Requires Mist-level integration for chunked transfer.
2. **AG-UI multi-agent coordination**: No cross-agent event distribution. Requires Zenoh bus integration.
3. **AG-UI event ordering**: No happens-before ordering enforcement.
4. **SC-HMI progressive disclosure**: Dark Cockpit mode not wired to all pages.
5. **Domain type unification**: Fractal layers still don't import ui/domain.gleam.

---

## 11. Metrics Summary

| Metric | Before | After (Expected) |
|--------|--------|-------------------|
| SC-AGUI compliance | 29% (5/17) | ~47% (8/17) |
| L7 Federation triple-interface | 0/3 | 3/3 |
| SC-PROM compliance | 14% (1/7) | ~43% (3/7) |
| Swarm layer coverage | 3/8 | 8/8 |
| Triple-interface completeness | 7/8 layers | 8/8 layers |
| New test assertions | 0 | ~56 |

---

## 12. STAMP & Constitutional Alignment

- **SC-GLM-UI-001**: Triple-Interface Mandate — L7 Federation completes 8/8 layers
- **SC-AGUI-001..004**: AG-UI protocol transport, SSE, RFC 6902, HITL — wired to HTTP
- **SC-FED-001, SC-FED-006**: Federation attestation — surfaced in UI
- **SC-PROM-001**: PROMETHEUS proof verification — connected to verification UI
- **SC-FRACTAL-001**: Genotype topology — swarm report covers all 8 layers
- **Psi-3 (Verification)**: Proof tokens visible in UI enable human verification
- **SC-FUNC-001**: Gleam build must compile clean after every batch

---

## 13. Conclusion

This plan addresses the three most critical UI gaps identified in the v21.5.0-GLM fractal analysis. Implementation is organized into 5 batches with clear dependencies. Batch 0 (foundation) must come first due to Gleam's exhaustive match enforcement. Batches 1-3 can proceed in parallel. The total effort is ~1,220 lines across 14 files, with verification at each batch via `gleam build && gleam test`.

Expected SIL-6 compliance improvement: AG-UI 29%→47%, PROMETHEUS 14%→43%, L7 Federation 0/3→3/3.
