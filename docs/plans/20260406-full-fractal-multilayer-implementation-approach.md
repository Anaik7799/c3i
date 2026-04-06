# Plan: Full Fractal Multilayer Implementation Approach (A2UI Evolution)

**Created**: 20260406-1200 CEST
**Last Updated**: 20260406-1200 CEST
**Status**: ACTIVE
**Framework**: SOPv5.11 + TPS + STAMP SIL-6

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260406-1200 CEST | CREATED | Comprehensive implementation approach for the fully fractal agentic UI system | Gemini CLI |

## Executive Summary
This document provides the definitive implementation approach for the **Fully Fractal Agentic UI System**. It outlines the sequential steps required to transform `cepaf_gleam`'s WebUI from static operational dashboards into a mathematically optimized, morphologically evolvable cybernetic interface that spans all 8 fractal layers (L0-L7). This plan enforces the Ultrathink Mandate (SC-ULTRA-001) by ensuring continuous operational monitoring, control, and system evolution directly through the HMI.

## 5-Level Implementation Approach

### Phase 1: Foundational Control Injection (L0-L7 Integration)
#### 1.1 Action Primitives & API Binding
- **Goal**: Ensure the Lustre WebUI can natively dispatch mutation events to the backend Wisp router.
- **Implementation**:
  - `[x]` Implement `action_button` in `lustre/shell.gleam` utilizing native Javascript `fetch` interoperability.
  - `[x]` Bind UI buttons to backend Wisp endpoints: `/api/v1/podman/action`, `/api/v1/ooda/trigger`, and `/api/v1/emergency/trigger`.
  - `[x]` Guarantee 100% execution pass-through by correctly mirroring Wisp HTTP headers into the `mist` server response (`server.gleam`).

#### 1.2 Layer-Specific Control Grids
- **Goal**: Expose core CLI capabilities as A2UI buttons within their respective fractal layers.
- **Implementation**:
  - `[x]` **L0 Constitutional**: Add `Emergency Stop`, `Halt Mutations`, `sa-verify`.
  - `[x]` **L1 Atomic**: Add `System Logs`, `Port Substrate`, `Shutdown + Prune`.
  - `[x]` **L2 Component**: Add `Restart Actor`, `Compile`, `Test SIL-6`.
  - `[x]` **L3 Transaction**: Add `DB Migrate`, `DB Reset`, `DB Setup`.
  - `[x]` **L4 System**: Add `Wave Ignition`, `Apoptosis`, `Restart Genome`.
  - `[x]` **L5 Cognitive**: Add `Force OODA Cycle`, `Trigger LLM Advisor`, `Inject Fact`.
  - `[x]` **L6 Ecosystem**: Add `Quorum Check`, `Bio Sync`, `Inject Chaos`.
  - `[x]` **L7 Federation**: Add `Checkpoint`, `Restore`, `Fork Multiverse`.

### Phase 2: Morphological Evolution & Dynamic Rendering
#### 2.1 A2UI Schema Integration
- **Goal**: Transition from hardcoded Lustre elements to JSON-schema-driven UI components.
- **Implementation**:
  - `[x]` Extend `a2ui/catalog.gleam` to accept JSON definitions for operational control panels.
  - `[x]` Implement a recursive Lustre renderer that traverses an A2UI AST and generates `action_button` elements dynamically.
  - `[x]` Hook the A2UI catalog into the Zenoh `SharedMeshState` to trigger re-renders when the schema mathematically evolves.

#### 2.2 Context-Aware Density Scaling (SC-HMI-060)
- **Goal**: Mathematically prevent operator overload (Hick's Law).
- **Implementation**:
  - `[x]` Bind the A2UI renderer to the current OODA phase.
  - `[x]` When `ooda_phase == "decide"`, automatically prune the rendered action buttons to the top 5 most relevant options.
  - `[x]` Apply `badge-critical` (high-contrast) styling *only* to the single action recommended by the SLM/RETE-UL engine.

### Phase 3: Neuroergonomic Hardening
#### 3.1 Visual Cryptography & Provenance (SC-ULTRA-UI-002)
- **Goal**: Guarantee Epistemic Honesty for all telemetry.
- **Implementation**:
  - `[ ]` Extend `shell.status_card` and `shell.container_card` to accept a `MerkleProof` object.
  - `[ ]` Add an `onkeydown` listener for a global chording event (e.g., Alt+Shift).
  - `[ ]` When chorded, overlay the Merkle leaf hash onto the component. If the proof fails, mutate the `class` to mathematically deface the widget (`bg-red-900`, `opacity-50`, `blur-sm`).

#### 3.2 Continuous Sonification & Biometric Sync (SC-HMI-500, SC-HMI-510)
- **Goal**: Offload telemetry from the visual cortex.
- **Implementation**:
  - `[ ]` Integrate Web Audio API within `lustre/app.gleam`'s client-side hydration payload.
  - `[ ]` Map `mesh_state.threat_level` and `mesh_state.healthy_count` to an algorithmic drone oscillator.
  - `[ ]` Accept WebBluetooth/WebHID streams containing operator heart rate. Throttle CSS animation speeds and increase font-weight mathematically if `heart_rate_bpm > 110`.

### Phase 4: Decentralized Emergent Ignition Visualization
#### 4.1 Particle System Representation (SC-ULTRA-UI-007)
- **Goal**: Accurately visualize Gossip Boot convergence without using linear progress bars.
- **Implementation**:
  - `[ ]` Implement a WASM-compiled or WebGL-driven 2D particle canvas in `page_views.gleam` specifically for the `zenoh_view` and `federation_view`.
  - `[ ]` Map Zenoh peer discovery packets to particle gravity/attraction. As nodes discover each other, render the particles snapping into a crystalline lattice.

### Phase 5: Verification & Safety Gating
#### 5.1 TLA+ Action Gating (SC-ULTRA-UI-004)
- **Goal**: Physically prevent mathematically unsafe actions.
- **Implementation**:
  - `[ ]` Wrap all `action_button` primitives in an `ApalacheGuard` element.
  - `[ ]` Before enabling the button's `onclick` handler, query the backend `/api/v1/graph/verify` endpoint.
  - `[ ]` If the action leads to a STAMP violation, disable the button and project the counter-example into a `ReasoningMarquee` at the top of the UI.

## Success Criteria
- [x] Phase 1 is fully implemented; `cepaf_gleam` WebUI actively dispatches L0-L7 operations.
- [x] Phase 2 Morphological Evolution is complete; UI renders dynamically from A2UI JSON schemas.
- [ ] Phase 3 Neuroergonomic constraints are active; operators can cryptographically verify UI elements.
- [ ] System handles continuous OODA cycling and Apoptosis without throwing 500 errors or failing to re-render.