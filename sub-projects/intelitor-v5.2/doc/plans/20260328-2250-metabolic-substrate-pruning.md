# Plan: Metabolic Substrate Pruning

**Created**: 20260328-2250 CEST
**Status**: ACTIVE
**Framework**: SOPv5.11 + STAMP + Metabolic Maintenance

## Executive Summary
This plan details the implementation of a high-assurance "Metabolic Pruning" system within the F# CEPAF kernel. The goal is to safely reclaim ~515GB of orphaned Podman overlay layers that are no longer tracked by the engine but consume physical substrate space.

## 5.0 Substrate Maintenance & Metabolic Pruning (Priority: P0)

### 5.1 Metabolic Analysis Engine (L5 Node Metabolism)
- **Scan**: Recursively scan `/home/an/.local/share/containers/storage/overlay`.
- **Metrics**: Aggregate size, inode count, and timestamps per layer.
- **Reporting**: Publish initial metabolic state to `indrajaal/metabolism/storage/status` via Zenoh.

### 5.2 Active Layer Verification (L4 Container Substrate)
- **Ground Truth**: Exhaustively query Podman API for all `UpperDir` and `LowerDir` paths from all images/containers.
- **Consensus**: Perform set-difference (`Set Physical - Set Logical`) to identify candidate orphans.
- **Control Check**: Verification that no "Starting" or "In-Morphogenesis" containers are pruned.

### 5.3 Differential Verification & Orphan RCA
- **Exhaustive Re-Check**: For each orphan, perform secondary validation against the Podman metadata blob.
- **RCA Tracker**: Determine *why* the directory became an orphan (e.g., interrupted build wave, failed push).
- **Audit Log**: Maintain persistent history of orphans in `data/metabolism/orphan_history.db`.

### 5.4 Unified Interface (CLI, MCP, Zenoh)
- **CLI**: `sa-mesh prune --metabolic [--dry-run]`
- **MCP**: Tool `swarm_metabolic_prune` for supervisor agent invocation.
- **Zenoh**: Subscribe to `indrajaal/metabolism/prune/request` for remote activation.

### 5.5 Human-in-the-Loop Safety Gate
- **Report**: Display RPN, reclaimable space, and BLAKE3 hash of the deletion set.
- **Verification**: Require explicit human confirmation (e.g., `--confirm-metabolic-prune <HASH>`) before deletion.
- **Transactional Prune**: Atomic removal with detailed audit logging to `docs/journal/` and Immutable Register update.

## 6.0 Implementation Plan

*   **Step 1 (Critical)**: Implement `MetabolicPruner.fs` with set-difference logic.
*   **Step 2 (Critical)**: Implement RCA tracking for orphans (identifying interrupted build waves).
*   **Step 3 (High)**: Integrate Zenoh/MCP/CLI entry points.
*   **Step 4 (Medium)**: Implement the BLAKE3-based Human-in-the-Loop safety gate.

## 7.0 Success Criteria
- Substrate reclaimed by safe removal of verified orphans (Target: ~515GB).
- Persistent audit log of all pruning operations and orphan RCAs.
- Zero impact on active or starting containers.
