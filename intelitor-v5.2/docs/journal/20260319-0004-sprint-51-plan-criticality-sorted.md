# Sprint 51: Safety Stub Remediation — Comprehensive Criticality Analysis

**Date**: 2026-03-19 00:04 CET
**Sprint**: 51
**Status**: ACTIVE — Revised per founder directive
**Predecessor**: Sprint 50 (ZUIP complete, commit 5225896f9 + 38bacdf66)
**Total Stubs Identified**: ~55 across 21 files

### Sprint 51 Directive (2026-03-19)

| Status | Count | Tasks |
|--------|-------|-------|
| **IMPLEMENT** | 12 | T5, T10, T11, T12, T13, T14, T18, T19, T21, T22, T24, T25 |
| **HOLD** (manual approval) | 13 | T1, T2, T3, T4, T6, T7, T8, T9, T15, T16, T17, T20, T23 |

**IMPLEMENT tasks by RPN**: T5(120) → T10(100) → T11(90) → T12(84) → T13(75) → T18(72) → T14(60) → T19(48) → T21(36) → T22(36) → T24(24) → T25(16)
**All P0 safety stubs (T1-T4) are on HOLD** — no autonomous implementation until manually approved.

---

## Executive Summary

Sprint 50 completed the Zenoh Universal Integration Plan (ZUIP), closing 77 gaps where safety-critical state mutations were invisible to the Zenoh mesh. Sprint 51 shifts focus to **stub remediation** — production-deployed functions that compile and pass type checks but return hardcoded error values, fake data, or silently discard results. These stubs create a false sense of system health: the system compiles with 0 errors and 0 warnings, but critical code paths (authentication, security policy enforcement, audit chain verification, session management) are non-functional at runtime.

The stubs are sorted below by FMEA Risk Priority Number (RPN = Severity × Occurrence × Detection, each 1-10). Higher RPN means higher combined risk from severity of failure, likelihood of encountering it, and difficulty of detecting it before production impact.

---

## FMEA Master Table (All 25 Tasks, Descending RPN)

| Rank | Task | File | RPN | S | O | D | Priority | Constitutional |
|------|------|------|-----|---|---|---|----------|----------------|
| 1 | T3: SecurityPolicy | security_policy.ex | 240 | 10 | 4 | 6 | P0 | SC-SEC-044, Ω₀ |
| 2 | T1: ImmutableState RS | cockpit/prajna/immutable_state.ex | 216 | 9 | 3 | 8 | P0 | Ω₈, Ψ₂, Ψ₃ |
| 3 | T4: Accounts.get_user_by_email | accounts.ex | 168 | 8 | 7 | 3 | P0 | SC-SEC-047, Ω₀.1 |
| 4 | T2: ForensicAuditTrail | compliance/forensic_audit_trail.ex | 162 | 9 | 2 | 9 | P0 | SC-REG-002, Ψ₃ |
| 5 | T5: Route module | route.ex | 120 | 6 | 4 | 5 | P1 | SC-CMD-017 |
| 6 | T6: SMRITI Extractors | smriti/senses/extractors.ex | 120 | 6 | 5 | 4 | P1 | SC-AI-001 |
| 7 | T8: CRM Automation | crm/automation/*.ex | 120 | 5 | 6 | 4 | P1 | — |
| 8 | T9: SessionSecurity | accounts/session_security.ex | 112 | 7 | 4 | 4 | P1 | SC-SEC-047 |
| 9 | T7: Jain Propagation | jain/propagation.ex | 105 | 7 | 3 | 5 | P1 | Ψ₁ |
| 10 | T10: ConfigManagement | config_management.ex | 100 | 5 | 5 | 4 | P1 | SC-SEC-047 |
| 11 | T11: Alarms.list_alarms | alarms.ex | 90 | 6 | 5 | 3 | P1 | SC-CMD-017 |
| 12 | T12: OodaSupervisor | OodaSupervisor.fs | 84 | 7 | 3 | 4 | P1 | SC-BIO-003 |
| 13 | T13: GraphQL Federation | graphql_federation.ex | 75 | 5 | 3 | 5 | P2 | — |
| 14 | T18: KMS AI | kms/ai.ex | 72 | 6 | 3 | 4 | P2 | SC-AI-001 |
| 15 | T14: EventStreaming | event_streaming.ex | 60 | 4 | 3 | 5 | P2 | — |
| 16 | T20: send_confirmation_email | send_confirmation_email.ex | 50 | 5 | 5 | 2 | P2 | — |
| 17 | T15: ExternalConnectors | external_connectors.ex | 48 | 4 | 3 | 4 | P2 | — |
| 18 | T16: CRM Forecasting | crm/analytics/forecasting.ex | 48 | 4 | 3 | 4 | P2 | — |
| 19 | T17: WorkflowNotifier | crm/notifiers/workflow_notifier.ex | 48 | 4 | 4 | 3 | P2 | — |
| 20 | T19: TestEvolution | biomorphic_test_evolution.ex | 48 | 4 | 3 | 4 | P2 | — |
| 21 | T21: Mara Chaos Agent | immune/mara.ex | 36 | 6 | 2 | 3 | P3 | SC-IMMUNE-001 |
| 22 | T22: SMRITI RAG | smriti/*.ex | 36 | 6 | 2 | 3 | P3 | SC-AI-001 |
| 23 | T23: Ark Bootstrap | — | 24 | 8 | 1 | 3 | P3 | Ψ₁ |
| 24 | T24: Federation Dashboard | — | 24 | 4 | 2 | 3 | P3 | SC-FRAC-006 |
| 25 | T25: TUI Polish + NL CLI | — | 16 | 2 | 2 | 4 | P3 | — |

---

## P0 — CRITICAL (Constitutional & Safety Integrity)

These stubs violate constitutional invariants (Ψ₀-Ψ₅) or axioms (Ω₀-Ω₉). Delay creates compounding risk because downstream systems assume these functions work correctly.

---

### T3: SecurityPolicy — Full Authentication/Authorization Bypass
**FMEA RPN: 240** (Severity=10, Occurrence=4, Detection=6) — **HIGHEST RISK**

**File**: `lib/indrajaal/security_policy.ex`
**Constitutional**: SC-SEC-044 (Sobelow check), SC-SEC-047 (Encryption), Ω₀ (Founder's Directive — resource/power protection)

#### What It Is
The `SecurityPolicy` module is the centralized security enforcement point for the Indrajaal system. It sits at the boundary between external requests and internal domain logic, responsible for:
- **Identity verification** (authenticate: "who are you?")
- **Permission checking** (authorize: "can you do this?")
- **Access control decisions** (validate_access: "should this specific access be allowed?")
- **Policy lifecycle** (create, apply, enforce policies)
- **Subscription-tier security** (enforce_subscription_security: tier-based feature gating)

#### Current Stub Code (ALL 6 Functions)

```elixir
# All return the same error pattern:
def authenticate(credentials) do
  {:error, "SecurityPolicy.authenticate not yet implemented - stub only"}
end

def authorize(user, action) do
  {:error, "SecurityPolicy.authorize not yet implemented - stub only"}
end

def validate_access(user, resource, action) do
  false  # Note: returns false, not {:error, ...} — subtly different
end

def enforce_policies(context, policies, opts) do
  {:error, "SecurityPolicy.enforce_policies not yet implemented - stub only"}
end

def enforce_subscription_security(subscription, action, opts) do
  {:error, "SecurityPolicy.enforce_subscription_security not yet implemented - stub only"}
end

def create_policies(params) do
  {:error, "SecurityPolicy.create_policies not yet implemented - stub only"}
end

def apply_policies(policies, context) do
  {:error, "SecurityPolicy.apply_policies not yet implemented - stub only"}
end
```

#### Who Calls These Functions

1. **`enterprise_gateway.ex:496`** — `authenticate/1` is the FIRST call in `process_request/2`. Since it always returns `{:error, ...}`, the entire enterprise gateway request processing pipeline is 100% non-functional. Every request through this path fails immediately.

2. **`graphql_federation.ex`** — `enforce_policies/3` is called in the federated query path, but the Absinthe GraphQL parser itself fails before this point is reached (Absinthe is not in mix.exs dependencies), making this caller currently unreachable.

3. **`create_policies/1`** — Called during system initialization. The return value `{:error, ...}` is **silently discarded** by the caller — the system continues booting as if policies were created successfully.

#### Impact of Not Implementing

**Immediate (1st Order)**: Enterprise Gateway is completely non-functional. Any enterprise API request returns an authentication error. No external system integration works.

**Cascading (2nd-3rd Order)**: Any multi-tenant deployment where security policies gate access between tenants has ZERO enforcement. A tenant could theoretically access another tenant's data if they bypass the gateway error and reach lower layers directly. The `validate_access/3` returning `false` is slightly safer (deny-by-default), but the inconsistency between `false` and `{:error, ...}` means callers handling one pattern will mishandle the other.

**Constitutional (4th-5th Order)**: Violates Ω₀ (Founder's Directive) — the system cannot protect resources if it cannot authenticate or authorize. Violates SC-SEC-044 — Sobelow security scanning would flag the absence of policy enforcement. A SIL-6 system with no security policy enforcement at its primary boundary is a fundamental contradiction.

#### Impact of Delaying

Each sprint of delay:
- Enterprise Gateway remains dead code (~500 lines of routing logic that can never execute)
- Any demo of multi-tenant security features is impossible
- Integration tests that test the full request→response pipeline cannot be written
- Security audit compliance (ISO 27001) cannot be demonstrated
- Risk compounds because other modules may be written assuming SecurityPolicy works, creating more hidden dependencies on stubs

#### Required Implementation
1. `authenticate/1`: Delegate to `Indrajaal.Authentication` module (JWT verification exists)
2. `authorize/2`: Check against `Indrajaal.Authorization` role/permission system (Ash policies exist)
3. `validate_access/3`: Combine authenticate + authorize with resource-level check
4. `enforce_policies/3`: Apply tenant-scoped policy rules from Ash domain policies
5. `enforce_subscription_security/3`: Validate subscription tier permits the requested operation
6. Wire `create_policies/1` and `apply_policies/2` to the policy store

---

### T1: ImmutableState Reed-Solomon Repair — Self-Healing Disabled
**FMEA RPN: 216** (Severity=9, Occurrence=3, Detection=8) — **CONSTITUTIONAL**

**File**: `lib/indrajaal/cockpit/prajna/immutable_state.ex`
**Lines**: 1072-1097 (verify_block_rs/1), 1103-1149 (verify_chain_with_repair/1), ~1367 (emit_block_repaired — commented out)
**Constitutional**: Ω₈ (Immutable Register), Ψ₂ (Evolutionary Continuity), Ψ₃ (Verification Capability)
**STAMP**: SC-REG-001, SC-REG-006 (Self-Repair First), AOR-REG-002, AOR-REG-004, AOR-REG-009

#### What It Is

The ImmutableState module implements the system's append-only blockchain-like register. Every state mutation in the system is recorded as a cryptographically-signed block: `hash(block) = SHA3-256(content | prev_hash)`. Reed-Solomon error correction (RS(255,223)) adds parity data to each block so that corrupted blocks can be automatically repaired without human intervention — this is the "self-healing" guarantee of SC-REG-006.

The Reed-Solomon module (`reed_solomon.ex`) has three possible return values from `verify_and_repair/3`:
- `{:ok, data}` — block verified, no errors
- `{:repaired, repaired_data, repair_info}` — corruption detected AND repaired
- `{:error, :unrepairable}` — corruption beyond RS correction capability

#### Current Stub Code

```elixir
# lib/indrajaal/cockpit/prajna/immutable_state.ex, lines 1072-1097
defp verify_block_rs(block) do
  case ReedSolomon.verify_and_repair(block.content, block.rs_parity, block.rs_metadata) do
    {:ok, _data} ->
      {:ok, block}

    {:error, :unrepairable} ->
      {:error, {:unrepairable_block, block.index, block.block_hash}}

    # NOTE: The {:repaired, data, repair_info} clause is MISSING
    # Three TODO comments in this area mark the disabled repair path:
    # TODO: Handle {:repaired, repaired_data, repair_info} (line ~1087)
    # TODO: Call emit_block_repaired (line ~1114)
    # TODO: Uncomment emit_block_repaired function (line ~1367)
  end
end
```

The `{:repaired, data, repair_info}` tuple, when returned by the Reed-Solomon module, falls through to Elixir's default `case` clause behavior. Since there is no explicit catch-all clause, it raises a `CaseClauseError` at runtime. However, because the RS module's `do_repair/3` is rarely triggered (corruption is rare), this crash path is unlikely to be hit in normal operation — making it extremely hard to detect through testing.

Additional dead code:
- `verify_chain_with_repair/1` (lines 1103-1149): A function that iterates blocks through `verify_block_rs/1` — has ZERO external callers. It exists but is never invoked from any code path.
- `emit_block_repaired/2` (~line 1367): Entirely commented out. The telemetry emission for repair events does not exist as a callable function.
- `record_repair_event/3` (lines 1155-1173): EXISTS and is functional, but is never called because the repair path never triggers.

#### Who Calls This

`verify_block_rs/1` is called internally by the ImmutableState verification pipeline. The chain verification runs:
- On system startup (verifying register integrity)
- Periodically via Sentinel health monitoring (SC-PRAJNA-004)
- On demand via the Prajna cockpit "Verify Chain" action

#### Impact of Not Implementing

**Immediate (1st Order)**: If a block in the immutable register becomes corrupted (bit flip, disk error, partial write), the RS module CAN repair it — but ImmutableState will crash with a `CaseClauseError` instead of accepting the repair. The block remains corrupted.

**Cascading (2nd-3rd Order)**: A corrupted block breaks the hash chain. Every subsequent `verify_chain_integrity` call will report chain broken. The Immutable Register — the system's source of truth for all state mutations — becomes untrustable. Sentinel health monitoring will flag the chain as broken but cannot trigger repair because the repair path is disabled.

**Constitutional (4th-5th Order)**: This is a direct violation of three constitutional invariants:
- **Ψ₂ (Evolutionary Continuity)**: "Complete history preserved" — corrupted blocks mean lost history
- **Ψ₃ (Verification Capability)**: "All changes verifiable" — broken chain means verification fails
- **Ω₈ (Immutable Register)**: "Self-checking, self-repairing, evolvable" — self-repair is disabled

The system's defining property — an immutable, self-healing audit trail — is not self-healing. It compiles, it passes tests (because tests don't inject corruption), but the core guarantee is hollow.

#### Impact of Delaying

Each sprint of delay:
- Every block appended to the register has repair capability that cannot be invoked
- The probability of encountering a corrupted block increases with time and data volume
- When corruption IS encountered, it will crash the verification pipeline rather than heal
- The gap between "what CLAUDE.md promises" (self-healing register) and "what code does" (crash on repair) widens
- Any security audit examining the register's resilience claims will find them unsubstantiated

#### Required Implementation
1. Add `{:repaired, repaired_data, repair_info}` clause to `verify_block_rs/1`
2. Add matching clause to `verify_chain_with_repair/1` reduce function
3. Uncomment and complete `emit_block_repaired/2` telemetry function
4. Call `record_repair_event/3` to log the repair to the register itself
5. Update the block in the chain with repaired content
6. Wire `verify_chain_with_repair/1` to an actual caller (startup or periodic check)
7. Add Zenoh dual-write: `ZenohSafetyPublisher.publish_immutable_block/2` for repair events
8. Remove 3 TODO comments

---

### T4: Accounts.get_user_by_email — Login Completely Broken
**FMEA RPN: 168** (Severity=8, Occurrence=7, Detection=3)

**File**: `lib/indrajaal/accounts.ex`
**Lines**: 484-489 (get_user_by_email/1), 474 (authenticate_user/1 map form), 600 (authenticate_user/2 binary form)
**Constitutional**: SC-SEC-047, Ω₀.1 (Resource Acquisition — login enables system access)

#### What It Is

`get_user_by_email/1` is the foundational user lookup function. It is the first step in the authentication pipeline: look up the user record by email address, then verify credentials. Without it, no email-based login can succeed.

#### Current Stub Code

```elixir
# lib/indrajaal/accounts.ex, lines 484-489
def get_user_by_email(email) when is_binary(email) do
  # TODO: Implement actual user lookup
  # Should query the User resource by email
  {:error, :not_implemented}
end

# This calls get_user_by_email — always fails:
def authenticate_user(%{"email" => email, "password" => password}) do
  case get_user_by_email(email) do
    {:ok, user} -> verify_password(user, password)  # Never reached
    error -> error  # Always returns {:error, :not_implemented}
  end
end

# This also fails:
def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
  {:error, :invalid_credentials}  # Hardcoded failure
end
```

#### Who Calls This

1. **`auth_controller.ex:63`** — Standard web login. Calls `authenticate_user/1` which calls `get_user_by_email/1`. Always returns HTTP 401.
2. **`mobile_api_controller.ex:32`** — Mobile API login (appears twice for different endpoints). Both always return HTTP 401.
3. **`__request_password_reset/1` (line 646)** — Calls `get_user_by_email/1`, gets `{:error, _}`, then silently swallows the error and continues — password reset "succeeds" without finding a user.

#### The Irony: Real Implementation Exists Elsewhere

A working implementation EXISTS at `lib/indrajaal/accounts/authentication.ex:190`:
```elixir
def get_user_by_email(email) do
  Repo.get_by(User, email: email)
end
```
But `accounts.ex` does NOT delegate to it. The two implementations are disconnected.

#### Test Issues

Tests in `user_test.exs` call `authenticate_user` with keyword-list arguments (e.g., `authenticate_user(email: "test@example.com", password: "secret")`) — this matches NEITHER the map form (`%{"email" => ...}`) NOR the binary form (`email, password`). These tests would raise `FunctionClauseError` if actually executed, but they may be excluded from the default test suite.

#### Impact of Not Implementing

**Immediate (1st Order)**: No user can log in via email. The primary authentication path returns "invalid credentials" for every attempt, regardless of whether the user exists and has correct credentials.

**Cascading (2nd-3rd Order)**:
- Web dashboard (`/prajna`) requires authentication → inaccessible in production mode
- Mobile API authentication → all mobile clients locked out
- Password reset → silently completes but does nothing (user never found)
- Any feature behind authentication → unreachable

**Constitutional (4th-5th Order)**: Violates Ω₀.1 (Resource Acquisition) — the system cannot be accessed by authorized users, defeating the purpose of resource protection. The Founder cannot use the system if login doesn't work.

#### Impact of Delaying

Each sprint of delay:
- Every demo must bypass authentication (creating a false impression of system readiness)
- Any end-to-end test involving login is impossible
- Security testing cannot verify authentication hardening (rate limiting, lockout, MFA) because the base case (successful login) never works
- The divergence between `accounts.ex` and `accounts/authentication.ex` may grow as changes are made to one without awareness of the other

#### Required Implementation
1. Wire `get_user_by_email/1` to Ash `read` action: `Ash.Query.filter(User, email == ^email) |> Ash.read_one()`
2. OR delegate to existing `Indrajaal.Accounts.Authentication.get_user_by_email/1`
3. Ensure tenant context passes through (SC-ASH3-001: use `query.tenant`)
4. Fix `authenticate_user/2` binary form to call `get_user_by_email` instead of returning hardcoded error
5. Fix test argument format (keyword list → map or binary pair)

---

### T2: ForensicAuditTrail — Chain Integrity Always Returns Valid
**FMEA RPN: 162** (Severity=9, Occurrence=2, Detection=9)

**File**: `lib/indrajaal/compliance/forensic_audit_trail.ex`
**Line**: 679
**Constitutional**: SC-REG-002 (Chain Verification on startup), Ψ₂ (Evolutionary Continuity), Ψ₃ (Verification Capability)

#### What It Is

The ForensicAuditTrail module maintains a chain-of-custody record for compliance evidence — who accessed what, when, and what changed. `verify_chain_integrity/1` is the function that validates this chain hasn't been tampered with: each block's hash should match `SHA3-256(content | previous_hash)`.

This is distinct from ImmutableState's chain verification (T1). ForensicAuditTrail is specifically for compliance/legal evidence chains (ISO 27001, GDPR audit trails). ImmutableState is for system state mutations.

#### Current Stub Code

```elixir
# lib/indrajaal/compliance/forensic_audit_trail.ex, line 679
defp verify_chain_integrity(_evidence_id) do
  %{valid: true}  # Always returns valid, regardless of input
end
```

Note: This is a `defp` (private function), meaning it's only called internally.

#### Who Calls This

Called from `update_chain_of_custody/5` (line 192). The chain integrity check code was explicitly commented out at lines 208-211:
```elixir
# The following was deliberately disabled:
# integrity_check = verify_chain_integrity(evidence_id)
# if not integrity_check.valid do
#   trigger_custody_integrity_alert(evidence_id, custody_record, integrity_check)
# end
```

The `trigger_custody_integrity_alert/3` function was also removed entirely.

#### Impact of Not Implementing

**Immediate (1st Order)**: ANY mutation to the forensic audit trail goes undetected. An attacker could modify historical audit records, and the system would report "chain valid: true".

**Cascading (2nd-3rd Order)**:
- Compliance evidence is unverifiable — ISO 27001 and GDPR audit requirements cannot be met
- Chain-of-custody for legal proceedings (e.g., alarm response timelines, access logs) has no integrity guarantee
- The audit trail exists as data, but the data's trustworthiness is zero without verification

**Constitutional (4th-5th Order)**: Direct violation of Ψ₃ (Verification Capability): "All changes verifiable." If the verification function always returns true, the system has literally lost the ability to verify itself. This is an existential threat to the system's compliance posture.

#### Impact of Delaying

Each sprint of delay:
- Every new audit record added to the chain is unprotectable retroactively (if the chain is corrupted now, adding more records on top doesn't fix the break)
- Compliance certifications (ISO 27001) that reference "cryptographic chain integrity" are making false claims
- The longer the chain grows without verification, the more expensive repair becomes if corruption is eventually discovered
- Legal defensibility of audit records decreases — opposing counsel can argue chain integrity was never verified

#### Required Implementation
1. Iterate blocks in the evidence chain
2. Verify each block's hash: `SHA3-256(content | prev_hash) == block_hash`
3. Verify chain continuity: each block's `prev_hash` matches predecessor's `block_hash`
4. Return `%{valid: false, broken_at: index, reason: reason}` on mismatch
5. Restore `trigger_custody_integrity_alert/3` function
6. Uncomment the integrity check in `update_chain_of_custody/5`
7. Wire to ZenohSafetyPublisher for real-time chain status publication

---

## P1 — HIGH (Core Business Features)

These stubs affect core product functionality. While not constitutional violations, they prevent the system from delivering its primary value proposition.

---

### T5: Route Module — Enterprise Gateway Routing Dead
**FMEA RPN: 120** (Severity=6, Occurrence=4, Detection=5)

**File**: `lib/indrajaal/route.ex`

#### What It Is

The Route module implements physical security route matching — mapping alarm events, patrol routes, and access control paths to physical locations (sites, zones, buildings). In a security operations center (SOC), when an alarm fires, the system needs to determine which patrol route covers that zone and which guard should respond.

#### Current Stub Code

```elixir
def find_matching_route(criteria, opts \\ []) do
  {:error, "Route.find_matching_route not yet implemented - stub only"}
end

def find_matching_route(site_id, zone_id, opts) do
  {:error, "Route.find_matching_route not yet implemented - stub only"}
end

def match_route(alarm, routes) do
  {:error, "Route.match_route not yet implemented - stub only"}
end

def parse_route(route_string) do
  {:error, "Route.parse_route not yet implemented - stub only"}
end
```

#### Who Calls This

**`enterprise_gateway.ex:527`** — The Enterprise Gateway calls `find_matching_route` during request routing. Since this always fails, the gateway cannot route ANY request to the correct handler.

#### Impact of Not Implementing

**Immediate**: Enterprise Gateway routing is non-functional. Requests that make it past SecurityPolicy (T3) still cannot be routed to the correct handler.

**Cascading**: Guard tour planning, patrol optimization, alarm-to-zone correlation — all features that depend on route matching — are inert. The SOC dispatch workflow (alarm → zone → route → guard) breaks at step 3.

#### Impact of Delaying

- Enterprise Gateway remains a dead code path even after SecurityPolicy (T3) is fixed
- Route-dependent demo scenarios (guard tours, patrol management) cannot be demonstrated
- T3 and T5 form a sequential dependency: fixing T3 without T5 means requests authenticate but can't be routed

#### Required Implementation
1. Implement route matching using existing site/zone topology from Ash resources
2. `find_matching_route/2,3`: Query route assignments by site/zone
3. `match_route/2`: Pattern-match alarm attributes against route criteria
4. `parse_route/1`: Parse route definition strings into structured data

---

### T9: SessionSecurity — Sessions Created But Immediately Lost
**FMEA RPN: 112** (Severity=7, Occurrence=4, Detection=4)

**File**: `lib/indrajaal/accounts/session_security.ex`
**Line**: 393

#### What It Is

Session management after login: storing sessions, loading them for validation, and invalidating them on logout. This is the persistence layer for user sessions — once `authenticate_user` succeeds (T4), the session must be stored and retrievable.

#### Current Stub Code

```elixir
def load_session(session_id) do
  {:error, :not_implemented}
end

def store_session(session_data) do
  :ok  # Appears to succeed, but stores nothing
end

def invalidate_session(session_id) do
  :ok  # Appears to succeed, but invalidates nothing
end
```

The `store_session/1` stub is particularly insidious: it returns `:ok`, making the caller believe the session was saved. But nothing is persisted. On the next request, `load_session/1` returns `{:error, :not_implemented}`, and `validate_session/3` fails at its first step (a `with` chain that starts with `load_session`).

#### Who Calls This

**`auth_controller.ex`** — Called at lines 66, 184, 239, 505 for:
- Login response (store session after auth)
- Session refresh (load existing session)
- MFA verification (load session, add MFA flag)
- Logout (invalidate session)

#### Impact of Not Implementing

**Immediate**: Even if T4 (get_user_by_email) is fixed and login succeeds, the session is "stored" but immediately lost. The user's next request fails because the session cannot be loaded. Users are effectively logged in for exactly one request.

**Cascading**: Session refresh, MFA flows, and logout are all broken. Token refresh returns "session not found". MFA adds a flag to a non-existent session. Logout "succeeds" but there's nothing to invalidate.

#### Impact of Delaying

- T4 and T9 form a dependency chain: fixing T4 without T9 means login "works" but sessions don't persist
- Any multi-request workflow (login → navigate → perform action) is impossible
- Security features like session timeout, concurrent session limits, and forced logout are unimplementable until session storage works

#### Required Implementation
1. `store_session/1`: Persist to ETS table or Redis (session_id → session_data)
2. `load_session/1`: Retrieve from session store, return `{:ok, session}` or `{:error, :not_found}`
3. `invalidate_session/1`: Delete from session store
4. Add TTL-based expiration for session entries
5. Integrate with the existing Phoenix session infrastructure

---

### T8: CRM Automation — Workflow Actions Silently Suppressed
**FMEA RPN: 120** (Severity=5, Occurrence=6, Detection=4)

**Files**:
- `lib/indrajaal/crm/automation/approval.ex` (8 stubs)
- `lib/indrajaal/crm/automation/workflow.ex` (6 stubs)
- `lib/indrajaal/crm/automation/lead_assignment.ex` (4 stubs)

#### What It Is

The CRM automation layer handles three core business processes:
1. **Approval Workflows**: Multi-step approval for quotes, deals, discounts
2. **Workflow Automation**: Triggered actions on CRM events (email alerts, task creation, webhooks)
3. **Lead Assignment**: Auto-routing leads to sales reps based on territory, skills, workload

#### Current Stub Code

**Approval (8 stubs)**:
```elixir
defp notify_approvers(_step, _approval_process), do: :ok      # No notification sent
defp notify_delegate(_delegation, _approval_process), do: :ok  # No delegation notification
def recall(approval_id, opts), do: {:ok, %{...hardcoded...}}   # No DB persist
def check_and_escalate_timeouts(), do: []                       # Always empty, no escalation
defp get_approval_process(approval_id), do: {:ok, %{...}}      # Hardcoded fake 2-step process
defp validate_approver(user_id, step), do: :ok                  # Anyone can approve anything
defp check_step_complete(step), do: true                        # Every step auto-completes
defp advance_to_next_step(process, step), do: {:ok, process}    # No actual advancement
```

**Workflow (6 stubs)**:
```elixir
# In execute_action/2:
:email_alert -> Logger.info("Would send email")     # No email sent
:create_task -> Logger.info("Would create task")     # No task created
:invoke_flow -> Logger.info("Would invoke flow")     # No flow triggered
:outbound_message -> Logger.info("Would send SMS")   # No message sent
:webhook -> Logger.info("Would call webhook")        # No HTTP request
# In evaluate_condition:
:changed -> true   # Field change detection always returns true
```

**Lead Assignment (4 stubs)**:
```elixir
defp get_team_members(_team_id), do: ["user-1", "user-2", "user-3"]  # Hardcoded
defp get_territory_owner(territory) do
  case territory do
    "US-CA" -> "rep-california"    # Hardcoded
    "US-NY" -> "rep-newyork"       # Hardcoded
    _ -> "rep-default"             # Hardcoded
  end
end
defp get_skilled_reps(_required_skills), do: ["skilled-rep-1", "skilled-rep-2"]  # Hardcoded
defp get_team_workloads(team_ids), do: Enum.map(team_ids, fn id ->
  {id, :rand.uniform(20)}  # RANDOM workload — non-deterministic assignment
end)
```

#### Who Calls This

**Workflow engine**: `WorkflowNotifier` (Ash.Notifier) fires on EVERY CRM resource action (create, update, delete). Every CRM operation triggers workflow evaluation, but all actions are silently suppressed with Logger.info.

**Lead assignment**: Called when new leads are created. Assignment "works" but always assigns to hardcoded user IDs that don't exist in the database.

**Approval**: Not directly called from Ash resources (uses its own API), but referenced by the Quote approval flow.

#### Impact of Not Implementing

**Immediate**: CRM is a data entry system only. Data goes in, but no automated actions fire. No emails, no tasks, no webhooks, no notifications.

**Cascading**:
- Sales team gets no alerts when deals progress
- Quote approval is a formality (every approver is valid, every step auto-completes)
- Leads are assigned to non-existent users ("user-1", "user-2") — effectively unassigned
- Workload balancing is random, not data-driven

#### Impact of Delaying

- CRM demonstrations must manually simulate automation ("imagine an email would be sent here")
- Any CRM customer pilot would expose the automation gap immediately
- Integration testing (webhook → external system) is impossible
- Lead assignment randomness means test results are non-reproducible

---

### T7: Jain Propagation — Federation Invitation Broken
**FMEA RPN: 105** (Severity=7, Occurrence=3, Detection=5)

**File**: `lib/indrajaal/jain/propagation.ex`
**Line**: 172

#### What It Is

The Jain Propagation module handles holon-to-holon federation invitations — how new nodes join the mesh. `request_invitation/1` is the entry point for a holon requesting to join an existing federation.

#### Current Stub Code

```elixir
def request_invitation(params) do
  {:error, :not_implemented}
end
```

#### Who Calls This

**Zero direct callers in lib/**.  This is dead code currently — no code path in the system triggers federation invitation. However, it is referenced in documentation (HOLON_IMMORTAL_ARCHITECTURE.md) and the 10x10 Master Plan (Phase 7: Federation).

#### Impact of Not Implementing

**Immediate**: No impact on current functionality (no callers).

**Constitutional**: Violates Ψ₁ (Regeneration) — the system cannot propagate itself to new nodes. Federation (L7 in the fractal hierarchy) is non-functional.

#### Impact of Delaying

- Acceptable for single-node deployments
- Blocks multi-node testing and federation verification
- Must be implemented before any multi-site deployment

---

### T10: ConfigManagement — Audit Logs Misattributed to "system"
**FMEA RPN: 100** (Severity=5, Occurrence=5, Detection=4)

**File**: `lib/indrajaal/config_management.ex`
**Lines**: 452, 643, 772, 1002, 1214

#### What It Is

Configuration management with change tracking. Five locations call `get_current_user/0` which always returns `"system"`, and one `Versioning.get_versions/1` always returns `[]`.

#### Current Stub Code

```elixir
# Three separate definitions, all identical:
defp get_current_user, do: "system"
defp get_current_user, do: "system"
defp get_current_user, do: "system"

# Version listing:
def get_versions(config_id), do: []  # Always empty list

# Export:
def export_to_xml(config, opts), do: {:error, :not_implemented}
```

#### Impact of Not Implementing

**Immediate**: All configuration change audit logs attribute changes to "system" user, regardless of who actually made the change. This makes audit logs useless for accountability.

**Compliance**: ISO 27001 requires traceability of configuration changes to specific users. "system" for all changes fails this requirement.

**Version history**: `get_versions/1` returning `[]` means no configuration version history is available, even though versions may exist in the database.

#### Impact of Delaying

- Audit log quality degrades with every configuration change (all attributed to "system")
- The longer this runs, the more historical audit records are permanently misattributed
- Configuration rollback (which needs version history) is impossible

---

### T11: Alarms.list_alarms/1 — Core Product Feature Stubbed
**FMEA RPN: 90** (Severity=6, Occurrence=5, Detection=3)

**File**: `lib/indrajaal/alarms.ex`
**Lines**: 667-668

#### What It Is

Alarm listing is the core feature of a security management system. `list_alarms/1` should return filtered, paginated alarm data.

#### Current Stub Code

```elixir
def list_alarms(filters) do
  list_active_alarms(filters, [])  # Delegation — filters may not pass correctly
end
```

The delegation to `list_active_alarms/2` exists, but the filter transformation may be lossy (the `filters` map structure may not match what `list_active_alarms` expects).

#### Who Calls This

- `monitoring.ex:458` — System health monitoring
- `cache/warmer.ex:194` — Cache prewarming
- `config_management.ex:244` — Configuration-dependent alarm queries

#### Impact of Not Implementing

**Immediate**: Alarm listing may return incorrect results due to filter mismatch. Users querying alarms by severity, zone, or time range may see wrong data.

**Cascading**: Cache warming uses wrong alarm data. Health monitoring reports based on incomplete alarm lists. Dashboard alarm counts may be wrong.

#### Impact of Delaying

- Every alarm query potentially returns wrong results
- Dashboard alarm widgets show incorrect data
- Demo scenarios involving "show me all critical alarms in Zone A" may fail or show wrong counts

---

### T12: F# OodaSupervisor — Biomorphic Scaling Non-Functional
**FMEA RPN: 84** (Severity=7, Occurrence=3, Detection=4)

**File**: `lib/cepaf/src/Cepaf/Mesh/OodaSupervisor.fs`
**Lines**: 521, 524

#### What It Is

The OODA (Observe-Orient-Decide-Act) Supervisor implements the biomorphic metabolic scaling described in CLAUDE.md Section 92.0. It should dynamically scale agent count up/down based on API token availability ("energy") — the system behaves like a biological organism regulating its metabolic rate.

#### Current Stub Code

```fsharp
| ScaleUp n ->
    { state with LastDecisionTime = now },
    Skipped (sprintf "Scale up by %d not implemented" n)

| ScaleDown n ->
    { state with LastDecisionTime = now },
    Skipped (sprintf "Scale down by %d not implemented" n)
```

The `decide` function in the OODA loop never actually produces `ScaleUp` or `ScaleDown` decisions — these are dead code paths. The scaling logic that SHOULD feed into these decisions (based on API rate limit headers, token budget, and current load) is not implemented in the `decide` function.

#### Impact of Not Implementing

**Immediate**: No dynamic scaling. The system runs with a fixed agent count regardless of API availability.

**Constitutional**: Violates SC-BIO-003 (Agent scaling respects API limits) and AOR-BIO-002 (Scale agents dynamically within API budget).

#### Impact of Delaying

- System cannot respond to API rate limiting by reducing agent count
- Cannot exploit periods of low load by scaling up for more throughput
- Biomorphic metabolic model (Section 92.0) remains a specification without implementation

---

## P2 — MEDIUM (Integration & Wiring)

These stubs affect peripheral integrations and secondary features. They don't block core functionality but prevent feature completeness.

---

### T13: GraphQL Federation — Absinthe Not in Dependencies
**FMEA RPN: 75** (Severity=5, Occurrence=3, Detection=5)

**File**: `lib/indrajaal/integration/graphql_federation.ex`, Lines 707, 762

**What It Is**: Federated GraphQL schema for cross-service queries. Two query paths are commented out because Absinthe is not included in mix.exs dependencies. The entire GraphQL layer is inert — the module compiles but cannot parse or execute any GraphQL query.

**Impact of Delay**: Blocks any GraphQL API consumer. REST endpoints remain the only API surface. API consumers requiring GraphQL must wait.

---

### T18: KMS AI — LLM Classification and Embedding
**FMEA RPN: 72** (Severity=6, Occurrence=3, Detection=4)

**File**: `lib/indrajaal/kms/ai.ex`, Lines 454, 542

**What It Is**: IntentRouter (classifying user queries) and embedding API integration (vector representations for semantic search). Two TODO stubs block the RAG (Retrieval-Augmented Generation) pipeline.

**Impact of Delay**: Blocks 10x10 Master Plan Phase 5 (SMRITI RAG). Knowledge engine cannot classify intents or generate embeddings. Combined with T6 (parse_pdf), the entire knowledge ingestion pipeline is non-functional.

---

### T14: EventStreaming.list_processors/0
**FMEA RPN: 60** (Severity=4, Occurrence=3, Detection=5)

**File**: `lib/indrajaal/integration/event_streaming.ex`, Line 839

**What It Is**: Lists active stream processors. Currently commented out. Affects observability of the event streaming pipeline.

**Impact of Delay**: Cannot monitor active stream processors. Operational visibility into event flow is reduced.

---

### T20: send_confirmation_email — Registration Emails Swallowed
**FMEA RPN: 50** (Severity=5, Occurrence=5, Detection=2)

**File**: `lib/indrajaal/accounts/changes/send_confirmation_email.ex`, Line 11

**What It Is**: Ash change callback that should send email confirmation after user registration. Currently a no-op.

**Impact of Delay**: Users register but receive no confirmation email. Email verification flow is broken. Easy to detect once email is tested, but currently invisible because the function returns `:ok`.

---

### T15: ExternalConnectors — Connector Lifecycle
**FMEA RPN: 48** (Severity=4, Occurrence=3, Detection=4)

**File**: `lib/indrajaal/integration/external_connectors.ex`, Lines 666, 670

**What It Is**: Connector start/stop lifecycle management. Returns `{:error, :not_implemented}`.

**Impact of Delay**: Cannot programmatically manage external system connections. Manual connector management required.

---

### T16: CRM Forecasting
**FMEA RPN: 48** (Severity=4, Occurrence=3, Detection=4)

**File**: `lib/indrajaal/crm/analytics/forecasting.ex`, Line 263

**What It Is**: Sales pipeline forecasting based on opportunity stages and historical conversion rates.

**Impact of Delay**: CRM analytics dashboard shows no forecasts. Sales projections unavailable.

---

### T17: WorkflowNotifier — Owner Reassignment
**FMEA RPN: 48** (Severity=4, Occurrence=4, Detection=3)

**File**: `lib/indrajaal/crm/notifiers/workflow_notifier.ex`, Lines 149, 187

**What It Is**: Ash Notifier callback for lead/opportunity owner reassignment. The reassignment action is defined but the actual Ash update call is stubbed.

**Impact of Delay**: Workflow rules that trigger owner reassignment log "would reassign" but don't actually change ownership. Records stay with original owner.

---

### T19: BiomorphicTestEvolution — Fitness Scoring Approximate
**FMEA RPN: 48** (Severity=4, Occurrence=3, Detection=4)

**File**: `lib/indrajaal/cockpit/prajna/biomorphic_test_evolution.ex`, Lines 862, 875

**What It Is**: Coverage tool and mutation testing integration for test evolution fitness scoring. Without these, the system uses approximate fitness metrics instead of actual coverage data.

**Impact of Delay**: Test evolution uses estimated fitness instead of measured fitness. Evolution decisions may be suboptimal but not dangerous.

---

## P3 — LOW (Strategic / 10x10 Master Plan)

These are future-looking items from the 10x10 Master Plan. They don't affect current system operation.

---

### T21: Mara Chaos Agent (Phase 6)
**FMEA RPN: 36**

`lib/indrajaal/cockpit/prajna/immune/mara.ex` — 50% complete. Guardian "Antibody" auto-block at 75%. Chaos engineering scenarios for resilience testing. No production impact if delayed; affects resilience confidence only.

### T22: SMRITI RAG End-to-End (Phase 5)
**FMEA RPN: 36**

Blocked by T6 (parse_pdf) and T18 (embedding API). MemoryAgent + VectorStore modules exist but the ingestion pipeline has two broken endpoints. Cannot ingest documents until extractors work.

### T23: Ark Self-Extracting Bootstrap (Phase 9)
**FMEA RPN: 24**

Seed-of-Life bootstrap for total-loss recovery. Constitutional importance (Ψ₁ Regeneration) but extremely low occurrence probability. Can be delayed without risk to current operations.

### T24: Federation Dashboard (Phase 7)
**FMEA RPN: 24**

Multi-node gossip protocol + federation dashboard in Cepaf.Cockpit. SMRITI.Mesh.Gossip module exists but needs Zenoh router wiring. Only relevant for multi-node deployments.

### T25: TUI Polish + NL CLI (Phase 8)
**FMEA RPN: 16**

Natural language CLI query interface and user guide generator. Quality-of-life improvement with no safety impact.

---

## Revised Execution Plan (2026-03-19 Directive)

### Active Implementation Queue (8 tasks)

```
Wave A: Core Business (highest RPN first)
  T5  (Route module)         RPN=120  P1  — Enterprise Gateway routing
  T18 (KMS AI)               RPN=72   P2  — LLM classification + embedding
  T14 (EventStreaming)        RPN=60   P2  — list_processors/0

Wave B: Platform & Operations
  T10 (ConfigManagement)      RPN=100  P1  — Tenant context + versioning
  T11 (Alarms.list_alarms)    RPN=90   P1  — Core alarm listing
  T12 (OodaSupervisor)        RPN=84   P1  — F# biomorphic scaling
  T13 (GraphQL Federation)    RPN=75   P2  — Absinthe dependency wiring

Wave C: Test & Chaos
  T19 (TestEvolution)         RPN=48   P2  — Coverage + mutation fitness
  T21 (Mara Chaos Agent)      RPN=36   P3  — Chaos engineering to 100%
  T22 (SMRITI RAG)            RPN=36   P3  — E2E verification (blocked by T18)

Wave D: Strategic
  T24 (Federation Dashboard)  RPN=24   P3  — Gossip + dashboard + trust score
  T25 (TUI + NL CLI)          RPN=16   P3  — Natural language CLI
```

### HOLD Queue (13 tasks — manual approval required)

| Task | RPN | Reason for HOLD |
|------|-----|-----------------|
| T3 (SecurityPolicy) | 240 | P0 constitutional — founder review |
| T1 (ImmutableState RS) | 216 | P0 constitutional — founder review |
| T4 (get_user_by_email) | 168 | P0 auth chain — founder review |
| T2 (ForensicAuditTrail) | 162 | P0 compliance — founder review |
| T6 (SMRITI Extractors) | 120 | P1 — founder review |
| T8 (CRM Automation) | 120 | P1 — founder review |
| T9 (SessionSecurity) | 112 | P1 — founder review |
| T7 (Jain Propagation) | 105 | P1 — founder review |
| T20 (send_confirmation_email) | 50 | P2 — founder review |
| T15 (ExternalConnectors) | 48 | P2 — founder review |
| T16 (CRM Forecasting) | 48 | P2 — founder review |
| T17 (WorkflowNotifier) | 48 | P2 — founder review |
| T23 (Ark Bootstrap) | 24 | P3 — founder review |

### Dependencies

| Task | Depends On | Status |
|------|-----------|--------|
| T22 (RAG) | T18 (KMS AI) | T18 in IMPLEMENT queue |
| T22 (RAG) | T6 (Extractors) | T6 on HOLD — implement RAG without PDF parsing |
| T5 (Route) | T3 (SecurityPolicy) | T3 on HOLD — implement Route independently, test in isolation |

---

## Stub Density Heatmap

| File | Stub Count | Priority | Impact Zone |
|------|-----------|----------|-------------|
| `crm/automation/approval.ex` | 8 | P1 | CRM Business |
| `integration/external_connectors.ex` | 7 | P2 | Integration |
| `security_policy.ex` | 6 | **P0** | Security Boundary |
| `crm/automation/workflow.ex` | 6 | P1 | CRM Business |
| `config_management.ex` | 5 | P1 | Audit/Compliance |
| `crm/automation/lead_assignment.ex` | 4 | P1 | CRM Business |
| `cockpit/prajna/immutable_state.ex` | 3 | **P0** | Constitutional |
| `accounts/session_security.ex` | 3 | P1 | Auth Chain |
| `smriti/senses/extractors.ex` | 2 | P1 | Knowledge Engine |
| `cockpit/prajna/biomorphic_test_evolution.ex` | 2 | P2 | Test Infra |
| `crm/notifiers/workflow_notifier.ex` | 2 | P2 | CRM Business |
| `kms/ai.ex` | 2 | P2 | AI Pipeline |
| `integration/graphql_federation.ex` | 2 | P2 | API Surface |
| `compliance/forensic_audit_trail.ex` | 1 | **P0** | Compliance |
| `accounts.ex` | 1 | **P0** | Auth Entry Point |
| `route.ex` | 4 | P1 | Gateway Routing |
| `alarms.ex` | 1 | P1 | Core Product |
| `jain/propagation.ex` | 1 | P1 | Federation |
| `crm/analytics/forecasting.ex` | 1 | P2 | Analytics |
| `integration/event_streaming.ex` | 1 | P2 | Event Pipeline |
| `accounts/changes/send_confirmation_email.ex` | 1 | P2 | User Lifecycle |

**Total**: ~55 stubs across 21 files

---

## Constitutional Violation Summary

| Invariant | Violated By | Current State | Risk |
|-----------|------------|---------------|------|
| Ψ₂ (Evolutionary Continuity) | T1, T2 | Chain verification disabled/fake | History can be corrupted silently |
| Ψ₃ (Verification Capability) | T1, T2 | Self-repair disabled, integrity unchecked | System cannot verify itself |
| Ω₀ (Founder's Directive) | T3, T4 | Auth bypass, login broken | System cannot protect resources |
| Ω₈ (Immutable Register) | T1 | Self-healing promise not kept | Register degrades under corruption |
| SC-BIO-003 (Agent Scaling) | T12 | Fixed agent count | No metabolic regulation |
| SC-SEC-044 (Security) | T3 | No policy enforcement | Security boundary absent |
| SC-REG-006 (Self-Repair) | T1 | Repair return value crashes | Self-repair worse than absent |

---

## Risk Accumulation Model

The key insight of this analysis: **stubs don't just create current risk — they accumulate risk over time**.

| Time Horizon | P0 Stubs | P1 Stubs | P2 Stubs |
|-------------|----------|----------|----------|
| Sprint +1 | Chain corruption risk grows with data volume | Demo credibility gap | Negligible |
| Sprint +3 | Audit non-compliance becomes entrenched | CRM customers encounter automation gaps | Integration partners notice missing features |
| Sprint +6 | Constitutional violations compound: security + integrity + verification all fake | Business logic built on top of stubs creates deeper dependencies | Technical debt interest exceeds implementation cost |
| Sprint +12 | Existential: system makes SIL-6 claims with no security, no integrity, no self-healing | Refactoring cost exceeds greenfield for CRM automation | P2 items become P1 as product scope expands |

**Conclusion**: P0 items (T1-T4) should be treated as **blocking** for any production or GA release claim. P1 items should be completed within 2 sprints. P2 items can be scheduled based on product roadmap priorities.
