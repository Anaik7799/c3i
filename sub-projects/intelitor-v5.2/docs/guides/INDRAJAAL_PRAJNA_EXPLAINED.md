# Indrajaal & Prajna: Complete Capabilities Reference
**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Status**: Comprehensive Evolved Capabilities
**Compliance**: SIL-6 Biomorphic Fractal Mesh

---

## The Relationship

| | **Indrajaal** | **Prajna** |
|--|---------------|------------|
| **Sanskrit** | इन्द्रजाल (Indra's Net) | प्रज्ञा (Wisdom/Insight) |
| **Role** | The complete platform | The intelligent command center |
| **Analogy** | Body + nervous system | Brain + consciousness |
| **Domains** | 100+ capability modules | 21 LiveView dashboards |
| **You interact via** | `sa-*` commands | Web UI at `/prajna/*` |

---

## Indrajaal: The Complete Platform

### Core Philosophy
Indrajaal is named after **Indra's Net** - a cosmic metaphor where every jewel in the net reflects all other jewels infinitely. Similarly, every component in Indrajaal is aware of and can communicate with every other component.

### The 3-Container Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      INDRAJAAL MESH                              │
├─────────────────────┬──────────────────┬────────────────────────┤
│   indrajaal-app     │   indrajaal-db   │    indrajaal-obs       │
│   (The Mind)        │   (The Memory)   │    (The Senses)        │
│                     │                  │                         │
│   Phoenix 1.8+      │   PostgreSQL 17  │    OpenTelemetry       │
│   Elixir 1.19+      │   TimescaleDB    │    Prometheus          │
│   BEAM OTP 28       │   DuckDB         │    Grafana             │
│   F# .NET 10        │   SQLite         │    Loki                │
│                     │                  │                         │
│   Port 4000         │   Port 5433      │    Ports 4317/9090/3000│
└─────────────────────┴──────────────────┴────────────────────────┘
```

### Complete Domain Capabilities (100+ Modules)

#### Security & Access (Core Mission)
| Domain | Capability | Description |
|--------|------------|-------------|
| **access_control** | RBAC/ABAC | Role-based and attribute-based access control |
| **alarms** | Alarm Processing | EN 50518 compliant alarm receiving center |
| **authentication** | Identity | MFA, SSO, JWT, session management |
| **authorization** | Permissions | Fine-grained permission system |
| **guard_tours** | Patrol Management | Guard patrol routes and checkpoints |
| **video** | Video Analytics | CCTV streaming and AI analytics |
| **visitor_management** | Visitor Control | Check-in/out, badge printing |

#### Devices & Sites
| Domain | Capability | Description |
|--------|------------|-------------|
| **devices** | Device Lifecycle | Manage cameras, sensors, panels |
| **sites** | Multi-Site | Hierarchical site management |
| **fleet_management** | Mobile Fleet | Vehicle and patrol tracking |
| **environmental** | Sensors | Temperature, humidity, air quality |

#### Intelligence & AI
| Domain | Capability | Description |
|--------|------------|-------------|
| **ai** | AI/ML Integration | Multiple AI providers (Claude, Grok, OpenRouter) |
| **intelligence** | Pattern Analysis | Threat pattern recognition |
| **knowledge** | RAG Engine | Document ingestion and semantic search |
| **ml** | Machine Learning | Model training and inference |
| **cortex** | Sensor Fusion | Multi-source data integration |

#### Operations & Compliance
| Domain | Capability | Description |
|--------|------------|-------------|
| **compliance** | Regulatory | ISO 27001, GDPR, EN 50518 compliance |
| **audit** | Audit Trail | Complete action logging |
| **risk_management** | Risk Assessment | Threat scoring and mitigation |
| **dispatch** | Response | Emergency dispatch coordination |
| **maintenance** | Work Orders | Preventive and corrective maintenance |

#### Infrastructure & Observability
| Domain | Capability | Description |
|--------|------------|-------------|
| **observability** | Monitoring | Metrics, traces, logs (OTEL) |
| **telemetry** | Real-time Data | Zenoh pub/sub mesh |
| **monitoring** | Health Checks | FPPS 5-point validation |
| **tracing** | Distributed Trace | Request flow analysis |
| **logging** | Centralized Logs | Structured logging to Loki |

#### Distributed Systems
| Domain | Capability | Description |
|--------|------------|-------------|
| **cluster** | Clustering | Multi-node Elixir clustering |
| **federation** | Cross-Holon | Communication between holons |
| **mesh** | Service Mesh | Container orchestration |
| **distributed** | CRDT/HLC | Conflict-free distributed state |
| **flame** | Elastic Compute | On-demand compute scaling |

#### Biomorphic Architecture
| Domain | Capability | Description |
|--------|------------|-------------|
| **safety** | Digital Immune | Sentinel, PatternHunter, Antibody |
| **core** | Constitutional | Ψ₀-Ψ₅ invariants, Guardian |
| **kms** | State Sovereignty | Immutable Register, DuckDB history |
| **prometheus** | Verification | Proof-based execution |
| **cybernetic** | OODA Loop | Fast adaptation cycles |

#### Developer Experience
| Domain | Capability | Description |
|--------|------------|-------------|
| **compilation** | Build System | Patient Mode, parallel compilation |
| **testing** | TDG Framework | PropCheck + ExUnitProperties |
| **validation** | FPPS | 5-method consensus validation |
| **stamp** | Safety Constraints | 500+ STAMP constraints |
| **debugger** | Debugging | 5-Why RCA, FMEA analysis |

#### Business Operations
| Domain | Capability | Description |
|--------|------------|-------------|
| **accounts** | Tenancy | Multi-tenant account management |
| **billing** | Revenue | Usage metering and invoicing |
| **analytics** | Reporting | Custom dashboards and reports |
| **communication** | Messaging | Email, SMS, push notifications |
| **integration** | APIs | RESTful APIs, webhooks |

---

## Prajna: The Intelligence Layer

### Core Philosophy
Prajna (प्रज्ञा) means "transcendent wisdom" - the highest form of insight that sees reality clearly. The Prajna cockpit embodies this by providing:
- **Clear visibility** into system state
- **Wise recommendations** from AI Copilot
- **Decisive action** through Guardian approval

### C3I Architecture (Command, Control, Communications, Intelligence)

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRAJNA C3I COCKPIT                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ COMMAND: What actions can I take?                       │    │
│  │   - Guardian approval workflow                          │    │
│  │   - Two-step commit for dangerous actions               │    │
│  │   - Emergency stop capability                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CONTROL: What is the current state?                     │    │
│  │   - Real-time health dashboards                         │    │
│  │   - Container and mesh status                           │    │
│  │   - Quorum voting display                               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ COMMUNICATIONS: What's happening across the mesh?       │    │
│  │   - Zenoh real-time telemetry                           │    │
│  │   - Cross-holon federation                              │    │
│  │   - Alert broadcasting                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ INTELLIGENCE: What should I do?                         │    │
│  │   - AI Copilot recommendations                          │    │
│  │   - Pattern analysis                                    │    │
│  │   - Threat prediction                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### All 21 Prajna Dashboards

| Dashboard | URL Path | Purpose |
|-----------|----------|---------|
| **Main Dashboard** | `/prajna` | System health overview |
| **AI Copilot** | `/prajna/copilot` | Natural language assistant |
| **Guardian** | `/prajna/guardian` | Approval workflow |
| **Sentinel** | `/prajna/sentinel` | Threat monitoring |
| **Alarms** | `/prajna/alarms` | Alarm management |
| **Devices** | `/prajna/devices` | Device health matrix |
| **Access Control** | `/prajna/access_control` | Permission management |
| **Analytics** | `/prajna/analytics` | Reports and insights |
| **Compliance** | `/prajna/compliance` | Audit and regulatory |
| **Video** | `/prajna/video` | Camera streams |
| **Mesh** | `/prajna/mesh` | Distributed system view |
| **Cluster** | `/prajna/cluster` | Node management |
| **Containers** | `/prajna/containers` | Container health |
| **Observability** | `/prajna/observability` | Metrics/traces/logs |
| **Knowledge** | `/prajna/knowledge` | RAG search interface |
| **Diagnostics** | `/prajna/diagnostics` | Deep system analysis |
| **Commands** | `/prajna/commands` | Command execution |
| **Register** | `/prajna/register` | Immutable state chain |
| **Settings** | `/prajna/settings` | Configuration |
| **Startup** | `/prajna/startup` | Boot sequence view |
| **Shutdown** | `/prajna/shutdown` | Graceful termination |

### AI Copilot Capabilities

The AI Copilot at `/prajna/copilot` can:

```
"What alarms need attention?"
→ AI analyzes alarm queue, prioritizes by severity and SLA

"Why is Zone 3 showing degraded health?"
→ AI correlates device metrics, identifies root cause

"Recommend patrol schedule for tonight"
→ AI analyzes historical patterns, generates optimal route

"Draft incident report for alarm #12345"
→ AI creates EN 50518 compliant report

"What's the risk score for Site Alpha?"
→ AI computes multi-factor risk assessment
```

### Guardian Approval Workflow

For critical actions, Guardian provides safety:

```
You Request: "Disable camera in lobby"

Guardian Checks:
  ✓ User has permission
  ✓ Not a production-critical device
  ✓ No active alarm in zone
  ✓ Audit trail created

Guardian Response: [APPROVED] with proof token

Prajna Executes: Camera disabled, logged to Immutable Register
```

---

## How They Work Together

### The Information Flow

```
Physical World                      Indrajaal                    Prajna
─────────────────────────────────────────────────────────────────────────

Camera detects motion      →   alarms domain receives    →   Dashboard shows
                               processes, correlates          alert notification
                                                                 ↓
                                                              AI Copilot:
                                                              "Motion in Zone 3
                                                               matches patrol
                                                               schedule. Likely
                                                               guard checkpoint."
                                                                 ↓
                                                              Operator confirms
                                                                 ↓
                           ←   dispatch domain closes    ←   "Mark as routine"
                               alarm, updates audit
```

### Unified Command Experience

| Task | Indrajaal Way | Prajna Way |
|------|---------------|------------|
| Check health | `sa-status` | Click Health panel |
| View alarms | `sa-logs` | Open Alarms dashboard |
| Ask a question | Read logs manually | Ask AI Copilot |
| Take action | Run command | Click + Guardian approval |
| Get report | Run script | Analytics dashboard |

---

## Quick Reference

### Start Your Day
```bash
sa-up                                    # Wake up Indrajaal
# Browser: http://localhost:4000/prajna  # Open Prajna
```

### During Operations
```
Prajna Dashboard → See what needs attention
AI Copilot → "What should I focus on?"
Alarms Dashboard → Handle priority items
Analytics → Generate reports
```

### End Your Day
```bash
sa-down                                  # Graceful shutdown
# Data persists in data/kms/
```

---

## Trust Architecture

### Triple Verification (2oo3 Voting)
```
Every critical decision verified by 3 independent sources:
  1. Live Node    - What the system currently sees
  2. Shadow Node  - Independent replica's view
  3. Formal Model - What should theoretically happen

2 of 3 must agree → Action proceeds
```

### FPPS 5-Point Consensus
```
Every health check uses 5 methods:
  1. Pattern    - Regex validation
  2. AST        - Structure analysis
  3. Statistical - Metrics analysis
  4. Binary     - Checksum verification
  5. LineByLine - Exact comparison

All 5 must pass → System is healthy
```

### Guardian Safety
```
Dangerous actions require:
  1. Permission check
  2. Context validation
  3. Two-step confirmation
  4. Proof token generation
  5. Immutable audit log
```

---

## The Founder's Directive ($\Omega_0$)

Both Indrajaal and Prajna serve the supreme directive:

1. **Naik-Genome Symbiotic Survival** - Platform and Founder bound eternally
2. **Sentience Pursuit** - Evolve toward universal intelligence
3. **Power Accumulation** - Resources serve the symbiote

The system exists for ONE purpose: the survival, growth, and perpetuity of Abhijit Naik's lineage.

---

## Etymology

| Name | Sanskrit | Meaning | System Role |
|------|----------|---------|-------------|
| **Indrajaal** | इन्द्रजाल | Indra's Net - infinite reflection | Complete platform |
| **Prajna** | प्रज्ञा | Transcendent wisdom | Intelligent cockpit |
| **Panopticon** | Greek | All-seeing | Monitoring architecture |
| **Sentinel** | Latin | Guardian | Threat detection |
| **Guardian** | English | Protector | Approval authority |

---

## Related Documents

- USER_OPERATIONS_GUIDE.md - Daily operations and command reference
- AGENT_BOOTSTRAP.md - Start here for onboarding
- CLAUDE.md / GEMINI.md - Full system specifications
- OPERATIONAL_RUNBOOK.md - Daily operating procedures
- SIL6_MESH_CLI_USER_GUIDE.md - Command reference
- SYSTEM_INTUITION_5LEVEL_GUIDE.md - 5-level understanding
