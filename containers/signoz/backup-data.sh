#!/bin/bash
# Backup SigNoz data
# Usage: ./backup-data.sh [backup-name]

BACKUP_NAME="${1:-signoz-backup-$(date +%Y%m%d-%H%M%S)}"
BACKUP_DIR="/home/an/dev/indrajaal-demo/data/signoz/backups/$BACKUP_NAME"

echo "🔄 SigNoz Data Backup"
echo "════════════════════════════════════════════════════════════════"
echo "Backup name: $BACKUP_NAME"
echo "Backup location: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup ClickHouse data
echo "📦 Backing up ClickHouse data..."
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_traces FORMAT JSONEachRow" > "$BACKUP_DIR/traces.jsonl" 2>/dev/null
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_metrics FORMAT JSONEachRow" > "$BACKUP_DIR/metrics.jsonl" 2>/dev/null
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_logs FORMAT JSONEachRow" > "$BACKUP_DIR/logs.jsonl" 2>/dev/null

# Backup database schema
echo "📦 Backing up database schema..."
podman exec signoz-clickhouse clickhouse-client --query \
  "SHOW CREATE TABLE signoz.signoz_traces" > "$BACKUP_DIR/schema_traces.sql"
podman exec signoz-clickhouse clickhouse-client --query \
  "SHOW CREATE TABLE signoz.signoz_metrics" > "$BACKUP_DIR/schema_metrics.sql"
podman exec signoz-clickhouse clickhouse-client --query \
  "SHOW CREATE TABLE signoz.signoz_logs" > "$BACKUP_DIR/schema_logs.sql"

# Backup configuration files
echo "📦 Backing up configuration files..."
cp -r config "$BACKUP_DIR/"

# Create backup metadata
cat > "$BACKUP_DIR/metadata.json" << METADATA
{
  "backup_name": "$BACKUP_NAME",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "containers": {
    "clickhouse": "$(podman inspect signoz-clickhouse --format '{{.Image}}')",
    "otel-collector": "$(podman inspect signoz-otel-collector --format '{{.Image}}')",
    "query-service": "$(podman inspect signoz-query-service --format '{{.Image}}')",
    "frontend": "$(podman inspect signoz-frontend --format '{{.Image}}')"
  }
}
METADATA

echo ""
echo "✅ Backup completed successfully!"
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Backup contents:"
ls -lh "$BACKUP_DIR"
