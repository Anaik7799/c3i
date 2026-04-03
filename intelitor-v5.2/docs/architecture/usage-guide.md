# Indrajaal Usage Guide

**Version**: 1.0.0
**Date**: 2025-12-19
**Framework**: SOPv5.11 Cybernetic Architecture
**Classification**: OPERATIONAL DOCUMENTATION

---

## Table of Contents

1. [Overview](#1-overview)
2. [Web Dashboard](#2-web-dashboard)
3. [Mobile Applications](#3-mobile-applications)
4. [API Integration](#4-api-integration)
5. [Authentication & Security](#5-authentication--security)
6. [Alarm Management](#6-alarm-management)
7. [Access Control](#7-access-control)
8. [System Monitoring](#8-system-monitoring)
9. [Configuration Management](#9-configuration-management)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Overview

### 1.1 System Purpose

Indrajaal is an enterprise security management platform providing:

- **Alarm Processing**: Real-time alarm monitoring and intelligent response
- **Access Control**: RBAC with anti-passback and multi-factor authentication
- **Video Surveillance**: Integration with 100+ camera feeds
- **Guard Tour Management**: Patrol scheduling and checkpoint verification
- **Visitor Management**: Pre-registration, check-in/out, badge printing
- **Compliance Reporting**: SOX, GDPR, HIPAA, PCI DSS, IEC 61508

### 1.2 User Roles

| Role | Description | Access Level |
|------|-------------|--------------|
| **System Administrator** | Full system access, configuration management | All features |
| **Security Manager** | Alarm management, access control, reporting | Operational + Reports |
| **Security Operator** | Real-time monitoring, alarm response | Operational |
| **Guard** | Mobile patrol, checkpoint scanning | Mobile App |
| **Receptionist** | Visitor management, badge printing | Visitor Module |
| **Auditor** | Read-only access to logs and reports | Reports Only |

### 1.3 Accessing the System

**Web Dashboard**:
```
Production: https://indrajaal.example.com
Development: http://localhost:4000
```

**Mobile Apps**:
- iOS: App Store "Indrajaal Guard"
- Android: Google Play "Indrajaal Guard"

---

## 2. Web Dashboard

### 2.1 Dashboard Overview

The main dashboard provides real-time visibility into security operations:

```
┌─────────────────────────────────────────────────────────────────────┐
│  INTELITOR SECURITY DASHBOARD                      [User] [Logout]  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐│
│  │ Active      │  │ Processing  │  │ Avg         │  │ System      ││
│  │ Alarms: 12  │  │ Rate: 45/s  │  │ Latency:23ms│  │ Health: OK  ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘│
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ LIVE ALARM FEED                                    [Filter] [▼] ││
│  ├─────────────────────────────────────────────────────────────────┤│
│  │ 10:45:23  MOTION   Zone A-12     Warehouse Entry    [ACK] [ESC] ││
│  │ 10:44:58  DOOR     Door D-07     Main Lobby         [ACK] [ESC] ││
│  │ 10:44:12  TAMPER   Panel P-03    Server Room        [ACK] [ESC] ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  ┌─────────────────────────┐  ┌─────────────────────────────────┐  │
│  │ SITE MAP               │  │ RECENT ACTIVITY                 │  │
│  │ [Interactive Floor Plan]│  │ • Guard A completed patrol      │  │
│  │                         │  │ • Visitor John D. checked in    │  │
│  │                         │  │ • Door D-12 unlocked remotely   │  │
│  └─────────────────────────┘  └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Navigation Menu

| Menu Item | Path | Description |
|-----------|------|-------------|
| **Dashboard** | `/` | Main overview with real-time metrics |
| **Alarms** | `/alarms` | Alarm management and history |
| **Access Control** | `/admin/access_control` | Door/zone management |
| **Permissions** | `/admin/permissions` | User permission management |
| **Analytics** | `/analytics/stamp-tdg-gde-advanced` | Advanced analytics dashboard |
| **Performance** | `/performance` | System performance metrics |
| **Reports** | `/reports` | Compliance and operational reports |

### 2.3 Real-Time Monitoring Dashboard

Access via: `/monitoring`

The monitoring dashboard provides live metrics with 5-second auto-refresh:

```elixir
# Metrics displayed:
- Active Alarms Count
- Processing Rate (alarms/second)
- Average Latency (milliseconds)
- Queue Depth
- Agent Status (50-agent hierarchy)
```

**Features**:
- Auto-refresh every 5 seconds
- Manual refresh button
- Filter by alarm type/zone/priority
- Export to CSV/PDF

### 2.4 System Status Dashboard

Access via: `/system-status`

Displays comprehensive system health:

| Section | Metrics |
|---------|---------|
| **Container Health** | indrajaal-app, indrajaal-db, indrajaal-obs status |
| **Agent Hierarchy** | 50-agent status (1 Executive, 10 Domain, 15 Functional, 24 Workers) |
| **Database Health** | PostgreSQL 17/TimescaleDB connection pool status |
| **Cache Health** | Redis/ETS cache hit rates |
| **STAMP Compliance** | 195 safety constraint status |
| **OODA Loop** | Loop latency, decision quality metrics |

---

## 3. Mobile Applications

### 3.1 Guard Mobile App

The mobile app is optimized for battery efficiency and offline operation.

**Key Features**:
- Alarm notifications (push + in-app)
- Guard tour checkpoint scanning
- Incident reporting with photos
- Offline mode with sync
- Biometric authentication

### 3.2 Login Flow

```
┌─────────────────────┐
│   INTELITOR GUARD   │
│                     │
│  ┌───────────────┐  │
│  │ Username      │  │
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ Password      │  │
│  └───────────────┘  │
│                     │
│  [   LOGIN    ]     │
│                     │
│  ☐ Remember Device  │
│                     │
│  [Use Biometrics]   │
└─────────────────────┘
```

**Authentication Steps**:
1. Enter username/password
2. Device authorization check
3. MFA challenge (if required)
4. Session token generation
5. Dashboard access

### 3.3 Alarm Management (Mobile)

View and respond to alarms:

```
GET /api/mobile/alarms

Response:
{
  "alarms": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "type": "MOTION",
      "zone": "Zone A-12",
      "description": "Motion detected in warehouse",
      "priority": "high",
      "timestamp": "2025-12-19T10:45:23Z",
      "status": "active",
      "actions": ["acknowledge", "escalate", "dispatch"]
    }
  ],
  "meta": {
    "total": 12,
    "page": 1,
    "per_page": 20
  }
}
```

### 3.4 Guard Tour

Execute patrol checkpoints:

```
POST /api/mobile/guard-tours/{tour_id}/checkpoints/{checkpoint_id}/scan

Request:
{
  "scan_type": "nfc",
  "device_id": "device-123",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 10
  },
  "notes": "All clear"
}

Response:
{
  "checkpoint": {
    "id": "cp-456",
    "name": "Loading Dock A",
    "status": "completed",
    "scanned_at": "2025-12-19T10:50:00Z"
  },
  "tour_progress": {
    "completed": 5,
    "total": 12,
    "percentage": 41.67
  },
  "next_checkpoint": {
    "id": "cp-457",
    "name": "Parking Level 1",
    "distance_meters": 150
  }
}
```

### 3.5 Offline Mode

The mobile app supports offline operation:

1. **Data Caching**: Recent alarms, checkpoints, and configurations cached locally
2. **Queue Operations**: Actions queued when offline
3. **Sync on Reconnect**: Automatic sync with conflict resolution
4. **Offline Indicators**: Clear visual indication of offline status

---

## 4. API Integration

### 4.1 API Authentication

All API requests require JWT authentication:

```bash
# Login to obtain token
curl -X POST https://api.indrajaal.example.com/api/mobile/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "operator@example.com",
    "password": "secure_password",
    "device_id": "device-12345"
  }'

# Response
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "refresh_eyJhbGciOiJIUzI1NiIs...",
  "expires_at": "2025-12-19T22:00:00Z",
  "user": {
    "id": "user-123",
    "name": "John Operator",
    "role": "security_operator"
  }
}
```

### 4.2 Using the Token

Include the token in subsequent requests:

```bash
curl -X GET https://api.indrajaal.example.com/api/mobile/alarms \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### 4.3 Token Refresh

Tokens expire after 8 hours. Refresh before expiry:

```bash
POST /api/mobile/auth/refresh

Request:
{
  "refresh_token": "refresh_eyJhbGciOiJIUzI1NiIs..."
}

Response:
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9_NEW...",
  "expires_at": "2025-12-20T06:00:00Z"
}
```

### 4.4 API Rate Limits

| Endpoint Category | Rate Limit | Window |
|-------------------|------------|--------|
| Authentication | 10 requests | 1 minute |
| Alarms | 100 requests | 1 minute |
| Configuration | 50 requests | 1 minute |
| Batch Operations | 20 requests | 1 minute |

### 4.5 Batch Operations

For efficiency, use batch endpoints:

```bash
POST /api/mobile/batch

Request:
{
  "operations": [
    {
      "id": "op1",
      "method": "GET",
      "path": "/alarms",
      "params": {"status": "active"}
    },
    {
      "id": "op2",
      "method": "GET",
      "path": "/devices",
      "params": {"zone": "zone-a"}
    },
    {
      "id": "op3",
      "method": "GET",
      "path": "/sites/current"
    }
  ]
}

Response:
{
  "results": {
    "op1": {"status": 200, "data": {...}},
    "op2": {"status": 200, "data": {...}},
    "op3": {"status": 200, "data": {...}}
  },
  "meta": {
    "total_operations": 3,
    "successful": 3,
    "failed": 0
  }
}
```

---

## 5. Authentication & Security

### 5.1 Multi-Factor Authentication (MFA)

Indrajaal supports multiple MFA methods:

| Method | Description | Setup |
|--------|-------------|-------|
| **TOTP** | Time-based codes (Google Authenticator) | Profile > Security > Enable TOTP |
| **Biometrics** | Fingerprint/Face ID on mobile | Mobile App > Settings > Biometrics |
| **Hardware Key** | FIDO2/WebAuthn security keys | Profile > Security > Add Hardware Key |
| **SMS** | Backup SMS codes (not recommended) | Profile > Security > SMS Backup |

### 5.2 MFA Challenge Flow

When MFA is required:

```
POST /api/mobile/auth/login
Response: {"mfa_required": true, "challenge_id": "ch-123", "methods": ["totp", "biometric"]}

POST /api/mobile/auth/mfa/verify
Request: {"challenge_id": "ch-123", "method": "totp", "code": "123456"}
Response: {"token": "...", "refresh_token": "..."}
```

### 5.3 Session Management

**Session Properties**:
- Duration: 8 hours (configurable)
- Single session per device (configurable)
- Automatic logout on inactivity (30 minutes default)
- Session revocation by admin

**View Active Sessions**:
```
Profile > Security > Active Sessions

┌─────────────────────────────────────────────────────────────────┐
│ ACTIVE SESSIONS                                                  │
├─────────────────────────────────────────────────────────────────┤
│ Desktop Chrome - Windows 10                                      │
│ Last active: 2 minutes ago                     [Revoke]          │
│                                                                  │
│ Mobile App - iPhone 14                                           │
│ Last active: 15 minutes ago                    [Revoke]          │
│                                                                  │
│ API Integration - Server                                         │
│ Last active: 1 hour ago                        [Revoke]          │
└─────────────────────────────────────────────────────────────────┘
```

### 5.4 Microsoft Entra ID SSO

For enterprise deployments with Azure AD:

1. **Configuration**: Admin > Integrations > Microsoft Entra ID
2. **Login**: Click "Sign in with Microsoft" on login page
3. **Mapping**: AD groups map to Indrajaal roles automatically

---

## 6. Alarm Management

### 6.1 Alarm Types

| Type | Code | Priority | Description |
|------|------|----------|-------------|
| **Intrusion** | INTR | Critical | Unauthorized entry detected |
| **Motion** | MOTN | High | Motion sensor triggered |
| **Door** | DOOR | Medium | Door opened/forced/held |
| **Tamper** | TAMP | Critical | Device tampering detected |
| **Fire** | FIRE | Critical | Fire/smoke detected |
| **Panic** | PANC | Critical | Panic button activated |
| **Medical** | MEDC | Critical | Medical emergency |
| **Technical** | TECH | Low | Equipment malfunction |

### 6.2 Alarm Workflow

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  ACTIVE  │───▶│ACKNOWLEDGED│───▶│ RESOLVED │───▶│ ARCHIVED │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │                │                │
     │                │                │
     ▼                ▼                ▼
┌──────────┐    ┌──────────┐    ┌──────────┐
│ ESCALATE │    │ DISPATCH │    │ INCIDENT │
└──────────┘    └──────────┘    └──────────┘
```

### 6.3 Acknowledging Alarms

**Web Dashboard**:
1. Click alarm in feed
2. Review details and camera feed
3. Click "Acknowledge" button
4. Add notes (optional)
5. Select action (resolve/escalate/dispatch)

**Mobile App**:
```
POST /api/mobile/alarms/{alarm_id}/acknowledge

Request:
{
  "notes": "Verified false alarm - delivery driver",
  "action": "resolve"
}
```

### 6.4 Alarm Escalation

Escalation paths are configurable per alarm type:

```
Level 1: Security Operator (immediate)
Level 2: Security Manager (5 min no response)
Level 3: Site Manager (15 min no response)
Level 4: Emergency Services (critical alarms)
```

### 6.5 Alarm Reports

Generate alarm reports:

```
Reports > Alarm Reports > Generate

Options:
- Date Range: [Start] to [End]
- Alarm Types: [Select types]
- Zones: [Select zones]
- Status: [All/Active/Resolved]
- Format: PDF/CSV/Excel
```

---

## 7. Access Control

### 7.1 Door Management

View and control doors:

```
┌─────────────────────────────────────────────────────────────────┐
│ ACCESS CONTROL - DOORS                          [Add Door] [▼]  │
├─────────────────────────────────────────────────────────────────┤
│ Name           │ Status   │ Zone      │ Last Access │ Actions   │
├────────────────┼──────────┼───────────┼─────────────┼───────────┤
│ Main Entrance  │ 🔒Locked │ Lobby     │ 10:42 AM    │[Unlock][…]│
│ Server Room    │ 🔒Locked │ IT Area   │ 09:15 AM    │[Unlock][…]│
│ Parking Gate   │ 🔓Open   │ Parking   │ 10:45 AM    │[Lock][…]  │
│ Fire Exit A    │ 🔒Locked │ Emergency │ --          │[Monitor]  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Remote Door Control

**Unlock Door**:
```
POST /api/mobile/access-control/doors/{door_id}/unlock

Request:
{
  "duration_seconds": 10,
  "reason": "Visitor entry - Badge #12345"
}
```

**Lock Door**:
```
POST /api/mobile/access-control/doors/{door_id}/lock

Request:
{
  "reason": "End of business hours"
}
```

### 7.3 Access Groups

Manage user access groups:

| Group | Access Level | Doors |
|-------|-------------|-------|
| **All Staff** | Mon-Fri 7AM-7PM | Main, Parking, Cafeteria |
| **IT Department** | 24/7 | All + Server Room |
| **Executives** | 24/7 | All + Executive Floor |
| **Contractors** | Schedule-based | Specific zones |
| **Visitors** | Escorted only | Lobby, Meeting Rooms |

### 7.4 Anti-Passback

Anti-passback prevents credential sharing:

```
User enters Building A (badge in)
     ↓
System records: User IN Building A
     ↓
User attempts to enter again without exit
     ↓
ACCESS DENIED - Anti-passback violation
     ↓
Alert generated to Security
```

**Anti-passback Modes**:
- **Hard**: Access denied on violation
- **Soft**: Access allowed but logged
- **Timed**: Reset after configurable period

---

## 8. System Monitoring

### 8.1 Real-Time Metrics

The monitoring dashboard displays:

| Metric | Description | Target |
|--------|-------------|--------|
| **Processing Rate** | Alarms processed per second | > 100/s |
| **Latency** | Average alarm processing time | < 50ms |
| **Queue Depth** | Pending alarms in queue | < 100 |
| **Agent Efficiency** | 50-agent utilization | > 90% |
| **Container Health** | Docker container status | All green |
| **Database Connections** | Active pool connections | < 80% |

### 8.2 50-Agent Hierarchy Status

```
┌─────────────────────────────────────────────────────────────────┐
│ AGENT HIERARCHY STATUS                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                    ┌─────────────────┐                          │
│                    │   Executive     │                          │
│                    │    Agent (1)    │                          │
│                    │   Status: OK    │                          │
│                    └────────┬────────┘                          │
│                             │                                   │
│    ┌────────────────────────┼────────────────────────┐          │
│    ▼                        ▼                        ▼          │
│ ┌──────────┐          ┌──────────┐          ┌──────────┐        │
│ │ Domain   │          │ Domain   │          │ Domain   │        │
│ │ Agents   │          │ Agents   │          │ Agents   │        │
│ │  (10)    │          │  (10)    │          │  (10)    │        │
│ │ OK: 10   │          │ OK: 10   │          │ OK: 10   │        │
│ └────┬─────┘          └────┬─────┘          └────┬─────┘        │
│      │                     │                     │              │
│      ▼                     ▼                     ▼              │
│ ┌──────────┐          ┌──────────┐          ┌──────────┐        │
│ │Functional│          │Functional│          │ Worker   │        │
│ │ Agents   │          │ Agents   │          │ Agents   │        │
│ │  (15)    │          │  (15)    │          │  (24)    │        │
│ │ OK: 15   │          │ OK: 15   │          │ OK: 24   │        │
│ └──────────┘          └──────────┘          └──────────┘        │
│                                                                 │
│ Total: 50 agents │ Active: 50 │ Efficiency: 98.2%               │
└─────────────────────────────────────────────────────────────────┘
```

### 8.3 STAMP Compliance

View safety constraint compliance:

```
┌─────────────────────────────────────────────────────────────────┐
│ STAMP SAFETY CONSTRAINTS                        [195 Total]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ SC-VAL-001 to SC-VAL-008: Validation Process       ✅ 8/8      │
│ SC-CNT-009 to SC-CNT-016: Container Safety         ✅ 8/8      │
│ SC-AGT-017 to SC-AGT-024: Agent Coordination       ✅ 8/8      │
│ SC-CMP-025 to SC-CMP-032: Compilation Safety       ✅ 8/8      │
│ SC-DAT-033 to SC-DAT-040: Data Integrity           ✅ 8/8      │
│ SC-SEC-041 to SC-SEC-048: Security                 ✅ 8/8      │
│ ...                                                             │
│                                                                 │
│ OVERALL COMPLIANCE: 195/195 (100%)                              │
└─────────────────────────────────────────────────────────────────┘
```

### 8.4 OODA Loop Metrics

```
┌─────────────────────────────────────────────────────────────────┐
│ OODA LOOP PERFORMANCE                                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Loop Latency:                                                   │
│   Fast Loop:    ████████████░░░░░░░░  85ms (target: <100ms) ✅  │
│   Standard:     ██████████████░░░░░░  720ms (target: <1000ms)✅ │
│                                                                 │
│ Decision Quality:                                               │
│   Confidence:   ████████████████░░░░  0.92 (target: >0.70) ✅   │
│   Accuracy:     █████████████████░░░  0.96 (target: >0.90) ✅   │
│                                                                 │
│ Adaptation Rate:                                                │
│   Learning:     ██████████████████░░  0.95 (target: >0.90) ✅   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Configuration Management

### 9.1 Configuration API

The Configuration API provides 2,280+ endpoints for system configuration.

**Base URL**: `/api/mobile/config`

### 9.2 Site Configuration

```bash
# Get site configuration
GET /api/mobile/config/sites/{site_id}

Response:
{
  "site": {
    "id": "site-123",
    "name": "Headquarters",
    "address": "123 Main St",
    "timezone": "America/New_York",
    "coordinates": {
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    "settings": {
      "alarm_threshold": "high",
      "auto_arm_time": "22:00",
      "auto_disarm_time": "06:00"
    }
  }
}
```

### 9.3 Device Configuration

```bash
# Get device configuration
GET /api/mobile/config/devices/{device_id}

Response:
{
  "device": {
    "id": "dev-456",
    "type": "motion_sensor",
    "name": "Motion Sensor A-12",
    "zone_id": "zone-789",
    "settings": {
      "sensitivity": "medium",
      "pet_immunity": true,
      "dwell_time_seconds": 3
    },
    "firmware_version": "2.3.1",
    "last_heartbeat": "2025-12-19T10:45:00Z"
  }
}
```

### 9.4 Zone Configuration

```bash
# Get zone configuration
GET /api/mobile/config/zones/{zone_id}

Response:
{
  "zone": {
    "id": "zone-789",
    "name": "Warehouse A",
    "site_id": "site-123",
    "type": "interior",
    "arm_mode": "instant",
    "entry_delay_seconds": 0,
    "exit_delay_seconds": 30,
    "devices": ["dev-456", "dev-457", "dev-458"]
  }
}
```

### 9.5 User Preferences

```bash
# Get user preferences
GET /api/mobile/config/user/preferences

Response:
{
  "preferences": {
    "notification_settings": {
      "push_enabled": true,
      "email_enabled": true,
      "alarm_types": ["INTR", "FIRE", "PANC"],
      "quiet_hours": {
        "enabled": false,
        "start": "22:00",
        "end": "07:00"
      }
    },
    "display_settings": {
      "theme": "dark",
      "language": "en-US",
      "timezone": "America/New_York"
    },
    "dashboard_layout": {
      "widgets": ["alarms", "map", "activity"]
    }
  }
}
```

---

## 10. Troubleshooting

### 10.1 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| **Login failed** | Invalid credentials | Reset password via admin |
| **MFA not working** | Time sync issue | Sync device time, regenerate TOTP |
| **Slow dashboard** | Network latency | Check connection, clear cache |
| **Alarms delayed** | Queue backup | Check system status, scale workers |
| **Mobile app offline** | Network issues | Enable offline mode, sync later |
| **Door won't unlock** | Permission denied | Verify access group membership |

### 10.2 Error Codes

| Code | Description | Action |
|------|-------------|--------|
| **AUTH001** | Invalid credentials | Check username/password |
| **AUTH002** | Session expired | Re-authenticate |
| **AUTH003** | MFA required | Complete MFA challenge |
| **AUTH004** | Account locked | Contact administrator |
| **ACCESS001** | Permission denied | Request access from admin |
| **ACCESS002** | Anti-passback violation | Exit and re-enter properly |
| **DEVICE001** | Device offline | Check device connectivity |
| **DEVICE002** | Device tampered | Investigate physically |
| **SYSTEM001** | Service unavailable | Retry later or contact support |

### 10.3 Log Access

View system logs (admin only):

```
Admin > System > Logs

Log Categories:
- Authentication logs
- Access control logs
- Alarm event logs
- System health logs
- Audit logs
```

### 10.4 Support Contact

| Type | Contact |
|------|---------|
| **Technical Support** | support@indrajaal.example.com |
| **Emergency** | +1-800-555-0199 (24/7) |
| **Documentation** | docs.indrajaal.example.com |
| **Training** | training@indrajaal.example.com |

### 10.5 Health Check Endpoints

For API integration health checks:

```bash
# System health
GET /api/health
Response: {"status": "healthy", "timestamp": "2025-12-19T10:50:00Z"}

# Database health
GET /api/health/db
Response: {"status": "connected", "pool_size": 10, "checked_out": 3}

# Cache health
GET /api/health/cache
Response: {"status": "connected", "hit_rate": 0.95}
```

---

## Appendix A: Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+/` | Open command palette |
| `Ctrl+K` | Quick search |
| `Ctrl+Shift+A` | Go to alarms |
| `Ctrl+Shift+D` | Go to doors |
| `Ctrl+Shift+M` | Go to map |
| `Escape` | Close modal/panel |
| `Enter` | Confirm action |
| `A` | Acknowledge selected alarm |
| `E` | Escalate selected alarm |
| `R` | Refresh data |

---

## Appendix B: API Quick Reference

### Authentication

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mobile/auth/login` | POST | User login |
| `/api/mobile/auth/refresh` | POST | Refresh token |
| `/api/mobile/auth/logout` | POST | User logout |
| `/api/mobile/auth/mfa/verify` | POST | Verify MFA |

### Alarms

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mobile/alarms` | GET | List alarms |
| `/api/mobile/alarms/{id}` | GET | Get alarm details |
| `/api/mobile/alarms/{id}/acknowledge` | POST | Acknowledge alarm |
| `/api/mobile/alarms/{id}/resolve` | POST | Resolve alarm |
| `/api/mobile/alarms/{id}/escalate` | POST | Escalate alarm |

### Access Control

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mobile/doors` | GET | List doors |
| `/api/mobile/doors/{id}/unlock` | POST | Unlock door |
| `/api/mobile/doors/{id}/lock` | POST | Lock door |
| `/api/mobile/access-logs` | GET | Access history |

### Devices

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mobile/devices` | GET | List devices |
| `/api/mobile/devices/{id}` | GET | Get device details |
| `/api/mobile/devices/{id}/status` | GET | Get device status |

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-19
**Author**: Claude Code (Architecture Documentation)
**Framework Compliance**: SOPv5.11, STAMP, IEC 61508 SIL-2
