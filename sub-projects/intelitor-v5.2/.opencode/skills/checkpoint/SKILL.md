---
name: checkpoint
description: Unified checkpoint and multiverse management — capture, verify, fork, promote via MCP
---
---

# Checkpoint & Multiverse Control (SC-UCR-001 to SC-UCR-015)

Unified state management: checkpoints capture system state, multiverse forks isolated shadow universes.

## Usage
```
/checkpoint capture              # Full 4-phase checkpoint
/checkpoint quick                # Quick checkpoint (file+git only)
/checkpoint verify               # Verify checkpoint integrity
/checkpoint fork experiment-1    # Fork shadow universe
/checkpoint promote experiment-1 # Promote shadow to production
/checkpoint prune old-universe   # Remove shadow universe
/checkpoint list                 # List all universes
```

## Checkpoint Commands (SC-UCR-001)

### Full Capture (4-Phase Architecture)
`checkpoint_op(action: "full")` — Captures ALL 7 state locations:
1. **Phase 1**: FileSystem + KMS + Git state
2. **Phase 2**: Container state (CRIU if available)
3. **Phase 3**: Zenoh mesh state (Chandy-Lamport snapshot)
4. **Phase 4**: Multiverse verification (46 tests)

### Quick Capture
`checkpoint_op(action: "quick")` — Phase 1 only (fast, <10s)

### Verify
`checkpoint_op(action: "verify", archive_path: "/path/to/archive")`
- Constitutional verification (L8)
- FPPS 5-method consensus
- Hash chain integrity

## 7 State Locations (SC-UCR-012)
| Location | Content | Phase |
|----------|---------|-------|
| FileSystem | Source code, configs | 1 |
| KMS | Keys, certificates | 1 |
| Git | Commits, branches, tags | 1 |
| Container | Running state (CRIU) | 2 |
| Volume | Persistent data | 2 |
| Zenoh | Mesh state, subscriptions | 3 |
| DuckDB | Evolution history | 3 |

## Multiverse Commands (SC-UCR-011)

### Fork Shadow Universe
`multiverse_op(action: "fork", name: "experiment-1")`
- Creates isolated container instances
- No impact on production state
- Requires Guardian approval (SC-UCR-011)

### Verify Universe
`multiverse_op(action: "verify", name: "experiment-1")`
- Run 46-test verification suite
- Constitutional invariant check
- State integrity validation

### Promote Universe
`multiverse_op(action: "promote", name: "experiment-1")`
- Replace production with shadow state
- Requires full verification first
- Rollback path preserved

### Prune Universe
`multiverse_op(action: "prune", name: "old-universe")`
- Remove shadow universe and reclaim resources

### List Universes
`multiverse_op(action: "list")`
- Show all universes (production + shadows)
- Health status per universe
- Creation timestamp and origin checkpoint

## Workflow: Safe Deployment
1. Create checkpoint: `checkpoint_op(action: "full")`
2. Fork shadow: `multiverse_op(action: "fork", name: "deploy-test")`
3. Deploy to shadow (make changes in isolated universe)
4. Verify shadow: `multiverse_op(action: "verify", name: "deploy-test")`
5. Check health: `sentinel(action: "health")`
6. If healthy → Promote: `multiverse_op(action: "promote", name: "deploy-test")`
7. If unhealthy → Prune: `multiverse_op(action: "prune", name: "deploy-test")`

## Mathematical Foundation

**Chandy-Lamport Consistent Cut**: $C = (\{s_i\}, \{c_{ij}\})$ where $\forall m: send(m) \in C \iff recv(m) \in C$

**Global Snapshot**: $S_g = \{s_1, s_2, ..., s_n, c_{12}, c_{13}, ..., c_{(n-1)n}\}$

**State Space**: $|S| = \prod_{i=1}^{n} |S_i| \times \prod_{(i,j)} |C_{ij}|$

**Checkpoint Integrity**: $H(checkpoint) = SHA3(content \| prev\_hash)$ — hash chain

**Recovery Time**: $T_{recover} = T_{load} + T_{verify} + T_{replay} < 100ms$ (SC-BIO-EXT-003)

## STAMP Constraints
| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-UCR-001 | 4-phase architecture | checkpoint_op |
| SC-UCR-011 | Guardian approval for fork | multiverse_op |
| SC-UCR-012 | All 7 state locations captured | full checkpoint |
| SC-UCR-015 | Rollback path MUST exist | verify before promote |
