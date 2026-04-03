# UCAN Integration Analysis: The Standard for Sovereign Capability

**Date**: 2026-01-02T21:30:00+01:00
**Author**: Cybernetic Architect (Gemini)
**Status**: Technology Selection / Architectural Decision
**Subject**: User Controlled Authorization Networks (UCAN) as the implementation for Indrajaal Capability Tokens.

## 1. Executive Summary

We previously identified the need for **"Sovereign Capability Grants"** to replace centralized IAM (Identity & Access Management).

**Analysis**: UCAN (User Controlled Authorization Networks) is the *perfect* open standard for this. It fulfills every requirement of the Indrajaal "Fractal Control" strategy and adds capabilities we hadn't even scoped yet.

**Verdict**: **ADOPT IMMEDIATELY.** Do not invent a custom token format. UCAN is the standard for the "Post-Cloud" era.

---

## 2. What is UCAN? (The Capabilities)

UCAN extends the familiar JWT (JSON Web Token) structure but inverts the trust model.

### 2.1 Capability 1: Inversion of Control (User-Originated)
*   **Old Way (OAuth/IAM)**: A Server (Google) creates a token saying "I allow User X to do Y".
*   **UCAN Way**: A User (DID) signs a token saying "I authorize App A to access *MY* resource Z".
*   **Value for Indrajaal**: Aligns perfectly with the **Founder's Directive**. The Holon (User) is sovereign, not the Cloud Provider.

### 2.2 Capability 2: Infinite Delegation (The Fractal Chain)
*   **Mechanism**: A UCAN can contain a `prf` (proof) field, which is *another* UCAN.
    *   *Alice* grants *Phone* "Full Access".
    *   *Phone* grants *App* "Read Access" (citing Alice's grant as proof).
*   **Value for Indrajaal**: This *is* the **Fractal Control Mechanism**.
    *   L7 Federation delegates to L6 Cluster.
    *   L6 Cluster delegates to L3 Holon.
    *   L3 Holon delegates to L1 Function.
    *   *Verification*: The L1 Function can verify the L7 root authority offline by tracing the chain.

### 2.3 Capability 3: Attenuation (Least Privilege)
*   **Mechanism**: A delegate can only grant *less* or *equal* rights than they hold.
*   **Value for Indrajaal**: **Safety Plane Enforcement**. The `Guardian` can issue a "Safe Token" to the AI Copilot that *physically prevents* it from executing dangerous commands (`rm -rf`), regardless of what the AI "thinks".

### 2.4 Capability 4: Offline Verification
*   **Mechanism**: Validation relies on Public Key Cryptography (Ed25519/RSA), not a database lookup.
*   **Value for Indrajaal**: **Resilience**. A Holon can operate on a submarine or Mars. It doesn't need to "call home" to AWS IAM to check permissions.

---

## 3. Integration Strategy: "The Fractal Passport"

We will rename "Sovereign Capability Grants" to **"Holon Passports" (UCANs)**.

### 3.1 The Identity Root: `did:key`
*   Every Holon generates a `did:key` (Ed25519) on startup. This is its "Root Identity".
*   This key signs the "Root UCAN" allowing `*` (superuser) access to itself.

### 3.2 The Federation Handshake
1.  **Join**: New Holon sends its DID to Federation.
2.  **Grant**: Federation signs a UCAN granting `fed:access` to that DID.
3.  **Result**: The Holon can now talk to other Holons in the mesh using this token.

### 3.3 The Prajna Session
1.  **Login**: User connects via Internet Identity (II).
2.  **Delegation**: The Holon delegates `cockpit:admin` rights to the User's II DID for 1 hour.
3.  **Action**: Every command sent from Prajna includes this UCAN.
4.  **Audit**: The UCAN chain is logged to the `ImmutableState`. We know *exactly* who authorized what, backed by math.

---

## 4. Why this is "Better than Google"

| Feature | Google IAM | Indrajaal UCAN |
| :--- | :--- | :--- |
| **Trust Source** | Google Database | Math (Signatures) |
| **Availability** | Online Only | Offline / Local-First |
| **Delegation** | Complex (Assume Role) | Native / Recursive |
| **Interoperability** | Google-only | Universal (IPFS/Filecoin/Ethereum) |
| **Lock-in** | Absolute | Zero |

---

## 5. Strategic Recommendation

1.  **Standardize**: Adopt **UCAN 0.10** specs.
2.  **Library**: Use `rust-ucan` via NIFs (Rustler) for performance and correctness. Do not write a pure Elixir parser if a verified Rust one exists.
3.  **Scope**: Update **Sprint 33 (Economic Autonomy)** to use UCANs for "Energy Stream" authorization (spending credits requires a UCAN).

*UCAN is the missing cryptographic link that makes the "Fractal Holon" mathematically possible.*
