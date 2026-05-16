# Fractal Widgets L0-L7 Catalog — CPIG Phase C G4+G5 closure

> CPIG subsystem: Fractal widgets L0-L7 · Pass-15 G4+G5 closure
> Source modules: `lib/cepaf_gleam/src/cepaf_gleam/fractal/l{0..7}_*.gleam`
> Total: 8 modules, 1,107 LOC (per CLAUDE.md §7)

## STAMP references
- SC-FRACTAL-001..008
- SC-CPIG-014 (Fractal widgets G4 + G5 closure)
- SC-WIRE-001 (wiring guard parity)
- SC-GLM-UI-001 (triple-interface mandate)

## L0-L7 Widget Surface

| Layer | Module | LOC | Purpose | HITL | Primary STAMP |
|:---:|---|---:|---|:---:|---|
| **L0 Constitutional** | `l0_constitutional.gleam` | 176 | Guardian approval, emergency stop, Psi invariants (Ψ-0..5, Ω-0) | **Mandatory** | SC-PRIME-001, SC-SAFETY-022 |
| **L1 Atomic/Debug** | `l1_atomic_debug.gleam` | 118 | Debug trace viewer, event monitor, state inspections | Optional | SC-NIF-LOAD-006, SC-LOG-001 |
| **L2 Component** | `l2_component.gleam` | 112 | Reusable forms, data grids, badges, buttons, inputs | No | SC-AGUI-001, SC-A2UI-001 |
| **L3 Transaction** | `l3_transaction.gleam` | 144 | State diff viewer, tool invocation panel, command history | Optional | SC-XHOLON-001, SC-VALUE-GUARD-001 |
| **L4 System** | `l4_system.gleam` | 202 | Agent run monitor, step tracker, execution timeline | Optional | SC-DISP-REGISTRY-001, SC-SIL4-005 |
| **L5 Cognitive** | `l5_cognitive.gleam` | 149 | Reasoning display, OODA ring, AI copilot panel | Optional | SC-COG-001, SC-OODA-001 |
| **L6 Ecosystem** | `l6_ecosystem.gleam` | 105 | Agent mesh topology, A2A messaging, collaboration | Optional | SC-ZMOF-001, SC-GLM-ZEN-001 |
| **L7 Federation** | `l7_federation.gleam` | 101 | Gateway, version vectors, federated reconciliation, SIL-6 sync | Optional | SC-FED-001..006, SC-CPIG-FED-001 |
| **Total** | 8 modules | **1,107** | All 8 fractal layers covered | 1 mandatory | 16+ STAMP families |

## Cross-cutting invariants

| Invariant | Layer scope | Verifier |
|---|---|---|
| Every widget exposes init/0 | L0-L7 | `wiring_guard.gleam` |
| L0 widget requires Guardian token | L0 only | `guardian_gate.gleam` (HITL) |
| State changes publish OTel span | L1-L7 | `zenoh_otel.gleam` (SC-GLM-ZEN-001) |
| Action buttons require 2oo3 consensus | L0-L4 | `safety_kernel.gleam` (SC-SIL4-006) |
| Triple-interface parity (Lustre/Wisp/TUI) | L0-L7 | SC-GLM-UI-001 |

## HITL (Human-in-the-loop) policy

L0 Constitutional is the only **mandatory HITL** layer. All emergency-stop / Guardian-approval flows pass through `l0_constitutional.gleam`. Other layers are optional HITL (operator override only).

## Test coverage

| Module | Test file | Tests |
|---|---|---:|
| l0 | `test/fractal_l0_test.gleam` | C1-C8 gold standard |
| l1 | `test/fractal_l1_test.gleam` | C1-C7 |
| l2 | `test/fractal_l2_test.gleam` | C1-C6 |
| l3 | `test/fractal_l3_test.gleam` | C1-C7 |
| l4 | `test/fractal_l4_test.gleam` | C1-C8 |
| l5 | `test/fractal_l5_test.gleam` | C1-C8 |
| l6 | `test/fractal_l6_test.gleam` | C1-C7 |
| l7 | `test/fractal_l7_test.gleam` | C1-C8 |
| wiring | `test/fractal_widgets_wiring_test.gleam` (Pass-13) | exhaustiveness |

All 8 layers satisfy SC-MATH-COV-001 (H ≥ 2.5 bits Shannon entropy on test categories) per existing CLAUDE.md §8.2 metrics.

## Formal spec

- `specs/tla/FractalWidgets.tla` (Pass-13) — layer-widget parity invariant
- `specs/allium/fractal_widgets.allium` (proposed, not yet authored — Pass-16 scope)

## Cross-references

- CLAUDE.md §7 (Fractal Widget Architecture)
- `.claude/rules/biomorphic-evolution-protocol.md` — 7 biomorphic properties × 8 layers tensor
- `.claude/rules/agentic-ui-responsive-design.md` (SC-AGUI-UI family) — UI/L-layer mapping
- `lib/cepaf_gleam/src/cepaf_gleam/fractal/*.gleam` — source modules

## CPIG closure status

- G1 Formal Spec: ✓ `specs/tla/FractalWidgets.tla`
- G2 Wiring Guard: ✓ `lib/cepaf_gleam/test/fractal_widgets_wiring_test.gleam`
- G3 sa-plan Tracking: ✓ SC-FRACTAL-001..008
- **G4 ZK Ingestion**: ✓ this catalog (Pass-15, today)
- **G5 Email Closure**: ✓ this pack's email (Pass-15, today)

Score: 3/5 (post-recount) → **5/5** after Pass-15 close.

## Pass-16 follow-on scope

- Author `specs/allium/fractal_widgets.allium` (behavioural spec)
- Add federated CPIG sync (Claude/Gemini/Pi agree on layer scores)
- Cross-layer health rollup widget (meta-L8)
