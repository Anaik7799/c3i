# Real Data Wiring Gap Analysis — Ultrathink

**Date**: 2026-04-10
**STAMP**: SC-WIRE-001, SC-FUNC-002, SC-ULTRA-001
**Status**: CRITICAL GAP — Type wiring 100%, Real data 35%

## Operator Prompt (Preserved)

> add rete-ul and ruliology for all agentic UI fractal components across all
> fractal layers - ultrathink. think deep. are we picking real operations data
> from the system. also add and update all spec files

## The Hard Truth

**Type-level wiring: 100% (3,385 tests pass)**
**Real data flowing: ~35% (only 14+3 NIFs connected)**

The Gleam UI has correct types, correct init() functions, correct update() handlers,
correct Msg variants, correct renderers — but most pages display DEFAULT/EMPTY data
because no NIFs exist to fetch the real state from the Rust daemon.

## Gap Matrix: Real Data vs Mock by Fractal Layer

### L0 Constitutional
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| Guardian approval queue | MOCK | No NIF to query pending approvals from cortex |
| Psi invariant checks | MOCK | No NIF to run Psi-0..5 verification |
| Emergency stop state | MOCK | No NIF to check emergency halt status |

### L1 Atomic/Debug
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| OTel spans | MOCK | No NIF to query TransactionTrace from SQLite |
| Pipeline tracer | MOCK | `trace_recent(n)` needed |
| Rate limiting | MOCK | No NIF to query rate limit state |

### L2 Component
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| A2UI components | REAL | Rendered from type system (no external data needed) |

### L3 Transaction
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| Task CRUD | **REAL** | 7 NIFs connected (plan_status, plan_list, etc.) |
| Knowledge search | **REAL** | knowledge_search NIF connected |
| Conversation history | MOCK | `conversation_history(n)` needed |
| Semantic cache | MOCK | `cache_stats()` needed |

### L4 System
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| System health | **REAL** | 5 NIFs connected |
| Inference tier | MOCK | `inference_status()` needed |
| Container status | **REAL** | system_dashboard NIF |
| Voice pipeline | MOCK | `voice_status()` needed |
| HA election | MOCK | `ha_status()` needed |

### L5 Cognitive
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| Rule engine (RETE-UL) | **REAL** | 3 NIFs connected (evaluate, parse, version) |
| OODA cycle | MOCK | No NIF to query current OODA phase from cortex |
| FMEA report | MOCK | `fmea_report()` needed |
| Ruliology | MOCK | `ruliology_automaton()`, `ruliology_multiway()`, `ruliology_causal()` needed |

### L6 Ecosystem
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| Zenoh mesh | MOCK | No NIF to query active Zenoh sessions/topics |
| MCP tools | **REAL** | Via NIF system tools |

### L7 Federation
| Component | Real Data? | Missing NIF |
|-----------|-----------|-------------|
| Federation peers | MOCK | No NIF to query peer registry |
| Version vectors | MOCK | No NIF to query version state |

## Summary

| Category | Real | Mock | Coverage |
|----------|------|------|----------|
| NIFs connected | 17 | 0 | (existing 14+3 NIFs all work) |
| NIFs needed | 0 | 11 | (11 new NIFs required) |
| Pages with real data | 5 | 34 | **13%** of pages |
| Zenoh sessions | 0 | 5 | **0%** of agents |

## 11 New NIFs Required

| # | NIF Function | Rust Module | Returns | Layer |
|---|-------------|-------------|---------|-------|
| 1 | `inference_status()` | mcp_inference.rs | active_tier, model, latency, circuits | L4 |
| 2 | `trace_recent(n)` | trace.rs / db.rs | Last N TransactionSummary rows | L1 |
| 3 | `voice_status()` | gemini_live.rs | ws_connected, tier, transcription | L4 |
| 4 | `conversation_history(n)` | db.rs | Last N messages with role | L3 |
| 5 | `cache_stats()` | db.rs | entries, hit_rate, hits, misses | L3 |
| 6 | `fmea_report()` | fmea.rs | failure_modes with S,O,D,RPN | L5 |
| 7 | `ha_status()` | ha_election.rs | role, lease_ttl, missed_beats | L4 |
| 8 | `ruliology_automaton(name)` | ruliology.rs | states, current, step_count | L5 |
| 9 | `ruliology_multiway()` | ruliology.rs | nodes, branches | L5 |
| 10 | `ruliology_causal()` | ruliology.rs | nodes, edges, weights | L5 |
| 11 | `ooda_phase()` | cortex.rs | current_phase, cycle_count, latency | L5 |

## Zenoh Session Bootstrap Gap

All 5 agents initialize with `zenoh_session: None`. No code assigns a real session.
This means ALL AG-UI event emissions silently no-op.

**Fix**: The orchestrator (`cepaf_gleam.gleam` main function) must:
1. Open a Zenoh session via NIF
2. Pass the session to each agent's start() function
3. Agents store the session in their state

## Allium Spec Gap

The Allium spec at `specs/allium/ignition.allium` does NOT cover:
- Chat processing pipeline (cortex.rs)
- Voice processing pipeline (gemini_live.rs)
- PipelineTracer
- Inference tier cascade
- AG-UI event protocol

These need new Allium entities, rules, and contracts.

## Action Items (Priority Order)

1. **Add 11 NIFs to Rust c3i_nif** (exposes real data to Gleam)
2. **Bootstrap Zenoh session in main** (enables AG-UI event emission)
3. **Wire Lustre pages to NIFs** (replace init() defaults with NIF queries)
4. **Update Allium spec** (add chat/voice/trace entities)
5. **Update TLA+ specs** (add formal models for new NIFs)
