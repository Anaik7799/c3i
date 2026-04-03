# Indrajaal ACE: Omni-Specification & Master Manual

**Version**: 2.3.0 (Enterprise-Resilient)
**Governance**: Autonomic Cybernetic Ecosystem (ACE)
**Safety**: SIL-2 Compliant (Design-for-Safety)

## 1.0 Level 1: Omni-Objective (The Prime Directive)
To provide a self-healing, zero-entropy, and hermetically sealed application infrastructure where the lifecycle (Build -> Verify -> Launch -> Monitor) is fully autonomic, eliminating 100% of manual configuration risks.

---

## 2.0 Level 2: Cybernetic Layers (The Anatomy)

### 2.1 Layer 1: Supply Guard (Pinned Construction)
*   **Artifact**: `containers/sopv51-elixir-app.nix`
*   **Hardening**: Pinned Nixpkgs, Native Headers (OpenSSL/Zlib), and Fat Toolchain.

### 2.2 Layer 2: Trust Guard (Setup Hardening)
*   **Mechanism**: Root-to-User Transition + Standard Cert Symlinking.
*   **Hardening**: `setpriv` execution + PATH/LD_LIBRARY_PATH sealing.

### 2.3 Layer 3: OODA Guard (Pre-flight Probing)
*   **Mechanism**: Port Probes, Image Checksums, and Dependency Ready-loops.

### 2.4 Layer 4: ACE GUARD (Live Self-Healing)
*   **Mechanism**: Post-launch health-monitoring loop in `vto_orchestrator.exs`.

---

## 3.0 Level 3: Governance & Security (AOR / STAMP)

### 3.1 Security Hardening (STAMP-SEC)
*   **SC-SEC-001**: Images MUST NOT include debugging shells in Prod (handled by dynamic profile).
*   **SC-SEC-002**: All filesystem writes MUST be limited to `/workspace/data` and `/workspace/logs`.

### 3.2 Operating Rules (AOR-ACE)
1.  **Re-Certification**: Any change to `mix.exs` triggers an autonomic re-build.
2.  **Telemetry**: All ACE state changes MUST be logged to `data/tmp/ace_audit.log`.

---

## 4.0 Level 4: Implementation Registry (Artifacts)

| Item | Context | Role |
| :--- | :--- | :--- |
| **ACE-BLUEPRINT** | Build | `containers/sopv51-elixir-app.nix` |
| **ACE-SSOT** | Config | `lib/indrajaal/deployment/config.ex` |
| **ACE-GUARD** | Runtime | `scripts/containers/vto_orchestrator.exs` |
| **ACE-TEST** | Compliance | `scripts/containers/tdg_container_compliance_tests.exs` |

---

## 5.0 Level 5: Operation & Disaster Recovery (User Guide)

### 5.1 One-Button Launch
```bash
# Standard Autonomic Start
elixir scripts/containers/vto_orchestrator.exs --env demo
```

### 5.2 Disaster Recovery (Autonomic Reset)
If the ACE GUARD reports a critical failure:
1.  **Purge**: `podman rm -f $(podman ps -aq)`
2.  **Clear Locks**: `rm -rf /nix/var/nix/db/big-lock`
3.  **Re-Certified Build**: `elixir scripts/containers/parallel_build_agent.exs --target app`

---

## 6.0 Maintenance & Kaizen
*   **Audit Frequency**: Monthly Trace-level deep builds.
*   **Entropy Check**: Real-time monitoring of `/workspace/data` growth.
