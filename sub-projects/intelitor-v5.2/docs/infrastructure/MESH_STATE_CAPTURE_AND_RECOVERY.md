# SIL-6 Biomorphic Fractal Mesh - State Capture and Recovery Guide

**Version**: 1.0.0
**Date**: 2026-01-09
**STAMP Compliance**: SC-HOLON-*, SC-REG-*, SC-FUNC-*
**Author**: Claude Opus 4.5 (Cybernetic Architect)

---

## Executive Summary

This document catalogs all critical infrastructure artifacts required to set up, run, and recover the SIL-6 Biomorphic Fractal Mesh system. It provides:
1. Complete artifact inventory with checksums
2. Dependency relationships between components
3. State capture procedures
4. Recovery procedures for system restoration

---

## 1. Critical Artifact Inventory

### 1.1 Podman-Compose Configuration Files (20 files)

| File | Purpose | Priority | Checksum Command |
|------|---------|----------|------------------|
| `lib/cepaf/artifacts/podman-compose-prod-standalone.yml` | **PRIMARY** 3-container production config | P0 | `sha256sum` |
| `podman-compose-fractal-mesh.yml` | 6-node hybrid mesh config | P0 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-fractal-cluster.yml` | Fractal cluster variant | P1 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-dev.yml` | Development environment | P2 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-sil4-full-mesh.yml` | SIL-6 Biomorphic full mesh | P1 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-hybrid.yml` | Hybrid deployment | P2 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-signoz.yml` | SigNoz observability | P2 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-clickhouse.yml` | ClickHouse analytics | P2 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-obs-standalone.yml` | OBS standalone | P2 | `sha256sum` |
| `lib/cepaf/artifacts/podman-compose-enterprise.yml` | Enterprise deployment | P2 | `sha256sum` |

#### Primary Configuration: `podman-compose-prod-standalone.yml`

**3-Container Architecture:**
```
┌─────────────────────────────────────────────────────────────────────┐
│                    PRODUCTION STANDALONE (3 Containers)              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │ indrajaal-db    │  │ indrajaal-obs   │  │ indrajaal-app   │     │
│  │ 172.28.0.20     │  │ 172.28.0.30     │  │ 172.28.0.10     │     │
│  │ :5433           │  │ :4317,9090,3000 │  │ :4000,4001,6379 │     │
│  │ PostgreSQL+TS   │  │ OTEL+Prom+Graf  │  │ Phoenix+Redis   │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│                                                                      │
│  Networks: indrajaal-mesh (172.28.0.0/16)                           │
│            indrajaal-internal (172.29.0.0/16)                       │
└─────────────────────────────────────────────────────────────────────┘
```

**Required Images:**
- `localhost/indrajaal-timescaledb-demo:nixos-devenv`
- `localhost/indrajaal-obs-unified:nixos-devenv`
- `localhost/indrajaal-app-unified:nixos-devenv`

### 1.2 Nix Container Definitions (24 files)

| File | Purpose | Priority |
|------|---------|----------|
| `containers/indrajaal-timescaledb-demo.nix` | PostgreSQL 17 + TimescaleDB container | P0 |
| `containers/enhanced-app-nixos.nix` | Phoenix application container | P0 |
| `containers/indrajaal-obs-unified.nix` | Unified observability container | P0 |
| `containers/indrajaal-cortex.nix` | F# Cortex container | P1 |
| `devenv.nix` | Development environment definition | P0 |
| `flake.nix` | Nix flake configuration | P0 |
| `containers/common/base-packages.nix` | Shared package definitions | P1 |
| `containers/common/phoenix-runtime.nix` | Phoenix runtime deps | P1 |

### 1.3 Container Images (Current State)

| Image | Tag | Size | Purpose |
|-------|-----|------|---------|
| `localhost/indrajaal-app` | latest | 12.8 GB | Phoenix application |
| `localhost/indrajaal-obs` | latest | 512 MB | Observability stack |
| `localhost/indrajaal-db` | latest | 875 MB | Database |
| `localhost/indrajaal-timescaledb-demo` | nixos-devenv | 875 MB | Production DB |
| `localhost/indrajaal-obs-unified` | nixos-devenv | 7.8 GB | Production OBS |
| `localhost/indrajaal-app-unified` | nixos-devenv | 9.39 GB | Production APP |
| `localhost/indrajaal-cortex` | latest | 552 MB | F# Cortex |

### 1.4 F# Orchestration Scripts (Wave-Based)

#### Primary Scripts (sa-*.fsx)

| Script | Purpose | Priority | STAMP |
|--------|---------|----------|-------|
| `sa-up.fsx` | Boot sequence orchestrator | P0 | SC-SIL6-001 |
| `sa-down.fsx` | Graceful shutdown | P0 | SC-SIL6-002 |
| `sa-health.fsx` | Health check wrapper | P0 | SC-SIL6-005 |
| `sa-status.fsx` | Container status display | P1 | SC-SIL6-004 |
| `sa-clean.fsx` | Container cleanup | P1 | SC-SIL6-003 |
| `sa-test.fsx` | Runtime test executor | P1 | SC-VAL-003 |
| `sa-verify.fsx` | 2oo3 verification | P1 | SC-SIL6-006 |
| `sa-emergency.fsx` | Emergency stop (<5s) | P0 | SC-EMR-057 |
| `sa-multiverse.fsx` | Parallel safe harbors | P2 | SC-DEP-* |

#### CEPAF Infrastructure Scripts

| Script | Purpose | Priority |
|--------|---------|----------|
| `lib/cepaf/scripts/Governance.fsx` | Universal policy engine | P0 |
| `lib/cepaf/scripts/RuntimeTestOrchestrator.fsx` | Test orchestration | P1 |
| `lib/cepaf/scripts/SIL6Orchestrator.fsx` | SIL-6 Biomorphic compliance | P1 |
| `lib/cepaf/scripts/PanopticonOrchestrator.fsx` | Mesh boot stages | P1 |
| `lib/cepaf/scripts/FractalRuntimeValidator.fsx` | Runtime validation | P1 |
| `lib/cepaf/scripts/CockpitOperations.fsx` | Cockpit lifecycle | P1 |

### 1.5 Critical Configuration Files

| File | Purpose | Priority |
|------|---------|----------|
| `lib/cepaf/artifacts/otel-config-fractal.yaml` | OTEL collector config | P0 |
| `config/zenoh/zenoh.json5` | Zenoh router config | P1 |
| `scripts/containers/entrypoint.sh` | Container entrypoint | P0 |
| `.env.standalone` | Environment variables | P0 |

### 1.6 KMS State Directory (`data/kms/`)

| File | Purpose | Backup Priority |
|------|---------|-----------------|
| `core.db` | Core system state (SQLite) | CRITICAL |
| `holons.db` | Holon state (SQLite) | CRITICAL |
| `todos.db` | Task state (SQLite) | HIGH |
| `analytics.duckdb` | Analytics data | HIGH |
| `telemetry.duckdb` | Telemetry history | MEDIUM |
| `multiverse_registry.json` | Multiverse registry | HIGH |
| `current_genotype` | Current genotype reference | HIGH |
| `fractal_execution.log` | Execution log | MEDIUM |

---

## 2. Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ARTIFACT DEPENDENCY GRAPH                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐                                                        │
│  │  devenv.nix  │ ──── Defines all sa-* commands                        │
│  └──────┬───────┘                                                        │
│         │                                                                 │
│         ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │                     Nix Container Definitions                  │       │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │       │
│  │  │ timescaledb │  │ obs-unified │  │ app-unified │          │       │
│  │  │    .nix     │  │    .nix     │  │    .nix     │          │       │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │       │
│  └─────────┼────────────────┼────────────────┼─────────────────┘       │
│            │                │                │                          │
│            ▼                ▼                ▼                          │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │                    Container Images (Podman)                   │       │
│  │  indrajaal-db:nixos-devenv  obs-unified:nixos-devenv          │       │
│  │  app-unified:nixos-devenv                                     │       │
│  └──────────────────────────────────────────────────────────────┘       │
│            │                │                │                          │
│            └────────────────┼────────────────┘                          │
│                             ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │              podman-compose-prod-standalone.yml               │       │
│  │                    (Container Orchestration)                  │       │
│  └──────────────────────────────┬───────────────────────────────┘       │
│                                 │                                        │
│                                 ▼                                        │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │                    F# Orchestration Scripts                    │       │
│  │  sa-up.fsx → sa-health.fsx → sa-status.fsx → sa-down.fsx     │       │
│  │                         │                                      │       │
│  │                         ▼                                      │       │
│  │                 Governance.fsx (Policy Engine)                │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                 │                                        │
│                                 ▼                                        │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │                      KMS State (data/kms/)                     │       │
│  │          SQLite (core.db, holons.db) + DuckDB (analytics)     │       │
│  └──────────────────────────────────────────────────────────────┘       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. State Capture Procedures

### 3.1 Full State Capture Script

```bash
#!/bin/bash
# mesh-state-capture.sh - Full state capture for recovery
# Version: 1.0.0

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/mesh-state-${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}"/{compose,nix,scripts,kms,images,config}

echo "=== SIL-6 Mesh State Capture: ${TIMESTAMP} ==="

# 1. Capture podman-compose files (P0)
echo "[1/8] Capturing compose configurations..."
cp lib/cepaf/artifacts/podman-compose-prod-standalone.yml "${BACKUP_DIR}/compose/"
cp podman-compose-fractal-mesh.yml "${BACKUP_DIR}/compose/"
cp lib/cepaf/artifacts/podman-compose-*.yml "${BACKUP_DIR}/compose/" 2>/dev/null || true

# 2. Capture Nix definitions (P0)
echo "[2/8] Capturing Nix container definitions..."
cp containers/*.nix "${BACKUP_DIR}/nix/"
cp devenv.nix flake.nix flake.lock "${BACKUP_DIR}/nix/"

# 3. Capture F# orchestration scripts (P0)
echo "[3/8] Capturing F# orchestration scripts..."
cp sa-*.fsx "${BACKUP_DIR}/scripts/"
cp -r lib/cepaf/scripts/*.fsx "${BACKUP_DIR}/scripts/cepaf/"

# 4. Capture KMS state (CRITICAL)
echo "[4/8] Capturing KMS state..."
cp -r data/kms/*.db "${BACKUP_DIR}/kms/" 2>/dev/null || true
cp -r data/kms/*.duckdb "${BACKUP_DIR}/kms/" 2>/dev/null || true
cp data/kms/multiverse_registry.json "${BACKUP_DIR}/kms/" 2>/dev/null || true
cp data/kms/current_genotype "${BACKUP_DIR}/kms/" 2>/dev/null || true

# 5. Capture container images (P0)
echo "[5/8] Capturing container image manifests..."
podman images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" > "${BACKUP_DIR}/images/manifest.txt"

# 6. Capture OTEL/Zenoh configs (P1)
echo "[6/8] Capturing observability configs..."
cp lib/cepaf/artifacts/otel-config-fractal.yaml "${BACKUP_DIR}/config/"
cp config/zenoh/*.json5 "${BACKUP_DIR}/config/" 2>/dev/null || true

# 7. Capture environment files
echo "[7/8] Capturing environment files..."
cp .env* "${BACKUP_DIR}/config/" 2>/dev/null || true
cp scripts/containers/entrypoint.sh "${BACKUP_DIR}/config/"

# 8. Generate checksums
echo "[8/8] Generating checksums..."
cd "${BACKUP_DIR}"
find . -type f -exec sha256sum {} \; > checksums.sha256
cd -

# Create tarball
echo "Creating backup archive..."
tar -czvf "backups/mesh-state-${TIMESTAMP}.tar.gz" -C backups "mesh-state-${TIMESTAMP}"

echo ""
echo "=== State Capture Complete ==="
echo "Archive: backups/mesh-state-${TIMESTAMP}.tar.gz"
echo "Checksum: $(sha256sum backups/mesh-state-${TIMESTAMP}.tar.gz | cut -d' ' -f1)"
```

### 3.2 Image Backup Script

```bash
#!/bin/bash
# mesh-image-backup.sh - Export container images for recovery
# Version: 1.0.0

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
IMAGE_DIR="backups/images-${TIMESTAMP}"

mkdir -p "${IMAGE_DIR}"

echo "=== Container Image Export ==="

# Export critical images
IMAGES=(
    "localhost/indrajaal-timescaledb-demo:nixos-devenv"
    "localhost/indrajaal-obs-unified:nixos-devenv"
    "localhost/indrajaal-app-unified:nixos-devenv"
    "localhost/indrajaal-cortex:latest"
)

for IMG in "${IMAGES[@]}"; do
    SAFE_NAME=$(echo "${IMG}" | tr '/:' '_')
    echo "Exporting ${IMG}..."
    podman save -o "${IMAGE_DIR}/${SAFE_NAME}.tar" "${IMG}"
done

# Generate manifest
podman images --format json > "${IMAGE_DIR}/manifest.json"

# Create archive
tar -czvf "backups/images-${TIMESTAMP}.tar.gz" -C backups "images-${TIMESTAMP}"

echo ""
echo "=== Image Export Complete ==="
echo "Archive: backups/images-${TIMESTAMP}.tar.gz"
```

### 3.3 Quick State Snapshot (Minimal)

```bash
#!/bin/bash
# mesh-quick-snapshot.sh - Minimal state for quick recovery
# Version: 1.0.0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAP_DIR="backups/quick-${TIMESTAMP}"

mkdir -p "${SNAP_DIR}"

# Only P0 artifacts
cp lib/cepaf/artifacts/podman-compose-prod-standalone.yml "${SNAP_DIR}/"
cp sa-up.fsx sa-down.fsx sa-health.fsx "${SNAP_DIR}/"
cp lib/cepaf/scripts/Governance.fsx "${SNAP_DIR}/"
cp -r data/kms/*.db "${SNAP_DIR}/" 2>/dev/null || true

tar -czvf "backups/quick-${TIMESTAMP}.tar.gz" -C backups "quick-${TIMESTAMP}"

echo "Quick snapshot: backups/quick-${TIMESTAMP}.tar.gz"
```

---

## 4. Recovery Procedures

### 4.1 Full System Recovery

```bash
#!/bin/bash
# mesh-recovery.sh - Full system recovery from backup
# Version: 1.0.0
# Usage: ./mesh-recovery.sh <backup-archive>

set -euo pipefail

ARCHIVE=$1
TEMP_DIR=$(mktemp -d)

echo "=== SIL-6 Mesh Recovery ==="
echo "Archive: ${ARCHIVE}"

# 1. Verify archive integrity
echo "[1/7] Verifying archive..."
tar -tzf "${ARCHIVE}" > /dev/null

# 2. Extract archive
echo "[2/7] Extracting archive..."
tar -xzf "${ARCHIVE}" -C "${TEMP_DIR}"
BACKUP_DIR=$(ls "${TEMP_DIR}")

# 3. Verify checksums
echo "[3/7] Verifying checksums..."
cd "${TEMP_DIR}/${BACKUP_DIR}"
if sha256sum -c checksums.sha256; then
    echo "Checksums verified OK"
else
    echo "ERROR: Checksum verification failed!"
    exit 1
fi
cd -

# 4. Stop existing containers
echo "[4/7] Stopping existing containers..."
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml down 2>/dev/null || true

# 5. Restore configurations
echo "[5/7] Restoring configurations..."
cp "${TEMP_DIR}/${BACKUP_DIR}/compose/"* lib/cepaf/artifacts/
cp "${TEMP_DIR}/${BACKUP_DIR}/scripts/"*.fsx ./
cp "${TEMP_DIR}/${BACKUP_DIR}/scripts/cepaf/"* lib/cepaf/scripts/

# 6. Restore KMS state
echo "[6/7] Restoring KMS state..."
mkdir -p data/kms
cp "${TEMP_DIR}/${BACKUP_DIR}/kms/"* data/kms/

# 7. Verify recovery
echo "[7/7] Verifying recovery..."
dotnet fsi sa-health.fsx

# Cleanup
rm -rf "${TEMP_DIR}"

echo ""
echo "=== Recovery Complete ==="
echo "Run 'devenv shell && sa-up' to start the mesh"
```

### 4.2 Image Recovery

```bash
#!/bin/bash
# mesh-image-recovery.sh - Restore container images
# Usage: ./mesh-image-recovery.sh <images-archive>

set -euo pipefail

ARCHIVE=$1
TEMP_DIR=$(mktemp -d)

echo "=== Container Image Recovery ==="

tar -xzf "${ARCHIVE}" -C "${TEMP_DIR}"

for TAR in "${TEMP_DIR}"/*/*.tar; do
    echo "Loading $(basename ${TAR})..."
    podman load -i "${TAR}"
done

podman images

rm -rf "${TEMP_DIR}"

echo "=== Image Recovery Complete ==="
```

### 4.3 Emergency Recovery (Minimal)

For rapid recovery when full restore is not possible:

```bash
#!/bin/bash
# mesh-emergency-recovery.sh - Minimal recovery procedure
# Version: 1.0.0

echo "=== Emergency Recovery Mode ==="

# 1. Clean all containers
echo "[1/5] Cleaning containers..."
podman rm -af 2>/dev/null || true
podman network prune -f 2>/dev/null || true

# 2. Rebuild critical images (if corrupted)
echo "[2/5] Rebuilding images..."
nix build .#indrajaal-timescaledb-demo 2>/dev/null || true
nix build .#indrajaal-obs-unified 2>/dev/null || true
nix build .#indrajaal-app-unified 2>/dev/null || true

# 3. Start minimal stack
echo "[3/5] Starting minimal stack..."
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml up -d indrajaal-db-prod

# 4. Wait for DB
echo "[4/5] Waiting for database..."
sleep 10
until pg_isready -h localhost -p 5433; do
    sleep 2
done

# 5. Start remaining services
echo "[5/5] Starting application services..."
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml up -d

echo ""
echo "=== Emergency Recovery Complete ==="
echo "Check status with: podman ps"
```

---

## 5. Health Verification Checks

### 5.1 Post-Recovery Verification Checklist

| Check | Command | Expected Result |
|-------|---------|-----------------|
| DB Running | `pg_isready -h localhost -p 5433` | exit 0 |
| OTEL Active | `curl -s http://localhost:4317/health` | healthy |
| Phoenix Up | `curl -s http://localhost:4000/health` | JSON status |
| Redis Ready | `redis-cli -p 6379 ping` | PONG |
| Prometheus | `curl -s http://localhost:9090/-/healthy` | ok |
| Grafana | `curl -s http://localhost:3000/api/health` | ok |

### 5.2 Automated Health Check Script

```bash
#!/bin/bash
# mesh-verify.sh - Post-recovery verification
# Version: 1.0.0

echo "=== Mesh Health Verification ==="

CHECKS_PASSED=0
CHECKS_TOTAL=6

# Check 1: Database
if pg_isready -h localhost -p 5433 > /dev/null 2>&1; then
    echo "[✓] Database (PostgreSQL): HEALTHY"
    ((CHECKS_PASSED++))
else
    echo "[✗] Database (PostgreSQL): FAILED"
fi

# Check 2: OTEL Collector
if curl -sf http://localhost:13133/health > /dev/null 2>&1; then
    echo "[✓] OTEL Collector: HEALTHY"
    ((CHECKS_PASSED++))
else
    echo "[✗] OTEL Collector: FAILED"
fi

# Check 3: Phoenix Application
if curl -sf http://localhost:4000/health > /dev/null 2>&1; then
    echo "[✓] Phoenix Application: HEALTHY"
    ((CHECKS_PASSED++))
else
    echo "[✗] Phoenix Application: FAILED"
fi

# Check 4: Prometheus
if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo "[✓] Prometheus: HEALTHY"
    ((CHECKS_PASSED++))
else
    echo "[✗] Prometheus: FAILED"
fi

# Check 5: Grafana
if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "[✓] Grafana: HEALTHY"
    ((CHECKS_PASSED++))
else
    echo "[✗] Grafana: FAILED"
fi

# Check 6: Container Count
CONTAINER_COUNT=$(podman ps --format "{{.Names}}" | grep -c "indrajaal" || true)
if [ "$CONTAINER_COUNT" -ge 3 ]; then
    echo "[✓] Container Count: ${CONTAINER_COUNT} (≥3)"
    ((CHECKS_PASSED++))
else
    echo "[✗] Container Count: ${CONTAINER_COUNT} (<3)"
fi

echo ""
echo "=== Verification Summary ==="
echo "Passed: ${CHECKS_PASSED}/${CHECKS_TOTAL}"

if [ "$CHECKS_PASSED" -eq "$CHECKS_TOTAL" ]; then
    echo "Status: ALL CHECKS PASSED"
    exit 0
else
    echo "Status: SOME CHECKS FAILED"
    exit 1
fi
```

---

## 6. Wave-Based Startup/Shutdown Sequences

### 6.1 Startup Sequence (sa-up.fsx)

```
Wave 1: Infrastructure (DB + Networks)
├── Create networks (indrajaal-mesh, indrajaal-internal)
├── Start indrajaal-db-prod
└── Wait for pg_isready

Wave 2: Observability
├── Start indrajaal-obs-prod
├── Wait for OTEL health endpoint
└── Verify Prometheus scraping

Wave 3: Application
├── Start indrajaal-ex-app-1
├── Wait for Phoenix health endpoint
└── Verify Redis connectivity

Wave 4: Verification
├── Run FPPS 5-method health check
├── Verify Zenoh mesh connectivity
└── Publish mesh-ready event
```

### 6.2 Shutdown Sequence (sa-down.fsx)

```
Wave 1: Application Drain
├── Set Phoenix to maintenance mode
├── Drain active connections
└── Publish dying gasp event

Wave 2: Checkpoint State
├── Capture KMS state to backup
├── Sync DuckDB analytics
└── Flush OTEL buffers

Wave 3: Stop Services
├── Stop indrajaal-ex-app-1
├── Stop indrajaal-obs-prod
└── Stop indrajaal-db-prod

Wave 4: Cleanup
├── Remove stopped containers
├── Prune unused networks
└── Update Digital Twin state
```

---

## 7. STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-BACKUP-001 | Full backup MUST include all P0 artifacts | CRITICAL |
| SC-BACKUP-002 | KMS state (SQLite/DuckDB) MUST be included | CRITICAL |
| SC-BACKUP-003 | Checksums MUST be verified on recovery | CRITICAL |
| SC-BACKUP-004 | Recovery time objective: <15 minutes | HIGH |
| SC-BACKUP-005 | Backup archives MUST be encrypted at rest | HIGH |
| SC-BACKUP-006 | Weekly full backup MANDATORY | MEDIUM |
| SC-BACKUP-007 | Daily incremental backup RECOMMENDED | MEDIUM |

---

## 8. AOR Rules

| ID | Rule |
|----|------|
| AOR-BACKUP-001 | Run `mesh-state-capture.sh` before major changes |
| AOR-BACKUP-002 | Verify checksum integrity before any restore |
| AOR-BACKUP-003 | Test recovery procedure monthly |
| AOR-BACKUP-004 | Keep minimum 3 backup generations |
| AOR-BACKUP-005 | Store backups in separate location from source |
| AOR-BACKUP-006 | Document any manual recovery steps |

---

## 9. Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    MESH STATE & RECOVERY QUICK REFERENCE                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STATE CAPTURE:                                                          │
│  ─────────────                                                           │
│  ./scripts/infrastructure/mesh-state-capture.sh                         │
│  ./scripts/infrastructure/mesh-image-backup.sh                          │
│  ./scripts/infrastructure/mesh-quick-snapshot.sh                        │
│                                                                          │
│  RECOVERY:                                                               │
│  ─────────                                                               │
│  ./scripts/infrastructure/mesh-recovery.sh <archive>                    │
│  ./scripts/infrastructure/mesh-image-recovery.sh <images-archive>       │
│  ./scripts/infrastructure/mesh-emergency-recovery.sh                    │
│                                                                          │
│  VERIFICATION:                                                           │
│  ─────────────                                                           │
│  ./scripts/infrastructure/mesh-verify.sh                                │
│  devenv shell && sa-health                                              │
│                                                                          │
│  CRITICAL PATHS:                                                         │
│  ───────────────                                                         │
│  lib/cepaf/artifacts/podman-compose-prod-standalone.yml  (P0)           │
│  data/kms/core.db                                        (CRITICAL)     │
│  sa-up.fsx, sa-down.fsx, sa-health.fsx                  (P0)           │
│  lib/cepaf/scripts/Governance.fsx                        (P0)           │
│                                                                          │
│  PORTS:                                                                  │
│  ──────                                                                  │
│  5433  - PostgreSQL                                                      │
│  4317  - OTEL gRPC                                                       │
│  4000  - Phoenix HTTP                                                    │
│  9090  - Prometheus                                                      │
│  3000  - Grafana                                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Related Documents

| Document | Location |
|----------|----------|
| CLAUDE.md | `/CLAUDE.md` |
| Holon Architecture | `docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md` |
| Full App Test Plan | `docs/testing/FULL_APP_HOLON_CAPABILITY_TEST_PLAN.md` |
| Agent Cognitive Protocol | `.claude/rules/agent-cognitive-protocol.md` |
| Functional Invariant Rule | `.claude/rules/functional-invariant.md` |

---

**Document Control**
| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-09 |
| Author | Claude Opus 4.5 |
| STAMP | SC-BACKUP-001 to SC-BACKUP-007 |
| Review | Pending |
