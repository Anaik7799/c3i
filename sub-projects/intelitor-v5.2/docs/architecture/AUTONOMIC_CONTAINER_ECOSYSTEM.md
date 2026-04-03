# Indrajaal Autonomic Container Ecosystem (ACE) - Master Specification

**Version**: 2.0.0
**Status**: OPERATIONAL
**Cybernetic Framework**: SOPv5.11 + VTO + Jidoka + PHICS

## 1.0 Strategic Vision: Autonomic Infrastructure (Level 1)
To establish a self-governing, anti-fragile infrastructure layer where the application container lifecycle is managed by cybernetic feedback loops, ensuring 100% environment fidelity and zero-touch reliability across Dev, Demo, and Production.

---

## 2.0 System Architecture: The Cybernetic Shield (Level 2)

### 2.1 The Supply Chain Guard (Layer 1)
*   **Mechanism**: Pinned Nixpkgs + fat toolchain.
*   **Physics**: Hermetic derivation (`sopv51-elixir-app.nix`) eliminates host-leakage entropy.

### 2.2 The VTO OODA Loop (Layer 2)
*   **Observe**: Internal probes verify image integrity and DNS.
*   **Orient**: State alignment with `Indrajaal.Deployment.Config`.
*   **Decide**: Autonomic strategy selection (PHICS for Dev, Shield for Demo).
*   **Act**: Jidoka-protected launch sequence.

### 2.3 PHICS Synchronization (Layer 3)
*   **Mechanism**: Phoenix Hot-Reloading Integration Container System.
*   **Goal**: <50ms hot-reload latency while maintaining container isolation.

---

## 3.0 Agent Operating Rules (AOR) & Safety (Level 3)

### 3.1 AOR-CNT (Container Rules)
1.  **AOR-CNT-001**: Agents MUST NOT run `podman run` manually; all launches must pass through `vto_orchestrator.exs`.
2.  **AOR-CNT-002**: Agents MUST refresh the Nix derivation if `mix.lock` or native headers change.
3.  **AOR-CNT-003**: Agents MUST verify health status via internal probes before declaring a task In