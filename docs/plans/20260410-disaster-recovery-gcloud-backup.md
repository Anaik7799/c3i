# Disaster Recovery Plan — Google Cloud State Backup

**Date**: 2026-04-10
**Version**: v22.5.0-CORTEX
**STAMP**: SC-FUNC-003 (rollback path), SC-FUNC-004 (state recoverable), SC-SMRITI-074 (immortality protocol)
**Mandate**: Complete system recovery from git clone + GCS state download

---

## 1. Recovery Guarantee

**Promise**: If the local environment is destroyed (disk crash, corruption, theft), the system can be fully operational within 30 minutes by:

```
1. git clone https://github.com/Anaik7799/c3i.git     # Code (5 min)
2. nix develop                                          # Dev environment (10 min)
3. ./sa-restore --from gcs                              # State from GCS (5 min)
4. cargo build --release                                # Rust daemon (5 min)
5. gleam build && mix compile                           # Gleam + Elixir (5 min)
```

---

## 2. State Inventory (What Must Be Backed Up)

### Tier 1: CRITICAL (Loss = System Dead)

| File | Size | Location | Contents |
|------|------|----------|----------|
| `Smriti.db` (active) | 5.6 MB | `sub-projects/c3i/data/smriti/` | Tasks, preferences, API keys, conversation history, semantic cache, trace data |
| `planning.db` | 312 KB | `sub-projects/c3i/data/smriti/` | Task management state (2,669 tasks) |
| `holons.db` | 20 MB | `sub-projects/c3i/data/smriti/` | Holon sovereign state, evolution history |
| `core.db` | 6.6 MB | `sub-projects/c3i/data/smriti/` | Core system state |
| `smriti.db` (knowledge) | 43 MB | `sub-projects/c3i/data/smriti/` | Full knowledge base, FTS5 index |

**Total Tier 1**: ~76 MB

### Tier 2: HIGH (Loss = Degraded Operation)

| File | Size | Location | Contents |
|------|------|----------|----------|
| `chaya.db` | 48 KB | `data/chaya/` | Digital twin state |
| `Smriti.db` (root) | 44 KB | `data/smriti/` | Root-level preferences |
| `analytics.duckdb` | 12 KB | `sub-projects/c3i/data/smriti/` | DuckDB analytics |
| `telemetry.duckdb` | 268 KB | `sub-projects/c3i/data/smriti/` | Telemetry time-series |
| `test_manager.db` | 48 KB | `sub-projects/c3i/data/smriti/` | Test lifecycle tracking |
| `test_tracking.db` | 28 KB | `sub-projects/c3i/data/smriti/` | Test coverage data |
| `todos.db` | 24 KB | `sub-projects/c3i/data/smriti/` | Legacy todo state |
| `model_registry.db` | varies | `sub-projects/c3i/data/models/` | ML model registry |
| `api_usage.db` | varies | `sub-projects/c3i/data/metrics/` | API usage metrics |

**Total Tier 2**: ~1 MB

### Tier 3: MEDIUM (Loss = Rebuild Required)

| File/Dir | Size | Location | Contents |
|----------|------|----------|----------|
| `system_dna.json` | 2 KB | `sub-projects/c3i/data/smriti/` | System genome hash |
| `container_registry.json` | 26 KB | `sub-projects/c3i/data/smriti/` | Container image registry |
| `current_genotype` | 64 B | `sub-projects/c3i/data/smriti/` | Current genotype hash |
| `captains_log.json` | 2 KB | `sub-projects/c3i/data/smriti/` | Operator session log |
| `migration_session_*.json` | 1 MB | `sub-projects/c3i/data/smriti/` | Migration state |
| `multiverse_registry.json` | 122 B | `sub-projects/c3i/data/smriti/` | Git multiverse state |
| Claude memory | 36 KB | `~/.claude/projects/.../memory/` | Agent session context |
| Specs & Allium | 724 KB | `specs/` | Committed to git (recoverable) |

**Total Tier 3**: ~2 MB

### Tier 4: EPHEMERAL (No Backup Needed)

| What | Why |
|------|-----|
| `_build/`, `deps/` | Rebuilt by `mix compile` |
| `target/` | Rebuilt by `cargo build` |
| `build/` | Rebuilt by `gleam build` |
| `fractal_execution.log` (129 MB) | Ephemeral runtime log |
| `test_evolution_*.db` (many) | Temporary test artifacts |
| `sessions/`, `test_runs/` | Ephemeral session data |
| Node-specific dirs (app-1, app-2, etc.) | Rebuilt on container boot |

### Total Backup Size: ~80 MB (compressed: ~25-30 MB)

---

## 3. Backup Architecture

```
LOCAL SYSTEM                          GOOGLE CLOUD STORAGE
═══════════════                       ═══════════════════

data/smriti/Smriti.db ──────┐
data/chaya/chaya.db ────────┤
sub-projects/c3i/data/      │       gs://indrajaal-c3i-state/
  smriti/Smriti.db ─────────┤       ├── latest/           (most recent)
  smriti/planning.db ───────┤       │   ├── smriti/       (all DBs)
  smriti/holons.db ─────────┼──────▶│   ├── config/       (JSON state)
  smriti/core.db ───────────┤       │   └── memory/       (Claude memory)
  smriti/smriti.db ─────────┤       ├── daily/            (daily snapshots)
  smriti/*.json ────────────┤       │   └── 20260410/
  smriti/*.duckdb ──────────┤       ├── weekly/           (weekly archives)
~/.claude/memory/ ──────────┘       │   └── 20260410/
                                    └── manifest.json     (backup metadata)
```

---

## 4. Implementation

### 4.1 GCS Setup (One-Time)

```bash
# 1. Authenticate
gcloud auth login

# 2. Create project (if needed)
gcloud projects create indrajaal-c3i --name="Indrajaal C3I"
gcloud config set project indrajaal-c3i

# 3. Create bucket (nearline storage for cost efficiency)
gsutil mb -c nearline -l europe-north1 gs://indrajaal-c3i-state/

# 4. Set lifecycle (auto-delete daily backups after 30 days, weekly after 90)
cat > /tmp/lifecycle.json << 'EOF'
{
  "rule": [
    {"action": {"type": "Delete"}, "condition": {"age": 30, "matchesPrefix": ["daily/"]}},
    {"action": {"type": "Delete"}, "condition": {"age": 90, "matchesPrefix": ["weekly/"]}}
  ]
}
EOF
gsutil lifecycle set /tmp/lifecycle.json gs://indrajaal-c3i-state/
```

### 4.2 Backup Script

```bash
#!/usr/bin/env bash
# scripts/backup/gcs-backup.sh — C3I State Backup to Google Cloud Storage
# STAMP: SC-FUNC-003, SC-FUNC-004, SC-SMRITI-074

set -euo pipefail

BUCKET="gs://indrajaal-c3i-state"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PROJECT_ROOT="/home/an/dev/ver/c3i"
BACKUP_DIR="/tmp/c3i-backup-${TIMESTAMP}"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  C3I STATE BACKUP TO GOOGLE CLOUD STORAGE            ║"
echo "║  Timestamp: ${TIMESTAMP}                              ║"
echo "╚═══════════════════════════════════════════════════════╝"

# --- Phase 1: Collect State ---
mkdir -p "${BACKUP_DIR}/smriti" "${BACKUP_DIR}/config" "${BACKUP_DIR}/memory"

echo "📦 Phase 1: Collecting state files..."

# Tier 1: Critical DBs (with WAL checkpoint first)
for db in Smriti.db planning.db holons.db core.db smriti.db; do
  src="${PROJECT_ROOT}/sub-projects/c3i/data/smriti/${db}"
  [ -f "$src" ] && {
    # Checkpoint WAL to ensure consistency
    sqlite3 "$src" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
    cp "$src" "${BACKUP_DIR}/smriti/"
    echo "  ✅ ${db} ($(du -h "$src" | cut -f1))"
  }
done

# Root-level DBs
for db in data/smriti/Smriti.db data/chaya/chaya.db; do
  src="${PROJECT_ROOT}/${db}"
  [ -f "$src" ] && {
    sqlite3 "$src" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
    cp "$src" "${BACKUP_DIR}/smriti/root-$(basename $db)"
    echo "  ✅ root-$(basename $db)"
  }
done

# Tier 2: DuckDB + test DBs
for f in analytics.duckdb telemetry.duckdb test_manager.db test_tracking.db todos.db; do
  src="${PROJECT_ROOT}/sub-projects/c3i/data/smriti/${f}"
  [ -f "$src" ] && cp "$src" "${BACKUP_DIR}/smriti/"
done

# Tier 3: JSON config state
for f in system_dna.json container_registry.json current_genotype captains_log.json multiverse_registry.json; do
  src="${PROJECT_ROOT}/sub-projects/c3i/data/smriti/${f}"
  [ -f "$src" ] && cp "$src" "${BACKUP_DIR}/config/"
done

# Migration sessions
cp "${PROJECT_ROOT}"/sub-projects/c3i/data/smriti/migration_session_*.json "${BACKUP_DIR}/config/" 2>/dev/null || true

# Model registry
[ -f "${PROJECT_ROOT}/sub-projects/c3i/data/models/model_registry.db" ] && \
  cp "${PROJECT_ROOT}/sub-projects/c3i/data/models/model_registry.db" "${BACKUP_DIR}/smriti/"

# API usage metrics
[ -f "${PROJECT_ROOT}/sub-projects/c3i/data/metrics/api_usage.db" ] && \
  cp "${PROJECT_ROOT}/sub-projects/c3i/data/metrics/api_usage.db" "${BACKUP_DIR}/smriti/"

# Claude memory
cp -r ~/.claude/projects/-home-an-dev-ver-c3i/memory/* "${BACKUP_DIR}/memory/" 2>/dev/null || true

# --- Phase 2: Create Manifest ---
echo "📋 Phase 2: Creating manifest..."

cat > "${BACKUP_DIR}/manifest.json" << MANIFEST
{
  "timestamp": "${TIMESTAMP}",
  "version": "22.5.0-CORTEX",
  "git_commit": "$(git -C ${PROJECT_ROOT} rev-parse HEAD)",
  "git_branch": "$(git -C ${PROJECT_ROOT} branch --show-current)",
  "files": $(find "${BACKUP_DIR}" -type f | wc -l),
  "total_size_bytes": $(du -sb "${BACKUP_DIR}" | cut -f1),
  "databases": {
    "smriti_tasks": $(sqlite3 "${BACKUP_DIR}/smriti/planning.db" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo 0),
    "smriti_prefs": $(sqlite3 "${BACKUP_DIR}/smriti/Smriti.db" "SELECT COUNT(*) FROM UserPreferences;" 2>/dev/null || echo 0)
  },
  "hostname": "$(hostname)",
  "backup_tool": "gcs-backup.sh v1.0"
}
MANIFEST

echo "  ✅ manifest.json"

# --- Phase 3: Compress ---
echo "🗜️  Phase 3: Compressing..."
ARCHIVE="/tmp/c3i-backup-${TIMESTAMP}.tar.zst"
tar -C /tmp -cf - "c3i-backup-${TIMESTAMP}" | zstd -3 -T4 > "${ARCHIVE}"
ARCHIVE_SIZE=$(du -h "${ARCHIVE}" | cut -f1)
echo "  ✅ Archive: ${ARCHIVE_SIZE}"

# --- Phase 4: Upload to GCS ---
echo "☁️  Phase 4: Uploading to GCS..."

# Latest (overwrite)
gsutil -m cp "${ARCHIVE}" "${BUCKET}/latest/c3i-state-latest.tar.zst"
gsutil cp "${BACKUP_DIR}/manifest.json" "${BUCKET}/latest/manifest.json"

# Daily snapshot
gsutil cp "${ARCHIVE}" "${BUCKET}/daily/${TIMESTAMP}/c3i-state.tar.zst"
gsutil cp "${BACKUP_DIR}/manifest.json" "${BUCKET}/daily/${TIMESTAMP}/manifest.json"

# Weekly (if Monday)
if [ "$(date +%u)" = "1" ]; then
  gsutil cp "${ARCHIVE}" "${BUCKET}/weekly/${TIMESTAMP}/c3i-state.tar.zst"
  gsutil cp "${BACKUP_DIR}/manifest.json" "${BUCKET}/weekly/${TIMESTAMP}/manifest.json"
  echo "  ✅ Weekly snapshot saved"
fi

echo "  ✅ Uploaded to ${BUCKET}"

# --- Phase 5: Cleanup ---
rm -rf "${BACKUP_DIR}" "${ARCHIVE}"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  BACKUP COMPLETE                                      ║"
echo "║  Size: ${ARCHIVE_SIZE} | Files: $(find "${BACKUP_DIR}" -type f 2>/dev/null | wc -l || echo "cleaned")          ║"
echo "║  GCS:  ${BUCKET}/latest/                              ║"
echo "╚═══════════════════════════════════════════════════════╝"
```

### 4.3 Restore Script

```bash
#!/usr/bin/env bash
# scripts/backup/gcs-restore.sh — C3I State Restore from Google Cloud Storage
# STAMP: SC-FUNC-003, SC-FUNC-004

set -euo pipefail

BUCKET="gs://indrajaal-c3i-state"
PROJECT_ROOT="/home/an/dev/ver/c3i"
RESTORE_DIR="/tmp/c3i-restore-$$"
SOURCE="${1:-latest}"  # "latest" or "daily/20260410-120000" or "weekly/20260407-000000"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  C3I STATE RESTORE FROM GOOGLE CLOUD STORAGE         ║"
echo "║  Source: ${SOURCE}                                    ║"
echo "╚═══════════════════════════════════════════════════════╝"

# --- Phase 1: Download ---
echo "⬇️  Phase 1: Downloading from GCS..."
mkdir -p "${RESTORE_DIR}"

if [ "$SOURCE" = "latest" ]; then
  gsutil cp "${BUCKET}/latest/c3i-state-latest.tar.zst" "${RESTORE_DIR}/archive.tar.zst"
  gsutil cp "${BUCKET}/latest/manifest.json" "${RESTORE_DIR}/manifest.json"
else
  gsutil cp "${BUCKET}/${SOURCE}/c3i-state.tar.zst" "${RESTORE_DIR}/archive.tar.zst"
  gsutil cp "${BUCKET}/${SOURCE}/manifest.json" "${RESTORE_DIR}/manifest.json"
fi

# Show manifest
echo "📋 Backup metadata:"
cat "${RESTORE_DIR}/manifest.json" | python3 -m json.tool 2>/dev/null || cat "${RESTORE_DIR}/manifest.json"
echo ""

# --- Phase 2: Decompress ---
echo "🗜️  Phase 2: Decompressing..."
cd "${RESTORE_DIR}"
zstd -d archive.tar.zst -o archive.tar
tar xf archive.tar
EXTRACTED=$(ls -d c3i-backup-* 2>/dev/null | head -1)

# --- Phase 3: Restore State ---
echo "📥 Phase 3: Restoring state..."

# Stop any running daemon
pkill -f sa-plan-daemon 2>/dev/null || true
sleep 1

# Ensure directories exist
mkdir -p "${PROJECT_ROOT}/data/smriti"
mkdir -p "${PROJECT_ROOT}/data/chaya"
mkdir -p "${PROJECT_ROOT}/sub-projects/c3i/data/smriti"
mkdir -p "${PROJECT_ROOT}/sub-projects/c3i/data/models"
mkdir -p "${PROJECT_ROOT}/sub-projects/c3i/data/metrics"
mkdir -p ~/.claude/projects/-home-an-dev-ver-c3i/memory

# Restore Tier 1 critical DBs
for db in Smriti.db planning.db holons.db core.db smriti.db; do
  src="${EXTRACTED}/smriti/${db}"
  [ -f "$src" ] && {
    cp "$src" "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/"
    echo "  ✅ ${db}"
  }
done

# Restore root-level DBs
[ -f "${EXTRACTED}/smriti/root-Smriti.db" ] && \
  cp "${EXTRACTED}/smriti/root-Smriti.db" "${PROJECT_ROOT}/data/smriti/Smriti.db"
[ -f "${EXTRACTED}/smriti/root-chaya.db" ] && \
  cp "${EXTRACTED}/smriti/root-chaya.db" "${PROJECT_ROOT}/data/chaya/chaya.db"

# Restore Tier 2
for f in analytics.duckdb telemetry.duckdb test_manager.db test_tracking.db todos.db model_registry.db api_usage.db; do
  src="${EXTRACTED}/smriti/${f}"
  [ -f "$src" ] && cp "$src" "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/"
done

# Restore config JSON
cp "${EXTRACTED}"/config/*.json "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/" 2>/dev/null || true
[ -f "${EXTRACTED}/config/current_genotype" ] && \
  cp "${EXTRACTED}/config/current_genotype" "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/"

# Restore Claude memory
cp "${EXTRACTED}"/memory/*.md ~/.claude/projects/-home-an-dev-ver-c3i/memory/ 2>/dev/null || true

# --- Phase 4: Verify ---
echo "🔍 Phase 4: Verifying..."
TASKS=$(sqlite3 "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/planning.db" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "FAIL")
PREFS=$(sqlite3 "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/Smriti.db" "SELECT COUNT(*) FROM UserPreferences;" 2>/dev/null || echo "FAIL")
echo "  Tasks: ${TASKS} | Preferences: ${PREFS}"

# --- Phase 5: Cleanup ---
rm -rf "${RESTORE_DIR}"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  RESTORE COMPLETE                                     ║"
echo "║  Tasks: ${TASKS} | Prefs: ${PREFS}                   ║"
echo "║  Next: cargo build --release && gleam build           ║"
echo "╚═══════════════════════════════════════════════════════╝"
```

---

## 5. Recovery Procedures

### 5.1 Full Recovery (Total Loss)

```bash
# Step 1: Fresh machine with Nix
sh <(curl -L https://nixos.org/nix/install) --daemon
nix-env -iA nixpkgs.direnv

# Step 2: Clone repo
git clone https://github.com/Anaik7799/c3i.git ~/dev/ver/c3i
cd ~/dev/ver/c3i

# Step 3: Enter dev environment
direnv allow  # or: nix develop

# Step 4: Authenticate GCS
gcloud auth login

# Step 5: Restore state
./scripts/backup/gcs-restore.sh latest

# Step 6: Build
cd sub-projects/c3i && cargo build --release && cd ../..
cd lib/cepaf_gleam && gleam build && cd ../..
NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
  ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" mix compile --jobs 16

# Step 7: Verify
./sa-plan status
# Expected: 2,669+ tasks, 133+ preferences
```

### 5.2 Partial Recovery (Corrupted DB)

```bash
# Restore only specific DB
gsutil cp gs://indrajaal-c3i-state/latest/c3i-state-latest.tar.zst /tmp/
cd /tmp && zstd -d c3i-state-latest.tar.zst && tar xf c3i-state-latest.tar
cp c3i-backup-*/smriti/Smriti.db ~/dev/ver/c3i/sub-projects/c3i/data/smriti/
```

### 5.3 Point-in-Time Recovery

```bash
# List available snapshots
gsutil ls gs://indrajaal-c3i-state/daily/

# Restore from specific date
./scripts/backup/gcs-restore.sh daily/20260409-120000
```

---

## 6. Automation

### 6.1 Cron Schedule

```bash
# Add to crontab -e
# Daily backup at 2:00 AM
0 2 * * * /home/an/dev/ver/c3i/scripts/backup/gcs-backup.sh >> /home/an/dev/ver/c3i/data/tmp/backup.log 2>&1

# Weekly integrity check (Sunday 3:00 AM)
0 3 * * 0 gsutil ls -l gs://indrajaal-c3i-state/latest/ >> /home/an/dev/ver/c3i/data/tmp/backup-verify.log 2>&1
```

### 6.2 Pre-Commit Hook (Optional)

```bash
# .git/hooks/pre-push — backup before push
#!/bin/bash
echo "Running state backup before push..."
./scripts/backup/gcs-backup.sh
```

### 6.3 sa-plan Integration

```bash
# Manual backup via CLI
./sa-plan backup       # → runs gcs-backup.sh
./sa-plan restore      # → runs gcs-restore.sh latest
./sa-plan restore --from daily/20260409-120000
```

---

## 7. Cost Estimate

| Storage | Size | Monthly Cost (Nearline) |
|---------|------|----------------------|
| Latest snapshot | ~30 MB | $0.003 |
| 30 daily snapshots | ~900 MB | $0.009 |
| 12 weekly snapshots | ~360 MB | $0.004 |
| **Total** | **~1.3 GB** | **~$0.016/month** |

---

## 8. Security

- GCS bucket: private (no public access)
- Authentication: gcloud OAuth2 (operator login)
- Encryption: GCS server-side encryption (AES-256) by default
- Sensitive data: API keys in Smriti.db are already encrypted (SC-OPENCLAW-001)
- Access log: GCS access logs enabled for audit trail

---

## 9. Prerequisites

Before first backup, the operator must:

1. **Authenticate gcloud**: `! gcloud auth login` (interactive browser login)
2. **Create GCS bucket**: Run the one-time setup commands from §4.1
3. **Install zstd**: Already in devenv.nix packages (via `nix develop`)
4. **Test**: Run `./scripts/backup/gcs-backup.sh` manually once
