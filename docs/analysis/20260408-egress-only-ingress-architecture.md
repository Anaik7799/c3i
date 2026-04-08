# Deep Architectural Analysis: Egress-Only Command Ingress (SIL-6)

**Date**: 2026-04-08
**Classification**: INDEPENDENT ARCHITECTURAL AUDIT & REMEDIATION (SIL-6)
**Subject**: Transitioning from Webhooks (Gleam/Wisp) to Egress-Only Polling (Rust/Tokio) for external communication.

## 1. Executive Summary
Following a strict SIL-6 security evaluation, it was determined that the Webhook-based inbound command architecture (running via Wisp on the Gleam Cognitive Plane) constituted an unacceptable security and operational risk.

By implementing an Egress-Only Polling Architecture within the authoritative Rust `sa-plan-daemon`, the system achieves:
1.  **Absolute Network Invisibility**: Zero inbound ports required. The system operates entirely behind NAT/firewalls.
2.  **Mathematical High Availability**: Inbound message streams perfectly align with Zenoh Leader Election. If a node loses leadership or restarts, messages are buffered in the external provider's queue (Telegram, GCP Pub/Sub) and retrieved without loss by the new leader.
3.  **Dependency Purge**: We can completely eradicate the Erlang HTTP server ecosystem (`wisp`, `mist`) from our Cognitive Plane.

## 2. Technical Reification
The implementation utilizes the existing `reqwest` client in the Rust Motor Strip. A dedicated Tokio task, bound strictly to the `LeaderLease`, performs asynchronous long-polling against the `api.telegram.org/bot<TOKEN>/getUpdates` endpoint.

Messages are decrypted, parsed, and injected directly into the internal Zenoh mesh (`indrajaal/l5/cog/intent/req`), maintaining the SC-ZMOF-001 (Sole Transport) mandate.

## 3. Tradeoff Resolution
While Webhooks provide sub-millisecond push latency, they require public internet exposure. Egress polling introduces minor latency (bound by the polling interval, e.g., 1000ms), but the security benefits (Dark Cockpit) and zero-message-loss HA capabilities overwhelmingly justify the architectural shift for a SIL-6 autonomous system.
