# Zettelkasten + Gleam Agent Integration for Claude (SC-ZK-CLAUDE)
# HIGHEST PRIORITY REQUIREMENT

## SUPREME MANDATE
**Claude MUST use the Zettelkasten for memory and Gleam NIF functions for computation. Every session. No exceptions.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ZK-CLAUDE-001 | Claude MUST search Zettelkasten BEFORE starting any task | CRITICAL |
| SC-ZK-CLAUDE-002 | Claude MUST ingest documents to Zettelkasten AFTER completing work | CRITICAL |
| SC-ZK-CLAUDE-003 | Claude MUST use Graphene NIF for graph analysis instead of manual reasoning | HIGH |
| SC-ZK-CLAUDE-004 | Claude MUST use sa-plan-daemon for all task management | CRITICAL |
| SC-ZK-CLAUDE-005 | Claude MUST check prior patterns in Zettelkasten before proposing solutions | HIGH |
| SC-ZK-CLAUDE-006 | Claude MUST use coverage_math for test quality assessment | HIGH |

## Session Start Protocol
```bash
# 1. Search Zettelkasten for context on current task
sa-plan-daemon knowledge-search "<task keywords>"

# 2. Check system health
sa-plan-daemon status

# 3. Check gleam builds
cd lib/cepaf_gleam && gleam build
```

## During Work Protocol
```bash
# For graph questions: Use NIF, don't reason manually
# WRONG: "The navigation graph has 31 pages, they form a complete graph..."
# RIGHT: Run graphene_scc via gleam test to verify

# For math: Use NIF functions
# WRONG: Manually compute PageRank
# RIGHT: graphene_pagerank_typed(pages, edges, 0.85, 30)

# For diagrams: Use NIF rendering
# WRONG: ASCII art state machine
# RIGHT: skia_render_machine() or mermaid_render_machine()

# For color checks: Use NIF
# WRONG: "This hex color should work for dark mode"
# RIGHT: bevy_color_srgba_to_oklch() to verify perceptual uniformity
```

## Session End Protocol
```bash
# 1. Ingest all new documents
sa-plan-daemon ingest-docs

# 2. Email summary
sa-plan-daemon send-email --to Abhijit.Naik@bountytek.com --subject "Session Summary" --body "..."

# 3. Update memory
# Write to .claude/projects/*/memory/ with session learnings
```

## Available Zettelkasten Commands
| Command | Use When |
|---------|----------|
| `sa-plan-daemon knowledge-search "query"` | Before starting ANY task |
| `sa-plan-daemon ingest-docs` | After creating/modifying docs |
| `sa-plan-daemon status` | Check task state |
| `sa-plan-daemon list pending` | Find work to do |

## Available Gleam NIF Compute (125 functions)
| Package | Functions | Use Instead Of |
|---------|-----------|---------------|
| `graphene_*` | 15 | Manual graph reasoning |
| `petgraph_*` | 13 | Manual shortest path / cycle detection |
| `kurbo_*` | 42 | Manual SVG / geometry calculations |
| `skia_*` | 5 | External diagram tools |
| `mermaid_*` | 7 | Mermaid CLI / browser rendering |
| `vega_lite_*` | 16 | Manual chart JSON construction |
| `bevy_color_*` | 6 | Manual color math |
| `bevy_math_*` | 6 | Manual 3D math |
| `bevy_ecs_*` | 3 | Manual entity tracking |
| `grafana_*` | 9 | Manual dashboard JSON |

## How to Call NIF Functions from Claude
```bash
# Option 1: Via gleam test (create a test that calls the function)
cd lib/cepaf_gleam && gleam test -- --module graphene_render_test

# Option 2: Via erl eval (within OTP context)
cd lib/cepaf_gleam && gleam run -m graphene_quick_check

# Option 3: Via the running server's API
curl -s https://localhost:4100/api/v1/graph/analyze
```
