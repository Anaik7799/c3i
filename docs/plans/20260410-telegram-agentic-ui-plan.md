# Plan: Telegram Agentic UI App

**Created**: 20260410-0900 CEST
**Last Updated**: 20260410-0900 CEST
**Status**: APPROVED
**Framework**: SOPv5.11 + TPS
**Compliance**: SC-ZENOH-005, SC-ZMOF-001, SC-OPENCLAW-001

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260410-0900 CEST | CREATED | Initial Plan Creation | Gemini CLI |
| 20260410-0905 CEST | APPROVED | User Approved | User |

## Executive Summary
Implement a fully functional Telegram App that mirrors the `cepaf_gleam` Agentic UI capabilities. The app adheres to the Fractal Brain-Stem architecture via a "Gleam-Native Rendering + Rust Motor Execution" strategy. Gleam translates the 32 AG-UI events into rich Telegram UI payloads (Inline Keyboards, Markdown Formatting, EditMessage updates) and publishes them to the Zenoh mesh. Rust (`sa-plan-daemon`) listens to these intents and executes the physical HTTP requests to the Telegram API.

## 5-Level Detailed Plan

### 1.0 - Telegram Agentic UI Integration (Priority: P1)
#### 1.1 - Gleam Telegram UI Renderer (Cognitive Plane) (Priority: P1)
##### 1.1.1 - AG-UI to Telegram Event Mapping (Priority: P1)
###### 1.1.1.1 - State Tracking Actor (`gateway/telegram_app.gleam`)
- 1.1.1.1.1 - Create supervised OTP actor `lib/cepaf_gleam/src/cepaf_gleam/gateway/telegram_app.gleam`.
- 1.1.1.1.2 - Subscribe to the AG-UI event stream via Zenoh (`indrajaal/l5/cog/agui/**`).
- 1.1.1.1.3 - Maintain conversational state (tracking Telegram `message_id` against AG-UI `run_id` for in-place message edits).
###### 1.1.1.2 - Telegram Payload Translation
- 1.1.1.2.1 - Translate `Reasoning*` and `TextMessage*` events into debounced Telegram `sendMessage` or `editMessageText` JSON payloads.
- 1.1.1.2.2 - Translate `ToolCall*` events into dynamic progress messages.
- 1.1.1.2.3 - Translate `StateSnapshot` / A2UI components into Telegram Inline Keyboards for interactive operations.
##### 1.1.2 - Motor Intent Emission (Priority: P1)
###### 1.1.2.1 - Zenoh Dispatch
- 1.1.2.1.1 - Publish the formatted Telegram HTTP JSON payloads to the Rust Motor Strip via `indrajaal/l4/system/mcp/req/gateway/telegram`.

#### 1.2 - Rust Motor Execution (Motor Strip) (Priority: P1)
##### 1.2.1 - Zenoh Subscription (Priority: P1)
###### 1.2.1.1 - Gateway Listener (`sa-plan-daemon`)
- 1.2.1.1.1 - Ensure `gateway.rs` subscribes to `indrajaal/l4/system/mcp/req/gateway/telegram`.
- 1.2.1.1.2 - Extract Telegram Chat ID, Token (from secure storage), and JSON payload.
##### 1.2.2 - HTTP Execution (Priority: P1)
###### 1.2.2.1 - Telegram API Integration
- 1.2.2.1.1 - Execute POST requests to `api.telegram.org` using `reqwest`.
- 1.2.2.1.2 - Handle Telegram 429 Rate Limits and publish retry/failure telemetry back to Zenoh.

#### 1.3 - Sensory Input (Mobile-to-Cognitive) (Priority: P1)
##### 1.3.1 - Telegram Webhook Handling (Priority: P1)
###### 1.3.1.1 - Ingress Polling / Webhook
- 1.3.1.1.1 - Rust receives incoming Telegram messages or Inline Keyboard Callback Queries.
- 1.3.1.1.2 - Rust formats the input into a standard intent and publishes to `indrajaal/l5/cog/intent/req`.
###### 1.3.1.2 - Gleam Intent Processing
- 1.3.1.2.1 - Gleam Cortex processes the intent, updates state, and restarts the AG-UI emission cycle.

## Success Criteria
- Telegram bot correctly renders Text, Reasoning, and Tool Calls.
- Telegram bot dynamically updates messages (e.g., streaming text or showing tool progress) without spamming chat history (using `editMessageText`).
- User can click Inline Keyboard buttons to trigger actions back into the mesh.
- Zero direct HTTP calls from Gleam; all network I/O is restricted to Rust.

## Risk Assessment (5-Level RCA considerations)
- **Rate Limiting**: Telegram has strict limits on `editMessageText` (approx. 1 per second per message). Gleam MUST debounce AG-UI streaming chunks before emitting Motor Intents to avoid HTTP 429 errors.
- **Message Ordering**: Zenoh is fast, but UDP/TCP transport can jumble packets. Gleam must track Telegram `message_id` to ensure edits apply to the correct message block.