# Journal: FerrisKey IAM Fractal Analysis — Use Cases, Data Flows, Control Flows & Implications Across L0-L7

**Date**: 2026-04-19
**Version**: v22.11.0-FERRISKEY-FRACTAL
**Session Type**: Comprehensive Fractal Analysis
**ZK Recall**: [zk-8662c18a370ce077] fractal layer coverage matrix pattern. [zk-bf35f7e5373c218a] full fractal analysis with institutional knowledge. [zk-03d2bc227da29769] anti-pattern: egress-only for Google.

---

## 1. Scope & Trigger

Comprehensive fractal analysis of the FerrisKey IAM + Google Cloud Service Directory + Cloud IAM integration across all 8 fractal layers (L0-L7). This journal details every use case with: functionality provided, data flow, control flow, expected improvements, and implications at each layer.

**System Under Analysis**: 19 containers, 31 Rust modules (9,104 LOC), 283+ Gleam modules (~42,000 LOC), 73 MCP tools, 8 Zenoh topic families, 3,206 lines of fractal safety kernel code.

---

## 2. Fractal Layer Coverage Tensor

### 2.1 Auth Feature x Layer Matrix

```
                    L0    L1    L2    L3    L4    L5    L6    L7
                   CONST  DBG   COMP  TXNL  SYS   COG   ECO   FED
                   ─────  ─────  ─── ─────  ─────  ─── ─────  ─────
OIDC JWT Valid.     ██     ░░    ░░    ░░    ░░    ██    ░░    ░░
RBAC Fractal Map    ██     ██    ██    ██    ██    ██    ██    ██
MFA Enforcement     ██     ░░    ░░    ░░    ░░    ░░    ░░    ░░
Token Exchange      ██     ░░    ░░    ░░    ░░    ░░    ░░    ██
Service Directory   ░░     ░░    ░░    ░░    ██    ░░    ██    ██
Cloud IAM (WIF)     ██     ░░    ░░    ░░    ██    ░░    ██    ░░
Webhook→Zenoh       ░░     ██    ░░    ░░    ░░    ░░    ██    ░░
Audit Events        ██     ██    ░░    ██    ░░    ░░    ██    ░░
Dark Cockpit        ░░     ░░    ░░    ░░    ░░    ██    ░░    ░░
Health Cascade      ██     ██    ██    ██    ██    ██    ██    ██
Guard Grid          ██     ██    ██    ██    ██    ██    ██    ██
Google SSO          ██     ░░    ██    ░░    ░░    ░░    ░░    ██
                   ─────  ─────  ─── ─────  ─────  ─── ─────  ─────
Coverage:           9/12   5/12  3/12  4/12  5/12  5/12  6/12  5/12

██ = directly impacted    ░░ = indirectly impacted or no impact
```

**Total cells filled: 42/96 = 43.8% direct impact across 12 features x 8 layers**

---

## 3. L0 Constitutional — Identity Is Constitutional

### 3.1 What Exists at L0

The L0 Constitutional layer (275 lines, 9 types, 19 functions) enforces:
- **Guardian Approval**: HITL gate with 2oo3 quorum consensus (SC-SIL4-006)
- **Psi Invariants**: 6 constitutional axioms (Psi-0 Existence through Psi-5 Truthfulness)
- **Emergency Stop**: Armed/triggered state machine with reason logging
- **Consensus Voting**: Multiple guardians cast votes, threshold depends on severity

### 3.2 Use Cases at L0

#### UC-L0-001: Guardian Approval with OIDC Identity

**Functionality**: Guardian approval requests now carry authenticated identity. Before FerrisKey, any holder of the static token could approve. Now, only `c3i-admin` with verified MFA can approve Critical operations.

**Data Flow**:
```
Operator clicks "Approve" on L0 Guardian panel
    │
    ▼
POST /api/v1/guardian/respond
    │ Authorization: Bearer <ferriskey-jwt>
    │ Body: { request_id: "req-001", decision: "approve", confirmation: "CONFIRM" }
    │
    ▼
auth.gleam: validate_request(request)
    │ FERRISKEY_ENABLED=true → oidc.validate_token(jwt)
    │ → TokenClaims { sub: "user-1", roles: ["c3i-admin"], acr: "mfa:totp" }
    │
    ▼
rbac.authorize_layer_access(user, L0Constitutional)
    │ can_access_layer(FullAccess, L0) → True
    │ require_mfa_for_layer(L0) → True
    │ has_mfa(claims) → True (acr contains "mfa")
    │ → Ok(Nil) ✓ Authorized
    │
    ▼
l0_constitutional.resolve_request(state, "req-001", Approved)
    │ → ApprovalState with request moved to history
    │
    ▼
Zenoh publish:
    ├─ indrajaal/otel/spans/auth/guardian/approved
    ├─ indrajaal/l0/const/approval/req-001
    └─ indrajaal/auth/admin/action (webhook → bridge → Zenoh)
```

**Control Flow**:
```
Request arrives
    ▼
is_mutation(POST)? → Yes
    ▼
validate_request() → AuthenticatedOidc(claims)?
    ├─ Unauthenticated → 401 { error: "no_token" }
    ├─ InvalidToken(r) → 401 { error: r }
    └─ AuthenticatedOidc(claims) ▼
        authorize_layer_access(user, L0Constitutional)?
            ├─ insufficient_permission → 403 { error: "insufficient_permission" }
            ├─ mfa_required → 403 { error: "mfa_required", hint: "enroll TOTP in FerrisKey" }
            └─ Ok(Nil) → proceed to Guardian logic
                ▼
            guardians_for_severity(Critical) → 3 required
                ▼
            cast_vote(consensus, user.sub, VoteApprove)
                ▼
            evaluate_consensus() → ConsensusApproved | ConsensusIncomplete | ConsensusRejected
```

**Improvement**: Before: anyone with static token = God mode. After: named identity, MFA verified, quorum tracked, audit trail.

**Implications**:
- All existing L0 operations now require FerrisKey JWT when `FERRISKEY_ENABLED=true`
- Emergency stop requires admin + MFA — intentional friction for safety
- Psi invariant changes are auditable to specific human identity
- Consensus votes tied to `sub` claim — no anonymous voting
- Guard grid L0 cell `[guardian]` now validates auth before recording verdict

#### UC-L0-002: Emergency Stop with Verified Identity

**Functionality**: Emergency stop (`POST /api/v1/emergency/trigger`) now requires named admin identity with MFA. The trigger reason includes who triggered it.

**Data Flow**:
```
Operator triggers emergency stop
    │ POST /api/v1/emergency/trigger
    │ Authorization: Bearer <jwt with c3i-admin + mfa>
    │ Body: { reason: "cascade failure detected", confirmation: "EMERGENCY" }
    │
    ▼
auth → rbac.authorize_layer_access(user, L0Constitutional) → Ok(Nil)
    │
    ▼
l0_constitutional.trigger_emergency(state, reason_with_identity, timestamp)
    │ → EmergencyState { armed: True, triggered: True,
    │     trigger_reason: Some("cascade failure detected [by: admin@bountytek.com]") }
    │
    ▼
MoZ publish: indrajaal/mcp/req/emergency_stop/{id}
    │ (broadcasts to all 19 containers via Zenoh)
    │
    ▼
Zenoh events:
    ├─ indrajaal/l0/const/emergency/triggered
    ├─ indrajaal/auth/admin/action (identity: admin, action: emergency_stop)
    └─ indrajaal/otel/spans/auth/emergency
```

**Improvement**: Accountability. "Who pulled the emergency stop?" is now answered by JWT `sub` + `preferred_username` in the audit trail.

#### UC-L0-003: Psi Invariant Verification with Auth Context

**Functionality**: Psi invariant checks (Psi-0 through Psi-5) now include auth verification as part of Psi-5 (Truthfulness) — the system verifies its own identity plane is functioning.

**Data Flow**:
```
Health cascade check_cascade()
    │ L0 checks:
    │   ├─ Psi-0 (Existence): system_health NIF returns data
    │   ├─ Psi-1 (Regeneration): SQLite WAL intact
    │   ├─ Psi-2 (History): immutable register has entries
    │   ├─ Psi-3 (Verification): STAMP constraints validated
    │   ├─ Psi-4 (Human Alignment): HINT sections preserved
    │   └─ Psi-5 (Truthfulness): FerrisKey healthy + JWKS cached
    │
    ▼
New Psi-5 sub-check: FerrisKey health
    │ HTTP GET http://ferriskey:8080/health
    │ Expected: { status: "ok" }
    │ If unhealthy → Psi-5 Warning (not Fail — graceful degradation)
```

**Improvement**: Identity plane health is now a constitutional invariant. If FerrisKey goes down, the system enters degraded mode (static token fallback) but Psi-5 emits a Warning — operator is notified.

---

## 4. L1 Atomic/Debug — Auth Telemetry

### 4.1 What Exists at L1

L1 (118 lines, 4 types, 9 functions): OTel trace spans, event monitoring, debug probes. Bounded buffer (500 entries).

### 4.2 Use Cases at L1

#### UC-L1-001: Auth Event Telemetry via OTel Spans

**Functionality**: Every authentication event produces an OTel span published to Zenoh. This enables distributed tracing of auth flows across the mesh.

**Data Flow**:
```
JWT validation in auth.gleam
    │
    ▼
zenoh_otel.publish_span(Auth, "validate_token")
    │ OtelSpan {
    │   trace_id: request_trace_id,
    │   span_id: generated,
    │   name: "auth.validate_token",
    │   ooda_phase: Observe,
    │   page: Auth,
    │   element: "oidc_validation",
    │   duration_us: validation_time,
    │   attributes: { user: claims.sub, roles: claims.roles, mfa: has_mfa }
    │ }
    │
    ▼
Zenoh topic: indrajaal/otel/spans/auth/validate_token
    │
    ▼
Consumers:
    ├─ obs-prod (Prometheus/Grafana): auth latency histogram
    ├─ Dashboard WebSocket: real-time auth activity feed
    └─ TUI split-screen: auth event counter
```

**Improvement**: Before: no visibility into auth operations. After: every JWT validation is traced with sub-millisecond timing, user identity, and MFA status.

**Implications**:
- L1 EventMonitorState gains auth-typed events (filter by "auth.*")
- TraceSpan attributes include FerrisKey-specific fields (sub, roles, acr)
- 500-entry buffer may need increase if auth events are high-frequency (e.g., polling)

#### UC-L1-002: Gemini Voice Auth Attribution

**Functionality**: Voice pipeline (gemini_live.rs, 307 lines) now attributes transcription requests to authenticated users.

**Data Flow**:
```
Voice input (microphone)
    │
    ▼
gemini_live.rs: WebSocket to Gemini Live
    │ (API key from FerrisKey vault instead of Smriti.db)
    │
    ▼
Transcription response
    │
    ▼
OTel span: indrajaal/otel/spans/voice/transcription
    │ attributes: { user: claims.sub, duration_ms: 250, tier: 1 }
    │
    ▼
Cost attribution: Gemini API usage tracked per user identity
```

**Improvement**: Per-user cost tracking for Gemini API calls. Before: aggregate usage. After: `c3i-admin` vs `c3i-operator` usage breakdown.

---

## 5. L2 Component — Auth UI Components

### 5.1 What Exists at L2

L2 (112 lines): Reusable forms, data grids, badges, buttons, inputs. A2UI catalog (233 component types).

### 5.2 Use Cases at L2

#### UC-L2-001: Auth Badge Components

**Functionality**: Permission-level badges rendered in Lustre SSR pages. 5 visual states matching RBAC levels.

**Data Flow**:
```
AuthenticatedUser { permission: FullAccess }
    │
    ▼
lustre/auth.gleam: rbac_card(model)
    │ → span([class("badge badge-admin")], [text("full_access")])
    │
    ▼
CSS classes:
    badge-admin    → red gradient (L0 access)
    badge-operator → amber gradient (L1-L7)
    badge-viewer   → green gradient (L4-L7)
    badge-service  → purple gradient (L3-L6)
    badge-none     → gray (no access)
```

**Improvement**: Visual RBAC — operator sees their exact permission level and accessible layers at a glance.

#### UC-L2-002: Fractal Layer Access Chips

**Functionality**: Colored chips showing which fractal layers the current user can access.

**Data Flow**:
```
rbac.accessible_layers(OperatorAccess)
    │ → [L1, L2, L3, L4, L5, L6, L7]  (7 layers)
    │
    ▼
list.map: span([class("chip layer-chip")], [text("L1")])
    │ → 7 green chips + 1 gray chip (L0 inaccessible)
    │
    ▼
TUI equivalent (auth_view.gleam):
    │ L0  L1  L2  L3  L4  L5  L6  L7
    │ [░░] [██] [██] [██] [██] [██] [██] [██]
    │  gray  green across accessible layers
```

**Improvement**: Self-service permission visibility. No need to ask admin "what can I access?"

#### UC-L2-003: "Sign in with Google" Button (Planned)

**Functionality**: A2UI catalog component for Google SSO initiation. Redirects to FerrisKey -> Google OIDC flow.

**Improvement**: One-click authentication for Google Workspace users.

---

## 6. L3 Transaction — Auth State Management

### 6.1 What Exists at L3

L3 (144 lines): State diff viewer, tool invocation panel, command history. SQLite/Smriti.db state sovereignty.

### 6.2 Use Cases at L3

#### UC-L3-001: Credential Migration from Smriti.db to FerrisKey Vault

**Functionality**: API keys, passwords, and OAuth tokens currently stored in Smriti.db (SQLite) migrate to FerrisKey's encrypted vault.

**Data Flow**:
```
Before:
    sa-plan-daemon → db.get_preference("gemini_api_key") → Smriti.db → plaintext key

After:
    sa-plan-daemon → auth.rs::OidcClient::get_token() → FerrisKey JWT
    → FerrisKey vault lookup by client attribute → encrypted key
    → returned in custom claim or via dedicated API
```

**Control Flow**:
```
Credential needed
    │
    ▼
FERRISKEY_ENABLED?
    ├─ No: db.get_preference("key_name") → Smriti.db (current behavior)
    └─ Yes: FerrisKey client attribute lookup
        │ GET /admin/realms/c3i-dev/clients/{client-id}
        │ → response.attributes.gemini_api_key
        │
        ▼
    Cache in OnceLock (Rust) or persistent_term (BEAM)
```

**Improvement**: Credentials encrypted at rest in FerrisKey PostgreSQL. Key rotation via admin console without code deploy. Audit trail for credential access.

**Implications**:
- Smriti.db "secrets" category becomes backup only
- `db.get_preference` calls for credentials wrapped in FerrisKey-first fallback
- Migration is additive — Smriti.db values preserved as fallback

#### UC-L3-002: Token Exchange as Transaction

**Functionality**: Telegram token exchange (RFC 8693) is a multi-step transaction: validate HMAC → build exchange body → POST to FerrisKey → parse response → return JWT.

**Data Flow**:
```
Telegram Mini App
    │ POST /api/v1/auth/telegram
    │ Body: { init_data: "...", telegram_user_id: 12345, telegram_username: "abhijit" }
    │
    ▼
Step 1: telegram/auth.gleam → validate_hmac(init_data, bot_token)
    │ → Authenticated(TelegramUser { id: 12345, username: "abhijit" })
    │
    ▼
Step 2: token_exchange.gleam → build_exchange_body(12345, "abhijit", client_id, secret)
    │ → form-encoded: grant_type=urn:ietf:params:oauth:grant-type:token-exchange&...
    │
    ▼
Step 3: POST http://ferriskey:8080/realms/c3i-dev/protocol/openid-connect/token
    │ Body: exchange request
    │ → { access_token: "<jwt>", expires_in: 3600, refresh_token: "<rt>" }
    │
    ▼
Step 4: parse_exchange_response(body) → ExchangeResponse
    │
    ▼
Return JWT to Telegram Mini App
    │ { access_token: "<jwt>", token_type: "Bearer", expires_in: 3600 }
```

**Improvement**: Telegram users get full FerrisKey identity with RBAC (default: c3i-viewer). Before: Telegram users had no persistent identity or role.

#### UC-L3-003: Audit Log Transaction Tracing

**Functionality**: Every auth decision (approve/deny) logged to Smriti.db via PipelineTracer for transaction-level audit.

**Data Flow**:
```
Auth decision made
    │
    ▼
PipelineTracer.add_stage("auth", stage_data)
    │ (zero DB writes during processing — in-memory Vec)
    │
    ▼
PipelineTracer.finish_with_zenoh()
    │ Batch write to SQLite: TransactionTrace table
    │ Publish to Zenoh: indrajaal/l5/cog/trace/{id}
    │ Footer: "Pipeline: auth(2ms) > validate(5ms) > rbac(1ms) > respond(8ms)"
```

**Improvement**: Auth decisions are part of the pipeline trace — visible in the same trace viewer as inference and planning operations.

---

## 7. L4 System — Container Auth & Service Directory

### 7.1 What Exists at L4

L4 (202 lines, 4 types, 8 functions): Agent run monitoring, step tracking, execution timeline. Container lifecycle management via Podman.

### 7.2 Use Cases at L4

#### UC-L4-001: FerrisKey as Container #17 in Boot Sequence

**Functionality**: FerrisKey container added to the SIL-6 Biomorphic Mesh genome at Boot Tier 2.5 (after database, before application containers).

**Control Flow**:
```
Panoptic Ignition boot sequence
    │
    Tier 1: Zenoh Control Plane (zenoh-router, TCP 7447)
    │ ✓ Health: TCP connection to 7447
    │
    Tier 2: Database (postgres, pg_isready 5433)
    │ ✓ Health: pg_isready returns 0
    │
    Tier 2.5: IAM (ferriskey, HTTP 8080) ← NEW
    │ ✓ Health: HTTP GET /health returns { status: "ok" }
    │ ✓ Dependency: postgres (ferriskey-db on 5434)
    │ ✗ If unhealthy → HALT boot (SC-IAM-001)
    │   (FerrisKey must be available before apps start)
    │
    Tier 3: Observability (obs-prod)
    │ ...continues through Tier 7
```

**Improvement**: Identity plane is infrastructure-level — not an afterthought. Apps cannot start without auth available.

**Implications**:
- Boot time increases by ~1-2s (FerrisKey startup <1s, health check 1s)
- Boot failure at Tier 2.5 blocks all subsequent tiers
- Digital Twin (chaya) must also register FerrisKey health

#### UC-L4-002: Service Directory Registration on Boot

**Functionality**: Each container registers itself in Google Cloud Service Directory upon passing health check.

**Data Flow**:
```
Container ex-app-1 boots
    │
    ▼
Health check passes (TCP 4000)
    │
    ▼
sa-plan-daemon service_directory.rs: register_endpoint()
    │
    ├─ Step 1: Get FerrisKey JWT (client credentials, cached)
    │
    ├─ Step 2: Exchange for GCP token via WIF
    │   POST https://sts.googleapis.com/v1/token
    │   subject_token: <ferriskey-jwt>
    │   audience: workloadIdentityPools/c3i-pool/providers/ferriskey-provider
    │
    ├─ Step 3: Register in Service Directory
    │   POST servicedirectory.googleapis.com/v1/
    │     projects/bountytek-c3i/locations/europe-north1/
    │     namespaces/c3i-prod/services/phoenix-legacy/endpoints/app-1
    │   Body: {
    │     address: "10.x.x.x",
    │     port: 4000,
    │     metadata: {
    │       fractal_layer: "L3",
    │       version: "v22.11.0",
    │       boot_tier: 6,
    │       health_check: "tcp",
    │       sil6_category: "ElixirApp",
    │       ooda_capable: true
    │     }
    │   }
    │
    └─ Step 4: Publish to Zenoh
        indrajaal/l7/discovery/registered/phoenix-legacy
```

**Improvement**: All 19 containers visible in Google Cloud Console with real-time metadata. Before: operator had to run `podman ps` to see what's running.

#### UC-L4-003: Container Health Metadata Updates

**Functionality**: Every 10s, health check results update Service Directory endpoint metadata.

**Data Flow**:
```
Health orchestra (every 10s)
    │ For each container:
    │   health_check(container) → { healthy: true, score: 0.95, latency_ms: 12 }
    │
    ▼
service_directory.update_metadata(service, endpoint, {
    healthy: "true",
    health_score: "0.95",
    last_check: "2026-04-19T11:30:00Z",
    check_latency_ms: "12"
})
    │
    ▼
If health transitions (healthy → degraded):
    DNS automatically routes away from degraded endpoint
    Zenoh: indrajaal/health/{node}/degraded
```

**Improvement**: DNS-based automatic failover. Before: manual container restart. After: Cloud DNS stops resolving to unhealthy endpoints.

#### UC-L4-004: Container Restart Requires L4 Access

**Functionality**: Container lifecycle operations (restart, stop, rebuild) now require operator or admin role.

**Control Flow**:
```
POST /api/v1/podman/restart
    │ Authorization: Bearer <jwt>
    │ Body: { container: "ex-app-1" }
    │
    ▼
auth.get_authenticated_user(request)
    │ → AuthenticatedUser { permission: OperatorAccess }
    │
    ▼
rbac.can_access_layer(OperatorAccess, L4System)
    │ → True (level 4 >= 1)
    │
    ▼
podman_api.restart_container("ex-app-1")
    │
    ▼
Service Directory: deregister → restart → health check → re-register
```

**Improvement**: Viewer role cannot restart containers. Before: any token holder could restart anything.

---

## 8. L5 Cognitive — Inference Auth & OODA

### 8.1 What Exists at L5

L5 (146 lines, 3 types, 9 functions): OODA cycle monitoring (100ms target), reasoning streaming, decision logging with 60-cycle history.

### 8.2 Use Cases at L5

#### UC-L5-001: Per-User Gemini Inference Attribution

**Functionality**: Every Gemini API call now carries user identity from FerrisKey JWT. Enables per-user cost tracking and rate limiting.

**Data Flow**:
```
User sends chat message via Telegram
    │
    ▼
ingress_polling.rs: receive message
    │ sender_identity: telegram_user_id (mapped to FerrisKey user via token exchange)
    │
    ▼
cortex.rs: classify_intent(message, user_context)
    │ user_context includes: sub, roles, permission_level, has_mfa
    │
    ▼
mcp_inference.rs: hedged_infer(prompt, user_id)
    │
    ├─ Tier 1: Gemini Direct
    │   Rate limit check: user_requests[user_id] < 20/min
    │   API key: from FerrisKey vault (not Smriti.db)
    │   OTel span: { user: user_id, tier: 1, latency_ms: 900 }
    │
    ├─ Tier 2: OpenRouter (parallel)
    │   Same user attribution
    │
    ▼
PipelineTracer: trace includes user_id at every stage
    │ Footer: "Pipeline[user:admin]: recv(0ms) > class(1ms) > infer(900ms) > delivered(1400ms)"
```

**Improvement**: Cost visibility per user. Rate limiting per authenticated identity (not per IP). Abuse detection: "user X made 500 inference calls in 1 hour".

#### UC-L5-002: OODA Cycle with Auth Context

**Functionality**: The OODA cycle (Observe → Orient → Decide → Act) now includes auth state as an observation input.

**Data Flow**:
```
OODA Observe phase
    │
    ├─ System health (NIF: system_health)
    ├─ Active tasks (NIF: plan_status)
    ├─ Auth state (NEW):
    │   ├─ FerrisKey healthy? (from health_cascade L0 check)
    │   ├─ Active sessions count (from FerrisKey admin API)
    │   ├─ Recent auth failures (from Zenoh: indrajaal/auth/login)
    │   └─ MFA enrollment rate (from FerrisKey metrics)
    │
    ▼
OODA Orient phase
    │ If auth failures > threshold → security threat detected
    │ If FerrisKey unhealthy → degraded mode
    │ If MFA enrollment < required → compliance gap
    │
    ▼
OODA Decide phase
    │ Rule engine evaluates auth-related GRL rules
    │ Example: "If auth_failure_count > 10 in 5min → escalate_to_admin"
    │
    ▼
OODA Act phase
    │ Send alert via gateway (Telegram/GChat)
    │ Update Dark Cockpit mode (Bright if auth anomaly)
```

**Improvement**: Auth anomalies trigger OODA cycle decisions. Before: auth events were invisible to the cognitive layer. After: auth is an input signal for system intelligence.

#### UC-L5-003: MCP Tool Authorization

**Functionality**: MCP tool invocations gated by FerrisKey RBAC. Different tools require different permission levels.

**Control Flow**:
```
MCP tool request: plan_search("query")
    │
    ▼
MoZ: indrajaal/mcp/req/plan_search/{id}
    │ Payload includes: requester_jwt
    │
    ▼
MCP handler: validate JWT → extract roles → check permission
    │
    ├─ plan_search: requires L3 (Transaction) → OperatorAccess+
    ├─ system_health: requires L4 (System) → OperatorAccess+
    ├─ emergency_stop: requires L0 (Constitutional) → FullAccess + MFA
    └─ knowledge_search: requires L5 (Cognitive) → ViewerAccess+
    │
    ▼
Authorized? Execute tool : Return 403
```

**Improvement**: Scoped MCP tools. Viewer can search knowledge but cannot modify plans. Admin with MFA can trigger emergency stop.

---

## 9. L6 Ecosystem — Mesh Auth Events

### 9.1 What Exists at L6

L6 (107 lines, 4 types, 9 functions): Agent mesh topology, A2A messaging, quorum tracking. Max 50 agents, 200 messages.

### 9.2 Use Cases at L6

#### UC-L6-001: Webhook → Zenoh Auth Event Bridge

**Functionality**: FerrisKey webhook events classified by dark cockpit rules and published to Zenoh mesh. 16 event types, 8 Zenoh topics.

**Data Flow**:
```
FerrisKey event: login_failure
    │
    ▼
POST http://ferriskey-c3i-bridge:9090/webhook
    │ { event_type: "login_failure", user_id: "u-1", ip_address: "10.0.0.5" }
    │
    ▼
classify_event("login_failure") → Publish (anomalous)
    │ (dark cockpit: login_success would be Suppress)
    │
    ▼
AuthEvent {
    event_type: "login_failure",
    severity: "warning",
    user_id: "u-1",
    ip_address: "10.0.0.5",
    timestamp: "2026-04-19T11:30:00Z"
}
    │
    ▼
Zenoh.put("indrajaal/auth/login", json)
Zenoh.put("indrajaal/otel/spans/auth/login", json)
    │
    ▼
Mesh subscribers:
    ├─ Dashboard WS → auth event panel shows login failure
    ├─ TUI → auth status shows "⚠ Login failure from 10.0.0.5"
    ├─ OODA Observe → auth_failure_count++
    └─ Prometheus exporter → auth_failures_total metric
```

**Dark Cockpit Classification (7 tests verify)**:

| Event | Action | Rationale |
|-------|--------|-----------|
| login_success | SUPPRESS | Nominal — dark cockpit hides healthy state |
| login_failure | PUBLISH | Anomalous — potential attack |
| token_issued | SUPPRESS | Nominal — routine token refresh |
| token_revoked | PUBLISH | Security action — always visible |
| role_assigned | PUBLISH | Access change — always visible |
| mfa_failure | PUBLISH | Authentication bypass attempt |
| admin_action | PUBLISH | Administrative change — audit required |
| unknown_event | PUBLISH | Fail-safe — unknown events are published |

**Improvement**: Security events visible across the entire mesh. Before: no auth event visibility. After: real-time auth event stream on dashboard.

#### UC-L6-002: Service Directory ↔ Zenoh Dual Discovery

**Functionality**: sa-plan-daemon syncs Service Directory endpoints to Zenoh mesh cache every 60s.

**Data Flow**:
```
sa-plan-daemon sync loop (every 60s)
    │
    ▼
GET servicedirectory.googleapis.com/v1/.../namespaces/c3i-prod/services
    │ (auth via WIF: FerrisKey JWT → GCP token)
    │
    ▼
For each service:
    │ Zenoh.put("indrajaal/l7/discovery/endpoints/{service}", json)
    │
    ▼
Mesh services can discover peers via:
    Option A: Zenoh.get("indrajaal/l7/discovery/endpoints/gleam-wisp") → cached
    Option B: DNS query "gleam-wisp.c3i-prod.sd.internal" → Cloud DNS → SD
    Option C: Direct SD API call (auth required)
```

**Improvement**: Hybrid discovery — mesh-local speed (Zenoh cache, <1ms) with cloud-authoritative backend (Service Directory, <100ms).

#### UC-L6-003: Pub/Sub Auth via WIF

**Functionality**: GCP Pub/Sub polling (ingress_polling.rs) authenticates via Workload Identity Federation instead of Application Default Credentials.

**Control Flow**:
```
Before:
    gcloud auth application-default login → ADC file on disk
    ingress_polling.rs uses ADC for Pub/Sub API calls

After:
    sa-plan-daemon → FerrisKey JWT (client credentials)
    → WIF exchange (FerrisKey JWT → GCP STS → GCP token)
    → Pub/Sub API call with GCP token
    → No credential file on disk (keyless)
```

**Improvement**: No service account key files stored anywhere. Credentials are ephemeral, short-lived (1 hour), and auto-rotating.

---

## 10. L7 Federation — Gateway Auth & Cross-Mesh

### 10.1 What Exists at L7

L7 (95 lines, 3 types, 7 functions): Federation peers with version vectors, attestation gating, peer lifecycle (Connected → Suspected → Disconnected).

### 10.2 Use Cases at L7

#### UC-L7-001: Authenticated Gateway Broadcasts

**Functionality**: Gateway broadcasts to Telegram and GChat now carry authenticated identity.

**Data Flow**:
```
OODA Decide: "send alert to operator"
    │
    ▼
gateway.rs: broadcast(message, channels, user_context)
    │
    ├─ Telegram:
    │   POST https://api.telegram.org/bot{token}/sendMessage
    │   Body includes: { text: "[from: cortex@c3i-service] Alert: ..." }
    │
    ├─ GChat:
    │   POST https://chat.googleapis.com/v1/spaces/{space}/messages
    │   Body: { text: "[c3i-service] Alert: ..." }
    │   Auth: webhook URL (will migrate to FerrisKey-brokered OAuth)
    │
    └─ Zenoh: indrajaal/gateway/{channel}/sent
        { user: "sa-plan-daemon", identity: "c3i-service", message_id: "..." }
```

**Improvement**: Every outbound message attributed to a service identity. Before: anonymous broadcasts. After: "sa-plan-daemon sent this alert" visible in audit trail.

#### UC-L7-002: Google SSO Federation

**Functionality**: Google Workspace users authenticate via FerrisKey OIDC broker to access C3I.

**Data Flow**:
```
Operator opens https://vm-1.tail55d152.ts.net:4100/auth
    │ → "Sign in with Google" button
    │
    ▼
Redirect: FerrisKey → Google → authenticate → FerrisKey callback
    │ → FerrisKey creates/links local user
    │ → FerrisKey issues JWT with mapped role
    │
    ▼
Redirect: FerrisKey → C3I /auth/callback
    │ → Exchange code for JWT
    │ → auth.gleam validates JWT
    │ → rbac resolves permission from Google-mapped role
    │
    ▼
Operator authenticated with Google identity
    │ sub: ferriskey-user-id
    │ email: user@bountytek.com
    │ roles: ["c3i-operator"] (mapped from Google Workspace group)
    │ idp: "google"
```

**Improvement**: SSO with existing Google Workspace credentials. No separate password to manage.

#### UC-L7-003: Multi-Region Service Discovery

**Functionality**: Service Directory enables cross-region service discovery for federated C3I deployments.

**Data Flow**:
```
C3I instance in europe-north1 needs to discover peer in us-central1
    │
    ▼
GET servicedirectory.googleapis.com/v1/
    projects/bountytek-c3i/locations/us-central1/
    namespaces/c3i-prod/services/zenoh-router/endpoints
    │ Auth: WIF token (same identity pool)
    │
    ▼
Response: { endpoints: [{ address: "10.y.y.y", port: 7447 }] }
    │
    ▼
l7_federation: add_peer(FederationPeer {
    peer_id: "us-central1-zenoh-1",
    endpoint: "10.y.y.y:7447",
    status: PeerConnected,
    version_vector: [(us-central1, 42)],
    attestation_valid: true
})
```

**Improvement**: Automatic peer discovery across regions. Before: manual endpoint configuration. After: Service Directory resolves peers dynamically.

---

## 11. Health Cascade Auth Integration

### 11.1 Updated Dependency Graph with Auth

```
L0 Constitutional ← (no deps) + FerrisKey health check (NEW)
    │
    ├─ L1 Atomic/Debug ← [L0]
    │   └─ Auth OTel span pipeline verified
    │
    ├─ L2 Component ← [L0, L1]
    │   └─ Auth UI components render correctly
    │
    ├─ L3 Transaction ← [L0, L1, L2]
    │   └─ Smriti.db credential access + FerrisKey vault
    │
    ├─ L4 System ← [L0, L3]
    │   └─ FerrisKey container healthy + SD registration
    │
    ├─ L5 Cognitive ← [L0, L3, L4]
    │   └─ OIDC validation works + MCP tools authorized
    │
    ├─ L6 Ecosystem ← [L0, L4]
    │   └─ Webhook bridge connected + Zenoh auth topics active
    │
    └─ L7 Federation ← [L0, L5, L6]
        └─ Gateway auth + SD cross-region discovery
```

### 11.2 Auth-Related Health Checks per Layer

| Layer | Check | Pass Condition | Failure Mode |
|-------|-------|---------------|-------------|
| L0 | FerrisKey HTTP /health | Returns 200 + `{"status":"ok"}` | Warning (graceful degradation to static token) |
| L0 | JWKS cache populated | At least 1 key in cache | Warning (first request will be slow) |
| L1 | Auth OTel exporter | Zenoh connected + publishing | Warning (auth events not visible) |
| L3 | Smriti.db secrets readable | `get_preference("gemini_api_key")` returns value | Error (no API key for inference) |
| L4 | FerrisKey container running | `podman inspect` shows running | Error (auth unavailable) |
| L4 | SD registration successful | Endpoint created in Service Directory | Warning (cloud visibility lost) |
| L5 | OIDC validation functional | Test token validates successfully | Error (all authenticated requests fail) |
| L6 | Webhook bridge connected | HTTP 200 from bridge /health | Warning (auth events not bridged) |
| L6 | Zenoh auth topics active | Subscriber exists on `indrajaal/auth/**` | Warning (auth events not consumed) |
| L7 | Gateway auth working | Service account JWT cached | Warning (gateway cannot authenticate) |

---

## 12. Guard Grid Auth Cells

### 12.1 New Guard Grid Cells for Auth

The 24-cell guard grid (8 layers x 3 modules) gains auth-aware checks:

```
L0: [guardian + AUTH_GATE, psi_invariants + FERRISKEY_HEALTH, emergency_stop + MFA_CHECK]
L1: [nif_bridge, otel_trace + AUTH_SPANS, debug_probes]
L2: [a2ui_catalog + AUTH_COMPONENTS, shell_helpers, lustre_ssr]
L3: [plan_status, smriti_db + CREDENTIAL_VAULT, planning_db]
L4: [container_genome + FERRISKEY_CONTAINER, boot_sequencer + SD_REGISTRATION, cpu_governor]
L5: [cortex + USER_CONTEXT, ooda_loop + AUTH_OBSERVE, inference_cascade + RATE_LIMIT]
L6: [zenoh_mesh + AUTH_TOPICS, quorum, moz_bridge + AUTH_HEADERS]
L7: [gateway + IDENTITY, ha_election, version_vectors + SD_FEDERATION]
```

### 12.2 Wolfram Rule Analysis Impact

**Rule 110 (Chaos Detection)**: If auth failures cascade across L0 → L5 → L7, Rule 110 detects emergent chaos pattern. Example: FerrisKey down → OIDC validation fails → inference unauthenticated → gateway broadcasts fail → cascade detected.

**Rule 30 (Randomness)**: Random auth failures (network glitches) vs systematic (configuration error). Rule 30 distinguishes: random failures have high entropy, systematic have low entropy.

**Rule 184 (Backpressure)**: If auth validation adds latency to every request, Rule 184 detects queue buildup. JWKS cache mitigation keeps validation <1ms.

---

## 13. Expected Improvements Summary

| Area | Before | After | Improvement Factor |
|---|---|---|---|
| **Identity** | Static token (1 identity) | Per-user JWT (unlimited) | N:1 |
| **Authorization** | Binary (has token / doesn't) | 5-level RBAC x 8 layers = 40 access cells | 40:1 granularity |
| **MFA** | None | TOTP + WebAuthn + Magic Links for L0 | ∞ improvement |
| **Audit trail** | None | 16 event types x 8 Zenoh topics | 0 → 128 audit points |
| **Credential security** | Plaintext in SQLite | Encrypted in FerrisKey vault | Qualitative |
| **Key rotation** | Manual DB edit | Admin console + webhook notification | Hours → minutes |
| **Service discovery** | `podman ps` + manual config | DNS + Service Directory + Zenoh cache | Manual → automatic |
| **GCP auth** | Service account keys on disk | Keyless via WIF | Eliminates key leakage risk |
| **Multi-user** | Single operator | Unlimited via Google SSO | 1 → N users |
| **Cost attribution** | Aggregate | Per-user per-API | 1 bucket → N buckets |
| **Incident isolation** | Manual `podman stop` | SD deregister + IAM revoke (<60s) | Minutes → seconds |
| **Compliance** | Manual log review | Cloud Audit Logs + Policy Analyzer | Manual → automated |
| **Dark cockpit** | No auth events | Nominal suppressed, anomalous published | 0 → intelligent filtering |
| **Boot safety** | Apps start without auth | FerrisKey gates boot at Tier 2.5 | Unsafe → safe |

---

## 14. STAMP & Constitutional Alignment

### 14.1 Total STAMP Constraints Introduced

| Family | Count | Layer | Severity |
|---|---|---|---|
| SC-AUTH-001..008 | 8 | L0 | CRITICAL-HIGH |
| SC-IAM-001..008 | 8 | L0 | CRITICAL-HIGH |
| SC-SD-001..006 | 6 | L4/L6 | CRITICAL-MEDIUM |
| SC-WIF-001..006 | 6 | L0/L6 | CRITICAL-HIGH |
| SC-GCP-001..006 | 6 | L6/L7 | CRITICAL-MEDIUM |
| **TOTAL** | **34** | L0-L7 | — |

### 14.2 Psi Invariant Alignment

| Invariant | Auth Integration |
|---|---|
| Psi-0 (Existence) | FerrisKey health gates boot. If FerrisKey dies, system enters degraded mode but continues (Psi-0 preserved). |
| Psi-1 (Regeneration) | FerrisKey state in PostgreSQL. Container restart → sessions preserved. |
| Psi-2 (History) | All auth events in immutable Zenoh OTel spans. Cannot be deleted. |
| Psi-3 (Verification) | JWKS signature verification proves token authenticity. Guard grid verifies auth subsystem. |
| Psi-4 (Human Alignment) | RBAC enforces human-defined access boundaries. Google Workspace groups map to roles per admin policy. |
| Psi-5 (Truthfulness) | FerrisKey health is a Psi-5 sub-check. Auth system must not lie about identity. |
| Omega-0 (Founder) | Founder's Google account (Abhijit.Naik@bountytek.com) = c3i-admin via @bountytek.com domain rule. |

---

## 15. Conclusion

The FerrisKey IAM integration touches **all 8 fractal layers** with varying depth:

- **L0 Constitutional** (9/12 features): Deepest impact — auth IS constitutional. MFA, Guardian approval, Psi invariant verification all enhanced.
- **L6 Ecosystem** (6/12 features): Second deepest — webhook bridge, Zenoh auth topics, Service Directory sync, WIF for GCP APIs.
- **L1 Atomic/Debug** and **L5 Cognitive** (5/12 each): Auth telemetry spans and per-user inference attribution.
- **L4 System** and **L7 Federation** (5/12 each): Container boot gating and cross-mesh discovery.
- **L3 Transaction** (4/12): Credential migration and token exchange as stateful operations.
- **L2 Component** (3/12): Lightest touch — UI badge and chip components.

**Total fractal tensor**: 42/96 cells directly impacted (43.8%), with all remaining cells indirectly affected through the health cascade dependency graph.

The system transitions from **anonymous static-token operation** to **named identity-federated multi-user RBAC with MFA, audit trail, and automated service discovery** — while maintaining backward compatibility via the `FERRISKEY_ENABLED` toggle and preserving all 7 Psi invariants + Omega-0.
