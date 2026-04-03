# Specification: Application Container Lifecycle (5-Level)

**Version**: 1.0.0
**Classification**: INFRASTRUCTURE-SSOT
**Framework**: SOPv5.11 + TPS (Jidoka)

## 1.0 Strategic Objective: Robust Hardened Container Ecosystem (Level 1)
Establish a zero-defect, hermetically sealed, and cybernetically managed application container lifecycle that guarantees 100% compilation success and runtime stability across all environments (Dev, Demo, Prod).

---

## 2.0 Major Milestones & Task Groups (Levels 2 & 3)

### 2.1 Milestone: Hardened Image Construction (Level 2)
#### 2.1.1 Task Group: Nix Derivation Engineering (Level 3)
*   **Objective**: Define a reproducible "Fat" runtime image.
*   **Mechanism**: `containers/sopv51-elixir-app.nix`.

#### 2.1.2 Task Group: Toolchain & Dependency Hardening (Level 3)
*   **Objective**: Inject C-compilation tools and explicit package managers.
*   **Items**: `gcc`, `gnumake`, `rebar3`, `binutils`.

### 2.2 Milestone: Runtime Orchestration (VTO) (Level 2)
#### 2.2.1 Task Group: OODA Loop Enforcement (Level 3)
*   **Objective**: Use the Verify-Then-Orchestrate pattern for all launches.
*   **Mechanism**: `scripts/containers/vto_orchestrator.exs`.

#### 2.2.2 Task Group: SSL/TLS Trust Establishment (Level 3)
*   **Objective**: Guarantee CA certificate availability at runtime.
*   **Mechanism**: Entrypoint symlinking.

---

## 3.0 Detailed Implementation & Micro-tasks (Levels 4 & 5)

### 3.1 Construction Phase (Level 4)
*   **3.1.1 Define Nix Derivation (Step 5)**: 
    *   Set `MIX_REBAR3` env var to Nix path.
    *   Include `cacert` in `contents`.
*   **3.1.2 Execute Parallel Build (Step 5)**:
    *   Run `elixir parallel_build_agent.exs --target app`.
    *   Verify layer caching success.

### 3.2 Verification Phase (Level 4)
*   **3.2.1 Structural Analysis (Step 5)**:
    *   `podman run --rm app gcc --version` (Checks toolchain).
    *   `podman run --rm app ls /etc/ssl/certs/ca-certificates.crt` (Checks SSL).
*   **3.2.2 Compilation Test (Step 5)**:
    *   Run `mix compile` inside the container context to verify C-extensions.

### 3.3 Orchestration Phase (Level 4)
*   **3.3.1 Load Deployment SSoT (Step 5)**:
    *   Extract port mappings and volumes from `Indrajaal.Deployment.Config`.
*   **3.3.2 Launch Stack (Step 5)**:
    *   Execute `vto_orchestrator.exs --action start`.
    *   Monitor health checks (Wait for status `healthy`).

---

## 4.0 Identification of Key Items

### 4.1 Build-Time Artifacts
| Item | Role | File Path |
| :--- | :--- | :--- |
| **Derivation** | Image Blueprint | `containers/sopv51-elixir-app.nix` |
| **Build Script** | Orchestrator | `scripts/containers/parallel_build_agent.exs` |
| **Mix Config** | Local Registry | `.local-registry/` |

### 4.2 Runtime Artifacts
| Item | Role | File Path |
| :--- | :--- | :--- |
| **SSoT** | Config Source | `lib/indrajaal/deployment/config.ex` |
| **Runtime** | Dynamic Config | `config/runtime.exs` |
| **VTO Script** | Launch Guard | `scripts/containers/vto_orchestrator.exs` |

---

## 5.0 Maintenance & Compliance (STAMP)

### 5.1 Safety Constraints
*   **SC-CNT-009**: All app logic MUST run in NixOS-based containers.
*   **SC-CNT-VTO**: Manual `podman run` is FORBIDDEN for production flows.
*   **SC-SEC-042**: `SECRET_KEY_BASE` MUST NOT be baked into images.

### 5.2 Jidoka (Self-Healing)
If the health check fails after 30 retries, the orchestrator triggers:
1.  `podman logs` dump to `data/tmp/startup_failure.log`.
2.  Automatic `down` of dependencies.
3.  Exit with code 1.
