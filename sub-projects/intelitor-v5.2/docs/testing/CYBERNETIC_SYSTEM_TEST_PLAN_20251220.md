# CYBERNETIC_SYSTEM_TEST_PLAN_20251220.md

**Version**: 1.0.0
**Date**: 2025-12-20
**Status**: ACTIVE
**Author**: Gemini (Cybernetic Architect)
**Context**: Verification of `docs/architecture/SYSTEM_IMPACT_ANALYSIS_20251220.md`

## 1. Objective
To empirically verify the "Autonomic Organism" properties of the Indrajaal system defined in the System Impact Analysis. We will validate that the system exhibits **Immunity** (Security), **Connectivity** (Nervous System), **Perception** (Observability), and **Homeostasis** (Stability).

## 2. Test Strategy: The "Organism" Checks

We will execute a battery of automated tests targeting the four biological layers of the system.

### 2.1 Layer 1: Immunity Check (Foundation)
**Claim**: The system rejects foreign bodies (Root processes, non-NixOS environments).
*   **Test C1.1**: Verify Podman is running in **Rootless** mode.
*   **Test C1.2**: Verify container images are sourced from **Localhost** (Immunology against supply chain attacks).
*   **Test C1.3**: Verify `indrajaal-db` is running with the correct User UID (non-zero).

### 2.2 Layer 2: Nervous System Check (Connectivity)
**Claim**: Sidecar architecture enables <1ms latency (Synaptic Speed).
*   **Test C2.1**: Measure latency between `indrajaal-app` and `indrajaal-redis` (Localhost loopback).
*   **Test C2.2**: Verify Tailscale DNS resolution (Identity recognition).

### 2.3 Layer 3: Perception Check (Observability)
**Claim**: The system has real-time proprioception (Self-awareness).
*   **Test C3.1**: Verify Prometheus is successfully scraping `indrajaal-app`.
*   **Test C3.2**: Check for active OTLP traces (Signoz connectivity).

### 2.4 Layer 4: Homeostasis Check (Cognition)
**Claim**: The system maintains stability under stress.
*   **Test C4.1**: **Stimulus**: Verify Health Check endpoints are responsive (<200ms).
*   **Test C4.2**: **Response**: Simulate a "Stress" signal (check if Cortex Sensor reports metrics).

## 3. Execution Protocol
*   **Tool**: `scripts/testing/verify_cybernetic_system.exs` (Automated Elixir Script).
*   **Environment**: Level 3 (Demo) or Level 1 (Dev) Container Stack.
*   **Pass Criteria**: 100% of checks must pass. Any failure indicates a "Pathology" in the organism.

## 4. Recovery
If tests fail, the "Immune System" (Validation Framework) will trigger a diagnostic report.
