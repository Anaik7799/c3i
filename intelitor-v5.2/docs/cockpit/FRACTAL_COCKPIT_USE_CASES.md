# Fractal Knowledge Cockpit - Operational Use Cases

**Version**: 1.0.0 | **Date**: 2025-12-30 | **Status**: ACTIVE
**STAMP Constraints**: SC-PRAJNA-001 to SC-PRAJNA-007, SC-HMI-001 to SC-HMI-004

---

## Executive Summary

The Fractal Knowledge Cockpit is a Bio-Inspired Dark Cockpit TUI implementing NASA-STD-3000,
NUREG-0700, MIL-STD-1472H, and Laux/Wickens C3I Visual Display Principles. This document
catalogs all operational use cases across user roles and system components.

---

## 1. USER MANUAL SCENARIOS (End Users)

### 1.1 Document Ingestion & Knowledge Discovery

| UC-UM-001 | Bulk Document Ingestion |
|-----------|-------------------------|
| **Actor** | Knowledge Worker |
| **Goal** | Ingest documents into knowledge graph with fractal classification |
| **Precondition** | Documents exist in `docs/` hierarchy |
| **Flow** | 1. Launch cockpit → 2. Select ingestion mode → 3. Monitor progress → 4. Review classification |
| **Success Metrics** | < 3 second target, AS-IS → TO-BE mapping complete |
| **Fractal Level** | L4-L5 (Component-Domain) |

| UC-UM-002 | Statistical Sampling Preview |
|-----------|------------------------------|
| **Actor** | Knowledge Worker |
| **Goal** | Preview 3-file sample before full ingestion |
| **Flow** | 1. Select sample mode → 2. View entropy analysis → 3. Approve/abort full run |
| **Safety** | Prevents wasted compute on malformed datasets |

| UC-UM-003 | Knowledge Structure Visualization |
|-----------|-----------------------------------|
| **Actor** | Analyst |
| **Goal** | View hierarchical knowledge tree with entropy indicators |
| **Output** | Tree visualization with doc counts and progress bars |

| UC-UM-004 | Pattern Transformation Review |
|-----------|-------------------------------|
| **Actor** | Knowledge Architect |
| **Goal** | Review AS-IS → TO-BE transformation matrix |
| **Flow** | View pattern mappings (prose-dense → holonic_map/L3, etc.) |

### 1.2 Real-Time Monitoring

| UC-UM-010 | Pipeline Progress Monitoring |
|-----------|------------------------------|
| **Actor** | Operator |
| **Goal** | Monitor 8-phase pipeline progress in real-time |
| **Visual Elements** | Phase icons (🔍📊🏷️📖🔄🗺️📇✅), sparkline, trend arrows |

| UC-UM-011 | Throughput Analysis |
|-----------|----------------------|
| **Actor** | Performance Analyst |
| **Goal** | Monitor docs/s throughput with historical sparkline |
| **Metrics** | Current rate, trend (↑↓→), 12-sample history |

| UC-UM-012 | Target Tracking |
|-----------|-----------------|
| **Actor** | SLA Manager |
| **Goal** | Track time vs target (e.g., 972ms vs 3000ms = 308% ahead) |
| **Alert** | Color changes at 50%, 80%, 100% thresholds |

### 1.3 Error & Exception Handling

| UC-UM-020 | Error Count Monitoring |
|-----------|------------------------|
| **Actor** | Operator |
| **Goal** | Monitor error count with Dark Cockpit philosophy |
| **Behavior** | 0 errors = dim gray, >0 = bright red (management by exception) |

| UC-UM-021 | Fractal Log Analysis |
|-----------|----------------------|
| **Actor** | Support Engineer |
| **Goal** | Review 7-level fractal logs (L1-L7) with color coding |
| **Levels** | L1=Function, L2=Module, L3=Domain, L4=Component, L5=System, L6=Federation, L7=Universe |

---

## 2. DEVELOPER SCENARIOS — Comprehensive Coverage

### 2.1 Onboarding & Ramp-Up

| UC-DEV-001 | First-Day System Landscape |
|------------|----------------------------|
| **Actor** | New Developer |
| **Goal** | Understand overall system landscape and how services connect |
| **Output** | Interactive dependency graph, service map, team ownership |
| **Fractal** | L5-L6 (System-Federation) |

| UC-DEV-002 | Getting Started Guide Discovery |
|------------|--------------------------------|
| **Actor** | New Developer |
| **Goal** | Find local development setup instructions |
| **Sources** | `CLAUDE.md`, `README.md`, `docs/setup/` |
| **Output** | Step-by-step environment setup checklist |

| UC-DEV-003 | Team Conventions & Standards |
|------------|------------------------------|
| **Actor** | New Developer |
| **Goal** | Locate coding standards and contribution guidelines |
| **Sources** | `.credo.exs`, `.formatter.exs`, `CONTRIBUTING.md` |
| **STAMP** | SC-DOC-001 |

| UC-DEV-004 | Project Familiarisation |
|------------|-------------------------|
| **Actor** | New Developer |
| **Goal** | Discover relevant repositories for a given domain |
| **Output** | Domain-to-repo mapping, tech stack rationale |

| UC-DEV-005 | Historical Context Acquisition |
|------------|-------------------------------|
| **Actor** | Developer |
| **Goal** | Read past design documents to understand evolution |
| **Sources** | `journal/`, `docs/architecture/`, ADRs |
| **Output** | Timeline of major refactoring, deprecated approaches |

| UC-DEV-006 | Environment Setup Automation |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Find IDE configs, linter rules, formatting settings |
| **Sources** | `.vscode/`, `devenv.nix`, `.tool-versions` |
| **Integration** | Patient Mode, NixOS/Podman stack |

### 2.2 Code Discovery & Reuse

| UC-DEV-010 | Pattern Hunting |
|------------|-----------------|
| **Actor** | Developer |
| **Goal** | "How do we handle pagination/retry logic/date formatting?" |
| **Search** | Semantic code search across `lib/**/*.ex` |
| **Output** | Pattern examples with usage context |

| UC-DEV-011 | Internal Library Discovery |
|------------|----------------------------|
| **Actor** | Developer |
| **Goal** | Find shared libraries before adding external deps |
| **Scope** | Monorepo helper functions, reusable components |
| **STAMP** | AOR-GEM-003 (No Hallucinated APIs) |

| UC-DEV-012 | Reference Implementation Search |
|------------|--------------------------------|
| **Actor** | Developer |
| **Goal** | Find working examples of external service integration |
| **Examples** | OpenRouter, Zenoh, OTEL, Grafana integrations |
| **Output** | Annotated code snippets with context |

| UC-DEV-013 | Anti-Pattern Awareness |
|------------|------------------------|
| **Actor** | Developer |
| **Goal** | Understand approaches that failed |
| **Sources** | `journal/` RCA entries, deprecated code comments |
| **Output** | Pitfalls list, performance bottleneck history |

| UC-DEV-014 | Cross-Project Learning |
|------------|------------------------|
| **Actor** | Developer |
| **Goal** | Find how another team solved similar problem |
| **Scope** | Shared services, canonical pattern implementations |
| **Fractal** | L4-L5 (Component-System) |

| UC-DEV-015 | Codebase Pattern Analysis |
|------------|---------------------------|
| **Actor** | Developer |
| **Goal** | Identify code patterns and classify by fractal level |
| **Input** | `lib/**/*.ex`, `test/**/*.exs` |
| **Output** | Pattern frequency, entropy distribution, refactoring candidates |

### 2.3 Debugging & Troubleshooting

| UC-DEV-020 | Error Investigation |
|------------|---------------------|
| **Actor** | Developer |
| **Goal** | Search for specific error messages or codes |
| **Sources** | `EP-*` error patterns in CLAUDE.md, logs, code |
| **Output** | Root cause, past incidents, workarounds |

| UC-DEV-021 | Log Interpretation |
|------------|---------------------|
| **Actor** | Developer |
| **Goal** | Understand what specific log entries mean |
| **Integration** | 7-level fractal logging (L1-L7), Loki queries |
| **Output** | Code path, structured data meanings |

| UC-DEV-022 | Dependency Debugging |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Understand upstream/downstream service contracts |
| **Tools** | Integration test setups, mock configurations |
| **STAMP** | SC-TEST-004 (Mock external modules) |

| UC-DEV-023 | Data Flow Tracing |
|------------|-------------------|
| **Actor** | Developer |
| **Goal** | Understand how data moves through the system |
| **Visual** | Transformation logic, validation rules, Ash pipelines |
| **Fractal** | L3-L4 (Domain-Component) |

| UC-DEV-024 | Environment-Specific Issues |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Find dev/staging/prod configuration differences |
| **Sources** | `config/`, feature flags, environment variables |
| **Output** | Environment quirks, known issues |

| UC-DEV-025 | Memory & Resource Debugging |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Find profiling guides and tools |
| **History** | Past memory leak investigations, resource limits |
| **Tools** | `:recon`, `:observer`, FLAME pool stats |

### 2.4 Decision Archaeology & Context

| UC-DEV-030 | ADR Access |
|------------|------------|
| **Actor** | Developer |
| **Goal** | Understand why a particular technology was chosen |
| **Sources** | `docs/architecture/`, `journal/` ADR entries |
| **Output** | Trade-off analysis, constraint documentation |

| UC-DEV-031 | Technical Debt Context |
|------------|------------------------|
| **Actor** | Developer |
| **Goal** | Understand why shortcuts were taken |
| **Sources** | `TODO` comments, `PROJECT_TODOLIST.md`, journal |
| **Output** | Remediation timelines, risk assessments |

| UC-DEV-032 | Abandoned Approach Investigation |
|------------|----------------------------------|
| **Actor** | Developer |
| **Goal** | Find what was tried before current solution |
| **Sources** | Git history, deprecated branches, journal RCAs |
| **Output** | Lessons learned, rejection rationale |

| UC-DEV-033 | Requirement Traceability |
|------------|--------------------------|
| **Actor** | Developer |
| **Goal** | Connect code to original business requirements |
| **Output** | Ticket links, discussion threads, scope changes |

| UC-DEV-034 | Constraint Documentation |
|------------|--------------------------|
| **Actor** | Developer |
| **Goal** | Find regulatory/compliance requirements affecting code |
| **STAMP** | IEC 61508, ISO 27001, GDPR, EN 50131 compliance |
| **Output** | Security requirements, performance SLAs |

### 2.5 API & Integration Work

| UC-DEV-040 | API Contract Discovery |
|------------|------------------------|
| **Actor** | Developer |
| **Goal** | Find OpenAPI/Swagger specifications |
| **Sources** | `priv/static/swagger.json`, GraphQL schemas, gRPC protos |
| **Output** | Service definitions, endpoint documentation |

| UC-DEV-041 | Integration Pattern Reference |
|------------|-------------------------------|
| **Actor** | Developer |
| **Goal** | Find service-to-service communication patterns |
| **Patterns** | Zenoh pub/sub, Phoenix channels, Control Bus |
| **STAMP** | SC-BUS-001 (Async only) |

| UC-DEV-042 | Auth & Authorisation Reference |
|------------|--------------------------------|
| **Actor** | Developer |
| **Goal** | Understand OAuth flows, token handling |
| **Sources** | `lib/indrajaal/authentication/`, JWT configs |
| **Security** | API key management, service accounts |

| UC-DEV-043 | Third-Party Integration Guides |
|------------|--------------------------------|
| **Actor** | Developer |
| **Goal** | Find setup instructions for external services |
| **Examples** | OpenRouter AI, Grafana, Prometheus, TimescaleDB |
| **Info** | Rate limits, quotas, sandbox credentials |

| UC-DEV-044 | API Versioning & Compatibility |
|------------|--------------------------------|
| **Actor** | Developer |
| **Goal** | Understand versioning strategies |
| **Output** | Backward compatibility, deprecation timelines |

### 2.6 Testing Scenarios

| UC-DEV-050 | Test Strategy Discovery |
|------------|-------------------------|
| **Actor** | QA Engineer |
| **Goal** | Understand what tests exist for a component |
| **Output** | Coverage expectations, naming standards |
| **STAMP** | SC-TEST-001 (Test files MUST compile) |

| UC-DEV-051 | Test Coverage Mapping |
|------------|----------------------|
| **Actor** | QA Engineer |
| **Goal** | Map test files to implementation files |
| **Output** | Coverage gaps, orphan tests, untested modules |

| UC-DEV-052 | Test Data Management |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Find fixtures and seed data |
| **Sources** | `test/support/factories/`, `priv/repo/seeds.exs` |
| **STAMP** | SC-FAC-001 (Use Ash.Changeset pattern) |

| UC-DEV-053 | Test Environment Setup |
|------------|------------------------|
| **Actor** | Developer |
| **Goal** | Run integration tests locally |
| **Tools** | Mock servers, contract testing, 3-container stack |
| **Command** | `MIX_ENV=test mix test --coverage` |

| UC-DEV-054 | Edge Case Documentation |
|------------|-------------------------|
| **Actor** | QA Engineer |
| **Goal** | Find documented edge cases and boundary conditions |
| **Sources** | Property tests (PropCheck + ExUnitProperties) |
| **STAMP** | Ω₄ (TDG - Test-Driven Generation) |

| UC-DEV-055 | Performance Test Reference |
|------------|---------------------------|
| **Actor** | Developer |
| **Goal** | Find load testing scripts and baselines |
| **Sources** | `scripts/performance/`, Artillery configs |
| **Metrics** | Response <50ms (SC-PRF-050) |

### 2.7 Code Review & Quality

| UC-DEV-060 | Review Checklist Access |
|------------|-------------------------|
| **Actor** | Reviewer |
| **Goal** | Find component-specific review guidelines |
| **Checklists** | Security review, performance criteria |
| **STAMP** | Ω₆ (Mandatory Gates) |

| UC-DEV-061 | Style Guide Reference |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Find coding conventions and standards |
| **Sources** | `.credo.exs`, Credo rules, naming conventions |
| **STAMP** | SC-CREDO-001 to SC-CREDO-005 |

| UC-DEV-062 | Common Feedback Patterns |
|------------|--------------------------|
| **Actor** | Reviewer |
| **Goal** | Find frequently given review feedback |
| **Examples** | apply/2 anti-pattern, DRY violations, complexity |
| **AOR** | AOR-CREDO-001, AOR-CREDO-002 |

| UC-DEV-063 | Approval Requirements |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Understand who approves changes to specific areas |
| **Paths** | Escalation for architectural changes, compliance sign-off |

### 2.8 Build & Deployment Understanding

| UC-DEV-070 | CI/CD Pipeline Comprehension |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Understand build stages and purposes |
| **Sources** | `.github/workflows/`, pipeline configs |
| **Stages** | Compile → Test → Credo → Dialyzer → Sobelow |

| UC-DEV-071 | Patient Mode Build Monitoring |
|------------|-------------------------------|
| **Actor** | CI System |
| **Goal** | Monitor `NO_TIMEOUT=true PATIENT_MODE=enabled` builds |
| **Log** | `./data/tmp/1-compile.log` real-time parsing |
| **STAMP** | SC-CMP-028 (no interruption) |

| UC-DEV-072 | Build Failure Investigation |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Find common build failure causes and fixes |
| **Sources** | EP-* error patterns, flaky test docs |
| **AOR** | AOR-TPS-001 (Jidoka - stop on defect) |

| UC-DEV-073 | Deployment Procedure Reference |
|------------|--------------------------------|
| **Actor** | DevOps |
| **Goal** | Understand deployment strategies |
| **Strategies** | Blue-green, canary, rollback procedures |
| **STAMP** | SC-EMR-060 (Rollback capability) |

| UC-DEV-074 | Release Process |
|------------|-----------------|
| **Actor** | Release Manager |
| **Goal** | Find versioning conventions and changelog practices |
| **Output** | Release approval workflows, semantic versioning |

| UC-DEV-075 | Quality Gate Dashboard |
|------------|------------------------|
| **Actor** | Release Manager |
| **Goal** | Visualize Compile, Credo, Dialyzer, Sobelow, Test status |
| **STAMP** | Ω₆ (Mandatory Gates) |

| UC-DEV-076 | Warning Elimination Tracking |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Track compilation warnings during Patient Mode |
| **Target** | Zero warnings (Ω₃ Zero-Defect) |

### 2.9 Security-Related Scenarios

| UC-DEV-080 | Secure Coding Guidelines |
|------------|--------------------------|
| **Actor** | Developer |
| **Goal** | Find language-specific security best practices |
| **Sources** | Sobelow rules, input validation, output encoding |
| **STAMP** | SC-SEC-044 (Sobelow check) |

| UC-DEV-081 | Vulnerability Context |
|------------|----------------------|
| **Actor** | Security Engineer |
| **Goal** | Find past security incidents and remediations |
| **Sources** | Journal security entries, vulnerability assessments |

| UC-DEV-082 | Secrets Management |
|------------|---------------------|
| **Actor** | Developer |
| **Goal** | Understand how secrets are stored and accessed |
| **Procedures** | Rotation, emergency revocation |
| **Warning** | Never commit `.env`, `credentials.json` |

| UC-DEV-083 | Compliance Requirements |
|------------|-------------------------|
| **Actor** | Developer |
| **Goal** | Find GDPR/PCI/SOC2/IEC 61508 relevant code |
| **Sources** | Audit logging, data retention implementations |
| **STAMP** | Full compliance matrix in CLAUDE.md |

| UC-DEV-084 | Security Review Preparation |
|------------|----------------------------|
| **Actor** | Security Engineer |
| **Goal** | Find threat models and security architecture |
| **Sources** | STAMP constraints, penetration test results |

### 2.10 Performance Optimisation

| UC-DEV-090 | Baseline Discovery |
|------------|---------------------|
| **Actor** | Developer |
| **Goal** | Find performance benchmarks for components |
| **Targets** | Response <50ms (SC-PRF-050), OODA <100ms |
| **Sources** | Historical trends, SLA definitions |

| UC-DEV-091 | Optimisation History |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Find past performance improvements |
| **Sources** | Journal entries, profiling results |
| **Output** | Failed attempts, bottleneck analyses |

| UC-DEV-092 | Caching Strategies |
|------------|---------------------|
| **Actor** | Developer |
| **Goal** | Understand caching layers and configurations |
| **Components** | Redis (embedded in app), ETS, Cachex |
| **Info** | Invalidation logic, cache-related incidents |

| UC-DEV-093 | Database Optimisation |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Find query optimisation guidelines |
| **Sources** | Indexing strategies, slow query docs |
| **STAMP** | SC-DB-012 (create_if_not_exists indexes) |

### 2.11 Migration & Modernisation

| UC-DEV-100 | Legacy System Understanding |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Find documentation for systems being replaced |
| **Output** | Business logic in legacy, data migration requirements |

| UC-DEV-101 | Migration Planning |
|------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find past migration playbooks |
| **Patterns** | Strangler fig, dual-write, shadow mode |
| **Sources** | Rollback strategies, traffic routing configs |

| UC-DEV-102 | Compatibility Requirements |
|------------|---------------------------|
| **Actor** | Developer |
| **Goal** | Understand backward compatibility constraints |
| **Output** | Client dependencies, sunset timelines |

### 2.12 Documentation Contribution

| UC-DEV-110 | Documentation Standards |
|------------|-------------------------|
| **Actor** | Developer |
| **Goal** | Find templates for different doc types |
| **Sources** | `docs/templates/`, review processes |
| **STAMP** | SC-DOC-001 (moduledoc with WHAT/WHY/CONSTRAINTS) |

| UC-DEV-111 | Keeping Docs Current |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Understand documentation ownership |
| **Tools** | Stale doc flagging, docs-as-code practices |

| UC-DEV-112 | Knowledge Capture |
|------------|-------------------|
| **Actor** | Developer |
| **Goal** | Find formats for capturing tribal knowledge |
| **Templates** | Runbooks, postmortem standards, RCA format |

### 2.13 Collaboration & Communication

| UC-DEV-120 | Finding Expertise |
|------------|-------------------|
| **Actor** | Developer |
| **Goal** | Discover who has deep knowledge of specific areas |
| **Sources** | Git blame, past contributors, CODEOWNERS |

| UC-DEV-121 | Async Communication Reference |
|------------|-------------------------------|
| **Actor** | Developer |
| **Goal** | Find past technical discussions and outcomes |
| **Sources** | RFC archives, design review notes |

| UC-DEV-122 | Cross-Team Coordination |
|------------|-------------------------|
| **Actor** | Developer |
| **Goal** | Find dependency owners and communication channels |
| **Output** | API consumer registries, shared component governance |

### 2.14 Tool & Environment Configuration

| UC-DEV-130 | IDE Setup |
|------------|-----------|
| **Actor** | Developer |
| **Goal** | Find recommended extensions and configurations |
| **Sources** | `.vscode/`, debugging configs, keyboard shortcuts |

| UC-DEV-131 | Local Dev Environment |
|------------|----------------------|
| **Actor** | Developer |
| **Goal** | Find container setup files |
| **Sources** | `podman-compose.yml`, `devenv.nix`, seed scripts |
| **STAMP** | SC-CNT-009 (NixOS/Podman only) |

| UC-DEV-132 | Debugging Tool Configuration |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Find profiler and tracing setup |
| **Tools** | Distributed tracing (OTEL), log aggregation (Loki) |

### 2.15 Incident Response (Developer Perspective)

| UC-DEV-140 | Service Ownership Lookup |
|------------|--------------------------|
| **Actor** | Developer |
| **Goal** | Find who owns what during incident |
| **Output** | Escalation paths, on-call schedules |

| UC-DEV-141 | Runbook Execution |
|------------|-------------------|
| **Actor** | Developer |
| **Goal** | Find step-by-step remediation guides |
| **Sources** | `scripts/`, automation scripts, diagnostic queries |

| UC-DEV-142 | Postmortem Contribution |
|------------|-------------------------|
| **Actor** | Developer |
| **Goal** | Find timeline reconstruction resources |
| **Templates** | RCA format, action item tracking |
| **AOR** | AOR-RCA-001 (5-Level Analysis) |

### 2.16 Dependency & Module Analysis

| UC-DEV-150 | Dependency Graph Construction |
|------------|-------------------------------|
| **Actor** | Architect |
| **Goal** | Build module dependency graph from imports |
| **Output** | Graph visualization, cycle detection, coupling metrics |

| UC-DEV-151 | Git Incremental Validation |
|------------|---------------------------|
| **Actor** | Developer |
| **Goal** | Validate only changed files since last commit |
| **Efficiency** | Faster feedback loop on large codebases |

| UC-DEV-152 | API Documentation Generation |
|------------|------------------------------|
| **Actor** | Developer |
| **Goal** | Extract @spec, @doc, @typedoc for API reference |
| **Output** | Structured API documentation tree |

| UC-DEV-153 | Journal Entry Analysis |
|------------|------------------------|
| **Actor** | Project Manager |
| **Goal** | Analyze `journal/` entries for decision tracking |
| **Output** | Timeline, decision points, RCA entries |

---

## 3. ADMIN & SRE SCENARIOS — Comprehensive Coverage

### 3.1 Incident Management

| UC-SRE-001 | Incident Detection & Triage |
|------------|------------------------------|
| **Actor** | SRE |
| **Goal** | Find alerting thresholds and classification criteria |
| **Output** | Severity classification, service criticality, business impact |
| **STAMP** | SC-EMR-057 (Stop <5s on violation) |

| UC-SRE-002 | Initial Response Coordination |
|------------|-------------------------------|
| **Actor** | Incident Commander |
| **Goal** | Find on-call rosters, war room setup, escalation paths |
| **Output** | Contact information, handoff procedures, communication templates |

| UC-SRE-003 | Diagnosis & Investigation |
|------------|---------------------------|
| **Actor** | SRE |
| **Goal** | Find service dependency maps for impact analysis |
| **Tools** | Diagnostic commands, safe-to-run queries, log locations |
| **Fractal** | L4-L6 (Component-Federation) |

| UC-SRE-004 | Runbook Execution |
|------------|-------------------|
| **Actor** | SRE |
| **Goal** | Find step-by-step remediation procedures |
| **Sources** | `scripts/`, automated remediation, rollback procedures |
| **STAMP** | SC-EMR-060 (Rollback capability) |

| UC-SRE-005 | Incident Communication |
|------------|------------------------|
| **Actor** | Incident Commander |
| **Goal** | Find status page updates, communication protocols |
| **Templates** | Customer communication, regulatory notifications |

| UC-SRE-006 | Post-Incident Activities |
|------------|--------------------------|
| **Actor** | SRE Lead |
| **Goal** | Find postmortem templates, action item tracking |
| **Output** | Timeline reconstruction, blameless culture guidelines |
| **AOR** | AOR-RCA-001 (5-Level Analysis) |

### 3.2 Runbook Management

| UC-SRE-010 | Runbook Discovery |
|------------|-------------------|
| **Actor** | SRE |
| **Goal** | Find runbooks by service, symptom, or error type |
| **Metadata** | Ownership, last-updated, dependencies |
| **Categories** | Diagnostic, remediation, escalation |

| UC-SRE-011 | Runbook Creation |
|------------|------------------|
| **Actor** | SRE |
| **Goal** | Find templates and approval workflows |
| **Validation** | Testing procedures, versioning requirements |

| UC-SRE-012 | Runbook Automation |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find automation candidates and scripting standards |
| **Checkpoints** | Human-in-the-loop, rollback mechanisms |

| UC-SRE-013 | Runbook Effectiveness |
|------------|----------------------|
| **Actor** | SRE Manager |
| **Goal** | Track usage, success rates, MTTR improvements |
| **Analysis** | Feedback from responders, gap analysis |

### 3.3 Configuration Management

| UC-SRE-020 | Configuration Discovery |
|------------|-------------------------|
| **Actor** | SRE |
| **Goal** | Find configuration locations across environments |
| **Sources** | `config/`, feature flags, inheritance hierarchies |

| UC-SRE-021 | Configuration Change Management |
|------------|--------------------------------|
| **Actor** | SRE |
| **Goal** | Find approval workflows, drift detection |
| **Tools** | Rollback procedures, impact analysis |

| UC-SRE-022 | Environment-Specific Configs |
|------------|------------------------------|
| **Actor** | SRE |
| **Goal** | Find dev/staging/prod differences |
| **Procedures** | Promotion, secrets management, parity exceptions |

| UC-SRE-023 | Infrastructure as Code |
|------------|------------------------|
| **Actor** | DevOps |
| **Goal** | Find IaC modules (NixOS, devenv.nix) |
| **Safety** | State management, blast radius limits |
| **STAMP** | SC-CNT-009 (NixOS/Podman only) |

| UC-SRE-024 | Secrets & Sensitive Config |
|------------|------------------------------|
| **Actor** | SRE |
| **Goal** | Find rotation schedules, revocation procedures |
| **Audit** | Access trails, injection mechanisms |

### 3.4 Deployment Operations

| UC-SRE-030 | Deployment Procedures |
|------------|----------------------|
| **Actor** | DevOps |
| **Goal** | Find deployment checklists by service type |
| **Policies** | Change freeze calendars, approval chains |

| UC-SRE-031 | Deployment Strategies |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find blue-green, canary configurations |
| **Coordination** | Feature flags, traffic shifting, rollback triggers |

| UC-SRE-032 | Deployment Execution |
|------------|----------------------|
| **Actor** | DevOps |
| **Goal** | Find command references and monitoring dashboards |
| **Validation** | Smoke tests, communication protocols |

| UC-SRE-033 | Rollback Procedures |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find rollback decision criteria and instructions |
| **Considerations** | Data migration, partial rollback for microservices |
| **STAMP** | SC-EMR-060 |

| UC-SRE-034 | Release Coordination |
|------------|----------------------|
| **Actor** | Release Manager |
| **Goal** | Find multi-service coordination, dependency ordering |
| **Output** | Release notes, customer communication |

### 3.5 Monitoring & Observability

| UC-SRE-040 | Monitoring Setup |
|------------|------------------|
| **Actor** | SRE |
| **Goal** | Find monitoring stack architecture |
| **Components** | OTEL, Prometheus, Grafana, Loki |
| **STAMP** | SC-OBS-069 (Dual Log), SC-OBS-071 (4 OTEL modules) |

| UC-SRE-041 | Dashboard Management |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find existing dashboards by service/domain |
| **Standards** | Templates, ownership, access control |
| **Port** | Grafana :3000 |

| UC-SRE-042 | Alert Configuration |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find alert thresholds, routing rules |
| **Mitigation** | Suppression, maintenance windows, fatigue reduction |

| UC-SRE-043 | SLI/SLO Management |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find SLO definitions, SLI measurement |
| **Tracking** | Error budget, review procedures |
| **Target** | Response <50ms (SC-PRF-050) |

| UC-SRE-044 | Observability Tooling |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find tracing queries, log templates |
| **Correlation** | Cross-telemetry techniques, distributed tracing |

| UC-SRE-045 | Anomaly Detection |
|------------|-------------------|
| **Actor** | SRE |
| **Goal** | Find baseline definitions, seasonal patterns |
| **Tuning** | False positive reduction, investigation workflows |

### 3.6 Capacity Planning

| UC-SRE-050 | Capacity Assessment |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find resource utilisation baselines |
| **Analysis** | Growth trends, headroom requirements |

| UC-SRE-051 | Scaling Procedures |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find horizontal/vertical scaling procedures |
| **Automation** | Auto-scaling configs, bottleneck identification |

| UC-SRE-052 | Capacity Forecasting |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find demand forecasting, seasonal patterns |
| **Planning** | Event-driven capacity, long-term roadmaps |

| UC-SRE-053 | Resource Optimisation |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find rightsizing recommendations |
| **Analysis** | Unused resources, cost-capacity trade-offs |

| UC-SRE-054 | Capacity Incident Response |
|------------|---------------------------|
| **Actor** | SRE |
| **Goal** | Find emergency scaling, load shedding |
| **Mechanisms** | Graceful degradation, communication |

### 3.7 Reliability Engineering

| UC-SRE-060 | Reliability Assessment |
|------------|------------------------|
| **Actor** | SRE |
| **Goal** | Find service reliability scorecards |
| **Analysis** | Failure modes, single points of failure |

| UC-SRE-061 | Chaos Engineering |
|------------|-------------------|
| **Actor** | SRE |
| **Goal** | Find chaos experiment catalogues |
| **Safety** | Steady-state hypotheses, blast radius controls |

| UC-SRE-062 | Resilience Patterns |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find circuit breaker, retry configurations |
| **Patterns** | Timeouts, bulkheads, isolation |
| **STAMP** | SC-BUS-003 (1000 events/sec breaker) |

| UC-SRE-063 | Disaster Recovery |
|------------|-------------------|
| **Actor** | SRE |
| **Goal** | Find DR runbooks by disaster scenario |
| **Metrics** | RTO/RPO definitions, failover procedures |

| UC-SRE-064 | Business Continuity |
|------------|---------------------|
| **Actor** | SRE |
| **Goal** | Find critical service definitions |
| **Procedures** | Degraded mode operations, extended outage plans |

| UC-SRE-065 | Production Readiness Reviews |
|------------|------------------------------|
| **Actor** | SRE Lead |
| **Goal** | Find PRR checklists, reliability debt tracking |
| **Framework** | Prioritisation, budgeting, investment |

### 3.8 Performance Management

| UC-SRE-070 | Performance Monitoring |
|------------|------------------------|
| **Actor** | SRE |
| **Goal** | Find performance baselines, latency percentiles |
| **Detection** | Throughput measurement, regression detection |
| **STAMP** | SC-PRF-050 (Response <50ms) |

| UC-SRE-071 | Performance Investigation |
|------------|---------------------------|
| **Actor** | SRE |
| **Goal** | Find profiling tools, flame graph generation |
| **Analysis** | Database queries, distributed tracing |

| UC-SRE-072 | Load Testing |
|------------|--------------|
| **Actor** | SRE |
| **Goal** | Find load testing environments and scenarios |
| **Sources** | `scripts/performance/`, Artillery configs |
| **Interpretation** | Result analysis, baseline comparison |

| UC-SRE-073 | Synthetic Monitoring |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find synthetic test configurations |
| **Analysis** | Coverage gaps, real user correlation |

### 3.9 Security Operations

| UC-SRE-080 | Security Monitoring |
|------------|---------------------|
| **Actor** | Security Engineer |
| **Goal** | Find security event detection rules |
| **Tools** | SIEM queries, security dashboards |

| UC-SRE-081 | Vulnerability Management |
|------------|-------------------------|
| **Actor** | Security Engineer |
| **Goal** | Find scanning schedules, prioritisation criteria |
| **Procedures** | Patching timelines, exception processes |

| UC-SRE-082 | Access Management |
|------------|-------------------|
| **Actor** | Security Engineer |
| **Goal** | Find provisioning, access reviews |
| **Procedures** | Break-glass access, privilege escalation monitoring |

| UC-SRE-083 | Security Incident Response |
|------------|---------------------------|
| **Actor** | Security Engineer |
| **Goal** | Find classification criteria, containment procedures |
| **Requirements** | Forensic collection, regulatory notification |

| UC-SRE-084 | Compliance Operations |
|------------|----------------------|
| **Actor** | Security Engineer |
| **Goal** | Find compliance control mappings |
| **Audit** | Evidence collection, remediation workflows |
| **STAMP** | IEC 61508, ISO 27001, GDPR, EN 50131 |

| UC-SRE-085 | Security Hardening |
|------------|---------------------|
| **Actor** | Security Engineer |
| **Goal** | Find baseline configurations, verification |
| **Detection** | Configuration drift, waiver processes |
| **STAMP** | SC-SEC-047 (Encryption) |

### 3.10 Database Operations

| UC-SRE-090 | Database Administration |
|------------|-------------------------|
| **Actor** | DBA |
| **Goal** | Find instance inventories, access procedures |
| **Info** | Maintenance windows, upgrade paths |
| **Stack** | PostgreSQL 17 + TimescaleDB |

| UC-SRE-091 | Backup & Recovery |
|------------|-------------------|
| **Actor** | DBA |
| **Goal** | Find backup schedules, verification |
| **Procedures** | Point-in-time recovery, cross-region backups |

| UC-SRE-092 | Database Performance |
|------------|----------------------|
| **Actor** | DBA |
| **Goal** | Find slow query analysis, indexing strategies |
| **Tuning** | Connection pools, query plans |
| **STAMP** | SC-DB-012 (create_if_not_exists indexes) |

| UC-SRE-093 | Schema Management |
|------------|-------------------|
| **Actor** | DBA |
| **Goal** | Find schema change procedures |
| **Versioning** | Migration rollback, backward compatibility |
| **STAMP** | SC-MIG-001, SC-MIG-002 |

| UC-SRE-094 | Database Scaling |
|------------|------------------|
| **Actor** | DBA |
| **Goal** | Find read replica, sharding configurations |
| **Procedures** | Connection scaling, failover |

### 3.11 Network Operations

| UC-SRE-100 | Network Topology |
|------------|------------------|
| **Actor** | Network Engineer |
| **Goal** | Find architecture diagrams, configurations |
| **Components** | Subnets, VLANs, load balancers, DNS |

| UC-SRE-101 | Network Troubleshooting |
|------------|-------------------------|
| **Actor** | SRE |
| **Goal** | Find diagnostic procedures, packet capture |
| **Analysis** | Path tracing, latency investigation |

| UC-SRE-102 | Network Security |
|------------|------------------|
| **Actor** | Security Engineer |
| **Goal** | Find firewall rules, segmentation policies |
| **Protection** | DDoS mitigation, intrusion detection |

### 3.12 Container & Orchestration

| UC-SRE-110 | Container Health Dashboard |
|------------|----------------------------|
| **Actor** | SysAdmin |
| **Goal** | Monitor 3-container stack (App, DB, Obs) health |
| **Containers** | `indrajaal-app`, `indrajaal-db`, `indrajaal-obs` |
| **Metrics** | CPU, Memory, Network, Restart count |

| UC-SRE-111 | Container Lifecycle Management |
|------------|-------------------------------|
| **Actor** | DevOps Engineer |
| **Goal** | Start/Stop/Restart containers via cockpit |
| **Commands** | `podman-compose up -d`, `podman stop`, `podman restart` |
| **STAMP** | SC-CNT-009 (NixOS/Podman only) |

| UC-SRE-112 | Container Log Aggregation |
|------------|---------------------------|
| **Actor** | SysAdmin |
| **Goal** | Stream and filter container logs in cockpit |
| **Integration** | `podman logs -f` with fractal level filtering |

| UC-SRE-113 | Registry Management |
|------------|----------------------|
| **Actor** | DevOps Engineer |
| **Goal** | Manage `localhost/` container registry |
| **STAMP** | SC-CNT-010 (localhost registry only) |

| UC-SRE-114 | Container Image Standards |
|------------|---------------------------|
| **Actor** | DevOps |
| **Goal** | Find image scanning, registry management |
| **Config** | Runtime configurations, resource limits |
| **STAMP** | SC-CNT-012 (Rootless) |

| UC-SRE-115 | Container Troubleshooting |
|------------|---------------------------|
| **Actor** | SRE |
| **Goal** | Find pod debugging, storage troubleshooting |
| **Analysis** | Network policies, component issues |

### 3.13 Cloud Operations

| UC-SRE-120 | Cloud Resource Management |
|------------|---------------------------|
| **Actor** | Cloud Engineer |
| **Goal** | Find resource inventory, tagging standards |
| **Lifecycle** | Orphaned resource cleanup, cross-account management |

| UC-SRE-121 | Cost Management |
|------------|-----------------|
| **Actor** | FinOps |
| **Goal** | Find cost allocation, anomaly detection |
| **Optimisation** | Reservations, savings plans |

| UC-SRE-122 | FinOps Practices |
|------------|------------------|
| **Actor** | FinOps |
| **Goal** | Find visibility, governance policies |
| **Accountability** | Cost optimisation workflows, financial models |

### 3.14 Automation & Tooling

| UC-SRE-130 | Automation Inventory |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find existing scripts, ownership, maintenance |
| **Approval** | Documentation, usage requirements |

| UC-SRE-131 | Job Scheduling |
|------------|----------------|
| **Actor** | SRE |
| **Goal** | Find scheduled jobs, dependency management |
| **Monitoring** | Failure alerting, execution history |

| UC-SRE-132 | ChatOps & Self-Service |
|------------|------------------------|
| **Actor** | SRE |
| **Goal** | Find command references, portal capabilities |
| **Workflows** | Request procedures, approvals |

| UC-SRE-133 | Automation Monitoring |
|------------|----------------------|
| **Actor** | SRE |
| **Goal** | Find execution monitoring, failure patterns |
| **Metrics** | Performance, SLAs |

### 3.15 Vendor & Third-Party

| UC-SRE-140 | Vendor Operations |
|------------|-------------------|
| **Actor** | SRE |
| **Goal** | Find vendor contacts, SLA tracking |
| **Procedures** | Incident coordination, change notifications |

| UC-SRE-141 | Third-Party Integrations |
|------------|--------------------------|
| **Actor** | SRE |
| **Goal** | Find integration health monitoring |
| **Procedures** | Failover, credential management, versioning |

| UC-SRE-142 | Vendor Incidents |
|------------|------------------|
| **Actor** | SRE |
| **Goal** | Find vendor status monitoring |
| **Procedures** | Impact assessment, postmortem participation |

### 3.16 Change Management

| UC-SRE-150 | Change Procedures |
|------------|-------------------|
| **Actor** | Change Manager |
| **Goal** | Find request templates, approval matrices |
| **Scheduling** | Coordination, emergency procedures |

| UC-SRE-151 | Change Risk Assessment |
|------------|------------------------|
| **Actor** | Change Manager |
| **Goal** | Find classification criteria, impact analysis |
| **Planning** | Rollback requirements, testing |

| UC-SRE-152 | Change Communication |
|------------|----------------------|
| **Actor** | Change Manager |
| **Goal** | Find notification procedures, calendars |
| **Policies** | Change freeze, stakeholder requirements |

| UC-SRE-153 | Change Review |
|------------|---------------|
| **Actor** | Change Manager |
| **Goal** | Find post-implementation review procedures |
| **Metrics** | Success metrics, failed change analysis |

### 3.17 Compliance & Audit

| UC-SRE-160 | Compliance Monitoring |
|------------|----------------------|
| **Actor** | Compliance Officer |
| **Goal** | Find control configurations, violation detection |
| **Tracking** | Remediation, reporting |

| UC-SRE-161 | Audit Support |
|------------|---------------|
| **Actor** | Compliance Officer |
| **Goal** | Find evidence collection, audit trails |
| **Procedures** | Response, finding remediation |

| UC-SRE-162 | Regulatory Requirements |
|------------|-------------------------|
| **Actor** | Compliance Officer |
| **Goal** | Find requirement mappings, change tracking |
| **Reporting** | Procedures, incident notification |
| **STAMP** | IEC 61508 SIL-2, ISO 27001, GDPR, EN 50131 |

| UC-SRE-163 | Policy Enforcement |
|------------|---------------------|
| **Actor** | Compliance Officer |
| **Goal** | Find enforcement mechanisms, exceptions |
| **Handling** | Violations, update communication |

### 3.18 Documentation & Knowledge Transfer

| UC-SRE-170 | Operational Documentation |
|------------|---------------------------|
| **Actor** | SRE |
| **Goal** | Find standards, review processes |
| **Tracking** | Freshness, ownership |

| UC-SRE-171 | Knowledge Capture |
|------------|-------------------|
| **Actor** | SRE |
| **Goal** | Find tribal knowledge procedures |
| **Processes** | Lessons learned, expertise mapping |

| UC-SRE-172 | Training & Enablement |
|------------|----------------------|
| **Actor** | SRE Manager |
| **Goal** | Find onboarding materials, certifications |
| **Programs** | Shadowing, mentorship, competency assessment |

---

## 4. TECHNICAL LEADERSHIP & ARCHITECTURE SCENARIOS — Comprehensive Coverage

### 4.1 Architecture Decision Making

| UC-ARCH-001 | Decision Context Gathering |
|-------------|----------------------------|
| **Actor** | Architect |
| **Goal** | Find historical decisions, constraints, business strategy |
| **Sources** | ADRs, regulatory docs, `journal/` |
| **Output** | Precedent analysis, organisational capabilities |

| UC-ARCH-002 | Options Analysis |
|-------------|------------------|
| **Actor** | Architect |
| **Goal** | Find past evaluations, POC results, industry benchmarks |
| **Output** | Reference architectures, TCO models |

| UC-ARCH-003 | Trade-off Documentation |
|-------------|-------------------------|
| **Actor** | Architect |
| **Goal** | Find ADR templates, risk assessment frameworks |
| **Classification** | Reversibility levels, commitment tracking |

| UC-ARCH-004 | Decision Socialisation |
|-------------|------------------------|
| **Actor** | Architect |
| **Goal** | Find review board procedures, stakeholder mapping |
| **Processes** | Consensus-building, escalation paths |

| UC-ARCH-005 | Decision Tracking |
|-------------|-------------------|
| **Actor** | Architect |
| **Goal** | Find ADR repositories, status tracking, dependencies |
| **Schedules** | Sunset triggers, revisit cadences |

### 4.2 Technology Strategy & Roadmapping

| UC-ARCH-010 | Technology Radar Maintenance |
|-------------|------------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find assessment criteria, emerging tech evaluation |
| **Tracking** | Adoption lifecycle, retirement planning |

| UC-ARCH-011 | Strategic Alignment |
|-------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find business capability to technology mappings |
| **Output** | Investment plans, outcome traceability |

| UC-ARCH-012 | Roadmap Development |
|-------------|---------------------|
| **Actor** | Tech Lead |
| **Goal** | Find templates, dependency sequencing |
| **Cadence** | Communication, update schedules |

| UC-ARCH-013 | Technology Lifecycle |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find currency tracking, EOL/EOS schedules |
| **Planning** | Migration triggers, legacy risk assessment |

| UC-ARCH-014 | Innovation Pipeline |
|-------------|---------------------|
| **Actor** | Tech Lead |
| **Goal** | Find proposal templates, experimentation budget |
| **Metrics** | Portfolio balance, promotion paths |

| UC-ARCH-015 | Build vs Buy Analysis |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find make/buy/partner frameworks |
| **Analysis** | TCO, strategic differentiation |

### 4.3 System Design & Modelling

| UC-ARCH-020 | Architecture Documentation |
|-------------|----------------------------|
| **Actor** | Architect |
| **Goal** | Find documentation standards, diagramming conventions |
| **Structure** | Repository navigation, abstraction levels |

| UC-ARCH-021 | Domain Modelling |
|-------------|------------------|
| **Actor** | Architect |
| **Goal** | Find domain model repositories, bounded contexts |
| **Assets** | Ubiquitous language glossaries, ownership |
| **Fractal** | L3 (Domain level) |

| UC-ARCH-022 | System Decomposition |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find service boundary criteria, coupling analysis |
| **Patterns** | Microservices vs monolith decision frameworks |

| UC-ARCH-023 | Integration Architecture |
|-------------|--------------------------|
| **Actor** | Architect |
| **Goal** | Find integration pattern standards |
| **Patterns** | API guidelines, event-driven architecture |
| **STAMP** | SC-BUS-001 (Async only) |

| UC-ARCH-024 | Data Architecture |
|-------------|-------------------|
| **Actor** | Data Architect |
| **Goal** | Find data model repositories, lineage documentation |
| **Patterns** | Ownership, consistency, distribution |

| UC-ARCH-025 | Security Architecture |
|-------------|----------------------|
| **Actor** | Security Architect |
| **Goal** | Find security patterns, threat model templates |
| **Strategy** | Zero-trust progression, control catalogues |

### 4.4 Standards & Governance

| UC-ARCH-030 | Technical Standards Management |
|-------------|--------------------------------|
| **Actor** | Architect |
| **Goal** | Find standards documentation, lifecycle management |
| **Procedures** | Exception/waiver, enforcement mechanisms |

| UC-ARCH-031 | Coding Standards |
|-------------|------------------|
| **Actor** | Tech Lead |
| **Goal** | Find language-specific guidelines, review criteria |
| **Tools** | Static analysis rules (Credo, Dialyzer) |
| **STAMP** | SC-CREDO-001 to SC-CREDO-005 |

| UC-ARCH-032 | API Standards |
|-------------|---------------|
| **Actor** | Architect |
| **Goal** | Find API design guidelines, versioning policies |
| **Procedures** | Review, approval, deprecation |

| UC-ARCH-033 | Data Standards |
|-------------|----------------|
| **Actor** | Data Architect |
| **Goal** | Find naming conventions, quality standards |
| **Policies** | MDM, classification, handling |

| UC-ARCH-034 | Infrastructure Standards |
|-------------|--------------------------|
| **Actor** | DevOps Lead |
| **Goal** | Find provisioning standards, tagging conventions |
| **STAMP** | SC-CNT-009 (NixOS/Podman only) |

| UC-ARCH-035 | Governance Processes |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find ARB charters, escalation paths |
| **Metrics** | Compliance monitoring, effectiveness |

### 4.5 Technical Debt Management

| UC-ARCH-040 | Debt Identification |
|-------------|---------------------|
| **Actor** | Tech Lead |
| **Goal** | Find debt catalogues, detection mechanisms |
| **Classification** | Taxonomies, ownership attribution |

| UC-ARCH-041 | Debt Assessment |
|-------------|------------------|
| **Actor** | Tech Lead |
| **Goal** | Find impact quantification, prioritisation |
| **Models** | Risk assessment, interest calculation |

| UC-ARCH-042 | Debt Remediation |
|-------------|------------------|
| **Actor** | Tech Lead |
| **Goal** | Find strategy templates, paydown roadmaps |
| **Metrics** | Resource allocation, success criteria |

| UC-ARCH-043 | Debt Prevention |
|-------------|-----------------|
| **Actor** | Architect |
| **Goal** | Find architectural guardrails, design review checkpoints |
| **Classification** | Intentional vs accidental debt |

| UC-ARCH-044 | Debt Communication |
|-------------|---------------------|
| **Actor** | Tech Lead |
| **Goal** | Find visualisation, stakeholder templates |
| **Translation** | Business impact frameworks |

| UC-ARCH-045 | Debt Governance |
|-------------|-----------------|
| **Actor** | Architect |
| **Goal** | Find review cadences, threshold definitions |
| **Policies** | Guidelines, accountability structures |

### 4.6 Cross-Team Technical Coordination

| UC-ARCH-050 | Dependency Management |
|-------------|----------------------|
| **Actor** | Tech Lead |
| **Goal** | Find service dependency maps, interface agreements |
| **Processes** | Change notification, risk assessment |

| UC-ARCH-051 | Shared Component Governance |
|-------------|------------------------------|
| **Actor** | Architect |
| **Goal** | Find ownership models, contribution guidelines |
| **Definitions** | Roadmaps, SLAs, versioning strategies |

| UC-ARCH-052 | Platform Team Coordination |
|-------------|---------------------------|
| **Actor** | Platform Lead |
| **Goal** | Find capability catalogues, adoption processes |
| **Boundaries** | Platform vs product responsibilities |

| UC-ARCH-053 | Cross-Cutting Concern Alignment |
|-------------|----------------------------------|
| **Actor** | Architect |
| **Goal** | Find observability standards, security patterns |
| **Tracking** | Performance standards, ownership |
| **STAMP** | SC-OBS-069, SC-OBS-071 |

| UC-ARCH-054 | Technical Community Facilitation |
|-------------|-----------------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find guild charters, knowledge sharing schedules |
| **Programs** | Collaboration tools, mentorship |

| UC-ARCH-055 | Conflict Resolution |
|-------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find disagreement escalation, arbitration processes |
| **Frameworks** | Consensus-building, decision authority |

### 4.7 Capacity & Scalability Planning

| UC-ARCH-060 | Scalability Assessment |
|-------------|------------------------|
| **Actor** | Architect |
| **Goal** | Find scalability limits, bottleneck analysis |
| **Testing** | Methodologies, improvement roadmaps |

| UC-ARCH-061 | Growth Modelling |
|-------------|------------------|
| **Actor** | Architect |
| **Goal** | Find projection models, capacity calculations |
| **Planning** | Scenario documentation, trigger thresholds |

| UC-ARCH-062 | Architectural Scalability |
|-------------|---------------------------|
| **Actor** | Architect |
| **Goal** | Find horizontal/vertical scaling frameworks |
| **Patterns** | Statelessness, distribution, caching |

| UC-ARCH-063 | Global Distribution |
|-------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find multi-region patterns, data sovereignty |
| **Strategies** | Latency optimisation, consistency models |

| UC-ARCH-064 | Cost-Performance Optimisation |
|-------------|-------------------------------|
| **Actor** | Architect |
| **Goal** | Find trade-off analysis, efficiency benchmarks |
| **Allocation** | Performance budgets, opportunity identification |

| UC-ARCH-065 | Future-Proofing |
|-------------|-----------------|
| **Actor** | Architect |
| **Goal** | Find capacity runway assessments |
| **Strategies** | Flexibility evaluation, optionality planning |

### 4.8 Risk & Resilience Architecture

| UC-ARCH-070 | Risk Identification |
|-------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find architectural risk registers, SPOF analyses |
| **Mapping** | Blast radius, cascading failure modes |

| UC-ARCH-071 | Resilience Patterns |
|-------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find circuit breaker standards, retry policies |
| **Patterns** | Bulkheads, isolation, graceful degradation |
| **STAMP** | SC-BUS-003 (1000 events/sec breaker) |

| UC-ARCH-072 | Failure Domain Design |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find boundary definitions, fault isolation |
| **Testing** | Containment mechanisms, validation strategies |

| UC-ARCH-073 | Disaster Recovery Architecture |
|-------------|--------------------------------|
| **Actor** | Architect |
| **Goal** | Find DR patterns, RTO/RPO mappings |
| **Design** | Failover architecture, testing approaches |
| **STAMP** | SC-EMR-060 (Rollback capability) |

| UC-ARCH-074 | Business Continuity |
|-------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find critical path identification |
| **Definition** | Minimum viable service, degraded mode architecture |

| UC-ARCH-075 | Chaos Engineering Strategy |
|-------------|----------------------------|
| **Actor** | SRE Lead |
| **Goal** | Find programme documentation, experiment frameworks |
| **Models** | Hypothesis libraries, maturity progression |

### 4.9 Security Architecture

| UC-ARCH-080 | Security Strategy |
|-------------|-------------------|
| **Actor** | Security Architect |
| **Goal** | Find principles, roadmaps, investment priorities |
| **Assessment** | Maturity models, security posture |

| UC-ARCH-081 | Threat Modelling |
|-------------|------------------|
| **Actor** | Security Architect |
| **Goal** | Find templates, attack pattern catalogues |
| **Repositories** | Threat models by system, update triggers |

| UC-ARCH-082 | Identity & Access Architecture |
|-------------|--------------------------------|
| **Actor** | Security Architect |
| **Goal** | Find identity patterns, authentication strategy |
| **Design** | Authorisation models, federation architecture |

| UC-ARCH-083 | Data Protection Architecture |
|-------------|------------------------------|
| **Actor** | Security Architect |
| **Goal** | Find encryption standards, key management |
| **Patterns** | Privacy-by-design, DLP architecture |
| **STAMP** | SC-SEC-047 (Encryption) |

| UC-ARCH-084 | Network Security Architecture |
|-------------|-------------------------------|
| **Actor** | Security Architect |
| **Goal** | Find segmentation strategies, zero-trust |
| **Patterns** | Perimeter security, monitoring architecture |

| UC-ARCH-085 | Security Assurance |
|-------------|---------------------|
| **Actor** | Security Architect |
| **Goal** | Find testing strategy, review processes |
| **Metrics** | Measurement, incident response architecture |

### 4.10 Performance Architecture

| UC-ARCH-090 | Performance Strategy |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find SLA architecture, budget allocation |
| **Strategy** | Testing, monitoring architecture |
| **STAMP** | SC-PRF-050 (Response <50ms) |

| UC-ARCH-091 | Latency Architecture |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find budget decomposition, critical path optimisation |
| **Strategies** | Caching, edge computing, CDN architecture |

| UC-ARCH-092 | Throughput Architecture |
|-------------|-------------------------|
| **Actor** | Architect |
| **Goal** | Find capacity modelling, parallel processing |
| **Patterns** | Queueing, load distribution strategies |

| UC-ARCH-093 | Resource Efficiency |
|-------------|---------------------|
| **Actor** | Architect |
| **Goal** | Find optimisation patterns, right-sizing |
| **Targets** | Resource pooling, efficiency metrics |

| UC-ARCH-094 | Performance Observability |
|-------------|---------------------------|
| **Actor** | Architect |
| **Goal** | Find monitoring architecture, distributed tracing |
| **Detection** | Anomaly detection, correlation analysis |

| UC-ARCH-095 | Performance Governance |
|-------------|------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find review processes, regression prevention |
| **Tracking** | Performance debt, improvement prioritisation |

### 4.11 Data & Analytics Architecture

| UC-ARCH-100 | Data Strategy |
|-------------|---------------|
| **Actor** | Data Architect |
| **Goal** | Find enterprise data strategy, principles |
| **Frameworks** | Governance, maturity models |

| UC-ARCH-101 | Data Platform Architecture |
|-------------|----------------------------|
| **Actor** | Data Architect |
| **Goal** | Find lake/warehouse architecture, pipeline patterns |
| **Decisions** | Real-time vs batch, capability roadmaps |

| UC-ARCH-102 | Data Integration |
|-------------|------------------|
| **Actor** | Data Architect |
| **Goal** | Find integration patterns, ETL/ELT decisions |
| **Strategies** | Synchronisation, data API architecture |

| UC-ARCH-103 | Analytics Architecture |
|-------------|------------------------|
| **Actor** | Data Architect |
| **Goal** | Find platform architecture, self-service enablement |
| **Patterns** | Embedded analytics, governance |

| UC-ARCH-104 | ML Architecture |
|-------------|-----------------|
| **Actor** | ML Architect |
| **Goal** | Find ML platform, deployment patterns |
| **Tooling** | MLOps architecture, governance frameworks |

| UC-ARCH-105 | Data Quality Architecture |
|-------------|---------------------------|
| **Actor** | Data Architect |
| **Goal** | Find monitoring architecture, validation patterns |
| **Tracking** | Lineage, quality metrics and SLAs |

### 4.12 Integration Architecture

| UC-ARCH-110 | Integration Strategy |
|-------------|----------------------|
| **Actor** | Integration Architect |
| **Goal** | Find principles, pattern selection criteria |
| **Governance** | Platform capabilities |

| UC-ARCH-111 | API Architecture |
|-------------|------------------|
| **Actor** | API Architect |
| **Goal** | Find gateway architecture, management capabilities |
| **Security** | Versioning, lifecycle architecture |

| UC-ARCH-112 | Event-Driven Architecture |
|-------------|---------------------------|
| **Actor** | Architect |
| **Goal** | Find streaming platform, schema management |
| **Patterns** | Event sourcing, CQRS implementation |

| UC-ARCH-113 | Messaging Architecture |
|-------------|------------------------|
| **Actor** | Architect |
| **Goal** | Find broker architecture, routing patterns |
| **Guarantees** | Reliability, ordering, dead letter handling |

| UC-ARCH-114 | Service Mesh Architecture |
|-------------|---------------------------|
| **Actor** | Architect |
| **Goal** | Find deployment patterns, traffic management |
| **Integration** | Security model, observability |

| UC-ARCH-115 | B2B Integration |
|-------------|-----------------|
| **Actor** | Integration Architect |
| **Goal** | Find partner patterns, protocol support |
| **Architecture** | Onboarding, security and compliance |

### 4.13 Cloud Architecture

| UC-ARCH-120 | Cloud Strategy |
|-------------|----------------|
| **Actor** | Cloud Architect |
| **Goal** | Find adoption strategy, multi-cloud policies |
| **Planning** | Provider selection, exit strategy |

| UC-ARCH-121 | Cloud-Native Architecture |
|-------------|---------------------------|
| **Actor** | Cloud Architect |
| **Goal** | Find design principles, container orchestration |
| **Patterns** | Serverless, cloud-native applications |

| UC-ARCH-122 | Cloud Infrastructure |
|-------------|----------------------|
| **Actor** | Cloud Architect |
| **Goal** | Find infrastructure patterns, network architecture |
| **Design** | Storage, compute selection |

| UC-ARCH-123 | Cloud Security |
|-------------|----------------|
| **Actor** | Cloud Security Architect |
| **Goal** | Find security patterns, IAM in cloud |
| **Architecture** | Data protection, compliance |

| UC-ARCH-124 | Cloud Operations Architecture |
|-------------|-------------------------------|
| **Actor** | Cloud Architect |
| **Goal** | Find monitoring, cost management architecture |
| **Patterns** | Automation, IaC, DR architecture |

| UC-ARCH-125 | Cloud Migration Architecture |
|-------------|------------------------------|
| **Actor** | Cloud Architect |
| **Goal** | Find migration patterns (6Rs), assessment frameworks |
| **Planning** | Wave planning, cutover architecture |

### 4.14 Architecture Review & Quality

| UC-ARCH-130 | Architecture Review Processes |
|-------------|-------------------------------|
| **Actor** | Architect |
| **Goal** | Find ARB procedures, criteria checklists |
| **Tracking** | Submission requirements, outcome tracking |

| UC-ARCH-131 | Architecture Quality Assessment |
|-------------|----------------------------------|
| **Actor** | Architect |
| **Goal** | Find quality attributes, fitness functions |
| **Metrics** | Technical debt measurement, health scorecards |

| UC-ARCH-132 | Design Review |
|-------------|---------------|
| **Actor** | Tech Lead |
| **Goal** | Find templates, participation requirements |
| **Workflows** | Feedback incorporation, approval |

| UC-ARCH-133 | Code Architecture Review |
|-------------|--------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find conformance checking, architectural smells |
| **Monitoring** | Dependency analysis, erosion detection |

| UC-ARCH-134 | Production Readiness Review |
|-------------|------------------------------|
| **Actor** | SRE Lead |
| **Goal** | Find PRR criteria, launch review processes |
| **Capture** | Post-launch validation, lessons learned |

| UC-ARCH-135 | Continuous Architecture Assessment |
|-------------|-------------------------------------|
| **Actor** | Architect |
| **Goal** | Find observability metrics, runtime validation |
| **Tracking** | Drift detection, evolution monitoring |

### 4.15 Architecture Communication

| UC-ARCH-140 | Stakeholder Communication |
|-------------|---------------------------|
| **Actor** | Architect |
| **Goal** | Find presentation templates, abstraction levels |
| **Formats** | Summary formats, executive briefings |

| UC-ARCH-141 | Technical Documentation |
|-------------|-------------------------|
| **Actor** | Architect |
| **Goal** | Find documentation standards, diagram conventions |
| **Processes** | Review, approval, maintenance |

| UC-ARCH-142 | Architecture Visualisation |
|-------------|----------------------------|
| **Actor** | Architect |
| **Goal** | Find diagram types, interactive exploration tools |
| **Targeting** | Model repositories, audience-appropriate views |

| UC-ARCH-143 | Decision Communication |
|-------------|------------------------|
| **Actor** | Architect |
| **Goal** | Find ADR communication templates |
| **Articulation** | Rationale, impact, feedback collection |

| UC-ARCH-144 | Roadmap Communication |
|-------------|----------------------|
| **Actor** | Tech Lead |
| **Goal** | Find visualisation standards, update communication |
| **Alignment** | Dependency communication, stakeholder alignment |

| UC-ARCH-145 | Architecture Evangelism |
|-------------|-------------------------|
| **Actor** | Architect |
| **Goal** | Find principle communication, success stories |
| **Building** | Community engagement, architecture culture |

### 4.16 Vendor & Technology Evaluation

| UC-ARCH-150 | Vendor Assessment |
|-------------|-------------------|
| **Actor** | Architect |
| **Goal** | Find evaluation frameworks, comparison matrices |
| **Processes** | Reference checks, risk assessment |

| UC-ARCH-151 | Technology Evaluation |
|-------------|----------------------|
| **Actor** | Tech Lead |
| **Goal** | Find assessment criteria, POC templates |
| **Frameworks** | Benchmark methodologies, fit analysis |

| UC-ARCH-152 | Build vs Buy Analysis |
|-------------|----------------------|
| **Actor** | Architect |
| **Goal** | Find decision frameworks, TCO models |
| **Assessment** | Strategic differentiation, maintenance burden |

| UC-ARCH-153 | Open Source Evaluation |
|-------------|------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find assessment criteria, community health |
| **Analysis** | License compliance, security assessment |

| UC-ARCH-154 | Vendor Relationship Management |
|-------------|--------------------------------|
| **Actor** | Architect |
| **Goal** | Find escalation procedures, roadmap alignment |
| **Monitoring** | Performance, contract requirements |

| UC-ARCH-155 | Technology Sunset Planning |
|-------------|----------------------------|
| **Actor** | Architect |
| **Goal** | Find deprecation criteria, migration triggers |
| **Planning** | Replacement evaluation, sunset communication |

### 4.17 Team Topology & Organisation Design

| UC-ARCH-160 | Team Structure Alignment |
|-------------|--------------------------|
| **Actor** | Architect |
| **Goal** | Find Conway's Law analysis, cognitive load assessment |
| **Design** | Interaction modes, boundary principles |

| UC-ARCH-161 | Platform Thinking |
|-------------|-------------------|
| **Actor** | Platform Lead |
| **Goal** | Find team charter templates, capability definition |
| **Boundaries** | Adoption metrics, platform vs product |

| UC-ARCH-162 | Enabling Teams |
|-------------|----------------|
| **Actor** | Tech Lead |
| **Goal** | Find engagement models, capability uplift |
| **Criteria** | Success metrics, rotation and focus |

| UC-ARCH-163 | Stream-Aligned Teams |
|-------------|----------------------|
| **Actor** | Tech Lead |
| **Goal** | Find value stream mapping, autonomy boundaries |
| **Definitions** | Dependency minimisation, team APIs |

| UC-ARCH-164 | Architecture & Team Evolution |
|-------------|-------------------------------|
| **Actor** | Architect |
| **Goal** | Find co-evolution patterns, splitting criteria |
| **Models** | Capability roadmaps, team maturity |

| UC-ARCH-165 | Collaboration Patterns |
|-------------|------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find mode selection criteria, X-as-a-Service |
| **Metrics** | Facilitation models, effectiveness |

### 4.18 Innovation & Emerging Technology

| UC-ARCH-170 | Technology Scanning |
|-------------|---------------------|
| **Actor** | Tech Lead |
| **Goal** | Find radar processes, trend analysis |
| **Monitoring** | Academic research, competitor tracking |

| UC-ARCH-171 | Experimentation Governance |
|-------------|----------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find proposal processes, success criteria |
| **Allocation** | Resource allocation, promotion to production |

| UC-ARCH-172 | POC Management |
|-------------|----------------|
| **Actor** | Tech Lead |
| **Goal** | Find planning templates, evaluation criteria |
| **Capture** | Knowledge capture, timeline management |

| UC-ARCH-173 | Innovation Metrics |
|-------------|---------------------|
| **Actor** | Tech Lead |
| **Goal** | Find portfolio balance, experimentation velocity |
| **Indicators** | ROI measurement, culture indicators |

| UC-ARCH-174 | Emerging Technology Adoption |
|-------------|------------------------------|
| **Actor** | Architect |
| **Goal** | Find readiness assessment, pilot design |
| **Planning** | Scaling criteria, risk management |

| UC-ARCH-175 | Technology Partnership |
|-------------|------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find partnership evaluation, co-innovation models |
| **Governance** | Partnership governance, IP considerations |

### 4.19 Compliance & Regulatory Architecture

| UC-ARCH-180 | Compliance Architecture |
|-------------|-------------------------|
| **Actor** | Compliance Architect |
| **Goal** | Find requirement mappings, control architecture |
| **Monitoring** | Compliance monitoring, evidence generation |
| **STAMP** | IEC 61508 SIL-2, ISO 27001, GDPR, EN 50131 |

| UC-ARCH-181 | Privacy Architecture |
|-------------|----------------------|
| **Actor** | Privacy Architect |
| **Goal** | Find privacy-by-design patterns |
| **Implementation** | Data subject rights, consent management |

| UC-ARCH-182 | Industry-Specific Compliance |
|-------------|------------------------------|
| **Actor** | Compliance Architect |
| **Goal** | Find regulation mappings (PCI, HIPAA) |
| **Roadmaps** | Industry patterns, certification requirements |

| UC-ARCH-183 | Audit Architecture |
|-------------|---------------------|
| **Actor** | Compliance Architect |
| **Goal** | Find audit trail patterns, evidence architecture |
| **Monitoring** | Access/reporting, continuous compliance |

| UC-ARCH-184 | Cross-Border Compliance |
|-------------|-------------------------|
| **Actor** | Compliance Architect |
| **Goal** | Find data residency patterns, transfer mechanisms |
| **Harmonisation** | Jurisdiction requirements, global compliance |

| UC-ARCH-185 | Regulatory Change Management |
|-------------|------------------------------|
| **Actor** | Compliance Architect |
| **Goal** | Find change monitoring, impact assessment |
| **Tracking** | Adaptation planning, compliance debt |

### 4.20 Architecture Mentorship & Capability Building

| UC-ARCH-190 | Architecture Skills Development |
|-------------|----------------------------------|
| **Actor** | Architecture Manager |
| **Goal** | Find competency frameworks, learning paths |
| **Guidance** | Certification, career progression |

| UC-ARCH-191 | Mentorship Programmes |
|-------------|----------------------|
| **Actor** | Architecture Manager |
| **Goal** | Find programme design, matching criteria |
| **Governance** | Success metrics, programme governance |

| UC-ARCH-192 | Architecture Community |
|-------------|------------------------|
| **Actor** | Architect |
| **Goal** | Find guild charters, engagement metrics |
| **Formats** | Knowledge sharing, health indicators |

| UC-ARCH-193 | Design Thinking Enablement |
|-------------|----------------------------|
| **Actor** | Tech Lead |
| **Goal** | Find workshop materials, architectural katas |
| **Programs** | Dojo programmes, hands-on learning |

| UC-ARCH-194 | Architecture Onboarding |
|-------------|-------------------------|
| **Actor** | Architecture Manager |
| **Goal** | Find onboarding materials, context transfer |
| **Development** | Relationship building, influence development |

| UC-ARCH-195 | Succession Planning |
|-------------|---------------------|
| **Actor** | Architecture Manager |
| **Goal** | Find knowledge documentation, critical knowledge ID |
| **Planning** | Transfer planning, continuity planning |

---

## 5. PRODUCT & BUSINESS STAKEHOLDER USE CASES

### 5.1 Product Management

| UC-BIZ-001 | Feature Delivery Dashboard |
|------------|---------------------------|
| **Actor** | Product Manager |
| **Goal** | Monitor feature development progress across fractal levels |
| **Visualizations** | Sprint burndown, feature completion %, velocity trends |
| **Value** | Real-time visibility into development pipeline health |

| UC-BIZ-002 | Product Roadmap Alignment |
|------------|---------------------------|
| **Actor** | Product Manager |
| **Goal** | Track roadmap items mapped to system components |
| **Metrics** | Planned vs delivered, dependency status, risk indicators |
| **Integration** | Links to JIRA/Linear/GitHub issues |

| UC-BIZ-003 | User Story Coverage |
|------------|---------------------|
| **Actor** | Product Owner |
| **Goal** | View test coverage mapped to user stories |
| **Coverage** | Acceptance criteria → test mapping visualization |
| **STAMP** | SC-TEST-001 compliance tracking |

| UC-BIZ-004 | Release Readiness Assessment |
|------------|---------------------------|
| **Actor** | Product Manager |
| **Goal** | Evaluate system readiness for release |
| **Gates** | Quality gates, test pass rates, performance benchmarks |
| **Dashboard** | Go/No-Go decision support panel |

| UC-BIZ-005 | Feature Flag Management |
|------------|------------------------|
| **Actor** | Product Manager |
| **Goal** | Monitor feature flag states and rollout percentages |
| **Visualization** | Flag status grid, rollout progress bars |
| **Safety** | Rollback capability indicators |

| UC-BIZ-006 | Customer Impact Analysis |
|------------|-------------------------|
| **Actor** | Product Manager |
| **Goal** | Assess how system changes affect customer segments |
| **Metrics** | Impact radius, affected users, risk score |
| **Integration** | Customer feedback correlation |

### 5.2 Business Analysis

| UC-BIZ-010 | Business Requirements Traceability |
|------------|-----------------------------------|
| **Actor** | Business Analyst |
| **Goal** | Trace business requirements to implementation |
| **Visualization** | Requirements → Code → Tests matrix |
| **Coverage** | Requirement fulfillment percentage |

| UC-BIZ-011 | Process Flow Monitoring |
|------------|------------------------|
| **Actor** | Business Analyst |
| **Goal** | Monitor business process execution in real-time |
| **Flows** | OODA cycles, approval workflows, escalation paths |
| **Metrics** | Process completion times, bottleneck identification |

| UC-BIZ-012 | Data Quality Dashboard |
|------------|----------------------|
| **Actor** | Business Analyst |
| **Goal** | Monitor data quality metrics across domains |
| **Metrics** | Completeness, accuracy, timeliness, consistency |
| **Domains** | 10 domain data quality scores |

| UC-BIZ-013 | Business Rule Validation |
|------------|-------------------------|
| **Actor** | Business Analyst |
| **Goal** | Verify business rules are correctly implemented |
| **Validation** | Rule engine outputs, constraint satisfaction |
| **STAMP** | SC-VAL-003 consensus verification |

| UC-BIZ-014 | Integration Point Health |
|------------|-------------------------|
| **Actor** | Business Analyst |
| **Goal** | Monitor external system integration status |
| **Integrations** | API health, data sync status, error rates |
| **Visualization** | Integration topology map with health indicators |

| UC-BIZ-015 | Business KPI Tracker |
|------------|---------------------|
| **Actor** | Business Analyst |
| **Goal** | Track key business performance indicators |
| **KPIs** | Transaction volumes, response times, error rates |
| **Trends** | Historical comparison, forecasting |

### 5.3 Project Management

| UC-BIZ-020 | Sprint Progress Overview |
|------------|-------------------------|
| **Actor** | Project Manager |
| **Goal** | Monitor sprint progress across all teams |
| **Metrics** | Story points completed, blockers, velocity |
| **Visualization** | Burndown charts, team capacity utilization |

| UC-BIZ-021 | Resource Allocation View |
|------------|-------------------------|
| **Actor** | Project Manager |
| **Goal** | View agent/resource allocation across projects |
| **Resources** | 50 agents, container resources, compute utilization |
| **Balance** | Workload distribution visualization |

| UC-BIZ-022 | Dependency Tracking |
|------------|---------------------|
| **Actor** | Project Manager |
| **Goal** | Monitor inter-team and system dependencies |
| **Dependencies** | Blocking items, critical path, risk items |
| **Visualization** | Dependency graph with status colors |

| UC-BIZ-023 | Milestone Tracking |
|------------|-------------------|
| **Actor** | Project Manager |
| **Goal** | Track project milestones and deliverables |
| **Milestones** | Phase gates, delivery dates, completion status |
| **Alerts** | At-risk milestone warnings |

| UC-BIZ-024 | Team Velocity Analysis |
|------------|----------------------|
| **Actor** | Project Manager |
| **Goal** | Analyze team performance trends |
| **Metrics** | Velocity trends, estimation accuracy, cycle time |
| **Comparison** | Cross-team benchmarking |

| UC-BIZ-025 | Risk Register Dashboard |
|------------|------------------------|
| **Actor** | Project Manager |
| **Goal** | Monitor project risks and mitigations |
| **Risks** | Probability × Impact matrix, mitigation status |
| **STAMP** | Risk-to-constraint mapping |

### 5.4 Executive Leadership

| UC-BIZ-030 | Executive Summary Dashboard |
|------------|---------------------------|
| **Actor** | CTO / CIO |
| **Goal** | High-level system health and business metrics |
| **Metrics** | Uptime, performance, security posture, compliance |
| **Dark Cockpit** | Exception-based alerting only |

| UC-BIZ-031 | Strategic Initiative Tracking |
|------------|------------------------------|
| **Actor** | Executive |
| **Goal** | Monitor progress on strategic technology initiatives |
| **Initiatives** | Fractal architecture adoption, safety compliance |
| **ROI** | Investment vs value delivered tracking |

| UC-BIZ-032 | Technology Debt Overview |
|------------|-------------------------|
| **Actor** | CTO |
| **Goal** | Visualize technical debt across the system |
| **Debt** | Code quality, outdated dependencies, architectural debt |
| **Trends** | Debt accumulation/reduction over time |

| UC-BIZ-033 | Compliance Posture Summary |
|------------|---------------------------|
| **Actor** | Executive |
| **Goal** | High-level compliance status for regulations |
| **Standards** | IEC 61508, ISO 27001, GDPR, EN 50131 |
| **Status** | Compliance percentage per standard |

| UC-BIZ-034 | Incident Executive Summary |
|------------|---------------------------|
| **Actor** | Executive |
| **Goal** | Summary of critical incidents and resolutions |
| **Metrics** | MTTR, incident count, severity distribution |
| **Trends** | Incident frequency trends |

| UC-BIZ-035 | Cost Attribution Dashboard |
|------------|--------------------------|
| **Actor** | Executive |
| **Goal** | View infrastructure costs by component |
| **Costs** | Container resources, API usage, storage |
| **Optimization** | Cost optimization recommendations |

### 5.5 Finance & Budget

| UC-BIZ-040 | Infrastructure Cost Tracking |
|------------|----------------------------|
| **Actor** | Finance Manager |
| **Goal** | Track infrastructure costs in real-time |
| **Costs** | Compute, storage, network, API calls |
| **Budgets** | Budget vs actual spending |

| UC-BIZ-041 | Resource Utilization Efficiency |
|------------|-------------------------------|
| **Actor** | Finance Manager |
| **Goal** | Monitor resource utilization efficiency |
| **Metrics** | CPU/Memory utilization vs cost |
| **Optimization** | Waste identification, right-sizing recommendations |

| UC-BIZ-042 | Project Budget Tracking |
|------------|------------------------|
| **Actor** | Finance Manager |
| **Goal** | Track project spending against budgets |
| **Budget** | Allocated vs consumed, forecast to completion |
| **Alerts** | Budget overrun warnings |

| UC-BIZ-043 | License Compliance |
|------------|-------------------|
| **Actor** | Finance Manager |
| **Goal** | Monitor software license usage and compliance |
| **Licenses** | Active licenses, utilization, expiration dates |
| **Compliance** | License audit readiness |

| UC-BIZ-044 | API Cost Attribution |
|------------|---------------------|
| **Actor** | Finance Manager |
| **Goal** | Track API usage costs by department/project |
| **APIs** | Claude API, external integrations |
| **STAMP** | SC-API-001 rate limit cost correlation |

| UC-BIZ-045 | FinOps Dashboard |
|------------|-----------------|
| **Actor** | Finance Manager |
| **Goal** | Cloud financial operations overview |
| **Metrics** | Unit economics, cost per transaction |
| **Trends** | Cost efficiency improvement tracking |

### 5.6 Customer Success

| UC-BIZ-050 | Customer Health Score |
|------------|---------------------|
| **Actor** | Customer Success Manager |
| **Goal** | Monitor customer health indicators |
| **Metrics** | Usage patterns, engagement, support tickets |
| **Risk** | Churn risk indicators |

| UC-BIZ-051 | Feature Adoption Tracking |
|------------|-------------------------|
| **Actor** | Customer Success Manager |
| **Goal** | Track feature adoption across customer base |
| **Adoption** | Feature usage %, adoption curves |
| **Segments** | Customer segment analysis |

| UC-BIZ-052 | SLA Compliance Monitor |
|------------|----------------------|
| **Actor** | Customer Success Manager |
| **Goal** | Monitor SLA compliance per customer |
| **SLAs** | Uptime, response time, resolution time |
| **Alerts** | SLA breach warnings |

| UC-BIZ-053 | Support Ticket Analytics |
|------------|------------------------|
| **Actor** | Customer Success Manager |
| **Goal** | Analyze support ticket patterns |
| **Metrics** | Ticket volume, categories, resolution times |
| **Trends** | Issue pattern identification |

| UC-BIZ-054 | Customer Feedback Integration |
|------------|------------------------------|
| **Actor** | Customer Success Manager |
| **Goal** | Correlate customer feedback with system metrics |
| **Feedback** | NPS, CSAT, feature requests |
| **Correlation** | System health vs customer satisfaction |

| UC-BIZ-055 | Onboarding Progress |
|------------|---------------------|
| **Actor** | Customer Success Manager |
| **Goal** | Track customer onboarding progress |
| **Stages** | Setup, training, go-live milestones |
| **Health** | Onboarding health indicators |

### 5.7 Sales & Pre-Sales

| UC-BIZ-060 | Demo Environment Status |
|------------|------------------------|
| **Actor** | Sales Engineer |
| **Goal** | Monitor demo environment availability |
| **Status** | Container health, data freshness, feature availability |
| **Readiness** | Demo readiness indicators |

| UC-BIZ-061 | Proof of Concept Tracking |
|------------|-------------------------|
| **Actor** | Sales Engineer |
| **Goal** | Track POC deployments and metrics |
| **POCs** | Active POCs, success criteria, timeline |
| **Metrics** | POC performance vs benchmarks |

| UC-BIZ-062 | Competitive Differentiation |
|------------|---------------------------|
| **Actor** | Pre-Sales |
| **Goal** | Visualize unique system capabilities |
| **Capabilities** | 50-agent mesh, fractal logging, STAMP safety |
| **Comparison** | Benchmark vs industry standards |

| UC-BIZ-063 | Security Posture for Sales |
|------------|--------------------------|
| **Actor** | Sales Engineer |
| **Goal** | Present security capabilities to prospects |
| **Security** | Compliance certifications, security metrics |
| **STAMP** | Safety constraint compliance visualization |

| UC-BIZ-064 | Scalability Demonstration |
|------------|-------------------------|
| **Actor** | Sales Engineer |
| **Goal** | Demonstrate system scalability metrics |
| **Metrics** | Throughput, latency under load, resource efficiency |
| **Visualization** | Live performance dashboards |

| UC-BIZ-065 | Integration Capability Showcase |
|------------|------------------------------|
| **Actor** | Sales Engineer |
| **Goal** | Demonstrate integration capabilities |
| **Integrations** | API catalog, webhook support, data formats |
| **Visualization** | Integration architecture diagrams |

### 5.8 Marketing

| UC-BIZ-070 | System Capability Infographics |
|------------|-------------------------------|
| **Actor** | Marketing Manager |
| **Goal** | Generate visual assets from system metrics |
| **Exports** | SVG/PNG dashboards, performance charts |
| **Content** | Marketing collateral generation |

| UC-BIZ-071 | Case Study Metrics |
|------------|-------------------|
| **Actor** | Marketing Manager |
| **Goal** | Extract metrics for customer case studies |
| **Metrics** | Performance improvements, ROI data |
| **Export** | Formatted metric reports |

| UC-BIZ-072 | Thought Leadership Content |
|------------|--------------------------|
| **Actor** | Marketing Manager |
| **Goal** | Generate content around technical innovations |
| **Content** | Fractal architecture, STAMP safety, OODA |
| **Format** | Blog-ready technical summaries |

| UC-BIZ-073 | Competitive Intelligence |
|------------|------------------------|
| **Actor** | Marketing Manager |
| **Goal** | Compare system metrics to industry benchmarks |
| **Benchmarks** | Performance, safety, compliance scores |
| **Visualization** | Competitive comparison charts |

| UC-BIZ-074 | Product Update Communications |
|------------|----------------------------|
| **Actor** | Marketing Manager |
| **Goal** | Generate release notes and update communications |
| **Content** | Feature releases, improvements, fixes |
| **Format** | Customer-facing release summaries |

### 5.9 Compliance, Legal & Risk

| UC-BIZ-080 | Regulatory Compliance Dashboard |
|------------|-------------------------------|
| **Actor** | Compliance Officer |
| **Goal** | Monitor compliance across all regulations |
| **Standards** | IEC 61508, ISO 27001, GDPR, EN 50131 |
| **Status** | Per-standard compliance percentage |

| UC-BIZ-081 | Audit Trail Viewer |
|------------|-------------------|
| **Actor** | Compliance Officer |
| **Goal** | View comprehensive audit trails |
| **Trails** | User actions, system changes, access logs |
| **Retention** | Audit log retention status |

| UC-BIZ-082 | Data Privacy Monitor |
|------------|---------------------|
| **Actor** | DPO / Legal |
| **Goal** | Monitor data privacy compliance |
| **Privacy** | PII handling, consent management, data retention |
| **GDPR** | GDPR Article compliance tracking |

| UC-BIZ-083 | Security Incident Report |
|------------|------------------------|
| **Actor** | Compliance Officer |
| **Goal** | Generate security incident reports |
| **Reports** | Incident timeline, impact assessment, remediation |
| **Compliance** | Regulatory notification requirements |

| UC-BIZ-084 | Risk Assessment Dashboard |
|------------|-------------------------|
| **Actor** | Risk Manager |
| **Goal** | Visualize enterprise risk posture |
| **Risks** | Operational, technical, compliance, security |
| **STAMP** | Risk-to-constraint mapping |

| UC-BIZ-085 | Contract Compliance Monitor |
|------------|---------------------------|
| **Actor** | Legal |
| **Goal** | Monitor SLA and contract compliance |
| **Contracts** | SLA terms, performance commitments |
| **Alerts** | Contract violation warnings |

| UC-BIZ-086 | Evidence Collection for Audits |
|------------|------------------------------|
| **Actor** | Compliance Officer |
| **Goal** | Collect evidence for compliance audits |
| **Evidence** | Logs, configurations, test results |
| **Export** | Audit-ready evidence packages |

### 5.10 QA Leadership

| UC-BIZ-090 | Test Strategy Dashboard |
|------------|------------------------|
| **Actor** | QA Manager |
| **Goal** | Overview of test strategy execution |
| **Coverage** | Unit, integration, E2E, property-based tests |
| **TDG** | Test-Driven Generation compliance |

| UC-BIZ-091 | Quality Gate Status |
|------------|---------------------|
| **Actor** | QA Manager |
| **Goal** | Monitor quality gate passage rates |
| **Gates** | Compile, test, format, credo, sobelow, coverage |
| **STAMP** | SC-VAL quality gate compliance |

| UC-BIZ-092 | Defect Density Analysis |
|------------|------------------------|
| **Actor** | QA Manager |
| **Goal** | Analyze defect density by component |
| **Metrics** | Defects per KLOC, defect trends |
| **FMEA** | Severity classification |

| UC-BIZ-093 | Test Automation Coverage |
|------------|-------------------------|
| **Actor** | QA Manager |
| **Goal** | Track test automation progress |
| **Coverage** | Automated vs manual test ratio |
| **Target** | >95% automation target tracking |

| UC-BIZ-094 | Performance Test Results |
|------------|------------------------|
| **Actor** | QA Manager |
| **Goal** | View performance test results and trends |
| **Metrics** | Response times, throughput, resource usage |
| **Benchmarks** | Performance vs SLA targets |

| UC-BIZ-095 | Test Environment Health |
|------------|------------------------|
| **Actor** | QA Manager |
| **Goal** | Monitor test environment availability |
| **Environments** | Dev, test, staging container health |
| **Data** | Test data freshness and validity |

### 5.11 Operations & Service Management

| UC-BIZ-100 | Service Health Overview |
|------------|------------------------|
| **Actor** | Service Manager |
| **Goal** | Unified view of all service health |
| **Services** | Phoenix app, agents, containers, integrations |
| **Dark Cockpit** | Exception-based alerting |

| UC-BIZ-101 | Incident Management Dashboard |
|------------|----------------------------|
| **Actor** | Service Manager |
| **Goal** | Manage incidents end-to-end |
| **Workflow** | Detection, triage, resolution, post-mortem |
| **Metrics** | MTTD, MTTR, incident count |

| UC-BIZ-102 | Change Management View |
|------------|----------------------|
| **Actor** | Service Manager |
| **Goal** | Track changes and their impact |
| **Changes** | Deployments, configurations, rollbacks |
| **Risk** | Change risk assessment |

| UC-BIZ-103 | Problem Management |
|------------|-------------------|
| **Actor** | Service Manager |
| **Goal** | Track root cause analysis and problem resolution |
| **RCA** | 5-Level RCA integration |
| **Trends** | Recurring problem identification |

| UC-BIZ-104 | Service Level Monitoring |
|------------|------------------------|
| **Actor** | Service Manager |
| **Goal** | Monitor SLIs, SLOs, and SLAs |
| **Metrics** | Error budgets, availability, latency |
| **Alerts** | SLO breach warnings |

| UC-BIZ-105 | Capacity Planning View |
|------------|----------------------|
| **Actor** | Service Manager |
| **Goal** | Plan capacity based on growth trends |
| **Capacity** | Resource utilization forecasts |
| **Recommendations** | Scaling recommendations |

### 5.12 HR & Talent Management

| UC-BIZ-110 | Team Skill Matrix |
|------------|------------------|
| **Actor** | HR Manager / Team Lead |
| **Goal** | View team skills mapped to system domains |
| **Skills** | Domain expertise, technology proficiency |
| **Gaps** | Skill gap identification |

| UC-BIZ-111 | Onboarding Progress Tracker |
|------------|---------------------------|
| **Actor** | HR Manager |
| **Goal** | Track new team member onboarding |
| **Progress** | Training completion, system access, mentorship |
| **Timeline** | Onboarding milestone tracking |

| UC-BIZ-112 | Knowledge Transfer Status |
|------------|-------------------------|
| **Actor** | HR Manager |
| **Goal** | Monitor knowledge transfer for transitions |
| **Transfer** | Documentation status, shadowing progress |
| **Succession** | Critical knowledge preservation |

| UC-BIZ-113 | Team Workload Balance |
|------------|----------------------|
| **Actor** | HR Manager |
| **Goal** | Monitor team workload distribution |
| **Balance** | Task distribution, overtime indicators |
| **Health** | Team burnout risk indicators |

| UC-BIZ-114 | Training Needs Analysis |
|------------|----------------------|
| **Actor** | HR Manager |
| **Goal** | Identify training needs from system usage |
| **Analysis** | Error patterns, support requests, skill gaps |
| **Recommendations** | Training program suggestions |

### 5.13 Vendor & Procurement Management

| UC-BIZ-120 | Vendor Integration Health |
|------------|-------------------------|
| **Actor** | Procurement Manager |
| **Goal** | Monitor third-party integration health |
| **Vendors** | API availability, performance, SLA compliance |
| **Alerts** | Vendor service degradation warnings |

| UC-BIZ-121 | Contract Performance Tracking |
|------------|----------------------------|
| **Actor** | Procurement Manager |
| **Goal** | Track vendor contract performance |
| **Metrics** | SLA achievement, service quality |
| **Review** | Contract renewal decision support |

| UC-BIZ-122 | Dependency Risk Assessment |
|------------|--------------------------|
| **Actor** | Procurement Manager |
| **Goal** | Assess vendor dependency risks |
| **Dependencies** | Critical vendor identification |
| **Mitigation** | Alternative vendor readiness |

| UC-BIZ-123 | Cost Optimization Analysis |
|------------|-------------------------|
| **Actor** | Procurement Manager |
| **Goal** | Analyze vendor costs and optimization opportunities |
| **Costs** | Usage-based billing analysis |
| **Recommendations** | Cost optimization suggestions |

| UC-BIZ-124 | License Utilization |
|------------|---------------------|
| **Actor** | Procurement Manager |
| **Goal** | Track software license utilization |
| **Licenses** | Active vs purchased, usage patterns |
| **Optimization** | License consolidation opportunities |

### 5.14 External Stakeholder Communication

| UC-BIZ-130 | Public Status Page Data |
|------------|------------------------|
| **Actor** | Communications Manager |
| **Goal** | Provide data for public status pages |
| **Status** | Service availability, incident updates |
| **Export** | Status page API integration |

| UC-BIZ-131 | Partner Integration Dashboard |
|------------|----------------------------|
| **Actor** | Partner Manager |
| **Goal** | Monitor partner system integrations |
| **Partners** | Connection health, data sync status |
| **SLAs** | Partner SLA compliance |

| UC-BIZ-132 | Regulatory Report Generation |
|------------|---------------------------|
| **Actor** | Regulatory Affairs |
| **Goal** | Generate reports for regulatory bodies |
| **Reports** | Compliance evidence, audit trails |
| **Format** | Regulator-specific formats |

| UC-BIZ-133 | Investor Technical Briefing |
|------------|---------------------------|
| **Actor** | Investor Relations |
| **Goal** | Provide technical metrics for investor updates |
| **Metrics** | System growth, reliability, innovation |
| **Visualization** | Executive summary dashboards |

| UC-BIZ-134 | Board Technical Summary |
|------------|------------------------|
| **Actor** | Executive Assistant |
| **Goal** | Generate board-level technical summaries |
| **Summary** | Risk posture, strategic progress, key metrics |
| **Format** | Board presentation format |

### 5.15 Business Continuity & Disaster Recovery

| UC-BIZ-140 | DR Readiness Dashboard |
|------------|----------------------|
| **Actor** | BC/DR Manager |
| **Goal** | Monitor disaster recovery readiness |
| **Readiness** | Backup status, replication lag, failover capability |
| **RTO/RPO** | Recovery objective tracking |

| UC-BIZ-141 | Business Impact Analysis |
|------------|------------------------|
| **Actor** | BC/DR Manager |
| **Goal** | Visualize business impact of system components |
| **Impact** | Component criticality, dependency mapping |
| **Priority** | Recovery priority matrix |

| UC-BIZ-142 | Failover Test Results |
|------------|---------------------|
| **Actor** | BC/DR Manager |
| **Goal** | View disaster recovery test results |
| **Tests** | Last test date, success rate, issues found |
| **Compliance** | DR test compliance |

| UC-BIZ-143 | Data Backup Status |
|------------|-------------------|
| **Actor** | BC/DR Manager |
| **Goal** | Monitor backup completeness and health |
| **Backups** | Last backup, size, verification status |
| **Alerts** | Backup failure warnings |

| UC-BIZ-144 | Recovery Runbook Access |
|------------|----------------------|
| **Actor** | BC/DR Manager |
| **Goal** | Quick access to recovery procedures |
| **Runbooks** | Component-specific recovery guides |
| **Integration** | Direct links to operational runbooks |

### 5.16 Strategic Programme Management

| UC-BIZ-150 | Programme Portfolio View |
|------------|------------------------|
| **Actor** | Programme Manager |
| **Goal** | Overview of all strategic programmes |
| **Programmes** | Status, progress, health indicators |
| **Dependencies** | Cross-programme dependencies |

| UC-BIZ-151 | Strategic Alignment Tracker |
|------------|---------------------------|
| **Actor** | Programme Manager |
| **Goal** | Track initiative alignment to strategy |
| **Alignment** | Strategic goal mapping |
| **Progress** | Goal achievement metrics |

| UC-BIZ-152 | Benefits Realization |
|------------|---------------------|
| **Actor** | Programme Manager |
| **Goal** | Track programme benefits realization |
| **Benefits** | Expected vs realized benefits |
| **ROI** | Return on investment tracking |

| UC-BIZ-153 | Cross-Team Coordination |
|------------|----------------------|
| **Actor** | Programme Manager |
| **Goal** | Monitor cross-team deliverables |
| **Deliverables** | Team dependencies, integration points |
| **Risks** | Coordination risk indicators |

| UC-BIZ-154 | Strategic Risk Register |
|------------|----------------------|
| **Actor** | Programme Manager |
| **Goal** | Monitor strategic-level risks |
| **Risks** | Programme risks, mitigation status |
| **Impact** | Business impact assessment |

### 5.17 Data & Analytics Business Users

| UC-BIZ-160 | Data Pipeline Health |
|------------|---------------------|
| **Actor** | Data Analyst |
| **Goal** | Monitor data pipeline execution status |
| **Pipelines** | ETL status, data freshness, quality scores |
| **Alerts** | Pipeline failure notifications |

| UC-BIZ-161 | Report Generation Status |
|------------|------------------------|
| **Actor** | Data Analyst |
| **Goal** | Track report generation and delivery |
| **Reports** | Scheduled reports, completion status |
| **Distribution** | Report delivery confirmation |

| UC-BIZ-162 | Data Quality Scorecard |
|------------|----------------------|
| **Actor** | Data Analyst |
| **Goal** | View data quality metrics across domains |
| **Quality** | Completeness, accuracy, consistency |
| **Domains** | Per-domain quality scores |

| UC-BIZ-163 | Analytics Platform Health |
|------------|------------------------|
| **Actor** | Data Analyst |
| **Goal** | Monitor analytics infrastructure status |
| **Platform** | Query performance, resource utilization |
| **Availability** | Analytics service uptime |

| UC-BIZ-164 | Self-Service Analytics Status |
|------------|---------------------------|
| **Actor** | Business User |
| **Goal** | Check self-service analytics availability |
| **Services** | Dashboard access, data refresh status |
| **Performance** | Query response times |

### 5.18 Innovation & Digital Transformation

| UC-BIZ-170 | Innovation Pipeline Dashboard |
|------------|----------------------------|
| **Actor** | Innovation Manager |
| **Goal** | Track innovation initiatives progress |
| **Pipeline** | Ideas, POCs, pilots, production |
| **Metrics** | Time-to-value, success rates |

| UC-BIZ-171 | Technology Radar View |
|------------|---------------------|
| **Actor** | Innovation Manager |
| **Goal** | Visualize technology adoption status |
| **Radar** | Adopt, trial, assess, hold categories |
| **Trends** | Technology trend indicators |

| UC-BIZ-172 | Experimentation Platform |
|------------|------------------------|
| **Actor** | Innovation Manager |
| **Goal** | Monitor A/B tests and experiments |
| **Experiments** | Active tests, results, statistical significance |
| **Decisions** | Experiment-driven decisions |

| UC-BIZ-173 | Digital Maturity Assessment |
|------------|--------------------------|
| **Actor** | Digital Transformation Lead |
| **Goal** | Track digital maturity progress |
| **Maturity** | Domain maturity scores |
| **Roadmap** | Maturity improvement roadmap |

| UC-BIZ-174 | AI/ML Model Performance |
|------------|------------------------|
| **Actor** | Innovation Manager |
| **Goal** | Monitor AI/ML model performance |
| **Models** | Model accuracy, drift detection |
| **Training** | Training pipeline status |

### 5.19 Facilities & Physical Operations

| UC-BIZ-180 | Data Center Integration |
|------------|----------------------|
| **Actor** | Facilities Manager |
| **Goal** | Monitor physical infrastructure metrics |
| **Metrics** | Power, cooling, rack utilization |
| **Integration** | DCIM system integration |

| UC-BIZ-181 | Environmental Monitoring |
|------------|------------------------|
| **Actor** | Facilities Manager |
| **Goal** | Track environmental conditions |
| **Conditions** | Temperature, humidity, power quality |
| **Alerts** | Environmental threshold alerts |

| UC-BIZ-182 | Physical Security Correlation |
|------------|---------------------------|
| **Actor** | Facilities Manager |
| **Goal** | Correlate physical and cyber security |
| **Correlation** | Access events, security incidents |
| **Integration** | Physical access system integration |

| UC-BIZ-183 | Infrastructure Maintenance Schedule |
|------------|----------------------------------|
| **Actor** | Facilities Manager |
| **Goal** | View infrastructure maintenance windows |
| **Schedule** | Planned maintenance, impact assessment |
| **Coordination** | System-infrastructure coordination |

### 5.20 Cross-Functional Collaboration

| UC-BIZ-190 | Stakeholder Communication Hub |
|------------|----------------------------|
| **Actor** | All Stakeholders |
| **Goal** | Centralized communication dashboard |
| **Communications** | Announcements, alerts, updates |
| **Channels** | Role-based information distribution |

| UC-BIZ-191 | Decision Support Dashboard |
|------------|-------------------------|
| **Actor** | Decision Makers |
| **Goal** | Data-driven decision support |
| **Data** | Key metrics, trends, recommendations |
| **Visualization** | Executive decision dashboards |

| UC-BIZ-192 | Cross-Functional Meeting Support |
|------------|-------------------------------|
| **Actor** | Meeting Facilitator |
| **Goal** | Real-time data for cross-functional meetings |
| **Data** | Relevant metrics, status updates |
| **Export** | Meeting-ready reports |

| UC-BIZ-193 | Handoff Documentation |
|------------|---------------------|
| **Actor** | Team Member |
| **Goal** | Generate handoff documentation between teams |
| **Documentation** | Status, blockers, next steps |
| **Context** | Relevant system state capture |

| UC-BIZ-194 | Escalation Path Visualization |
|------------|----------------------------|
| **Actor** | All Stakeholders |
| **Goal** | Understand escalation paths and contacts |
| **Paths** | Issue-specific escalation routes |
| **Contacts** | Current on-call information |

| UC-BIZ-195 | Knowledge Base Integration |
|------------|-------------------------|
| **Actor** | All Stakeholders |
| **Goal** | Access relevant knowledge from cockpit |
| **Knowledge** | Runbooks, FAQs, documentation |
| **Context** | Context-aware knowledge suggestions |

---

## 6. INDRAJAAL SYSTEM COMPONENT USE CASES

### 6.1 Agent Mesh (50 Agents)

| UC-SYS-001 | Executive Agent Oversight |
|------------|---------------------------|
| **Component** | Executive Agent (1) |
| **Goal** | Display supreme authority status and active directives |
| **STAMP** | AOR-EXE-001 |
| **Metrics** | Active agents, delegated tasks, override count |

| UC-SYS-002 | Domain Agent Grid |
|------------|---------------------|
| **Component** | Domain Agents (10) |
| **Goal** | 10-column grid showing Access, Accounts, Alarms, etc. |
| **Domains** | Access, Accounts, Alarms, Analytics, Authentication, Authorization, Compliance, Devices, Observability, Sites |

| UC-SYS-003 | Functional Agent Status |
|------------|-------------------------|
| **Component** | Functional Agents (15) |
| **Goal** | Monitor functional agent health and task queues |
| **Types** | OODA, Cortex, Sentinel, ACE, Fractal agents |

| UC-SYS-004 | Worker Agent Pool |
|------------|---------------------|
| **Component** | Worker Agents (24) |
| **Goal** | Visualize worker pool utilization and task distribution |
| **Metrics** | Active workers, queue depth, completion rate |

### 6.2 OODA Loop Visualization

| UC-SYS-010 | OODA Cycle Dashboard |
|------------|----------------------|
| **Component** | OodaAgent |
| **Goal** | Visualize Observe → Orient → Decide → Act cycle |
| **Constraint** | < 100ms cycle time (SC-OODA-001) |
| **Metrics** | Observation queue, orientation latency, decision count |

| UC-SYS-011 | Hysteresis Monitor |
|------------|---------------------|
| **Component** | OODA Controller |
| **Goal** | Display decision oscillation prevention status |
| **STAMP** | SC-OODA-005 (10% margin, 3-cycle hold) |

| UC-SYS-012 | AI Orientation Status |
|------------|----------------------|
| **Component** | AI Orientation Module |
| **Goal** | Show AI orientation with 20ms timeout status |
| **STAMP** | SC-OODA-006 (fallback to local heuristics) |

### 6.3 Control Bus Operations

| UC-SYS-020 | Unified Control Bus Status |
|------------|---------------------------|
| **Component** | UnifiedControlBus |
| **Goal** | Monitor async message flow and backpressure |
| **STAMP** | SC-BUS-001 (async only), SC-BUS-003 (1000 events/sec breaker) |

| UC-SYS-021 | Event Ordering Verification |
|------------|----------------------------|
| **Component** | Control Bus |
| **Goal** | Verify event ordering preservation |
| **STAMP** | SC-BUS-004 |

| UC-SYS-022 | Circuit Breaker Dashboard |
|------------|--------------------------|
| **Component** | CircuitBreaker |
| **Goal** | Display circuit breaker states (closed/open/half-open) |
| **Threshold** | 1000 events/sec triggers break |

### 6.4 GDE (Goal-Directed Evolution)

| UC-SYS-030 | Guardian Validation Status |
|------------|---------------------------|
| **Component** | GDE Guardian |
| **Goal** | Show code proposal validation status |
| **STAMP** | SC-GDE-001 |
| **Metrics** | Proposals submitted, validated, rejected |

| UC-SYS-031 | Shadow Testing Dashboard |
|------------|--------------------------|
| **Component** | ShadowMode |
| **Goal** | Monitor shadow testing of proposed changes |
| **STAMP** | SC-GDE-002 |

| UC-SYS-032 | Rollback Capability Status |
|------------|----------------------------|
| **Component** | GDE Rollback |
| **Goal** | Display rollback readiness and history |
| **STAMP** | SC-GDE-003 |

| UC-SYS-033 | Proposal Threshold Tracker |
|------------|----------------------------|
| **Component** | GDE Controller |
| **Goal** | Show proposals meeting >=0.85 threshold |
| **STAMP** | SC-GDE-004 |

### 6.5 Sensor Network

| UC-SYS-040 | Container Health Sensor |
|------------|-------------------------|
| **Component** | ContainerHealthSensor |
| **Goal** | Real-time container health metrics |
| **STAMP** | SC-SENS-001 (non-blocking polling) |

| UC-SYS-041 | Graceful Degradation Display |
|------------|------------------------------|
| **Component** | Sensor Network |
| **Goal** | Show degraded sensors and fallback status |
| **STAMP** | SC-SENS-002 |

| UC-SYS-042 | Observation Buffer Status |
|------------|---------------------------|
| **Component** | Sensor Buffer |
| **Goal** | Display buffer utilization and overflow warnings |
| **STAMP** | SC-SENS-003 |

### 6.6 VSM (Viable System Model)

| UC-SYS-050 | System 1: Operations Dashboard |
|------------|-------------------------------|
| **Component** | System1Operations |
| **Goal** | Monitor operational units and resource allocation |
| **Focus** | Day-to-day operations |

| UC-SYS-051 | System 2: Coordination View |
|------------|----------------------------|
| **Component** | System2Coordination |
| **Goal** | Display anti-oscillation and conflict resolution |
| **Focus** | Damping oscillations between System 1 units |

| UC-SYS-052 | System 3: Control Dashboard |
|------------|----------------------------|
| **Component** | System3Control |
| **Goal** | Show resource bargaining and optimization |
| **Focus** | Internal regulation |

| UC-SYS-053 | System 4: Intelligence View |
|------------|----------------------------|
| **Component** | System4Intelligence |
| **Goal** | Display environmental scanning and adaptation |
| **Focus** | Future planning, market sensing |

| UC-SYS-054 | System 5: Policy Dashboard |
|------------|---------------------------|
| **Component** | System5Policy |
| **Goal** | Show policy decisions and identity maintenance |
| **Focus** | Ultimate authority, value alignment |

### 6.7 FLAME Distributed Computing

| UC-SYS-060 | FLAME Pool Status |
|------------|-------------------|
| **Component** | FlameRunner |
| **Goal** | Monitor FLAME backend pool utilization |
| **Port** | Phoenix 4000-4001 |

| UC-SYS-061 | Distributed Task Distribution |
|------------|-------------------------------|
| **Component** | FLAME |
| **Goal** | Visualize task distribution across nodes |
| **Metrics** | Active nodes, task queue, completion rate |

### 6.8 Zenoh Mesh Networking

| UC-SYS-070 | Zenoh Mesh Topology |
|------------|---------------------|
| **Component** | ZenohMesh |
| **Goal** | Display mesh network topology and node status |
| **Protocol** | Zenoh pub/sub |

| UC-SYS-071 | KPI Publisher Status |
|------------|----------------------|
| **Component** | ZenohKpiPublisher |
| **Goal** | Monitor KPI publication to mesh |
| **Metrics** | Published topics, subscribers, latency |

| UC-SYS-072 | Control Subscriber Status |
|------------|---------------------------|
| **Component** | ZenohControlSubscriber |
| **Goal** | Display control message subscriptions |
| **Topics** | Commands, configuration updates |

---

## 7. HOLON USE CASES

### 7.1 Holon Lifecycle Management

| UC-HOL-001 | Holon State Visualization |
|------------|---------------------------|
| **Component** | HolonInstance |
| **Goal** | Display holon state machine: Dormant → Awakening → Active → Stressed → Healing → Apoptotic |
| **Colors** | Gray=Dormant, Blue=Awakening, Green=Active, Yellow=Stressed, Cyan=Healing, Red=Apoptotic |

| UC-HOL-002 | Vital Signs Dashboard |
|------------|----------------------|
| **Component** | VitalSigns |
| **Goal** | Monitor HealthIndex (0-1) and StressIndex (0-1) |
| **Display** | Dual bar charts with trend lines |

| UC-HOL-003 | Membrane Permeability Control |
|------------|-------------------------------|
| **Component** | Bio.Membrane |
| **Goal** | Display and control message filtering |
| **States** | Closed, Selective, Open, Emergency |

| UC-HOL-004 | Holon Hierarchy Tree |
|------------|----------------------|
| **Component** | Holon Registry |
| **Goal** | Visualize parent-child holon relationships |
| **Navigation** | Drill-down from federation to function level |

### 7.2 Holon Communication

| UC-HOL-010 | Message Flow Visualization |
|------------|----------------------------|
| **Component** | Messaging |
| **Goal** | Display inter-holon message flow |
| **Types** | Status, Health, Alert, Command |

| UC-HOL-011 | Rate Limiting Status |
|------------|----------------------|
| **Component** | Membrane.RateLimit |
| **Goal** | Show message rate vs limit (default 100/sec) |
| **Alert** | Warning at 80%, block at 100% |

| UC-HOL-012 | Blocked Sources List |
|------------|----------------------|
| **Component** | Membrane.BlockedSources |
| **Goal** | Display and manage blocked message sources |
| **Actions** | Add, remove, temporary block |

### 7.3 Bio Layer Operations

| UC-HOL-020 | Autopoiesis Status |
|------------|---------------------|
| **Component** | Bio.Autopoiesis |
| **Goal** | Show self-organization and self-maintenance |
| **Metrics** | Self-repair actions, adaptation count |

| UC-HOL-021 | Metabolic Resource Flow |
|------------|-------------------------|
| **Component** | ResourceLifecycle |
| **Goal** | Visualize resource consumption and production |
| **Resources** | CPU, Memory, Network, Storage |

| UC-HOL-022 | Homeostasis Indicators |
|------------|------------------------|
| **Component** | Bio Layer |
| **Goal** | Display system stability metrics |
| **Target** | Maintain equilibrium despite perturbations |

### 7.4 Immune Layer Operations

| UC-HOL-030 | Antibody Status |
|------------|-----------------|
| **Component** | Immune.Antibody |
| **Goal** | Display threat detection and response |
| **Metrics** | Threats detected, neutralized, escaped |

| UC-HOL-031 | MARA (Malicious Activity Response) |
|------------|-----------------------------------|
| **Component** | Immune.Mara |
| **Goal** | Monitor automated threat response |
| **Actions** | Quarantine, block, alert, escalate |

| UC-HOL-032 | Immune Memory |
|------------|----------------|
| **Component** | Immune Layer |
| **Goal** | Display learned threat patterns |
| **Storage** | Pattern database with confidence scores |

### 7.5 Neuro Layer Operations

| UC-HOL-040 | Spine Message Bus |
|------------|-------------------|
| **Component** | Neuro.Spine |
| **Goal** | Monitor neural backbone message flow |
| **Latency** | Target < 1ms for reflex messages |

| UC-HOL-041 | Reflex Arc Status |
|------------|-------------------|
| **Component** | Neuro Layer |
| **Goal** | Display fast reflex response status |
| **Examples** | Emergency stop, circuit breaker, rate limiting |

| UC-HOL-042 | Learning Rate Monitor |
|------------|----------------------|
| **Component** | Neuro Layer |
| **Goal** | Track system learning and adaptation rate |
| **Integration** | TrainingGym metrics |

---

## 8. FRACTAL LEVEL MATRIX

| Level | Name | Scope | Example Use Cases |
|-------|------|-------|-------------------|
| L1 | Function | Single function | UC-DEV-001 (pattern analysis) |
| L2 | Module | Single module | UC-DEV-010 (moduledoc check) |
| L3 | Domain | Ash domain | UC-SYS-002 (domain agents) |
| L4 | Component | Subsystem | UC-UM-001 (ingestion) |
| L5 | System | Full system | UC-ADM-001 (container health) |
| L6 | Federation | Multi-system | UC-SYS-070 (mesh topology) |
| L7 | Universe | All systems | UC-SYS-054 (System 5 policy) |

---

## 9. DARK COCKPIT PRINCIPLES APPLIED

| Principle | Implementation |
|-----------|----------------|
| **Management by Exception** | UC-UM-020: 0 errors = dim, >0 = bright |
| **Analog over Digital** | UC-UM-011: Sparklines instead of just numbers |
| **Trend Vectors** | UC-UM-011: Trend arrows (↑↓→) |
| **Staleness Decay** | Grayed-out data after timeout |
| **Two-Step Commit** | Critical operations require arm → confirm |
| **Salience Filtering** | UC-HOL-030: Threat priority scoring |
| **Redundancy Gain** | Multi-modal alerts (visual + log) |
| **Common Operational Picture** | Standardized header across all views |
| **Discriminability** | Distinct colors for each fractal level |
| **Supervisory Control** | Show automation state, not just sensors |

---

## 10. INTEGRATION TOUCHPOINTS

| System | Cockpit Integration | Protocol |
|--------|---------------------|----------|
| Phoenix | Health endpoint, metrics | HTTP :4000 |
| PostgreSQL | Connection status | TCP :5433 |
| OTEL Collector | Trace/metric ingestion | gRPC :4317, HTTP :4318 |
| Prometheus | Metric queries | HTTP :9090 |
| Grafana | Dashboard links | HTTP :3000 |
| Loki | Log queries | HTTP :3100 |
| Podman | Container management | Unix socket |
| Zenoh | Mesh messaging | Zenoh protocol |
| FLAME | Distributed compute | BEAM distribution |

---

## 11. STAMP CONSTRAINT COVERAGE

| Constraint ID | Description | Use Cases |
|---------------|-------------|-----------|
| SC-PRAJNA-001 | Bio layer active | UC-HOL-020-022 |
| SC-PRAJNA-002 | Immune layer active | UC-HOL-030-032 |
| SC-PRAJNA-003 | Neuro layer active | UC-HOL-040-042 |
| SC-HMI-001 | Dark Cockpit colors | All visual UCs |
| SC-HMI-002 | Trend vectors | UC-UM-011 |
| SC-HMI-003 | Staleness decay | All monitoring UCs |
| SC-OODA-001 | <100ms cycle | UC-SYS-010 |
| SC-BUS-003 | 1000 events/sec breaker | UC-SYS-022 |
| SC-GDE-001-004 | Guardian validation | UC-SYS-030-033 |
| SC-SENS-001-003 | Sensor safety | UC-SYS-040-042 |

---

## 12. PRIORITY MATRIX

| Priority | Use Cases | Justification |
|----------|-----------|---------------|
| **P0 Critical** | UC-SRE-001, UC-SRE-110, UC-SYS-001, UC-HOL-001, UC-ARCH-070, UC-BIZ-080, UC-BIZ-140 | Incident response, container health, risk architecture, compliance, DR readiness |
| **P1 High** | UC-UM-001, UC-SYS-010, UC-SYS-020, UC-SRE-040, UC-ARCH-001-005, UC-BIZ-030-034, UC-BIZ-100-104 | Operations, OODA, ADR management, executive oversight, service health |
| **P2 Medium** | UC-DEV-001-006, UC-SRE-090-094, UC-ARCH-030-035, UC-BIZ-001-006, UC-BIZ-090-095 | Developer onboarding, standards governance, product management, QA leadership |
| **P3 Low** | UC-UM-003-004, UC-DEV-010-015, UC-ARCH-190-195, UC-BIZ-070-074, UC-BIZ-170-174 | Discovery, mentorship, marketing, innovation |

---

*Total Use Cases: 463*
*Developer Use Cases: 73 (UC-DEV-001 to UC-DEV-153)*
*SRE/Operations Use Cases: 82 (UC-SRE-001 to UC-SRE-172)*
*Architecture/Leadership Use Cases: 119 (UC-ARCH-001 to UC-ARCH-195)*
*Product & Business Use Cases: 111 (UC-BIZ-001 to UC-BIZ-195)*
*User Manual Use Cases: 21 (UC-UM-001 to UC-UM-021)*
*System Component Use Cases: 42 (UC-SYS-001 to UC-SYS-072)*
*Holon Use Cases: 15 (UC-HOL-001 to UC-HOL-042)*
*Fractal Levels Covered: L1-L7*
*STAMP Constraints: 45+*
*System Components: 50+ Agents, 3 Containers, 5 VSM Systems*
*Architecture Categories: 20 (Decision Making, Strategy, Design, Standards, Debt, Coordination, Capacity, Risk, Security, Performance, Data, Integration, Cloud, Review, Communication, Vendor, Team Topology, Innovation, Compliance, Mentorship)*
*Business Categories: 20 (Product Management, Business Analysis, Project Management, Executive Leadership, Finance, Customer Success, Sales, Marketing, Compliance/Legal/Risk, QA Leadership, Operations, HR/Talent, Vendor/Procurement, External Stakeholders, BC/DR, Strategic Programme, Data/Analytics, Innovation, Facilities, Cross-Functional)*
*SRE Categories: 18 (Incident, Runbook, Config, Deploy, Monitor, Capacity, Reliability, Performance, Security, Database, Network, Container, Cloud, Automation, Vendor, Change, Compliance, Documentation)*
*Developer Categories: 16 (Onboarding, Discovery, Debugging, Archaeology, API, Testing, Review, Build, Security, Performance, Migration, Documentation, Collaboration, Tools, Incident Response, Analysis)*
