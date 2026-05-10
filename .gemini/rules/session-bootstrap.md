# Session Bootstrap Protocol (SC-BOOTSTRAP)
# सत्र प्रारम्भ प्रोतोकॉल

## Mandate (आदेश)
**Every Claude session MUST bootstrap with Zettelkasten recall + Gleam compute verification.**
Memory-first, Zettelkasten-second, compute-third, act-fourth.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-BOOTSTRAP-001 | Session MUST check memory BEFORE reading any code files | HIGH |
| SC-BOOTSTRAP-002 | Session MUST search Zettelkasten for task-relevant prior patterns | CRITICAL |
| SC-BOOTSTRAP-003 | Session MUST verify `gleam build` passes before any code change | HIGH |
| SC-BOOTSTRAP-004 | Session MUST use Gleam NIF compute for graph/math, NOT manual reasoning | CRITICAL |
| SC-BOOTSTRAP-005 | Session MUST ingest new documents to Zettelkasten before ending | CRITICAL |

## Bootstrap Sequence

### Phase 1: Recall (0-5s)
```bash
# 1. Read MEMORY.md — prior session context
# 2. MANDATORY: Search Zettelkasten for task context
sa-plan-daemon knowledge-search "<user request keywords>"
# 3. Check active tasks
sa-plan-daemon status
```

### Phase 2: Verify (5-10s)
```bash
# 4. Build check
cd lib/cepaf_gleam && gleam build
# 5. Nav graph health via Gleam NIF
gleam run -m cepaf_gleam/claude_compute
# Output: SCC=1 (all pages reachable), PageRank, boot DAG
```

### Phase 3: Orient (10-15s)
```
# 6. Map request to Zettelkasten recall results
# 7. If prior pattern exists -> follow it, don't reinvent
# 8. If anti-pattern exists -> explicitly avoid it
# 9. Begin execution
```

### Phase 4: Session End
```bash
# 10. Ingest all new/modified documents
sa-plan-daemon ingest-docs
# 11. Email summary
sa-plan-daemon send-email --to Abhijit.Naik@bountytek.com ...
# 12. Update memory with session learnings
```

## Compute Rules — USE NIF, NOT MANUAL REASONING
| Task | WRONG | RIGHT |
|------|-------|-------|
| Graph reachability | "All 31 pages form a complete graph so SCC=1" | `graphene_scc_typed(pages, edges)` |
| Test priority | "Dashboard is most important because..." | `graphene_pagerank_typed(pages, edges, 0.85, 30)` |
| Critical path | "T005 blocks T003 which blocks T015" | `petgraph_dijkstra(nodes, edges, 0)` |
| Boot order | "Zenoh must start before DB" | `petgraph_toposort(containers, deps)` |
| Color check | "This looks accessible enough" | `bevy_color_srgba_to_oklch()` -> verify L* diff |
| State diagram | Draw ASCII art | `skia_render_machine()` -> PNG |
| Architecture diagram | Describe in text | `mermaid_render()` -> SVG |
| Chart | "Here's a table of values" | `vega_lite_preset()` -> JSON spec |

## Anti-Patterns (दोष निवारण)
- ❌ Reading the entire GEMINI.md (rules/ already loaded)
- ❌ Skipping Zettelkasten search ("I'll figure it out from scratch")
- ❌ Manual graph reasoning when NIF functions exist
- ❌ ASCII art diagrams when skia/mermaid can render PNGs/SVGs
- ❌ Forgetting to ingest documents at session end
- ❌ Not checking prior anti-patterns before proposing solutions
