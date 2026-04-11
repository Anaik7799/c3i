#!/usr/bin/env bash
# C3I State Restore from Google Cloud Storage
# STAMP: SC-FUNC-003, SC-FUNC-004
# Usage: ./scripts/backup/gcs-restore.sh [latest|daily/YYYYMMDD-HHMMSS|weekly/YYYYMMDD-HHMMSS]

set -euo pipefail

BUCKET="${C3I_GCS_BUCKET:-gs://indrajaal-c3i-state}"
PROJECT_ROOT="${PROJECT_ROOT:-/home/an/dev/ver/c3i}"
RESTORE_DIR="/tmp/c3i-restore-$$"
SOURCE="${1:-latest}"

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
elif [ "$SOURCE" = "list" ]; then
  echo "Available backups:"
  echo "=== Daily ==="
  gsutil ls "${BUCKET}/daily/" 2>/dev/null || echo "  (none)"
  echo "=== Weekly ==="
  gsutil ls "${BUCKET}/weekly/" 2>/dev/null || echo "  (none)"
  rm -rf "${RESTORE_DIR}"
  exit 0
else
  gsutil cp "${BUCKET}/${SOURCE}/c3i-state.tar.zst" "${RESTORE_DIR}/archive.tar.zst"
  gsutil cp "${BUCKET}/${SOURCE}/manifest.json" "${RESTORE_DIR}/manifest.json"
fi

echo "📋 Backup manifest:"
python3 -m json.tool "${RESTORE_DIR}/manifest.json" 2>/dev/null || cat "${RESTORE_DIR}/manifest.json"
echo ""

# --- Phase 2: Decompress ---
echo "🗜️  Phase 2: Decompressing..."
cd "${RESTORE_DIR}"
zstd -d archive.tar.zst -o archive.tar
tar xf archive.tar
EXTRACTED=$(ls -d c3i-backup-* 2>/dev/null | head -1)

if [ -z "$EXTRACTED" ]; then
  echo "❌ No backup data found in archive"
  exit 1
fi

# --- Phase 3: Stop services ---
echo "🛑 Phase 3: Stopping services..."
pkill -f sa-plan-daemon 2>/dev/null || true
sleep 1

# --- Phase 4: Restore ---
echo "📥 Phase 4: Restoring state..."

mkdir -p "${PROJECT_ROOT}/data/smriti"
mkdir -p "${PROJECT_ROOT}/data/chaya"
mkdir -p "${PROJECT_ROOT}/sub-projects/c3i/data/smriti"
mkdir -p "${PROJECT_ROOT}/sub-projects/c3i/data/models"
mkdir -p "${PROJECT_ROOT}/sub-projects/c3i/data/metrics"
mkdir -p ~/.claude/projects/-home-an-dev-ver-c3i/memory

# Critical DBs
for db in Smriti.db planning.db holons.db core.db smriti.db; do
  src="${EXTRACTED}/smriti/${db}"
  [ -f "$src" ] && {
    cp "$src" "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/"
    echo "  ✅ ${db}"
  }
done

# Root DBs
[ -f "${EXTRACTED}/smriti/root-Smriti.db" ] && {
  cp "${EXTRACTED}/smriti/root-Smriti.db" "${PROJECT_ROOT}/data/smriti/Smriti.db"
  echo "  ✅ root-Smriti.db"
}
[ -f "${EXTRACTED}/smriti/root-chaya.db" ] && {
  cp "${EXTRACTED}/smriti/root-chaya.db" "${PROJECT_ROOT}/data/chaya/chaya.db"
  echo "  ✅ root-chaya.db"
}

# Auxiliary DBs
for f in analytics.duckdb telemetry.duckdb test_manager.db test_tracking.db todos.db model_registry.db api_usage.db; do
  src="${EXTRACTED}/smriti/${f}"
  [ -f "$src" ] && cp "$src" "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/"
done

# Config JSON
cp "${EXTRACTED}"/config/*.json "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/" 2>/dev/null || true
[ -f "${EXTRACTED}/config/current_genotype" ] && \
  cp "${EXTRACTED}/config/current_genotype" "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/"

# Claude memory
cp "${EXTRACTED}"/memory/*.md ~/.claude/projects/-home-an-dev-ver-c3i/memory/ 2>/dev/null || true
echo "  ✅ Claude memory"

# --- Phase 5: Verify ---
echo "🔍 Phase 5: Verifying integrity..."
TASKS=$(sqlite3 "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/planning.db" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "FAIL")
PREFS=$(sqlite3 "${PROJECT_ROOT}/sub-projects/c3i/data/smriti/Smriti.db" "SELECT COUNT(*) FROM UserPreferences;" 2>/dev/null || echo "FAIL")

echo "  Tasks: ${TASKS} | Preferences: ${PREFS}"

# Integrity checks
for db in Smriti.db planning.db holons.db core.db smriti.db; do
  dbpath="${PROJECT_ROOT}/sub-projects/c3i/data/smriti/${db}"
  [ -f "$dbpath" ] && {
    result=$(sqlite3 "$dbpath" "PRAGMA integrity_check;" 2>/dev/null || echo "FAIL")
    if [ "$result" = "ok" ]; then
      echo "  ✅ ${db} integrity: OK"
    else
      echo "  ❌ ${db} integrity: FAILED"
    fi
  }
done

# --- Cleanup ---
rm -rf "${RESTORE_DIR}"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  RESTORE COMPLETE                                     ║"
echo "║  Tasks: ${TASKS} | Prefs: ${PREFS}                   ║"
echo "║                                                       ║"
echo "║  Next steps:                                          ║"
echo "║  1. cd sub-projects/c3i && cargo build --release      ║"
echo "║  2. cd lib/cepaf_gleam && gleam build                 ║"
echo "║  3. mix compile --jobs 16                             ║"
echo "║  4. ./sa-plan status                                  ║"
echo "╚═══════════════════════════════════════════════════════╝"
