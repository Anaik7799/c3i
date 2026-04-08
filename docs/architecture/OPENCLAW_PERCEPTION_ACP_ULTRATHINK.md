# Architectural Specification: OpenClaw Perception & ACP Ultrathink Formalization

**Version**: 4.0.0 (Perception & Protocol Revision)
**Date**: 2026-04-08
**Classification**: SYSTEM ARCHITECTURE / SIL-6 FORMAL METHODS
**Compliance**: SC-ULTRA-001, SC-MATH-003, SC-FMEA-001, SC-STAMP-001

## 1. Mathematical Preliminaries & State Space ($\Sigma_{PER}$)

In this third deep pass over the OpenClaw codebase (`src/acp`, `src/canvas-host`, `src/realtime-voice`), we abstract away the TypeScript implementation and extract the mathematical core of **Continuous Perception** and **Boundaried Control**. 

**State Space Definitions**:
*   $\mathcal{A}_{acp} \in \mathbb{P}$: The Agent Control Protocol boundary defining the exact permissions $P$ of an agent session.
*   $\mathcal{V}_{canvas} \in \mathcal{C}$: A CRDT-backed shared spatial rendering context (A2UI Canvas).
*   $\Phi_{audio} \in \mathbb{R}^n$: Continuous vector streams representing real-time voice and media ingestion.

**Ultrathink Invariant (SC-ULTRA-003)**:
$$ \forall s \in \text{Streams} : \text{Process}(s) \implies \text{GuardianVerify}(\text{Content}(s)) \wedge \text{Latency}(s) < 20ms $$

## 2. Advanced Feature Extraction & Ultrathink Mapping

### 2.1 Agent Control Protocol (ACP) (`src/acp`)
*   **OpenClaw Concept**: Standardized protocol for defining agent boundaries, translating capabilities, and managing persistent bindings.
*   **Ultrathink Reification**: **SIL-6 Guardian Boundaries**.
    *   The `cepaf_gleam/security/hitl_validator.gleam` is elevated to an **ACP Translator**. Before any Zenoh intent reaches the Rust Motor Strip, it must pass through the ACP boundary. The ACP translator guarantees that agents cannot escalate privileges outside their ephemeral session policy.
    *   **Math**: $\forall i \in \text{Intents} : \text{Execute}(i) \iff \text{ACP\_Verify}(i, \text{SessionPolicy})$.

### 2.2 Canvas Host & A2UI State (`src/canvas-host`, `src/a2ui`)
*   **OpenClaw Concept**: Rendering interactive UI components that agents and users collaborate on.
*   **Ultrathink Reification**: **Zenoh-Native A2UI CRDT Hologram**.
    *   Instead of React components, we use our existing `cepaf_gleam/a2ui/catalog.gleam`. The "Canvas" is not a webpage; it is a shared CRDT state published on `indrajaal/l6/canvas`.
    *   Lustre (Web), Ratatui (TUI), and the Agent's internal representation all synchronize to this mathematically guaranteed spatial state.

### 2.3 Real-Time Voice & Media (`src/realtime-voice`, `src/media-understanding`)
*   **OpenClaw Concept**: WebRTC-based streaming voice communication and continuous visual processing.
*   **Ultrathink Reification**: **Continuous OODA Wavefronts (Zero-Latency Perception)**.
    *   The Rust daemon `sa-plan` incorporates a WebRTC sink. It streams audio chunks via Zenoh to a dedicated `intelitor-perception` podman cell running Whisper/Gemma for near-instant transcription and multimodal reasoning.
    *   OODA cycles shift from discrete "text turns" to continuous state evaluations.

## 3. STAMP Safety Constraints (SC-PER-ULTRA)

| ID | Constraint | Control Action | Feedback |
| :--- | :--- | :--- | :--- |
| **SC-PER-030** | ACP boundaries MUST NOT be modified by the agent they contain. | Immutable Policy passing. | Signature validation. |
| **SC-PER-031** | Continuous streams MUST be terminable via a hardware/OOB interrupt. | Guardian `EmergencyStop` Zenoh broadcast. | Stream socket closure. |
| **SC-PER-032** | A2UI Canvas CRDT MUST resolve conflicts deterministically. | Lexicographic timestamp sorting in Gleam. | Sync parity checks. |
| **SC-PER-033** | Media processing MUST run in an ephemeral, unprivileged Podman sandbox. | `sa-plan` enforces `--network none` for processing cells. | Namespace auditing. |

## 4. Failure Mode and Effects Analysis (FMEA)

| Component | Failure Mode | Local Effect | System Effect | RPN | Mitigation (AOR) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `ACP Boundary` | Policy parsing bug. | Agent escapes bounds. | Unrestricted host access. | 100 | **AOR-ACP-001**: ACP policies must be statically typed and verified by the Rust compiler at load time. |
| `Canvas Host` | CRDT divergence. | User sees state A, Agent sees B. | Hallucinated interactions. | 60 | **AOR-CNV-002**: Gleam Canvas actor enforces periodic Merkle-tree state hashing over Zenoh. |
| `Voice Stream` | Buffer overflow. | High latency, OOM. | Voice agent crashes. | 45 | **AOR-STR-003**: Enforce 20ms frame bounds; drop frames if queue exceeds $N_{max}$. |

## 5. Agent Operating Rules (AOR-PER)
*   **AOR-PER-001** ($\mathbf{F}$): An Agent SHALL NOT process voice streams that have not been tagged by the Guardian for acoustic safety (e.g., preventing sonic prompt injection).
*   **AOR-PER-002** ($\mathbf{O}$): The `ExecutiveSupervisor` MUST inject the current Canvas State Hash into every reasoning prompt to ensure spatial awareness.
