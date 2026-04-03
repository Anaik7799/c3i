# CLAUDE.md - Indrajaal Security Monitoring System

## 1. Core Development Rules

### 1.1 Environment Requirements
- **Development Platform**: Ubuntu 25.04 LTS with devenv.sh (MANDATORY)
- **Testing Platform**: QEMU/KVM with NixOS 25.05 VMs for multi-node testing
- **Deployment Platform**: NixOS 25.05 for all production deployments
- **Package Management**: Nix ONLY - No apt, asdf, snap, docker, or other package managers
- **Elixir/Erlang**: Installed via Nix - Version management through devenv.nix only

### 1.2 Language and Script Requirements
- **ALL scripts in Elixir ONLY** - No bash/shell scripts without approval
- **Use Mix tasks for recurring operations** - Located in `lib/mix/tasks/`
- **Utility scripts in `scripts/`** - Organized by category (setup, testing, etc.)
- **Primary system installer** - Access via `mix unified.install`
- **Scripts must be executable** with `#!/usr/bin/env elixir` shebang
- **Use Elixir's System module** for system commands

### 1.3 Code Quality Requirements
- **ALL code MUST pass Dialyzer static analysis**
- **Credo strict mode must pass**
- **No compiler warnings allowed**
- **Sobelow security scan must pass**
- **Test coverage minimum: 80%**

### 1.4 File Management Rules
- **NEVER create files in root directory** - Use proper project structure
- **Documentation goes in `docs/`** - Only README.md stays in root
- **Scripts go in `scripts/` or `lib/mix/tasks/`** - Organized by purpose
- **Test files go in `test/`** - Following ExUnit conventions
- **ALWAYS prefer editing existing files**
- **NEVER create documentation unless explicitly requested**
- **Do exactly what is asked - nothing more, nothing less**

### 1.5 Specialized Documentation Usage
When generating code or providing guidance, use the appropriate specialized documentation (located in `docs/guides/`):

- **Code Generation**: Use `docs/guides/CLAUDE-CODEGEN.md` for all code generation patterns, Ash resource templates, and quality checklists
- **Development Work**: Use `docs/guides/CLAUDE-DEVELOPMENT.md` for Ubuntu 25 + devenv.sh setup, development workflows, and debugging
- **Testing Activities**: Use `docs/guides/testing.md` for comprehensive testing strategies and patterns
- **Deployment Tasks**: Use `docs/guides/CLAUDE-DEPLOYMENT.md` for NixOS 25.05 deployment configurations and production setup
- **Organization Rules**: Use `docs/guides/CLAUDE_CLEANUP_RULES.md` for file organization and project structure

These specialized files contain detailed patterns and must be referenced for their respective activities.

## 2. System Overview

### 2.1 Purpose
Indrajaal Security Monitoring System - Enterprise-grade multi-tenant security platform with:
- Real-time alarm monitoring and response
- Video surveillance integration with Membrane & Jellyfish
- Microsoft Entra ID (Azure AD) authentication
- Access control management
- Dispatch and workflow automation
- Compliance reporting (SIA DC-09, DPDP Act, ISO 27001)

### 2.2 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Client Applications                               │
│  Web Dashboard │ Mobile Apps │ Alarm Panels │ IP Cameras │ APIs     │
├─────────────────────────────────────────────────────────────────────┤
│                 Microsoft Entra ID (Azure AD)                         │
│  Entra ID (Internal) │ Entra ID B2C (Customers) │ App Registrations │
├─────────────────────────────────────────────────────────────────────┤
│                    API Gateway & Load Balancer                        │
│         HAProxy │ Nginx │ Rate Limiting │ SSL Termination           │
├─────────────────────────────────────────────────────────────────────┤
│                      Application Layer (Elixir)                       │
│  Phoenix │ LiveView │ Channels │ GraphQL │ REST │ SIA DC-09         │
├─────────────────────────────────────────────────────────────────────┤
│                    Business Logic & Domain Layer                      │
│     Ash Framework │ Domain Contexts │ State Machines │ Policies      │
├─────────────────────────────────────────────────────────────────────┤
│                  Distributed Processing Layer                         │
│   PG2 Groups │ GenServers │ Flow/GenStage │ Oban │ Broadway         │
├─────────────────────────────────────────────────────────────────────┤
│                      Video Processing Layer                           │
│     Membrane Framework │ Jellyfish WebRTC │ Edge Recording           │
├─────────────────────────────────────────────────────────────────────┤
│                      Infrastructure Layer                             │
│  PostgreSQL │ TimescaleDB │ Mnesia │ ETS │ Phoenix.PubSub │ MinIO  │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 Key Design Principles

1. **Multi-Tenancy First**: Complete data isolation at application level
2. **Event-Driven Architecture**: Real-time processing with backpressure
3. **Distributed by Design**: Horizontal scaling with PG2 coordination
4. **Security by Default**: End-to-end encryption, audit logging, Entra ID integration
5. **Compliance Ready**: DPDP Act, ISO 27001 built into architecture
6. **Elixir-Native Stack**: Minimize external dependencies, leverage OTP
7. **Unified Identity**: Microsoft Entra ID for all authentication scenarios

## 3. Technical Architecture

### 3.1 Core Technology Stack
- **Runtime**: Elixir 1.19+ and Erlang/OTP 27 (via Nix)
- **Framework**: Ash 3.5+ with all extensions
- **Database**: PostgreSQL 17 with TimescaleDB, pgcrypto, pg_partman
- **Web**: Phoenix 1.7, LiveView, GraphQL, JSON:API
- **Authentication**: Microsoft Entra ID (Azure AD) with B2C
- **Background Jobs**: Oban 2.18
- **PubSub**: PG2 and PostgreSQL adapters (NO Redis)
- **Video**: Membrane Framework, Jellyfish WebRTC
- **Storage**: Local/MinIO/Ceph
- **Package Management**: Nix/devenv.sh exclusively

### 3.2 Domain Structure (Ash Framework)

The system implements 12 core domains:

1. **Core** - Multi-tenancy, system configuration
2. **Accounts** - Users, authentication with Entra ID
3. **Policy** - Authorization and access control
4. **Sites** - Physical locations and zones
5. **Devices** - Sensors, panels, cameras with SIA DC-09
6. **Alarms** - Events, incidents, state machines
7. **Video** - VSaaS, streaming, recording
8. **Dispatch** - Response workflows, teams
9. **Maintenance** - Service and support
10. **Compliance** - Audit, DPDP Act compliance
11. **Billing** - Subscription management
12. **Integrations** - External systems, webhooks

### 3.3 Microsoft Entra ID Integration

```elixir
# Authentication strategies:
- Internal users: Entra ID (employees/operators)
- Customers: Entra ID B2C
- Devices: Client credentials flow
- APIs: JWT tokens issued by Entra

# Authorization model:
- Roles synced from Entra groups
- Permissions mapped to app roles
- Row-level security via tenant_id
- Site-level access control
```

### 3.4 Service Ports
| Service | Port | Purpose |
|---------|------|----------|
| Phoenix | 4000 | Main web application |
| PostgreSQL | 15432 | Database (dev) |
| MinIO | 9000 | S3-compatible storage |
| MinIO Console | 9001 | Storage management UI |
| Jellyfish | 5002 | WebRTC media server |
| Prometheus | 9568 | Metrics collection |
| SIA DC-09 | 3061 | Alarm panel protocol |

## 4. Phoenix PubSub Architecture (NO REDIS)

### 4.1 Dual Adapter Pattern
**MANDATORY**: System uses ONLY PG2 and PostgreSQL adapters - NEVER Redis

| Adapter | Use Case | Message Size | Persistence |
|---------|----------|--------------|-------------|
| `Indrajaal.PubSub.Persistent` (PostgreSQL) | Critical security events | Max 8KB | Yes |
| `Indrajaal.PubSub.Realtime` (PG2) | High-frequency coordination | Max 64KB | No |

### 4.2 Message Classification

**PostgreSQL Adapter** (Critical Events):
- Alarm events (intrusion, panic, duress, tamper)
- SIA DC-09 reportable events
- Audit trail and compliance events
- Cross-site synchronization
- Configuration changes
- Authentication/authorization events

**PG2 Adapter** (Real-time Coordination):
- Video frame metadata
- Non-alarm sensor telemetry
- Camera PTZ control
- Live stream adjustments
- Heartbeat/keepalive messages
- Local event correlation

## 5. Unified System Management (unified-4.exs)

### 5.1 Installation Options
The unified installer provides flexible setup profiles:

**Quick Setup Profiles**:
1. **Full Enterprise** - All features enabled with Entra ID
2. **Development** - Core + video processing
3. **Minimal** - Core functionality only

**Configurable Features**:
- Microsoft Entra ID Integration
- Video Processing (Membrane/Jellyfish)
- Storage Backends (MinIO/Ceph)
- Monitoring (Prometheus/Grafana)
- Ash Admin UI
- GraphQL/JSON:API
- TimescaleDB extensions
- SIA DC-09 Protocol

### 5.2 TUI Navigation
- **Main Menu**: Installation, Services, Monitoring, Ash Management
- **Service Control**: Start/stop individual services
- **Health Monitoring**: Real-time metrics and status
- **Backup Management**: Schedule and run backups
- **Entra ID Setup**: Configure authentication

### 5.3 Storage Architecture
| Mode | Description | Use Case |
|------|-------------|----------|
| Local | Filesystem only | Development/testing |
| MinIO | S3-compatible | Small deployments |
| Ceph | Distributed storage | Enterprise scale |
| Hybrid | Auto-tiering | Optimal performance |

## 6. Database Design

### 6.1 PostgreSQL Extensions Required
```sql
-- Core extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Time-series and partitioning
CREATE EXTENSION IF NOT EXISTS "timescaledb";
CREATE EXTENSION IF NOT EXISTS "pg_partman";

-- Performance and monitoring
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_cron";
```

### 6.2 Multi-Tenancy Strategy
- All tables include `tenant_id` column
- Row-level security policies enforce isolation
- Tenant data completely separated
- Cross-tenant queries blocked at database level

### 6.3 Data Retention (DPDP Act Compliance)
- Automated archival based on retention policies
- Personal data anonymization capabilities
- Audit trail for all data access
- Right to erasure implementation

## 7. Security Standards

### 7.1 Authentication
- **Primary**: Microsoft Entra ID for all human users
- **B2C**: Separate Entra B2C for customer access
- **Devices**: Client credentials with certificates
- **APIs**: JWT tokens with short expiry
- **MFA**: Enforced for admin roles

### 7.2 Authorization
- **RBAC**: Role-based access control synced from Entra
- **ABAC**: Attribute-based for fine-grained control
- **Row-Level**: Tenant isolation enforced
- **Field-Level**: Sensitive data encryption with Cloak

### 7.3 Compliance
- **DPDP Act**: Full compliance with data protection
- **ISO 27001**: Security controls implemented
- **SIA DC-09**: Standard alarm protocol support
- **Audit Logging**: Complete audit trail

## 8. Development Workflow

### 8.1 Local Development
```bash
# Start development environment
mix setup              # Complete project setup
mix unified.install    # Run unified installer

# Development commands
mix phx.server        # Start Phoenix server
iex -S mix           # Interactive shell
mix test             # Run tests
mix test.coverage    # Run with coverage analysis
```

### 8.2 Testing
```elixir
# Run full test suite
mix test

# Run with coverage
mix test --cover

# Run specific domain tests
mix test apps/indrajaal/test/domains/alarms

# Property-based testing for critical paths
mix test --only property
```

### 8.3 Code Quality
```bash
# Format code
mix format

# Run static analysis
mix credo --strict

# Type checking
mix dialyzer

# Security scan
mix sobelow

# Full quality check
mix quality
```

## 9. Deployment

### 9.3 Environment Variables
```bash
# Microsoft Entra ID
ENTRA_TENANT_ID=your-tenant-id
ENTRA_CLIENT_ID=your-client-id
ENTRA_CLIENT_SECRET=your-client-secret
ENTRA_B2C_TENANT_ID=your-b2c-tenant
ENTRA_B2C_CLIENT_ID=your-b2c-client
ENTRA_B2C_CLIENT_SECRET=your-b2c-secret

# Database
DATABASE_URL=postgresql://user:pass@host/db

# Security
SECRET_KEY_BASE=your-secret-key
GUARDIAN_SECRET_KEY=your-guardian-key

# Services
JELLYFISH_URL=http://jellyfish:5002
MINIO_ENDPOINT=http://minio:9000
```

## 10. Monitoring & Operations

### 10.1 Health Checks
- `/health` - Overall system health
- `/ready` - Readiness probe
- `/metrics` - Prometheus metrics

### 10.2 Key Metrics
- Active alarms by severity
- Response time percentiles
- Video streams active
- API request rates
- Database connection pool
- Background job queues

### 10.3 Operational Procedures
- Automated backups via pg_cron
- Log aggregation to Grafana Loki
- Distributed tracing with OpenTelemetry
- Alert routing via PagerDuty

## 11. Design by Contract (DbC)

### 11.1 Core Principles
- **Preconditions**: Client obligations before calling
- **Postconditions**: Supplier guarantees after execution
- **Invariants**: Conditions that always hold
- **Fail Fast**: Detect violations immediately

### 11.2 Implementation Strategy
1. Use pattern matching for structural validation
2. Apply guard clauses for type checking
3. Use typespecs + Dialyzer for static verification
4. Add DbC libraries for complex contracts

### 11.3 Contract Libraries
- **ExContract**: `requires/1`, `ensures/1`, `check/1`
- **Bond**: `@pre`, `@post`, `old()` for state changes
- Enable in dev/test only: `config :bond, enabled: Mix.env() in [:dev, :test]`

---

## 12. Project Organization

### 12.1 Directory Structure
```
indrajaal/
├── config/         # Application configuration
├── lib/            # Application source code
│   ├── indrajaal/  # Core business logic
│   ├── indrajaal_web/ # Web interface
│   └── mix/tasks/  # Custom Mix tasks
├── test/           # Test files
├── priv/           # Private application files
├── scripts/        # Utility scripts (organized by category)
├── docs/           # All documentation
│   ├── guides/     # CLAUDE-*.md files
│   ├── journal/    # Project progress tracking
│   └── archive/    # Historical documentation
└── data/           # Analysis outputs and data files
```

### 12.2 Mix Tasks Available
- `mix setup` - Complete project setup
- `mix test.coverage` - Run tests with coverage analysis
- `mix project.analyze` - Analyze project structure and quality
- `mix unified.install` - Run unified installer
- `mix docs` - Generate project documentation

### 12.3 File Placement Rules
1. **Never create files in root** except essential configs
2. **Documentation** → `docs/` (except README.md)
3. **Scripts** → `scripts/` or `lib/mix/tasks/`
4. **Tests** → `test/`
5. **Web files** → `lib/indrajaal_web/`
6. **Core logic** → `lib/indrajaal/`

---

*This CLAUDE.md provides comprehensive guidelines for the Indrajaal Security Monitoring System. Follow these rules to ensure consistent, high-quality code and system configuration.*