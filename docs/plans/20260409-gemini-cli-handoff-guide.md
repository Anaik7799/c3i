# Gemini CLI Handoff Guide: sa-plan-daemon Development

**Date**: 2026-04-09
**Purpose**: Enable the Gemini CLI agent to continue development of the `sa-plan-daemon` Rust binary
**STAMP**: SC-TODO-001, SC-COG-001, SC-OPENCLAW-001

---

## 1. System Overview

### What is sa-plan-daemon?

`sa-plan-daemon` is the Rust binary that serves as the **pre-frontal cortex** of the Indrajaal C3I system. It runs as a long-lived daemon process, subscribing to the Zenoh mesh for intent routing, and processing commands from Telegram, Google Chat, and MCP tool calls.

### Location

```
native/planning_daemon/
  src/           -- 27 source files, 7,245 LOC total
  Cargo.toml     -- dependency manifest
  target/        -- build output
```

### Build

```bash
cd native/planning_daemon
cargo build --release
```

The release binary is at `target/release/sa-plan-daemon`. A wrapper script at the repo root (`./sa-plan`) delegates to it.

### Run Modes

```bash
# Daemon mode: connects to Zenoh mesh, polls Telegram/GChat, processes intents
sa-plan-daemon daemon

# Simulation test: starts HTTP mock server + runs 400 scenarios
sa-plan-daemon sim-test --port 9999 --duration-secs 120

# Preflight checks: verifies Smriti.db, Zenoh, API keys
sa-plan-daemon preflight

# Task management (these work without daemon mode)
sa-plan-daemon status
sa-plan-daemon add "Task description" P1
sa-plan-daemon update <task-id> completed
sa-plan-daemon list pending
sa-plan-daemon list in_progress
```

### Run Tests

```bash
cd native/planning_daemon
cargo test
```

---

## 2. File Map

Every `.rs` file with its purpose and line count:

| File | Lines | Purpose |
|------|-------|---------|
| **cortex.rs** | 1,063 | Main processing loop. Subscribes to Zenoh `indrajaal/l5/cog/intent/**` and `indrajaal/l5/cog/mcp/req/plan/**`. Intent classifier dispatches to: voice handler, slash commands (/status, /email, /trace, etc.), MCP tools, and text inference cascade. Also starts Telegram/GChat polling supervisors, inference warmup, and keepalive ping loop. |
| **cli.rs** | 969 | CLI subcommands: `daemon`, `sim-test`, `preflight`, `status`, `add`, `update`, `list`, `send-email`, `smoke-test`. Contains the 400-scenario simulator orchestration and preflight check logic. |
| **types.rs** | 850 | All MCP types (`McpRequest`, `McpResponse`, `McpError`), `PlanningMethod` enum, container constants (ports, timeouts, health check intervals, CPU governor thresholds, BIST parameters). Also `GenomeEntry`, `BootTier`, `HealthStatus`, `ImageCategory` ADTs mirrored from F#. |
| **db.rs** | 728 | SQLite operations against `data/smriti/Smriti.db`. 7 tables: `Tasks`, `UserPreferences`, `TransactionTrace`, `TransactionSummary`, `SemanticCache`, `ConversationHistory`, plus the existing Smriti tables. WAL mode, exponential backoff with jitter for lock contention, 5s busy timeout. |
| **mcp_inference.rs** | 581 | 6-tier hedged inference engine. Persistent `OnceLock<reqwest::Client>` for TLS session reuse. Circuit breakers per tier (3 failures = 60s cooldown). Hedged parallel requests (Gemini Direct and OpenRouter race, first wins). Voice processing with 5-tier cascade. 30s keepalive pings. |
| **mcp_gworkspace.rs** | 380 | Gmail SMTP send (`send-email` subcommand), OAuth token refresh via `gcloud auth`, Google Chat webhook delivery. Parallel delivery to Telegram + GChat via `broadcast_message()`. |
| **ingress_polling.rs** | 331 | Telegram long-polling (getUpdates API) and GChat polling via GCP Pub/Sub. Voice message detection: downloads OGG file, base64-encodes, publishes to Zenoh. Offset persistence to Smriti for restart resilience. 3-retry Zenoh publish with dead letter logging. |
| **simulator.rs** | 280 | HTTP mock server for `sim-test`. 400 scenarios covering: text commands, slash commands (/status, /email, /containers, /trace), voice messages, GChat messages, edge cases. Listens on configurable port, mimics Telegram Bot API responses. |
| **trace.rs** | 241 | `PipelineTracer` struct for per-intent transaction tracing. Records stages (classify, inference, delivery) with latency. Persists to `TransactionTrace` and `TransactionSummary` tables. History query and statistics aggregation. |
| **main.rs** | 233 | CLI entry point using `clap`. Defines subcommands: `daemon`, `status`, `add`, `update`, `list`, `preflight`, `sim-test`, `send-email`, `smoke-test`. Initializes `env_logger`. |
| **gemini_live.rs** | 227 | Gemini 3.1 Flash Live WebSocket client. OGG-to-PCM conversion via ffmpeg, WebSocket session management, audio chunk streaming (8KB), response collection (inputTranscription + modelTurn). |
| **errors.rs** | 218 | `IgnitionError` enum: `InternalError`, `SqliteError`, `ZenohError`, `TimeoutError`, `ValidationError`. Implements `Display`, `From<rusqlite::Error>`, etc. |
| **smoke_test.rs** | 171 | `smoke-test` subcommand: end-to-end verification of daemon health. Checks Smriti.db connectivity, task CRUD, preference read/write, inference cascade warm-up. |
| **gateway.rs** | 148 | Parallel delivery to Telegram + GChat. `broadcast_message(text, emergency)` sends to all configured channels. Retry logic with 3 attempts. SMTP email delivery via `mcp_gworkspace`. |
| **supervisor.rs** | 111 | Supervisor restart logic for polling services. Wraps `tokio::spawn` with crash detection and exponential backoff restart (5s delay). |
| **audit_log.rs** | 100 | Append-only audit log for security-critical operations. Writes to `data/smriti/audit.log` with timestamp, action, actor, and result. |
| **zenoh_telemetry.rs** | 91 | Zenoh session management. Publishes heartbeat to `indrajaal/cortex/health` every 10s. State vector publishing for HA leader election. |
| **markdown.rs** | 90 | `PROJECT_TODOLIST.md` generator. Reads tasks from Smriti.db and renders markdown. Called after every task mutation to keep the derived file in sync. |
| **ha_election.rs** | 81 | High-availability leader election via Zenoh lease on `indrajaal/l4/system/leader_lease`. Mutual exclusion over Smriti.db writes. |
| **mcp_file.rs** | 59 | MCP `read_file` tool: reads file contents with path validation and size limit (1MB). |
| **math_monitor.rs** | 57 | Mathematical discipline monitoring. Shannon entropy, CCM, ITQS computation for test quality metrics. |
| **command_verifier.rs** | 61 | Validates command syntax before execution. Prevents injection attacks in shell-delegated commands. |
| **mcp_sys.rs** | 49 | MCP system tools: `podman_containers` (list all running containers via `podman ps`). |
| **mcp_web.rs** | 45 | MCP web tools: `web_search` and `fetch_url` for internet access from the cortex. |
| **mcp_browser.rs** | 28 | Browser automation stub. Placeholder for headless Chrome integration. |
| **heartbeat.rs** | 30 | Proactive heartbeat service. Publishes daemon liveness to Zenoh every 10 seconds. |
| **tui.rs** | 23 | TUI dashboard stub. Placeholder for Ratatui-based terminal dashboard. |

---

## 3. Current Gaps to Address

### 3.1 Gemini Live WS "Internal error" on Setup

**Priority**: P1
**File**: `gemini_live.rs`

The Live WS API returns `{"error": "Internal error"}` instead of `setupComplete`. This may be caused by:
- Model name mismatch (`gemini-3.1-flash-live-preview` may have changed)
- Missing or incorrect `generationConfig` fields
- API key permission scope

**Action**: Test with different model names. Check the Gemini API changelog for breaking changes. Try removing `systemInstruction` from the setup message to isolate the issue.

### 3.2 Voice Test Suite

**Priority**: P1
**File**: New test module needed

No automated voice tests exist. Plan:
1. Source WAV samples from `voxserv/audio_quality_testing_samples` or similar corpus
2. Convert to OGG Opus, base64 encode
3. Add voice scenarios to `simulator.rs` (currently only text scenarios)
4. Assert transcription quality, latency bounds, and accent profile accumulation

### 3.3 Rate Limiting per User

**Priority**: P2
**File**: `cortex.rs`

Currently no per-user rate limiting. A single user could flood the system with voice messages. Implement:
- Token bucket per `chat_id` (e.g., 10 messages/minute)
- Graceful "slow down" response when exceeded
- Store rate limit state in Smriti or in-memory `DashMap`

### 3.4 Semantic Caching for Voice Transcriptions

**Priority**: P2
**File**: `db.rs`, `mcp_inference.rs`

The `SemanticCache` table exists but is not used for voice transcriptions. Similar voice messages (e.g., "check status") could hit the cache instead of re-running the full cascade.

**Approach**: Hash the first 100 chars of the transcription (not the audio) and check cache before Stage 2 inference.

### 3.5 RAG Pipeline

**Priority**: P2
**Files**: `cortex.rs`, `db.rs`, new module

The Smriti knowledge graph (documents, preferences, task history) is not wired into the inference prompt. Implement:
- Vector embedding of Smriti documents (use Ollama `nomic-embed-text` or similar)
- Semantic search on user prompt before inference
- Inject top-3 relevant context chunks into the Stage 2 prompt

### 3.6 DuckDB Analytics for Percentile Latency

**Priority**: P3
**File**: `db.rs` or new `analytics.rs`

The `TransactionTrace` and `TransactionSummary` tables contain rich latency data. DuckDB could compute:
- P50/P95/P99 latency per tier
- Success rate per model over time
- Voice vs text latency comparison
- Cache hit rate trends

### 3.7 Conversation History Context Window Management

**Priority**: P2
**File**: `db.rs`, `cortex.rs`

Currently, the last 50 messages per `chat_id` are retained, and 10 are loaded for context. For long conversations, this is not enough context. Implement:
- Summarize messages older than the last 10 into a single "conversation summary"
- Store the summary in a separate column or table
- Include summary + last 10 messages in inference prompt
- Use a smaller model (gemma3) for summarization to save cost

---

## 4. Key Design Decisions

### 4.1 SQLite for All Hot-Path Writes

**Decision**: Use SQLite for tasks, preferences, traces, semantic cache, and conversation history. Not DuckDB, not RocksDB.

**Rationale**:
- WAL mode provides concurrent read/write with low latency
- Single-file database, trivially backed up and restored
- Exponential backoff with jitter handles lock contention gracefully
- Schema migrations are idempotent (`CREATE TABLE IF NOT EXISTS`)
- DuckDB is reserved for read-heavy analytics queries (not yet implemented)

### 4.2 Hedged Parallel Requests

**Decision**: Fire Gemini Direct AND OpenRouter simultaneously; first success wins.

**Rationale**:
- Reduces tail latency: if one provider is slow, the other wins
- Channel-based (`tokio::sync::mpsc`): first result returns immediately
- Both results are collected; failures are tracked per-tier circuit breaker
- Cost is doubled per request, but latency improvement is significant for interactive use

### 4.3 Circuit Breakers with 60s Cooldown

**Decision**: After 3 consecutive failures, skip the tier for 60 seconds.

**Implementation**: `CircuitBreaker` struct with `AtomicU32` failure counter and `AtomicU64` last failure epoch. Lock-free, no mutex.

**States**:
- **Closed** (failures < 3): Requests pass through normally
- **Open** (failures >= 3, within 60s): Requests are skipped
- **Half-open** (failures >= 3, after 60s): One request allowed; success resets, failure extends

### 4.4 Persistent OnceLock HTTP Client

**Decision**: Single `reqwest::Client` shared across all tiers via `OnceLock`.

**Rationale**:
- TLS sessions are reused (no cold TLS handshake per request)
- Connection pool: 4 idle connections per host
- TCP keepalive: 30s
- 30s background keepalive ping keeps TLS warm (fires to Gemini and OpenRouter)

### 4.5 2-Stage Voice Processing

**Decision**: Separate audio transcription from text inference.

**Rationale**: Gemini's `systemInstruction` is effectively ignored when audio `inline_data` is present. The model cannot follow the full system prompt (Gmail access, Zenoh commands, etc.) alongside audio. By splitting into two stages:
- Stage 1 gets the best possible transcription (audio-focused)
- Stage 2 gets the best possible response (text-focused, full context)

### 4.6 30s Keepalive Ping

**Decision**: Background task pings Gemini and OpenRouter every 30 seconds with minimal tokens.

**Rationale**: Keeps TLS sessions warm. Without this, the first request after idle time incurs a ~200-500ms TLS handshake penalty.

### 4.7 Safe String Truncation

**Decision**: The `trunc()` function walks backward to find a valid UTF-8 char boundary.

**Rationale**: Standard Rust `&s[..n]` panics if `n` lands in a multi-byte character. This was discovered in production when a Hindi/Devanagari voice transcription triggered a panic.

---

## 5. Smriti Preferences Reference

All keys read/written by `sa-plan-daemon`:

| Key | Category | Type | Purpose |
|-----|----------|------|---------|
| `gemini_api_key` | `agent` | String | Google AI Studio API key for Gemini models |
| `openrouter_api_key` | `agent` | String | OpenRouter API key for hedged LLM requests |
| `telegram_token` | `infra_state` | String | Telegram Bot API token |
| `telegram_poll_offset` | `infra_state` | Integer (as string) | Last processed Telegram update ID (persisted for restart) |
| `gcp_project_id` | `infra_state` | String | Google Cloud project ID for GChat Pub/Sub |
| `gcp_pubsub_subscription` | `infra_state` | String | GCP Pub/Sub subscription name for GChat polling |
| `voice_accent_profile` | `agent` | String | Pipe-separated accent learning samples from voice transcriptions |
| `system_prompt_override` | `agent` | String | Optional override for the default SYSTEM_PROMPT |
| `inference_model` | `agent` | String | Override default inference model |
| `gchat_webhook_url` | `infra_state` | String | Google Chat space webhook URL for response delivery |
| `gmail_sender` | `agent` | String | Gmail sender address for SMTP delivery |
| `gmail_app_password` | `agent` | String | Gmail app-specific password for SMTP auth |

### Preference Categories

| Category | Purpose |
|----------|---------|
| `agent` | AI/LLM-related settings (API keys, models, learning profiles) |
| `infra_state` | Infrastructure state (polling offsets, connection tokens) |
| `user` | User-facing preferences |
| `system` | System configuration |

### API

```rust
// Read
db::get_preference("gemini_api_key") -> Result<Option<String>, IgnitionError>

// Write
db::set_preference("voice_accent_profile", "Sample: hello world", "agent") -> Result<(), IgnitionError>

// List all in category
db::list_preferences(Some("agent")) -> Result<Vec<(String, String, String)>, IgnitionError>
// Returns: Vec<(key, value, category)>
```

---

## 6. STAMP Constraints Reference

Constraints directly relevant to sa-plan-daemon development:

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-TODO-001 | All task management via sa-plan-daemon exclusively | CRITICAL | No direct file edits to PROJECT_TODOLIST.md |
| SC-COG-001 | Neuromorphic intent routing via Zenoh | CRITICAL | cortex.rs subscribes to `indrajaal/l5/cog/intent/**` |
| SC-OPENCLAW-001 | Voice processing with offline fallback | CRITICAL | 5-tier cascade, Tier 3 always works |
| SC-SAFETY-022 | Emergency stop < 5 seconds | CRITICAL | /emergency command broadcasts P0 alert |
| SC-ZMOF-001 | Zenoh is sole transport for internal mesh | CRITICAL | All intents via Zenoh pub/sub, not HTTP |
| SC-HA-001 | Zero-downtime evolution | CRITICAL | Leader election via Zenoh lease |
| SC-XHOLON-001 | Isolated database files, WAL mode | CRITICAL | db.rs uses WAL, 5s busy timeout |
| SC-XHOLON-030 | No data loss on crash | CRITICAL | WAL mode + exponential backoff |
| SC-API-001 | Backoff and rate limiting | HIGH | Circuit breakers, hedged requests |
| SC-MUDA-001 | Zero compilation warnings | HIGH | `cargo build` must produce 0 warnings |
| SC-ARCH-SPLIT-001 | Monitoring + ops = Rust only | CRITICAL | sa-plan-daemon is Rust, UI is Gleam |
| SC-ARCH-SPLIT-003 | Bridge via NIF/Zenoh/CLI only | HIGH | Gleam calls sa-plan via CLI or Zenoh |

### Key AOR Rules

| ID | Rule |
|----|------|
| AOR-FUNC-001 | VERIFY compilation before ANY code commit |
| AOR-ZENOH-001 | NEVER set SKIP_ZENOH_NIF=1 in production |
| AOR-DELETE-001 | ALWAYS backup before deleting files |
| AOR-IGNITE-005 | Tier boot failures MUST halt the pipeline |

---

## 7. Architecture Context

### How sa-plan-daemon Fits in the System

```
                    +--------------------------+
                    |   16-Container SIL-6     |
                    |   Biomorphic Mesh        |
                    |   (Podman + Zenoh)       |
                    +--------+-----------------+
                             |
                     Zenoh PubSub
                             |
                    +--------v-----------------+
                    |   sa-plan-daemon          |  <-- YOU ARE HERE
                    |   (Rust, long-lived)      |
                    |                           |
                    |   Subscribes:             |
                    |     indrajaal/l5/cog/**   |
                    |                           |
                    |   Publishes:              |
                    |     indrajaal/cortex/**   |
                    |     indrajaal/plan/**     |
                    +--------+-----------------+
                             |
                    +--------v-----------------+
                    |   External APIs           |
                    |   - Gemini (Direct + Live)|
                    |   - OpenRouter            |
                    |   - Ollama (local)        |
                    |   - Telegram Bot API      |
                    |   - GChat Pub/Sub         |
                    |   - Gmail SMTP            |
                    +--------------------------+
```

### Data Flow for a Typical Voice Message

```
1. User sends voice note in Telegram
2. ingress_polling.rs: downloads OGG, base64-encodes, publishes to Zenoh
3. cortex.rs: receives intent, detects type="voice"
4. cortex.rs: loads accent_profile from Smriti
5. mcp_inference.rs: 5-tier voice cascade (Live WS -> REST -> Whisper -> rule ack)
6. cortex.rs: extracts transcription, saves accent sample
7. cortex.rs: runs transcript through text inference cascade with full system context
8. cortex.rs: saves to ConversationHistory
9. gateway.rs: broadcasts response to Telegram + GChat
10. trace.rs: records pipeline latency to TransactionTrace
```

### Database Schema (Smriti.db)

Tables managed by sa-plan-daemon (all created idempotently):

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `Tasks` | Task management (todolist) | Id, Title, Status, Priority, ParentId, Owner, Created |
| `UserPreferences` | Key-value configuration store | Key, Value, Category, UpdatedAt |
| `TransactionTrace` | Per-stage latency tracing | intent_id, stage, tier, latency_ms, success |
| `TransactionSummary` | Per-intent summary | intent_id, source, total_latency_ms, tier_used, tiers_tried |
| `SemanticCache` | LLM response cache | prompt_hash, response, model_used, ttl_secs, hit_count |
| `ConversationHistory` | Per-chat message log | chat_id, role, content, timestamp_ms |
| `AuditLog` | Security audit trail | timestamp, action, actor, result |

---

## 8. Development Workflow

### Building

```bash
cd native/planning_daemon
cargo build --release 2>&1 | tail -5
# Must produce 0 warnings (SC-MUDA-001)
```

### Testing

```bash
cd native/planning_daemon
cargo test
```

### Running Locally

```bash
# Set minimum required preferences in Smriti.db first:
# gemini_api_key, telegram_token (or set SIMULATOR_TELEGRAM_URL for mock)

# With real Zenoh:
./target/release/sa-plan-daemon daemon

# With simulator (no external dependencies):
./target/release/sa-plan-daemon sim-test --port 9999 --duration-secs 120
```

### Adding a New Feature

1. Identify the relevant file from the file map (Section 2)
2. Check STAMP constraints (Section 6) for applicable rules
3. Implement with zero warnings
4. Add tests in the same file or a new test module
5. Run `cargo test` and `cargo build --release`
6. Test manually with `sim-test` or `daemon` mode

### Adding a New MCP Tool

1. Create handler function in the appropriate `mcp_*.rs` file
2. Register the tool name in `cortex.rs` `handle_mcp_request()` dispatch
3. Add the tool to the MCP queryable response in `start_mcp_queryable()`
4. Add simulator scenarios in `simulator.rs`
5. Document the tool in CLAUDE.md Section 5.0

### Adding a New Slash Command

1. Add pattern match in `cortex.rs` at the slash command section (~line 300+)
2. Implement the handler (inline or in a separate function)
3. Add to the `SYSTEM_PROMPT` in `mcp_inference.rs` so the LLM knows about it
4. Add simulator scenario in `simulator.rs`

---

## 9. Dependency Highlights

Key crates used (from Cargo.toml):

| Crate | Purpose |
|-------|---------|
| `zenoh` | Mesh pub/sub communication |
| `tokio` | Async runtime (multi-threaded) |
| `reqwest` | HTTP client for API calls |
| `rusqlite` | SQLite database access |
| `serde` / `serde_json` | JSON serialization |
| `clap` | CLI argument parsing |
| `chrono` | Timestamps |
| `uuid` | Unique identifiers for intents |
| `base64` | Audio encoding for voice |
| `tokio-tungstenite` | WebSocket client for Gemini Live |
| `futures-util` | Stream/Sink extensions for WebSocket |
| `log` / `env_logger` | Logging |
| `rand` | Jitter for exponential backoff |

---

## 10. Quick Reference Card

| Task | Command |
|------|---------|
| Build | `cargo build --release` |
| Test | `cargo test` |
| Run daemon | `sa-plan-daemon daemon` |
| Run sim-test | `sa-plan-daemon sim-test --port 9999 --duration-secs 120` |
| Preflight | `sa-plan-daemon preflight` |
| Task status | `sa-plan-daemon status` |
| Add task | `sa-plan-daemon add "Description" P1` |
| Update task | `sa-plan-daemon update <id> completed` |
| List tasks | `sa-plan-daemon list pending` |
| Send email | `sa-plan-daemon send-email "to@example.com" "subject" "body"` |
| Smoke test | `sa-plan-daemon smoke-test` |
| Logs | `RUST_LOG=info sa-plan-daemon daemon` |
| Debug logs | `RUST_LOG=debug sa-plan-daemon daemon` |
