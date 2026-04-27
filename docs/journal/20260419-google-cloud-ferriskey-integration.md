# Journal: Google Cloud + FerrisKey System Integration — Complete Use Cases, Data Flows, Control Flows & Impact Analysis

**Date**: 2026-04-19
**Version**: v22.11.0-FERRISKEY-GCP
**Session Type**: Architecture Design & Integration Planning
**ZK Recall**: [zk-03d2bc227da29769] anti-pattern: never expose internal REST endpoints to Google Workspace webhooks — use egress-only. [zk-0fa06bc0dcde9313] operator directive: full system must be Rust code in sa-planner.

---

## 1. Scope & Trigger

### Trigger
Operator directive to provide full Google Cloud integration details through the newly-integrated FerrisKey IAM system. The C3I system already has 9 active Google service integrations + 4 MCP tools + 3 stub implementations. FerrisKey now provides the unified identity plane to secure, federate, and audit all Google interactions.

### Scope
This journal covers:
- All 17 Google service integration points (active + planned)
- Authentication/authorization flows for each service
- Data flow diagrams for every Google API interaction
- Control flow through FerrisKey OIDC -> Google OAuth2 -> service API
- Impact on all 7 fractal layers (L0-L7)
- Impact on SDLC, SRE, and application flows
- 42 use cases across 8 Google service families

### Pre-State: Current Google Integrations Inventory

| Service | Status | Implementation | Auth Method |
|---------|--------|---------------|-------------|
| Gemini Direct API (Tier 1) | **Active** | `mcp_inference.rs` | API key in Smriti.db |
| Gemini Live WebSocket (Voice) | **Active** | `gemini_live.rs` | API key in Smriti.db |
| OpenRouter/Gemini (Tier 2) | **Active** | `mcp_inference.rs` | API key |
| Gmail SMTP | **Active** | `mcp_gworkspace.rs` (lettre) | App password in Smriti.db |
| Gmail OAuth2 API | **Disabled** | `mcp_gworkspace.rs` | OAuth2 refresh token (disabled 2026-04-12) |
| Google Chat Webhooks | **Active** | `gateway.rs` | Webhook URL (no auth) |
| GCP Pub/Sub (GChat ingress) | **Active** | `ingress_polling.rs` | Application Default Credentials |
| Google Calendar MCP | **Available** | Claude MCP server | OAuth2 via MCP |
| Google Drive MCP | **Available** | Claude MCP server | OAuth2 via MCP |
| Gmail MCP | **Available** | Claude MCP server | OAuth2 via MCP |
| Google Drive (rclone FUSE) | **Active** | rclone mount at `sub-projects/work/gdrive/` | OAuth2 via rclone |
| Google Sheets API | **Stub** | `mcp_gworkspace.rs` | Not implemented |
| Google Docs API | **Stub** | `mcp_gworkspace.rs` | Not implemented |
| Google Tasks API | **Stub** | `mcp_gworkspace.rs` | Not implemented |

---

## 2. Architecture Overview: FerrisKey as Google Identity Bridge

### 2.1 Current State (Pre-FerrisKey)

```
┌─────────────────────────────────────────────────────────┐
│                    C3I SYSTEM                             │
│                                                           │
│  sa-plan-daemon ──API Key──────> Gemini API               │
│  sa-plan-daemon ──App Password──> Gmail SMTP              │
│  sa-plan-daemon ──Webhook URL──> Google Chat              │
│  sa-plan-daemon ──ADC──────────> GCP Pub/Sub              │
│  rclone ─────────OAuth2────────> Google Drive              │
│  Claude MCP ─────OAuth2────────> Gmail/Calendar/Drive      │
│                                                           │
│  Problem: 6 different auth methods, no unified identity,  │
│  no audit trail, no RBAC, credentials scattered in        │
│  Smriti.db + env vars + rclone config                     │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Target State (With FerrisKey)

```
┌──────────────────────────────────────────────────────────────────┐
│                    C3I SYSTEM                                     │
│                                                                    │
│  ┌───────────────────────────────────────────┐                    │
│  │         FERRISKEY IAM (Container #17)      │                    │
│  │                                             │                    │
│  │  Realm: c3i-dev                             │                    │
│  │  ┌─────────────────────────────────────┐   │                    │
│  │  │ Identity Providers                   │   │                    │
│  │  │  ├─ Google Workspace (OIDC broker)   │   │                    │
│  │  │  ├─ Telegram (custom token exchange) │   │                    │
│  │  │  └─ Local credentials (password)     │   │                    │
│  │  └─────────────────────────────────────┘   │                    │
│  │  ┌─────────────────────────────────────┐   │                    │
│  │  │ Service Accounts (client credentials)│   │                    │
│  │  │  ├─ sa-plan-daemon                   │   │                    │
│  │  │  ├─ mcp-dispatch                     │   │                    │
│  │  │  ├─ gemini-inference                 │   │                    │
│  │  │  └─ google-workspace                 │   │                    │
│  │  └─────────────────────────────────────┘   │                    │
│  │  ┌─────────────────────────────────────┐   │                    │
│  │  │ Protocol Mappers                     │   │                    │
│  │  │  ├─ google_access_token (claim)      │   │                    │
│  │  │  ├─ gmail_scope (scope mapper)       │   │                    │
│  │  │  └─ drive_scope (scope mapper)       │   │                    │
│  │  └─────────────────────────────────────┘   │                    │
│  └───────────────────────────────────────────┘                    │
│       │                    │                    │                   │
│       ▼                    ▼                    ▼                   │
│  ┌─────────┐  ┌────────────────┐  ┌──────────────────┐           │
│  │ Gleam   │  │ sa-plan-daemon │  │ Zenoh Mesh       │           │
│  │ Wisp    │  │ (Rust)         │  │ indrajaal/auth/* │           │
│  │ :4100   │  │ cortex/gateway │  │ indrajaal/otel/* │           │
│  └────┬────┘  └───────┬────────┘  └──────────────────┘           │
│       │               │                                            │
│       ▼               ▼                                            │
│  ┌──────────────────────────────────────┐                         │
│  │       GOOGLE CLOUD SERVICES           │                         │
│  │  ├─ Gemini API (inference)            │                         │
│  │  ├─ Gmail API (send/read)             │                         │
│  │  ├─ Calendar API (events)             │                         │
│  │  ├─ Drive API (files)                 │                         │
│  │  ├─ Pub/Sub (ingress)                 │                         │
│  │  ├─ Cloud IAM (workload identity)     │                         │
│  │  └─ Sheets/Docs/Tasks (future)        │                         │
│  └──────────────────────────────────────┘                         │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Google Service Integration Details

### 3.1 Gemini AI Inference (Active — Tier 1 & Voice)

**Current auth**: API key stored in Smriti.db (`gemini_api_key`)
**Files**: `mcp_inference.rs` (663 lines), `gemini_live.rs` (307 lines)
**Fractal Layer**: L5_COGNITIVE

#### Data Flow

```
User Intent (Telegram/GChat)
    │
    ▼
sa-plan-daemon cortex.rs
    │ classify_intent()
    ▼
mcp_inference.rs: hedged_infer()
    │
    ├─ Tier 1: Gemini Direct (parallel)─────────────────────────┐
    │  POST https://generativelanguage.googleapis.com/           │
    │       v1beta/models/gemini-3.1-flash-lite-preview          │
    │       :generateContent?key={gemini_api_key}                │
    │  Headers: Content-Type: application/json                   │
    │  Body: { contents: [{ parts: [{ text: prompt }] }],       │
    │          systemInstruction: { parts: [{ text: ctx }] } }   │
    │  Response: { candidates: [{ content: { parts } }] }       │
    │  Latency: ~900ms                                           │
    │                                                             │
    ├─ Tier 2: OpenRouter (parallel)────────────────────────────┤
    │  POST https://openrouter.ai/api/v1/chat/completions       │
    │  Headers: Authorization: Bearer {openrouter_api_key}       │
    │  Body: { model: "google/gemini-3-flash-preview",           │
    │          messages: [...] }                                  │
    │  Latency: ~1.1s                                            │
    │                                                             │
    ▼ First success wins (tokio::join!)                          │
    │                                                             │
    ├─ Tier 3: Ollama gemma4 (fallback) ─ port 11435 ──────────┤
    ├─ Tier 4: Ollama gemma3 (fallback) ─ port 11434 ──────────┤
    ├─ Tier 5: RETE-UL rule engine (in-process) ───────────────┤
    └─ Tier 6: Static acknowledgment ──────────────────────────┘
    │
    ▼
PipelineTracer: batch write to SQLite + Zenoh
    │ indrajaal/l5/cog/trace/{id}
    ▼
gateway.rs: broadcast to Telegram + GChat
```

#### Voice Data Flow (Gemini Live)

```
Microphone Input
    │ PCM 16kHz mono
    ▼
gemini_live.rs: WebSocket client
    │ wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage
    │     .v1alpha.GenerativeService.BidiGenerateContent
    │     ?key={gemini_api_key}
    │
    ├─ Setup: { model: "models/gemini-3.1-flash-live-preview",
    │           generationConfig: { responseModalities: ["TEXT"] } }
    │
    ├─ Audio chunks: { realtimeInput: { mediaChunks: [{ data: base64 }] } }
    │
    ├─ Response: { serverContent: { modelTurn: { parts: [{ text }] } } }
    │
    ▼ Fallback on WS error:
    ├─ Tier 2: Gemini REST multimodal (POST with audio bytes)
    ├─ Tier 3: Whisper.cpp local transcription (75MB model)
    └─ Tier 5: Rule-based acknowledgment
```

#### FerrisKey Integration Impact

| Aspect | Current | With FerrisKey |
|--------|---------|---------------|
| API key storage | Smriti.db plain text | FerrisKey vault (encrypted secret) |
| Key rotation | Manual DB update | FerrisKey admin console + webhook notification |
| Audit trail | None | OTel spans via Zenoh on every inference call |
| Rate limiting | Per-IP (20/min) | Per-user (authenticated identity) |
| Cost attribution | Aggregate | Per-role (admin vs operator vs viewer) |

**FerrisKey Config Addition** (realm-c3i-dev.json):
```json
{
  "clientId": "gemini-inference",
  "name": "Gemini Inference Service Account",
  "serviceAccountsEnabled": true,
  "attributes": {
    "gemini_api_key": "{encrypted}",
    "google_project_id": "{project}"
  }
}
```

---

### 3.2 Gmail Integration (Active — SMTP + OAuth2 Planned)

**Current auth**: App password in Smriti.db
**File**: `mcp_gworkspace.rs` (380 lines)
**Fractal Layer**: L7_FEDERATION (gateway)

#### Data Flow: SMTP Send (Current)

```
sa-plan-daemon send-email
    │ --to Abhijit.Naik@bountytek.com
    │ --subject "Journal: ..."
    │ --body "..."
    │ -a docs/journal/file.md
    │
    ▼
mcp_gworkspace.rs: send_email_smtp()
    │
    ├─ Build RFC 2822 message (lettre crate)
    │   ├─ From: {sender from Smriti.db}
    │   ├─ To: recipient
    │   ├─ Subject: subject
    │   ├─ Body: text/plain
    │   └─ Attachment: base64-encoded file (MIME type detected)
    │
    ├─ SMTP Connection
    │   Host: smtp.gmail.com:587
    │   Auth: App Password from Smriti.db (smtp_password)
    │   TLS: STARTTLS
    │
    ├─ Send via lettre::SmtpTransport
    │
    └─ Zenoh publish: indrajaal/otel/spans/email/sent
```

#### Data Flow: OAuth2 Gmail (Planned via FerrisKey)

```
FerrisKey Token Exchange
    │
    ▼
sa-plan-daemon auth.rs: OidcClient::get_token()
    │ grant_type=client_credentials
    │ client_id=google-workspace
    │ scope=gmail.send
    │
    ▼
FerrisKey exchanges for Google OAuth2 token
    │ POST https://oauth2.googleapis.com/token
    │ (FerrisKey acts as token broker)
    │
    ▼
sa-plan-daemon: gmail_send_email()
    │ POST https://gmail.googleapis.com/gmail/v1/users/me/messages/send
    │ Authorization: Bearer {google_access_token}
    │ Body: { raw: base64url(RFC2822 message) }
    │
    ▼
Zenoh publish: indrajaal/auth/google/gmail/send
    │ (audit event with user identity)
```

#### Control Flow: FerrisKey -> Google OAuth2 Token Broker

```
Request to send email
    │
    ▼
FerrisKey enabled?
    ├─ No: Use SMTP with App Password (current behavior)
    └─ Yes:
        │
        ▼
    sa-plan-daemon gets FerrisKey JWT
        │ (client credentials, cached)
        ▼
    FerrisKey validates JWT + checks scope
        │ scope: gmail.send
        ▼
    FerrisKey looks up Google refresh token
        │ (stored in FerrisKey user attributes or protocol mapper)
        ▼
    FerrisKey exchanges refresh token for Google access token
        │ POST https://oauth2.googleapis.com/token
        │ grant_type=refresh_token
        │ refresh_token={stored_in_ferriskey}
        │ client_id={google_client_id}
        │ client_secret={google_client_secret}
        ▼
    Returns Google access token to sa-plan-daemon
        │ (via FerrisKey token response, injected as custom claim)
        ▼
    sa-plan-daemon calls Gmail API with Google token
        │
        ▼
    Webhook event -> Zenoh: indrajaal/auth/google/token/exchanged
```

---

### 3.3 Google Calendar Integration (Available — MCP + Planned Native)

**Current auth**: MCP server OAuth2
**Available MCP tools**: `create_event`, `list_events`, `get_event`, `suggest_time`, `respond_to_event`, `delete_event`, `update_event`, `list_calendars`
**Fractal Layer**: L5_COGNITIVE (scheduling)

#### Use Cases

| ID | Use Case | Actor | Flow |
|---|---|---|---|
| UC-CAL-001 | **MEDDPICC Deal Review** | Sales operator | Create recurring QBR event with ARM/Nokia contacts |
| UC-CAL-002 | **Weekly Rhythm** | Sales operator | List next week's meetings for Friday planning |
| UC-CAL-003 | **Meeting Prep** | Sales agent | Get event details + ZK search for account context |
| UC-CAL-004 | **Time Suggestion** | Sales agent | Suggest meeting times avoiding conflicts |
| UC-CAL-005 | **OODA Cycle Scheduling** | System | Auto-schedule daily OODA review meetings |
| UC-CAL-006 | **Incident Response** | SRE | Create war room event when system health < 0.5 |

#### Data Flow: Create Calendar Event

```
Operator: "Schedule QBR with ARM for next Thursday"
    │
    ▼
sa-plan-daemon cortex.rs: classify_intent()
    │ category: calendar_action
    ▼
Decision: use FerrisKey-brokered Google Calendar API
    │
    ▼
auth.rs: OidcClient::get_token()
    │ FerrisKey JWT with scope: calendar
    ▼
FerrisKey: exchange for Google Calendar token
    │ scope: https://www.googleapis.com/auth/calendar
    ▼
POST https://www.googleapis.com/calendar/v3/calendars/primary/events
    │ Authorization: Bearer {google_calendar_token}
    │ Body: {
    │   summary: "QBR with ARM",
    │   start: { dateTime: "2026-04-23T10:00:00+02:00" },
    │   end: { dateTime: "2026-04-23T11:00:00+02:00" },
    │   attendees: [{ email: "contact@arm.com" }],
    │   description: "Quarterly Business Review - FY27 pipeline"
    │ }
    ▼
Response: { id: "event-id", htmlLink: "..." }
    │
    ├─ Zenoh: indrajaal/otel/spans/calendar/event_created
    ├─ ZK ingest: activity log with event details
    └─ Gateway: "QBR scheduled for Thu 23 Apr 10:00" -> Telegram
```

---

### 3.4 Google Drive Integration (Active — rclone + MCP)

**Current auth**: rclone OAuth2 (FUSE mount at `sub-projects/work/gdrive/`)
**Available MCP tools**: `create_file`, `download_file_content`, `read_file_content`, `search_files`, `get_file_metadata`, `get_file_permissions`, `list_recent_files`
**Fractal Layer**: L3_TRANSACTION (data)

#### Data Flow: FY27 Plan Sync

```
FY27-Plan/ (Obsidian Vault on Google Drive)
    │
    ├─ rclone FUSE mount at sub-projects/work/gdrive/
    │   └─ 1-Work/FY27-Plan/
    │       ├─ activities/     (daily logs, meetings)
    │       ├─ Analysis/       (business cases, rate cards)
    │       ├─ refs/           (OEM data, contacts)
    │       └─ zettelkasten/   (FY27-ZK database)
    │
    ├─ Rust build constraint (SC-GDRIVE-BUILD-001):
    │   CARGO_TARGET_DIR=/home/an/dev/ver/c3i/sub-projects/work/
    │   (FUSE mount doesn't support exec permissions)
    │
    ├─ ZK import flow:
    │   cd zettelkasten/ && $ZK import ..
    │   └─ Scans all .md files -> SQLite FTS5 index
    │       └─ 475+ holons, 13,437 contacts
    │
    └─ Obsidian sync:
        ├─ Obsidian reads/writes .md files
        ├─ rclone syncs to Google Drive
        └─ Three consumers: Obsidian (visual), FY27-ZK (search), C3I-ZK (engineering)
```

#### FerrisKey Impact on Drive Access

| Aspect | Current | With FerrisKey |
|--------|---------|---------------|
| Authentication | rclone OAuth2 (user-interactive) | FerrisKey service account + Google Drive scope |
| Access audit | None (rclone is transparent) | Drive access events -> Zenoh mesh |
| Permission model | Full drive access via rclone | Scoped per-folder via FerrisKey role |
| Multi-user | Single rclone config | Per-user Drive access via FerrisKey identity |

---

### 3.5 Google Chat Integration (Active — Webhook + Pub/Sub)

**Current auth**: Webhook URL (no auth) + GCP Application Default Credentials
**Files**: `gateway.rs` (198 lines), `ingress_polling.rs` (331 lines)
**Fractal Layer**: L7_FEDERATION (gateway)

#### Data Flow: Outbound (C3I -> GChat)

```
OODA Decision / Gateway Broadcast
    │
    ▼
gateway.rs: send_to_gchat()
    │
    POST https://chat.googleapis.com/v1/spaces/{space}/messages?key={webhook_key}
    │ Body: { text: "message" }
    │ No auth header (webhook URL contains key)
    │
    ├─ Retry: 1 attempt on failure
    └─ Zenoh: indrajaal/gateway/gchat/sent
```

#### Data Flow: Inbound (GChat -> C3I) — Egress-Only Pattern

```
Google Chat User sends message
    │
    ▼
Google Chat API
    │ Pushes to GCP Pub/Sub topic: indrajaal-gchat-ingress
    │ (Google service account: chat-api-push@system.gserviceaccount.com)
    ▼
GCP Pub/Sub Subscription: indrajaal-gchat-pull
    │ (pull mode, 1-day retention)
    ▼
sa-plan-daemon ingress_polling.rs
    │ Long-poll via gcloud auth (Application Default Credentials)
    │ Pulls messages every 5s
    │
    ├─ Deserialize: extract text, sender, space_id
    ├─ Publish to Zenoh: indrajaal/intent/gchat/{message_id}
    └─ Acknowledge message in Pub/Sub
    │
    ▼
cortex.rs: process_intent()
    │ 6-tier hedged inference
    ▼
gateway.rs: broadcast response
    ├─ GChat webhook (reply)
    └─ Telegram (mirror)
```

**Anti-Pattern [zk-03d2bc227da29769]**: Never expose internal REST endpoints to Google. Always use egress-only Pub/Sub polling. This prevents:
- Inbound firewall requirements
- DDoS attack surface
- Webhook signature validation complexity
- IP allowlist management

#### FerrisKey Impact

| Aspect | Current | With FerrisKey |
|--------|---------|---------------|
| Webhook auth | URL-based (key in URL) | FerrisKey validates GChat sender identity |
| Pub/Sub auth | Application Default Credentials | FerrisKey service account with Pub/Sub scope |
| Message attribution | Sender name from GChat payload | Mapped to FerrisKey user identity |
| Rate limiting | Per-IP | Per-authenticated-user |

---

### 3.6 GCP Pub/Sub Integration (Active — Ingress Channel)

**Current auth**: Application Default Credentials (`gcloud auth application-default login`)
**File**: `ingress_polling.rs` (331 lines)
**Fractal Layer**: L6_ECOSYSTEM

#### Control Flow

```
System Startup
    │
    ▼
ingress_polling.rs: start_polling()
    │
    ├─ Load GCP credentials
    │   ├─ gcp_project_id from Smriti.db
    │   ├─ gcp_pubsub_subscription from Smriti.db
    │   └─ Auth: Application Default Credentials
    │       (GOOGLE_APPLICATION_CREDENTIALS env or gcloud ADC)
    │
    ├─ Polling loop (every 5s):
    │   │
    │   ▼
    │   POST https://pubsub.googleapis.com/v1/projects/{project}/
    │        subscriptions/{subscription}:pull
    │   Body: { maxMessages: 10 }
    │   Auth: Bearer {adc_token}
    │   │
    │   ▼
    │   For each message:
    │   ├─ Decode base64 payload
    │   ├─ Parse JSON (chat message structure)
    │   ├─ PII scrub (SC-SEC-003, SC-LOG-003)
    │   ├─ Publish to Zenoh: indrajaal/intent/{channel}/{id}
    │   └─ ACK message in Pub/Sub
    │
    └─ Circuit breaker: 3 failures -> 60s cooldown
```

#### FerrisKey Integration

```
FerrisKey Service Account: gcp-pubsub
    │
    ├─ Scope: pubsub.subscriber, pubsub.viewer
    ├─ Google service account key stored in FerrisKey vault
    │   (not in Smriti.db or env vars)
    │
    ├─ Token exchange flow:
    │   sa-plan-daemon -> FerrisKey JWT -> exchange for Google token
    │   -> use Google token for Pub/Sub API calls
    │
    └─ Audit: every Pub/Sub pull logged to Zenoh
        indrajaal/auth/google/pubsub/pull
```

---

### 3.7 Google Workspace Identity Federation (Planned)

**Fractal Layer**: L0_CONSTITUTIONAL

#### Data Flow: Google Workspace SSO

```
Operator opens https://vm-1.tail55d152.ts.net:4100/auth
    │
    ▼
Lustre auth page: "Sign in with Google" button
    │
    ▼
Redirect to FerrisKey: /realms/c3i-dev/protocol/openid-connect/auth
    │ ?client_id=c3i-lustre-ui
    │ &redirect_uri=https://vm-1.tail55d152.ts.net:4100/auth/callback
    │ &response_type=code
    │ &kc_idp_hint=google   (direct to Google IdP)
    │
    ▼
FerrisKey redirects to Google:
    │ https://accounts.google.com/o/oauth2/v2/auth
    │ ?client_id={google_client_id}
    │ &redirect_uri={ferriskey_callback}
    │ &scope=openid email profile
    │ &response_type=code
    │
    ▼
User authenticates with Google (@bountytek.com)
    │
    ▼
Google redirects to FerrisKey callback:
    │ /realms/c3i-dev/broker/google/endpoint
    │ ?code={authorization_code}
    │
    ▼
FerrisKey exchanges code for Google tokens:
    │ POST https://oauth2.googleapis.com/token
    │ Body: { code, client_id, client_secret, redirect_uri, grant_type }
    │
    ▼
FerrisKey creates/links local user:
    │ ├─ sub: ferriskey-user-id
    │ ├─ email: user@bountytek.com
    │ ├─ federated_identity: google/{google_sub}
    │ └─ roles: [assigned by admin or auto-mapped by email domain]
    │
    ▼
FerrisKey issues its own JWT:
    │ ├─ sub: ferriskey-user-id
    │ ├─ preferred_username: user@bountytek.com
    │ ├─ roles: ["c3i-operator"]  (mapped from Google Workspace group)
    │ ├─ acr: "1" (or "mfa" if Google verified 2FA)
    │ └─ idp: "google"
    │
    ▼
FerrisKey redirects to C3I callback:
    │ https://vm-1.tail55d152.ts.net:4100/auth/callback?code={ferriskey_code}
    │
    ▼
Gleam Wisp exchanges code for FerrisKey JWT:
    │ POST /realms/c3i-dev/protocol/openid-connect/token
    │ Body: { code, client_id, redirect_uri, grant_type=authorization_code }
    │
    ▼
auth.gleam: validate_request()
    │ ├─ AuthenticatedOidc(claims)
    │ └─ rbac.resolve_permission(["c3i-operator"]) -> OperatorAccess
    │
    ▼
Zenoh events:
    ├─ indrajaal/auth/login (success, dark cockpit suppressed)
    └─ indrajaal/auth/federation/linked (Google IdP)
```

#### Google Workspace Group -> FerrisKey Role Mapping

```
Google Workspace                    FerrisKey Realm
──────────────                      ─────────────
Group: c3i-admins@bountytek.com  →  Role: c3i-admin
Group: c3i-ops@bountytek.com     →  Role: c3i-operator
Group: c3i-viewers@bountytek.com →  Role: c3i-viewer
Default (no group match)         →  Role: c3i-viewer

Configuration in FerrisKey Identity Provider:
{
  "identityProviders": [{
    "alias": "google",
    "providerId": "oidc",
    "config": {
      "clientId": "{GOOGLE_CLIENT_ID}",
      "clientSecret": "{GOOGLE_CLIENT_SECRET}",
      "authorizationUrl": "https://accounts.google.com/o/oauth2/v2/auth",
      "tokenUrl": "https://oauth2.googleapis.com/token",
      "userInfoUrl": "https://openidconnect.googleapis.com/v1/userinfo",
      "defaultScope": "openid email profile",
      "syncMode": "FORCE"
    },
    "mappers": [{
      "name": "google-email-domain-role",
      "identityProviderMapper": "hardcoded-role-idp-mapper",
      "config": {
        "role": "c3i-operator"
      }
    }]
  }]
}
```

---

### 3.8 GKE Workload Identity Federation (Planned — Production)

**Fractal Layer**: L4_SYSTEM

#### Data Flow: Pod Authentication

```
C3I Pod on GKE
    │
    ▼
Kubernetes Service Account
    │ Annotated: iam.gke.io/gcp-service-account=c3i-sa@project.iam.gserviceaccount.com
    │
    ▼
GKE Workload Identity Provider
    │ Issues Kubernetes token with Google-compatible claims
    │
    ▼
FerrisKey validates Kubernetes-issued JWT
    │ (FerrisKey trusts GKE OIDC issuer)
    │
    ▼
FerrisKey issues C3I JWT with:
    │ ├─ sub: service-account-{pod-name}
    │ ├─ roles: ["c3i-service"]
    │ └─ google_project: "{project}"
    │
    ▼
Pod uses C3I JWT for internal mesh communication
    │ + uses Workload Identity for Google Cloud API calls
    │
    ▼
No service account keys stored in containers
    (all credentials federated through GKE + FerrisKey)
```

---

## 4. Complete Use Case Matrix

### 4.1 Gemini/AI Use Cases (6)

| ID | Use Case | Actor | Google Service | FerrisKey Role | Layer |
|---|---|---|---|---|---|
| UC-GEM-001 | Chat intent processing | sa-plan-daemon | Gemini API | c3i-service | L5 |
| UC-GEM-002 | Voice transcription | sa-plan-daemon | Gemini Live | c3i-service | L1 |
| UC-GEM-003 | Hedged inference (parallel) | sa-plan-daemon | Gemini + OpenRouter | c3i-service | L5 |
| UC-GEM-004 | RAG context enrichment | sa-plan-daemon | Gemini API | c3i-service | L5 |
| UC-GEM-005 | Gemma chat widget (UI) | Browser | Ollama (local) | c3i-viewer+ | L5 |
| UC-GEM-006 | API key rotation | Admin | Gemini API Console | c3i-admin | L0 |

### 4.2 Gmail Use Cases (6)

| ID | Use Case | Actor | Google Service | FerrisKey Role | Layer |
|---|---|---|---|---|---|
| UC-GMAIL-001 | Journal email dispatch | sa-plan-daemon | Gmail SMTP | c3i-service | L7 |
| UC-GMAIL-002 | Session summary email | sa-plan-daemon | Gmail SMTP | c3i-service | L7 |
| UC-GMAIL-003 | Password reset email | FerrisKey | Gmail SMTP | system | L0 |
| UC-GMAIL-004 | Magic link email | FerrisKey | Gmail SMTP | system | L0 |
| UC-GMAIL-005 | Search inbox (MCP) | Claude agent | Gmail API | c3i-operator+ | L5 |
| UC-GMAIL-006 | Draft proposal (MCP) | Claude agent | Gmail API | c3i-operator+ | L5 |

### 4.3 Calendar Use Cases (6)

| ID | Use Case | Actor | Google Service | FerrisKey Role | Layer |
|---|---|---|---|---|---|
| UC-CAL-001 | MEDDPICC deal review | Sales operator | Calendar API | c3i-operator | L5 |
| UC-CAL-002 | Weekly rhythm planning | Sales operator | Calendar API | c3i-operator | L5 |
| UC-CAL-003 | Meeting prep brief | Sales agent | Calendar API | c3i-viewer+ | L5 |
| UC-CAL-004 | Time suggestion | Sales agent | Calendar API | c3i-viewer+ | L5 |
| UC-CAL-005 | OODA review scheduling | System | Calendar API | c3i-service | L5 |
| UC-CAL-006 | Incident war room | SRE | Calendar API | c3i-operator | L4 |

### 4.4 Drive Use Cases (6)

| ID | Use Case | Actor | Google Service | FerrisKey Role | Layer |
|---|---|---|---|---|---|
| UC-DRV-001 | FY27 plan sync | rclone | Drive API | c3i-service | L3 |
| UC-DRV-002 | Obsidian vault sync | Obsidian app | Drive API | user-scoped | L3 |
| UC-DRV-003 | ZK document import | FY27-ZK binary | Drive (FUSE) | c3i-service | L3 |
| UC-DRV-004 | File search (MCP) | Claude agent | Drive API | c3i-operator+ | L5 |
| UC-DRV-005 | Download attachment | Claude agent | Drive API | c3i-viewer+ | L5 |
| UC-DRV-006 | Upload proposal | Sales agent | Drive API | c3i-operator | L5 |

### 4.5 Google Chat Use Cases (6)

| ID | Use Case | Actor | Google Service | FerrisKey Role | Layer |
|---|---|---|---|---|---|
| UC-GCHAT-001 | Intent delivery (inbound) | GChat user | Chat API + Pub/Sub | mapped via GChat identity | L7 |
| UC-GCHAT-002 | Response broadcast | sa-plan-daemon | Chat Webhook | c3i-service | L7 |
| UC-GCHAT-003 | Alert notification | System | Chat Webhook | c3i-service | L7 |
| UC-GCHAT-004 | Pipeline reminder | Sales agent | Chat Webhook | c3i-service | L7 |
| UC-GCHAT-005 | OTel span notification | Zenoh subscriber | Chat Webhook | c3i-service | L1 |
| UC-GCHAT-006 | Health degradation alert | Sentinel | Chat Webhook | c3i-service | L0 |

### 4.6 GCP Infrastructure Use Cases (6)

| ID | Use Case | Actor | Google Service | FerrisKey Role | Layer |
|---|---|---|---|---|---|
| UC-GCP-001 | Pub/Sub message polling | sa-plan-daemon | Pub/Sub API | c3i-service | L6 |
| UC-GCP-002 | Workload Identity auth | GKE pod | Cloud IAM | c3i-service | L4 |
| UC-GCP-003 | Cloud Logging export | Observability | Cloud Logging | c3i-service | L1 |
| UC-GCP-004 | Artifact Registry push | CI/CD | Artifact Registry | c3i-admin | L4 |
| UC-GCP-005 | Cloud Monitoring metrics | Prometheus | Cloud Monitoring | c3i-service | L1 |
| UC-GCP-006 | Secret Manager sync | FerrisKey | Secret Manager | c3i-admin | L0 |

### 4.7 Identity Federation Use Cases (6)

| ID | Use Case | Actor | Google Service | FerrisKey Role | Layer |
|---|---|---|---|---|---|
| UC-FED-001 | Google SSO login | Operator | Google OIDC | mapped to c3i role | L0 |
| UC-FED-002 | Google group -> role mapping | Admin | Workspace Directory | c3i-admin | L0 |
| UC-FED-003 | Google MFA passthrough | Operator | Google 2FA | affects L0 MFA check | L0 |
| UC-FED-004 | Google service account link | Admin | Cloud IAM | c3i-admin | L0 |
| UC-FED-005 | Token exchange for APIs | sa-plan-daemon | OAuth2 token endpoint | c3i-service | L3 |
| UC-FED-006 | Credential rotation | Admin | FerrisKey admin | c3i-admin | L0 |

---

## 5. Impact on System Components

### 5.1 Impact by Fractal Layer

```
L0 CONSTITUTIONAL ████████████ HIGH IMPACT
  ├─ FerrisKey IAM is L0 (auth is constitutional)
  ├─ Google SSO federation (identity provider)
  ├─ MFA passthrough from Google 2FA
  ├─ API key storage moved to FerrisKey vault
  ├─ Secret Manager integration for credential sync
  └─ Emergency stop now requires FerrisKey MFA

L1 ATOMIC/DEBUG ████████ MEDIUM IMPACT
  ├─ OTel spans for all Google API calls via Zenoh
  ├─ Gemini Live voice telemetry attributed to user identity
  ├─ Cloud Logging export with FerrisKey correlation IDs
  └─ Prometheus metrics tagged with FerrisKey client_id

L2 COMPONENT ████ LOW IMPACT
  ├─ Auth page UI components (Lustre SSR)
  └─ "Sign in with Google" button component

L3 TRANSACTION █████████ MEDIUM-HIGH IMPACT
  ├─ Google Drive file operations now auth-gated
  ├─ FY27 ZK import requires Drive scope
  ├─ Smriti.db secrets migrated to FerrisKey vault
  └─ Token exchange transactions logged

L4 SYSTEM ████████ MEDIUM IMPACT
  ├─ FerrisKey container #17 in boot sequence
  ├─ GKE Workload Identity for pod auth
  ├─ Container health checks include FerrisKey
  └─ Artifact Registry push requires FerrisKey JWT

L5 COGNITIVE ████████████ HIGH IMPACT
  ├─ Gemini inference now per-user attributed
  ├─ Calendar integration for OODA scheduling
  ├─ Gmail/Drive MCP tools behind RBAC
  ├─ Cortex intent processing has user context
  └─ RAG context enriched with user identity

L6 ECOSYSTEM █████████ MEDIUM-HIGH IMPACT
  ├─ Pub/Sub integration via FerrisKey service account
  ├─ Zenoh mesh carries auth events (8 new topics)
  ├─ Google Cloud IAM role mapping
  └─ Webhook -> Zenoh bridge for auth events

L7 FEDERATION ████████████ HIGH IMPACT
  ├─ Gateway broadcasts now authenticated
  ├─ GChat identity mapped to FerrisKey user
  ├─ Telegram federation via token exchange
  ├─ Multi-gateway auth coordination
  └─ Federated session management
```

### 5.2 Impact on Applications

| Application | Component | Impact | Details |
|---|---|---|---|
| **Gleam Wisp API** | auth.gleam | HIGH | OIDC validation path, RBAC middleware, Google IdP tokens |
| **Gleam Lustre UI** | auth page | MEDIUM | "Sign in with Google" flow, role display, MFA status |
| **Gleam TUI** | auth_view | LOW | Auth status display with Google identity info |
| **sa-plan-daemon** | auth.rs, cortex.rs | HIGH | Client credentials, token caching, per-user attribution |
| **sa-plan-daemon** | mcp_gworkspace.rs | HIGH | Gmail/Drive/Calendar via FerrisKey-brokered tokens |
| **sa-plan-daemon** | mcp_inference.rs | MEDIUM | API key from FerrisKey vault, per-user rate limiting |
| **sa-plan-daemon** | ingress_polling.rs | MEDIUM | Pub/Sub auth via FerrisKey service account |
| **sa-plan-daemon** | gateway.rs | MEDIUM | GChat/Telegram identity mapping |
| **FerrisKey Bridge** | webhook_zenoh.rs | HIGH | All Google auth events -> Zenoh mesh |
| **Elixir Phoenix** | Guardian + OIDC | MEDIUM | Google SSO via FerrisKey for legacy UI |
| **rclone** | FUSE mount | LOW | Eventually replace with FerrisKey-scoped Drive tokens |
| **FY27-ZK** | zettelkasten binary | LOW | Drive access for import stays via FUSE |

### 5.3 Impact on SDLC Flows

| SDLC Phase | Impact | Details |
|---|---|---|
| **Development** | LOW | Static tokens still work, FerrisKey optional in dev |
| **Build** | NONE | `gleam build` / `cargo build` unchanged |
| **Test** | LOW | Auth tests added (38 new tests), existing tests unaffected |
| **Integration Test** | MEDIUM | FerrisKey container needed for OIDC integration tests |
| **Staging Deploy** | MEDIUM | FerrisKey must be healthy before app containers, Google IdP configured |
| **Production Deploy** | HIGH | FerrisKey mandatory, Google SSO required, MFA enforced for admin |
| **Monitoring** | MEDIUM | Auth events in Zenoh, OTel spans for Google API calls |
| **Incident Response** | MEDIUM | SRE authenticates via Google SSO, MFA for emergency stop |
| **Post-Incident** | LOW | Auth audit trail available in Zenoh for RCA |
| **Rollback** | LOW | `FERRISKEY_ENABLED=false` reverts to static tokens |

### 5.4 Impact on SRE Flows

| SRE Activity | Before FerrisKey | After FerrisKey |
|---|---|---|
| **On-call login** | Static token (same for everyone) | Google SSO -> personal identity -> audit trail |
| **Health check** | GET /health (open) | GET /health (still open, no change) |
| **Container restart** | curl with static token | curl with personal JWT (L4 access required) |
| **Emergency stop** | curl with static token | JWT + MFA required (SC-IAM-004) |
| **Key rotation** | Manual Smriti.db update | FerrisKey admin console + webhook notification |
| **User access review** | N/A (single operator) | FerrisKey admin console: list users, roles, sessions |
| **Credential leak response** | Rotate app password | Revoke FerrisKey token + rotate client secret |
| **Compliance audit** | Manual log review | Zenoh auth event query with timestamp range |
| **Capacity planning** | No per-user metrics | Per-user API call attribution via FerrisKey claims |
| **Runbook automation** | Static token in scripts | Service account JWT (auto-rotating, no human credentials in CI) |

---

## 6. Zenoh Topic Map: Google Integration Events

```
indrajaal/
├── auth/
│   ├── google/
│   │   ├── sso/login          # Google SSO login events
│   │   ├── sso/logout         # Google SSO logout events
│   │   ├── token/exchanged    # FerrisKey -> Google token exchange
│   │   ├── token/refreshed    # Google token auto-refresh
│   │   ├── token/revoked      # Google token revocation
│   │   ├── gmail/send         # Gmail API send events
│   │   ├── calendar/event     # Calendar event CRUD
│   │   ├── drive/access       # Drive file access
│   │   └── pubsub/pull        # Pub/Sub polling events
│   ├── login                  # All login events (any IdP)
│   ├── logout                 # All logout events
│   ├── role/changed           # Role assignment changes
│   └── mfa/failed             # MFA failures
├── otel/spans/
│   ├── auth/{event_type}      # OTel spans for all auth events
│   ├── inference/{tier}       # Gemini inference spans
│   ├── email/sent             # Email dispatch spans
│   └── calendar/event         # Calendar operation spans
├── gateway/
│   ├── gchat/                 # Google Chat message events
│   └── telegram/              # Telegram message events
└── l5/cog/
    └── trace/{id}             # Pipeline trace (includes Gemini response time)
```

---

## 7. Security Considerations

### 7.1 Credential Storage Migration

| Credential | Current Storage | Target Storage | Migration Path |
|---|---|---|---|
| `gemini_api_key` | Smriti.db (plaintext) | FerrisKey vault (encrypted) | FerrisKey client attribute |
| `openrouter_api_key` | Smriti.db | FerrisKey vault | FerrisKey client attribute |
| `smtp_password` (Gmail) | Smriti.db | FerrisKey vault | FerrisKey realm SMTP config |
| `google_refresh_token` | Smriti.db | FerrisKey user attribute | FerrisKey IdP link storage |
| `gcp_project_id` | Smriti.db | FerrisKey realm config | Environment variable + realm attribute |
| `gchat_webhook_url` | Smriti.db | FerrisKey client attribute | Per-client webhook URL |

### 7.2 Threat Model: Google-Specific

| Threat | Mitigation | STAMP |
|---|---|---|
| Stolen Google OAuth2 token | FerrisKey short-lived tokens (30min), auto-revoke on suspicious activity | SC-AUTH-003 |
| API key leak | FerrisKey vault encryption, key rotation via admin console | SC-IAM-008 |
| Phishing via Google SSO | MFA required for L0, domain restriction to @bountytek.com | SC-IAM-004 |
| Unauthorized Pub/Sub access | FerrisKey service account scoping, egress-only pattern | SC-AUTH-008 |
| GChat webhook abuse | Rate limiting per-user, webhook URL rotation | SC-SEC-008 |
| Drive data exfiltration | FerrisKey audit trail, per-folder RBAC scoping | SC-IAM-005 |

---

## 8. Implementation Roadmap

### Phase A: Immediate (This Sprint)
- [x] FerrisKey subproject created
- [x] OIDC token validation in Gleam
- [x] Fractal RBAC mapping
- [x] Webhook -> Zenoh bridge
- [ ] Google IdP configuration in FerrisKey realm

### Phase B: Google Identity Federation (Next Sprint)
- [ ] Configure Google OIDC broker in FerrisKey
- [ ] "Sign in with Google" flow in Lustre auth page
- [ ] Google Workspace group -> FerrisKey role mapper
- [ ] Google MFA passthrough for L0 operations

### Phase C: Google API Token Brokering (Sprint +2)
- [ ] FerrisKey -> Google OAuth2 token exchange
- [ ] Gmail API via FerrisKey-brokered tokens
- [ ] Calendar API native integration in sa-plan-daemon
- [ ] Drive API scoped access via FerrisKey

### Phase D: GCP Infrastructure (Sprint +3)
- [ ] Migrate credentials from Smriti.db to FerrisKey vault
- [ ] Pub/Sub auth via FerrisKey service account
- [ ] Cloud Logging export with FerrisKey correlation IDs
- [ ] GKE Workload Identity federation

### Phase E: Full Production (Sprint +4)
- [ ] Disable static token fallback (SC-AUTH-006)
- [ ] Enforce MFA for all admin users
- [ ] Complete audit trail verification
- [ ] Cloud Monitoring integration for auth metrics

---

## 9. STAMP & Constitutional Alignment

### New STAMP Constraints for Google Integration

| ID | Constraint | Severity |
|---|---|---|
| SC-GCP-001 | Google API calls MUST use FerrisKey-brokered tokens (no direct API keys) | HIGH |
| SC-GCP-002 | Inbound Google traffic MUST use egress-only polling (no exposed endpoints) | CRITICAL |
| SC-GCP-003 | Google credentials MUST be stored in FerrisKey vault (not Smriti.db) | HIGH |
| SC-GCP-004 | Google SSO users MUST be mapped to FerrisKey roles via domain rules | HIGH |
| SC-GCP-005 | Google API rate limits MUST be monitored via Zenoh telemetry | MEDIUM |
| SC-GCP-006 | Google token exchange events MUST produce OTel spans | HIGH |

### Constitutional Alignment

| Invariant | Google Integration Alignment |
|---|---|
| Psi-0 (Existence) | FerrisKey health gates all Google API access — no auth = no Google calls |
| Psi-3 (Verification) | Every Google API call traceable via OTel span with FerrisKey correlation ID |
| Psi-4 (Alignment) | Google Workspace groups map to fractal roles — preserving human-defined access boundaries |
| Psi-5 (Truthfulness) | No hardcoded Google credentials — all from FerrisKey vault (verifiable, auditable) |
| Omega-0 (Founder) | Founder's Google account = c3i-admin via @bountytek.com domain match |

---

## 10. Conclusion

The Google Cloud integration through FerrisKey creates a **unified identity plane** that replaces 6 disparate auth methods (API keys, app passwords, webhook URLs, ADC, rclone OAuth, MCP OAuth) with a single OIDC-federated flow. Key outcomes:

1. **42 use cases** across 7 Google service families — all auth-gated through FerrisKey RBAC
2. **Egress-only** pattern enforced for all inbound Google traffic (anti-pattern [zk-03d2bc227da29769])
3. **Per-user attribution** for all Google API costs (Gemini inference, Gmail, Drive)
4. **Credential consolidation** from Smriti.db + env vars + rclone config -> FerrisKey vault
5. **Audit trail** for every Google service interaction via Zenoh OTel spans
6. **Google SSO** enables multi-user access with domain-based role mapping
7. **Zero inbound ports** maintained — Google services accessed via egress-only client calls

The system transitions from "single operator with scattered API keys" to "enterprise-grade identity-federated Google Cloud integration" while maintaining backward compatibility via `FERRISKEY_ENABLED` toggle.
