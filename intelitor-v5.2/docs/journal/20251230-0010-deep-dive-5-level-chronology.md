# Deep Dive: 5-Level Chronology & Time Synchronization

**Date**: 2025-12-30 00:10 CEST
**Author**: Gemini Cybernetic Architect
**Context**: Defining the rigorous time-handling architecture required for correlating safety-critical Alarms with high-bandwidth Video streams in a distributed system.

## Level 1: The Global Clock (Absolute Time)
**Objective**: Establish a common reference frame.
-   **Standard**: **UTC** (ISO 8601) is the immutable standard for all internal storage and communication. Local time is a UI-only concern.
-   **Synchronization**: All nodes (Federation, Gravity Wells, Edge) MUST run **Chrony/NTP** synced to Stratum-1 sources.
-   **Safety Constraint**: `SC-TIME-001`: Maximum allowable drift is **50ms**. If drift > 50ms, the node is marked "Unhealthy" by the Guardian and its write permissions are revoked to prevent data corruption.

## Level 2: The Distributed Timestamp (Causal Time)
**Objective**: Order events across distributed nodes without relying on perfect clock sync.
-   **Mechanism**: **Hybrid Logical Clocks (HLC)**.
-   **Structure**: Timestamps are tuples: `{physical_utc, logical_counter, node_id}`.
-   **Benefit**: Guarantees **Causal Ordering**. If Alarm A causes Action B, A will *always* have a lower HLC than B, even if the nodes' physical clocks are slightly skewed. This is critical for RCA (Root Cause Analysis).

## Level 3: The Video Timeline (Stream Alignment)
**Objective**: Precisely correlate discrete Alarms with continuous Video segments.
-   **Mechanism**: **Normalized Presentation Time Stamps (PTS)**.
-   **Flow**:
    1.  **Ingest**: The `Multimedia-Membrane` reads the camera's RTSP timestamp.
    2.  **Normalization**: It maps the camera's internal clock to the Node's HLC at the moment of frame arrival (`delta_correction`).
    3.  **Tagging**: Every frame and every AI-derived metadata tag is stamped with this **System HLC**.
-   **Result**: "Fire detected at HLC 100" maps exactly to "Frame #450 at HLC 100", regardless of the camera's internal clock drift.

## Level 4: The Alarm Lifecycle (Interval Logic)
**Objective**: Model Alarms as stateful intervals, not just point events.
-   **Model**: An Alarm is a `Span` defined by `[activation_hlc, resolution_hlc)`.
-   **Storage**:
    -   **TimescaleDB**: Uses the `activation_hlc` as the primary hypertable key for partitioning.
    -   **Constraint**: The database enforces `activation < acknowledgment < resolution`.
-   **Correlation**: To find video for an alarm, we query LanceDB for all vector embeddings where `vector_hlc` intersects the `Alarm Span`.

## Level 5: The Edge of Simultaneity (Jitter & Watermarks)
**Objective**: Handle out-of-order arrival due to network latency (The "Fog of War").
-   **Mechanism**: **Watermark Buffering**.
-   **Logic**: The Event Processor maintains a dynamic "Watermark" (e.g., `CurrentTime - 500ms`).
    -   Events with `HLC < Watermark` are processed immediately.
    -   Events with `HLC > Watermark` are buffered.
    -   Late events (`HLC << Watermark`) are accepted but tagged `late_arrival: true` for audit purposes.
-   **Impact**: This introduces a deliberate 500ms latency to the "Real-Time" dashboard to ensure that what the operator sees is a *consistent* and *causally correct* picture of reality, rather than a jittery, out-of-order stream.

---
**Assertion**: This 5-level chronology ensures that Indrajaal maintains a coherent, legally defensible timeline of events even in the presence of network partitions and hardware clock drift.
