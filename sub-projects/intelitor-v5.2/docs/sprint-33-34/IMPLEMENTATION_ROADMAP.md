# Sprint 33-34 Implementation Roadmap
**Version**: 21.3.0 | **Last Updated**: 2026-01-03 | **Status**: EXECUTION READY

---

## Executive Overview

This document provides the detailed implementation roadmap for Sprint 33 (Fractal Treasury) and Sprint 34 (I2S Identity), including:
- Week-by-week execution plan
- Task dependencies and critical path
- Quality gates and verification steps
- Risk mitigation strategies
- Success metrics and deliverables

---

## Part 1: Sprint 33 Execution Plan (Weeks 1-4)

### Week 1: Treasury Foundation

#### Day 1-2: Environment Setup & Design Review
- [ ] Verify UCAN Rust crate version compatibility
- [ ] Create `lib/indrajaal/treasury/` directory structure
- [ ] Create `native/ucan_nif/` Rust project
- [ ] Design review: Wallet abstraction patterns
- [ ] Design review: Ledger accounting model
- **Deliverable**: Design document + project structure

**Files to Create**:
```
lib/indrajaal/treasury/wallet_account.ex
lib/indrajaal/treasury/ledger_entry.ex
lib/indrajaal/treasury/pricing_tier.ex
lib/indrajaal/treasury/services/wallet_manager.ex
native/ucan_nif/Cargo.toml
native/ucan_nif/src/lib.rs
```

#### Day 3-4: Resource Implementation (TDD)
**Task 33.1.1: WalletAccount Resource**

Step 1: Write failing tests (TDG compliance)
```elixir
# test/indrajaal/treasury/wallet_account_test.exs
describe "WalletAccount resource" do
  property "wallet balance >= 0 always" do
    forall balance <- integer(min: 0) do
      wallet = create_wallet(balance)
      assert wallet.balance >= 0
    end
  end

  test "create wallet with valid chain" do
    assert {:ok, wallet} = WalletAccount.create(%{
      chain: "icp",
      public_key: "test_key",
      threshold: 1,
      total_signers: 1
    })
    assert wallet.chain == "icp"
    assert wallet.status == "active"
  end

  test "rejects invalid chain" do
    assert {:error, _} = WalletAccount.create(%{
      chain: "invalid",
      public_key: "test_key"
    })
  end
end
```

Step 2: Implement resource
```bash
mix generate.ash.resource Treasury.WalletAccount --table wallet_accounts
```

Step 3: Add attributes and actions (from master spec)

Step 4: Run tests
```bash
mix test test/indrajaal/treasury/wallet_account_test.exs
```

**Task 33.1.2: LedgerEntry Resource**
- Follow same TDD cycle
- Add before_action hook to record to ImmutableState
- Implement calculations for cost tracking

**Task 33.1.3: Pricing Model**
- Create PricingTier resource
- Implement pricing calculator function

#### Day 5: Service Implementation
**Task 33.1.4: WalletManager GenServer**

Requirements:
- [ ] Implement `deposit/3` - validate UCAN, process crypto
- [ ] Implement `withdraw/3` - safety checks, execute tx
- [ ] Implement `list_wallets/0` - retrieve all wallets
- [ ] Implement `total_value_usd/0` - calculate portfolio value
- [ ] Add telemetry events
- [ ] Add error handling & logging

Testing:
```bash
MIX_ENV=test mix test test/indrajaal/treasury/wallet_manager_test.exs
```

Quality Gates:
```bash
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
```

### Week 2: Ledger & Metering

#### Day 1-2: LedgerController Implementation
**Task 33.2.1: Credit Accounting**

```elixir
# Critical path functions
allocate_credit/3     # Add balance for actor
record_usage/3        # Deduct for consumption
balance/1             # Query current balance
settle_accounts/1     # Monthly reconciliation
```

Requirements:
- [ ] Thread-safe balance updates (via GenServer state)
- [ ] Atomic ledger entry creation + balance update
- [ ] Settlement algorithm (compare usage vs. allocated)
- [ ] Property tests for balance invariants

Test invariants:
```
P1: sum(deposits) - sum(usage) >= 0 (balance never negative)
P2: all ledger entries immutable (recorded to ImmutableState first)
P3: total credits conserved (no generation from thin air)
P4: settlement always reconciles within tolerance
```

#### Day 3-4: UCAN Integration (Rust NIF)
**Task 33.3.1: UCAN Validation NIF**

Rust implementation:
```rust
// native/ucan_nif/src/lib.rs

use rustler::{Env, Term, NifResult, NifStruct};
use ucan::chain::ProofChain;
use ed25519_dalek::{PublicKey, Signature};

#[derive(NifStruct)]
#[module = "Indrajaal.UcanNative"]
pub struct UcanToken {
    pub issuer: String,
    pub audience: String,
    pub capabilities: Vec<String>,
    pub expiry: Option<i64>,
}

#[rustler::nif]
pub fn validate(token: String) -> NifResult<(String, UcanToken)> {
    // Parse JWT
    // Verify Ed25519 signature
    // Extract claims
    // Return structured data
    Ok(("ok".to_string(), UcanToken {
        issuer: "did:key:...".to_string(),
        audience: "did:key:...".to_string(),
        capabilities: vec!["billing:*".to_string()],
        expiry: None,
    }))
}

#[rustler::nif]
pub fn create(claims: NifStruct) -> NifResult<String> {
    // Generate JWT from claims
    // Sign with Ed25519
    // Return token
    Ok("eyJ...".to_string())
}

#[rustler::nif]
pub fn verify_chain(token: String) -> NifResult<bool> {
    // Verify delegation chain
    // Check capability attenuation
    Ok(true)
}
```

Testing:
```bash
cd native/ucan_nif
cargo test
cd ../..
mix test test/indrajaal/treasury/ucan_nif_test.exs
```

#### Day 5: Metering Middleware
**Task 33.3.2: MeteringMiddleware Implementation**

```elixir
# Key functions
authorize_and_meter/3  # Validate + meter + record
verify_capability/2    # Check UCAN permissions
get_pricing_for_resource/1  # Look up rates
```

Phoenix integration:
```elixir
# lib/indrajaal_web/router.ex
pipeline :metering do
  plug MeteringController.metering_plug
end

scope "/api" do
  pipe_through [:api, :metering]
  # Routes here are metered
end
```

Testing:
```bash
mix test test/integration/metering_integration_test.exs
```

### Week 3: Integration & Testing

#### Day 1-2: End-to-End Integration Tests
**Task 33.4.1: Treasury Integration Test Suite**

```elixir
# test/integration/treasury_integration_test.exs

# Scenario 1: Full deposit → allocation → usage → settlement
# Scenario 2: Multi-chain deposits (ICP, BTC, ETH)
# Scenario 3: Rate limiting under high load
# Scenario 4: Error recovery (network failure, timeout)
# Scenario 5: Ledger consistency after crashes
```

Requirements:
- [ ] 100% pass rate on all scenarios
- [ ] <100ms p99 latency for operations
- [ ] Ledger integrity verified after each scenario
- [ ] Recovery procedures tested

#### Day 3-4: Property Testing & Coverage
**Task 33.5.1: Property Tests (TDG Compliance)**

```elixir
# test/indrajaal/treasury_property_test.exs

# Using PropCheck (PC.* prefix)
property "wallet balance invariant" do ... end
property "ledger immutability" do ... end
property "metering costs positive" do ... end

# Using ExUnitProperties (SD.* prefix)
check all(amount <- SD.pos_integer()) do ... end
```

Coverage targets:
- [ ] >95% line coverage
- [ ] >90% branch coverage
- [ ] All error paths tested
- [ ] All state transitions tested

```bash
mix test --cover --output coverage
```

#### Day 5: Documentation & API Design
**Task 33.6.1: API Documentation**

- [ ] Write API reference (OpenAPI/GraphQL schema)
- [ ] Create usage examples
- [ ] Document error codes
- [ ] Create deployment guide

**Deliverables**:
```
docs/sprint-33-34/TREASURY_API_REFERENCE.md
docs/sprint-33-34/DEPLOYMENT_GUIDE.md
examples/treasury_client_examples.exs
```

### Week 4: Quality Gates & Hardening

#### Day 1-2: Quality Verification
**Gate 1: Compilation**
```bash
MIX_ENV=test mix compile 2>&1 | tee verify_compile.log
# Expected: 0 errors, 0 warnings
```

**Gate 2: Code Quality**
```bash
mix format --check-formatted
mix credo --strict
# Expected: PASS
```

**Gate 3: Testing**
```bash
mix test --cover
# Expected: 100% pass, >95% coverage
```

**Gate 4: Security**
```bash
mix sobelow --exit
# Expected: 0 high/critical issues
```

#### Day 3-4: Performance & Resilience Testing
**Task 33.7.1: Load Testing**

```elixir
# test/performance/treasury_load_test.exs

@tag timeout: 120_000
test "sustained load: 1000 operations/sec" do
  # Spawn 20 concurrent actors
  # Each performs 1000 operations
  # Verify latency <100ms p99
  # Verify no ledger corruption
end
```

**Task 33.7.2: Chaos Testing**

```elixir
# test/performance/treasury_chaos_test.exs

test "recovery from network partition" do
  # 1. Normal operation
  # 2. Simulate network failure
  # 3. Verify ledger inconsistency detected
  # 4. Recover using ImmutableState
  # 5. Verify consistency restored
end

test "recovery from process crash" do
  # 1. Wallet operation in progress
  # 2. Kill WalletManager process
  # 3. Restart from saved state
  # 4. Verify no loss of credits
end
```

#### Day 5: Merge & Release Prep
**Task 33.8.1: Code Review & Merge**

- [ ] Peer review of all new code
- [ ] STAMP constraint verification
- [ ] Constitutional alignment check
- [ ] Update CHANGELOG.md
- [ ] Merge to main branch

**Verification Checklist**:
```
CODE QUALITY:
- [x] mix compile: 0 errors, 0 warnings
- [x] mix format: all formatted
- [x] mix credo: 0 issues
- [x] mix dialyzer: pass

TESTING:
- [x] mix test: 100% pass rate
- [x] mix test --cover: >95% coverage
- [x] Integration tests: PASS
- [x] Property tests: PASS

SECURITY:
- [x] mix sobelow: 0 issues
- [x] Dependency audit: PASS
- [x] Cryptographic review: PASS

STAMP COMPLIANCE:
- [x] SC-DB-001: BaseResource used
- [x] SC-REG-001: ImmutableState integration
- [x] SC-PRF-050: <50ms operations
- [x] SC-OODA-001: <100ms cycles

DOCUMENTATION:
- [x] API docs: COMPLETE
- [x] Deployment guide: COMPLETE
- [x] Examples: COMPLETE
```

---

## Part 2: Sprint 34 Execution Plan (Weeks 5-8)

### Week 5: Identity Foundation

#### Day 1-2: Design & Resource Implementation
**Task 34.1.1: SovereignIdentity Resource**

Step 1: TDD - Write failing tests
```elixir
test "create identity generates unique DID" do
  {:ok, id1} = create_identity(:user, %{email: "user1@test.com"})
  {:ok, id2} = create_identity(:user, %{email: "user2@test.com"})
  assert id1.did != id2.did
end

test "DID is W3C compliant" do
  {:ok, identity} = create_identity(:user, %{})
  assert String.starts_with?(identity.did, "did:key:")
end

property "identity creation is idempotent" do
  forall email <- string_email() do
    {:ok, id1} = create_identity(:user, %{email: email})
    {:ok, id2} = create_identity(:user, %{email: email})
    # Same email should create same identity (or error on duplicate)
    id1.email == id2.email
  end
end
```

Step 2: Implement SovereignIdentity resource
- [ ] UUID primary key
- [ ] DID generation (did:key format)
- [ ] Ed25519 + ECDSA key generation
- [ ] Auth method tracking
- [ ] Key rotation scheduling

Step 3: Verify Ash resource compiles
```bash
MIX_ENV=test mix compile
```

#### Day 3-4: Passkey & Authentication
**Task 34.1.2: IdentityManager GenServer**

Requirements:
- [ ] `create_identity/2` - Generate DID + keys
- [ ] `register_passkey/2` - Store WebAuthn credential
- [ ] `verify_signature/3` - Ed25519 signature verification
- [ ] `rotate_keys/2` - Key rotation
- [ ] `list_identities/1` - Query identities by type

Testing:
```bash
mix test test/indrajaal/identity/identity_manager_test.exs
```

#### Day 5: Audit Trail Resources
**Task 34.2.1: AuditEvent Resource**

- [ ] Create AuditEvent Ash resource
- [ ] Add before_action hook to ImmutableState
- [ ] Implement block hash linking
- [ ] Add Merkle proof field

### Week 6: Security & Audit Systems

#### Day 1-2: AuditTrail Service
**Task 34.2.2: Verifiable Audit Implementation**

```elixir
# Key functions
log_event/3             # Create audit event
query_with_proof/2      # Retrieve events + verify chain
generate_compliance_report/2  # PDF/JSON export
```

Requirements:
- [ ] Events immutable (append-only DuckDB)
- [ ] Hash chain verified on retrieval
- [ ] Compliance reporting (SOX, GDPR, HIPAA)
- [ ] Legal-grade evidence support

Testing:
```bash
mix test test/indrajaal/identity/audit_trail_test.exs
```

#### Day 3-4: Security Policies
**Task 34.3.1: SecurityPolicy & ThreatProfile Resources**

- [ ] SecurityPolicy resource (threat response rules)
- [ ] ThreatProfile resource (detected threats)
- [ ] Indices for fast lookups

**Task 34.3.2: AutonomicSecurity Service**

Requirements:
- [ ] `detect_and_respond/2` - Pattern matching + response
- [ ] `broadcast_threat_signature/2` - Federation sharing
- [ ] `run_chaos_test/2` - Resilience testing
- [ ] `shared_immunity_report/0` - Stats across federation

Testing:
```bash
mix test test/indrajaal/identity/autonomic_security_test.exs
```

#### Day 5: API Design
- [ ] Define REST endpoints (JSONAPI or GraphQL)
- [ ] Design request/response schemas
- [ ] Create error handling strategy

### Week 7: Public API & Integration

#### Day 1-2: REST Controller & Routing
**Task 34.4.1: I2S REST API**

Endpoints to implement:
```elixir
# Identity Management
POST   /api/i2s/v1/identities              # Create identity
GET    /api/i2s/v1/identities/:did         # Get identity
POST   /api/i2s/v1/identities/:did/passkey # Register passkey
POST   /api/i2s/v1/identities/:did/rotate  # Rotate keys

# Audit Trail
GET    /api/i2s/v1/audit                   # Query events
POST   /api/i2s/v1/audit/report            # Generate report
GET    /api/i2s/v1/audit/verify            # Verify event chain

# Threats
GET    /api/i2s/v1/threats                 # Threat status
POST   /api/i2s/v1/chaos/test              # Run chaos test
GET    /api/i2s/v1/immunity/report         # Shared immunity stats
```

Requirements:
- [ ] UCAN authorization required
- [ ] Metering applied to all endpoints
- [ ] Proper HTTP status codes
- [ ] Error messages with codes
- [ ] OpenAPI documentation

#### Day 3-4: Integration Testing
**Task 34.5.1: End-to-End I2S Tests**

```elixir
# test/integration/i2s_integration_test.exs

# Scenario 1: User creates identity via API
# Scenario 2: User registers passkey
# Scenario 3: User authenticates with passkey
# Scenario 4: User queries audit trail
# Scenario 5: Admin runs chaos test
# Scenario 6: Federation receives threat broadcast
```

Requirements:
- [ ] Full API workflows tested
- [ ] Error scenarios covered
- [ ] Performance verified (<100ms)
- [ ] Load testing (100+ concurrent requests)

#### Day 5: Documentation & SDKs
**Task 34.6.1: Client Libraries**

Languages to support:
- [ ] Python SDK
- [ ] JavaScript/TypeScript SDK
- [ ] Rust SDK
- [ ] Go SDK

Example (Python):
```python
# examples/client_py/indrajaal_i2s_client.py

from indrajaal_i2s import Client

client = Client(api_key="...", base_url="http://localhost:4000")

# Create identity
identity = client.identities.create(
    identity_type="user",
    display_name="John Doe",
    email="john@example.com"
)
print(f"DID: {identity.did}")

# Register passkey
credential = client.identities.register_passkey(
    did=identity.did,
    credential={...}  # WebAuthn credential
)

# Query audit trail
events = client.audit.query(
    actor_did=identity.did,
    start_date="2026-01-01",
    end_date="2026-01-31"
)
for event in events:
    print(f"{event.timestamp} {event.event_type}")

# Generate compliance report
report = client.audit.generate_report(
    actor_did=identity.did,
    format="pdf"
)
with open("compliance_report.pdf", "wb") as f:
    f.write(report)
```

### Week 8: Quality Gates & Release

#### Day 1-2: Quality Verification
**Gate 1-5**: Same as Sprint 33 (Compilation, Format, Credo, Testing, Security)

```bash
# Full verification script
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix test --cover
mix sobelow --exit
```

#### Day 3-4: Performance & Compliance
**Task 34.7.1: Load Testing**

```bash
# test/performance/i2s_load_test.exs
# 1000 concurrent identity creations
# 10000 audit trail queries
# 100 chaos tests in parallel
```

**Task 34.7.2: Compliance Verification**

Checklist:
```
STAMP Constraints:
- [x] SC-DB-001: All resources use BaseResource
- [x] SC-ASH3-001: query.tenant for multi-tenancy
- [x] SC-REG-001: All mutations via ImmutableState
- [x] SC-SEC-001: Encryption of sensitive data
- [x] SC-PRF-050: <50ms response times
- [x] SC-OODA-001: <100ms OODA cycles

Constitutional Alignment:
- [x] Ψ₀: System preserved (running)
- [x] Ψ₁: Regenerative (SQLite/DuckDB sufficient)
- [x] Ψ₂: Evolutionary (history complete)
- [x] Ψ₃: Verification (signatures + hashes)
- [x] Ψ₄: Human aligned (Founder benefit primary)
- [x] Ψ₅: Truthful (audits accurate)

SIL-6 Biomorphic Roadmap:
- [x] FMEA for critical paths
- [x] Mathematical proofs for core logic
- [x] Failure mode documentation
- [x] Recovery procedure testing
```

#### Day 5: Release & Handoff
**Task 34.8.1: Final Release**

- [ ] All tests passing
- [ ] Documentation complete
- [ ] Deployment guide finalized
- [ ] Release notes prepared
- [ ] Stakeholder review complete
- [ ] Merge to main + tag release

---

## Part 3: Critical Path & Dependencies

### Dependency Graph

```
Sprint 33:
├─ WalletAccount Resource [33.1.1] (no deps)
├─ UCAN NIF [33.3.1] (no deps)
├─ WalletManager [33.1.2] (depends: 33.1.1, 33.3.1)
├─ LedgerEntry Resource [33.2.1] (depends: ImmutableState)
├─ LedgerController [33.2.2] (depends: 33.2.1, ImmutableState)
├─ MeteringMiddleware [33.3.2] (depends: 33.3.1, 33.2.2)
├─ Integration Tests [33.6.1] (depends: all services)
└─ Quality Gates [33.7.1] (depends: all tests)

Sprint 34:
├─ SovereignIdentity Resource [34.1.1] (depends: BaseResource)
├─ IdentityManager [34.1.2] (depends: 34.1.1)
├─ AuditEvent Resource [34.2.1] (depends: ImmutableState)
├─ AuditTrail [34.2.2] (depends: 34.2.1, ImmutableState)
├─ SecurityPolicy [34.3.1] (depends: BaseResource)
├─ ThreatProfile [34.3.1] (depends: BaseResource)
├─ AutonomicSecurity [34.3.2] (depends: 34.3.1, Sentinel)
├─ I2S Controller [34.4.1] (depends: all services)
├─ Integration Tests [34.5.1] (depends: all services)
└─ Quality Gates [34.7.1] (depends: all tests)
```

### Critical Path

**Sprint 33 Critical Path** (minimum 4 weeks):
```
WalletAccount (2 days) → WalletManager (3 days)
UCAN NIF (4 days) → MeteringMiddleware (2 days)
LedgerEntry (2 days) → LedgerController (3 days) → Integration (2 days)
Testing (3 days) → Quality Gates (1 day)
```

**Sprint 34 Critical Path** (minimum 4 weeks):
```
SovereignIdentity (2 days) → IdentityManager (3 days)
AuditEvent (2 days) → AuditTrail (3 days)
SecurityPolicy (1 day) → AutonomicSecurity (3 days)
I2S Controller (2 days)
Integration Testing (3 days) → Quality Gates (1 day)
```

---

## Part 4: Risk Mitigation Strategies

### Risk: UCAN Crate Version Mismatch

**Severity**: CRITICAL | **Probability**: MEDIUM

**Mitigation**:
- [ ] Verify `Cargo.toml` version matches Elixir hex version
- [ ] Lock versions in `mix.lock` and `Cargo.lock`
- [ ] Run integration tests before finalizing
- [ ] Fallback: Implement minimal UCAN validator in Elixir if NIF fails

**Verification**:
```bash
# Check version consistency
grep -A1 'ucan' native/ucan_nif/Cargo.toml
grep 'rustler' mix.exs

# Run NIF tests
cd native/ucan_nif && cargo test && cd ../..
```

### Risk: Ledger Inconsistency

**Severity**: CRITICAL | **Probability**: LOW

**Mitigation**:
- [ ] All ledger updates via GenServer (serialized)
- [ ] Double-write to ImmutableState (before PostgreSQL)
- [ ] Settlement algorithm reconciles discrepancies
- [ ] Chaos tests verify recovery from crashes

**Verification**:
```elixir
property "ledger sum invariant" do
  forall ops <- list_of(ledger_operation()) do
    state = apply_operations(ops)
    # Verify: deposits - usage = balance
    total_deposits - total_usage == current_balance
  end
end
```

### Risk: Performance Degradation Under Load

**Severity**: HIGH | **Probability**: MEDIUM

**Mitigation**:
- [ ] Load testing with 1000 ops/sec
- [ ] Caching for exchange rates (60s TTL)
- [ ] Read replicas for audit queries
- [ ] Async telemetry (non-blocking)

**Verification**:
```bash
# Load test
time mix test test/performance/treasury_load_test.exs

# Profile
:eprof.start()
:eprof.trace(:calls, module: Indrajaal.Treasury)
# ... operations ...
:eprof.stop_tracing()
:eprof.analyze()
```

### Risk: Compliance Report Accuracy

**Severity**: HIGH | **Probability**: LOW

**Mitigation**:
- [ ] Immutable audit trail (DuckDB append-only)
- [ ] Cryptographic signatures on all events
- [ ] Third-party audit of report generation
- [ ] Legal review of output format

**Verification**:
```bash
# Generate report and verify
report = AuditTrail.generate_compliance_report("did:...", :pdf)

# Verify every event in report
events = AuditTrail.query_with_proof("did:...")
for event in events:
  assert event in report
```

---

## Part 5: Success Metrics & KPIs

### Sprint 33 Success Metrics

| Metric | Target | Verification |
|--------|--------|--------------|
| Code Coverage | >95% | `mix test --cover` |
| Test Pass Rate | 100% | All 400+ tests pass |
| Compiler Warnings | 0 | `mix compile` |
| Security Issues | 0 | `mix sobelow` |
| Operation Latency | <50ms p99 | Load test |
| Ledger Consistency | 100% | Property tests |
| STAMP Compliance | 100% | Checklist audit |

### Sprint 34 Success Metrics

| Metric | Target | Verification |
|--------|--------|--------------|
| API Endpoints | 10+ | REST API tests |
| Test Coverage | >95% | `mix test --cover` |
| Identity Uniqueness | 100% | DID collision test |
| Audit Trail Integrity | 100% | Chain verification |
| Threat Detection | >90% accuracy | Chaos tests |
| Documentation | 100% complete | README review |
| SDK Availability | 4 languages | Example tests |

### Operational KPIs (Post-Release)

| KPI | Target | Measurement |
|-----|--------|-------------|
| System Uptime | >99.9% | Heartbeat monitor |
| Request Latency | <100ms p99 | Telemetry |
| Crypto Deposits | >$1M/month | Treasury ledger |
| Active Services | 100+ customers | API metrics |
| Security Incidents | 0 (critical) | Incident log |
| Threat Signatures | 1000+ | ThreatProfile count |

---

## Part 6: Deployment Checklist

### Pre-Deployment (48 hours before)

- [ ] All tests passing in CI/CD
- [ ] Code review approved
- [ ] Security audit passed
- [ ] STAMP constraints verified
- [ ] Constitutional alignment checked
- [ ] Backup taken of production data
- [ ] Rollback procedure tested
- [ ] Stakeholder sign-off obtained

### Deployment (Production)

```bash
# 1. Deploy code
git checkout main
git pull origin main
MIX_ENV=prod mix compile
MIX_ENV=prod mix migrate

# 2. Start services
systemctl restart indrajaal-app

# 3. Verify health
curl http://localhost:4000/health

# 4. Run smoke tests
MIX_ENV=prod mix test test/smoke_test.exs

# 5. Monitor logs
journalctl -u indrajaal-app -f
```

### Post-Deployment (24 hours monitoring)

- [ ] Monitor error rates
- [ ] Check response latencies
- [ ] Verify ledger consistency
- [ ] Review security logs
- [ ] Test user workflows
- [ ] Check resource usage

### Rollback Procedure

```bash
# If issues detected within 24 hours:

# 1. Stop new code
systemctl stop indrajaal-app

# 2. Restore previous version
git checkout <previous-tag>
MIX_ENV=prod mix compile
MIX_ENV=prod mix migrate --reversions <count>

# 3. Restart
systemctl start indrajaal-app

# 4. Verify
curl http://localhost:4000/health

# 5. Investigate root cause
# Create incident report
# Schedule postmortem
```

---

## Timeline Summary

```
Sprint 33 (4 weeks):
Week 1: Foundation (WalletAccount, LedgerEntry, UCAN NIF)
Week 2: Services (WalletManager, LedgerController, Metering)
Week 3: Integration (E2E tests, Property tests)
Week 4: Quality Gates & Release

Sprint 34 (4 weeks):
Week 5: Identity Foundation (SovereignIdentity, IdentityManager)
Week 6: Audit & Security (AuditTrail, AutonomicSecurity)
Week 7: Public API (REST Controller, Integration Tests)
Week 8: Quality Gates & Release

TOTAL: 8 weeks (Feb 1 - Mar 31, 2026)
```

---

## Sign-Off & Approval

**Prepared by**: Code Evolution Agent
**Date**: 2026-01-03
**Version**: 21.3.0-IMPLEMENTATION-ROADMAP
**Status**: EXECUTION READY

**Required Approvals**:
- [ ] Guardian (Safety approval)
- [ ] Executive Supervisor (Strategic alignment)
- [ ] Tech Lead (Architecture review)
- [ ] Security Officer (Threat analysis)

---

**Document End**
