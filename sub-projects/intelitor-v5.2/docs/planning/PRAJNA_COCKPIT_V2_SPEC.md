# Prajna & Cockpit: Post-Cloud Adaptation Plan

**Date**: 2026-01-02T23:45:00+01:00
**Author**: Cybernetic Architect (Gemini)
**Status**: Requirements Definition
**Context**: Required changes to Prajna Cockpit to support I2S, UCAN, and ICP.

## 1. Executive Summary

The current Prajna Cockpit is designed for *monitoring a server*.
The new Prajna Cockpit must be designed for *governing a sovereign holon*.

This requires 3 fundamental shifts in the UI/UX and underlying logic:
1.  **Identity Shift**: From Login/Password to **Wallet/DID Connection**.
2.  **Resource Shift**: From CPU/RAM Graphs to **Economic/Metabolic Flows**.
3.  **Control Shift**: From Admin Forms to **Governance Proposals**.

---

## 2. Required Changes: The "Cockpit 2.0" Specification

### 2.1 Identity & Access Module (The Passport Scanner)
*   **Current**: `Guardian` checks local user table.
*   **Required**:
    *   **Internet Identity Integration**: Add `auth_client.js` (ICP) to the frontend.
    *   **UCAN Resolver**: Middleware to parse `Authorization: Bearer <UCAN>` headers.
    *   **Capability Explorer**: A UI to visualize *who* has *what* rights (The Fractal Trust Chain).
    *   **Delegation UI**: "Grant Access" button that generates a short-lived UCAN for a support engineer or another Holon.

### 2.2 Economic/Metabolic Module (The Energy Gauge)
*   **Current**: Metrics show CPU %.
*   **Required**:
    *   **Treasury Widget**: Shows Cycle Balance, BTC/ETH holdings, and Burn Rate (Cycles/Hour).
    *   **Survival Time**: A "Time to Death" countdown based on current treasury and burn rate.
    *   **Top-Up**: "Add Funds" button (QR Code for Bitcoin/ICP).
    *   **Resource Arbitration**: UI to set "Max Bid Price" for compute resources (e.g., "Don't pay more than $0.10/hr for Spot Instances").

### 2.3 Governance Module (The Council Chamber)
*   **Current**: Config files and Environment Variables.
*   **Required**:
    *   **Proposal System**: Changes to critical config (Ψ) must be submitted as **Proposals**.
    *   **Voting Interface**: Stakeholders (Founder/Admins) vote on proposals using Threshold Signatures.
    *   **Constitution Viewer**: Read-only view of the Founder's Directive ($\Omega_0$) and current Safety Constraints ($\Psi$).

### 2.4 Immune System Viz (The Radar)
*   **Current**: Log lines in a terminal.
*   **Required**:
    *   **Threat Map**: Visualization of active `Sentinel` detections.
    *   **Antibody Status**: List of active antibodies and their targets.
    *   **Mara Controls**: "Run Fire Drill" button to manually trigger resilience tests.

### 2.5 Data Sovereignty Module (The Vault)
*   **Current**: Database tables.
*   **Required**:
    *   **Audit Browser**: Explorer for the `ImmutableState` hash chain.
    *   **Verifiable Export**: "Download Proof" button to get a cryptographically signed dump of specific logs for compliance.

---

## 3. Implementation Roadmap (Prajna)

### Phase 1: The Wallet Connection (Sprint 33)
*   Add `IndrajaalWeb.Auth.Web3` module.
*   Support Internet Identity login.
*   Replace session cookies with UCANs in LocalStorage.

### Phase 2: The Treasury View (Sprint 33)
*   Create `Indrajaal.Cockpit.Prajna.TreasuryLive` view.
*   Connect to `Indrajaal.Core.Holon.Metabolism` for real-time cycle data.

### Phase 3: The Governance Interface (Sprint 34)
*   Create `Indrajaal.Cockpit.Prajna.GovernanceLive` view.
*   Implement Proposal/Vote/Execute workflow.

### Phase 4: The Biomorphic Dashboard (Sprint 35)
*   Refactor the main dashboard to prioritize "Organism Health" (Metabolism/Immunity) over "Machine Stats" (CPU/Disk).

---

## 4. Technical Debt/Risk
*   **Frontend Heavy**: This adds significant JS/Wasm complexity to the Phoenix LiveView frontend (Internet Identity, UCAN signing).
*   **Mitigation**: Encapsulate all crypto logic in a `holon_sdk.js` library. LiveView only handles the *state*, not the *signing*.

*The Cockpit evolves from a Dashboard to a Bridge between the Human Founder and the Digital Holon.*
