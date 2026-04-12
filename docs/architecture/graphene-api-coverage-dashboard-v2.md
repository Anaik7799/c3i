# Graphene NIF — Complete API Coverage Dashboard v2
**Date**: 2026-04-12 | **NIF**: v0.2.0

## Executive Summary
| Metric | Value |
|--------|-------|
| Total crate pub fn | 2,205 |
| NIF-Wrappable | 273 (12.4%) |
| NIF Covered | 234 (85.7% of wrappable) |
| Gleam pub fn | 104 |
| NIF entry points | 30 |
| NIF dispatch ops | 152 |

## Coverage by Library
| Library | Crate fn | Wrappable | NIF | Gleam | NIF% | Gleam% |
|---------|:--------:|:---------:|:---:|:-----:|:----:|:------:|
| graphene | 11 | 11 | 11 | 15 | 100% | 136% |
| kurbo | 272 | 188 | 152 | 42 | 81% | 22% |
| tiny-skia | 324 | 15 | 15 | 5 | 100% | 33% |
| bevy_ecs | 1,096 | 5 | 5 | 3 | 100% | 60% |
| bevy_math | 446 | 8 | 8 | 6 | 100% | 75% |
| bevy_color | 19 | 8 | 8 | 6 | 100% | 75% |
| mermaid | 35 | 18 | 15 | 7 | 83% | 39% |
| vega_lite | 2 | 20 | 20 | 16 | 100% | 80% |
| **TOTAL** | **2,205** | **273** | **234** | **104** | **86%** | **38%** |

## Why 2,205 total but 273 wrappable?
- bevy_ecs (1,096): 99% OOP trait impls, scheduler internals
- bevy_math (446): 95% operator overloads, Deref impls
- tiny-skia (324): 95% pixmap mutation (handled by skia_draw_to_png)
- kurbo (272): 31% internal (is_nan, iterators, rounding)

## Agentic UI Use Cases
| Package | Dashboard | Planning | Immune | Zenoh | Cockpit |
|---------|:---------:|:--------:|:------:|:-----:|:-------:|
| graphene | PageRank | Task deps | Threat graph | Mesh topo | — |
| skia | Status PNGs | Wireframes | Alert renders | Topo render | Mode renders |
| kurbo | Ring SVG | Layout | Shield SVG | Node layout | OODA ring |
| bevy_color | Themes | — | — | — | Dark cockpit |
| mermaid | Flows | State diagrams | Defense flow | Mesh diagram | — |
| vega_lite | Sparkline, Pie | Priority, Gantt | Heatmap | Latency | OODA ring |

