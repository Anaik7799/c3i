#!/usr/bin/env bash
# C3I State Backup to Google Cloud Storage
# STAMP: SC-FUNC-003, SC-FUNC-004, SC-SMRITI-074
# Usage: ./scripts/backup/gcs-backup.sh [--dry-run]

set -euo pipefail

BUCKET="${C3I_GCS_BUCKET:-gs://indrajaal-c3i-state}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PROJECT_ROOT="${PROJECT_ROOT:-/home/an/dev/ver/c3i}"
BACKUP_DIR="/tmp/c3i-backup-${TIMESTAMP}"
DRY_RUN="${1:-}"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  C3I STATE BACKUP TO GOOGLE CLOUD STORAGE            ║"
echo "║  Timestamp: ${TIMESTAMP}                              ║"
echo "╚═══════════════════════════════════════════════════════╝"

mkdir -p "${BACKUP_DIR}/smriti" "${BACKUP_DIR}/config" "${BACKUP_DIR}/memory"

# --- Phase 1: Collect State ---
echo "📦 Phase 1: Collecting state files..."

# Tier 1: Critical DBs (WAL checkpoint for consistency)
for db in Smriti.db planning.db holons.db core.db smriti.db; do
  src="${PROJECT_ROOT}/sub-projects/c3i/data/smriti/${db}"
  [ -f "$src" ] && {
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
    cp "$src" "${BACKUP_DIR}/smriti/root-$(basename "$db")"
    echo "  ✅ root-$(basename "$db")"
  }
done

# Tier 2: DuckDB + auxiliary DBs
for f in analytics.duckdb telemetry.duckdb test_manager.db test_tracking.db todos.db; do
  src="${PROJECT_ROOT}/sub-projects/c3i/data/smriti/${f}"
  [ -f "$src" ] && cp "$src" "${BACKUP_DIR}/smriti/"
done

# Model registry & metrics
[ -f "${PROJECT_ROOT}/sub-projects/c3i/data/models/model_registry.db" ] && \
  cp "${PROJECT_ROOT}/sub-projects/c3i/data/models/model_registry.db" "${BACKUP_DIR}/smriti/"
[ -f "${PROJECT_ROOT}/sub-projects/c3i/data/metrics/api_usage.db" ] && \
  cp "${PROJECT_ROOT}/sub-projects/c3i/data/metrics/api_usage.db" "${BACKUP_DIR}/smriti/"

# Tier 3: JSON config state
for f in system_dna.json container_registry.json current_genotype captains_log.json multiverse_registry.json; do
  src="${PROJECT_ROOT}/sub-projects/c3i/data/smriti/${f}"
  [ -f "$src" ] && cp "$src" "${BACKUP_DIR}/config/"
done
cp "${PROJECT_ROOT}"/sub-projects/c3i/data/smriti/migration_session_*.json "${BACKUP_DIR}/config/" 2>/dev/null || true

# Claude memory
cp -r ~/.claude/projects/-home-an-dev-ver-c3i/memory/* "${BACKUP_DIR}/memory/" 2>/dev/null || true

# --- Phase 2: Manifest ---
echo "📋 Phase 2: Creating manifest..."
TASK_COUNT=$(sqlite3 "${BACKUP_DIR}/smriti/planning.db" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo 0)
PREF_COUNT=$(sqlite3 "${BACKUP_DIR}/smriti/Smriti.db" "SELECT COUNT(*) FROM UserPreferences;" 2>/dev/null || echo 0)

cat > "${BACKUP_DIR}/manifest.json" << MANIFEST
{
  "timestamp": "${TIMESTAMP}",
  "version": "22.5.0-CORTEX",
  "git_commit": "$(git -C "${PROJECT_ROOT}" rev-parse HEAD 2>/dev/null || echo "unknown")",
  "git_branch": "$(git -C "${PROJECT_ROOT}" branch --show-current 2>/dev/null || echo "unknown")",
  "file_count": $(find "${BACKUP_DIR}" -type f | wc -l),
  "total_size_bytes": $(du -sb "${BACKUP_DIR}" | cut -f1),
  "tasks": ${TASK_COUNT},
  "preferences": ${PREF_COUNT},
  "hostname": "$(hostname)"
}
MANIFEST

# --- Phase 3: Compress ---
echo "🗜️  Phase 3: Compressing..."
ARCHIVE="/tmp/c3i-backup-${TIMESTAMP}.tar.zst"
tar -C /tmp -cf - "c3i-backup-${TIMESTAMP}" | zstd -3 -T4 > "${ARCHIVE}"
ARCHIVE_SIZE=$(du -h "${ARCHIVE}" | cut -f1)
echo "  ✅ Archive: ${ARCHIVE_SIZE} (${TASK_COUNT} tasks, ${PREF_COUNT} prefs)"

if [ "${DRY_RUN}" = "--dry-run" ]; then
  echo "🏁 DRY RUN — skipping upload. Archive at: ${ARCHIVE}"
  rm -rf "${BACKUP_DIR}"
  exit 0
fi

# --- Phase 4: Upload ---
echo "☁️  Phase 4: Uploading to GCS..."
gsutil -q cp "${ARCHIVE}" "${BUCKET}/latest/c3i-state-latest.tar.zst"
gsutil -q cp "${BACKUP_DIR}/manifest.json" "${BUCKET}/latest/manifest.json"
gsutil -q cp "${ARCHIVE}" "${BUCKET}/daily/${TIMESTAMP}/c3i-state.tar.zst"
gsutil -q cp "${BACKUP_DIR}/manifest.json" "${BUCKET}/daily/${TIMESTAMP}/manifest.json"

if [ "$(date +%u)" = "1" ]; then
  gsutil -q cp "${ARCHIVE}" "${BUCKET}/weekly/${TIMESTAMP}/c3i-state.tar.zst"
  gsutil -q cp "${BACKUP_DIR}/manifest.json" "${BUCKET}/weekly/${TIMESTAMP}/manifest.json"
  echo "  ✅ Weekly snapshot saved"
fi

# --- Phase 5: Cleanup ---
rm -rf "${BACKUP_DIR}" "${ARCHIVE}"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  BACKUP COMPLETE — ${ARCHIVE_SIZE}                    ║"
echo "║  Tasks: ${TASK_COUNT} | Prefs: ${PREF_COUNT}          ║"
echo "║  GCS: ${BUCKET}/latest/                               ║"
echo "╚═══════════════════════════════════════════════════════╝"
