# Claude + Figma Design — 50 Use Cases with Graphene NIF
# क्लॉड + फिगमा डिज़ाइन — ग्राफीन एनआईएफ के साथ 50 उपयोग

**Date**: 2026-04-12 | **Libraries**: 10 packages, 125 Gleam fn
**Workflow**: Claude generates -> Graphene NIF computes/renders -> Figma receives design tokens/specs

---

## A. DESIGN SYSTEM GENERATION (UC01-UC10)

### UC01: Color Palette Generation from Brand Hex
**Workflow**: Designer provides brand hex (#00d4aa) -> Claude generates full palette
**Functions**: `bevy_color_hex_to_srgba` -> `bevy_color_srgba_to_hsla` -> rotate hue by 30/60/120/180 -> `bevy_color_hsla_to_srgba` -> `bevy_color_srgba_to_hex`
**Figma output**: 12 color swatches (primary, secondary, tertiary, complementary, analogous, triadic) as Figma Variables
**Operational use**: Auto-generate Dark Cockpit 5-mode color profiles

### UC02: WCAG Contrast Ratio Verification
**Workflow**: Claude checks every text/background pair for WCAG 2.1 AA compliance
**Functions**: `bevy_color_hex_to_srgba` -> `bevy_color_srgba_to_oklch` -> compute L* difference -> pass/fail
**Figma output**: Annotated color matrix showing pass/fail for each pair
**Operational use**: Pre-deploy accessibility gate (SC-HMI-009)

### UC03: Perceptual Color Space Theme Design
**Workflow**: Design theme in OKLCH (perceptually uniform) then convert to sRGB
**Functions**: `bevy_color_srgba_to_oklch` -> adjust L/C/H uniformly -> `bevy_color_hsla_to_srgba`
**Figma output**: Theme tokens with OKLCH source values + sRGB computed values
**Operational use**: L0-L7 fractal layer colors with guaranteed perceptual distinctness

### UC04: Responsive Spacing Scale Computation
**Workflow**: Define base unit -> Claude computes golden ratio / 8px grid scale
**Functions**: `kurbo_size_area` for viewport calculations, `kurbo_rect_area` for padding
**Figma output**: Spacing scale (4/8/12/16/24/32/48/64/96px) as Figma Variables
**Operational use**: Consistent spacing across Mobile/Tablet/Desktop/Wide breakpoints

### UC05: Typography Scale Generation
**Workflow**: Base font size + ratio -> compute heading/body/caption scale
**Functions**: `bevy_math_vec3_lerp` for size interpolation, `kurbo_size_area` for viewport fit
**Figma output**: Type scale (12/14/16/18/20/24/32/40px) with line-height ratios
**Operational use**: TUI ANSI rendering uses same scale (character grid)

### UC06: Icon Grid & Shape Generation
**Workflow**: Claude generates consistent icon shapes from geometric primitives
**Functions**: `kurbo_shape_typed(SvgCircle/SvgRect/SvgStar/SvgPolygon)` -> `kurbo_affine_scale` -> `kurbo_path_from_points`
**Figma output**: SVG icon set (24x24, 32x32, 48x48) on pixel grid
**Operational use**: A2UI catalog component icons (10 types x 8 layers)

### UC07: Design Token Export as JSON
**Workflow**: Claude extracts all design decisions into structured JSON tokens
**Functions**: All `bevy_color_*` for colors, `kurbo_size_area` for dimensions, `kurbo_rect_area` for layout
**Figma output**: design-tokens.json (Style Dictionary format) for Figma Tokens plugin
**Operational use**: Tokens consumed by Lustre SSR, Wisp API, TUI ANSI renderer

### UC08: Dark/Light Mode Token Generation
**Workflow**: Generate paired dark/light tokens from single semantic color
**Functions**: `bevy_color_srgba_to_hsla` -> invert lightness -> `bevy_color_hsla_to_srgba` -> `bevy_color_srgba_to_hex`
**Figma output**: Two token sets (dark=default, light=Solaris) switchable in Figma
**Operational use**: Dark Cockpit 5-mode (Dark/Dim/Normal/Bright/Emergency)

### UC09: Animation Easing Curve Design
**Workflow**: Design bezier easing curves visually, export as CSS timing functions
**Functions**: `kurbo_bezier_cubic_eval` to sample curve at 100 points, `kurbo_path_from_points` for SVG preview
**Figma output**: Easing curve visualization + CSS cubic-bezier() value
**Operational use**: Row highlight fade (1.8s), panel slide (200ms), toast appear (200ms)

### UC10: Component Shadow & Elevation System
**Workflow**: Define elevation levels with computed shadow parameters
**Functions**: `bevy_math_vec3_lerp` for shadow offset interpolation, `bevy_color_srgba_to_hsla` -> reduce lightness for shadow color
**Figma output**: 5 elevation levels with box-shadow CSS values
**Operational use**: Glassmorphism cards, floating panels, modal overlays

---

## B. UI COMPONENT DESIGN (UC11-UC20)

### UC11: Progress Ring SVG Generation
**Workflow**: Claude generates SVG progress rings for any percentage
**Functions**: `kurbo_shape_typed(SvgCircle)` -> `kurbo_affine_rotate` -> stroke-dasharray calculation
**Figma output**: Progress ring component with configurable fill ratio
**Operational use**: C2 Progress Rings (Active/Blocked/Completed)

### UC12: Data Grid Column Layout
**Workflow**: Auto-compute column widths based on content + viewport
**Functions**: `kurbo_rect_area` for total width, `kurbo_rect_intersect` for column overlap detection
**Figma output**: Responsive grid layout with breakpoint variants (1/2/4 col)
**Operational use**: C4 Task Grid (7 columns, 36px rows, Tabulator)

### UC13: Kanban Board Card Design
**Workflow**: Design card variants for each priority/status combination
**Functions**: `bevy_color_hex_to_srgba` for priority colors, `kurbo_rect_inflate` for padding, `kurbo_shape_typed(SvgRect)` for card shape
**Figma output**: Card component with 12 variants (4 priorities x 3 states)
**Operational use**: C5 Kanban Board (P0 red glow, P1 amber, P2 blue, P3 gray)

### UC14: Navigation Header Responsive Design
**Workflow**: Design header that adapts from hamburger (mobile) to full nav (desktop)
**Functions**: `kurbo_rect_contains` for hit testing, `kurbo_rect_union` for bounding box merge
**Figma output**: Header component with 4 breakpoint variants
**Operational use**: Shell.gleam navigation (4 grouped dropdowns + hamburger)

### UC15: Weather Bar Status Indicator Design
**Workflow**: Design health bar with animated states
**Functions**: `kurbo_shape_typed` for bar shape, `bevy_color_hsla_to_srgba` for health-to-color mapping
**Figma output**: Weather bar component in 5 states (Healthy/Degraded/Critical/Disconnected/Loading)
**Operational use**: C1 Weather Bar (32px header, health bar, live dot)

### UC16: Detail Panel Slide-In Design
**Workflow**: Design panel that slides from right (desktop) or bottom (mobile)
**Functions**: `kurbo_affine_translate` for slide animation path, `kurbo_rect_area` for panel sizing
**Figma output**: Detail panel with slide animation prototype + 5 content states
**Operational use**: C9 Detail Panel (400px slide-in, 5 actions, AI analysis)

### UC17: Triage Zone Layout Design
**Workflow**: Design 3-zone mobile layout (Critical/Attention/Nominal)
**Functions**: `kurbo_rect_inflate` for zone padding, `bevy_color_hex_to_srgba` for zone border colors
**Figma output**: Mobile triage layout with 44px touch targets, zone headers
**Operational use**: C4.zones Mobile Triage (on-call 3AM pattern)

### UC18: AI Chat Widget Design
**Workflow**: Design floating chat panel with message bubbles + shimmer loading
**Functions**: `kurbo_shape_typed(SvgRect)` for bubbles, `kurbo_bezier_cubic_eval` for shimmer animation curve
**Figma output**: Chat widget component with typing/waiting/response states
**Operational use**: C10 Gemma Chat (400x500px floating panel)

### UC19: Fractal Filter Chip Design
**Workflow**: Design L0-L7 chip components with layer-specific colors
**Functions**: `bevy_color_hex_to_srgba` per layer color, `kurbo_shape_typed(SvgRect)` for chip shape
**Figma output**: 9 chip variants (All + L0-L7) in active/inactive states
**Operational use**: C12 Fractal Filter (controls bar, 50x24px chips)

### UC20: Change Log Entry Design
**Workflow**: Design log entries with type-coded colors (status/priority/new/diff)
**Functions**: `bevy_color_srgba_to_hsla` for desaturation in Dim mode
**Figma output**: 5 log entry variants + ticker bar + expanded panel + mobile toast
**Operational use**: C11 Change Log (20px ticker, 300px expanded, 3s toast)

---

## C. DATA VISUALIZATION DESIGN (UC21-UC30)

### UC21: Health Sparkline Chart
**Workflow**: Claude generates Vega-Lite spec -> Figma renders preview
**Functions**: `vega_lite_health_sparkline` with sample data
**Figma output**: Sparkline component with area fill, trend arrow, score labels
**Operational use**: Analytics dashboard, header weather bar trend

### UC22: Priority Distribution Bar Chart
**Workflow**: Design horizontal bar chart with P0-P3 color coding
**Functions**: `vega_lite_priority_bar` with sample distribution data
**Figma output**: Bar chart component with gradient badges
**Operational use**: Sprint planning view, stakeholder demo

### UC23: Fractal Layer Heatmap
**Workflow**: Design 8x3 heatmap (L0-L7 x metrics) with red-yellow-green scale
**Functions**: `vega_lite_fractal_heatmap` with health scores, `bevy_color_srgba_to_oklch` for perceptual color mapping
**Figma output**: Heatmap component with layer labels + health percentages
**Operational use**: Architecture review, fractal sidebar visualization

### UC24: OODA Cycle Donut Ring
**Workflow**: Design 4-segment donut showing Observe/Orient/Decide/Act timing
**Functions**: `vega_lite_ooda_ring` with timing data, `kurbo_shape_typed(SvgCircle)` for ring geometry
**Figma output**: Donut chart component with phase labels + total budget
**Operational use**: Cockpit page, cognitive monitoring dashboard

### UC25: Task Age Histogram
**Workflow**: Design 4-bucket age chart (<1d, 1-3d, 3-7d, >7d) color-coded green-to-red
**Functions**: `vega_lite_age_histogram` with task data
**Figma output**: Histogram component with bucket labels + median annotation
**Operational use**: Sprint planning, stale task identification

### UC26: Task Timeline Gantt Chart
**Workflow**: Design horizontal Gantt with status-colored bars + NOW line
**Functions**: `vega_lite_timeline_gantt` with task start/end/status data
**Figma output**: Gantt component with time axis, task bars, priority markers
**Operational use**: C6 Timeline view, project tracking

### UC27: Status Pie Chart
**Workflow**: Design pie/donut showing Blocked/Active/Pending/Completed proportions
**Functions**: `vega_lite_status_pie` with status counts
**Figma output**: Pie chart component with status legend + count labels
**Operational use**: Dashboard overview, quick status assessment

### UC28: Multi-Layer Dashboard Composition
**Workflow**: Compose multiple charts into a single dashboard view
**Functions**: `vega_lite_layered` to combine specs, `kurbo_rect_union` for layout
**Figma output**: Dashboard frame with 6-chart grid layout
**Operational use**: Analytics view (health + priority + age + fractal + flow + OODA)

### UC29: Scatter Plot for Correlation Analysis
**Workflow**: Design scatter plot showing task age vs priority
**Functions**: `vega_lite_scatter` with task metrics
**Figma output**: Scatter plot component with color-coded dots
**Operational use**: Task analysis, identifying neglected high-priority items

### UC30: Area Chart for Cumulative Flow
**Workflow**: Design stacked area showing task flow over time
**Functions**: `vega_lite_area` with time-series task data
**Figma output**: Stacked area chart with status layers
**Operational use**: Velocity tracking, WIP monitoring

---

## D. ARCHITECTURE DIAGRAMS (UC31-UC40)

### UC31: State Machine Diagram Auto-Generation
**Workflow**: Claude defines states in Gleam -> renders as PNG + SVG
**Functions**: `c3i_page_state_machine` -> `skia_render_machine` (PNG) + `mermaid_render_machine` (SVG)
**Figma output**: State diagram frame for each component (C1-C12)
**Operational use**: Spec documentation, IEC 61508 evidence

### UC32: Navigation Graph Visualization
**Workflow**: Render 22-page navigation digraph with PageRank weights
**Functions**: `c3i_nav_graph_pages` -> `graphene_pagerank` -> `petgraph_dot_export` -> Graphviz
**Figma output**: Navigation map with page nodes sized by PageRank
**Operational use**: Test priority ordering, architecture review

### UC33: Boot Sequence DAG
**Workflow**: Validate and render 16-container boot order
**Functions**: `petgraph_toposort` -> `petgraph_dot_export_full` + `mermaid_build_flowchart`
**Figma output**: Boot DAG with tier annotations (1-7) and health checks
**Operational use**: SC-BOOT-008 validation, ignition sequence documentation

### UC34: Mesh Topology Diagram
**Workflow**: Render Zenoh mesh with 4 routers + 12 containers
**Functions**: `petgraph_all_edges` + `petgraph_neighbors` -> `mermaid_build_flowchart("LR")`
**Figma output**: Mesh topology frame with color-coded node categories
**Operational use**: Zenoh page visualization, network architecture

### UC35: AG-UI Protocol Sequence Diagram
**Workflow**: Render 32-event AG-UI protocol as sequence diagram
**Functions**: `mermaid_build_sequence(["Agent","Zenoh","Lustre","User"], messages)`
**Figma output**: Sequence diagram showing agent->UI event flow
**Operational use**: AG-UI documentation, developer onboarding

### UC36: OODA Loop Flow Diagram
**Workflow**: Render OODA cycle as flowchart with timing annotations
**Functions**: `mermaid_build_flowchart("TD", ooda_nodes, ooda_edges)`
**Figma output**: OODA cycle with phase boxes and latency annotations
**Operational use**: Cognitive architecture documentation

### UC37: Dependency Graph for Task Planning
**Workflow**: Render task dependency graph with critical path highlighted
**Functions**: `petgraph_dijkstra` for critical path -> `petgraph_dot_export_full`
**Figma output**: Task DAG with red critical path + green slack paths
**Operational use**: Sprint planning, blocker identification

### UC38: Fractal Layer Architecture Diagram
**Workflow**: Render L0-L7 layer diagram with component mapping
**Functions**: `mermaid_build_flowchart` with layer grouping + `bevy_color` for layer colors
**Figma output**: 8-layer architecture diagram with component annotations
**Operational use**: Architecture documentation, onboarding

### UC39: Container Health Cascade Diagram
**Workflow**: Show how failure propagates through container dependencies
**Functions**: `graphene_bfs` from failed node -> `petgraph_dot_export` with affected nodes highlighted
**Figma output**: Cascade diagram with blast radius annotations
**Operational use**: Incident response, FMEA documentation

### UC40: API Endpoint Map
**Workflow**: Render all Wisp API endpoints as organized diagram
**Functions**: `mermaid_build_flowchart` grouping endpoints by domain
**Figma output**: API map with HTTP methods, paths, response types
**Operational use**: API documentation, frontend integration

---

## E. OPERATIONAL DASHBOARDS (UC41-UC50)

### UC41: Grafana Health Dashboard Generation
**Workflow**: Claude generates complete Grafana dashboard JSON
**Functions**: `grafana_dashboard("C3I Health", panels)` with `grafana_health_gauge` + `grafana_container_table` + `grafana_ooda_timeseries`
**Figma output**: Dashboard wireframe matching generated Grafana layout
**Operational use**: Grafana port 3000, auto-provisioned on deploy

### UC42: Grafana Fractal Layer Dashboard
**Workflow**: Generate per-layer monitoring dashboard
**Functions**: `grafana_fractal_heatmap` + `grafana_task_bar` + `grafana_alert_list`
**Figma output**: Layer-focused dashboard design with drill-down panels
**Operational use**: Architecture-aware monitoring (L0 most critical)

### UC43: Grafana Zenoh Mesh Dashboard
**Workflow**: Generate mesh topology monitoring dashboard
**Functions**: `grafana_zenoh_graph` + `grafana_ooda_timeseries` + `grafana_container_table`
**Figma output**: Network monitoring dashboard with topology graph panel
**Operational use**: Zenoh health, message rates, partition detection

### UC44: Email Report Template Design
**Workflow**: Design HTML email template for automated reports
**Functions**: `skia_draw_to_png` for inline chart images, `vega_lite_*` for chart specs
**Figma output**: Email template with embedded chart placeholders
**Operational use**: Daily health reports via SMTP (sa-plan-daemon send-email)

### UC45: TUI Split-Screen Dashboard Design
**Workflow**: Design terminal dashboard layout matching ANSI renderer
**Functions**: `kurbo_rect_area` for character grid layout, `kurbo_rect_intersect` for pane overlap
**Figma output**: ASCII-art wireframe matching terminal 80x24/120x40 viewports
**Operational use**: Split-screen TUI (dashboard + test results simultaneously)

### UC46: Mobile Incident Response Screen
**Workflow**: Design minimal mobile screen for 3AM on-call triage
**Functions**: `kurbo_rect_contains` for 44px touch targets, `bevy_color` for high-contrast emergency colors
**Figma output**: Mobile-first triage screen with maximum signal-to-noise
**Operational use**: Concept D Mobile Triage (0.906 KPI score)

### UC47: Stakeholder Presentation Dashboard
**Workflow**: Design clean demo dashboard for board presentations
**Functions**: `vega_lite_health_sparkline` + `vega_lite_priority_bar` + `vega_lite_status_pie`
**Figma output**: Presentation-quality dashboard with minimal chrome
**Operational use**: Concept C Analytics Observatory for stakeholder demos

### UC48: Dark Cockpit Mode Transition Design
**Workflow**: Design 5-mode transition (Dark->Dim->Normal->Bright->Emergency)
**Functions**: `bevy_color_srgba_to_hsla` -> adjust saturation/lightness per mode -> `bevy_color_hsla_to_srgba`
**Figma output**: 5 mode variants with transition animations specified
**Operational use**: Dark Cockpit (SC-HMI-010, SC-BIO-EVO-001)

### UC49: Component Wireframe Export Pipeline
**Workflow**: Claude generates all component wireframes, exports for Figma
**Functions**: `skia_render_all` -> 17 PNGs, `mermaid_render` -> 15 SVGs
**Figma output**: Complete component library frame with all states rendered
**Operational use**: Design system documentation, developer handoff

### UC50: Design-Code Parity Verification
**Workflow**: Claude compares Figma design tokens against running system values
**Functions**: `bevy_color_hex_to_srgba` to parse Figma hex -> compare with domain.gleam constants -> `kurbo_rect_area` to compare dimensions
**Figma output**: Parity report showing drift between design and implementation
**Operational use**: SC-TRUTH-001 (system shows truth), design-code sync gate
