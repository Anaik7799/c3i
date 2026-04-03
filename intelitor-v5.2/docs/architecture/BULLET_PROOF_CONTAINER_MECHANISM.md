# Master Specification: Bullet-Proof Container Mechanism

**Version**: 1.1.0
**Framework**: SOPv5.11 + Cybernetic Physics
**Author**: Cybernetic Architect (Gemini)

## 1.0 Systematic Broad Review

A "Bullet-Proof" system is not just functional; it is **Anti-Fragile**. This analysis identifies the gap between "working" and "resilient."

### 1.1 AS-IS: Fragility Audit
*   **Leakage**: Image builds used host binaries (`rebar3`), causing "it works on my machine" failures.
*   **Incomplete Linkage**: Native Elixir nodes (`mimerl`) failed intermittently because `openssl.dev` headers were missing in the target layer.
*   **Permissions Paradox**: Rootless Podman UID mapping (1000:1000) was brittle across different host user IDs.
*   **Silent Hangs**: The OODA loop was incomplete—it checked if a container *started*, not if the *application logic inside* could reach its dependencies.

---

## 2.0 TO-BE: Bullet-Proof Implementation (The Shield)

### 2.1 Layer 1: Supply Chain Hardening (Supply Guard)
*   **Pinning**: `nixpkgs` is hard-pinned to a specific git revision.
*   **Hermeticity**: `MIX_REBAR3` environment variables force Mix to use internal Nix binaries, ignoring host paths.
*   **Native Completeness**: Injection of `openssl.dev`, `zlib.dev`, and `ncurses.dev` headers.

### 2.2 Layer 2: Trust & Connectivity (Trust Shield)
*   **Standard SSL**: Automatic symlinking of `ca-bundle.crt` to standard `/etc/ssl/certs` paths in the container entrypoint.
*   **Internal Shield Probe**: Entrypoint script now includes a DNS pre-flight (`getent hosts`) to prevent boot hangs.

### 2.3 Layer 3: Cybernetic Orchestration (VTO 2.0)
*   **Dependency Ordering**: Enforced numeric ordering (`dependency_order: 1..N`).
*   **Probe Integration**: The VTO Orchestrator simulates host-to-container connectivity before declaring "Healthy."

---

## 3.0 Operational Processes

### 3.1 The "Build Shield" Process
1.  **Codebase Refresh**: Ensure `mix.lock` is current.
2.  **Derivation Build**: Run `parallel_build_agent.exs`.
3.  **Atomic Swap**: Re-tag `localhost/indrajaal-app-hardened:latest` ONLY after successful validation.

### 3.2 The "VTO Shield" Process
1.  **Observe**: Check image integrity via `podman inspect`.
2.  **Orient**: Parse `Indrajaal.Deployment.Config` for the current environment.
3.  **Decide**: If `Demo`, enable `VTO_SHIELD_ENABLED=true`.
4.  **Act**: Start containers. Use `vto_orchestrator.exs` to manage Jidoka (halt on failure).

---

## 4.0 Compliance & Safety (STAMP)

| Constraint | Category | Bullet-Proof Metric |
| :--- | :--- | :--- |
| **SC-CNT-009** | Infrastructure | 100% NixOS based. |
| **SC-SEC-042** | Security | 0 Secrets in layers; all via runtime injection. |
| **SC-PRV-001** | Privileges | Read-only rootfs + Non-root internal UID (1000). |
| **SC-LIV-001** | Liveness | Probe success required before `healthy` status. |

---

## 5.0 Maintenance & Kaizen
*   **Weekly Audit**: Review `nixpkgs` security notices.
*   **Log Analysis**: Monitor `startup_failure.log` for recurring dependency race conditions.
*   **Performance**: Track build time; target < 120s for hardened layer rebuilds.
