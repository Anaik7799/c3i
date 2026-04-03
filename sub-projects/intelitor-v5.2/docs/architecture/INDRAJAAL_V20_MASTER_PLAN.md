# Indrajaal v20: The Sovereign Cybernetic Organism - Master Plan

**Version**: 20.0.0
**Date**: 2025-12-30
**Status**: DEFINITIVE
**Classification**: ARCHITECTURAL BIBLE

---

## 1.0 CONCEPT: The Cybernetic Organism
Indrajaal is not a "platform" or a "service." It is a **Distributed Cybernetic Organism**.
*   **Mission**: To provide a sovereign, self-healing, and evolutionary software foundation for safety-critical planetary-scale operations.
*   **Philosophy**: We reject the "Cloud-Native" model of renting proprietary APIs. We adopt the **"Sovereign Poly-Cloud"** model: utilizing commodity cloud resources (Compute/Storage) while retaining total ownership of Intelligence, State, and Logic.
*   **Metaphor**:
    *   **The Body**: Heterogeneous Compute (Hetzner, AWS, Edge).
    *   **The Brain**: Neuro-Symbolic AI (OpenRouter + Local Vectors).
    *   **The Nerves**: Secure Mesh (Tailscale + Zenoh).
    *   **The Skin**: Edge Protection (Cloudflare).

## 2.0 SPECIFICATION: The Biological Laws
The system is governed by immutable axioms that cannot be violated by any feature.

### 2.1 The Fractal Axiom
*   **Rule**: "As above, so below." The system is composed exclusively of **Holons**.
*   **Definition**: A Holon is an atomic unit containing:
    1.  **State** (Memory)
    2.  **Logic** (Compute)
    3.  **Membrane** (Security Boundary)
    4.  **Vital Signs** (Health Telemetry)
*   **Scope**: A single function is a Holon. A container is a Holon. The entire Federation is a Holon.

### 2.2 The Simplex Axiom (Safety > IQ)
*   **Rule**: The **Guardian Plane** (Deterministic Code) has absolute veto power over the **Cortex Plane** (Probabilistic AI).
*   **Constraint**: No AI-generated code or command executes without passing a formally verified safety check (`SC-NEURO-001`).

### 2.3 The Gravity Axiom
*   **Rule**: **Move Compute to Data**. Never move heavy data (Video/Logs) to the compute.
*   **Constraint**: Video processing MUST happen on the node where the stream ingests ("Gravity Well"). Only metadata moves.

### 2.4 The Sovereignty Axiom
*   **Rule**: No dependency on proprietary cloud "Intelligence" or "State" services.
*   **Allowed**: Raw Compute (EC2/Droplets), Block Storage, S3 API.
*   **Forbidden**: DynamoDB, Spanner, BigQuery, AWS Lambda, Azure OpenAI.

## 3.0 ARCHITECTURE: The Anatomy

### 3.1 Somatic System (Compute & Storage)
*   **The Gravity Well**: Hetzner Dedicated Servers (NVMe + GPU) for heavy ingest.
*   **The Federation Core**: Kubernetes (GKE/DOKS) for the Control Plane.
*   **The Edge**: Cloudflare Workers for global ingress.

### 3.2 Nervous System (Communication)
*   **Control Plane**: **Tailscale Mesh**. Encrypted, identity-based signaling.
*   **Data Plane**: **Zenoh + WebRTC**. High-bandwidth, zero-overhead streams.
*   **Pattern**: **Split-Plane Video**. Signaling via Tailscale; Pixels via WebRTC P2P.

### 3.3 Metabolic System (Data & State)
*   **Hot Memory**: **LanceDB** (Vectors) + **Redis** (PubSub) on Gravity Nodes.
*   **Cold Memory**: **Parquet** (Logs) queried via **DuckDB**.
*   **System of Record**: **CloudNativePG** (Postgres + TimescaleDB) on the Core.

### 3.4 Cognitive System (Intelligence)
*   **Reflex (System 1)**: Local **YOLO/Llama-8B** on Gravity Nodes (millisecond response).
*   **Reasoning (System 2)**: **OpenRouter** (Claude/Gemini) for complex analysis (second response).
*   **Memory**: **Pgvector** for long-term semantic retrieval.

## 4.0 IMPLEMENTATION: The Genetic Code

### 4.1 Core Modules
*   `Indrajaal.Core.Holon`: The behavior enforcing VSM compliance.
*   `Indrajaal.Bio.Membrane`: The security wrapper/firewall.
*   `Indrajaal.Cortex.Synapse`: The sensor fusion engine.

### 4.2 Critical Upgrades (v20.1)
*   **AU-01**: OpenRouter Adapter (Cognitive Decoupling).
*   **AU-02**: Data Locality Registry (Gravity Routing).
*   **AU-07**: Pre-Roll Ring Buffer (Instant Video Verification).
*   **AU-14**: The Video Artery (WebRTC P2P Implementation).
*   **AU-15**: Zenoh-First Nervous System.

### 4.3 Code Generation Strategy
*   **TDG**: Tests MUST exist before code (Test-Driven Generation).
*   **AOR**: Agents must follow Operational Rules (e.g., "Always format before commit").

## 5.0 VERIFICATION: The Immune System

### 5.1 The Three-Layer Pyramid
1.  **ExUnit**: Runtime validation of biological behaviors (Vital Signs, Mitosis).
2.  **Quint**: Model checking of distributed state machines and protocols.
3.  **Agda**: Formal proof of core safety invariants (e.g., "Guardian always vets Cortex").

### 5.2 The Gates
*   **G1 (Spec)**: Quint check passes.
*   **G2 (Code)**: Compilation (0 warnings) + ExUnit passes.
*   **G3 (Safety)**: STAMP constraints verified.

## 6.0 USABILITY: The Cybernetic Interface

### 6.1 The Prajna Cockpit
*   **Concept**: A **Holographic Interface** into the organism.
*   **Modes**:
    *   **Gardener Mode**: Observing health, pruning dead holons.
    *   **War Room Mode**: Incident Command, fusing Video + Map + Dispatch.
*   **Bimodal**:
    *   **Web (Elixir)**: Rich visualization, WebRTC video matrix.
    *   **TUI (F#)**: Tactical, low-bandwidth, ASCII video rendering (Kitty).

### 6.2 The OODA Visualizer
*   **Trust**: The operator sees the AI's "Thought Process" in real-time.
*   **Control**: A physical "Veto" button to stop the AI before the *Act* phase.

## 7.0 INFORMATION STRUCTURES & PROTOCOLS

To ensure 100% runtime coverage, we define the explicit data shapes and flow logic.

### 7.1 Core Schemas (The "DNA")
*   **Holon State**:
    ```elixir
    %{
      id: HolonID,
      type: Atom,       # :cell | :tissue | :organ
      vitals: %{health: 0.0..1.0, stress: 0.0..1.0, energy: Integer},
      config: Map,      # Static genetic code
      memory_ref: CID   # Content Addressable ID for state snapshot
    }
    ```
*   **Signal**:
    ```elixir
    %{
      id: UUID,
      source: HolonID,
      target: HolonID | :broadcast,
      type: :control | :data | :reflex,
      payload: Term,
      hlc: HLC.Timestamp # {phys, logical, node}
    }
    ```
*   **Vector Embedding**:
    ```elixir
    %{
      id: UUID,
      model_ver: String, # "openai/text-embedding-3-small"
      vector: Binary,    # [f32; 1536] packed
      metadata: Map      # {source_id: "cam-1", timestamp: HLC}
    }
    ```

### 7.2 Path Logic (The "Circulatory System")
*   **Control Router** (`Indrajaal.Mesh`):
    *   **Rule**: IF `type == :control` (Commands, Policy).
    *   **Transport**: Erlang Dist over Tailscale.
    *   **Guarantee**: At-least-once. Ordered. Max payload 64KB.
*   **Data Router** (`Indrajaal.Zenoh`):
    *   **Rule**: IF `type == :data` (Telemetry, State Sync).
    *   **Transport**: Zenoh over QUIC/TCP.
    *   **Guarantee**: Best-effort. High throughput.
*   **Video Artery** (`Indrajaal.Video.Artery`):
    *   **Rule**: IF `type == :video_stream`.
    *   **Transport**: WebRTC (DTLS-SRTP) via UDP P2P.
    *   **Guarantee**: Real-time (frames dropped if late).

### 7.3 Lifecycle Logic (The "Biology")
*   **Genesis (Boot Sequence)**:
    1.  **Kernel**: BEAM VM starts. `Indrajaal.Application` init.
    2.  **Identity**: Load Tailscale Auth Key. Assert Node ID.
    3.  **Mesh**: Join Tailscale Network. Connect to Zenoh Router.
    4.  **Membrane**: Start `Indrajaal.Bio.Membrane`. Open Ports 4000/9000.
    5.  **Consciousness**: Load local AI models (or connect OpenRouter).
*   **Eschatology (Shutdown Sequence)**:
    1.  **Apoptosis**: Signal `stop` to all Child Holons.
    2.  **Flush**: Drain `GenStage` buffers to Parquet/Disk.
    3.  **Disconnect**: Leave Zenoh/Tailscale mesh.
    4.  **Halt**: Stop BEAM VM.

---
**Assertion**: This Master Plan represents the complete synthesis of the Indrajaal v20 Architecture. It is the single source of truth for all subsequent development.
