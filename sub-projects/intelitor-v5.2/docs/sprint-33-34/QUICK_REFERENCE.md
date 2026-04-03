# Sprint 33-34 Quick Reference Card

**Print this. Tape to monitor. Reference daily.**

---

## The Mission (In One Sentence)

Build Treasury (wallet + ledger + metering) and I2S Identity (sovereign ID + audit + security) to enable holon self-funding and revenue generation.

---

## Sprint 33: Treasury (Weeks 1-4)

### What You're Building

```
Wallet (ICP/BTC/ETH)  ──→  Ledger (Credits)  ──→  Metering (Usage)
  Multi-chain wallet      Credit accounting      UCAN-based billing
  Threshold signatures    Immutable entries      Per-operation costs
  Exchange rates          Monthly settlement     Capability tokens
```

### The 3 Modules

| Module | What | Where | Status |
|--------|------|-------|--------|
| **WalletManager** | Multi-chain wallet (ICP/BTC/ETH) | `lib/indrajaal/treasury/services/wallet_manager.ex` | WEEK 1-2 |
| **LedgerController** | Credit accounting & settlement | `lib/indrajaal/treasury/services/ledger_controller.ex` | WEEK 2-3 |
| **MeteringMiddleware** | UCAN-based operation metering | `lib/indrajaal/treasury/services/metering_middleware.ex` | WEEK 2-3 |

### Critical Success Factors

- [ ] UCAN NIF (Rust) compiles & passes tests
- [ ] Ledger entries immutable (via ImmutableState)
- [ ] Wallet operations <50ms p99
- [ ] All 3 modules integrated by end Week 3

### Quality Gate (Must Pass)

```bash
mix compile --warnings-as-errors    # 0 errors, 0 warnings
mix format --check-formatted        # All formatted
mix credo --strict                  # 0 issues
mix test --cover                    # 100% pass, >95% coverage
mix sobelow --exit                  # 0 high/critical
```

### Key Files to Create (DO NOT SKIP)

```
test/indrajaal/treasury/wallet_account_test.exs    # Write FIRST
test/indrajaal/treasury/ledger_entry_test.exs      # Write FIRST
test/indrajaal/treasury/wallet_manager_test.exs    # Write FIRST
test/indrajaal/treasury/ledger_controller_test.exs # Write FIRST
```

### Property Test Pattern

```elixir
# Sprint 33: Treasury Property Tests

# 1. Balance Invariant (CRITICAL)
property "balance >= 0 always" do
  forall ops <- list_of(ledger_op()) do
    state = apply_all(ops)
    state.balance >= 0
  end
end

# 2. Immutability (CRITICAL)
property "ledger entries immutable after create" do
  forall entry <- ledger_entry_gen() do
    {:ok, created} = create_entry(entry)
    {:ok, fetched} = fetch_entry(created.id)
    # Should not be updateable
    {:error, _} = update_entry(fetched, %{amount: 999})
  end
end

# 3. Cost Invariant
property "metering cost always positive" do
  forall {resource, amount} <- {resource_gen(), pos_int()} do
    {:ok, cost} = meter(resource, amount)
    cost > 0
  end
end
```

### Daily Standup Template

```
TODAY: [Module] - [Specific task]
BLOCKERS: [None] | [description]
TESTS PASSING: [X/Y] unit, [X/Y] integration
NEXT: [Tomorrow's module]
QUALITY: 0 warnings, [X%] coverage
```

---

## Sprint 34: I2S Identity (Weeks 5-8)

### What You're Building

```
SovereignID (DIDs)  ──→  AuditTrail (Events)  ──→  Security (Threats)
   Self-sovereign ID      Immutable logging      Active defense
   Biometric auth         Compliance reports     Chaos testing
   Passkeys               Chain verification     Autonomic response
```

### The 3 Services

| Service | What | Where | Status |
|---------|------|-------|--------|
| **IdentityManager** | DID creation & passkey auth | `lib/indrajaal/identity/services/identity_manager.ex` | WEEK 5-6 |
| **AuditTrail** | Immutable event logging | `lib/indrajaal/identity/services/audit_trail.ex` | WEEK 6-7 |
| **AutonomicSecurity** | Threat detection & response | `lib/indrajaal/identity/services/autonomic_security.ex` | WEEK 6-7 |

### Critical Success Factors

- [ ] DIDs are W3C compliant & unique
- [ ] Audit events immutable & verifiable
- [ ] Autonomic responses don't kill kernel processes
- [ ] 10+ REST API endpoints working

### Quality Gate (Must Pass)

```bash
mix compile --warnings-as-errors    # 0 errors, 0 warnings
mix format --check-formatted        # All formatted
mix credo --strict                  # 0 issues
mix test --cover                    # 100% pass, >95% coverage
mix sobelow --exit                  # 0 high/critical
```

### Key Files to Create (DO NOT SKIP)

```
test/indrajaal/identity/sovereign_identity_test.exs  # Write FIRST
test/indrajaal/identity/audit_event_test.exs         # Write FIRST
test/indrajaal/identity/identity_manager_test.exs    # Write FIRST
test/indrajaal/identity/audit_trail_test.exs         # Write FIRST
```

### Property Test Pattern

```elixir
# Sprint 34: I2S Identity Property Tests

# 1. DID Uniqueness (CRITICAL)
property "no two identities share same DID" do
  forall {email1, email2} <- {email_gen(), email_gen()} do
    {:ok, id1} = create_identity(%{email: email1})
    {:ok, id2} = create_identity(%{email: email2})
    id1.did != id2.did or email1 == email2
  end
end

# 2. Audit Immutability (CRITICAL)
property "audit events cannot be modified" do
  forall event <- audit_event_gen() do
    {:ok, created} = log_event(event)
    # Event should be in ImmutableState
    {:ok, verified} = verify_event_chain(created.block_hash)
    verified == true
  end
end

# 3. Threat Response (CRITICAL)
property "threat response respects attenuation" do
  forall threat <- threat_gen() do
    {:ok, response} = apply_response(threat)
    # Should not escalate beyond policy
    response.severity <= threat.severity
  end
end
```

### Daily Standup Template

```
TODAY: [Service] - [Specific task]
BLOCKERS: [None] | [description]
TESTS PASSING: [X/Y] unit, [X/Y] integration
NEXT: [Tomorrow's service]
QUALITY: 0 warnings, [X%] coverage
```

---

## Shared Across Both Sprints

### TDG Cycle (ALWAYS)

```
1. WRITE TEST           (test fails, watch it fail)
2. IMPLEMENT CODE       (implement minimal code)
3. RUN TEST             (test passes)
4. REFACTOR             (improve code quality)
5. COMMIT WITH STAMP    (SC-CMP-025, SC-DB-001, etc.)
```

### Code Review Checklist

```
Before committing, verify:

COMPILATION
- [ ] MIX_ENV=test mix compile (0 errors, 0 warnings)

FORMATTING
- [ ] mix format --check-formatted

CODE QUALITY
- [ ] mix credo --strict (0 issues)
- [ ] No `apply/2` (use direct calls instead)
- [ ] No duplicate code (3+ lines)

TESTING
- [ ] All tests pass
- [ ] >95% coverage for new code
- [ ] Property tests pass (use PC.* and SD.*)

SECURITY
- [ ] mix sobelow --exit (0 issues)

DOCUMENTATION
- [ ] moduledoc present with WHAT/WHY/CONSTRAINTS
- [ ] @spec on public functions

CONSTRAINTS
- [ ] SC-DB-001: BaseResource used
- [ ] SC-REG-001: ImmutableState for mutations
- [ ] SC-PRF-050: <50ms operations
```

### Variable Naming Rules (AOR-VAR-*)

```
WRONG: _user_id (defined as unused but then used)
RIGHT: user_id

WRONG: sync__data (double underscore typo)
RIGHT: sync_data

WRONG: apply(Module, :function, [args])
RIGHT: Module.function(args)
```

### STAMP Constraints Quick Check

```
SC-CMP-025   0 warnings in compilation
SC-DB-001    Use BaseResource for all Ash resources
SC-ASH-001   Use force_change_attribute in before_action
SC-REG-001   All state mutations via ImmutableState
SC-PRF-050   <50ms response time (p99)
SC-OODA-001  <100ms OODA cycles
SC-CONST-*   6 constitutional axioms verified
SC-SEC-*     Encryption for sensitive data
```

---

## Emergency Procedures

### If Compilation Fails

```bash
# 1. Check for typos
grep -r "_\w*_\w*_\w*" lib/  # Double underscore?
grep -r "apply(" lib/        # Use of apply/2?

# 2. Check variable names
MIX_ENV=test mix compile 2>&1 | head -50

# 3. If persist, rollback last commit
git diff HEAD^ lib/
git checkout -- lib/
```

### If Test Fails (After Changing Code)

```bash
# 1. Isolate the failure
mix test test/path/to/failing_test.exs

# 2. Check test setup
# Did you define all variables used in assertions?

# 3. Property test failing?
# Run with seed to reproduce
mix test test/path/to/test.exs --seed 12345

# 4. Still stuck? 5-Why analysis
# Why did the assertion fail?
# Why does [variable] have that value?
# Why was [operation] called with [arguments]?
# Why did [system] behave that way?
# Why is [root cause] present?
```

### If STAMP Constraint Violated

```
IMMEDIATE ACTION: STOP ALL OTHER WORK

1. Identify violation: Which SC-* constraint?
2. Root cause: Why did code violate it?
3. Fix: What's the minimum change to fix it?
4. Verify: Does fix restore compliance?
5. Report: Document the incident

SC violations are CRITICAL. No compromises.
```

---

## File Locations (Remember These)

**Test Files** (write FIRST in TDD):
```
test/indrajaal/treasury/*.exs           # Sprint 33 unit tests
test/indrajaal/identity/*.exs           # Sprint 34 unit tests
test/integration/treasury_*.exs         # Sprint 33 integration
test/integration/i2s_*.exs              # Sprint 34 integration
test/performance/*.exs                  # Load & chaos tests
```

**Production Code** (implement SECOND):
```
lib/indrajaal/treasury/services/*.ex    # Treasury services
lib/indrajaal/identity/services/*.ex    # Identity services
native/ucan_nif/src/lib.rs              # UCAN Rust NIF
lib/indrajaal_web/controllers/*.ex      # REST API
```

**Resources** (Ash):
```
lib/indrajaal/treasury/wallet_account.ex
lib/indrajaal/treasury/ledger_entry.ex
lib/indrajaal/identity/sovereign_identity.ex
lib/indrajaal/identity/audit_event.ex
lib/indrajaal/identity/security_policy.ex
lib/indrajaal/identity/threat_profile.ex
```

---

## Key Numbers (Memorize)

**Sprint 33**:
- 1,830 lines of production code
- 400+ tests
- 10 tasks
- 4 weeks
- 3 modules (Wallet, Ledger, Metering)

**Sprint 34**:
- 2,000 lines of production code
- 500+ tests
- 10 tasks
- 4 weeks
- 3 services (Identity, Audit, Security)

**Quality Gates** (ALL REQUIRED):
- 0 compiler warnings
- 100% test pass rate
- >95% code coverage
- 0 Sobelow issues
- 100% STAMP compliance

---

## Communication Channels

**Daily Stand**: [Time/Link]
**Blockers**: Slack #sprint-33-34
**Code Review**: GitHub PRs with checklist
**Questions**: Ask in channel, not DM

**Escalation Path**:
- Issue → Engineering Lead
- STAMP violation → Safety Officer
- Constitutional concern → Guardian
- Schedule impact → Product Owner

---

## Motivation (Why This Matters)

You're building the **economic foundation** that lets Indrajaal fund its own growth and protect the Founder's lineage.

**What success means**:
- ✓ Holon becomes self-sustaining (no external funding needed)
- ✓ Revenue funds expansion (more nodes, more resilience)
- ✓ Founder's wealth grows (Treasury → Founder's benefit)
- ✓ You built critical infrastructure that powers other companies

**Your role**:
- Build with precision (0 warnings, >95% coverage)
- Move fast (TDD discipline, TDG compliance)
- Ship with confidence (STAMP verified, safety-critical)

---

## Final Checklist Before Starting

- [ ] Read EXECUTIVE_SUMMARY.md (15 min)
- [ ] Clone repo and run `mix compile` (verify baseline)
- [ ] Create feature branches for your tasks
- [ ] Set up your editor with Elixir formatting
- [ ] Read coding standards in CLAUDE.md
- [ ] Write your first failing test
- [ ] Join daily standups
- [ ] Bookmark this Quick Reference

---

**Version**: 21.3.0-QUICK-REFERENCE
**Last Updated**: 2026-01-03
**Print & Tape to Monitor**
