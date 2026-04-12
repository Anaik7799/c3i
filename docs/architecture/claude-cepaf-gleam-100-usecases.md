# Claude + cepaf_gleam — 100 Use Cases + Closed-Loop Auto-Evolution
# क्लॉड + सीपैफ_ग्लीम — 100 उपयोग + स्वचालित विकास बन्द चक्र

**Date**: 2026-04-12 | **System**: 335 modules, 2,114 pub fn, 708 types
**Closed Loop**: Claude observes -> generates -> renders -> tests -> deploys -> observes

---

## CLOSED-LOOP ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────┐
│                    AUTO-EVOLUTION LOOP                        │
│                                                              │
│  ① OBSERVE (graphene + petgraph + ha/*)                     │
│     graphene_analyze() -> graph metrics                      │
│     ha/health_calculus -> d(H)/dt derivative                 │
│     ha/guard_grid -> 24-cell Shannon entropy                 │
│     testing/coverage_math -> H, CCM, ITQS                    │
│                    │                                         │
│  ② ORIENT (zettelkasten + agents/cortex)                    │
│     zettelkasten/search -> prior patterns                    │
│     agents/ooda_fsm -> phase determination                   │
│     ha/anomaly_detector -> z-score deviation                 │
│     ha/fmea_generator -> RPN risk scoring                    │
│                    │                                         │
│  ③ DECIDE (rules + graphene + vega_lite)                    │
│     rules/engine -> 52 GRL rule evaluation                   │
│     graphene_pagerank -> test priority                       │
│     graphene_shortest_path -> critical path                  │
│     vega_lite_preset -> dashboard chart spec                 │
│                    │                                         │
│  ④ ACT (skia + mermaid + kurbo + web/server)                │
│     skia_render_* -> PNG state diagrams                      │
│     mermaid_render -> SVG architecture diagrams              │
│     kurbo_shape_typed -> SVG UI components                   │
│     web/server -> hot reload via ha/hot_reload               │
│                    │                                         │
│  ⑤ VERIFY (testing + graphene + grafana)                    │
│     gleam test -> 5,434 tests                                │
│     graphene_scc -> navigation reachability                  │
│     grafana_dashboard -> monitoring dashboards               │
│     ha/fitness_gate -> 6-KPI rollback gate                   │
│                    │                                         │
│  ⑥ PUBLISH (gateway + zenoh + smtp)                         │
│     gateway/telegram -> notify operator                      │
│     zenoh/client -> publish OTel spans                       │
│     sa-plan-daemon send-email -> report with PNGs            │
│     zettelkasten/ingestion -> learn from result              │
│                    │                                         │
│  └──────────> back to ① OBSERVE                             │
└─────────────────────────────────────────────────────────────┘
```

---

# L0 CONSTITUTIONAL (UC001-UC013)

## Observe
UC001: **Guardian Approval Audit** — `ha/guard_rules` evaluates 30 RETE-UL rules -> `graphene_analyze` on approval graph -> detect bottlenecks
  Figma: UC003 (Emergency Stop Button) + UC006 (Approval Flow)
  Closed loop: Guard rule fires -> approval pending -> notify via gateway/telegram -> human approves -> log to zettelkasten

UC002: **Psi Invariant Verification** — `verification/prometheus` checks Psi-0..5 + Omega-0 -> `ha/self_observer` validates display=truth
  Figma: UC002 (Psi Badge Set) + UC007 (Psi Health Chart)
  Closed loop: Observer finds violation -> ha/assertions fires -> system enters safe state -> alert -> RCA in zettelkasten

UC003: **Constitutional Hash Chain** — `eventsource/chain` verifies append-only log integrity -> `graphene_scc` confirms all events reachable
  Figma: UC005 (Hash Display) + UC011 (Immutable Register)
  Closed loop: Hash mismatch detected -> ha/rollback_controller reverts -> zettelkasten records anti-pattern

## Orient + Decide
UC004: **Safety Gate Scoring** — `ha/fmea_generator` computes RPN for each gate -> `vega_lite_heatmap` visualizes safety matrix
  Figma: UC008 (Safety Gate Heatmap) + UC012 (SIL-6 Dashboard)
  Closed loop: RPN > 200 -> auto-escalate to P0 -> sa-plan update task -> grafana_alert_list triggers

UC005: **2oo3 Consensus Verification** — `petgraph_connected_components` on voting graph -> must be 1
  Figma: UC004 (Voting Visualization) + UC088 (Quorum Voting)
  Closed loop: Component count > 1 -> split-brain -> ha/cell_architecture isolates -> apoptosis

## Act + Verify
UC006: **State Machine Auto-Generation** — `c3i_page_state_machine()` -> `skia_render_machine` PNG + `mermaid_render_machine` SVG
  Figma: UC009 (L0 State Machine) + UC031 (State Machine Diagrams)
  Closed loop: Model type changes -> wiring_guard detects -> re-render diagrams -> commit to docs/

UC007: **Constitutional Verification Flow** — `verification/graph_verification` runs L0-L7 checks -> `mermaid_build_flowchart` documents flow
  Figma: UC010 (Verification Flow)
  Auto-evolution: New constraint added -> verification flow diagram auto-regenerates

## Publish
UC008: **SIL-6 Evidence Package** — `skia_render_all` generates 17 PNGs -> `grafana_dashboard` creates monitoring -> email with attachments
  Figma: UC049 (Wireframe Pipeline)
  Auto-evolution: Every sprint -> evidence package auto-generated -> emailed -> ingested to zettelkasten

UC009: **Emergency Stop Propagation** — `graphene_bfs` from emergency node -> all downstream containers halt within 5s (SC-SAFETY-022)
  Figma: UC039 (Cascade Diagram)
  Closed loop: Emergency -> BFS computes blast radius -> apoptosis sequence -> dashboard updates -> post-mortem generated

UC010: **Dark Cockpit Mode Engine** — `prajna/dark_cockpit` determines mode from health -> `bevy_color_srgba_to_hsla` adjusts UI saturation
  Figma: UC048 (Dark Cockpit Transitions)
  Closed loop: Health=98 -> Dark mode (suppress noise) -> Health drops -> Bright mode auto-activates

UC011: **Wiring Guard Validation** — `testing/wiring_guard` verifies all Model constructors -> `graphene_analyze` on import graph
  Figma: UC050 (Design-Code Parity)
  Closed loop: Model field added -> wiring guard fails -> CI blocks -> developer fixes -> guard passes

UC012: **Constitutional Amendment Protocol** — `ha/guard_rules` + Guardian approval for any L0 change -> `zettelkasten/ingestion` records decision
  Figma: UC006 (Approval Flow)
  Auto-evolution: Amendment proposed -> 2oo3 vote -> approved -> rules updated -> zettelkasten learns

UC013: **Fractal Layer Integrity** — `fractal/l0_constitutional` + all 8 layer modules verify self-consistency -> `vega_lite_fractal_heatmap`
  Figma: UC023 (Fractal Heatmap)
  Closed loop: Layer health < 0.8 -> escalate cockpit mode -> focused investigation -> health restored

---

# L1 ATOMIC/DEBUG (UC014-UC025)

UC014: **OTel Span Auto-Publishing** — Every `ui/lustre/*` state change -> `ui/zenoh_otel` publishes span -> `testing/zenoh_test_observer` verifies
  Figma: UC023 (OTel Pipeline) + UC016 (Span Timeline)
  Closed loop: State change -> span published -> observer confirms -> if missing -> test failure -> fix

UC015: **NIF Health Monitoring** — `c3i/nif` 14 NIFs + `graphene.gleam` 125 fn -> `ha/beam_metrics` tracks call latency -> `vega_lite_line` trend
  Figma: UC018 (NIF Panel) + UC021 (NIF Frequency)
  Closed loop: NIF latency > 10ms -> ha/anomaly_detector flags -> degradation mode -> retry with backoff

UC016: **Telemetry Dashboard Auto-Build** — `grafana_ooda_timeseries` + `grafana_health_gauge` -> `grafana_dashboard` assembles -> deploy to port 3000
  Figma: UC041 (Grafana Health Dashboard)
  Auto-evolution: New metric added -> dashboard JSON regenerated -> Grafana API creates panel

UC017: **Debug Trace Viewer** — `fractal/l1_atomic_debug` captures events -> `ui/tui/renderer` shows ANSI -> `vega_lite_timeline_gantt` for web
  Figma: UC016 (OTel Span Timeline) + UC019 (Event Stream)
  Closed loop: Error detected -> trace captured -> visualized -> zettelkasten stores pattern

UC018: **Hot Reload Pipeline** — `ha/hot_reload` builds -> discovers changed modules -> soft_purge -> load -> verify via `ha/beam_metrics`
  Figma: N/A (runtime only)
  Closed loop: Code change -> gleam build -> hot reload -> 0 errors -> WebSocket stays alive -> dashboard updates

UC019: **Sparkline Widget Generation** — `vega_lite_health_sparkline` spec -> embedded in `ui/web/dashboard_views` SSR HTML
  Figma: UC017 (Sparkline Widget) + UC021 (Health Sparkline)
  Auto-evolution: New metric -> sparkline spec generated -> SSR HTML updated -> hot reload pushes to clients

UC020: **Test Coverage Math** — `testing/coverage_math` computes H, CCM, ITQS -> `vega_lite_bar` visualizes per-category coverage
  Figma: UC035 (Mini Bar Chart)
  Closed loop: Coverage < threshold -> test generation triggered -> coverage improves -> gate passes

UC021: **Build Stream Monitor** — `ha/beam_metrics` tracks compile time -> `vega_lite_area` for build time trend
  Figma: UC054 (Build Progress)
  Auto-evolution: Build time > 5s -> investigate -> optimize -> build time improves

UC022: **Zenoh OTel Integration** — `ui/zenoh_otel` + `testing/zenoh_test_observer` -> verify span delivery -> `vega_lite_scatter` latency
  Figma: UC022 (Zenoh Rate) + UC083 (Mesh Latency)
  Closed loop: Span delivery fails -> zenoh/lifecycle reconnects -> observer re-subscribes

UC023: **Auto-Build Hook** — PostToolUse hook -> `gleam build` -> 0 errors mandatory (SC-TPS-001 Jidoka)
  Figma: N/A (tooling)
  Closed loop: File edited -> auto-build -> error -> STOP -> fix -> build passes -> continue

UC024: **Freshness Monitor** — `actors/freshness_actor` checks NIF data every 10s -> `ha/freshness_monitor` escalates: Fresh->Stale->Dead
  Figma: UC015 (Weather Bar States)
  Closed loop: Data stale > 60s -> amber warning -> > 5min -> emergency mode -> force refresh

UC025: **Anomaly Detection** — `ha/anomaly_detector` Welford online algorithm -> z-score > 3 -> alert
  Figma: UC060 (CPU Governor)
  Closed loop: Anomaly detected -> alert fired -> zettelkasten stores -> pattern recognized next time

---

# L2 COMPONENT (UC026-UC038)

UC026: **A2UI Catalog Rendering** — `a2ui/catalog` 233 components -> `a2ui/renderer` -> HTML + JSON + ANSI tripartite output
  Figma: UC025 (A2UI Scale) + UC037 (Catalog Structure)
  Auto-evolution: New component registered -> catalog updated -> renderer generates output -> tests verify

UC027: **Component Validation Pipeline** — `a2ui/validator` allowlist check -> `kurbo_rect_contains` for touch target 44px gate
  Figma: UC028 (Touch Targets)
  Closed loop: Agent proposes component -> validator checks -> reject if < 44px -> agent retries

UC028: **SVG Shape Factory** — `kurbo_shape_typed(SvgRect/SvgCircle/SvgStar/SvgPolygon)` -> embed in Lustre HTML elements
  Figma: UC006 (Icon Grid) + UC011 (Progress Ring)
  Auto-evolution: New shape needed -> define in Gleam type -> kurbo generates SVG -> hot reload shows it

UC029: **Responsive Layout Engine** — `kurbo_rect_area` + `kurbo_rect_intersect` + `kurbo_rect_union` -> compute breakpoint layouts
  Figma: UC012 (Grid Layout) + UC014 (Responsive Header)
  Closed loop: Viewport changes -> layout recomputed -> components repositioned -> CSS breakpoints fire

UC030: **Form Validation System** — `core/types` + `core/result` validate inputs -> `bevy_color` for error/success states
  Figma: UC031 (Validation States)
  Auto-evolution: New field added -> validation rule auto-generated -> test added -> coverage maintained

UC031: **Badge Gradient Generator** — `bevy_color_srgba_to_hsla` -> shift hue 10 degrees -> `bevy_color_hsla_to_srgba` -> CSS gradient pair
  Figma: UC027 (Badge Gradients)
  Closed loop: New priority level -> gradient pair auto-generated -> badge component updated

UC032: **Data Table Auto-Sizer** — `kurbo_rect_area` per column content -> compute optimal widths -> Tabulator config JSON
  Figma: UC029 (Table Row) + UC012 (Grid Layout)
  Auto-evolution: Column added -> auto-sizer recomputes -> table rerenders -> test verifies

UC033: **Modal Dialog System** — `fractal/l2_component` forms + `a2ui/renderer` -> modal with Guardian approval for L0 actions
  Figma: UC030 (Modal Dialog)
  Closed loop: Destructive action -> modal shown -> user confirms -> Guardian approves -> action executes

UC034: **Tooltip Positioning** — `kurbo_rect_contains` for viewport bounds + `kurbo_affine_translate` for optimal placement
  Figma: UC033 (Tooltip Variants)
  Auto-evolution: Component moved -> tooltip reposition auto-calculated -> no overlap guaranteed

UC035: **Dark Cockpit Component Variants** — `prajna/dark_cockpit` mode -> `bevy_color_srgba_to_hsla` -> desaturate for Dim/Dark modes
  Figma: UC048 (Dark Cockpit) + UC008 (Dark/Light Tokens)
  Closed loop: Health improves -> Dark mode -> components auto-desaturate -> noise suppressed

UC036: **Bezier Animation Curves** — `kurbo_bezier_cubic_eval` samples 100 points -> CSS `cubic-bezier()` export
  Figma: UC009 (Easing Curves)
  Auto-evolution: Designer tweaks curve -> Gleam generates CSS -> hot reload applies -> verify visually

UC037: **Progress Ring Rendering** — `kurbo_shape_typed(SvgCircle)` + stroke-dasharray from count/total ratio -> SSR HTML
  Figma: UC011 (Progress Ring) + UC036 (Circular Progress)
  Closed loop: Task completes -> count updates -> ring re-renders -> WebSocket pushes to client

UC038: **Event Stream Widget** — `agui/event_stream_widget` isomorphic HTML+ANSI -> 32 AG-UI event types displayed
  Figma: UC019 (Event Stream)
  Closed loop: AG-UI event received -> widget renders -> change log updated -> toast notification on mobile

---

# L3 TRANSACTION (UC039-UC051)

UC039: **Task Dependency DAG Validation** — `petgraph_toposort` on task graph -> `petgraph_is_cyclic` check -> reject circular deps
  Figma: UC045 (Task DAG) + UC037 (Dependency Graph)
  Closed loop: Task created with dependency -> DAG validated -> cycle detected -> reject -> notify

UC040: **Critical Path Computation** — `petgraph_dijkstra` from blocked task -> find longest chain -> `vega_lite_timeline_gantt` visualize
  Figma: UC026 (Task Gantt) + UC045 (Task DAG)
  Closed loop: New block -> critical path recomputed -> dashboard updates -> focus recommended

UC041: **Sprint Burndown Auto-Chart** — `vega_lite_line` ideal vs actual -> embedded in planning dashboard
  Figma: UC046 (Sprint Burndown)
  Auto-evolution: Task completed -> burndown recalculated -> chart regenerated -> WS pushes update

UC042: **State Diff Viewer** — `fractal/l3_transaction` captures before/after -> `bevy_color` for add(green)/remove(red) highlighting
  Figma: UC041 (State Diff Viewer)
  Closed loop: State mutation -> diff computed -> viewer renders -> change log entry created

UC043: **CRDT State Merge** — `ha/crdt` GCounter + PNCounter + ORSet -> `mermaid_build_flowchart` for merge visualization
  Figma: UC050 (CRDT Merge Diagram)
  Closed loop: Concurrent update -> CRDT merge -> conflict resolved -> state converges -> verify via test

UC044: **Planning Data Model** — `planning/*` 16 modules -> `mermaid_build_flowchart` for ER diagram -> `petgraph_dot_export` for Graphviz
  Figma: UC048 (Data Model)
  Auto-evolution: New planning field -> model diagram regenerated -> committed to docs/

UC045: **Task Status Automation** — `agents/cortex` processes intent -> `c3i/nif` plan_update -> WebSocket pushes change
  Figma: UC040 (Task Card)
  Closed loop: Agent completes task -> NIF updates status -> WS pushes -> dashboard renders -> log entry

UC046: **Kanban Board Auto-Layout** — `ui/lustre/planning` MVU + `kurbo_rect_area` per column -> responsive card grid
  Figma: UC013 (Kanban Cards) + UC040 (Task Cards)
  Closed loop: Status changes -> card moves columns -> animation plays -> column counts update

UC047: **SQLite WAL Monitoring** — `db/sqlite` WAL mode -> `ha/health_calculus` d(WAL_size)/dt -> `vega_lite_line` trend
  Figma: UC044 (WAL Indicator)
  Closed loop: WAL grows > threshold -> checkpoint triggered -> WAL size drops -> health restored

UC048: **Transaction Pipeline Tracing** — `agents/cortex` PipelineTracer -> `ui/wisp/pipeline_trace_api` -> `vega_lite_timeline_gantt`
  Figma: UC016 (Span Timeline)
  Closed loop: Intent received -> traced end-to-end -> latency measured -> optimize if > budget

UC049: **Zettelkasten Knowledge Ingestion** — `zettelkasten/ingestion` -> `zettelkasten/entropy` Shannon H gate -> accept/reject
  Figma: UC074 (Knowledge Graph)
  Closed loop: Document created -> entropy check -> if H > 0.2 reject (noise) -> else ingest -> link to existing holons

UC050: **Cross-Holon Database Access** — `db/cross_holon` via Zenoh only (SC-XHOLON-003) -> `petgraph_connected_components` verify isolation
  Figma: UC086 (Key Expression Tree)
  Closed loop: Cross-holon query -> Zenoh transport -> OCC version check -> merge or reject

UC051: **Search with RAG Context** — `zettelkasten/search` FTS5 -> inject into Gemma system prompt -> `agents/cortex` processes
  Figma: UC074 (Knowledge Graph)
  Auto-evolution: Every search -> relevance scored -> search index tuned -> recall improves

---

# L4 SYSTEM (UC052-UC064)

UC052: **16-Container Boot Orchestration** — `petgraph_toposort` on genome DAG -> 7-tier parallel waves -> `vega_lite_timeline_gantt`
  Figma: UC057 (Boot Timeline) + UC062 (Boot Tier)
  Closed loop: Boot starts -> tier health checks -> pass -> next tier -> all healthy -> dashboard green

UC053: **Container Health Cascade** — `graphene_bfs` from failed container -> blast radius -> `ha/health_cascade` isolates
  Figma: UC039 (Cascade Diagram) + UC058 (Container Heatmap)
  Closed loop: Container fails -> BFS computes affected -> isolate -> restart -> health restores

UC054: **Image Staleness Detection** — age > 168h -> `ha/fitness_gate` triggers rebuild -> `vega_lite_bar` shows image ages
  Figma: UC059 (Image Staleness)
  Auto-evolution: Image stale -> rebuild triggered -> EMA updates build estimate -> next check faster

UC055: **CPU Governor Enforcement** — `ha/beam_metrics` CPU% -> if > 85% -> pause operations (SC-CPU-GOV-001)
  Figma: UC060 (CPU Governor)
  Closed loop: CPU > 85% -> heavy throttle -> wait loop -> CPU < 75% -> resume at reduced parallelism

UC056: **Podman Container Management** — `podman/*` 7 modules -> start/stop/restart -> `grafana_container_table` status
  Figma: UC053 (Container Grid) + UC055 (Health Row)
  Auto-evolution: Container unhealthy -> auto-restart (supervisor) -> health check -> if still failing -> apoptosis

UC057: **Port Binding Verification** — 4000-4010 mesh range + 4050 Wallaby + 4100 Gleam -> `kurbo_rect_contains` port conflict check
  Figma: UC056 (Port Table)
  Closed loop: Port conflict detected -> boot halts -> notify operator -> resolve -> retry

UC058: **Build History EMA** — SQLite build_history.db -> EMA alpha=0.3 -> `vega_lite_line` for build time prediction
  Figma: UC054 (Build Progress)
  Auto-evolution: Build completes -> EMA updated -> next estimate more accurate -> displayed before build

UC059: **System Health Dashboard** — `ha/health_calculus` d(H)/dt + d²(H)/dt² -> `vega_lite_health_sparkline` + `grafana_health_gauge`
  Figma: UC015 (Weather Bar) + UC041 (Grafana Health)
  Closed loop: d(H)/dt negative -> trend worsening -> cockpit escalates -> investigation triggered

UC060: **Graceful Degradation** — `ha/degradation` 4-tier: Full -> Reduced -> Minimal -> Safe -> `mermaid_build_state_diagram`
  Figma: UC048 (Dark Cockpit Transitions)
  Closed loop: Services degrade -> tier drops -> functionality reduced -> critical path maintained

UC061: **Canary Deployment** — `ha/canary_controller` 6-phase rollout -> `vega_lite_line` error rate comparison
  Figma: N/A (operational)
  Closed loop: Deploy canary -> monitor error rate -> below threshold -> promote -> else rollback

UC062: **Cell Architecture Isolation** — `ha/cell_architecture` blast radius cells -> `kurbo_rect_intersect` for containment check
  Figma: UC039 (Cascade Diagram)
  Auto-evolution: New container added -> cell boundaries recomputed -> isolation verified

UC063: **Fitness Gate Scoring** — `ha/fitness_gate` 6 KPIs -> composite score -> if < 0.4 auto-revert
  Figma: UC007 (Psi Health Chart)
  Closed loop: Evolution applied -> fitness measured -> score < 0.4 -> auto-revert -> zettelkasten records failure

UC064: **Evolution Scheduler** — `ha/evolution_scheduler` 6-hourly autonomous evolution cycle
  Figma: N/A (autonomous)
  Auto-evolution: Timer fires -> observe metrics -> orient via zettelkasten -> decide strategy -> act -> verify -> publish

---

# L5 COGNITIVE (UC065-UC077)

UC065: **OODA Loop Execution** — `agents/ooda_fsm` Observe->Orient->Decide->Act->Verify -> `vega_lite_ooda_ring` timing
  Figma: UC024 (OODA Ring) + UC071 (OODA Timing)
  Closed loop: OODA cycle completes -> timing recorded -> if > 100ms budget -> optimize -> retry

UC066: **6-Tier Hedged Inference** — `agents/cortex` Gemini->OpenRouter->Ollama->Rules -> `mermaid_build_flowchart` cascade
  Figma: UC075 (Inference Cascade) + UC072 (Inference Latency)
  Closed loop: Tier 1 fails -> Tier 2 fires -> first success wins -> circuit breaker tracks failures

UC067: **MCP Tool Dispatch** — `agui/tools` + `bridge/zenoh_mcp` -> 73 MCP tools -> `mermaid_build_sequence` protocol flow
  Figma: UC069 (MCP Tool Panel) + UC035 (AG-UI Sequence)
  Closed loop: Tool call -> dispatch via Zenoh -> result returned -> UI updates -> span published

UC068: **Gemma AI Chat Integration** — `agents/cortex` + RAG from zettelkasten -> system prompt enriched -> `vega_lite_scatter` response analysis
  Figma: UC018 (AI Chat Widget) + UC067 (Copilot Panel)
  Closed loop: User asks -> RAG injects context -> Gemma responds -> conversation stored -> recall improves

UC069: **Rule Engine Evaluation** — `rules/engine` 52 GRL rules -> `vega_lite_heatmap` for rule activation matrix
  Figma: UC073 (Rule Engine Heatmap)
  Auto-evolution: New rule added -> evaluation coverage verified -> heatmap updated -> dead rules detected

UC070: **PageRank Test Priority** — `graphene_pagerank(0.85, 30)` on 22-page graph -> test highest-ranked pages first
  Figma: UC032 (Navigation Graph)
  Closed loop: New page added -> PageRank recomputed -> test order updated -> highest risk tested first

UC071: **Knowledge Graph Visualization** — `zettelkasten/linker` connections -> `petgraph_dot_export_full` -> Graphviz rendering
  Figma: UC074 (Knowledge Graph)
  Auto-evolution: New holon ingested -> links auto-discovered -> graph grows -> entropy monitored

UC072: **Skill Loading** — `agents/skill_loader` reads .agents/skills/ -> prompt injection protection -> `mermaid_build_flowchart` skill flow
  Figma: N/A (agent infrastructure)
  Closed loop: Skill added -> loader validates -> skill available -> agent uses -> effectiveness measured

UC073: **Semantic Cache** — `agents/cortex` 24h TTL SQLite-backed -> skip inference on cache hit -> `vega_lite_bar` hit/miss ratio
  Figma: UC072 (Inference Latency)
  Closed loop: Query -> cache hit -> instant response -> miss -> inference -> cache stored -> next hit faster

UC074: **Conversation History** — `agents/cortex` 50-message sliding window -> context compression -> `vega_lite_area` context size
  Figma: UC067 (Copilot Panel)
  Auto-evolution: Context too large -> summarization triggered -> context compressed -> quality maintained

UC075: **PII Scrubbing** — `agents/cortex` regex-based redaction -> `vega_lite_bar` PII detection counts by type
  Figma: N/A (security)
  Closed loop: PII detected -> scrubbed -> logged -> compliance verified -> zettelkasten tracks patterns

UC076: **Workspace Context Isolation** — `agents/workspace` strict boundaries -> `petgraph_connected_components` verify no leaks
  Figma: N/A (agent infrastructure)
  Closed loop: Agent spawned -> workspace isolated -> context boundary verified -> no cross-contamination

UC077: **Visual Reasoning** — `ui/visual_reasoning` + `kurbo_bezier_cubic_eval` for thought flow curves -> SVG reasoning trace
  Figma: UC068 (Reasoning Display)
  Auto-evolution: Reasoning pattern recognized -> stored as template -> reused in similar situations

---

# L6 ECOSYSTEM (UC078-UC089)

UC078: **Zenoh Mesh Topology** — `zenoh/lifecycle` + `petgraph_all_edges` -> `petgraph_dot_export_full` -> `mermaid_build_flowchart`
  Figma: UC034 (Mesh Topology) + UC079 (Topology Map)
  Closed loop: Node joins/leaves -> topology updates -> graph re-analyzed -> dashboard renders

UC079: **Zenoh Health Monitoring** — `zenoh/safety` + `zenoh/client` -> `grafana_zenoh_graph` node graph panel
  Figma: UC043 (Grafana Zenoh) + UC083 (Mesh Latency)
  Closed loop: Zenoh disconnection > 30s -> alert -> exponential backoff reconnect -> health restored

UC080: **OTel-over-Zenoh (OoZ)** — `ui/zenoh_otel` publishes spans to `indrajaal/otel/spans/**` -> `vega_lite_scatter` latency
  Figma: UC023 (OTel Pipeline)
  Auto-evolution: Span format evolves -> schema updated -> old consumers notified -> migration

UC081: **MCP-over-Zenoh (MoZ)** — `bridge/zenoh_mcp` JSON-RPC over pub/sub -> `mermaid_build_sequence` protocol trace
  Figma: UC087 (ZMOF Backplane)
  Closed loop: MoZ request -> Zenoh transport -> tool executes -> response published -> client receives

UC082: **Quorum Router Management** — `zenoh/client` x4 routers -> `petgraph_min_spanning_tree` for optimal routing
  Figma: UC081 (Router Cards) + UC088 (Quorum Voting)
  Closed loop: Router fails -> quorum recalculated -> if < 2oo3 -> alert -> restart -> quorum restored

UC083: **Topic Hierarchy Browser** — `zenoh/domain` key expressions -> `petgraph_neighbors` for tree -> `ui/wisp/zenoh_browser_api`
  Figma: UC080 (Topic Browser) + UC086 (Key Expression)
  Auto-evolution: New topic created -> browser auto-discovers -> hierarchy updated

UC084: **Pub/Sub Flow Visualization** — `agui/zenoh_bus` + `kurbo_vec2_from_angle` + `kurbo_path_from_points` for directional arrows
  Figma: UC082 (Pub/Sub Arrows)
  Closed loop: New subscription -> flow arrow added -> diagram updates -> verify delivery

UC085: **Partition Detection** — `petgraph_connected_components` on router graph -> if > 1 -> split-brain alert
  Figma: UC085 (Partition Detection)
  Closed loop: Partition detected -> SIL4-015 apoptosis -> minority fenced -> data preserved -> reconcile

UC086: **Mesh Metrics Dashboard** — `grafana_zenoh_graph` + `grafana_ooda_timeseries` -> assembled dashboard
  Figma: UC043 (Grafana Zenoh Mesh)
  Auto-evolution: New metric published -> Grafana panel auto-added -> dashboard grows

UC087: **A2A Agent Communication** — `agui/zenoh_bus` cross-agent messaging -> `mermaid_build_sequence` for A2A flow
  Figma: UC035 (AG-UI Sequence)
  Closed loop: Agent A publishes -> Agent B subscribes -> result published -> UI updates

UC088: **Zenoh Session Lifecycle** — `zenoh/lifecycle` manage session -> `mermaid_build_state_diagram` for lifecycle states
  Figma: UC088 (Zenoh Lifecycle)
  Closed loop: Session drops -> auto-reconnect with backoff -> re-subscribe topics -> health restored

UC089: **Cluster Event Coordination** — `zenoh/client` `indrajaal/cluster/events` -> `graphene_bfs` for event propagation analysis
  Figma: UC034 (Mesh Topology)
  Auto-evolution: Cluster event -> all nodes receive -> verify via observer -> log to zettelkasten

---

# L7 FEDERATION (UC090-UC100)

UC090: **3-Region Federation Topology** — `ha/zenoh_federation` EU+US+APAC -> `petgraph_dijkstra` for optimal routing
  Figma: UC098 (3-Region Federation) + UC091 (World Map)
  Closed loop: Message sent -> routed via shortest path -> delivered -> latency measured -> route optimized

UC091: **Leader Election** — `ha/crdt` + Zenoh lease -> Primary/Backup/Standby -> `mermaid_build_state_diagram`
  Figma: UC099 (Leader Election State Machine)
  Closed loop: Leader fails -> election triggers -> new leader elected -> state transferred -> operations resume

UC092: **Version Vector Tracking** — `ha/crdt` version vectors -> `ui/wisp/federation_api` -> `vega_lite_heatmap` sync status
  Figma: UC092 (Version Vector Display) + UC096 (Sync Status)
  Closed loop: Concurrent update -> version vectors diverge -> CRDT merge -> vectors converge

UC093: **Gateway Message Routing** — `gateway/telegram` + `gateway/gchat` + `gateway/whatsapp` -> `mermaid_build_flowchart`
  Figma: UC093 (Gateway Router) + UC040 (API Map)
  Closed loop: Message received -> classify intent -> route to cortex -> process -> broadcast response

UC094: **Ed25519 Attestation** — `core/ids` cryptographic identity -> `bevy_color` for valid(green)/expired(red) badge
  Figma: UC094 (Attestation Badge)
  Closed loop: Attestation expires (1h) -> auto-renew -> if renewal fails -> node quarantined

UC095: **Cross-Region Latency Monitoring** — `petgraph_bellman_ford` for all-pairs latency -> `vega_lite_heatmap` 3x3 matrix
  Figma: UC095 (Cross-Region Latency)
  Auto-evolution: Latency increases -> route recalculated -> if no improvement -> alert operator

UC096: **Federation Sync Protocol** — `ha/crdt` replication -> `petgraph_all_edges` for sync graph -> `vega_lite_bar` sync lag
  Figma: UC096 (Sync Status)
  Closed loop: Sync lag > threshold -> priority replication -> lag reduces -> normal mode

UC097: **Multi-Node Consensus** — `verification/swarm` 2oo3 voting -> `graphene_scc` verify all nodes reachable
  Figma: UC088 (Quorum Voting) + UC005 (2oo3 Visualization)
  Closed loop: Vote requested -> 2oo3 collected -> if consensus -> act -> else -> escalate

UC098: **Chat Pipeline Broadcast** — `agents/cortex` -> `gateway/*` parallel broadcast to Telegram+GChat+WhatsApp
  Figma: UC093 (Gateway Router)
  Closed loop: Intent processed -> response generated -> broadcast to all channels -> delivery confirmed

UC099: **Smriti Knowledge Federation** — `zettelkasten/*` + `db/cross_holon` -> federated knowledge across nodes
  Figma: UC074 (Knowledge Graph)
  Auto-evolution: Knowledge created on Node A -> replicated to Node B -> both searchable -> no data loss

UC100: **Email Report Generation** — sa-plan-daemon send-email + `skia_render_all` PNGs + `vega_lite_*` chart specs -> daily digest
  Figma: UC044 (Email Template) + UC049 (Wireframe Pipeline)
  Closed loop: Cron 6AM -> metrics collected -> charts generated -> PNGs rendered -> email sent -> zettelkasten logs

---

# FIGMA MAPPING MATRIX

| Figma UC | cepaf_gleam UC | Closed Loop? |
|----------|---------------|:------------:|
| UC001 (Palette) | UC031 (Badge Gradient) | ✓ |
| UC002 (WCAG) | UC027 (Validation) | ✓ |
| UC003 (Emergency) | UC009 (Emergency Stop) | ✓ |
| UC004 (2oo3) | UC005 (2oo3 Verify) | ✓ |
| UC006 (Approval) | UC001 (Guardian Audit) | ✓ |
| UC007 (Psi Chart) | UC002 (Psi Verify) | ✓ |
| UC009 (Easing) | UC036 (Bezier Animation) | ✓ |
| UC011 (Ring) | UC037 (Progress Ring) | ✓ |
| UC012 (Grid) | UC032 (Table Auto-Sizer) | ✓ |
| UC013 (Kanban) | UC046 (Kanban Layout) | ✓ |
| UC015 (Weather) | UC024 (Freshness Monitor) | ✓ |
| UC016 (Timeline) | UC048 (Pipeline Trace) | ✓ |
| UC017 (Sparkline) | UC019 (Sparkline Gen) | ✓ |
| UC018 (Chat) | UC068 (Gemma Chat) | ✓ |
| UC021 (Health) | UC059 (System Health) | ✓ |
| UC023 (Heatmap) | UC013 (Fractal Integrity) | ✓ |
| UC024 (OODA) | UC065 (OODA Loop) | ✓ |
| UC025 (Age) | UC054 (Image Staleness) | ✓ |
| UC026 (Gantt) | UC040 (Critical Path) | ✓ |
| UC031 (State) | UC006 (State Machine Gen) | ✓ |
| UC032 (Nav) | UC070 (PageRank Priority) | ✓ |
| UC033 (Boot) | UC052 (Boot Orchestration) | ✓ |
| UC034 (Mesh) | UC078 (Zenoh Topology) | ✓ |
| UC035 (Sequence) | UC067 (MCP Dispatch) | ✓ |
| UC039 (Cascade) | UC053 (Health Cascade) | ✓ |
| UC041 (Grafana) | UC016 (Telemetry Dash) | ✓ |
| UC045 (Task DAG) | UC039 (DAG Validation) | ✓ |
| UC048 (Cockpit) | UC010 (Dark Cockpit) | ✓ |
| UC049 (Wireframe) | UC008 (Evidence Package) | ✓ |
| UC050 (Parity) | UC011 (Wiring Guard) | ✓ |

ALL 30 Figma use cases mapped to cepaf_gleam use cases with closed loops.

---

# AUTO-EVOLUTION INTEGRATION POINTS

| Trigger | Observer | Actor | Verifier | Publisher |
|---------|----------|-------|----------|-----------|
| File edited | PostToolUse hook | gleam build | 0 errors gate | hot_reload |
| Test fails | gleam test | code-evolution agent | gleam test again | zettelkasten |
| Health drops | actors/freshness | ha/degradation | ha/fitness_gate | gateway/telegram |
| Coverage gaps | testing/coverage_math | test-generator agent | H >= 2.5 gate | zettelkasten |
| Deploy | ha/canary_controller | web/server | ha/fitness_gate | grafana |
| Sprint end | ha/evolution_scheduler | agents/cortex | graphene_scc | sa-plan send-email |
| Error | ha/anomaly_detector | ha/guard_rules | verification/ | zettelkasten |
| New page | fractal/l*_widget | skia_render + mermaid | wiring_guard | docs/ commit |
