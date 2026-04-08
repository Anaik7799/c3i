# Architectural Specification: OpenClaw CLI Ultrathink Formalization

**Version**: 2.0.0 (Ultrathink Revision)
**Date**: 2026-04-08
**Classification**: SYSTEM ARCHITECTURE / SIL-6 FORMAL METHODS
**Compliance**: SC-ULTRA-001, SC-MATH-003, SC-FMEA-001, SC-STAMP-001

## 1. Mathematical Preliminaries & State Space ($\Sigma_{CLI}$)

To achieve SIL-6 compliance, the CLI operational layer is formalized as a rigorous state machine where all mutations are cryptographically verifiable.

**State Space Definitions**:
*   $\mathcal{S}_{secret} \in \mathbb{C}$: The set of all cryptographic secrets (API tokens, OAuth states).
*   $\mathcal{H}_{hitl} \in \{Pending, Approved, Denied, Timeout\}$: Human-in-the-loop approval states.
*   $\mathcal{N}_{node} \in \mathcal{Z}$: Zero-IP Identity nodes authenticated on the Zenoh mesh.
*   $\mathcal{E}_{exec} \in \mathcal{P}$: Ephemeral execution sandboxes (Podman cells).

**Ultrathink Invariant (SC-ULTRA-001)**:
$$ \forall a \in \text{CLI\_Actions} : \text{Mutation}(a) \implies \text{CRDT\_Sync}(\text{Smriti.db}) \wedge \text{EventSourcingLog}(a) $$

## 2. Advanced Feature Extraction & Ultrathink Mapping

We transcend the TypeScript-based OpenClaw implementations and map their underlying *intents* to our 8 Ultrathink Focus Areas.

### 2.1 Zero-IP Node Pairing & Discovery (`openclaw nodes / pair`)
*   **OpenClaw Concept**: Pairing companion apps or external devices via QR codes or network discovery.
*   **Ultrathink Reification**: **Zero-IP Identity Routing (Zenoh)**.
    *   Devices do not connect via IP/TCP directly to the Brain-Stem. Instead, the CLI generates a cryptographic Zenoh token (`sa-plan pair`).
    *   The remote node (e.g., Vision Pro, Raspberry Pi) publishes to `indrajaal/l6/sensors/{uuid}`.
    *   **Math**: $\forall n \in \mathcal{N}_{node} : \text{Authenticate}(n) \iff \text{ValidSignature}(n_{token}, \text{Root\_CA})$.

### 2.2 Cryptographic Secret Management (`openclaw secrets`)
*   **OpenClaw Concept**: Managing LLM and channel tokens via a local keychain.
*   **Ultrathink Reification**: **Zenoh-Native CRDT State Backplane**.
    *   `sa-plan secrets set` does not write to a flat file. It writes to the SQLite CRDT backplane (`Smriti.db`), which is symmetrically encrypted.
    *   **Math**: $\text{Store}(K, V) = \text{Encrypt}(V, K_{master}) \to \text{CRDT\_Append}(EventLog)$.

### 2.3 Human-in-the-Loop (HITL) execution (`openclaw exec-approvals`)
*   **OpenClaw Concept**: Halting dangerous shell commands until a user clicks "Approve".
*   **Ultrathink Reification**: **Continuous Formal Verification & OODA Halting**.
    *   The Gleam Cortex evaluates $Risk(Command)$. If $Risk > \tau_{safe}$, the OODA cycle transitions to $\mathcal{H}_{hitl} = Pending$.
    *   The Rust Motor Strip refuses to act without a cryptographic signature from the Gateway channel (Telegram/GChat) proving human consent.

## 3. STAMP Safety Constraints (SC-CLI-ULTRA)

| ID | Constraint | Control Action | Feedback |
| :--- | :--- | :--- | :--- |
| **SC-CLI-010** | System SHALL NOT expose decrypted secrets in memory for >50ms. | Rust `Zeroize` drop on secret strings. | Memory profile audit. |
| **SC-CLI-011** | Destructive commands (e.g., `rm`, `mkfs`) MUST require multi-factor HITL approval. | Cortex Halts OODA $\to$ Gateway publishes intent. | Human signs intent via Telegram. |
| **SC-CLI-012** | Remote nodes MUST NOT execute commands, only publish sensory data. | Zenoh Subscriber Permissions restricted to `/sensors/**`. | Access Denied errors. |
| **SC-CLI-013** | CLI configuration mutations MUST be replicated via CRDT before returning `0`. | `Smriti.db` block until sync complete. | SQLite WAL sync status. |

## 4. Failure Mode and Effects Analysis (FMEA)

| Component | Failure Mode | Local Effect | System Effect | RPN | Mitigation (AOR) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `sa-plan secrets` | Secret written to stdout/log. | Token leakage. | Catastrophic security breach. | 100 | **AOR-SEC-005**: All secret parameters passed via `stdin` or encrypted env, NEVER `argv`. Strict `Zeroize` traits. |
| `sa-plan pair` | Forged Zenoh token accepted. | Rogue node joins mesh. | Contaminated sensory data (Hallucination). | 80 | **AOR-ID-002**: Strict ECDSA signature verification on all incoming Zenoh payloads. |
| `sa-plan approvals`| HITL timeout fails closed indefinitely. | OODA loop deadlock. | Cortex permanently stalled. | 60 | **AOR-TMP-009**: Timeout forces $\mathcal{H}_{hitl} \to Denied$ after 300s. OODA loop resumes with `FallbackAction`. |

## 5. Agent Operating Rules (AOR-CLI)
*   **AOR-CLI-001** ($\mathbf{F}$): An Agent SHALL NOT bypass the HITL gate for any command matching the regex `.*(rm|drop|delete|kill|shutdown|reboot).*`.
*   **AOR-CLI-002** ($\mathbf{O}$): The `sa-plan` daemon MUST audit log the invocation of any administrative CLI command (e.g., `secrets`, `models`, `channels`) to the Cryptographic Event Sourcing Log.
