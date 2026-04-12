# Claude + Figma Design — 100 Use Cases across 8 Fractal Layers
# क्लॉड + फिगमा — 8 भग्नात्मक स्तरों पर 100 उपयोग
**Date**: 2026-04-12 | **Libraries**: 10 packages, 125 Gleam fn

Each use case = Layer + Category + Workflow + Functions + Figma Output + Operational Use

---

# L0 CONSTITUTIONAL — Safety, Guardian, Psi Invariants (UC001-UC012)

### Design System at L0
UC001: **Guardian Approval Modal Colors** — `bevy_color_hex_to_srgba("#ff4757")` -> verify red has WCAG 4.5:1 against dark bg -> Figma: Emergency button component
UC002: **Psi Invariant Badge Set** — `kurbo_shape_typed(SvgRect)` for 6 Psi badges (Psi-0..5, Omega-0) -> `bevy_color` per severity -> Figma: Badge library
UC003: **Emergency Stop Button** — `kurbo_shape_typed(SvgCircle)` 80px red circle + `bevy_color_srgba_to_oklch` verify visibility -> Figma: L0 emergency component

### UI Components at L0
UC004: **2oo3 Voting Visualization** — `kurbo_shape_typed(SvgCircle)` x3 nodes + `kurbo_path_from_points` connecting lines -> Figma: Voting panel component
UC005: **Constitutional Hash Display** — `kurbo_rect_area` for monospace hash layout + `bevy_color` for integrity indicators -> Figma: Hash verification widget
UC006: **Guardian Approval Flow** — `mermaid_build_sequence(["Agent","Guardian","Human","System"])` -> Figma: Approval sequence prototype

### Data Viz at L0
UC007: **Psi Invariant Health Chart** — `vega_lite_bar` with 6 invariant scores -> Figma: Constitutional health panel
UC008: **Safety Gate Heatmap** — `vega_lite_heatmap` across 16 containers x 6 gates -> Figma: Safety matrix

### Architecture at L0
UC009: **L0 State Machine** — `c3i_page_state_machine()` + `skia_render_machine` -> Figma: State diagram frame
UC010: **Constitutional Verification Flow** — `mermaid_build_flowchart("TD")` for PROMETHEUS proof chain -> Figma: Verification architecture
UC011: **Immutable Register Diagram** — `petgraph_dot_export` for append-only log structure -> Figma: Audit trail visualization

### Operations at L0
UC012: **SIL-6 Compliance Dashboard** — `grafana_health_gauge("SIL-6 Score")` + `grafana_alert_list("Constitutional")` -> Figma: Grafana dashboard wireframe

---

# L1 ATOMIC/DEBUG — Telemetry, NIF, Tracing (UC013-UC024)

### Design System at L1
UC013: **Telemetry Color Scale** — `bevy_color_srgba_to_hsla` generate 10-step latency heat scale (green 0ms -> red 100ms) -> Figma: Latency color tokens
UC014: **Debug Trace Font System** — `kurbo_size_area` for monospace character grid calculations -> Figma: Debug panel typography
UC015: **NIF Status Indicator** — `bevy_color_hex_to_srgba` for loaded/unloaded/error states -> Figma: NIF badge variants

### UI Components at L1
UC016: **OTel Span Timeline** — `vega_lite_timeline_gantt` for trace spans + `kurbo_rect_intersect` for overlap detection -> Figma: Trace viewer component
UC017: **Sparkline Widget** — `vega_lite_health_sparkline` for inline metric trends + `kurbo_bezier_cubic_eval` for smooth curves -> Figma: Sparkline atom
UC018: **NIF Health Panel** — `skia_render_component("c1_weather")` for 4-state NIF status display -> Figma: NIF monitor widget
UC019: **Event Stream Log** — `kurbo_rect_area` for row sizing + `bevy_color` for event type coding -> Figma: Real-time event list

### Data Viz at L1
UC020: **Latency Distribution** — `vega_lite_scatter` (request latency vs time) + `vega_lite_line` for p50/p95/p99 -> Figma: Latency analysis panel
UC021: **NIF Call Frequency** — `vega_lite_bar` for NIF function call counts -> Figma: NIF usage chart
UC022: **Zenoh Message Rate** — `vega_lite_area` for message throughput over time -> Figma: Throughput sparkline

### Architecture at L1
UC023: **OTel Pipeline Diagram** — `mermaid_build_flowchart("LR", [("App","Collector"),("Collector","Zenoh"),("Zenoh","Dashboard")])` -> Figma: Telemetry architecture
UC024: **NIF Bridge Diagram** — `mermaid_build_sequence(["Gleam","Erlang","Rust","Zenoh"])` -> Figma: NIF call flow

---

# L2 COMPONENT — Pure Logic, Forms, Badges (UC025-UC037)

### Design System at L2
UC025: **A2UI Component Type Scale** — `kurbo_shape_typed` for each of 10 A2UI types (badge, button, data_table, etc.) -> Figma: Component catalog
UC026: **Form Input Sizing** — `kurbo_rect_area` + `kurbo_rect_inflate(8px padding)` for input fields -> Figma: Input component variants
UC027: **Badge Gradient System** — `bevy_color_srgba_to_hsla` -> shift hue by 10 for gradient badge pairs -> Figma: Gradient badge tokens
UC028: **Button Touch Target** — `kurbo_rect_contains` verify all buttons >= 44x44px (WCAG) -> Figma: Touch target overlay

### UI Components at L2
UC029: **Data Table Row Design** — `kurbo_rect_area` for column widths + `bevy_color` for alternating rows -> Figma: Table row variants (even/odd/hover/selected)
UC030: **Modal Dialog Design** — `kurbo_rect_inflate` for padding + `kurbo_affine_scale` for responsive sizing -> Figma: Modal component with overlay
UC031: **Form Validation States** — `bevy_color_hex_to_srgba` for success/warning/error states -> Figma: Input state variants (5 states)
UC032: **Dropdown Menu** — `kurbo_rect_union` for bounding box + `kurbo_rect_contains` for hit testing -> Figma: Dropdown with items
UC033: **Tooltip Component** — `kurbo_triangle_area` for arrow sizing + `kurbo_affine_rotate` for arrow direction -> Figma: Tooltip variants (top/bottom/left/right)
UC034: **Slider Component** — `kurbo_bezier_cubic_eval` for non-linear value mapping + `kurbo_vec2_lerp` for thumb position -> Figma: Range slider

### Data Viz at L2
UC035: **Mini Bar Chart** — `vega_lite_bar` embedded in table cell -> Figma: Inline micro-chart
UC036: **Progress Indicator** — `kurbo_shape_typed(SvgCircle)` for ring + `vega_lite_pie` for segment -> Figma: Circular progress variants

### Architecture at L2
UC037: **A2UI Catalog Structure** — `mermaid_build_flowchart` showing 10 component types x 8 layers -> Figma: Component hierarchy diagram

---

# L3 TRANSACTION — State, DB, Planning (UC038-UC050)

### Design System at L3
UC038: **Task Status Color System** — `bevy_color_hex_to_srgba` for BLOCKED=#ff4757, ACTIVE=#4d96ff, PENDING=#7a8fa6, DONE=#3dd68c -> Figma: Status color tokens
UC039: **Priority Gradient Badges** — P0 `bevy_color_srgba_to_hsla` + gradient from #ff4757->#ff6b81 -> Figma: Priority badge set

### UI Components at L3
UC040: **Task Card Design** — `kurbo_shape_typed(SvgRect)` + `kurbo_rect_inflate` for P0 glow border -> Figma: Kanban card (12 variants)
UC041: **State Diff Viewer** — `kurbo_rect_area` for before/after columns + `bevy_color` for add/remove highlighting -> Figma: Diff panel component
UC042: **Command History Panel** — `kurbo_rect_area` for log entry sizing -> Figma: Command history with timestamps
UC043: **Task Detail Panel** — `kurbo_affine_translate` for slide-in animation + `kurbo_rect_area` for 400px panel -> Figma: Detail panel (5 actions)
UC044: **SQLite WAL Indicator** — `vega_lite_health_sparkline` for WAL checkpoint timing -> Figma: DB health widget

### Data Viz at L3
UC045: **Task Dependency Graph** — `petgraph_dijkstra` for critical path + `petgraph_dot_export_full` -> Figma: Task DAG with critical path
UC046: **Sprint Burndown** — `vega_lite_line` for ideal vs actual burndown -> Figma: Burndown chart component
UC047: **WIP Limit Gauge** — `vega_lite_bar` horizontal with WIP limit line -> Figma: Kanban WIP indicator

### Architecture at L3
UC048: **Planning Data Model** — `mermaid_build_flowchart` for Smriti.db schema -> Figma: ER diagram
UC049: **Transaction Flow** — `mermaid_build_sequence(["Client","Wisp","NIF","SQLite"])` -> Figma: Transaction sequence
UC050: **CRDT Merge Diagram** — `mermaid_build_flowchart` for GCounter/PNCounter/ORSet merge logic -> Figma: CRDT visualization

---

# L4 SYSTEM — Containers, Podman, Boot (UC051-UC063)

### Design System at L4
UC051: **Container Category Colors** — 8 categories x `bevy_color_hex_to_srgba` (ElixirApp=blue, Zenoh=cyan, DB=green, etc.) -> Figma: Container color tokens
UC052: **Health State Icons** — `kurbo_shape_typed` for healthy(circle)/degraded(triangle)/critical(diamond) -> Figma: Health icon set

### UI Components at L4
UC053: **Container Card Grid** — `kurbo_rect_area` for 16-card grid layout + `kurbo_rect_intersect` for responsive reflow -> Figma: Container grid (4x4/2x8/1x16)
UC054: **Build Progress Bar** — `kurbo_shape_typed(SvgRect)` + EMA fill ratio -> Figma: Build progress with EMA estimate
UC055: **Container Health Row** — `bevy_color` for status badge + `kurbo_rect_area` for table row -> Figma: Container table row variants
UC056: **Port Binding Table** — `kurbo_rect_area` for column layout with 16 ports -> Figma: Port assignment table

### Data Viz at L4
UC057: **Boot Sequence Timeline** — `vega_lite_timeline_gantt` for 7-tier boot with parallel waves -> Figma: Boot Gantt chart
UC058: **Container Health Heatmap** — `vega_lite_fractal_heatmap` for 16 containers x 5 health metrics -> Figma: Container heatmap
UC059: **Image Staleness Chart** — `vega_lite_bar` showing image age vs 168h threshold -> Figma: Image freshness chart
UC060: **CPU Governor Dashboard** — `vega_lite_area` for CPU% over time with 85% limit line -> Figma: CPU monitoring panel

### Architecture at L4
UC061: **16-Container Genome** — `petgraph_dot_export_full` for boot dependency DAG -> Figma: Genome architecture diagram
UC062: **Boot Tier Diagram** — `mermaid_build_flowchart("TD")` for 7-tier sequence -> Figma: Boot sequence diagram
UC063: **Health Check Flow** — `mermaid_build_sequence(["Podman","Container","TCP","Health"])` -> Figma: Health check sequence

---

# L5 COGNITIVE — OODA, MCP, AI Advisory (UC064-UC076)

### Design System at L5
UC064: **OODA Phase Colors** — Observe=#00d4aa, Orient=#4d96ff, Decide=#f5a623, Act=#3dd68c via `bevy_color` -> Figma: OODA color tokens
UC065: **AI Response Bubble Style** — `kurbo_shape_typed(SvgRect)` with 8px radius + `bevy_color` for model-specific tint -> Figma: Chat bubble variants

### UI Components at L5
UC066: **OODA Ring Widget** — `kurbo_shape_typed(SvgCircle)` x4 concentric rings + `kurbo_affine_rotate` per phase -> Figma: OODA ring component
UC067: **AI Copilot Panel** — `kurbo_rect_area` for 400x500px floating panel + `kurbo_affine_translate` for minimize animation -> Figma: Copilot panel with states
UC068: **Reasoning Display** — `kurbo_rect_inflate` for thought bubble padding + `bevy_color` for reasoning vs encrypted -> Figma: Reasoning viewer
UC069: **MCP Tool Call Panel** — `mermaid_build_sequence(["Agent","MCP","Tool","Result"])` as inline sequence -> Figma: Tool invocation widget
UC070: **Gemma Model Selector** — `bevy_color` badges for Gemma3(fast) vs Gemma4(deep) -> Figma: Model toggle component

### Data Viz at L5
UC071: **OODA Cycle Timing** — `vega_lite_ooda_ring` donut + `vega_lite_line` for timing trend -> Figma: OODA analytics panel
UC072: **Inference Latency** — `vega_lite_scatter` for model latency vs accuracy -> Figma: Model comparison chart
UC073: **Rule Engine Heatmap** — `vega_lite_heatmap` for 52 GRL rules x 13 domains -> Figma: Rule activation matrix
UC074: **Knowledge Graph** — `petgraph_neighbors` for Zettelkasten connections + `petgraph_dot_export` -> Figma: Knowledge graph visualization

### Architecture at L5
UC075: **6-Tier Inference Cascade** — `mermaid_build_flowchart("TD")` for Gemini->OpenRouter->Ollama->Rules chain -> Figma: Inference architecture
UC076: **Cortex ReAct Loop** — `mermaid_build_state_diagram` for ProcessIntent->Observe->Decide->Act cycle -> Figma: Cortex state diagram

---

# L6 ECOSYSTEM — Zenoh Mesh, Quorum (UC077-UC088)

### Design System at L6
UC077: **Mesh Node Category Shapes** — `kurbo_shape_typed(SvgCircle)` for routers, `SvgRect` for apps, `SvgPolygon(6)` for DB -> Figma: Topology node icons
UC078: **Quorum Health Indicators** — 3-dot voting display (green=agree, red=disagree) via `kurbo_shape_typed(SvgCircle)` x3 -> Figma: Quorum widget

### UI Components at L6
UC079: **Mesh Topology Map** — `petgraph_all_edges` + `kurbo_path_from_points` for connections + `bevy_math_vec3_cross` for 3D layout -> Figma: Interactive topology view
UC080: **Zenoh Topic Browser** — `petgraph_neighbors` for topic tree + `kurbo_rect_area` for tree layout -> Figma: Topic hierarchy panel
UC081: **Router Health Cards** — `kurbo_shape_typed(SvgRect)` x4 router cards + `bevy_color` for status -> Figma: Router card set
UC082: **Pub/Sub Flow Arrows** — `kurbo_vec2_from_angle` + `kurbo_path_from_points` for directional arrows -> Figma: Data flow arrows

### Data Viz at L6
UC083: **Mesh Latency Chart** — `vega_lite_line` for inter-node latency over time -> Figma: Latency trend chart
UC084: **Topic Throughput** — `vega_lite_area` stacked for top 10 Zenoh topics by message rate -> Figma: Throughput breakdown
UC085: **Partition Detection** — `petgraph_connected_components` result as `vega_lite_pie` (1=healthy, >1=partitioned) -> Figma: Partition alert widget

### Architecture at L6
UC086: **Zenoh Key Expression Tree** — `petgraph_dot_export` for `indrajaal/**` topic hierarchy -> Figma: Key expression map
UC087: **ZMOF Backplane Diagram** — `mermaid_build_flowchart("LR")` for OoZ + MoZ protocol layers -> Figma: ZMOF architecture
UC088: **Quorum Voting Sequence** — `mermaid_build_sequence(["Node1","Node2","Node3","Consensus"])` for 2oo3 protocol -> Figma: Voting sequence

---

# L7 FEDERATION — Multi-Node, Gateway, Consensus (UC089-UC100)

### Design System at L7
UC089: **Region Theme Colors** — EU=#00d4aa, US=#4d96ff, APAC=#f5a623 via `bevy_color_hex_to_srgba` -> Figma: Region color tokens
UC090: **Federation Status Icons** — `kurbo_shape_typed(SvgStar(5))` for federation node + `bevy_color` per region -> Figma: Federation node icons

### UI Components at L7
UC091: **World Map Layout** — `kurbo_affine_translate` to position 3 region nodes + `kurbo_path_from_points` for connections -> Figma: Global topology view
UC092: **Version Vector Display** — `kurbo_rect_area` for vector clock table + `bevy_color` for conflict highlighting -> Figma: Version vector widget
UC093: **Gateway Message Router** — `mermaid_build_flowchart("LR")` for Telegram->Gateway->Zenoh flow -> Figma: Gateway routing panel
UC094: **Attestation Badge** — `kurbo_shape_typed(SvgPolygon(6))` hexagonal Ed25519 badge + `bevy_color` for valid/expired -> Figma: Attestation indicator

### Data Viz at L7
UC095: **Cross-Region Latency** — `vega_lite_heatmap` for 3x3 region latency matrix -> Figma: Inter-region latency map
UC096: **Federation Sync Status** — `vega_lite_bar` for sync lag per region -> Figma: Sync status chart
UC097: **Message Delivery Timeline** — `vega_lite_timeline_gantt` for cross-region message delivery -> Figma: Delivery timeline

### Architecture at L7
UC098: **3-Region Federation** — `petgraph_dot_export_full` for EU-US-APAC topology with weighted edges -> Figma: Federation architecture
UC099: **Leader Election State Machine** — `mermaid_build_state_diagram` for Primary/Backup/Standby states + `skia_render_machine` -> Figma: HA state diagram
UC100: **Optimal Message Routing** — `petgraph_dijkstra` for shortest path between regions + `petgraph_bellman_ford` for negative-weight detection -> Figma: Routing optimization diagram

---

# CROSS-REFERENCE MATRIX

## Use Cases per Package
| Package | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | Total |
|---------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:-----:|
| bevy_color | 3 | 2 | 3 | 2 | 2 | 2 | 1 | 2 | **17** |
| kurbo | 3 | 1 | 7 | 4 | 4 | 3 | 3 | 3 | **28** |
| vega_lite | 2 | 3 | 2 | 3 | 4 | 3 | 3 | 3 | **23** |
| mermaid | 2 | 2 | 1 | 3 | 2 | 3 | 2 | 2 | **17** |
| petgraph | 1 | 0 | 0 | 1 | 1 | 1 | 3 | 2 | **9** |
| skia | 2 | 1 | 0 | 0 | 0 | 0 | 0 | 1 | **4** |
| grafana | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | **2** |
| graphene | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1** |
| bevy_math | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | **2** |
| bevy_ecs | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **0** |

## Use Cases per Category
| Category | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | Total |
|----------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:-----:|
| Design System | 3 | 3 | 4 | 2 | 2 | 2 | 2 | 2 | **20** |
| UI Components | 3 | 4 | 6 | 5 | 4 | 5 | 4 | 4 | **35** |
| Data Viz | 2 | 3 | 2 | 3 | 4 | 4 | 3 | 3 | **24** |
| Architecture | 3 | 2 | 1 | 3 | 3 | 2 | 3 | 3 | **20** |
| Operations | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **1** |
