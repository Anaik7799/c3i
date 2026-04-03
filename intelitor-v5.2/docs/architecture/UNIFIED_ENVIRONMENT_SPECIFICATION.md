# Indrajaal: Unified Environment Lifecycle Specification

**Version**: 1.0.0
**Environments**: Dev | Test | Demo | Prod
**Framework**: ACE (Autonomic Container Ecosystem)

## 1.0 Level 1: Strategic Unified Objective
To eliminate environment drift by using a single **Hardened ACE Image** as the foundation for all 4 application contexts, differentiated only by dynamic cybernetic profile injection.

---

## 2.0 Level 2: Environment Profiles (Architecture)

| Profile | Purpose | Data Persistence | Cybernetic Controls |
| :--- | :--- | :--- | :--- |
| **Dev** | Hot-reload dev | Host bind-mount | PHICS Enabled, `MIX_ENV=dev` |
| **Test** | CI/CD validation | Ephemeral volume | Shield Active, `MIX_ENV=test` |
| **Demo** | Stable showcase | Seeded volume | Shield Active, `MIX_ENV=demo` |
| **Prod** | Real-world ops | Encrypted volume | Hardened Ports (80/443), `MIX_ENV=prod` |

---

## 3.0 Level 3: Setup Governance (AOR)
*   **AOR-ENV-001**: Images MUST be built once and promoted through environments (Test -> Demo -> Prod).
*   **AOR-ENV-002**: Secrets (`SECRET_KEY_BASE`) MUST be injected via the Orchestrator, never baked into the Nix layer.
*   **AOR-ENV-003**: The VTO Loop MUST verify the environment-specific ports before binding.

---

## 4.0 Level 4: Unified Implementation (Mechanisms)
*   **Blueprint**: `containers/sopv51-elixir-app.nix` (v1.1.0 Hardened).
*   **SSoT**: `lib/indrajaal/deployment/config.ex` (Supports `env_profile`).
*   **Guard**: `scripts/containers/vto_orchestrator.exs --env <profile>`.

---

## 5.0 Level 5: Operation User Guide (CLI)

### 5.1 Development Setup
```bash
# Starts with hot-reloading and host-source sync
elixir scripts/containers/vto_orchestrator.exs --env dev
```

### 5.2 Test Environment
```bash
# Starts isolated for CI testing
elixir scripts/containers/vto_orchestrator.exs --env test
```

### 5.3 Demo Launch
```bash
# Standard demo stack
elixir scripts/containers/vto_orchestrator.exs --env demo
```

### 5.4 Production Hardening
```bash
# Standard production stack with port 80/443 mapping
elixir scripts/containers/vto_orchestrator.exs --env prod
```

---

## 6.0 Health & Verification Probes
Each environment launch triggers the **ACE Shield**:
1.  **Port Probe**: Ensures 4000/80 availability.
2.  **ID Mapping**: Adapts UID 1000 dynamically.
3.  **Ready Probe**: Waits for Postgres `pg_isready` before app boot.
