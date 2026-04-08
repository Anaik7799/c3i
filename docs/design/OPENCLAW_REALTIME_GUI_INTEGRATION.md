# Design: Agentic UI & Continuous Perception (Penta-Stack)

**Version**: 2.0.0
**Date**: 2026-04-08
**Classification**: GUI INTEGRATION / SIL-6

## 1. Overview
This document specifies how the OpenClaw Canvas Host, ACP boundaries, and Real-time Voice streams are integrated into the **Indrajaal Penta-Stack UI**. We transition from a chat-based interface to a **Spatial Agentic Hologram**.

## 2. Fractal GUI Component Mapping

| OpenClaw Concept | UI Component Name | Layer | Description |
| :--- | :--- | :--- | :--- |
| **Canvas Host** | `A2UI_HolographicCanvas` | L6 | A dynamic, grid-based workspace where the agent spawns interactive widgets (tables, graphs) instead of text responses. |
| **Realtime Voice** | `AcousticWavefrontVisualizer` | L1 | A WebGL/TUI audio waveform analyzer showing streaming transcription confidence and latency. |
| **ACP Boundary** | `GuardianPolicyInspector` | L0 | A security panel showing the live cryptographically enforced bounds around the current agent session. |

## 3. Gleam Lustre Implementation (Web UI)

### 3.1 Holographic Canvas (A2UI Component)
*   **Module**: `cepaf_gleam/a2ui/hologram.gleam`
*   **Data Source**: Subscribes to `indrajaal/l6/canvas/state`.
*   **Interaction**: When the user drags a widget or edits a field on the canvas, Lustre emits a Zenoh `CanvasUpdate` intent. The CRDT engine resolves it and broadcasts the updated state back to the agent.

### 3.2 Real-Time Acoustic Bridge
*   **Module**: `cepaf_gleam/ui/web/voice_bridge.gleam`
*   **Function**: Utilizes browser `getUserMedia` to capture audio. Audio is chunked (e.g., 20ms frames), base64 encoded, and streamed over a WebSocket to the Wisp REST server, which bridges it to the Zenoh `indrajaal/l1/stream/audio` topic.

## 4. TUI Implementation (Ratatui Bridge)
The TUI (`cepaf_gleam/ui/tui/split_screen.gleam`) will be enhanced:
1.  **Canvas Pane**: Instead of a chat log, the TUI renders the A2UI components using ANSI art. A table on the Web UI renders as a Ratatui `Table` widget, perfectly synchronized via the CRDT.
2.  **ACP Pane**: A constant read-out of the current Agent's allowed tools and blocked directories (e.g., `[BLOCKED: /etc, /root] [ALLOWED: /home/an/dev]`).

## 5. Wisp REST Endpoints
*   `WS /api/v1/stream/voice` - Full-duplex WebSocket for binary audio streaming.
*   `GET /api/v1/canvas` - Retrieves the current Merkle root and state of the collaborative workspace.
