# Deep Architectural Analysis: External Command Ingress & Security

**Date**: 2026-04-08
**Classification**: INDEPENDENT ARCHITECTURAL AUDIT (SIL-6)
**Subject**: The optimal entity and methodology for handling external inbound commands (Telegram, Google Chat, WhatsApp) while minimizing dependencies and maximizing security.

## 1. Executive Summary

An independent, "Ultrathink Deep Pass" has been conducted to determine the optimal component for receiving external commands. The current implementation utilizing the **Gleam `wisp` REST router (L7)** violates the principles of minimal dependencies, Zero-Trust isolation, and High Availability (HA) continuity.

The mathematically optimal, SIL-6 compliant solution is an **Egress-Only Polling Architecture** located entirely within the **Rust `sa-plan-daemon` (L4 Motor Strip)**. 

## 2. Architectural Analysis (Fractal Layers)

### 2.1 The Flaw in the Current Design (Wisp/Gleam)
Currently, external commands reach the system via Webhooks. Webhooks require opening an inbound HTTP port (4100) on the `intelitor-app` container, directly exposing the BEAM VM (Gleam/Erlang) to the public internet. 
- **Violation**: The Cognitive Plane (Gleam) should act strictly as the "Brain", insulated from raw internet noise. It should only listen to sanitized intents on the internal Zenoh mesh (`indrajaal/`).

### 2.2 The Optimal Design (Rust `sa-plan-daemon`)
The Rust daemon acts as the physical "Skin and Motor Strip". It is designed to safely perform network I/O and process execution.
- **Alignment**: Rust is memory-safe and highly optimized for async network operations. By shifting ingress to Rust, the `sa-plan-daemon` becomes the absolute boundary between the public internet and the internal cognitive mesh.

## 3. Security Analysis (SIL-6 Attack Surface)

### 3.1 The Inbound Port Vulnerability
Running a Webhook listener requires firewall rules allowing inbound TCP traffic. Any open port is a continuous attack surface susceptible to DDoS, malformed payload injections, and zero-day HTTP parsing vulnerabilities in the Erlang `mist`/`wisp` stack.

### 3.2 The Egress-Only Paradigm (Polling/PubSub)
Instead of Webhooks, the system must use **Long Polling** (e.g., Telegram `getUpdates`) or Cloud Pub/Sub pull subscriptions (Google Workspace). 
- **Security Guarantee**: This requires **ZERO inbound open ports**. The Rust daemon only makes outbound (egress) HTTPS requests to verified provider domains. 
- **Result**: The system becomes entirely invisible from the outside internet. It is a "Dark Cockpit."

### 3.3 Cryptographic Secret Locality
Currently, the API tokens required to verify Webhooks are stored in the Rust-managed `Smriti.db`. Passing these secrets into Gleam memory just to authenticate requests increases the risk of memory leakage. Rust provides the `Zeroize` trait to securely wipe memory immediately after token usage.

## 4. Dependency Minimization Analysis

Implementing Webhooks in Gleam required importing the `wisp` and `mist` libraries, which transitively pull in an entire Erlang HTTP server ecosystem. 

By utilizing the Rust `reqwest` client (which is *already* a required dependency for outbound messaging):
- We can completely remove `wisp`, `mist`, and `glisten` from `lib/cepaf_gleam/gleam.toml`.
- **Zero new dependencies** are added to the Rust `Cargo.toml`. 

## 5. High Availability (HA) & Seamless Upgrade Impact

Webhooks handle HA poorly during zero-downtime upgrades. When the Primary node drains and yields to the Backup node, incoming HTTP requests from Telegram/Google will drop, resulting in lost user commands.

**Polling fits perfectly with Zenoh Leader Election**:
- Only the node holding the `LeaderLease` executes the outbound polling loop.
- If the Primary node drops the lease (e.g., during an upgrade or crash), the Backup node immediately acquires the lease and resumes the polling loop.
- **Mathematical Guarantee**: Zero dropped connections and zero lost intents during binary swaps.

## 6. Strategic Conclusion

1. **Deprecate the Gleam Wisp Router**: Remove the `router.gleam` implementation and its dependencies.
2. **Implement Egress-Only Polling in Rust**: The `sa-plan-daemon` must spawn an async Tokio task (tied to the HA `LeaderElection` lock) that long-polls the Telegram API (and Google Pub/Sub).
3. **Internal Routing**: Upon fetching a new message, the Rust daemon parses it, verifies it, and publishes the `TaskIntent` to the Zenoh mesh for the Gleam Cortex.

This architecture achieves absolute network invisibility, minimizes dependencies, and mathematical perfection in HA failover.
