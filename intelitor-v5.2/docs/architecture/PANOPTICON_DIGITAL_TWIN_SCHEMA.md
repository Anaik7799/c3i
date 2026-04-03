# Panopticon Digital Twin: Technical Schema
**Version**: 5.0.0
**Role**: Deterministic State Capture for SIL6 Forensics

## 1.0 State Components

### 1.1 The Control Vector (SQLite)
*   `test_id`: UUID
*   `run_mode`: `live | shadow | model`
*   `quorum_status`: `achieved | lost | fault`
*   `active_constraints`: JSON list of SC-* IDs

### 1.2 The Telemetry Vector (DuckDB)
*   `logical_timestamp`: HLC (Hybrid Logical Clock)
*   `fractal_layer`: `L1..L5`
*   `source_node`: `primary | shadow | sim`
*   `payload_hash`: SHA256 of message data
*   `latency_ms`: Response delta from judge

### 1.3 The Evolutionary Marker
*   `git_hash`: Current mutation pointer
*   `req_id`: Linked SRS requirement
*   `fitness_score`: 0.0 - 1.0 (Quality metric)

## 2.0 Causality Chain Logic
The Panopticon uses **Hybrid Logical Clocks (HLC)** to ensure that events across the distributed mesh are ordered correctly, even in the presence of NTP drift. 

### Invariant:
`□ (Event_A -> Event_B) ⟹ (HLC(A) < HLC(B))`
