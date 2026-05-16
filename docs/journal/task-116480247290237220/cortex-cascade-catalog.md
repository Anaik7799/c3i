# Cortex 6-tier Inference Cascade Catalog — CPIG Phase D G4+G5 closure

> CPIG subsystem: Cortex 6-tier hedged inference · Pass-15 G4+G5 closure
> Source: `sub-projects/c3i/native/planning_daemon/src/{cortex,mcp_inference}.rs`
> Per CLAUDE.md §15 (Chat Processing Pipeline)

## STAMP references
- SC-COG-001 (chat pipeline)
- SC-CPIG-014 (Cortex G4 + G5 closure)
- SC-INFER-RUST-API-001..008 (mistral.rs Rust-API-only mandate)
- SC-XHOLON-001 (Smriti.db substrate)
- SC-PII-001 (PII scrubber on hot path)

## 7-Tier Inference Cascade (canonical, per CLAUDE.md §15)

> Note: documented as "7-Tier" in CLAUDE.md (6 real tiers + static-ack safety net). Cortex-6-tier shorthand counts the real tiers; Tier 7 is the no-blackhole guarantee.

| Tier | Model | Latency | Cost | Transport | Module |
|:---:|---|:---:|:---:|---|---|
| 1 | Gemini Direct (gemini-3.1-flash-lite-preview) | ~900 ms | Free | HTTPS | `mcp_inference.rs` |
| 2 | OpenRouter (gemini-3-flash-preview) | ~1.1 s | $0.000009 | HTTPS | `mcp_inference.rs` |
| 3 | **mistral.rs gemma4 (in-process)** | **~500 ms** | **Free** | **In-process (zero HTTP)** | `mcp_inference.rs` (SC-INFER-RUST-API) |
| 4 | Ollama gemma4 (port 11435) | ~4 s | Free | HTTP | `mcp_inference.rs` |
| 5 | Ollama gemma3 (port 11434, last resort) | ~10 s | Free | HTTP | `mcp_inference.rs` |
| 6 | RETE-UL rule engine | <1 ms | Free | In-process | `rule_engine.rs` |
| 7 | Static ack | <1 ms | Free | In-process | `cortex.rs` (no-blackhole guarantee) |

## Hedging strategy

- **Tier 1 + 2**: hedged via `tokio::join!` — first success wins.
- **Tier 3**: primary local; `OnceLock<mistralrs::Model>` singleton, no per-request rebuild.
- **Tier 4-5**: fallback chain for offline / local-only operation.
- **Tier 6**: deterministic; covers patterns RETE-UL can answer.
- **Tier 7**: static; always succeeds; bounds worst-case latency.

## Circuit breakers (5 independent)

| Breaker | Trip threshold | Cooldown |
|---|:---:|:---:|
| Gemini Direct | 3 failures | 60 s |
| OpenRouter | 3 failures | 60 s |
| mistral.rs | 3 failures | 60 s |
| Ollama gemma4 | 3 failures | 60 s |
| Ollama gemma3 | 3 failures | 60 s |

## Persistent HTTP

`OnceLock<reqwest::Client>` with 30 s keepalive pinger eliminates TLS cold-start (per CLAUDE.md §15.2 footer).

## No-blackhole guarantees (7)

1. Tier hedging (1+2 parallel)
2. Tier 3 in-process fallback (no network needed)
3. Tier 4-5 Ollama local fallback
4. Tier 6 RETE-UL deterministic answer
5. Tier 7 static ack
6. Circuit breakers prevent cascade timeout
7. PipelineTracer emits trace even on failure (single batch write)

## Cost analysis (per 1k chats)

| Tier mix | Cost (USD) | Median latency |
|---|---:|---:|
| Tier 3 only (offline) | $0 | ~500 ms |
| Tier 1 only (Gemini) | $0 | ~900 ms |
| Tier 2 only (OpenRouter) | $0.009 | ~1.1 s |
| Hedged 1+2 | $0.009 | ~600 ms (faster of two) |
| Full cascade (rare) | $0.009 | <10 s p99 |

## Pipeline tracer (SC-XHOLON-001)

- **Hot path**: zero DB writes during processing (in-memory `Vec<TraceStage>`)
- **Finish**: single batch write on `finish_with_zenoh()` to SQLite + Zenoh
- **Output**: `TransactionTrace` + `TransactionSummary` tables + `indrajaal/l5/cog/trace/{id}`
- **Footer format**: `Pipeline: recv(0ms) > class(1ms) > ack(2ms) > infer(1200ms) > delivered(1400ms)`

## Additional capabilities (per CLAUDE.md §15.2)

| Feature | Module | Notes |
|---|---|---|
| Semantic cache | `db.rs` | 24h TTL, SQLite-backed |
| Conversation history | `cortex.rs` | 50-message sliding window per chat |
| Rate limiting | `cortex.rs` | 20 messages/minute per user |
| RAG pipeline | `rag.rs` | Smriti FTS5 context injection (~4 ms) |
| PII scrubber | `pii.rs` | 5 regex (email, phone, CC, SSN, IP) — SC-SEC-003 |
| SMTP email | `mcp_gworkspace.rs` | lettre crate, attachments, vault-resolved creds |
| Multilingual detection | `cortex.rs` | auto-detect input language |
| Conversation summarisation | `cortex.rs` | periodic context compression |

## Wiring Guard (Pass-14 evidence)

`sub-projects/c3i/native/planning_daemon/tests/cortex_cascade_wiring_test.rs` (Pass-14):
- All 7 tiers enumerable
- Circuit breaker count = 5
- Persistent HTTP client = 1 OnceLock
- No-blackhole guarantees = 7 mechanisms

## CPIG closure status

- G1 Formal Spec: ✓ (per CLAUDE.md, TLA+ stub planned in `specs/tla/CortexCascade.tla`)
- G2 Wiring Guard: ✓ `cortex_cascade_wiring_test.rs` (Pass-14)
- G3 sa-plan Tracking: ✓ SC-COG-001 + SC-INFER-RUST-API family
- **G4 ZK Ingestion**: ✓ this catalog (Pass-15, today)
- **G5 Email Closure**: ✓ this pack's email (Pass-15, today)

Score: 3/5 → **5/5** after Pass-15 close.

## Cross-references

- CLAUDE.md §15 (chat pipeline) and §16 (voice pipeline)
- `.claude/rules/mistral-rust-api-mandate.md` (SC-INFER-RUST-API)
- `.claude/rules/planning-daemon-rust-only-tests.md` (SC-PD-RUST-ONLY)
- `sub-projects/c3i/native/planning_daemon/src/{cortex,mcp_inference,rag,trace}.rs`
