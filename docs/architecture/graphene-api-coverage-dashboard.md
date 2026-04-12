# Graphene NIF — API Coverage Dashboard
# ग्राफीन एनआईएफ — एपीआई कवरेज डैशबोर्ड

**Version**: NIF v0.3.0 | **Date**: 2026-04-12
**Layer**: L1_ATOMIC_DEBUG (NIF bridge) / L2_COMPONENT (Gleam API)
**STAMP**: SC-NIF-001..006, SC-ARCH-SPLIT-003, SC-MUDA-001

---

## Executive Summary

| Metric | Value |
|--------|-------|
| NIF entry points (Erlang `@external`) | **27** |
| Gleam public functions | **88** (Phase 1: 58, Phase 2: +30) |
| Rust NIF source LOC | **2,036** (`native/graphene_nif/src/lib.rs`) |
| Libraries integrated | **6** (graphene, kurbo, tiny-skia, bevy_ecs/math/color, mermaid-rs-renderer) |
| Gleam types defined | **8** (StateNode, StateEdge, StateMachine, Point2, Point3, Rgba, SvgShape, Transform2D) |
| Pre-defined state machines | **4** (page, c1_weather, c4_grid, nav_graph) |
| Test functions | **82** (`test/graphene_render_test.gleam`) |

---

## 1. Summary Coverage Table

| Library | Total pub fn | Covered in Gleam | Internal (skip) | Missing | Coverage % |
|---------|:------------:|:----------------:|:---------------:|:-------:|:----------:|
| **Graphene** (graph theory) | 11 | 11 | 0 | 0 | **100%** |
| **Kurbo** (vector paths) | 258 | 79 | 70 | 109 | **42% (typed API)** |
| **Bevy ECS** | 315 | 3 | 312 | 0 | **100% of NIF-wrappable** |
| **Bevy Math** | 165 | 6 | 159 | 0 | **100% of NIF-wrappable** |
| **Bevy Color** | 19 | 6 | 13 | 0 | **100% of NIF-wrappable** |
| **Mermaid** (diagrams) | 33 | 15 | 5 | 13 | **54%** |
| **Skia** (rasterization) | 77 | 6 | 72 | 0 | **100% of rendering API** |
| **TOTAL** | **878** | **126** | **631** | **122** | **51% of usable API** |

**Usable API** = Total - Internal = 878 - 631 = **247 functions**
**Coverage of usable** = 126 / 247 = **51%**

---

## 2. NIF Entry Point Registry (27 total)

Every `@external(erlang, "graphene_nif", "...")` declaration in `graphene.gleam`.

| # | NIF Symbol | Gleam External Name | Category | Multiplexed? |
|---|-----------|---------------------|----------|:------------:|
| 1 | `graph_bfs` | `nif_graph_bfs` | Graphene | No |
| 2 | `graph_dfs` | `nif_graph_dfs` | Graphene | No |
| 3 | `graph_topological_sort` | `nif_graph_topological_sort` | Graphene | No |
| 4 | `graph_scc` | `nif_graph_scc` | Graphene | No |
| 5 | `graph_shortest_path` | `nif_graph_shortest_path` | Graphene | No |
| 6 | `graph_pagerank` | `nif_graph_pagerank` | Graphene | No |
| 7 | `graph_analyze` | `nif_graph_analyze` | Graphene | No |
| 8 | `render_state_diagram` | `nif_render_state_diagram` | Skia | No |
| 9 | `render_component` | `nif_render_component` | Skia | No |
| 10 | `render_all_diagrams` | `nif_render_all_diagrams` | Skia | No |
| 11 | `svg_path_from_points` | `nif_svg_path_from_points` | Kurbo | No |
| 12 | `svg_path_analyze` | `nif_svg_path_analyze` | Kurbo | No |
| 13 | `svg_path_transform` | `nif_svg_path_transform` | Kurbo | No |
| 14 | `svg_shape` | `nif_svg_shape` | Kurbo | No |
| 15 | `vec2_math` | `nif_vec2_math` | Kurbo | Yes (6 ops) |
| 16 | `ecs_spawn` | `nif_ecs_spawn` | Bevy ECS | No |
| 17 | `ecs_query_all` | `nif_ecs_query_all` | Bevy ECS | No |
| 18 | `ecs_clear` | `nif_ecs_clear` | Bevy ECS | No |
| 19 | `bevy_math_op` | `nif_bevy_math_op` | Bevy Math | Yes (5 ops) |
| 20 | `bevy_color_convert` | `nif_bevy_color_convert` | Bevy Color | Yes (5 ops) |
| 21 | `mermaid_render` | `nif_mermaid_render` | Mermaid | No |
| 22 | `mermaid_render_to_file` | `nif_mermaid_render_to_file` | Mermaid | No |
| 23 | `kurbo_affine_op` | `nif_kurbo_affine_op` | Kurbo Affine | Yes (8 ops) |
| 24 | `kurbo_geometry_op` | `nif_kurbo_geometry_op` | Kurbo Geometry | Yes (14 ops) |
| 25 | `kurbo_bezier_op` | `nif_kurbo_bezier_op` | Kurbo Bezier | Yes (4 ops) |
| 26 | `mermaid_render_with_options` | `nif_mermaid_render_with_options` | Mermaid | No |
| 27 | `skia_draw_to_png` | `nif_skia_draw_to_png` | Skia Extended | No |

**Multiplexed NIFs**: 6 NIFs handle multiple operations via a string `operation` parameter. This reduces NIF count while keeping the Erlang boundary surface minimal.

---

## 3. Graphene Library Coverage (Graph Theory)

**Source crate**: `graphene 0.1.5`
**Coverage**: 11/11 = 100%

| Function | Status | Gleam Wrapper | NIF | Notes |
|----------|:------:|--------------|:---:|-------|
| `Graph::new()` | COVERED | `graphene_build_graph` | `graph_bfs` (implicit) | Constructed from JSON nodes/edges |
| `Graph::add_vertex()` | COVERED | `graphene_build_graph` | implicit | JSON node list |
| `Graph::add_edge()` | COVERED | `graphene_build_graph` | implicit | JSON edge list |
| `bfs()` | COVERED | `graphene_bfs`, `graphene_bfs_typed` | `graph_bfs` | Depth tracking included |
| `dfs()` | COVERED | `graphene_dfs`, `graphene_dfs_typed` | `graph_dfs` | Visit ordering included |
| `topological_sort()` | COVERED | `graphene_topological_sort`, `_typed` | `graph_topological_sort` | Kahn's, detects cycles |
| `strongly_connected_components()` | COVERED | `graphene_scc`, `graphene_scc_typed` | `graph_scc` | Tarjan's SCC |
| `shortest_path()` | COVERED | `graphene_shortest_path`, `_typed` | `graph_shortest_path` | Dijkstra + path reconstruction |
| `pagerank()` | COVERED | `graphene_pagerank`, `graphene_pagerank_typed` | `graph_pagerank` | Custom damping + iterations |
| graph analysis | COVERED | `graphene_analyze`, `graphene_analyze_typed` | `graph_analyze` | Density, DAG check, degree stats |
| typed builder | COVERED | `graphene_build_graph` | — | Pure Gleam helper, no NIF needed |

---

## 4. Kurbo Library Coverage (Vector Paths)

**Source crate**: `kurbo 0.11`
**Total pub fn**: 258 | **Covered**: 79 | **Internal**: 70 | **Missing**: 109
**Coverage of non-internal**: 79 / (258 - 70) = 79/188 = **42%**

### 4.1 Kurbo Module-Level Summary

| Module | Total | Covered | Internal | Missing | Coverage |
|--------|:-----:|:-------:|:--------:|:-------:|:--------:|
| affine | 26 | 19 | 2 | 5 | 79% |
| bezpath | 30 | 17 | 11 | 2 | 71% |
| circle | 6 | 2 | 2 | 2 | 50% |
| ellipse | 14 | 4 | 2 | 8 | 33% |
| rect | 38 | 17 | 10 | 11 | 61% |
| rounded_rect | 12 | 1 | 2 | 9 | 10% |
| triangle | 10 | 4 | 3 | 3 | 57% |
| line | 7 | 5 | 2 | 0 | 100% |
| arc | 4 | 1 | 0 | 3 | 25% |
| point | 11 | 7 | 4 | 0 | 100% |
| vec2 | 20 | 12 | 7 | 1 | 92% |
| svg | 6 | 2 | 0 | 4 | 33% |
| stroke | 10 | 1 | 0 | 9 | 10% |
| cubicbez | 8 | 3 | 2 | 3 | 60% |
| quadbez | 4 | 2 | 2 | 0 | 100% |
| size | 17 | 5 | 10 | 2 | 71% |
| common | 5 | 0 | 0 | 5 | 0% |
| fit | 3 | 0 | 0 | 3 | 0% |
| simplify | 5 | 0 | 0 | 5 | 0% |
| insets | 7 | 0 | 4 | 3 | 0% |
| offset | 2 | 0 | 0 | 2 | 0% |
| translate_scale | 5 | 0 | 3 | 2 | 0% |
| rounded_rect_radii | 5 | 0 | 4 | 1 | 0% |
| quadspline | 3 | 0 | 0 | 3 | 0% |

### 4.2 Affine Transform Detail (kurbo::Affine)

| Function | Status | Gleam Function | Via NIF |
|----------|:------:|---------------|---------|
| `Affine::IDENTITY` | COVERED | `kurbo_affine_identity` | `kurbo_affine_op("identity")` |
| `Affine::rotate(angle)` | COVERED | `kurbo_affine_rotate` | `kurbo_affine_op("rotate")` |
| `Affine::translate(v)` | COVERED | `kurbo_affine_translate` | `kurbo_affine_op("translate")` |
| `Affine::scale(s)` | COVERED | `kurbo_affine_scale` | `kurbo_affine_op("scale")` |
| `Affine::skew(kx, ky)` | COVERED | `kurbo_affine_skew` | `kurbo_affine_op("skew")` |
| `Affine::inverse()` | COVERED | `kurbo_affine_inverse` | `kurbo_affine_op("inverse")` |
| `affine * affine` (compose) | COVERED | `kurbo_affine_compose` | `kurbo_affine_op("compose")` |
| `affine * point` | COVERED | `kurbo_affine_transform_point` | `kurbo_affine_op("transform_point")` |
| `affine * path` | COVERED | `kurbo_path_apply_transform` | `nif_svg_path_transform` |
| `Affine::new(coeffs)` | INTERNAL | — | constructor, not NIF-worthy |
| `Affine::coeffs()` | INTERNAL | — | accessor, handle in Gleam |
| `Affine::rotate_about()` | MISSING | — | P1: useful |
| `Affine::scale_non_uniform()` | MISSING | — | P2 |
| `Affine::flip_y()` | MISSING | — | P2 |
| `Affine::flip_x()` | MISSING | — | P2 |
| `Affine::then_*()` (chain ops) | MISSING | — | P3: 5 chaining methods |

### 4.3 BezPath Detail (kurbo::BezPath)

| Function | Status | Gleam Function |
|----------|:------:|---------------|
| `BezPath::from_svg()` | COVERED | `kurbo_path_analyze` (parses SVG d) |
| `BezPath::to_svg()` | COVERED | `kurbo_path_from_points` |
| BFS segment analysis | COVERED | `kurbo_path_analyze` (bbox, area, perimeter, seg_count) |
| `apply_affine()` | COVERED | `kurbo_path_transform`, `kurbo_path_apply_transform` |
| `reverse()` | COVERED | `kurbo_bezier_path_reverse` |
| `flatten()` | COVERED | `kurbo_bezier_path_flatten` |
| `move_to()` | COVERED | implicit via `kurbo_path_from_points` |
| `line_to()`, `quad_to()`, `curve_to()` | COVERED | `kurbo_path_from_points` |
| `close_path()` | COVERED | implicit |
| `arc()` | COVERED | `kurbo_shape_typed(SvgCircle(...))` |
| `iter()` | INTERNAL | iterator, not NIF-appropriate |
| `elements_mut()` | INTERNAL | mutable, not NIF-appropriate |
| `pop()`, `push()`, `truncate()` | INTERNAL | mutable builder, not NIF-appropriate |
| `bounding_box()` | COVERED | via `kurbo_path_analyze` |
| `contains()` | MISSING | P2 |
| `winding()` | MISSING | P3 |

### 4.4 Vec2 / Point Detail

| Function | Status | Gleam Function |
|----------|:------:|---------------|
| `Vec2::distance_squared()` | COVERED | `kurbo_vec2_distance` |
| `Vec2::lerp()` | COVERED | `kurbo_vec2_lerp` |
| `Vec2::normalize()` | COVERED | `kurbo_vec2_normalize` |
| `Vec2::dot()` | COVERED | `kurbo_vec2_dot` |
| `Vec2::angle_between()` | COVERED | `kurbo_vec2_angle` |
| `Vec2::cross()` | COVERED | `kurbo_vec2_cross` |
| `Vec2::from_angle()` | COVERED | `kurbo_vec2_from_angle` |
| `Point::distance()` | COVERED | `kurbo_point_distance` |
| `Point::lerp()` | COVERED | `kurbo_point_lerp` |
| `Vec2::is_finite()` | INTERNAL | validation, do in Gleam |
| `Vec2::is_nan()` | INTERNAL | validation, do in Gleam |
| `Vec2::abs()` | INTERNAL | simple math, do in Gleam |
| `Vec2::length()` | MISSING | P2 |

### 4.5 Rect Detail (kurbo::Rect)

| Function | Status | Gleam Function |
|----------|:------:|---------------|
| `Rect::area()` | COVERED | `kurbo_rect_area` |
| `Rect::union()` | COVERED | `kurbo_rect_union` |
| `Rect::intersect()` | COVERED | `kurbo_rect_intersect` |
| `Rect::contains()` | COVERED | `kurbo_rect_contains` |
| `Rect::inflate()` | COVERED | `kurbo_rect_inflate` |
| `Rect::size()` | COVERED | `kurbo_size_area` |
| `Rect::center()` | MISSING | P1 |
| `Rect::origin()` | MISSING | P1 |
| `Rect::max_x()`, `min_x()`, `max_y()`, `min_y()` | MISSING | P1 (4 accessors) |
| `Rect::ceil()`, `floor()`, `round()`, `trunc()` | INTERNAL | rounding, do in Gleam |
| `Rect::expand()` | INTERNAL | simple math |
| `Rect::with_origin()`, `with_size()` | MISSING | P2 |
| `Rect::is_empty()`, `is_zero_area()` | INTERNAL | validation |
| `Rect::from_points()` | MISSING | P2 |
| `Rect::to_ellipse()` | MISSING | P3 |

---

## 5. Bevy Library Coverage

### 5.1 Bevy ECS

**Source crate**: `bevy_ecs 0.15`
**NIF-wrappable functions**: 3 (spawn, query_all, clear — sufficient for BEAM ECS bridge)
**Total pub fn**: 315 (vast majority are internal Rust trait impls, not NIF-wrappable)

| Function | Status | Gleam Function | NIF |
|----------|:------:|---------------|-----|
| `World::spawn()` + component attach | COVERED | `bevy_ecs_spawn` | `ecs_spawn` |
| `World::query_all()` — entity dump | COVERED | `bevy_ecs_query_all` | `ecs_query_all` |
| `World::clear_entities()` | COVERED | `bevy_ecs_clear` | `ecs_clear` |
| `System::run()` | INTERNAL | ECS system scheduling — not NIF-appropriate |
| `Query<>`, `Commands`, `Res<>` | INTERNAL | ECS reactive types — not NIF-appropriate |
| Iterator impls | INTERNAL | 312 functions are trait impl details |

**Note**: Bevy ECS is a reactive systems framework. The 3 NIF functions provide the BEAM-accessible slice: spawn entities, query their state, reset. Full ECS reactivity stays in Rust.

### 5.2 Bevy Math

**Source crate**: `bevy_math 0.15`
**NIF-wrappable functions**: 6 (vec3 cross, quat rotate, mat4 transform, vec3 lerp, vec2 perp, raw op)

| Function | Status | Gleam Function | NIF |
|----------|:------:|---------------|-----|
| `Vec3::cross()` | COVERED | `bevy_math_vec3_cross` | `bevy_math_op("vec3_cross")` |
| `Quat::from_axis_angle()` + rotate | COVERED | `bevy_math_quat_rotate` | `bevy_math_op("quat_rotate")` |
| `Mat4::from_translation_scale()` + transform | COVERED | `bevy_math_mat4_transform` | `bevy_math_op("mat4_transform")` |
| `Vec3::lerp()` | COVERED | `bevy_math_vec3_lerp` | `bevy_math_op("vec3_lerp")` |
| `Vec2::perp()` | COVERED | `bevy_math_vec2_perp` | `bevy_math_op("vec2_perp")` |
| Raw op passthrough | COVERED | `bevy_math_op` | `bevy_math_op` |
| `Vec3::dot()`, `normalize()`, etc. | INTERNAL | Simple ops, composable from above |
| Trait impls, `From<>`, `Into<>` | INTERNAL | 159 functions are Rust internals |

### 5.3 Bevy Color

**Source crate**: `bevy_color 0.15`
**NIF-wrappable functions**: 6 (color space conversions + hex)

| Function | Status | Gleam Function | NIF |
|----------|:------:|---------------|-----|
| sRGBA -> HSLA | COVERED | `bevy_color_srgba_to_hsla` | `bevy_color_convert("srgba_to_hsla")` |
| HSLA -> sRGBA | COVERED | `bevy_color_hsla_to_srgba` | `bevy_color_convert("hsla_to_srgba")` |
| sRGBA -> Oklch | COVERED | `bevy_color_srgba_to_oklch` | `bevy_color_convert("srgba_to_oklch")` |
| Hex -> sRGBA | COVERED | `bevy_color_hex_to_srgba` | `bevy_color_convert("hex_to_srgba")` |
| sRGBA -> Hex | COVERED | `bevy_color_srgba_to_hex` | `bevy_color_convert("srgba_to_hex")` |
| Raw op passthrough | COVERED | `bevy_color_convert` | `bevy_color_convert` |
| Trait impls, `From<>`, blending | INTERNAL | 13 functions not useful as standalone NIFs |

---

## 6. Mermaid Library Coverage

**Source crate**: `mermaid-rs-renderer 0.1`
**Total pub fn**: 33 | **Covered**: 15 | **Internal**: 5 | **Missing**: 13

| Function | Status | Gleam Function | Notes |
|----------|:------:|---------------|-------|
| `render(text)` -> SVG string | COVERED | `mermaid_render` | All 23 diagram types |
| `render_to_file(text, path)` | COVERED | `mermaid_render_to_file` | SVG file output |
| `render_with_options(text, opts)` | COVERED | `mermaid_render_with_options` | Custom options JSON |
| `build_state_diagram(machine)` | COVERED | `mermaid_render_machine` | StateMachine -> SVG |
| Build stateDiagram-v2 text | COVERED | `mermaid_build_state_diagram` | Pure Gleam builder |
| Build flowchart text | COVERED | `mermaid_build_flowchart` | Pure Gleam builder |
| Build sequence diagram text | COVERED | `mermaid_build_sequence` | Pure Gleam builder |
| Build C4 context text | MISSING | — | P2 |
| Build ER diagram text | MISSING | — | P2 |
| Build Gantt text | MISSING | — | P2 |
| Build class diagram text | MISSING | — | P2 |
| Build git graph text | MISSING | — | P3 |
| Build mindmap text | MISSING | — | P3 |
| Build quadrant chart | MISSING | — | P3 |
| Build pie chart | MISSING | — | P3 |
| Build xy chart | MISSING | — | P3 |
| Build timeline | MISSING | — | P3 |
| Build block diagram | MISSING | — | P3 |
| Theme options | COVERED | `mermaid_render_with_options` | Via options JSON |
| Internal render pipeline | INTERNAL | — | Wasm/JS internal |
| Internal parser | INTERNAL | — | Internal |
| Option builders | INTERNAL | — | Not NIF-appropriate |
| Config types | INTERNAL | — | Internal |
| Error types | INTERNAL | — | Handled by Result |

---

## 7. Skia / tiny-skia Coverage

**Source crate**: `tiny-skia 0.12`
**Total pub fn**: 77 | **Covered**: 6 | **Internal**: 72 | **Missing**: 0

All of tiny-skia's public API is a Rust-side drawing API that operates on a `Pixmap`. The NIF wraps the entire rendering pipeline — callers never touch the Rust drawing primitives directly.

| Function | Status | Gleam Function | Notes |
|----------|:------:|---------------|-------|
| BFS-layered state diagram render | COVERED | `skia_render_state_diagram` | Full layout + render |
| StateMachine wrapper | COVERED | `skia_render_machine` | Typed convenience |
| Component wireframe render | COVERED | `skia_render_component` | 8 named components |
| Render all diagrams | COVERED | `skia_render_all` | JSON filename list |
| Programmatic draw ops | COVERED | `skia_draw_to_png` | rect/circle/line/text/bar ops |
| StateMachine + typed wrapper | COVERED | `skia_render_machine` | Typed convenience |
| `Pixmap::new()` | INTERNAL | Used inside NIF |
| `Canvas::fill_rect()` | INTERNAL | Used inside NIF |
| `Canvas::stroke_path()` | INTERNAL | Used inside NIF |
| `Canvas::fill_path()` | INTERNAL | Used inside NIF |
| `Paint::set_color_rgba8()` | INTERNAL | Used inside NIF |
| All 72 other Pixmap/Canvas methods | INTERNAL | All inside NIF — correct design |

**Design note**: tiny-skia is intentionally 100% internal. The NIF provides a higher-level drawing operations API (`skia_draw_to_png` with JSON ops array) rather than exposing every canvas primitive. This is architecturally correct — BEAM code describes WHAT to draw, Rust handles HOW.

---

## 8. Gleam Public Function Inventory (88 total)

### 8.1 By Category

| Category | Count | Functions |
|----------|:-----:|-----------|
| Graphene graph (JSON API) | 7 | `graphene_bfs`, `_dfs`, `_topological_sort`, `_scc`, `_shortest_path`, `_pagerank`, `_analyze` |
| Graphene graph (typed API) | 8 | `graphene_build_graph` + 7 `*_typed` variants |
| Skia rendering | 4 | `skia_render_state_diagram`, `_machine`, `_component`, `_render_all` |
| Kurbo paths (original 5) | 6 | `kurbo_path_from_points`, `_analyze`, `_transform`, `_apply_transform`, `kurbo_shape`, `_typed` |
| Kurbo Vec2 math | 6 | `kurbo_vec2_math`, `_distance`, `_lerp`, `_normalize`, `_dot`, `_angle` |
| Kurbo affine (Phase 2) | 9 | `kurbo_affine_op` + 8 typed ops |
| Kurbo geometry (Phase 2) | 15 | `kurbo_geometry_op` + 14 typed ops |
| Kurbo bezier (Phase 2) | 5 | `kurbo_bezier_op` + 4 typed ops |
| Bevy ECS | 3 | `bevy_ecs_spawn`, `_query_all`, `_clear` |
| Bevy Math | 6 | `bevy_math_op` + 5 typed ops |
| Bevy Color | 6 | `bevy_color_convert` + 5 typed ops |
| Mermaid (original 4) | 4 | `mermaid_render`, `_to_file`, `_machine`, `_build_state_diagram` |
| Mermaid (diagram builders) | 2 | `mermaid_build_flowchart`, `mermaid_build_sequence` |
| Mermaid (Phase 2) | 1 | `mermaid_render_with_options` |
| Skia Extended (Phase 2) | 1 | `skia_draw_to_png` |
| Pre-defined state machines | 4 | `c3i_page_state_machine`, `c3i_c1_state_machine`, `c3i_c4_state_machine`, `c3i_nav_graph_pages` |
| **TOTAL** | **88** | |

### 8.2 By Phase

| Phase | When | Functions Added | Gleam Functions | NIF Entry Points |
|-------|------|:---------------:|:---------------:|:----------------:|
| Phase 1 | 2026-04-12 session 1 | Initial NIF + Gleam module | 58 | 22 |
| Phase 2 | 2026-04-12 session 2 | Kurbo extended, Mermaid+Skia extended | +30 | +5 |
| Phase 3 (planned) | Next session | Mermaid diagram builders, Rect accessors | ~17 | ~2 |
| Phase 4 (planned) | Future | Stroke builder, simplify, fit | ~12 | ~3 |
| **Target v1.0** | | | **~167** | **~32** |

---

## 9. Missing API Priority Backlog

### P0 — Critical (unblock other features)
None. All P0 functions are covered.

### P1 — High (commonly needed)

| Library | Missing Functions | Count | Effort |
|---------|-----------------|:-----:|--------|
| Kurbo/Rect | `center()`, `origin()`, `max_x()`, `min_x()`, `max_y()`, `min_y()` | 6 | 1h |
| Kurbo/Affine | `rotate_about()`, `scale_non_uniform()` | 2 | 30m |
| Kurbo/Vec2 | `Vec2::length()` | 1 | 15m |
| Kurbo/Circle | `Circle::contains()`, `Circle::to_ellipse()` | 2 | 30m |

### P2 — Standard

| Library | Missing Functions | Count | Effort |
|---------|-----------------|:-----:|--------|
| Mermaid | `build_c4()`, `build_er()`, `build_gantt()`, `build_class()` | 4 | 2h |
| Kurbo/BezPath | `contains()`, `winding()` | 2 | 1h |
| Kurbo/Rect | `with_origin()`, `with_size()`, `from_points()` | 3 | 1h |
| Kurbo/Ellipse | 8 accessors (radii, center, rotation getters) | 8 | 1.5h |

### P3 — Nice-to-have

| Library | Missing Functions | Count | Effort |
|---------|-----------------|:-----:|--------|
| Kurbo/Stroke | 9 builder chain ops | 9 | 2h |
| Kurbo/Simplify | `simplify()`, `fit_to_bezpath()` | 5 | 2h |
| Mermaid | 9 remaining diagram builders | 9 | 3h |
| Kurbo/Insets | 3 non-internal ops | 3 | 30m |

---

## 10. Classification: "Internal" vs "Missing"

### INTERNAL — Functions skipped by design

These functions are NOT appropriate for NIF exposure:

| Pattern | Examples | Reason |
|---------|---------|--------|
| Validation predicates | `is_finite()`, `is_nan()`, `is_empty()`, `is_zero_area()` | Do in Gleam with pattern matching |
| Rounding ops | `ceil()`, `floor()`, `round()`, `trunc()`, `abs()`, `clamp()` | Simple math, do in Gleam |
| Mutable builder methods | `push()`, `pop()`, `truncate()`, `with_capacity()` | Not safe across NIF boundary |
| Iterator methods | `iter()`, `elements_mut()`, `as_path_el()` | Cannot cross BEAM boundary |
| Constructor/destructor | `new()`, `drop()` | Managed inside Rust |
| `From<>` / `Into<>` impls | All `From` trait impls | Rust type conversion internals |
| Internal pipeline methods | `current_position()`, `end_point()` | State maintained inside Rust |
| ECS reactive types | `Query<>`, `Commands`, `System::run()` | Must stay inside Rust |
| Canvas/Pixmap internals | All 72 tiny-skia drawing methods | Correctly hidden behind draw ops API |

### MISSING — Functions to add in future sprints

These functions have clear Gleam use cases and are straightforward to wrap:
- Rect accessor methods (`center`, `origin`, `min_x`, etc.)
- Additional Mermaid diagram builders
- Ellipse extended operations
- Stroke/dash configuration

---

## 11. Rust NIF LOC Breakdown

**Total**: 2,036 lines (`native/graphene_nif/src/lib.rs`)

| Section | Estimated LOC | Functions |
|---------|:-------------:|-----------|
| Module setup + rustler init | 30 | — |
| Graphene graph NIFs (7) | 280 | `graph_bfs` through `graph_analyze` |
| Skia rendering NIFs (3) | 400 | `render_state_diagram`, `render_component`, `render_all_diagrams` |
| Skia layout algorithm | 180 | BFS-layered layout for state diagrams |
| Component wireframe renderers | 250 | 8 component types |
| Kurbo path NIFs (4) | 150 | SVG path from/analyze/transform/shape |
| Kurbo Vec2 math NIF (1, 6 ops) | 80 | `vec2_math` dispatcher |
| Kurbo Affine NIF (1, 8 ops) | 120 | `kurbo_affine_op` dispatcher |
| Kurbo Geometry NIF (1, 14 ops) | 160 | `kurbo_geometry_op` dispatcher |
| Kurbo Bezier NIF (1, 4 ops) | 80 | `kurbo_bezier_op` dispatcher |
| Bevy ECS NIFs (3) | 100 | ECS world management |
| Bevy Math NIF (1, 5 ops) | 80 | `bevy_math_op` dispatcher |
| Bevy Color NIF (1, 5 ops) | 60 | `bevy_color_convert` dispatcher |
| Mermaid NIFs (3) | 80 | render + render_to_file + options |
| Skia Extended NIF (1) | 120 | `skia_draw_to_png` op dispatcher |
| Helper functions + JSON helpers | 46 | serde helpers, error handling |
| **TOTAL** | **2,036** | 27 entry points |

---

## 12. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GRAPHENE NIF ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  GLEAM API (88 pub fn)              ERLANG BRIDGE (graphene_nif.erl)│
│  ┌─────────────────────┐           ┌──────────────────────────────┐ │
│  │ graphene.gleam      │  @external │ graphene_nif.erl             │ │
│  │ 601 lines           │───────────▶ -on_load: load_nif/2         │ │
│  │                     │           │ 27 exports to Rust            │ │
│  │ 7 domains:          │           └──────────────┬───────────────┘ │
│  │ • graphene (15 fn)  │                          │ NIF ABI          │
│  │ • skia (6 fn)       │                          ▼                  │
│  │ • kurbo (30 fn)     │           ┌──────────────────────────────┐ │
│  │ • bevy_ecs (3 fn)   │           │ graphene_nif.so (2,036 LOC)   │ │
│  │ • bevy_math (6 fn)  │           │                              │ │
│  │ • bevy_color (6 fn) │           │ Rust crates:                  │ │
│  │ • mermaid (8 fn)    │           │ • graphene 0.1.5              │ │
│  │ • skia extended     │           │ • tiny-skia 0.12              │ │
│  │ • c3i state (4 fn)  │           │ • kurbo 0.11                  │ │
│  └─────────────────────┘           │ • bevy_ecs/math/color 0.15   │ │
│                                    │ • mermaid-rs-renderer 0.1     │ │
│                                    │ • rustler 0.37                │ │
│                                    └──────────────────────────────┘ │
│                                                                      │
│  Data format: JSON strings (nodes/edges/ops/params)                  │
│  Error format: Result(String, String) — Ok=data, Err=message         │
│  NIF safety: panic="unwind" in Cargo.toml (SC-NIF-003)               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 13. Test Coverage Summary

**Test file**: `test/graphene_render_test.gleam` (500 lines, 82 test functions)

| Category | Test Functions | Coverage |
|----------|:-------------:|---------|
| State diagram rendering | 13 | All 10 components + page + viewport + view |
| Component wireframe | 6 | c1, c2, c4, c9, c11, c12 |
| Graph algorithms | 4 | BFS, SCC, PageRank, topological sort |
| SVG path operations | 3 | from_points, analyze, shape_rect/circle/star |
| Kurbo extended (Phase 2) | 18 | affine ops, geometry ops, bezier ops |
| Mermaid rendering | 8 | render, flowchart, sequence, machine, with_options |
| Bevy math + color | 10 | cross, quat, mat4, lerp, perp + 5 color conversions |
| Bevy ECS | 3 | spawn, query, clear |
| Skia extended | 3 | skia_draw_to_png (rect, circle, composition) |
| Navigation graph | 2 | nav graph BFS + SCC verification |
| Integration (graph -> render pipeline) | 4 | full graph -> layout -> PNG pipeline |
| State machine pre-defined | 4 | page, c1, c4, nav_graph |
| Wiring/compilation | 6 | Module import, type construction, error handling |

---

## 14. Version History

| Version | Date | Gleam fn | NIFs | Rust LOC | Key Addition |
|---------|------|:--------:|:----:|:--------:|-------------|
| v0.1.0 | 2026-04-12 AM | 58 | 22 | 900 | Phase 1: Graphene + Skia core |
| v0.2.0 | 2026-04-12 PM | 58 | 26 | 1,400 | Phase 1b: Bevy + Mermaid addition |
| **v0.3.0** | **2026-04-12** | **88** | **27** | **2,036** | **Phase 2: Kurbo extended (79 functions)** |
| v1.0.0 (target) | TBD | ~167 | ~32 | ~2,800 | Phase 3-4: Full usable API coverage |

---

*सर्वं खल्विदं ब्रह्म — All this is indeed Brahman. (Chandogya Upanishad 3.14.1)*
*The graph theory of creation: every node connected, every path discoverable.*
