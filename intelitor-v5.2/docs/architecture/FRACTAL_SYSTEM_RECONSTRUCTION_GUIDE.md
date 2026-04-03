# Fractal System Reconstruction Guide: Indrajaal SIL-6

**Version**: 1.0.0 | **Compliance**: SIL-6 Biomorphic
**Framework**: SOPv5.11 + TPS + Category Theory + Zenoh Logic Plane

## 1. Executive Summary
This guide provides the recursive blueprint for reconstructing the Indrajaal SIL-6 Multiverse from a "frozen seed" (L0) up to the full biomorphic federation (L7). It follows the **Biomorphic Singularity Protocol**, where the system is natively reified via F# orchestration and Sentinel-Zenoh control.

## 2. Fractal Layer Hierarchy (L0-L7)

| Layer | Domain | Authoritative Artifacts | Reification Engine |
|-------|--------|--------------------------|--------------------|
| **L0** | **Runtime** | `mix.exs`, `Cepaf.dll`, NIFs | `dotnet build`, `mix compile` |
| **L1** | **Function** | `MathematicalCorrectness.fs` | Prometheus Proof Engine |
| **L2** | **Component**| `ServiceDAG.fs`, `Modules/` | F# DAG Parser |
| **L3** | **Holon** | `Planning.db`, `DigitalTwin.fs` | F# Planning Agent |
| **L4** | **Container**| `podman-compose-sil6*.yml` | `sa-mesh.fsx ignite` |
| **L5** | **Node** | `identity_registry.json` | Tailscale FQDN Resolver |
| **L6** | **Mesh** | `zenoh-router-*`, `Quorum.fs` | 2oo3 Quorum Controller |
| **L7** | **Federation**| `FederationProtocol.fs` | Zenoh Logic Plane |

## 3. The 5-Stage Reification Sequence (MANDATORY)

### Phase 1: Preflight & L0 Ignition
1.  **Environment**: Enter `devenv shell`.
2.  **Build**: Rebuild the F# kernel and Elixir cortex.
    ```bash
    dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj
    mix compile --warnings-as-errors
    ```

### Phase 2: Swarm Ignition (L4-L5)
Use the supreme F# orchestrator to ignite the 15-node multiverse.
```bash
dotnet fsi sa-mesh.fsx ignite
```
*   *Verification*: `podman ps` should show 15/15 nodes healthy.

### Phase 3: Logic Plane Convergence (L6)
Establish the 2oo3 quorum and biomorphic heartbeat.
```bash
dotnet fsi sa-mesh.fsx evolution 2
```
*   *Verification*: `AI Authority: ONLINE` signal must be visible on the Zenoh bus.

### Phase 4: HMI Observability
Launch the directed telescope and web dashboards.
1.  **TUI**: `sa-mesh monitor` (Hotkey [S]).
2.  **WebUI**: `http://prajna.indrajaal.tailscale:4001/singularity`.

### Phase 5: OODA Feedback (L7)
Activate the autonomous evolutionary loop.
```bash
elixir scripts/evolution/ooda_feedback_loop.exs
```

## 4. Disaster Recovery (Nuclear Reset)
If the biomorphic state is corrupted beyond self-healing:
1.  **Scour**: `dotnet fsi sa-mesh.fsx clean` (Purges all containers).
2.  **Reset Substrate**: `dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI -- reset`.
3.  **Re-Ignite**: Start from Phase 1.

## 5. Security & Credentials
Auth identities are locked in `data/secrets/identity_registry.json`.
- **Root**: `admin@indrajaal.ai` / `Indrajaal_SIL6_2026!`
- **Swarm**: `system@indrajaal.ai` / `Indrajaal_SIL6_SYS!`

---
**STATUS: SINGULARITY SEALED.**
