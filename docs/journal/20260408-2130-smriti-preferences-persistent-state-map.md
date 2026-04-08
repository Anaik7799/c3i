# Journal: Smriti Preferences Population + Persistent State Map

**Date**: 2026-04-08T21:30Z
**STAMP**: SC-HOLON-009, SC-FUNC-004, SC-STATE-001, SC-MCP-001

---

## 1. Scope & Trigger

User requested: (1) Full system pass with all important datapoints identified, (2) Populate Smriti with comprehensive system state, (3) Map all persistent state locations, (4) Send status to Google Chat.

## 2. Pre-State Assessment

Smriti had 4 preferences (telegram_token, telegram_bot_name, primary_google_account, gchat_webhook). No toolchain, hardware, artifact, infrastructure, or git state was tracked. System config was scattered across env vars, hardcoded values, and undocumented sources.

## 3. Execution Detail

### 3.1 Smriti UserPreferences: 4 → 73

Populated 73 preferences across 13 categories by scanning:
- Environment variables for secrets/keys
- Git config for identity/remote
- `/proc` and system tools for hardware specs
- `--version` commands for all toolchain components
- TCP probes for infrastructure live state
- File system for artifact counts and binary sizes
- SQLite queries for database sizes

### 3.2 Categories Populated

| Category | Count | Source Method |
|----------|-------|--------------|
| identity | 7 | Git config, Google account, Telegram |
| gateway | 2 | GChat webhook, Telegram chat ID |
| infrastructure | 7 | Port configs, DB paths, service URLs |
| infra_state | 9 | TCP probes to 7447/7448/7449/5433/11434/4317/4100 |
| system | 8 | Test results, version, component counts |
| toolchain | 7 | `--version` for Gleam/OTP/Rust/Node/.NET/Podman/Playwright |
| hardware | 5 | `nproc`, `free -h`, `df -h`, `uname -r` |
| artifacts | 12 | `find` + `wc -l` across all source directories |
| binaries | 4 | `ls -lh` on .so and daemon binaries |
| databases | 3 | `ls -lh` on Smriti/Chaya databases |
| agent | 3 | Model selection for Claude/Gemini/Ollama |
| secrets | 1 | Telegram bot token (pre-existing) |
| git | 5 | `git log`, `git remote`, `du -sh` |

### 3.3 Persistent State Map — 7 Tiers

#### Tier 1: Authoritative Databases (P0-P1)
| Database | Size | Purpose |
|----------|------|---------|
| `sub-projects/c3i/data/smriti/Smriti.db` | 388K | Tasks (886) + UserPreferences (73) + EventLog |
| `sub-projects/c3i/data/smriti/smriti.db` | 43M | Full Smriti knowledge graph |
| `sub-projects/c3i/data/smriti/holons.db` | 20M | Holon sovereign state |
| `sub-projects/c3i/data/smriti/core.db` | 6.6M | KMS core catalog |
| `sub-projects/c3i/data/smriti/planning.db` | 312K | Planning history |
| `sub-projects/c3i/data/chaya/chaya.db` | 756K | Digital twin state |
| `sub-projects/c3i/lib/cepaf/artifacts/cepa-state.db` | 18M | F# orchestrator state |
| `sub-projects/c3i/lib/cepaf/artifacts/build-history.db` | 100K | Build EMA timing |

#### Tier 2: Specifications & Rules (Git-tracked)
- `specs/allium/` — 39 behavioral specs, 9,841 lines
- `specs/tla/` — TLA+ formal proofs (LeaderElection.tla)
- `.claude/rules/` — 56 STAMP constraint files
- `.claude/agents/` — 29 agent definitions
- `CLAUDE.md` — System guidance v22.3.0-GLM

#### Tier 3: Documentation & Journals (Git-tracked)
- `docs/journal/` — 149 session journals (13-section format)
- `docs/plans/` — Implementation plans
- `docs/architecture/` — Architecture documents
- `docs/GLEAM_UI_DEVELOPMENT_PROMPT.md` — Dev prompt v22.3.0-GLM

#### Tier 4: Build Artifacts (Regenerable)
- `lib/cepaf_gleam/priv/c3i_nif.so` — 2.8M unified NIF
- `lib/cepaf_gleam/priv/planning_nif.so` — 13M planning NIF
- `lib/cepaf_gleam/priv/rule_engine_nif.so` — 1.8M RETE-UL
- `sub-projects/c3i/target/release/sa-plan-daemon` — 15M daemon

#### Tier 5: Runtime State (Ephemeral)
- Per-node holon DBs (`data/smriti/*/holons.db` — 6 nodes)
- Metrics DB (`data/metrics/api_usage.db`)
- Monitoring DB (`data/monitoring/tricameral_monitor.db`)
- Governance DB (`data/governance/tricameral.db`)
- Evolution DB (`data/evolution/tricameral_evolution.db`)
- UTLTS DB (`data/holons/test/utlts.db` — 46M)
- Guardian proposals (`data/holons/guardian/proposals.db`)
- ~30 test evolution DBs (`data/test_evolution_*.db`)

#### Tier 6: Backups & Checkpoints
- `sub-projects/c3i/backups/mesh-state-*/` — Full mesh snapshots
- `sub-projects/c3i/data/checkpoints/*/` — Timestamped checkpoints
- `sub-projects/c3i/backup/smriti/` — Smriti backup snapshots
- `data/tmp/backup/` — Deletion safeguard backups (SC-DELETE-003)

#### Tier 7: AI Agent State
- `.claude/settings.local.json` — Claude permissions
- `.gemini/settings.json` — Gemini config
- `~/.claude/projects/.../memory/` — Claude persistent memory (5 files)

### 3.4 Google Chat Integration
- Webhook stored in Smriti as `gchat_webhook`
- Full system status sent via `sa-plan-daemon gateway --channel gchat`
- Messages dispatched in <1s

## 4. Root Cause Analysis

System configuration was fragmented across:
- Environment variables (volatile, lost on shell exit)
- Hardcoded constants in Rust/Gleam/Erlang source
- Git config (local, not portable)
- Undocumented tribal knowledge

Smriti.db UserPreferences provides a single queryable source of truth per SC-HOLON-009.

## 5. Fix Taxonomy

| Category | Action |
|----------|--------|
| Data population | 69 new preferences added to Smriti |
| Documentation | This journal maps all 7 tiers of persistent state |
| Integration | GChat webhook stored for automated messaging |
| Verification | TCP probes confirm live infrastructure state |

## 6. Patterns & Anti-Patterns Discovered

**Pattern (GOOD)**: Smriti UserPreferences as system config store — single `SELECT` query for any parameter. Categories provide namespace isolation.

**Pattern (GOOD)**: `infra_state` category captures point-in-time liveness probes. Can be refreshed by any agent to get current infrastructure health.

**Anti-Pattern**: ~30 orphaned `test_evolution_*.db` files in `data/` — test evolution runs that created DBs without cleanup. Should be periodically purged (Muda — inventory waste).

**Anti-Pattern**: Multiple copies of holons.db across 6+ node directories — each 112K with identical schema. Federation state should use version vectors, not file copies.

## 7. Verification Matrix

| Check | Result |
|-------|--------|
| Smriti preferences count | 73 |
| Categories | 13 |
| GChat message sent | ✅ (838ms) |
| Gleam server running | ✅ (port 4100) |
| Ollama running | ✅ (port 11434) |
| Zenoh routers | ❌ (7447/7448/7449 all down) |
| Postgres | ❌ (5433 down) |
| OTel collector | ❌ (4317 down) |

## 8. Files Modified

- `sub-projects/c3i/data/smriti/Smriti.db` — 69 new UserPreferences rows (not git-tracked, contains secrets)
- `docs/journal/20260408-2130-smriti-preferences-persistent-state-map.md` — this journal

## 9. Architectural Observations

The persistent state architecture follows the Holon sovereignty model (SC-HOLON-009):
- **Authoritative state**: SQLite/DuckDB files per holon
- **Derived artifacts**: PROJECT_TODOLIST.md, compiled binaries
- **Ephemeral state**: TCP connections, process PIDs, Zenoh sessions
- **Immutable state**: Git history, journal entries, Allium specs

The total persistent state across all databases is approximately **180MB**, with the largest being the UTLTS test tracking DB (46M) and the knowledge graph (43M).

## 10. Remaining Gaps

- `telegram_chat_id` is empty — needs user to provide their Telegram chat ID
- No `openrouter_api_key` stored (was in env var, expired or unset)
- No `github_token` for API access (PR creation, issue management)
- No `google_oauth_refresh` for Workspace API (Sheets, Docs, Slides)
- `infra_state` is static — should be refreshed automatically on session start
- ~30 orphaned `test_evolution_*.db` files consuming ~3MB (Muda: inventory waste)

## 11. Metrics Summary

| Metric | Before | After |
|--------|--------|-------|
| Smriti preferences | 4 | **73** |
| Categories | 3 | **13** |
| System datapoints tracked | ~4 | **73** |
| Persistent state tiers documented | 0 | **7** |
| Databases inventoried | 0 | **90+** |
| GChat messages sent | 0 | **2** |

## 12. STAMP & Constitutional Alignment

| Constraint | Status |
|-----------|--------|
| SC-HOLON-009 | COMPLIANT — SQLite is authoritative source for all preferences |
| SC-FUNC-004 | COMPLIANT — State recoverable from SQLite/DuckDB |
| SC-STATE-001 | COMPLIANT — Atomic state updates via SQLite UPSERT |
| SC-MCP-001 | ADVANCING — All 73 preferences queryable via sa-plan-daemon |

## 13. Conclusion

Populated 73 system preferences into Smriti.db across 13 categories, establishing a single source of truth for all system configuration. Mapped 7 tiers of persistent state (authoritative databases → specs → docs → build artifacts → runtime → backups → agent state) covering 90+ database files totaling ~180MB. Google Chat integration verified via sa-plan-daemon gateway. Infrastructure probes show Gleam server and Ollama running; Zenoh/Postgres/OTel are down (expected in dev environment without full mesh boot).
