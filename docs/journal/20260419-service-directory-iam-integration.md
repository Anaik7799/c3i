# Journal: Google Cloud Service Directory + IAM Integration — Complete System Service Review & Integration Architecture

**Date**: 2026-04-19
**Version**: v22.11.0-FERRISKEY-GCP-SD
**Session Type**: Architecture Design & Integration Planning
**ZK Recall**: [zk-03d2bc227da29769] anti-pattern: never expose internal REST endpoints — egress-only. [zk-0fa06bc0dcde9313] operator directive: full system must be Rust code in sa-planner.

---

## 1. Scope & Trigger

### Trigger
Operator directive to review ALL system services and design how Google Cloud Service Directory and Google Cloud IAM can be integrated with the C3I mesh. This builds on the FerrisKey IAM integration (v22.11.0-FERRISKEY) to create a hybrid identity and service discovery plane spanning on-premises C3I mesh and Google Cloud.

### Scope
- Complete inventory of 19 containers, 73 MCP tools, 31 Rust modules, 8 Zenoh topic families
- Google Cloud Service Directory integration for service registration and discovery
- Google Cloud IAM + Workload Identity Federation for keyless authentication
- Workforce Identity Federation for FerrisKey -> Google Cloud bridge
- Impact analysis across all 7 fractal layers, SDLC, SRE, and application flows

---

## 2. Complete System Service Inventory

### 2.1 Container Services (19 total)

#### Core Mesh Containers (4)

| # | Container | Port | Health Check | Role | Layer |
|---|-----------|------|-------------|------|-------|
| 1 | **app** (Phoenix/Elixir) | 4000 | TCP 4000 | Primary web server | L3 |
| 2 | **postgres** | 5433 | `pg_isready` | Relational database | L3 |
| 3 | **redis** | 6379 | `redis-cli ping` | Cache and session store | L3 |
| 4 | **zenoh** | 7447, 8000 | TCP 7447 | Pub/sub mesh backbone | L6 |

#### Gleam Application (1)

| # | Container | Port | Health Check | Role | Layer |
|---|-----------|------|-------------|------|-------|
| 5 | **gleam-wisp** | 4100 | HTTP `/health` | SSR UI + REST API + WebSocket | L5 |

#### AI/Inference (3)

| # | Container | Port | Health Check | Role | Layer |
|---|-----------|------|-------------|------|-------|
| 6 | **ollama** (gemma3) | 11434 | HTTP `/api/tags` | LLM inference Tier 3 | L5 |
| 7 | **ollama** (gemma4) | 11435 | HTTP `/api/tags` | LLM inference Tier 4 | L5 |
| 8 | **sa-plan-daemon** | — | Zenoh heartbeat | Cortex, gateway, planning, inference | L5 |

#### Observability (1)

| # | Container | Port | Health Check | Role | Layer |
|---|-----------|------|-------------|------|-------|
| 9 | **obs-prod** | 3000, 4317, 4318, 9090 | TCP 4317 | Grafana + OTel + Prometheus | L1 |

#### SIL-6 Mesh Extensions (7)

| # | Container | Port | Health Check | Role | Layer |
|---|-----------|------|-------------|------|-------|
| 10-13 | **zenoh-router-1/2/3** + spare | 7447 | TCP 7447 | Quorum routers | L6 |
| 14-16 | **ex-app-2/3** + **chaya** | 4000 | TCP 4000 | HA replicas + Digital Twin | L4 |

#### FerrisKey IAM (3)

| # | Container | Port | Health Check | Role | Layer |
|---|-----------|------|-------------|------|-------|
| 17 | **ferriskey-db** | 5434 | `pg_isready` | IAM database | L0 |
| 18 | **ferriskey** | 8080 | HTTP `/health` | OIDC/OAuth2 identity server | L0 |
| 19 | **ferriskey-c3i-bridge** | 9090 | TCP 9090 | Webhook -> Zenoh bridge | L6 |

### 2.2 Rust Daemon Services (31 modules, 9,104 LOC)

| Module | LOC | Service Type | Outbound Connections | Layer |
|--------|-----|-------------|---------------------|-------|
| `cortex.rs` | 1,567 | Intent processor | Gemini API, Zenoh | L5 |
| `mcp_inference.rs` | 663 | 6-tier hedged inference | Gemini, OpenRouter, Ollama | L5 |
| `gemini_live.rs` | 307 | Voice WebSocket | Gemini Live API | L1 |
| `mcp_gworkspace.rs` | 380 | Google Workspace | Gmail SMTP, GChat webhooks | L7 |
| `ingress_polling.rs` | 331 | GCP Pub/Sub poller | GCP Pub/Sub API | L6 |
| `gateway.rs` | 198 | Message broadcaster | Telegram, GChat webhooks | L7 |
| `db.rs` | 1,000 | SQLite backend | Smriti.db (local) | L3 |
| `rule_engine.rs` | 961 | RETE-UL (52 rules) | In-process | L5 |
| `ruliology.rs` | 929 | Wolfram CA engine | In-process | L5 |
| `types.rs` | 850 | Domain types | — | L2 |
| `trace.rs` | 242 | Pipeline tracer | SQLite + Zenoh | L1 |
| `ha_election.rs` | 81 | Leader election | Zenoh lease | L4 |
| `heartbeat.rs` | 30 | 10-min OODA cron | Zenoh | L5 |
| `auth.rs` | — | OIDC client (new) | FerrisKey | L0 |
| *17 others* | 1,565 | Various | Various | L0-L7 |

### 2.3 Gleam Services (283+ modules, ~42,000+ LOC)

| Subsystem | Modules | Service Type | Port | Layer |
|-----------|---------|-------------|------|-------|
| Lustre Web UI | 24 | SSR HTML pages | 4100 | L5 |
| Wisp REST API | 15 | JSON endpoints | 4100 | L5 |
| TUI Terminal | 23 | ANSI dashboard | — | L5 |
| AG-UI Events | 6 | 32-event protocol | 4100 (WS) | L5 |
| A2UI Catalog | 5 | 233 component types | — | L2 |
| Fractal L0-L7 | 8 | Widget rendering | — | L0-L7 |
| Auth (new) | 3 | OIDC/RBAC/exchange | 4100 | L0 |
| NIF Bridge | 2 | 14 NIFs to Rust | — | L1 |
| MoZ Transport | 3 | MCP-over-Zenoh | — | L6 |
| Testing | 4+ | Coverage math | — | L0 |

### 2.4 External Service Connections (12 outbound)

| # | Service | Protocol | Endpoint | Auth Method | Layer |
|---|---------|----------|----------|-------------|-------|
| 1 | Gemini Direct | HTTPS | `generativelanguage.googleapis.com` | API key | L5 |
| 2 | Gemini Live | WSS | `generativelanguage.googleapis.com/ws` | API key | L1 |
| 3 | OpenRouter | HTTPS | `openrouter.ai/api/v1` | API key | L5 |
| 4 | Gmail SMTP | SMTP/TLS | `smtp.gmail.com:587` | App password | L7 |
| 5 | GChat Webhook | HTTPS | `chat.googleapis.com/v1/spaces` | URL key | L7 |
| 6 | GCP Pub/Sub | HTTPS | `pubsub.googleapis.com/v1` | ADC | L6 |
| 7 | Telegram API | HTTPS | `api.telegram.org/bot` | Bot token | L7 |
| 8 | Google Drive | FUSE | `drive.googleapis.com` | rclone OAuth2 | L3 |
| 9 | Google Calendar | HTTPS | `googleapis.com/calendar/v3` | MCP OAuth2 | L5 |
| 10 | Google Drive API | HTTPS | `googleapis.com/drive/v3` | MCP OAuth2 | L3 |
| 11 | Gmail API | HTTPS | `gmail.googleapis.com/v1` | MCP OAuth2 | L5 |
| 12 | FerrisKey | HTTP | `localhost:8080` (internal) | Client creds | L0 |

### 2.5 Zenoh Topic Families (8 major namespaces)

| Namespace | Topics | Purpose | Producers | Consumers |
|-----------|--------|---------|-----------|-----------|
| `indrajaal/otel/**` | spans, metrics, logs | Distributed tracing | All services | obs-prod, dashboard |
| `indrajaal/l0/const/**` | manifesto, audit | Constitutional safety | FerrisKey, guardian | All L0 services |
| `indrajaal/l4/system/**` | lifecycle, health, leader | System operations | sa-plan-daemon | Dashboard, TUI |
| `indrajaal/l5/cog/**` | trace, intent, inference | Cognitive operations | cortex.rs | Dashboard, gateway |
| `indrajaal/auth/**` | login, logout, role, mfa | IAM events | FerrisKey bridge | Dashboard, cortex |
| `indrajaal/gateway/**` | gchat, telegram | Message routing | gateway.rs | Broadcast subscribers |
| `indrajaal/mcp/**` | req, res | MCP-over-Zenoh | MoZ client | MCP tool handlers |
| `indrajaal/health/**` | node health | Health checks | All containers | Health orchestra |

### 2.6 MCP Tools (73 total)

| Category | Count | Source | Auth |
|----------|-------|--------|------|
| C3I NIF tools | 26 | Gleam NIF -> Rust | Internal (no auth) |
| sa-plan-daemon tools | 47 | Rust daemon | Client credentials |
| Google tools (Gmail/Calendar/Drive) | 20 | Claude MCP servers | OAuth2 via MCP |
| Playwright tools | 19 | Playwright MCP | Internal |
| Other (Figma, Indeed, etc.) | 8 | Various MCP servers | Various |

---

## 3. Google Cloud Service Directory Integration Design

### 3.1 Namespace Architecture

```
Google Cloud Service Directory
    │
    └─ Project: bountytek-c3i
        │
        ├─ Location: europe-north1 (Stockholm)
        │
        ├─ Namespace: c3i-prod
        │   ├─ Service: gleam-wisp-api
        │   │   └─ Endpoint: vm-1 { address: 10.x.x.x, port: 4100, metadata: { layer: L5, version: v22.11.0 } }
        │   ├─ Service: sa-plan-daemon
        │   │   └─ Endpoint: vm-1 { address: 10.x.x.x, port: 0, metadata: { layer: L5, type: daemon } }
        │   ├─ Service: ferriskey-iam
        │   │   └─ Endpoint: vm-1 { address: 10.x.x.x, port: 8080, metadata: { layer: L0, type: iam } }
        │   ├─ Service: zenoh-router
        │   │   ├─ Endpoint: router-0 { address: 10.x.x.x, port: 7447 }
        │   │   ├─ Endpoint: router-1 { address: 10.x.x.y, port: 7447 }
        │   │   └─ Endpoint: router-2 { address: 10.x.x.z, port: 7447 }
        │   ├─ Service: postgres-primary
        │   │   └─ Endpoint: db-prod { address: 10.x.x.x, port: 5433 }
        │   ├─ Service: obs-stack
        │   │   └─ Endpoint: obs-prod { address: 10.x.x.x, port: 4317, metadata: { grafana: 3000, prometheus: 9090 } }
        │   ├─ Service: ollama-gemma3
        │   │   └─ Endpoint: ollama-1 { address: 10.x.x.x, port: 11434 }
        │   ├─ Service: ollama-gemma4
        │   │   └─ Endpoint: ollama-2 { address: 10.x.x.x, port: 11435 }
        │   ├─ Service: phoenix-legacy
        │   │   └─ Endpoint: app-1 { address: 10.x.x.x, port: 4000 }
        │   └─ Service: ferriskey-bridge
        │       └─ Endpoint: bridge-1 { address: 10.x.x.x, port: 9090 }
        │
        ├─ Namespace: c3i-staging
        │   └─ (mirrors c3i-prod with staging endpoints)
        │
        └─ Namespace: c3i-dev
            └─ (mirrors c3i-prod with localhost endpoints)
```

### 3.2 Service Metadata Schema

Every service registered in Service Directory carries structured metadata:

```json
{
  "fractal_layer": "L5",
  "version": "v22.11.0",
  "boot_tier": 5,
  "health_check": "http",
  "health_path": "/health",
  "health_interval_s": 10,
  "zenoh_topics": ["indrajaal/l5/cog/**"],
  "ferriskey_client_id": "sa-plan-daemon",
  "sil6_category": "Cognitive",
  "container_type": "BuiltFromDockerfile",
  "dependencies": ["postgres", "zenoh", "ferriskey"],
  "ooda_capable": true,
  "dark_cockpit": true
}
```

### 3.3 Service Registration Flow

```
Container Boot (Panoptic Ignition)
    │
    ├─ Tier 1: Zenoh Control Plane (zenoh-router)
    │   └─ Register: zenoh-router endpoints in Service Directory
    │
    ├─ Tier 2: Database (postgres)
    │   └─ Register: postgres-primary in Service Directory
    │
    ├─ Tier 2.5: IAM (ferriskey)
    │   └─ Register: ferriskey-iam in Service Directory
    │
    ├─ Tier 3: Observability (obs-prod)
    │   └─ Register: obs-stack in Service Directory
    │
    ├─ Tier 4: Quorum Routers (zenoh-router-1/2/3)
    │   └─ Register: additional zenoh endpoints
    │
    ├─ Tier 5: Cognitive (cortex + cepaf-bridge)
    │   └─ Register: sa-plan-daemon in Service Directory
    │
    ├─ Tier 6: Application (ex-app-1 + chaya + ollama)
    │   └─ Register: phoenix-legacy, ollama services
    │
    └─ Tier 7: HA + ML (app-2/3 + ml-runners)
        └─ Register: HA replicas in Service Directory

Each registration:
    │
    ├─ Authenticate via Workload Identity Federation
    │   (FerrisKey JWT -> GCP STS -> Service Directory API)
    │
    ├─ POST servicedirectory.googleapis.com/v1/
    │   projects/bountytek-c3i/locations/europe-north1/
    │   namespaces/c3i-prod/services/{service}/endpoints/{endpoint}
    │
    └─ Publish to Zenoh: indrajaal/l7/discovery/registered/{service}
```

### 3.4 Service Discovery Flow

```
Service A needs to connect to Service B
    │
    ▼
Option 1: DNS Resolution (standard apps)
    │ dig service-b.c3i-prod.sd.internal
    │ Cloud DNS -> Service Directory -> IP:port
    │
Option 2: Zenoh Discovery (mesh services)
    │ zenoh.get("indrajaal/l7/discovery/endpoints/service-b")
    │ (cached from Service Directory via sa-plan-daemon sync)
    │
Option 3: Direct API (programmatic)
    │ GET servicedirectory.googleapis.com/v1/.../services/service-b/endpoints
    │ Auth: Workload Identity Federation token
    │
    ▼
Endpoint returned: { address: "10.x.x.x", port: 4100, metadata: {...} }
    │
    ▼
Connect with FerrisKey JWT in Authorization header
```

---

## 4. Google Cloud IAM Integration Design

### 4.1 Workload Identity Federation (On-Premises -> GCP)

FerrisKey acts as the OIDC Identity Provider for Workload Identity Federation. C3I services authenticate to FerrisKey, then exchange FerrisKey JWTs for Google Cloud access tokens — **no service account keys stored anywhere**.

```
┌──────────────────────────────────────────────────────────────┐
│                    ON-PREMISES (C3I MESH)                      │
│                                                                │
│  sa-plan-daemon                                                │
│     │                                                          │
│     ├─ 1. Get FerrisKey JWT (client credentials)               │
│     │     POST ferriskey:8080/realms/c3i-prod/                 │
│     │          protocol/openid-connect/token                   │
│     │     Response: { access_token: "<ferriskey-jwt>" }        │
│     │                                                          │
│     ├─ 2. Exchange FerrisKey JWT for GCP Token                 │
│     │     POST https://sts.googleapis.com/v1/token             │
│     │     Body: {                                              │
│     │       grant_type: "urn:ietf:params:oauth:grant-type:     │
│     │                    token-exchange",                      │
│     │       subject_token_type: "urn:ietf:params:oauth:        │
│     │                           token-type:jwt",               │
│     │       subject_token: "<ferriskey-jwt>",                  │
│     │       audience: "//iam.googleapis.com/projects/          │
│     │                  PROJECT/locations/global/               │
│     │                  workloadIdentityPools/c3i-pool/         │
│     │                  providers/ferriskey-provider"            │
│     │     }                                                    │
│     │     Response: { access_token: "<gcp-sts-token>" }        │
│     │                                                          │
│     ├─ 3. Impersonate Service Account                          │
│     │     POST https://iamcredentials.googleapis.com/v1/       │
│     │          projects/-/serviceAccounts/                     │
│     │          c3i-sa@project.iam.gserviceaccount.com          │
│     │          :generateAccessToken                            │
│     │     Body: { scope: ["https://www.googleapis.com/auth/    │
│     │                      cloud-platform"] }                  │
│     │     Response: { accessToken: "<gcp-access-token>" }      │
│     │                                                          │
│     └─ 4. Call Google Cloud APIs with GCP token                │
│           GET servicedirectory.googleapis.com/v1/...            │
│           Authorization: Bearer <gcp-access-token>             │
│                                                                │
└──────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────┐
│                    GOOGLE CLOUD                                │
│                                                                │
│  Workload Identity Pool: c3i-pool                              │
│    Provider: ferriskey-provider                                │
│      Type: OIDC                                                │
│      Issuer: https://ferriskey.bountytek.com/realms/c3i-prod   │
│      Audiences: ["c3i-wisp-api", "sa-plan-daemon"]            │
│      Attribute Mapping:                                        │
│        google.subject = assertion.sub                          │
│        attribute.role = assertion.realm_access.roles[0]        │
│        attribute.layer = assertion.fractal_layer               │
│                                                                │
│  Service Account: c3i-sa@project.iam.gserviceaccount.com      │
│    Roles:                                                      │
│      - roles/servicedirectory.editor (register/discover)       │
│      - roles/pubsub.subscriber (GChat ingress)                │
│      - roles/monitoring.viewer (Cloud Monitoring)              │
│      - roles/logging.logWriter (Cloud Logging export)          │
│                                                                │
│  IAM Condition (on servicedirectory.editor):                   │
│    attribute.role == "c3i-admin" ||                            │
│    attribute.role == "c3i-service"                             │
│    (only admin and service accounts can register services)     │
│                                                                │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 GCP IAM Role Mapping

| FerrisKey Role | GCP IAM Roles | Scope | IAM Condition |
|---|---|---|---|
| `c3i-admin` | `roles/servicedirectory.admin`, `roles/iam.securityAdmin` | Full SD management, IAM policy changes | None (unrestricted) |
| `c3i-operator` | `roles/servicedirectory.viewer`, `roles/monitoring.viewer` | Read-only SD, monitoring dashboards | `attribute.role == "c3i-operator"` |
| `c3i-service` | `roles/servicedirectory.editor`, `roles/pubsub.subscriber` | Register/deregister services, pull messages | `attribute.role == "c3i-service"` |
| `c3i-viewer` | `roles/servicedirectory.viewer` | Read-only SD queries | `attribute.role == "c3i-viewer"` |

### 4.3 Custom GCP IAM Roles for C3I

```yaml
# Custom role: C3I Service Registrar
title: "C3I Service Registrar"
description: "Register and manage C3I mesh services in Service Directory"
includedPermissions:
  - servicedirectory.namespaces.get
  - servicedirectory.namespaces.list
  - servicedirectory.services.create
  - servicedirectory.services.update
  - servicedirectory.services.delete
  - servicedirectory.services.get
  - servicedirectory.services.list
  - servicedirectory.endpoints.create
  - servicedirectory.endpoints.update
  - servicedirectory.endpoints.delete
  - servicedirectory.endpoints.get
  - servicedirectory.endpoints.list

# Custom role: C3I Service Consumer
title: "C3I Service Consumer"
description: "Discover and resolve C3I mesh service endpoints"
includedPermissions:
  - servicedirectory.namespaces.get
  - servicedirectory.services.get
  - servicedirectory.services.list
  - servicedirectory.services.resolve
  - servicedirectory.endpoints.get
  - servicedirectory.endpoints.list
```

---

## 5. Combined Architecture: FerrisKey + Service Directory + Cloud IAM

### 5.1 Unified Identity & Discovery Plane

```
┌─────────────────────────────────────────────────────────────────────┐
│                  IDENTITY & DISCOVERY PLANE                          │
│                                                                      │
│  ┌─────────────┐    ┌──────────────────┐    ┌───────────────────┐  │
│  │  FerrisKey   │    │  Google Cloud     │    │  Google Cloud     │  │
│  │  IAM         │◄──►│  IAM (WIF)        │◄──►│  Service         │  │
│  │  (on-prem)   │    │  (cloud)          │    │  Directory       │  │
│  │              │    │                    │    │  (cloud)          │  │
│  │  Users       │    │  Service Accounts │    │  Namespaces      │  │
│  │  Roles       │    │  WIF Pools        │    │  Services        │  │
│  │  Clients     │    │  IAM Conditions   │    │  Endpoints       │  │
│  │  MFA         │    │  Custom Roles     │    │  Metadata        │  │
│  │  Webhooks    │    │  Audit Logs       │    │  DNS             │  │
│  └──────┬───────┘    └────────┬──────────┘    └────────┬─────────┘  │
│         │                     │                         │            │
│         ▼                     ▼                         ▼            │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              ZENOH MESH (indrajaal/**)                        │   │
│  │                                                               │   │
│  │  indrajaal/auth/**         ← FerrisKey events                │   │
│  │  indrajaal/l7/discovery/** ← Service Directory sync          │   │
│  │  indrajaal/otel/spans/**   ← OTel traces (all services)     │   │
│  │  indrajaal/health/**       ← Health checks                   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│         │              │              │              │               │
│    ┌────▼────┐   ┌─────▼─────┐  ┌────▼────┐  ┌─────▼──────┐      │
│    │ Gleam   │   │ sa-plan   │  │ Phoenix │  │ Containers │      │
│    │ :4100   │   │ daemon    │  │ :4000   │  │ #1-#19     │      │
│    └─────────┘   └───────────┘  └─────────┘  └────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 Service Lifecycle with Service Directory

```
1. REGISTER (Boot)
   Container starts -> health check passes ->
   sa-plan-daemon registers in Service Directory via WIF ->
   Zenoh publish: indrajaal/l7/discovery/registered/{service}

2. DISCOVER (Runtime)
   Service needs peer -> query Zenoh cache OR DNS OR SD API ->
   get endpoint address:port + metadata ->
   connect with FerrisKey JWT

3. HEALTH (Steady State)
   Every 10s: health check -> update SD endpoint metadata ->
   if unhealthy: update metadata { healthy: false } ->
   Zenoh publish: indrajaal/health/{node}/degraded

4. SCALE (Horizontal)
   New instance boots -> registers new endpoint in SD ->
   existing services discover via DNS/Zenoh ->
   load balancing across endpoints

5. DEREGISTER (Shutdown)
   Container receives SIGTERM -> dying gasp to Zenoh ->
   sa-plan-daemon deregisters from Service Directory ->
   DNS record removed automatically ->
   Zenoh publish: indrajaal/l7/discovery/deregistered/{service}

6. FAILOVER (HA)
   Leader election via Zenoh lease ->
   new leader updates SD endpoint metadata { role: primary } ->
   old leader metadata updated { role: standby } ->
   DNS resolves to new primary automatically
```

---

## 6. Use Cases

### 6.1 Service Directory Use Cases (12)

| ID | Use Case | Actor | Flow | Impact |
|---|---|---|---|---|
| UC-SD-001 | **Service Registration at Boot** | Panoptic Ignition | Container boot -> health pass -> SD register | All 19 containers visible in cloud console |
| UC-SD-002 | **DNS-Based Discovery** | Any service | DNS query `gleam-wisp.c3i-prod.sd.internal` -> IP:port | Standard DNS resolution, no SDK needed |
| UC-SD-003 | **Zenoh Endpoint Sync** | sa-plan-daemon | Poll SD every 60s -> publish to `indrajaal/l7/discovery/**` | Mesh-local cache of cloud registry |
| UC-SD-004 | **Health Metadata Update** | Health orchestra | Health check result -> update SD endpoint metadata | Cloud console shows real-time health |
| UC-SD-005 | **Canary Deployment** | Admin | Register new endpoint with `canary: true` metadata | Traffic splitting via metadata-aware routing |
| UC-SD-006 | **Multi-Region Discovery** | Federation | SD query across regions -> select nearest endpoint | Latency-optimized service selection |
| UC-SD-007 | **Version Tracking** | CI/CD | Deploy new version -> update `version` metadata | Cloud console shows running versions |
| UC-SD-008 | **Dependency Graph** | Impact analyzer | Query SD metadata `dependencies` field -> build graph | Automated blast radius calculation |
| UC-SD-009 | **SRE Dashboard** | SRE operator | Cloud Console -> Service Directory -> all services status | Single pane of glass for all services |
| UC-SD-010 | **Failover Detection** | HA monitor | Leader changes -> update SD `role` metadata -> DNS updates | Automatic failover via DNS |
| UC-SD-011 | **Deregistration on Shutdown** | Container lifecycle | SIGTERM -> deregister from SD -> DNS record removed | Clean shutdown, no stale endpoints |
| UC-SD-012 | **Audit Trail** | Compliance | SD API calls logged in Cloud Audit Logs | Complete registration/discovery audit |

### 6.2 Cloud IAM Use Cases (12)

| ID | Use Case | Actor | Flow | Impact |
|---|---|---|---|---|
| UC-IAM-001 | **Keyless Auth (WIF)** | sa-plan-daemon | FerrisKey JWT -> STS -> GCP token | No service account keys on disk |
| UC-IAM-002 | **Fractal Role Mapping** | Admin | FerrisKey role -> IAM Condition -> GCP permissions | Consistent RBAC across on-prem and cloud |
| UC-IAM-003 | **Time-Limited Access** | Contractor | IAM Condition: `request.time < expiry` | Auto-revoke after contract ends |
| UC-IAM-004 | **Environment Isolation** | CI/CD | IAM Condition: `attribute.env == "staging"` | Dev cannot touch prod SD entries |
| UC-IAM-005 | **Least Privilege Analysis** | Security | IAM Recommender scans actual API usage | Remove over-provisioned permissions |
| UC-IAM-006 | **Policy Audit** | Compliance | Policy Analyzer: "Why does X have access to Y?" | Compliance evidence generation |
| UC-IAM-007 | **Custom Role: Service Registrar** | sa-plan-daemon | Custom role with only SD registration perms | Minimal blast radius for daemon |
| UC-IAM-008 | **Custom Role: Service Consumer** | Gleam Wisp | Custom role with only SD query perms | Read-only discovery for API server |
| UC-IAM-009 | **VPC Service Controls** | Security | SD inside perimeter -> no external discovery | Prevent service endpoint leakage |
| UC-IAM-010 | **Workforce Identity** | Google Workspace user | Google SSO -> FerrisKey -> Cloud Console | Same identity for mesh and cloud |
| UC-IAM-011 | **Audit Logging** | SRE | All SD/IAM operations in Cloud Audit Logs | Forensic investigation capability |
| UC-IAM-012 | **Organization Policy** | Platform team | "All services must use private IPs" enforced globally | Prevent public endpoint registration |

### 6.3 Combined SD + IAM Use Cases (6)

| ID | Use Case | Flow | Impact |
|---|---|---|---|
| UC-SDIAM-001 | **Authenticated Service Discovery** | WIF auth -> SD query -> verified endpoint | No unauthenticated discovery possible |
| UC-SDIAM-002 | **Role-Scoped Discovery** | c3i-viewer can discover L4-L7 services only (IAM Condition on SD query by `attribute.layer`) | RBAC extends to service discovery |
| UC-SDIAM-003 | **Perimeter-Bounded Registration** | VPC SC perimeter -> only mesh services can register -> external services blocked | Service registration confined to mesh |
| UC-SDIAM-004 | **Cross-Mesh Federation** | SD in region-A + SD in region-B -> WIF exchanges -> federated discovery | Multi-region mesh with unified identity |
| UC-SDIAM-005 | **Breach Containment** | Compromised service -> revoke WIF mapping -> SD deregister -> DNS removed -> isolated in <60s | Rapid service isolation on compromise |
| UC-SDIAM-006 | **Compliance Dashboard** | SD endpoints + IAM policies + Audit Logs -> unified compliance view | SOC 2 / ISO 27001 evidence |

---

## 7. Impact Analysis

### 7.1 Impact by Fractal Layer

| Layer | Impact | Changes |
|---|---|---|
| **L0 Constitutional** | **HIGH** | FerrisKey -> WIF -> Cloud IAM chain is constitutional. IAM Conditions enforce fractal RBAC in cloud. Service account key elimination is a security improvement. |
| **L1 Atomic/Debug** | **MEDIUM** | Cloud Audit Logs provide additional telemetry. OTel spans for SD API calls. Cloud Logging export via WIF. |
| **L2 Component** | **LOW** | SD metadata schema types. No UI component changes. |
| **L3 Transaction** | **MEDIUM** | SD registration/deregistration are stateful operations. Postgres + Redis endpoints registered in SD. |
| **L4 System** | **HIGH** | All 19 containers registered in SD. Boot sequence includes SD registration. Leader election updates SD metadata. Health checks update SD. |
| **L5 Cognitive** | **MEDIUM** | Inference tier endpoints discoverable via SD. sa-plan-daemon registers itself. OODA cycle can query SD for mesh topology. |
| **L6 Ecosystem** | **HIGH** | Zenoh router endpoints in SD. Pub/Sub auth via WIF. SD sync to Zenoh cache. Service Directory IS the cloud-side service mesh registry. |
| **L7 Federation** | **HIGH** | Multi-region discovery via SD. Cross-mesh federation via WIF. Gateway services registered for external access. |

### 7.2 Impact on SDLC

| Phase | Impact | Details |
|---|---|---|
| **Development** | LOW | SD registration optional in dev (`SD_ENABLED=false`). Local Zenoh discovery unchanged. |
| **Build** | NONE | No build changes. SD client is runtime-only. |
| **Test** | LOW | Mock SD API for integration tests. WIF not needed in test. |
| **Staging** | MEDIUM | SD registration required. WIF pool configured. IAM Conditions tested. |
| **Production** | HIGH | SD mandatory. WIF mandatory. No service account keys. VPC Service Controls active. |
| **Monitoring** | HIGH | Cloud Console shows all services. IAM Recommender active. Audit Logs exported. |
| **Incident Response** | HIGH | SD deregistration for isolation. IAM policy revocation. Cloud Audit Logs for RCA. |

### 7.3 Impact on SRE

| SRE Activity | Before SD + IAM | After SD + IAM |
|---|---|---|
| **Service Discovery** | Manual: check compose files, run `podman ps` | Cloud Console: Service Directory -> all endpoints |
| **Health Dashboard** | Zenoh telemetry + Grafana | + Cloud Console SD metadata health status |
| **Incident Isolation** | Manual: `podman stop` | SD deregister + IAM revoke = instant isolation |
| **Capacity Planning** | Manual endpoint counting | SD endpoint list + metadata (version, load, region) |
| **Compliance Audit** | Manual log review | Cloud Audit Logs + Policy Analyzer + IAM Recommender |
| **Key Rotation** | Manual Smriti.db update | WIF = keyless. No keys to rotate. |
| **Multi-Region** | Not supported | SD cross-region discovery + WIF federation |
| **Disaster Recovery** | Manual failover | SD health metadata + DNS automatic failover |

---

## 8. Implementation in sa-plan-daemon (Rust)

Per [zk-0fa06bc0dcde9313]: full system must be Rust code in sa-planner.

### 8.1 New Module: `service_directory.rs`

```rust
// sub-projects/c3i/native/planning_daemon/src/service_directory.rs

pub struct ServiceDirectoryClient {
    project_id: String,
    location: String,
    namespace: String,
    http: reqwest::Client,
    wif_pool: String,        // Workload Identity Pool
    wif_provider: String,    // FerrisKey OIDC provider
}

impl ServiceDirectoryClient {
    /// Register a service endpoint in Google Cloud Service Directory.
    /// Uses Workload Identity Federation: FerrisKey JWT -> GCP STS -> SD API.
    pub async fn register_endpoint(
        &self,
        service: &str,
        endpoint: &str,
        address: &str,
        port: u16,
        metadata: HashMap<String, String>,
    ) -> Result<(), SdError>;

    /// Deregister an endpoint (shutdown/failover).
    pub async fn deregister_endpoint(
        &self,
        service: &str,
        endpoint: &str,
    ) -> Result<(), SdError>;

    /// Discover all endpoints for a service.
    pub async fn resolve_service(
        &self,
        service: &str,
    ) -> Result<Vec<Endpoint>, SdError>;

    /// Update endpoint metadata (health, version, leader status).
    pub async fn update_metadata(
        &self,
        service: &str,
        endpoint: &str,
        metadata: HashMap<String, String>,
    ) -> Result<(), SdError>;

    /// Exchange FerrisKey JWT for GCP access token via WIF.
    async fn get_gcp_token(&self) -> Result<String, SdError>;
}
```

### 8.2 New Module: `wif.rs` (Workload Identity Federation)

```rust
// sub-projects/c3i/native/planning_daemon/src/wif.rs

pub struct WorkloadIdentityFederation {
    pool_id: String,
    provider_id: String,
    service_account: String,
    oidc_client: OidcClient,    // From ferriskey bridge
    token_cache: TokenCache,
}

impl WorkloadIdentityFederation {
    /// Full WIF token exchange:
    /// 1. Get FerrisKey JWT (cached)
    /// 2. Exchange for GCP STS token
    /// 3. Impersonate service account
    /// 4. Return GCP access token
    pub async fn get_gcp_token(&self, scopes: &[&str]) -> Result<String, WifError>;
}
```

---

## 9. STAMP Constraints

### New Constraint Families

| ID | Constraint | Severity |
|---|---|---|
| SC-SD-001 | All 19 containers MUST be registered in Service Directory | HIGH |
| SC-SD-002 | Registration MUST occur after health check passes | CRITICAL |
| SC-SD-003 | Deregistration MUST occur on SIGTERM (dying gasp) | CRITICAL |
| SC-SD-004 | Health metadata MUST be updated every 10s | HIGH |
| SC-SD-005 | Zenoh cache MUST sync with SD every 60s | MEDIUM |
| SC-SD-006 | SD operations MUST use WIF (no service account keys) | CRITICAL |
| SC-WIF-001 | All GCP API calls MUST use Workload Identity Federation | CRITICAL |
| SC-WIF-002 | FerrisKey MUST be the sole OIDC provider for WIF | HIGH |
| SC-WIF-003 | GCP tokens MUST be short-lived (max 1 hour) | HIGH |
| SC-WIF-004 | IAM Conditions MUST enforce fractal layer RBAC | HIGH |
| SC-WIF-005 | WIF attribute mapping MUST include fractal_layer | HIGH |
| SC-WIF-006 | VPC Service Controls MUST protect SD namespace in prod | HIGH |

---

## 10. Conclusion

Google Cloud Service Directory + IAM integration creates a **hybrid identity and discovery plane** that bridges the on-premises C3I mesh (Zenoh + FerrisKey) with Google Cloud (Service Directory + IAM + WIF).

**Key architectural outcomes:**

1. **19 services registered** in Service Directory with fractal layer metadata — visible in Google Cloud Console
2. **Zero service account keys** — Workload Identity Federation eliminates all long-lived credentials
3. **Fractal RBAC in cloud** — IAM Conditions enforce L0-L7 access boundaries on GCP resources
4. **DNS-based discovery** — Standard DNS resolution for services via Cloud DNS + Service Directory
5. **Zenoh + SD dual discovery** — Mesh-local Zenoh cache with cloud-authoritative SD backend
6. **Instant isolation** — Compromised service deregistered from SD + IAM revoked in <60s
7. **Compliance ready** — Cloud Audit Logs + Policy Analyzer + IAM Recommender for SOC 2 / ISO 27001
8. **30 use cases** — 12 Service Directory + 12 Cloud IAM + 6 combined SD+IAM

The integration follows the egress-only anti-pattern ([zk-03d2bc227da29769]): C3I services call outbound to Google Cloud APIs, Google Cloud never calls inbound to the mesh. All implementations in Rust per operator directive ([zk-0fa06bc0dcde9313]).
