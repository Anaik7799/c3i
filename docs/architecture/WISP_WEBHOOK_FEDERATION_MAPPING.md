# Specification: Wisp REST Webhook Federation (Inbound Gateways)

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: SYSTEM ARCHITECTURE
**Compliance**: SC-MCP-001, SC-COG-001, SC-ZMOF-001

## 1. Introduction
This specification defines the integration of the **Inbound (Sensory) Pathway** for the Indrajaal Personal OS. We are exposing public HTTP endpoints via the Gleam Wisp framework to receive webhooks from Telegram, Google Chat, and WhatsApp.

## 2. Capability Matrix & Fractal Mapping

| Inbound Trigger | Indrajaal Mapping (Wisp Endpoint) | Fractal Layer | SIL-6 Safety Constraint |
| :--- | :--- | :--- | :--- |
| **Telegram Update** | `POST /api/v1/webhooks/telegram` | L7 (Federation) | SC-SEC-041 (Verify Telegram Secret Token in headers) |
| **Google Chat Event**| `POST /api/v1/webhooks/gchat` | L7 (Federation) | SC-SEC-041 (Verify Google Bearer Token) |
| **WhatsApp Message**| `POST /api/v1/webhooks/whatsapp` | L7 (Federation) | SC-SEC-041 (Verify Meta SHA256 Signature) |

## 3. Operational & Usage Layers

### 3.1 Webhook Verification & Routing
1.  **Ingestion**: Wisp receives the raw JSON payload.
2.  **Verification**: Before parsing the body, Wisp MUST cryptographically verify the request originated from the official provider (e.g., matching the `X-Telegram-Bot-Api-Secret-Token` header against `Smriti.db`).
3.  **Translation**: Wisp extracts the user's text and sender ID.
4.  **Zenoh Injection**: Wisp calls `cepaf_gleam/gateway/telegram.process_inbound_message()` to publish the intent to `indrajaal/l5/cog/intent/req`.
5.  **Cortex Activation**: The Rust `sa-plan-daemon` Cortex ingests the intent, triggers the LLM for classification (Test 3), and executes the resulting MCP tool.

## 4. Substrate Independence
The Wisp server runs inside the `intelitor-app` container. It relies solely on Zenoh for internal communication. If Wisp crashes, it does not affect the Rust Planning Daemon or the Mojo Inference Cell.
