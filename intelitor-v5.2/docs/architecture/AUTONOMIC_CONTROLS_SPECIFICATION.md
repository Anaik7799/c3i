# Specification: Autonomic Infrastructure Controls

**Version**: 1.0.0
**Framework**: ACE (Autonomic Container Ecosystem)
**Status**: ACTIVE

## 1.0 Control: Port Collision Shield
*   **Brittleness**: Blindly attempting to bind ports (5433, 4000) leading to silent container crashes.
*   **Mechanism**: `check_port_collisions/1` in `vto_orchestrator.exs`.
*   **Physics**: Uses `nc -z` to probe host ports before `podman run`. Halts execution (Jidoka) if collision detected.

## 2.0 Control: Service-Ready Probe (Postgres)
*   **Brittleness**: App booting before Database internal initialization is complete.
*   **Mechanism**: `wait_for_postgres/1` loop.
*   **Physics**: Polls `pg_isready` inside the container bridge network. Max 10 retries with 2s jitter.

## 3.0 Control: Dynamic Identity Adaptation
*   **Brittleness**: Permissions drift across multi-user host systems (UID mismatch).
*   **Mechanism**: Entrypoint `CURRENT_UID` detection in `sopv51-elixir-app.nix`.
*   **Physics**: Dynamically aligns internal developer user context with host runtime identity.

## 4.0 Control: Supply Chain Pinning
*   **Brittleness**: Upstream `nixpkgs` rolling updates breaking BEAM/OTP versions.
*   **Mechanism**: Hard-coded `nixpkgsRev` in derivation.
*   **Physics**: Guarantees 100% build reproducibility across all build nodes.

---

## 5.0 Safety (STAMP) Constraints
*   **SC-ACE-PROBE**: All services MUST have a 'ready' probe defined in the VTO loop.
*   **SC-ACE-ID**: Container rootfs MUST be mountable by host UID 1000 without manual chown.
