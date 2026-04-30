---
name: zk-cost-optimizer
description: Agentic optimization skill. Before every LLM-inducing step (plan-task, run build, fire job), query v_ooda_live + v_cost_by_agent in smriti.db. If cache_hit_ratio < 0.7 or cost_per_citation > $0.10 for the agent type, prefer ZK recall from cheap cached holons over fresh LLM call. Use ./sa-zk-metrics to read, ./sa-zk-zenoh-publisher to publish, ./sa-zk-ooda-snapshot to refresh the shared JSON. Agents MUST check thresholds before expensive work.
version: 1.0.0
---

# ZK Cost Optimizer — Agentic Skill

## Trigger
- Agent is about to make an LLM call, run a build, or start a new session.
- Any action with estimated token cost > 1,000 tokens.
- Scheduled 60-s polling loop (`./sa-zk-zenoh-publisher 60 &`).

## Workflow
```
1. READ ./sa-zk-metrics --json  → current KPIs
2. IF embedding_coverage_pct < 50
     → DEFER: enqueue embed_refresh job via sa-plan first
3. IF cache_hit_ratio < 0.7
     → REFACTOR: stabilize system prompt prefix before LLM call
4. IF cost_per_citation > 0.10
     → RECALL: run ./sa-plan zk-recall "<query>" instead of LLM
5. IF alarm/edges_low is active
     → BATCH: run link-extractor before heavy recall operations
6. EMIT spans via zenoh_otel.emit(Dashboard, "optim", Decide)
```

## Commands available
- `./sa-zk-metrics --ooda`         — human-readable KPI snapshot
- `./sa-zk-metrics --json`         — machine-readable for agents
- `./sa-zk-ooda-snapshot`          — refresh live JSON once
- `./sa-zk-zenoh-publisher 0`      — publish snapshot to Zenoh + JSON
- `./sa-zk-zenoh-publisher 60 &`   — continuous 60s loop
- `./sa-plan zk-recall "<q>"`      — 6-stage recall pipeline
- `./sa-plan knowledge-search "q"` — FTS5 only (faster)
- `./sa-plan semantic-search "q"`  — embedding-based
- `./sa-plan embed`                — backfill missing embeddings

## Target KPIs (pass-8)
| KPI | Current | Target | Gap |
|---|---|---|---|
| embedding_coverage_pct | 37% | 95% | −58pp |
| cache_hit_ratio | 47.8% | 90% | −42pp |
| cost_per_citation | $0.85 | $0.05 | 17x over |
| edges_total | 3,074 | 10,000 | −7k |
| pipeline/rag avg | 2,781 ms | 800 ms | 3.5x over |

## Hooks
- Pi `before_agent_start` → inject dual-ZK recall (see .pi/extensions/zk-recall.ts)
- Claude `UserPromptSubmit` → zk-recall (see .claude/settings.json)
- Both emit OTel + persist to session_metrics

## STAMP
SC-PASS7-ZK-OPT-001 · SC-OODA-003 · SC-GLM-ZEN-001 · SC-RECALL-RAG · SC-PI-AUTO-001
