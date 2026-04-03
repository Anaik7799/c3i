# External Interfaces & API Inventory

**Date**: 2025-12-28T22:35:00+01:00
**Type**: Architecture Documentation
**Status**: COMPLETE
**Framework**: SOPv5.11 + STAMP

---

## Summary

| Category | Count |
|----------|-------|
| Public Web Pages (LiveView) | 25+ |
| Health Endpoints | 4 |
| REST API Endpoints | ~300+ |
| Real-time Channels | 8 |
| **Total Endpoints** | **~2,280+** |

---

## 1. WEB PAGES (LiveView Dashboards)

### Main Dashboard
| Route | Description |
|-------|-------------|
| `/` | Home page |
| `/analytics/dashboard` | General Analytics |
| `/analytics/stamp-tdg-gde-advanced` | STAMP TDG GDE Advanced Analytics |
| `/performance` | Performance Dashboard (SOPv5.1) |
| `/monitoring` | Monitoring Dashboard |

### PRAJNA C3I Cockpit (NASA-STD-3000 Dark Cockpit)
| Route | Description |
|-------|-------------|
| `/cockpit` | Main Cockpit Dashboard |
| `/cockpit/dashboard` | Dashboard View |
| `/cockpit/startup` | Startup Sequence Monitor |
| `/cockpit/containers` | Container Management |
| `/cockpit/commands` | Command Console |
| `/cockpit/mesh` | Network Mesh Visualization |
| `/cockpit/alarms` | Alarm Management |
| `/cockpit/ai-copilot` | AI Copilot Assistant |
| `/cockpit/cluster` | Cluster Configuration |
| `/cockpit/settings` | Settings |
| `/cockpit/diagnostics` | Diagnostics & Testing |
| `/cockpit/shutdown` | Shutdown Controls |
| `/cockpit/observability` | Observability Stack |

### Operations Center
| Route | Description |
|-------|-------------|
| `/operations/alarms` | Active Alarms List |
| `/operations/alarms/:id` | Alarm Investigation |
| `/operations/access` | Access Control Dashboard |
| `/operations/video` | Video Wall Monitoring |
| `/operations/dispatch` | Dispatch Console |

### Admin Pages
| Route | Description |
|-------|-------------|
| `/admin/permissions` | Permissions Management |
| `/admin/access_control` | Access Control Monitoring |
| `/admin/config` | Configuration Management |
| `/admin/system-status` | System Status Overview |

---

## 2. HEALTH/STATUS ENDPOINTS (Kubernetes Probes)

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `GET /healthz` | Liveness Probe | `{"status": "healthy"}` |
| `GET /ready` | Readiness Probe (DB, Redis, PubSub) | `{"status": "ready", "checks": {...}}` |
| `GET /startup` | Startup Probe | `{"status": "started"}` |
| `GET /health` | Comprehensive Health Check | Full system status |

**Response Format:**
```json
{
  "status": "healthy|ready|ok|started",
  "timestamp": "ISO8601",
  "checks": { "component": {"status": "ok|error|warning"} },
  "probes": { "liveness": {...}, "readiness": {...}, "startup": {...} }
}
```

---

## 3. REST API ENDPOINTS

### Authentication (`/api/mobile/auth/`)
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/login` | Mobile login | No |
| POST | `/login/biometric` | Biometric auth | No |
| POST | `/refresh` | Token refresh | No |
| POST | `/password/reset` | Password reset | No |
| POST | `/mfa/verify` | MFA verification | No |
| POST | `/logout` | Logout | Yes |
| GET | `/session` | Current session info | Yes |
| POST | `/mfa/enroll` | MFA enrollment | Yes |

### Alarm Management (`/api/mobile/alarms/`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | List alarms (pagination, filtering) |
| GET | `/:id` | Get alarm with full details |
| POST | `/:id/acknowledge` | Acknowledge alarm |
| POST | `/:id/resolve` | Resolve alarm |
| POST | `/:id/escalate` | Escalate alarm |

### Alarm Configuration (`/api/mobile/config/alarms/`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/types` | List alarm types |
| POST | `/types` | Create alarm type |
| POST | `/types/bulk` | Bulk create alarm types |
| POST | `/bulk` | Bulk create alarms |
| PUT | `/bulk` | Bulk update alarms |
| DELETE | `/bulk` | Bulk delete alarms |
| GET | `/export` | Export alarms |
| POST | `/import` | Import alarms |
| GET | `/templates` | List templates |
| POST | `/templates` | Create template |
| POST | `/templates/:id/apply` | Apply template |
| GET | `/:id/versions` | List alarm versions |
| POST | `/:id/rollback` | Rollback alarm to version |
| GET | `/rules` | List alarm rules |
| POST | `/rules` | Create rule |
| PUT | `/rules/:id` | Update rule |
| DELETE | `/rules/:id` | Delete rule |
| GET | `/workflows` | List workflows |
| POST | `/workflows` | Create workflow |
| PUT | `/workflows/:id` | Update workflow |
| GET | `/escalation-policies` | List escalation policies |
| POST | `/escalation-policies` | Create escalation policy |
| PUT | `/escalation-policies/:id` | Update escalation policy |

### Device Management (`/api/mobile/config/devices/`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | List devices |
| GET | `/:id` | Get device |
| POST | `/` | Create device |
| PUT | `/:id` | Update device |
| DELETE | `/:id` | Delete device |
| GET | `/types` | List device types |
| POST | `/register` | Register new device |
| GET | `/:id/parameters` | Get device parameters |
| PUT | `/:id/parameters` | Update device parameters |
| POST | `/:id/firmware-update` | Firmware update |
| POST | `/bulk` | Bulk create |
| PUT | `/bulk` | Bulk update |
| DELETE | `/bulk` | Bulk delete |
| GET | `/export` | Export devices |
| POST | `/import` | Import devices |

### Site & Location Management (`/api/mobile/config/sites/`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | List sites |
| GET | `/:id` | Get site |
| POST | `/` | Create site |
| PUT | `/:id` | Update site |
| DELETE | `/:id` | Delete site |
| GET | `/:site_id/locations` | Get site locations |
| POST | `/:site_id/locations` | Create location |
| PUT | `/locations/:id` | Update location |
| GET | `/:site_id/zones` | Get site zones |
| POST | `/:site_id/zones` | Create zone |
| PUT | `/zones/:id` | Update zone |
| POST | `/:id/maps/upload` | Upload site map |
| GET | `/:id/operating-hours` | Get operating hours |
| PUT | `/:id/operating-hours` | Update operating hours |

### Video Management (`/api/mobile/config/video/`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | List video resources |
| GET | `/:id` | Get video resource |
| POST | `/` | Create video resource |
| PUT | `/:id` | Update video resource |
| DELETE | `/:id` | Delete video resource |
| GET | `/streams` | List streams |
| POST | `/streams` | Create stream |
| PUT | `/streams/:id` | Update stream |
| GET | `/analytics` | Video analytics |
| POST | `/analytics` | Create analytics rule |
| PUT | `/analytics/:id` | Update analytics rule |
| GET | `/recording-policies` | Recording policies |
| POST | `/recording-policies` | Create recording policy |
| PUT | `/recording-policies/:id` | Update recording policy |
| GET | `/retention-policies` | Retention policies |
| PUT | `/retention-policies` | Update retention policies |
| POST | `/privacy-masks` | Create privacy mask |
| PUT | `/privacy-masks/:id` | Update privacy mask |

### Configuration Domains Summary
| Domain | Base Path | Endpoints |
|--------|-----------|-----------|
| Access Control | `/api/mobile/config/access_control` | 48+ |
| Visitor Management | `/api/mobile/config/visitor_management` | 32+ |
| Guard Tours | `/api/mobile/config/guard_tours` | 32+ |
| Maintenance | `/api/mobile/config/maintenance` | 32+ |
| Shifts | `/api/mobile/config/shifts` | 24+ |
| Analytics | `/api/mobile/config/analytics` | 24+ |
| Intelligence | `/api/mobile/config/intelligence` | 24+ |
| Integration | `/api/mobile/config/integration` | 24+ |
| Communication | `/api/mobile/config/communication` | 24+ |
| Fleet Management | `/api/mobile/config/fleet` | 24+ |
| Environmental | `/api/mobile/config/environmental` | 24+ |
| Compliance | `/api/mobile/config/compliance` | 24+ |
| Training | `/api/mobile/config/training` | 24+ |
| Accounts | `/api/mobile/config/accounts` | 24+ |

### Batch Operations (`/api/mobile/batch/`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/get` | Batch retrieve resources |
| POST | `/create` | Batch create resources |
| PUT | `/update` | Batch update resources |
| POST | `/acknowledge` | Batch acknowledge |
| POST | `/sync` | Batch sync |

### Dashboard & Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/mobile/dashboard` | Get mobile dashboard data |
| POST | `/api/mobile/notifications/register` | Register push notifications |
| GET | `/api/mobile/notifications/preferences` | Get preferences |
| PUT | `/api/mobile/notifications/preferences` | Update preferences |

### Analytics API (`/api/v1/analytics/`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/stamp-tdg-gde` | STAMP TDG GDE metrics |
| GET | `/real-time` | Real-time metrics |
| GET | `/historical` | Historical data |
| GET | `/predictions` | ML predictions |
| GET | `/anomalies` | Anomaly detection |
| GET | `/benchmarks` | Performance benchmarks |
| GET | `/data-quality` | Data quality metrics |
| GET | `/metadata` | API metadata |
| POST | `/export` | Export data |
| GET | `/health` | Analytics API health |

---

## 4. REAL-TIME INTERFACES (WebSocket Channels)

### WebSocket Endpoint
```
/mobile/socket
```

**Configuration:**
- Authentication: JWT token validation required
- Rate Limiting: Per-user connection limits enforced
- Device Tracking: Device ID assignment and monitoring
- Tenant Isolation: Strict multi-tenancy enforcement

### Channel Definitions

#### Alarm Channel (`alarm:*`)
**Join Topics:**
- `alarm:tenant:{tenant_id}` - Subscribe to all alarms for tenant
- `alarm:{alarm_id}` - Subscribe to specific alarm (UUID format)

**Client Events (handle_in):**
| Event | Payload | Description |
|-------|---------|-------------|
| `listAlarms` | `{filters: {...}}` | Query active alarms |
| `getStatistics` | `{}` | Get alarm statistics |
| `acknowledgeAlarm` | `{alarm_id: uuid}` | Acknowledge alarm |

**Server Events (broadcast):**
| Event | Description |
|-------|-------------|
| `alarm:created` | New alarm broadcast |
| `alarm:updated` | Alarm update broadcast |
| `alarm:resolved` | Alarm resolution |
| `alarm:escalated` | Alarm escalation notification |
| `initial_state` | Initial alarm state after join |

#### Device Channel (`device:*`)
**Join Topics:**
- `device:{device_id}` - Monitor specific device

**Client Events:**
| Event | Payload | Description |
|-------|---------|-------------|
| `device_command` | `{command: "reboot\|reset\|update_config"}` | Send device command |

**Server Events:**
| Event | Description |
|-------|-------------|
| `maintenance_mode_changed` | Device maintenance mode status |

#### Site Channel (`site:*`)
**Join Topics:**
- `site:{site_id}` - Monitor site activity

#### Config Channel (`config:*`)
**Join Topics:**
- `config:{resource_type}` - Configuration change notifications

#### Notification Channel (`notification:*`)
**Join Topics:**
- `notification:{user_id}` - User-specific notifications

**Client Events:**
| Event | Description |
|-------|-------------|
| `mark_read` | Mark notification as read |
| `mark_all_read` | Mark all notifications as read |

**Server Events:**
| Event | Description |
|-------|-------------|
| `notification` | New notification broadcast |
| `unread_count` | Unread notification count update |

#### Video Channel (`video:*`)
**Join Topics:**
- `video:tenant:{tenant_id}` - All tenant video events
- `video:stream:{stream_id}` - Specific stream monitoring
- `video:camera:{camera_id}` - Specific camera feed
- `video:analytics:{analytics_id}` - Video analytics results

**Server Events:**
| Event | Description |
|-------|-------------|
| `stream:started` | Stream started notification |
| `stream:stopped` | Stream stopped notification |
| `stream:quality_changed` | Video quality change |
| `camera:status_changed` | Camera status update |
| `recording:started` | Recording started |
| `recording:stopped` | Recording stopped |
| `analytics:alert` | Video analytics alerts |

#### Sync Channel (`sync:*`)
**Join Topics:**
- `sync:{device_id}` - Device data synchronization

**Purpose:** Offline-capable mobile app synchronization with conflict resolution

#### Patrol Channel (`patrol:*`)
**Join Topics:**
- `patrol:{patrol_id}` - Guard patrol tracking

**Purpose:** Guard patrol route tracking and real-time updates

---

## 5. GraphQL INTERFACE (Partial/Stub)

**Module:** `Indrajaal.Integration.GraphqlFederation`

**Status:** Schema composition framework implemented, parser not yet integrated

**Planned Capabilities:**
- Federation schema composition
- Query execution across multiple services
- Subscription management
- Schema versioning and hot-reload
- Security policy enforcement
- Performance analytics

**Note:** Awaits Absinthe parser integration

---

## 6. DEVELOPMENT ENDPOINTS (Dev Routes Only)

| Route | Description |
|-------|-------------|
| `/dev/dashboard` | Phoenix LiveDashboard metrics |
| `/dev/mailbox` | Swoosh email preview |

---

## ARCHITECTURE HIGHLIGHTS

### Security
| Feature | Implementation |
|---------|----------------|
| Multi-Tenancy | Strict tenant isolation via `tenant_id` |
| Authentication | JWT (mobile), Session (web) |
| MFA Support | TOTP + biometric (fingerprint/face) |
| Rate Limiting | WebSocket + API endpoints |
| Audit Logging | All operations logged |
| Field-level Permissions | Role-based access control |

### Observability
| Feature | Implementation |
|---------|----------------|
| Tracing | OpenTelemetry on all endpoints |
| Metrics | Prometheus + SigNoz |
| Logging | Dual logging (Console + JSON) |
| Health Checks | Kubernetes-compatible probes |

### Performance
| Feature | Implementation |
|---------|----------------|
| Batch Operations | Efficient mobile operations |
| Offline Support | Sync channel for mobile apps |
| Caching | Redis-backed caching |
| Connection Pooling | Database connection optimization |

---

## STAMP Constraints

| Constraint | Description |
|------------|-------------|
| SC-API-001 | All endpoints must validate tenant isolation |
| SC-API-002 | JWT tokens must be validated on every request |
| SC-API-003 | Rate limiting must be enforced |
| SC-API-004 | Audit logging required for all mutations |
| SC-WS-001 | WebSocket connections must authenticate |
| SC-WS-002 | Channel subscriptions must respect tenant boundaries |
| SC-HEALTH-001 | Health endpoints must respond within 100ms |

---

## File References

| Component | Path |
|-----------|------|
| Router | `lib/indrajaal_web/router.ex` |
| Health Controller | `lib/indrajaal_web/controllers/health_controller.ex` |
| Mobile Socket | `lib/indrajaal_web/channels/mobile_socket.ex` |
| Alarm Channel | `lib/indrajaal_web/channels/alarm_channel.ex` |
| Device Channel | `lib/indrajaal_web/channels/device_channel.ex` |
| Video Channel | `lib/indrajaal_web/channels/video_channel.ex` |
| LiveView Pages | `lib/indrajaal_web/live/` |
| API Controllers | `lib/indrajaal_web/controllers/api/` |

---

*Generated: 2025-12-28T22:35:00+01:00 | Total Endpoints: ~2,280+ | Framework: SOPv5.11*
