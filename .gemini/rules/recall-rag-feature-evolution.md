# Recall/RAG/Context Memory Feature Evolution Rule (SC-RECALL-RAG)

## Mandate
**Every time the Recall/RAG/Context Memory subsystem is modified, the full feature evolution pipeline MUST execute.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-RECALL-RAG-001 | ZK modules (zettelkasten/*.gleam) changes MUST run recall_rag_regression_test | CRITICAL |
| SC-RECALL-RAG-002 | RAG pipeline (rag.rs) changes MUST verify <500ms FTS5 query time | HIGH |
| SC-RECALL-RAG-003 | Semantic cache changes MUST verify 24h TTL behavior | HIGH |
| SC-RECALL-RAG-004 | Hook changes MUST verify all 3 hooks fire (SessionStart, UserPromptSubmit, Stop) | CRITICAL |
| SC-RECALL-RAG-005 | Dashboard MUST be updated at https://vm-1.tail55d152.ts.net:4200/recall-rag | HIGH |
| SC-RECALL-RAG-006 | Pi bridge compatibility MUST be verified after any ZK type changes | HIGH |
| SC-RECALL-RAG-007 | New ZK holons MUST be ingested after feature completion | HIGH |
| SC-RECALL-RAG-008 | Journal entry MUST follow 13-section protocol | CRITICAL |

## Subsystem Inventory
| Component | Location | Lines | Language |
|-----------|----------|-------|----------|
| ZK Types | zettelkasten/types.gleam | 233 | Gleam |
| ZK Search | zettelkasten/search.gleam | 241 | Gleam |
| ZK Operations | zettelkasten/operations.gleam | 435 | Gleam |
| ZK Ingestion | zettelkasten/ingestion.gleam | 265 | Gleam |
| ZK Entropy | zettelkasten/entropy.gleam | 128 | Gleam |
| ZK Trust | zettelkasten/trust.gleam | 121 | Gleam |
| ZK Linker | zettelkasten/linker.gleam | 168 | Gleam |
| ZK Metrics | zettelkasten/metrics.gleam | 191 | Gleam |
| ZK Rules | zettelkasten/rules.gleam | 184 | Gleam |
| ZK Export | zettelkasten/export.gleam | 168 | Gleam |
| RAG Pipeline | planning_daemon/src/rag.rs | 104 | Rust |
| Cortex | planning_daemon/src/cortex.rs | 1,980 | Rust |
| PipelineTracer | planning_daemon/src/trace.rs | 241 | Rust |
| Inference | planning_daemon/src/mcp_inference.rs | 663 | Rust |
| DB Backend | planning_daemon/src/db.rs | 1,017 | Rust |

## Pi-Mono Integration Checklist
When modifying recall/RAG:
1. Check pi_claude_code.gleam still compiles
2. Verify tool federation count (93)
3. Verify event bridge (29 Pi ↔ 32 AG-UI)
4. Update Pi integration docs if API changes

## Dashboard URL
- HTTP: http://vm-1.tail55d152.ts.net:4200/recall-rag
- HTTPS: https://vm-1.tail55d152.ts.net:4200/recall-rag
- Deck: https://vm-1.tail55d152.ts.net:4200/recall-rag-deck
