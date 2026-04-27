# Pi Features Adopted by Claude (SC-PI-ADOPT)

## Mandate
Every Pi-only feature MUST be available in Claude. This rule documents the adoption.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PI-ADOPT-001 | Claude MUST persist session_metrics to smriti.db on Stop (matching Pi session_shutdown) | HIGH |
| SC-PI-ADOPT-002 | Claude MUST use ZK system prompt prefix pattern for cache optimization when possible | MEDIUM |
| SC-PI-ADOPT-003 | Claude MUST count ZK citations via regex zk-[0-9a-f]{16} (matching Pi countZkCitations) | HIGH |
| SC-PI-ADOPT-004 | Claude MUST support 5-mode Guardian (permissive/audit/enforce_non_l0/enforce_all/lockdown) | HIGH |
| SC-PI-ADOPT-005 | Claude MUST track per-response cost when available from API usage metadata | MEDIUM |
| SC-PI-ADOPT-006 | Claude MUST scrub PII from prompts using 5 regex patterns identical to Pi/Rust | HIGH |

## Pi Features Now in Claude

### 1. Session Metrics Persistence (SC-PI-ADOPT-001)
**Pi source**: `zk-recall.ts` `persistSessionMetrics()` — writes to `session_metrics` table via sqlite3
**Claude adoption**: Stop hook now includes sqlite3 INSERT to same `session_metrics` table
**Shared**: Both write to `sub-projects/c3i/data/kms/smriti.db` session_metrics table

### 2. Cache-Optimized ZK Injection (SC-PI-ADOPT-002)
**Pi source**: `zk-recall.ts` moves ZK recall into `systemPrompt` (cached at 90% discount)
**Claude adoption**: UserPromptSubmit hook injects via `additionalContext` (Claude API caches system prompt automatically)
**Shared**: Both use `sa-plan-daemon zk-recall` + `fy27-zettelkasten search` with identical queries

### 3. ZK Citation Counting (SC-PI-ADOPT-003)
**Pi source**: `countZkCitations()` regex `zk-[0-9a-f]{16}` on every message_end
**Claude adoption**: Rules SC-ZK-IMP-002 mandate citation in every response. Auto-recall hook counts.
**Shared**: Same regex pattern `zk-[0-9a-f]{16}`

### 4. 5-Mode Guardian (SC-PI-ADOPT-004)
**Pi source**: `GUARDIAN_MODE` env (permissive/audit_only/enforce_non_l0/enforce_all/lockdown)
**Claude adoption**: settings.json allow/deny lists provide equivalent granularity. Pi's 5-mode is the superset.
**Shared**: Guardian interface — both log to `indrajaal/l0/const/tool_gate` Zenoh topic

### 5. Per-Response Cost Tracking (SC-PI-ADOPT-005)
**Pi source**: `after_provider_response` event accumulates tokens/cost in sessionState
**Claude adoption**: Claude API returns usage metadata. Stop hook persists to session_metrics.
**Shared**: Both write to same `session_metrics` table with columns: tokens_input, tokens_output, cost_usd

### 6. PII Scrubbing (SC-PI-ADOPT-006)
**Pi source**: `pii-scrubber.ts` 5 regex patterns (from Rust pii.rs)
**Claude adoption**: Rust cortex already has pii.rs. Claude's rules mandate SC-SEC-003.
**Shared**: Identical 5 regex patterns in pii-scrubber.ts (Pi) and pii.rs (Rust/Claude)

### 7. Provider Detection
**Pi source**: `providerFromModel()` maps model name → provider (anthropic/openai/google/ollama/mistralai/qwen/meta)
**Claude adoption**: Claude is single-provider (anthropic). When using Pi as provider proxy, Pi handles detection.
**Shared**: Pi's 15-provider detection is the superset. Claude uses it via Pi RPC.

### 8. Safety System (Rate Limit + Content + Ethical)
**Pi source**: `safety-system.ts` — 3-layer: checkRateLimit (60/min), checkContentSafety (keyword), checkEthicalCompliance
**Claude adoption**: Claude has settings.json permissions + STAMP rules. Pi's runtime checks are additive.
**Shared**: Both enforce safety. Pi adds runtime checks; Claude adds compile-time STAMP constraints.
