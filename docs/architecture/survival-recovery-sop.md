# C3I Survival & Recovery Standard Operating Procedure

**Version:** 1.0.0
**Date:** 2026-04-11
**Classification:** CRITICAL — SIL-6
**Author:** Claude Opus 4.6 + Abhijit Naik
**STAMP:** SC-FUNC-003, SC-FUNC-004, SC-SIL4-007, SC-SIL4-026, SC-XHOLON-030
**Last Verified:** 2026-04-11 (12/12 checks pass)

---

## 1. System Identity

| Attribute | Value |
|-----------|-------|
| System | C3I Indrajaal — Gleam-first Cybernetic Command-and-Control Cockpit |
| Version | v22.6.0-BRAIN |
| Primary Language | Gleam (BEAM VM) |
| Operations Language | Rust (sa-plan-daemon, 31 modules, 9,104 LOC) |
| Test Count | 3,786 passed, 0 failures |
| Knowledge Base | 2,060 holons, 6,647 STAMP refs, FTS5 indexed |
| Tasks | 2,710 (917 completed, 1,733 pending, 47 in_progress, 13 blocked) |
| Modules | 288 Gleam + 120 Rust + 746 F# (legacy) |
| Containers | 17 in SIL-6 Biomorphic Mesh |
| Git Remote | https://github.com/Anaik7799/c3i.git |
| GCS Backup | gs://indrajaal-c3i-backup-eu-north1/ |
| Operator Email | Abhijit.Naik@bountytek.com |
| Bot | @c3i_talk_bot (Telegram) |
| Location | Sweden (GDPR: europe-north1) |

---

## 2. What Must Survive

### Tier 1: CRITICAL — Loss = System Dead

| Asset | Location | Size | Content | Recovery Time |
|-------|----------|------|---------|---------------|
| **Smriti.db** | `sub-projects/c3i/data/smriti/Smriti.db` | 5.6 MB | 2,710 tasks, 85 traces, 293 cache, 32 conversations, 137 prefs | Minutes (restore from GCS) |
| **KMS holons** | `sub-projects/c3i/data/kms/smriti.db` | 9.2 MB | 2,060 holons, FTS5 index, knowledge graph | Minutes (restore) or 12.6s (re-ingest) |
| **planning.db** | `sub-projects/c3i/data/smriti/planning.db` | 312 KB | Planning state | Minutes (restore) |
| **core.db** | `sub-projects/c3i/data/smriti/core.db` | 6.5 MB | Core system state | Minutes (restore) |
| **holons.db** | `sub-projects/c3i/data/smriti/holons.db` | 19.2 MB | Legacy holon store | Minutes (restore) |
| **.env** | `.env` | 1 KB | TELEGRAM_TOKEN, API keys | Manual (recreate from Smriti secrets) |
| **Git repository** | GitHub + local | ~200 MB | ALL source code, docs, specs, journals | `git clone` (minutes) |

### Tier 2: HIGH — Loss = Degraded Operation

| Asset | Location | Size | Content |
|-------|----------|------|---------|
| SSL certificates | `lib/cepaf_gleam/priv/ssl/` | 3 KB | HTTPS for Mini App |
| analytics.duckdb | `sub-projects/c3i/data/smriti/` | varies | Analytics data |
| telemetry.duckdb | `sub-projects/c3i/data/smriti/` | varies | Telemetry history |
| model_registry.db | `sub-projects/c3i/data/models/` | varies | AI model metadata |
| api_usage.db | `sub-projects/c3i/data/metrics/` | varies | API usage tracking |
| chaya.db | `data/chaya/` | 48 KB | Digital twin state |
| Root Smriti.db | `data/smriti/Smriti.db` | 72 KB | Root-level state |

### Tier 3: MEDIUM — Loss = Manual Rebuild

| Asset | Location | Content |
|-------|----------|---------|
| 43 Allium specs | `specs/allium/` | Behavioral specifications |
| 5 TLA+ specs | `specs/tla/` | Formal verification |
| Wolfram spec | `specs/wolfram/` | Computational rules |
| Claude agent memory | `~/.claude/projects/.../memory/` | Session context |
| system_dna.json | `sub-projects/c3i/data/smriti/` | Genome config |

---

## 3. Backup Architecture

### 3.1 Backup Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    BACKUP ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  LOCAL                          REMOTE                           │
│  ├── SQLite DBs (WAL mode)      ├── GitHub (git push)           │
│  ├── .env (tokens)              ├── GCS europe-north1            │
│  ├── SSL certs                  │   ├── daily/ (90-day retain)  │
│  ├── Allium/TLA+ specs          │   └── versioning enabled      │
│  └── Claude memory              └── SMTP (email attachments)     │
│                                                                  │
│  BACKUP FLOW:                                                    │
│  1. sa-plan backup              → tar.zst → GCS upload           │
│  2. git push                    → GitHub remote                  │
│  3. sa-plan send-email          → attachment to operator email   │
│                                                                  │
│  RESTORE FLOW:                                                   │
│  1. git clone                   → source code + docs + specs     │
│  2. sa-plan restore             → GCS download → decompress      │
│  3. sa-plan ingest-docs         → re-index Zettelkasten (12.6s)  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Backup Methods

| Method | What | Where | Frequency | Retention |
|--------|------|-------|-----------|-----------|
| **GCS backup** | All DBs + specs + memory | `gs://indrajaal-c3i-backup-eu-north1/` | Daily (target) | 90 days |
| **Git push** | All source + docs + journals | GitHub `Anaik7799/c3i` | Every commit | Permanent |
| **SMTP email** | Key journals + architecture docs | Abhijit.Naik@bountytek.com | Per session | Email retention |
| **SQLite WAL** | Transaction durability | Local disk | Continuous | Until checkpoint |

### 3.3 GCS Backup Details

| Setting | Value |
|---------|-------|
| Bucket | `indrajaal-c3i-backup-eu-north1` |
| Region | EUROPE-NORTH1 (Finland — GDPR compliant) |
| Storage class | STANDARD |
| Versioning | Enabled (every upload creates a new version) |
| Lifecycle | Delete objects older than 90 days |
| Auth | OAuth2 refresh token in Smriti UserPreferences |
| Upload method | GCS JSON API via `reqwest` (direct HTTP, not gcloud CLI) |
| Compression | zstd (93.7 MB → 22.8 MB = 75.6% compression) |
| Integrity | SHA-256 per-file + archive-level hash |

### 3.4 Backup Contents (Current)

```
Archive: c3i-backup-20260411-073322.tar.zst (22.8 MB)
├── CRITICAL (8 files, ~42 MB uncompressed)
│   ├── sub-projects/c3i/data/smriti/Smriti.db       5.6 MB
│   ├── sub-projects/c3i/data/smriti/planning.db      312 KB
│   ├── sub-projects/c3i/data/smriti/holons.db        19.2 MB
│   ├── sub-projects/c3i/data/smriti/core.db          6.5 MB
│   ├── sub-projects/c3i/data/smriti/smriti.db        42.9 MB
│   ├── sub-projects/c3i/data/kms/smriti.db           9.2 MB
│   ├── data/smriti/Smriti.db                         72 KB
│   └── data/chaya/chaya.db                           48 KB
├── HIGH (7 files)
│   ├── lib/cepaf_gleam/priv/ssl/cert.pem             1 KB
│   ├── lib/cepaf_gleam/priv/ssl/key.pem              2 KB
│   ├── analytics.duckdb, telemetry.duckdb
│   └── model_registry.db, api_usage.db, test_*.db
├── MEDIUM (~1,100 files, ~40 MB uncompressed)
│   ├── 43 Allium specs
│   ├── 5 TLA+ specs
│   ├── Wolfram ruliology spec
│   ├── Formal specs
│   ├── Claude agent memory files
│   └── system_dna.json, container_registry.json
└── manifest.json (SHA-256 per file, metadata)
```

---

## 4. Failure Scenarios & Recovery Procedures

### 4.1 Scenario: Local Disk Failure (Total Loss)

**Impact:** ALL local data destroyed. System dead.

**Recovery Time:** ~30 minutes

**Procedure:**

```bash
# Step 1: Get a fresh machine (5 min)
# Ensure: Linux x86_64, 16GB RAM, NixOS or Ubuntu

# Step 2: Clone the repository (2 min)
git clone https://github.com/Anaik7799/c3i.git
cd c3i
git checkout v22.6.0-BRAIN

# Step 3: Install dependencies (10 min)
# If NixOS:
nix develop  # devenv.nix handles everything
# If Ubuntu:
# Install: erlang, gleam, rust, sqlite3, podman

# Step 4: Restore from GCS backup (5 min)
# Get OAuth token
export GOOGLE_CLIENT_ID="764086051850-..."
export GOOGLE_CLIENT_SECRET="d-FL95Q19q7MQmFpd7hHD0Ty"
export GOOGLE_REFRESH_TOKEN="1//0cZyeleFKrNmv..."

# Download latest backup
ACCESS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&refresh_token=${GOOGLE_REFRESH_TOKEN}&grant_type=refresh_token" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# List available backups
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://storage.googleapis.com/storage/v1/b/indrajaal-c3i-backup-eu-north1/o" \
  | python3 -c "import sys,json; [print(i['name']) for i in json.load(sys.stdin).get('items',[])]"

# Download the latest
LATEST=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://storage.googleapis.com/storage/v1/b/indrajaal-c3i-backup-eu-north1/o" \
  | python3 -c "import sys,json; items=json.load(sys.stdin).get('items',[]); print(items[-1]['name'] if items else '')")

curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://storage.googleapis.com/storage/v1/b/indrajaal-c3i-backup-eu-north1/o/${LATEST}?alt=media" \
  -o /tmp/restore.tar.zst

# Decompress and restore
cd /path/to/c3i
zstd -d /tmp/restore.tar.zst -o /tmp/restore.tar
tar xf /tmp/restore.tar

# Step 5: Verify SQLite integrity (1 min)
sqlite3 sub-projects/c3i/data/smriti/Smriti.db "PRAGMA integrity_check;"
sqlite3 sub-projects/c3i/data/kms/smriti.db "PRAGMA integrity_check;"

# Step 6: Rebuild and test (5 min)
cd lib/cepaf_gleam && gleam build && gleam test
cd ../../sub-projects/c3i/native/planning_daemon && cargo build --release

# Step 7: Re-ingest Zettelkasten (if KMS DB was not in backup)
./sub-projects/c3i/target/release/sa-plan-daemon ingest-docs

# Step 8: Verify
./sub-projects/c3i/target/release/sa-plan-daemon status
./sub-projects/c3i/target/release/sa-plan-daemon knowledge-search "system status"

# Step 9: Start services
cd lib/cepaf_gleam && gleam run -- --serve &  # Wisp HTTP on 4100
```

### 4.2 Scenario: Database Corruption (Single DB)

**Impact:** One SQLite DB corrupted. Partial degradation.

**Recovery Time:** ~5 minutes

**Procedure:**

```bash
# Step 1: Identify corrupted DB
sqlite3 sub-projects/c3i/data/smriti/Smriti.db "PRAGMA integrity_check;"
# If output != "ok" → corrupted

# Step 2: Restore single DB from GCS backup
# Download backup, extract only the corrupted file
tar xf /tmp/restore.tar sub-projects/c3i/data/smriti/Smriti.db

# Step 3: Verify
sqlite3 sub-projects/c3i/data/smriti/Smriti.db "PRAGMA integrity_check;"
sqlite3 sub-projects/c3i/data/smriti/Smriti.db "SELECT count(*) FROM Tasks;"

# Alternative: If KMS holons corrupted, re-ingest is faster than restore
./sub-projects/c3i/target/release/sa-plan-daemon ingest-docs  # 12.6 seconds
```

### 4.3 Scenario: GCS Credentials Expired

**Impact:** Cannot backup or restore from cloud. Local operation unaffected.

**Recovery Time:** ~10 minutes

**Procedure:**

```bash
# Step 1: Get new OAuth refresh token
# Go to: https://console.cloud.google.com/apis/credentials
# Download OAuth 2.0 Client ID JSON
# Run: gcloud auth application-default login

# Step 2: Update Smriti preferences
./sub-projects/c3i/target/release/sa-plan-daemon set-pref \
  -k google_oauth_refresh -v 'NEW_REFRESH_TOKEN' -C secrets

# Step 3: Test
./sub-projects/c3i/target/release/sa-plan-daemon backup --dry-run
```

### 4.4 Scenario: Git Remote Lost (GitHub Down)

**Impact:** Cannot push/pull. Local repo intact.

**Recovery Time:** Immediate (local work continues) + ~10 min (new remote)

**Procedure:**

```bash
# Local work continues unaffected

# Set up alternative remote
git remote add backup git@gitlab.com:anaik7799/c3i.git
git push backup main --tags

# Or create a new repo
gh repo create c3i-mirror --private
git remote add mirror https://github.com/Anaik7799/c3i-mirror.git
git push mirror main --tags
```

### 4.5 Scenario: Rust Binary Lost or Won't Build

**Impact:** sa-plan-daemon unavailable. Tasks, backup, email, ingestion down.

**Recovery Time:** ~3 minutes (rebuild)

**Procedure:**

```bash
# Rebuild from source
cd sub-projects/c3i/native/planning_daemon
cargo build --release

# If Rust toolchain missing
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
cargo build --release

# Verify
./target/release/sa-plan-daemon status
```

### 4.6 Scenario: Gleam Build Broken

**Impact:** UI, tests, knowledge modules unavailable.

**Recovery Time:** Diagnosis-dependent

**Procedure:**

```bash
# Step 1: Check error
cd lib/cepaf_gleam && gleam build 2>&1 | head -20

# Step 2: If dependency issue
gleam clean && gleam build

# Step 3: If code error — revert to last known good
git log --oneline -5
git checkout v22.6.0-BRAIN -- lib/cepaf_gleam/

# Step 4: Verify
gleam build && gleam test
```

### 4.7 Scenario: SMTP Credentials Invalid

**Impact:** Cannot send emails. All other operations normal.

**Recovery Time:** ~5 minutes

**Procedure:**

```bash
# Step 1: Generate new Gmail App Password
# Go to: https://myaccount.google.com/apppasswords
# Generate for "Mail" on "Linux"

# Step 2: Update Smriti
./sub-projects/c3i/target/release/sa-plan-daemon set-pref \
  -k gmail_app_password -v 'xxxx xxxx xxxx xxxx' -C secrets

# Step 3: Test
./sub-projects/c3i/target/release/sa-plan-daemon send-email \
  --to "Abhijit.Naik@bountytek.com" \
  --subject "SMTP Test" --body "Credentials updated."
```

### 4.8 Scenario: Telegram Bot Token Revoked

**Impact:** Bot commands and Mini App button stop working.

**Recovery Time:** ~10 minutes

**Procedure:**

```bash
# Step 1: Create new bot token via @BotFather
# /mybots → @c3i_talk_bot → API Token → Revoke → Generate new

# Step 2: Update .env
echo "TELEGRAM_TOKEN=NEW_TOKEN" >> .env

# Step 3: Update Smriti
./sub-projects/c3i/target/release/sa-plan-daemon set-pref \
  -k telegram_token -v 'NEW_TOKEN' -C secrets

# Step 4: Reconfigure Mini App Menu Button in BotFather
# /mybots → Bot Settings → Menu Button → set URL
```

### 4.9 Scenario: Container Mesh Won't Start

**Impact:** 17-container swarm not operational.

**Recovery Time:** ~10 minutes

**Procedure:**

```bash
# Step 1: Check Podman
podman ps -a
podman network ls | grep sil6

# Step 2: Recreate network if missing
podman network create indrajaal-sil6-mesh

# Step 3: Start swarm
./sa-up

# Step 4: If individual container fails
podman logs <container-name>
# Common fix: port conflict
podman rm <container-name>
# Restart with correct ports (see §OPS-M03 in use cases doc)

# Step 5: Verify
./sub-projects/c3i/target/release/sa-plan-daemon status
```

### 4.10 Scenario: Complete Disaster (Fire/Theft — All Local Hardware Lost)

**Impact:** Total loss of local infrastructure.

**Recovery Time:** ~1 hour (new machine setup)

**What survives:**
- GitHub repository (all code, docs, specs, journals) — PERMANENT
- GCS backup (all DBs, configs, certificates) — 90-day retention
- Email archives (key journals sent as attachments) — PERMANENT
- Smriti credentials (in GCS backup) — 90-day retention
- Operator's memory (documented in 180+ journal entries) — PERMANENT in Git

**What's lost:**
- Running container state (ephemeral — rebuilt from genome)
- In-progress Claude/Gemini sessions (context not persisted)
- Uncommitted code changes (always commit before ending session)

**Procedure:** Follow §4.1 (Total Disk Failure) on new hardware.

---

## 5. Backup Operations

### 5.1 Manual Backup

```bash
# Full backup to GCS
cd /home/an/dev/ver/c3i
./sub-projects/c3i/target/release/sa-plan-daemon backup

# Dry run (see what would be backed up)
./sub-projects/c3i/target/release/sa-plan-daemon backup --dry-run
```

### 5.2 Automated Daily Backup (Cron)

```bash
# Add to crontab -e
# Daily at 02:00 CEST
0 2 * * * cd /home/an/dev/ver/c3i && ./sub-projects/c3i/target/release/sa-plan-daemon backup >> /home/an/dev/ver/c3i/data/logs/backup.log 2>&1
```

### 5.3 Manual GCS Upload (When sa-plan backup Fails)

```bash
# Direct upload via GCS REST API
DB="sub-projects/c3i/data/smriti/Smriti.db"
CLIENT_ID=$(sqlite3 "$DB" "SELECT Value FROM UserPreferences WHERE Key='google_client_id';")
CLIENT_SECRET=$(sqlite3 "$DB" "SELECT Value FROM UserPreferences WHERE Key='google_client_secret';")
REFRESH_TOKEN=$(sqlite3 "$DB" "SELECT Value FROM UserPreferences WHERE Key='google_oauth_refresh';")

ACCESS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Create archive manually
tar cf - sub-projects/c3i/data/ data/smriti/ lib/cepaf_gleam/priv/ssl/ .env specs/ | zstd -3 > /tmp/manual-backup.tar.zst

# Upload
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
curl -X POST "https://storage.googleapis.com/upload/storage/v1/b/indrajaal-c3i-backup-eu-north1/o?uploadType=media&name=manual/${TIMESTAMP}/backup.tar.zst" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/tmp/manual-backup.tar.zst
```

### 5.4 Restore from GCS

```bash
# List available backups
./sub-projects/c3i/target/release/sa-plan-daemon restore list

# Restore latest
./sub-projects/c3i/target/release/sa-plan-daemon restore latest

# Restore specific backup
./sub-projects/c3i/target/release/sa-plan-daemon restore daily/20260411-073322
```

### 5.5 Verify Backup Integrity

```bash
# List GCS objects
DB="sub-projects/c3i/data/smriti/Smriti.db"
CLIENT_ID=$(sqlite3 "$DB" "SELECT Value FROM UserPreferences WHERE Key='google_client_id';")
CLIENT_SECRET=$(sqlite3 "$DB" "SELECT Value FROM UserPreferences WHERE Key='google_client_secret';")
REFRESH_TOKEN=$(sqlite3 "$DB" "SELECT Value FROM UserPreferences WHERE Key='google_oauth_refresh';")
ACCESS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://storage.googleapis.com/storage/v1/b/indrajaal-c3i-backup-eu-north1/o" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    size_mb = int(item.get('size', 0)) / 1024 / 1024
    print(f\"  {item['name']} — {size_mb:.1f} MB — {item['timeCreated']}\")
"

# Verify local DB integrity
for db in sub-projects/c3i/data/smriti/Smriti.db sub-projects/c3i/data/kms/smriti.db data/smriti/Smriti.db; do
  echo -n "$db: "
  sqlite3 "$db" "PRAGMA integrity_check;" 2>/dev/null || echo "NOT FOUND"
done
```

---

## 6. Credentials & Secrets Inventory

| Secret | Location | Purpose | Rotation |
|--------|----------|---------|----------|
| Telegram bot token | Smriti `telegram_token` | Bot API access | On compromise |
| Gmail app password | Smriti `gmail_app_password` | SMTP email | On compromise |
| Google OAuth client ID | Smriti `google_client_id` | GCS + Gmail API | Permanent |
| Google OAuth secret | Smriti `google_client_secret` | GCS + Gmail API | On compromise |
| Google OAuth refresh | Smriti `google_oauth_refresh` | Token refresh | On expiry |
| Gemini API key | Smriti `gemini_api_key` | Inference tier 1 | On compromise |
| Gemini Live API key | Smriti `gemini_api_key_live` | Voice WebSocket | On compromise |
| OpenRouter API key | Smriti `openrouter_api_key` | Inference tier 2 | On compromise |
| SSL cert + key | `priv/ssl/cert.pem` + `key.pem` | HTTPS Mini App | Annually (365 days) |

**All secrets are stored in Smriti.db UserPreferences table, backed up to GCS.**

**To regenerate all secrets from scratch:**
1. Telegram: @BotFather → /newbot or /token
2. Gmail: https://myaccount.google.com/apppasswords
3. Google OAuth: https://console.cloud.google.com/apis/credentials
4. Gemini: https://aistudio.google.com/app/apikey
5. OpenRouter: https://openrouter.ai/keys
6. SSL: `openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes`

---

## 7. Health Check Commands

### Quick Health (30 seconds)

```bash
cd /home/an/dev/ver/c3i

# 1. Can we build?
cd lib/cepaf_gleam && gleam build 2>&1 | tail -1

# 2. Do tests pass?
gleam test 2>&1 | tail -1

# 3. Is sa-plan operational?
cd ../.. && ./sub-projects/c3i/target/release/sa-plan-daemon status 2>&1 | grep "tasks"

# 4. Is Zettelkasten alive?
./sub-projects/c3i/target/release/sa-plan-daemon knowledge-search "health" -l 1 2>&1 | grep -v INFO

# 5. Can we send email?
# (skip in quick check — costs 1 second)
```

### Full Health (5 minutes)

Run the comprehensive verification suite from §12 of this session (12 checks covering build, tests, Rust, sa-plan, knowledge search, holons, Smriti data, GCS backup, SMTP, git, module coverage, HTTPS).

### Continuous Monitoring

```bash
# Heartbeat cron (every 10 minutes when daemon runs)
# The cortex heartbeat (heartbeat.rs) checks:
# 1. OODA cycle responsiveness
# 2. Zenoh mesh connectivity
# 3. SQLite integrity
# 4. Container health

# Manual: check daemon logs
journalctl -u sa-plan-daemon -f --no-pager
```

---

## 8. Disaster Recovery Drill

### Monthly DR Test Protocol

**Duration:** ~30 minutes
**Frequency:** Monthly
**Objective:** Verify complete system recovery from GCS backup

**Steps:**

```
1. BACKUP (2 min)
   sa-plan backup → verify GCS upload → note archive name

2. DESTROY (1 min)
   mv sub-projects/c3i/data/smriti/Smriti.db /tmp/dr-test-smriti.db
   mv sub-projects/c3i/data/kms/smriti.db /tmp/dr-test-kms.db
   # (move, don't delete — safety net)

3. VERIFY BROKEN (1 min)
   sa-plan status  → should fail (no DB)
   sa-plan knowledge-search "test"  → should fail

4. RESTORE (5 min)
   sa-plan restore latest
   # OR manual GCS download + decompress

5. VERIFY RESTORED (5 min)
   sqlite3 sub-projects/c3i/data/smriti/Smriti.db "PRAGMA integrity_check;"
   sqlite3 sub-projects/c3i/data/kms/smriti.db "PRAGMA integrity_check;"
   sa-plan status  → should show tasks
   sa-plan knowledge-search "apoptosis"  → should return results
   gleam test  → should pass

6. RE-INGEST (if KMS lost, 15 seconds)
   sa-plan ingest-docs

7. COMPARE (5 min)
   # Compare task counts, holon counts, preference counts
   # against pre-destroy values

8. CLEANUP (1 min)
   rm /tmp/dr-test-smriti.db /tmp/dr-test-kms.db

9. RECORD
   # Create journal entry with DR test results
   # Note any issues found
```

**Success Criteria:**
- [ ] All DBs restored with integrity_check = ok
- [ ] Task count matches pre-destroy
- [ ] Holon count matches pre-destroy (or re-ingested to same count)
- [ ] All 3,786 Gleam tests pass
- [ ] Knowledge search returns relevant results
- [ ] SMTP email sends successfully

---

## 9. Recovery Time Objectives

| Scenario | RTO | RPO | Method |
|----------|-----|-----|--------|
| Single DB corruption | 5 min | 0 (WAL) | Restore from GCS |
| Rust binary lost | 3 min | 0 | `cargo build --release` |
| Gleam build broken | 10 min | 0 | `git checkout` known tag |
| Local disk failure | 30 min | Last backup | GCS restore + rebuild |
| Complete disaster | 1 hour | Last backup | New machine + GCS + git clone |
| GCS unavailable | Immediate | 0 | Local operation continues |
| GitHub down | Immediate | 0 | Local operation continues |
| SMTP failure | 5 min | N/A | Regenerate app password |
| Telegram token revoked | 10 min | N/A | New token via BotFather |

**RPO (Recovery Point Objective):** Worst case = time since last GCS backup (target: daily = max 24h data loss).

**RTO (Recovery Time Objective):** Worst case = 1 hour for complete disaster on new hardware.

---

## 10. Contact & Escalation

| Level | Who | Contact | When |
|-------|-----|---------|------|
| L1 | System (automated) | Telegram @c3i_talk_bot | Proactive alerts via Three Voices |
| L2 | Operator | Abhijit.Naik@bountytek.com | SMTP alerts for P0/P1 |
| L3 | AI Assistant | Claude/Gemini session | Complex RCA, code fixes |

---

## 11. STAMP Compliance

| Constraint | How This SOP Addresses It |
|-----------|--------------------------|
| SC-FUNC-003 | Rollback path exists for every change (§4 recovery procedures) |
| SC-FUNC-004 | State recoverable from SQLite/DuckDB (§4.1 GCS restore) |
| SC-SIL4-007 | Dying gasp checkpoint before shutdown (backup before destructive ops) |
| SC-SIL4-026 | Rollback path with 24-hour window (GCS daily backup, 90-day retention) |
| SC-DELETE-001 | Untracked files backed up before deletion (GCS tier system) |
| SC-XHOLON-030 | Self-healing from SQLite alone (§4.2 single DB restore) |
| SC-SMRITI-074 | Immortality protocol atomic and complete (GCS + Git = two independent copies) |

---

## 12. Version History

| Date | Version | Change |
|------|---------|--------|
| 2026-04-11 | 1.0.0 | Initial SOP — 10 failure scenarios, GCS setup, DR drill protocol |
