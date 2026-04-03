# Indrajaal User-Centric Services: Fractal Control & Sovereignty (I2S-Control)

**Date**: 2026-01-02T21:00:00+01:00
**Author**: Cybernetic Architect (Gemini)
**Status**: Requirements Definition
**Objective**: Define the "User-Centric" control plane for Indrajaal that replicates and exceeds the utility of GCP/AWS Consoles, while maintaining fractal sovereignty.

## 1. The Core Requirement: Fractal Control

In AWS/GCP, "Control" is a centralized web console. In Indrajaal, "Control" must be a **Fractal Mechanism**.
*   **L1 (Function)**: The Function controls its own memory.
*   **L3 (Holon)**: The Holon controls its own wallet and users.
*   **L7 (Federation)**: The Federation controls its own topology.

**Mandate**: A single, deterministic logic (The Founder's Directive) must govern rights, billing, and operations at *every* layer, recursively.

---

## 2. Service Displacement: User-Centric Operations

We map the "User Experience" services of Cloud Providers to Indrajaal equivalents.

| Capability | GCP/AWS Service | Indrajaal Equivalent (I2S-Control) | Advantage |
| :--- | :--- | :--- | :--- |
| **Billing** | AWS Cost Explorer / GCP Billing | **Fractal Treasury** | Real-time, streaming payments. No monthly "bill shock". Pay-as-you-go per millisecond. |
| **Metering** | CloudWatch Metrics / Stackdriver | **SmartMetrics Metering** | Cryptographically verified usage proofs. The user can *audit* the bill. |
| **Access** | AWS IAM / GCP IAM | **Sovereign Capability Grants** | Tokens that grant rights. Can be delegated, sold, or revoked instantly. |
| **Operations** | AWS Systems Manager / Cloud Console | **Prajna Cockpit** | A unified, local-first console. Works offline. No "portal lag". |
| **Support** | AWS Support / Trusted Advisor | **Prajna AI Advisor** | Instant, code-aware support. "Fix it for me" button. |

---

## 3. The Fractal Control Mechanism

### 3.1 Deterministic Rights (The "Capability Token")
Instead of Access Control Lists (ACLs) stored in a database, we use **Capability Tokens**.
*   **Structure**: `[HolonID : ResourceID : Action : Constraints : Signature]`
*   **Verification**: Any node can verify a token mathematically without checking a central DB.
*   **Fractal**: A Federation Token grants access to a Cluster. A Cluster Token grants access to a Holon. A Holon Token grants access to a Function.

### 3.2 Recursive Billing (The "Energy Stream")
Billing is not a database row; it is a **Flow**.
1.  **User** opens a payment stream (Superfluid / Lightning) to the **Holon**.
2.  **Holon** keeps a cut, and streams payment to the **Cluster** (for bandwidth).
3.  **Cluster** keeps a cut, and streams payment to the **Substrate** (AWS/GCP/ICP).
*   **Result**: Real-time economic equilibrium. If the user stops paying, the service stops *instantly* (no debt risk).

### 3.3 Usability: "The Universal Console"
The `Prajna Cockpit` is not just a monitoring tool; it is the **Universal Controller**.
*   **Single Pane**: One UI to manage Identity, Billing, Code, and Security.
*   **Context Aware**: Zoom In/Out (Fractal View). See the whole Federation or a single Line of Code.
*   **Actionable**: Every metric is clickable. Every error has a "Fix" button.

---

## 4. Implementation Priorities (Sprint 33)

1.  **Capability Token Standard**: Define the JWT/Biscuits-like token format for rights (SC-SEC-001).
2.  **Metering Middleware**: Inject metering logic into the `Prajna.SmartMetrics` pipeline to count "Billable Units" (Requests, CPU, GB-Hours).
3.  **Treasury Logic**: Implement the basic ledger for "Credits In / Resources Out".

*By fractalizing control, we give the user the power of a Cloud Admin at the scale of a single function.*
