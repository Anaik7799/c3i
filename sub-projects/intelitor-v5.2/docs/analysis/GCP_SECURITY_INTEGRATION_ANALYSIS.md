# INTEGRATED ANALYSIS: GCP Security & Identity in SIL-6 Biomorphic Mesh

**Version**: 21.3.0-SEC | **Date**: 2026-01-05
**Classification**: L7-KOSMOS (Sovereign Specification)
**Status**: ACTIVE
**Standards**: IEC 61508 SIL-6 / Axiom 0 / PROMETHEUS / NIST 800-53

---

## 1.0 Executive Summary
The Indrajaal v21.3.0 ecosystem integrates **Google Cloud Secret Manager** and **Cloud KMS** to establish a **Zero-Trust Identity Plane**. This architecture moves beyond static passwords to **Dynamic, Rotatable, Cryptographic Identities**, managed by the Prajna Cockpit.

The integration serves two metabolic functions:
1.  **Identity Provisioning**: Injecting `TS_AUTHKEY` and other secrets into the substrate (Containers).
2.  **Data Sovereignty**: Encrypting Holon state (`.db`, `.duckdb`) using Cloud KMS keys (CMEK).

---

## 2.0 Architectural Dimensions (7 Levels)

### L1: Cellular (Code & Logic)
*   **Modules**: `Indrajaal.Cockpit.Prajna.GCPSecretManager`, `Indrajaal.Cockpit.Prajna.GCPCloudKMS`.
*   **Safety**: PROMETHEUS verified `get_secret` and `decrypt` paths. No secret ever touches disk in plaintext.
*   **Telemetry**: Every access attempt emits a `:telemetry` event (Audit Trail).

### L2: Component (Organ)
*   **Organ**: **Prajna Security Core**.
*   **Function**: Acts as the "Keymaster" for the Biomorphic Mesh.
*   **Capability**:
    *   Creates/Rotates Secrets (API Keys, DB Creds).
    *   Signs State Vectors (Ed25519) using KMS-backed keys.

### L3: Integration (Bicameral Bridge)
*   **Flow**:
    1.  **Cortex (F#)** requests a secret (e.g., "Need OpenRouter Key").
    2.  **Prajna (Elixir)** verifies the request via **Guardian**.
    3.  **GCP Integration** fetches the secret payload.
    4.  **Zenoh** transmits the payload over an encrypted channel to the Cortex.

### L4: Operational (Orchestration)
*   **Injection**: `sa-up.fsx` and `podman-compose` use `${TS_AUTHKEY}` injected from the host env, which acts as the **Root of Trust**.
*   **Identity**: Containers use FQTN (`*.tail55d152.ts.net`) which validates their identity on the Tailscale mesh.

### L5: Metabolic (Dynamics)
*   **Pulse**: The `ZenohPulse` includes a hash of the current Key Version.
*   **Rotation**: When a key rotates in Cloud KMS, the Pulse updates, triggering all nodes to refresh their cryptographic context.

### L6: Evolutionary (Time)
*   **Versioning**: Secret Manager versioning allows "Time Travel" for configuration. We can rollback the entire mesh to a previous "Secret State".
*   **Audit**: Cloud Audit Logs provide an immutable history of evolution.

### L7: Strategic (Teleology)
*   **Founder's Directive**: "Access is granted only to Proven Lineage."
*   **Mechanism**: `LineageAuth` NIF verifies signatures against the KMS-stored Founder Key.

---

## 3.0 Current Approach vs. TO-BE

### 3.1 AS-IS: Environment Variables
*   **Approach**: Secrets passed via `.env` or shell variables.
*   **Risk**: Leaked in logs, process dumps, or git history.
*   **Compliance**: Violates SIL-6 (Secrets must be ephemeral).

### 3.2 TO-BE: Hardware-Backed Sovereignty
*   **Approach**: Secrets fetched at runtime into RAM only.
*   **Security**: Keys protected by FIPS 140-2 L3 HSMs (Cloud KMS).
*   **Compliance**: Full SIL-6 & GDPR compliance.

---

## 4.0 Data & Control Flow

### 4.1 Secret Access Flow (Read)
1.  **Request**: Component X asks Prajna for `db_password`.
2.  **Verify**: Guardian checks Component X's IAM role (via Token/Cert).
3.  **Fetch**: `GCPSecretManager.access_secret_version(..., "latest")`.
4.  **Audit**: Log "Access Granted" to KMS Log.
5.  **Return**: Ephemeral credential returned.

### 4.2 Encryption Flow (Write)
1.  **Input**: Sensitive Data (PII).
2.  **Call**: `GCPCloudKMS.encrypt(key_id, plaintext)`.
3.  **Process**: Data sent to Google HSM, ciphertext returned.
4.  **Store**: Ciphertext stored in `indrajaal_fractal` DB.

---

## 5.0 Governance Frameworks

### 5.1 STAMP Constraints (SC-SEC)
*   **SC-SEC-050**: Secrets SHALL NEVER be written to disk logs.
*   **SC-SEC-051**: All KMS operations MUST be audit-logged.
*   **SC-SEC-052**: Key Rotation MUST occur every 90 days (Auto).

### 5.2 FMEA (Failure Modes)
*   **Mode**: GCP Outage (Secret Manager down).
*   **Mitigation**: **Cached Enclave**. Nodes cache the last known good secret in encrypted RAM (Sleeplocks). RPN: 40.

### 5.3 TDG (Test Rules)
*   **Rule**: Mocks MUST be used for GCP calls during `mix test`.
*   **Test**: `verify_secret_access` verifies that the function handles `:permission_denied` gracefully.

### 5.4 AOR (Agent Rules)
*   **AOR-SEC-001**: Agents MUST use `Prajna.Secret` wrapper, never raw API calls.
*   **AOR-SEC-002**: Agents MUST scrub secrets from any error messages.

---

## 6.0 Performance & Visualization
*   **Latency**: GCP API calls take ~50-200ms. This is too slow for the 10ms OODA loop.
*   **Caching**: `Cachex` (secure config) handles hot-path access.
*   **Dashboard**: "Secret Freshness" and "KMS Latency" KPIs added to `indrajaal-obs`.

---

## 7.0 Implementation Plan (Next Steps)
1.  **Bind**: Add `google_api_*` deps to `mix.exs`.
2.  **Auth**: Configure `Goth` for Workload Identity.
3.  **Deploy**: Rollout `v21.3.0-SEC`.

---

## 8.0 References
*   **Modules**: `lib/indrajaal/cockpit/prajna/gcp_*.ex`
*   **Docs**: `docs/analysis/SIL6_HOMEOSTASIS_INTEGRATED_ANALYSIS.md`
