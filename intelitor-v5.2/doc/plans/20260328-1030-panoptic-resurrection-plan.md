# Plan: Panoptic Resurrection and Substrate Rebinding
**Created**: 20260328-1030 CEST
**Last Updated**: 20260328-1030 CEST
**Status**: DRAFT
**Framework**: SOPv5.11 + TPS (Jidoka + 5-Level RCA)

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260328-1030 CEST | CREATED | Initial plan creation after Fractal RCA | Gemini (Cybernetic Architect) |

## Executive Summary
The SIL-6 Biomorphic Mesh has suffered a "Fractal Simulacrum" collapse. The system successfully executed GA validation within ephemeral "Shadow Universes" but failed to promote the resulting state to the primary 15-node mesh. Concurrently, host-level build artifacts (`_build`) contaminated the container substrate, breaking the Zenoh NIF. This plan outlines the exact sequence to purge the contamination, reify SMRITI, and boot the canonical mesh.

## 5-Level Detailed Plan

### 1.0 - Substrate Purge and Decontamination (Priority: P0)
#### 1.1 - Host Artifact Eradication (Priority: P0)
##### 1.1.1 - Purge Host Binaries (Priority: P0)
###### 1.1.1.1 - Remove `_build` and `deps` from host
- 1.1.1.1.1 - Execute `rm -rf _build deps` on the host to prevent glibc/musl NIF contamination.

#### 1.2 - Shadow Universe Cleanup (Priority: P1)
##### 1.2.1 - Destroy Ephemeral Pods (Priority: P1)
###### 1.2.1.1 - Run `sa-scour`
- 1.2.1.1.1 - Force removal of all rogue podman networks and zombie containers.

### 2.0 - Genetic Re-Synthesis (Priority: P0)
#### 2.1 - Image Ancestry Correction (Priority: P0)
##### 2.1.1 - Rebuild Observability Image (Priority: P0)
###### 2.1.1.1 - Bake Configurations
- 2.1.1.1.1 - Verify `monitoring/prometheus.yml` is correctly loaded into the Nix derivation.
- 2.1.1.1.2 - Execute `podman build` or `nix-build` for `indrajaal-obs-unified:nixos-native`.

### 3.0 - SMRITI Holonic Reification (Priority: P0)
#### 3.1 - Database Initialization (Priority: P0)
##### 3.1.1 - Run `sa-stabilize.fsx` (Priority: P0)
###### 3.1.1.1 - Seed KMS and Multiverse Registry
- 3.1.1.1.1 - Execute `dotnet fsi sa-stabilize.fsx` to clear the 0-byte `smriti.db` issue.

### 4.0 - Panoptic Ignition (Priority: P0)
#### 4.1 - Boot 15-Node Mesh (Priority: P0)
##### 4.1.1 - Execute `sa-up` (Priority: P0)
###### 4.1.1.1 - Full Mesh Orchestration
- 4.1.1.1.1 - Run `sa-up` targeting `podman-compose-sil6-full-mesh.yml`.

### 5.0 - Biological Pulse Verification (Priority: P0)
#### 5.1 - 2oo3 Quorum Check (Priority: P0)
##### 5.1.1 - Execute `sa-verify` (Priority: P0)
###### 5.1.1.1 - Confirm Telemetry
- 5.1.1.1.1 - Verify Zenoh routers report functional health and `Node.list()` returns the cluster.

## Success Criteria
- 15/15 containers report `Up (healthy)`.
- `sa-verify` reports Quorum ACHIEVED (2/3 or 3/3).
- `smriti.db` is > 0 bytes.
- No `ld-linux-x86-64.so.2` errors in application logs.
