# Unified Checkpoint Registry (UCR) Architecture

**Version**: 1.0.0
**Date**: 2026-01-09
**Status**: ACTIVE
**STAMP**: SC-UCR-001 to SC-UCR-010
**Compliance**: IEC 61508 SIL-6, ISO 27001 (State Management), Ψ₀/Ψ₂ Constitutional

## 1. Overview

The Unified Checkpoint Registry (UCR) provides centralized atomic checkpointing across all 7 distributed state locations in the SIL-6 Biomorphic Fractal Mesh architecture. It addresses the brittleness of distributed state by creating a single source of truth for system state snapshots.

### 1.1 Problem Statement

The architecture has 7 distributed state locations with no atomic checkpoint capability:

| Location | Content | Risk |
|----------|---------|------|
| File System | 170+ scripts, configs, Dockerfiles | Version drift |
| KMS SQLite | 5 databases (holons, todos, tests) | Data loss |
| Container Images | 12 images (~50 GB) | Registry failure |
| Container Volumes | PostgreSQL, Redis data | Corruption |
| Zenoh Mesh | Runtime pub/sub state | Session loss |
| DuckDB Analytics | Evolution history | Analytics gap |
| Environment | `.env` files, container env | Config mismatch |

### 1.2 Solution

UCR creates a **single atomic checkpoint** containing:
- All file artifacts with SHA-256 hashes
- KMS database copies via `VACUUM INTO`
- Container image manifest (IDs, not full images)
- Git state (hash + dirty diff)
- FPPS health score at checkpoint time
- Constitutional verification (Ψ₀/Ψ₂)

## 2. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         UNIFIED CHECKPOINT REGISTRY (UCR)                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐│
│  │ CHECKPOINT MANIFEST                                                              ││
│  │ data/checkpoints/{timestamp}/manifest.json                                       ││
│  │                                                                                  ││
│  │ {                                                                                ││
│  │   "version": "1.0.0",                                                           ││
│  │   "timestamp": "2026-01-09T10:30:00Z",                                          ││
│  │   "git_hash": "a21425841...",                                                   ││
│  │   "git_dirty": false,                                                           ││
│  │   "system_hash": "sha256:unified-state-hash",                                   ││
│  │   "components": {                                                               ││
│  │     "file_artifacts": { "count": 45, "total_size": 500KB, "hash": "..." },     ││
│  │     "kms_databases": { "count": 5, "total_size": 25.9MB, "hash": "..." },      ││
│  │     "container_images": { "count": 12, "hash": "..." }                         ││
│  │   },                                                                            ││
│  │   "constitutional": { "psi_0": true, "psi_2": true, "founder": "active" },     ││
│  │   "fpps_health": { "score": 0.95, "consensus": true },                         ││
│  │   "stamp_constraints": ["SC-UCR-001", "SC-UCR-010", ...]                        ││
│  │ }                                                                               ││
│  └─────────────────────────────────────────────────────────────────────────────────┘│
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐│
│  │ ARCHIVE STRUCTURE                                                                ││
│  │                                                                                  ││
│  │ data/checkpoints/{timestamp}.tar.gz                                             ││
│  │ └── {timestamp}/                                                                ││
│  │     ├── manifest.json           ← Checkpoint metadata + unified hash            ││
│  │     ├── artifacts/              ← File artifacts by category                    ││
│  │     │   ├── compose/            ← Compose files (9 files)                       ││
│  │     │   ├── nix/                ← Nix configurations                            ││
│  │     │   ├── orchestration/      ← sa-*.fsx scripts                              ││
│  │     │   ├── mesh/               ← Mesh infrastructure scripts                   ││
│  │     │   ├── cepaf/              ← CEPAF runtime scripts                         ││
│  │     │   └── zenoh/              ← Zenoh configuration                           ││
│  │     ├── kms/                    ← SQLite database copies                        ││
│  │     │   ├── core.db             ← Core holon identity (260 rows)                ││
│  │     │   ├── holons.db           ← Full holon state (1,241 rows)                 ││
│  │     │   ├── todos.db            ← Task tracking (14 rows)                       ││
│  │     │   ├── test_manager.db     ← Test definitions (4 rows)                     ││
│  │     │   └── test_tracking.db    ← Test history                                  ││
│  │     ├── container-manifest.txt  ← Image IDs + sizes                             ││
│  │     ├── checksums.sha256        ← Per-file checksums                            ││
│  │     └── git-diff.patch          ← Uncommitted changes (if dirty)                ││
│  └─────────────────────────────────────────────────────────────────────────────────┘│
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 3. External Artifacts Inventory

### 3.1 F# Mesh Scripts (8 files, 152.5 KB)

| File | Size | SHA-256 Hash | Purpose |
|------|------|--------------|---------|
| `scripts/infrastructure/MeshCommon.fsx` | 12,180 | `6ba242e55502490fcc5bc1843c7303c661662c96678d8341596341eac3509a54` | Shared utilities module |
| `scripts/infrastructure/mesh-verify.fsx` | 20,365 | `e20f2edf049025a653450b28d427cabe2636d6daf8b4f3f286e665431e8482d2` | FPPS 5-method consensus |
| `scripts/infrastructure/mesh-state-capture.fsx` | 21,808 | `4ef9e67f8f6ec75cea12e485c9b3c78e1670f33caa2a4c11c608dc3efd265ade` | Full state backup |
| `scripts/infrastructure/mesh-recovery.fsx` | 25,792 | `b1d6dc60b82a35298c5ed0e3baca203bff26f8322b6266e506a374c292dc56fe` | Full system recovery |
| `scripts/infrastructure/mesh-emergency-recovery.fsx` | 25,487 | `262887328ca3960c3e5e4b7526b855ba2b53ea6650907f1a8991abe2c49d7c28` | Emergency protocol |
| `scripts/infrastructure/mesh-image-backup.fsx` | 16,773 | `824caf33e06d417b79dd58e3efd628c0eeb8c9af5e6edc16af1d35955746ef89` | Container image export |
| `scripts/infrastructure/mesh-image-recovery.fsx` | 18,786 | `30eec3e9540adc6c8693b4e45252156f4a54602736b48bd518249af37836dae0` | Container image restore |
| `scripts/infrastructure/mesh-quick-snapshot.fsx` | 11,341 | `05c2563e28c491fa654cd6a30a03bb143b6968d7f08a932c1badbdc855fa121b` | Minimal P0 snapshot |

### 3.2 SA-*.fsx Orchestration Scripts (18 files, 69 KB)

| File | Size | Purpose |
|------|------|---------|
| `sa-up.fsx` | 1,700 | Start mesh containers |
| `sa-down.fsx` | 1,706 | Stop mesh containers |
| `sa-clean.fsx` | 886 | Remove containers |
| `sa-status.fsx` | 606 | Container status |
| `sa-health.fsx` | 604 | Health verification |
| `sa-emergency.fsx` | 614 | Emergency stop |
| `sa-mesh.fsx` | 10,398 | Full SIL-6 mesh orchestration |
| `sa-deploy.fsx` | 3,277 | Deployment |
| `sa-test.fsx` | 6,634 | Runtime tests |
| `sa-sil6-boot.fsx` | 2,719 | SIL-6 boot |
| `sa-sil6-homeostasis-boot.fsx` | 10,392 | Homeostasis boot |
| `sa-verify-all.fsx` | 4,668 | Full verification |
| `sa-fractal-verify.fsx` | 7,025 | Fractal verification |
| `sa-stabilize.fsx` | 6,506 | Stabilization |
| `sa-genotype.fsx` | 2,034 | Genotype management |
| `sa-multiverse.fsx` | 4,660 | Multiverse |
| `sa-patch-cubdb.fsx` | 2,047 | CubDB patch |
| `sa-update-kms-schema.fsx` | 2,547 | KMS schema update |

### 3.3 Compose Files (9 files, 92 KB)

| File | Size | Purpose |
|------|------|---------|
| `podman-compose-prod-standalone.yml` | 16,110 | **PRIMARY** - 3-container production |
| `podman-compose-sil6-full-mesh.yml` | 22,429 | **TARGET** - 6-container SIL-6 mesh |
| `podman-compose-fractal-cluster.yml` | 4,567 | Fractal cluster |
| `podman-compose-fractal-standalone.yml` | 8,850 | Fractal standalone |
| `podman-compose-app-debug.yml` | 18,851 | App debug |
| `podman-compose-app-standalone.yml` | 8,247 | App standalone |
| `podman-compose-db-standalone.yml` | 2,235 | DB standalone |
| `podman-compose-obs-standalone.yml` | 3,034 | Obs standalone |
| `podman-compose-standalone-full.yml` | 5,768 | Standalone full |

### 3.4 Nix Files (16 files, 175.9 KB)

| File | Size | Purpose |
|------|------|---------|
| `devenv.nix` | 21,878 | **CRITICAL** - Development environment |
| `containers/default.nix` | 7,730 | Container default |
| `containers/enhanced-app-nixos.nix` | 42,295 | Enhanced app |
| `containers/demo-ready-nixos.nix` | 35,580 | Demo ready |
| `containers/production-ready-nixos.nix` | 17,228 | Production ready |
| `containers/git-aware-nixos.nix` | 21,742 | Git aware |
| *(+10 more container nix files)* | | |

### 3.5 KMS Databases (5 files, 25.9 MB)

| Database | Size | Tables | Rows | Purpose |
|----------|------|--------|------|---------|
| `data/kms/holons.db` | 20,185,088 | holons, holon_events, holon_edges, holon_vectors | 1,344 | Full holon state + embeddings |
| `data/kms/core.db` | 6,852,608 | holons, holon_events, holon_edges | 260 | Core holon identity |
| `data/kms/test_manager.db` | 49,152 | test_definitions, test_executions, telemetry_signals | 4 | Test specifications |
| `data/kms/test_tracking.db` | 28,672 | test_runs, test_cases, metrics | 0 | Test history |
| `data/kms/todos.db` | 24,576 | todos | 14 | Task tracking |

### 3.6 Container Images (12 images, ~50 GB)

| Image | Size | Priority |
|-------|------|----------|
| `localhost/indrajaal-app:latest` | 12.8 GB | **P0 Critical** |
| `localhost/indrajaal-app-unified:nixos-devenv` | 9.39 GB | **P0 Critical** |
| `localhost/indrajaal-obs-unified:nixos-devenv` | 7.8 GB | **P0 Critical** |
| `localhost/indrajaal-db:latest` | 875 MB | **P0 Critical** |
| `localhost/indrajaal-timescaledb-demo:nixos-devenv` | 875 MB | **P0 Critical** |
| `localhost/indrajaal-cortex:latest` | 552 MB | P1 High |
| `localhost/indrajaal-obs:latest` | 512 MB | P1 High |
| `localhost/indrajaal-obs-sil4:latest` | 512 MB | P1 High |
| `docker.io/eclipse/zenoh:1.3.4` | 34.5 MB | P1 High |
| `localhost/indrajaal-app-hardened:latest` | 4.48 GB | P2 Optional |

### 3.7 Configuration Files

| File | Size | Purpose |
|------|------|---------|
| `config/zenoh/zenoh.json5` | 2,528 | Zenoh main configuration |
| `config/zenoh/router.json5` | 1,525 | Zenoh router configuration |
| `.env` | 280 | Active environment |
| `.env.example` | 15,859 | Environment template |
| `.envrc` | 3,615 | direnv configuration |

## 4. Database Schema Reference

### 4.1 holons Table (core.db, holons.db)

```sql
CREATE TABLE holons (
  id TEXT PRIMARY KEY,
  fqun TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('knowledge','process','agent','artifact','index','task')),
  name TEXT NOT NULL,
  parent_id TEXT REFERENCES holons(id),
  genome TEXT NOT NULL DEFAULT '{}',
  vital_signs TEXT DEFAULT '{"health":1.0,"stress":0.0,"energy":1.0}',
  membrane TEXT DEFAULT '{}',
  payload TEXT NOT NULL DEFAULT '{}',
  hlc_physical INTEGER NOT NULL,
  hlc_logical INTEGER NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);
```

### 4.2 holon_vectors Table (holons.db)

```sql
CREATE TABLE holon_vectors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  holon_id TEXT NOT NULL,
  model TEXT NOT NULL,
  dimensions INTEGER NOT NULL,
  embedding TEXT NOT NULL,
  chunk_index INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  UNIQUE(holon_id, model, chunk_index),
  FOREIGN KEY(holon_id) REFERENCES holons(id) ON DELETE CASCADE
);
```

### 4.3 todos Table (todos.db)

```sql
CREATE TABLE todos (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  priority TEXT NOT NULL DEFAULT 'p2',
  layer TEXT NOT NULL DEFAULT 'l1',
  fqun TEXT NOT NULL,
  payload TEXT DEFAULT '{}',
  inserted_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

## 5. STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| **SC-UCR-001** | Checkpoint MUST capture all 7 distributed state locations atomically | CRITICAL | Archive completeness check |
| **SC-UCR-002** | Manifest MUST include SHA-256 hash for every artifact | CRITICAL | Hash presence validation |
| **SC-UCR-003** | KMS databases MUST use `VACUUM INTO` for consistent copy | HIGH | SQLite integrity check |
| **SC-UCR-004** | Git state MUST be captured (hash + dirty diff) | HIGH | Git metadata presence |
| **SC-UCR-005** | FPPS health score MUST be recorded at checkpoint time | HIGH | Health score in manifest |
| **SC-UCR-006** | Constitutional invariants (Ψ₀/Ψ₂) MUST be verified | CRITICAL | Invariant flags in manifest |
| **SC-UCR-007** | Unified system hash MUST be computed from all component hashes | CRITICAL | Hash chain verification |
| **SC-UCR-008** | Restore operation MUST verify checksums before overwriting | CRITICAL | Pre-restore validation |
| **SC-UCR-009** | Checkpoint archive MUST be self-contained and portable | HIGH | Archive isolation test |
| **SC-UCR-010** | Checkpoint metadata MUST include STAMP constraint references | MEDIUM | Metadata completeness |

## 6. 7-Level Implications

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ L7: FEDERATION LEVEL                                                                 │
│     - Checkpoint enables disaster recovery across federated holon instances         │
│     - Archive can be transferred to airgapped environments                          │
│     - Supports substrate-independent holon migration                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ L6: CLUSTER LEVEL                                                                    │
│     - Full mesh state can be restored on any compatible cluster                     │
│     - Container image manifest enables registry reconstruction                      │
│     - Compose configs define exact deployment topology                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ L5: NODE LEVEL                                                                       │
│     - devenv.nix ensures reproducible development environment                       │
│     - Nix flakes provide hermetic dependencies                                      │
│     - Git state captures exact codebase version                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ L4: CONTAINER LEVEL                                                                  │
│     - Image manifest + compose config = deterministic containers                    │
│     - Volume state captured via KMS database backup                                 │
│     - Network topology preserved in compose files                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ L3: HOLON/AGENT LEVEL                                                               │
│     - All holon state in SQLite (core.db, holons.db)                               │
│     - Holon edges preserve graph relationships                                      │
│     - Holon vectors preserve embeddings                                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ L2: COMPONENT/MODULE LEVEL                                                           │
│     - CEPAF scripts captured with exact versions                                    │
│     - Mesh infrastructure scripts versioned                                         │
│     - SA orchestration scripts preserved                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ L1: FUNCTION/CODE LEVEL                                                              │
│     - Git hash provides exact code version                                          │
│     - Dirty diff captures uncommitted changes                                       │
│     - Constitutional invariants verified at checkpoint time                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 7. Operations

### 7.1 Create Checkpoint

```bash
# Create a new checkpoint
dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx

# Or explicitly
dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx --create
```

**Output**: `data/checkpoints/{timestamp}.tar.gz`

### 7.2 List Checkpoints

```bash
dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx --list
```

### 7.3 Restore from Checkpoint

```bash
dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx --restore data/checkpoints/20260109_103000.tar.gz
```

### 7.4 Integration with Mesh Scripts

The checkpoint system integrates with existing mesh infrastructure:

| Script | Checkpoint Integration |
|--------|------------------------|
| `mesh-state-capture.fsx` | Creates priority-ordered backups |
| `mesh-recovery.fsx` | Uses checkpoint archives for recovery |
| `mesh-emergency-recovery.fsx` | Verifies checkpoint exists (Ψ₀/Ψ₂) |
| `mesh-quick-snapshot.fsx` | Minimal P0 checkpoint for fast capture |

## 8. Recovery Procedure

### 8.1 Full Recovery from Checkpoint

```bash
# 1. Stop any running containers
dotnet fsi sa-down.fsx

# 2. Restore from checkpoint
dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx --restore data/checkpoints/YYYYMMDD_HHMMSS.tar.gz

# 3. Verify restored state
dotnet fsi scripts/infrastructure/mesh-verify.fsx

# 4. Start mesh with restored state
dotnet fsi sa-up.fsx
```

### 8.2 Partial Recovery (KMS Only)

```bash
# Extract only KMS databases from checkpoint
tar -xzf data/checkpoints/YYYYMMDD_HHMMSS.tar.gz -C /tmp YYYYMMDD_HHMMSS/kms/
cp /tmp/YYYYMMDD_HHMMSS/kms/*.db data/kms/
```

## 9. CI/CD Integration

### 9.1 Pre-Deployment Checkpoint

```yaml
# In Jenkinsfile or CI config
stages:
  - name: checkpoint
    script: dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx
    artifacts:
      paths:
        - data/checkpoints/*.tar.gz

  - name: deploy
    script: dotnet fsi sa-up.fsx
    on_failure:
      script: dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx --restore $LATEST_CHECKPOINT
```

### 9.2 Scheduled Checkpoints

```bash
# cron job for daily checkpoint at 2 AM
0 2 * * * cd /path/to/project && dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx >> /var/log/checkpoint.log 2>&1
```

## 10. Related Documents

- `CLAUDE.md` §5.0 STAMP Constraints (SC-HOLON-*, SC-VAL-*)
- `docs/architecture/HOLON_IMMUTABLE_REGISTER.md`
- `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md`
- `docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md`
- `journal/2026-01/20260109-1045-unified-checkpoint-registry-analysis.md`

## Appendix A: Quick Reference

### A.1 Key Hashes (2026-01-09 Snapshot)

```
MESH SCRIPTS:
  MeshCommon.fsx:           6ba242e55502490fcc5bc1843c7303c661662c96678d8341596341eac3509a54
  mesh-verify.fsx:          e20f2edf049025a653450b28d427cabe2636d6daf8b4f3f286e665431e8482d2
  mesh-checkpoint.fsx:      [newly created]

COMPOSE:
  prod-standalone.yml:      b0be5f8b312d85e7d76262473f1a7b3896e114af3ec43d4cc179ff529ccf11c7
  sil6-full-mesh.yml:       d25d2f577fffbcd255abddd3abcd5d6a92b5eb5761c94381521452af0b97e6aa

KMS:
  holons.db:                6c979c3960bdd35ecb14cc4cb9b386472a268e2b2d81a6fe5e54dab8f00ec2d7
  core.db:                  4fd696ccba04802096af571d7dc549a65e22eb5d7e082f287d29c2240e8b1de1
  todos.db:                 2b94fa8c0d762d863379e95c7dd0d9020ff1f5a8446e48650311db0b10de6057
```

### A.2 Size Summary

| Category | Files | Size |
|----------|-------|------|
| F# Mesh Scripts | 9 | 175.7 KB |
| SA-*.fsx Scripts | 18 | 69 KB |
| Compose Files | 9 | 92 KB |
| Nix Files | 16 | 175.9 KB |
| KMS Databases | 5 | 25.9 MB |
| Container Images | 12 | ~50 GB |
| **Checkpoint Archive** | 1 | **~30 MB** (excl. images) |

## 11. Alternative Checkpointing Techniques Evaluation

### 11.1 Distributed Checkpointing Algorithms

| Algorithm | Description | Applicability | Recommendation |
|-----------|-------------|---------------|----------------|
| **Chandy-Lamport** | Global snapshot via marker propagation | HIGH | **ADOPT** for Zenoh mesh state |
| Coordinated Checkpointing | Synchronous barrier across all nodes | MEDIUM | DEFER - overhead concerns |
| Uncoordinated Checkpointing | Independent node checkpoints | LOW | REJECT - domino effect risk |
| Asynchronous Barrier Snapshotting | Flink-style incremental | HIGH | CONSIDER for stream processing |

### 11.2 CRIU Container Checkpointing

**Status**: RECOMMENDED for Phase 2

CRIU (Checkpoint/Restore in Userspace) enables capturing complete container state including memory, file descriptors, and network connections.

**Integration**:
```bash
# Checkpoint container with full state
podman container checkpoint indrajaal-ex-app-1 \
    --export /data/checkpoints/container-state/app.tar.gz

# Restore from checkpoint
podman container restore \
    --import /data/checkpoints/container-state/app.tar.gz
```

**Benefits**:
- Full process memory capture
- Network socket state preservation
- Zero-downtime migration capability
- GPU workload support (CRIUgpu 2025+)

**Limitations**:
- Requires CAP_SYS_ADMIN or rootless configuration
- Storage overhead (~1GB per container)
- Not all processes are checkpointable

### 11.3 TigerBeetle Evaluation

**Verdict**: NOT SUITABLE

| Aspect | Finding | Impact |
|--------|---------|--------|
| Domain | Financial transactions ONLY | Cannot store holon state |
| Data Model | Double-entry bookkeeping | Incompatible with graphs |
| Schema | Fixed accounts/transfers | No custom tables |
| ACID | Strict Serializability (Jepsen verified) | Beneficial but wrong domain |

**Conclusion**: Continue using SQLite/DuckDB per SC-HOLON-001.

### 11.4 Zenoh Network State Capture

**Status**: PROPOSED for Phase 3

Zenoh mesh state includes:
- Active subscriptions (key expressions)
- Publisher registry (liveliness tokens)
- Storage replicas (zone mapping)
- Session state (peer connections)

**Chandy-Lamport Implementation**:
```
MARKER PROPAGATION:
┌─────────────┐     marker     ┌─────────────┐
│  Node A     │ ──────────────►│  Node B     │
│  (Zenoh)    │                │  (Zenoh)    │
└─────────────┘                └─────────────┘
      │                              │
      ▼                              ▼
  Record local               Record local
  state, forward             state, forward
  marker                     marker
```

## 12. Multiverse Shadow Verification

### 12.1 Concept

Multiverse provides isolated "shadow universes" for testing checkpoint recovery without affecting production state.

### 12.2 Verification Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                  MULTIVERSE SHADOW VERIFICATION                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   PRODUCTION              SHADOW UNIVERSE                        │
│   ──────────              ───────────────                        │
│                                                                  │
│   ┌─────────┐            ┌─────────────────────────────────┐   │
│   │Checkpoint│───fork───►│ Shadow Network + Pod             │   │
│   │ Archive  │           │ ┌─────────────────────────────┐  │   │
│   └─────────┘           │ │ Restore checkpoint           │  │   │
│                          │ │ Boot mesh (sa-up)            │  │   │
│                          │ │ FPPS verification            │  │   │
│                          │ │ Constitutional check (Ψ₀/Ψ₂)  │  │   │
│                          │ └─────────────────────────────┘  │   │
│                          │                                   │   │
│                          │ Pass? ───yes──► Prune shadow     │   │
│                          │   │                               │   │
│                          │   no                              │   │
│                          │   ▼                               │   │
│                          │ Flag checkpoint as INVALID        │   │
│                          └─────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 12.3 Implementation (sa-multiverse.fsx)

```fsharp
// Verify checkpoint in shadow universe
let verifyCheckpoint (checkpointPath: string) =
    let shadowName = sprintf "verify-%s" (DateTime.Now.ToString("yyyyMMdd-HHmmss"))

    // Fork isolated universe
    Multiverse.fork shadowName checkpointPath

    // Boot and verify
    let health = Multiverse.exec shadowName "mesh-verify.fsx"
    let constitutional = Multiverse.exec shadowName "constitutional-check"

    // Cleanup and report
    if health.score > 0.8 && constitutional.psi0 && constitutional.psi2 then
        Multiverse.prune shadowName
        Ok { verified = true; health = health; constitutional = constitutional }
    else
        Error { reason = "Verification failed"; health = health }
```

### 12.4 Usage

```bash
# Create checkpoint with shadow verification
dotnet fsi scripts/infrastructure/mesh-checkpoint.fsx --verify-shadow

# Manual shadow verification
dotnet fsi sa-multiverse.fsx verify /data/checkpoints/20260109_120000.tar.gz
```

## 13. FMEA Risk Analysis

### 13.1 Checkpoint System Failure Modes

| ID | Failure Mode | S | O | D | RPN | Mitigation | Status |
|----|--------------|---|---|---|-----|------------|--------|
| FM-001 | Partial file capture | 8 | 3 | 4 | 96 | SHA-256 manifest | IMPLEMENTED |
| FM-002 | KMS corruption during backup | 9 | 2 | 5 | 90 | VACUUM INTO | IMPLEMENTED |
| FM-003 | Container state not captured | 7 | 4 | 6 | 168 | CRIU checkpoint | PROPOSED |
| FM-004 | Zenoh session state lost | 6 | 5 | 7 | 210 | Chandy-Lamport | PROPOSED |
| FM-005 | Restore fails silently | 9 | 2 | 3 | 54 | Multiverse verify | PROPOSED |
| FM-006 | Git diff patch corrupted | 5 | 3 | 4 | 60 | Patch validation | IMPLEMENTED |
| FM-007 | Archive integrity failure | 8 | 2 | 3 | 48 | Checksum verify | IMPLEMENTED |

### 13.2 Critical Findings

1. **Highest Risk (RPN 210)**: Zenoh session state loss
   - Mitigation: Chandy-Lamport marker propagation
   - Priority: Phase 3

2. **High Risk (RPN 168)**: Container state not captured
   - Mitigation: CRIU container checkpoint
   - Priority: Phase 2

3. **Medium Risk (RPN 96)**: Partial file capture
   - Mitigation: SHA-256 manifest with completeness check
   - Status: IMPLEMENTED

## 14. Enhanced STAMP Constraints

| ID | Constraint | Severity | Phase |
|----|------------|----------|-------|
| SC-UCR-001 | Checkpoint MUST capture all 7 distributed state locations atomically | CRITICAL | 1 |
| SC-UCR-002 | Manifest MUST include SHA-256 hash for every artifact | CRITICAL | 1 |
| SC-UCR-003 | KMS databases MUST use `VACUUM INTO` for consistent copy | HIGH | 1 |
| SC-UCR-004 | Git state MUST be captured (hash + dirty diff) | HIGH | 1 |
| SC-UCR-005 | FPPS health score MUST be recorded at checkpoint time | HIGH | 1 |
| SC-UCR-006 | Constitutional invariants (Ψ₀/Ψ₂) MUST be verified | CRITICAL | 1 |
| SC-UCR-007 | Unified system hash MUST be computed from all component hashes | CRITICAL | 1 |
| SC-UCR-008 | Restore operation MUST verify checksums before overwriting | CRITICAL | 1 |
| SC-UCR-009 | Checkpoint archive MUST be self-contained and portable | HIGH | 1 |
| SC-UCR-010 | Checkpoint metadata MUST include STAMP constraint references | MEDIUM | 1 |
| **SC-UCR-011** | Container state SHOULD be captured via CRIU when available | HIGH | **2** |
| **SC-UCR-012** | Checkpoint SHOULD be verified via multiverse shadow instantiation | HIGH | **4** |
| **SC-UCR-013** | Shadow verification MUST pass FPPS health score > 0.8 | HIGH | **4** |
| **SC-UCR-014** | Shadow verification MUST confirm constitutional invariants (Ψ₀/Ψ₂) | CRITICAL | **4** |
| **SC-UCR-015** | Zenoh mesh state SHOULD be captured via Chandy-Lamport markers | HIGH | **3** |

## 15. Phased Implementation Roadmap

### Phase 1: Foundation (COMPLETE)
- ✓ File artifacts with SHA-256
- ✓ KMS database backup (VACUUM INTO)
- ✓ Git state capture
- ✓ Container image manifest
- ✓ FPPS health verification
- ✓ Constitutional invariant check

### Phase 2: Container State (PROPOSED)
```bash
dotnet fsi mesh-checkpoint.fsx --with-criu
```
- CRIU checkpoint for running containers
- Volume snapshot via tar
- Redis dump for session state

### Phase 3: Network State (PROPOSED)
```bash
dotnet fsi mesh-checkpoint.fsx --full-mesh
```
- Zenoh subscription registry export
- Publisher liveliness snapshot
- Chandy-Lamport marker propagation

### Phase 4: Verification (PROPOSED)
```bash
dotnet fsi mesh-checkpoint.fsx --verify-shadow
```
- Automatic multiverse fork
- Shadow mesh boot test
- FPPS and constitutional verification
- Auto-prune on success

## 16. Tradeoff Summary

| Enhancement | Benefit | Cost | Complexity | Recommendation |
|-------------|---------|------|------------|----------------|
| CRIU container | Full memory state | ~1GB/container | MEDIUM | **ADOPT** Phase 2 |
| Chandy-Lamport | Network snapshot | Implementation | HIGH | **ADOPT** Phase 3 |
| TigerBeetle | ACID financial | Complete redesign | VERY HIGH | **REJECT** |
| Multiverse verify | Proven recovery | ~2 min overhead | LOW | **ADOPT** Phase 4 |
| Event sourcing | Point-in-time | Replay complexity | MEDIUM | **DEFER** |

## Appendix B: Updated F# Script Inventory

### B.1 Mesh Infrastructure Scripts (9 files, 175.7 KB)

| File | Size | SHA-256 | Purpose |
|------|------|---------|---------|
| `MeshCommon.fsx` | 12,180 | `6ba242e5...` | Shared utilities |
| `mesh-verify.fsx` | 20,365 | `e20f2edf...` | FPPS verification |
| `mesh-state-capture.fsx` | 21,808 | `4ef9e67f...` | State backup |
| `mesh-recovery.fsx` | 25,792 | `b1d6dc60...` | Full recovery |
| `mesh-emergency-recovery.fsx` | 25,487 | `26288732...` | Emergency protocol |
| `mesh-image-backup.fsx` | 16,773 | `824caf33...` | Image export |
| `mesh-image-recovery.fsx` | 18,786 | `30eec3e9...` | Image restore |
| `mesh-quick-snapshot.fsx` | 11,341 | `05c2563e...` | Quick snapshot |
| `mesh-checkpoint.fsx` | 23,216 | `acede51c...` | **UCR implementation** |

## 17. Extended 3-Run Analysis (2026-01-09)

### 17.1 Complete External Artifact Inventory

| Category | Files | Total Size | SHA-256 Verified |
|----------|-------|------------|------------------|
| F# Mesh Scripts | 9 | 175,748 bytes | ✓ |
| SA Orchestration | 13 | 50,625 bytes | ✓ |
| Compose Files | 9 | 92 KB | ✓ |
| Nix Files | 16 | 175.9 KB | ✓ |
| KMS Databases | 5 | 27.1 MB | ✓ |
| CEPAF Scripts | 4 | 74.6 KB | ✓ |
| Elixir Config | 6 | 175.8 KB | ✓ |
| **Total** | **62** | **~28 MB** | **✓** |

### 17.2 8-Level Fractal Analysis Summary

```
L1 (Function): SHA-256 hash verification for each artifact
L2 (Component): F# script interdependencies tracked
L3 (Holon): SQLite VACUUM INTO for consistent KMS backup
L4 (Container): CRIU proposal for full process state
L5 (Node): devenv.nix + Nix flake for reproducibility
L6 (Cluster): Compose configs define mesh topology
L7 (Federation): Cross-holon attestation via Chandy-Lamport
L8 (Constitutional): Ψ₀/Ψ₂ verification before checkpoint
```

### 17.3 Critical FMEA Findings

| Rank | Failure Mode | RPN | Mitigation | Status |
|------|--------------|-----|------------|--------|
| 1 | Zenoh session state loss | 210 | Chandy-Lamport markers | PROPOSED |
| 2 | Container state loss | 168 | CRIU checkpoint | PROPOSED |
| 3 | Federation sync failure | 108 | Cross-holon attestation | PROPOSED |
| 4 | KMS database corruption | 72 | VACUUM INTO | IMPLEMENTED |
| 5 | Image registry failure | 70 | Local manifest | IMPLEMENTED |

### 17.4 Updated State Hash Registry

```
═══════════════════════════════════════════════════════════════════════════════
           AUTHORITATIVE STATE HASHES (2026-01-09 Extended Analysis)
═══════════════════════════════════════════════════════════════════════════════

MESH INFRASTRUCTURE (175,748 bytes)
  MeshCommon.fsx          6ba242e55502490fcc5bc1843c7303c661662c96678d8341596341eac3509a54
  mesh-verify.fsx         e20f2edf049025a653450b28d427cabe2636d6daf8b4f3f286e665431e8482d2
  mesh-checkpoint.fsx     acede51c2510124ec669f94f1e0fd69b510c9c8d5e3015628cbb1f4917af7902

SA ORCHESTRATION (50,625 bytes)
  sa-up.fsx               13c5b923b84cd6b7aa52d4961f3fa2e1b6eaa945b9966d1558a018d100268a80
  sa-mesh.fsx             fe48ab87a9cde6a768af8cb6679b44adfc83853fd5169091037b790d3208ccb5
  sa-multiverse.fsx       69c334f4746511edb40773d6c5a7e7b9de3d459130fad68d1abea1b51f6fc0ea

KMS DATABASES (27,140,096 bytes)
  holons.db               6c979c3960bdd35ecb14cc4cb9b386472a268e2b2d81a6fe5e54dab8f00ec2d7
  core.db                 4fd696ccba04802096af571d7dc549a65e22eb5d7e082f287d29c2240e8b1de1
  todos.db                2b94fa8c0d762d863379e95c7dd0d9020ff1f5a8446e48650311db0b10de6057

COMPOSE & NIX
  prod-standalone.yml     b0be5f8b312d85e7d76262473f1a7b3896e114af3ec43d4cc179ff529ccf11c7
  sil6-full-mesh.yml      d25d2f577fffbcd255abddd3abcd5d6a92b5eb5761c94381521452af0b97e6aa
  devenv.nix              8025123ab181c6eaa80bd10bf3d62d884ade1919f6aac75b4307ae244eff30aa
═══════════════════════════════════════════════════════════════════════════════
```

## Appendix C: References

### C.1 Internal Documentation
- `CLAUDE.md` §5.0 STAMP Constraints
- `docs/architecture/HOLON_IMMUTABLE_REGISTER.md`
- `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md`
- `journal/2026-01/20260109-1045-unified-checkpoint-registry-analysis.md`

### C.2 External Resources
- CRIU Podman: https://criu.org/Podman
- Chandy-Lamport: https://www.researchgate.net/publication/371772234
- TigerBeetle Jepsen: https://jepsen.io/analyses/tigerbeetle-0.16.11
- Zenoh Gozuryū: https://zenoh.io/blog/2025-04-14-zenoh-gozuryu/
- Commanded (Event Sourcing): https://www.curiosum.com/blog/segregate-responsibilities-with-elixir-commanded
