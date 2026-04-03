# Indrajaal Artifact State Specification: Level-5 Resolution

**Compliance**: SIL-6 Biomorphic (Deterministic Control)
**Tracking Mode**: REST API (Podman/Zenoh)
**State Model**: Biomorphic Genome-Phenome Mapping

## 1. Data Flow & Control Flow
1. **Genotype Definition**: Static F# records define the "Map."
2. **REST Observation**: Supervisor calls `http://localhost:8080/v4.0.0/libpod/containers/json` to fetch the "Territory."
3. **Atomic Comparison**: Every port binding and capability is cross-referenced (L4 Pass).
4. **Entropy Calculation**: Divergence scores are updated based on delta counts.
5. **Jidoka Halt**: If any L5 Atomic state (e.g., Proof Token) is invalid, the mesh wave halts immediately.

## 2. Holon State Attributes (Micro-Pass)
### L4: Network Organelle
- **Socket Invariants**: Verify host-to-container port translation.
- **Route Integrity**: Verify if the bridge IP matches the signed mesh map.

### L4: Storage Organelle
- **Volume Hash**: Compare host path signature against the "Genotype" hash to prevent unauthorized mount-points.

### L5: Atomic State
- **Proof Signature**: Every `NodeTwin` transition is cryptographically signed using the KMS key.
- **Pulse Metrics**: Tracks `Jitter` in CPU and IO responses to predict "Thundering Herd" connection storms.

## 3. Configuration Management
- **Verification**: Changes are made via `REST API` calls only. Command-line interactions are logged but considered "Secondary" source.
- **Persistence**: Final system state is committed to `cepa-state.db` after each transaction wave.
