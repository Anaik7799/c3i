# Sutra for Police, Defence & Public Safety — Requirements Analysis

**Date**: 2026-04-19
**Context**: Matrix protocol is already used by German Bundeswehr, French government (Tchap), NATO, and UK MOD. Sutra needs specific hardening for mission-critical use.

---

## 1. MANDATORY Security Features

### 1.1 End-to-End Encryption Hardening
| Requirement | Current State | Gap | Priority |
|-------------|--------------|-----|----------|
| Perfect Forward Secrecy (Olm/Megolm) | Keys stored but not real crypto | Need real Ed25519/Curve25519 via NIF | P0 |
| Message-level encryption | Stub (content stored plaintext) | Need Megolm session encryption for room messages | P0 |
| Cross-signing verification | UIA + key storage works | Need real signature validation | P0 |
| Key rotation (per-session) | Not implemented | Rotate Megolm session every N messages or T hours | P1 |
| Secure key backup | Stored in KV | Need encrypted backup with recovery passphrase | P1 |
| Device verification (SAS/QR) | Stub | Need Short Authentication String or QR code verification | P1 |
| Zero-knowledge proof of identity | Not implemented | For undercover officers — verify without revealing identity | P2 |

### 1.2 Authentication & Access Control
| Requirement | Current State | Gap | Priority |
|-------------|--------------|-----|----------|
| Multi-factor authentication (MFA) | Password only | Add TOTP, FIDO2/WebAuthn, PIV/CAC smartcard | P0 |
| SSO/OIDC integration | Returns 404 (disabled) | Need OIDC provider integration (Keycloak, Azure AD) | P0 |
| Role-Based Access Control (RBAC) | Power levels only | Need roles: Officer, Dispatcher, Commander, Admin, Auditor | P0 |
| Security clearance levels | Not implemented | UNCLASSIFIED / RESTRICTED / CONFIDENTIAL / SECRET / TOP SECRET | P0 |
| Mandatory Access Control (MAC) | Not implemented | Bell-LaPadula: no read up, no write down | P1 |
| Session timeout & re-auth | Tokens never expire | Auto-logout after inactivity, re-auth for sensitive ops | P0 |
| IP-based access restriction | Not implemented | Limit access to VPN/MPLS networks only | P1 |
| Certificate-based auth (mTLS) | Not implemented | Client certificates for device authentication | P1 |

### 1.3 Audit & Compliance
| Requirement | Current State | Gap | Priority |
|-------------|--------------|-----|----------|
| Immutable audit log | Not implemented | Every action logged: who, what, when, from where | P0 |
| Chain of custody for messages | Not implemented | Cryptographic proof of message integrity (hash chain) | P0 |
| Legal hold / eDiscovery | Not implemented | Preserve messages for legal proceedings, prevent deletion | P0 |
| GDPR data subject access requests | Not implemented | Export all data for a user on request | P1 |
| Data retention policies | Not implemented | Auto-delete after N days/months per policy | P1 |
| Access log for who-read-what | Not implemented | Track every message read event for accountability | P0 |
| Tamper-evident storage | KV in-memory | Need append-only log with Merkle tree verification | P1 |

### 1.4 Data Classification
| Requirement | Current State | Gap | Priority |
|-------------|--------------|-----|----------|
| Room classification labels | Not implemented | Tag rooms with security classification level | P0 |
| Cross-domain guard | Not implemented | Prevent classified content flowing to unclassified rooms | P0 |
| Content inspection | Not implemented | DLP (Data Loss Prevention) — block PII/classified data leaks | P1 |
| Watermarking | Not implemented | Invisible watermarks in shared files for leak tracing | P2 |
| Geofencing | Not implemented | Restrict access based on device GPS location | P2 |

---

## 2. Operational Features for Public Safety

### 2.1 Priority Messaging
| Feature | Description | Priority |
|---------|-------------|----------|
| Emergency alerts (Code Red) | Push-to-all with override — bypass DND, max priority | P0 |
| Priority levels | P1-P5 message priority with queue preemption | P0 |
| Delivery confirmation | Per-message delivery + read receipt with timestamps | P0 |
| Recall/retract | Commander can recall sent messages from all devices | P1 |
| Scheduled messages | Pre-compose messages for timed release (shift briefings) | P2 |
| Broadcast channels | One-to-many read-only channels (dispatch → all units) | P0 |

### 2.2 Voice & Video (Mission Critical Push-to-Talk)
| Feature | Description | Priority |
|---------|-------------|----------|
| MCPTT (3GPP TS 24.379) | Mission Critical Push-to-Talk over LTE/5G | P0 |
| Group voice calls | Encrypted group audio (WebRTC or Jingle) | P0 |
| Floor control | Who's talking indicator, priority override for commanders | P0 |
| Recording | Auto-record all calls for evidence/training | P0 |
| Ambient listening | Authorized remote activation for officer safety | P2 |
| Video streaming | Body camera live stream to command center | P1 |

### 2.3 Location & Situational Awareness
| Feature | Description | Priority |
|---------|-------------|----------|
| Real-time location sharing | GPS position of all units on shared map | P0 |
| Geofenced alerts | Alert when unit enters/leaves defined area | P0 |
| Location history | Track unit movements for post-incident review | P1 |
| Map annotations | Share tactical markers, perimeters, routes | P0 |
| Proximity alerts | Warn when friendly units are near each other or threats | P1 |
| Indoor positioning | BLE/UWB for building interior tracking | P2 |

### 2.4 Incident Management
| Feature | Description | Priority |
|---------|-------------|----------|
| Incident rooms (auto-create) | Auto-create encrypted room per incident with assigned units | P0 |
| CAD integration | Receive Computer-Aided Dispatch events as Matrix messages | P0 |
| Status updates | Unit status: Available/En Route/On Scene/Busy/Emergency | P0 |
| Evidence attachment | Photos/video/audio attached to incident room with metadata | P0 |
| Chain of evidence | Cryptographic hash of all evidence files, timestamps, GPS | P0 |
| Incident timeline | Automatic timeline reconstruction from all messages/events | P1 |
| Resource tracking | Equipment, vehicle, personnel assignment per incident | P1 |

### 2.5 Interoperability
| Feature | Description | Priority |
|---------|-------------|----------|
| P25/TETRA bridge | Bridge to existing radio systems (Motorola, Airbus) | P0 |
| CAD/RMS integration | REST/SOAP bridge to Records Management Systems | P0 |
| NLETS/NCIC bridge | Law enforcement database queries via Matrix | P1 |
| CJIS compliance | FBI CJIS Security Policy compliance (encryption, audit, access) | P0 |
| FirstNet integration | Dedicated public safety LTE band 14 support | P1 |
| NATO STANAG compliance | Interoperability with allied forces systems | P1 |
| Blue Force Tracking | Integration with military BFT systems | P1 |

---

## 3. Reliability & Availability

### 3.1 High Availability
| Requirement | Current State | Gap | Priority |
|-------------|--------------|-----|----------|
| Active-active clustering | Single instance | Need multi-node with state replication | P0 |
| Automatic failover | No HA | Need < 30s failover to standby | P0 |
| Data replication | KV in-memory only | Need SQLite WAL + Zenoh CRDT replication | P0 |
| Zero-downtime upgrades | Must restart | Need BEAM hot code reload | P1 |
| Geographic redundancy | Single location | Need multi-site deployment | P1 |
| Disaster recovery | No backup | Need automated backup + restore | P0 |

### 3.2 Offline/Degraded Operation
| Requirement | Current State | Gap | Priority |
|-------------|--------------|-----|----------|
| Offline message queue | Not implemented | Queue messages when disconnected, sync on reconnect | P0 |
| Store-and-forward | Not implemented | Relay messages through intermediate nodes | P0 |
| Mesh networking | Not implemented | Device-to-device communication without server (Zenoh P2P) | P1 |
| Bandwidth-efficient sync | Full sync every time | Need delta sync, compressed payloads | P1 |
| Satellite backhaul | Not implemented | Support for high-latency, low-bandwidth links | P2 |
| Radio silence mode | Not implemented | Encrypt and queue — no RF emissions until authorized | P2 |

### 3.3 Performance
| Requirement | Current State | Gap | Priority |
|-------------|--------------|-----|----------|
| Message delivery < 500ms | Depends on sync interval | Need WebSocket push, not polling | P0 |
| Support 10K concurrent users | Single OTP actor | Need actor sharding, connection pooling | P0 |
| Support 100K messages/day | KV list scan | Need indexed storage (SQLite + FTS5) | P1 |
| Message throughput > 1000/sec | Not benchmarked | Need load testing, optimization | P1 |

---

## 4. Defence-Specific Features

### 4.1 Classification & Handling
| Feature | Description | Priority |
|---------|-------------|----------|
| NATO classification markings | UNCLASSIFIED / RESTRICTED / CONFIDENTIAL / SECRET / COSMIC TOP SECRET | P0 |
| Handling caveats | NOFORN, REL TO, FVEY, EYES ONLY | P0 |
| Cross-domain solutions | CDS for controlled information flow between classifications | P0 |
| Crypto period management | Key material lifecycle with scheduled rotation | P1 |
| TEMPEST compliance | EMI shielding for classified operations | P2 |

### 4.2 Command & Control (C2)
| Feature | Description | Priority |
|---------|-------------|----------|
| Hierarchical channels | Brigade → Battalion → Company → Platoon → Squad | P0 |
| Operations orders (OPORD) | Structured message format for orders (5-paragraph) | P1 |
| Mission planning integration | Link to mission planning tools (JMPS, PFPS) | P1 |
| Battle rhythm automation | Scheduled briefings, reports, handovers | P1 |
| Coalition operations | Multi-nation rooms with classification controls | P0 |

### 4.3 Intelligence
| Feature | Description | Priority |
|---------|-------------|----------|
| SIGINT/HUMINT channels | Compartmented rooms with need-to-know access | P0 |
| Source protection | Anonymous messaging, cover identities | P0 |
| Intelligence reporting | SALUTE, INTREP, INTSUM structured formats | P1 |
| Imagery dissemination | Satellite/drone imagery with NITF metadata | P1 |
| Fusion rooms | Multi-INT analysis rooms with AI summarization | P2 |

---

## 5. Implementation Roadmap

### Sprint A: Security Foundation (2 weeks)
1. Real E2EE with Erlang `:crypto` NIF (Ed25519, Curve25519, AES-256-GCM)
2. Immutable audit log (append-only event store with hash chain)
3. Token expiration + session timeout
4. RBAC with roles (admin, commander, officer, dispatcher, auditor)
5. Room classification labels (custom state event `m.room.classification`)
6. SQLite persistence (wire sqlite_ops.gleam to actual DB)

### Sprint B: Operational Features (2 weeks)
1. Priority message system (custom event type with priority field)
2. Emergency broadcast (push-to-all room with @room notification)
3. Location sharing (custom event type with GPS coordinates)
4. Incident room auto-creation (API endpoint + Zenoh trigger)
5. Status tracking (custom presence extension)
6. Delivery confirmation (read receipts with timestamps)

### Sprint C: HA & Reliability (2 weeks)
1. SQLite WAL for durable storage
2. Zenoh-based state replication (CRDT sync between nodes)
3. WebSocket push (Mist WebSocket handler for real-time delivery)
4. Connection pooling + actor sharding
5. Offline message queue
6. Automated backup/restore

### Sprint D: Integration & Compliance (2 weeks)
1. OIDC/SSO integration (Keycloak connector)
2. MFA (TOTP + WebAuthn)
3. CJIS compliance audit trail
4. CAD system bridge (REST webhook)
5. Data retention policies
6. Legal hold mechanism

### Sprint E: Voice & Advanced (4 weeks)
1. WebRTC voice calls via Matrix VoIP
2. Group call support (Ogg Opus)
3. PTT (Push-to-Talk) with floor control
4. Body camera stream integration
5. Real-time map with unit positions
6. AI-powered incident summarization

---

## 6. Compliance Standards

| Standard | Scope | Applicability |
|----------|-------|---------------|
| **CJIS Security Policy** | US law enforcement | Encryption at rest + transit, audit, access control, MFA |
| **FedRAMP** | US federal government | Cloud security baseline (Low/Moderate/High) |
| **NATO STANAG 4774/4778** | Military interop | Metadata binding, confidentiality labels |
| **IEC 61508 SIL-4** | Safety-critical | Already in C3I framework |
| **Common Criteria EAL4+** | Defence procurement | Formal security evaluation |
| **GDPR** | EU data protection | Data subject rights, lawful processing |
| **UK Official-Sensitive** | UK government | Handling of sensitive government data |
| **NIS2 Directive** | EU critical infrastructure | Cybersecurity obligations for essential services |
| **FIPS 140-3** | US crypto modules | Validated cryptographic implementations |
| **SOC 2 Type II** | Service organizations | Security, availability, processing integrity |

---

## 7. Existing Matrix Deployments in Defence/Government

| Organization | System | Scale |
|-------------|--------|-------|
| **German Bundeswehr** | BwMessenger (Element) | 250,000+ soldiers |
| **French Government** | Tchap (custom Element) | 500,000+ civil servants |
| **NATO ACT** | Element deployment | Allied Command Transformation |
| **UK MOD** | Defence Digital | Secure messaging trial |
| **Swedish Armed Forces** | Matrix evaluation | Tactical messaging |
| **US Navy** | Matrix evaluation | Shipboard comms |
| **Ukrainian MOD** | Delta (includes Matrix) | Battlefield C2 |

---

## 8. Sutra Advantages for Public Safety

### Why Gleam/BEAM is ideal:
1. **Fault tolerance** — OTP supervisors auto-restart failed processes
2. **Hot code upgrade** — Update without downtime (already in C3I framework)
3. **Massive concurrency** — BEAM handles millions of lightweight processes
4. **Low latency** — Soft real-time guarantees
5. **Distribution** — Built-in Erlang distribution for clustering

### Why Sutra specifically:
1. **Sovereign** — No dependency on Element's infrastructure
2. **Auditable** — Full source code, formal verification (TLA+/Agda)
3. **Customizable** — Add domain-specific event types, workflows
4. **Integrated** — Zenoh mesh for IoT/sensor integration
5. **Compact** — 22K LOC vs Synapse's 200K+ Python
6. **Type-safe** — Gleam's exhaustive pattern matching prevents bugs
