# Design: OpenClaw Advanced GUI Integration (Penta-Stack)

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: GUI INTEGRATION / SIL-6

## 1. Overview
The advanced capabilities extracted from OpenClaw (Context Engine, Routing, Memory, Sessions, Updater) must be visually accessible and controllable via the **Indrajaal Penta-Stack UI** (Lustre Web, Wisp REST, Ratatui TUI).

## 2. Fractal GUI Component Mapping

| OpenClaw Concept | UI Component Name | Layer | Description |
| :--- | :--- | :--- | :--- |
| **Sessions** | `SessionVisualizer` | L5 | A real-time graph showing active LLM sessions, their isolated context size, and token usage. |
| **Routing** | `SwarmRoutingMatrix` | L6 | A dynamic Sankey diagram displaying intents flowing between sub-agents (e.g., Cortex -> Workspace -> Briefing). |
| **Memory** | `EpisodicMemoryExplorer` | L3 | A search interface to query the `Smriti.db` vector embeddings and visualize semantic relationships. |
| **Updater** | `ApoptosisDashboard` | L4 | Visualizes the A/B partition state, cryptographic signature verification, and atomic swap readiness. |
| **Wizard** | `OnboardingTerminal` | L7 | A conversational TUI/Web hybrid component for interactive user setup (pairing devices, setting secrets). |

## 3. Gleam Lustre Implementation (Web UI)

### 3.1 Session Visualizer (A2UI Component)
We will define a new A2UI component in `cepaf_gleam/a2ui/catalog.gleam`:
*   **Type**: `A2UISessionGraph`
*   **Data Source**: Zenoh subscription to `indrajaal/l5/cog/session/status`.
*   **Render**: Uses SVGs or Canvas (via Lustre) to render the isolated memory boundaries.

### 3.2 Routing Matrix
*   **Type**: `A2UIRoutingFlow`
*   **Data Source**: OTel spans published to `indrajaal/otel/span/**`. The UI subscribes to these spans and reconstructs the directed acyclic graph (DAG) of the agentic transaction.

## 4. TUI Implementation (Ratatui Bridge)
The TUI (`cepaf_gleam/ui/tui/split_screen.gleam`) will be enhanced with two new panes:
1.  **Memory Pane**: Tail the `EventLog` in real-time, highlighting semantic similarity scores when a memory retrieval intent is fired.
2.  **Swarm Pane**: A matrix view of all active agents (Cortex, Briefing, Workspace, SkillLoader) and their current `SessionID`.

## 5. Wisp REST Endpoints
*   `GET /api/v1/sessions` - Returns active session boundaries.
*   `POST /api/v1/memory/search` - Triggers a vector search via the Rust daemon.
*   `POST /api/v1/system/update` - Initiates the cryptographically verified A/B update sequence.
