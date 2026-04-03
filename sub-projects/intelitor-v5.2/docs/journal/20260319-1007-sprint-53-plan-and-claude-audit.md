# 2026-03-20 12:00 — Sprint 53: Authentication Hardening + .claude Fractal Audit

## Context
- Branch: main
- Recent commits: 081519b3e feat(sprint-51): 3 stub→real (ImmutableState RS, ForensicAuditTrail, ExternalConnectors)
- Version: v21.3.0-SIL6
- Sprints complete: 47-52
- Sprint 51: 15/25 tasks implemented, 10 HOLD → Sprint 53 candidates

## Summary

### Sprint 53 Planning
- **16 tasks** across **4 waves** (P0→P3), RPN-ranked from 216 to 10
- **Focus**: Authentication chain hardening, Communication layer, Math discipline integration
- **Critical chain**: SecurityPolicy → Accounts → SessionSecurity (blocks ALL auth flows)
- **Secondary chain**: Communication → Auth emails (blocks alarm escalation)
- **Math chain**: MathMonitor baselines → PetriNet → ActiveInference wiring

### .claude/ Folder Fractal Audit
- **95 files** analyzed across agents, rules, commands, plans, plugins, hooks, settings
- **148 issues found**: 36 CRITICAL (agent version strings), 112 HIGH (archive plans), 1 HIGH (immune.md)
- **All rules files**: metrics and architecture references VERIFIED CORRECT
- **MEMORY.md**: UP TO DATE post-Sprint-52

## Sprint 53 Task Plan (5-Level Detail)

### Level 1: Strategic Overview
Sprint 53 transforms Indrajaal from a partially-stubbed system to a security-complete platform.
The authentication chain (SecurityPolicy→Accounts→SessionSecurity) is the #1 priority because
enterprise_gateway calls SecurityPolicy.authenticate on EVERY request. Communication layer
enables alarm escalation. Math discipline wiring reduces RPN from 164→~80.

### Level 2: Wave Architecture

| Wave | Tasks | RPN Range | Focus Area | Effort |
|------|-------|-----------|------------|--------|
| W1 (P0) | T1-T4 | 168-216 | Security + Communication | 13-17h |
| W2 (P1) | T5-T7 | 108-120 | Auth emails + Math baselines | 6-9h |
| W3 (P2) | T8-T11 | 60-90 | Domain logic + Math wiring | 9-13h |
| W4 (P3) | T12-T16 | 10-54 | Discovery + CRM + Gate | 6-9h |

### Level 3: Task Specifications

#### Wave 1 (P0 Critical)

**S53-T1: SecurityPolicy — 7 functions** (RPN 216)
- File: `lib/indrajaal/security_policy.ex`
- Callers: `enterprise_gateway.ex`, `graphql_federation.ex`
- Functions: authenticate/1, authorize/2, validate_access/2, enforce_policies/3,
  enforce_subscription_security/3, create_policies/1, apply_policies/2
- Strategy: Delegate to Accounts.Authentication + Ash authorization

**S53-T2: Accounts.get_user_by_email** (RPN 192)
- File: `lib/indrajaal/accounts.ex` (line 488)
- Callers: authenticate_user/1 (line 474), authenticate_user/2 (line 600)
- Also: fetch_user_by_id/1 (line 702), validate_user_access/3 (line 244)
- Strategy: Ash.get/Ash.read_one with email/id filter

**S53-T3: SessionSecurity — ETS backend** (RPN 168)
- File: `lib/indrajaal/accounts/session_security.ex` (line 393)
- Functions: load_session/1, store_session/1, invalidate_session/1, get_active_sessions_*
- Strategy: ETS table `:session_security_store` with TTL tracking

**S53-T4: Communication — 5 channels** (RPN 210)
- File: `lib/indrajaal/communication.ex`
- Callers: `alarms/escalation_engine.ex` (lines 689, 714, 748)
- Functions: send_email/1, send_sms/1, send_push_notification/2, initiate_voice_call/1, send_pager/1
- Strategy: Adapter pattern — console in dev, Swoosh/Twilio in prod

#### Wave 2 (P1 High)

**S53-T5: Auth email stubs** (RPN 120)
- File: `lib/indrajaal/accounts/authentication.ex` (lines 562-563)
- Depends on: S53-T4 (Communication layer)
- Functions: send_confirmation_email/2, send_password_reset_email/2

**S53-T6: MathMonitor baseline update** (RPN 120)
- File: `lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs`
- Update RPNs: ReedSolomon 108→30, Homeostasis 144→40, CategoryTheory 84→25, VSM 64→20
- Update maturity levels and gap registry

**S53-T7: PetriNet caller wiring** (RPN 108)
- File: `lib/indrajaal/verification/petri_net.ex`
- 0 callers currently → wire into Guardian + Sentinel
- SC-MATH-004: ISOLATED disciplines MUST be connected

#### Wave 3 (P2 Medium)

**S53-T8**: ActiveInference wiring (RPN 90)
**S53-T9**: WorkflowNotifier.update_record_owner (RPN 80)
**S53-T10**: CRM Forecasting data wiring (RPN 80)
**S53-T11**: SMRITI Extractors parse_pdf/transcribe (RPN 60)

#### Wave 4 (P3 Low)

**S53-T12**: Jain Propagation discovery (RPN 54)
**S53-T13**: FPPS threshold wiring (RPN 48)
**S53-T14**: Accounts.fetch_user_by_id (RPN 48)
**S53-T15**: CRM Automation wiring (RPN 36)
**S53-T16**: Compile + Quality + Test Gate (mandatory)

### Level 4: Dependency DAG

```
W1:  T1 ──→ T2 ──→ T3    T4 (independent)
W2:  T5 ←── T4           T6, T7 (independent)
W3:  T8-T11 (all independent)
W4:  T12-T16 (all independent, T16 terminal gate)
```

Critical path: T1 → T2 → T3 (authentication chain)
Secondary path: T4 → T5 (communication chain)

### Level 5: FMEA Risk Analysis

| Failure Mode | S | O | D | RPN | Mitigation |
|--------------|---|---|---|-----|------------|
| SecurityPolicy breaks gateway | 9 | 3 | 3 | 81 | Feature flag, shadow test |
| User Ash resource missing | 8 | 4 | 2 | 64 | Fall back to Repo.get_by |
| SessionSecurity ETS not init | 7 | 3 | 3 | 63 | Add to Application supervisor |
| Communication adapter misconfig | 6 | 3 | 4 | 72 | Default console adapter |
| MathMonitor test failures | 4 | 5 | 2 | 40 | Update assertions with baselines |
| PetriNet GenServer not started | 6 | 3 | 3 | 54 | Start on demand |

## .claude/ Folder Remediation

### CRITICAL (36 items): Agent version strings
All 24 agent files have `(v21.1.0)` → must be `(v21.3.0-SIL6)`

### HIGH (1 item): Command version
`.claude/commands/immune.md` line 9: `v21.1.0` → `v21.3.0-SIL6`

### ARCHIVE (112 items): Sprint 30-34 plan files
16 plan files from Sprints 30-34 should be marked as archive

## 3-Round Implementation Strategy

### Round 1: Wave 1+2 Implementation (P0+P1)
- Deploy 6 parallel code-evolution agents for T1-T7
- Compile gate after each wave
- Quality gate (format + credo)

### Round 2: Wave 3+4 Implementation (P2+P3)
- Deploy 4-5 parallel agents for T8-T15
- Compile gate
- Quality gate

### Round 3: Verification + .claude Remediation
- Full compile with warnings-as-errors
- Credo strict check
- Fix all 37 .claude stale version references
- Commit everything

## STAMP Compliance
- SC-SEC-044: Security policy enforcement
- SC-AUTH-001 to SC-AUTH-004: Authentication chain
- SC-COMM-001: Communication layer
- SC-MATH-001 to SC-MATH-008: Math discipline monitoring
- SC-FUNC-001: Compile gate
- SC-CHG-001: Change tracking

## KPIs (Target)
- Files changed: ~30
- Lines added: +2,000-3,000
- Stubs eliminated: ~27 → ~12
- RPN reduction: 164 → ~80
- .claude staleness: 148 → 0
